package soulscorch.backend;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxState;
import soulscorch.backend.TransitionData;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.interfaces.IBeatReceiver;
import soulscorch.backend.system.Scene;

class MusicBeatState extends Scene implements IBeatReceiver {
    public static var defaultTransition:TransitionData = new TransitionData(FADE, IN, 0.4);

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
        var crochet = ((60.0 / lastChange) * 1000.0) / 4.0;
        curStep = Math.floor(Conductor.songPosition / crochet);
    }

    private function updateBeat():Void {
        curBeat = Math.floor(curStep / 4);
        curMeasure = Math.floor(curBeat / 4);
    }

    override public function stepHit(step:Int):Void {
        if (step % 4 == 0) {
            beatHit(curBeat);
        }
        if (step % 16 == 0) {
            measureHit(curMeasure);
        }
    }

    override public function beatHit(beat:Int):Void {}
    override public function measureHit(measure:Int):Void {}

    public static function switchState(nextState:FlxState, ?transData:TransitionData):Void {
        var transition = transData != null ? transData : defaultTransition;

        if (MusicBeatTransition.isTransitioning) return;
        MusicBeatTransition.isTransitioning = true;

        FlxG.state.openSubState(new MusicBeatSubstate(function() {
            FlxG.switchState(nextState);
        }, transition));
    }
}