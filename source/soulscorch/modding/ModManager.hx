package soulscorch.modding;

import soulscorch.modding.SoulModParser.SoulModData;
import haxe.io.Path;
#if sys
import sys.FileSystem;
#end

class ModManager {
    public static var activeMods:Array<String> = [];
    public static var modConfigs:Map<String, SoulModData> = new Map();

    public static function reloadMods():Void {
        activeMods = [];
        modConfigs.clear();

        #if sys
        var modsDir = "mods/";
        if (!FileSystem.exists(modsDir)) {
            FileSystem.createDirectory(modsDir);
            return;
        }

        var folders = FileSystem.readDirectory(modsDir);
        for (folder in folders) {
            if (FileSystem.isDirectory(Path.join([modsDir, folder]))) {
                var config = SoulModParser.parse(folder);
                modConfigs.set(folder, config);
                activeMods.push(folder);
                
                if (soulscorch.ui.DevConsole.instance != null) {
                    soulscorch.ui.DevConsole.instance.log('[MOD MANAGER] Loaded: ' + config.name + ' (v' + config.version + ')');
                }
            }
        }

        // Sort mods by load_priority (higher number loads first)
        activeMods.sort(function(a, b) {
            var configA = modConfigs.get(a);
            var configB = modConfigs.get(b);
            if (configA.load_priority > configB.load_priority) return -1;
            if (configA.load_priority < configB.load_priority) return 1;
            return 0;
        });
        #end
    }

    private static function normalizeAssetPath(localPath:String):String {
        if (localPath == null || localPath.length == 0) {
            return localPath;
        }

        var normalized = StringTools.replace(localPath, "\\", "/");
        while (normalized.indexOf("./") == 0) {
            normalized = normalized.substr(2);
        }

        if (normalized.indexOf("assets/preload/") == 0) {
            normalized = "assets/" + normalized.substr("assets/preload/".length);
        } else if (normalized.indexOf("assets/") != 0 && normalized.indexOf("mods/") != 0) {
            normalized = "assets/" + normalized;
        }

        return normalized;
    }

    private static function getAssetCandidates(localPath:String):Array<String> {
        var normalized = normalizeAssetPath(localPath);
        var candidates:Array<String> = [];
        var seen:Map<String, Bool> = new Map();

        function addCandidate(candidate:String):Void {
            if (candidate == null || candidate.length == 0) return;
            var clean = StringTools.replace(candidate, "\\", "/");
            if (!seen.exists(clean)) {
                candidates.push(clean);
                seen.set(clean, true);
            }
        }

        addCandidate(normalized);

        if (normalized.indexOf("assets/") == 0) {
            addCandidate("assets/preload/" + normalized.substr("assets/".length));
        } else {
            addCandidate("assets/" + normalized);
            addCandidate("assets/preload/" + normalized);
        }

        if (normalized.indexOf("assets/preload/") == 0) {
            addCandidate("assets/" + normalized.substr("assets/preload/".length));
        }

        return candidates;
    }

    private static function getModCandidates(localPath:String):Array<String> {
        var normalized = normalizeAssetPath(localPath);
        var relative = normalized;

        if (relative.indexOf("assets/") == 0) {
            relative = relative.substr("assets/".length);
        }

        var candidates:Array<String> = [];
        var seen:Map<String, Bool> = new Map();

        function addCandidate(candidate:String):Void {
            if (candidate == null || candidate.length == 0) return;
            var clean = StringTools.replace(candidate, "\\", "/");
            if (!seen.exists(clean)) {
                candidates.push(clean);
                seen.set(clean, true);
            }
        }

        addCandidate(relative);
        addCandidate(Path.join(["assets", relative]));
        addCandidate(Path.join(["assets", "preload", relative]));
        addCandidate(Path.join(["mods", relative]));
        addCandidate(Path.join(["mods", "assets", relative]));
        addCandidate(Path.join(["mods", "assets", "preload", relative]));

        return candidates;
    }

    // Resolves a path: Checks active mods first, then falls back to base assets
    public static function getPath(localPath:String):String {
        var normalized = normalizeAssetPath(localPath);

        #if sys
        var sourceCandidates = getAssetCandidates(localPath);
        for (candidate in sourceCandidates) {
            if (FileSystem.exists(candidate)) {
                return candidate;
            }
        }

        for (mod in activeMods) {
            var candidates = getModCandidates(normalized);
            for (candidate in candidates) {
                var modPath = Path.join(["mods", mod, candidate]);
                if (FileSystem.exists(modPath)) {
                    return modPath;
                }
            }

            var legacyModPath = Path.join(["mods", mod, localPath]);
            if (FileSystem.exists(legacyModPath)) {
                return legacyModPath;
            }
        }
        #end

        return normalized;
    }
}