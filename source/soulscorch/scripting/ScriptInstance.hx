package soulscorch.scripting;

interface ScriptInstance {
    public var active:Bool;
    public var path(default, null):String;

    public function call(func:String, ?args:Array<Dynamic>):Dynamic;
    public function set(key:String, value:Dynamic):Void;
    public function get(key:String):Dynamic;
    public function destroy():Void;
}