package soulscorch.scripting;

import flixel.FlxG;
import flixel.math.FlxMath;
import flixel.util.FlxColor;
import hscript.Expr;
import hscript.Interp;
import hscript.Parser;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.system.EventBus;
import soulscorch.backend.system.engine.DevConsole;
import soulscorch.backend.system.engine.Engine;
import soulscorch.backend.system.engine.Runtime;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.ScriptInstance;
import soulscorch.scripting.mod.ModLoader;

using StringTools;

class Script implements ScriptInstance {
    public var active:Bool = false;
    public var path(default, null):String;

    public var interp:Interp;
    public var parser:Parser;
    public var ast:Expr;

    public function new(path:String, autoLoad:Bool = true) {
        this.path = path;
        interp = new Interp();
        parser = new Parser();

        parser.allowTypes = true;
        parser.allowJSON = true;
        parser.allowMetadata = true;

        setupGlobals();

        if (autoLoad) {
            load();
        }
    }

    public function setupGlobals():Void {
        set("Std", Std);
        set("Math", Math);
        set("StringTools", StringTools);
        #if sys set("Sys", Sys); #end

        set("FlxG", FlxG);
        set("FlxSprite", flixel.FlxSprite);
        set("FlxCamera", flixel.FlxCamera);
        set("FlxText", flixel.text.FlxText);
        set("FlxMath", flixel.math.FlxMath);
        set("FlxTween", flixel.tweens.FlxTween);
        set("FlxEase", flixel.tweens.FlxEase);
        set("FlxTimer", flixel.util.FlxTimer);
        set("FlxColor", {
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

        set("Runtime", Runtime);
        set("Conductor", Conductor);
        set("Paths", Paths);
        set("EventBus", EventBus);
        set("Logger", Logger);
        set("ModLoader", ModLoader);

        set("game", FlxG.state);
        set("state", FlxG.state);
    }

    public function load():Bool {
        if (path == null || path.trim().length == 0) {
            active = false;
            return false;
        }

        var fullPath = ModLoader.getPath(path.trim());
        if (!AssetResolver.exists(fullPath)) {
            active = false;
            return false;
        }

        try {
            var rawCode = AssetResolver.getText(fullPath);
            ast = parser.parseString(rawCode);
            interp.execute(ast);
            active = true;
            return true;
        } catch (e:Dynamic) {
            Logger.error('Script parse/runtime error in $path: $e', "script");
            if (DevConsole.instance != null) {
                DevConsole.instance.log('[SCRIPT ERROR] $path: ' + Std.string(e));
            }
            active = false;
            return false;
        }
    }

    public function set(key:String, value:Dynamic):Void {
        if (interp != null) {
            interp.variables.set(key, value);
        }
    }

    public function get(key:String):Dynamic {
        return (interp != null) ? interp.variables.get(key) : null;
    }

    public function call(func:String, ?args:Array<Dynamic>):Dynamic {
        if (!active || interp == null || !interp.variables.exists(func)) return null;

        var fn = interp.variables.get(func);
        if (fn != null && Reflect.isFunction(fn)) {
            try {
                return Reflect.callMethod(null, fn, (args != null) ? args : []);
            } catch (e:Dynamic) {
                Logger.error('Runtime error in script $func ($path): $e', "script");
            }
        }
        return null;
    }

    public function destroy():Void {
        active = false;
        if (interp != null) {
            interp.variables.clear();
            interp = null;
        }
        parser = null;
        ast = null;
    }
}