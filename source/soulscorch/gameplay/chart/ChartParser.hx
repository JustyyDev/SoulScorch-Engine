package soulscorch.gameplay.chart;

import haxe.Json;
import haxe.xml.Access;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.system.XMSoul;
import soulscorch.backend.utils.Logger;

using StringTools;

class ChartParser {
    public static function parse(rawText:String, ?songNameFallback:String = "tutorial"):Song {
        if (rawText == null || rawText.trim().length == 0) {
            return new Song(songNameFallback, songNameFallback);
        }

        // Auto-detect .soulchart XML format by looking for opening tag
        if (rawText.trim().startsWith("<")) {
            return parseSoulChartXML(rawText, songNameFallback);
        }

        // Otherwise, fall back to parsing legacy JSON format
        return parseLegacyJSON(rawText, songNameFallback);
    }

    private static function parseSoulChartXML(rawXml:String, fallback:String):Song {
        try {
            var xml = Xml.parse(rawXml);
            var root = new Access(xml.firstElement());

            var songName = XMSoul.getAttr(root, "song", fallback);
            var parsed = new Song(songName, songName);

            parsed.bpm = XMSoul.getFloatAttr(root, "bpm", 100.0);
            parsed.scrollSpeed = XMSoul.getFloatAttr(root, "speed", 2.0);
            parsed.player1 = XMSoul.getAttr(root, "player1", "bf");
            parsed.player2 = XMSoul.getAttr(root, "player2", "dad");
            parsed.gfVersion = XMSoul.getAttr(root, "gfVersion", "gf");
            parsed.stage = XMSoul.getAttr(root, "stage", "stage");
            parsed.needsVoices = XMSoul.getBoolAttr(root, "needsVoices", true);

            parsed.chart = new Chart(parsed.bpm, parsed.scrollSpeed);

            for (node in root.elements) {
                switch (node.name.toLowerCase()) {
                    case "note":
                        var time = XMSoul.getFloatAttr(node, "time", 0.0);
                        var dir = XMSoul.getIntAttr(node, "dir", 0);
                        var len = XMSoul.getFloatAttr(node, "len", 0.0);
                        var type = XMSoul.getAttr(node, "type", "Default");
                        var player = XMSoul.getBoolAttr(node, "player", true);
                        parsed.chart.addNote(time, dir, len, type, player);

                    case "event":
                        var time = XMSoul.getFloatAttr(node, "time", 0.0);
                        var name = XMSoul.getAttr(node, "name", "");
                        var val1 = XMSoul.getAttr(node, "val1", "");
                        var val2 = XMSoul.getAttr(node, "val2", "");
                        parsed.chart.addEvent(time, name, val1, val2);
                }
            }

            loadExternalEvents(songName, parsed.chart);

            parsed.chart.sortNotes();
            parsed.chart.sortEvents();
            return parsed;

        } catch (e:Dynamic) {
            Logger.error('Failed parsing .soulchart XML: $e', "chart");
            return new Song(fallback, fallback);
        }
    }

