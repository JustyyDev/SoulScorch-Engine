package soulscorch.scripting.mod;

import haxe.Json;
import openfl.Lib;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.mod.SoulModData;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

class ModLoader {
    public static var activeMods:Array<String> = [];
    public static var loadedModConfigs:Map<String, SoulModData> = new Map<String, SoulModData>();
    public static var globalFlags:Map<String, Bool> = new Map<String, Bool>();

    public static function scan():Void {
        activeMods = [];
        loadedModConfigs.clear();
        globalFlags.clear();

        #if sys
        var modsFolder = "mods";
        if (!FileSystem.exists(modsFolder) || !FileSystem.isDirectory(modsFolder)) {
            try { FileSystem.createDirectory(modsFolder); } catch (e:Dynamic) {}
            return;
        }

        var entries = FileSystem.readDirectory(modsFolder);
        var rawModList:Array<SoulModData> = [];

        for (folder in entries) {
            var fullPath = '$modsFolder/$folder';
            if (FileSystem.isDirectory(fullPath) && !folder.startsWith(".") && !folder.startsWith("_")) {
                var config = loadConfig(fullPath, folder);
                rawModList.push(config);
                loadedModConfigs.set(folder, config);
            }
        }

        // Sort by load_priority (descending)
        rawModList.sort(function(a, b) {
            var prioA = (a.load_priority != null) ? a.load_priority : 0;
            var prioB = (b.load_priority != null) ? b.load_priority : 0;
            return prioB - prioA;
        });

        for (mod in rawModList) {
            activeMods.push(mod.folder);
            
            // Register feature flags
            if (mod.flags != null) {
                for (flag in mod.flags) {
                    globalFlags.set(flag, true);
                }
            }

            Logger.info('Registered mod: ${mod.name} (${mod.folder}) v${mod.version}', "modloader");
        }

        applyActiveModWindowDetails();
        #end
    }

    #if sys
    private static function loadConfig(modPath:String, folderName:String):SoulModData {
        var possibleFiles = ["soulmod.json", "mod.json", "_polymod_meta.json", "config.json"];
        for (file in possibleFiles) {
            var fullFilePath = '$modPath/$file';
            if (FileSystem.exists(fullFilePath)) {
                try {
                    var content = File.getContent(fullFilePath);
                    var parsed:Dynamic = Json.parse(content);

                    return {
                        name: (parsed.name != null) ? parsed.name : folderName,
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
                    Logger.warn('Error reading $fullFilePath: $e', "modloader");
                }
            }
        }

        return {
            name: folderName,
            version: "1.0.0",
            author: "Unknown",
            description: "No metadata file found.",
            folder: folderName,
            global_scripts: ["data/global.soul"],
            flags: []
        };
    }
    #end

    public static function applyActiveModWindowDetails():Void {
        if (activeMods.length == 0) return;

        // Apply title_bar from the highest priority enabled mod
        var primaryMod = loadedModConfigs.get(activeMods[0]);
        if (primaryMod != null && primaryMod.title_bar != null) {
            if (primaryMod.title_bar.title != null && Lib.current != null && Lib.current.stage != null && Lib.current.stage.window != null) {
                Lib.current.stage.window.title = primaryMod.title_bar.title;
            }
        }
    }

    public static function hasFlag(flagName:String):Bool {
        return globalFlags.exists(flagName);
    }

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