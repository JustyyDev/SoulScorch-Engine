package soulscorch.backend;

import flixel.FlxG;
import flixel.FlxSubState;
import soulscorch.backend.TransitionData;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.interfaces.IBeatReceiver;

class MusicBeatSubstate extends FlxSubState implements IBeatReceiver {
    public var curStep:Int = 0;
    public var curBeat:Int = 0;
    public var curMeasure:Int = 0;

    public function new() {
        super();
    }

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
        var lastChange = Conductor.getBPMAtTime(Conductor.songPosition);
        var currentStepCrochet = (lastChange.stepCrochet != null && lastChange.stepCrochet > 0) 
            ? lastChange.stepCrochet 
            : ((60.0 / lastChange.bpm) * 1000.0) / 4.0;
        curStep = lastChange.stepTime + Math.floor((Conductor.songPosition - lastChange.songTime) / currentStepCrochet);
    }

    private function updateBeat():Void {
        curBeat = Math.floor(curStep / 4);
        curMeasure = Math.floor(curBeat / 4);
    }

    public function stepHit(step:Int):Void {
        if (step % 4 == 0) {
            beatHit(curBeat);
        }
        if (step % 16 == 0) {
            measureHit(curMeasure);
        }
    }

    public function beatHit(beat:Int):Void {}
    public function measureHit(measure:Int):Void {}
}