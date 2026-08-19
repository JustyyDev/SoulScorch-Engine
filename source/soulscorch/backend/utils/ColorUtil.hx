package soulscorch.backend.utils;

import flixel.math.FlxMath;
import flixel.util.FlxColor;

class ColorUtil {
    public static function lerpColor(colorA:FlxColor, colorB:FlxColor, ratio:Float):FlxColor {
        var t = FlxMath.bound(ratio, 0.0, 1.0);
        var r = Math.round(colorA.red + (colorB.red - colorA.red) * t);
        var g = Math.round(colorA.green + (colorB.green - colorA.green) * t);
        var b = Math.round(colorA.blue + (colorB.blue - colorA.blue) * t);
        var a = Math.round(colorA.alpha + (colorB.alpha - colorA.alpha) * t);
        return FlxColor.fromRGB(r, g, b, a);
    }

    public static function getHealthColor(healthPercent:Float):FlxColor {
        if (healthPercent > 60.0) return 0xFF6BFF8E;
        if (healthPercent > 20.0) return 0xFFFFCC00;
        return 0xFFFF4444;
    }

    public static function fromHexSafe(hexString:String, fallback:FlxColor = FlxColor.WHITE):FlxColor {
        if (hexString == null || hexString.length == 0) return fallback;
        var parsed:Null<FlxColor> = FlxColor.fromString(hexString);
        return (parsed != null) ? parsed : fallback;
    }

    public static function adjustBrightness(color:FlxColor, factor:Float):FlxColor {
        var r = FlxMath.bound(Math.round(color.red * factor), 0, 255);
        var g = FlxMath.bound(Math.round(color.green * factor), 0, 255);
        var b = FlxMath.bound(Math.round(color.blue * factor), 0, 255);
        return FlxColor.fromRGB(r, g, b, color.alpha);
    }
}