package soulscorch.assets;

import openfl.utils.Assets;
import openfl.media.Sound;
import openfl.display.BitmapData;
import flixel.graphics.FlxGraphic;
import flixel.FlxG;
import haxe.Json;
import soulscorch.core.Engine;
import soulscorch.modding.ModLoader;
import StringTools;

#if sys
import sys.io.File;
import sys.FileSystem;
#end

class AssetResolver {
    
    public static function exists(path:String):Bool {
        if (path == null || StringTools.trim(path).length == 0 || StringTools.trim(path) == "/") {
            return false;
        }
        #if sys
        if (path != null && FileSystem.exists(path)) {
            return true;
        }
        #end
        return resolveModPath(path) != null || Assets.exists(path);
    }

    public static function getText(path:String):String {
        if (path == null || StringTools.trim(path).length == 0 || StringTools.trim(path) == "/") {
            return "";
        }

        var modPath = resolveModPath(path);
        #if sys
        if (modPath != null && FileSystem.exists(modPath)) {
            return File.getContent(modPath);
        }
        if (path != null && FileSystem.exists(path)) {
            return File.getContent(path);
        }
        #end

        return Assets.getText(path);
    }

    public static function getJson(path:String):Dynamic {
        var rawText = getText(path);
        if (rawText != null && rawText.length > 0) {
            try {
                return Json.parse(rawText);
            } catch (e:Dynamic) {
                Sys.println('AssetResolver JSON Error parsing $path: $e');
            }
        }
        return null;
    }

    public static function getImage(path:String):FlxGraphic {
        var modPath = resolveModPath(path);
        var returnGraphic:FlxGraphic = null;

        #if sys
        var resolvedFile = modPath != null && FileSystem.exists(modPath) ? modPath : (path != null && FileSystem.exists(path) ? path : null);
        if (resolvedFile != null) {
            var bitmap = BitmapData.fromFile(resolvedFile);
            if (bitmap != null) {
                returnGraphic = FlxGraphic.fromBitmapData(bitmap, false, resolvedFile);
                returnGraphic.persist = true;
            }
        }
        #end

        if (returnGraphic == null && Assets.exists(path)) {
            returnGraphic = FlxG.bitmap.add(path);
        }

        return returnGraphic;
    }

    public static function getSound(path:String):Sound {
        var modPath = resolveModPath(path);
        
        #if sys
        var resolvedFile = modPath != null && FileSystem.exists(modPath) ? modPath : (path != null && FileSystem.exists(path) ? path : null);
        if (resolvedFile != null) {
            return Sound.fromFile(resolvedFile);
        }
        #end

        if (Assets.exists(path)) {
            return Assets.getSound(path);
        }
        
        return null;
    }

    static function resolveModPath(path:String):Null<String> {
        if (path == null || StringTools.trim(path).length == 0 || StringTools.trim(path) == "/") {
            return null;
        }

        if (Engine.instance == null) {
            return null;
        }

        var loader:ModLoader = Engine.instance.resolve("modLoader");
        return loader == null ? null : loader.resolveAsset(path);
    }
}