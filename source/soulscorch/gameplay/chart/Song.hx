package soulscorch.gameplay.chart;

import haxe.Json;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.ModLoader;

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
    public var title:String;
    public var bpm:Float = 140.0;
    public var difficulty:String = "normal";
    public var stage:String = "stage";
    public var scrollSpeed:Float = 2.0;

    public var player1:String = "bf";
    public var player2:String = "dad";
    public var gfVersion:String = "gf";

    public var chart:Chart;

    public function new(id:String, title:String) {
        this.id = id;
        this.title = title;
    }

    /**
     * Searches mod and base asset paths to deserialize a raw SwagSong structure.
     */
    public static function loadFromJson(songId:String, difficulty:String = "normal"):SwagSong {
        var diffName = (difficulty == null || difficulty.length == 0) ? "normal" : difficulty.toLowerCase().trim();
        var diffSuffix = (diffName == "normal") ? "" : '-$diffName';

        var pathsToTry = [
            'assets/songs/$songId/charts/$diffName.json',
            'assets/songs/$songId/charts/normal.json',
            'assets/songs/$songId/chart$diffSuffix.json',
            'assets/songs/$songId/$songId$diffSuffix.json',
            'assets/songs/$songId/chart.json',
            'assets/songs/$songId/$songId.json'
        ];

        var finalPath:String = null;
        for (p in pathsToTry) {
            var resolved = ModLoader.getPath(p);
            if (AssetResolver.exists(resolved)) {
                finalPath = resolved;
                break;
            }
        }

        if (finalPath == null) {
            Logger.warn('Chart JSON not found for "$songId" [$diffName]', "chart");
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