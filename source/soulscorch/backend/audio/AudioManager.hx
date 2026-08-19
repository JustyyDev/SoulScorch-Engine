package soulscorch.backend.audio;

import flixel.FlxG;
import flixel.sound.FlxSound;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.audio.StemMixer;

class AudioManager {
    public var inst:FlxSound;
    public var vocals:FlxSound;
    public var opponentVocals:FlxSound;
    public var mixer:StemMixer;

    public var onSongComplete:Void->Void;
    public var isMutedVocalPlayer:Bool = false;
    public var isMutedVocalOpponent:Bool = false;

    public function new() {
        mixer = new StemMixer();
    }

    public function loadSong(songId:String):Void {
        clear();

        var instSound = Paths.inst(songId);
        if (instSound != null) {
            inst = new FlxSound().loadEmbedded(instSound);
            inst.onComplete = function() {
                if (onSongComplete != null) onSongComplete();
            };
            FlxG.sound.list.add(inst);
            mixer.registerStem("inst", inst);
        }

        var voiceSound = Paths.voices(songId);
        if (voiceSound != null) {
            vocals = new FlxSound().loadEmbedded(voiceSound);
            FlxG.sound.list.add(vocals);
            mixer.registerStem("vocals", vocals);
        }

        var oppVoiceSound = Paths.voices(songId + "-opponent");
        if (oppVoiceSound == null) oppVoiceSound = Paths.voices(songId + "-dad");

        if (oppVoiceSound != null) {
            opponentVocals = new FlxSound().loadEmbedded(oppVoiceSound);
            FlxG.sound.list.add(opponentVocals);
            mixer.registerStem("opponentVocals", opponentVocals);
        }
    }

    public function play():Void {
        mixer.play();
    }

    public function pause():Void {
        mixer.pause();
    }

    public function resume():Void {
        mixer.resume();
    }

    public function stop():Void {
        mixer.stop();
    }

    public function muteVocal(isPlayer:Bool, muted:Bool):Void {
        if (isPlayer) {
            isMutedVocalPlayer = muted;
            if (vocals != null) vocals.volume = muted ? 0.0 : 1.0;
        } else {
            isMutedVocalOpponent = muted;
            if (opponentVocals != null) opponentVocals.volume = muted ? 0.0 : 1.0;
        }
    }

    public function update(elapsed:Float):Void {
        if (inst != null && inst.playing) {
            mixer.syncAll(inst.time, 25.0);
        }
    }

    public function clear():Void {
        mixer.clear();

        if (inst != null) {
            FlxG.sound.list.remove(inst, true);
            inst.destroy();
            inst = null;
        }
        if (vocals != null) {
            FlxG.sound.list.remove(vocals, true);
            vocals.destroy();
            vocals = null;
        }
        if (opponentVocals != null) {
            FlxG.sound.list.remove(opponentVocals, true);
            opponentVocals.destroy();
            opponentVocals = null;
        }
    }
}