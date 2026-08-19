package soulscorch.gameplay.notes;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.math.FlxMath;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.audio.Conductor;

using StringTools;

class Note extends FlxSprite {
    public var strumTime:Float = 0.0;
    public var noteData:Int = 0;
    public var rawNoteData:Int = 0;
    public var mustPress:Bool = false;
    public var isSustainNote:Bool = false;
    public var isSustainEnd:Bool = false;
    public var parent:Note = null;
    public var tail:Array<Note> = [];
    public var sustainLength:Float = 0.0;
    public var noteType:String = "default";
    public var skin:String = "default";

    public var canBeHit:Bool = false;
    public var tooLate:Bool = false;
    public var wasGoodHit:Bool = false;
    public var ignoreNote:Bool = false;
    public var hitHealth:Float = 0.023;
    public var missHealth:Float = 0.0475;

    public var offsetX:Float = 0.0;
    public var offsetY:Float = 0.0;
    public var multSpeed:Float = 1.0;
    public var copyX:Bool = true;
    public var copyY:Bool = true;
    public var copyAngle:Bool = true;
    public var copyAlpha:Bool = true;

    private static var colorDirections:Array<String> = ["purple", "blue", "green", "red"];
    private static var directionNames:Array<String> = ["left", "down", "up", "right"];

    public function new(strumTime:Float, noteData:Int, ?sustainLength:Float = 0.0, ?parent:Note = null, isSustainNote:Bool = false, isSustainEnd:Bool = false, mustPress:Bool = true, ?noteType:String = "default", ?skin:String = "default") {
        super();

        this.strumTime = strumTime;
        this.noteData = noteData % 4;
        this.rawNoteData = noteData;
        this.sustainLength = sustainLength;
        this.parent = parent;
        this.isSustainNote = isSustainNote;
        this.isSustainEnd = isSustainEnd;
        this.mustPress = mustPress;
        this.noteType = (noteType != null && noteType.length > 0) ? noteType : "default";
        this.skin = (skin != null && skin.length > 0) ? skin : NoteSkinManager.getNoteSkinName();

        loadNoteGraphic();
        antialiasing = true;
    }

    public function loadNoteGraphic():Void {
        var dirColor = colorDirections[noteData % 4];
        var atlas = NoteSkinManager.getSkinAtlas(skin);

        if (atlas != null) {
            frames = atlas;
            if (isSustainNote) {
                if (isSustainEnd) {
                    animation.addByPrefix("holdend", '$dirColor hold end', 24, true);
                    animation.play("holdend");
                } else {
                    animation.addByPrefix("holdpiece", '$dirColor hold piece', 24, true);
                    animation.play("holdpiece");
                }
            } else {
                animation.addByPrefix("scroll", '$dirColor 0', 24, true);
                animation.play("scroll");
            }
        } else {
            var colors:Array<Int> = [0xFFC24B99, 0xFF00FFFF, 0xFF12FA05, 0xFFF9393F];
            makeGraphic(isSustainNote ? 30 : 100, isSustainNote ? 45 : 100, colors[noteData % 4]);
        }

        setGraphicSize(Std.int(width * 0.7));
        updateHitbox();

        if (isSustainNote) {
            alpha = 0.6;
            offsetX += width / 2;
            if (parent != null) {
                offsetX = parent.offsetX + (parent.width / 2) - (width / 2);
            }
        }
    }

    public function updatePosition(strumX:Float, strumY:Float, scrollSpeed:Float, downscroll:Bool):Void {
        var speed:Float = FlxMath.roundDecimal(scrollSpeed * multSpeed, 2);
        var distance:Float = (strumTime - Conductor.songPosition) * (0.45 * speed);

        if (copyX) x = strumX + offsetX;
        if (copyY) {
            if (downscroll) {
                y = strumY + distance + offsetY;
                if (isSustainNote) {
                    if (isSustainEnd) {
                        y += (Conductor.stepCrochet * 0.45 * speed) - height;
                    }
                    flipY = true;
                }
            } else {
                y = strumY - distance + offsetY;
                if (isSustainNote) flipY = false;
            }
        }

        if (mustPress) {
            if (isSustainNote) {
                canBeHit = (strumTime <= Conductor.songPosition + (Conductor.stepCrochet * 0.5)
                    && strumTime >= Conductor.songPosition - (Conductor.stepCrochet * 1.5));
            } else {
                canBeHit = (strumTime >= Conductor.songPosition - Conductor.safeZoneOffset
                    && strumTime <= Conductor.songPosition + Conductor.safeZoneOffset);
            }
        } else {
            canBeHit = false;
        }
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        if (mustPress && !wasGoodHit && strumTime < Conductor.songPosition - Conductor.safeZoneOffset) {
            tooLate = true;
        }
    }
}