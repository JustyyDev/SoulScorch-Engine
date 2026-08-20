package soulscorch.backend;

import flixel.tweens.FlxEase;
import flixel.util.FlxColor;

enum TransitionType {
    FADE;
    WIPE;
    DIAMOND;
    GLITCH;
    NONE;
}

enum TransitionDirection {
    IN;
    OUT;
}

class TransitionData {
    public var type:TransitionType;
    public var direction:TransitionDirection;
    public var duration:Float;
    public var color:FlxColor;
    public var ease:flixel.tweens.FlxEase.EaseFunction;

    public function new(
        type:TransitionType = WIPE,
        direction:TransitionDirection = OUT,
        duration:Float = 0.35,
        color:FlxColor = FlxColor.BLACK,
        ?ease:flixel.tweens.FlxEase.EaseFunction
    ) {
        this.type = type;
        this.direction = direction;
        this.duration = duration;
        this.color = color;
        this.ease = ease != null ? ease : FlxEase.quartOut;
    }
}