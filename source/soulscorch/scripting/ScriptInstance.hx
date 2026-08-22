package soulscorch.scripting;

interface ScriptInstance {
    public var active:Bool;
    public var path(default, null):String;

    public function load():Bool;
    public function call(func:String, ?args:Array<Dynamic>):Dynamic;
    public function set(key:String, value:Dynamic):Void;
    public function get(key:String):Dynamic;
    public function importClass(className:String):Bool;
    public function destroy():Void;
}