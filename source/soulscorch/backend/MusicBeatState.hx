package soulscorch.backend;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxState;
import soulscorch.backend.TransitionData;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.interfaces.IBeatReceiver;
import soulscorch.backend.system.Scene;

class MusicBeatState extends Scene implements IBeatReceiver {
    public static var defaultTransition:TransitionData = new TransitionData(TransitionType.FADE, TransitionDirection.OUT, 0.45);
    public static var skipNextTransIn:Bool = false;
    public static var skipNextTransOut:Bool = false;

    override public function create():Void {
        super.create();

        if (!skipNextTransIn) {
            openSubState(new CustomSubstate(function() {}, new TransitionData(defaultTransition.type, IN, defaultTransition.duration, defaultTransition.color)));
        }
        skipNextTransIn = false;
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
        var currentStepCrochet = (lastChange.stepCrochet != null && lastChange.stepCrochet > 0) ? lastChange.stepCrochet : ((60.0 / lastChange.bpm) * 1000.0) / 4.0;
        curStep = lastChange.stepTime + Math.floor((Conductor.songPosition - lastChange.songTime) / currentStepCrochet);
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

        var stateName:String = Type.getClassName(Type.getClass(nextState)).split(".").pop();
        var redirectTarget:Null<String> = soulscorch.scripting.mod.SoulGlobalScript.getRedirect(stateName);

        var finalTarget:FlxState = (redirectTarget != null) 
            ? new soulscorch.scripting.mod.ModCustomState(redirectTarget) 
            : nextState;

        if (skipNextTransOut) {
            skipNextTransOut = false;
            MusicBeatTransition.isTransitioning = false;
            FlxG.switchState(finalTarget);
            return;
        }

        FlxG.state.openSubState(new CustomSubstate(function() {
            FlxG.switchState(finalTarget);
        }, transition));
    }
}

class CustomSubstate extends MusicBeatSubstate {
    public function new(onComplete:Void->Void, trans:TransitionData) {
        super(onComplete, trans);
    }
}