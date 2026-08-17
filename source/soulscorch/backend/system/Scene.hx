package soulscorch.backend.system;

import flixel.FlxG;
import flixel.FlxState;
import flixel.FlxSubState;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.interfaces.IBeatReceiver;
import soulscorch.backend.system.Achievements;
import soulscorch.backend.system.NotificationManager;
import soulscorch.backend.utils.Scheduler;

class Scene extends FlxState implements IBeatReceiver {
    public var curStep:Int = 0;
    public var curBeat:Int = 0;
    public var curMeasure:Int = 0;
    public var controlsEnabled:Bool = true;
    public var isTransitioning:Bool = false;

    private var _lastBeat:Int = -1;
    private var _lastStep:Int = -1;

    public function new() {
        super();
    }

    override public function create():Void {
        super.create();
        if (NotificationManager.instance != null) {
            add(NotificationManager.instance);
        }
        if (Achievements.instance != null) {
            add(Achievements.instance.popupGroup);
        }
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        if (Scheduler.instance != null) Scheduler.instance.update(elapsed);
        if (Achievements.instance != null) Achievements.instance.update(elapsed);
        updateConductorTrackers();
    }

    private function updateConductorTrackers():Void {
        if (Conductor.stepCrochet <= 0) return;

        curStep = Std.int(Conductor.songPosition / Conductor.stepCrochet);
        curBeat = Std.int(curStep / 4);
        curMeasure = Std.int(curBeat / 4);

        if (curStep != _lastStep) {
            _lastStep = curStep;
            stepHit(curStep);
        }

        if (curBeat != _lastBeat) {
            _lastBeat = curBeat;
            beatHit(curBeat);
        }
    }

    override public function destroy():Void {
        if (NotificationManager.instance != null) remove(NotificationManager.instance);
        if (Achievements.instance != null) remove(Achievements.instance.popupGroup);
        super.destroy();
    }

    public function stepHit(step:Int):Void {}
    public function beatHit(beat:Int):Void {}
    public function measureHit(measure:Int):Void {}

    public function switchScene(nextScene:Scene):Void {
        if (isTransitioning) return;
        isTransitioning = true;
        controlsEnabled = false;
        FlxG.switchState(nextScene);
    }

    public function openSubScene(subScene:FlxSubState):Void {
        controlsEnabled = false;
        openSubState(subScene);
    }

    public function closeSubScene():Void {
        controlsEnabled = true;
        closeSubState();
    }
}