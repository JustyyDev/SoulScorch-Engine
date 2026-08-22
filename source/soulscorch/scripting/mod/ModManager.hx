package soulscorch.scripting.mod;

import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.mod.SoulModData;
import soulscorch.scripting.mod.SoulModParser;
import soulscorch.scripting.mod.SoulGlobalScript;

#if sys
import sys.FileSystem;
#end

using StringTools;

class ModManager {
    public static var allMods:Array<String> = [];
    public static var activeMods:Array<String> = [];
    public static var modConfigs:Map<String, SoulModData> = new Map<String, SoulModData>();

    public static function reloadMods():Void {
        allMods = [];
        activeMods = [];
        modConfigs.clear();

        #if sys
        var modsDir = "mods";
        if (FileSystem.exists(modsDir) && FileSystem.isDirectory(modsDir)) {
            var folders = FileSystem.readDirectory(modsDir);
            for (folder in folders) {
                var fullDir = '$modsDir/$folder';
                if (FileSystem.isDirectory(fullDir) && !folder.startsWith(".") && !folder.startsWith("_")) {
                    allMods.push(folder);
                    var data = SoulModParser.parseFolder(fullDir, folder);
                    modConfigs.set(folder, data);
                }
            }
        }
        #end

        ModRegistry.instance.loadConfig();
        activeMods = ModRegistry.instance.enabledMods.copy();

        activeMods.sort(function(a:String, b:String):Int {
            var confA = modConfigs.get(a);
            var confB = modConfigs.get(b);
            var prioA = (confA != null && confA.load_priority != null) ? confA.load_priority : 0;
            var prioB = (confB != null && confB.load_priority != null) ? confB.load_priority : 0;
            return prioB - prioA;
        });

        Logger.info('Discovered ${allMods.length} mod(s), ${activeMods.length} active.', "mods");
        SoulGlobalScript.init();
    }

    public static function getPath(filePath:String):String {
        if (filePath == null || filePath.trim().length == 0) return "";
        var clean = filePath.replace("\\", "/").trim();
        while (clean.startsWith("/")) clean = clean.substr(1);

        #if sys
        for (mod in activeMods) {
            var modPath = 'mods/$mod/$clean';
            if (FileSystem.exists(modPath)) return modPath;

            if (clean.startsWith("assets/preload/")) {
                var sub = clean.substr(15);
                var subPath = 'mods/$mod/$sub';
                if (FileSystem.exists(subPath)) return subPath;
            } else if (clean.startsWith("assets/")) {
                var sub = clean.substr(7);
                var subPath = 'mods/$mod/$sub';
                if (FileSystem.exists(subPath)) return subPath;
            }
        }

        if (FileSystem.exists(clean)) return clean;
        #end

        return 'assets/$clean';
    }

    public static function resolveModAsset(filePath:String, ?extensions:Array<String>):String {
        if (filePath == null || filePath.trim().length == 0) return "";
        var clean = filePath.replace("\\", "/").trim();
        while (clean.startsWith("/")) clean = clean.substr(1);

        #if sys
        for (mod in activeMods) {
            var modPath = 'mods/$mod/$clean';
            if (FileSystem.exists(modPath) && !FileSystem.isDirectory(modPath)) return modPath;

            if (extensions != null) {
                for (ext in extensions) {
                    var probe = modPath + (ext.startsWith(".") ? ext : "." + ext);
                    if (FileSystem.exists(probe) && !FileSystem.isDirectory(probe)) return probe;
                }
            }

            if (clean.startsWith("assets/preload/")) {
                var stripped = clean.substr(15);
                var sPath = 'mods/$mod/$stripped';
                if (FileSystem.exists(sPath) && !FileSystem.isDirectory(sPath)) return sPath;
            }
        }

        if (FileSystem.exists(clean) && !FileSystem.isDirectory(clean)) return clean;
        if (extensions != null) {
            for (ext in extensions) {
                var probe = clean + (ext.startsWith(".") ? ext : "." + ext);
                if (FileSystem.exists(probe) && !FileSystem.isDirectory(probe)) return probe;
            }
        }
        #end

        return getPath(clean);
    }
}