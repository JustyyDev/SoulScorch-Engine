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

    private var holdTimer:Float = 0.0;
    private var repeatTimer:Float = 0.0;
    private var holdingUp:Bool = false;
    private var holdingDown:Bool = false;

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

        border = new FlxSprite(0, 0).makeGraphic(Std.int(width), 30, 0xFF3F557A);
        add(border);

        bg = new FlxSprite(1, 1).makeGraphic(Std.int(width - 2), 28, 0xFF1B2434);
        add(bg);

        label = new FlxText(8, 6, width * 0.45, labelText, 14);
        label.setFormat(Paths.font("vcr"), 14, FlxColor.WHITE, LEFT);
        add(label);

        valueText = new FlxText(width * 0.45, 6, width * 0.55 - 32, Std.string(initialValue), 14);
        valueText.setFormat(Paths.font("vcr"), 14, 0xFFFFCC00, RIGHT);
        add(valueText);

        btnUp = new FlxSprite(width - 26, 2).makeGraphic(24, 12, 0xFF2E3D54);
        add(btnUp);

        btnDown = new FlxSprite(width - 26, 16).makeGraphic(24, 12, 0xFF2E3D54);
        add(btnDown);

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

        var inUpBtn = (mousePos.x >= x + bg.width - 26 && mousePos.x <= x + bg.width - 2 && mousePos.y >= y + 2 && mousePos.y <= y + 14);
        var inDownBtn = (mousePos.x >= x + bg.width - 26 && mousePos.x <= x + bg.width - 2 && mousePos.y >= y + 16 && mousePos.y <= y + 28);

        btnUp.color = inUpBtn ? 0xFF4F6991 : 0xFF2E3D54;
        btnDown.color = inDownBtn ? 0xFF4F6991 : 0xFF2E3D54;

        var mult = 1.0;
        if (FlxG.keys.pressed.SHIFT) mult = 10.0;
        if (FlxG.keys.pressed.CONTROL) mult = 0.1;

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