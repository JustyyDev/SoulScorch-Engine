package soulscorch.gameplay.notes;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.math.FlxMath;
import flixel.math.FlxRect;
import flixel.util.FlxColor;
import soulscorch.backend.audio.Conductor;

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

    public var offsetX:Float = 0.0;
    public var offsetY:Float = 0.0;
    public var multAlpha:Float = 1.0;
    public var multSpeed:Float = 1.0;

    public static inline var DEFAULT_SCALE:Float = 0.7;
    public static inline var STRUM_SPACING:Float = 112.0;

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
        this.noteType = (noteType != null && noteType.trim().length > 0) ? noteType : "normal";

        loadNoteSkin(skin);
        setupAnimation();

        antialiasing = true;
        scrollFactor.set(0, 0);

        if (isSustainNote) {
            alpha = 0.6;
            multAlpha = 0.6;
        }

        updateHitbox();
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
            makeGraphic(Std.int(112 * DEFAULT_SCALE), isSustainNote ? 40 : Std.int(112 * DEFAULT_SCALE), colorInt);
        }
    }

    private function setupAnimation():Void {
        if (frames == null || frames.frames == null || frames.frames.length == 0) return;

        var color = NoteSkinManager.noteColors[noteData];

        if (isSustainNote) {
            if (isSustainEnd) {
                var endPrefixes:Array<String> = switch (noteData) {
                    case 0: ["pruple end hold", "purple hold end", "purple end hold"];
                    case 1: ["blue hold end", "blue end hold"];
                    case 2: ["green hold end", "green end hold"];
                    case 3: ["red hold end", "red end hold"];
                    default: ['$color hold end', '$color end hold'];
                };
                tryAddAnimation("holdend", endPrefixes, 24, true);
            } else {
                var piecePrefixes = [
                    '$color hold piece',
                    '${color}0 hold piece',
                    '$color hold'
                ];
                tryAddAnimation("hold", piecePrefixes, 24, true);
            }
        } else {
            var scrollPrefixes = [
                '$color',
                '${color}0',
                '$color scroll'
            ];
            tryAddAnimation("scroll", scrollPrefixes, 24, true);
        }

        playAnim();
    }

    private function tryAddAnimation(animName:String, prefixes:Array<String>, fps:Int = 24, loop:Bool = true):Bool {
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

    public function playAnim():Void {
        if (isSustainNote) {
            if (isSustainEnd) {
                if (animation.getByName("holdend") != null) animation.play("holdend");
            } else {
                if (animation.getByName("hold") != null) animation.play("hold");
            }
        } else {
            if (animation.getByName("scroll") != null) animation.play("scroll");
        }

        scale.set(DEFAULT_SCALE, DEFAULT_SCALE);
        updateHitbox();
    }

    public function updatePosition(strumX:Float, strumY:Float, songSpeed:Float, downscroll:Bool):Void {
        var distance = (strumTime - Conductor.songPosition) * (0.45 * (songSpeed * multSpeed));

        x = strumX + offsetX;
        if (downscroll) {
            y = strumY + distance + offsetY;
        } else {
            y = strumY - distance + offsetY;
        }

        if (isSustainNote) {
            x += (STRUM_SPACING * DEFAULT_SCALE * 0.5) - (width * 0.5);

            if (downscroll) {
                flipY = true;
                y -= height * 0.5;
            } else {
                flipY = false;
            }

            // Clip active holds past the receptor line
            if (parent != null && parent.wasGoodHit && strumTime <= Conductor.songPosition) {
                var clipHeight:Float = (Conductor.songPosition - strumTime) * (0.45 * (songSpeed * multSpeed));
                if (clipHeight > 0) {
                    if (downscroll) {
                        clipRect = new FlxRect(0, 0, width / scale.x, Math.max(0, (height / scale.y) - (clipHeight / scale.y)));
                    } else {
                        clipRect = new FlxRect(0, clipHeight / scale.y, width / scale.x, (height / scale.y) - (clipHeight / scale.y));
                    }
                }
            }
        }

        canBeHit = (strumTime > Conductor.songPosition - (Conductor.safeZoneOffset * 1.5)
            && strumTime < Conductor.songPosition + (Conductor.safeZoneOffset * 0.5));

        if (strumTime < Conductor.songPosition - Conductor.safeZoneOffset && !wasGoodHit) {
            tooLate = true;
        }
    }
}