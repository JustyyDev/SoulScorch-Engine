package soulscorch.backend.assets;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.sound.FlxSound;
import soulscorch.backend.utils.Logger;

class AssetHelper {
    /**
     * Safely assigns Sparrow atlas frames to a sprite with fallback placeholder generation on failure.
     */
    public static function loadSparrowSafely(sprite:FlxSprite, path:String):Bool {
        var frames = Paths.getFrames(path);
        if (frames != null) {
            sprite.frames = frames;
            return true;
        }

        Logger.warn('Missing or corrupt Sparrow atlas: $path');
        makeFallbackGraphic(sprite);
        return false;
    }

    /**
     * Safely loads an image graphic onto a sprite with fallback placeholder generation on failure.
     */
    public static function loadGraphicSafely(sprite:FlxSprite, path:String):Bool {
        var resolvedPath = Paths.image(path);
        var graphic = AssetResolver.getImage(resolvedPath);

        if (graphic != null) {
            sprite.loadGraphic(graphic);
            return true;
        }

        Logger.warn('Missing graphic: $path');
        makeFallbackGraphic(sprite);
        return false;
    }

    /**
     * Safely loads and plays a sound effect without throwing unhandled null exceptions.
     */
    public static function playSoundSafely(path:String, volume:Float = 1.0):FlxSound {
        var sound = AssetResolver.getSound(Paths.sound(path));
        if (sound != null) {
            return FlxG.sound.play(sound, volume);
        }

        Logger.warn('Missing sound asset: $path');
        return null;
    }

    private static inline function makeFallbackGraphic(sprite:FlxSprite, width:Int = 64, height:Int = 64):Void {
        sprite.makeGraphic(width, height, 0xFFFF00FF); // Standard magenta missing-texture color
    }
}