package soulscorch.backend.system;

import flixel.FlxG;
import flixel.FlxState;
import flixel.FlxSubState;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.interfaces.IBeatReceiver;
import soulscorch.backend.system.Achievements;
import soulscorch.backend.system.NotificationManager;
import soulscorch.backend.system.engine.Engine;
import soulscorch.backend.utils.Logger;
import soulscorch.backend.utils.Scheduler;

class Scene extends FlxState implements IBeatReceiver {
    public var curStep:Int = 0;
    public var curBeat:Int = 0;
    public var curMeasure:Int = 0;
    public var controlsEnabled:Bool = true;
    public var isTransitioning:Bool = false;
    public var sceneName:String = "UnnamedScene";

    private var _lastBeat:Int = -1;
    private var _lastStep:Int = -1;
    private var _lastMeasure:Int = -1;

    public function new() {
        super();
        sceneName = Type.getClassName(Type.getClass(this));
    }

    override public function create():Void {
        super.create();

        if (NotificationManager.instance != null) {
            add(NotificationManager.instance);
        }
        if (Achievements.instance != null) {
            add(Achievements.instance.popupGroup);
        }

        if (Engine.instance != null) {
            Engine.instance.notifySceneCreate(this);
        }

        Logger.info('[SCENE] Initialized scene: $sceneName', "scene");
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        
        if (Scheduler.instance != null) {
            Scheduler.instance.update(elapsed);
        }
        if (Achievements.instance != null) {
            Achievements.instance.update(elapsed);
        }
        
        updateConductorTrackers();
    }

    private function updateConductorTrackers():Void {
        curStep = Conductor.curStep;
        curBeat = Conductor.curBeat;
        curMeasure = Conductor.curMeasure;

        if (curStep != _lastStep) {
            _lastStep = curStep;
            stepHit(curStep);
        }

        if (curBeat != _lastBeat) {
            _lastBeat = curBeat;
            beatHit(curBeat);
        }

        if (curMeasure != _lastMeasure) {
            _lastMeasure = curMeasure;
            measureHit(curMeasure);
        }
    }

    override public function destroy():Void {
        if (NotificationManager.instance != null) {
            remove(NotificationManager.instance);
        }
        if (Achievements.instance != null) {
            remove(Achievements.instance.popupGroup);
        }

        Logger.info('[SCENE] Destroyed scene: $sceneName', "scene");
        super.destroy();
    }

    public function stepHit(step:Int):Void {}
    
    public function beatHit(beat:Int):Void {}
    
    public function measureHit(measure:Int):Void {}

    public function switchScene(nextScene:FlxState):Void {
        if (isTransitioning) return;
        isTransitioning = true;
        controlsEnabled = false;

        if (Engine.instance != null && Std.isOfType(nextScene, Scene)) {
            Engine.instance.notifySceneSwitch(cast nextScene);
        }

        FlxG.switchState(nextScene);
    }

    public function openSubScene(subScene:FlxSubState):Void {
        if (!controlsEnabled) return;
        controlsEnabled = false;
        openSubState(subScene);
    }

    public function closeSubScene():Void {
        controlsEnabled = true;
        closeSubState();
    }
}