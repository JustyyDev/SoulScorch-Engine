package soulscorch.scripting.mod;

import soulscorch.backend.assets.AssetResolver;
import soulscorch.scripting.mod.ModManager;
import soulscorch.scripting.mod.SoulModData;

class ModLoader {
    public static var activeMods(get, never):Array<String>;
    inline static function get_activeMods():Array<String> return ModManager.activeMods;

    public static var allMods(get, never):Array<String>;
    inline static function get_allMods():Array<String> return ModManager.allMods;

    public static var modConfigs(get, never):Map<String, SoulModData>;
    inline static function get_modConfigs():Map<String, SoulModData> return ModManager.modConfigs;

    public static inline function scan():Void {
        ModManager.reloadMods();
    }

    public static inline function getPath(filePath:String):String {
        return ModManager.getPath(filePath);
    }

    public static inline function resolveAsset(filePath:String, ?extensions:Array<String>):String {
        return ModManager.resolveModAsset(filePath, extensions);
    }

    public static inline function exists(filePath:String):Bool {
        return AssetResolver.exists(filePath);
    }
}