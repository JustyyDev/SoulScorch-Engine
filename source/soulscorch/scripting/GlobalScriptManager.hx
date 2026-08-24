package soulscorch.scripting;

import flixel.FlxG;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.backends.ScriptBackendType;
import soulscorch.scripting.mod.ModLoader;

#if sys
import sys.FileSystem;
#end

using StringTools;

class GlobalScriptManager {
    public static var instance(get, null):GlobalScriptManager;
    private static var _instance:GlobalScriptManager;

    public var activeScripts:Array<ScriptInstance> = [];
    private var _loadedPaths:Array<String> = [];
    private var _elapsedArgCache:Array<Dynamic> = [0.0];
    private var _stepArgCache:Array<Dynamic> = [0];
    private var _beatArgCache:Array<Dynamic> = [0];

    public function new() {
        _instance = this;
        scanGlobalScripts();
    }

    public static inline function get_instance():GlobalScriptManager {
        if (_instance == null) {
            _instance = new GlobalScriptManager();
        }
        return _instance;
    }

    public function scanGlobalScripts():Void {
        #if sys
        var searchPaths = [
            "assets/data/scripts/global",
            "assets/scripts/global",
            "mods/global_scripts"
        ];

        for (mod in ModLoader.activeMods) {
            searchPaths.push('mods/$mod/scripts/global');
            searchPaths.push('mods/$mod/global_scripts');
            searchPaths.push('mods/$mod/data/scripts');
        }

        for (path in searchPaths) {
            if (FileSystem.exists(path) && FileSystem.isDirectory(path)) {
                var files = FileSystem.readDirectory(path);
                for (file in files) {
                    var lower = file.toLowerCase();
                    if (lower.endsWith(".hx") || lower.endsWith(".hscript") || lower.endsWith(".soul") || lower.endsWith(".lua") || lower.endsWith(".py")) {
                        var fullPath = '$path/$file';
                        if (_loadedPaths.contains(fullPath)) continue;
                        if (!ScriptManager.isBackendEnabledForPath(fullPath)) continue;

                        var script:ScriptInstance = ScriptBackendType.createInstance(fullPath);
                        if (script != null && script.active) {
                            _loadedPaths.push(fullPath);
                            activeScripts.push(script);
                            script.set("isGlobal", true);
                            script.call("onGlobalInit", []);
                            script.call("create", []);
                            Logger.info('Global script loaded: $fullPath', "script");
                        }
                    }
                }
            }
        }
        #end
    }

    public function setAll(key:String, value:Dynamic):Void {
        for (script in activeScripts) {
            if (script != null && script.active) {
                script.set(key, value);
            }
        }
    }

    public function call(funcName:String, ?args:Array<Dynamic>):Dynamic {
        if (args == null) args = [];
        var lastResult:Dynamic = null;
        for (script in activeScripts) {
            if (script != null && script.active) {
                var res = script.call(funcName, args);
                if (res != null) lastResult = res;
            }
        }
        return lastResult;
    }

    public function update(elapsed:Float):Void {
        _elapsedArgCache[0] = elapsed;
        call("onGlobalUpdate", _elapsedArgCache);
        call("onUpdate", _elapsedArgCache);
        call("update", _elapsedArgCache);
    }

    public function onStateSwitch():Void {
        call("onPreStateSwitch", []);
        call("onStateSwitch", []);
    }

    public function stepHit(step:Int):Void {
        _stepArgCache[0] = step;
        call("onStepHit", _stepArgCache);
        call("stepHit", _stepArgCache);
    }

    public function beatHit(beat:Int):Void {
        _beatArgCache[0] = beat;
        call("onBeatHit", _beatArgCache);
        call("beatHit", _beatArgCache);
    }

    public function reload():Void {
        for (script in activeScripts) {
            if (script != null) script.destroy();
        }
        activeScripts = [];
        _loadedPaths = [];
        scanGlobalScripts();
    }
}