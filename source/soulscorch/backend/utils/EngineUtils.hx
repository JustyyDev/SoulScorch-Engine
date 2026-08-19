package soulscorch.backend.utils;

import flixel.FlxG;
import flixel.math.FlxMath;
import openfl.system.System;

#if cpp
import cpp.vm.Gc;
#end

class EngineUtils {
    public static inline function clamp(value:Float, min:Float, max:Float):Float {
        return FlxMath.bound(value, min, max);
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
            try {
                sys.FileSystem.createDirectory(path);
            } catch (e:Dynamic) {}
        }
        #end
    }

    public static function getSystemMemoryMB():Float {
        #if cpp
        return Math.round((Gc.memInfo64(Gc.MEM_INFO_USAGE) / (1024 * 1024)) * 100) / 100;
        #else
        return Math.round((System.totalMemory / (1024 * 1024)) * 100) / 100;
        #end
    }

    public static inline function setFramerate(target:Int):Void {
        var validFps = Std.int(Math.max(30, target));
        FlxG.updateFramerate = validFps;
        FlxG.drawFramerate = validFps;
    }
}