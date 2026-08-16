package soulscorch.gameplay;

import flixel.FlxG;
import flixel.sound.FlxSound;
import soulscorch.assets.AssetResolver;
import soulscorch.modding.ModLoader;

class AudioManager {
    public static inline var DRIFT_THRESHOLD_MS:Float = 20.0;

    public var inst:FlxSound;
    public var stems:Map<String, FlxSound> = new Map<String, FlxSound>();
    public var isPlaying:Bool = false;
    public var isPaused:Bool = false;

    public var time(get, set):Float;

    public function new() {}

    public function loadSong(songId:String, ?customStems:Array<String>):Void {
        clear();

        // Actual on-disk layout is assets/songs/{songId}/song/{Inst,Voices}.ogg
        var instPath = ModLoader.getPath('assets/songs/$songId/song/Inst.ogg');
        if (!AssetResolver.exists(instPath)) {
            instPath = ModLoader.getPath('assets/songs/$songId/Inst.ogg');
        }
        if (AssetResolver.exists(instPath)) {
            inst = FlxG.sound.load(instPath);
            inst.onComplete = onSongComplete;
        } else {
            Sys.println('[WARN] Missing Inst track: $instPath');
        }

        var defaultStemList = ["Voices", "Voices-Player", "Voices-Opponent"];
        if (customStems != null) {
            for (st in customStems) {
                if (!defaultStemList.contains(st)) defaultStemList.push(st);
            }
        }

        for (stemName in defaultStemList) {
            var stemPath = ModLoader.getPath('assets/songs/$songId/song/$stemName.ogg');
            if (!AssetResolver.exists(stemPath)) {
                stemPath = ModLoader.getPath('assets/songs/$songId/$stemName.ogg');
            }
            if (AssetResolver.exists(stemPath)) {
                var sound = FlxG.sound.load(stemPath);
                stems.set(stemName, sound);
            }
        }
    }

    public function play():Void {
        if (inst != null) inst.play();
        for (stem in stems) {
            stem.play();
        }
        isPlaying = true;
        isPaused = false;
    }

    public function pause():Void {
        if (inst != null) inst.pause();
        for (stem in stems) {
            stem.pause();
        }
        isPaused = true;
        isPlaying = false;
    }

    public function resume():Void {
        if (inst != null) inst.resume();
        for (stem in stems) {
            stem.resume();
        }
        resync();
        isPaused = false;
        isPlaying = true;
    }

    public function stop():Void {
        if (inst != null) inst.stop();
        for (stem in stems) {
            stem.stop();
        }
        isPlaying = false;
        isPaused = false;
    }

    public function update(elapsed:Float):Void {
        if (isPlaying && inst != null && inst.playing) {
            Conductor.songPosition = inst.time;

            // Prevent audio drift across stems
            for (name => stem in stems) {
                if (stem.playing) {
                    var diff = Math.abs(stem.time - inst.time);
                    if (diff > DRIFT_THRESHOLD_MS) {
                        stem.time = inst.time;
                    }
                }
            }
        }
    }

    public function setStemVolume(stemName:String, volume:Float):Void {
        if (stems.exists(stemName)) {
            stems.get(stemName).volume = Math.max(0.0, Math.min(1.0, volume));
        }
    }

    public function muteVocal(isPlayer:Bool, mute:Bool):Void {
        var targetStem = isPlayer ? "Voices-Player" : "Voices-Opponent";
        if (stems.exists(targetStem)) {
            stems.get(targetStem).volume = mute ? 0.0 : 1.0;
        } else if (stems.exists("Voices")) {
            stems.get("Voices").volume = mute ? 0.0 : 1.0;
        }
    }

    public function resync():Void {
        if (inst == null) return;
        var currentTime = inst.time;
        for (stem in stems) {
            stem.time = currentTime;
        }
        Conductor.songPosition = currentTime;
    }

    public dynamic function onSongComplete():Void {}

    public function clear():Void {
        stop();
        if (inst != null) {
            inst.destroy();
            inst = null;
        }
        for (stem in stems) {
            stem.destroy();
        }
        stems.clear();
    }

    inline function get_time():Float {
        return inst != null ? inst.time : 0.0;
    }

    inline function set_time(value:Float):Float {
        if (inst != null) inst.time = value;
        for (stem in stems) stem.time = value;
        return value;
    }
}