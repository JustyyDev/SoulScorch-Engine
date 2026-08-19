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
        if (sprite == null || graphicPath == null || graphicPath.trim().length == 0) return false;

        var graphic:FlxGraphic = AssetResolver.getGraphic(graphicPath);
        if (graphic != null && graphic.bitmap != null) {
            graphic.persist = true;
            graphic.destroyOnNoUse = false;
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
        if (sprite == null || assetName == null || assetName.trim().length == 0) return false;

        var clean = assetName.trim().replace("\\", "/");
        if (clean.startsWith("/")) clean = clean.substr(1);

        if (_cachedAtlases.exists(clean)) {
            var cached = _cachedAtlases.get(clean);
            if (cached != null && cached.parent != null && cached.parent.bitmap != null) {
                sprite.frames = cached;
                return true;
            }
            _cachedAtlases.remove(clean);
        }

        var frames = Paths.getSparrowAtlas(clean);
        if (frames != null && frames.parent != null && frames.parent.bitmap != null) {
            frames.parent.persist = true;
            frames.parent.destroyOnNoUse = false;
            _cachedAtlases.set(clean, frames);
            sprite.frames = frames;
            return true;
        }

        Logger.warn('Missing or corrupt Sparrow atlas: $assetName', "engine");
        sprite.makeGraphic(64, 64, 0xFFFF00FF);
        return false;
    }

    public static function playSoundSafely(soundName:String, volume:Float = 1.0):Void {
        if (soundName == null || soundName.trim().length == 0) return;

        var soundObj:Sound = Paths.sound(soundName);
        if (soundObj == null) soundObj = AssetResolver.getSound(soundName);

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