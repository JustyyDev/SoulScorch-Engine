package soulscorch.backend.assets;

import flixel.graphics.frames.FlxAtlasFrames;
import openfl.utils.Assets as OpenFLAssets;
import soulscorch.scripting.mod.ModLoader;

using StringTools;

class Paths {
    public static inline var SOUND_EXT:String = #if web "mp3" #else "ogg" #end;
    public static inline var VIDEO_EXT:String = "mp4";

    /**
     * Normalizes a virtual asset path, standardizing directory separators and roots.
     */
    public static function normalize(path:String):String {
        if (path == null || path.length == 0) return "";

        var clean = path.replace("\\", "/").trim();
        while (clean.startsWith("./")) {
            clean = clean.substr(2);
        }

        if (clean.startsWith("assets/preload/")) {
            clean = "assets/" + clean.substr("assets/preload/".length);
        } else if (!clean.startsWith("assets/") && !clean.startsWith("mods/") && !clean.startsWith("http://") && !clean.startsWith("https://")) {
            clean = "assets/" + clean;
        }

        return clean;
    }

    /**
     * Resolves an asset path against active mods and fallback base directories.
     */
    public static inline function getPath(path:String):String {
        return ModLoader.getPath(normalize(path));
    }

    public static inline function file(path:String):String {
        return getPath(path);
    }

    public static inline function image(path:String, ?ext:String = "png"):String {
        var clean = normalize(path);
        if (clean.indexOf(".") == -1) clean += "." + ext;
        return getPath(clean);
    }

    public static inline function xml(path:String):String {
        var clean = normalize(path);
        if (!clean.endsWith(".xml")) clean += ".xml";
        return getPath(clean);
    }

    public static inline function json(path:String):String {
        var clean = normalize(path);
        if (!clean.endsWith(".json")) clean += ".json";
        return getPath(clean);
    }

    public static inline function txt(path:String):String {
        var clean = normalize(path);
        if (!clean.endsWith(".txt")) clean += ".txt";
        return getPath(clean);
    }

    public static inline function sound(path:String):String {
        var clean = normalize(path);
        if (clean.indexOf(".") == -1) clean += "." + SOUND_EXT;
        return getPath(clean);
    }

    public static inline function music(path:String):String {
        var clean = normalize(path);
        if (clean.indexOf(".") == -1) clean += "." + SOUND_EXT;
        return getPath(clean);
    }

    public static inline function inst(songId:String):String {
        return getPath('assets/songs/$songId/song/Inst.$SOUND_EXT');
    }

    public static inline function voices(songId:String, ?stem:String = "Voices"):String {
        return getPath('assets/songs/$songId/song/$stem.$SOUND_EXT');
    }

    public static inline function font(name:String):String {
        var clean = normalize(name.endsWith(".ttf") || name.endsWith(".otf") ? name : name + ".ttf");
        if (!clean.startsWith("assets/fonts/")) clean = "assets/fonts/" + name;
        return getPath(clean);
    }

    public static inline function video(name:String):String {
        var clean = normalize(name.endsWith("." + VIDEO_EXT) ? name : name + "." + VIDEO_EXT);
        if (!clean.startsWith("assets/videos/")) clean = "assets/videos/" + clean;
        return getPath(clean);
    }

    /**
     * Loads a Sparrow / TexturePacker atlas from image and XML descriptors.
     */
    public static function getFrames(path:String):FlxAtlasFrames {
        if (path == null || path.trim().length == 0) return null;

        var imgPath = image(path);
        var xmlPath = xml(path);

        if (!AssetResolver.exists(imgPath) || !AssetResolver.exists(xmlPath)) return null;

        try {
            return FlxAtlasFrames.fromSparrow(AssetResolver.getImage(imgPath), AssetResolver.getText(xmlPath));
        } catch (e:Dynamic) {
            return null;
        }
    }

    public static inline function exists(path:String):Bool {
        return AssetResolver.exists(getPath(path));
    }
}