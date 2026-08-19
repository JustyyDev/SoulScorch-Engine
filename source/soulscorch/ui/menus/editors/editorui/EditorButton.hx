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
    public var onClick:Void->Void;
    public var isHovered:Bool = false;
    public var isPressed:Bool = false;
    public var enabled:Bool = true;

    public var buttonWidth:Float;
    public var buttonHeight:Float;

    private static inline var COLOR_NORMAL:Int = 0xFF243044;
    private static inline var COLOR_HOVER:Int = 0xFF384D6E;
    private static inline var COLOR_PRESS:Int = 0xFF18202E;
    private static inline var COLOR_DISABLED:Int = 0xFF151B26;

    public function new(x:Float, y:Float, width:Float, height:Float, labelText:String, ?onClick:Void->Void) {
        super(x, y);
        this.buttonWidth = width;
        this.buttonHeight = height;
        this.onClick = onClick;

        border = new FlxSprite(0, 0).makeGraphic(Std.int(width), Std.int(height), 0xFF3F557A);
        add(border);

        bg = new FlxSprite(1, 1).makeGraphic(Std.int(width - 2), Std.int(height - 2), COLOR_NORMAL);
        add(bg);

        label = new FlxText(4, (height - 16) * 0.5, width - 8, labelText, 14);
        label.setFormat(Paths.font("vcr"), 14, FlxColor.WHITE, CENTER);
        add(label);

        scrollFactor.set(0, 0);
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (!enabled) {
            bg.color = COLOR_DISABLED;
            label.color = 0xFF666666;
            return;
        }

        var cam:FlxCamera = (cameras != null && cameras.length > 0) ? cameras[0] : FlxG.camera;
        var mousePos:FlxPoint = FlxG.mouse.getPositionInCameraView(cam);

        isHovered = (mousePos.x >= x && mousePos.x <= x + buttonWidth && mousePos.y >= y && mousePos.y <= y + buttonHeight);

        if (isHovered) {
            if (FlxG.mouse.pressed) {
                isPressed = true;
                bg.color = COLOR_PRESS;
            } else {
                if (isPressed && FlxG.mouse.justReleased) {
                    isPressed = false;
                    AssetHelper.playSoundSafely("scrollMenu", 0.6);
                    if (onClick != null) onClick();
                }
                bg.color = COLOR_HOVER;
            }
        } else {
            isPressed = false;
            bg.color = COLOR_NORMAL;
        }

        if (FlxG.mouse.justReleased) {
            isPressed = false;
        }
    }
}