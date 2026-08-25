package soulscorch.scripting.backends;

import haxe.Json;
import haxe.Timer;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.ScriptInstance;
import soulscorch.scripting.ScriptManager;
import soulscorch.scripting.mod.ModManager;

#if sys
import sys.io.Process;
#end

using StringTools;

class JavaScriptScript implements ScriptInstance {
    public var active:Bool = false;
    public var path(default, null):String;

    private var variables:Map<String, Dynamic> = new Map<String, Dynamic>();
    private var lastProcessCallAt:Float = 0.0;

    public function new(scriptPath:String) {
        path = scriptPath != null ? scriptPath : "";
        load();
    }

    public function load():Bool {
        #if sys
        var resolved = ModManager.getPath(path);
        active = resolved != null && resolved.length > 0 && sys.FileSystem.exists(resolved);
        #else
        active = false;
        #end
        return active;
    }

    public function call(func:String, ?args:Array<Dynamic>):Dynamic {
        #if sys
        if (!active || func == null || func.length == 0) return null;
        var now = Timer.stamp();
        if ((func == "update" || func == "onUpdate" || func == "onUpdatePost") &&
            ScriptManager.pythonProcessIntervalSeconds > 0 &&
            now - lastProcessCallAt < ScriptManager.pythonProcessIntervalSeconds) return null;

        try {
            lastProcessCallAt = now;
            var resolved = ModManager.getPath(path);
            var payload = {
                callback: func,
                args: args != null ? args : [],
                context: {
                    scriptPath: path,
                    scriptBackend: "javascript"
                }
            };
            var proc = new Process("node", [resolved, func, Json.stringify(payload)]);
            var output = proc.stdout.readAll().toString().trim();
            proc.close();
            if (output.length == 0) return null;
            try return Json.parse(output) catch (_:Dynamic) return output;
        } catch (e:Dynamic) {
            Logger.warn('JavaScript execution notice in $func ($path): $e', "javascript");
        }
        #end
        return null;
    }

    public function set(key:String, value:Dynamic):Void {
        variables.set(key, value);
    }

    public function get(key:String):Dynamic {
        return variables.exists(key) ? variables.get(key) : null;
    }

    public function importClass(className:String):Bool {
        return false;
    }

    public function destroy():Void {
        active = false;
        variables.clear();
    }
}
