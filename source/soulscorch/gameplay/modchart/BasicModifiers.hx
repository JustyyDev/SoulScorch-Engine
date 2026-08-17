package soulscorch.gameplay.modchart;

import flixel.FlxSprite;
import soulscorch.backend.audio.Conductor;
import soulscorch.gameplay.modchart.ModchartTypes.ModTarget;
import soulscorch.gameplay.notes.Note;

class DrunkModifier extends Modifier {
    public var speed:Float = 1.0;
    public var totalTime:Float = 0.0;

    public function new() {
        super("drunk");
    }

    override public function update(elapsed:Float):Void {
        totalTime += elapsed;
    }

    override public function modifyReceptor(receptor:FlxSprite, lane:Int, target:ModTarget):Void {
        var val = getValue(target, lane);
        if (val != 0) {
            receptor.x += Math.sin((totalTime * speed * 2.5) + (lane * 0.35)) * (val * 40.0);
        }
    }

    override public function modifyNote(note:Note, lane:Int, target:ModTarget, strumTime:Float):Void {
        var val = getValue(target, lane);
        if (val != 0) {
            var diff = strumTime - Conductor.songPosition;
            note.x += Math.sin(((totalTime * speed * 2.5) + (diff * 0.004)) + (lane * 0.35)) * (val * 40.0);
        }
    }
}

class TipsyModifier extends Modifier {
    public var speed:Float = 1.0;
    public var totalTime:Float = 0.0;

    public function new() {
        super("tipsy");
    }

    override public function update(elapsed:Float):Void {
        totalTime += elapsed;
    }

    override public function modifyReceptor(receptor:FlxSprite, lane:Int, target:ModTarget):Void {
        var val = getValue(target, lane);
        if (val != 0) {
            receptor.y += Math.cos((totalTime * speed * 2.5) + (lane * 0.45)) * (val * 30.0);
        }
    }

    override public function modifyNote(note:Note, lane:Int, target:ModTarget, strumTime:Float):Void {
        var val = getValue(target, lane);
        if (val != 0) {
            var diff = strumTime - Conductor.songPosition;
            note.y += Math.cos(((totalTime * speed * 2.5) + (diff * 0.004)) + (lane * 0.45)) * (val * 30.0);
        }
    }
}