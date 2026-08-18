package soulscorch.backend.audio;

import flixel.FlxG;
import flixel.system.FlxSound;
import soulscorch.backend.assets.Paths;

class SoundChannelPool {
    private static var activeSounds:Map<String, FlxSound> = new Map();

    /**
     * Plays a sound effect safely, ensuring multiple identical sounds don't stack-deafen the player.
     */
    public static function playUnique(soundKey:String, volume:Float = 1.0):Void {
        if (activeSounds.exists(soundKey)) {
            var snd = activeSounds.get(soundKey);
            if (snd != null && snd.playing) {
                return; // Prevent overlapping spam
            }
        }

        var soundAsset = Paths.sound(soundKey);
        if (soundAsset != null) {
            var snd = FlxG.sound.play(soundAsset, volume, false, function() {
                activeSounds.remove(soundKey);
            });
            if (snd != null) {
                activeSounds.set(soundKey, snd);
            }
        }
    }

    public static function clearPool():Void {
        for (snd in activeSounds) {
            if (snd != null) snd.stop();
        }
        activeSounds.clear();
    }
}