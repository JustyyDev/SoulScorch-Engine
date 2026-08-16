package soulscorch.media;

import flixel.FlxG;
import soulscorch.core.EventBus;

class AudioSpectrum {
    public static var bands:Array<Float> = [for (i in 0...16) 0.0];
    public static var bass(get, never):Float;
    public static var mid(get, never):Float;
    public static var treble(get, never):Float;

    public static function update():Void {
        if (FlxG.sound.music == null || !FlxG.sound.music.playing) {
            for (i in 0...bands.length) {
                bands[i] = Math.max(0.0, bands[i] - (FlxG.elapsed * 3.0));
            }
            return;
        }

        // Decay bands over time
        for (i in 0...bands.length) {
            bands[i] = Math.max(0.0, bands[i] - (FlxG.elapsed * 2.5));
        }

        EventBus.publish("audio/spectrum", {bass: bass, mid: mid, treble: treble});
    }

    public static function feedBeat(intensity:Float = 1.0):Void {
        for (i in 0...bands.length) {
            bands[i] = Math.min(1.0, bands[i] + (intensity * (1.0 - (i / bands.length))));
        }
    }

    static inline function get_bass():Float {
        return (bands[0] + bands[1] + bands[2]) / 3.0;
    }

    static inline function get_mid():Float {
        return (bands[5] + bands[6] + bands[7]) / 3.0;
    }

    static inline function get_treble():Float {
        return (bands[12] + bands[13] + bands[14]) / 3.0;
    }
}