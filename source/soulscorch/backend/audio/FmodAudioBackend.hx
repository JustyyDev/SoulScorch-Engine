package soulscorch.backend.audio;

import flixel.FlxG;
import flixel.sound.FlxSound;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import openfl.media.Sound;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.utils.Logger;

using StringTools;

/**
 * Optional FMOD-backed audio engine.
 *
 * Enabled only when the `SOULSCORCH_FMOD` haxedef is set (and the `linc_fmod`
 * haxelib is installed). When disabled, every method is a no-op so the rest of
 * the engine keeps using the default OpenFL/Flixel audio path untouched.
 *
 * This wrapper mirrors the subset of `AudioManager` that the gameplay loop
 * relies on (load/play/pause/resume/stop/fade/volume/sync) so it can be
 * swapped in behind the same call sites.
 */
class FmodAudioBackend {
    public static var instance:FmodAudioBackend = new FmodAudioBackend();

    public var isLoaded:Bool = false;
    public var onSongComplete:Void->Void;

    // Fallback FlxSound channels used when FMOD is unavailable at runtime.
    private var inst:FlxSound;
    private var vocals:FlxSound;
    private var opponentVocals:FlxSound;

    #if SOULSCORCH_FMOD
    // Real FMOD handles. Types come from linc_fmod.
    private var fmodSystem:Dynamic;
    private var instChannel:Dynamic;
    private var vocalChannel:Dynamic;
    private var oppChannel:Dynamic;
    private var instSound:Dynamic;
    private var vocalSound:Dynamic;
    private var oppSound:Dynamic;
    private var fmodReady:Bool = false;
    private var playbackStarted:Bool = false;
    private var completionDispatched:Bool = false;
    #end

    public function new() {
        instance = this;
        #if SOULSCORCH_FMOD
        initFmod();
        #end
    }

    #if SOULSCORCH_FMOD
    private function initFmod():Void {
        try {
            var FMOD = Type.resolveClass("fm.fmod.FMOD");
            if (FMOD == null) {
                Logger.warn("[FMOD] linc_fmod not found at runtime, falling back to FlxSound.", "audio");
                return;
            }
            fmodSystem = Reflect.callMethod(FMOD, Reflect.field(FMOD, "init"), [64, 0, null]);
            fmodReady = (fmodSystem != null);
            if (fmodReady) Logger.info("[FMOD] System initialized.", "audio");
        } catch (e:Dynamic) {
            Logger.error('[FMOD] Failed to initialize: $e', "audio");
            fmodReady = false;
        }
    }

    private function createSoundFromPath(path:String):Dynamic {
        if (fmodSystem == null) return null;
        var resolved = AssetResolver.resolveFile(path, [".ogg", ".mp3", ".wav", ""]);
        if (resolved == null) return null;
        try {
            return Reflect.callMethod(fmodSystem, Reflect.field(fmodSystem, "createSound"), [resolved, 0, null]);
        } catch (e:Dynamic) {
            Logger.error('[FMOD] createSound failed for $resolved: $e', "audio");
            return null;
        }
    }

    private function playSoundOn(sound:Dynamic, paused:Bool = true):Dynamic {
        if (fmodSystem == null || sound == null) return null;
        try {
            return Reflect.callMethod(fmodSystem, Reflect.field(fmodSystem, "playSound"), [sound, null, paused]);
        } catch (e:Dynamic) {
            return null;
        }
    }

    private function getChannelPosition(channel:Dynamic):Float {
        if (channel == null) return 0.0;
        var method = Reflect.field(channel, "getPosition");
        if (method == null) return 0.0;
        try return Reflect.callMethod(channel, method, []) catch (_:Dynamic) return 0.0;
    }

    private function setChannelPosition(channel:Dynamic, position:Float):Void {
        if (channel == null) return;
        var method = Reflect.field(channel, "setPosition");
        if (method != null) {
            try Reflect.callMethod(channel, method, [Std.int(Math.max(0.0, position))]) catch (_:Dynamic) {}
        }
    }

