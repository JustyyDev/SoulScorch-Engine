package soulscorch.gameplay.notes;

import flixel.FlxSprite;
import flixel.util.FlxColor;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.audio.Conductor;

using StringTools;

class Note extends FlxSprite {
    public var strumTime:Float = 0.0;
    public var noteData:Int = 0;
    public var sustainLength:Float = 0.0;
    public var parent:Note;
    public var isSustainNote:Bool = false;
    public var isEndNote:Bool = false;
    public var mustPress:Bool = false;
    public var noteType:String = "Default";

    public var canBeHit:Bool = false;
    public var tooLate:Bool = false;
    public var wasGoodHit:Bool = false;
    public var tail:Array<Note> = [];
    public var hitHealth:Float = 0.023;
    public var missHealth:Float = 0.0475;

    public var multSpeed:Float = 1.0;
    public var copyX:Bool = true;
    public var copyY:Bool = true;
    public var copyAngle:Bool = true;
    public var copyAlpha:Bool = true;

    private static var colArray:Array<String> = ['purple', 'blue', 'green', 'red'];

    public function new(
        strumTime:Float,
        noteData:Int,
        sustainLength:Float = 0.0,
        ?parent:Note,
        isSustainNote:Bool = false,
        isEndNote:Bool = false,
        mustPress:Bool = false,
        noteType:String = "Default"
    ) {
        super();

        this.strumTime = strumTime;
        this.noteData = noteData;
        this.sustainLength = sustainLength;
        this.parent = parent;
        this.isSustainNote = isSustainNote;
        this.isEndNote = isEndNote;
        this.mustPress = mustPress;
        this.noteType = noteType;

        loadNoteSkin();
    }

    public function loadNoteSkin(?customSkin:String):Void {
        var skinToLoad = (customSkin != null && customSkin.trim().length > 0) ? customSkin : "gameplay/notes/NOTE_assets";

        if (!AssetHelper.loadSparrowSafely(this, skinToLoad)) {
            if (!AssetHelper.loadSparrowSafely(this, "notes/NOTE_assets")) {
                AssetHelper.loadSparrowSafely(this, "NOTE_assets");
            }
        }

        var col = colArray[noteData % 4];

        if (isSustainNote) {
            if (isEndNote) {
                animation.addByPrefix('holdend', '$col hold end', 24, true);
                if (!animation.exists('holdend')) animation.addByPrefix('holdend', '${col}holdend', 24, true);
                if (!animation.exists('holdend')) animation.addByPrefix('holdend', 'pruple end hold', 24, true); // Legacy FNF typo support
                animation.play('holdend');
            } else {
                animation.addByPrefix('holdpiece', '$col hold piece', 24, true);
                if (!animation.exists('holdpiece')) animation.addByPrefix('holdpiece', '${col}hold', 24, true);
                if (!animation.exists('holdpiece')) animation.addByPrefix('holdpiece', '$col hold0', 24, true);
                animation.play('holdpiece');
            }
        } else {
            animation.addByPrefix('scroll', '$col scroll', 24, true);
            if (!animation.exists('scroll')) animation.addByPrefix('scroll', '$col 0', 24, true);
            if (!animation.exists('scroll')) animation.addByPrefix('scroll', '$col', 24, true);
            animation.play('scroll');
        }

        antialiasing = true;
        setGraphicSize(Std.int(width * 0.7));
        updateHitbox();

        if (isSustainNote) {
            alpha = 0.6;
            offsetX += width / 2;
        }
    }

    public function updatePosition(strumX:Float, strumY:Float, speed:Float, downscroll:Bool):Void {
        if (copyX) x = strumX;

        var scrollMult = (0.45 * speed * multSpeed);
        var diff = (strumTime - Conductor.songPosition);

        if (copyY) {
            if (downscroll) {
                y = strumY + (diff * scrollMult);
                if (isSustainNote) {
                    flipY = true;
                    if (isEndNote) y += (height / 2);
                }
            } else {
                y = strumY - (diff * scrollMult);
                if (isSustainNote) {
                    flipY = false;
                }
            }
        }

        canBeHit = (strumTime > Conductor.songPosition - 166 && strumTime < Conductor.songPosition + 166);
    }

    public static function colorForDirection(dir:Int):FlxColor {
        return switch (dir % 4) {
            case 0: 0xFFC24B99;
            case 1: 0xFF00FFFF;
            case 2: 0xFF12FA05;
            case 3: 0xFFF9393F;
            default: 0xFFFFFFFF;
        };
    }
}