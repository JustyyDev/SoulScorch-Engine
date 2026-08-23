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
import soulscorch.ui.hud.Alphabet;
import soulscorch.ui.menus.editors.editorui.EditorTheme;

class OptionRow extends FlxSpriteGroup {
    public var label:Alphabet;
    public var value:FlxText;
    public var rowBg:FlxSprite;
    public var activeIndicator:FlxSprite;
    public var statusCapsule:FlxSprite;

    public var targetY:Float = 0;
    public var rowWidth:Float = 0;
    public var isSelected:Bool = false;

    public function new(x:Float, y:Float, width:Float, labelText:String) {
        super(x, y);
        this.rowWidth = width;

        rowBg = new FlxSprite(0, 0).makeGraphic(Std.int(width), 54, EditorTheme.PANEL_BG);
        rowBg.alpha = 0.45;
        add(rowBg);

        var border = new FlxSprite(0, 53).makeGraphic(Std.int(width), 1, EditorTheme.PANEL_BORDER);
        border.alpha = 0.6;
        add(border);

        activeIndicator = new FlxSprite(0, 0).makeGraphic(5, 54, EditorTheme.ACCENT_CYAN);
        activeIndicator.alpha = 0.0;
        add(activeIndicator);

        statusCapsule = new FlxSprite(width - 16, 20).makeGraphic(6, 14, EditorTheme.ACCENT_CYAN);
        statusCapsule.alpha = 0.0;
        add(statusCapsule);

        // FNF-style Alphabet label
        label = new Alphabet(22, 0, labelText, false);
        label.targetY = 0;
        label.isMenuItem = false;
        label.y = (54 - label.height) * 0.5;
        add(label);

        value = new FlxText(width * 0.48, 16, (width * 0.48) - 24, "", 18);
        value.setFormat(Paths.font("vcr"), 18, EditorTheme.TEXT_PRIMARY, RIGHT, OUTLINE, FlxColor.BLACK);
        value.borderSize = 1.0;
        add(value);
    }

    public function setActive(active:Bool):Void {
        isSelected = active;
        label.color = active ? EditorTheme.ACCENT_CYAN : EditorTheme.TEXT_PRIMARY;

        FlxTween.cancelTweensOf(rowBg);
        FlxTween.tween(rowBg, {alpha: active ? 0.95 : 0.45}, 0.2, {ease: FlxEase.quartOut});

        FlxTween.cancelTweensOf(activeIndicator);
        FlxTween.tween(activeIndicator, {alpha: active ? 1.0 : 0.0}, 0.2, {ease: FlxEase.quartOut});

        FlxTween.cancelTweensOf(statusCapsule);
        FlxTween.tween(statusCapsule, {alpha: active ? 1.0 : 0.0}, 0.2, {ease: FlxEase.quartOut});
    }

    public function setValue(text:String, ?isOn:Bool):Void {
        value.text = text;
        if (isOn == null) {
            value.color = isSelected ? EditorTheme.ACCENT_CYAN : EditorTheme.TEXT_MUTED;
        } else {
            value.color = isOn ? 0xFF00FF88 : 0xFFFF0055;
            statusCapsule.color = isOn ? 0xFF00FF88 : 0xFFFF0055;
        }
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        var lerpFactor = FlxMath.bound(elapsed * 12.0, 0, 1);
        y = FlxMath.lerp(y, targetY, lerpFactor);
    }
}