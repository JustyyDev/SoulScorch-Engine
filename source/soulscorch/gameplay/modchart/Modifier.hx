package soulscorch.gameplay.modchart;

import flixel.FlxSprite;
import soulscorch.gameplay.modchart.ModchartTypes.ModTarget;
import soulscorch.gameplay.notes.Note;

class Modifier {
    public var name:String;
    public var playerValues:Array<Float> = [0.0, 0.0, 0.0, 0.0];
    public var opponentValues:Array<Float> = [0.0, 0.0, 0.0, 0.0];
    public var active:Bool = true;

    public function new(name:String) {
        this.name = name;
    }

    public function setValue(value:Float, target:ModTarget = BOTH, lane:Int = -1):Void {
        if (lane >= 0 && lane < 4) {
            if (target == PLAYER || target == BOTH) playerValues[lane] = value;
            if (target == OPPONENT || target == BOTH) opponentValues[lane] = value;
        } else {
            for (i in 0...4) {
                if (target == PLAYER || target == BOTH) playerValues[i] = value;
                if (target == OPPONENT || target == BOTH) opponentValues[i] = value;
            }
        }
    }

    public function getValue(target:ModTarget, lane:Int = 0):Float {
        var cleanLane = (lane >= 0 && lane < 4) ? lane : 0;
        return (target == OPPONENT) ? opponentValues[cleanLane] : playerValues[cleanLane];
    }

    public function update(elapsed:Float):Void {}

    public function modifyReceptor(receptor:FlxSprite, lane:Int, target:ModTarget):Void {}

    public function modifyNote(note:Note, lane:Int, target:ModTarget, strumTime:Float):Void {}
}