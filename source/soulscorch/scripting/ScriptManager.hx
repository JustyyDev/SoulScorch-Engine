package soulscorch.scripting;

import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.ScriptInstance;
import soulscorch.scripting.backends.ScriptBackendType;
import soulscorch.scripting.mod.ModLoader;

#if sys
import sys.FileSystem;
#end

using StringTools;

class ScriptManager {
    public var scripts:Array<ScriptInstance> = [];

    public function new() {}

    public function loadScript(path:String):Null<ScriptInstance> {
        var resolved = ModLoader.getPath(path);
        if (!AssetResolver.exists(resolved)) return null;

        var instance = ScriptBackendType.createInstance(resolved);
        if (instance != null) {
            scripts.push(instance);
        }
        return instance;
    }

    public function loadDirectory(dirPath:String):Void {
        var resolved = ModLoader.getPath(dirPath);
        #if sys
        if (FileSystem.exists(resolved) && FileSystem.isDirectory(resolved)) {
            for (file in FileSystem.readDirectory(resolved)) {
                if (file.endsWith(".hx") || file.endsWith(".soul") || file.endsWith(".lua")) {
                    loadScript('$resolved/$file');
                }
            }
        }
        #end
    }

    public function callAll(func:String, ?args:Array<Dynamic>):Void {
        for (s in scripts) {
            if (s.active) {
                s.call(func, args);
            }
        }
    }

    public function setAll(key:String, value:Dynamic):Void {
        for (s in scripts) {
            s.set(key, value);
        }
    }

    public function clear():Void {
        for (s in scripts) {
            s.destroy();
        }
        scripts = [];
    }
}