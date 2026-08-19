package soulscorch.backend.system.apis;

import haxe.io.Path;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.mod.ModManager;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

class FileSystemAPI {
    public static function saveModData(modName:String, fileName:String, data:String):Bool {
        if (modName == null || fileName == null) return false;

        #if sys
        try {
            var modDir = Path.join(["mods", modName, "data"]);
            if (!FileSystem.exists(modDir)) {
                FileSystem.createDirectory(modDir);
            }
            
            var fullPath = Path.join([modDir, fileName]);
            File.saveContent(fullPath, data != null ? data : "");
            return true;
        } catch (e:Dynamic) {
            Logger.error('Failed saving mod data to $fileName: $e', "io");
            return false;
        }
        #else
        return false;
        #end
    }

    public static function readModData(modName:String, fileName:String):Null<String> {
        if (modName == null || fileName == null) return null;

        #if sys
        var fullPath = Path.join(["mods", modName, "data", fileName]);
        if (FileSystem.exists(fullPath) && !FileSystem.isDirectory(fullPath)) {
            try {
                return File.getContent(fullPath);
            } catch (e:Dynamic) {
                Logger.error('Failed reading mod data from $fullPath: $e', "io");
            }
        }
        #end
        return null;
    }

    public static function readDirectory(path:String):Array<String> {
        if (path == null) return [];

        #if sys
        var resolved = ModManager.getPath(path);
        var target = (resolved != null && FileSystem.exists(resolved)) ? resolved : path;

        if (FileSystem.exists(target) && FileSystem.isDirectory(target)) {
            return FileSystem.readDirectory(target);
        }
        #end
        return [];
    }

    public static function exists(path:String):Bool {
        if (path == null || path.trim().length == 0) return false;

        #if sys
        var resolved = ModManager.getPath(path);
        return FileSystem.exists(resolved != null ? resolved : path);
        #else
        return false;
        #end
    }
}