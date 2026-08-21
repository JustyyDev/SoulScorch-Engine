package soulscorch.scripting.mod;

import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.ScriptManager;
import soulscorch.scripting.mod.ModManager;

#if sys
import sys.FileSystem;
#end

using StringTools;

class SoulGlobalScript {
    public static var scripts:Array<ScriptManager> = [];
    public static var stateRedirects:Map<String, String> = new Map<String, String>();

    public static function init():Void {
        clear();

        // 1. Gather all global script paths across active mods and base assets
        var scriptPaths:Array<String> = [];

        #if sys
        for (mod in ModManager.activeMods) {
            if (ModManager.modConfigs.exists(mod)) {
                var config = ModManager.modConfigs.get(mod);
                if (config != null && config.global_scripts != null) {
                    for (s in config.global_scripts) {
                        var fullPath = 'mods/$mod/$s';
                        if (FileSystem.exists(fullPath) && !scriptPaths.contains(fullPath)) {
                            scriptPaths.push(fullPath);
                        }
                    }
                }
            }

            // Also check standard global script entry points in mod directories
            var defaultModGlobals = [
                'mods/$mod/scripts/global.soul',
                'mods/$mod/scripts/global.hx',
                'mods/$mod/data/scripts/global.soul',
                'mods/$mod/data/global.soul'
            ];
            for (p in defaultModGlobals) {
                if (FileSystem.exists(p) && !scriptPaths.contains(p)) {
                    scriptPaths.push(p);
                }
            }
        }
        #end

        // Base assets global script fallback
        var baseGlobals = [
            "data/scripts/global.soul",
            "scripts/global.soul",
            "data/global.soul"
        ];
        for (bg in baseGlobals) {
            var resolved = AssetResolver.resolveFile(bg, [".soul", ".hx", ""]);
            if (resolved != null && !scriptPaths.contains(resolved)) {
                scriptPaths.push(resolved);
            }
        }

        // 2. Instantiate and register functions for each script
        for (path in scriptPaths) {
            var script = new ScriptManager();
            if (script.loadScript(path)) {
                registerScriptGlobals(script);
                script.callAll("onCreate", []);
                scripts.push(script);
            }
        }

        var redirectCount = 0;
        for (_ in stateRedirects) redirectCount++;

        Logger.info('Global scripts initialized (${scripts.length} active, ${redirectCount} state redirect(s)).', "scripts");
    }

    private static function registerScriptGlobals(script:ScriptManager):Void {
        script.setAll("redirectState", redirectState);
        script.setAll("getRedirect", getRedirect);
        script.setAll("clearRedirects", clearRedirects);
        script.setAll("addStateRedirect", redirectState);
    }

    public static function redirectState(fromState:String, toState:String):Void {
        if (fromState == null || toState == null) return;
        stateRedirects.set(fromState.trim(), toState.trim());
        Logger.info('Registered state redirect: $fromState -> $toState', "scripts");
    }

    public static function getRedirect(stateName:String):String {
        if (stateName == null) return null;
        var clean = stateName.trim();
        return stateRedirects.exists(clean) ? stateRedirects.get(clean) : clean;
    }

    public static function clearRedirects():Void {
        stateRedirects.clear();
    }

    public static function call(func:String, ?args:Array<Dynamic>):Void {
        for (script in scripts) {
            if (script != null && script.isValid) {
                script.callAll(func, args);
            }
        }
    }

    public static function clear():Void {
        for (script in scripts) {
            if (script != null) {
                script.callAll("onDestroy", []);
                script.clear();
            }
        }
        scripts = [];
        stateRedirects.clear();
    }
}