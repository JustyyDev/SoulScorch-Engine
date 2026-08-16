package soulscorch.scripting;

import flixel.FlxSubState;
import soulscorch.scripting.backends.HScriptIris;

class ScriptedSubState extends FlxSubState {
    public var scriptPath(default, null):String;
    public var script:ScriptInstance;
    public function new(path:String) { super(); scriptPath = path; }
    override public function create():Void { super.create(); script = new HScriptIris(scriptPath); if (script == null || !script.active) return; script.set("substate", this); script.set("add", add); script.set("remove", remove); script.set("close", close); script.call("create"); script.call("onCreate"); }
    override public function update(elapsed:Float):Void { if (script != null && script.active) script.call("update", [elapsed]); super.update(elapsed); if (script != null && script.active) script.call("updatePost", [elapsed]); }
    override public function destroy():Void { if (script != null) { script.call("destroy"); script.destroy(); } super.destroy(); }
}
