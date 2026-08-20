package soulscorch.backend;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxState;
import flixel.util.FlxColor;
import haxe.xml.Access;
import soulscorch.backend.TransitionData;
import soulscorch.backend.TransitionData.TransitionDirection;
import soulscorch.backend.TransitionData.TransitionType;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.interfaces.IBeatReceiver;
import soulscorch.backend.system.Scene;
import soulscorch.backend.system.XMSoul;

class MusicBeatState extends Scene implements IBeatReceiver {
    public static var defaultTransition:TransitionData = new TransitionData(TransitionType.WIPE, TransitionDirection.OUT, 0.35);
    public static var skipNextTransIn:Bool = false;
    public static var skipNextTransOut:Bool = false;
    public static var nextStateTarget:FlxState = null;

    override public function create():Void {
        super.create();

        loadCustomTransitions();

        if (!skipNextTransIn) {
            MusicBeatTransition.play(new TransitionData(
                defaultTransition.type, 
                TransitionDirection.IN, 
                defaultTransition.duration, 
                defaultTransition.color, 
                defaultTransition.ease,
                defaultTransition.sound
            ));
        }
        skipNextTransIn = false;
    }

    public static function loadCustomTransitions():Void {
        var access:Access = XMSoul.parse("config/transitions");
        if (access == null) access = XMSoul.parse("data/config/transitions");

        if (access != null) {
            var typeStr = XMSoul.getAttr(access, "type", "wipe");
            var duration = XMSoul.getFloatAttr(access, "duration", 0.35);
            var easeStr = XMSoul.getAttr(access, "ease", "quartOut");
            var colStr = XMSoul.getAttr(access, "color", "0xFF000000");
            var sfx = XMSoul.getAttr(access, "sound", null);

            var color = FlxColor.fromString(colStr);
            defaultTransition = new TransitionData(
                TransitionData.parseType(typeStr),
                TransitionDirection.OUT,
                duration,
                color != null ? color : FlxColor.BLACK,
                TransitionData.parseEase(easeStr),
                sfx
            );
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
        var currentStepCrochet = (lastChange.stepCrochet != null && lastChange.stepCrochet > 0) 
            ? lastChange.stepCrochet 
            : ((60.0 / lastChange.bpm) * 1000.0) / 4.0;
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
        if (nextState == null) return;
        if (MusicBeatTransition.isTransitioning) return;

        var transition = transData != null ? transData : defaultTransition;

        var stateName:String = Type.getClassName(Type.getClass(nextState)).split(".").pop();
        var redirectTarget:Null<String> = soulscorch.scripting.mod.SoulGlobalScript.getRedirect(stateName);

        var finalTarget:FlxState = (redirectTarget != null) 
            ? new soulscorch.scripting.mod.ModCustomState(redirectTarget) 
            : nextState;

        if (skipNextTransOut || transition.type == NONE || FlxG.state == null) {
            skipNextTransOut = false;
            MusicBeatTransition.isTransitioning = false;
            FlxG.switchState(finalTarget);
            return;
        }

        nextStateTarget = finalTarget;
        MusicBeatTransition.play(transition, function() {
            FlxG.switchState(nextStateTarget);
            nextStateTarget = null;
        });
    }

    public static function resetState(?transData:TransitionData):Void {
        if (FlxG.state == null) return;
        var curClass = Type.getClass(FlxG.state);
        switchState(Type.createInstance(curClass, []), transData);
    }
}