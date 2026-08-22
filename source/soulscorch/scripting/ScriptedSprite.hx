package soulscorch.scripting;

import flixel.FlxSprite;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.scripting.backends.ScriptBackendType;

using StringTools;

class ScriptedSprite extends FlxSprite {
    public var script:ScriptInstance;

    public function new(x:Float = 0, y:Float = 0, scriptName:String) {
        super(x, y);

        var resolved = AssetResolver.resolveFile('scripts/components/$scriptName', [".hx", ".soul", ".lua", ".py", ".hscript", ""]);
        var finalPath = (resolved != null) ? resolved : 'scripts/components/$scriptName.hx';

        this.script = ScriptBackendType.createInstance(finalPath);
        if (script != null && script.active) {
            script.set("this", this);
            script.set("sprite", this);
            script.call("onReady", []);
            script.call("create", []);
        }
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        if (script != null && script.active) {
            script.call("onUpdate", [elapsed]);
            script.call("update", [elapsed]);
        }
    }

    override public function destroy():Void {
        if (script != null && script.active) {
            script.call("onDestroy", []);
            script.destroy();
            script = null;
        }
        super.destroy();
    }
}