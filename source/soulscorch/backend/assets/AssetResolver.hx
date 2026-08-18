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
        var resolved = ModLoader.getPath(path);

        #if sys
        if (FileSystem.exists(resolved)) return true;
        #end

        return openfl.utils.Assets.exists(resolved);
    }

    public static function resolveFile(basePath:String, ?extensions:Array<String>):Null<String> {
        if (basePath == null || basePath.trim().length == 0) return null;
        var clean = basePath.trim();

        // 1. Direct check
        if (exists(clean)) return ModLoader.getPath(clean);

        // 2. Check with extensions
        var exts = (extensions != null) ? extensions : ["", ".png", ".xml", ".ogg", ".mp3", ".json", ".txt", ".hx", ".lua"];
        
        var folderPrefixes = [
            "",
            "assets/",
            "assets/images/",
            "assets/sounds/",
            "assets/music/",
            "assets/fonts/",
            "assets/data/",
            "assets/shared/",
            "assets/preload/"
        ];

        for (prefix in folderPrefixes) {
            var targetPath = (clean.startsWith("assets/") && prefix.length > 0) ? clean : prefix + clean;
            for (ext in exts) {
                var test = targetPath + ext;
                var resolved = ModLoader.getPath(test);
                #if sys
                if (FileSystem.exists(resolved) && !FileSystem.isDirectory(resolved)) {
                    return resolved;
                }
                #end
                if (openfl.utils.Assets.exists(resolved)) {
                    return resolved;
                }
            }
        }

        return null;
    }

    public static function getText(path:String):String {
        var resolved = resolveFile(path, [".json", ".txt", ".xml", ".hx", ".lua", ".soul", ""]);
        if (resolved == null) return "";

        #if sys
        if (FileSystem.exists(resolved)) {
            try {
                return File.getContent(resolved);
            } catch (e:Dynamic) {
                Logger.error('Failed reading text file at $resolved: $e', "assets");
            }
        }
        #end

        if (openfl.utils.Assets.exists(resolved)) {
            var raw = openfl.utils.Assets.getText(resolved);
            if (raw != null) return raw;
        }

        return "";
    }

    public static function getSound(path:String):Null<Sound> {
        var resolved = resolveFile(path, [".ogg", ".mp3", ".wav", ""]);
        if (resolved == null) return null;

        #if sys
        if (FileSystem.exists(resolved)) {
            try {
                return Sound.fromFile(resolved);
            } catch (e:Dynamic) {
                Logger.error('Failed loading native sound from $resolved: $e', "assets");
            }
        }
        #end

        if (openfl.utils.Assets.exists(resolved)) {
            return openfl.utils.Assets.getSound(resolved);
        }

        return null;
    }

    public static function getBitmapData(path:String):Null<BitmapData> {
        var resolved = resolveFile(path, [".png", ".jpg", ".jpeg", ""]);
        if (resolved == null) return null;

        #if sys
        if (FileSystem.exists(resolved)) {
            try {
                return BitmapData.fromFile(resolved);
            } catch (e:Dynamic) {
                Logger.error('Failed loading bitmap from $resolved: $e', "assets");
            }
        }
        #end

        if (openfl.utils.Assets.exists(resolved)) {
            return openfl.utils.Assets.getBitmapData(resolved);
        }

        return null;
    }

    public static inline function getImage(path:String):Null<BitmapData> {
        return getBitmapData(path);
    }
}