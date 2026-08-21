package soulscorch.gameplay.song;

import flixel.util.FlxColor;

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
            folder: ""
        };
    }

    public static function getColor(meta:SongMetadata):FlxColor {
        if (meta.color == null || meta.color.length == 0) return 0xFF9900FF;
        var clean = StringTools.trim(meta.color);
        if (StringTools.startsWith(clean, "#")) {
            return FlxColor.fromString(clean);
        } else if (StringTools.startsWith(clean, "0x") || StringTools.startsWith(clean, "0X")) {
            var val = Std.parseInt(clean);
            return val != null ? val : 0xFF9900FF;
        }
        return FlxColor.fromString("#" + clean);
    }
}