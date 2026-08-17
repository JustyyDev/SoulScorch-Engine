package soulscorch.scripting.mod;

import soulscorch.scripting.mod.SoulModData;

class ModLoader {
    public static var activeMods(get, never):Array<String>;

    public static inline function get_activeMods():Array<String> {
        return ModManager.activeMods;
    }

    public function new() {}

    public function scan():Void {
        ModManager.reloadMods();
    }

    public static function scanMods():Void {
        ModManager.reloadMods();
    }

    public static inline function getPath(assetPath:String):String {
        return ModManager.getPath(assetPath);
    }

    public static inline function resolveAsset(path:String):Null<String> {
        var resolved = ModManager.getPath(path);
        return (resolved != null && resolved.length > 0) ? resolved : null;
    }
}