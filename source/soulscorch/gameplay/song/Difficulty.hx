package soulscorch.gameplay.song;

import flixel.util.FlxColor;

using StringTools;

class Difficulty {
    public static var defaultList:Array<String> = ["easy", "normal", "hard", "erect", "nightmare"];

    public static inline function format(diff:String):String {
        if (diff == null || diff.trim().length == 0) return "NORMAL";
        return diff.toUpperCase().trim();
    }

    public static inline function getSuffix(diff:String):String {
        var clean = (diff == null || diff.trim().length == 0) ? "normal" : diff.toLowerCase().trim();
        return (clean == "normal") ? "" : '-$clean';
    }

    public static function getColor(diff:String):FlxColor {
        var clean = (diff == null || diff.trim().length == 0) ? "normal" : diff.toLowerCase().trim();
        return switch (clean) {
            case "easy": 0xFF55E055;
            case "normal": 0xFFE0E055;
            case "hard": 0xFFE04040;
            case "erect": 0xFFB030E0;
            case "nightmare": 0xFF101010;
            default: 0xFFFFFFFF;
        };
    }
}