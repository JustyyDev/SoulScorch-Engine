package soulscorch.gameplay.notes;

import flixel.FlxG;
import flixel.graphics.frames.FlxAtlasFrames;
import haxe.xml.Access;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.system.XMSoul;

using StringTools;

typedef NoteSkinConfig = {
    var name:String;
    var type:String; // "sparrow" or "grid"
    var atlasPath:String;
    var sustainPath:String;
    var scale:Float;
    var antialiasing:Bool;
    var colors:Array<String>;
    var directions:Array<String>;
    var gridNoteWidth:Int;
    var gridNoteHeight:Int;
    var gridHoldWidth:Int;
    var gridHoldHeight:Int;
}

typedef NoteSplashConfig = {
    var name:String;
    var atlasPath:String;
    var scale:Float;
    var alpha:Float;
    var fps:Int;
    var antialiasing:Bool;
    var animOffsets:Map<String, Array<Float>>;
}

class NoteSkinManager {
    public static var defaultSkin:String = "default";
    private static var _skinCache:Map<String, FlxAtlasFrames> = new Map<String, FlxAtlasFrames>();
    private static var _splashCache:Map<String, FlxAtlasFrames> = new Map<String, FlxAtlasFrames>();

    public static var noteColors:Array<String> = ["purple", "blue", "green", "red"];
    public static var noteDirections:Array<String> = ["left", "down", "up", "right"];

    public static function getSkinConfig(?skinName:String):NoteSkinConfig {
        var cleanSkin = (skinName != null && skinName.trim().length > 0) ? skinName.trim() : getNoteSkinName();
        var config:NoteSkinConfig = {
            name: cleanSkin,
            type: "sparrow",
            atlasPath: cleanSkin,
            sustainPath: cleanSkin,
            scale: 0.7,
            antialiasing: true,
            colors: ["purple", "blue", "green", "red"],
            directions: ["left", "down", "up", "right"],
            gridNoteWidth: 17,
            gridNoteHeight: 17,
            gridHoldWidth: 7,
            gridHoldHeight: 6
        };

        var access:Access = XMSoul.parse('noteskins/notes/$cleanSkin');
        if (access == null) access = XMSoul.parse('data/noteskins/notes/$cleanSkin');
        if (access == null) access = XMSoul.parse('ui/game/notes/$cleanSkin');
        if (access == null) access = XMSoul.parse('notes/$cleanSkin');

        if (access != null && access.name.toLowerCase() == "noteskin") {
            config.type = XMSoul.getAttr(access, "type", "sparrow");
            config.atlasPath = XMSoul.getAttr(access, "sprite", XMSoul.getAttr(access, "image", cleanSkin));
            config.sustainPath = XMSoul.getAttr(access, "sustainSprite", config.atlasPath);
            config.scale = XMSoul.getFloatAttr(access, "scale", config.type == "grid" ? 6.0 : 0.7);
            config.antialiasing = XMSoul.getBoolAttr(access, "antialiasing", config.type != "grid");

            if (access.hasNode.gridDimensions) {
                var gd = access.node.gridDimensions;
                config.gridNoteWidth = XMSoul.getIntAttr(gd, "noteWidth", 17);
                config.gridNoteHeight = XMSoul.getIntAttr(gd, "noteHeight", 17);
                config.gridHoldWidth = XMSoul.getIntAttr(gd, "holdWidth", 7);
                config.gridHoldHeight = XMSoul.getIntAttr(gd, "holdHeight", 6);
            }
        }

        return config;
    }

    public static function getSplashConfig(?splashName:String):NoteSplashConfig {
        var cleanSplash = (splashName != null && splashName.trim().length > 0) ? splashName.trim() : "default";
        var config:NoteSplashConfig = {
            name: cleanSplash,
            atlasPath: 'ui/game/splashes/$cleanSplash',
            scale: 1.0,
            alpha: 0.6,
            fps: 24,
            antialiasing: true,
            animOffsets: new Map<String, Array<Float>>()
        };

        var access:Access = XMSoul.parse('noteskins/splashes/$cleanSplash');
        if (access == null) access = XMSoul.parse('data/noteskins/splashes/$cleanSplash');
        if (access == null) access = XMSoul.parse('data/splashes/$cleanSplash');
        if (access == null) access = XMSoul.parse('splashes/$cleanSplash');

        if (access != null) {
            config.atlasPath = XMSoul.getAttr(access, "sprite", XMSoul.getAttr(access, "image", 'ui/game/splashes/$cleanSplash'));
            config.scale = XMSoul.getFloatAttr(access, "scale", 1.0);
            config.alpha = XMSoul.getFloatAttr(access, "alpha", 0.6);
            config.fps = XMSoul.getIntAttr(access, "fps", 24);
            config.antialiasing = XMSoul.getBoolAttr(access, "antialiasing", true);
        }

        return config;
    }

    public static function getSkinAtlas(?skinName:String):Null<FlxAtlasFrames> {
        var conf = getSkinConfig(skinName);
        var cleanSkin = conf.atlasPath;

        if (_skinCache.exists(cleanSkin)) {
            var cached = _skinCache.get(cleanSkin);
            if (cached != null && cached.parent != null) return cached;
            _skinCache.remove(cleanSkin);
        }

        var lookups:Array<String> = [
            cleanSkin,
            'ui/game/notes/$cleanSkin',
            'noteskins/notes/$cleanSkin',
            'images/ui/game/notes/$cleanSkin',
            'ui/game/notes/NOTE_assets',
            'NOTE_assets',
            'default'
        ];

        for (path in lookups) {
            var atlas = Paths.getSparrowAtlas(path);
            if (atlas != null) {
                _skinCache.set(cleanSkin, atlas);
                return atlas;
            }
        }

        return null;
    }

    public static function getSplashAtlas(?splashName:String):Null<FlxAtlasFrames> {
        var conf = getSplashConfig(splashName);
        var cleanSkin = conf.atlasPath;

        if (_splashCache.exists(cleanSkin)) {
            var cached = _splashCache.get(cleanSkin);
            if (cached != null && cached.parent != null) return cached;
            _splashCache.remove(cleanSkin);
        }

        var lookups:Array<String> = [
            cleanSkin,
            'ui/game/splashes/$cleanSkin',
            'noteskins/splashes/$cleanSkin',
            'data/splashes/$cleanSkin',
            'ui/game/notes/noteSplashes',
            'noteSplashes'
        ];

        for (path in lookups) {
            var atlas = Paths.getSparrowAtlas(path);
            if (atlas != null) {
                _splashCache.set(cleanSkin, atlas);
                return atlas;
            }
        }

        return null;
    }

    public static function getNoteSkinName():String {
        if (FlxG.save != null && FlxG.save.data != null && FlxG.save.data.noteSkin != null) {
            return Std.string(FlxG.save.data.noteSkin);
        }
        return defaultSkin;
    }

    public static function clearCache():Void {
        _skinCache.clear();
        _splashCache.clear();
    }
}