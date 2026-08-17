package soulscorch.scripting;

import flixel.FlxG;
import soulscorch.backend.utils.Logger;

#if sys
import sys.FileSystem;
#end

class GlobalScriptManager {
    public static var instance(get, null):GlobalScriptManager;
    private static var _instance:GlobalScriptManager;

    public var activeScripts:Array<ScriptInstance> = [];

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
            "mods/global_scripts"
        ];

        for (mod in ModLoader.activeMods) {
            searchPaths.push('mods/$mod/scripts/global');
            searchPaths.push('mods/$mod/global_scripts');
        }

        for (path in searchPaths) {
            if (FileSystem.exists(path) && FileSystem.isDirectory(path)) {
                var files = FileSystem.readDirectory(path);
                for (file in files) {
                    if (StringTools.endsWith(file, ".hx") || StringTools.endsWith(file, ".hscript")) {
                        var fullPath = '$path/$file';
                        var script = new Script(fullPath);
                        if (script.active) {
                            activeScripts.push(script);
                            script.call("onGlobalInit", []);
                            Logger.info('Global script loaded: $fullPath', "script");
                        }
                    }
                }
            }
        }
        #end
    }

    public function call(funcName:String, ?args:Array<Dynamic>):Void {
        if (args == null) args = [];
        for (script in activeScripts) {
            if (script.active) {
                script.call(funcName, args);
            }
        }
    }

    public function update(elapsed:Float):Void {
        call("onGlobalUpdate", [elapsed]);
    }

    public function onStateSwitch():Void {
        call("onStateSwitch", []);
    }

    public function reload():Void {
        for (script in activeScripts) {
            script.destroy();
        }
        activeScripts = [];
        scanGlobalScripts();
    }
}