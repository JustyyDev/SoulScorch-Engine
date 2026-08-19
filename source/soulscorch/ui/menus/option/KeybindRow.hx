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
import soulscorch.ui.menus.editors.editorui.EditorTheme;

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

        rowBg = new FlxSprite(0, 0).makeGraphic(Std.int(width), 54, EditorTheme.PANEL_BG);
        rowBg.alpha = 0.45;
        add(rowBg);

        var border = new FlxSprite(0, 53).makeGraphic(Std.int(width), 1, EditorTheme.PANEL_BORDER);
        border.alpha = 0.6;
        add(border);

        activeIndicator = new FlxSprite(0, 0).makeGraphic(5, 54, EditorTheme.ACCENT_CYAN);
        activeIndicator.alpha = 0.0;
        add(activeIndicator);

        label = new FlxText(22, 16, width * 0.48, displayName, 18);
        label.setFormat(Paths.font("vcr"), 18, EditorTheme.TEXT_PRIMARY, LEFT, OUTLINE, FlxColor.BLACK);
        label.borderSize = 1.0;
        add(label);

        keyText = new FlxText(width * 0.45, 16, (width * 0.55) - 20, "", 18);
        keyText.setFormat(Paths.font("vcr"), 18, EditorTheme.ACCENT_CYAN, RIGHT, OUTLINE, FlxColor.BLACK);
        keyText.borderSize = 1.0;
        add(keyText);

        refreshKeyLabel();
    }

    public function setActive(active:Bool):Void {
        isSelected = active;
        label.color = active ? EditorTheme.ACCENT_CYAN : EditorTheme.TEXT_PRIMARY;

        FlxTween.cancelTweensOf(rowBg);
        FlxTween.tween(rowBg, {alpha: active ? 0.95 : 0.45}, 0.2, {ease: FlxEase.quartOut});

        FlxTween.cancelTweensOf(activeIndicator);
        FlxTween.tween(activeIndicator, {alpha: active ? 1.0 : 0.0}, 0.2, {ease: FlxEase.quartOut});
    }

    public function setListening(listening:Bool):Void {
        if (listening) {
            keyText.text = "> PRESS ANY KEY <";
            keyText.color = EditorTheme.ACCENT_MAGENTA;
        } else {
            refreshKeyLabel();
        }
    }

    public function refreshKeyLabel():Void {
        var primaryKey = InputMap.getKeyLabel(actionName, 0);
        var secondaryKey = InputMap.getKeyLabel(actionName, 1);

        if (secondaryKey != "NONE" && secondaryKey != primaryKey) {
            keyText.text = '[ $primaryKey ]  |  [ $secondaryKey ]';
        } else {
            keyText.text = '[ $primaryKey ]';
        }

        keyText.color = isSelected ? EditorTheme.ACCENT_CYAN : EditorTheme.TEXT_MUTED;
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        var lerpFactor = FlxMath.bound(elapsed * 12.0, 0, 1);
        y = FlxMath.lerp(y, targetY, lerpFactor);
    }
}