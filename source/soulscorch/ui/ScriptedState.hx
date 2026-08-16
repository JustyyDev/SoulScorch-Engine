package soulscorch.ui;

import flixel.FlxG;
import soulscorch.core.Scene;
import soulscorch.modding.Script;
import soulscorch.assets.AssetResolver;
import soulscorch.modding.ModLoader;
import soulscorch.core.Logger;

class ScriptedState extends Scene {
    public var scriptName:String;
    public var script:Script;

    public function new(scriptName:String) {
        super();
        this.scriptName = scriptName;
    }

    override public function create():Void {
        super.create();

        var scriptPath = 'assets/data/states/$scriptName.hx';
        script = new Script(scriptPath);

        if (script.active) {
            script.set("state", this);
            script.set("add", add);
            script.set("remove", remove);
            script.set("insert", insert);
            script.set("members", members);
            script.set("switchState", function(nextState) {
                FlxG.switchState(nextState);
            });
            script.set("openSubState", function(subState) {
                openSubState(subState);
            });

            script.call("create");
            script.call("onCreate");
            script.call("createPost");
            script.call("onCreatePost");
        } else {
            Logger.warn("script", 'ScriptedState could not find $scriptPath, falling back.');
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

    override public function stepHit(step:Int):Void {
        super.stepHit(step);
        if (script != null && script.active) {
            script.call("stepHit", [step]);
            script.call("onStepHit", [step]);
        }
    }

    override public function beatHit(beat:Int):Void {
        super.beatHit(beat);
        if (script != null && script.active) {
            script.call("beatHit", [beat]);
            script.call("onBeatHit", [beat]);
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