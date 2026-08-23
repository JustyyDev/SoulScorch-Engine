package soulscorch.gameplay.notes;

import flixel.FlxG;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.util.FlxColor;
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
    var type:String;
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
}

class NoteSkinManager {
    public static var defaultSkin:String = "default";
    private static var _skinCache:Map<String, FlxAtlasFrames> = new Map<String, FlxAtlasFrames>();
    private static var _configCache:Map<String, NoteSkinConfig> = new Map<String, NoteSkinConfig>();

    public static var noteColors:Array<String> = ["purple", "blue", "green", "red"];
    public static var noteDirections:Array<String> = ["left", "down", "up", "right"];

    public static var defaultLaneColors:Array<FlxColor> = [
        0xFFC24B99,
        0xFF00FFFF,
        0xFF12FA05,
        0xFFF9393F
    ];

    public static inline function getLaneColor(lane:Int):FlxColor {
        return defaultLaneColors[lane % 4];
    }

    public static function getSkinConfig(?skinName:String):NoteSkinConfig {
        var cleanSkin = (skinName != null && skinName.trim().length > 0) ? skinName.trim() : defaultSkin;

        if (_configCache.exists(cleanSkin)) {
            return _configCache.get(cleanSkin);
        }

        var config:NoteSkinConfig = {
            name: cleanSkin,
            type: "sparrow",
            atlasPath: "NOTE_assets",
            sustainPath: "NOTE_assets",
            scale: 0.7,
            antialiasing: true,
            sustainAlpha: 0.6,
            colors: ["purple", "blue", "green", "red"],
            directions: ["left", "down", "up", "right"],
            tapAnims: new Map<Int, String>(),
            strumAnims: new Map<Int, StrumAnimConfig>(),
            holdAnims: new Map<Int, HoldAnimConfig>()
        };

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

        var candidateXmls = [
            'noteskins/$cleanSkin',
            'data/noteskins/$cleanSkin',
            'noteskins/default',
            'data/noteskins/default'
        ];

        var access:Access = null;
        for (p in candidateXmls) {
            access = XMSoul.parse(p, true, false);
            if (access != null && access.name == "noteSkin") break;
            access = null;
        }

        if (access != null) {
            config.scale = XMSoul.getFloatAttr(access, "scale", 0.7);
            config.antialiasing = XMSoul.getBoolAttr(access, "antialiasing", true);
            config.atlasPath = XMSoul.getAttr(access, "sprite", "NOTE_assets");

            if (access.hasNode.resolve("strums")) {
                for (stNode in access.node.resolve("strums").nodes.resolve("strum")) {
                    var lane = XMSoul.getIntAttr(stNode, "lane", 0);
                    config.strumAnims.set(lane, {
                        staticAnim: XMSoul.getAttr(stNode, "static", 'arrow' + noteDirections[lane].toUpperCase()),
                        pressedAnim: XMSoul.getAttr(stNode, "press", noteDirections[lane] + ' press'),
                        confirmAnim: XMSoul.getAttr(stNode, "confirm", noteDirections[lane] + ' confirm')
                    });
                }
            }

            if (access.hasNode.resolve("notes")) {
                for (nNode in access.node.resolve("notes").nodes.resolve("note")) {
                    var lane = XMSoul.getIntAttr(nNode, "lane", 0);
                    config.tapAnims.set(lane, XMSoul.getAttr(nNode, "anim", noteColors[lane]));
                }
            }

            if (access.hasNode.resolve("sustains")) {
                var susParent = access.node.resolve("sustains");
                config.sustainAlpha = XMSoul.getFloatAttr(susParent, "alpha", 0.6);
                for (hNode in susParent.nodes.resolve("hold")) {
                    var lane = XMSoul.getIntAttr(hNode, "lane", 0);
                    config.holdAnims.set(lane, {
                        bodyAnim: XMSoul.getAttr(hNode, "piece", noteColors[lane] + ' hold piece'),
                        endAnim: XMSoul.getAttr(hNode, "end", (lane == 0 ? "pruple end hold" : noteColors[lane] + ' hold end'))
                    });
                }
            }
        }

        _configCache.set(cleanSkin, config);
        return config;
    }

    public static function getSkinAtlas(?skinName:String):Null<FlxAtlasFrames> {
        var conf = getSkinConfig(skinName);
        var targetSprite = conf.atlasPath;

        if (_skinCache.exists(targetSprite)) {
            var cached = _skinCache.get(targetSprite);
            if (cached != null && cached.parent != null) return cached;
            _skinCache.remove(targetSprite);
        }

        var atlas = Paths.getSparrowAtlas(targetSprite);
        if (atlas == null) atlas = Paths.getSparrowAtlas("NOTE_assets");

        if (atlas != null) {
            _skinCache.set(targetSprite, atlas);
        }
        return atlas;
    }

    public static inline function getNoteSkinName():String {
        return defaultSkin;
    }

    public static inline function clearCache():Void {
        _skinCache.clear();
        _configCache.clear();
    }
}