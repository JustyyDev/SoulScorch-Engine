package soulscorch.scripting;

import flixel.FlxSprite;

class ScriptedSprite extends FlxSprite {
    public var script:ScriptInstance;

    public function new(x:Float = 0, y:Float = 0, scriptName:String) {
        super(x, y);

        var path = 'scripts/components/$scriptName.hx';
        var scriptObj = new Script(path);

        scriptObj.set("this", this);
        scriptObj.set("sprite", this);
        this.script = scriptObj;

        if (script.active) {
            script.call("onReady");
        }
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        if (script != null && script.active) {
            script.call("onUpdate", [elapsed]);
        }
    }

    override public function destroy():Void {
        if (script != null && script.active) {
            script.call("onDestroy");
            script.destroy();
            script = null;
        }
        super.destroy();
    }
}