package soulscorch.backend.system.apis;

import haxe.io.Path;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.mod.ModLoader;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

class FileSystemAPI {
    /**
     * Safely saves text data inside a mod's isolated data directory.
     */
    public static function saveModData(modName:String, fileName:String, data:String):Bool {
        #if sys
        try {
            var modDir = Path.join(["mods", modName, "data"]);
            if (!FileSystem.exists(modDir)) {
                FileSystem.createDirectory(modDir);
            }
            
            var fullPath = Path.join([modDir, fileName]);
            File.saveContent(fullPath, data);
            return true;
        } catch (e:Dynamic) {
            Logger.error('Failed saving mod data to $fileName: $e');
            return false;
        }
        #else
        return false;
        #end
    }

    /**
     * Reads text data from a specific mod's isolated data folder.
     */
    public static function readModData(modName:String, fileName:String):String {
        #if sys
        var fullPath = Path.join(["mods", modName, "data", fileName]);
        if (FileSystem.exists(fullPath)) {
            try {
                return File.getContent(fullPath);
            } catch (e:Dynamic) {
                Logger.error('Failed reading mod data from $fullPath: $e');
            }
        }
        #end
        return null;
    }

    /**
     * Reads all file names from a target directory path.
     */
    public static function readDirectory(path:String):Array<String> {
        #if sys
        var resolved = ModLoader.getPath(path);
        var target = (resolved != null && FileSystem.exists(resolved)) ? resolved : path;

        if (FileSystem.exists(target) && FileSystem.isDirectory(target)) {
            return FileSystem.readDirectory(target);
        }
        #end
        return [];
    }

    /**
     * Checks if a file or folder exists on disk.
     */
    public static function exists(path:String):Bool {
        #if sys
        var resolved = ModLoader.getPath(path);
        return FileSystem.exists(resolved != null ? resolved : path);
        #else
        return false;
        #end
    }
}