    private function isChannelPlaying(channel:Dynamic):Bool {
        if (channel == null) return false;
        var method = Reflect.field(channel, "isPlaying");
        if (method == null) return false;
        try return Reflect.callMethod(channel, method, []) == true catch (_:Dynamic) return false;
    }

    private function releaseSound(sound:Dynamic):Void {
        if (sound == null) return;
        var method = Reflect.field(sound, "release");
        if (method != null) {
            try Reflect.callMethod(sound, method, []) catch (_:Dynamic) {}
        }
    }
    #end

    public function isPlaying():Bool {
        #if SOULSCORCH_FMOD
        if (fmodReady) return isChannelPlaying(instChannel);
        #end
        return inst != null && inst.playing;
    }

    public function getPosition():Float {
        #if SOULSCORCH_FMOD
        if (fmodReady) return getChannelPosition(instChannel);
        #end
        return inst != null ? inst.time : 0.0;
    }

    public function loadSong(songId:String):Bool {
        #if SOULSCORCH_FMOD
        if (fmodReady) {
            clear();
            var cleanSong = (songId != null && songId.trim().length > 0) ? songId.toLowerCase().trim() : "tutorial";
            instSound = createSoundFromPath('songs/$cleanSong/song/Inst');
            if (instSound == null) instSound = createSoundFromPath('songs/$cleanSong/Inst');
            if (instSound == null) {
                Logger.error('[FMOD] Could not find instrumental for song: $cleanSong', "audio");
                return false;
            }
            instChannel = playSoundOn(instSound);
            var voiceSound = createSoundFromPath('songs/$cleanSong/song/Voices');
            if (voiceSound != null) {
                vocalSound = voiceSound;
                vocalChannel = playSoundOn(vocalSound);
            }
            var oppSoundPath = createSoundFromPath('songs/$cleanSong/song/Voices-Opponent');
            if (oppSoundPath != null) {
                oppSound = oppSoundPath;
                oppChannel = playSoundOn(oppSound);
            }
            isLoaded = true;
            playbackStarted = false;
            completionDispatched = false;
            return true;
        }
        #end

        clear();

        var cleanSong = (songId != null && songId.trim().length > 0) ? songId.toLowerCase().trim() : "tutorial";
        var instSound = Paths.inst(cleanSong);

        if (instSound == null) {
            Logger.error('[FMOD] Could not find instrumental for song: $cleanSong', "audio");
            return false;
        }

        inst = new FlxSound().loadEmbedded(instSound);
        inst.volume = 1.0;
        inst.onComplete = function() {
            if (onSongComplete != null) onSongComplete();
        };
        FlxG.sound.list.add(inst);

        var voiceSound = Paths.voices(cleanSong, "Player");
        if (voiceSound == null) voiceSound = Paths.voices(cleanSong);

        if (voiceSound != null) {
            vocals = new FlxSound().loadEmbedded(voiceSound);
            vocals.volume = 1.0;
            FlxG.sound.list.add(vocals);
        }

        var oppVoiceSound = Paths.voices(cleanSong, "Opponent");
        if (oppVoiceSound != null && oppVoiceSound != voiceSound) {
            opponentVocals = new FlxSound().loadEmbedded(oppVoiceSound);
            opponentVocals.volume = 1.0;
            FlxG.sound.list.add(opponentVocals);
        }

        isLoaded = true;
        return true;
    }

    public function loadVocalStem(path:String, isPlayer:Bool):Void {
        #if SOULSCORCH_FMOD
        if (fmodReady) {
            var s = createSoundFromPath(path);
            if (s == null) return;
            if (isPlayer) {
                vocalSound = s;
                vocalChannel = playSoundOn(s);
                if (playbackStarted && vocalChannel != null) Reflect.callMethod(vocalChannel, Reflect.field(vocalChannel, "start"), []);
            } else {
                oppSound = s;
                oppChannel = playSoundOn(s);
                if (playbackStarted && oppChannel != null) Reflect.callMethod(oppChannel, Reflect.field(oppChannel, "start"), []);
            }
            return;
        }
        #end

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
        if (soundObj == null) return;

        var ch = new FlxSound().loadEmbedded(soundObj);
        ch.volume = 1.0;
        FlxG.sound.list.add(ch);
        if (isPlayer) {
            if (vocals != null) FlxG.sound.list.remove(vocals, true);
            vocals = ch;
        } else {
            if (opponentVocals != null) FlxG.sound.list.remove(opponentVocals, true);
            opponentVocals = ch;
        }
    }

