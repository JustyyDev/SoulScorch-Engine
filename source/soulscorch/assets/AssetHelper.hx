package soulscorch.assets;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.sound.FlxSound;

class AssetHelper {
    public static function loadSparrowSafely(sprite:FlxSprite, imagePath:String, xmlPath:String):Bool {
        var resolvedImg = Paths.getPath(imagePath);
        var resolvedXml = Paths.getPath(xmlPath);

        if (AssetResolver.exists(resolvedImg) && AssetResolver.exists(resolvedXml)) {
            try {
                sprite.frames = FlxAtlasFrames.fromSparrow(resolvedImg, AssetResolver.getText(resolvedXml));
                return true;
            } catch (e:Dynamic) {
                Sys.println('[WARN] Failed parsing Sparrow atlas at $imagePath: $e');
            }
        } else {
            Sys.println('[WARN] Missing atlas assets: $imagePath or $xmlPath');
        }

        sprite.makeGraphic(64, 64, 0xFFFF00FF);
        return false;
    }

    public static function loadGraphicSafely(sprite:FlxSprite, path:String):Bool {
        var resolved = Paths.getPath(path);
        if (AssetResolver.exists(resolved)) {
            sprite.loadGraphic(resolved);
            return true;
        }

        Sys.println('[WARN] Missing graphic: $path');
        sprite.makeGraphic(64, 64, 0xFFFF00FF);
        return false;
    }

    public static function playSoundSafely(path:String, volume:Float = 1.0):FlxSound {
        var resolved = Paths.getPath(path);
        if (AssetResolver.exists(resolved)) {
            return FlxG.sound.play(resolved, volume);
        }
        return null;
    }
}