package soulscorch.backend.audio;

import flixel.FlxG;
import flixel.sound.FlxSound;

using StringTools;

class StemMixer {
    public var stems:Map<String, FlxSound> = new Map<String, FlxSound>();

    public function new() {}

    public function addStem(name:String, sound:FlxSound):Void {
        if (name == null || sound == null) return;
        var key = name.toLowerCase().trim();
        if (key.length == 0) return;
        var old = stems.get(key);
        if (old != null && old != sound) {
            old.stop();
            if (FlxG.sound.list != null) FlxG.sound.list.remove(old, true);
            old.destroy();
        }
        stems.set(key, sound);
    }

    public function getStem(name:String):Null<FlxSound> {
        if (name == null) return null;
        return stems.get(name.toLowerCase().trim());
    }

    public function setVolume(name:String, volume:Float):Void {
        if (name == null) return;
        var stem = stems.get(name.toLowerCase().trim());
        if (stem != null) {
            stem.volume = Math.max(0.0, Math.min(1.0, volume));
        }
    }

    public function muteStem(name:String, muted:Bool):Void {
        if (name == null) return;
        var stem = stems.get(name.toLowerCase().trim());
        if (stem != null) {
            stem.volume = muted ? 0.0 : 1.0;
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

    public function setTime(time:Float):Void {
        for (stem in stems) {
            if (stem != null) stem.time = time;
        }
    }

    public function clear():Void {
        for (stem in stems) {
            if (stem != null) {
                stem.stop();
                FlxG.sound.list.remove(stem, true);
                stem.destroy();
            }
        }
        stems.clear();
    }
}