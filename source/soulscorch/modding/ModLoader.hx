package soulscorch.modding;

#if sys
import sys.FileSystem;
import sys.io.File;
#end
import haxe.Json;

typedef ModMetadata = {
    var id:String;
    var name:String;
    var description:String;
    var version:String;
    var api:String;
}

class ModLoader {
    public static var activeMods:Array<ModMetadata> = [];
    public static var modDirectories:Array<String> = [];

    public function new() {}

    public function scan():Void {
        #if sys
        var modsPath = "mods/";
        if (!FileSystem.exists(modsPath)) {
            FileSystem.createDirectory(modsPath);
            return;
        }

        var directories = FileSystem.readDirectory(modsPath);
        for (dir in directories) {
            var fullPath = modsPath + dir;
            if (FileSystem.isDirectory(fullPath)) {
                var metaPath = fullPath + "/mod.json";
                if (FileSystem.exists(metaPath)) {
                    var raw = File.getContent(metaPath);
                    var meta:ModMetadata = cast Json.parse(raw);
                    activeMods.push(meta);
                    modDirectories.push(fullPath);
                }
            }
        }
        #end
    }

    public function resolveAsset(path:String):Null<String> {
        #if sys
        for (dir in modDirectories) {
            var checkPath = dir + "/" + path;
            if (FileSystem.exists(checkPath)) {
                return checkPath;
            }
        }
        #end
        return null;
    }

    public static function getPath(assetPath:String):String {
        #if sys
        for (dir in modDirectories) {
            var checkPath = dir + "/" + assetPath;
            if (FileSystem.exists(checkPath)) {
                return checkPath;
            }
        }
        #end
        return assetPath;
    }
}