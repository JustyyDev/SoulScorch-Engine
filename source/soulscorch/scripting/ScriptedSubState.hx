package soulscorch.scripting;

import flixel.FlxG;
import flixel.FlxSubState;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.backends.ScriptBackendType;
import soulscorch.scripting.mod.ModLoader;

using StringTools;

class ScriptedSubState extends FlxSubState {
    public var scriptName:String;
    public var script:ScriptInstance;

    private static final SUPPORTED_EXTENSIONS:Array<String> = [
        "hx", "soul", "lua", "py", "hscript"
    ];

    private static final SEARCH_DIRECTORIES:Array<String> = [
        "data/substates/", "scripts/substates/", "data/"
    ];

    public function new(scriptName:String) {
        super();
        this.scriptName = scriptName;

        var finalScriptPath:String = null;
        for (dir in SEARCH_DIRECTORIES) {
            for (ext in SUPPORTED_EXTENSIONS) {
                var testPath = ModLoader.getPath('$dir$scriptName.$ext');
                if (AssetResolver.exists(testPath)) {
                    finalScriptPath = testPath;
                    break;
                }
            }
            if (finalScriptPath != null) break;
        }

        if (finalScriptPath != null) {
            this.script = ScriptBackendType.createInstance(finalScriptPath);
            if (script != null && script.active) {
                ScriptAPI.install(script);
                script.set("substate", this);
                script.set("add", add);
                script.set("remove", remove);
                script.set("close", close);
                script.set("Paths", Paths);
                script.set("Conductor", Conductor);

                script.call("create", []);
                script.call("onCreate", []);
            }
        } else {
            Logger.warn('ScriptedSubState could not find script for $scriptName.', "script");
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
            script.call("destroy", []);
            script.call("onDestroy", []);
            script.destroy();
            script = null;
        }
        super.destroy();
    }
}