package soulscorch.gameplay.actors;

import flixel.FlxSprite;
import flixel.math.FlxMath;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.interfaces.IBeatReceiver;

class HealthIcon extends FlxSprite implements IBeatReceiver {
    public var character:String = "face";
    public var isPlayer:Bool = false;
    public var isWinning:Bool = false;
    public var isLosing:Bool = false;

    public var iconScale:Float = 1.0;
    public var bopScale:Float = 1.2;

    public function new(character:String = "face", isPlayer:Bool = false) {
        super();
        this.isPlayer = isPlayer;
        changeIcon(character);
        scrollFactor.set(0, 0);
    }

    /**
     * Loads an icon grid sheet (neutral, losing, and optional winning frames).
     */
    public function changeIcon(char:String):Void {
        this.character = char;
        var iconPath = Paths.image('icons/icon-$char');
        if (!AssetResolver.exists(iconPath)) {
            iconPath = Paths.image('icons/icon-face');
        }

        var graphic = AssetResolver.getImage(iconPath);
        if (graphic != null) {
            // Determine whether the icon sheet contains 2 frames (neutral, losing) or 3 (+ winning)
            var frameCount = Math.floor(graphic.width / 150);
            loadGraphic(graphic, true, 150, 150);

            if (frameCount >= 3) {
                animation.add("neutral", [0], 0, false, isPlayer);
                animation.add("losing", [1], 0, false, isPlayer);
                animation.add("winning", [2], 0, false, isPlayer);
            } else {
                animation.add("neutral", [0], 0, false, isPlayer);
                animation.add("losing", [1], 0, false, isPlayer);
                animation.add("winning", [0], 0, false, isPlayer);
            }

            animation.play("neutral");
        }
    }

    public function updateHealth(healthPercent:Float):Void {
        if (healthPercent < 20.0) {
            isLosing = true;
            isWinning = false;
            animation.play("losing");
        } else if (healthPercent > 80.0) {
            isLosing = false;
            isWinning = true;
            animation.play("winning");
        } else {
            isLosing = false;
            isWinning = false;
            animation.play("neutral");
        }
    }

    public function stepHit(step:Int):Void {}

    public function beatHit(beat:Int):Void {
        scale.set(bopScale, bopScale);
    }

    public function measureHit(measure:Int):Void {}

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        scale.set(
            FlxMath.lerp(iconScale, scale.x, Math.exp(-elapsed * 9.0)),
            FlxMath.lerp(iconScale, scale.y, Math.exp(-elapsed * 9.0))
        );
        updateHitbox();
    }
}