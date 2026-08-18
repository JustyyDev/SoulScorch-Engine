package soulscorch.backend.audio;

import flixel.FlxG;
import flixel.sound.FlxSound;
import openfl.media.Sound;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.utils.Logger;

using StringTools;

class AudioManager {
    public var inst:FlxSound;
    public var playerVocals:FlxSound;
    public var opponentVocals:FlxSound;

    public var isPlaying:Bool = false;
    public var onSongComplete:Void->Void;

    public function new() {
        inst = new FlxSound();
        playerVocals = new FlxSound();
        opponentVocals = new FlxSound();

        FlxG.sound.list.add(inst);
        FlxG.sound.list.add(playerVocals);
        FlxG.sound.list.add(opponentVocals);
    }

    public function loadSong(songId:String):Bool {
        clear();

        var clean = songId.toLowerCase().trim();
        var instSound = Paths.inst(clean);
        var voicesSound = Paths.voices(clean);

        if (instSound != null) {
            inst.loadEmbedded(instSound);
        } else {
            Logger.warn('Could not find Inst audio for: $clean', "audio");
        }

        if (voicesSound != null) {
            playerVocals.loadEmbedded(voicesSound);
        }

        var oppVoicesPathStr = 'assets/songs/$clean/Voices-Opponent.ogg';
        if (AssetResolver.exists(oppVoicesPathStr)) {
            var oppSound = AssetResolver.getSound(oppVoicesPathStr);
            if (oppSound != null) {
                opponentVocals.loadEmbedded(oppSound);
            }
        }

        inst.onComplete = function() {
            if (onSongComplete != null) onSongComplete();
        };

        return instSound != null;
    }

    public function play():Void {
        inst.play();
        @:privateAccess if (playerVocals._sound != null) playerVocals.play();
        @:privateAccess if (opponentVocals._sound != null) opponentVocals.play();
        isPlaying = true;
    }

    public function pause():Void {
        inst.pause();
        @:privateAccess if (playerVocals._sound != null) playerVocals.pause();
        @:privateAccess if (opponentVocals._sound != null) opponentVocals.pause();
        isPlaying = false;
    }

    public function resume():Void {
        inst.resume();
        @:privateAccess if (playerVocals._sound != null) playerVocals.resume();
        @:privateAccess if (opponentVocals._sound != null) opponentVocals.resume();
        isPlaying = true;
    }

    public function stop():Void {
        inst.stop();
        @:privateAccess if (playerVocals._sound != null) playerVocals.stop();
        @:privateAccess if (opponentVocals._sound != null) opponentVocals.stop();
        isPlaying = false;
    }

    public function setTime(timeMs:Float):Void {
        inst.time = timeMs;
        @:privateAccess if (playerVocals._sound != null) playerVocals.time = timeMs;
        @:privateAccess if (opponentVocals._sound != null) opponentVocals.time = timeMs;
    }

    public function muteVocal(isPlayer:Bool, mute:Bool):Void {
        @:privateAccess {
            if (isPlayer && playerVocals._sound != null) {
                playerVocals.volume = mute ? 0.0 : 1.0;
            } else if (!isPlayer && opponentVocals._sound != null) {
                opponentVocals.volume = mute ? 0.0 : 1.0;
            }
        }
    }

    public function update(elapsed:Float):Void {
        if (isPlaying && inst != null && inst.playing) {
            @:privateAccess {
                if (playerVocals._sound != null && Math.abs(inst.time - playerVocals.time) > 20) {
                    playerVocals.time = inst.time;
                }
                if (opponentVocals._sound != null && Math.abs(inst.time - opponentVocals.time) > 20) {
                    opponentVocals.time = inst.time;
                }
            }
        }
    }

    public function clear():Void {
        stop();
        inst.loadEmbedded(null);
        playerVocals.loadEmbedded(null);
        opponentVocals.loadEmbedded(null);
    }
}