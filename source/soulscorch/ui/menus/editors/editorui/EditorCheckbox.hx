package soulscorch.ui.menus.editors.editorui;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.Paths;

class EditorCheckbox extends FlxSpriteGroup {
    public var checked(default, set):Bool = false;
    public var onChange:Bool->Void;
    public var labelText(default, set):String;

    private var label:FlxText;
    private var box:FlxSprite;
    private var boxBorder:FlxSprite;
    private var checkmark:FlxSprite;
    private var checkTween:FlxTween;

    public function new(x:Float, y:Float, labelText:String, initialChecked:Bool = false, ?onChange:Bool->Void) {
        super(x, y);
        this.onChange = onChange;
        this.labelText = labelText;

        boxBorder = EditorTheme.makeRoundedRect(22, 22, 0xFF2F364D, 5);
        boxBorder.setPosition(0, 2);
        add(boxBorder);

        box = EditorTheme.makeRoundedRect(18, 18, 0xFF141722, 4);
        box.setPosition(2, 4);
        add(box);

        checkmark = new FlxSprite(5, 7).makeGraphic(12, 12, 0xFF00FFCC);
        checkmark.visible = initialChecked;
        add(checkmark);

        label = new FlxText(32, 4, 0, labelText, 13);
        label.setFormat(Paths.font("vcr"), 13, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
        label.borderSize = 1.0;
        add(label);

        this.checked = initialChecked;
        scrollFactor.set(0, 0);
    }

    private function set_checked(v:Bool):Bool {
        checked = v;
        if (checkmark != null) {
            checkmark.visible = checked;
            if (checkTween != null) checkTween.cancel();
            checkmark.scale.set(checked ? 0.4 : 1.0, checked ? 0.4 : 1.0);
            checkTween = FlxTween.tween(checkmark.scale, {x: 1.0, y: 1.0}, 0.18, {ease: FlxEase.backOut});
        }
        return checked;
    }

    private function set_labelText(t:String):String {
        labelText = t;
        if (label != null) {
            label.text = t;
        }
        return labelText;
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        var cam:FlxCamera = (cameras != null && cameras.length > 0) ? cameras[0] : FlxG.camera;
        var mousePos:FlxPoint = FlxG.mouse.getPositionInCameraView(cam);
        var totalWidth:Float = 32 + (label != null ? label.width : 100);

        var isHovered:Bool = (mousePos.x >= x && mousePos.x <= x + totalWidth && mousePos.y >= y && mousePos.y <= y + 26);
        if (boxBorder != null) {
            boxBorder.color = isHovered ? 0xFF00FFCC : 0xFF2F364D;
        }

        if (isHovered && FlxG.mouse.justPressed) {
            checked = !checked;
            AssetHelper.playSoundSafely("scrollMenu", 0.6);
            if (onChange != null) {
                onChange(checked);
            }
        }
    }
}