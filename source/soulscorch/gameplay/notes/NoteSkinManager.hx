package soulscorch.gameplay.notes;

import flixel.FlxG;
import flixel.graphics.frames.FlxAtlasFrames;
import soulscorch.backend.assets.Paths;

class NoteSkinManager {
    public static var defaultSkin:String = "default";

    public static function getSkinAtlas(skinName:String):Null<FlxAtlasFrames> {
        var cleanSkin = (skinName != null && skinName.length > 0) ? skinName : getNoteSkinName();

        var lookups:Array<String> = [
            'ui/notes/$cleanSkin',
            'notes/$cleanSkin',
            cleanSkin,
            'gameplay/notes/$cleanSkin',
            "ui/notes/default",
            "notes/default",
            "notes/NOTE_assets",
            "NOTE_assets"
        ];

        for (path in lookups) {
            var atlas = Paths.getSparrowAtlas(path);
            if (atlas != null) return atlas;
        }

        return null;
    }

    public static function getSplashAtlas(skinName:String):Null<FlxAtlasFrames> {
        var cleanSkin = (skinName != null && skinName.length > 0) ? skinName : getNoteSkinName();

        var lookups:Array<String> = [
            'ui/notes/${cleanSkin}_splashes',
            'ui/notes/splashes_$cleanSkin',
            'notes/${cleanSkin}_splashes',
            '${cleanSkin}_splashes',
            'ui/noteSplashes',
            'noteSplashes',
            'ui/notes/default_splashes'
        ];

        for (path in lookups) {
            var atlas = Paths.getSparrowAtlas(path);
            if (atlas != null) return atlas;
        }

        return null;
    }

    public static function getNoteSkinName():String {
        if (FlxG.save != null && FlxG.save.data != null && FlxG.save.data.noteSkin != null) {
            return Std.string(FlxG.save.data.noteSkin);
        }
        return defaultSkin;
    }
}