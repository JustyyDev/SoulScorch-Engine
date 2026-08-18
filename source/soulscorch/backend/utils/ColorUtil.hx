package soulscorch.backend.utils;

import flixel.util.FlxColor;

class ColorUtil {
    /**
     * Interpolates between two FlxColors based on a progress ratio (0.0 to 1.0).
     */
    public static function lerpColor(colorA:FlxColor, colorB:FlxColor, ratio:Float):FlxColor {
        var r = Math.round(colorA.red + (colorB.red - colorA.red) * ratio);
        var g = Math.round(colorA.green + (colorB.green - colorA.green) * ratio);
        var b = Math.round(colorA.blue + (colorB.blue - colorA.blue) * ratio);
        var a = Math.round(colorA.alpha + (colorB.alpha - colorA.alpha) * ratio);
        return FlxColor.fromRGB(r, g, b, a);
    }

    /**
     * Returns a vibrant difficulty or health bar color string representation.
     */
    public static function getHealthColor(healthPercent:Float):FlxColor {
        if (healthPercent > 60) return 0xFF6BFF8E; // Safe green
        if (healthPercent > 20) return 0xFFFFCC00; // Caution yellow
        return 0xFFFF4444; // Danger red
    }
}