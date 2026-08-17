package soulscorch.core;

import haxe.Json;
import openfl.utils.Assets;
import soulscorch.modding.ModLoader;

/**
 * Internationalization helper. Strings can be registered in code or loaded from
 * a JSON table resolved through the mod loader. Falls back to the key when a
 * translation is missing.
 */
class Localization {
    public static var instance(default, null):Localization;

    public var locale:String = "en-US";
    var strings:Map<String, String> = new Map();

    public function new() {
        instance = this;
    }

    public function register(key:String, value:String):Void {
        strings.set(key, value);
    }

    public function loadFile(path:String):Void {
        try {
            var resolved = ModLoader.getPath(path);
            if (Assets.exists(resolved)) {
                var raw = Assets.getText(resolved);
                var parsed:Dynamic = Json.parse(raw);
                for (field in Reflect.fields(parsed)) {
                    strings.set(field, Reflect.field(parsed, field));
                }
                Logger.info("i18n", 'Loaded locale table from $path');
            }
        } catch (e:Dynamic) {
            Logger.error("i18n", "Failed to load localization $path: " + e);
        }
    }

    public function get(key:String, ?fallback:String):String {
        if (strings.exists(key)) return strings.get(key);
        return fallback != null ? fallback : key;
    }

    public function has(key:String):Bool {
        return strings.exists(key);
    }

    public function setLocale(loc:String):Void {
        locale = loc;
        strings = new Map();
        loadFile('assets/languages/$loc.json');
    }
}
