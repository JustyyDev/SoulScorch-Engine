package soulscorch.backend.system;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxState;
import soulscorch.graphics.shaders.SoulCamera;
import flixel.FlxSubState;
import flixel.util.FlxColor;
import haxe.xml.Access;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.interfaces.IBeatReceiver;
import soulscorch.backend.system.Achievements;
import soulscorch.backend.system.EventBus;
import soulscorch.backend.system.NotificationManager;
import soulscorch.backend.system.XMSoul;
import soulscorch.backend.system.engine.Engine;
import soulscorch.backend.utils.Logger;
import soulscorch.backend.utils.Scheduler;
import soulscorch.scripting.mod.SoulGlobalScript;

using StringTools;

class Scene extends FlxState implements IBeatReceiver {
    public var curStep:Int = 0;
    public var curBeat:Int = 0;
    public var curMeasure:Int = 0;

    public var controlsEnabled:Bool = true;
    public var isTransitioning:Bool = false;
    public var sceneName:String = "UnnamedScene";

    // Standard Multi-Camera Layout (Inherited by all sub-states)
    public var camGame:SoulCamera;
    public var camHUD:SoulCamera;
    public var camOther:SoulCamera;

    // Configurable Scene Parameters from .xmsoul
    public var defaultCamZoom:Float = 1.0;
    public var defaultCamAntialiasing:Bool = true;
    public var defaultBgColor:FlxColor = FlxColor.BLACK;
    public var enableBeatTracking:Bool = true;

    private var _lastBeat:Int = -1;
    private var _lastStep:Int = -1;
    private var _lastMeasure:Int = -1;

    public function new() {
        super();
        sceneName = Type.getClassName(Type.getClass(this)).split(".").pop();
    }

    override public function create():Void {
        loadSceneConfig();
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

        SoulGlobalScript.call("onStateSwitch", []);
        Logger.info('[SCENE] Initialized scene: $sceneName', "scene");
    }

    /**
     * Dynamically reads scene viewport configurations from config/scene.xmsoul if present.
     */
    public function loadSceneConfig():Void {
        var access:Access = XMSoul.parse("config/scene");
        if (access == null) access = XMSoul.parse("data/config/scene");

        if (access != null) {
            defaultCamZoom = XMSoul.getFloatAttr(access, "defaultZoom", 1.0);
            defaultCamAntialiasing = XMSoul.getBoolAttr(access, "antialiasing", true);
            enableBeatTracking = XMSoul.getBoolAttr(access, "beatTracking", true);

            var bgColStr = XMSoul.getAttr(access, "bgColor", "0xFF000000");
            var col = FlxColor.fromString(bgColStr);
            if (col != null) defaultBgColor = col;
        }
    }

    public function setupCameras():Void {
        camGame = new SoulCamera();
        camHUD = new SoulCamera();
        camOther = new SoulCamera();

        camGame.bgColor = defaultBgColor;
        camHUD.bgColor.alpha = 0;
        camOther.bgColor.alpha = 0;

        camGame.antialiasing = defaultCamAntialiasing;
        camHUD.antialiasing = defaultCamAntialiasing;
        camOther.antialiasing = defaultCamAntialiasing;

        camGame.zoom = defaultCamZoom;

        FlxG.cameras.reset(camGame);
        FlxG.cameras.add(camHUD, false);
        FlxG.cameras.add(camOther, false);
        FlxG.cameras.setDefaultDrawTarget(camGame, true);
    }

    override public function update(elapsed:Float):Void {
        SoulGlobalScript.call("onUpdate", [elapsed]);
        super.update(elapsed);

        if (Scheduler.instance != null) Scheduler.instance.update(elapsed);

        #if !macro
        try {
            if (Achievements.instance != null) {
                Reflect.callMethod(Achievements.instance, Reflect.field(Achievements.instance, "update"), [elapsed]);
            }
        } catch (e:Dynamic) {}
        #end

        if (enableBeatTracking) {
            updateConductorTrackers();
        }

        SoulGlobalScript.call("onUpdatePost", [elapsed]);
    }

    private function updateConductorTrackers():Void {
        curStep = Conductor.curStep;
        curBeat = Conductor.curBeat;
        curMeasure = Conductor.curMeasure;

        if (curStep != _lastStep) {
            _lastStep = curStep;
            stepHit(curStep);
            SoulGlobalScript.call("onStepHit", [curStep]);
        }

        if (curBeat != _lastBeat) {
            _lastBeat = curBeat;
            beatHit(curBeat);
            SoulGlobalScript.call("onBeatHit", [curBeat]);
        }

        if (curMeasure != _lastMeasure) {
            _lastMeasure = curMeasure;
            measureHit(curMeasure);
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