package soulscorch.gameplay;

import flixel.FlxSprite;
import flixel.util.FlxColor;
import soulscorch.assets.AssetHelper;

class NoteSprite extends FlxSprite {
    public static inline var WIDTH:Int = 112;
    public static inline var HEIGHT:Int = 112;

    public var noteData:Note;
    public var isSustain:Bool = false;
    public var isSustainEnd:Bool = false;
    public var offsetX:Float = 0;
    public var offsetY:Float = 0;
    public var hitHealth:Float = 0.025;
    public var missHealth:Float = 0.0475;

    static var colArray:Array<String> = ['purple', 'blue', 'green', 'red'];

    public function new(noteData:Note, isSustain:Bool = false, isSustainEnd:Bool = false) {
        super();
        this.noteData = noteData;
        this.isSustain = isSustain;
        this.isSustainEnd = isSustainEnd;

        loadNoteGraphic();
    }

    public function loadNoteGraphic():Void {
        var loaded = AssetHelper.loadSparrowSafely(this, "assets/images/gameplay/notes/default.png", "assets/images/gameplay/notes/default.xml");

        if (loaded) {
            var dirName = colArray[noteData.direction % 4];

            if (isSustainEnd) {
                if (noteData.direction % 4 == 0) {
                    animation.addByPrefix('holdend', 'pruple end hold0', 24, true);
                } else {
                    animation.addByPrefix('holdend', dirName + ' hold end0', 24, true);
                }
                animation.play('holdend');
            } else if (isSustain) {
                animation.addByPrefix('holdpiece', dirName + ' hold piece0', 24, true);
                animation.play('holdpiece');
            } else {
                animation.addByPrefix('scroll', dirName + '0', 24, true);
                animation.play('scroll');
            }

            setGraphicSize(Std.int(width * 0.7));
            updateHitbox();
        } else {
            makeGraphic(WIDTH, HEIGHT, colorForDirection(noteData.direction));
            setGraphicSize(Std.int(width * 0.7));
            updateHitbox();
        }

        if (isSustain) {
            alpha = 0.6;
        }
        antialiasing = true;
    }

    public static function colorForDirection(direction:Int):FlxColor {
        return switch (direction % 4) {
            case 0: 0xFFC24B99;
            case 1: 0xFF00FFFF;
            case 2: 0xFF12FA05;
            default: 0xFFF9393F;
        }
    }
}