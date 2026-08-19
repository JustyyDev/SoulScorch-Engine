package soulscorch.backend.audio;

import flixel.sound.FlxSound;
import flixel.tweens.FlxTween;

class StemMixer {
    public var stems:Map<String, FlxSound> = new Map<String, FlxSound>();

    public function new() {}

    public function registerStem(name:String, sound:FlxSound):Void {
        if (name == null || sound == null) return;
        stems.set(name.toLowerCase().trim(), sound);
    }

    public function getStem(name:String):Null<FlxSound> {
        return stems.get(name.toLowerCase().trim());
    }

    public function setVolume(name:String, volume:Float):Void {
        var stem = stems.get(name.toLowerCase().trim());
        if (stem != null) {
            stem.volume = Math.max(0.0, Math.min(1.0, volume));
        }
    }

    public function fadeStem(name:String, targetVolume:Float, duration:Float):Void {
        var stem = stems.get(name.toLowerCase().trim());
        if (stem != null) {
            FlxTween.tween(stem, {volume: Math.max(0.0, Math.min(1.0, targetVolume))}, duration);
        }
    }

    public function syncAll(targetTime:Float, toleranceMs:Float = 25.0):Void {
        for (stem in stems) {
            if (stem != null && stem.playing && Math.abs(stem.time - targetTime) > toleranceMs) {
                stem.time = targetTime;
            }
        }
    }

    public function play():Void {
        for (stem in stems) {
            if (stem != null) stem.play();
        }
    }

    public function pause():Void {
        for (stem in stems) {
            if (stem != null) stem.pause();
        }
    }

    public function resume():Void {
        for (stem in stems) {
            if (stem != null) stem.resume();
        }
    }

    public function stop():Void {
        for (stem in stems) {
            if (stem != null) stem.stop();
        }
    }

    public function mute(name:String):Void {
        setVolume(name, 0.0);
    }

    public function unmute(name:String):Void {
        setVolume(name, 1.0);
    }

    public function clear():Void {
        stop();
        stems.clear();
    }
}