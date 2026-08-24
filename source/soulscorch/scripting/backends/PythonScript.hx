package soulscorch.scripting.backends;

import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import haxe.Timer;
import haxe.Json;
import openfl.display.BlendMode;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.utils.Logger;
import soulscorch.gameplay.PlayState;
import soulscorch.scripting.ScriptInstance;
import soulscorch.scripting.ScriptManager;
import soulscorch.scripting.mod.ModManager;

#if sys
import sys.io.Process;
#end

using StringTools;

class PythonScript implements ScriptInstance {
    public var active:Bool = false;
    public var path(default, null):String;

    private var variables:Map<String, Dynamic> = new Map<String, Dynamic>();
    private var pySprites:Map<String, FlxSprite> = new Map<String, FlxSprite>();
    private var pyTexts:Map<String, FlxText> = new Map<String, FlxText>();
    private var lastProcessCallAt:Float = 0.0;

    public function new(scriptPath:String) {
        this.path = (scriptPath == null) ? "" : scriptPath;
        load();
    }

    public function load():Bool {
        var fullPath = ModManager.getPath(path);
        if (!AssetResolver.exists(fullPath)) {
            active = false;
            return false;
        }

        variables.set("FlxG", FlxG);
        variables.set("game", FlxG.state);
        variables.set("state", FlxG.state);
        variables.set("Conductor", Conductor);
        variables.set("Paths", Paths);
        variables.set("AssetHelper", AssetHelper);
        variables.set("FlxColor", {
            BLACK: 0xFF000000,
            WHITE: 0xFFFFFFFF,
            RED: 0xFFFF0000,
            GREEN: 0xFF00FF00,
            BLUE: 0xFF0000FF,
            CYAN: 0xFF00FFFF,
            MAGENTA: 0xFFFF00FF,
            YELLOW: 0xFFFFFF00,
            TRANSPARENT: 0x00000000,
            fromRGB: FlxColor.fromRGB,
            fromHSL: FlxColor.fromHSL,
            fromString: FlxColor.fromString
        });
        variables.set("FlxSprite", FlxSprite);
        variables.set("FlxText", FlxText);
        variables.set("FlxTimer", FlxTimer);
        variables.set("FlxTween", FlxTween);
        variables.set("FlxEase", FlxEase);
        variables.set("Logger", Logger);
        variables.set("PlayState", PlayState);
        variables.set("ModManager", ModManager);

        active = true;
        return true;
    }

    // --- Extended API (no limits) ---
    public function makeLuaSprite(tag:String, ?image:String, x:Float = 0, y:Float = 0):FlxSprite {
        var spr = new FlxSprite(x, y);
        if (image != null && image != "") {
            if (AssetResolver.exists(image)) AssetHelper.loadGraphicSafely(spr, image);
            else spr.makeGraphic(1, 1, FlxColor.WHITE);
        } else {
            spr.makeGraphic(1, 1, FlxColor.WHITE);
        }
        pySprites.set(tag, spr);
        return spr;
    }

