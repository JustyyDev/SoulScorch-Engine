package soulscorch.ui;

import flixel.FlxSprite;
import flixel.math.FlxMath;
import soulscorch.assets.AssetResolver;

class HealthIcon extends FlxSprite {
    public var isPlayer:Bool;
    public var char:String = "";
    public var iconScale:Float = 1.0;
    public var iconOffset:Array<Float> = [0, 0];

    public function new(char:String = "bf", isPlayer:Bool = false) {
        super();
        this.isPlayer = isPlayer;
        changeIcon(char);
        antialiasing = true;
        scrollFactor.set();
    }

    public function changeIcon(newChar:String):Void {
        if (this.char == newChar) return;
        this.char = newChar;
        
        var path = 'assets/images/icons/icon-$char.png';
        if (!AssetResolver.exists(path)) {
            path = 'assets/images/icons/icon-face.png';
        }
        
        loadGraphic(path, true, 150, 150);
        animation.add(char, [0, 1], 0, false, isPlayer);
        animation.play(char);
        updateHitbox();
        
        iconOffset[0] = (width - 150) / 2;
        iconOffset[1] = (height - 150) / 2;
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        
        var mult:Float = FlxMath.lerp(iconScale, 1.0, elapsed * 9);
        scale.set(mult, mult);
        updateHitbox();
        
        offset.set(iconOffset[0], iconOffset[1]);
    }

    public function bop():Void {
        iconScale = 1.2;
        scale.set(1.2, 1.2);
        updateHitbox();
    }
}