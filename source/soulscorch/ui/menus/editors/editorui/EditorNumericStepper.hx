package soulscorch.ui.menus.editors.editorui;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import soulscorch.backend.assets.Paths;

class EditorNumericStepper extends FlxSpriteGroup {
    public var value(default, set):Float = 0.0;
    public var min:Float = -9999.0;
    public var max:Float = 9999.0;
    public var step:Float = 1.0;
    public var onChange:Float->Void;

    private var label:FlxText;
    private var valueText:FlxText;
    private var bg:FlxSprite;
    private var btnUp:FlxSprite;
    private var btnDown:FlxSprite;

    public function new(x:Float, y:Float, width:Float, labelText:String, initialValue:Float = 0.0, min:Float = -9999.0, max:Float = 9999.0, step:Float = 1.0, ?onChange:Float->Void) {
        super(x, y);
        this.min = min;
        this.max = max;
        this.step = step;
        this.onChange = onChange;

        bg = new FlxSprite(0, 0).makeGraphic(Std.int(width), 30, 0xFF1B2434);
        add(bg);

        label = new FlxText(8, 6, width * 0.5, labelText, 14);
        label.setFormat(Paths.font("vcr"), 14, FlxColor.WHITE, LEFT);
        add(label);

        valueText = new FlxText(width * 0.5, 6, width * 0.5 - 30, Std.string(initialValue), 14);
        valueText.setFormat(Paths.font("vcr"), 14, 0xFFFFCC00, RIGHT);
        add(valueText);

        btnUp = new FlxSprite(width - 24, 2).makeGraphic(22, 12, 0xFF2E3D54);
        add(btnUp);

        btnDown = new FlxSprite(width - 24, 16).makeGraphic(22, 12, 0xFF2E3D54);
        add(btnDown);

        this.value = initialValue;
        scrollFactor.set(0, 0);
    }

    private function set_value(v:Float):Float {
        value = Math.max(min, Math.min(max, v));
        if (valueText != null) {
            valueText.text = Std.string(Math.round(value * 100) / 100);
        }
        if (onChange != null) {
            onChange(value);
        }
        return value;
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        var mousePos = FlxG.mouse.getScreenPosition();

        if (FlxG.mouse.justPressed && mousePos.x >= x + bg.width - 26 && mousePos.x <= x + bg.width - 2) {
            if (mousePos.y >= y + 2 && mousePos.y <= y + 14) {
                value += step * (FlxG.keys.pressed.SHIFT ? 10.0 : 1.0);
            } else if (mousePos.y >= y + 16 && mousePos.y <= y + 28) {
                value -= step * (FlxG.keys.pressed.SHIFT ? 10.0 : 1.0);
            }
        }
    }
}