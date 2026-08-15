package soulscorch.core;

interface Module {
    public var active:Bool;
    public var name:String;
    
    public function initialize(engine:Engine):Void;
    public function update(elapsed:Float):Void;
    public function draw():Void;
    public function onStateSwitch():Void;
    public function destroy():Void;
}