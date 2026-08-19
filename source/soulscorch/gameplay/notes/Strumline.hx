package soulscorch.gameplay.notes;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;

class StrumNote extends FlxSprite {
    public var noteData:Int = 0;
    public var isPlayer:Bool = false;
    public var resetAnim:Float = 0.0;
    public var downscroll:Bool = false;

    private var animOffsets:Map<String, Array<Float>> = new Map<String, Array<Float>>();
    private static var colorDirections:Array<String> = ["purple", "blue", "green", "red"];
    private static var directionNames:Array<String> = ["left", "down", "up", "right"];

    public function new(x:Float, y:Float, noteData:Int, isPlayer:Bool = true, downscroll:Bool = false, ?skin:String = "default") {
        super(x, y);
        this.noteData = noteData;
        this.isPlayer = isPlayer;
        this.downscroll = downscroll;

        loadReceptor(skin);
        playAnim("static");
        antialiasing = true;
    }

    public function loadReceptor(?skin:String = "default"):Void {
        var dirColor = colorDirections[noteData % 4];
        var dirName = directionNames[noteData % 4];

        var atlas = NoteSkinManager.getSkinAtlas(skin);
        if (atlas != null) {
            frames = atlas;
            animation.addByPrefix("static", 'arrow' + dirName.toUpperCase(), 24, false);
            animation.addByPrefix("pressed", '$dirColor press', 24, false);
            animation.addByPrefix("confirm", '$dirColor confirm', 24, false);

            setOffset("static", 0, 0);
            setOffset("pressed", 2, 2);
            setOffset("confirm", 13, 13);
        } else {
            var colors:Array<Int> = [0xFFC24B99, 0xFF00FFFF, 0xFF12FA05, 0xFFF9393F];
            makeGraphic(100, 100, colors[noteData % 4]);
        }

        setGraphicSize(Std.int(width * 0.7));
        updateHitbox();
    }

    public function playAnim(animName:String, force:Bool = false):Void {
        if (animation.getByName(animName) != null) {
            animation.play(animName, force);
            centerOffsets();

            var off = animOffsets.get(animName);
            if (off != null) {
                offset.x += off[0];
                offset.y += off[1];
            }
        }
    }

    public function setOffset(anim:String, x:Float, y:Float):Void {
        animOffsets.set(anim, [x, y]);
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (resetAnim > 0) {
            resetAnim -= elapsed;
            if (resetAnim <= 0) {
                resetAnim = 0;
                playAnim("static");
            }
        }
    }
}

class Strumline extends FlxSpriteGroup {
    public static inline var STRUM_SPACING:Float = 112.0;

    public var receptors:Array<StrumNote> = [];
    public var isPlayer:Bool = true;
    public var downscroll:Bool = false;

    public function new(x:Float, y:Float, isPlayer:Bool = true, downscroll:Bool = false, ?skin:String = "default") {
        super(x, y);
        this.isPlayer = isPlayer;
        this.downscroll = downscroll;

        for (i in 0...4) {
            var strum = new StrumNote(i * STRUM_SPACING, 0, i, isPlayer, downscroll, skin);
            receptors.push(strum);
            add(strum);
        }
    }

    public function playStrumAnim(dir:Int, animName:String, force:Bool = false):Void {
        if (dir >= 0 && dir < receptors.length && receptors[dir] != null) {
            receptors[dir].playAnim(animName, force);
        }
    }

    public function resetStrums():Void {
        for (strum in receptors) {
            if (strum != null) {
                strum.playAnim("static");
                strum.resetAnim = 0;
            }
        }
    }
}