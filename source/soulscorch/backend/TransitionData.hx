package soulscorch.backend;

import flixel.tweens.FlxEase;
import flixel.util.FlxColor;

using StringTools;

enum TransitionType {
    FADE;
    WIPE;
    DIAMOND;
    GLITCH;
    CURTAIN;
    CIRCLE;
    BARS;
    SHUTTER;
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
    public var sound:Null<String>;

    public function new(
        type:TransitionType = WIPE,
        direction:TransitionDirection = OUT,
        duration:Float = 0.35,
        color:FlxColor = FlxColor.BLACK,
        ?ease:flixel.tweens.FlxEase.EaseFunction,
        ?sound:String
    ) {
        this.type = type;
        this.direction = direction;
        this.duration = duration;
        this.color = color;
        this.ease = ease != null ? ease : FlxEase.quartOut;
        this.sound = sound;
    }

    public static function parseType(name:String):TransitionType {
        return switch (name.toLowerCase().trim()) {
            case "fade": FADE;
            case "wipe": WIPE;
            case "diamond": DIAMOND;
            case "glitch": GLITCH;
            case "curtain": CURTAIN;
            case "circle": CIRCLE;
            case "bars": BARS;
            case "shutter": SHUTTER;
            case "none", "off": NONE;
            default: WIPE;
        };
    }

    public static function parseEase(easeName:String):flixel.tweens.FlxEase.EaseFunction {
        return switch (easeName.toLowerCase().trim()) {
            case "linear": FlxEase.linear;
            case "quadin": FlxEase.quadIn;
            case "quadout": FlxEase.quadOut;
            case "quadinout": FlxEase.quadInOut;
            case "cubein": FlxEase.cubeIn;
            case "cubeout": FlxEase.cubeOut;
            case "cubeinout": FlxEase.cubeInOut;
            case "quartin": FlxEase.quartIn;
            case "quartout": FlxEase.quartOut;
            case "quartinout": FlxEase.quartInOut;
            case "sinein": FlxEase.sineIn;
            case "sineout": FlxEase.sineOut;
            case "sineinout": FlxEase.sineInOut;
            case "bouncein": FlxEase.bounceIn;
            case "bounceout": FlxEase.bounceOut;
            case "elasticin": FlxEase.elasticIn;
            case "elasticout": FlxEase.elasticOut;
            case "circin": FlxEase.circIn;
            case "circout": FlxEase.circOut;
            case "backin": FlxEase.backIn;
            case "backout": FlxEase.backOut;
            default: FlxEase.quartOut;
        };
    }
}