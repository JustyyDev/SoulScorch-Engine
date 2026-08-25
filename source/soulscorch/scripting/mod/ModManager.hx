package soulscorch.scripting.mod;

import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.mod.ModFeatureRegistry;
import soulscorch.scripting.mod.ModValidator;
import soulscorch.scripting.mod.SoulModData;
import soulscorch.scripting.mod.SoulModParser;
import soulscorch.scripting.mod.SoulGlobalScript;
import soulscorch.backend.system.XMSoul;
import soulscorch.gameplay.actors.HealthIcon;

#if sys
import sys.FileSystem;
import haxe.io.Path;
#end

using StringTools;

class ModManager {
    public static var allMods:Array<String> = [];
    public static var activeMods:Array<String> = [];
    public static var modConfigs:Map<String, SoulModData> = new Map<String, SoulModData>();
    public static var modRoots:Array<String> = [];
    public static var modFolderRoots:Map<String, String> = new Map<String, String>();
    public static var validationWarnings:Map<String, Array<String>> = new Map<String, Array<String>>();

    #if sys
    private static function detectModRoots():Array<String> {
        var roots:Array<String> = [];

        var pushRoot = function(root:String) {
            if (root == null || root.trim().length == 0) return;
            var clean = root.replace("\\", "/");
            while (clean.endsWith("/")) clean = clean.substr(0, clean.length - 1);
            if (clean.length == 0 || roots.contains(clean)) return;
            if (FileSystem.exists(clean) && FileSystem.isDirectory(clean)) {
                roots.push(clean);
            }
        };

        pushRoot("mods");
        pushRoot("bin/hl/bin/mods");
        pushRoot("bin/windows/bin/mods");
        pushRoot("bin/linux/bin/mods");
        pushRoot("bin/macos/bin/mods");

        var exePath = Sys.programPath();
        if (exePath != null && exePath.length > 0) {
            var exeDir = Path.directory(exePath).replace("\\", "/");
            pushRoot(exeDir + "/mods");
            pushRoot(exeDir + "/../mods");
        }

        return roots;
    }
    #end

    private static function getModFolderRoot(mod:String):String {
        if (mod != null && modFolderRoots.exists(mod)) return modFolderRoots.get(mod);
        return modRoots.length > 0 ? modRoots[0] : "mods";
    }

    public static function getModFolderRootPath(mod:String):String {
        return getModFolderRoot(mod);
    }

    public static function reloadMods():Void {
        XMSoul.clearCache();
        HealthIcon.clearCache();
        allMods = [];
        activeMods = [];
        modConfigs.clear();
        modRoots = [];
        modFolderRoots.clear();
        validationWarnings.clear();

        #if sys
        modRoots = detectModRoots();
        for (modsDir in modRoots) {
            var folders = FileSystem.readDirectory(modsDir);
            for (folder in folders) {
                var fullDir = '$modsDir/$folder';
                if (FileSystem.isDirectory(fullDir) && !folder.startsWith(".") && !folder.startsWith("_")) {
                    if (!allMods.contains(folder)) {
                        allMods.push(folder);
                        var data = SoulModParser.parseFolder(fullDir, folder);
                        modConfigs.set(folder, data);
                        modFolderRoots.set(folder, modsDir);
                    }
                }
            }
        }
        #end

        #if sys
        for (mod in allMods) {
            var modPath = getModFolderRoot(mod) + '/$mod';
            var warnings = ModValidator.validateFolder(modPath, mod, modConfigs.get(mod), allMods);
            if (warnings.length > 0) {
                validationWarnings.set(mod, warnings);
                for (warning in warnings) Logger.warn('[$mod] $warning', "mod-validator");
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
        ModFeatureRegistry.reload();
        ModFeatureRegistry.applyStateRedirects();
    }

    public static function getPath(filePath:String):String {
        if (filePath == null || filePath.trim().length == 0) return "";
        var clean = filePath.replace("\\", "/").trim();
        while (clean.startsWith("/")) clean = clean.substr(1);

        #if sys
        for (mod in activeMods) {
            var modPath = getModFolderRoot(mod) + '/$mod/$clean';
            if (FileSystem.exists(modPath)) return modPath;

            if (clean.startsWith("assets/preload/")) {
                var sub = clean.substr(15);
                var subPath = getModFolderRoot(mod) + '/$mod/$sub';
                if (FileSystem.exists(subPath)) return subPath;
            } else if (clean.startsWith("assets/")) {
                var sub = clean.substr(7);
                var subPath = getModFolderRoot(mod) + '/$mod/$sub';
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
            var modPath = getModFolderRoot(mod) + '/$mod/$clean';
            if (FileSystem.exists(modPath) && !FileSystem.isDirectory(modPath)) return modPath;

            if (extensions != null) {
                for (ext in extensions) {
                    var probe = modPath + (ext.startsWith(".") ? ext : "." + ext);
                    if (FileSystem.exists(probe) && !FileSystem.isDirectory(probe)) return probe;
                }
            }

            if (clean.startsWith("assets/preload/")) {
                var stripped = clean.substr(15);
                var sPath = getModFolderRoot(mod) + '/$mod/$stripped';
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