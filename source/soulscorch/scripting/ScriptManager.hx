package soulscorch.scripting;

import soulscorch.modding.ModManager;
import soulscorch.scripting.backends.HScriptIris;
import soulscorch.scripting.backends.LuaScript;
import soulscorch.scripting.soul.SoulScriptParser;
import soulscorch.backend.localization.LanguageManager;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

class ScriptManager {
    public var scripts:Array<ScriptInstance> = [];
    public var globals:Map<String, Dynamic> = new Map();
    private var timestamps:Map<String, Float> = new Map();
    public function new() {}
    public function load(path:String):ScriptInstance {
        if (path == null || path.length == 0) return null; var resolved:String = ModManager.getPath(path); var dot:Int = path.lastIndexOf("."); var ext:String = dot >= 0 ? path.substr(dot + 1).toLowerCase() : "hx";
        var instance:ScriptInstance = switch (ext) { case "lua": new LuaScript(resolved); case "soul", "ss": new HScriptIris(createSoulFile(resolved)); default: new HScriptIris(resolved); };
        for (name in globals.keys()) instance.set(name, globals.get(name));
        if (instance.active) { scripts.push(instance); rememberTimestamp(resolved); return instance; } instance.destroy(); return null;
    }
    public function loadDirectory(path:String):Void {
        #if sys
        var resolved:String = ModManager.getPath(path); if (resolved == null || !FileSystem.exists(resolved) || !FileSystem.isDirectory(resolved)) return;
        for (file in FileSystem.readDirectory(resolved)) { var lower:String = file.toLowerCase(); if (hasSuffix(lower, ".hx") || hasSuffix(lower, ".hscript") || hasSuffix(lower, ".lua") || hasSuffix(lower, ".soul") || hasSuffix(lower, ".ss")) load(path + "/" + file); }
        #end
    }
    public function dispatch(event:String, ?args:Array<Dynamic>):Void {
        var dead:Array<ScriptInstance> = []; for (script in scripts) { if (script == null || !script.active) dead.push(script); else script.call(event, args); }
        for (script in dead) if (script != null) { script.destroy(); scripts.remove(script); }
    }
    public function setGlobal(name:String, value:Dynamic):Void { globals.set(name, value); for (script in scripts) if (script != null && script.active) script.set(name, value); }
    public function getText(key:String, ?tokens:Map<String, Dynamic>):String return LanguageManager.instance.get(key, tokens);
    public function setLanguage(language:String):Bool return LanguageManager.instance.setLanguage(language);
    public function updateHotReload():Void {
        #if sys
        var reload:Array<String> = []; for (script in scripts) if (script != null && script.active && FileSystem.exists(script.path)) { var time:Float = FileSystem.stat(script.path).mtime.getTime(); if (timestamps.exists(script.path) && timestamps.get(script.path) != time) reload.push(script.path); else timestamps.set(script.path, time); }
        for (path in reload) { for (script in scripts) if (script.path == path) { script.destroy(); scripts.remove(script); break; } load(path); }
        #end
    }
    public function clear():Void { for (script in scripts) if (script != null) script.destroy(); scripts = []; timestamps.clear(); }
    private function rememberTimestamp(path:String):Void { #if sys if (FileSystem.exists(path)) timestamps.set(path, FileSystem.stat(path).mtime.getTime()); #end }
    private function createSoulFile(path:String):String { #if sys if (FileSystem.exists(path)) { var temp:String = path + ".transpiled.hx"; File.saveContent(temp, SoulScriptParser.transpile(File.getContent(path))); return temp; } #end return path; }
    private static function hasSuffix(value:String, suffix:String):Bool return value != null && suffix != null && value.length >= suffix.length && value.substr(value.length - suffix.length) == suffix;
}
