package soulscorch.backend.utils.tools;

using StringTools;

/**
 * Custom string helper extensions for SoulScorch Engine.
 * Intended to be used via `using soulscorch.backend.utils.tools.StringTools;`
 */
class StringTools {
    /**
     * Formats song and asset IDs for disk paths (e.g. "Dad Battle (Remix)" -> "dad-battle-remix").
     */
    public static function formatSongPath(s:String):String {
        if (s == null) return "";
        var formatted = s.toLowerCase().trim();
        formatted = formatted.replace(" ", "-");
        var illegalChars = ["<", ">", ":", "\"", "/", "\\", "|", "?", "*", "(", ")", "'", "."];
        for (char in illegalChars) {
            formatted = formatted.replace(char, "");
        }
        return formatted;
    }

    /**
     * Safely parses a string to a Float, returning a fallback on invalid/empty values.
     */
    public static function forceFloat(s:String, defaultValue:Float = 0.0):Float {
        if (s == null || s.trim().length == 0) return defaultValue;
        var parsed = Std.parseFloat(s.trim());
        return Math.isNaN(parsed) ? defaultValue : parsed;
    }

    /**
     * Safely parses a string to an Int, returning a fallback on invalid/empty values.
     */
    public static function forceInt(s:String, defaultValue:Int = 0):Int {
        if (s == null || s.trim().length == 0) return defaultValue;
        var parsed = Std.parseInt(s.trim());
        return parsed == null ? defaultValue : parsed;
    }

    /**
     * Pads leading zeros to an integer or string (e.g. `combo.addZeros(3)` -> "005").
     */
    public static function addZeros(str:Dynamic, num:Int = 2):String {
        var s = Std.string(str);
        while (s.length < num) {
            s = "0" + s;
        }
        return s;
    }

    /**
     * Capitalizes the first letter of a string.
     */
    public static function capitalize(s:String):String {
        if (s == null || s.length == 0) return "";
        return s.charAt(0).toUpperCase() + s.substr(1);
    }
}