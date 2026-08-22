package soulscorch.gameplay.notes;

import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.util.FlxColor;
import soulscorch.backend.assets.Paths;
import soulscorch.gameplay.notes.NoteSkinManager;

using StringTools;

class StrumArrow extends FlxSprite {
    public var direction:Int = 0;
    public var resetAnim:Float = 0.0;
    public var isPlayer:Bool = false;
    public var downscroll:Bool = false;
    public var currentSkin:String = "NOTE_assets";

    public var baseX:Float = 0.0;
    public var baseY:Float = 0.0;
    public var skinScale:Float = 0.7;

    public static inline var STRUM_SIZE:Float = 112.0 * 0.7;

    private static var DIR_STRINGS:Array<String> = ["left", "down", "up", "right"];
    private static var DIR_UPPER:Array<String> = ["LEFT", "DOWN", "UP", "RIGHT"];

    public function new(x:Float, y:Float, direction:Int, isPlayer:Bool = false, downscroll:Bool = false, ?skin:String = "NOTE_assets") {
        super(x, y);
        this.direction = direction % 4;
        this.isPlayer = isPlayer;
        this.downscroll = downscroll;
        this.baseX = x;
        this.baseY = y;
        this.currentSkin = (skin != null && skin.trim().length > 0) ? skin.trim() : "NOTE_assets";

        loadReceptorSkin(this.currentSkin);

        antialiasing = true;
        scrollFactor.set(0, 0);

        playAnim("static", true);
    }

    public function loadReceptorSkin(skin:String = "NOTE_assets"):Void {
        this.currentSkin = (skin != null && skin.trim().length > 0) ? skin.trim() : "NOTE_assets";
        var skinConf = NoteSkinManager.getSkinConfig(this.currentSkin);
        this.skinScale = (skinConf != null && skinConf.scale > 0) ? skinConf.scale : 0.7;
        antialiasing = (skinConf != null) ? skinConf.antialiasing : true;

        var atlas:FlxAtlasFrames = NoteSkinManager.getSkinAtlas(this.currentSkin);
        if (atlas != null) {
            frames = atlas;
            setupAnimations();
        } else {
            makeGraphic(Std.int(STRUM_SIZE), Std.int(STRUM_SIZE), NoteSkinManager.getLaneColor(this.direction));
        }

        scale.set(skinScale, skinScale);
        updateHitbox();
    }

    public function setupAnimations():Void {
        if (frames == null || frames.frames == null || frames.frames.length == 0) return;

        animation.destroyAnimations();

        var dirIdx = direction % 4;
        var dirName = DIR_STRINGS[dirIdx];
        var dirUpper = DIR_UPPER[dirIdx];
        var colorName = NoteSkinManager.noteColors[dirIdx];

        // 1. Static Strum (Static arrow receptor)
        animation.addByPrefix("static", 'arrow$dirUpper', 24, false);
        if (animation.getByName("static") == null) animation.addByPrefix("static", 'arrow $dirUpper', 24, false);
        if (animation.getByName("static") == null) animation.addByPrefix("static", '$dirName static', 24, false);
        if (animation.getByName("static") == null) animation.addByPrefix("static", 'static $dirName', 24, false);

        // 2. Pressed Strum (Key down animation)
        animation.addByPrefix("pressed", '$dirName press', 24, false);
        if (animation.getByName("pressed") == null) animation.addByPrefix("pressed", '$colorName press', 24, false);
        if (animation.getByName("pressed") == null) animation.addByPrefix("pressed", '$dirName note press', 24, false);
        if (animation.getByName("pressed") == null) animation.addByPrefix("pressed", '$dirUpper press', 24, false);

        // 3. Confirm Strum (Hit / Glow animation)
        animation.addByPrefix("confirm", '$dirName confirm', 24, false);
        if (animation.getByName("confirm") == null) animation.addByPrefix("confirm", '$colorName confirm', 24, false);
        if (animation.getByName("confirm") == null) animation.addByPrefix("confirm", '$dirName note confirm', 24, false);
        if (animation.getByName("confirm") == null) animation.addByPrefix("confirm", '$dirUpper confirm', 24, false);
    }

    public function playAnim(animName:String, force:Bool = false):Void {
        if (animation.getByName(animName) == null) {
            setupAnimations();
        }

        if (animation.getByName(animName) != null) {
            animation.play(animName, force);
        }

        scale.set(skinScale, skinScale);
        updateHitbox();

        // Exact anchor compensation so confirming and pressing stays centered on the lane
        offset.x += (frameWidth * skinScale - STRUM_SIZE) * 0.5;
        offset.y += (frameHeight * skinScale - STRUM_SIZE) * 0.5;
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