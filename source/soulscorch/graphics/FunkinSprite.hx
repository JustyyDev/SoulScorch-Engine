package soulscorch.graphics;

import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import haxe.Json;
import openfl.utils.Assets;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.utils.Logger;

using StringTools;

class FunkinSprite extends FlxSprite {
    public function new(x:Float = 0, y:Float = 0) {
        super(x, y);
    }

    public function loadSprite(path:String):Bool {
        var cleanPath = path.endsWith("/") ? path.substr(0, path.length - 1) : path;
        
        var jsonAnimPath = '$cleanPath/Animation.json';
        var resolvedAnim = AssetResolver.resolveFile(jsonAnimPath, [".json", ""]);

        if (resolvedAnim != null) {
            try {
                var dir = cleanPath.substring(0, cleanPath.lastIndexOf("/") + 1);
                var rawJson = AssetResolver.getText(resolvedAnim);
                if (rawJson != null) {
                    loadAnimateAtlas(dir, rawJson);
                    return true;
                }
            } catch (e:Dynamic) {
                Logger.warn('Failed to load Animate spritemap at $cleanPath: $e', "graphics");
            }
        }

        var sparrowLoaded = loadSparrow(path);
        if (sparrowLoaded) return true;

        var graphic = AssetResolver.getGraphic(path);
        if (graphic != null) {
            loadGraphic(graphic);
            return true;
        }

        return false;
    }

    private function loadAnimateAtlas(directory:String, animationJson:String):Void {
        try {
            var pngPath = '${directory}spritemap1.png';
            var resolvedImage = AssetResolver.resolveFile(pngPath, [".png", ""]);
            if (resolvedImage != null) {
                var graphic = AssetResolver.getGraphic(resolvedImage);
                if (graphic != null) {
                    loadGraphic(graphic);
                }
            }
        } catch (e:Dynamic) {
            Logger.error('Error parsing spritemap sheets: $e', "graphics");
        }
    }

    public function loadSparrow(path:String):Bool {
        var atlas = Paths.getSparrowAtlas(path);
        if (atlas != null) {
            frames = atlas;
            return true;
        }
        return false;
    }

    public function addAnim(name:String, prefix:String, fps:Int = 24, loop:Bool = false):Void {
        if (animation != null) {
            animation.addByPrefix(name, prefix, fps, loop);
        }
    }

    public function playAnim(name:String, force:Bool = false, reversed:Bool = false, frame:Int = 0):Void {
        if (animation != null && animation.getByName(name) != null) {
            animation.play(name, force, reversed, frame);
        }
    }
}