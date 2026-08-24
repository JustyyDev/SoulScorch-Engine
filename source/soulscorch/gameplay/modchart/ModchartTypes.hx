package soulscorch.gameplay.modchart;

enum ModTarget {
    PLAYER;
    OPPONENT;
    BOTH;
}

typedef ModchartTarget = ModTarget;

typedef ModchartEvent = {
    var step:Float;
    var name:String;
    var value:Float;
    var duration:Float;
    var ease:String;
    var target:ModTarget;
    var ?lane:Int;
}