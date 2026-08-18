package soulscorch.gameplay.notes;

import flixel.FlxSprite;
import flixel.util.FlxColor;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.audio.Conductor;
import soulscorch.scripting.mod.ModLoader;

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

    private static var colArray:Array<String> = ['purple', 'blue', 'green', 'red'];

    public function new(strumTime:Float, noteData:Int, sustainLength:Float = 0.0, ?parent:Note, isSustainNote:Bool = false, isEndNote:Bool = false, mustPress:Bool = false, noteType:String = "Default") {
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

    public function loadNoteSkin():Void {
        var pathsToTry = ["NOTE_assets", "notes/NOTE_assets", "gameplay/notes/NOTE_assets"];
        for (p in pathsToTry) {
            if (AssetResolver.exists('assets/images/$p.png') || AssetResolver.exists('images/$p.png') || AssetResolver.exists('$p.png')) {
                AssetHelper.loadSparrowSafely(this, p);
                break;
            }
        }

        var col = colArray[noteData % 4];

        if (isSustainNote) {
            if (isEndNote) {
                animation.addByPrefix('holdend', '$col hold end', 24, true);
                if (!animation.exists('holdend')) animation.addByPrefix('holdend', '${col}holdend', 24, true);
                animation.play('holdend');
            } else {
                animation.addByPrefix('holdpiece', '$col hold piece', 24, true);
                if (!animation.exists('holdpiece')) animation.addByPrefix('holdpiece', '${col}hold', 24, true);
                animation.play('holdpiece');
            }
        } else {
            animation.addByPrefix('scroll', '$col scroll', 24, true);
            if (!animation.exists('scroll')) animation.addByPrefix('scroll', '$col 0', 24, true);
            animation.play('scroll');
        }

        antialiasing = true;
        setGraphicSize(Std.int(width * 0.7));
        updateHitbox();
    }

    public function updatePosition(strumX:Float, strumY:Float, speed:Float, downscroll:Bool):Void {
        x = strumX;
        var diff = (strumTime - Conductor.songPosition);

        if (downscroll) {
            y = strumY + (diff * (0.45 * speed));
        } else {
            y = strumY - (diff * (0.45 * speed));
        }

        canBeHit = (strumTime > Conductor.songPosition - 160 && strumTime < Conductor.songPosition + 160);
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