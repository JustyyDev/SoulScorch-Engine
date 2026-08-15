package soulscorch.gameplay;

import flixel.FlxSprite;
import soulscorch.assets.AssetHelper;

class StrumArrow extends FlxSprite {
    public var direction:Int = 0;
    public var resetAnim:Float = 0;
    public var player:Int = 0;

    static var dirNames:Array<String> = ['left', 'down', 'up', 'right'];
    static var staticNames:Array<String> = ['arrowLEFT', 'arrowDOWN', 'arrowUP', 'arrowRIGHT'];

    public function new(x:Float, y:Float, direction:Int, player:Int = 1) {
        super(x, y);
        this.direction = direction;
        this.player = player;

        loadStrumGraphic();
    }

    public function loadStrumGraphic():Void {
        // Path matches: assets/preload/images/gameplay/notes/default.png + .xml
        var loaded = AssetHelper.loadSparrowSafely(this, "assets/images/gameplay/notes/default.png", "assets/images/gameplay/notes/default.xml");

        if (loaded) {
            var dir = dirNames[direction % 4];
            var staticDir = staticNames[direction % 4];

            animation.addByPrefix('static', staticDir + '0', 24, false);
            animation.addByPrefix('pressed', dir + ' press', 24, false);
            animation.addByPrefix('confirm', dir + ' confirm', 24, false);

            playAnim('static');
            setGraphicSize(Std.int(width * 0.7));
            updateHitbox();
        } else {
            makeGraphic(110, 110, 0x88FFFFFF);
        }

        antialiasing = true;
    }

    public function playAnim(animName:String, force:Bool = false):Void {
        animation.play(animName, force);
        centerOffsets();
        centerOrigin();

        // Adjust offsets for glowing confirmation pop
        if (animName == 'confirm') {
            offset.x += 13;
            offset.y += 13;
        }
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (resetAnim > 0) {
            resetAnim -= elapsed;
            if (resetAnim <= 0) {
                playAnim('static');
                resetAnim = 0;
            }
        }
    }
}