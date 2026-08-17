package soulscorch.ui.menus.option;

import flixel.FlxBasic;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import soulscorch.backend.assets.Paths;

// A single selectable row in the options menu (label + a right-aligned value/badge)[cite: 48].
class OptionRow extends FlxTypedGroup<FlxBasic> {
    public var label:FlxText;
    public var value:FlxText;
    public var rowBg:FlxSprite;

    public function new(x:Float, y:Float, width:Float, labelText:String) {
        super();

        rowBg = new FlxSprite(x, y).makeGraphic(Std.int(width), 36, 0xFF17222E);
        rowBg.alpha = 0.0;
        add(rowBg);

        label = new FlxText(x + 20, y + 6, width * 0.55, labelText, 20);
        label.setFormat(Paths.font("vcr"), 20, FlxColor.WHITE, LEFT);
        add(label);

        value = new FlxText(x + width * 0.55, y + 6, width * 0.4, "", 20);
        value.setFormat(Paths.font("vcr"), 20, FlxColor.WHITE, RIGHT);
        value.alignment = RIGHT;
        add(value);
    }

    public function setActive(active:Bool):Void {
        label.color = active ? 0xFF7AD1FF : FlxColor.WHITE;
        label.alpha = active ? 1.0 : 0.75;
        rowBg.alpha = active ? 0.35 : 0.0;
    }

    // isOn == null means "not a toggle" (e.g. a numeric/keybind value) -> plain white text[cite: 48].
    public function setValue(text:String, ?isOn:Bool):Void {
        value.text = text;
        if (isOn == null) {
            value.color = 0xFFCFCFCF;
        } else {
            value.color = isOn ? 0xFF6BFF8E : 0xFFFF6B6B;
        }
    }

    public function setRowVisible(rowVisible:Bool):Void {
        rowBg.visible = rowVisible;
        label.visible = rowVisible;
        value.visible = rowVisible;
    }
}