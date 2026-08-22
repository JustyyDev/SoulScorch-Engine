package soulscorch.scripting;

import haxe.io.Path;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.system.EventBus;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.mod.ModLoader;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

class FileWatcher {
    private var fileTimestamps:Map<String, Float> = new Map();
    private var watchedDirectories:Array<String> = [];
    private var checkTimer:Float = 0.0;
    public var checkInterval:Float = 0.5;

    public function new() {
        refreshWatchedDirectories();
        scanInitialTimestamps();
    }

    public function refreshWatchedDirectories():Void {
        watchedDirectories = [
            "assets/scripts",
            "assets/data",
            "assets/songs",
            "assets/data/scripts/global",
            "mods/global_scripts"
        ];

        #if sys
        for (mod in ModLoader.activeMods) {
            watchedDirectories.push('mods/$mod/scripts');
            watchedDirectories.push('mods/$mod/data');
            watchedDirectories.push('mods/$mod/songs');
            watchedDirectories.push('mods/$mod/scripts/global');
            watchedDirectories.push('mods/$mod/global_scripts');
            watchedDirectories.push('mods/$mod/data/states');
            watchedDirectories.push('mods/$mod/data/substates');
            watchedDirectories.push('mods/$mod/data/ui');
        }
        #end
    }

    private function scanInitialTimestamps():Void {
        #if sys
        for (dir in watchedDirectories) {
            scanDirectory(dir, false);
        }
        #end
    }

    public function update(elapsed:Float):Void {
        #if sys
        checkTimer += elapsed;
        if (checkTimer >= checkInterval) {
            checkTimer = 0.0;
            for (dir in watchedDirectories) {
                scanDirectory(dir, true);
            }
        }
        #end
    }

    #if sys
    private function scanDirectory(path:String, notifyOnChange:Bool):Void {
        if (!FileSystem.exists(path) || !FileSystem.isDirectory(path)) return;

        var entries = FileSystem.readDirectory(path);
        for (entry in entries) {
            var fullPath = Path.join([path, entry]);
            if (FileSystem.isDirectory(fullPath)) {
                scanDirectory(fullPath, notifyOnChange);
            } else {
                var stat = FileSystem.stat(fullPath);
                var mtime = stat.mtime.getTime();

                if (!fileTimestamps.exists(fullPath)) {
                    fileTimestamps.set(fullPath, mtime);
                } else if (fileTimestamps.get(fullPath) != mtime) {
                    fileTimestamps.set(fullPath, mtime);
                    if (notifyOnChange) {
                        onFileModified(fullPath);
                    }
                }
            }
        }
    }

    private function onFileModified(filePath:String):Void {
        Logger.info('HotReload detected change in: $filePath', "watcher");
        EventBus.publish("script/modified", {path: filePath});
    }
    #end
}