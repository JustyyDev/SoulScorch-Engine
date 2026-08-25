package soulscorch.backend.audio;

import flixel.FlxG;
import soulscorch.backend.system.EventBus;

class AudioSpectrum {
    public static var bands:Array<Float> = [for (i in 0...16) 0.0];
    public static var bass(get, never):Float;
    public static var mid(get, never):Float;
    public static var treble(get, never):Float;

    public static function update():Void {
        var decayRate = (FlxG.sound.music != null && FlxG.sound.music.playing) ? 2.5 : 3.0;

        for (i in 0...bands.length) {
            bands[i] = Math.max(0.0, bands[i] - (FlxG.elapsed * decayRate));
        }

        try {
            var bus:Dynamic = EventBus;
            if (Reflect.hasField(bus, "publish")) {
                bus.publish("audio/spectrum", {bass: bass, mid: mid, treble: treble});
            } else if (Reflect.hasField(bus, "emit")) {
                bus.emit("audio/spectrum", {bass: bass, mid: mid, treble: treble});
            }
        } catch (e:Dynamic) {}
    }

    public static function feedBeat(intensity:Float = 1.0):Void {
        for (i in 0...bands.length) {
            var mult = 1.0 - (i / bands.length);
            bands[i] = Math.min(1.0, bands[i] + (intensity * mult));
        }
    }

    public static function setLevels(bassLevel:Float, midLevel:Float, trebleLevel:Float, elapsed:Float):Void {
        var lerp = Math.min(1.0, Math.max(0.0, elapsed * 18.0));
        for (i in 0...bands.length) {
            var target = i < 5 ? bassLevel : (i < 11 ? midLevel : trebleLevel);
            bands[i] += (Math.min(1.0, Math.max(0.0, target)) - bands[i]) * lerp;
        }
    }

    public static function reset():Void {
        for (i in 0...bands.length) bands[i] = 0.0;
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