    private static function parseLegacyJSON(rawJson:String, fallback:String):Song {
        try {
            var raw:Dynamic = Json.parse(rawJson);
            var songData:Dynamic = raw;

            if (raw != null && Reflect.hasField(raw, "song")) {
                var innerSong = Reflect.field(raw, "song");
                if (Reflect.isObject(innerSong)) songData = innerSong;
            }

            var songName:String = Reflect.hasField(songData, "song") ? Std.string(Reflect.field(songData, "song")) : fallback;
            var parsed = new Song(songName, songName);

            if (Reflect.hasField(songData, "bpm")) parsed.bpm = Std.parseFloat(Std.string(Reflect.field(songData, "bpm")));
            if (Reflect.hasField(songData, "scrollSpeed")) parsed.scrollSpeed = Std.parseFloat(Std.string(Reflect.field(songData, "scrollSpeed")));
            else if (Reflect.hasField(songData, "speed")) parsed.scrollSpeed = Std.parseFloat(Std.string(Reflect.field(songData, "speed")));

            if (Reflect.hasField(songData, "player1")) parsed.player1 = Std.string(Reflect.field(songData, "player1"));
            if (Reflect.hasField(songData, "player2")) parsed.player2 = Std.string(Reflect.field(songData, "player2"));
            if (Reflect.hasField(songData, "gfVersion")) parsed.gfVersion = Std.string(Reflect.field(songData, "gfVersion"));
            if (Reflect.hasField(songData, "stage")) parsed.stage = Std.string(Reflect.field(songData, "stage"));
            if (Reflect.hasField(songData, "needsVoices")) parsed.needsVoices = Reflect.field(songData, "needsVoices") == true;

            parsed.chart = new Chart(parsed.bpm, parsed.scrollSpeed);

            var curBpm:Float = parsed.bpm;
            var runningTime:Float = 0.0;
            var totalSteps:Int = 0;

            // Handle legacy Psych array notes format...
            if (Reflect.hasField(songData, "notes") && songData.notes != null) {
                var sections:Array<Dynamic> = cast Reflect.field(songData, "notes");
                if (sections != null) {
                    for (sec in sections) {
                        if (sec == null) continue;
                        var mustHitSection:Bool = Reflect.hasField(sec, "mustHitSection") ? (sec.mustHitSection == true) : true;

                        if (Reflect.hasField(sec, "changeBPM") && sec.changeBPM == true && Reflect.hasField(sec, "bpm")) {
                            curBpm = Std.parseFloat(Std.string(sec.bpm));
                            parsed.chart.addEvent(runningTime, "BPM Change", Std.string(curBpm), "");
                            parsed.chart.addBpmChange(totalSteps, runningTime, curBpm);
                        }

                        if (Reflect.hasField(sec, "sectionNotes") && sec.sectionNotes != null) {
                            var rawNotes:Array<Dynamic> = cast sec.sectionNotes;
                            for (n in rawNotes) {
                                if (n != null && n.length >= 2) {
                                    var time:Float = Std.parseFloat(Std.string(n[0]));
                                    var rawData:Int = Std.parseInt(Std.string(n[1]));
                                    var susLen:Float = (n.length > 2 && n[2] != null) ? Std.parseFloat(Std.string(n[2])) : 0.0;
                                    var type:String = (n.length > 3 && n[3] != null && Std.string(n[3]).trim().length > 0) ? Std.string(n[3]) : "Default";

                                    var direction:Int = rawData % 4;
                                    var mustPress:Bool = (rawData < 4) ? mustHitSection : !mustHitSection;

                                    parsed.chart.addNote(time, direction, susLen, type, mustPress);
                                }
                            }
                        }

                        var lengthInSteps:Int = Reflect.hasField(sec, "lengthInSteps") ? Std.parseInt(Std.string(sec.lengthInSteps)) : 16;
                        var stepCrochet:Float = ((60.0 / curBpm) * 1000.0) / 4.0;
                        
                        runningTime += stepCrochet * lengthInSteps;
                        totalSteps += lengthInSteps;
                    }
                }
            }

            if (Reflect.hasField(songData, "events") && songData.events != null) {
                var rawEvents:Array<Dynamic> = cast Reflect.field(songData, "events");
                if (rawEvents != null) parseEventsArray(rawEvents, parsed.chart);
            }

            loadExternalEvents(songName, parsed.chart);

            parsed.chart.sortNotes();
            parsed.chart.sortEvents();
            return parsed;

        } catch (e:Dynamic) {
            Logger.error('Failed parsing legacy chart JSON: $e', "chart");
            return new Song(fallback, fallback);
        }
    }

    private static function parseEventsArray(rawEvents:Array<Dynamic>, chart:Chart):Void {
        for (e in rawEvents) {
            if (e == null) continue;
            if (Reflect.hasField(e, "time") && Reflect.hasField(e, "name")) {
                var time:Float = Std.parseFloat(Std.string(e.time));
                var name:String = Std.string(e.name);
                var params:Array<Dynamic> = Reflect.hasField(e, "params") ? cast e.params : [];
                var val1:String = (params.length > 0 && params[0] != null) ? Std.string(params[0]) : "";
                var val2:String = (params.length > 1 && params[1] != null) ? Std.string(params[1]) : "";
                chart.addEvent(time, name, val1, val2);
            } else if (e.length >= 2) {
                var time:Float = Std.parseFloat(Std.string(e[0]));
                var subEvents:Array<Dynamic> = cast e[1];
                if (subEvents != null) {
                    for (sub in subEvents) {
                        if (sub != null && sub.length >= 3) {
                            var eventName:String = Std.string(sub[0]);
                            var val1:String = (sub[1] != null) ? Std.string(sub[1]) : "";
                            var val2:String = (sub[2] != null) ? Std.string(sub[2]) : "";
                            chart.addEvent(time, eventName, val1, val2);
                        }
                    }
                }
            }
        }
    }

    private static function loadExternalEvents(songId:String, chart:Chart):Void {
        var clean = songId.toLowerCase().trim();
        var candidates = [
            'songs/$clean/events',
            'data/$clean/events',
            'assets/preload/songs/$clean/events'
        ];

        for (path in candidates) {
            var resolved = AssetResolver.resolveFile(path, [".soulchart", ".json", ""]);
            if (resolved != null) {
                try {
                    var raw = AssetResolver.getText(resolved);
                    // Check if the event file is a modern .soulchart xml
                    if (raw.trim().startsWith("<")) {
                        var xml = Xml.parse(raw);
                        var root = new Access(xml.firstElement());
                        for (node in root.elements) {
                            if (node.name.toLowerCase() == "event") {
                                chart.addEvent(XMSoul.getFloatAttr(node, "time", 0.0), XMSoul.getAttr(node, "name", ""), XMSoul.getAttr(node, "val1", ""), XMSoul.getAttr(node, "val2", ""));
                            }
                        }
                    } else {
                        var parsedJson = Json.parse(raw);
                        if (parsedJson != null && Reflect.hasField(parsedJson, "events")) {
                            var evList:Array<Dynamic> = cast Reflect.field(parsedJson, "events");
                            if (evList != null) parseEventsArray(evList, chart);
                        }
                    }
                } catch (e:Dynamic) {}
                break;
            }
        }
    }
}