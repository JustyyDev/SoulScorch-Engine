package soulscorch.scripting.mod;

import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.ScriptInstance;
import soulscorch.scripting.backends.ScriptBackendType;
import soulscorch.scripting.mod.ModManager;

#if sys
import sys.FileSystem;
#end

using StringTools;

class SoulGlobalScript {
    public static var scripts:Array<ScriptInstance> = [];
    public static var stateRedirects:Map<String, String> = new Map<String, String>();
    private static var _loadedPaths:Array<String> = [];

    public static function init():Void {
        clear();

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

            var defaultModGlobals = [
                'mods/$mod/scripts/global.soul',
                'mods/$mod/scripts/global.hx',
                'mods/$mod/scripts/global.hscript',
                'mods/$mod/scripts/global.iris',
                'mods/$mod/scripts/global.lua',
                'mods/$mod/scripts/global.py',
                'mods/$mod/data/scripts/global.soul',
                'mods/$mod/data/scripts/global.hx',
                'mods/$mod/data/scripts/global.hscript',
                'mods/$mod/data/scripts/global.iris',
                'mods/$mod/data/scripts/global.lua',
                'mods/$mod/data/scripts/global.py',
                'mods/$mod/data/global.soul',
                'mods/$mod/data/global.hx',
                'mods/$mod/data/global.hscript',
                'mods/$mod/data/global.iris',
                'mods/$mod/data/global.lua',
                'mods/$mod/data/global.py'
            ];
            for (p in defaultModGlobals) {
                if (FileSystem.exists(p) && !scriptPaths.contains(p)) {
                    scriptPaths.push(p);
                }
            }
        }
        #end

        var baseGlobals = [
            "data/scripts/global",
            "scripts/global",
            "data/global"
        ];
        for (bg in baseGlobals) {
            var resolved = AssetResolver.resolveFile(bg, [".soul", ".hx", ".hscript", ".iris", ".lua", ".py", ""]);
            if (resolved != null && !scriptPaths.contains(resolved)) {
                scriptPaths.push(resolved);
            }
        }

        for (path in scriptPaths) {
            if (_loadedPaths.contains(path)) continue;

            var instance:ScriptInstance = ScriptBackendType.createInstance(path);
            if (instance != null && instance.active) {
                ScriptAPI.install(instance);
                _loadedPaths.push(path);
                registerScriptGlobals(instance);
                instance.call("create", []);
                instance.call("onCreate", []);
                scripts.push(instance);
            }
        }

        var redirectCount = 0;
        for (_ in stateRedirects) redirectCount++;

        Logger.info('Global scripts initialized (${scripts.length} active, ${redirectCount} state redirect(s)).', "scripts");
    }

    private static function registerScriptGlobals(script:ScriptInstance):Void {
        script.set("redirectState", redirectState);
        script.set("getRedirect", getRedirect);
        script.set("clearRedirects", clearRedirects);
        script.set("addStateRedirect", redirectState);
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
            if (script != null && script.active) {
                script.call(func, args);
            }
        }
    }

    public static function clear():Void {
        for (script in scripts) {
            if (script != null) {
                script.call("onDestroy", []);
                script.destroy();
            }
        }
        scripts = [];
        _loadedPaths = [];
        stateRedirects.clear();
    }
}