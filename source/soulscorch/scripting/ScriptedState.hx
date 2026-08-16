package soulscorch.scripting;

import flixel.FlxG;
import flixel.FlxState;

class ScriptedState extends FlxState {
    public var scriptPath(default, null):String;
    public var scriptManager:ScriptManager;
    public var script:ScriptInstance;

    public function new(path:String) {
        super();
        scriptPath = path;
        scriptManager = new ScriptManager();
    }

    override public function create():Void {
        super.create();

        script = scriptManager.load(scriptPath);
        if (script == null || !script.active) return;

        script.set("this", this);
        script.set("state", this);
        script.set("game", this);
        script.set("add", add);
        script.set("remove", remove);
        script.set("insert", insert);

        script.call("create");
        script.call("onCreate");
    }

    override public function update(elapsed:Float):Void {
        if (script != null && script.active) script.call("update", [elapsed]);
        super.update(elapsed);
        if (script != null && script.active) script.call("updatePost", [elapsed]);
    }

    override public function destroy():Void {
        if (scriptManager != null) {
            scriptManager.dispatch("destroy");
            scriptManager.dispatch("onDestroy");
            scriptManager.clear();
        }
        super.destroy();
    }
}