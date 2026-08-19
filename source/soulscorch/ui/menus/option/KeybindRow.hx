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
import soulscorch.backend.input.InputMap;

class KeybindRow extends FlxSpriteGroup {
    public var label:FlxText;
    public var keyText:FlxText;
    public var rowBg:FlxSprite;
    public var activeIndicator:FlxSprite;
    public var actionName:String;

    public var targetY:Float = 0;
    public var isSelected:Bool = false;

    public function new(x:Float, y:Float, width:Float, actionName:String, displayName:String) {
        super(x, y);
        this.actionName = actionName;

        rowBg = new FlxSprite(0, 0).makeGraphic(Std.int(width), 50, 0xFF171321);
        rowBg.alpha = 0.35;
        add(rowBg);

        activeIndicator = new FlxSprite(0, 0).makeGraphic(6, 50, 0xFF00FFCC);
        activeIndicator.alpha = 0.0;
        add(activeIndicator);

        label = new FlxText(24, 14, width * 0.5, displayName, 18);
        label.setFormat(Paths.font("vcr"), 18, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
        label.borderSize = 1.0;
        add(label);

        keyText = new FlxText(width * 0.45, 14, width * 0.50, "", 18);
        keyText.setFormat(Paths.font("vcr"), 18, 0xFF00FFCC, RIGHT, OUTLINE, FlxColor.BLACK);
        keyText.borderSize = 1.0;
        add(keyText);

        refreshKeyLabel();
    }

    public function setActive(active:Bool):Void {
        isSelected = active;
        label.color = active ? 0xFF00FFCC : FlxColor.WHITE;
        
        FlxTween.cancelTweensOf(rowBg);
        FlxTween.tween(rowBg, {alpha: active ? 0.85 : 0.25}, 0.2, {ease: FlxEase.quadOut});

        FlxTween.cancelTweensOf(activeIndicator);
        FlxTween.tween(activeIndicator, {alpha: active ? 1.0 : 0.0}, 0.2, {ease: FlxEase.quadOut});
    }

    public function setListening(listening:Bool):Void {
        if (listening) {
            keyText.text = "> PRESS ANY KEY <";
            keyText.color = 0xFFFF5555;
        } else {
            refreshKeyLabel();
        }
    }

    public function refreshKeyLabel():Void {
        var primaryKey = InputMap.getKeyLabel(actionName, 0);
        keyText.text = '[ $primaryKey ]';
        keyText.color = isSelected ? 0xFF00FFCC : 0xFF88EEEE;
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        var lerpFactor = FlxMath.bound(elapsed * 12.0, 0, 1);
        y = FlxMath.lerp(y, targetY, lerpFactor);
    }
}