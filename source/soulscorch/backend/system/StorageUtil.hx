package soulscorch.backend.system;

import haxe.io.Path;
import lime.system.System;
import soulscorch.backend.utils.Logger;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

class StorageUtil {
    public static function getStorageDirectory():String {
        #if android
        return Path.addTrailingSlash(System.applicationStorageDirectory);
        #elseif ios
        return Path.addTrailingSlash(System.documentsDirectory);
        #else
        return "./";
        #end
    }

    public static function getPath(filePath:String):String {
        if (filePath == null || filePath.trim().length == 0) return getStorageDirectory();
        var clean = filePath.replace("\\", "/").trim();
        while (clean.startsWith("/")) clean = clean.substr(1);
        return getStorageDirectory() + clean;
    }

    public static function exists(filePath:String):Bool {
        if (filePath == null || filePath.trim().length == 0) return false;
        var resolved = getPath(filePath);
        #if sys
        if (FileSystem.exists(resolved) && !FileSystem.isDirectory(resolved)) return true;
        if (FileSystem.exists(filePath) && !FileSystem.isDirectory(filePath)) return true;
        #end
        return openfl.utils.Assets.exists(filePath);
    }

    public static function saveText(filePath:String, content:String):Bool {
        if (filePath == null) return false;
        var fullPath = getPath(filePath);
        #if sys
        try {
            var dir = Path.directory(fullPath);
            if (!FileSystem.exists(dir)) {
                FileSystem.createDirectory(dir);
            }
            File.saveContent(fullPath, content != null ? content : "");
            return true;
        } catch (e:Dynamic) {
            Logger.error('Failed saving text file "$fullPath": $e', "storage");
            return false;
        }
        #else
        return false;
        #end
    }

    public static function loadText(filePath:String):String {
        if (filePath == null) return "";
        var fullPath = getPath(filePath);
        #if sys
        if (FileSystem.exists(fullPath) && !FileSystem.isDirectory(fullPath)) {
            try {
                return File.getContent(fullPath);
            } catch (e:Dynamic) {
                Logger.error('Failed reading text file "$fullPath": $e', "storage");
                return "";
            }
        }
        #end
        if (openfl.utils.Assets.exists(filePath)) {
            try {
                return openfl.utils.Assets.getText(filePath);
            } catch (e:Dynamic) {
                return "";
            }
        }
        return "";
    }
}