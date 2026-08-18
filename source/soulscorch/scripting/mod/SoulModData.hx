package soulscorch.scripting.mod;

import flixel.util.FlxColor;

typedef SoulModTitleBar = {
    var ?title:String;
    var ?icon:String;
}

typedef SoulModData = {
    var name:String;
    var version:String;
    var author:String;
    var ?api_version:String;
    var ?engine_version:String;
    var description:String;
    var ?color:String;
    var ?icon:String;
    var ?title_bar:SoulModTitleBar;
    var ?global_scripts:Array<String>;
    var ?dependencies:Array<String>;
    var ?incompatibilities:Array<String>;
    var ?flags:Array<String>;
    var ?load_priority:Int;
    var ?restart_required:Bool;
    var folder:String;
}