package soulscorch.backend.assets;

import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import openfl.display.BitmapData;
import openfl.media.Sound;
import openfl.utils.Assets;
#if cpp
import cpp.vm.Gc;
#elseif hl
import hl.Gc;
#elseif java
import java.lang.System;
#end

using StringTools;

class Paths {
    public static var currentTrackedAssets:Map<String, FlxGraphic> = new Map<String, FlxGraphic>();
    public static var currentTrackedSounds:Map<String, Sound> = new Map<String, Sound>();

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
        if (key == null) return null;
        var clean = key.trim();

        var variants = switch (clean) {
            case "scrollMenu", "scroll":
                ['sounds/menu/scroll', 'sounds/scrollMenu', 'sounds/scroll', 'sounds/menu/scrollMenu'];
            case "confirmMenu", "confirm":
                ['sounds/menu/confirm', 'sounds/confirmMenu', 'sounds/confirm', 'sounds/menu/confirmMenu'];
            case "cancelMenu", "cancel":
                ['sounds/menu/cancel', 'sounds/cancelMenu', 'sounds/cancel', 'sounds/menu/cancelMenu'];
            default:
                ['sounds/$clean', 'sounds/menu/$clean', '$clean'];
        };

        for (v in variants) {
            var snd = AssetResolver.getSound(v);
            if (snd != null) {
                currentTrackedSounds.set(v, snd);
                return snd;
            }
        }

        return null;
    }

    public static inline function soundRandom(key:String, min:Int, max:Int):Null<Sound> {
        return sound(key + FlxG.random.int(min, max));
    }

    public static function music(key:String):Null<Sound> {
        if (key == null) return null;
        var clean = key.trim();
        var tries = ['music/$clean', 'songs/$clean', 'music/menu/$clean', '$clean'];

        for (t in tries) {
            var snd = AssetResolver.getSound(t);
            if (snd != null) {
                currentTrackedSounds.set(t, snd);
                return snd;
            }
        }

        return null;
    }

    public static function inst(song:String):Null<Sound> {
        if (song == null) return null;
        var clean = song.toLowerCase().trim();
        var dashes = clean.replace(" ", "-");
        var stripped = clean.replace(" ", "").replace("-", "");

        var tries = [
            'songs/$dashes/Inst',
            'songs/$clean/Inst',
            'songs/$stripped/Inst',
            'music/$dashes/Inst',
            'music/$clean/Inst',
            '$dashes/Inst',
            '$clean/Inst'
        ];

        for (t in tries) {
            var snd = AssetResolver.getSound(t);
            if (snd != null) {
                currentTrackedSounds.set(t, snd);
                return snd;
            }
        }

        return null;
    }

    public static function voices(song:String):Null<Sound> {
        if (song == null) return null;
        var clean = song.toLowerCase().trim();
        var dashes = clean.replace(" ", "-");
        var stripped = clean.replace(" ", "").replace("-", "");

        var tries = [
            'songs/$dashes/Voices',
            'songs/$clean/Voices',
            'songs/$stripped/Voices',
            'music/$dashes/Voices',
            'music/$clean/Voices',
            '$dashes/Voices',
            '$clean/Voices'
        ];

        for (t in tries) {
            var snd = AssetResolver.getSound(t);
            if (snd != null) {
                currentTrackedSounds.set(t, snd);
                return snd;
            }
        }

        return null;
    }

    public static inline function image(key:String):Null<BitmapData> {
        return AssetResolver.getBitmapData('images/$key');
    }

    public static inline function graphic(key:String):Null<FlxGraphic> {
        var graph = AssetResolver.getGraphic('images/$key');
        if (graph == null) graph = AssetResolver.getGraphic(key);

        if (graph != null) {
            currentTrackedAssets.set(key, graph);
        }
        return graph;
    }

    public static inline function font(key:String):String {
        var clean = (key != null && key.trim().length > 0) ? key.trim() : "vcr";
        var resolved = AssetResolver.resolveFile('fonts/$clean', [".ttf", ".otf", ""]);
        if (resolved == null) resolved = AssetResolver.resolveFile('$clean', [".ttf", ".otf", ""]);
        return (resolved != null) ? resolved : 'assets/fonts/$clean.ttf';
    }

    public static function getSparrowAtlas(key:String):Null<FlxAtlasFrames> {
        if (key == null || key.trim().length == 0) return null;
        var clean = key.trim().replace("\\", "/");
        if (clean.startsWith("/")) clean = clean.substr(1);

        var graph = graphic(clean);
        var xmlContent = AssetResolver.getText('images/$clean.xml');
        if (xmlContent.length == 0) xmlContent = AssetResolver.getText('$clean.xml');

        if (graph != null && xmlContent.length > 0) {
            return FlxAtlasFrames.fromSparrow(graph, xmlContent);
        }
        return null;
    }

    public static function clearStoredMemory():Void {
        @:privateAccess {
            if (Assets.cache != null) {
                Assets.cache.clear("IMAGE");
                Assets.cache.clear("SOUND");
            }
        }

        FlxG.bitmap.dumpCache();
        FlxG.bitmap.clearCache();

        currentTrackedAssets.clear();
        currentTrackedSounds.clear();
        AssetHelper.clearAtlasCache();

        runGarbageCollector();
    }

    @:access(flixel.system.frontEnds.BitmapFrontEnd)
    public static function clearUnusedMemory():Void {
        for (key in FlxG.bitmap._cache.keys()) {
            var graph:FlxGraphic = FlxG.bitmap._cache.get(key);
            if (graph != null && !graph.persist && graph.useCount <= 0 && !currentTrackedAssets.exists(key)) {
                FlxG.bitmap.remove(graph);
            }
        }

        runGarbageCollector();
    }

    private static function runGarbageCollector():Void {
        #if cpp
        Gc.run(true);
        Gc.compact();
        #elseif hl
        Gc.major();
        #elseif java
        System.gc();
        #end
    }
}