package soulscorch.ui.hud;

import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.ui.FlxBar;
import flixel.util.FlxColor;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.gameplay.actors.HealthIcon;

class HealthBar extends FlxSpriteGroup {
    public var bg:FlxSprite;
    public var bar:FlxBar;
    public var iconP1:HealthIcon;
    public var iconP2:HealthIcon;

    public var percent(default, set):Float = 50.0;
    public var iconOffset:Float = 26.0;

    public function new(x:Float, y:Float, charP1:String = "bf", charP2:String = "dad") {
        super(x, y);

        bg = new FlxSprite(0, 0);
        if (!AssetHelper.loadGraphicSafely(bg, "ui/game/healthBar")) {
            if (!AssetHelper.loadGraphicSafely(bg, "ui/healthBar")) {
                bg.makeGraphic(604, 19, FlxColor.BLACK);
            }
        }
        bg.antialiasing = true;
        add(bg);

        bar = new FlxBar(
            bg.x + 4,
            bg.y + 4,
            RIGHT_TO_LEFT,
            Std.int(bg.width - 8),
            Std.int(bg.height - 8),
            this,
            "percent",
            0,
            100
        );
        bar.createFilledBar(0xFFFF0000, 0xFF66FF33);
        bar.antialiasing = true;
        add(bar);

        iconP1 = new HealthIcon(charP1, true);
        iconP2 = new HealthIcon(charP2, false);

        add(iconP2);
        add(iconP1);

        set_percent(50.0);
    }

    public function setColors(leftColor:FlxColor, rightColor:FlxColor):Void {
        if (bar != null) bar.createFilledBar(leftColor, rightColor);
    }

    private function set_percent(value:Float):Float {
        percent = Math.max(0.0, Math.min(100.0, value));

        if (bar != null) {
            var factor:Float = (percent / 100.0);

            if (iconP1 != null) {
                iconP1.x = bar.x + (bar.width * (1.0 - factor)) - iconOffset;
                iconP1.y = bar.y - (iconP1.height / 2.0) + (bar.height / 2.0);
                iconP1.updateHealth(percent);
            }

            if (iconP2 != null) {
                iconP2.x = bar.x + (bar.width * (1.0 - factor)) - (iconP2.width - iconOffset);
                iconP2.y = bar.y - (iconP2.height / 2.0) + (bar.height / 2.0);
                iconP2.updateHealth(100.0 - percent);
            }
        }

        return percent;
    }

    public function bop(beat:Int = 0):Void {
        if (iconP1 != null) iconP1.beatHit(beat);
        if (iconP2 != null) iconP2.beatHit(beat);
    }
}