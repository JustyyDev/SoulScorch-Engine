package soulscorch.gameplay.notes;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.math.FlxMath;
import flixel.math.FlxRect;
import flixel.util.FlxColor;
import haxe.xml.Access;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.system.XMSoul;

using StringTools;

class Note extends FlxSprite {
    public var strumTime:Float = 0.0;
    public var noteData:Int = 0;
    public var sustainLength:Float = 0.0;
    public var isSustainNote:Bool = false;
    public var isSustainEnd:Bool = false;
    public var mustPress:Bool = false;
    public var noteType:String = "normal";

    public var parent:Note = null;
    public var tail:Array<Note> = [];

    public var canBeHit:Bool = false;
    public var tooLate:Bool = false;
    public var wasGoodHit:Bool = false;
    public var hitByOpponent:Bool = false;
    public var ignoreNote:Bool = false;
    public var causesMiss:Bool = false;
    public var playSingAnim:Bool = true;
    public var noteSplashes:Bool = true;

    public var hitHealth:Float = 0.023;
    public var missHealth:Float = 0.0475;

    public var offsetX:Float = 0.0;
    public var offsetY:Float = 0.0;
    public var multAlpha:Float = 1.0;
    public var multSpeed:Float = 1.0;
    public var copyAngle:Bool = true;
    public var copyAlpha:Bool = true;

    public static inline var DEFAULT_SCALE:Float = 0.7;
    public static inline var STRUM_WIDTH:Float = 112.0 * DEFAULT_SCALE;

    public function new(
        strumTime:Float,
        noteData:Int,
        sustainLength:Float = 0,
        ?parent:Note = null,
        isSustainNote:Bool = false,
        isSustainEnd:Bool = false,
        mustPress:Bool = true,
        noteType:String = "normal",
        skin:String = "NOTE_assets"
    ) {
        super();

        this.strumTime = strumTime;
        this.noteData = noteData % 4;
        this.sustainLength = sustainLength;
        this.parent = parent;
        this.isSustainNote = isSustainNote;
        this.isSustainEnd = isSustainEnd;
        this.mustPress = mustPress;
        this.noteType = (noteType != null && noteType.trim().length > 0) ? noteType.trim() : "normal";

        loadNoteSkin(skin);
        setupAnimation();
        applyNoteTypeConfig(this.noteType);

        antialiasing = true;
        scrollFactor.set(0, 0);

        if (isSustainNote) {
            alpha = 0.6;
            multAlpha = 0.6;
        }

        playAnim();
    }

    public function loadNoteSkin(skin:String = "NOTE_assets"):Void {
        var atlas:FlxAtlasFrames = NoteSkinManager.getSkinAtlas(skin);
        if (atlas != null) {
            frames = atlas;
        } else {
            var colorInt:FlxColor = switch (noteData % 4) {
                case 0: 0xFFC24B99;
                case 1: 0xFF00FFFF;
                case 2: 0xFF12FA05;
                case 3: 0xFFF9393F;
                default: 0xFFFFFFFF;
            };
            makeGraphic(Std.int(STRUM_WIDTH), isSustainNote ? 30 : Std.int(STRUM_WIDTH), colorInt);
        }
    }

    public function applyNoteTypeConfig(typeId:String):Void {
        var cleanType = (typeId == null || typeId.trim().length == 0) ? "normal" : typeId.trim();

        var access:Access = XMSoul.parse('data/notes/$cleanType');
        if (access == null) access = XMSoul.parse('notes/$cleanType');
        if (access == null) access = XMSoul.parse('data/config/notes/$cleanType');

        if (access != null) {
            hitHealth = XMSoul.getFloatAttr(access, "hitHealth", 0.023);
            missHealth = XMSoul.getFloatAttr(access, "missDamage", XMSoul.getFloatAttr(access, "missHealth", 0.0475));
            playSingAnim = XMSoul.getBoolAttr(access, "playSingAnim", true);
            causesMiss = XMSoul.getBoolAttr(access, "causesMiss", false);
            noteSplashes = XMSoul.getBoolAttr(access, "noteSplashes", true);

            var customTexture = XMSoul.getAttr(access, "texture", "NOTE_assets");
            if (customTexture != "NOTE_assets" && customTexture != "default") {
                loadNoteSkin(customTexture);
                setupAnimation();
            }
            return;
        }

        switch (cleanType.toLowerCase()) {
            case "hurt note", "hurt":
                color = 0xFF444444;
                missHealth = 0.2;
                hitHealth = -0.15;
                causesMiss = true;
            case "mine":
                color = 0xFFFF0055;
                ignoreNote = true;
                missHealth = 0.0;
                hitHealth = -0.35;
            case "instakill":
                color = 0xFFFF0000;
                missHealth = 2.0;
            case "noanim":
                playSingAnim = false;
        }
    }

