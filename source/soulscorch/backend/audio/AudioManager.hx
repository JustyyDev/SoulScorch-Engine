package soulscorch.backend.audio;

import flixel.FlxG;
import flixel.sound.FlxSound;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.mod.ModLoader;

class AudioManager {
    public var inst:FlxSound;
    public var vocals:FlxSound;
    public var opponentVocals:FlxSound;

    public var isPlaying:Bool = false;
    public var onSongComplete:Void->Void;

    public function new() {
        inst = new FlxSound();
        vocals = new FlxSound();
        opponentVocals = new FlxSound();

        FlxG.sound.list.add(inst);
        FlxG.sound.list.add(vocals);
        FlxG.sound.list.add(opponentVocals);
    }

    public function loadSong(songId:String):Void {
        clear();

        var instPath = Paths.inst(songId);
        var voicesPath = Paths.voices(songId);
        var oppVoicesPath = Paths.sound('songs/$songId/Voices-Opponent');

        if (AssetResolver.exists(instPath)) {
            inst.loadEmbedded(instPath, false, false, onSongFinished);
        }

        if (AssetResolver.exists(voicesPath)) {
            vocals.loadEmbedded(voicesPath, false, false);
        }

        if (AssetResolver.exists(oppVoicesPath)) {
            opponentVocals.loadEmbedded(oppVoicesPath, false, false);
        }

        Logger.info('Loaded audio tracks for song: $songId', "audio");
    }

    public function play():Void {
        if (inst != null) inst.play();
        if (vocals != null && vocals.length > 0) vocals.play();
        if (opponentVocals != null && opponentVocals.length > 0) opponentVocals.play();
        isPlaying = true;
    }

    public function pause():Void {
        if (inst != null && inst.playing) inst.pause();
        if (vocals != null && vocals.playing) vocals.pause();
        if (opponentVocals != null && opponentVocals.playing) opponentVocals.pause();
        isPlaying = false;
    }

    public function resume():Void {
        if (inst != null) inst.resume();
        if (vocals != null && vocals.length > 0) vocals.resume();
        if (opponentVocals != null && opponentVocals.length > 0) opponentVocals.resume();
        resync();
        isPlaying = true;
    }

    public function stop():Void {
        if (inst != null) inst.stop();
        if (vocals != null) vocals.stop();
        if (opponentVocals != null) opponentVocals.stop();
        isPlaying = false;
    }

    public function setTime(time:Float):Void {
        if (inst != null) inst.time = time;
        if (vocals != null && vocals.length > 0) vocals.time = time;
        if (opponentVocals != null && opponentVocals.length > 0) opponentVocals.time = time;
        Conductor.songPosition = time;
    }

    public function resync():Void {
        if (inst != null && inst.playing) {
            if (vocals != null && vocals.length > 0 && Math.abs(vocals.time - inst.time) > 20) {
                vocals.time = inst.time;
            }
            if (opponentVocals != null && opponentVocals.length > 0 && Math.abs(opponentVocals.time - inst.time) > 20) {
                opponentVocals.time = inst.time;
            }
        }
    }

    public function update(elapsed:Float):Void {
        if (isPlaying && inst != null && inst.playing) {
            // Periodic sync check between stems
            if (vocals != null && vocals.playing && Math.abs(vocals.time - inst.time) > 25) {
                vocals.time = inst.time;
            }
        }
    }

    public function muteVocal(isPlayer:Bool, mute:Bool):Void {
        if (isPlayer && vocals != null) {
            vocals.volume = mute ? 0.0 : 1.0;
        } else if (!isPlayer && opponentVocals != null) {
            opponentVocals.volume = mute ? 0.0 : 1.0;
        }
    }

    private function onSongFinished():Void {
        isPlaying = false;
        if (onSongComplete != null) {
            onSongComplete();
        }
    }

    public function clear():Void {
        stop();
        if (inst != null) inst.destroy();
        if (vocals != null) vocals.destroy();
        if (opponentVocals != null) opponentVocals.destroy();
    }
}