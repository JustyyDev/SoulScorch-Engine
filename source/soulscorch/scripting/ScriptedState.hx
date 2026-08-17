package soulscorch.scripting;

import flixel.FlxG;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.system.Scene;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.mod.ModLoader;

using StringTools;

class ScriptedState extends Scene {
    public var scriptName:String;
    public var script:ScriptInstance;

    public function new(scriptName:String) {
        super();
        this.scriptName = scriptName;
    }

    override public function create():Void {
        super.create();

        var possiblePaths = [
            'assets/data/states/$scriptName.hx',
            'assets/states/$scriptName.hx',
            'scripts/states/$scriptName.hx'
        ];

        var finalPath:String = null;
        for (p in possiblePaths) {
            var resolved = ModLoader.getPath(p);
            if (AssetResolver.exists(resolved)) {
                finalPath = resolved;
                break;
            }
        }

        if (finalPath == null) finalPath = possiblePaths[0];

        var scriptObj = new Script(finalPath);
        this.script = scriptObj;

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
            Logger.warn('ScriptedState could not find $finalPath, falling back.', "script");
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
            script = null;
        }
        super.destroy();
    }
}