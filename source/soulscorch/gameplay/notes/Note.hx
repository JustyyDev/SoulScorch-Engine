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

typedef NoteTypeConfig = {
    var hitHealth:Float;
    var missHealth:Float;
    var playSingAnim:Bool;
    var causesMiss:Bool;
    var ignoreNote:Bool;
    var noteSplashes:Bool;
    var color:FlxColor;
    var ?texture:String;
}

class Note extends FlxSprite {
    private static inline var SUSTAIN_OVERLAP:Float = 2.0;

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

    private var sustainClipRect:FlxRect = new FlxRect();
    private var lastSustainSpeed:Float = -1.0;
    private static var _noteTypeCache:Map<String, NoteTypeConfig> = new Map<String, NoteTypeConfig>();

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
        this.noteData = NoteSkinManager.normalizeLane(noteData);
        this.sustainLength = Math.max(0, sustainLength);
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
        if (atlas == null) atlas = Paths.getSparrowAtlas("ui/game/notes/default");
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
        var cacheKey = cleanType.toLowerCase();

        if (!_noteTypeCache.exists(cacheKey)) {
            _noteTypeCache.set(cacheKey, loadNoteTypeConfig(cleanType));
        }

        var conf = _noteTypeCache.get(cacheKey);
        hitHealth = conf.hitHealth;
        missHealth = conf.missHealth;
        playSingAnim = conf.playSingAnim;
        causesMiss = conf.causesMiss;
        ignoreNote = conf.ignoreNote;
        noteSplashes = conf.noteSplashes;
        color = conf.color;

