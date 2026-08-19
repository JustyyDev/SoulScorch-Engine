package soulscorch.scripting.mod;

import flixel.FlxG;
import haxe.io.Path;
import openfl.Lib;
import soulscorch.backend.system.engine.DevConsole;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.mod.SoulModData;

#if sys
import sys.FileSystem;
#end

class ModManager {
    public static var allMods:Array<String> = [];
    public static var activeMods(get, set):Array<String>;
    public static var modConfigs:Map<String, SoulModData> = new Map();

    public static inline function get_activeMods():Array<String> {
        return ModRegistry.instance.enabledMods;
    }

    public static inline function set_activeMods(value:Array<String>):Array<String> {
        ModRegistry.instance.enabledMods = value;
        return value;
    }

    public static function reloadMods():Void {
        allMods = [];
        modConfigs.clear();
        ModRegistry.instance.clear();

        #if sys
        var modsDir = "mods";
        if (!FileSystem.exists(modsDir)) {
            try { FileSystem.createDirectory(modsDir); } catch (e:Dynamic) {}
        } else {
            var folders = FileSystem.readDirectory(modsDir);
            for (folder in folders) {
                var fullDir = '$modsDir/$folder';
                if (FileSystem.isDirectory(fullDir) && !folder.startsWith(".") && !folder.startsWith("_")) {
                    var config = SoulModParser.parseFolder(fullDir, folder);
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
                return prioB - prioA;
            });
        }
        #end

        ModRegistry.instance.loadSavedConfig();
        applyWindowDetails();
        ModLoader.syncWithManager();
    }

    public static function applyWindowDetails():Void {
        if (activeMods.length > 0) {
            var topMod = modConfigs.get(activeMods[0]);
            if (topMod != null && topMod.title_bar != null && topMod.title_bar.title != null) {
                if (Lib.current != null && Lib.current.stage != null && Lib.current.stage.window != null) {
                    Lib.current.stage.window.title = topMod.title_bar.title;
                }
            }
        }
    }

    public static function getActiveModDirectories():Array<String> {
        var roots:Array<String> = [];
        for (mod in activeMods) {
            roots.push('mods/$mod');
        }
        return roots;
    }

    public static function getPath(localPath:String):String {
        if (localPath == null || StringTools.trim(localPath).length == 0) return "";
        var clean = StringTools.trim(StringTools.replace(localPath, "\\", "/"));
        if (clean.startsWith("/")) clean = clean.substr(1);

        #if sys
        for (mod in activeMods) {
            var candidates = [
                'mods/$mod/$clean',
                'mods/$mod/assets/$clean'
            ];

            for (checkPath in candidates) {
                if (FileSystem.exists(checkPath)) return checkPath;
            }
        }

        var assetCandidates = [
            clean,
            'assets/$clean',
            'assets/preload/$clean'
        ];

        for (candidate in assetCandidates) {
            if (FileSystem.exists(candidate)) return candidate;
        }
        #end

        return localPath;
    }
}