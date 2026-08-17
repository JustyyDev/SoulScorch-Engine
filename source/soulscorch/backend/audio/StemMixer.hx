package soulscorch.backend.audio;

import flixel.sound.FlxSound;
import flixel.tweens.FlxTween;

class StemMixer {
    public var stems:Map<String, FlxSound> = new Map();

    public function new() {}

    public function registerStem(name:String, sound:FlxSound):Void {
        stems.set(name.toLowerCase().trim(), sound);
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
            FlxTween.tween(stem, {volume: targetVolume}, duration);
        }
    }

    public function mute(name:String):Void {
        setVolume(name, 0.0);
    }

    public function unmute(name:String):Void {
        setVolume(name, 1.0);
    }

    public function clear():Void {
        stems.clear();
    }
}