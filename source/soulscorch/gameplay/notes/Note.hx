package soulscorch.gameplay.notes;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.util.FlxColor;
import soulscorch.modding.ModManager;
#if sys
import sys.FileSystem;
#end

class Note extends FlxSprite {
    public static inline var LANE_COUNT:Int = 4;
    public static inline var NOTE_SIZE:Int = 48;
    public static inline var PIXELS_PER_MS:Float = 0.45;

    public var strumTime:Float;
    public var noteData(default, set):Int;
    public var isSustainNote:Bool;
    public var sustainLength:Float;
    public var parentNote:Note;
    public var canBeHit:Bool = false;
    public var wasGoodHit:Bool = false;
    public var tooLate:Bool = false;
    public var mustPress:Bool = true;
    public var noteType:String = "Default";
    public var downscroll:Bool = false;
    public var sustainScale:Float = 1.0;
    public var hitWindow:Float = 160.0;

    public function new(strumTime:Float, noteData:Int, sustainLength:Float = 0.0, ?parentNote:Note, isSustainNote:Bool = false, mustPress:Bool = true, noteType:String = "Default") {
        super();
        this.strumTime = strumTime;
        this.noteData = noteData;
        this.sustainLength = Math.max(0.0, sustainLength);
        this.parentNote = parentNote;
        this.isSustainNote = isSustainNote;
        this.mustPress = mustPress;
        this.noteType = noteType == null ? "Default" : noteType;
        loadSkin();
        updateVisualScale();
    }

    private function set_noteData(value:Int):Int {
        var normalized:Int = value % LANE_COUNT;
        if (normalized < 0) normalized += LANE_COUNT;
        noteData = normalized;
        return normalized;
    }

    private function loadSkin():Void {
        var skinPath:String = ModManager.getPath("images/gameplay/notes/default.png");
        var loaded:Bool = false;
        #if sys
        if (skinPath != null && FileSystem.exists(skinPath)) {
            loaded = loadGraphic(skinPath, false, NOTE_SIZE, NOTE_SIZE) != null;
        }
        #end
        if (!loaded) makeGraphic(NOTE_SIZE, NOTE_SIZE, colorForLane(noteData));
        antialiasing = true;
    }

    public function updateForSong(songPosition:Float, scrollSpeed:Float, downscroll:Bool):Void {
        this.downscroll = downscroll;
        var distance:Float = (strumTime - songPosition) * PIXELS_PER_MS * scrollSpeed;
        y = downscroll ? FlxG.height * 0.72 - distance : FlxG.height * 0.28 + distance;
        canBeHit = Math.abs(strumTime - songPosition) <= hitWindow;
        tooLate = songPosition - strumTime > hitWindow;
        updateVisualScale();
    }

    public function updateVisualScale():Void {
        if (!isSustainNote) {
            scale.set(1.0, 1.0);
        } else {
            scale.set(1.0, Math.max(0.1, sustainLength * PIXELS_PER_MS * sustainScale / NOTE_SIZE));
        }
        updateHitbox();
    }

    public function setScrollSpeed(value:Float):Void {
        sustainScale = Math.max(0.1, value);
        updateVisualScale();
    }

    public function clipSustain(remainingLength:Float):Void {
        if (!isSustainNote) return;
        sustainLength = Math.max(0.0, remainingLength);
        updateVisualScale();
    }

    public static function colorForLane(lane:Int):FlxColor {
        return switch ((lane % LANE_COUNT + LANE_COUNT) % LANE_COUNT) {
            case 0: FlxColor.PURPLE;
            case 1: FlxColor.CYAN;
            case 2: FlxColor.GREEN;
            default: FlxColor.RED;
        };
    }
}
