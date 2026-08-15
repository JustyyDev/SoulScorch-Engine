package soulscorch.gameplay;

import haxe.Json;
import soulscorch.assets.AssetResolver;
import soulscorch.gameplay.Song.SongMetadata;

class SongLoader {
    static inline var SONG_ROOT:String = "assets/songs";

    public static function load(songId:String, difficulty:String = "normal"):Song {
        var metadataPath = '$SONG_ROOT/$songId/meta.json';
        var chartPath = '$SONG_ROOT/$songId/$difficulty.json';

        if (!AssetResolver.exists(chartPath)) {
            chartPath = '$SONG_ROOT/$songId/chart.json';
        }

        if (!AssetResolver.exists(chartPath)) {
            throw 'Chart file missing: $chartPath';
        }

        var metaRaw = AssetResolver.exists(metadataPath) ? AssetResolver.getText(metadataPath) : "{}";
        var chartRaw = AssetResolver.getText(chartPath);

        var metaData:Dynamic = Json.parse(metaRaw);
        var chartData:Dynamic = Json.parse(chartRaw);

        var song = new Song(songId, metaData.title != null ? metaData.title : songId);
        song.difficulty = difficulty;
        song.bpm = chartData.bpm != null ? chartData.bpm : (metaData.bpm != null ? metaData.bpm : 140.0);
        song.scrollSpeed = chartData.scrollSpeed != null ? chartData.scrollSpeed : (metaData.scrollSpeed != null ? metaData.scrollSpeed : 1.0);
        song.stage = metaData.stage != null ? metaData.stage : "stage";
        
        song.player1 = metaData.player1 != null ? metaData.player1 : "bf";
        song.player2 = metaData.player2 != null ? metaData.player2 : "dad";
        song.gfVersion = metaData.gfVersion != null ? metaData.gfVersion : "gf";

        song.chart.bpm = song.bpm;

        if (chartData.notes != null) {
            var noteArray:Array<Dynamic> = cast chartData.notes;
            for (note in noteArray) {
                var time:Float = note.time != null ? note.time : 0.0;
                var dir:Int = note.direction != null ? note.direction : 0;
                var sus:Float = note.sustainLength != null ? note.sustainLength : 0.0;
                var mustPress:Bool = note.mustPress != null ? note.mustPress : true;
                var type:String = note.type != null ? note.type : "";

                song.chart.addNote(time, dir, sus, type, mustPress);
            }
        }

        if (chartData.bpmChanges != null) {
            var bpmArray:Array<Dynamic> = cast chartData.bpmChanges;
            for (change in bpmArray) {
                song.chart.bpmChanges.push({
                    stepTime: change.stepTime != null ? change.stepTime : 0,
                    time: change.time != null ? change.time : 0.0,
                    bpm: change.bpm != null ? change.bpm : song.bpm
                });
            }
        }

        song.chart.notes.sort(function(a, b) {
            return (a.time < b.time) ? -1 : (a.time > b.time) ? 1 : 0;
        });

        return song;
    }
}