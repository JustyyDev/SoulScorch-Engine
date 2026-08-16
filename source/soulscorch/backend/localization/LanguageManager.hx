package soulscorch.backend.localization;

import haxe.Json;
import soulscorch.modding.ModManager;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

typedef LanguageChanged = String->Void;

class LanguageManager {
    public static var instance:LanguageManager = new LanguageManager();
    public var language(default, null):String = "en";
    public var fallback(default, null):String = "en";
    private var values:Map<String, String> = new Map();
    private var callbacks:Array<LanguageChanged> = [];
    public function new() {}
    public function load(?lang:String):Bool {
        var requested:String = lang == null || lang.length == 0 ? language : lang;
        var loaded:Bool = loadFile(requested);
        if (!loaded && requested != fallback) loaded = loadFile(fallback);
        if (loaded) language = requested;
        return loaded;
    }
    public function setLanguage(lang:String):Bool { var old:String = language; var result:Bool = load(lang); if (result && old != language) for (callback in callbacks) if (callback != null) callback(language); return result; }
    public function get(key:String, ?tokens:Map<String, Dynamic>):String {
        var result:String = values.exists(key) ? values.get(key) : key;
        if (tokens != null) for (name in tokens.keys()) result = result.split("{" + name + "}").join(Std.string(tokens.get(name)));
        return result;
    }
    public function onLanguageChanged(callback:LanguageChanged):Void if (callback != null && !callbacks.contains(callback)) callbacks.push(callback);
    public function offLanguageChanged(callback:LanguageChanged):Void callbacks.remove(callback);
    public function loadFile(lang:String):Bool {
        var path:String = ModManager.getPath('locales/$lang.json');
        #if sys
        if (path == null || !FileSystem.exists(path)) return false;
        try { var raw:Dynamic = Json.parse(File.getContent(path)); values = new Map(); flatten(raw, ""); return true; } catch (error:Dynamic) { return false; }
        #else
        return false;
        #end
    }
    private function flatten(value:Dynamic, prefix:String):Void {
        if (value == null) return;
        for (field in Reflect.fields(value)) { var next:String = prefix.length == 0 ? field : prefix + "." + field; var child:Dynamic = Reflect.field(value, field); if (Reflect.isObject(child) && !Std.isOfType(child, String)) flatten(child, next); else values.set(next, Std.string(child)); }
    }
}
