package soulscorch.ui.menus.option;

import flixel.FlxBasic;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import soulscorch.backend.assets.Paths;

class OptionRow extends flixel.group.FlxSpriteGroup {
    public var label:FlxText;
    public var value:FlxText;
    public var rowBg:FlxSprite;
    public var activeIndicator:FlxSprite;

    private var targetAlpha:Float = 0.0;

    public function new(x:Float, y:Float, width:Float, labelText:String) {
        super();

        rowBg = new FlxSprite(x, y).makeGraphic(Std.int(width), 46, 0xFF171321);
        rowBg.alpha = 0.4;
        add(rowBg);

        activeIndicator = new FlxSprite(x + 4, y + 8).makeGraphic(6, 30, 0xFF00FFCC);
        activeIndicator.alpha = 0.0;
        add(activeIndicator);

        label = new FlxText(x + 24, y + 12, width * 0.55, labelText, 18);
        label.setFormat(Paths.font("vcr"), 18, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
        label.borderSize = 1.0;
        add(label);

        value = new FlxText(x + width * 0.4, y + 12, width * 0.55, "", 18);
        value.setFormat(Paths.font("vcr"), 18, FlxColor.WHITE, RIGHT, OUTLINE, FlxColor.BLACK);
        value.borderSize = 1.0;
        add(value);
    }

    public function setActive(active:Bool):Void {
        label.color = active ? 0xFF00FFCC : FlxColor.WHITE;
        targetAlpha = active ? 0.85 : 0.2;
        
        FlxTween.cancelTweensOf(rowBg);
        FlxTween.tween(rowBg, {alpha: targetAlpha}, 0.2, {ease: FlxEase.quadOut});

        FlxTween.cancelTweensOf(activeIndicator);
        FlxTween.tween(activeIndicator, {alpha: active ? 1.0 : 0.0}, 0.2, {ease: FlxEase.quadOut});
    }

    public function setValue(text:String, ?isOn:Bool):Void {
        value.text = text;
        if (isOn == null) {
            value.color = 0xFFCCCCCC;
        } else {
            value.color = isOn ? 0xFF6BFF8E : 0xFFFF5555;
        }
    }

    public function setRowVisible(rowVisible:Bool):Void {
        rowBg.visible = rowVisible;
        label.visible = rowVisible;
        value.visible = rowVisible;
        activeIndicator.visible = rowVisible;
    }
}