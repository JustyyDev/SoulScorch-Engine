package soulscorch.gameplay;

import haxe.Json;
import soulscorch.gameplay.Chart.NoteData;
import soulscorch.gameplay.Chart.BPMChangeEvent;

class ChartParser {
    public static function parseLegacy(rawJson:String):Dynamic {
        var data:Dynamic = Json.parse(rawJson);
        
        if (data.song != null && data.song.notes != null) {
            return convertPsychToSoulScorch(data.song);
        }
        
        return data;
    }

    private static function convertPsychToSoulScorch(legacySong:Dynamic):Dynamic {
        var modernData:Dynamic = {
            title: legacySong.song != null ? legacySong.song : "Unknown",
            bpm: legacySong.bpm,
            scrollSpeed: legacySong.speed,
            player1: legacySong.player1,
            player2: legacySong.player2,
            gfVersion: legacySong.player3 != null ? legacySong.player3 : "gf",
            notes: [],
            bpmChanges: [],
            svChanges: []
        };

        var legacySections:Array<Dynamic> = cast legacySong.notes;
        var curBPM:Float = legacySong.bpm;
        var totalSteps:Int = 0;
        var totalTime:Float = 0;

        for (section in legacySections) {
            if (section.changeBPM != null && section.changeBPM && section.bpm != curBPM) {
                curBPM = section.bpm;
                modernData.bpmChanges.push({
                    stepTime: totalSteps,
                    time: totalTime,
                    bpm: curBPM
                });
            }

            var sectionNotes:Array<Dynamic> = cast section.sectionNotes;
            var mustHitSection:Bool = section.mustHitSection;

            for (note in sectionNotes) {
                var time:Float = note[0];
                var dir:Int = Std.int(note[1] % 4);
                var sus:Float = note.length > 2 ? note[2] : 0;
                var type:String = note.length > 3 ? Std.string(note[3]) : "";
                
                var isOpponentNode:Bool = note[1] > 3;
                var mustPress:Bool = mustHitSection ? !isOpponentNode : isOpponentNode;

                modernData.notes.push({
                    time: time,
                    direction: dir,
                    sustainLength: sus,
                    type: type,
                    mustPress: mustPress
                });
            }

            totalSteps += 16;
            totalTime += (16 * ( (60 / curBPM) * 1000 ) / 4);
        }

        return modernData;
    }
}