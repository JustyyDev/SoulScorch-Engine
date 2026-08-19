package soulscorch.scripting.mod;

import haxe.Json;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.mod.SoulModData;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

class SoulModParser {
    public static function parse(jsonContent:String, folderName:String = ""):SoulModData {
        try {
            var parsed:Dynamic = Json.parse(jsonContent);
            return {
                name: (parsed.name != null) ? parsed.name : ((parsed.title != null) ? parsed.title : folderName),
                version: (parsed.version != null) ? parsed.version : "1.0.0",
                author: (parsed.author != null) ? parsed.author : "Unknown",
                api_version: parsed.api_version,
                engine_version: parsed.engine_version,
                description: (parsed.description != null) ? parsed.description : "",
                color: parsed.color,
                icon: parsed.icon,
                title_bar: parsed.title_bar,
                global_scripts: (parsed.global_scripts != null) ? cast parsed.global_scripts : ["data/global.soul"],
                dependencies: (parsed.dependencies != null) ? cast parsed.dependencies : [],
                incompatibilities: (parsed.incompatibilities != null) ? cast parsed.incompatibilities : [],
                flags: (parsed.flags != null) ? cast parsed.flags : [],
                load_priority: (parsed.load_priority != null) ? parsed.load_priority : 0,
                restart_required: (parsed.restart_required != null) ? parsed.restart_required : false,
                folder: folderName
            };
        } catch (e:Dynamic) {
            Logger.warn('Failed parsing mod metadata JSON: $e', "parser");
        }

        return fallback(folderName);
    }

    #if sys
    public static function parseFolder(modPath:String, folderName:String = ""):SoulModData {
        if (folderName == "" && modPath != null) {
            var parts = modPath.replace("\\", "/").split("/");
            while (parts.length > 0 && parts[parts.length - 1] == "") parts.pop();
            if (parts.length > 0) folderName = parts[parts.length - 1];
        }

        var possibleFiles = ["soulmod.json", "mod.json", "_polymod_meta.json", "config.json"];
        for (file in possibleFiles) {
            var fullFilePath = '$modPath/$file';
            if (FileSystem.exists(fullFilePath)) {
                return parseFile(fullFilePath, folderName);
            }
        }

        return fallback(folderName);
    }

    public static function parseFile(filePath:String, folderName:String = ""):SoulModData {
        if (folderName == "" && filePath != null) {
            var parts = filePath.replace("\\", "/").split("/");
            if (parts.length >= 2) {
                folderName = parts[parts.length - 2];
            }
        }

        if (FileSystem.exists(filePath)) {
            try {
                var content = File.getContent(filePath);
                return parse(content, folderName);
            } catch (e:Dynamic) {
                Logger.error('Failed reading mod file at $filePath: $e', "parser");
            }
        }

        return fallback(folderName);
    }
    #end

    public static function fallback(folderName:String = "unknown"):SoulModData {
        return {
            name: folderName != "" ? folderName : "Unknown Mod",
            version: "1.0.0",
            author: "Unknown",
            api_version: "1.0.0",
            engine_version: "1.0.0",
            description: "No description provided.",
            color: "#FFFFFF",
            icon: null,
            title_bar: null,
            global_scripts: ["data/global.soul"],
            dependencies: [],
            incompatibilities: [],
            flags: [],
            load_priority: 0,
            restart_required: false,
            folder: folderName
        };
    }
}