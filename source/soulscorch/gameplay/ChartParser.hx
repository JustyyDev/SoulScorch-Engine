package soulscorch.gameplay;

import haxe.Json;
import soulscorch.gameplay.Chart.BPMChangeEvent;

class ChartParser {
    public static function parse(rawJson:String):Song {
        var rawData:Dynamic = Json.parse(rawJson);
        var songData:Dynamic = Reflect.hasField(rawData, "song") ? rawData.song : rawData;

        var songId:String = songData.song != null ? songData.song : "tutorial";
        var song = new Song(songId, songId);
        song.bpm = songData.bpm != null ? songData.bpm : 100.0;
        song.scrollSpeed = songData.speed != null ? songData.speed : 2.0;
        song.player1 = songData.player1 != null ? songData.player1 : "bf";
        song.player2 = songData.player2 != null ? songData.player2 : "dad";
        song.gfVersion = songData.player3 != null ? songData.player3 : (songData.gfVersion != null ? songData.gfVersion : "gf");
        song.stage = songData.stage != null ? songData.stage : "stage";

        var chart = new Chart(song.bpm, song.scrollSpeed);

        if (songData.notes != null) {
            var sections:Array<Dynamic> = cast songData.notes;
            var curBPM:Float = song.bpm;
            var totalSteps:Int = 0;
            var totalTime:Float = 0.0;

            for (section in sections) {
                if (section.changeBPM != null && section.changeBPM == true && section.bpm != curBPM) {
                    curBPM = section.bpm;
                    chart.bpmChanges.push({
                        stepTime: totalSteps,
                        time: totalTime,
                        bpm: curBPM
                    });
                }

                if (section.sectionNotes != null) {
                    var sectionNotes:Array<Dynamic> = cast section.sectionNotes;
                    var mustHitSection:Bool = section.mustHitSection == true;

                    for (songNote in sectionNotes) {
                        var strumTime:Float = songNote[0];
                        var noteData:Int = Std.int(songNote[1]) % 4;
                        var susLength:Float = songNote.length > 2 ? songNote[2] : 0.0;
                        var noteType:String = songNote.length > 3 ? Std.string(songNote[3]) : "Default";

                        var isOpponentLane:Bool = songNote[1] >= 4;
                        var mustPress:Bool = mustHitSection ? !isOpponentLane : isOpponentLane;

                        chart.addNote(strumTime, noteData, susLength, noteType, mustPress);
                    }
                }

                totalSteps += 16;
                totalTime += (16 * ((60.0 / curBPM) * 1000.0) / 4.0);
            }
        }

        chart.notes.sort(function(a, b) return (a.strumTime < b.strumTime) ? -1 : (a.strumTime > b.strumTime) ? 1 : 0);
        song.chart = chart;
        return song;
    }
}