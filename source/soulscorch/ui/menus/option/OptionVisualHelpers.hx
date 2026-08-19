package soulscorch.ui.menus.option;

import flixel.FlxSprite;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import soulscorch.ui.menus.editors.editorui.EditorTheme;

class OptionVisualHelpers {
    public static function createCapsuleBadge(x:Float, y:Float, width:Float, color:FlxColor):FlxSprite {
        var spr = new FlxSprite(x, y).makeGraphic(Std.int(width), 20, color);
        spr.antialiasing = true;
        return spr;
    }

    public static function createHeaderBar(width:Float, height:Float = 65):FlxSprite {
        var header = new FlxSprite(0, 0).makeGraphic(Std.int(width), Std.int(height), EditorTheme.PANEL_HEADER);
        return header;
    }

    public static function pulseElement(sprite:FlxSprite, targetScale:Float = 1.05, duration:Float = 0.15):Void {
        FlxTween.cancelTweensOf(sprite.scale);
        FlxTween.tween(sprite.scale, {x: targetScale, y: targetScale}, duration, {ease: FlxEase.quartOut});
    }
}