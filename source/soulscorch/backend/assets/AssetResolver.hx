package soulscorch.backend.assets;

import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import haxe.Json;
import openfl.display.BitmapData;
import openfl.media.Sound;
import openfl.utils.Assets as OpenFLAssets;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.ModLoader;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

class AssetResolver {
    public static function exists(path:String):Bool {
        if (path == null || path.trim().length == 0) return false;

        #if sys
        if (FileSystem.exists(path)) return true;
        #end

        var modPath = ModLoader.getPath(path);
        #if sys
        if (modPath != null && FileSystem.exists(modPath)) return true;
        #end

        return OpenFLAssets.exists(path);
    }

    public static function getText(path:String):String {
        if (path == null || path.trim().length == 0) return "";

        var resolved = ModLoader.getPath(path);
        #if sys
        if (resolved != null && FileSystem.exists(resolved)) {
            return File.getContent(resolved);
        }
        if (FileSystem.exists(path)) {
            return File.getContent(path);
        }
        #end

        if (OpenFLAssets.exists(path)) {
            return OpenFLAssets.getText(path);
        }

        return "";
    }

    public static function getJson(path:String):Dynamic {
        var raw = getText(path);
        if (raw != null && raw.trim().length > 0) {
            try {
                return Json.parse(raw);
            } catch (e:Dynamic) {
                Logger.error('Failed parsing JSON at $path: $e');
            }
        }
        return null;
    }

    public static function getImage(path:String, ?persist:Bool = true):FlxGraphic {
        if (path == null || path.trim().length == 0) return null;

        var resolved = ModLoader.getPath(path);

        // Check Flixel graphic cache first
        if (FlxG.bitmap.checkCache(resolved)) {
            return FlxG.bitmap.get(resolved);
        }

        #if sys
        var targetFile = (resolved != null && FileSystem.exists(resolved)) ? resolved : (FileSystem.exists(path) ? path : null);
        if (targetFile != null) {
            var bitmap = BitmapData.fromFile(targetFile);
            if (bitmap != null) {
                var graphic = FlxGraphic.fromBitmapData(bitmap, false, targetFile);
                graphic.persist = persist;
                graphic.destroyOnNoUse = !persist;
                return graphic;
            }
        }
        #end

        if (OpenFLAssets.exists(path)) {
            return FlxG.bitmap.add(path, false, path);
        }

        Logger.warn('Image not found: $path');
        return null;
    }

    public static function getSound(path:String):Sound {
        if (path == null || path.trim().length == 0) return null;

        var resolved = ModLoader.getPath(path);

        #if sys
        var targetFile = (resolved != null && FileSystem.exists(resolved)) ? resolved : (FileSystem.exists(path) ? path : null);
        if (targetFile != null) {
            return Sound.fromFile(targetFile);
        }
        #end

        if (OpenFLAssets.exists(path)) {
            return OpenFLAssets.getSound(path);
        }

        Logger.warn('Sound not found: $path');
        return null;
    }
}