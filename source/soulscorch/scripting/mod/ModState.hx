package soulscorch.scripting.mod;

import flixel.FlxG;
import soulscorch.backend.system.Scene;
import soulscorch.scripting.backends.HScriptIris;

class ModState extends Scene {
    public var script:HScriptIris;
    public var stateName:String;

    public function new(stateName:String, scriptPath:String) {
        super();
        this.stateName = stateName;
        this.script = new HScriptIris(scriptPath);
    }

    override public function create():Void {
        super.create();

        if (script != null) {
            script.set("state", this);
            script.set("add", this.add);
            script.set("remove", this.remove);
            script.set("insert", this.insert);
            script.set("members", this.members);
            script.set("switchState", function(nextState) {
                FlxG.switchState(nextState);
            });
            script.set("openSubState", function(subState) {
                openSubState(subState);
            });

            script.call("create");
            script.call("onCreate");
            script.call("postCreate");
            script.call("onCreatePost");
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

    override public function beatHit(beat:Int):Void {
        super.beatHit(beat);
        if (script != null && script.active) {
            script.call("beatHit", [beat]);
            script.call("onBeatHit", [beat]);
        }
    }

    override public function stepHit(step:Int):Void {
        super.stepHit(step);
        if (script != null && script.active) {
            script.call("stepHit", [step]);
            script.call("onStepHit", [step]);
        }
    }

    override public function destroy():Void {
        if (script != null) {
            script.call("destroy");
            script.call("onDestroy");
            script.destroy();
            script = null;
        }
        super.destroy();
    }
}