    public function makeLuaText(tag:String, text:String, width:Float = 0, x:Float = 0, y:Float = 0):FlxText {
        var txt = new FlxText(x, y, width, text, 16);
        txt.setFormat(Paths.font("vcr"), 16, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
        pyTexts.set(tag, txt);
        return txt;
    }

    public function addLuaSprite(tag:String, inFront:Bool = false):Void {
        var spr = pySprites.get(tag);
        if (spr != null && FlxG.state != null) {
            if (inFront) FlxG.state.add(spr); else FlxG.state.insert(0, spr);
        }
    }

    public function addLuaText(tag:String, inFront:Bool = false):Void {
        var txt = pyTexts.get(tag);
        if (txt != null && FlxG.state != null) {
            if (inFront) FlxG.state.add(txt); else FlxG.state.insert(0, txt);
        }
    }

    public function setTextBorder(tag:String, size:Int, colorStr:String):Void {
        var txt = pyTexts.get(tag);
        if (txt != null) {
            txt.borderSize = size;
            txt.borderColor = FlxColor.fromString(colorStr);
            txt.borderStyle = OUTLINE;
        }
    }

    public function setTextAlignment(tag:String, align:String):Void {
        var txt = pyTexts.get(tag);
        if (txt != null) {
            txt.alignment = switch (align.toLowerCase().trim()) {
                case "center" | "centre": CENTER;
                case "right": RIGHT;
                default: LEFT;
            };
        }
    }

    public function setTextWidth(tag:String, width:Float):Void {
        var txt = pyTexts.get(tag);
        if (txt != null) txt.fieldWidth = width;
    }

    public function setObjectOrder(tag:String, order:Int):Void {
        var obj:FlxBasic = pySprites.exists(tag) ? pySprites.get(tag) : pyTexts.get(tag);
        if (obj != null && FlxG.state != null) {
            FlxG.state.remove(obj);
            FlxG.state.insert(order, obj);
        }
    }

    public function getObjectOrder(tag:String):Int {
        var obj:FlxBasic = pySprites.exists(tag) ? pySprites.get(tag) : pyTexts.get(tag);
        if (obj != null && FlxG.state != null) return FlxG.state.members.indexOf(obj);
        return -1;
    }

    public function objectPlayAnim(tag:String, anim:String, forced:Bool = false):Void {
        var spr = pySprites.get(tag);
        if (spr != null && spr.animation != null && spr.animation.exists(anim)) spr.animation.play(anim, forced);
    }

    public function screenCenter(tag:String, axis:String = "xy"):Void {
        var obj:FlxSprite = pySprites.exists(tag) ? pySprites.get(tag) : pyTexts.get(tag);
        if (obj != null) {
            var a = axis.toLowerCase().trim();
            if (a == "x") obj.screenCenter(X);
            else if (a == "y") obj.screenCenter(Y);
            else obj.screenCenter();
        }
    }

    public function setBlendMode(tag:String, blend:String):Void {
        var obj:FlxSprite = pySprites.exists(tag) ? pySprites.get(tag) : pyTexts.get(tag);
        if (obj != null) {
            obj.blend = switch (blend.toLowerCase().trim()) {
                case "add": BlendMode.ADD;
                case "subtract": BlendMode.SUBTRACT;
                case "multiply": BlendMode.MULTIPLY;
                case "screen": BlendMode.SCREEN;
                case "erase": BlendMode.ERASE;
                default: BlendMode.NORMAL;
            };
        }
    }

    public function playSound(soundPath:String, volume:Float = 1.0):Void {
        AssetHelper.playSoundSafely(soundPath, volume);
    }

    public function call(func:String, ?args:Array<Dynamic>):Dynamic {
        // Guard per-frame hooks to prevent frame freezes from process spawning
        if (func == "update" || func == "onUpdate" || func == "onUpdatePost") {
            return null;
        }

        var now = Timer.stamp();
        if (ScriptManager.pythonProcessIntervalSeconds > 0 && (now - lastProcessCallAt) < ScriptManager.pythonProcessIntervalSeconds) {
            return null;
        }

        #if sys
        if (!active || path == null) return null;
        var fullPath = ModManager.getPath(path);
        try {
            lastProcessCallAt = now;
            var procArgs = ["python", fullPath, func];
            if (args != null) {
                for (a in args) procArgs.push(Std.string(a));
            }
            var proc = new Process(procArgs[0], procArgs.slice(1));
            var output = proc.stdout.readAll().toString();
            proc.close();
            var cleanOutput = output.trim();
            if (cleanOutput.length == 0) return null;
            try {
                return Json.parse(cleanOutput);
            } catch (_:Dynamic) {
                return cleanOutput;
            }
        } catch (e:Dynamic) {
            Logger.warn('Python execution notice in $func ($path): $e', "python");
        }
        #end
        return null;
    }

    public function set(key:String, value:Dynamic):Void {
        variables.set(key, value);
    }

    public function get(key:String):Dynamic {
        if (variables.exists(key)) return variables.get(key);
        if (pySprites.exists(key)) return pySprites.get(key);
        if (pyTexts.exists(key)) return pyTexts.get(key);
        return null;
    }

    public function importClass(className:String):Bool {
        if (className == null) return false;
        var resolvedClass:Dynamic = Type.resolveClass(className);
        if (resolvedClass != null) {
            set(className.substr(className.lastIndexOf(".") + 1), resolvedClass);
            return true;
        }
        return false;
    }

    public function destroy():Void {
        active = false;
        for (s in pySprites) s.destroy();
        for (txt in pyTexts) txt.destroy();
        pySprites.clear();
        pyTexts.clear();
        variables.clear();
    }
}