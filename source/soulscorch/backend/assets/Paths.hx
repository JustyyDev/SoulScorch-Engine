package soulscorch.backend.assets;

import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import openfl.display.BitmapData;
import openfl.media.Sound;
import openfl.utils.Assets;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.system.engine.EngineOptimizer;
import soulscorch.scripting.mod.ModManager;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

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
    public static var localTrackedAssets:Array<String> = [];

    public static inline function file(file:String):String {
        return ModManager.getPath(file);
    }

    public static inline function getPath(file:String, ?type:Dynamic, ?library:String):String {
        return ModManager.getPath(file);
    }

    public static inline function txt(key:String):String {
        var resolved = AssetResolver.resolveFile('data/$key', [".txt", ""]);
        return (resolved != null) ? resolved : file('data/$key.txt');
    }

    public static inline function xml(key:String):String {
        var resolved = AssetResolver.resolveFile('images/$key', [".xml", ""]);
        return (resolved != null) ? resolved : file('images/$key.xml');
    }

    public static inline function json(key:String):String {
        var resolved = AssetResolver.resolveFile('data/$key', [".json", ""]);
        return (resolved != null) ? resolved : file('data/$key.json');
    }

    public static inline function xmsoul(key:String):String {
        var resolved = AssetResolver.resolveFile('data/$key', [".xmsoul", ".xml", ""]);
        return (resolved != null) ? resolved : file('data/$key.xmsoul');
    }

    public static inline function config(key:String):String {
        var resolved = AssetResolver.resolveFile('data/config/$key', [".xmsoul", ".xml", ".json", ".txt", ""]);
        return (resolved != null) ? resolved : file('data/config/$key.xmsoul');
    }

    public static inline function exists(path:String):Bool {
        return AssetResolver.exists(path);
    }

    public static function sound(key:String):Null<Sound> {
        if (key == null) return null;
        var clean = key.trim();

        if (currentTrackedSounds.exists(clean)) {
            return currentTrackedSounds.get(clean);
        }

        var variants = switch (clean) {
            case "scrollMenu", "scroll":
                ['sounds/menu/scroll', 'sounds/scrollMenu', 'sounds/scroll', 'sounds/menu/scrollMenu', 'sfx/scroll'];
            case "confirmMenu", "confirm":
                ['sounds/menu/confirm', 'sounds/confirmMenu', 'sounds/confirm', 'sounds/menu/confirmMenu', 'sfx/confirm'];
            case "cancelMenu", "cancel":
                ['sounds/menu/cancel', 'sounds/cancelMenu', 'sounds/cancel', 'sounds/menu/cancelMenu', 'sfx/cancel'];
            default:
                ['sounds/$clean', 'sounds/menu/$clean', 'sfx/$clean', '$clean'];
        };

        for (v in variants) {
            var snd = AssetResolver.getSound(v);
            if (snd != null) {
                currentTrackedSounds.set(clean, snd);
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

        if (currentTrackedSounds.exists(clean)) {
            return currentTrackedSounds.get(clean);
        }

        var tries = ['music/$clean', 'songs/$clean', 'music/menu/$clean', 'sounds/music/$clean', '$clean'];

        for (t in tries) {
            var snd = AssetResolver.getSound(t);
            if (snd != null) {
                currentTrackedSounds.set(clean, snd);
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

        var cacheKey = 'inst-$clean';
        if (currentTrackedSounds.exists(cacheKey)) {
            return currentTrackedSounds.get(cacheKey);
        }

        var tries = [
            'songs/$clean/song/Inst',
            'songs/$dashes/song/Inst',
            'songs/$stripped/song/Inst',
            'songs/$clean/Inst',
            'songs/$dashes/Inst',
            'songs/$stripped/Inst',
            'music/$clean/Inst',
            'music/$dashes/Inst',
            'data/$clean/Inst',
            '$clean/Inst',
            '$dashes/Inst'
        ];

        for (t in tries) {
            var snd = AssetResolver.getSound(t);
            if (snd != null) {
                currentTrackedSounds.set(cacheKey, snd);
                return snd;
            }
        }

        return null;
    }

    public static function voices(song:String, ?suffix:String = ""):Null<Sound> {
        if (song == null) return null;
        var clean = song.toLowerCase().trim();
        var dashes = clean.replace(" ", "-");
        var stripped = clean.replace(" ", "").replace("-", "");

        var fileNames = (suffix != null && suffix.length > 0) ? ['Voices-$suffix', 'Voices_$suffix', 'Voices'] : ['Voices'];
        var cacheKey = 'voices-$clean-$suffix';
        if (currentTrackedSounds.exists(cacheKey)) {
            return currentTrackedSounds.get(cacheKey);
        }

        var tries:Array<String> = [];
        for (fName in fileNames) {
            tries.push('songs/$clean/song/$fName');
            tries.push('songs/$dashes/song/$fName');
            tries.push('songs/$stripped/song/$fName');
            tries.push('songs/$clean/$fName');
            tries.push('songs/$dashes/$fName');
            tries.push('songs/$stripped/$fName');
            tries.push('music/$clean/$fName');
            tries.push('data/$clean/$fName');
            tries.push('$clean/$fName');
        }

        for (t in tries) {
            var snd = AssetResolver.getSound(t);
            if (snd != null) {
                currentTrackedSounds.set(cacheKey, snd);
                return snd;
            }
        }

        return null;
    }

    public static inline function image(key:String):Null<BitmapData> {
        return AssetResolver.getBitmapData('images/$key');
    }

    public static function graphic(key:String):Null<FlxGraphic> {
        if (key == null || key.trim().length == 0) return null;
        var clean = key.trim();

        if (currentTrackedAssets.exists(clean)) {
            return currentTrackedAssets.get(clean);
        }

        var graph = AssetResolver.getGraphic('images/$clean');
        if (graph == null) graph = AssetResolver.getGraphic(clean);

        if (graph != null) {
            graph.persist = true;
            graph.destroyOnNoUse = false;
            currentTrackedAssets.set(clean, graph);
            localTrackedAssets.push(clean);
        }
        return graph;
    }

    public static inline function font(key:String):String {
        var clean = (key != null && key.trim().length > 0) ? key.trim() : "vcr";
        var resolved = AssetResolver.resolveFile('fonts/$clean', [".ttf", ".otf", ""]);
        if (resolved == null) resolved = AssetResolver.resolveFile('$clean', [".ttf", ".otf", ""]);
        return (resolved != null) ? resolved : file('fonts/$clean.ttf');
    }

    public static function getSparrowAtlas(key:String):Null<FlxAtlasFrames> {
        if (key == null || key.trim().length == 0) return null;
        var clean = key.trim().replace("\\", "/");
        while (clean.startsWith("/")) clean = clean.substr(1);

        var graph:FlxGraphic = graphic(clean);
        if (graph == null && !clean.startsWith("images/")) {
            graph = graphic('images/$clean');
        }
        if (graph == null) return null;

        var rawXml:String = null;

        var xmlPath:String = xml(clean);
        #if sys
        if (FileSystem.exists(xmlPath)) {
            try {
                rawXml = File.getContent(xmlPath);
            } catch (e:Dynamic) {}
        }
        #end

        if (rawXml == null) {
            var resolved = AssetResolver.resolveFile('images/$clean', [".xml"]);
            if (resolved == null) resolved = AssetResolver.resolveFile(clean, [".xml"]);
            if (resolved != null) {
                rawXml = AssetResolver.getText(resolved);
            }
        }

        if (rawXml != null && rawXml.length > 0) {
            try {
                var cleanXml = sanitizeDuplicateXmlAttributes(rawXml);
                return FlxAtlasFrames.fromSparrow(graph, cleanXml);
            } catch (e:Dynamic) {
                try {
                    return FlxAtlasFrames.fromSparrow(graph, rawXml);
                } catch (err:Dynamic) {}
            }
        }

        return null;
    }

    /**
     * Cleans duplicate attributes within single XML tags to prevent XmlParserException crashes.
     */
    private static function sanitizeDuplicateXmlAttributes(xmlContent:String):String {
        if (xmlContent == null || xmlContent.length == 0) return xmlContent;

        var tagRegex = ~/<([a-zA-Z0-9_:]+)(\s+[^>]+?)(\/?)>/g;
        return tagRegex.map(xmlContent, function(r:EReg) {
            var tagName = r.matched(1);
            var rawAttrs = r.matched(2);
            var closingSlash = r.matched(3);

            var attrRegex = ~/([a-zA-Z0-9_:]+)\s*=\s*(['"])(.*?)\2/g;
            var seenAttrs:Map<String, Bool> = new Map<String, Bool>();
            var cleanedAttrs:Array<String> = [];

            while (attrRegex.match(rawAttrs)) {
                var attrName = attrRegex.matched(1);
                var fullAttr = attrRegex.matched(0);

                if (!seenAttrs.exists(attrName)) {
                    seenAttrs.set(attrName, true);
                    cleanedAttrs.push(fullAttr);
                }

                rawAttrs = attrRegex.matchedRight();
            }

            return '<$tagName ${cleanedAttrs.join(" ")}$closingSlash>';
        });
    }

    public static function getTextureAtlas(key:String):Null<FlxAtlasFrames> {
        if (key == null || key.trim().length == 0) return null;
        var clean = key.trim().replace("\\", "/");
        while (clean.startsWith("/")) clean = clean.substr(1);

        var graph = graphic(clean);
        if (graph == null) graph = graphic('ui/game/cutscenes/$clean');
        if (graph == null) graph = graphic('characters/$clean');

        var jsonStr:String = null;
        var jsonPaths = [
            'images/$clean.json',
            'assets/preload/images/$clean.json',
            'assets/images/$clean.json',
            'ui/game/cutscenes/$clean.json',
            'assets/preload/images/ui/game/cutscenes/$clean.json',
            '$clean.json'
        ];

        #if sys
        for (jp in jsonPaths) {
            var p = ModManager.getPath(jp);
            if (sys.FileSystem.exists(p)) {
                try {
                    jsonStr = sys.io.File.getContent(p);
                    break;
                } catch (e:Dynamic) {}
            }
        }
        #end

        if (graph != null && jsonStr != null) {
            try {
                var parsed:Dynamic = haxe.Json.parse(jsonStr);
                var frameCollection = new FlxAtlasFrames(graph);

                if (Reflect.hasField(parsed, "ATLAS") && Reflect.hasField(parsed.ATLAS, "SPRITES")) {
                    var sprites:Array<Dynamic> = cast parsed.ATLAS.SPRITES;
                    for (sObj in sprites) {
                        var sprData = sObj.SPRITE;
                        var name:String = Std.string(sprData.name);
                        var x:Float = Std.parseFloat(Std.string(sprData.x));
                        var y:Float = Std.parseFloat(Std.string(sprData.y));
                        var w:Float = Std.parseFloat(Std.string(sprData.w));
                        var h:Float = Std.parseFloat(Std.string(sprData.h));
                        var rotated:Bool = sprData.rotated == true || Std.string(sprData.rotated) == "true";

                        var rect = FlxRect.get(x, y, w, h);
                        var size = FlxPoint.get(w, h);
                        var offset = FlxPoint.get(0, 0);

                        frameCollection.addAtlasFrame(rect, size, offset, name, rotated ? 90 : 0);
                    }
                } else if (Reflect.hasField(parsed, "frames")) {
                    var framesField = parsed.frames;
                    if (Std.isOfType(framesField, Array)) {
                        for (f in (cast framesField : Array<Dynamic>)) {
                            var fName = Std.string(f.filename);
                            var fRect = f.frame;
                            var rect = FlxRect.get(fRect.x, fRect.y, fRect.w, fRect.h);
                            var size = FlxPoint.get(f.sourceSize.w, f.sourceSize.h);
                            var offset = FlxPoint.get(f.spriteSourceSize.x, f.spriteSourceSize.y);
                            frameCollection.addAtlasFrame(rect, size, offset, fName, f.rotated ? 90 : 0);
                        }
                    }
                }

                if (frameCollection.frames.length > 0) {
                    return frameCollection;
                }
            } catch (e:Dynamic) {}
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
        localTrackedAssets = [];

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

    public static function runGarbageCollector():Void {
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