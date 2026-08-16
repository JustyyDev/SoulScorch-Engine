package soulscorch.assets;

import flixel.graphics.frames.FlxAtlasFrames;
import soulscorch.modding.ModManager;

using StringTools;

class Paths {
    public static inline function normalize(path:String):String {
        if (path == null || path.length == 0) {
            return path;
        }

        var normalized = StringTools.replace(path, "\\", "/");
        while (normalized.indexOf("./") == 0) {
            normalized = normalized.substr(2);
        }

        if (normalized.indexOf("assets/preload/") == 0) {
            normalized = "assets/" + normalized.substr("assets/preload/".length);
        } else if (normalized.indexOf("assets/") != 0 && normalized.indexOf("mods/") != 0 && normalized.indexOf("http://") != 0 && normalized.indexOf("https://") != 0) {
            normalized = "assets/" + normalized;
        }

        return normalized;
    }

    public static inline function getPath(path:String):String {
        return ModManager.getPath(path);
    }

    public static inline function file(path:String):String {
        return getPath(path);
    }

    public static inline function image(path:String, ?ext:String):String {
        var target = path == null ? "" : path.trim();
        if (target.length == 0) return target;

        var clean = normalize(target);
        if (clean.indexOf(".") == -1) {
            var imageExt = ext != null ? ext : "png";
            clean = clean + "." + imageExt;
        }

        return getPath(clean);
    }

    public static inline function xml(path:String):String {
        var target = path == null ? "" : path.trim();
        if (target.length == 0) return target;
        var clean = normalize(target);
        if (!clean.endsWith(".xml")) {
            clean = clean + ".xml";
        }
        return getPath(clean);
    }

    public static inline function txt(path:String):String {
        var target = path == null ? "" : path.trim();
        if (target.length == 0) return target;
        var clean = normalize(target);
        if (!clean.endsWith(".txt")) {
            clean = clean + ".txt";
        }
        return getPath(clean);
    }

    public static inline function sound(path:String, ?ext:String):String {
        var target = path == null ? "" : path.trim();
        if (target.length == 0) return target;
        var clean = normalize(target);
        if (clean.indexOf(".") == -1) {
            clean = clean + "." + (ext != null ? ext : "ogg");
        }
        return getPath(clean);
    }

    public static inline function text(path:String):String {
        return txt(path);
    }

    public static inline function getFrames(path:String, ?ext:String):FlxAtlasFrames {
        var target = path == null ? "" : path.trim();
        if (target.length == 0) return null;

        var imagePath = image(target, ext != null ? ext : "png");
        var xmlPath = xml(target);
        return FlxAtlasFrames.fromSparrow(imagePath, xmlPath);
    }

    public static inline function exists(path:String):Bool {
        var resolved = getPath(path);
        return soulscorch.assets.AssetResolver.exists(resolved);
    }
}
