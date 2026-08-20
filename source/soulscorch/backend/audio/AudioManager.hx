package soulscorch.backend.audio;

import flixel.FlxG;
import flixel.sound.FlxSound;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.utils.Logger;

using StringTools;

class AudioManager {
    public var inst:FlxSound;
    public var vocals:FlxSound;
    public var opponentVocals:FlxSound;

    public var isLoaded:Bool = false;
    public var onSongComplete:Void->Void;

    public function new() {}

    public function loadSong(songId:String):Bool {
        clear();

        var cleanSong = (songId != null && songId.trim().length > 0) ? songId.toLowerCase().trim() : "tutorial";
        var instSound = Paths.inst(cleanSong);

        if (instSound == null) {
            Logger.error('Could not find instrumental for song: $cleanSong', "audio");
            return false;
        }

        inst = new FlxSound().loadEmbedded(instSound);
        inst.volume = 1.0;
        inst.onComplete = function() {
            if (onSongComplete != null) onSongComplete();
        };
        FlxG.sound.list.add(inst);

        var voiceSound = Paths.voices(cleanSong);
        if (voiceSound != null) {
            vocals = new FlxSound().loadEmbedded(voiceSound);
            vocals.volume = 1.0;
            FlxG.sound.list.add(vocals);
        }

        isLoaded = true;
        return true;
    }

    public function play():Void {
        if (inst != null) {
            inst.volume = 1.0;
            inst.play();
        }
        if (vocals != null) {
            vocals.volume = 1.0;
            vocals.play();
        }
    }

    public function pause():Void {
        if (inst != null && inst.playing) inst.pause();
        if (vocals != null && vocals.playing) vocals.pause();
    }

    public function resume():Void {
        if (inst != null) inst.resume();
        if (vocals != null) vocals.resume();
    }

    public function stop():Void {
        if (inst != null) inst.stop();
        if (vocals != null) vocals.stop();
    }

    public function muteVocal(isPlayer:Bool, mute:Bool):Void {
        if (vocals != null) {
            vocals.volume = mute ? 0.0 : 1.0;
        }
    }

    public function update(elapsed:Float):Void {
        if (inst != null && vocals != null && inst.playing && vocals.playing) {
            if (Math.abs(inst.time - vocals.time) > 25.0) {
                vocals.time = inst.time;
            }
        }
    }

    public function clear():Void {
        if (inst != null) {
            inst.stop();
            FlxG.sound.list.remove(inst, true);
            inst.destroy();
            inst = null;
        }
        if (vocals != null) {
            vocals.stop();
            FlxG.sound.list.remove(vocals, true);
            vocals.destroy();
            vocals = null;
        }
        isLoaded = false;
    }
}