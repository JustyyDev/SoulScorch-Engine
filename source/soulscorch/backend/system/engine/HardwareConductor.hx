package soulscorch.backend.system.engine;

import flixel.FlxG;
import soulscorch.backend.audio.Conductor;

class HardwareConductor {
    public static var accurateTime(get, never):Float;
    private static var startTime:Float = 0.0;
    private static var isRunning:Bool = false;

    public static inline function get_accurateTime():Float {
        #if sys
        return Sys.time() * 1000.0;
        #else
        return openfl.Lib.getTimer();
        #end
    }

    public static function start():Void {
        startTime = accurateTime;
        isRunning = true;
    }

    public static function stop():Void {
        isRunning = false;
    }

    public static function getElapsedTime():Float {
        if (!isRunning) return 0.0;
        return accurateTime - startTime;
    }

    public static function update(audioPosition:Float, elapsed:Float):Void {
        if (Math.abs(Conductor.songPosition - audioPosition) > 20.0) {
            Conductor.songPosition = audioPosition;
        } else {
            Conductor.songPosition += elapsed * 1000.0 * Conductor.timeScale;
        }
    }
}