package soulscorch.gameplay.notes;

import flixel.FlxSprite;
import soulscorch.backend.assets.AssetHelper;

class StrumArrow extends FlxSprite {
    public var noteData:Int = 0;
    public var resetAnim:Float = 0.0;
    public var downscroll:Bool = false;
    public var isPlayer:Bool = false;

    public var baseX:Float = 0.0;
    public var baseY:Float = 0.0;

    private static var colArray:Array<String> = ['purple', 'blue', 'green', 'red'];

    public function new(x:Float, y:Float, noteData:Int, isPlayer:Bool = false, downscroll:Bool = false) {
        super(x, y);

        this.noteData = noteData;
        this.isPlayer = isPlayer;
        this.downscroll = downscroll;
        this.baseX = x;
        this.baseY = y;

        loadSkin();
        playAnim("static");
    }

    public function loadSkin():Void {
        AssetHelper.loadSparrowSafely(this, "gameplay/notes/NOTE_assets");

        var col = colArray[noteData % 4];
        animation.addByPrefix("static", 'arrow' + col.toUpperCase(), 24, false);
        animation.addByPrefix("pressed", '$col press', 24, false);
        animation.addByPrefix("confirm", '$col confirm', 24, false);

        antialiasing = true;
        setGraphicSize(Std.int(width * 0.7));
        updateHitbox();
    }

    public function playAnim(animName:String, force:Bool = false):Void {
        animation.play(animName, force);
        centerOffsets();
        centerOrigin();

        if (animName == "confirm") {
            centerOffsets();
            offset.x -= 13;
            offset.y -= 13;
        }
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