package soulscorch.backend.system.engine;

import flixel.FlxG;
import flixel.math.FlxMath;
import soulscorch.backend.audio.Conductor;

class HardwareConductor {
    public static var accurateTime(get, never):Float;
    public static var rawTime(get, never):Float;
    public static var isRunning(default, null):Bool = false;
    public static var isPaused(default, null):Bool = false;

    public static var driftThreshold:Float = 20.0;
    public static var maxAllowedDrift:Float = 65.0;
    public static var driftCorrectionSpeed:Float = 0.12;

    private static var startTime:Float = 0.0;
    private static var pauseTime:Float = 0.0;
    private static var accumulatedOffset:Float = 0.0;
    private static var lastHardwareTime:Float = 0.0;

    public static inline function get_accurateTime():Float {
        #if sys
        return Sys.time() * 1000.0;
        #else
        return openfl.Lib.getTimer();
        #end
    }

    public static inline function get_rawTime():Float {
        #if sys
        return Sys.time();
        #else
        return openfl.Lib.getTimer() / 1000.0;
        #end
    }

    public static function start(initialSongPosition:Float = 0.0):Void {
        startTime = accurateTime - initialSongPosition;
        lastHardwareTime = accurateTime;
        accumulatedOffset = 0.0;
        isPaused = false;
        isRunning = true;
    }

    public static function pause():Void {
        if (!isRunning || isPaused) return;
        pauseTime = accurateTime;
        isPaused = true;
    }

    public static function resume():Void {
        if (!isRunning || !isPaused) return;
        var pauseDuration = accurateTime - pauseTime;
        startTime += pauseDuration;
        lastHardwareTime = accurateTime;
        isPaused = false;
    }

    public static function stop():Void {
        isRunning = false;
        isPaused = false;
        startTime = 0.0;
        pauseTime = 0.0;
        accumulatedOffset = 0.0;
    }

    public static function reset(newPosition:Float = 0.0):Void {
        startTime = accurateTime - newPosition;
        lastHardwareTime = accurateTime;
        accumulatedOffset = 0.0;
    }

    public static function getElapsedTime():Float {
        if (!isRunning) return 0.0;
        if (isPaused) return pauseTime - startTime;
        return accurateTime - startTime;
    }

    public static function update(audioPosition:Float, elapsed:Float):Void {
        if (!isRunning || isPaused) return;

        var currentHardwareTime = accurateTime;
        var hardwareDelta = currentHardwareTime - lastHardwareTime;
        lastHardwareTime = currentHardwareTime;

        var predictedPosition = Conductor.songPosition + hardwareDelta;
        var difference = audioPosition - predictedPosition;

        if (Math.abs(difference) > maxAllowedDrift) {
            Conductor.songPosition = audioPosition;
            startTime = accurateTime - audioPosition;
        } else if (Math.abs(difference) > driftThreshold) {
            Conductor.songPosition = FlxMath.lerp(predictedPosition, audioPosition, driftCorrectionSpeed);
        } else {
            Conductor.songPosition = predictedPosition;
        }
    }
}