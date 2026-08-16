package soulscorch.modding;

import flixel.FlxG;
import haxe.ds.StringMap;
#if sys
import sys.FileSystem;
import sys.io.File;
import haxe.io.Path;
#end

typedef WatchTarget = {
    var path:String;
    var lastModified:Float;
}

class FileWatcher {
    public static var instance:FileWatcher;

    var targets:StringMap<WatchTarget> = new StringMap<WatchTarget>();
    var checkInterval:Float = 0.5;
    var timer:Float = 0.0;
    var autoTrackMods:Bool = true;

    public function new() {
        instance = this;
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
        for (mod in ModManager.activeMods) {
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
            } else if (StringTools.endsWith(path, ".hx") || StringTools.endsWith(path, ".xml")) {
                var stat = FileSystem.stat(path);
                var lastMod = stat.mtime.getTime();

                // Add to tracker if it's a newly created file
                if (!targets.exists(path)) {
                    targets.set(path, { path: path, lastModified: lastMod });
                }
            }
        }
    }
    #end

    function checkModifications():Void {
        #if sys
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
        #end
    }

    private function onFileChanged(path:String):Void {
        if (soulscorch.ui.DevConsole.instance != null) {
            soulscorch.ui.DevConsole.instance.log('[HOT-RELOAD] Modification detected: ' + path);
        }
        
        // Soft-restart ModState to apply new script/XML changes instantly
        if (Std.isOfType(FlxG.state, soulscorch.modding.ModState)) {
            var currentState:soulscorch.modding.ModState = cast FlxG.state;
            FlxG.switchState(new soulscorch.modding.ModState(currentState.stateName, currentState.script.scriptName));
        }
    }

    public function clear():Void {
        targets.clear();
    }
}