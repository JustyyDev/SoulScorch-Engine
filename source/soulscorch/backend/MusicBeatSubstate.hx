package soulscorch.backend;

import flixel.FlxG;
import flixel.FlxSubState;
import soulscorch.backend.TransitionData;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.interfaces.IBeatReceiver;

class MusicBeatSubstate extends FlxSubState implements IBeatReceiver {
    private var curStep:Int = 0;
    private var curBeat:Int = 0;
    private var curMeasure:Int = 0;

    private var onTransitionOut:Void->Void;
    private var transData:TransitionData;

    public function new(?onComplete:Void->Void, ?trans:TransitionData) {
        super();
        this.onTransitionOut = onComplete;
        this.transData = trans;
    }

    override public function create():Void {
        super.create();

        if (transData != null) {
            var trans = new MusicBeatTransition(transData, function() {
                if (onTransitionOut != null) {
                    onTransitionOut();
                }
                close();
            });
            add(trans);
        }
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
        var crochet = ((60.0 / lastChange) * 1000.0) / 4.0;
        curStep = Math.floor(Conductor.songPosition / crochet);
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