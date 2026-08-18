package soulscorch.backend.system;

import haxe.io.Path;
import lime.system.System;

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
        if (filePath == null) return getStorageDirectory();
        var clean = filePath.replace("\\", "/").trim();
        if (clean.startsWith("/")) clean = clean.substr(1);
        return getStorageDirectory() + clean;
    }

    public static function exists(filePath:String):Bool {
        if (filePath == null || filePath.trim().length == 0) return false;
        var resolved = getPath(filePath);
        #if sys
        if (FileSystem.exists(resolved)) return true;
        #end
        return openfl.utils.Assets.exists(filePath);
    }

    public static function saveText(filePath:String, content:String):Bool {
        var fullPath = getPath(filePath);
        #if sys
        try {
            var dir = Path.directory(fullPath);
            if (!FileSystem.exists(dir)) {
                FileSystem.createDirectory(dir);
            }
            File.saveContent(fullPath, content);
            return true;
        } catch (e:Dynamic) {
            return false;
        }
        #else
        return false;
        #end
    }

    public static function loadText(filePath:String):String {
        var fullPath = getPath(filePath);
        #if sys
        if (FileSystem.exists(fullPath)) {
            try {
                return File.getContent(fullPath);
            } catch (e:Dynamic) {
                return "";
            }
        }
        #end
        if (openfl.utils.Assets.exists(filePath)) {
            return openfl.utils.Assets.getText(filePath);
        }
        return "";
    }
}