        if (conf.texture != null && conf.texture.length > 0 && conf.texture != skinName) {
            this.skinName = conf.texture;
            loadNoteSkin(conf.texture);
        }
    }

    private static function loadNoteTypeConfig(cleanType:String):NoteTypeConfig {
        var access:Access = XMSoul.parse('data/notes/$cleanType', true, false);
        if (access == null) access = XMSoul.parse('notes/$cleanType', true, false);

        if (access != null) {
            var customTexture = XMSoul.getAttr(access, "texture", "NOTE_assets");
            return {
                hitHealth: XMSoul.getFloatAttr(access, "hitHealth", 0.023),
                missHealth: XMSoul.getFloatAttr(access, "missDamage", XMSoul.getFloatAttr(access, "missHealth", 0.0475)),
                playSingAnim: XMSoul.getBoolAttr(access, "playSingAnim", true),
                causesMiss: XMSoul.getBoolAttr(access, "causesMiss", false),
                ignoreNote: XMSoul.getBoolAttr(access, "ignore", XMSoul.getBoolAttr(access, "ignoreNote", false)),
                noteSplashes: XMSoul.getBoolAttr(access, "noteSplashes", true),
                color: FlxColor.WHITE,
                texture: (customTexture != "NOTE_assets" && customTexture != "default") ? customTexture : null
            };
        }

        return switch (cleanType.toLowerCase()) {
            case "hurt note", "hurt":
                {hitHealth: -0.15, missHealth: 0.2, playSingAnim: true, causesMiss: true, ignoreNote: false, noteSplashes: true, color: 0xFF444444};
            case "mine":
                {hitHealth: -0.35, missHealth: 0.0, playSingAnim: true, causesMiss: false, ignoreNote: true, noteSplashes: false, color: 0xFFFF0055};
            case "instakill":
                {hitHealth: 0.023, missHealth: 2.0, playSingAnim: true, causesMiss: false, ignoreNote: false, noteSplashes: true, color: 0xFFFF0000};
            case "noanim":
                {hitHealth: 0.023, missHealth: 0.0475, playSingAnim: false, causesMiss: false, ignoreNote: false, noteSplashes: true, color: FlxColor.WHITE};
            default:
                {hitHealth: 0.023, missHealth: 0.0475, playSingAnim: true, causesMiss: false, ignoreNote: false, noteSplashes: true, color: FlxColor.WHITE};
        };
    }

    private function setupAnimation(?conf:NoteSkinConfig):Void {
        if (frames == null || frames.frames == null || frames.frames.length == 0) return;

        animation.destroyAnimations();
        var lane = NoteSkinManager.normalizeLane(noteData);
        var colorName = NoteSkinManager.noteColors[lane];

        if (isSustainNote) {
            if (isSustainEnd) {
                var holdConf = conf != null ? conf.holdAnims.get(lane) : null;
                var endPrefixes = [
                    holdConf != null ? holdConf.endAnim : "",
                    (noteData == 0 ? "purple hold end" : colorName + " hold end"),
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
                var holdConf = conf != null ? conf.holdAnims.get(lane) : null;
                var bodyPrefixes = [
                    holdConf != null ? holdConf.bodyAnim : "",
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
            var tapAnim = conf != null ? conf.tapAnims.get(lane) : null;
            var tapPrefixes = [
                tapAnim != null ? tapAnim : "",
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

    public function playAnim(?songSpeed:Float = 1.0):Void {
        if (isSustainNote) {
            if (isSustainEnd) {
                if (animation.getByName("holdend") == null) setupAnimation();
                if (animation.getByName("holdend") != null) animation.play("holdend");
                resizeSustainEnd(songSpeed);
            } else {
                if (animation.getByName("hold") == null) setupAnimation();
                if (animation.getByName("hold") != null) animation.play("hold");
                resizeSustainBody(songSpeed);
            }
        } else {
            if (animation.getByName("scroll") == null) setupAnimation();
            if (animation.getByName("scroll") != null) animation.play("scroll");
            scale.set(skinScale, skinScale);
            updateHitbox();
        }
    }

    private function resizeSustainBody(songSpeed:Float):Void {
        var stepHeight:Float = Conductor.stepCrochet * 0.45 * songSpeed * multSpeed;
        var baseHeight:Float = (frameHeight > 0) ? frameHeight : 44.0;
        scale.set(skinScale, (stepHeight + SUSTAIN_OVERLAP) / baseHeight);
        updateHitbox();
        lastSustainSpeed = songSpeed * multSpeed;
    }

    private function resizeSustainEnd(songSpeed:Float):Void {
        scale.set(skinScale, skinScale);
        updateHitbox();
        lastSustainSpeed = songSpeed * multSpeed;
    }

    public function updatePosition(strumX:Float, strumY:Float, songSpeed:Float, downscroll:Bool, ?strumWidth:Float):Void {
        var currentSpeed:Float = songSpeed * multSpeed;
        var distance:Float = (strumTime - Conductor.songPosition) * (0.45 * currentSpeed);
        var laneWidth:Float = (strumWidth != null && strumWidth > 0) ? strumWidth : StrumArrow.STRUM_SIZE;

        if (isSustainNote && lastSustainSpeed != currentSpeed) {
            if (isSustainEnd) resizeSustainEnd(songSpeed); else resizeSustainBody(songSpeed);
        }

        x = strumX + ((laneWidth - width) * 0.5) + offsetX;

        if (isSustainNote) {
            flipY = downscroll;

            if (downscroll) {
                y = strumY + (StrumArrow.STRUM_SIZE * 0.5) - distance + offsetY;
            } else {
                y = strumY + (StrumArrow.STRUM_SIZE * 0.5) + distance - height + offsetY;
            }

            if (parent != null && parent.wasGoodHit && strumTime <= Conductor.songPosition + Conductor.stepCrochet) {
                var strumCenterY = strumY + (StrumArrow.STRUM_SIZE * 0.5);
                if (downscroll) {
                    var clipHeight:Float = FlxMath.bound((strumCenterY - y) / scale.y, 0, frameHeight);
                    sustainClipRect.set(0, 0, frameWidth, clipHeight);
                } else {
                    var clipTop:Float = FlxMath.bound((strumCenterY - y) / scale.y, 0, frameHeight);
                    sustainClipRect.set(0, clipTop, frameWidth, frameHeight - clipTop);
                }
                clipRect = sustainClipRect;
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