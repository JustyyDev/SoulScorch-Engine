package soulscorch.gameplay;

import flixel.FlxSprite;
import soulscorch.assets.AssetHelper;

class NoteSplash extends FlxSprite {
    public function new(x:Float = 0, y:Float = 0, direction:Int = 0) {
        super(x, y);
        loadSplashes();
        setup(x, y, direction);
    }

    public function loadSplashes():Void {
        var loaded = AssetHelper.loadSparrowSafely(this, "assets/images/gameplay/splashes/noteSplashes.png", "assets/images/gameplay/splashes/noteSplashes.xml");

        if (loaded) {
            animation.addByPrefix('note0', 'note splash purple', 24, false);
            animation.addByPrefix('note1', 'note splash blue', 24, false);
            animation.addByPrefix('note2', 'note splash green', 24, false);
            animation.addByPrefix('note3', 'note splash red', 24, false);
        } else {
            makeGraphic(140, 140, 0x99FFFFFF);
        }
        antialiasing = true;
    }

    public function setup(x:Float, y:Float, direction:Int):Void {
        setPosition(x, y);
        alpha = 0.85;

        if (animation.getByName('note' + direction) != null) {
            animation.play('note' + direction, true);
            updateHitbox();
            offset.set(width * 0.28, height * 0.28);
        }
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        if (animation.curAnim != null && animation.curAnim.finished) {
            kill();
        }
    }
}