package soulscorch.modding;

#if sys
import sys.FileSystem;
#end
import soulscorch.assets.AssetResolver;

class ScriptManager {
    public var scripts:Array<Script> = [];

    public function new() {}

    public function loadScript(path:String):Script {
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
        for (script in scripts) {
            if (script.active) {
                script.set(name, value);
            }
        }
    }

    public function call(func:String, ?args:Array<Dynamic>):Dynamic {
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