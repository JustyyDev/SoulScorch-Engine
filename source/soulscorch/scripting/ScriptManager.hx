package soulscorch.scripting;

import haxe.io.Path;
import soulscorch.modding.ModLoader;
import soulscorch.scripting.backends.HScriptIris;
import soulscorch.scripting.backends.LuaScript;
import soulscorch.scripting.soul.SoulScriptParser;
import soulscorch.backend.localization.LanguageManager;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

class ScriptManager {
    public static var instance:ScriptManager;

    public var scripts:Array<ScriptInstance> = [];
    public var globals:Map<String, Dynamic> = new Map();
    private var timestamps:Map<String, Float> = new Map();

    public function new() {
        instance = this;
    }

    public function load(path:String):ScriptInstance {
        if (path == null || path.length == 0) return null;

        var resolved:String = ModLoader.getPath(path);
        if (resolved == null) resolved = path;

        var ext:String = Path.extension(resolved).toLowerCase();
        var script:ScriptInstance = null;

        switch (ext) {
            case "lua":
                script = new LuaScript(resolved);
            case "soul", "ss":
                #if sys
                if (FileSystem.exists(resolved)) {
                    var transpiled:String = SoulScriptParser.transpile(File.getContent(resolved));
                    script = new HScriptIris(resolved, transpiled);
                }
                #end
            default:
                script = new HScriptIris(resolved);
        }

        if (script == null) return null;

        for (name in globals.keys()) {
            script.set(name, globals.get(name));
        }

        if (script.active) {
            scripts.push(script);
            rememberTimestamp(resolved);
            return script;
        }

        script.destroy();
        return null;
    }

    public function loadDirectory(path:String):Void {
        #if sys
        var resolved:String = ModLoader.getPath(path);
        if (resolved == null || !FileSystem.exists(resolved) || !FileSystem.isDirectory(resolved)) return;

        for (file in FileSystem.readDirectory(resolved)) {
            var ext:String = Path.extension(file).toLowerCase();
            if (ext == "hx" || ext == "hscript" || ext == "lua" || ext == "soul" || ext == "ss") {
                load(path + "/" + file);
            }
        }
        #end
    }

    public function dispatch(event:String, ?args:Array<Dynamic>):Void {
        var i:Int = scripts.length - 1;
        while (i >= 0) {
            var script = scripts[i];
            if (script == null || !script.active) {
                if (script != null) script.destroy();
                scripts.splice(i, 1);
            } else {
                script.call(event, args);
            }
            i--;
        }
    }

    public function setGlobal(name:String, value:Dynamic):Void {
        globals.set(name, value);
        for (script in scripts) {
            if (script != null && script.active) {
                script.set(name, value);
            }
        }
    }

    public function updateHotReload():Void {
        #if sys
        var reload:Array<String> = [];
        for (script in scripts) {
            if (script != null && script.active && FileSystem.exists(script.path)) {
                var time:Float = FileSystem.stat(script.path).mtime.getTime();
                if (timestamps.exists(script.path) && timestamps.get(script.path) != time) {
                    reload.push(script.path);
                } else {
                    timestamps.set(script.path, time);
                }
            }
        }

        for (path in reload) {
            var i:Int = scripts.length - 1;
            while (i >= 0) {
                if (scripts[i].path == path) {
                    scripts[i].destroy();
                    scripts.splice(i, 1);
                    break;
                }
                i--;
            }
            load(path);
        }
        #end
    }

    public function clear():Void {
        for (script in scripts) {
            if (script != null) script.destroy();
        }
        scripts = [];
        timestamps.clear();
    }

    private function rememberTimestamp(path:String):Void {
        #if sys
        if (FileSystem.exists(path)) {
            timestamps.set(path, FileSystem.stat(path).mtime.getTime());
        }
        #end
    }
}