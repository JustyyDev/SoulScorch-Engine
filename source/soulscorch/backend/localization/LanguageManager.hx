package soulscorch.backend.localization;

import haxe.Json;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.ModLoader;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

typedef LanguageChangedCallback = String->Void;

class LanguageManager {
    public static var instance(get, null):LanguageManager;
    private static var _instance:LanguageManager;

    public var currentLanguage(default, null):String = "en";
    public var fallbackLanguage(default, null):String = "en";

    private var strings:Map<String, String> = new Map();
    private var callbacks:Array<LanguageChangedCallback> = [];

    public function new() {}

    public static inline function get_instance():LanguageManager {
        if (_instance == null) {
            _instance = new LanguageManager();
        }
        return _instance;
    }

    /**
     * Loads a locale file, falling back to the default language if not found.
     */
    public function load(?lang:String):Bool {
        var target:String = (lang != null && lang.length > 0) ? lang : currentLanguage;
        var success:Bool = loadFile(target);

        if (!success && target != fallbackLanguage) {
            Logger.warn('Locale "$target" not found. Falling back to "$fallbackLanguage".');
            success = loadFile(fallbackLanguage);
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
            Logger.info('Language switched from "$previous" to "$currentLanguage".');
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
        var result:String = strings.exists(key) ? strings.get(key) : key;

        if (tokens != null) {
            for (tokenName in tokens.keys()) {
                result = StringTools.replace(result, '{$tokenName}', Std.string(tokens.get(tokenName)));
            }
        }
        return result;
    }

    public static inline function getString(key:String, ?tokens:Map<String, Dynamic>):String {
        return instance.get(key, tokens);
    }

    public function has(key:String):Bool {
        return strings.exists(key);
    }

    public function onLanguageChanged(callback:LanguageChangedCallback):Void {
        if (callback != null && !callbacks.contains(callback)) {
            callbacks.push(callback);
        }
    }

    public function offLanguageChanged(callback:LanguageChangedCallback):Void {
        callbacks.remove(callback);
    }

    public function loadFile(lang:String):Bool {
        var path:String = ModLoader.getPath('assets/locales/$lang.json');
        if (path == null) {
            path = ModLoader.getPath('locales/$lang.json');
        }

        #if sys
        if (path == null || !FileSystem.exists(path)) {
            return false;
        }

        try {
            var rawContent:String = File.getContent(path);
            var parsed:Dynamic = Json.parse(rawContent);
            strings.clear();
            flattenJson(parsed, "");
            Logger.info('Loaded localization file: $path (${Lambda.count(strings)} entries)');
            return true;
        } catch (error:Dynamic) {
            Logger.error('Failed parsing locale file "$path": $error');
            return false;
        }
        #else
        return false;
        #end
    }

    private function flattenJson(value:Dynamic, prefix:String):Void {
        if (value == null) return;

        for (field in Reflect.fields(value)) {
            var keyPath:String = prefix.length == 0 ? field : '$prefix.$field';
            var child:Dynamic = Reflect.field(value, field);

            if (Reflect.isObject(child) && !Std.isOfType(child, String)) {
                flattenJson(child, keyPath);
            } else {
                strings.set(keyPath, Std.string(child));
            }
        }
    }
}