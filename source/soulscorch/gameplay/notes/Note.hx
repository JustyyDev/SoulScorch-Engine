package soulscorch.gameplay.notes;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.util.FlxColor;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.audio.Conductor;

class Note extends FlxSprite {
    public static inline var LANE_COUNT:Int = 4;
    public static inline var NOTE_SIZE:Int = 112; // Standard base note width[cite: 71]
    public static inline var PIXELS_PER_MS:Float = 0.45; // Pixel scroll factor[cite: 69]

    public static var colArray:Array<String> = ['purple', 'blue', 'green', 'red'];[cite: 71]

    public var strumTime:Float;
    public var noteData(default, set):Int;
    public var isSustainNote:Bool;
    public var isSustainEnd:Bool;
    public var sustainLength:Float;
    public var parentNote:Note;
    public var tail:Array<Note> = [];

    public var canBeHit:Bool = false;
    public var wasGoodHit:Bool = false;
    public var tooLate:Bool = false;
    public var mustPress:Bool = true;
    public var noteType:String = "Default";
    public var downscroll:Bool = false;

    public var hitHealth:Float = 0.025;[cite: 71]
    public var missHealth:Float = 0.0475;[cite: 71]
    public var hitWindow:Float = 160.0;[cite: 69]
    public var sustainScale:Float = 1.0;

    public var offsetX:Float = 0.0;
    public var offsetY:Float = 0.0;

    public function new(
        strumTime:Float,
        noteData:Int,
        sustainLength:Float = 0.0,
        ?parentNote:Note,
        isSustainNote:Bool = false,
        isSustainEnd:Bool = false,
        mustPress:Bool = true,
        noteType:String = "Default"
    ) {
        super();
        this.strumTime = strumTime;
        this.noteData = noteData;
        this.sustainLength = Math.max(0.0, sustainLength);[cite: 69]
        this.parentNote = parentNote;
        this.isSustainNote = isSustainNote;
        this.isSustainEnd = isSustainEnd;
        this.mustPress = mustPress;
        this.noteType = (noteType == null || noteType.length == 0) ? "Default" : noteType;

        loadSkin();
    }

    private function set_noteData(value:Int):Int {
        var normalized:Int = value % LANE_COUNT;
        if (normalized < 0) normalized += LANE_COUNT;
        noteData = normalized;
        return normalized;
    }

    /**
     * Loads Sparrow atlas skins with fallback to colored primitive graphics.
     */
    public function loadSkin():Void {
        var dirName = colArray[noteData % LANE_COUNT];
        var customSkinPath = (noteType != "Default" && noteType != "") ? 'notes/$noteType' : "notes/NOTE_assets";

        if (!Paths.exists(Paths.xml(customSkinPath))) {
            customSkinPath = "notes/NOTE_assets";
        }

        var loaded = AssetHelper.loadSparrowSafely(this, customSkinPath);

        if (loaded) {
            if (isSustainEnd) {
                if (noteData % LANE_COUNT == 0) {
                    animation.addByPrefix('holdend', 'pruple end hold', 24, true);[cite: 71]
                } else {
                    animation.addByPrefix('holdend', dirName + ' hold end', 24, true);[cite: 71]
                }
                animation.play('holdend');
            } else if (isSustainNote) {
                animation.addByPrefix('holdpiece', dirName + ' hold piece', 24, true);[cite: 71]
                animation.play('holdpiece');
            } else {
                animation.addByPrefix('scroll', dirName + '0', 24, true);[cite: 71]
                animation.play('scroll');
            }

            setGraphicSize(Std.int(width * 0.7));[cite: 71, 73]
            updateHitbox();
        } else {
            makeGraphic(NOTE_SIZE, NOTE_SIZE, colorForDirection(noteData));[cite: 71]
            setGraphicSize(Std.int(width * 0.7));[cite: 71]
            updateHitbox();
        }

        if (isSustainNote) {
            alpha = 0.6;[cite: 71]
        }

        antialiasing = true;
        scrollFactor.set(0, 0);
    }

    /**
     * Updates hit logic and visual positioning relative to target receptor.
     */
    public function updatePosition(receptorX:Float, receptorY:Float, scrollSpeed:Float, downscroll:Bool):Void {
        this.downscroll = downscroll;
        var songPos = Conductor.songPosition;
        var speedMod = scrollSpeed * PIXELS_PER_MS;
        var distance:Float = (strumTime - songPos) * speedMod;[cite: 69]

        x = receptorX + offsetX;

        if (downscroll) {
            y = receptorY + distance + offsetY;
            if (isSustainEnd && parentNote != null) {
                y -= height * 0.5;
            }
        } else {
            y = receptorY - distance + offsetY;
        }

        // Timing validation
        var safeZone = (Conductor.safeZoneOffset > 0) ? Conductor.safeZoneOffset : hitWindow;
        canBeHit = (strumTime <= songPos + safeZone && strumTime >= songPos - (safeZone * 0.5));
        tooLate = (songPos - strumTime > safeZone && !wasGoodHit);[cite: 69]

        // Handle sustain clipping when held past target receptor
        if (isSustainNote && wasGoodHit && songPos > strumTime) {
            clipSustain(songPos);
        }
    }

    public function clipSustain(songPosition:Float):Void {
        if (!isSustainNote) return;

        var remainingDist = (strumTime + sustainLength) - songPosition;
        if (remainingDist <= 0) {
            kill();
            visible = false;
        }
    }

    public static function colorForDirection(direction:Int):FlxColor {
        return switch (direction % LANE_COUNT) {
            case 0: 0xFFC24B99; // Left (Purple)[cite: 71]
            case 1: 0xFF00FFFF; // Down (Cyan)[cite: 71]
            case 2: 0xFF12FA05; // Up (Green)[cite: 71]
            default: 0xFFF9393F; // Right (Red)[cite: 71]
        };
    }
}