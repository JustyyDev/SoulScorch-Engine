package soulscorch.scripting.backends;

import flixel.FlxG;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.ScriptInstance;
import soulscorch.scripting.mod.ModManager;

#if sys
import sys.io.Process;
#end

using StringTools;

class PythonScript implements ScriptInstance {
    public var active:Bool = false;
    public var path(default, null):String;
    private var variables:Map<String, Dynamic> = new Map<String, Dynamic>();

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
        active = true;
        call("onCreate", []);
        return true;
    }

    public function call(func:String, ?args:Array<Dynamic>):Dynamic {
        #if sys
        if (!active || path == null) return null;
        var fullPath = ModManager.getPath(path);
        try {
            var procArgs = ["python", fullPath, func];
            if (args != null) {
                for (a in args) procArgs.push(Std.string(a));
            }
            var proc = new Process(procArgs[0], procArgs.slice(1));
            var output = proc.stdout.readAll().toString();
            proc.close();
            return output.trim();
        } catch (e:Dynamic) {
            Logger.warn('Python execution warning in $func ($path): $e', "python");
        }
        #end
        return null;
    }

    public function set(key:String, value:Dynamic):Void {
        variables.set(key, value);
    }

    public function get(key:String):Dynamic {
        return variables.get(key);
    }

    public function destroy():Void {
        active = false;
        call("onDestroy", []);
        variables.clear();
    }
}