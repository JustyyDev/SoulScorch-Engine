package soulscorch.gameplay.notes;

import flixel.group.FlxSpriteGroup;

class Strumline extends FlxSpriteGroup {
    public var receptors:Array<StrumArrow> = [];
    public var isPlayer:Bool = false;
    public var downscroll:Bool = false;

    public static inline var STRUM_SPACING:Float = 112.0;

    public function new(x:Float, y:Float, isPlayer:Bool = false, downscroll:Bool = false, skin:String = "NOTE_assets") {
        super(x, y);
        this.isPlayer = isPlayer;
        this.downscroll = downscroll;

        createReceptors(skin);
    }

    public function createReceptors(skin:String = "NOTE_assets"):Void {
        clearReceptors();

        for (i in 0...4) {
            var receptor = new StrumArrow(i * STRUM_SPACING, 0, i, isPlayer, downscroll, skin);
            receptors.push(receptor);
            add(receptor);
        }
    }

    public function clearReceptors():Void {
        while (receptors.length > 0) {
            var r = receptors.pop();
            remove(r, true);
            r.destroy();
        }
    }

    public function playStrumAnim(dir:Int, animName:String, force:Bool = true):Void {
        if (dir >= 0 && dir < receptors.length && receptors[dir] != null) {
            receptors[dir].playAnim(animName, force);
        }
    }
}