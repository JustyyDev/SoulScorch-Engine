package soulscorch.ui.hud;

import flixel.FlxSprite;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.Paths;

class ComboNumber extends FlxSprite {
    public function new(x:Float, y:Float, digit:Int) {
        super(x, y);

        var loaded = AssetHelper.loadGraphicSafely(this, 'ui/num$digit');
        if (!loaded) {
            makeGraphic(24, 30, 0xFFFFFFFF);
        }

        antialiasing = true;
        acceleration.y = 600;
        velocity.y = -FlxG.random.int(140, 180);
        velocity.x = FlxG.random.float(-20, 20);
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        alpha -= elapsed * 1.5;
        if (alpha <= 0) {
            kill();
            destroy();
        }
    }
}