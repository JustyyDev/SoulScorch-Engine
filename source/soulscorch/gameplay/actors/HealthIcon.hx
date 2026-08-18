package soulscorch.gameplay.actors;

import flixel.FlxSprite;
import flixel.math.FlxMath;
import openfl.display.BitmapData;
import soulscorch.backend.assets.AssetResolver;

using StringTools;

class HealthIcon extends FlxSprite {
    public var char:String = "face";
    public var isPlayer:Bool = false;
    public var isWinning:Bool = false;
    public var isLosing:Bool = false;

    private var hasLosingIcon:Bool = false;
    private var hasWinningIcon:Bool = false;

    public function new(char:String = "face", isPlayer:Bool = false) {
        super();
        this.isPlayer = isPlayer;
        changeIcon(char);
        scrollFactor.set();
    }

    public function changeIcon(char:String):Void {
        this.char = (char != null && char.length > 0) ? char : "face";

        var iconPathStr = 'icons/icon-$char';
        var resolved = AssetResolver.resolveFile('assets/images/$iconPathStr', [".png"]);
        if (resolved == null) resolved = AssetResolver.resolveFile('assets/preload/images/$iconPathStr', [".png"]);
        if (resolved == null) resolved = AssetResolver.resolveFile('images/$iconPathStr', [".png"]);
        if (resolved == null) resolved = AssetResolver.resolveFile('assets/images/icons/icon-face', [".png"]);

        var bitmap:BitmapData = (resolved != null) ? AssetResolver.getBitmapData(resolved) : null;

        if (bitmap != null) {
            var iconWidth:Int = bitmap.width;
            var iconHeight:Int = bitmap.height;

            // Check how many 150x150 frames exist in the spritesheet
            if (iconWidth >= iconHeight * 3) {
                // 3 Frames: Normal (0), Losing (1), Winning (2)
                var frameWidth = Std.int(iconWidth / 3);
                loadGraphic(bitmap, true, frameWidth, iconHeight);
                animation.add(char, [0, 1, 2], 0, false, isPlayer);
                hasLosingIcon = true;
                hasWinningIcon = true;
            } else if (iconWidth >= iconHeight * 2) {
                // 2 Frames: Normal (0), Losing (1)
                var frameWidth = Std.int(iconWidth / 2);
                loadGraphic(bitmap, true, frameWidth, iconHeight);
                animation.add(char, [0, 1], 0, false, isPlayer);
                hasLosingIcon = true;
                hasWinningIcon = false;
            } else {
                // 1 Single Frame: Use frame 0 for all health states
                loadGraphic(bitmap, true, iconWidth, iconHeight);
                animation.add(char, [0, 0], 0, false, isPlayer);
                hasLosingIcon = false;
                hasWinningIcon = false;
            }

            animation.play(char);
        } else {
            makeGraphic(150, 150, 0xFFFF00FF);
        }

        antialiasing = true;
        updateHitbox();
    }

    public function updateHealth(healthPercent:Float):Void {
        if (animation.curAnim == null) return;

        if (hasWinningIcon && healthPercent > 80.0) {
            animation.curAnim.curFrame = 2;
        } else if (hasLosingIcon && healthPercent < 20.0) {
            animation.curAnim.curFrame = 1;
        } else {
            animation.curAnim.curFrame = 0;
        }
    }

    public function beatHit(beat:Int):Void {
        scale.set(1.2, 1.2);
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        scale.x = FlxMath.lerp(1.0, scale.x, Math.exp(-elapsed * 9.0));
        scale.y = FlxMath.lerp(1.0, scale.y, Math.exp(-elapsed * 9.0));
        updateHitbox();
    }
}