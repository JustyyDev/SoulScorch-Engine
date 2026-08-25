package soulscorch.scripting.mod;

import soulscorch.scripting.mod.SoulModData;

#if sys
import sys.FileSystem;
#end

using StringTools;

class ModValidator {
    public static function validateFolder(modPath:String, folderName:String, data:SoulModData, allKnownMods:Array<String>):Array<String> {
        var warnings:Array<String> = [];

        if (folderName == null || folderName.trim().length == 0) {
            warnings.push("Mod folder has an empty name.");
        }

        if (data == null) {
            warnings.push("Mod data could not be parsed.");
            return warnings;
        }

        if (data.name == null || data.name.trim().length == 0) warnings.push("Missing mod name.");
        if (data.version == null || data.version.trim().length == 0) warnings.push("Missing mod version.");
        if (data.author == null || data.author.trim().length == 0 || data.author == "Unknown") warnings.push("Missing mod author.");

        #if sys
        if (!hasConfigFile(modPath)) {
            warnings.push("Missing soulmod.json, soulmod.xmsoul, mod.json, mod.xmsoul, config.json, or config.xmsoul.");
        }

        if (data.icon == null || data.icon.trim().length == 0) {
            warnings.push("Missing icon field. The mod menu will use a fallback icon.");
        } else if (!assetExistsInMod(modPath, data.icon, ["", ".png", ".jpg", ".jpeg", ".webp"])) {
            warnings.push('Icon not found: ${data.icon}');
        }

        if (data.global_scripts != null) {
            for (script in data.global_scripts) {
                if (script != null && script.trim().length > 0 && !assetExistsInMod(modPath, script, ["", ".soul", ".hx", ".hscript", ".iris", ".lua", ".py", ".js"])) {
                    warnings.push('Global script not found: $script');
                }
            }
        }
        #end

        if (data.dependencies != null && allKnownMods != null) {
            for (dependency in data.dependencies) {
                if (dependency != null && dependency.trim().length > 0 && !allKnownMods.contains(dependency.trim())) {
                    warnings.push('Missing dependency: ${dependency.trim()}');
                }
            }
        }

        return warnings;
    }

    #if sys
    private static function hasConfigFile(modPath:String):Bool {
        var files = ["soulmod.json", "soulmod.xmsoul", "mod.json", "mod.xmsoul", "config.json", "config.xmsoul", "_polymod_meta.json"];
        for (file in files) {
            if (FileSystem.exists('$modPath/$file') && !FileSystem.isDirectory('$modPath/$file')) return true;
        }
        return false;
    }

    private static function assetExistsInMod(modPath:String, path:String, extensions:Array<String>):Bool {
        var clean = path.replace("\\", "/").trim();
        while (clean.startsWith("/")) clean = clean.substr(1);

        var prefixes = ["", "assets/", "assets/preload/", "images/", "assets/preload/images/", "scripts/", "data/"];
        for (prefix in prefixes) {
            for (ext in extensions) {
                var probe = '$modPath/$prefix$clean';
                if (ext.length > 0 && !probe.toLowerCase().endsWith(ext)) probe += ext;
                if (FileSystem.exists(probe) && !FileSystem.isDirectory(probe)) return true;
            }
        }
        return false;
    }
    #end
}
