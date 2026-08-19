package soulscorch.gameplay.notes;

import flixel.FlxG;
import flixel.FlxSprite;
import soulscorch.backend.assets.AssetHelper;

class NoteSplash extends FlxSprite {
    public var direction:Int = 0;

    public function new(x:Float = 0, y:Float = 0, direction:Int = 0) {
        super(x, y);
        this.direction = direction;

        loadSplashSkin("notes/noteSplashes");
        antialiasing = true;
        scrollFactor.set(0, 0);
    }

    public function loadSplashSkin(skinPath:String = "notes/noteSplashes"):Void {
        var loaded = AssetHelper.loadSparrowSafely(this, skinPath);
        if (!loaded) {
            loaded = AssetHelper.loadSparrowSafely(this, "noteSplashes");
        }

        if (loaded) {
            var dirs = ["purple", "blue", "green", "red"];
            for (i in 0...4) {
                var colorName = dirs[i];
                animation.addByPrefix('splash-$i-1', 'note splash $colorName 1', 24, false);
                animation.addByPrefix('splash-$i-2', 'note splash $colorName 2', 24, false);
                if (!animation.exists('splash-$i-1')) {
                    animation.addByPrefix('splash-$i-1', 'splash $colorName 1', 24, false);
                    animation.addByPrefix('splash-$i-2', 'splash $colorName 2', 24, false);
                }
            }
        }
    }

    public function spawn(x:Float, y:Float, direction:Int = 0):Void {
        this.direction = direction;
        setPosition(x, y);

        var variation = FlxG.random.int(1, 2);
        animation.play('splash-$direction-$variation', true);

        if (animation.curAnim != null) {
            offset.set(width * 0.3, height * 0.3);
        }

        alpha = 0.85;
        visible = true;

        animation.finishCallback = function(_) {
            kill();
            visible = false;
        };
    }
}