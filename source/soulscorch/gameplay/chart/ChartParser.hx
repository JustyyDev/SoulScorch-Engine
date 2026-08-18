package soulscorch.gameplay.chart;

import haxe.Json;
import soulscorch.backend.utils.Logger;
import soulscorch.gameplay.chart.Chart;
import soulscorch.gameplay.chart.Song;

using StringTools;

class ChartParser {
    public static function parse(rawJson:String):Song {
        if (rawJson == null || rawJson.trim().length == 0) {
            return new Song("tutorial", "Tutorial");
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

            var songName:String = Reflect.hasField(songData, "song") ? Reflect.field(songData, "song") : "tutorial";
            var parsed = new Song(songName, songName);

            if (Reflect.hasField(songData, "bpm")) parsed.bpm = Reflect.field(songData, "bpm");
            if (Reflect.hasField(songData, "speed")) parsed.scrollSpeed = Reflect.field(songData, "speed");
            if (Reflect.hasField(songData, "player1")) parsed.player1 = Reflect.field(songData, "player1");
            if (Reflect.hasField(songData, "player2")) parsed.player2 = Reflect.field(songData, "player2");
            if (Reflect.hasField(songData, "gfVersion")) parsed.gfVersion = Reflect.field(songData, "gfVersion");
            if (Reflect.hasField(songData, "stage")) parsed.stage = Reflect.field(songData, "stage");
            if (Reflect.hasField(songData, "needsVoices")) parsed.needsVoices = Reflect.field(songData, "needsVoices");

            parsed.chart = new Chart(parsed.bpm, parsed.scrollSpeed);

            // 1. Parse Notes
            if (Reflect.hasField(songData, "notes") && songData.notes != null) {
                var sections:Array<Dynamic> = cast Reflect.field(songData, "notes");
                if (sections != null) {
                    for (sec in sections) {
                        if (sec == null) continue;
                        var mustHitSection:Bool = Reflect.hasField(sec, "mustHitSection") ? sec.mustHitSection : true;

                        if (Reflect.hasField(sec, "sectionNotes") && sec.sectionNotes != null) {
                            var rawNotes:Array<Dynamic> = cast sec.sectionNotes;
                            for (n in rawNotes) {
                                if (n != null && n.length >= 2) {
                                    var time:Float = n[0];
                                    var rawData:Int = Std.int(n[1]);
                                    var susLen:Float = (n.length > 2) ? n[2] : 0.0;
                                    var type:String = (n.length > 3 && n[3] != null) ? Std.string(n[3]) : "default";

                                    var direction:Int = rawData % 4;
                                    var mustPress:Bool = (rawData < 4) ? mustHitSection : !mustHitSection;

                                    // Corrected parameter order: (time, direction, susLen, type, mustPress)
                                    parsed.chart.addNote(time, direction, susLen, type, mustPress);
                                }
                            }
                        }
                    }
                }
            }

            // 2. Parse Events
            if (Reflect.hasField(songData, "events") && songData.events != null) {
                var rawEvents:Array<Dynamic> = cast Reflect.field(songData, "events");
                if (rawEvents != null) {
                    for (e in rawEvents) {
                        if (e != null && e.length >= 2) {
                            var time:Float = e[0];
                            var subEvents:Array<Dynamic> = cast e[1];
                            if (subEvents != null) {
                                for (sub in subEvents) {
                                    if (sub != null && sub.length >= 3) {
                                        var eventName:String = Std.string(sub[0]);
                                        var val1:String = Std.string(sub[1]);
                                        var val2:String = Std.string(sub[2]);
                                        parsed.chart.addEvent(time, eventName, val1, val2);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            return parsed;
        } catch (e:Dynamic) {
            Logger.error('Failed parsing chart JSON: $e', "chart");
            return new Song("tutorial", "Tutorial");
        }
    }
}