package soulscorch.scripting;

import flixel.FlxG;
import flixel.FlxSubState;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.mod.ModLoader;

using StringTools;

class ScriptedSubState extends FlxSubState {
    public var scriptName:String;
    public var script:ScriptInstance;

    public function new(scriptName:String) {
        super();
        this.scriptName = scriptName;

        var possiblePaths = [
            'assets/data/substates/$scriptName.hx',
            'assets/substates/$scriptName.hx',
            'scripts/substates/$scriptName.hx'
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
            script.set("substate", this);
            script.set("add", add);
            script.set("remove", remove);
            script.set("close", close);

            script.call("create");
            script.call("onCreate");
        } else {
            Logger.warn('ScriptedSubState could not find $finalPath.', "script");
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
            script = null;
        }
        super.destroy();
    }
}