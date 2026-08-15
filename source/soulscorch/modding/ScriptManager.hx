package soulscorch.modding;

import hscript.Parser;
import hscript.Interp;
import soulscorch.assets.AssetResolver;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.math.FlxMath;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxTimer;
import soulscorch.gameplay.PlayState;
import soulscorch.gameplay.Conductor;
import soulscorch.gameplay.Character;
import soulscorch.core.Runtime;

class Script {
    public var interp:Interp;
    public var parser:Parser;
    public var scriptName:String;
    public var active:Bool = true;

    public function new(path:String) {
        scriptName = path;
        interp = new Interp();
        parser = new Parser();
        
        parser.allowTypes = true;
        parser.allowJSON = true;
        parser.allowMetadata = true;

        preset();

        if (AssetResolver.exists(path)) {
            try {
                var scriptText = AssetResolver.getText(path);
                var expr = parser.parseString(scriptText, scriptName);
                interp.execute(expr);
            } catch (e:Dynamic) {
                Sys.println('HScript Error ($scriptName): $e');
                active = false;
            }
        } else {
            active = false;
        }
    }
    
    public function preset():Void {
        set("FlxG", FlxG);
        set("FlxSprite", FlxSprite);
        set("FlxMath", FlxMath);
        set("FlxTween", FlxTween);
        set("FlxEase", FlxEase);
        set("FlxTimer", FlxTimer);
        set("Std", Std);
        set("Math", Math);
        set("Sys", Sys);
        set("StringTools", StringTools);
        set("PlayState", PlayState);
        set("Conductor", Conductor);
        set("Character", Character);
        set("Runtime", Runtime);
        
        if (FlxG.state != null) {
            set("add", FlxG.state.add);
            set("remove", FlxG.state.remove);
            set("insert", FlxG.state.insert);
        }
    }

    public function set(name:String, value:Dynamic):Void {
        interp.variables.set(name, value);
    }

    public function get(name:String):Dynamic {
        return interp.variables.get(name);
    }

    public function call(funcName:String, args:Array<Dynamic>):Dynamic {
        if (!active || !interp.variables.exists(funcName)) return null;
        
        var func = interp.variables.get(funcName);
        if (Reflect.isFunction(func)) {
            try {
                return Reflect.callMethod(null, func, args);
            } catch (e:Dynamic) {
                Sys.println('HScript Call Error ($scriptName - $funcName): $e');
            }
        }
        return null;
    }
    
    public function destroy():Void {
        interp = null;
        parser = null;
        active = false;
    }
}

class ScriptManager {
    public var scripts:Array<Script> = [];

    public function new() {}

    public function loadScript(path:String):Script {
        var script = new Script(path);
        if (script.active) {
            scripts.push(script);
            script.call("onCreate", []);
        }
        return script;
    }

    public function set(name:String, value:Dynamic):Void {
        for (script in scripts) {
            script.set(name, value);
        }
    }

    public function call(funcName:String, args:Array<Dynamic> = null):Void {
        if (args == null) args = [];
        for (script in scripts) {
            script.call(funcName, args);
        }
    }
    
    public function destroy():Void {
        for (script in scripts) {
            script.destroy();
        }
        scripts = [];
    }
}