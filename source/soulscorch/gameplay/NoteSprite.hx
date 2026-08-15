package soulscorch.gameplay;

import flixel.FlxSprite;
import flixel.util.FlxColor;
import flixel.graphics.frames.FlxAtlasFrames;
import soulscorch.gameplay.Chart.NoteData;

class NoteSprite extends FlxSprite {
    public static inline var WIDTH:Int = 112;
    public static inline var HEIGHT:Int = 112;

    public var data:NoteData;
    public var isSustain:Bool;

    public function new(data:NoteData, isSustain:Bool = false) {
        super();
        this.data = data;
        this.isSustain = isSustain;
        
        makeGraphic(WIDTH, HEIGHT, colorForDirection(data.direction));
        
        setGraphicSize(Std.int(width * 0.7));
        updateHitbox();
        antialiasing = true;

        if (isSustain) {
            alpha = 0.6;
        }
    }

    public static function colorForDirection(direction:Int):FlxColor {
        return switch (direction) {
            case 0: 0xFFC24B99;
            case 1: 0xFF00FFFF;
            case 2: 0xFF12FA05;
            default: 0xFFF9393F;
        }
    }
}