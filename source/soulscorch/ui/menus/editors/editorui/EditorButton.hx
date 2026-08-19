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

class EditorButton extends FlxSpriteGroup {
    public var label:FlxText;
    public var bg:FlxSprite;
    public var border:FlxSprite;
    public var accentLine:FlxSprite;
    public var onClick:Void->Void;
    public var isHovered:Bool = false;
    public var isPressed:Bool = false;
    public var enabled(default, set):Bool = true;

    public var buttonWidth:Float;
    public var buttonHeight:Float;

    private static inline var COLOR_NORMAL:Int = 0xFF1A1C28;
    private static inline var COLOR_HOVER:Int = 0xFF25293C;
    private static inline var COLOR_PRESS:Int = 0xFF10121A;
    private static inline var COLOR_DISABLED:Int = 0xFF0D0F14;

    public function new(x:Float, y:Float, width:Float, height:Float, labelText:String, ?onClick:Void->Void) {
        super(x, y);
        this.buttonWidth = width;
        this.buttonHeight = height;
        this.onClick = onClick;

        // Outer Glow / Border Frame
        border = new FlxSprite(0, 0).makeGraphic(Std.int(width), Std.int(height), 0xFF2F364D);
        add(border);

        // Main Background Body
        bg = new FlxSprite(1, 1).makeGraphic(Std.int(width - 2), Std.int(height - 2), COLOR_NORMAL);
        add(bg);

        // Modern Accent Bottom Line Indicator
        accentLine = new FlxSprite(1, height - 3).makeGraphic(Std.int(width - 2), 2, 0xFF00FFCC);
        add(accentLine);

        label = new FlxText(4, (height - 16) * 0.5 - 1, width - 8, labelText, 13);
        label.setFormat(Paths.font("vcr"), 13, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        label.borderSize = 1.0;
        add(label);

        scrollFactor.set(0, 0);
    }

    private function set_enabled(value:Bool):Bool {
        enabled = value;
        if (!enabled) {
            bg.color = COLOR_DISABLED;
            accentLine.visible = false;
            label.color = 0xFF555555;
        } else {
            bg.color = COLOR_NORMAL;
            accentLine.visible = true;
            label.color = FlxColor.WHITE;
        }
        return enabled;
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        if (!enabled) return;

        var cam:FlxCamera = (cameras != null && cameras.length > 0) ? cameras[0] : FlxG.camera;
        var mousePos:FlxPoint = FlxG.mouse.getPositionInCameraView(cam);

        isHovered = (mousePos.x >= x && mousePos.x <= x + buttonWidth && mousePos.y >= y && mousePos.y <= y + buttonHeight);

        if (isHovered) {
            if (FlxG.mouse.pressed) {
                isPressed = true;
                bg.color = COLOR_PRESS;
                accentLine.color = 0xFF009977;
            } else {
                if (isPressed && FlxG.mouse.justReleased) {
                    isPressed = false;
                    AssetHelper.playSoundSafely("scrollMenu", 0.6);
                    if (onClick != null) onClick();
                }
                bg.color = COLOR_HOVER;
                accentLine.color = 0xFF00FFFF;
            }
            border.color = 0xFF00FFCC;
        } else {
            isPressed = false;
            bg.color = COLOR_NORMAL;
            accentLine.color = 0xFF00FFCC;
            border.color = 0xFF2F364D;
        }

        if (FlxG.mouse.justReleased) {
            isPressed = false;
        }
    }
}