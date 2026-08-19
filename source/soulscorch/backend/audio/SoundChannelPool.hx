package soulscorch.backend.audio;

import flixel.FlxG;
import flixel.sound.FlxSound;
import soulscorch.backend.assets.Paths;

class SoundChannelPool {
    private static var activeSounds:Map<String, FlxSound> = new Map<String, FlxSound>();

    /**
     * Plays a sound effect safely, ensuring multiple identical sounds don't stack-deafen the player.
     */
    public static function playUnique(soundKey:String, volume:Float = 1.0, pitch:Float = 1.0):Void {
        if (activeSounds.exists(soundKey)) {
            var snd = activeSounds.get(soundKey);
            if (snd != null && snd.playing) {
                return;
            }
        }

        var soundAsset = Paths.sound(soundKey);
        if (soundAsset != null) {
            var snd = FlxG.sound.play(soundAsset, volume, false, true, function() {
                activeSounds.remove(soundKey);
            });

            if (snd != null) {
                snd.pitch = pitch;
                activeSounds.set(soundKey, snd);
            }
        }
    }

    public static function stopSound(soundKey:String):Void {
        if (activeSounds.exists(soundKey)) {
            var snd = activeSounds.get(soundKey);
            if (snd != null) {
                snd.stop();
                snd.destroy();
            }
            activeSounds.remove(soundKey);
        }
    }

    public static function clearPool():Void {
        for (key in activeSounds.keys()) {
            var snd = activeSounds.get(key);
            if (snd != null) {
                snd.stop();
                snd.destroy();
            }
        }
        activeSounds.clear();
    }
}