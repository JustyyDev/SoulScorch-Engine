package soulscorch.modding;

import flixel.FlxG;
#if sys
import sys.FileSystem;
#end

class GlobalScriptManager {
    public static var instance:GlobalScriptManager;
    public var activeScripts:Array<Script> = [];

    public function new() {
        if (instance != null) return;
        instance = this;
        scanGlobalScripts();
    }

    public function scanGlobalScripts():Void {
        #if sys
        var path = "mods/global_scripts/";
        if (FileSystem.exists(path)) {
            var files = FileSystem.readDirectory(path);
            for (file in files) {
                if (file.endsWith(".hx") || file.endsWith(".hscript")) {
                    var script = new Script(path + file);
                    if (script.active) {
                        activeScripts.push(script);
                        script.call("onGlobalInit", []);
                    }
                }
            }
        }
        #end
    }

    public function call(funcName:String, args:Array<Dynamic> = null):Void {
        if (args == null) args = [];
        for (script in activeScripts) {
            script.call(funcName, args);
        }
    }

    public function update(elapsed:Float):Void {
        call("onGlobalUpdate", [elapsed]);
    }
    
    public function onStateSwitch():Void {
        call("onStateSwitch", []);
    }
}