package soulscorch.gameplay.song;

import flixel.util.FlxColor;

using StringTools;

class Difficulty {
    public static var defaultList:Array<String> = ["easy", "normal", "hard", "erect", "nightmare"];
    public static var list:Array<String> = ["easy", "normal", "hard", "erect", "nightmare"];

    public static inline function format(diff:String):String {
        if (diff == null || diff.trim().length == 0) return "NORMAL";
        var clean = diff.trim();
        return clean.substr(0, 1).toUpperCase() + clean.substr(1).toLowerCase();
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
            case "nightmare" | "hell" | "insane": 0xFF601070;
            case "mania" | "expert": 0xFF30D0FF;
            default: 0xFFFFFFFF;
        };
    }

    public static function getScrollSpeedMultiplier(diff:String):Float {
        var clean = (diff == null || diff.trim().length == 0) ? "normal" : diff.toLowerCase().trim();
        return switch (clean) {
            case "easy": 0.85;
            case "normal": 1.0;
            case "hard": 1.05;
            case "erect": 1.15;
            case "nightmare": 1.25;
            default: 1.0;
        };
    }

    public static function reset():Void {
        list = defaultList.copy();
    }

    public static function setList(customDiffs:Array<String>):Void {
        if (customDiffs != null && customDiffs.length > 0) {
            list = [];
            for (d in customDiffs) {
                if (d != null && d.trim().length > 0) list.push(d.toLowerCase().trim());
            }
        } else {
            reset();
        }
    }
}