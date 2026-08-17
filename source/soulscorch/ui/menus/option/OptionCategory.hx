package soulscorch.ui.menus.option;

typedef OptionData = {
    var name:String;
    var description:String;
    var type:String; // "bool", "int", "float", "keybind", "enum"
    var ?min:Float;
    var ?max:Float;
    var ?step:Float;
    var ?options:Array<String>;
    var getValue:Void->Dynamic;
    var setValue:Dynamic->Void;
}

class OptionCategory {
    public var name:String;
    public var options:Array<OptionData> = [];

    public function new(name:String, options:Array<OptionData>) {
        this.name = name;
        this.options = options;
    }
}