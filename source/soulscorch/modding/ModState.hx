package soulscorch.modding;

import soulscorch.core.Scene;
import flixel.FlxG;
import flixel.FlxSprite;

class ModState extends Scene {
    public var script:ScriptCore;
    public var stateName:String;

    public function new(stateName:String, scriptPath:String) {
        super();
        this.stateName = stateName;
        this.script = new ScriptCore(scriptPath);
    }

    override public function create():Void {
        super.create();
        
        // Pass the state instance itself to the script so it can add objects
        script.interp.variables.set("add", this.add);
        script.interp.variables.set("remove", this.remove);
        script.interp.variables.set("insert", this.insert);
        script.interp.variables.set("members", this.members);
        
        script.call("onCreate");
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        script.call("onUpdate", [elapsed]);
    }

    override public function beatHit(beat:Int):Void {
        super.beatHit(beat);
        script.call("onBeatHit", [beat]);
    }
    
    override public function stepHit(step:Int):Void {
        super.stepHit(step);
        script.call("onStepHit", [step]);
    }

    override public function destroy():Void {
        script.call("onDestroy");
        super.destroy();
    }
}