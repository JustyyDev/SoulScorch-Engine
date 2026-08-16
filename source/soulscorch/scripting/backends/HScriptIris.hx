package soulscorch.scripting.backends;

import flixel.FlxG;
import soulscorch.gameplay.Conductor;
import soulscorch.modding.Script;
import soulscorch.scripting.ScriptInstance;

class HScriptIris implements ScriptInstance {
    public var active:Bool = false;
    public var path(default, null):String;
    private var script:Script;

    public function new(scriptPath:String) {
        path = scriptPath == null ? "" : scriptPath;
        script = new Script(path);
        active = script.active;
        set("FlxG", FlxG); set("Conductor", Conductor); set("game", FlxG.state);
    }

    public function importClass(className:String):Bool {
        if (script == null || !script.active || className == null) return false;
        var value:Dynamic = switch (className) { case "flixel.FlxG": FlxG; case "soulscorch.gameplay.Conductor": Conductor; default: null; };
        if (value == null) return false;
        var shortName:String = className.substr(className.lastIndexOf(".") + 1);
        script.set(shortName, value);
        return true;
    }

    public function call(func:String, ?args:Array<Dynamic>):Dynamic return script == null ? null : script.call(func, args);
    public function set(key:String, value:Dynamic):Void if (script != null) script.set(key, value);
    public function get(key:String):Dynamic return script == null ? null : script.get(key);
    public function destroy():Void { active = false; if (script != null) script.destroy(); script = null; }
}
