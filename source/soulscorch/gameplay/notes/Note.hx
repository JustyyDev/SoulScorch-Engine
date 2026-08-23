package soulscorch.gameplay.notes;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.math.FlxMath;
import flixel.math.FlxRect;
import flixel.util.FlxColor;
import haxe.xml.Access;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.system.XMSoul;
import soulscorch.gameplay.notes.NoteSkinManager;

using StringTools;

class Note extends FlxSprite {
    public var strumTime:Float = 0.0;
    public var noteData:Int = 0;
    public var sustainLength:Float = 0.0;
    public var isSustainNote:Bool = false;
    public var isSustainEnd:Bool = false;
    public var mustPress:Bool = false;
    public var noteType:String = "normal";
    public var skinName:String = "default";

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
    public var skinScale:Float = 0.7;

    private static var _sharedClipRect:FlxRect = new FlxRect();

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
        skin:String = "default"
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
        this.skinName = (skin != null && skin.trim().length > 0) ? skin.trim() : "default";

        var skinConf = NoteSkinManager.getSkinConfig(this.skinName);
        this.skinScale = (skinConf != null && skinConf.scale > 0) ? skinConf.scale : DEFAULT_SCALE;

        loadNoteSkin(this.skinName);
        applyColorTint();
        applyNoteTypeConfig(this.noteType);

        antialiasing = (skinConf != null) ? skinConf.antialiasing : true;
        scrollFactor.set(0, 0);

        if (isSustainNote) {
            alpha = (skinConf != null) ? skinConf.sustainAlpha : 0.6;
            multAlpha = alpha;
        }

