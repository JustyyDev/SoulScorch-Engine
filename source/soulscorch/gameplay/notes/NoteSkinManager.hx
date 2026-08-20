package soulscorch.gameplay.notes;

import flixel.FlxG;
import flixel.graphics.frames.FlxAtlasFrames;
import haxe.xml.Access;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.system.XMSoul;

using StringTools;

typedef StrumAnimConfig = {
    var staticAnim:String;
    var pressedAnim:String;
    var confirmAnim:String;
}

typedef HoldAnimConfig = {
    var bodyAnim:String;
    var endAnim:String;
}

typedef NoteSkinConfig = {
    var name:String;
    var type:String; // "sparrow" or "grid"
    var atlasPath:String;
    var sustainPath:String;
    var scale:Float;
    var antialiasing:Bool;
    var sustainAlpha:Float;
    var colors:Array<String>;
    var directions:Array<String>;
    var tapAnims:Map<Int, String>;
    var strumAnims:Map<Int, StrumAnimConfig>;
    var holdAnims:Map<Int, HoldAnimConfig>;
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
    private static var _configCache:Map<String, NoteSkinConfig> = new Map<String, NoteSkinConfig>();

    public static var noteColors:Array<String> = ["purple", "blue", "green", "red"];
    public static var noteDirections:Array<String> = ["left", "down", "up", "right"];

    public static function getSkinConfig(?skinName:String):NoteSkinConfig {
        var cleanSkin = (skinName != null && skinName.trim().length > 0) ? skinName.trim() : getNoteSkinName();

        if (_configCache.exists(cleanSkin)) {
            return _configCache.get(cleanSkin);
        }

        var config:NoteSkinConfig = {
            name: cleanSkin,
            type: "sparrow",
            atlasPath: cleanSkin,
            sustainPath: cleanSkin,
            scale: 0.7,
            antialiasing: true,
            sustainAlpha: 0.6,
            colors: ["purple", "blue", "green", "red"],
            directions: ["left", "down", "up", "right"],
            tapAnims: new Map<Int, String>(),
            strumAnims: new Map<Int, StrumAnimConfig>(),
            holdAnims: new Map<Int, HoldAnimConfig>(),
            gridNoteWidth: 17,
            gridNoteHeight: 17,
            gridHoldWidth: 7,
            gridHoldHeight: 6
        };

        // Standard Fallback Mappings
        for (i in 0...4) {
            config.tapAnims.set(i, noteColors[i]);
            config.strumAnims.set(i, {
                staticAnim: 'arrow' + noteDirections[i].toUpperCase(),
                pressedAnim: noteDirections[i] + ' press',
                confirmAnim: noteDirections[i] + ' confirm'
            });
            config.holdAnims.set(i, {
                bodyAnim: noteColors[i] + ' hold piece',
                endAnim: (i == 0 ? "pruple end hold" : noteColors[i] + ' hold end')
            });
        }

        var access:Access = XMSoul.parse('noteskins/notes/$cleanSkin');
        if (access == null) access = XMSoul.parse('data/noteskins/notes/$cleanSkin');
        if (access == null) access = XMSoul.parse('ui/game/notes/$cleanSkin');
        if (access == null) access = XMSoul.parse('data/ui/game/notes/$cleanSkin');
        if (access == null) access = XMSoul.parse('notes/$cleanSkin');

        if (access != null) {
            config.type = XMSoul.getAttr(access, "type", "sparrow");
            config.atlasPath = XMSoul.getAttr(access, "sprite", XMSoul.getAttr(access, "image", cleanSkin));
            config.sustainPath = XMSoul.getAttr(access, "sustainSprite", config.atlasPath);
            config.scale = XMSoul.getFloatAttr(access, "scale", config.type == "grid" ? 6.0 : 0.7);
            config.antialiasing = XMSoul.getBoolAttr(access, "antialiasing", config.type != "grid");

            // Parse <receptors>
            if (access.hasNode.resolve("receptors")) {
                for (strumNode in access.node.resolve("receptors").nodes.resolve("strum")) {
                    var lane = XMSoul.getIntAttr(strumNode, "lane", 0);
                    config.strumAnims.set(lane, {
                        staticAnim: XMSoul.getAttr(strumNode, "static", 'arrow' + noteDirections[lane % 4].toUpperCase()),
                        pressedAnim: XMSoul.getAttr(strumNode, "pressed", noteDirections[lane % 4] + ' press'),
                        confirmAnim: XMSoul.getAttr(strumNode, "confirm", noteDirections[lane % 4] + ' confirm')
                    });
                }
            }

            // Parse <tapNotes>
            if (access.hasNode.resolve("tapNotes")) {
                for (noteNode in access.node.resolve("tapNotes").nodes.resolve("note")) {
                    var lane = XMSoul.getIntAttr(noteNode, "lane", 0);
                    config.tapAnims.set(lane, XMSoul.getAttr(noteNode, "anim", noteColors[lane % 4]));
                }
            }

            // Parse <sustains>
            if (access.hasNode.resolve("sustains")) {
                var susNode = access.node.resolve("sustains");
                config.sustainAlpha = XMSoul.getFloatAttr(susNode, "alpha", 0.6);

                for (holdNode in susNode.nodes.resolve("hold")) {
                    var lane = XMSoul.getIntAttr(holdNode, "lane", 0);
                    var endAnim = XMSoul.getAttr(holdNode, "end", (lane == 0 ? "pruple end hold" : noteColors[lane % 4] + " hold end"));
                    
                    // Safety normalize any leftover XML typos
                    if (endAnim == "purlpe end hold") endAnim = "pruple end hold";

                    config.holdAnims.set(lane, {
                        bodyAnim: XMSoul.getAttr(holdNode, "body", noteColors[lane % 4] + " hold piece"),
                        endAnim: endAnim
                    });
                }
            }
        }

        _configCache.set(cleanSkin, config);
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
        _configCache.clear();
    }
}