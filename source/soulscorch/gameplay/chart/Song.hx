package soulscorch.gameplay.chart;

import flixel.util.FlxColor;
import haxe.Json;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.utils.Logger;
import soulscorch.gameplay.chart.Chart;
import soulscorch.scripting.mod.ModLoader;

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

    /**
     * Searches mod and base asset paths to deserialize a raw SwagSong structure.
     */
    public static function loadFromJson(songId:String, difficulty:String = "normal"):SwagSong {
        var cleanSong = (songId == null || songId.trim().length == 0) ? "tutorial" : songId.toLowerCase().trim();
        var diffName = (difficulty == null || difficulty.trim().length == 0) ? "normal" : difficulty.toLowerCase().trim();
        var diffSuffix = (diffName == "normal") ? "" : '-$diffName';

        var pathsToTry = [
            'assets/songs/$cleanSong/charts/$diffName.json',
            'assets/songs/$cleanSong/chart$diffSuffix.json',
            'assets/songs/$cleanSong/$cleanSong$diffSuffix.json',
            'assets/data/$cleanSong/$cleanSong$diffSuffix.json',
            'assets/data/$cleanSong/$diffName.json',
            'data/$cleanSong/$cleanSong$diffSuffix.json',
            'data/charts/$cleanSong/$diffName.json'
        ];

        if (diffName == "normal") {
            pathsToTry.push('assets/songs/$cleanSong/chart.json');
            pathsToTry.push('assets/songs/$cleanSong/$cleanSong.json');
            pathsToTry.push('assets/data/$cleanSong/$cleanSong.json');
            pathsToTry.push('data/$cleanSong/$cleanSong.json');
        }

        var finalPath:String = null;
        for (p in pathsToTry) {
            var resolved = ModLoader.getPath(p);
            if (AssetResolver.exists(resolved)) {
                finalPath = resolved;
                break;
            }
        }

        if (finalPath == null) {
            Logger.warn('Chart JSON not found for "$cleanSong" [$diffName]', "chart");
            return null;
        }

        try {
            var rawText = AssetResolver.getText(finalPath);
            var rawJson:Dynamic = Json.parse(rawText);
            var songData:SwagSong = null;

            if (rawJson != null && Reflect.hasField(rawJson, "song") && Reflect.isObject(Reflect.field(rawJson, "song"))) {
                songData = cast Reflect.field(rawJson, "song");
            } else {
                songData = cast rawJson;
            }

            return songData;
        } catch (e:Dynamic) {
            Logger.error('Failed to parse raw chart JSON ($finalPath): $e', "chart");
            return null;
        }
    }
}