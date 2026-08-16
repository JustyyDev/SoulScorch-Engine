package soulscorch.backend;

import flixel.FlxSubState;
import soulscorch.gameplay.Conductor;

class MusicBeatSubstate extends FlxSubState {
    private var curStep:Int = 0;
    private var curBeat:Int = 0;
    private var decStep:Float = 0;
    private var decBeat:Float = 0;

    override public function update(elapsed:Float):Void {
        var oldStep:Int = curStep;
        updateCurStep();
        updateBeat();

        if (oldStep != curStep && curStep > 0) {
            stepHit(curStep);
        }

        super.update(elapsed);
    }

    private function updateCurStep():Void {
        if (Conductor.bpm <= 0) return;
        decStep = Conductor.songPosition / (60 / Conductor.bpm * 1000) * 4;
        curStep = Std.int(decStep);
    }

    private function updateBeat():Void {
        curBeat = Std.int(curStep / 4);
        decBeat = decStep / 4;
    }

    public function stepHit(step:Int):Void {
        if (step % 4 == 0) {
            beatHit(Std.int(step / 4));
        }
    }

    public function beatHit(beat:Int):Void {
        // Override in substates for rhythmic UI pulsing
    }
}