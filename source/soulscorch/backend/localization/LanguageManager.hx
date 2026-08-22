package soulscorch.backend.localization;

import haxe.Json;
import haxe.xml.Access;
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
        loadLanguageIntoMap(fallbackLanguage, fallbackStrings);
    }

    public function load(?lang:String):Bool {
        var target:String = (lang != null && lang.trim().length > 0) ? lang.trim().toLowerCase() : currentLanguage;
        
        strings.clear();
        var success:Bool = loadLanguageIntoMap(target, strings);

        if (!success && target != fallbackLanguage) {
            Logger.warn('Locale "$target" not found. Falling back to "$fallbackLanguage".', "i18n");
            success = loadLanguageIntoMap(fallbackLanguage, strings);
        }

        if (success) {
            currentLanguage = target;
        }
        return success;
    }

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
        var searchFolders = [
            "languages",
            "locales",
            "assets/languages",
            "assets/preload/languages",
            "assets/locales"
        ];

        #if sys
        var scanFolder = function(path:String) {
            if (FileSystem.exists(path) && FileSystem.isDirectory(path)) {
                for (item in FileSystem.readDirectory(path)) {
                    var full = '$path/$item';
                    if (FileSystem.isDirectory(full)) {
                        if (!langs.contains(item.toLowerCase())) langs.push(item.toLowerCase());
                    } else if (item.endsWith(".json") || item.endsWith(".xml")) {
                        var cleanName = item.substring(0, item.lastIndexOf(".")).toLowerCase();
                        if (!langs.contains(cleanName)) langs.push(cleanName);
                    }
                }
            }
        };

        for (dir in searchFolders) scanFolder(dir);

        if (ModManager.activeMods != null) {
            for (mod in ModManager.activeMods) {
                for (dir in searchFolders) {
                    scanFolder('mods/$mod/$dir');
                }
            }
        }
        #end

        if (!langs.contains("en")) langs.push("en");
        return langs;
    }

    private function loadLanguageIntoMap(lang:String, targetMap:Map<String, String>):Bool {
        var foundAny = false;
        var langSearchRoots = [
            'languages/$lang',
            'locales/$lang',
            'assets/languages/$lang',
            'assets/preload/languages/$lang',
            'data/languages/$lang',
            'data/locales/$lang'
        ];

        #if sys
        // Scan Mod Overrides First
        if (ModManager.activeMods != null) {
            for (mod in ModManager.activeMods) {
                for (root in langSearchRoots) {
                    var modDir = 'mods/$mod/$root';
                    if (FileSystem.exists(modDir) && FileSystem.isDirectory(modDir)) {
                        for (file in FileSystem.readDirectory(modDir)) {
                            if (loadFileIntoMap('$modDir/$file', targetMap)) foundAny = true;
                        }
                    }
                }
            }
        }

        // Scan Base Game Folders
        for (root in langSearchRoots) {
            if (FileSystem.exists(root) && FileSystem.isDirectory(root)) {
                for (file in FileSystem.readDirectory(root)) {
                    if (loadFileIntoMap('$root/$file', targetMap)) foundAny = true;
                }
            } else if (FileSystem.exists('$root.json') || FileSystem.exists('$root.xml')) {
                if (loadFileIntoMap(FileSystem.exists('$root.json') ? '$root.json' : '$root.xml', targetMap)) foundAny = true;
            }
        }
        #end

        return foundAny;
    }

    private function loadFileIntoMap(filePath:String, targetMap:Map<String, String>):Bool {
        #if sys
        if (!FileSystem.exists(filePath)) return false;

        try {
            var raw = File.getContent(filePath);
            if (raw == null || raw.trim().length == 0) return false;

            if (filePath.endsWith(".json")) {
                var parsed:Dynamic = Json.parse(raw);
                flattenJson(parsed, "", targetMap);
                return true;
            } else if (filePath.endsWith(".xml")) {
                var xmlObj = Xml.parse(raw);
                parseXmlNode(xmlObj.firstElement(), "", targetMap);
                return true;
            } else if (filePath.endsWith(".ini") || filePath.endsWith(".txt")) {
                var lines = raw.split("\n");
                for (l in lines) {
                    var line = l.trim();
                    if (line.length == 0 || line.startsWith("#") || line.startsWith(";")) continue;
                    var eq = line.indexOf("=");
                    if (eq != -1) {
                        targetMap.set(line.substr(0, eq).trim(), line.substr(eq + 1).trim());
                    }
                }
                return true;
            }
        } catch (e:Dynamic) {
            Logger.error('Failed reading locale file "$filePath": $e', "i18n");
        }
        #end
        return false;
    }

    private function parseXmlNode(node:Xml, prefix:String, targetMap:Map<String, String>):Void {
        if (node == null) return;

        for (elem in node.elements()) {
            var keyName = elem.get("id");
            if (keyName == null || keyName.length == 0) keyName = elem.get("name");
            if (keyName == null || keyName.length == 0) keyName = elem.nodeName;

            var fullKey = prefix.length > 0 ? '$prefix.$keyName' : keyName;

            // Direct text inside tag
            var text = elem.firstChild() != null ? elem.firstChild().nodeValue : "";
            if (text != null && text.trim().length > 0) {
                targetMap.set(fullKey, text.trim());
            }

            // Or attributes like <string id="play" text="Play" />
            if (elem.exists("text")) {
                targetMap.set(fullKey, elem.get("text"));
            } else if (elem.exists("value")) {
                targetMap.set(fullKey, elem.get("value"));
            }

            parseXmlNode(elem, fullKey, targetMap);
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