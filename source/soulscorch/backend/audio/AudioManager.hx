package soulscorch.backend.audio;

import flixel.FlxG;
import flixel.sound.FlxSound;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.audio.StemMixer;

using StringTools;

class AudioManager {
    public var inst:FlxSound;
    public var vocals:FlxSound;
    public var opponentVocals:FlxSound;
    public var mixer:StemMixer;

    public var onSongComplete:Void->Void;
    public var isPlaying:Bool = false;

    public function new() {
        mixer = new StemMixer();
    }

    public function loadSong(songId:String):Void {
        clear();

        var instAsset = Paths.inst(songId);
        if (instAsset != null) {
            inst = new FlxSound().loadEmbedded(instAsset);
            inst.onComplete = function() {
                if (onSongComplete != null) onSongComplete();
            };
            FlxG.sound.list.add(inst);
            mixer.addStem("inst", inst);
        }

        var voicesAsset = Paths.voices(songId);
        if (voicesAsset != null) {
            vocals = new FlxSound().loadEmbedded(voicesAsset);
            FlxG.sound.list.add(vocals);
            mixer.addStem("voices", vocals);
        }

        var oppVoicesAsset = Paths.voices(songId + "-opponent");
        if (oppVoicesAsset != null) {
            opponentVocals = new FlxSound().loadEmbedded(oppVoicesAsset);
            FlxG.sound.list.add(opponentVocals);
            mixer.addStem("opponent_voices", opponentVocals);
        }
    }

    public function play():Void {
        isPlaying = true;
        mixer.play();
    }

    public function pause():Void {
        isPlaying = false;
        mixer.pause();
    }

    public function resume():Void {
        isPlaying = true;
        mixer.resume();
    }

    public function stop():Void {
        isPlaying = false;
        mixer.stop();
    }

    public function update(elapsed:Float):Void {
        if (isPlaying && inst != null && vocals != null) {
            if (Math.abs(inst.time - vocals.time) > 20) {
                vocals.time = inst.time;
            }
        }
    }

    public function muteVocal(isPlayer:Bool, muted:Bool):Void {
        if (isPlayer && vocals != null) {
            vocals.volume = muted ? 0.0 : 1.0;
        } else if (!isPlayer && opponentVocals != null) {
            opponentVocals.volume = muted ? 0.0 : 1.0;
        }
    }

    public function clear():Void {
        isPlaying = false;
        mixer.clear();
        inst = null;
        vocals = null;
        opponentVocals = null;
    }
}