    private function setupAnimation():Void {
        if (frames == null || frames.frames == null || frames.frames.length == 0) return;

        var colorName = NoteSkinManager.noteColors[noteData % 4];

        if (isSustainNote) {
            if (isSustainEnd) {
                var endPrefix = (noteData == 0) ? "pruple end hold" : (colorName + " hold end");
                tryAddAnimation("holdend", [endPrefix, "purple hold end", colorName + " end hold", colorName + " hold end"]);
            } else {
                var bodyPrefix = (noteData == 0) ? "purple hold piece" : (colorName + " hold piece");
                tryAddAnimation("hold", [bodyPrefix, colorName + " hold piece", colorName + " piece"]);
            }
        } else {
            tryAddAnimation("scroll", [colorName + "0", colorName + " scroll", colorName]);
        }
    }

    private function tryAddAnimation(animName:String, prefixes:Array<String>):Bool {
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

    public function playAnim(?songSpeed:Float = 2.0):Void {
        scale.set(DEFAULT_SCALE, DEFAULT_SCALE);
        updateHitbox();

        if (isSustainNote) {
            if (isSustainEnd) {
                if (animation.getByName("holdend") != null) animation.play("holdend");
                updateHitbox();
            } else {
                if (animation.getByName("hold") != null) animation.play("hold");
                var stepHeight:Float = (Conductor.stepCrochet * 0.45 * (songSpeed * multSpeed));
                var baseH:Float = (frameHeight > 0) ? frameHeight : 44.0;
                scale.set(DEFAULT_SCALE, (stepHeight + 1.5) / baseH);
                updateHitbox();
            }
        } else {
            if (animation.getByName("scroll") != null) animation.play("scroll");
            centerOffsets();
            centerOrigin();
        }
    }

    public function updatePosition(strumX:Float, strumY:Float, songSpeed:Float, downscroll:Bool):Void {
        var distance:Float = (strumTime - Conductor.songPosition) * (0.45 * (songSpeed * multSpeed));
        var stepHeight:Float = (Conductor.stepCrochet * 0.45 * (songSpeed * multSpeed));

        var strumCenterX:Float = strumX + (STRUM_WIDTH * 0.5);
        var strumCenterY:Float = strumY + (STRUM_WIDTH * 0.5);

        x = strumCenterX - (width * 0.5) + offsetX;

        if (isSustainNote) {
            flipY = downscroll;

            if (downscroll) {
                y = strumCenterY - distance + stepHeight - height + offsetY;
            } else {
                y = strumCenterY + distance - stepHeight + offsetY;
            }

            if (parent != null && parent.wasGoodHit && strumTime <= Conductor.songPosition + Conductor.stepCrochet) {
                if (downscroll) {
                    var clipHeight:Float = Math.max(0, (strumCenterY - y) / scale.y);
                    clipRect = new FlxRect(0, 0, frameWidth, clipHeight);
                } else {
                    var clipHeight:Float = Math.max(0, (y + height - strumCenterY) / scale.y);
                    clipRect = new FlxRect(0, frameHeight - clipHeight, frameWidth, clipHeight);
                }
            } else {
                clipRect = null;
            }
        } else {
            if (downscroll) {
                y = strumCenterY - distance - (height * 0.5) + offsetY;
            } else {
                y = strumCenterY + distance - (height * 0.5) + offsetY;
            }
        }

        canBeHit = (strumTime > Conductor.songPosition - (Conductor.safeZoneOffset * 1.5)
            && strumTime < Conductor.songPosition + (Conductor.safeZoneOffset * 0.5));

        if (strumTime < Conductor.songPosition - Conductor.safeZoneOffset && !wasGoodHit) {
            tooLate = true;
        }
    }
}