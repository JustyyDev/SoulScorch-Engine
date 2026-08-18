package soulscorch.scripting.mod;

import haxe.Json;
import soulscorch.backend.utils.Logger;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

typedef SoulModConfig = {
    var name:String;
    var description:String;
    var author:String;
    var version:String;
    var ?api_version:String;
    var ?color:String;
    var ?globalScript:String;
}

class ModLoader {
    public static var activeMods:Array<String> = [];
    public static var loadedModConfigs:Map<String, SoulModConfig> = new Map<String, SoulModConfig>();

    public static function scan():Void {
        activeMods = [];
        loadedModConfigs.clear();

        #if sys
        var modsFolder = "mods";
        if (!FileSystem.exists(modsFolder) || !FileSystem.isDirectory(modsFolder)) {
            try { FileSystem.createDirectory(modsFolder); } catch (e:Dynamic) {}
            return;
        }

        var entries = FileSystem.readDirectory(modsFolder);
        for (folder in entries) {
            var fullPath = '$modsFolder/$folder';
            if (FileSystem.isDirectory(fullPath) && !folder.startsWith(".") && !folder.startsWith("_")) {
                var config = loadConfig(fullPath, folder);
                loadedModConfigs.set(folder, config);
                activeMods.push(folder);
                Logger.info('Registered mod: ${config.name} ($folder) v${config.version}', "modloader");
            }
        }
        #end
    }

    #if sys
    private static function loadConfig(modPath:String, folderName:String):SoulModConfig {
        var possibleFiles = ["soulmod.json", "mod.json", "_polymod_meta.json", "config.json"];
        for (file in possibleFiles) {
            var fullFilePath = '$modPath/$file';
            if (FileSystem.exists(fullFilePath)) {
                try {
                    var content = File.getContent(fullFilePath);
                    var parsed:Dynamic = Json.parse(content);
                    return {
                        name: (parsed.name != null) ? parsed.name : ((parsed.title != null) ? parsed.title : folderName),
                        description: (parsed.description != null) ? parsed.description : "",
                        author: (parsed.author != null) ? parsed.author : "Unknown",
                        version: (parsed.version != null) ? parsed.version : "1.0.0",
                        api_version: parsed.api_version,
                        color: parsed.color,
                        globalScript: parsed.globalScript
                    };
                } catch (e:Dynamic) {
                    Logger.warn('Error reading $fullFilePath: $e', "modloader");
                }
            }
        }

        return {
            name: folderName,
            description: "No metadata file found.",
            author: "Unknown",
            version: "1.0.0"
        };
    }
    #end

    public static function getPath(relPath:String):String {
        #if sys
        var clean = relPath.trim().replace("\\", "/");
        if (clean.startsWith("/")) clean = clean.substr(1);

        for (mod in activeMods) {
            var candidates = [
                'mods/$mod/$clean',
                'mods/$mod/assets/$clean'
            ];

            for (c in candidates) {
                if (FileSystem.exists(c)) return c;
            }
        }
        #end
        return relPath;
    }
}