    public function play():Void {
        #if SOULSCORCH_FMOD
        if (fmodReady) {
            if (instChannel != null) Reflect.callMethod(instChannel, Reflect.field(instChannel, "start"), []);
            if (vocalChannel != null) Reflect.callMethod(vocalChannel, Reflect.field(vocalChannel, "start"), []);
            if (oppChannel != null) Reflect.callMethod(oppChannel, Reflect.field(oppChannel, "start"), []);
            playbackStarted = true;
            completionDispatched = false;
            return;
        }
        #end
        if (inst != null) { FlxTween.cancelTweensOf(inst); inst.volume = 1.0; inst.play(); }
        if (vocals != null) { FlxTween.cancelTweensOf(vocals); vocals.volume = 1.0; vocals.play(); }
        if (opponentVocals != null) { FlxTween.cancelTweensOf(opponentVocals); opponentVocals.volume = 1.0; opponentVocals.play(); }
    }

    public function pause():Void {
        #if SOULSCORCH_FMOD
        if (fmodReady) {
            if (instChannel != null) Reflect.callMethod(instChannel, Reflect.field(instChannel, "setPaused"), [true]);
            if (vocalChannel != null) Reflect.callMethod(vocalChannel, Reflect.field(vocalChannel, "setPaused"), [true]);
            if (oppChannel != null) Reflect.callMethod(oppChannel, Reflect.field(oppChannel, "setPaused"), [true]);
            return;
        }
        #end
        if (inst != null && inst.playing) inst.pause();
        if (vocals != null && vocals.playing) vocals.pause();
        if (opponentVocals != null && opponentVocals.playing) opponentVocals.pause();
    }

    public function resume():Void {
        #if SOULSCORCH_FMOD
        if (fmodReady) {
            if (instChannel != null) Reflect.callMethod(instChannel, Reflect.field(instChannel, "setPaused"), [false]);
            if (vocalChannel != null) Reflect.callMethod(vocalChannel, Reflect.field(vocalChannel, "setPaused"), [false]);
            if (oppChannel != null) Reflect.callMethod(oppChannel, Reflect.field(oppChannel, "setPaused"), [false]);
            syncVocals();
            return;
        }
        #end
        if (inst != null) inst.resume();
        if (vocals != null) vocals.resume();
        if (opponentVocals != null) opponentVocals.resume();
        syncVocals();
    }

    public function stop():Void {
        #if SOULSCORCH_FMOD
        if (fmodReady) {
            if (instChannel != null) Reflect.callMethod(instChannel, Reflect.field(instChannel, "stop"), []);
            if (vocalChannel != null) Reflect.callMethod(vocalChannel, Reflect.field(vocalChannel, "stop"), []);
            if (oppChannel != null) Reflect.callMethod(oppChannel, Reflect.field(oppChannel, "stop"), []);
            playbackStarted = false;
            return;
        }
        #end
        cancelAudioTweens();
        if (inst != null) inst.stop();
        if (vocals != null) vocals.stop();
        if (opponentVocals != null) opponentVocals.stop();
    }

    public function fadeOut(duration:Float = 0.5, ?onComplete:Void->Void):Void {
        #if SOULSCORCH_FMOD
        if (fmodReady) {
            if (instChannel != null) Reflect.callMethod(instChannel, Reflect.field(instChannel, "setVolume"), [0.0]);
            if (vocalChannel != null) Reflect.callMethod(vocalChannel, Reflect.field(vocalChannel, "setVolume"), [0.0]);
            if (oppChannel != null) Reflect.callMethod(oppChannel, Reflect.field(oppChannel, "setVolume"), [0.0]);
            if (onComplete != null) onComplete();
            return;
        }
        #end
        cancelAudioTweens();
        if (inst != null && inst.playing) {
            inst.fadeOut(duration, 0, function(_) { if (onComplete != null) onComplete(); });
        }
        if (vocals != null && vocals.playing) vocals.fadeOut(duration, 0);
        if (opponentVocals != null && opponentVocals.playing) opponentVocals.fadeOut(duration, 0);
    }

