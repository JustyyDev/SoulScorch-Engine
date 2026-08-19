package soulscorch.gameplay.notes;

import flixel.FlxG;
import flixel.graphics.frames.FlxAtlasFrames;
import soulscorch.backend.assets.Paths;

class NoteSkinManager {
    public static var defaultSkin:String = "default";

    public static function getSkinAtlas(skinName:String):Null<FlxAtlasFrames> {
        var cleanSkin = (skinName != null && skinName.length > 0) ? skinName : getNoteSkinName();

        var atlas = Paths.getSparrowAtlas('ui/notes/$cleanSkin');
        if (atlas == null) atlas = Paths.getSparrowAtlas('notes/$cleanSkin');
        if (atlas == null) atlas = Paths.getSparrowAtlas(cleanSkin);

        if (atlas == null) {
            atlas = Paths.getSparrowAtlas("ui/notes/default");
            if (atlas == null) atlas = Paths.getSparrowAtlas("notes/default");
            if (atlas == null) atlas = Paths.getSparrowAtlas("NOTE_assets");
        }

        return atlas;
    }

    public static function getSplashAtlas(skinName:String):Null<FlxAtlasFrames> {
        var cleanSkin = (skinName != null && skinName.length > 0) ? skinName : getNoteSkinName();

        var atlas = Paths.getSparrowAtlas('ui/notes/${cleanSkin}_splashes');
        if (atlas == null) atlas = Paths.getSparrowAtlas('ui/notes/splashes_$cleanSkin');
        if (atlas == null) atlas = Paths.getSparrowAtlas('notes/${cleanSkin}_splashes');
        if (atlas == null) atlas = Paths.getSparrowAtlas('${cleanSkin}_splashes');

        // Global Fallbacks
        if (atlas == null) atlas = Paths.getSparrowAtlas('ui/noteSplashes');
        if (atlas == null) atlas = Paths.getSparrowAtlas('noteSplashes');
        if (atlas == null) atlas = Paths.getSparrowAtlas('ui/notes/default_splashes');

        return atlas;
    }

    public static function getNoteSkinName():String {
        if (FlxG.save != null && FlxG.save.data != null && FlxG.save.data.noteSkin != null) {
            return Std.string(FlxG.save.data.noteSkin);
        }
        return defaultSkin;
    }
}