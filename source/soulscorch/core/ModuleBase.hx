package soulscorch.core;

/**
 * Convenience base class implementing the Module interface with no-op defaults.
 * Subclasses override only the hooks they need.
 */
class ModuleBase implements Module {
    public var active:Bool = true;
    public var name:String;

    public function new(name:String) {
        this.name = name;
    }

    public function initialize(engine:Engine):Void {}

    public function update(elapsed:Float):Void {}

    public function draw():Void {}

    public function onStateSwitch():Void {}

    public function destroy():Void {
        active = false;
    }
}
