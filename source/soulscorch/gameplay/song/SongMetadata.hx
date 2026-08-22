package soulscorch.gameplay.song;

import flixel.util.FlxColor;

using StringTools;

typedef SongMetadata = {
    var title:String;
    var ?artist:String;
    var ?charter:String;
    var ?bpm:Float;
    var ?speed:Float;
    var ?stage:String;
    var ?player1:String;
    var ?player2:String;
    var ?gfVersion:String;
    var ?difficulties:Array<String>;
    var ?color:String;
    var ?freeplayIcon:String;
    var ?icon:String;
    var ?cutscene:String;
    var ?endCutscene:String;
    var ?needsVoices:Bool;
    var ?coopAllowed:Bool;
    var ?opponentModeAllowed:Bool;
    var ?previewStart:Float;
    var ?previewEnd:Float;
    var ?week:Int;
    var ?locked:Bool;
    var ?folder:String;
    var ?rating:Float;
    var ?keyCount:Int;
}

class SongMetadataHelper {
    public static function createDefault(title:String):SongMetadata {
        return {
            title: title,
            artist: "Unknown",
            charter: "Unknown",
            bpm: 100.0,
            speed: 1.0,
            stage: "stage",
            player1: "bf",
            player2: "dad",
            gfVersion: "gf",
            difficulties: ["Easy", "Normal", "Hard"],
            color: "#AF66CE",
            freeplayIcon: title.toLowerCase(),
            icon: title.toLowerCase(),
            cutscene: "",
            endCutscene: "",
            needsVoices: true,
            coopAllowed: false,
            opponentModeAllowed: false,
            previewStart: 0.0,
            previewEnd: 0.0,
            week: 1,
            locked: false,
            folder: "",
            rating: 1.0,
            keyCount: 4
        };
    }

    public static function getColor(meta:SongMetadata):FlxColor {
        if (meta == null || meta.color == null || meta.color.length == 0) return 0xFF9900FF;
        return parseColor(meta.color);
    }

    public static function parseColor(rawColor:String):FlxColor {
        if (rawColor == null) return 0xFF9900FF;
        var clean = rawColor.trim();
        if (clean.startsWith("#")) {
            return FlxColor.fromString(clean);
        } else if (clean.startsWith("0x") || clean.startsWith("0X")) {
            var val = Std.parseInt(clean);
            return val != null ? val : 0xFF9900FF;
        } else if (clean.contains(",")) {
            var parts = clean.split(",").map(function(s) return Std.parseInt(s.trim()));
            if (parts.length >= 3) {
                return FlxColor.fromRGB(parts[0], parts[1], parts[2], parts.length > 3 ? parts[3] : 255);
            }
        }
        return FlxColor.fromString("#" + clean);
    }
}