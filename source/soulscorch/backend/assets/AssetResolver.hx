package soulscorch.backend.assets;

import flixel.FlxG;
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
    public static var trackedSounds:Map<String, Sound> = new Map<String, Sound>();

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
        var clean = basePath.trim().replace("\\", "/");

        // 1. Direct check
        if (exists(clean)) return ModLoader.getPath(clean);

        // 2. Check with extensions & folder prefixes
        var exts = (extensions != null) ? extensions : ["", ".png", ".xml", ".ogg", ".mp3", ".json", ".txt", ".hx", ".lua", ".soul"];
        
        var folderPrefixes = [
            "",
            "assets/",
            "assets/preload/",
            "assets/shared/",
            "assets/images/",
            "assets/preload/images/",
            "assets/sounds/",
            "assets/preload/sounds/",
            "assets/music/",
            "assets/preload/music/",
            "assets/songs/",
            "assets/data/",
            "assets/preload/data/",
            "assets/data/config/",
            "assets/preload/data/config/",
            "assets/fonts/",
            "assets/preload/fonts/",
            "images/",
            "sounds/",
            "music/",
            "data/"
        ];

        for (ext in exts) {
            var pathWithExt = (clean.endsWith(ext) && ext.length > 0) ? clean : clean + ext;

            for (prefix in folderPrefixes) {
                var test = (pathWithExt.startsWith("assets/") && prefix.length > 0) ? pathWithExt : prefix + pathWithExt;
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

        if (trackedSounds.exists(resolved)) {
            return trackedSounds.get(resolved);
        }

        var snd:Sound = null;

        #if sys
        if (FileSystem.exists(resolved)) {
            try {
                snd = Sound.fromFile(resolved);
            } catch (e:Dynamic) {
                Logger.error('Failed loading native sound from $resolved: $e', "assets");
            }
        }
        #end

        if (snd == null && openfl.utils.Assets.exists(resolved)) {
            snd = openfl.utils.Assets.getSound(resolved);
        }

        if (snd != null) {
            trackedSounds.set(resolved, snd);
        }

        return snd;
    }

    public static function getBitmapData(path:String):Null<BitmapData> {
        var graphic = getGraphic(path);
        return (graphic != null) ? graphic.bitmap : null;
    }

    public static function getGraphic(path:String):Null<FlxGraphic> {
        var resolved = resolveFile(path, [".png", ".jpg", ".jpeg", ""]);
        if (resolved == null) return null;

        if (FlxG.bitmap.checkCache(resolved)) {
            return FlxG.bitmap.get(resolved);
        }

        var bmp:BitmapData = null;

        #if sys
        if (FileSystem.exists(resolved)) {
            try {
                bmp = BitmapData.fromFile(resolved);
            } catch (e:Dynamic) {
                Logger.error('Failed loading bitmap from $resolved: $e', "assets");
            }
        }
        #end

        if (bmp == null && openfl.utils.Assets.exists(resolved)) {
            bmp = openfl.utils.Assets.getBitmapData(resolved);
        }

        if (bmp != null) {
            return FlxG.bitmap.add(bmp, false, resolved);
        }

        return null;
    }

    public static inline function getImage(path:String):Null<BitmapData> {
        return getBitmapData(path);
    }

    public static function clearCache():Void {
        trackedSounds.clear();
    }
}