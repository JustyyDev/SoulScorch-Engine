package soulscorch.gameplay.notes;

import flixel.FlxG;
import flixel.graphics.frames.FlxAtlasFrames;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;

class NoteSkinManager {
    public static var defaultSkin:String = "default";
    private static var _skinCache:Map<String, FlxAtlasFrames> = new Map<String, FlxAtlasFrames>();
    private static var _splashCache:Map<String, FlxAtlasFrames> = new Map<String, FlxAtlasFrames>();

    public static var noteColors:Array<String> = ["purple", "blue", "green", "red"];
    public static var noteDirections:Array<String> = ["left", "down", "up", "right"];

    public static function getSkinAtlas(?skinName:String):Null<FlxAtlasFrames> {
        var cleanSkin = (skinName != null && skinName.trim().length > 0) ? skinName.trim() : getNoteSkinName();

        if (_skinCache.exists(cleanSkin)) {
            var cached = _skinCache.get(cleanSkin);
            if (cached != null && cached.parent != null) return cached;
            _skinCache.remove(cleanSkin);
        }

        var lookups:Array<String> = [
            'ui/game/notes/$cleanSkin',
            'images/ui/game/notes/$cleanSkin',
            'ui/notes/$cleanSkin',
            'notes/$cleanSkin',
            cleanSkin,
            'ui/game/notes/NOTE_assets',
            'images/ui/game/notes/NOTE_assets',
            'ui/game/notes/default',
            'images/ui/game/notes/default',
            'gameplay/notes/$cleanSkin',
            "NOTE_assets",
            "default"
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

    public static function getSplashAtlas(?skinName:String):Null<FlxAtlasFrames> {
        var cleanSkin = (skinName != null && skinName.trim().length > 0) ? skinName.trim() : getNoteSkinName();

        if (_splashCache.exists(cleanSkin)) {
            var cached = _splashCache.get(cleanSkin);
            if (cached != null && cached.parent != null) return cached;
            _splashCache.remove(cleanSkin);
        }

        var lookups:Array<String> = [
            'ui/game/notes/${cleanSkin}_splashes',
            'images/ui/game/notes/${cleanSkin}_splashes',
            'ui/notes/${cleanSkin}_splashes',
            'notes/${cleanSkin}_splashes',
            'ui/game/notes/noteSplashes',
            'images/ui/game/notes/noteSplashes',
            'ui/noteSplashes',
            'noteSplashes',
            'ui/notes/default_splashes'
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