    public function muteVocal(isPlayer:Bool, mute:Bool):Void {
        #if SOULSCORCH_FMOD
        if (fmodReady) {
            var ch = isPlayer ? vocalChannel : (oppChannel != null ? oppChannel : vocalChannel);
            if (ch != null) Reflect.callMethod(ch, Reflect.field(ch, "setVolume"), [mute ? 0.0 : 1.0]);
            return;
        }
        #end
        var target = isPlayer ? vocals : (opponentVocals != null ? opponentVocals : vocals);
        if (target != null) {
            FlxTween.cancelTweensOf(target);
            target.volume = mute ? 0.0 : 1.0;
        }
    }

    public function syncVocals():Void {
        #if SOULSCORCH_FMOD
        if (fmodReady) {
            var position = getChannelPosition(instChannel);
            if (vocalChannel != null && Math.abs(position - getChannelPosition(vocalChannel)) > 20.0) setChannelPosition(vocalChannel, position);
            if (oppChannel != null && Math.abs(position - getChannelPosition(oppChannel)) > 20.0) setChannelPosition(oppChannel, position);
            return;
        }
        #end
        if (inst != null && inst.playing) {
            if (vocals != null && vocals.playing && Math.abs(inst.time - vocals.time) > 20.0) vocals.time = inst.time;
            if (opponentVocals != null && opponentVocals.playing && Math.abs(inst.time - opponentVocals.time) > 20.0) opponentVocals.time = inst.time;
        }
    }

    public function update(elapsed:Float):Void {
        #if SOULSCORCH_FMOD
        if (fmodReady && fmodSystem != null) {
            Reflect.callMethod(fmodSystem, Reflect.field(fmodSystem, "update"), []);
            syncVocals();
            if (playbackStarted && !completionDispatched && instChannel != null && !isChannelPlaying(instChannel)) {
                completionDispatched = true;
                playbackStarted = false;
                if (onSongComplete != null) onSongComplete();
            }
            return;
        }
        #end
        syncVocals();
    }

    public function cancelAudioTweens():Void {
        if (inst != null) FlxTween.cancelTweensOf(inst);
        if (vocals != null) FlxTween.cancelTweensOf(vocals);
        if (opponentVocals != null) FlxTween.cancelTweensOf(opponentVocals);
    }

    public function clear():Void {
        #if SOULSCORCH_FMOD
        if (fmodReady) {
            if (instChannel != null) Reflect.callMethod(instChannel, Reflect.field(instChannel, "stop"), []);
            if (vocalChannel != null) Reflect.callMethod(vocalChannel, Reflect.field(vocalChannel, "stop"), []);
            if (oppChannel != null) Reflect.callMethod(oppChannel, Reflect.field(oppChannel, "stop"), []);
            releaseSound(instSound);
            releaseSound(vocalSound);
            releaseSound(oppSound);
            instChannel = vocalChannel = oppChannel = null;
            instSound = vocalSound = oppSound = null;
            playbackStarted = false;
            completionDispatched = false;
            isLoaded = false;
            return;
        }
        #end
        cancelAudioTweens();
        if (inst != null) { inst.stop(); if (FlxG.sound.list != null) FlxG.sound.list.remove(inst, true); inst.destroy(); inst = null; }
        if (vocals != null) { vocals.stop(); if (FlxG.sound.list != null) FlxG.sound.list.remove(vocals, true); vocals.destroy(); vocals = null; }
        if (opponentVocals != null) { opponentVocals.stop(); if (FlxG.sound.list != null) FlxG.sound.list.remove(opponentVocals, true); opponentVocals.destroy(); opponentVocals = null; }
        isLoaded = false;
    }
}
