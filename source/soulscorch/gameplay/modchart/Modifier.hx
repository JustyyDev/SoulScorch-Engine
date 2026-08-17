package soulscorch.gameplay.modchart;

import soulscorch.gameplay.modchart.ModchartTypes.ModTarget;
import soulscorch.gameplay.modchart.ModchartTypes.RenderTransform;

class Modifier {
    public var name:String;
    public var values:Array<Array<Float>>; // [target (0: player, 1: opponent)][lane (0-3, 4: all)]
    public var active:Bool = true;

    public function new(name:String) {
        this.name = name;
        this.values = [
            [0.0, 0.0, 0.0, 0.0, 0.0], // Player (Lanes 0-3 + Global 4)
            [0.0, 0.0, 0.0, 0.0, 0.0]  // Opponent (Lanes 0-3 + Global 4)
        ];
    }

    public function getValue(target:ModTarget, lane:Int = 4):Float {
        var tIdx = (target == BOTH || target == PLAYER) ? 0 : 1;
        var lIdx = (lane >= 0 && lane < 4) ? lane : 4;
        return values[tIdx][lIdx] + (lIdx != 4 ? values[tIdx][4] : 0.0);
    }

    public function setValue(value:Float, target:ModTarget = BOTH, lane:Int = 4):Void {
        var lIdx = (lane >= 0 && lane < 4) ? lane : 4;
        if (target == BOTH || target == PLAYER) values[0][lIdx] = value;
        if (target == BOTH || target == OPPONENT) values[1][lIdx] = value;
    }

    public function applyStrum(transform:RenderTransform, lane:Int, target:ModTarget, songPosition:Float):Void {}
    public function applyNote(transform:RenderTransform, lane:Int, target:ModTarget, songPosition:Float, noteDist:Float):Void {}
    public function applySustain(transform:RenderTransform, lane:Int, target:ModTarget, songPosition:Float, noteDist:Float):Void {}
}