package soulscorch.ui.menus.option;

import flixel.FlxBasic;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.input.InputMap;

class KeybindRow extends FlxTypedGroup<FlxBasic> {
    public var label:FlxText;
    public var keyText:FlxText;
    public var rowBg:FlxSprite;
    public var activeIndicator:FlxSprite;
    public var actionName:String;

    private var targetAlpha:Float = 0.0;

    public function new(x:Float, y:Float, width:Float, actionName:String, displayName:String) {
        super();
        this.actionName = actionName;

        rowBg = new FlxSprite(x, y).makeGraphic(Std.int(width), 46, 0xFF171321);
        rowBg.alpha = 0.4;
        add(rowBg);

        activeIndicator = new FlxSprite(x + 4, y + 8).makeGraphic(6, 30, 0xFF00FFCC);
        activeIndicator.alpha = 0.0;
        add(activeIndicator);

        label = new FlxText(x + 24, y + 12, width * 0.5, displayName, 18);
        label.setFormat(Paths.font("vcr"), 18, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
        label.borderSize = 1.0;
        add(label);

        keyText = new FlxText(x + width * 0.4, y + 12, width * 0.55, "", 18);
        keyText.setFormat(Paths.font("vcr"), 18, 0xFF00FFCC, RIGHT, OUTLINE, FlxColor.BLACK);
        keyText.borderSize = 1.0;
        add(keyText);

        refreshKeyLabel();
    }

    public function setActive(active:Bool):Void {
        label.color = active ? 0xFF00FFCC : FlxColor.WHITE;
        targetAlpha = active ? 0.85 : 0.2;
        
        FlxTween.cancelTweensOf(rowBg);
        FlxTween.tween(rowBg, {alpha: targetAlpha}, 0.2, {ease: FlxEase.quadOut});

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
        keyText.color = 0xFF00FFCC;
    }

    public function setRowVisible(rowVisible:Bool):Void {
        rowBg.visible = rowVisible;
        label.visible = rowVisible;
        keyText.visible = rowVisible;
        activeIndicator.visible = rowVisible;
    }
}