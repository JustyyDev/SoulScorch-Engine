package soulscorch.ui.menus.editors.editorui;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import soulscorch.backend.assets.Paths;

using StringTools;

class EditorInputText extends FlxSpriteGroup {
    public var labelText:FlxText;
    public var inputText:FlxText;
    public var text(default, set):String = "";
    public var isFocused:Bool = false;
    public var onChange:String->Void;

    private var box:FlxSprite;
    private var boxBorder:FlxSprite;
    private var fieldWidth:Float;

    public function new(x:Float, y:Float, width:Float, label:String, defaultText:String = "", ?onChange:String->Void) {
        super(x, y);
        this.fieldWidth = width;
        this.onChange = onChange;
        this.text = defaultText;

        labelText = new FlxText(0, 0, width, label, 12);
        labelText.setFormat(Paths.font("vcr"), 12, EditorTheme.TEXT_MUTED, LEFT);
        add(labelText);

        boxBorder = new FlxSprite(0, 18).makeGraphic(Std.int(width), 24, EditorTheme.PANEL_BORDER);
        add(boxBorder);

        box = new FlxSprite(1, 19).makeGraphic(Std.int(width - 2), 22, EditorTheme.BTN_IDLE);
        add(box);

        inputText = new FlxText(6, 21, width - 12, text, 12);
        inputText.setFormat(Paths.font("vcr"), 12, EditorTheme.TEXT_PRIMARY, LEFT);
        add(inputText);

        scrollFactor.set(0, 0);
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        var mx = FlxG.mouse.screenX;
        var my = FlxG.mouse.screenY;

        if (FlxG.mouse.justPressed) {
            var inside = (mx >= x && mx <= x + fieldWidth && my >= y + 18 && my <= y + 42);
            setFocus(inside);
        }

        if (isFocused) {
            handleKeyboard();
        }
    }

    private function handleKeyboard():Void {
        var key = FlxG.keys.firstJustPressed();
        if (key == -1) return;

        if (FlxG.keys.justPressed.BACKSPACE) {
            if (text.length > 0) {
                text = text.substr(0, text.length - 1);
                if (onChange != null) onChange(text);
            }
        } else if (FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.ESCAPE) {
            setFocus(false);
        }
    }

    public function setFocus(focused:Bool):Void {
        isFocused = focused;
        boxBorder.color = isFocused ? EditorTheme.ACCENT_CYAN : EditorTheme.PANEL_BORDER;
    }

    private function set_text(v:String):String {
        text = (v != null) ? v : "";
        if (inputText != null) inputText.text = text;
        return text;
    }
}