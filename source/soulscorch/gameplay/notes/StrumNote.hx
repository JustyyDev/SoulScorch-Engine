package soulscorch.gameplay.notes;

import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.system.engine.Runtime;

enum abstract StrumDirection(Int) from Int to Int {
    var LEFT = 0;
    var DOWN = 1;
    var UP = 2;
    var RIGHT = 3;
}

class StrumNote extends FlxSprite {
    public var direction:StrumDirection;
    public var resetAnim:Float = 0.0;
    public var isPlayer:Bool = false;
    public var downscroll:Bool = false;

    public function new(x:Float, y:Float, direction:StrumDirection, isPlayer:Bool = false, downscroll:Bool = false) {
        super(x, y);
        this.direction = direction;
        this.isPlayer = isPlayer;
        this.downscroll = downscroll;

        loadReceptorSkin("gameplay/notes/NOTE_assets");
        scrollFactor.set(0, 0);
    }

    public function loadReceptorSkin(skinPath:String):Void {
        var loaded = AssetHelper.loadSparrowSafely(this, skinPath);
        if (!loaded) {
            loaded = AssetHelper.loadSparrowSafely(this, "notes/NOTE_assets");
            if (!loaded) AssetHelper.loadSparrowSafely(this, "NOTE_assets");
        }

        var dirStr = getDirectionName(direction);

        animation.addByPrefix("static", 'arrow$dirStr');
        animation.addByPrefix("pressed", '$dirStr press', 24, false);
        animation.addByPrefix("confirm", '$dirStr confirm', 24, false);

        antialiasing = (Runtime.config != null) ? Runtime.config.antialiasing : true;
        setGraphicSize(Std.int(width * 0.7));
        updateHitbox();

        playAnim("static");
    }

    public function playAnim(anim:String, force:Bool = false):Void {
        animation.play(anim, force);
        centerOffsets();
        centerOrigin();

        if (anim == "confirm") {
            offset.x -= 13;
            offset.y -= 13;
        }
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        if (resetAnim > 0) {
            resetAnim -= elapsed;
            if (resetAnim <= 0) {
                playAnim("static");
                resetAnim = 0;
            }
        }
    }

    private static inline function getDirectionName(dir:StrumDirection):String {
        return switch (dir) {
            case LEFT: "LEFT";
            case DOWN: "DOWN";
            case UP: "UP";
            case RIGHT: "RIGHT";
        };
    }
}

class Strumline extends FlxSpriteGroup {
    public var receptors:Array<StrumNote> = [];
    public var isPlayer:Bool = false;
    public var downscroll:Bool = false;

    public static inline var STRUM_SPACING:Float = 112.0;

    public function new(x:Float, y:Float, isPlayer:Bool = false, downscroll:Bool = false) {
        super(x, y);
        this.isPlayer = isPlayer;
        this.downscroll = downscroll;

        for (i in 0...4) {
            var receptor = new StrumNote(i * STRUM_SPACING, 0, cast i, isPlayer, downscroll);
            receptors.push(receptor);
            add(receptor);
        }
    }

    public function playReceptorAnim(lane:Int, anim:String, force:Bool = false):Void {
        if (lane >= 0 && lane < receptors.length) {
            receptors[lane].playAnim(anim, force);
        }
    }
}