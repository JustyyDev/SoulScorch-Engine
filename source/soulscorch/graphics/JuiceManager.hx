package soulscorch.graphics;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;

class JuiceManager {
    /**
     * Punches camera zoom instantly and returns smoothly.
     */
    public static function bumpCamera(cam:FlxCamera, gameZoomAdd:Float = 0.015, hudZoomAdd:Float = 0.01):Void {
        if (cam != null) {
            cam.zoom += gameZoomAdd;
        }
    }

    /**
     * Flashes the camera with a custom color overlay.
     */
    public static function flash(cam:FlxCamera, color:FlxColor = FlxColor.WHITE, duration:Float = 0.15, forced:Bool = false):Void {
        if (cam != null) {
            cam.flash(color, duration, null, forced);
        }
    }

    /**
     * Shakes the camera dynamically.
     */
    public static function shake(cam:FlxCamera, intensity:Float = 0.005, duration:Float = 0.1):Void {
        if (cam != null) {
            cam.shake(intensity, duration);
        }
    }
}