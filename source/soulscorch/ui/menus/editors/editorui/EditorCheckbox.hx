package soulscorch.ui.menus.editors.editorui;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import soulscorch.backend.assets.Paths;

class EditorCheckbox extends FlxSpriteGroup {
    public var checked(default, set):Bool = false;
    public var onChange:Bool->Void;

    private var label:FlxText;
    private var box:FlxSprite;
    private var checkmark:FlxSprite;

    public function new(x:Float, y:Float, labelText:String, initialChecked:Bool = false, ?onChange:Bool->Void) {
        super(x, y);
        this.onChange = onChange;

        box = new FlxSprite(0, 2).makeGraphic(20, 20, 0xFF1B2434);
        add(box);

        checkmark = new FlxSprite(4, 6).makeGraphic(12, 12, 0xFF6BFF8E);
        checkmark.visible = initialChecked;
        add(checkmark);

        label = new FlxText(32, 0, 200, labelText, 16);
        label.setFormat(Paths.font("vcr"), 16, FlxColor.WHITE, LEFT);
        add(label);

        this.checked = initialChecked;
        scrollFactor.set(0, 0);
    }

    private function set_checked(v:Bool):Bool {
        checked = v;
        if (checkmark != null) {
            checkmark.visible = checked;
        }
        if (onChange != null) {
            onChange(checked);
        }
        return checked;
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        var mousePos = FlxG.mouse.getScreenPosition();
        if (FlxG.mouse.justPressed && mousePos.x >= x && mousePos.x <= x + 200 && mousePos.y >= y && mousePos.y <= y + 24) {
            checked = !checked;
        }
    }
}