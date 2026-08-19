package soulscorch.gameplay.actors;

import flixel.FlxSprite;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import openfl.display.BitmapData;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;

using StringTools;

class HealthIcon extends FlxSprite {
    public var char:String = "face";
    public var isPlayer:Bool = false;
    public var sprTracker:FlxSprite = null;
    public var trackerOffset:FlxPoint;

    private var hasLosingIcon:Bool = false;
    private var hasWinningIcon:Bool = false;

    public function new(char:String = "face", isPlayer:Bool = false) {
        super();
        this.isPlayer = isPlayer;
        this.trackerOffset = FlxPoint.get(10, -30);
        changeIcon(char);
        scrollFactor.set();
    }

    public function changeIcon(newChar:String):Void {
        var cleanChar = (newChar != null && newChar.trim().length > 0) ? newChar.trim() : "face";
        this.char = cleanChar;

        var iconCandidates = [
            'ui/game/icons/icon-$cleanChar',
            'ui/game/icons/$cleanChar',
            'ui/game/icons/$cleanChar/icon',
            'images/ui/game/icons/icon-$cleanChar',
            'images/ui/game/icons/$cleanChar',
            'images/icons/icon-$cleanChar',
            'images/icons/$cleanChar',
            'icons/icon-$cleanChar',
            'icons/$cleanChar',
            'ui/game/icons/icon-face',
            'icons/icon-face',
            'images/icons/icon-face'
        ];

        var resolved:String = null;
        for (c in iconCandidates) {
            resolved = AssetResolver.resolveFile(c, [".png", ""]);
            if (resolved != null) break;
        }

        var bitmap:BitmapData = (resolved != null) ? AssetResolver.getBitmapData(resolved) : null;

        if (bitmap != null) {
            var iconWidth:Int = bitmap.width;
            var iconHeight:Int = bitmap.height;

            if (iconWidth >= iconHeight * 3) {
                var frameWidth = Std.int(iconWidth / 3);
                loadGraphic(bitmap, true, frameWidth, iconHeight);
                animation.add(cleanChar, [0, 1, 2], 0, false, isPlayer);
                hasLosingIcon = true;
                hasWinningIcon = true;
            } else if (iconWidth >= iconHeight * 2) {
                var frameWidth = Std.int(iconWidth / 2);
                loadGraphic(bitmap, true, frameWidth, iconHeight);
                animation.add(cleanChar, [0, 1], 0, false, isPlayer);
                hasLosingIcon = true;
                hasWinningIcon = false;
            } else {
                loadGraphic(bitmap, true, iconWidth, iconHeight);
                animation.add(cleanChar, [0, 0], 0, false, isPlayer);
                hasLosingIcon = false;
                hasWinningIcon = false;
            }

            animation.play(cleanChar);
        } else {
            makeGraphic(150, 150, 0xFFFF00FF);
        }

        antialiasing = !cleanChar.endsWith("-pixel");
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

    public function bounce():Void {
        scale.set(1.2, 1.2);
    }

    public function beatHit(beat:Int):Void {
        bounce();
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (sprTracker != null) {
            setPosition(sprTracker.x + sprTracker.width + trackerOffset.x, sprTracker.y + trackerOffset.y);
            scrollFactor.set(sprTracker.scrollFactor.x, sprTracker.scrollFactor.y);
            visible = sprTracker.visible;
            alpha = sprTracker.alpha;
        }

        var lerpFactor = FlxMath.bound(elapsed * 9.0, 0, 1);
        scale.x = FlxMath.lerp(scale.x, 1.0, lerpFactor);
        scale.y = FlxMath.lerp(scale.y, 1.0, lerpFactor);
    }

    override public function destroy():Void {
        if (trackerOffset != null) {
            trackerOffset.put();
            trackerOffset = null;
        }
        super.destroy();
    }
}