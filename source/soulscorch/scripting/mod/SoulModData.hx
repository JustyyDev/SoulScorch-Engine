package soulscorch.scripting.mod;

typedef SoulModData = {
    var name:String;
    var version:String;
    var api_version:String;
    var description:String;
    var color:String;
    var global_scripts:Array<String>;
    var flags:Array<String>;
    var load_priority:Int;
    var ?restart_required:Bool;
    var ?dependencies:Array<String>;
    var ?author:String;
}