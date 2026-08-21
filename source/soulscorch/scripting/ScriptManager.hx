package soulscorch.scripting;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import hscript.Expr;
import hscript.Interp;
import hscript.Parser;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.utils.Logger;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

class ScriptManager {
    public var interp:Interp;
    public var parser:Parser;
    public var isValid:Bool = false;
    public var scriptPath:String = "";

    public function new() {
        parser = new Parser();
        parser.allowTypes = true;
        parser.allowJSON = true;
        parser.allowMetadata = true;

        interp = new Interp();
        initDefaultVariables();
    }

    private function initDefaultVariables():Void {
        // Native System & Math Reflection
        interp.variables.set("Std", Std);
        interp.variables.set("Math", Math);
        interp.variables.set("StringTools", StringTools);
        interp.variables.set("Reflect", Reflect);
        interp.variables.set("Type", Type);

        // Engine Core
        interp.variables.set("Paths", Paths);
        interp.variables.set("Conductor", Conductor);
        interp.variables.set("FlxG", FlxG);
        interp.variables.set("FlxSprite", FlxSprite);
        interp.variables.set("FlxText", FlxText);
        interp.variables.set("FlxMath", FlxMath);
        interp.variables.set("FlxTween", FlxTween);
        interp.variables.set("FlxEase", FlxEase);
        interp.variables.set("FlxTimer", FlxTimer);
        interp.variables.set("FlxPoint", {
            get: function(?x:Float = 0, ?y:Float = 0) return FlxPoint.get(x, y),
            weak: function(?x:Float = 0, ?y:Float = 0) return FlxPoint.weak(x, y)
        });
        interp.variables.set("FlxColor", {
            WHITE: 0xFFFFFFFF,
            BLACK: 0xFF000000,
            RED: 0xFFFF0000,
            GREEN: 0xFF00FF00,
            BLUE: 0xFF0000FF,
            YELLOW: 0xFFFFFF00,
            CYAN: 0xFF00FFFF,
            MAGENTA: 0xFFFF00FF,
            TRANSPARENT: 0x00000000,
            fromString: function(str:String) return FlxColor.fromString(str),
            fromRGB: function(r:Int, g:Int, b:Int, a:Int = 255) return FlxColor.fromRGB(r, g, b, a)
        });
    }

    public function loadScript(path:String):Bool {
        this.scriptPath = path;
        var rawContent:String = null;

        var resolved = AssetResolver.resolveFile(path, [".soul", ".hx", ".hscript", ""]);
        if (resolved != null) {
            rawContent = AssetResolver.getText(resolved);
        }

        #if sys
        if (rawContent == null && FileSystem.exists(path)) {
            try { rawContent = File.getContent(path); } catch(e:Dynamic) {}
        }
        #end

        if (rawContent == null || rawContent.trim().length == 0) {
            Logger.warn('Could not locate script at: $path', "script");
            return false;
        }

        try {
            var expr:Expr = parser.parseString(rawContent, path);
            interp.execute(expr);
            isValid = true;
            return true;
        } catch (e:Dynamic) {
            Logger.error('Failed to initialize SoulScript ($path): $e', "soulscript");
            isValid = false;
            return false;
        }
    }

    public function setAll(key:String, val:Dynamic):Void {
        interp.variables.set(key, val);
    }

    public function get(key:String):Dynamic {
        return interp.variables.get(key);
    }

    public function callAll(func:String, ?args:Array<Dynamic>):Dynamic {
        if (!isValid) return null;
        if (args == null) args = [];

        var fn = interp.variables.get(func);
        if (fn != null && Reflect.isFunction(fn)) {
            try {
                return Reflect.callMethod(null, fn, args);
            } catch (e:Dynamic) {
                Logger.error('Runtime error in [$scriptPath] -> $func(): $e', "soulscript");
            }
        }
        return null;
    }

    public function clear():Void {
        interp.variables.clear();
        isValid = false;
    }
}