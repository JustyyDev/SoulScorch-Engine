package soulscorch.ui.menus.option;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import soulscorch.backend.assets.Paths;

class OptionRow extends FlxSpriteGroup {
    public var label:FlxText;
    public var value:FlxText;
    public var rowBg:FlxSprite;
    public var activeIndicator:FlxSprite;

    public var targetY:Float = 0;
    public var rowWidth:Float = 0;
    public var isSelected:Bool = false;

    public function new(x:Float, y:Float, width:Float, labelText:String) {
        super(x, y);
        this.rowWidth = width;

        rowBg = new FlxSprite(0, 0).makeGraphic(Std.int(width), 50, 0xFF171321);
        rowBg.alpha = 0.35;
        add(rowBg);

        activeIndicator = new FlxSprite(0, 0).makeGraphic(6, 50, 0xFF00FFCC);
        activeIndicator.alpha = 0.0;
        add(activeIndicator);

        label = new FlxText(24, 14, width * 0.55, labelText, 18);
        label.setFormat(Paths.font("vcr"), 18, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
        label.borderSize = 1.0;
        add(label);

        value = new FlxText(width * 0.45, 14, width * 0.50, "", 18);
        value.setFormat(Paths.font("vcr"), 18, FlxColor.WHITE, RIGHT, OUTLINE, FlxColor.BLACK);
        value.borderSize = 1.0;
        add(value);
    }

    public function setActive(active:Bool):Void {
        isSelected = active;
        label.color = active ? 0xFF00FFCC : FlxColor.WHITE;
        
        FlxTween.cancelTweensOf(rowBg);
        FlxTween.tween(rowBg, {alpha: active ? 0.85 : 0.25}, 0.2, {ease: FlxEase.quadOut});

        FlxTween.cancelTweensOf(activeIndicator);
        FlxTween.tween(activeIndicator, {alpha: active ? 1.0 : 0.0}, 0.2, {ease: FlxEase.quadOut});
    }

    public function setValue(text:String, ?isOn:Bool):Void {
        value.text = text;
        if (isOn == null) {
            value.color = isSelected ? 0xFFFFFFFF : 0xFFCCCCCC;
        } else {
            value.color = isOn ? 0xFF6BFF8E : 0xFFFF5555;
        }
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        var lerpFactor = FlxMath.bound(elapsed * 12.0, 0, 1);
        y = FlxMath.lerp(y, targetY, lerpFactor);
    }
}