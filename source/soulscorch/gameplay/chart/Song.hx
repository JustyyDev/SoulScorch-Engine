package soulscorch.gameplay.chart;

import flixel.util.FlxColor;
import haxe.Json;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.utils.Logger;
import soulscorch.gameplay.chart.Chart;
import soulscorch.gameplay.chart.ChartParser;

using StringTools;

typedef SwagSection = {
    var sectionNotes:Array<Dynamic>;
    var mustHitSection:Bool;
    var ?bpm:Float;
    var ?changeBPM:Bool;
    var ?altAnim:Bool;
    var ?lengthInSteps:Int;
}

typedef SwagSong = {
    var song:String;
    var bpm:Float;
    var speed:Float;
    var player1:String;
    var player2:String;
    var gfVersion:String;
    var stage:String;
    var notes:Array<SwagSection>;
    var ?events:Array<Dynamic>;
    var ?needsVoices:Bool;
}

class Song {
    public var id:String;
    public var song:String;
    public var title:String;
    public var artist:String = "Unknown";
    public var charter:String = "Unknown";
    public var bpm:Float = 100.0;
    public var difficulty:String = "normal";
    public var scrollSpeed:Float = 1.0;
    public var stage:String = "stage";
    public var player1:String = "bf";
    public var player2:String = "dad";
    public var gfVersion:String = "gf";
    public var needsVoices:Bool = true;
    public var color:Null<FlxColor> = null;
    public var chart:Chart;

    public function new(id:String, title:String = "") {
        this.id = id;
        this.song = id;
        this.title = (title != null && title.length > 0) ? title : id;
        this.chart = new Chart();
    }

    public static function load(songId:String, difficulty:String = "normal"):Song {
            var cleanSong = (songId == null || songId.trim().length == 0) ? "tutorial" : songId.toLowerCase().trim();
            var diffName = (difficulty == null || difficulty.trim().length == 0) ? "normal" : difficulty.toLowerCase().trim();
            var diffSuffix = (diffName == "normal") ? "" : '-$diffName';

            // Updated paths checking for .soulchart first!
            var pathsToTry = [
                'songs/$cleanSong/charts/$diffName',
                'songs/$cleanSong/chart$diffSuffix',
                'songs/$cleanSong/$cleanSong$diffSuffix',
                'data/$cleanSong/$diffName'
            ];

            var finalPath:String = null;
            for (p in pathsToTry) {
                // Check for modern .soulchart first, then fallback to .json
                var resolved = AssetResolver.resolveFile(p, [".soulchart", ".json", ""]);
                if (resolved != null) {
                    finalPath = resolved;
                    break;
                }
            }

            if (finalPath == null) {
                Logger.warn('Chart file not found for "$cleanSong" [$diffName]', "chart");
                return new Song(cleanSong, cleanSong);
            }

            var rawText = AssetResolver.getText(finalPath);
            var songInstance = ChartParser.parse(rawText, cleanSong);
            songInstance.difficulty = diffName;
            return songInstance;
        }

    public static function loadFromJson(songId:String, difficulty:String = "normal"):Null<SwagSong> {
        var songObj = load(songId, difficulty);
        if (songObj == null) return null;

        return {
            song: songObj.song,
            bpm: songObj.bpm,
            speed: songObj.scrollSpeed,
            player1: songObj.player1,
            player2: songObj.player2,
            gfVersion: songObj.gfVersion,
            stage: songObj.stage,
            notes: [],
            events: songObj.chart != null ? cast songObj.chart.events : [],
            needsVoices: songObj.needsVoices
        };
    }
}