package soulscorch.ui.menus.editors.editorui;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.Paths;

class EditorNumericStepper extends FlxSpriteGroup {
    public var value(default, set):Float = 0.0;
    public var min:Float = -9999.0;
    public var max:Float = 9999.0;
    public var step:Float = 1.0;
    public var decimals:Int = 2;
    public var onChange:Float->Void;

    private var label:FlxText;
    private var valueText:FlxText;
    private var bg:FlxSprite;
    private var border:FlxSprite;
    private var btnUp:FlxSprite;
    private var btnDown:FlxSprite;
    private var btnUpText:FlxText;
    private var btnDownText:FlxText;

    private var holdTimer:Float = 0.0;
    private var repeatTimer:Float = 0.0;
    private var holdingUp:Bool = false;
    private var holdingDown:Bool = false;
    private var scrubbing:Bool = false;
    private var scrubStartX:Float = 0.0;
    private var scrubStartVal:Float = 0.0;

    public function new(
        x:Float,
        y:Float,
        width:Float,
        labelText:String,
        initialValue:Float = 0.0,
        min:Float = -9999.0,
        max:Float = 9999.0,
        step:Float = 1.0,
        decimals:Int = 2,
        ?onChange:Float->Void
    ) {
        super(x, y);
        this.min = min;
        this.max = max;
        this.step = step;
        this.decimals = decimals;
        this.onChange = onChange;

        var w = Std.int(width);
        border = EditorTheme.makeRoundedRect(w, 32, EditorTheme.PANEL_BORDER, EditorTheme.CORNER_SM);
        add(border);

        bg = EditorTheme.makeRoundedRect(w - 2, 30, EditorTheme.BG_DARK, EditorTheme.CORNER_SM - 1);
        bg.setPosition(1, 1);
        add(bg);

        label = new FlxText(10, 8, width * 0.45, labelText, 13);
        label.setFormat(Paths.font("vcr"), 13, FlxColor.WHITE, LEFT);
        add(label);

        valueText = new FlxText(width * 0.45, 8, width * 0.55 - 34, Std.string(initialValue), 13);
        valueText.setFormat(Paths.font("vcr"), 13, EditorTheme.TEXT_HIGHLIGHT, RIGHT);
        add(valueText);

        btnUp = EditorTheme.makeRoundedRect(26, 13, EditorTheme.BTN_IDLE, 4);
        btnUp.setPosition(width - 28, 2);
        add(btnUp);

        btnDown = EditorTheme.makeRoundedRect(26, 13, EditorTheme.BTN_IDLE, 4);
        btnDown.setPosition(width - 28, 17);
        add(btnDown);

        btnUpText = new FlxText(width - 28, 0, 26, "+", 11);
        btnUpText.setFormat(Paths.font("vcr"), 11, EditorTheme.TEXT_PRIMARY, CENTER);
        add(btnUpText);

        btnDownText = new FlxText(width - 28, 15, 26, "-", 11);
        btnDownText.setFormat(Paths.font("vcr"), 11, EditorTheme.TEXT_PRIMARY, CENTER);
        add(btnDownText);

        this.value = initialValue;
        scrollFactor.set(0, 0);
    }

    private function set_value(v:Float):Float {
        value = FlxMath.bound(v, min, max);
        var pow = Math.pow(10, decimals);
        value = Math.round(value * pow) / pow;

        if (valueText != null) {
            valueText.text = Std.string(value);
        }
        if (onChange != null) {
            onChange(value);
        }
        return value;
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        var cam:FlxCamera = (cameras != null && cameras.length > 0) ? cameras[0] : FlxG.camera;
        var mousePos:FlxPoint = FlxG.mouse.getPositionInCameraView(cam);

        var inBox = (mousePos.x >= x && mousePos.x <= x + bg.width + 2 && mousePos.y >= y && mousePos.y <= y + 32);
        if (inBox && FlxG.mouse.wheel != 0) {
            var mult = FlxG.keys.pressed.SHIFT ? 10.0 : 1.0;
            value += FlxG.mouse.wheel * step * mult;
        }

        var inUpBtn = (mousePos.x >= x + bg.width - 28 && mousePos.x <= x + bg.width - 2 && mousePos.y >= y + 2 && mousePos.y <= y + 15);
        var inDownBtn = (mousePos.x >= x + bg.width - 28 && mousePos.x <= x + bg.width - 2 && mousePos.y >= y + 17 && mousePos.y <= y + 30);

        if (btnUp != null) btnUp.color = inUpBtn ? EditorTheme.ACCENT_CYAN : EditorTheme.BTN_IDLE;
        if (btnDown != null) btnDown.color = inDownBtn ? EditorTheme.ACCENT_CYAN : EditorTheme.BTN_IDLE;

        var mult = 1.0;
        if (FlxG.keys.pressed.SHIFT) mult = 10.0;
        if (FlxG.keys.pressed.CONTROL) mult = 0.1;

        // Drag-to-scrub on the value field
        if (FlxG.mouse.justPressed && inBox && !inUpBtn && !inDownBtn) {
            scrubbing = true;
            scrubStartX = mousePos.x;
            scrubStartVal = value;
        }
        if (scrubbing && FlxG.mouse.pressed) {
            var delta = (mousePos.x - scrubStartX) * step * mult;
            value = scrubStartVal + delta;
        }
        if (FlxG.mouse.justReleased) scrubbing = false;

        if (FlxG.mouse.justPressed) {
            if (inUpBtn) {
                holdingUp = true;
                value += step * mult;
                AssetHelper.playSoundSafely("scrollMenu", 0.5);
            } else if (inDownBtn) {
                holdingDown = true;
                value -= step * mult;
                AssetHelper.playSoundSafely("scrollMenu", 0.5);
            }
        }

        if (FlxG.mouse.pressed && (holdingUp || holdingDown)) {
            holdTimer += elapsed;
            if (holdTimer > 0.4) {
                repeatTimer += elapsed;
                if (repeatTimer > 0.05) {
                    if (holdingUp) value += step * mult;
                    if (holdingDown) value -= step * mult;
                    repeatTimer = 0.0;
                }
            }
        }

        if (FlxG.mouse.justReleased) {
            holdingUp = false;
            holdingDown = false;
            holdTimer = 0.0;
            repeatTimer = 0.0;
        }
    }
}