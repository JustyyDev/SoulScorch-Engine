package soulscorch.backend.assets;

import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;
import openfl.media.Sound;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.mod.ModLoader;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

class AssetResolver {
    public static function exists(path:String):Bool {
        if (path == null || path.trim().length == 0) return false;

        #if sys
        if (FileSystem.exists(path)) return true;
        #end

        return openfl.utils.Assets.exists(path);
    }

    public static function getText(path:String):String {
        if (path == null || path.trim().length == 0) return "";

        #if sys
        if (FileSystem.exists(path)) {
            try {
                return File.getContent(path);
            } catch (e:Dynamic) {
                Logger.error('Failed reading text file at $path: $e', "assets");
            }
        }
        #end

        if (openfl.utils.Assets.exists(path)) {
            var raw = openfl.utils.Assets.getText(path);
            if (raw != null && raw.trim().length > 0) {
                return raw;
            }
        }

        return "";
    }

    public static function getSound(path:String):Null<Sound> {
        if (path == null || path.trim().length == 0) return null;

        #if sys
        if (FileSystem.exists(path)) {
            try {
                return Sound.fromFile(path);
            } catch (e:Dynamic) {
                Logger.error('Failed loading native sound from $path: $e', "assets");
            }
        }
        #end

        if (openfl.utils.Assets.exists(path)) {
            return openfl.utils.Assets.getSound(path);
        }

        return null;
    }

    public static function getBitmapData(path:String):Null<BitmapData> {
        if (path == null || path.trim().length == 0) return null;

        #if sys
        if (FileSystem.exists(path)) {
            try {
                return BitmapData.fromFile(path);
            } catch (e:Dynamic) {
                Logger.error('Failed loading native bitmap from $path: $e', "assets");
            }
        }
        #end

        if (openfl.utils.Assets.exists(path)) {
            return openfl.utils.Assets.getBitmapData(path);
        }

        return null;
    }

    public static function getImage(path:String):Null<BitmapData> {
        return getBitmapData(path);
    }
}