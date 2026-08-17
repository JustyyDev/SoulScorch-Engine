package soulscorch.scripting.soul;

package soulscorch.scripting.soul;

import flixel.FlxG;
import flixel.math.FlxMath;
import hscript.Expr;
import hscript.Interp;
import hscript.Parser;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.system.EventBus;
import soulscorch.backend.system.engine.DevConsole;
import soulscorch.backend.system.engine.Runtime;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.ModLoader;
import soulscorch.scripting.ScriptInstance;

class SoulScript implements ScriptInstance {
    public var active:Bool = false;
    public var path(default, null):String;

    public var interp:Interp;
    public var parser:Parser;
    public var ast:Expr;
    public var transpiledCode:String = "";

    public function new(path:String, autoLoad:Bool = true) {
        this.path = path;
        interp = new Interp();
        parser = new Parser();

        parser.allowTypes = true;
        parser.allowJSON = true;
        parser.allowMetadata = true;
        interp.scriptPath = path;

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
        set("FlxColor", flixel.util.FlxColor);

        set("Runtime", Runtime.engine);
        set("Conductor", Conductor);
        set("Paths", Paths);
        set("EventBus", EventBus);
        set("Logger", Logger);
        set("ModLoader", ModLoader);

        set("game", FlxG.state);
        set("state", FlxG.state);
    }

    public function load():Bool {
        if (path == null || StringTools.trim(path).length == 0) {
            active = false;
            return false;
        }

        var fullPath = ModLoader.getPath(StringTools.trim(path));
        if (!AssetResolver.exists(fullPath)) {
            active = false;
            return false;
        }

        try {
            var rawSoulCode = AssetResolver.getText(fullPath);
            transpiledCode = SoulScriptParser.transpile(rawSoulCode);
            ast = parser.parseString(transpiledCode);
            interp.execute(ast);
            active = true;
            return true;
        } catch (e:Dynamic) {
            Logger.error('SoulScript transpile/runtime error in $path: $e', "soulscript");
            if (DevConsole.instance != null) {
                DevConsole.instance.log('[SOULSCRIPT ERROR] $path: ' + Std.string(e));
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
                Logger.error('Runtime error in SoulScript $func ($path): $e', "soulscript");
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