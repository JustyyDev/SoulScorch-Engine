package soulscorch.ui.menus.editors.editorui;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxPoint;
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
    private var cursor:FlxSprite;
    private var fieldWidth:Float;
    private var cursorTimer:Float = 0.0;

    public function new(x:Float, y:Float, width:Float, label:String, defaultText:String = "", ?onChange:String->Void) {
        super(x, y);
        this.fieldWidth = width;
        this.onChange = onChange;
        this.text = defaultText;

        labelText = new FlxText(0, 0, width, label, 12);
        labelText.setFormat(Paths.font("vcr"), 12, EditorTheme.TEXT_MUTED, LEFT);
        add(labelText);

        boxBorder = EditorTheme.makeRoundedRect(Std.int(width), 24, EditorTheme.PANEL_BORDER, EditorTheme.CORNER_SM);
        boxBorder.setPosition(0, 18);
        add(boxBorder);

        box = EditorTheme.makeRoundedRect(Std.int(width - 2), 22, EditorTheme.BTN_IDLE, EditorTheme.CORNER_SM - 1);
        box.setPosition(1, 19);
        add(box);

        inputText = new FlxText(6, 21, width - 12, text, 12);
        inputText.setFormat(Paths.font("vcr"), 12, EditorTheme.TEXT_PRIMARY, LEFT);
        add(inputText);

        cursor = new FlxSprite(6, 22).makeGraphic(2, 16, EditorTheme.ACCENT_CYAN);
        cursor.visible = false;
        add(cursor);

        scrollFactor.set(0, 0);
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        var cam:FlxCamera = (cameras != null && cameras.length > 0) ? cameras[0] : FlxG.camera;
        var mousePos:FlxPoint = FlxG.mouse.getPositionInCameraView(cam);

        if (FlxG.mouse.justPressed) {
            var inside = (mousePos.x >= x && mousePos.x <= x + fieldWidth && mousePos.y >= y + 18 && mousePos.y <= y + 42);
            setFocus(inside);
        }

        if (isFocused) {
            handleKeyboard();
            cursorTimer += elapsed;
            if (cursorTimer >= 0.5) {
                cursorTimer = 0.0;
                cursor.visible = !cursor.visible;
            }
            cursor.x = 6 + inputText.width;
        } else {
            cursor.visible = false;
        }
    }

    private function handleKeyboard():Void {
        if (FlxG.keys.justPressed.BACKSPACE) {
            if (text.length > 0) {
                text = text.substr(0, text.length - 1);
                if (onChange != null) onChange(text);
            }
        } else if (FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.ESCAPE) {
            setFocus(false);
        } else {
            // Capture alphanumeric + symbol input
            for (code in 65...91) { // A-Z
                if (FlxG.keys.checkStatus(code, JUST_PRESSED)) {
                    var letter = String.fromCharCode(code);
                    if (!FlxG.keys.pressed.SHIFT) letter = letter.toLowerCase();
                    text += letter;
                    if (onChange != null) onChange(text);
                    return;
                }
            }
            for (code in 48...58) { // 0-9
                if (FlxG.keys.checkStatus(code, JUST_PRESSED)) {
                    text += String.fromCharCode(code);
                    if (onChange != null) onChange(text);
                    return;
                }
            }
            if (FlxG.keys.justPressed.PERIOD) { text += "."; if (onChange != null) onChange(text); }
            if (FlxG.keys.justPressed.MINUS) { text += "-"; if (onChange != null) onChange(text); }
            if (FlxG.keys.justPressed.SLASH) { text += "/"; if (onChange != null) onChange(text); }
            if (FlxG.keys.justPressed.SPACE) { text += " "; if (onChange != null) onChange(text); }
        }
    }

    public function setFocus(focused:Bool):Void {
        isFocused = focused;
        boxBorder.color = isFocused ? EditorTheme.ACCENT_CYAN : EditorTheme.PANEL_BORDER;
        if (isFocused) cursorTimer = 0.0;
    }

    private function set_text(v:String):String {
        text = (v != null) ? v : "";
        if (inputText != null) inputText.text = text;
        return text;
    }
}