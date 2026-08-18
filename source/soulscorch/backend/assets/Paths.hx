package soulscorch.backend.assets;

import flixel.FlxG;
import flixel.graphics.frames.FlxAtlasFrames;
import openfl.display.BitmapData;
import openfl.media.Sound;

using StringTools;

class Paths {
    public static inline function file(file:String):String {
        return 'assets/$file';
    }

    public static inline function txt(key:String):String {
        return 'assets/data/$key.txt';
    }

    public static inline function xml(key:String):String {
        return 'assets/images/$key.xml';
    }

    public static inline function json(key:String):String {
        return 'assets/data/$key.json';
    }

    public static inline function exists(path:String):Bool {
        return AssetResolver.exists(path);
    }

    public static inline function sound(key:String):Null<Sound> {
        return AssetResolver.getSound('sounds/$key');
    }

    public static inline function soundRandom(key:String, min:Int, max:Int):Null<Sound> {
        return sound(key + FlxG.random.int(min, max));
    }

    public static inline function music(key:String):Null<Sound> {
        var snd = AssetResolver.getSound('music/$key');
        if (snd == null) snd = AssetResolver.getSound('songs/$key');
        return snd;
    }

    public static inline function inst(song:String):Null<Sound> {
        var clean = song.toLowerCase().trim();
        var snd = AssetResolver.getSound('songs/$clean/Inst');
        if (snd == null) snd = AssetResolver.getSound('assets/songs/$clean/Inst');
        if (snd == null) snd = AssetResolver.getSound('music/$clean/Inst');
        return snd;
    }

    public static inline function voices(song:String):Null<Sound> {
        var clean = song.toLowerCase().trim();
        var snd = AssetResolver.getSound('songs/$clean/Voices');
        if (snd == null) snd = AssetResolver.getSound('assets/songs/$clean/Voices');
        if (snd == null) snd = AssetResolver.getSound('music/$clean/Voices');
        return snd;
    }

    public static inline function image(key:String):Null<BitmapData> {
        return AssetResolver.getBitmapData('images/$key');
    }

    public static inline function font(key:String):String {
        var resolved = AssetResolver.resolveFile('fonts/$key', [".ttf", ".otf", ""]);
        return (resolved != null) ? resolved : 'assets/fonts/$key.ttf';
    }

    public static function getSparrowAtlas(key:String):Null<FlxAtlasFrames> {
        var bmp = AssetResolver.getBitmapData('images/$key');
        var xmlContent = AssetResolver.getText('images/$key.xml');
        if (bmp != null && xmlContent.length > 0) {
            return FlxAtlasFrames.fromSparrow(bmp, xmlContent);
        }
        return null;
    }
}