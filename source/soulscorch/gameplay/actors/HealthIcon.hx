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

typedef IconProps = {
    var frameCount:Int;
    var normalFrame:Int;
    var losingFrame:Int;
    var winningFrame:Int;
    var targetSize:Float;
    var minScale:Float;
    var maxScale:Float;
    var antialiasing:Bool;
    var bopIntensity:Float;
    var bopSpeed:Float;
    var rotationBop:Float;
    var customOffsetX:Float;
    var customOffsetY:Float;
    var pulseOnLowHealth:Bool;
    var iconScale:Float;
};

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
    private var baseScale:Float = 1.0;

    // Custom Animation & Bop Properties
    public var bopIntensity:Float = 1.2;
    public var bopSpeed:Float = 12.0;
    public var rotationBop:Float = 4.0;
    public var customOffsetX:Float = 0.0;
    public var customOffsetY:Float = 0.0;
    public var pulseOnLowHealth:Bool = true;

    // Static caches: avoid repeated file I/O, XML parsing and asset lookups on changeIcon
    private static var _iconPropCache:Map<String, IconProps> = new Map();
    private static var _iconGraphicCache:Map<String, FlxGraphic> = new Map();
    private static inline var FALLBACK_ICON:String = "face";

    public static function clearCache():Void {
        _iconPropCache.clear();
        _iconGraphicCache.clear();
    }

    public function new(character:String = "face", isPlayer:Bool = false) {
        super();
        this.isPlayer = isPlayer;
        changeIcon(character);
        scrollFactor.set();
    }

    public function changeIcon(char:String):Void {
        var cleanChar = (char != null && char.trim().length > 0) ? char.trim().toLowerCase() : FALLBACK_ICON;
        if (cleanChar == "none") cleanChar = FALLBACK_ICON;
        this.character = cleanChar;

        bopIntensity = 1.2;
        bopSpeed = 12.0;
        rotationBop = 4.0;
        customOffsetX = 0.0;
        customOffsetY = 0.0;
        iconScale = 1.0;
        pulseOnLowHealth = true;

        // Cached XMSoul-derived properties (no file I/O / XML parsing on repeat)
        var props = _iconPropCache.get(cleanChar);
        if (props == null) {
            var iconConfig = loadIconXMSoul(cleanChar);
            if (iconConfig != null) {
                bopIntensity = iconConfig.bopIntensity;
                bopSpeed = iconConfig.bopSpeed;
                rotationBop = iconConfig.rotationBop;
                customOffsetX = iconConfig.offsetX;
                customOffsetY = iconConfig.offsetY;
                pulseOnLowHealth = iconConfig.pulseOnLowHealth;
                iconScale = FlxMath.bound(iconConfig.scale, iconConfig.minScale, iconConfig.maxScale);
            }
            props = {
                frameCount: iconConfig != null ? iconConfig.frameCount : 0,
                normalFrame: iconConfig != null ? iconConfig.normalFrame : 0,
                losingFrame: iconConfig != null ? iconConfig.losingFrame : 0,
                winningFrame: iconConfig != null ? iconConfig.winningFrame : 0,
                targetSize: iconConfig != null ? iconConfig.targetSize : 150.0,
                minScale: iconConfig != null ? iconConfig.minScale : 0.5,
                maxScale: iconConfig != null ? iconConfig.maxScale : 2.0,
                antialiasing: iconConfig != null ? iconConfig.antialiasing : true,
                bopIntensity: bopIntensity,
                bopSpeed: bopSpeed,
                rotationBop: rotationBop,
                customOffsetX: customOffsetX,
                customOffsetY: customOffsetY,
                pulseOnLowHealth: pulseOnLowHealth,
                iconScale: iconScale
            };
            _iconPropCache.set(cleanChar, props);
        } else {
            bopIntensity = props.bopIntensity;
            bopSpeed = props.bopSpeed;
            rotationBop = props.rotationBop;
            customOffsetX = props.customOffsetX;
            customOffsetY = props.customOffsetY;
            pulseOnLowHealth = props.pulseOnLowHealth;
            iconScale = props.iconScale;
        }

        // Cached resolved graphic (no repeated asset lookups on repeat)
        var graphic = _iconGraphicCache.get(cleanChar);
        if (graphic == null) {
            graphic = getIconGraphic(cleanChar);
            if (graphic == null) graphic = getIconGraphic(FALLBACK_ICON);
            if (graphic != null) _iconGraphicCache.set(cleanChar, graphic);
        }

        if (graphic != null) {
            var rawWidth = graphic.width;
            var rawHeight = graphic.height;
            var frameRatio = rawWidth / rawHeight;

            var frameCount = props != null ? props.frameCount : 0;
            if (frameCount <= 0 && frameRatio <= 1.4) {
                frameCount = 1;
                isSingleFrame = true;
                hasWinningFrame = false;
            } else if (frameCount <= 0 && frameRatio >= 2.6) {
                frameCount = 3;
                isSingleFrame = false;
                hasWinningFrame = true;
            } else if (frameCount <= 0) {
                frameCount = 2;
                isSingleFrame = false;
                hasWinningFrame = false;
            }
            frameCount = Std.int(Math.max(1, Math.min(frameCount, rawWidth)));
            isSingleFrame = frameCount == 1;
            hasWinningFrame = frameCount >= 3;

            var frameWidth = Std.int(rawWidth / frameCount);
            loadGraphic(graphic, frameCount > 1, frameWidth, rawHeight);

            if (isSingleFrame) {
                addIconAnimation("normal", 0, isPlayer);
                addIconAnimation("losing", 0, isPlayer);
                addIconAnimation("winning", 0, isPlayer);
            } else {
                var normalFrame = props != null ? props.normalFrame : 0;
                var losingFrame = props != null ? props.losingFrame : (frameCount >= 2 ? 1 : 0);
                var winningFrame = props != null ? props.winningFrame : (frameCount >= 3 ? 2 : 0);
                addIconAnimation("normal", clampFrame(normalFrame, frameCount), isPlayer);
                addIconAnimation("losing", clampFrame(losingFrame, frameCount), isPlayer);
                addIconAnimation("winning", clampFrame(winningFrame, frameCount), isPlayer);
            }

            var targetHeight = props != null ? props.targetSize : 150.0;
            if (targetHeight <= 0) targetHeight = 150.0;
            var targetWidth = (frameWidth / rawHeight) * targetHeight;
            setGraphicSize(Std.int(Math.max(1, targetWidth)), Std.int(Math.max(1, targetHeight)));
            baseScale = scale.x;
            scale.set(baseScale * iconScale, baseScale * iconScale);

            animation.play("normal");
            antialiasing = props != null ? props.antialiasing : (!cleanChar.endsWith("-pixel") && !cleanChar.startsWith("senpai") && !cleanChar.startsWith("spirit"));
            updateHitbox();
        } else {
            makeGraphic(150, 150, 0xFFFF0055);
            isSingleFrame = true;
            hasWinningFrame = false;
        }
    }

    private function loadIconXMSoul(char:String):Null<XMSoulIconConfig> {
        var paths = [
            'data/icons/$char',
            'data/characters/$char',
            'config/icons/$char',
            'icons/$char.xmsoul',
            'images/icons/$char.xmsoul',
            'data/icons/$char.xmsoul',
            'data/characters/$char.xmsoul',
            'assets/preload/data/icons/$char.xmsoul',
            'assets/preload/data/characters/$char.xmsoul',
            'assets/preload/icons/$char.xmsoul'
        ];

        for (path in paths) {
            var config = XMSoul.loadIconConfig(path);
            if (config != null) {
                try {
                    return config;
                } catch (e:Dynamic) {
                    Logger.warn('Failed parsing icon .xmsoul for $char: $e', "icon");
                }
            }
        }
        return null;
    }

    private function addIconAnimation(name:String, frame:Int, reverse:Bool):Void {
        animation.add(name, [frame], 0, false, reverse);
    }

    private static inline function clampFrame(frame:Int, frameCount:Int):Int {
        return Std.int(Math.max(0, Math.min(frame, frameCount - 1)));
    }

    private function getIconGraphic(char:String):Null<FlxGraphic> {
        var lookups = [
            'ui/game/icons/$char/icon',
            'ui/game/icons/icon-$char',
            'ui/game/icons/$char',
            'icons/icon-$char',
            'images/icons/icon-$char',
            'ui/icons/icon-$char',
            'icons/$char',
            'images/icons/$char',
            'icon-$char',
            'ui/icons/$char',
            'ui/game/icons/face/icon',
            'ui/game/icons/icon-face',
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
        var targetScale = baseScale * iconScale * bopIntensity;
        scale.set(targetScale, targetScale);
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
            FlxMath.lerp(scale.x, baseScale * iconScale, lerpFactor),
            FlxMath.lerp(scale.y, baseScale * iconScale, lerpFactor)
        );
        angle = FlxMath.lerp(angle, 0, lerpFactor);
    }
}