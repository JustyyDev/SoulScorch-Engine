package soulscorch.gameplay.notes;

import flixel.FlxG;
import flixel.FlxSprite;

class NoteSplash extends FlxSprite {
    private static var colorDirections:Array<String> = ["purple", "blue", "green", "red"];

    public function new(x:Float = 0, y:Float = 0, ?noteData:Int = 0) {
        super(x, y);
        loadSplash("default");
        antialiasing = true;
        alpha = 0.6;
    }

    public function loadSplash(?skin:String = "default"):Void {
        var atlas = NoteSkinManager.getSplashAtlas(skin);
        if (atlas != null && atlas.frames != null) {
            this.frames = atlas;
            for (i in 0...4) {
                var animName = colorDirections[i];
                animation.addByPrefix('note1-$i', 'note splash $animName 1', 24, false);
                animation.addByPrefix('note2-$i', 'note splash $animName 2', 24, false);
            }
        } else {
            makeGraphic(100, 100, 0xFFFFCC00);
        }
    }

    public function spawn(receptorX:Float, receptorY:Float, noteData:Int, ?skin:String):Void {
        loadSplash(skin);

        setPosition(receptorX - (width * 0.2), receptorY - (height * 0.2));
        alpha = 0.6;

        var variant = FlxG.random.int(1, 2);
        var animName = 'note$variant-${noteData % 4}';

        if (animation.getByName(animName) != null) {
            animation.play(animName, true);
            if (animation.curAnim != null) {
                animation.curAnim.frameRate = 24 + FlxG.random.int(-2, 2);
            }
        } else {
            animation.play('note1-0', true);
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