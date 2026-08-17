package soulscorch.backend.system.modules;

interface Module {
    public var active:Bool;
    public var name:String;

    public function initialize():Void;
    public function update(elapsed:Float):Void;
    public function draw():Void;
    public function onStateSwitch():Void;
    public function onEvent(eventName:String, ?eventData:Dynamic):Void;
    public function destroy():Void;
}

class ModuleBase implements Module {
    public var active:Bool = true;
    public var name:String;

    public function new(name:String) {
        this.name = name;
    }

    public function initialize():Void {}
    public function update(elapsed:Float):Void {}
    public function draw():Void {}
    public function onStateSwitch():Void {}
    public function onEvent(eventName:String, ?eventData:Dynamic):Void {}
    public function destroy():Void {
        active = false;
    }
}