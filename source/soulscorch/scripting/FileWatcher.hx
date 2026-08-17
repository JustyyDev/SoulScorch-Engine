package soulscorch.scripting;

import flixel.FlxG;
import haxe.ds.StringMap;
import haxe.io.Path;
import soulscorch.backend.system.EventBus;
import soulscorch.backend.system.engine.DevConsole;
import soulscorch.backend.utils.Logger;

#if sys
import sys.FileSystem;
#end

typedef WatchTarget = {
    var path:String;
    var lastModified:Float;
}

class FileWatcher {
    public static var instance(get, null):FileWatcher;
    private static var _instance:FileWatcher;

    var targets:StringMap<WatchTarget> = new StringMap<WatchTarget>();
    var checkInterval:Float = 0.5;
    var timer:Float = 0.0;
    public var autoTrackMods:Bool = true;

    public function new() {
        _instance = this;
    }

    public static inline function get_instance():FileWatcher {
        if (_instance == null) {
            _instance = new FileWatcher();
        }
        return _instance;
    }

    public function update(elapsed:Float):Void {
        #if sys
        timer += elapsed;
        if (timer >= checkInterval) {
            timer = 0.0;
            if (autoTrackMods) scanActiveMods();
            checkModifications();
        }
        #end
    }

    #if sys
    function scanActiveMods():Void {
        for (mod in ModLoader.activeMods) {
            var modDir = Path.join(["mods", mod]);
            scanDirectory(modDir);
        }
    }

    function scanDirectory(dir:String):Void {
        if (!FileSystem.exists(dir)) return;

        var files = FileSystem.readDirectory(dir);
        for (file in files) {
            var path = Path.join([dir, file]);
            if (FileSystem.isDirectory(path)) {
                scanDirectory(path);
            } else if (StringTools.endsWith(path, ".hx") || StringTools.endsWith(path, ".xml") || StringTools.endsWith(path, ".json")) {
                var stat = FileSystem.stat(path);
                var lastMod = stat.mtime.getTime();

                if (!targets.exists(path)) {
                    targets.set(path, {path: path, lastModified: lastMod});
                }
            }
        }
    }

    function checkModifications():Void {
        for (key in targets.keys()) {
            var target = targets.get(key);
            if (FileSystem.exists(target.path)) {
                var currentModified = FileSystem.stat(target.path).mtime.getTime();
                if (currentModified > target.lastModified) {
                    target.lastModified = currentModified;
                    onFileChanged(target.path);
                }
            }
        }
    }
    #end

    private function onFileChanged(path:String):Void {
        Logger.info('Hot-Reload modification detected: $path', "hotreload");

        if (DevConsole.instance != null) {
            DevConsole.instance.log('[HOT-RELOAD] Modification detected: ' + path);
        }

        EventBus.emit("script/modified", {path: path});

        if (Std.isOfType(FlxG.state, ScriptedState)) {
            var currentState:ScriptedState = cast FlxG.state;
            FlxG.switchState(new ScriptedState(currentState.scriptName));
        }
    }

    public function clear():Void {
        targets.clear();
    }
}