        playAnim();
    }

    public function applyColorTint():Void {
        this.color = FlxColor.WHITE;
    }

    public function loadNoteSkin(skin:String = "default"):Void {
        var skinConf = NoteSkinManager.getSkinConfig(skin);
        var atlas:FlxAtlasFrames = NoteSkinManager.getSkinAtlas(skin);
        if (atlas == null) atlas = Paths.getSparrowAtlas("ui/game/notes/NOTE_assets");
        if (atlas == null) atlas = Paths.getSparrowAtlas("NOTE_assets");

        if (atlas != null) {
            frames = atlas;
            setupAnimation(skinConf);
        } else {
            makeGraphic(Std.int(STRUM_WIDTH), isSustainNote ? 30 : Std.int(STRUM_WIDTH), NoteSkinManager.getLaneColor(this.noteData));
        }
    }

    public function applyNoteTypeConfig(typeId:String):Void {
        var cleanType = (typeId == null || typeId.trim().length == 0) ? "normal" : typeId.trim();

        var access:Access = XMSoul.parse('data/notes/$cleanType', true, false);
        if (access == null) access = XMSoul.parse('notes/$cleanType', true, false);

        if (access != null) {
            hitHealth = XMSoul.getFloatAttr(access, "hitHealth", 0.023);
            missHealth = XMSoul.getFloatAttr(access, "missDamage", XMSoul.getFloatAttr(access, "missHealth", 0.0475));
            playSingAnim = XMSoul.getBoolAttr(access, "playSingAnim", true);
            causesMiss = XMSoul.getBoolAttr(access, "causesMiss", false);
            noteSplashes = XMSoul.getBoolAttr(access, "noteSplashes", true);

            var customTexture = XMSoul.getAttr(access, "texture", "NOTE_assets");
            if (customTexture != "NOTE_assets" && customTexture != "default") {
                this.skinName = customTexture;
                loadNoteSkin(customTexture);
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

    private function setupAnimation(?conf:NoteSkinConfig):Void {
        if (frames == null || frames.frames == null || frames.frames.length == 0) return;

        animation.destroyAnimations();
        var colorName = NoteSkinManager.noteColors[noteData % 4];

        if (isSustainNote) {
            if (isSustainEnd) {
                var endPrefixes = [
                    (noteData == 0 ? "pruple end hold" : colorName + " hold end"),
                    colorName + " hold end",
                    colorName + " tail",
                    colorName + " hold piece"
                ];
                for (p in endPrefixes) {
                    animation.addByPrefix("holdend", p, 24, false);
                    if (animation.getByName("holdend") != null) break;
                }
            } else {
                var bodyPrefixes = [
                    colorName + " hold piece",
                    colorName + " hold",
                    colorName + " piece"
                ];
                for (p in bodyPrefixes) {
                    animation.addByPrefix("hold", p, 24, false);
                    if (animation.getByName("hold") != null) break;
                }
            }
        } else {
            var tapPrefixes = [
                colorName + "0",
                colorName,
                colorName + " note",
                colorName + " tap"
            ];
            for (p in tapPrefixes) {
                animation.addByPrefix("scroll", p, 24, false);
                if (animation.getByName("scroll") != null) break;
            }
        }
    }

    public function playAnim(?songSpeed:Float = 2.0):Void {
        if (isSustainNote) {
            if (isSustainEnd) {
                if (animation.getByName("holdend") == null) setupAnimation();
                if (animation.getByName("holdend") != null) animation.play("holdend");
                scale.set(skinScale, skinScale);
                updateHitbox();
                
                // Align tail smoothly based on resolution space to avoid clipping
                if (animation.curAnim != null && animation.curAnim.name.endsWith("end")) {
                    centerOrigin();
                    offset.y += 1.0; 
                }
            } else {
                if (animation.getByName("hold") == null) setupAnimation();
                if (animation.getByName("hold") != null) animation.play("hold");
                var stepHeight:Float = (Conductor.stepCrochet * 0.45 * (songSpeed * multSpeed));
                var baseH:Float = (frameHeight > 0) ? frameHeight : 44.0;
                
                // FIXED: Changed overlapping padding from + 2.0 to + 0.5 to stop the body from bleeding over the tail
                scale.set(skinScale, (stepHeight + 0.5) / baseH); 
                updateHitbox();
            }
        } else {
            if (animation.getByName("scroll") == null) setupAnimation();
            if (animation.getByName("scroll") != null) animation.play("scroll");
            scale.set(skinScale, skinScale);
            updateHitbox();
        }
    }

    public function updatePosition(strumX:Float, strumY:Float, songSpeed:Float, downscroll:Bool):Void {
        var currentSpeed:Float = songSpeed * multSpeed;
        var distance:Float = (strumTime - Conductor.songPosition) * (0.45 * currentSpeed);
        var stepHeight:Float = (Conductor.stepCrochet * 0.45 * currentSpeed);

        x = strumX + ((StrumArrow.STRUM_SIZE - width) * 0.5) + offsetX;

        if (isSustainNote) {
            flipY = downscroll;

            if (downscroll) {
                y = strumY + (StrumArrow.STRUM_SIZE * 0.5) - distance - height + stepHeight + offsetY;
                // Nudge downscroll flipped tails exactly onto the body line
                if (isSustainEnd) {
                    y += 1.5; 
                }
            } else {
                y = strumY + (StrumArrow.STRUM_SIZE * 0.5) + distance - stepHeight + offsetY;
            }

            if (parent != null && parent.wasGoodHit && strumTime <= Conductor.songPosition + Conductor.stepCrochet) {
                var strumCenterY = strumY + (StrumArrow.STRUM_SIZE * 0.5);
                if (downscroll) {
                    var clipHeight:Float = Math.max(0, (strumCenterY - y) / scale.y);
                    _sharedClipRect.set(0, 0, frameWidth, clipHeight);
                    clipRect = _sharedClipRect;
                } else {
                    var clipHeight:Float = Math.max(0, (y + height - strumCenterY) / scale.y);
                    _sharedClipRect.set(0, frameHeight - clipHeight, frameWidth, clipHeight);
                    clipRect = _sharedClipRect;
                }
            } else {
                clipRect = null;
            }
        } else {
            if (downscroll) {
                y = strumY + (StrumArrow.STRUM_SIZE * 0.5) - distance - (height * 0.5) + offsetY;
            } else {
                y = strumY + (StrumArrow.STRUM_SIZE * 0.5) + distance - (height * 0.5) + offsetY;
            }
        }

        canBeHit = (strumTime > Conductor.songPosition - (Conductor.safeZoneOffset * 1.5)
            && strumTime < Conductor.songPosition + (Conductor.safeZoneOffset * 0.5));

        if (strumTime < Conductor.songPosition - Conductor.safeZoneOffset && !wasGoodHit) {
            tooLate = true;
        }
    }
}