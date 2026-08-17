package soulscorch.backend.interfaces;

interface IScriptable {
    public function call(func:String, ?args:Array<Dynamic>):Dynamic;
    public function set(variable:String, value:Dynamic):Void;
    public function get(variable:String):Dynamic;
}