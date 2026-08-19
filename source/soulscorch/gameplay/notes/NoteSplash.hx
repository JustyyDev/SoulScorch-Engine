package soulscorch.gameplay.notes;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;

class NoteSplash extends FlxSprite {
    public function new(x:Float = 0, y:Float = 0, ?noteData:Int = 0) {
        super(x, y);
        loadSplash("NOTE_assets");
        antialiasing = true;
        alpha = 0.6;
    }

    public function loadSplash(?skin:String = "NOTE_assets"):Void {
        var atlas:FlxAtlasFrames = NoteSkinManager.getSplashAtlas(skin);
        if (atlas != null && atlas.frames != null) {
            this.frames = atlas;
            for (i in 0...4) {
                var colorName = NoteSkinManager.noteColors[i];
                animation.addByPrefix('note1-$i', 'note splash $colorName 1', 24, false);
                animation.addByPrefix('note2-$i', 'note splash $colorName 2', 24, false);
                animation.addByPrefix('impact1-$i', 'note impact 1 $colorName', 24, false);
                animation.addByPrefix('impact2-$i', 'note impact 2 $colorName', 24, false);
            }
        } else {
            makeGraphic(100, 100, 0xFFFFCC00);
        }
    }

    public function spawn(receptorX:Float, receptorY:Float, noteData:Int, ?skin:String):Void {
        loadSplash(skin);

        setPosition(receptorX - (width * 0.25), receptorY - (height * 0.25));
        alpha = 0.6;

        var variant = FlxG.random.int(1, 2);
        var animName = 'note$variant-${noteData % 4}';

        if (animation.getByName(animName) == null) {
            animName = 'impact$variant-${noteData % 4}';
        }

        if (animation.getByName(animName) != null) {
            animation.play(animName, true);
            if (animation.curAnim != null) {
                animation.curAnim.frameRate = 24 + FlxG.random.int(-2, 2);
            }
        }

        centerOffsets();
        centerOrigin();
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        if (animation.curAnim != null && animation.curAnim.finished) {
            kill();
        }
    }
}