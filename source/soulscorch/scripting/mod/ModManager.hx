package soulscorch.scripting.mod;

import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.system.XMSoul;
import soulscorch.backend.utils.Logger;

#if sys
import sys.FileSystem;
#end

using StringTools;

class ModManager {
    public static var allMods:Array<String> = [];
    public static var activeMods:Array<String> = [];
    public static var modConfigs:Map<String, XMSoulModConfig> = new Map<String, XMSoulModConfig>();

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

                    var configPath = '$fullDir/mod.xmsoul';
                    if (FileSystem.exists(configPath)) {
                        var conf = XMSoul.loadModConfig(configPath);
                        if (conf != null) {
                            modConfigs.set(folder, conf);
                        }
                    }
                }
            }
        }
        #end

        ModRegistry.instance.loadConfig();
        activeMods = ModRegistry.instance.enabledMods.copy();

        activeMods.sort(function(a:String, b:String):Int {
            var confA = modConfigs.get(a);
            var confB = modConfigs.get(b);
            var prioA = (confA != null && confA.flags.exists("priority")) ? cast(confA.flags.get("priority"), Float) : 0.0;
            var prioB = (confB != null && confB.flags.exists("priority")) ? cast(confB.flags.get("priority"), Float) : 0.0;
            return Std.int(prioB - prioA);
        });

        Logger.info('Discovered ${allMods.length} mod(s), ${activeMods.length} active.', "mods");
        SoulGlobalScript.init();
    }

    public static function getFlag(modId:String, flagName:String, defaultVal:Dynamic = null):Dynamic {
        if (modConfigs.exists(modId)) {
            var conf = modConfigs.get(modId);
            if (conf != null && conf.flags.exists(flagName)) {
                return conf.flags.get(flagName);
            }
        }
        return defaultVal;
    }

    public static function getActiveFlag(flagName:String, defaultVal:Dynamic = null):Dynamic {
        for (mod in activeMods) {
            var val = getFlag(mod, flagName, null);
            if (val != null) return val;
        }
        return defaultVal;
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