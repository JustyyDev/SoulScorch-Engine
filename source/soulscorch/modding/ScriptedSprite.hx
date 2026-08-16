package soulscorch.modding;

import flixel.FlxSprite;

class ScriptedSprite extends FlxSprite {
    public var script:ScriptCore;

    public function new(x:Float, y:Float, scriptName:String) {
        super(x, y);
        
        // Initialize the script attached specifically to this sprite
        var path = ModManager.getPath('scripts/components/$scriptName.hx');
        script = new ScriptCore(path);
        
        // Pass the sprite reference into the script so it can modify itself
        script.interp.variables.set("this", this);
        
        script.call("onReady");
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        script.call("onUpdate", [elapsed]);
    }

    override public function destroy():Void {
        script.call("onDestroy");
        super.destroy();
    }
}