package soulscorch.scripting.backends;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.tweens.FlxTween;
import soulscorch.scripting.ScriptInstance;
#if sys
import sys.FileSystem;
#end

class LuaScript implements ScriptInstance {
    public var active:Bool = false;
    public var path(default, null):String;
    private var variables:Map<String, Dynamic> = new Map();
    private var sprites:Map<String, FlxSprite> = new Map();
    public function new(scriptPath:String) { path = scriptPath == null ? "" : scriptPath; variables.set("FlxG", FlxG); }
    public function call(func:String, ?args:Array<Dynamic>):Dynamic return null;
    public function set(key:String, value:Dynamic):Void if (key != null && key.length > 0) setProperty(variables, key, value);
    public function get(key:String):Dynamic return getProperty(variables, key);
    public function makeLuaSprite(name:String, imagePath:String, x:Float = 0, y:Float = 0):FlxSprite {
        var sprite:FlxSprite = new FlxSprite(x, y);
        #if sys
        if (imagePath != null && FileSystem.exists(imagePath)) sprite.loadGraphic(imagePath);
        #end
        if (sprite.graphic == null) sprite.makeGraphic(64, 64, 0xFFFF00FF);
        sprites.set(name, sprite); if (FlxG.state != null) FlxG.state.add(sprite); return sprite;
    }
    public function doTweenX(tag:String, target:Dynamic, value:Float, duration:Float):Void if (target != null) FlxTween.tween(target, {x: value}, duration);
    public function doTweenZoom(tag:String, target:Dynamic, value:Float, duration:Float):Void if (target != null) FlxTween.tween(target, {zoom: value}, duration);
    public static function setProperty(root:Dynamic, dottedPath:String, value:Dynamic):Void {
        var parts:Array<String> = dottedPath.split("."); var current:Dynamic = root;
        for (i in 0...(parts.length - 1)) { if (current == null) return; current = Reflect.getProperty(current, parts[i]); }
        if (current != null && parts.length > 0) Reflect.setProperty(current, parts[parts.length - 1], value);
    }
    public static function getProperty(root:Dynamic, dottedPath:String):Dynamic {
        if (root == null || dottedPath == null) return null; var current:Dynamic = root;
        for (part in dottedPath.split(".")) { if (current == null) return null; current = Reflect.getProperty(current, part); } return current;
    }
    public function destroy():Void { active = false; sprites.clear(); variables.clear(); }
}
