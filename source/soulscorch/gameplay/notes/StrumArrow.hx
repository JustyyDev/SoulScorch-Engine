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
            makeGraphic(Std.int(STRUM_SIZE), Std.int(STRUM_SIZE), 0xFFFFFFFF);
        }
    }

    public function setupAnimations(?conf:NoteSkinConfig):Void {
        if (frames == null || frames.frames == null || frames.frames.length == 0) return;

        var dirName = NoteSkinManager.noteDirections[direction % 4];
        var dirUpper = dirName.toUpperCase();

        var animConf = (conf != null && conf.strumAnims.exists(direction)) ? conf.strumAnims.get(direction) : null;

        var staticPrefix = (animConf != null) ? animConf.staticAnim : 'arrow' + dirUpper;
        var pressPrefix = (animConf != null) ? animConf.pressedAnim : dirName + ' press';
        var confirmPrefix = (animConf != null) ? animConf.confirmAnim : dirName + ' confirm';

        animation.addByPrefix("static", staticPrefix, 24, false);
        if (animation.getByName("static") == null) {
            animation.addByPrefix("static", 'arrow' + dirUpper, 24, false);
        }

        animation.addByPrefix("pressed", pressPrefix, 24, false);
        if (animation.getByName("pressed") == null) {
            animation.addByPrefix("pressed", dirName + ' press', 24, false);
        }

        animation.addByPrefix("confirm", confirmPrefix, 24, false);
        if (animation.getByName("confirm") == null) {
            animation.addByPrefix("confirm", dirName + ' confirm', 24, false);
        }
    }

    public function playAnim(animName:String, force:Bool = false):Void {
        if (animation.getByName(animName) == null) return;

        animation.play(animName, force);
        scale.set(skinScale, skinScale);
        updateHitbox();

        if (animName == "confirm") {
            centerOffsets();
            offset.x -= 13;
            offset.y -= 13;
        } else if (animName == "pressed") {
            centerOffsets();
            offset.x -= 2;
            offset.y -= 2;
        } else {
            centerOffsets();
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