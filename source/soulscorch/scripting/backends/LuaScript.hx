package soulscorch.scripting.backends;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import soulscorch.scripting.ScriptInstance;
#if sys
import sys.FileSystem;
#end

class LuaScript implements ScriptInstance {
    public var active:Bool = false;
    public var path(default, null):String;
    private var variables:Map<String, Dynamic> = new Map();
    private var sprites:Map<String, FlxSprite> = new Map();

    public function new(scriptPath:String) {
        path = scriptPath == null ? "" : scriptPath;
        variables.set("FlxG", FlxG);
        variables.set("game", FlxG.state);
        active = true;
    }

    public function call(func:String, ?args:Array<Dynamic>):Dynamic {
        return null;
    }

    public function set(key:String, value:Dynamic):Void {
        if (key != null && key.length > 0) {
            variables.set(key, value);
        }
    }

    public function get(key:String):Dynamic {
        return variables.get(key);
    }

    public function makeLuaSprite(name:String, imagePath:String, x:Float = 0, y:Float = 0):FlxSprite {
        var sprite:FlxSprite = new FlxSprite(x, y);
        #if sys
        if (imagePath != null && FileSystem.exists(imagePath)) {
            sprite.loadGraphic(imagePath);
        }
        #end
        if (sprite.graphic == null) sprite.makeGraphic(64, 64, 0xFFFF00FF);
        sprites.set(name, sprite);
        if (FlxG.state != null) FlxG.state.add(sprite);
        return sprite;
    }

    public function doTweenX(tag:String, targetName:String, value:Float, duration:Float, ?easeName:String = "linear"):Void {
        var target = getProperty(variables, targetName);
        if (target != null) {
            var easeFunc = Reflect.field(FlxEase, easeName);
            FlxTween.tween(target, {x: value}, duration, {ease: easeFunc});
        }
    }

    public function doTweenZoom(tag:String, targetName:String, value:Float, duration:Float, ?easeName:String = "linear"):Void {
        var target = getProperty(variables, targetName);
        if (target != null) {
            var easeFunc = Reflect.field(FlxEase, easeName);
            FlxTween.tween(target, {zoom: value}, duration, {ease: easeFunc});
        }
    }

    public static function setProperty(root:Dynamic, dottedPath:String, value:Dynamic):Void {
        if (root == null || dottedPath == null) return;
        var parts:Array<String> = dottedPath.split(".");
        var current:Dynamic = root;

        for (i in 0...(parts.length - 1)) {
            if (current == null) return;
            var key = parts[i];
            if (Std.isOfType(current, haxe.ds.StringMap)) {
                current = cast(current, haxe.ds.StringMap<Dynamic>).get(key);
            } else {
                current = Reflect.getProperty(current, key);
            }
        }

        if (current != null && parts.length > 0) {
            var lastKey = parts[parts.length - 1];
            if (Std.isOfType(current, haxe.ds.StringMap)) {
                cast(current, haxe.ds.StringMap<Dynamic>).set(lastKey, value);
            } else {
                Reflect.setProperty(current, lastKey, value);
            }
        }
    }

    public static function getProperty(root:Dynamic, dottedPath:String):Dynamic {
        if (root == null || dottedPath == null) return null;
        var current:Dynamic = root;

        for (part in dottedPath.split(".")) {
            if (current == null) return null;
            if (Std.isOfType(current, haxe.ds.StringMap)) {
                current = cast(current, haxe.ds.StringMap<Dynamic>).get(part);
            } else {
                current = Reflect.getProperty(current, part);
            }
        }
        return current;
    }

    public function destroy():Void {
        active = false;
        sprites.clear();
        variables.clear();
    }
}