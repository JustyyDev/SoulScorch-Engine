package soulscorch.scripting;

import flixel.FlxG;
import flixel.FlxSprite;
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
        interp.scriptPath = path;

        setupGlobals();

        if (autoLoad) {
            load();
        }
    }

    public function setupGlobals():Void {
        // Core Haxe Types
        set("Std", Std);
        set("Math", Math);
        set("StringTools", StringTools);
        set("Date", Date);
        #if sys set("Sys", Sys); #end

        // Flixel Core & Hierarchy
        set("FlxG", FlxG);
        set("FlxSprite", flixel.FlxSprite);
        set("FlxBasic", flixel.FlxBasic);
        set("FlxCamera", flixel.FlxCamera);
        set("FlxObject", flixel.FlxObject);
        set("FlxGroup", flixel.group.FlxGroup);
        set("FlxTypedGroup", flixel.group.FlxGroup.FlxTypedGroup);
        set("FlxSpriteGroup", flixel.group.FlxSpriteGroup);
        set("FlxText", flixel.text.FlxText);

        // Flixel Tweens, Timers & Math
        set("FlxMath", flixel.math.FlxMath);
        set("FlxTimer", flixel.util.FlxTimer);
        set("FlxTween", flixel.tweens.FlxTween);
        set("FlxEase", flixel.tweens.FlxEase);
        set("FlxColor", flixel.util.FlxColor);

        // Flixel Audio
        set("FlxSound", flixel.sound.FlxSound);
        set("FlxSoundGroup", flixel.sound.FlxSoundGroup);

        // SoulScorch Backend Systems
        set("Runtime", Runtime.engine);
        set("Engine", soulscorch.backend.system.engine.Engine.instance);
        set("Conductor", Conductor);
        set("Paths", Paths);
        set("EventBus", EventBus);
        set("Logger", Logger);
        set("ModLoader", ModLoader);
        set("ModManager", ModLoader);
        set("script", this);
        set("scriptPath", path);

        #if desktop
        set("Discord", soulscorch.backend.system.modules.discord.DiscordRPC);
        #end
    }

    public function load():Bool {
        if (path == null || StringTools.trim(path).length == 0) {
            active = false;
            return false;
        }

        var fullPath = ModLoader.getPath(StringTools.trim(path));
        if (fullPath == null || fullPath.length == 0 || StringTools.endsWith(fullPath, "/")) {
            active = false;
            return false;
        }

        if (!AssetResolver.exists(fullPath)) {
            active = false;
            return false;
        }

        try {
            var code = AssetResolver.getText(fullPath);
            ast = parser.parseString(code);
            interp.execute(ast);
            active = true;
            return true;
        } catch (e:Dynamic) {
            Logger.error('Script parse/execute error in $path: $e', "script");
            if (DevConsole.instance != null) {
                DevConsole.instance.log('[HSCRIPT ERROR] $path: ' + Std.string(e));
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
        if (interp != null) {
            return interp.variables.get(key);
        }
        return null;
    }

    public function call(func:String, ?args:Array<Dynamic>):Dynamic {
        if (!active || interp == null || !interp.variables.exists(func)) return null;

        var fn = interp.variables.get(func);
        if (fn != null && Reflect.isFunction(fn)) {
            try {
                return Reflect.callMethod(null, fn, (args != null) ? args : []);
            } catch (e:Dynamic) {
                Logger.error('Runtime error executing $func in $path: $e', "script");
                if (DevConsole.instance != null) {
                    DevConsole.instance.log('[HSCRIPT RUNTIME] $path ($func): ' + Std.string(e));
                }
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