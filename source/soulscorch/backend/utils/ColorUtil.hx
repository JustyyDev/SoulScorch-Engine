package soulscorch.backend.utils;

import flixel.math.FlxMath;
import flixel.util.FlxColor;

using StringTools;

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

        var clean = hexString.trim();
        if (clean.length == 0) return fallback;

        if (clean.indexOf(",") != -1) {
            var parts = clean.split(",");
            if (parts.length >= 3) {
                var r = Std.parseInt(parts[0].trim());
                var g = Std.parseInt(parts[1].trim());
                var b = Std.parseInt(parts[2].trim());
                var a = (parts.length > 3) ? Std.parseInt(parts[3].trim()) : 255;
                if (r != null && g != null && b != null) {
                    return FlxColor.fromRGB(
                        FlxMath.bound(r, 0, 255),
                        FlxMath.bound(g, 0, 255),
                        FlxMath.bound(b, 0, 255),
                        a != null ? FlxMath.bound(a, 0, 255) : 255
                    );
                }
            }
        }

        var direct:Null<FlxColor> = FlxColor.fromString(clean);
        if (direct != null) return direct;

        var lower = clean.toLowerCase();
        if (lower.startsWith("0x")) {
            var parsedInt = Std.parseInt(clean);
            if (parsedInt != null) return cast parsedInt;

            var hex = clean.substr(2);
            if (hex.length == 6) {
                var six = FlxColor.fromString("#FF" + hex);
                if (six != null) return six;
            } else if (hex.length == 8) {
                var eight = FlxColor.fromString("#" + hex);
                if (eight != null) return eight;
            }
        }

        if (!clean.startsWith("#")) {
            var raw = clean;
            if (raw.length == 6) {
                var rgb = FlxColor.fromString("#FF" + raw);
                if (rgb != null) return rgb;
            } else if (raw.length == 8) {
                var argb = FlxColor.fromString("#" + raw);
                if (argb != null) return argb;
            }
        }

        return fallback;
    }

    public static function adjustBrightness(color:FlxColor, factor:Float):FlxColor {
        var r = FlxMath.bound(Math.round(color.red * factor), 0, 255);
        var g = FlxMath.bound(Math.round(color.green * factor), 0, 255);
        var b = FlxMath.bound(Math.round(color.blue * factor), 0, 255);
        return FlxColor.fromRGB(r, g, b, color.alpha);
    }
}