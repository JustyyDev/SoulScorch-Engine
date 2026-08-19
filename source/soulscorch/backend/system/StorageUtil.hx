package soulscorch.backend.system;

import haxe.Json;
import haxe.io.Bytes;
import haxe.io.Path;
import lime.system.System;
import soulscorch.backend.utils.Logger;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

class StorageUtil {
    private static var _cachedStorageDir:String = null;

    public static function getStorageDirectory():String {
        if (_cachedStorageDir != null) return _cachedStorageDir;

        #if windows
        var appData = Sys.getEnv("APPDATA");
        if (appData != null && appData.length > 0) {
            _cachedStorageDir = Path.addTrailingSlash(Path.join([appData, "SoulScorchEngine"]));
        } else {
            _cachedStorageDir = "./";
        }
        #elseif mac
        var home = Sys.getEnv("HOME");
        _cachedStorageDir = Path.addTrailingSlash(Path.join([home, "Library", "Application Support", "SoulScorchEngine"]));
        #elseif linux
        var home = Sys.getEnv("HOME");
        _cachedStorageDir = Path.addTrailingSlash(Path.join([home, ".local", "share", "SoulScorchEngine"]));
        #elseif android
        _cachedStorageDir = Path.addTrailingSlash(System.applicationStorageDirectory);
        #elseif ios
        _cachedStorageDir = Path.addTrailingSlash(System.documentsDirectory);
        #else
        _cachedStorageDir = "./";
        #end

        #if sys
        try {
            if (!FileSystem.exists(_cachedStorageDir)) {
                FileSystem.createDirectory(_cachedStorageDir);
            }
        } catch (e:Dynamic) {
            Logger.warn('Could not initialize storage directory $_cachedStorageDir: $e', "storage");
            _cachedStorageDir = "./";
        }
        #end

        return _cachedStorageDir;
    }

    public static function getPath(filePath:String):String {
        if (filePath == null || filePath.trim().length == 0) return getStorageDirectory();
        var clean = filePath.replace("\\", "/").trim();
        while (clean.startsWith("/")) clean = clean.substr(1);
        return Path.join([getStorageDirectory(), clean]);
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
            if (!FileSystem.exists(dir)) FileSystem.createDirectory(dir);
            File.saveContent(fullPath, content != null ? content : "");
            return true;
        } catch (e:Dynamic) {
            Logger.error('Failed saving text to "$fullPath": $e', "storage");
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
                Logger.error('Failed reading text from "$fullPath": $e', "storage");
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

    public static function saveJson(filePath:String, data:Dynamic, pretty:Bool = true):Bool {
        try {
            var serialized = pretty ? Json.stringify(data, "    ") : Json.stringify(data);
            return saveText(filePath, serialized);
        } catch (e:Dynamic) {
            Logger.error('Failed to serialize JSON for $filePath: $e', "storage");
            return false;
        }
    }

    public static function loadJson(filePath:String):Dynamic {
        var raw = loadText(filePath);
        if (raw == null || raw.trim().length == 0) return null;
        try {
            return Json.parse(raw);
        } catch (e:Dynamic) {
            Logger.error('Failed parsing JSON from $filePath: $e', "storage");
            return null;
        }
    }

    public static function deleteFile(filePath:String):Bool {
        #if sys
        var fullPath = getPath(filePath);
        try {
            if (FileSystem.exists(fullPath)) {
                FileSystem.deleteFile(fullPath);
                return true;
            }
        } catch (e:Dynamic) {
            Logger.error('Could not delete file "$fullPath": $e', "storage");
        }
        #end
        return false;
    }
}