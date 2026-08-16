package soulscorch.utils;

import flixel.FlxG;
import openfl.system.System;

class EngineUtils {
    public static inline function clamp(value:Float, min:Float, max:Float):Float {
        if (value < min) return min;
        if (value > max) return max;
        return value;
    }

    public static inline function lerp(a:Float, b:Float, t:Float):Float {
        return a + (b - a) * t;
    }

    public static inline function formatMemoryMB(bytes:Float):String {
        var mb:Float = bytes / (1024 * 1024);
        return Std.string(Math.round(mb * 100) / 100) + " MB";
    }

    public static inline function formatFrameRate(fps:Int):String {
        return Std.string(fps) + " FPS";
    }

    public static function safeFileDirectory(path:String):Void {
        #if sys
        if (path != null && path.length > 0 && !sys.FileSystem.exists(path)) {
            sys.FileSystem.createDirectory(path);
        }
        #end
    }

    public static inline function getSystemMemoryMB():Float {
        #if cpp
        return Math.round((cpp.vm.Gc.memInfo64(cpp.vm.Gc.MEM_INFO_USAGE) / (1024 * 1024)) * 100) / 100;
        #else
        return Math.round((System.totalMemory / (1024 * 1024)) * 100) / 100;
        #end
    }

    public static inline function setFramerate(target:Int):Void {
        FlxG.updateFramerate = target;
        FlxG.drawFramerate = target;
    }
}
