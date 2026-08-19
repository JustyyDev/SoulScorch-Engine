package soulscorch.gameplay.notes;

import flixel.FlxSprite;

class StrumArrow extends FlxSprite {
    public var noteData:Int = 0;
    public var resetAnim:Float = 0.0;
    public var downscroll:Bool = false;
    public var isPlayer:Bool = false;

    public var baseX:Float = 0.0;
    public var baseY:Float = 0.0;

    private static var colArray:Array<String> = ['purple', 'blue', 'green', 'red'];

    public function new(x:Float, y:Float, noteData:Int, isPlayer:Bool = false, downscroll:Bool = false, ?skin:String = "default") {
        super(x, y);

        this.noteData = noteData;
        this.isPlayer = isPlayer;
        this.downscroll = downscroll;
        this.baseX = x;
        this.baseY = y;

        loadSkin(skin);
        playAnim("static");
    }

    public function loadSkin(?skinPath:String):Void {
        var atlas = NoteSkinManager.getSkinAtlas(skinPath);
        if (atlas != null) {
            frames = atlas;
            var col = colArray[noteData % 4];
            animation.addByPrefix("static", 'arrow' + col.toUpperCase(), 24, false);
            animation.addByPrefix("pressed", '$col press', 24, false);
            animation.addByPrefix("confirm", '$col confirm', 24, false);
        } else {
            var colors:Array<Int> = [0xFFC24B99, 0xFF00FFFF, 0xFF12FA05, 0xFFF9393F];
            makeGraphic(100, 100, colors[noteData % 4]);
        }

        antialiasing = true;
        setGraphicSize(Std.int(width * 0.7));
        updateHitbox();
    }

    public function playAnim(animName:String, force:Bool = false):Void {
        animation.play(animName, force);
        centerOffsets();
        centerOrigin();

        if (animName == "confirm") {
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