package soulscorch.scripting.mod;

import flixel.FlxG;
import haxe.io.Path;
import soulscorch.backend.system.engine.DevConsole;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.mod.SoulModData;

#if sys
import sys.FileSystem;
#end

class ModManager {
    public static var allMods:Array<String> = [];[cite: 62]
    public static var activeMods:Array<String> = [];[cite: 62]
    public static var modConfigs:Map<String, SoulModData> = new Map();[cite: 62]
    public static var selectedMod:String = null;[cite: 62]

    public static function reloadMods():Void {
        allMods = [];[cite: 62]
        modConfigs.clear();[cite: 62]
        ModRegistry.instance.clear();

        #if sys
        var modsDir = "mods/";[cite: 62]
        if (!FileSystem.exists(modsDir)) {
            FileSystem.createDirectory(modsDir);[cite: 62]
        } else {
            var folders = FileSystem.readDirectory(modsDir);[cite: 62]
            for (folder in folders) {
                var fullDir = Path.join([modsDir, folder]);
                if (FileSystem.isDirectory(fullDir)) {[cite: 62]
                    var config = SoulModParser.parse(folder);[cite: 62]
                    modConfigs.set(folder, config);[cite: 62]
                    ModRegistry.instance.register(folder, config);
                    allMods.push(folder);[cite: 62]
                }
            }

            allMods.sort(function(a:String, b:String):Int {
                var configA = modConfigs.get(a);
                var configB = modConfigs.get(b);
                var prioA = configA != null ? configA.load_priority : 0;
                var prioB = configB != null ? configB.load_priority : 0;
                if (prioA > prioB) return -1;[cite: 62]
                if (prioA < prioB) return 1;[cite: 62]
                return 0;[cite: 62]
            });
        }
        #end

        if (selectedMod == null && FlxG.save != null && FlxG.save.data.selectedMod != null) {
            selectedMod = cast FlxG.save.data.selectedMod;[cite: 62]
        }
        applySelection();[cite: 62]
    }

    public static function applySelection():Void {
        if (selectedMod != null && selectedMod.length > 0 && allMods.contains(selectedMod)) {
            activeMods = [selectedMod];[cite: 62]
            ModRegistry.instance.enabledMods = [selectedMod];
            var config = modConfigs.get(selectedMod);
            Logger.info('Active mod set to: ' + (config != null ? config.name : selectedMod), "mods");
            if (DevConsole.instance != null) {
                DevConsole.instance.log('[MOD MANAGER] Active mod: ' + (config != null ? config.name : selectedMod));[cite: 62]
            }
        } else {
            selectedMod = null;[cite: 62]
            activeMods = [];[cite: 62]
            ModRegistry.instance.enabledMods = [];
            Logger.info("All mods disabled", "mods");
            if (DevConsole.instance != null) {
                DevConsole.instance.log('[MOD MANAGER] Mods Disabled');[cite: 62]
            }
        }
    }

    public static function setSelectedMod(modName:String):Void {
        selectedMod = (modName == null || modName.length == 0) ? null : modName;[cite: 62]
        applySelection();[cite: 62]

        if (FlxG.save != null) {
            FlxG.save.data.selectedMod = selectedMod;[cite: 62]
            FlxG.save.flush();[cite: 62]
        }
    }

    public static function getActiveModDirectories():Array<String> {
        var roots:Array<String> = [];
        for (mod in activeMods) {
            roots.push('mods/$mod');
        }
        return roots;
    }

    public static function normalizeAssetPath(localPath:String):String {
        if (localPath == null || localPath.length == 0) return "";[cite: 61]
        var normalized = StringTools.replace(StringTools.trim(localPath), "\\", "/");[cite: 61, 62]

        while (normalized.indexOf("./") == 0) {
            normalized = normalized.substr(2);[cite: 61, 62]
        }

        if (normalized.indexOf("assets/preload/") == 0) {
            normalized = "assets/" + normalized.substr("assets/preload/".length);[cite: 61, 62]
        } else if (normalized.indexOf("assets/") != 0 && normalized.indexOf("mods/") != 0 && normalized.indexOf("http://") != 0 && normalized.indexOf("https://") != 0) {[cite: 61]
            normalized = "assets/" + normalized;[cite: 61, 62]
        }

        return normalized;[cite: 61]
    }

    private static function getAssetCandidates(localPath:String):Array<String> {
        var normalized = normalizeAssetPath(localPath);
        if (normalized.length == 0) return [];[cite: 61]

        var candidates:Array<String> = [];
        var seen:Map<String, Bool> = new Map();

        function addCandidate(candidate:String):Void {
            if (candidate == null || candidate.length == 0) return;[cite: 61, 62]
            var clean = StringTools.replace(candidate, "\\", "/");[cite: 61, 62]
            if (!seen.exists(clean)) {
                candidates.push(clean);[cite: 61, 62]
                seen.set(clean, true);[cite: 61, 62]
            }
        }

        addCandidate(normalized);[cite: 61, 62]
        if (normalized.indexOf("assets/") == 0) {
            addCandidate("assets/preload/" + normalized.substr("assets/".length));[cite: 61, 62]
        } else {
            addCandidate("assets/" + normalized);[cite: 61, 62]
            addCandidate("assets/preload/" + normalized);[cite: 61, 62]
        }

        return candidates;[cite: 61]
    }

    private static function getModCandidates(localPath:String):Array<String> {
        var normalized = normalizeAssetPath(localPath);
        if (normalized.length == 0) return [];[cite: 61]

        var relative = normalized;
        if (relative.indexOf("assets/") == 0) {
            relative = relative.substr("assets/".length);[cite: 61, 62]
        }

        var candidates:Array<String> = [];
        var seen:Map<String, Bool> = new Map();

        function addCandidate(candidate:String):Void {
            if (candidate == null || candidate.length == 0) return;[cite: 61, 62]
            var clean = StringTools.replace(candidate, "\\", "/");[cite: 61, 62]
            if (!seen.exists(clean)) {
                candidates.push(clean);[cite: 61, 62]
                seen.set(clean, true);[cite: 61, 62]
            }
        }

        addCandidate(relative);[cite: 61, 62]
        addCandidate("assets/" + relative);[cite: 61]
        addCandidate("assets/preload/" + relative);[cite: 61]
        addCandidate("mods/" + relative);[cite: 61]
        addCandidate("mods/assets/" + relative);[cite: 61]
        addCandidate("mods/assets/preload/" + relative);[cite: 61]

        return candidates;[cite: 61]
    }

    public static function getPath(localPath:String):String {
        if (localPath == null || StringTools.trim(localPath).length == 0) return "";[cite: 61]
        var normalized = normalizeAssetPath(localPath);

        #if sys
        // 1. Check mod candidates under active mod directories first
        for (mod in activeMods) {
            var modDir = 'mods/$mod';
            for (candidate in getModCandidates(normalized)) {
                var checkPath = '$modDir/$candidate';
                if (FileSystem.exists(checkPath)) {
                    return checkPath;[cite: 61, 62]
                }
            }

            var directModPath = '$modDir/$localPath';
            if (FileSystem.exists(directModPath)) {
                return directModPath;
            }
        }

        // 2. Fall back to base assets
        for (candidate in getAssetCandidates(normalized)) {
            if (FileSystem.exists(candidate)) {
                return candidate;[cite: 61, 62]
            }
        }
        #end

        return normalized;[cite: 61, 62]
    }
}