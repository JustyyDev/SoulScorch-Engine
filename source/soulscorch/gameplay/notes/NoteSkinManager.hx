package soulscorch.gameplay.notes;

import flixel.FlxG;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.util.FlxColor;
import haxe.xml.Access;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.system.XMSoul;
import soulscorch.gameplay.GameplayFlags;

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
    var gridNoteWidth:Int;
    var gridNoteHeight:Int;
    var gridHoldWidth:Int;
    var gridHoldHeight:Int;
}

class NoteSkinManager {
    public static var defaultSkin:String = "NOTE_assets";
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
        var cleanLane = lane % 4;
        return defaultLaneColors[cleanLane];
    }

    public static function getSkinConfig(?skinName:String):NoteSkinConfig {
        var cleanSkin = (skinName != null && skinName.trim().length > 0 && skinName != "default") ? skinName.trim() : getNoteSkinName();

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

        _configCache.set(cleanSkin, config);
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

        var atlas = Paths.getSparrowAtlas(cleanSkin);
        if (atlas == null) atlas = Paths.getSparrowAtlas("NOTE_assets");

        if (atlas != null) {
            _skinCache.set(cleanSkin, atlas);
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