package soulscorch.backend.assets;

import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;
import openfl.media.Sound;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.mod.ModManager;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

class AssetResolver {
    public static var trackedSounds:Map<String, Sound> = new Map<String, Sound>();

    public static function exists(path:String):Bool {
        if (path == null || path.trim().length == 0) return false;
        var resolved = resolveFile(path);
        return resolved != null;
    }

    public static function resolveFile(basePath:String, ?extensions:Array<String>):Null<String> {
        if (basePath == null || basePath.trim().length == 0) return null;
        var clean = basePath.trim().replace("\\", "/");
        while (clean.startsWith("/")) clean = clean.substr(1);

        var exts = (extensions != null && extensions.length > 0) ? extensions : [
            "",
            ".png",
            ".xml",
            ".ogg",
            ".mp3",
            ".wav",
            ".json",
            ".txt",
            ".soul",
            ".hx",
            ".lua",
            ".frag",
            ".vert",
            ".ttf",
            ".otf"
        ];

        var folderPrefixes = [
            "",
            "data/ui/",
            "data/",
            "shaders/",
            "images/ui/",
            "images/ui/main/",
            "images/ui/title/",
            "images/ui/warning/",
            "images/icons/",
            "images/characters/",
            "images/",
            "sounds/",
            "sounds/menu/",
            "music/",
            "music/menu/",
            "songs/",
            "fonts/",
            "assets/",
            "assets/preload/",
            "assets/shared/",
            "assets/data/",
            "assets/images/",
            "assets/sounds/",
            "assets/music/",
            "assets/songs/",
            "assets/fonts/",
            "assets/shaders/"
        ];

        #if sys
        // 1. Search in active enabled mods (highest priority first)
        if (ModManager.activeMods != null) {
            for (mod in ModManager.activeMods) {
                for (ext in exts) {
                    var pathWithExt = (clean.endsWith(ext) && ext.length > 0) ? clean : clean + ext;
                    for (prefix in folderPrefixes) {
                        var combined = (pathWithExt.startsWith(prefix) || pathWithExt.startsWith("mods/")) ? pathWithExt : prefix + pathWithExt;
                        var fullModPath = 'mods/$mod/$combined';
                        if (FileSystem.exists(fullModPath) && !FileSystem.isDirectory(fullModPath)) {
                            return fullModPath;
                        }
                    }
                }
            }
        }

        // 2. Search in base assets
        for (ext in exts) {
            var pathWithExt = (clean.endsWith(ext) && ext.length > 0) ? clean : clean + ext;
            for (prefix in folderPrefixes) {
                var combined = (pathWithExt.startsWith(prefix) || pathWithExt.startsWith("assets/")) ? pathWithExt : prefix + pathWithExt;
                if (FileSystem.exists(combined) && !FileSystem.isDirectory(combined)) {
                    return combined;
                }
                var assetsPrefix = 'assets/$combined';
                if (FileSystem.exists(assetsPrefix) && !FileSystem.isDirectory(assetsPrefix)) {
                    return assetsPrefix;
                }
            }
        }
        #end

        return null;
    }

    public static function getText(path:String):String {
        var resolved = resolveFile(path, [".soul", ".xml", ".frag", ".vert", ".json", ".txt", ".hx", ".lua", ""]);
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

        return "";
    }

    public static function getShader(key:String):String {
        var frag = getText('shaders/$key.frag');
        if (frag.length == 0) frag = getText('$key.frag');
        return frag;
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
                Logger.error('Failed loading sound from $resolved: $e', "assets");
            }
        }
        #end

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
            var cached = FlxG.bitmap.get(resolved);
            if (cached != null && cached.bitmap != null) {
                return cached;
            }
            FlxG.bitmap.remove(cached);
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

        if (bmp != null) {
            var graph = FlxGraphic.fromBitmapData(bmp, false, resolved);
            graph.persist = true;
            graph.destroyOnNoUse = false;
            FlxG.bitmap.addGraphic(graph);
            return graph;
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