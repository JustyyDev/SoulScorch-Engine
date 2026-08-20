package soulscorch.gameplay.notes;

import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;

using StringTools;

class StrumArrow extends FlxSprite {
    public var direction:Int = 0;
    public var resetAnim:Float = 0.0;
    public var isPlayer:Bool = false;
    public var downscroll:Bool = false;

    public var baseX:Float = 0.0;
    public var baseY:Float = 0.0;
    public var baseScale:Float = 0.7;

    public function new(x:Float, y:Float, direction:Int, isPlayer:Bool = false, downscroll:Bool = false, ?skin:String = "NOTE_assets") {
        super(x, y);
        this.direction = direction % 4;
        this.isPlayer = isPlayer;
        this.downscroll = downscroll;
        this.baseX = x;
        this.baseY = y;

        var conf = NoteSkinManager.getSkinConfig(skin);
        this.baseScale = conf.scale;

        loadReceptorSkin(skin);
        setupAnimations();

        antialiasing = conf.antialiasing;
        scrollFactor.set(0, 0);

        scale.set(baseScale, baseScale);
        updateHitbox();

        playAnim("static");
    }

    public function loadReceptorSkin(skin:String = "NOTE_assets"):Void {
        var atlas:FlxAtlasFrames = NoteSkinManager.getSkinAtlas(skin);
        var conf = NoteSkinManager.getSkinConfig(skin);

        if (atlas != null) {
            frames = atlas;
        } else {
            var colorInt:FlxColor = switch (direction) {
                case 0: 0xFFC24B99;
                case 1: 0xFF00FFFF;
                case 2: 0xFF12FA05;
                case 3: 0xFFF9393F;
                default: 0xFFFFFFFF;
            };
            makeGraphic(Std.int(112 * baseScale), Std.int(112 * baseScale), colorInt);
        }
    }

    private function setupAnimations():Void {
        if (frames == null || frames.frames == null || frames.frames.length == 0) return;

        var conf = NoteSkinManager.getSkinConfig();
        var strumConf = conf.strumAnims.get(direction % 4);

        var staticName = (strumConf != null) ? strumConf.staticAnim : 'arrow' + NoteSkinManager.noteDirections[direction].toUpperCase();
        var pressName  = (strumConf != null) ? strumConf.pressedAnim : NoteSkinManager.noteDirections[direction] + ' press';
        var confName   = (strumConf != null) ? strumConf.confirmAnim : NoteSkinManager.noteDirections[direction] + ' confirm';

        tryAddAnim("static", [staticName, staticName.replace(" ", ""), staticName + "0000"], 24, false);
        tryAddAnim("pressed", [pressName, pressName.replace(" ", ""), pressName + "0000"], 24, false);
        tryAddAnim("confirm", [confName, confName.replace(" ", ""), confName + "0000"], 24, false);
    }

    private function tryAddAnim(animName:String, prefixes:Array<String>, fps:Int = 24, loop:Bool = false):Bool {
        if (frames == null || frames.frames == null) return false;

        for (prefix in prefixes) {
            var prefixLower = prefix.toLowerCase().trim();
            for (f in frames.frames) {
                if (f.name != null && f.name.toLowerCase().startsWith(prefixLower)) {
                    animation.addByPrefix(animName, prefix, fps, loop);
                    return true;
                }
            }
        }
        return false;
    }

    public function playAnim(animName:String, force:Bool = false):Void {
        if (animation.getByName(animName) == null) return;

        animation.play(animName, force);
        centerOffsets();
        centerOrigin();

        if (animName == "confirm") {
            offset.x += (frameWidth * scale.x - 112 * baseScale) * 0.5;
            offset.y += (frameHeight * scale.y - 112 * baseScale) * 0.5;
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