package soulscorch.scripting.mod;

import soulscorch.scripting.mod.SoulModData;

class ModLoader {
    public static var activeMods(get, never):Array<String>;
    public static var loadedModConfigs(get, never):Map<String, SoulModData>;
    public static var globalFlags:Map<String, Bool> = new Map<String, Bool>();

    public static inline function get_activeMods():Array<String> {
        return ModRegistry.instance.enabledMods;
    }

    public static inline function get_loadedModConfigs():Map<String, SoulModData> {
        return ModManager.modConfigs;
    }

    public static function scan():Void {
        ModManager.reloadMods();
    }

    public static function syncWithManager():Void {
        globalFlags.clear();
        for (mod in activeMods) {
            var config = loadedModConfigs.get(mod);
            if (config != null && config.flags != null) {
                for (flag in config.flags) {
                    globalFlags.set(flag, true);
                }
            }
        }
    }

    public static function hasFlag(flagName:String):Bool {
        return globalFlags.exists(flagName);
    }

    public static function getPath(relPath:String):String {
        return ModManager.getPath(relPath);
    }
}