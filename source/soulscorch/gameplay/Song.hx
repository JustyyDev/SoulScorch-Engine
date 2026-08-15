package soulscorch.gameplay;

import haxe.Json;
import soulscorch.assets.AssetResolver;
import soulscorch.modding.ModLoader;

typedef SwagSong = {
    var song:String;
    var bpm:Float;
    var speed:Float;
    var player1:String;
    var player2:String;
    var gfVersion:String;
    var stage:String;
    var notes:Array<SwagSection>;
}

typedef SwagSection = {
    var sectionNotes:Array<Dynamic>;
    var mustHitSection:Bool;
    var bpm:Null<Float>;
    var changeBPM:Null<Bool>;
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

    public static function loadFromJson(songId:String, difficulty:String = "normal"):SwagSong {
        var diffSuffix = (difficulty.toLowerCase() == "normal" || difficulty == "") ? "" : '-$difficulty';
        var chartPath = ModLoader.getPath('assets/songs/$songId/chart$diffSuffix.json');

        if (!AssetResolver.exists(chartPath)) {
            chartPath = ModLoader.getPath('assets/songs/$songId/$songId$diffSuffix.json');
        }

        if (!AssetResolver.exists(chartPath)) {
            Sys.println('[WARN] Chart JSON not found: $chartPath');
            return null;
        }

        var rawJson:Dynamic = Json.parse(AssetResolver.getText(chartPath));
        var songData:SwagSong = null;

        if (rawJson != null && Reflect.hasField(rawJson, "song") && Reflect.isObject(Reflect.field(rawJson, "song"))) {
            songData = cast Reflect.field(rawJson, "song");
        } else {
            songData = cast rawJson;
        }

        return songData;
    }
}