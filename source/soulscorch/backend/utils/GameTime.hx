package soulscorch.backend.utils;

class GameTime {
    public static inline function now():Float {
        return Sys.time();
    }

    public static function formatTime(seconds:Float):String {
        var total = Math.floor(seconds);
        var minutes = Math.floor(total / 60);
        var secs = total % 60;
        var ms = Math.floor((seconds - total) * 1000);
        return '${pad(minutes)}:${pad(secs)}.${pad(ms, 3)}';
    }

    public static function formatClock(seconds:Float):String {
        var total = Math.floor(seconds);
        var minutes = Math.floor(total / 60);
        var secs = total % 60;
        return '${pad(minutes)}:${pad(secs)}';
    }

    public static inline function dateString():String {
        return Date.now().toString();
    }

    public static function pad(value:Int, ?len:Int = 2):String {
        var str = Std.string(value);
        while (str.length < len) str = "0" + str;
        return str;
    }
}