package soulscorch.assets;

import openfl.utils.Assets;
import openfl.media.Sound;
import openfl.display.BitmapData;
import flixel.graphics.FlxGraphic;
import flixel.FlxG;
import haxe.Json;
import soulscorch.core.Engine;
import soulscorch.modding.ModLoader;

#if sys
import sys.io.File;
import sys.FileSystem;
#end

class AssetResolver {
    
    public static function exists(path:String):Bool {
        return resolveModPath(path) != null || Assets.exists(path);
    }

    public static function getText(path:String):String {
        var modPath = resolveModPath(path);
        #if sys
        if (modPath != null) {
            return File.getContent(modPath);
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
        if (modPath != null && FileSystem.exists(modPath)) {
            var bitmap = BitmapData.fromFile(modPath);
            if (bitmap != null) {
                // Creates a cached FlxGraphic so it doesn't leak memory if called repeatedly
                returnGraphic = FlxGraphic.fromBitmapData(bitmap, false, modPath);
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
        if (modPath != null && FileSystem.exists(modPath)) {
            return Sound.fromFile(modPath);
        }
        #end

        if (Assets.exists(path)) {
            return Assets.getSound(path);
        }
        
        return null;
    }

    static function resolveModPath(path:String):Null<String> {
        if (Engine.instance == null) {
            return null;
        }

        var loader:ModLoader = Engine.instance.resolve("modLoader");
        return loader == null ? null : loader.resolveAsset(path);
    }
}