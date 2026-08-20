package soulscorch.gameplay.actors;

import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.math.FlxMath;
import flixel.util.FlxColor;
import soulscorch.backend.assets.AssetResolver;

using StringTools;

class HealthIcon extends FlxSprite {
    public var sprTracker:FlxSprite;
    public var isPlayer:Bool = false;
    public var isOldIcon:Bool = false;
    public var character:String = "face";

    // Backward-compatible alias for CharacterEditorState
    @:isVar public var char(get, set):String;
    inline function get_char():String return character;
    inline function set_char(val:String):String {
        changeIcon(val);
        return character;
    }

    public var isSingleFrame:Bool = false;
    public var hasWinningFrame:Bool = false;
    public var iconScale:Float = 1.0;
    public var autoUpdatePosition:Bool = true;

    public function new(character:String = "face", isPlayer:Bool = false) {
        super();
        this.isPlayer = isPlayer;
        changeIcon(character);
        scrollFactor.set();
    }

    public function changeIcon(char:String):Void {
        var cleanChar = (char != null && char.trim().length > 0) ? char.trim().toLowerCase() : "face";
        if (cleanChar == "none") cleanChar = "face";
        this.character = cleanChar;

        var graphic = getIconGraphic(cleanChar);
        if (graphic == null) {
            graphic = getIconGraphic("face");
        }

        if (graphic != null) {
            var rawWidth = graphic.width;
            var rawHeight = graphic.height;
            var frameRatio = rawWidth / rawHeight;

            if (frameRatio <= 1.4) {
                isSingleFrame = true;
                hasWinningFrame = false;
                loadGraphic(graphic, false, rawWidth, rawHeight);
                animation.add("normal", [0], 0, false, isPlayer);
                animation.add("losing", [0], 0, false, isPlayer);
                animation.add("winning", [0], 0, false, isPlayer);
            } else if (frameRatio >= 2.6) {
                isSingleFrame = false;
                hasWinningFrame = true;
                var frameWidth = Std.int(rawWidth / 3);
                loadGraphic(graphic, true, frameWidth, rawHeight);
                animation.add("winning", [0], 0, false, isPlayer);
                animation.add("normal", [1], 0, false, isPlayer);
                animation.add("losing", [2], 0, false, isPlayer);
            } else {
                isSingleFrame = false;
                hasWinningFrame = false;
                var frameWidth = Std.int(rawWidth / 2);
                loadGraphic(graphic, true, frameWidth, rawHeight);
                animation.add("normal", [0], 0, false, isPlayer);
                animation.add("losing", [1], 0, false, isPlayer);
                animation.add("winning", [0], 0, false, isPlayer);
            }

            animation.play("normal");
            antialiasing = !cleanChar.endsWith("-pixel") && !cleanChar.startsWith("senpai") && !cleanChar.startsWith("spirit");
            updateHitbox();
        } else {
            makeGraphic(150, 150, 0xFFFF0055);
            isSingleFrame = true;
            hasWinningFrame = false;
        }
    }

    private function getIconGraphic(char:String):Null<FlxGraphic> {
        var lookups = [
            'icons/icon-$char',
            'images/icons/icon-$char',
            'ui/icons/icon-$char',
            'icons/$char',
            'images/icons/$char',
            'icon-$char',
            'ui/icons/$char',
            'icons/icon-face',
            'images/icons/icon-face',
            'icon-face'
        ];

        for (path in lookups) {
            var graph = AssetResolver.getGraphic(path);
            if (graph != null) return graph;
        }
        return null;
    }

    public function updateHealth(healthPercent:Float):Void {
        if (isSingleFrame) {
            if (animation.curAnim == null || animation.curAnim.name != "normal") {
                animation.play("normal");
            }
            return;
        }

        if (healthPercent < 20.0) {
            if (animation.getByName("losing") != null) animation.play("losing");
        } else if (healthPercent > 80.0 && hasWinningFrame) {
            if (animation.getByName("winning") != null) animation.play("winning");
        } else {
            if (animation.getByName("normal") != null) animation.play("normal");
        }
    }

    public function beatHit(beat:Int):Void {
        scale.set(iconScale * 1.2, iconScale * 1.2);
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (sprTracker != null && autoUpdatePosition) {
            setPosition(sprTracker.x + sprTracker.width + 10, sprTracker.y - 30);
        }

        scale.set(
            FlxMath.lerp(scale.x, iconScale, FlxMath.bound(elapsed * 12.0, 0, 1)),
            FlxMath.lerp(scale.y, iconScale, FlxMath.bound(elapsed * 12.0, 0, 1))
        );
        updateHitbox();
    }
}