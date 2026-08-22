package soulscorch.gameplay.notes;

import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.util.FlxColor;
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

    public function new(x:Float, y:Float, direction:Int, isPlayer:Bool = false, downscroll:Bool = false, ?skin:String = "NOTE_assets") {
        super(x, y);
        this.direction = direction % 4;
        this.isPlayer = isPlayer;
        this.downscroll = downscroll;
        this.baseX = x;
        this.baseY = y;
        this.currentSkin = (skin != null && skin.trim().length > 0) ? skin.trim() : "NOTE_assets";

        var skinConf = NoteSkinManager.getSkinConfig(this.currentSkin);
        this.skinScale = (skinConf != null && skinConf.scale > 0) ? skinConf.scale : 0.7;

        loadReceptorSkin(this.currentSkin);
        setupAnimations(skinConf);

        antialiasing = (skinConf != null) ? skinConf.antialiasing : true;
        scrollFactor.set(0, 0);

        scale.set(skinScale, skinScale);
        updateHitbox();

        playAnim("static", true);
    }

    public function loadReceptorSkin(skin:String = "NOTE_assets"):Void {
        this.currentSkin = skin;
        var atlas:FlxAtlasFrames = NoteSkinManager.getSkinAtlas(skin);
        if (atlas != null) {
            frames = atlas;
        } else {
            makeGraphic(Std.int(STRUM_SIZE), Std.int(STRUM_SIZE), NoteSkinManager.getLaneColor(this.direction));
        }
    }

    public function setupAnimations(?conf:NoteSkinConfig):Void {
        if (frames == null || frames.frames == null || frames.frames.length == 0) return;

        var dirName = switch (direction % 4) {
            case 0: "left";
            case 1: "down";
            case 2: "up";
            case 3: "right";
            default: "left";
        };
        var dirUpper = dirName.toUpperCase();
        var colorName = NoteSkinManager.noteColors[direction % 4];

        // 1. Static Receptor Prefix
        animation.addByPrefix("static", 'arrow$dirUpper', 24, false);
        if (animation.getByName("static") == null) {
            animation.addByPrefix("static", 'arrow $dirUpper', 24, false);
        }
        if (animation.getByName("static") == null) {
            animation.addByPrefix("static", '$dirName static', 24, false);
        }

        // 2. Pressed Receptor Prefix
        animation.addByPrefix("pressed", '$dirName press', 24, false);
        if (animation.getByName("pressed") == null) {
            animation.addByPrefix("pressed", '$colorName press', 24, false);
        }
        if (animation.getByName("pressed") == null) {
            animation.addByPrefix("pressed", '$dirName note press', 24, false);
        }

        // 3. Confirm (Hit) Receptor Prefix
        animation.addByPrefix("confirm", '$dirName confirm', 24, false);
        if (animation.getByName("confirm") == null) {
            animation.addByPrefix("confirm", '$colorName confirm', 24, false);
        }
        if (animation.getByName("confirm") == null) {
            animation.addByPrefix("confirm", '$dirName note confirm', 24, false);
        }
    }

    public function playAnim(animName:String, force:Bool = false):Void {
        if (animation.getByName(animName) == null) return;

        animation.play(animName, force);
        scale.set(skinScale, skinScale);
        updateHitbox();

        // Exact center alignment offset compensation for confirm/press frames
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