package soulscorch.backend.audio;

import flixel.FlxG;
import flixel.sound.FlxSound;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import openfl.media.Sound;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.utils.Logger;

#if SOULSCORCH_FMOD
import soulscorch.backend.audio.FmodAudioBackend;
#end

using StringTools;

class AudioManager {
    public var inst:FlxSound;
    public var vocals:FlxSound;
    public var opponentVocals:FlxSound;

    public var isLoaded:Bool = false;
    public var onSongComplete:Void->Void;

    public function new() {}

    #if SOULSCORCH_FMOD
    private inline function fmod():FmodAudioBackend {
        FmodAudioBackend.instance.onSongComplete = onSongComplete;
        return FmodAudioBackend.instance;
    }
    #end

    public function loadSong(songId:String):Bool {
        #if SOULSCORCH_FMOD
        if (fmod().loadSong(songId)) { isLoaded = true; return true; }
        return false;
        #else
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

        // Load Player / General Vocals
        var voiceSound = Paths.voices(cleanSong, "Player");
        if (voiceSound == null) voiceSound = Paths.voices(cleanSong);

        if (voiceSound != null) {
            vocals = new FlxSound().loadEmbedded(voiceSound);
            vocals.volume = 1.0;
            FlxG.sound.list.add(vocals);
        }

        // Load Opponent Vocals (if split)
        var oppVoiceSound = Paths.voices(cleanSong, "Opponent");
        if (oppVoiceSound != null && oppVoiceSound != voiceSound) {
            opponentVocals = new FlxSound().loadEmbedded(oppVoiceSound);
            opponentVocals.volume = 1.0;
            FlxG.sound.list.add(opponentVocals);
        }

        isLoaded = true;
        return true;
        #end
    }

    #if SOULSCORCH_FMOD
    public function loadVocalStem(path:String, isPlayer:Bool):Void {
        fmod().loadVocalStem(path, isPlayer);
    }
    #else
    public function loadVocalStem(path:String, isPlayer:Bool):Void {
        var soundObj:Sound = Paths.sound(path);

        if (soundObj == null) {
            var resolved = AssetResolver.resolveFile(path, [".ogg", ".mp3", ".wav"]);
            if (resolved != null) {
                #if sys
                soundObj = Sound.fromFile(resolved);
                #else
                soundObj = openfl.utils.Assets.getSound(resolved);
                #end
            }
        }

        if (soundObj != null) {
            if (isPlayer) {
                if (vocals != null && FlxG.sound.list != null) FlxG.sound.list.remove(vocals, true);
                vocals = new FlxSound().loadEmbedded(soundObj);
                vocals.volume = 1.0;
                FlxG.sound.list.add(vocals);
            } else {
                if (opponentVocals != null && FlxG.sound.list != null) FlxG.sound.list.remove(opponentVocals, true);
                opponentVocals = new FlxSound().loadEmbedded(soundObj);
                opponentVocals.volume = 1.0;
                FlxG.sound.list.add(opponentVocals);
            }
        }
    }
    #end

    #if SOULSCORCH_FMOD
    public function play():Void { fmod().play(); }
    public function pause():Void { fmod().pause(); }
    public function resume():Void { fmod().resume(); }
    public function stop():Void { fmod().stop(); }
    public function fadeOut(duration:Float = 0.5, ?onComplete:Void->Void):Void { fmod().fadeOut(duration, onComplete); }
    public function muteVocal(isPlayer:Bool, mute:Bool):Void { fmod().muteVocal(isPlayer, mute); }
    public function update(elapsed:Float):Void { fmod().update(elapsed); }
    #else
    public function play():Void {
        if (inst != null) {
            FlxTween.cancelTweensOf(inst);
            inst.volume = 1.0;
            inst.play();
        }
        if (vocals != null) {
            FlxTween.cancelTweensOf(vocals);
            vocals.volume = 1.0;
            vocals.play();
        }
        if (opponentVocals != null) {
            FlxTween.cancelTweensOf(opponentVocals);
            opponentVocals.volume = 1.0;
            opponentVocals.play();
        }
    }

    public function pause():Void {
        if (inst != null && inst.playing) inst.pause();
        if (vocals != null && vocals.playing) vocals.pause();
        if (opponentVocals != null && opponentVocals.playing) opponentVocals.pause();
    }

    public function resume():Void {
        if (inst != null) inst.resume();
        if (vocals != null) vocals.resume();
        if (opponentVocals != null) opponentVocals.resume();
        syncVocals();
    }

    public function stop():Void {
        cancelAudioTweens();
        if (inst != null) inst.stop();
        if (vocals != null) vocals.stop();
        if (opponentVocals != null) opponentVocals.stop();
    }

    public function fadeOut(duration:Float = 0.5, ?onComplete:Void->Void):Void {
        cancelAudioTweens();

        if (inst != null && inst.playing) {
            inst.fadeOut(duration, 0, function(_) {
                if (onComplete != null) onComplete();
            });
        }
        if (vocals != null && vocals.playing) {
            vocals.fadeOut(duration, 0);
        }
        if (opponentVocals != null && opponentVocals.playing) {
            opponentVocals.fadeOut(duration, 0);
        }
    }

    public function muteVocal(isPlayer:Bool, mute:Bool):Void {
        if (isPlayer) {
            if (vocals != null) {
                FlxTween.cancelTweensOf(vocals);
                vocals.volume = mute ? 0.0 : 1.0;
            }
        } else {
            if (opponentVocals != null) {
                FlxTween.cancelTweensOf(opponentVocals);
                opponentVocals.volume = mute ? 0.0 : 1.0;
            } else if (vocals != null) {
                FlxTween.cancelTweensOf(vocals);
                vocals.volume = mute ? 0.0 : 1.0;
            }
        }
    }

    public function syncVocals():Void {
        if (inst != null && inst.playing) {
            if (vocals != null && vocals.playing) {
                if (Math.abs(inst.time - vocals.time) > 20.0) {
                    vocals.time = inst.time;
                }
            }
            if (opponentVocals != null && opponentVocals.playing) {
                if (Math.abs(inst.time - opponentVocals.time) > 20.0) {
                    opponentVocals.time = inst.time;
                }
            }
        }
    }

    public function update(elapsed:Float):Void {
        syncVocals();
    }
    #end

    public function cancelAudioTweens():Void {
        if (inst != null) FlxTween.cancelTweensOf(inst);
        if (vocals != null) FlxTween.cancelTweensOf(vocals);
        if (opponentVocals != null) FlxTween.cancelTweensOf(opponentVocals);
    }

    public function clear():Void {
        #if SOULSCORCH_FMOD
        fmod().clear();
        #end
        cancelAudioTweens();

        if (inst != null) {
            inst.stop();
            if (FlxG.sound.list != null) FlxG.sound.list.remove(inst, true);
            inst.destroy();
            inst = null;
        }
        if (vocals != null) {
            vocals.stop();
            if (FlxG.sound.list != null) FlxG.sound.list.remove(vocals, true);
            vocals.destroy();
            vocals = null;
        }
        if (opponentVocals != null) {
            opponentVocals.stop();
            if (FlxG.sound.list != null) FlxG.sound.list.remove(opponentVocals, true);
            opponentVocals.destroy();
            opponentVocals = null;
        }
        isLoaded = false;
    }
}