package soulscorch.backend;

#if sys
import sys.FileSystem;
import sys.io.File;
import haxe.io.Path;
#end
import soulscorch.modding.ModManager;

class FileSystemAPI {
    
    // Safely writes a file ONLY within a specific mod's directory
    public static function saveModData(modName:String, fileName:String, data:String):Bool {
        #if sys
        try {
            var modDir = Path.join(["mods", modName, "data"]);
            if (!FileSystem.exists(modDir)) FileSystem.createDirectory(modDir);
            
            var fullPath = Path.join([modDir, fileName]);
            File.saveContent(fullPath, data);
            return true;
        } catch (e:Dynamic) {
            soulscorch.ui.DevConsole.instance.log('[FS ERROR] Could not save: ' + e);
            return false;
        }
        #else
        return false;
        #end
    }

    public static function readModData(modName:String, fileName:String):String {
        #if sys
        var fullPath = Path.join(["mods", modName, "data", fileName]);
        if (FileSystem.exists(fullPath)) {
            return File.getContent(fullPath);
        }
        #end
        return null;
    }

    public static function readDirectory(path:String):Array<String> {
        #if sys
        if (FileSystem.exists(path) && FileSystem.isDirectory(path)) {
            return FileSystem.readDirectory(path);
        }
        #end
        return [];
    }
}