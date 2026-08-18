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
    public static function loadGraphicSafely(sprite:FlxSprite, graphicPath:String):Bool {
        if (sprite == null || graphicPath == null) return false;

        var bitmap:BitmapData = AssetResolver.getBitmapData(graphicPath);
        if (bitmap != null) {
            sprite.loadGraphic(bitmap);
            return true;
        }

        Logger.warn('Missing graphic: $graphicPath', "engine");
        sprite.makeGraphic(64, 64, 0xFFFF00FF);
        return false;
    }

    public static function loadSparrowSafely(sprite:FlxSprite, assetName:String):Bool {
        if (sprite == null || assetName == null) return false;

        var pngResolved = AssetResolver.resolveFile(assetName, [".png"]);
        var xmlResolved = AssetResolver.resolveFile(assetName, [".xml"]);

        if (pngResolved != null && xmlResolved != null) {
            var bitmap:BitmapData = AssetResolver.getBitmapData(pngResolved);
            var xmlText:String = AssetResolver.getText(xmlResolved);

            if (bitmap != null && xmlText != null && xmlText.length > 0) {
                var frames = FlxAtlasFrames.fromSparrow(bitmap, xmlText);
                if (frames != null) {
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
}