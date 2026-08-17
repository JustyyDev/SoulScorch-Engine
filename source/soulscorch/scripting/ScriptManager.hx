package soulscorch.scripting;

import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.utils.Logger;

#if sys
import sys.FileSystem;
#end

class ScriptManager {
    public static var instance:ScriptManager;
    public var scripts:Array<ScriptInstance> = [];

    public function new() {
        instance = this;
    }

    public function loadScript(path:String):ScriptInstance {
        var resolved = ModLoader.getPath(path);
        if (AssetResolver.exists(resolved)) {
            var script = new Script(resolved);
            if (script.active) {
                scripts.push(script);
                return script;
            }
        }
        return null;
    }

    public function loadScriptsFromDir(dirPath:String):Void {
        #if sys
        var resolved = ModLoader.getPath(dirPath);
        if (FileSystem.exists(resolved) && FileSystem.isDirectory(resolved)) {
            for (file in FileSystem.readDirectory(resolved)) {
                if (StringTools.endsWith(file, ".hx") || StringTools.endsWith(file, ".hscript")) {
                    loadScript(dirPath + "/" + file);
                }
            }
        }
        #end
    }

    public function set(name:String, value:Dynamic):Void {
        setAll(name, value);
    }

    public function setAll(name:String, value:Dynamic):Void {
        for (script in scripts) {
            if (script.active) {
                script.set(name, value);
            }
        }
    }

    public function call(func:String, ?args:Array<Dynamic>):Dynamic {
        return callAll(func, args);
    }

    public function callAll(func:String, ?args:Array<Dynamic>):Dynamic {
        if (args == null) args = [];
        var lastResult:Dynamic = null;

        for (script in scripts) {
            if (script.active) {
                var res = script.call(func, args);
                if (res != null) lastResult = res;
            }
        }
        return lastResult;
    }

    public function remove(script:ScriptInstance):Void {
        if (script == null) return;
        script.destroy();
        scripts.remove(script);
    }

    public function clear():Void {
        for (script in scripts) {
            script.destroy();
        }
        scripts = [];
    }

    public function destroy():Void {
        clear();
    }
}