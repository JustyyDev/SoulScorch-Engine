package soulscorch.scripting;

import flixel.FlxBasic;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.backends.ScriptBackendType;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

class ScriptManager {
    public static var instance:ScriptManager;
    public var scripts:Array<ScriptInstance> = [];
    public var scriptPath:String = "";
    
    // Cached global variable dictionary to inject into any new script
    public var presetVariables:Map<String, Dynamic> = new Map<String, Dynamic>();

    public var isValid(get, never):Bool;
    public var active(get, never):Bool;

    inline function get_isValid():Bool {
        return scripts.length > 0 && scripts[0].active;
    }

    inline function get_active():Bool {
        return isValid;
    }

    public function new() {
        instance = this;
    }

    public function loadScript(path:String):Bool {
        this.scriptPath = path;
        var resolved = AssetResolver.resolveFile(path, [".soul", ".hx", ".hscript", ".lua", ".py", ".js", ""]);
        var finalPath = (resolved != null) ? resolved : path;

        var backendType = ScriptBackendType.fromPath(finalPath);

        // If it is explicitly a Lua script, load it via LuaScript backend only
        if (backendType == ScriptBackendType.LUA) {
            var luaInst = new soulscorch.scripting.backends.LuaScript(finalPath);
            for (key => val in presetVariables) {
                luaInst.set(key, val);
            }
            if (luaInst.active) {
                scripts.push(luaInst);
                return true;
            } else {
                Logger.error('Failed to activate Lua script backend for: $finalPath', "script");
                return false;
            }
        }

        // Standard HScript / SoulScript fallback path for non-Lua files
        var inst = ScriptBackendType.createInstance(finalPath);
        if (inst != null) {
            for (key => val in presetVariables) {
                inst.set(key, val);
            }
            if (inst.active) {
                scripts.push(inst);
                return true;
            }
        }

        var script = new Script(finalPath, false);
        for (key => val in presetVariables) {
            script.set(key, val);
        }
        
        if (script.load()) {
            scripts.push(script);
            return true;
        }

        return false;
    }

    public function importClass(className:String):Bool {
        var success = false;
        for (s in scripts) {
            if (s != null && s.active) {
                if (s.importClass(className)) {
                    success = true;
                }
            }
        }
        return success;
    }

    public function setAll(key:String, val:Dynamic):Void {
        presetVariables.set(key, val);
        for (s in scripts) {
            if (s != null && s.active) s.set(key, val);
        }
    }

    public function get(key:String):Dynamic {
        for (s in scripts) {
            if (s != null && s.active) {
                var v = s.get(key);
                if (v != null) return v;
            }
        }
        if (presetVariables.exists(key)) return presetVariables.get(key);
        return null;
    }

    public function callAll(func:String, ?args:Array<Dynamic>):Dynamic {
        if (args == null) args = [];
        var lastResult:Dynamic = null;
        for (s in scripts) {
            if (s != null && s.active) {
                var res = s.call(func, args);
                if (res != null) lastResult = res;
            }
        }
        return lastResult;
    }

    public function clear():Void {
        for (s in scripts) {
            if (s != null) s.destroy();
        }
        scripts = [];
        presetVariables.clear();
    }
}