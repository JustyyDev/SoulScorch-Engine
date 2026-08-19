package soulscorch.backend.utils;

class GameTime {
    public static inline function now():Float {
        #if sys
        return Sys.time();
        #else
        return Date.now().getTime() / 1000.0;
        #end
    }

    public static function formatTime(seconds:Float):String {
        var safeSecs = Math.max(0, seconds);
        var total = Math.floor(safeSecs);
        var minutes = Math.floor(total / 60);
        var secs = total % 60;
        var ms = Math.floor((safeSecs - total) * 1000);
        return '${pad(minutes)}:${pad(secs)}.${pad(ms, 3)}';
    }

    public static function formatClock(seconds:Float):String {
        var safeSecs = Math.max(0, seconds);
        var total = Math.floor(safeSecs);
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