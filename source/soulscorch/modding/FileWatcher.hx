package soulscorch.modding;

#if sys
import sys.FileSystem;
import sys.io.File;
import haxe.ds.StringMap;

typedef WatchTarget = {
    var path:String;
    var lastModified:Float;
    var callback:String->Void;
    var isDirectory:Bool;
}

class FileWatcher {
    public static var instance:FileWatcher;

    var targets:StringMap<WatchTarget> = new StringMap<WatchTarget>();
    var checkInterval:Float = 0.5;
    var timer:Float = 0.0;

    public function new() {
        instance = this;
    }

    public function watchFile(filePath:String, onModified:String->Void):Void {
        var resolved = ModLoader.getPath(filePath);
        if (FileSystem.exists(resolved) && !FileSystem.isDirectory(resolved)) {
            var stat = FileSystem.stat(resolved);
            targets.set(resolved, {
                path: resolved,
                lastModified: stat.mtime.getTime(),
                callback: onModified,
                isDirectory: false
            });
        }
    }

    public function watchDirectory(dirPath:String, onModified:String->Void):Void {
        var resolved = ModLoader.getPath(dirPath);
        if (FileSystem.exists(resolved) && FileSystem.isDirectory(resolved)) {
            var stat = FileSystem.stat(resolved);
            targets.set(resolved, {
                path: resolved,
                lastModified: stat.mtime.getTime(),
                callback: onModified,
                isDirectory: true
            });
        }
    }

    public function update(elapsed:Float):Void {
        timer += elapsed;
        if (timer >= checkInterval) {
            timer = 0.0;
            checkModifications();
        }
    }

    function checkModifications():Void {
        for (key in targets.keys()) {
            var target = targets.get(key);
            if (FileSystem.exists(target.path)) {
                var currentModified = FileSystem.stat(target.path).mtime.getTime();
                if (currentModified > target.lastModified) {
                    target.lastModified = currentModified;
                    Sys.println('[HOT-RELOAD] Detected modification in: ' + target.path);
                    if (target.callback != null) {
                        target.callback(target.path);
                    }
                }
            }
        }
    }

    public function clear():Void {
        targets.clear();
    }
}
#else
class FileWatcher {
    public static var instance:FileWatcher;
    public function new() { instance = this; }
    public function watchFile(filePath:String, onModified:String->Void):Void {}
    public function watchDirectory(dirPath:String, onModified:String->Void):Void {}
    public function update(elapsed:Float):Void {}
    public function clear():Void {}
}
#end