package soulscorch.backend.audio;

import flixel.FlxG;
import flixel.system.FlxSound;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.utils.Logger;

class AudioManager {
    public var inst:FlxSound;
    public var vocals:FlxSound;
    public var opponentVocals:FlxSound;
    public var onSongComplete:Void->Void;

    public var isMutedVocalPlayer:Bool = false;
    public var isMutedVocalOpponent:Bool = false;

    public function new() {}

    public function loadSong(songId:String):Void {
        clear();

        var instSound = Paths.inst(songId);
        if (instSound != null) {
            inst = new FlxSound().loadEmbedded(instSound);
            inst.onComplete = function() {
                if (onSongComplete != null) onSongComplete();
            };
            FlxG.sound.list.add(inst);
        }

        var voiceSound = Paths.voices(songId);
        if (voiceSound != null) {
            vocals = new FlxSound().loadEmbedded(voiceSound);
            FlxG.sound.list.add(vocals);
        }

        var oppVoiceSound = Paths.voices(songId + "-opponent");
        if (oppVoiceSound != null) {
            opponentVocals = new FlxSound().loadEmbedded(oppVoiceSound);
            FlxG.sound.list.add(opponentVocals);
        }
    }

    public function play():Void {
        if (inst != null) inst.play();
        if (vocals != null) vocals.play();
        if (opponentVocals != null) opponentVocals.play();
    }

    public function pause():Void {
        if (inst != null) inst.pause();
        if (vocals != null) vocals.pause();
        if (opponentVocals != null) opponentVocals.pause();
    }

    public function resume():Void {
        if (inst != null) inst.resume();
        if (vocals != null) vocals.resume();
        if (opponentVocals != null) opponentVocals.resume();
    }

    public function stop():Void {
        if (inst != null) inst.stop();
        if (vocals != null) vocals.stop();
        if (opponentVocals != null) opponentVocals.stop();
    }

    public function muteVocal(isPlayer:Bool, muted:Bool):Void {
        if (isPlayer) {
            isMutedVocalPlayer = muted;
            if (vocals != null) {
                vocals.volume = Math.max(0.0, Math.min(1.0, muted ? 0.0 : 1.0));
            }
        } else {
            isMutedVocalOpponent = muted;
            if (opponentVocals != null) {
                opponentVocals.volume = Math.max(0.0, Math.min(1.0, muted ? 0.0 : 1.0));
            }
        }
    }

    public function update(elapsed:Float):Void {
        if (inst != null && inst.playing) {
            if (vocals != null && vocals.playing && Math.abs(inst.time - vocals.time) > 20) {
                vocals.time = inst.time;
            }
            if (opponentVocals != null && opponentVocals.playing && Math.abs(inst.time - opponentVocals.time) > 20) {
                opponentVocals.time = inst.time;
            }
        }
    }

    public function clear():Void {
        stop();
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