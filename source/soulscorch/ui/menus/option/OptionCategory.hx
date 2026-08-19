package soulscorch.ui.menus.option;

import flixel.util.FlxColor;

typedef OptionData = {
    var name:String;
    var description:String;
    var type:String; // "bool", "int", "float", "enum", "keybind", "button"
    var ?min:Float;
    var ?max:Float;
    var ?step:Float;
    var ?options:Array<String>;
    var ?formatValue:Dynamic->String;
    var getValue:Void->Dynamic;
    var setValue:Dynamic->Void;
}

class OptionCategory {
    public var name:String;
    public var icon:String;
    public var color:FlxColor;
    public var options:Array<OptionData> = [];

    public function new(name:String, ?icon:String = "options", ?color:FlxColor = 0xFF221A30, options:Array<OptionData>) {
        this.name = name;
        this.icon = icon;
        this.color = color;
        this.options = options != null ? options : [];
    }
}