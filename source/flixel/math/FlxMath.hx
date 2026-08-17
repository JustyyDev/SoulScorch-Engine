package flixel.math;

import Math;
import flixel.util.FlxPool;

/**
 * A custom implementation of FlxMath designed to provide framerate-independent
 * lerping for rhythm game mechanics, alongside the standard Flixel utilities.
 */
class FlxMath {
    /**
     * Framerate-independent linear interpolation.
     * Use this for smooth camera movement and UI scaling that feels identical on 60Hz and 144Hz monitors.
     * 
     * @param a Base value
     * @param b Target value
     * @param ratio Interpolation ratio (0.0 to 1.0)
     * @param elapsed Delta time (usually FlxG.elapsed)
     * @return Interpolated value
     */
    public static inline function lerp(a:Float, b:Float, ratio:Float, ?elapsed:Float):Float {
        if (elapsed != null) {
            // Adjust ratio based on delta time, assuming a base 60fps frame time (1/60)
            return a + (b - a) * (1 - Math.exp(-ratio * (elapsed * 60)));
        }
        return a + ratio * (b - a);
    }

    // Standard FlxMath functions required for compatibility
    public static inline function bound(Value:Float, ?Min:Float, ?Max:Float):Float {
        var lowerBound:Float = (Min != null && Value < Min) ? Min : Value;
        return (Max != null && lowerBound > Max) ? Max : lowerBound;
    }

    public static inline function roundDecimal(Value:Float, Precision:Int):Float {
        var mult:Float = 1;
        for (i in 0...Precision) {
            mult *= 10;
        }
        return Math.round(Value * mult) / mult;
    }

    public static inline function distanceBetween(SpriteA:flixel.FlxSprite, SpriteB:flixel.FlxSprite):Float {
        var dx:Float = SpriteA.x - SpriteB.x;
        var dy:Float = SpriteA.y - SpriteB.y;
        return Math.sqrt(dx * dx + dy * dy);
    }
}