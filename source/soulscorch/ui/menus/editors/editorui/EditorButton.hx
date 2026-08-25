package soulscorch.ui.menus.editors.editorui;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.Paths;

class EditorButton extends FlxSpriteGroup {
    public var label:FlxText;
    public var bg:FlxSprite;
    public var border:FlxSprite;
    public var accentLine:FlxSprite;
    public var glow:FlxSprite;
    public var onClick:Void->Void;
    public var isHovered:Bool = false;
    public var isPressed:Bool = false;
    public var enabled(default, set):Bool = true;

    public var buttonWidth:Float;
    public var buttonHeight:Float;

    private static inline var COLOR_NORMAL:Int = EditorTheme.BTN_IDLE;
    private static inline var COLOR_HOVER:Int = EditorTheme.BTN_HOVER;
    private static inline var COLOR_PRESS:Int = 0xFF151B1E;
    private static inline var COLOR_DISABLED:Int = 0xFF171B1E;

    private var hoverTween:FlxTween;

    public function new(x:Float, y:Float, width:Float, height:Float, labelText:String, ?onClick:Void->Void) {
        super(x, y);
        this.buttonWidth = width;
        this.buttonHeight = height;
        this.onClick = onClick;

        var w = Std.int(width);
        var h = Std.int(height);

        // Soft glow behind the button
        glow = EditorTheme.makeShadow(w, h, EditorTheme.CORNER_SM, 6);
        glow.alpha = 0.0;
        glow.color = EditorTheme.ACCENT_CYAN;
        add(glow);

        // Outer border frame (rounded)
        border = EditorTheme.makeRoundedRect(w, h, EditorTheme.PANEL_BORDER, EditorTheme.CORNER_SM);
        add(border);

        // Main background body (rounded, inset)
        bg = EditorTheme.makeRoundedRect(w - 2, h - 2, COLOR_NORMAL, EditorTheme.CORNER_SM - 1);
        bg.setPosition(1, 1);
        add(bg);

        // Accent left rail indicator
        accentLine = new FlxSprite(1, 1).makeGraphic(3, Std.int(height - 2), EditorTheme.ACCENT_CYAN);
        add(accentLine);

        label = new FlxText(9, (height - 16) * 0.5 - 1, width - 14, EditorTheme.clampLabel(labelText, Std.int(Math.max(8, width / 7))), 13);
        label.setFormat(Paths.font("vcr"), 13, EditorTheme.TEXT_PRIMARY, CENTER);
        add(label);

        scrollFactor.set(0, 0);
    }

    private function set_enabled(value:Bool):Bool {
        enabled = value;
        if (!enabled) {
            bg.color = COLOR_DISABLED;
            accentLine.visible = false;
            label.color = 0xFF555555;
            glow.alpha = 0.0;
        } else {
            bg.color = COLOR_NORMAL;
            accentLine.visible = true;
            label.color = FlxColor.WHITE;
        }
        return enabled;
    }

    private function animateHover(target:Bool):Void {
        if (hoverTween != null) hoverTween.cancel();
        var targetAlpha = target ? 0.55 : 0.0;
        hoverTween = FlxTween.tween(glow, {alpha: targetAlpha}, 0.18, {ease: FlxEase.quadOut});
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        if (!enabled) return;

        var cam:FlxCamera = (cameras != null && cameras.length > 0) ? cameras[0] : FlxG.camera;
        var mousePos:FlxPoint = FlxG.mouse.getPositionInCameraView(cam);

        var wasHovered = isHovered;
        isHovered = (mousePos.x >= x && mousePos.x <= x + buttonWidth && mousePos.y >= y && mousePos.y <= y + buttonHeight);

        if (isHovered != wasHovered) animateHover(isHovered);

        if (isHovered) {
            if (FlxG.mouse.pressed) {
                isPressed = true;
                bg.color = COLOR_PRESS;
                accentLine.color = EditorTheme.ACCENT_YELLOW;
                border.color = 0xFF00FFCC;
            } else {
                if (isPressed && FlxG.mouse.justReleased) {
                    isPressed = false;
                    AssetHelper.playSoundSafely("scrollMenu", 0.6);
                    if (onClick != null) onClick();
                }
                bg.color = COLOR_HOVER;
                accentLine.color = EditorTheme.ACCENT_CYAN;
                border.color = 0xFF00FFCC;
            }
        } else {
            isPressed = false;
            bg.color = COLOR_NORMAL;
            accentLine.color = EditorTheme.ACCENT_CYAN;
            border.color = EditorTheme.PANEL_BORDER;
        }

        if (FlxG.mouse.justReleased) {
            isPressed = false;
        }
    }
}