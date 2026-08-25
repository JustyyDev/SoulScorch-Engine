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
    public var analysisEnabled(default, null):Bool = false;
    public var analyzer(default, null):AudioAnalyzer;

    private var _vocalSyncAccumulator:Float = 0.0;
    private static inline var VOCAL_SYNC_INTERVAL:Float = 0.035;
    private static inline var VOCAL_SYNC_THRESHOLD_MS:Float = 20.0;

    public function new() {}

    public function setAnalysisEnabled(enabled:Bool):Void {
        analysisEnabled = enabled;
        if (enabled && analyzer == null) analyzer = new AudioAnalyzer();
        if (!enabled) AudioSpectrum.reset();
    }

    private function updateAnalysis(elapsed:Float):Void {
        if (!analysisEnabled || analyzer == null) return;
        analyzer.update(elapsed);
        AudioSpectrum.setLevels(analyzer.bass, analyzer.mid, analyzer.treble, elapsed);
    }

    public function isPlaying():Bool {
        #if SOULSCORCH_FMOD
        return fmod().isPlaying();
        #else
        return inst != null && inst.playing;
        #end
    }

    public function getPosition():Float {
        #if SOULSCORCH_FMOD
        return fmod().getPosition();
        #else
        return inst != null ? inst.time : 0.0;
        #end
    }

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
        _vocalSyncAccumulator = 0.0;
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
                destroyChannel(vocals);
                vocals = new FlxSound().loadEmbedded(soundObj);
                vocals.volume = 1.0;
                FlxG.sound.list.add(vocals);
            } else {
                destroyChannel(opponentVocals);
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
    public function update(elapsed:Float):Void {
        fmod().update(elapsed);
        updateAnalysis(elapsed);
    }
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
                var target = mute ? 0.0 : 1.0;
                if (vocals.volume != target) {
                    FlxTween.cancelTweensOf(vocals);
                    vocals.volume = target;
                }
            }
        } else {
            if (opponentVocals != null) {
                var targetOpp = mute ? 0.0 : 1.0;
                if (opponentVocals.volume != targetOpp) {
                    FlxTween.cancelTweensOf(opponentVocals);
                    opponentVocals.volume = targetOpp;
                }
            } else if (vocals != null) {
                var targetFallback = mute ? 0.0 : 1.0;
                if (vocals.volume != targetFallback) {
                    FlxTween.cancelTweensOf(vocals);
                    vocals.volume = targetFallback;
                }
            }
        }
    }

    public function syncVocals():Void {
        if (inst == null || !inst.playing) return;

        var instTime = inst.time;
        if (vocals != null && vocals.playing) {
            if (Math.abs(instTime - vocals.time) > VOCAL_SYNC_THRESHOLD_MS) {
                vocals.time = instTime;
            }
        }
        if (opponentVocals != null && opponentVocals.playing) {
            if (Math.abs(instTime - opponentVocals.time) > VOCAL_SYNC_THRESHOLD_MS) {
                opponentVocals.time = instTime;
            }
        }
    }

    public function update(elapsed:Float):Void {
        _vocalSyncAccumulator += elapsed;
        if (_vocalSyncAccumulator >= VOCAL_SYNC_INTERVAL) {
            _vocalSyncAccumulator = 0.0;
            syncVocals();
        }
        updateAnalysis(elapsed);
    }
    #end

    public function cancelAudioTweens():Void {
        if (inst != null) FlxTween.cancelTweensOf(inst);
        if (vocals != null) FlxTween.cancelTweensOf(vocals);
        if (opponentVocals != null) FlxTween.cancelTweensOf(opponentVocals);
    }

    private function destroyChannel(channel:FlxSound):Void {
        if (channel == null) return;
        channel.stop();
        if (FlxG.sound.list != null) FlxG.sound.list.remove(channel, true);
        channel.destroy();
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
        _vocalSyncAccumulator = 0.0;
    }
}