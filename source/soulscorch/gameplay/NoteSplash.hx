package soulscorch.gameplay;

import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import soulscorch.assets.AssetResolver;
import soulscorch.modding.ModLoader;

class NoteSplash extends FlxSprite {
    public function new(x:Float, y:Float, direction:Int) {
        super(x, y);
        
        var rawPath = 'assets/images/gameplay/noteSplashes';
        var resolvedPath = ModLoader.getPath(rawPath);

        if (AssetResolver.exists('$resolvedPath.xml')) {
            frames = FlxAtlasFrames.fromSparrow('$resolvedPath.png', '$resolvedPath.xml');
            
            animation.addByPrefix('note1', 'note splash blue', 24, false);
            animation.addByPrefix('note2', 'note splash green', 24, false);
            animation.addByPrefix('note0', 'note splash purple', 24, false);
            animation.addByPrefix('note3', 'note splash red', 24, false);
            
            setup(direction);
        }
        antialiasing = true;
    }

    public function setup(direction:Int):Void {
        animation.play('note' + direction, true);
        updateHitbox();
        
        offset.set(width * 0.3, height * 0.3);
        alpha = 0.6;
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        if (animation.curAnim != null && animation.curAnim.finished) {
            kill();
        }
    }
}