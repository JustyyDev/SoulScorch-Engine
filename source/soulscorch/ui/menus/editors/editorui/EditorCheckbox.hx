package soulscorch.ui.menus.editors.editorui;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
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

    public function new(x:Float, y:Float, labelText:String, initialChecked:Bool = false, ?onChange:Bool->Void) {
        super(x, y);
        this.onChange = onChange;

        boxBorder = new FlxSprite(0, 2).makeGraphic(20, 20, 0xFF3F557A);
        add(boxBorder);

        box = new FlxSprite(1, 3).makeGraphic(18, 18, 0xFF1B2434);
        add(box);

        checkmark = new FlxSprite(4, 6).makeGraphic(12, 12, 0xFF00FFCC);
        checkmark.visible = initialChecked;
        add(checkmark);

        label = new FlxText(28, 3, 0, labelText, 14);
        label.setFormat(Paths.font("vcr"), 14, FlxColor.WHITE, LEFT);
        add(label);

        this.checked = initialChecked;
        scrollFactor.set(0, 0);
    }

    private function set_checked(v:Bool):Bool {
        checked = v;
        if (checkmark != null) {
            checkmark.visible = checked;
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
        var totalWidth:Float = 28 + label.width;

        var isHovered:Bool = (mousePos.x >= x && mousePos.x <= x + totalWidth && mousePos.y >= y && mousePos.y <= y + 24);
        boxBorder.color = isHovered ? 0xFF00FFCC : 0xFF3F557A;

        if (isHovered && FlxG.mouse.justPressed) {
            checked = !checked;
            AssetHelper.playSoundSafely("scrollMenu", 0.6);
            if (onChange != null) {
                onChange(checked);
            }
        }
    }
}