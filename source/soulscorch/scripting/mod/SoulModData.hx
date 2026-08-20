package soulscorch.scripting.mod;

typedef SoulModData = {
    var name:String;
    var ?title:String;
    var version:String;
    var author:String;
    var description:String;
    var ?icon:String;
    var ?api_version:String;
    var ?dependencies:Array<String>;
    var ?global_scripts:Array<String>;
    var ?load_priority:Int;
    var ?priority:Int;
    var ?color:String;
    var ?folder:String;
}