package soulscorch.backend.localization;

import haxe.Json;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.mod.ModManager;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

typedef LanguageChangedCallback = String->Void;

class LanguageManager {
    public static var instance(get, null):LanguageManager;
    private static var _instance:LanguageManager;

    public var currentLanguage(default, null):String = "en";
    public var fallbackLanguage(default, null):String = "en";

    private var strings:Map<String, String> = new Map<String, String>();
    private var fallbackStrings:Map<String, String> = new Map<String, String>();
    private var callbacks:Array<LanguageChangedCallback> = [];

    public function new() {
        loadFallback();
    }

    public static inline function get_instance():LanguageManager {
        if (_instance == null) {
            _instance = new LanguageManager();
        }
        return _instance;
    }

    private function loadFallback():Void {
        fallbackStrings.clear();
        loadTableIntoMap(fallbackLanguage, fallbackStrings);
    }

    /**
     * Loads a locale file, falling back to the default language table if missing.
     */
    public function load(?lang:String):Bool {
        var target:String = (lang != null && lang.trim().length > 0) ? lang.trim().toLowerCase() : currentLanguage;
        
        strings.clear();
        var success:Bool = loadTableIntoMap(target, strings);

        if (!success && target != fallbackLanguage) {
            Logger.warn('Locale "$target" not found. Falling back to "$fallbackLanguage".', "i18n");
            success = loadTableIntoMap(fallbackLanguage, strings);
        }

        if (success) {
            currentLanguage = target;
        }
        return success;
    }

    /**
     * Changes the active language and notifies all registered subscribers.
     */
    public function setLanguage(lang:String):Bool {
        var previous:String = currentLanguage;
        var loaded:Bool = load(lang);

        if (loaded && previous != currentLanguage) {
            Logger.info('Language switched from "$previous" to "$currentLanguage".', "i18n");
            for (callback in callbacks) {
                if (callback != null) {
                    callback(currentLanguage);
                }
            }
        }
        return loaded;
    }

    /**
     * Resolves a key into translated text with token interpolation (e.g., {score}).
     */
    public function get(key:String, ?tokens:Map<String, Dynamic>):String {
        var result:String = null;

        if (strings.exists(key)) {
            result = strings.get(key);
        } else if (fallbackStrings.exists(key)) {
            result = fallbackStrings.get(key);
        } else {
            result = key;
        }

        if (tokens != null) {
            for (tokenName in tokens.keys()) {
                result = result.replace('{$tokenName}', Std.string(tokens.get(tokenName)));
            }
        }
        return result;
    }

    public static inline function getString(key:String, ?tokens:Map<String, Dynamic>):String {
        return instance.get(key, tokens);
    }

    public function has(key:String):Bool {
        return strings.exists(key) || fallbackStrings.exists(key);
    }

    public function onLanguageChanged(callback:LanguageChangedCallback):Void {
        if (callback != null && !callbacks.contains(callback)) {
            callbacks.push(callback);
        }
    }

    public function offLanguageChanged(callback:LanguageChangedCallback):Void {
        callbacks.remove(callback);
    }

    public function getAvailableLanguages():Array<String> {
        var langs:Array<String> = [];
        var candidates = ["locales", "languages", "data/locales"];

        #if sys
        for (dir in candidates) {
            if (FileSystem.exists(dir) && FileSystem.isDirectory(dir)) {
                for (file in FileSystem.readDirectory(dir)) {
                    if (file.endsWith(".json")) {
                        var id = file.substr(0, file.length - 5).toLowerCase();
                        if (!langs.contains(id)) langs.push(id);
                    }
                }
            }
        }

        if (ModManager.activeMods != null) {
            for (mod in ModManager.activeMods) {
                for (dir in candidates) {
                    var full = 'mods/$mod/$dir';
                    if (FileSystem.exists(full) && FileSystem.isDirectory(full)) {
                        for (file in FileSystem.readDirectory(full)) {
                            if (file.endsWith(".json")) {
                                var id = file.substr(0, file.length - 5).toLowerCase();
                                if (!langs.contains(id)) langs.push(id);
                            }
                        }
                    }
                }
            }
        }
        #end

        if (langs.length == 0) langs = ["en"];
        return langs;
    }

    private function loadTableIntoMap(lang:String, targetMap:Map<String, String>):Bool {
        var candidates = [
            'locales/$lang',
            'languages/$lang',
            'data/locales/$lang',
            'assets/locales/$lang',
            'assets/languages/$lang'
        ];

        var resolved:String = null;
        for (c in candidates) {
            resolved = AssetResolver.resolveFile(c, [".json", ""]);
            if (resolved != null) break;
        }

        if (resolved == null) return false;

        try {
            var rawContent = AssetResolver.getText(resolved);
            if (rawContent.length == 0) return false;

            var parsed:Dynamic = Json.parse(rawContent);
            flattenJson(parsed, "", targetMap);
            Logger.info('Loaded localization table: $resolved (${Lambda.count(targetMap)} keys)', "i18n");
            return true;
        } catch (e:Dynamic) {
            Logger.error('Failed parsing localization file "$resolved": $e', "i18n");
            return false;
        }
    }

    private function flattenJson(value:Dynamic, prefix:String, targetMap:Map<String, String>):Void {
        if (value == null) return;

        for (field in Reflect.fields(value)) {
            var keyPath:String = prefix.length == 0 ? field : '$prefix.$field';
            var child:Dynamic = Reflect.field(value, field);

            if (Reflect.isObject(child) && !Std.isOfType(child, String)) {
                flattenJson(child, keyPath, targetMap);
            } else {
                targetMap.set(keyPath, Std.string(child));
            }
        }
    }
}