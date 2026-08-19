package soulscorch.ui.menus.option;

import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import soulscorch.backend.assets.Paths;

class OptionVisualHelpers {
    public static function createToggleSwitch(x:Float, y:Float, isOn:Bool):FlxSprite {
        var spr = new FlxSprite(x, y).makeGraphic(44, 22, isOn ? 0xFF00FFCC : 0xFF332B45);
        spr.antialiasing = true;
        return spr;
    }

    public static function createCategoryHeader(width:Float, title:String):FlxSprite {
        var header = new FlxSprite(0, 0).makeGraphic(Std.int(width), 65, 0xEE110E1A);
        return header;
    }

    public static function pulseElement(sprite:FlxSprite, targetScale:Float = 1.05, duration:Float = 0.15):Void {
        FlxTween.cancelTweensOf(sprite.scale);
        FlxTween.tween(sprite.scale, {x: targetScale, y: targetScale}, duration, {ease: FlxEase.quartOut});
    }
}