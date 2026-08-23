package soulscorch.ui.menus.editors.editorui;

import flixel.FlxSprite;
import flixel.util.FlxColor;
import openfl.display.Shape;
import openfl.display.BitmapData;

class EditorTheme {
    // --- Core surfaces ---
    public static inline var BG_DARK:FlxColor = 0xFF0B0910;
    public static inline var PANEL_BG:FlxColor = 0xEE16121F;
    public static inline var PANEL_HEADER:FlxColor = 0xFF1E1830;
    public static inline var PANEL_BORDER:FlxColor = 0xFF322A47;

    // --- Accents ---
    public static inline var ACCENT_CYAN:FlxColor = 0xFF20F1C8;
    public static inline var ACCENT_MAGENTA:FlxColor = 0xFFFF0055;
    public static inline var ACCENT_PURPLE:FlxColor = 0xFF8A3FFC;
    public static inline var ACCENT_YELLOW:FlxColor = 0xFFFFD700;
    public static inline var ACCENT_BLUE:FlxColor = 0xFF2D9BFF;

    // --- Buttons ---
    public static inline var BTN_IDLE:FlxColor = 0xFF231E33;
    public static inline var BTN_HOVER:FlxColor = 0xFF352D4D;
    public static inline var BTN_ACTIVE:FlxColor = 0xFF00FFCC;

    // --- Text ---
    public static inline var TEXT_PRIMARY:FlxColor = 0xFFFFFFFF;
    public static inline var TEXT_MUTED:FlxColor = 0xFF9F9BAA;
    public static inline var TEXT_HIGHLIGHT:FlxColor = 0xFF00FFCC;
    public static inline var TEXT_DANGER:FlxColor = 0xFFFF3366;

    // --- Grid ---
    public static inline var GRID_EVEN:FlxColor = 0xFF171321;
    public static inline var GRID_ODD:FlxColor = 0xFF1D192B;
    public static inline var GRID_SEPARATOR:FlxColor = 0xFF2F2845;

    // --- Geometry helpers ---
    public static inline var CORNER_SM:Int = 6;
    public static inline var CORNER_MD:Int = 10;
    public static inline var CORNER_LG:Int = 14;

    /**
     * Creates a FlxSprite containing a rounded-rectangle filled with `color`.
     * The sprite's top-left is the origin (0,0) so it can be positioned like a normal rect.
     */
    public static function makeRoundedRect(width:Int, height:Int, color:FlxColor, radius:Int = CORNER_MD, alpha:Float = 1.0):FlxSprite {
        var spr = new FlxSprite();
        var bmd = new BitmapData(width, height, true, 0x00000000);
        var shape = new Shape();
        shape.graphics.beginFill(color, alpha);
        shape.graphics.drawRoundRect(0, 0, width, height, radius, radius);
        shape.graphics.endFill();
        bmd.draw(shape);
        spr.loadGraphic(bmd);
        return spr;
    }

    /**
     * Creates a soft drop-shadow sprite sized to the given rect. Place it BEHIND
     * the target element and offset by (blur, blur) for a lifted look.
     */
    public static function makeShadow(width:Int, height:Int, radius:Int = CORNER_MD, blur:Int = 8):FlxSprite {
        var spr = new FlxSprite();
        var bmd = new BitmapData(width + blur * 2, height + blur * 2, true, 0x00000000);
        for (i in 0...blur) {
            var a = (0.30 * (1.0 - (i / blur)));
            var shape = new Shape();
            shape.graphics.beginFill(0x000000, a);
            shape.graphics.drawRoundRect(blur - i, blur - i, width + i * 2, height + i * 2, radius + i, radius + i);
            shape.graphics.endFill();
            bmd.draw(shape);
        }
        spr.loadGraphic(bmd);
        return spr;
    }

    /**
     * Creates a small circular accent dot (used for status indicators / bullets).
     */
    public static function makeDot(size:Int, color:FlxColor):FlxSprite {
        var spr = new FlxSprite();
        var bmd = new BitmapData(size, size, true, 0x00000000);
        var shape = new Shape();
        shape.graphics.beginFill(color, 1.0);
        shape.graphics.drawCircle(size * 0.5, size * 0.5, size * 0.5);
        shape.graphics.endFill();
        bmd.draw(shape);
        spr.loadGraphic(bmd);
        return spr;
    }

    /**
     * Creates a full-screen subtle vignette overlay (darkened edges) to give
     * editor canvases more depth. Add it at the bottom of the draw stack.
     */
    public static function makeVignette(width:Int, height:Int):FlxSprite {
        var spr = new FlxSprite();
        var bmd = new BitmapData(width, height, true, 0x00000000);
        var cx = width * 0.5;
        var cy = height * 0.5;
        var maxDist = Math.sqrt(cx * cx + cy * cy);
        for (y in 0...height) {
            for (x in 0...width) {
                var dx = x - cx;
                var dy = y - cy;
                var dist = Math.sqrt(dx * dx + dy * dy);
                var a = (dist / maxDist);
                a = a * a * 0.55; // edge darkness
                bmd.setPixel32(x, y, (Std.int(a * 255) << 24) | 0x000000);
            }
        }
        spr.loadGraphic(bmd);
        return spr;
    }

    /**
     * Creates a glowing diamond event-node marker used in the chart editor.
     */
    public static function makeEventMarker(size:Int):FlxSprite {
        var spr = new FlxSprite();
        var bmd = new BitmapData(size, size, true, 0x00000000);
        var s = new Shape();
        var hw = size * 0.5;

        // Outer glow
        s.graphics.beginFill(ACCENT_YELLOW, 0.22);
        s.graphics.moveTo(hw, 1); s.graphics.lineTo(size - 1, hw); s.graphics.lineTo(hw, size - 1); s.graphics.lineTo(1, hw); s.graphics.lineTo(hw, 1);
        s.graphics.endFill();

        // Body
        s.graphics.beginFill(ACCENT_YELLOW, 1.0);
        s.graphics.moveTo(hw, 4); s.graphics.lineTo(size - 4, hw); s.graphics.lineTo(hw, size - 4); s.graphics.lineTo(4, hw); s.graphics.lineTo(hw, 4);
        s.graphics.endFill();

        // Inner core
        s.graphics.beginFill(0xFF2A233D, 1.0);
        s.graphics.moveTo(hw, 9); s.graphics.lineTo(size - 9, hw); s.graphics.lineTo(hw, size - 9); s.graphics.lineTo(9, hw); s.graphics.lineTo(hw, 9);
        s.graphics.endFill();

        bmd.draw(s);
        spr.loadGraphic(bmd);
        return spr;
    }
}