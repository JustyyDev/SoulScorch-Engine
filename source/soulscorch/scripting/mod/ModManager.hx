package soulscorch.scripting.mod;

import haxe.Json;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.mod.ModRegistry;
import soulscorch.scripting.mod.SoulModData;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

class ModManager {
    public static var allMods:Array<String> = [];
    public static var activeMods:Array<String> = [];
    public static var modConfigs:Map<String, SoulModData> = new Map<String, SoulModData>();

    public static function reloadMods():Void {
        allMods = [];
        modConfigs.clear();

        #if sys
        var modsDir = "mods";
        if (FileSystem.exists(modsDir) && FileSystem.isDirectory(modsDir)) {
            var folders = FileSystem.readDirectory(modsDir);
            for (folder in folders) {
                var fullDir = '$modsDir/$folder';
                if (FileSystem.isDirectory(fullDir) && !folder.startsWith(".") && !folder.startsWith("_")) {
                    allMods.push(folder);

                    var configPath = '$fullDir/config.json';
                    if (FileSystem.exists(configPath)) {
                        try {
                            var raw = File.getContent(configPath);
                            var data:SoulModData = Json.parse(raw);
                            modConfigs.set(folder, data);
                        } catch (e:Dynamic) {
                            Logger.warn('Failed parsing mod config in $folder: $e', "mods");
                        }
                    }
                }
            }
        }
        #end

        ModRegistry.instance.loadConfig();
        activeMods = ModRegistry.instance.enabledMods.copy();

        Logger.info('Discovered ${allMods.length} mod(s), ${activeMods.length} active.', "mods");
    }

    public static function getPath(filePath:String):String {
        if (filePath == null || filePath.trim().length == 0) return "";
        var clean = filePath.replace("\\", "/").trim();
        while (clean.startsWith("/")) clean = clean.substr(1);

        #if sys
        for (mod in activeMods) {
            var modPath = 'mods/$mod/$clean';
            if (FileSystem.exists(modPath)) {
                return modPath;
            }
        }

        if (FileSystem.exists(clean)) {
            return clean;
        }
        #end

        return 'assets/$clean';
    }
}