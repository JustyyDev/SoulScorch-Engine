package soulscorch.core;

import soulscorch.backend.localization.LanguageManager;

class Localization {
    public static var instance(get, null):Localization;
    private static var _instance:Localization;

    public var locale(get, set):String;

    public function new() {
        _instance = this;
    }

    public static inline function get_instance():Localization {
        if (_instance == null) {
            _instance = new Localization();
        }
        return _instance;
    }

    inline function get_locale():String {
        return LanguageManager.instance.currentLanguage;
    }

    inline function set_locale(v:String):String {
        LanguageManager.instance.setLanguage(v);
        return LanguageManager.instance.currentLanguage;
    }

    public inline function register(key:String, value:String):Void {
        // Direct registrations can be handled dynamically
        LanguageManager.instance.get(key);
    }

    public inline function loadFile(path:String):Void {
        LanguageManager.instance.load(path);
    }

    public inline function get(key:String, ?fallback:String):String {
        if (LanguageManager.instance.has(key)) {
            return LanguageManager.instance.get(key);
        }
        return (fallback != null) ? fallback : key;
    }

    public inline function has(key:String):Bool {
        return LanguageManager.instance.has(key);
    }

    public inline function setLocale(loc:String):Void {
        LanguageManager.instance.setLanguage(loc);
    }
}