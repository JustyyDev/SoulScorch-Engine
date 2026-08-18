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
    public static var allMods:Array<String> = [];
    public static var activeMods:Array<String> = [];
    public static var modConfigs:Map<String, SoulModData> = new Map();
    public static var selectedMod:String = null;

    public static function reloadMods():Void {
        allMods = [];
        modConfigs.clear();
        ModRegistry.instance.clear();

        #if sys
        var modsDir = "mods/";
        if (!FileSystem.exists(modsDir)) {
            FileSystem.createDirectory(modsDir);
        } else {
            var folders = FileSystem.readDirectory(modsDir);
            for (folder in folders) {
                var fullDir = Path.join([modsDir, folder]);
                if (FileSystem.isDirectory(fullDir)) {
                    var config = SoulModParser.parse(folder);
                    modConfigs.set(folder, config);
                    ModRegistry.instance.register(folder, config);
                    allMods.push(folder);
                }
            }

            allMods.sort(function(a:String, b:String):Int {
                var configA = modConfigs.get(a);
                var configB = modConfigs.get(b);
                var prioA = configA != null ? configA.load_priority : 0;
                var prioB = configB != null ? configB.load_priority : 0;
                if (prioA > prioB) return -1;
                if (prioA < prioB) return 1;
                return 0;
            });
        }
        #end

        if (selectedMod == null && FlxG.save != null && FlxG.save.data.selectedMod != null) {
            selectedMod = cast FlxG.save.data.selectedMod;
        }
        applySelection();
    }

    public static function applySelection():Void {
        if (selectedMod != null && selectedMod.length > 0 && allMods.contains(selectedMod)) {
            activeMods = [selectedMod];
            ModRegistry.instance.enabledMods = [selectedMod];
            var config = modConfigs.get(selectedMod);
            Logger.info('Active mod set to: ' + (config != null ? config.name : selectedMod), "mods");
            if (DevConsole.instance != null) {
                DevConsole.instance.log('[MOD MANAGER] Active mod: ' + (config != null ? config.name : selectedMod));
            }
        } else {
            selectedMod = null;
            activeMods = [];
            ModRegistry.instance.enabledMods = [];
            Logger.info("All mods disabled", "mods");
            if (DevConsole.instance != null) {
                DevConsole.instance.log('[MOD MANAGER] Mods Disabled');
            }
        }
    }

    public static function setSelectedMod(modName:String):Void {
        selectedMod = (modName == null || modName.length == 0) ? null : modName;
        applySelection();

        if (FlxG.save != null) {
            FlxG.save.data.selectedMod = selectedMod;
            FlxG.save.flush();
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
        if (localPath == null || localPath.length == 0) return "";
        var normalized = StringTools.replace(StringTools.trim(localPath), "\\", "/");

        while (normalized.indexOf("./") == 0) {
            normalized = normalized.substr(2);
        }

        if (normalized.indexOf("assets/preload/") == 0) {
            normalized = "assets/" + normalized.substr("assets/preload/".length);
        } else if (normalized.indexOf("assets/") != 0 && normalized.indexOf("mods/") != 0 && normalized.indexOf("http://") != 0 && normalized.indexOf("https://") != 0) {
            normalized = "assets/" + normalized;
        }

        return normalized;
    }

    private static function getAssetCandidates(localPath:String):Array<String> {
        var normalized = normalizeAssetPath(localPath);
        if (normalized.length == 0) return [];

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

        return candidates;
    }

    private static function getModCandidates(localPath:String):Array<String> {
        var normalized = normalizeAssetPath(localPath);
        if (normalized.length == 0) return [];

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
        addCandidate("assets/" + relative);
        addCandidate("assets/preload/" + relative);
        addCandidate("mods/" + relative);
        addCandidate("mods/assets/" + relative);
        addCandidate("mods/assets/preload/" + relative);

        return candidates;
    }

    public static function getPath(localPath:String):String {
        if (localPath == null || StringTools.trim(localPath).length == 0) return "";
        var normalized = normalizeAssetPath(localPath);

        #if sys
        for (mod in activeMods) {
            var modDir = 'mods/$mod';
            for (candidate in getModCandidates(normalized)) {
                var checkPath = '$modDir/$candidate';
                if (FileSystem.exists(checkPath)) {
                    return checkPath;
                }
            }

            var directModPath = '$modDir/$localPath';
            if (FileSystem.exists(directModPath)) {
                return directModPath;
            }
        }

        for (candidate in getAssetCandidates(normalized)) {
            if (FileSystem.exists(candidate)) {
                return candidate;
            }
        }
        #end

        return normalized;
    }
}