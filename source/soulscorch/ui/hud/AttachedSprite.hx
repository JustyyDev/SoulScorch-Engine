package soulscorch.ui.hud;

import flixel.FlxSprite;
import soulscorch.backend.assets.AssetHelper;

class AttachedSprite extends FlxSprite {
    public var sprTracker:FlxSprite;
    public var xAdd:Float = 0.0;
    public var yAdd:Float = 0.0;
    public var angleAdd:Float = 0.0;
    public var alphaMult:Float = 1.0;
    public var copyAngle:Bool = true;
    public var copyAlpha:Bool = true;
    public var copyVisible:Bool = true;

    public function new(imagePath:String = "", ?animPrefix:String) {
        super();
        if (imagePath != null && imagePath.length > 0) {
            if (animPrefix != null && animPrefix.length > 0) {
                AssetHelper.loadSparrowSafely(this, imagePath);
                if (animation.getByName("idle") == null) {
                    animation.addByPrefix("idle", animPrefix, 24, true);
                }
                animation.play("idle");
            } else {
                AssetHelper.loadGraphicSafely(this, imagePath);
            }
        }
        antialiasing = true;
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (sprTracker != null && sprTracker.exists) {
            setPosition(sprTracker.x + xAdd, sprTracker.y + yAdd);
            if (sprTracker.scrollFactor != null) {
                scrollFactor.set(sprTracker.scrollFactor.x, sprTracker.scrollFactor.y);
            }

            if (copyAngle) angle = sprTracker.angle + angleAdd;
            if (copyAlpha) alpha = sprTracker.alpha * alphaMult;
            if (copyVisible) visible = sprTracker.visible;
            cameras = sprTracker.cameras;
        } else if (sprTracker != null) {
            visible = false;
        }
    }
}