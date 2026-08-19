package soulscorch.scripting.mod;

import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.ScriptManager;
import soulscorch.scripting.mod.ModManager;
import soulscorch.scripting.mod.SoulModData;

#if sys
import sys.FileSystem;
#end

using StringTools;

class SoulGlobalScript {
    public static var activeScripts:ScriptManager = new ScriptManager();
    public static var stateRedirects:Map<String, String> = new Map<String, String>();

    public static function init():Void {
        activeScripts.clear();
        clearRedirects();

        if (ModManager.activeMods == null) return;

        for (mod in ModManager.activeMods) {
            var config:Null<SoulModData> = ModManager.modConfigs.get(mod);

            // 1. Explicit global scripts declared in config.json
            if (config != null && config.global_scripts != null) {
                for (scriptFile in config.global_scripts) {
                    var scriptPath = 'mods/$mod/$scriptFile';
                    var resolved = AssetResolver.resolveFile(scriptPath, [".soul", ".hx", ".lua"]);
                    if (resolved != null) {
                        loadGlobalScript(resolved);
                    }
                }
            }

            // 2. Auto-scan mods/<mod>/scripts/ and mods/<mod>/data/scripts/
            #if sys
            var scanDirs = ['mods/$mod/scripts', 'mods/$mod/data/scripts'];
            for (dir in scanDirs) {
                if (FileSystem.exists(dir) && FileSystem.isDirectory(dir)) {
                    for (file in FileSystem.readDirectory(dir)) {
                        if (file.endsWith(".soul") || file.endsWith(".hx") || file.endsWith(".lua")) {
                            var fullPath = '$dir/$file';
                            loadGlobalScript(fullPath);
                        }
                    }
                }
            }
            #end
        }

        activeScripts.setAll("redirectState", redirectState);
        activeScripts.setAll("getRedirect", getRedirect);
        activeScripts.setAll("clearRedirects", clearRedirects);

        activeScripts.callAll("onGlobalInit");
        Logger.info('Global scripts initialized (${activeScripts.scripts.length} active, ${Lambda.count(stateRedirects)} state redirect(s)).', "scripts");
    }

    private static function loadGlobalScript(path:String):Void {
        var script = activeScripts.loadScript(path);
        if (script != null) {
            script.set("redirectState", redirectState);
            script.set("getRedirect", getRedirect);
            script.set("clearRedirects", clearRedirects);
        }
    }

    public static function redirectState(fromState:String, toState:String):Void {
        if (fromState == null || toState == null) return;
        var cleanFrom = fromState.trim();
        var cleanTo = toState.trim();

        stateRedirects.set(cleanFrom.toLowerCase(), cleanTo);
        Logger.info('Registered state redirect: [$cleanFrom -> $cleanTo]', "scripts");
    }

    public static function getRedirect(stateName:String):Null<String> {
        if (stateName == null) return null;
        var clean = stateName.trim().toLowerCase();

        if (stateRedirects.exists(clean)) {
            return stateRedirects.get(clean);
        }
        return null;
    }

    public static function hasRedirect(stateName:String):Bool {
        if (stateName == null) return false;
        return stateRedirects.exists(stateName.trim().toLowerCase());
    }

    public static function clearRedirects():Void {
        stateRedirects.clear();
    }

    public static inline function call(func:String, ?args:Array<Dynamic>):Void {
        if (activeScripts != null) {
            activeScripts.callAll(func, args);
        }
    }

    public static inline function set(variable:String, value:Dynamic):Void {
        if (activeScripts != null) {
            activeScripts.setAll(variable, value);
        }
    }
}