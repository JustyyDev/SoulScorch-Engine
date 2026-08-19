package soulscorch.gameplay.chart;

import haxe.Json;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.utils.Logger;
import soulscorch.gameplay.chart.Chart;
import soulscorch.gameplay.chart.Song;

using StringTools;

class ChartParser {
    public static function parse(rawJson:String, ?songNameFallback:String = "tutorial"):Song {
        if (rawJson == null || rawJson.trim().length == 0) {
            return new Song(songNameFallback, songNameFallback);
        }

        try {
            var raw:Dynamic = Json.parse(rawJson);
            var songData:Dynamic = raw;

            if (raw != null && Reflect.hasField(raw, "song")) {
                var innerSong = Reflect.field(raw, "song");
                if (Reflect.isObject(innerSong)) {
                    songData = innerSong;
                }
            }

            var songName:String = Reflect.hasField(songData, "song") ? Std.string(Reflect.field(songData, "song")) : songNameFallback;
            var parsed = new Song(songName, songName);

            if (Reflect.hasField(songData, "bpm")) parsed.bpm = Std.parseFloat(Std.string(Reflect.field(songData, "bpm")));
            if (Reflect.hasField(songData, "speed")) parsed.scrollSpeed = Std.parseFloat(Std.string(Reflect.field(songData, "speed")));
            if (Reflect.hasField(songData, "player1")) parsed.player1 = Std.string(Reflect.field(songData, "player1"));
            if (Reflect.hasField(songData, "player2")) parsed.player2 = Std.string(Reflect.field(songData, "player2"));
            if (Reflect.hasField(songData, "gfVersion")) parsed.gfVersion = Std.string(Reflect.field(songData, "gfVersion"));
            if (Reflect.hasField(songData, "stage")) parsed.stage = Std.string(Reflect.field(songData, "stage"));
            if (Reflect.hasField(songData, "needsVoices")) parsed.needsVoices = Reflect.field(songData, "needsVoices") == true;

            parsed.chart = new Chart(parsed.bpm, parsed.scrollSpeed);

            var curBpm:Float = parsed.bpm;
            var runningTime:Float = 0.0;
            var totalSteps:Int = 0;

            // 1. Parse Notes, Sections & Legacy Section BPM Changes
            if (Reflect.hasField(songData, "notes") && songData.notes != null) {
                var sections:Array<Dynamic> = cast Reflect.field(songData, "notes");
                if (sections != null) {
                    for (sec in sections) {
                        if (sec == null) continue;
                        var mustHitSection:Bool = Reflect.hasField(sec, "mustHitSection") ? (sec.mustHitSection == true) : true;

                        // Section BPM Change conversion
                        if (Reflect.hasField(sec, "changeBPM") && sec.changeBPM == true && Reflect.hasField(sec, "bpm") && sec.bpm != null) {
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

            // 2. Parse Embedded Events (Psych / Codename / V-Slice format)
            if (Reflect.hasField(songData, "events") && songData.events != null) {
                var rawEvents:Array<Dynamic> = cast Reflect.field(songData, "events");
                if (rawEvents != null) {
                    parseEventsArray(rawEvents, parsed.chart);
                }
            }

            // 3. Look for External events.json file
            loadExternalEvents(songName, parsed.chart);

            parsed.chart.sortNotes();
            parsed.chart.sortEvents();

            return parsed;
        } catch (e:Dynamic) {
            Logger.error('Failed parsing chart JSON: $e', "chart");
            return new Song(songNameFallback, songNameFallback);
        }
    }

    private static function parseEventsArray(rawEvents:Array<Dynamic>, chart:Chart):Void {
        for (e in rawEvents) {
            if (e != null && e.length >= 2) {
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
            'assets/songs/$clean/events',
            'assets/data/$clean/events'
        ];

        for (path in candidates) {
            var resolved = AssetResolver.resolveFile(path, [".json", ""]);
            if (resolved != null) {
                try {
                    var raw = Json.parse(AssetResolver.getText(resolved));
                    if (raw != null && Reflect.hasField(raw, "events")) {
                        var evList:Array<Dynamic> = cast Reflect.field(raw, "events");
                        if (evList != null) parseEventsArray(evList, chart);
                    }
                } catch (e:Dynamic) {
                    Logger.warn('Failed parsing external events for $songId: $e', "chart");
                }
                break;
            }
        }
    }
}