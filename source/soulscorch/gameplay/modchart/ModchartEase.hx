package soulscorch.gameplay.modchart;

import flixel.tweens.FlxEase;
import flixel.tweens.FlxEase.EaseFunction;

using StringTools;

class ModchartEase {
    /**
     * Resolves a string ease name from charts or scripts into a FlxEase function.
     */
    public static function getEase(name:String):EaseFunction {
        if (name == null || name.length == 0) return FlxEase.linear;

        var clean = name.toLowerCase().trim().replace("_", "").replace("-", "").replace(" ", "");
        return switch (clean) {
            case "linear": FlxEase.linear;
            case "smooth" | "smoothstep": FlxEase.smoothStepInOut;
            case "sinein": FlxEase.sineIn;
            case "sineout": FlxEase.sineOut;
            case "sineinout": FlxEase.sineInOut;
            case "quadin": FlxEase.quadIn;
            case "quadout": FlxEase.quadOut;
            case "quadinout": FlxEase.quadInOut;
            case "cubein": FlxEase.cubeIn;
            case "cubeout": FlxEase.cubeOut;
            case "cubeinout": FlxEase.cubeInOut;
            case "quartin": FlxEase.quartIn;
            case "quartout": FlxEase.quartOut;
            case "quartinout": FlxEase.quartInOut;
            case "expoin": FlxEase.expoIn;
            case "expoout": FlxEase.expoOut;
            case "expoinout": FlxEase.expoInOut;
            case "circin": FlxEase.circIn;
            case "circout": FlxEase.circOut;
            case "circinout": FlxEase.circInOut;
            case "backin": FlxEase.backIn;
            case "backout": FlxEase.backOut;
            case "backinout": FlxEase.backInOut;
            case "elasticin": FlxEase.elasticIn;
            case "elasticout": FlxEase.elasticOut;
            case "elasticinout": FlxEase.elasticInOut;
            case "bouncein": FlxEase.bounceIn;
            case "bounceout": FlxEase.bounceOut;
            case "bounceinout": FlxEase.bounceInOut;
            case "quadraticin": FlxEase.quadIn;
            case "quadraticout": FlxEase.quadOut;
            case "quadraticinout": FlxEase.quadInOut;
            case "cubicin": FlxEase.cubeIn;
            case "cubicout": FlxEase.cubeOut;
            case "cubicinout": FlxEase.cubeInOut;
            default: FlxEase.linear;
        };
    }
}