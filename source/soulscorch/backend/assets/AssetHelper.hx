package soulscorch.backend.assets;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.system.FlxSound;
import openfl.media.Sound;

#if sys
import sys.FileSystem;
#end

using StringTools;

class AssetHelper {
    public static function loadGraphicSafely(spr:FlxSprite, key:String):Bool {
        if (spr == null || key == null) return false;

        var graphic = Paths.image(key);
        if (graphic != null) {
            spr.loadGraphic(graphic);
            return true;
        }
        return false;
    }

    public static inline function loadImageSafely(spr:FlxSprite, key:String):Bool {
        return loadGraphicSafely(spr, key);
    }

    public static function clearAtlasCache():Void {
        // Clears cached graphic frames if tracked
    }

    public static function loadSparrowSafely(spr:FlxSprite, key:String):Bool {
        if (spr == null || key == null) return false;

        var clean = key.trim();

        // 1. Try loading as Adobe Animate JSON Texture Atlas (.json)
        var jsonAtlas = Paths.getTextureAtlas(clean);
        if (jsonAtlas != null && jsonAtlas.frames != null && jsonAtlas.frames.length > 0) {
            spr.frames = jsonAtlas;
            return true;
        }

        // 2. Try loading as Sparrow XML Atlas (.xml)
        var xmlLookups = [
            'images/$clean.xml',
            'assets/preload/images/$clean.xml',
            'assets/images/$clean.xml',
            'ui/game/cutscenes/$clean.xml',
            '$clean.xml'
        ];

        var hasXml = false;
        #if sys
        for (xp in xmlLookups) {
            if (FileSystem.exists(xp)) {
                hasXml = true;
                break;
            }
        }
        #else
        hasXml = true;
        #end

        if (hasXml) {
            var atlas:FlxAtlasFrames = Paths.getSparrowAtlas(clean);
            if (atlas != null && atlas.frames != null && atlas.frames.length > 0) {
                spr.frames = atlas;
                return true;
            }
        }

        return false;
    }

    public static function playSoundSafely(key:String, volume:Float = 1.0):Null<FlxSound> {
        if (key == null) return null;

        var soundObj:Sound = Paths.sound(key);
        if (soundObj == null && (key == "fnf_loss_sfx" || key == "loss_sfx")) {
            soundObj = Paths.sound("gameOverSFX");
        }

        if (soundObj != null) {
            return FlxG.sound.play(soundObj, volume);
        }
        return null;
    }
}