package soulscorch.gameplay.notes;

import flixel.FlxG;
import flixel.FlxSprite;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.Paths;

class NoteSplash extends FlxSprite {
    private var colorDirections:Array<String> = ["purple", "blue", "green", "red"];

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
        } else {
            var fallbackAtlas = Paths.getSparrowAtlas("ui/noteSplashes");
            if (fallbackAtlas == null) fallbackAtlas = Paths.getSparrowAtlas("noteSplashes");
            if (fallbackAtlas != null) {
                this.frames = fallbackAtlas;
            }
        }

        if (this.frames != null) {
            for (i in 0...4) {
                var animName = colorDirections[i];
                animation.addByPrefix('note1-$i', 'note splash $animName 1', 24, false);
                animation.addByPrefix('note2-$i', 'note splash $animName 2', 24, false);
            }
        } else {
            makeGraphic(100, 100, 0xFFFFCC00);
        }
    }

    public function spawn(x:Float, y:Float, noteData:Int, ?skin:String):Void {
        loadSplash(skin);

        // Center splash offset relative to strum receptor
        this.x = x - 70;
        this.y = y - 70;
        alpha = 0.6;

        var variant = FlxG.random.int(1, 2);
        var animName = 'note$variant-$noteData';

        if (animation.getByName(animName) != null) {
            animation.play(animName, true);
            animation.curAnim.frameRate = 24 + FlxG.random.int(-2, 2);
        } else {
            animation.play('note1-0', true);
        }
        centerOffsets();
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (animation.finished) {
            kill();
        }
    }
}