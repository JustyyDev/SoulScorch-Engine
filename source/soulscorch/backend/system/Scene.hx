package soulscorch.backend.system;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxState;
import flixel.FlxSubState;
import flixel.util.FlxColor;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.interfaces.IBeatReceiver;
import soulscorch.backend.system.Achievements;
import soulscorch.backend.system.NotificationManager;
import soulscorch.backend.system.engine.Engine;
import soulscorch.backend.utils.Logger;
import soulscorch.backend.utils.Scheduler;
import soulscorch.scripting.ScriptManager;

class Scene extends FlxState implements IBeatReceiver {
    public var curStep:Int = 0;
    public var curBeat:Int = 0;
    public var curMeasure:Int = 0;

    public var controlsEnabled:Bool = true;
    public var isTransitioning:Bool = false;
    public var sceneName:String = "UnnamedScene";

    // Standard Multi-Camera Layout (Inherited by all sub-states)
    public var camGame:FlxCamera;
    public var camHUD:FlxCamera;
    public var camOther:FlxCamera;

    private var _lastBeat:Int = -1;
    private var _lastStep:Int = -1;
    private var _lastMeasure:Int = -1;

    public function new() {
        super();
        sceneName = Type.getClassName(Type.getClass(this));
    }

    override public function create():Void {
        setupCameras();
        super.create();

        if (NotificationManager.instance != null) {
            NotificationManager.instance.cameras = [camOther];
            add(NotificationManager.instance);
        }

        #if !macro
        try {
            if (Achievements.instance != null && Reflect.hasField(Achievements.instance, "popupGroup")) {
                var group = Reflect.field(Achievements.instance, "popupGroup");
                if (group != null) {
                    Reflect.setField(group, "cameras", [camOther]);
                    add(cast group);
                }
            }
        } catch (e:Dynamic) {}

        try {
            if (Engine.instance != null) {
                Reflect.callMethod(Engine.instance, Reflect.field(Engine.instance, "notifySceneCreate"), [this]);
            }
        } catch (e:Dynamic) {}
        #end

        ScriptManager.call("onSceneCreate", [sceneName]);
        Logger.info('[SCENE] Initialized scene: $sceneName', "scene");
    }

    public function setupCameras():Void {
        camGame = new FlxCamera();
        camHUD = new FlxCamera();
        camOther = new FlxCamera();

        camHUD.bgColor.alpha = 0;
        camOther.bgColor.alpha = 0;

        FlxG.cameras.reset(camGame);
        FlxG.cameras.add(camHUD, false);
        FlxG.cameras.add(camOther, false);
        FlxG.cameras.setDefaultDrawTarget(camGame, true);
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (Scheduler.instance != null) Scheduler.instance.update(elapsed);

        #if !macro
        try {
            if (Achievements.instance != null) {
                Reflect.callMethod(Achievements.instance, Reflect.field(Achievements.instance, "update"), [elapsed]);
            }
        } catch (e:Dynamic) {}
        #end

        updateConductorTrackers();
        ScriptManager.call("onSceneUpdate", [elapsed]);
    }

    private function updateConductorTrackers():Void {
        curStep = Conductor.curStep;
        curBeat = Conductor.curBeat;
        curMeasure = Conductor.curMeasure;

        if (curStep != _lastStep) {
            _lastStep = curStep;
            stepHit(curStep);
            ScriptManager.call("onStepHit", [curStep]);
        }

        if (curBeat != _lastBeat) {
            _lastBeat = curBeat;
            beatHit(curBeat);
            ScriptManager.call("onBeatHit", [curBeat]);
        }

        if (curMeasure != _lastMeasure) {
            _lastMeasure = curMeasure;
            measureHit(curMeasure);
            ScriptManager.call("onMeasureHit", [curMeasure]);
        }
    }

    public function stepHit(step:Int):Void {}
    public function beatHit(beat:Int):Void {}
    public function measureHit(measure:Int):Void {}

    public function switchScene(nextScene:FlxState, fadeOutTime:Float = 0.35):Void {
        if (isTransitioning) return;
        isTransitioning = true;
        controlsEnabled = false;

        EventBus.publish("scene_switch", {current: sceneName, target: Type.getClassName(Type.getClass(nextScene))});

        if (fadeOutTime > 0 && camOther != null) {
            camOther.fade(FlxColor.BLACK, fadeOutTime, false, function() {
                executeSceneChange(nextScene);
            });
        } else {
            executeSceneChange(nextScene);
        }
    }

    private function executeSceneChange(nextScene:FlxState):Void {
        #if !macro
        try {
            if (Engine.instance != null && Std.isOfType(nextScene, Scene)) {
                Reflect.callMethod(Engine.instance, Reflect.field(Engine.instance, "notifySceneSwitch"), [nextScene]);
            }
        } catch (e:Dynamic) {}
        #end
        FlxG.switchState(nextScene);
    }

    public function openSubScene(subScene:FlxSubState):Void {
        if (!controlsEnabled) return;
        controlsEnabled = false;
        subScene.cameras = [camOther];
        openSubState(subScene);
    }

    public function closeSubScene():Void {
        controlsEnabled = true;
        closeSubState();
    }

    override public function destroy():Void {
        ScriptManager.call("onSceneDestroy", [sceneName]);

        try {
            EventBus.instance.offTarget(this);
        } catch (e:Dynamic) {}

        if (NotificationManager.instance != null) {
            remove(NotificationManager.instance);
        }

        Logger.info('[SCENE] Destroyed scene: $sceneName', "scene");
        super.destroy();
    }
}