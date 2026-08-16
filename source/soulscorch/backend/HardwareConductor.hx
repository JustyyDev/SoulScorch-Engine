package soulscorch.backend;

import flixel.sound.FlxSound;
import soulscorch.gameplay.Conductor;

class HardwareConductor {
    public var source:FlxSound;
    public var drift:Float = 0.0;
    public var smoothing:Float = 0.18;
    public var maxCorrection:Float = 35.0;
    public function new(?sound:FlxSound) source = sound;
    public function attach(sound:FlxSound):Void source = sound;
    public function update():Float {
        if (source == null) return Conductor.songPosition;
        var hardware:Float = source.time;
        var error:Float = hardware - Conductor.songPosition;
        drift = drift * (1.0 - smoothing) + error * smoothing;
        var correction:Float = Math.max(-maxCorrection, Math.min(maxCorrection, drift));
        Conductor.songPosition = hardware + correction;
        return Conductor.songPosition;
    }
    public function reset(position:Float = 0.0):Void { drift = 0.0; Conductor.songPosition = position; if (source != null) source.time = position; }
}
