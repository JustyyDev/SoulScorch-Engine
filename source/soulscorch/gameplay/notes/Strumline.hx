package soulscorch.gameplay.notes;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;

using StringTools;

class StrumNote extends FlxSprite {
    public var direction:Int = 0;
    public var resetAnim:Float = 0.0;
    public var isPlayer:Bool = false;
    public var downscroll:Bool = false;

    public var animOffsets:Map<String, FlxPoint> = new Map<String, FlxPoint>();
    public var baseScale:Float = 0.7;

    public function new(x:Float, y:Float, direction:Int, isPlayer:Bool = false, downscroll:Bool = false, skin:String = "NOTE_assets") {
        super(x, y);
        this.direction = direction % 4;
        this.isPlayer = isPlayer;
        this.downscroll = downscroll;

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

        var dirName = NoteSkinManager.noteDirections[direction];
        var dirUpper = dirName.toUpperCase();

        // Static Receptor
        var staticPrefixes = [
            'arrow$dirUpper',
            'arrow $dirUpper',
            '$dirName static'
        ];
        tryAddAnim("static", staticPrefixes, 24, false);

        // Pressed Receptor
        var pressPrefixes = [
            '$dirName press',
            'arrow$dirUpper press'
        ];
        tryAddAnim("pressed", pressPrefixes, 24, false);

        // Confirm (Hit Glow Note)
        var confirmPrefixes = [
            '$dirName confirm',
            'arrow$dirUpper confirm'
        ];
        tryAddAnim("confirm", confirmPrefixes, 24, false);
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
            centerOffsets();
            offset.x -= 13;
            offset.y -= 13;
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

    override public function destroy():Void {
        for (pt in animOffsets) {
            pt.put();
        }
        animOffsets.clear();
        super.destroy();
    }
}

class Strumline extends FlxSpriteGroup {
    public var receptors:Array<StrumNote> = [];
    public var isPlayer:Bool = false;
    public var downscroll:Bool = false;

    public static inline var STRUM_SPACING:Float = 112.0;

    public function new(x:Float, y:Float, isPlayer:Bool = false, downscroll:Bool = false, skin:String = "NOTE_assets") {
        super(x, y);
        this.isPlayer = isPlayer;
        this.downscroll = downscroll;

        createReceptors(skin);
    }

    public function createReceptors(skin:String = "NOTE_assets"):Void {
        clearReceptors();

        for (i in 0...4) {
            var receptor = new StrumNote(i * STRUM_SPACING, 0, i, isPlayer, downscroll, skin);
            receptors.push(receptor);
            add(receptor);
        }
    }

    public function clearReceptors():Void {
        while (receptors.length > 0) {
            var r = receptors.pop();
            remove(r, true);
            r.destroy();
        }
    }

    public function playStrumAnim(dir:Int, animName:String, force:Bool = true):Void {
        if (dir >= 0 && dir < receptors.length && receptors[dir] != null) {
            receptors[dir].playAnim(animName, force);
        }
    }
}