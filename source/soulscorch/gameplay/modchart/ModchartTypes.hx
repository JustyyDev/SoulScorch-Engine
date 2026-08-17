package soulscorch.gameplay.modchart;

import flixel.tweens.FlxEase.EaseFunction;

enum abstract ModTarget(Int) from Int to Int {
    var PLAYER = 0;
    var OPPONENT = 1;
    var BOTH = 2;
}

class RenderTransform {
    public var x:Float = 0.0;
    public var y:Float = 0.0;
    public var z:Float = 0.0;
    public var angle:Float = 0.0;
    public var alpha:Float = 1.0;
    public var scaleX:Float = 1.0;
    public var scaleY:Float = 1.0;
    public var skewX:Float = 0.0;
    public var skewY:Float = 0.0;

    public function new() {}

    public inline function reset():Void {
        x = 0.0;
        y = 0.0;
        z = 0.0;
        angle = 0.0;
        alpha = 1.0;
        scaleX = 1.0;
        scaleY = 1.0;
        skewX = 0.0;
        skewY = 0.0;
    }

    public inline function apply(transform:RenderTransform):Void {
        x += transform.x;
        y += transform.y;
        z += transform.z;
        angle += transform.angle;
        alpha *= transform.alpha;
        scaleX *= transform.scaleX;
        scaleY *= transform.scaleY;
        skewX += transform.skewX;
        skewY += transform.skewY;
    }
}

typedef ModchartEvent = {
    var step:Float;
    var modName:String;
    var targetValue:Float;
    var stepDuration:Float;
    var ease:EaseFunction;
    var target:ModTarget;
    var lane:Int; // -1 for all lanes
    var executed:Bool;
}