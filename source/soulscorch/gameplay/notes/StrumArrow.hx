package soulscorch.gameplay.notes;

import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
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

    public static inline var STRUM_SIZE:Float = 112.0 * 0.7;

    public function new(x:Float, y:Float, direction:Int, isPlayer:Bool = false, downscroll:Bool = false, ?skin:String = "NOTE_assets") {
        super(x, y);
        this.direction = direction % 4;
        this.isPlayer = isPlayer;
        this.downscroll = downscroll;
        this.baseX = x;
        this.baseY = y;
        this.baseScale = 0.7;

        loadReceptorSkin(skin);
        setupAnimations();

        antialiasing = true;
        scrollFactor.set(0, 0);

        scale.set(baseScale, baseScale);
        updateHitbox();

        playAnim("static");
    }

    public function loadReceptorSkin(skin:String = "NOTE_assets"):Void {
        var atlas:FlxAtlasFrames = NoteSkinManager.getSkinAtlas(skin);
        if (atlas != null) {
            frames = atlas;
        } else {
            makeGraphic(Std.int(STRUM_SIZE), Std.int(STRUM_SIZE), 0xFFFFFFFF);
        }
    }

    private function setupAnimations():Void {
        if (frames == null || frames.frames == null || frames.frames.length == 0) return;

        var dirName = NoteSkinManager.noteDirections[direction % 4];

        tryAddAnim("static", ['arrow' + dirName.toUpperCase(), 'arrow ' + dirName.toUpperCase()]);
        tryAddAnim("pressed", [dirName + ' press', dirName + 'press']);
        tryAddAnim("confirm", [dirName + ' confirm', dirName + 'confirm']);
    }

    private function tryAddAnim(animName:String, prefixes:Array<String>):Bool {
        for (prefix in prefixes) {
            var prefixLower = prefix.toLowerCase().trim();
            for (f in frames.frames) {
                if (f.name != null && f.name.toLowerCase().startsWith(prefixLower)) {
                    animation.addByPrefix(animName, f.name.substr(0, prefix.length), 24, false);
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