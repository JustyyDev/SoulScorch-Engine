package soulscorch.ui.hud;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.tweens.FlxTween;
import soulscorch.backend.assets.AssetHelper;

class ComboNumber extends FlxSprite {
    public function new(x:Float, y:Float, digit:Int) {
        super(x, y);

        var loaded = AssetHelper.loadGraphicSafely(this, 'ui/game/score/num$digit');
        if (!loaded) loaded = AssetHelper.loadGraphicSafely(this, 'ui/ratings/num$digit');
        if (!loaded) loaded = AssetHelper.loadGraphicSafely(this, 'ui/game/ratings/num$digit');
        if (!loaded) loaded = AssetHelper.loadGraphicSafely(this, 'ui/num$digit');
        if (!loaded) makeGraphic(24, 30, 0xFFFFFFFF);

        antialiasing = true;
        acceleration.y = 600;
        velocity.y = -FlxG.random.int(140, 180);
        velocity.x = FlxG.random.float(-10, 10);

        FlxTween.tween(this, {alpha: 0}, 0.25, {
            startDelay: 0.4,
            onComplete: function(_) {
                kill();
                destroy();
            }
        });
    }

    override public function destroy():Void {
        FlxTween.cancelTweensOf(this);
        super.destroy();
    }
}