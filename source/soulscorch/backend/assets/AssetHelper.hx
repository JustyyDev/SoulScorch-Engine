package soulscorch.backend.assets;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import openfl.display.BitmapData;
import openfl.media.Sound;
import soulscorch.backend.utils.Logger;

using StringTools;

class AssetHelper {
    private static var _cachedAtlases:Map<String, FlxAtlasFrames> = new Map<String, FlxAtlasFrames>();

    public static function loadGraphicSafely(sprite:FlxSprite, graphicPath:String):Bool {
        if (sprite == null || graphicPath == null) return false;

        var graphic:FlxGraphic = AssetResolver.getGraphic(graphicPath);
        if (graphic != null) {
            sprite.loadGraphic(graphic);
            return true;
        }

        Logger.warn('Missing graphic: $graphicPath', "engine");
        sprite.makeGraphic(64, 64, 0xFFFF00FF);
        return false;
    }

    public static function loadImageSafely(sprite:FlxSprite, graphicPath:String):Bool {
        return loadGraphicSafely(sprite, graphicPath);
    }

    public static function loadSparrowSafely(sprite:FlxSprite, assetName:String):Bool {
        if (sprite == null || assetName == null) return false;

        var clean = assetName.trim().replace("\\", "/");
        if (_cachedAtlases.exists(clean)) {
            sprite.frames = _cachedAtlases.get(clean);
            return true;
        }

        var pngResolved = AssetResolver.resolveFile(clean, [".png"]);
        var xmlResolved = AssetResolver.resolveFile(clean, [".xml"]);

        if (pngResolved != null && xmlResolved != null) {
            var graphic:FlxGraphic = AssetResolver.getGraphic(pngResolved);
            var xmlText:String = AssetResolver.getText(xmlResolved);

            if (graphic != null && xmlText != null && xmlText.length > 0) {
                var frames = FlxAtlasFrames.fromSparrow(graphic, xmlText);
                if (frames != null) {
                    _cachedAtlases.set(clean, frames);
                    sprite.frames = frames;
                    return true;
                }
            }
        }

        Logger.warn('Missing or corrupt Sparrow atlas: $assetName', "engine");
        sprite.makeGraphic(64, 64, 0xFFFF00FF);
        return false;
    }

    public static function playSoundSafely(soundName:String, volume:Float = 1.0):Void {
        if (soundName == null || soundName.trim().length == 0) return;

        var soundObj:Sound = AssetResolver.getSound(soundName);
        if (soundObj != null) {
            FlxG.sound.play(soundObj, volume);
        } else {
            Logger.warn('Missing sound asset: $soundName', "engine");
        }
    }

    public static function clearAtlasCache():Void {
        _cachedAtlases.clear();
    }
}