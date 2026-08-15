package soulscorch.ui;

import flixel.FlxG;
import flixel.FlxSubState;
import soulscorch.modding.Script;

class ScriptedSubState extends FlxSubState {
    public var scriptName:String;
    public var script:Script;

    public function new(scriptName:String) {
        super();
        this.scriptName = scriptName;

        var scriptPath = 'assets/data/substates/$scriptName.hx';
        script = new Script(scriptPath);

        if (script.active) {
            script.set("substate", this);
            script.set("add", add);
            script.set("remove", remove);
            script.set("close", close);
            script.call("create");
            script.call("onCreate");
        }
    }

    override public function update(elapsed:Float):Void {
        if (script != null && script.active) {
            script.call("update", [elapsed]);
            script.call("onUpdate", [elapsed]);
        }

        super.update(elapsed);

        if (script != null && script.active) {
            script.call("updatePost", [elapsed]);
            script.call("onUpdatePost", [elapsed]);
        }
    }

    override public function destroy():Void {
        if (script != null && script.active) {
            script.call("destroy");
            script.call("onDestroy");
            script.destroy();
        }
        super.destroy();
    }
}