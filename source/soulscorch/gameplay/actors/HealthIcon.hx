package soulscorch.gameplay.actors;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.math.FlxMath;
import flixel.util.FlxColor;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.system.XMSoul;
import soulscorch.backend.utils.Logger;

using StringTools;

class HealthIcon extends FlxSprite {
    public var sprTracker:FlxSprite;
    public var isPlayer:Bool = false;
    public var isOldIcon:Bool = false;
    public var character:String = "face";

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

    // Custom Animation & Bop Properties
    public var bopIntensity:Float = 1.2;
    public var bopSpeed:Float = 12.0;
    public var rotationBop:Float = 4.0;
    public var customOffsetX:Float = 0.0;
    public var customOffsetY:Float = 0.0;
    public var pulseOnLowHealth:Bool = true;

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

        bopIntensity = 1.2;
        bopSpeed = 12.0;
        rotationBop = 4.0;
        customOffsetX = 0.0;
        customOffsetY = 0.0;
        iconScale = 1.0;

        loadIconXMSoul(cleanChar);

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

    private function loadIconXMSoul(char:String):Void {
        var paths = [
            'icons/$char.xmsoul',
            'images/icons/$char.xmsoul',
            'data/icons/$char.xmsoul',
            'assets/preload/icons/$char.xmsoul'
        ];

        for (path in paths) {
            var access = XMSoul.parse(path);
            if (access != null) {
                try {
                    bopIntensity = XMSoul.getFloatAttr(access, "bopIntensity", 1.2);
                    bopSpeed = XMSoul.getFloatAttr(access, "bopSpeed", 12.0);
                    rotationBop = XMSoul.getFloatAttr(access, "rotationBop", 4.0);
                    customOffsetX = XMSoul.getFloatAttr(access, "offsetX", 0.0);
                    customOffsetY = XMSoul.getFloatAttr(access, "offsetY", 0.0);
                    pulseOnLowHealth = XMSoul.getBoolAttr(access, "pulseOnLowHealth", true);
                    iconScale = XMSoul.getFloatAttr(access, "scale", 1.0);
                    break;
                } catch (e:Dynamic) {
                    Logger.warn('Failed parsing icon .xmsoul for $char: $e', "icon");
                }
            }
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
        scale.set(iconScale * bopIntensity, iconScale * bopIntensity);
        angle = (FlxG.random.bool(50) ? 1 : -1) * rotationBop;
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (sprTracker != null && autoUpdatePosition) {
            var sideOffset = isPlayer ? (10 + customOffsetX) : (-10 - customOffsetX);
            setPosition(sprTracker.x + sprTracker.width + sideOffset, sprTracker.y - 30 + customOffsetY);
        }

        var lerpFactor = FlxMath.bound(elapsed * bopSpeed, 0, 1);
        scale.set(
            FlxMath.lerp(scale.x, iconScale, lerpFactor),
            FlxMath.lerp(scale.y, iconScale, lerpFactor)
        );
        angle = FlxMath.lerp(angle, 0, lerpFactor);
    }
}