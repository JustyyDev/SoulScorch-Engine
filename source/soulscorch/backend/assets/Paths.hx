package soulscorch.backend.assets;

import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import openfl.display.BitmapData;
import openfl.media.Sound;

using StringTools;

class Paths {
    public static inline function file(file:String):String {
        return 'assets/$file';
    }

    public static inline function txt(key:String):String {
        var resolved = AssetResolver.resolveFile('data/$key', [".txt", ""]);
        return (resolved != null) ? resolved : 'assets/data/$key.txt';
    }

    public static inline function xml(key:String):String {
        var resolved = AssetResolver.resolveFile('images/$key', [".xml", ""]);
        return (resolved != null) ? resolved : 'assets/images/$key.xml';
    }

    public static inline function json(key:String):String {
        var resolved = AssetResolver.resolveFile('data/$key', [".json", ""]);
        return (resolved != null) ? resolved : 'assets/data/$key.json';
    }

    public static inline function config(key:String):String {
        var resolved = AssetResolver.resolveFile('data/config/$key', [".txt", ".json", ""]);
        return (resolved != null) ? resolved : 'assets/data/config/$key.txt';
    }

    public static inline function exists(path:String):Bool {
        return AssetResolver.exists(path);
    }

    public static function sound(key:String):Null<Sound> {
        var clean = key.trim();

        // Check common FNF names and redirect to the nested menu/ directory if needed
        var variants = switch (clean) {
            case "scrollMenu", "scroll":
                ['sounds/menu/scroll', 'sounds/scrollMenu', 'sounds/scroll'];
            case "confirmMenu", "confirm":
                ['sounds/menu/confirm', 'sounds/confirmMenu', 'sounds/confirm'];
            case "cancelMenu", "cancel":
                ['sounds/menu/cancel', 'sounds/cancelMenu', 'sounds/cancel'];
            default:
                ['sounds/$clean', 'sounds/menu/$clean'];
        };

        for (v in variants) {
            var snd = AssetResolver.getSound(v);
            if (snd != null) return snd;
        }

        return null;
    }

    public static inline function soundRandom(key:String, min:Int, max:Int):Null<Sound> {
        return sound(key + FlxG.random.int(min, max));
    }

    public static function music(key:String):Null<Sound> {
        var clean = key.trim();
        var tries = ['music/$clean', 'songs/$clean', 'music/menu/$clean'];

        for (t in tries) {
            var snd = AssetResolver.getSound(t);
            if (snd != null) return snd;
        }

        return null;
    }

    public static function inst(song:String):Null<Sound> {
        var clean = song.toLowerCase().trim();
        var dashes = clean.replace(" ", "-");
        var stripped = clean.replace(" ", "").replace("-", "");

        var tries = [
            'songs/$dashes/Inst',
            'songs/$clean/Inst',
            'songs/$stripped/Inst',
            'music/$dashes/Inst',
            'music/$clean/Inst',
            'assets/songs/$dashes/Inst'
        ];

        for (t in tries) {
            var snd = AssetResolver.getSound(t);
            if (snd != null) return snd;
        }

        return null;
    }

    public static function voices(song:String):Null<Sound> {
        var clean = song.toLowerCase().trim();
        var dashes = clean.replace(" ", "-");
        var stripped = clean.replace(" ", "").replace("-", "");

        var tries = [
            'songs/$dashes/Voices',
            'songs/$clean/Voices',
            'songs/$stripped/Voices',
            'music/$dashes/Voices',
            'music/$clean/Voices',
            'assets/songs/$dashes/Voices'
        ];

        for (t in tries) {
            var snd = AssetResolver.getSound(t);
            if (snd != null) return snd;
        }

        return null;
    }

    public static inline function image(key:String):Null<BitmapData> {
        return AssetResolver.getBitmapData('images/$key');
    }

    public static inline function graphic(key:String):Null<FlxGraphic> {
        return AssetResolver.getGraphic('images/$key');
    }

    public static inline function font(key:String):String {
        var resolved = AssetResolver.resolveFile('fonts/$key', [".ttf", ".otf", ""]);
        return (resolved != null) ? resolved : 'assets/fonts/$key.ttf';
    }

    public static function getSparrowAtlas(key:String):Null<FlxAtlasFrames> {
        var graphic = AssetResolver.getGraphic('images/$key');
        var xmlContent = AssetResolver.getText('images/$key.xml');
        if (graphic != null && xmlContent.length > 0) {
            return FlxAtlasFrames.fromSparrow(graphic, xmlContent);
        }
        return null;
    }
}