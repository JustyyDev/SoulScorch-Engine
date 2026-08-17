package soulscorch.gameplay.chart;

import haxe.Json;
import soulscorch.backend.utils.Logger;

class ChartParser {
    /**
     * Parses a raw JSON string into a structured Song object with processed chart notes and BPM events.
     */
    public static function parse(rawJson:String):Song {
        if (rawJson == null || rawJson.length == 0) {
            Logger.error("Cannot parse empty chart JSON", "chart");
            return new Song("unknown", "Unknown");
        }

        var rawData:Dynamic = Json.parse(rawJson);
        var songData:Dynamic = Reflect.hasField(rawData, "song") ? rawData.song : rawData;

        var songId:String = (songData.song != null) ? songData.song : "tutorial";
        var song = new Song(songId, songId);
        song.bpm = (songData.bpm != null) ? songData.bpm : 100.0;
        song.scrollSpeed = (songData.speed != null) ? songData.speed : 2.0;
        song.player1 = (songData.player1 != null) ? songData.player1 : "bf";
        song.player2 = (songData.player2 != null) ? songData.player2 : "dad";
        song.gfVersion = (songData.player3 != null) ? songData.player3 : ((songData.gfVersion != null) ? songData.gfVersion : "gf");
        song.stage = (songData.stage != null) ? songData.stage : "stage";

        var chart = new Chart(song.bpm, song.scrollSpeed);

        // 1. Parse standard section notes
        if (songData.notes != null) {
            var sections:Array<Dynamic> = cast songData.notes;
            var curBPM:Float = song.bpm;
            var totalSteps:Int = 0;
            var totalTime:Float = 0.0;

            for (section in sections) {
                if (section == null) continue;

                if (section.changeBPM != null && section.changeBPM == true && section.bpm != null && section.bpm != curBPM) {
                    curBPM = section.bpm;
                    chart.bpmChanges.push({
                        stepTime: totalSteps,
                        time: totalTime,
                        bpm: curBPM
                    });
                }

                if (section.sectionNotes != null) {
                    var sectionNotes:Array<Dynamic> = cast section.sectionNotes;
                    var mustHitSection:Bool = (section.mustHitSection == true);

                    for (songNote in sectionNotes) {
                        if (songNote == null || songNote.length < 2) continue;

                        var strumTime:Float = songNote[0];
                        var rawLane:Int = Std.int(songNote[1]);
                        var noteData:Int = rawLane % 4;
                        var susLength:Float = songNote.length > 2 ? Math.max(0, songNote[2]) : 0.0;
                        var noteType:String = songNote.length > 3 ? Std.string(songNote[3]) : "Default";

                        var isOpponentLane:Bool = rawLane >= 4;
                        var mustPress:Bool = mustHitSection ? !isOpponentLane : isOpponentLane;

                        chart.addNote(strumTime, noteData, susLength, noteType, mustPress);
                    }
                }

                var stepCount:Int = (section.lengthInSteps != null) ? section.lengthInSteps : 16;
                totalSteps += stepCount;
                totalTime += (stepCount * ((60.0 / curBPM) * 1000.0) / 4.0);
            }
        }

        // 2. Parse song event arrays (Psych / V-Slice event blocks)
        if (songData.events != null) {
            var rawEvents:Array<Dynamic> = cast songData.events;
            for (eventGroup in rawEvents) {
                if (eventGroup == null || eventGroup.length < 2) continue;
                var time:Float = eventGroup[0];
                var subEvents:Array<Dynamic> = cast eventGroup[1];
                for (sub in subEvents) {
                    if (sub == null || sub.length < 1) continue;
                    var name:String = Std.string(sub[0]);
                    var val1:String = sub.length > 1 ? Std.string(sub[1]) : "";
                    var val2:String = sub.length > 2 ? Std.string(sub[2]) : "";
                    chart.addEvent(time, name, val1, val2);
                }
            }
        }

        chart.sortNotes();
        chart.sortEvents();
        song.chart = chart;

        return song;
    }
}