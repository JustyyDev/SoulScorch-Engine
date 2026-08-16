package soulscorch.core;

import flixel.FlxState;
import flixel.FlxG;
import flixel.FlxSubState;
import soulscorch.ui.DebugConsole;
import soulscorch.core.NotificationManager;
import soulscorch.core.Scheduler;

class Scene extends FlxState {
    public var curStep:Int = 0;
    public var curBeat:Int = 0;
    public var curMeasure:Int = 0;
    public var controlsEnabled:Bool = true;
    public var isTransitioning:Bool = false;

    public function new() {
        super();
    }

    override public function create():Void {
        super.create();
        if (DebugConsole.instance != null) {
            add(DebugConsole.instance);
        }
        if (NotificationManager.instance != null) {
            add(NotificationManager.instance);
        }
        Runtime.engine.onSceneCreate.dispatch(this);
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        if (Scheduler.instance != null) Scheduler.instance.update(elapsed);
        Runtime.engine.updateModules(elapsed);
    }

    // NotificationManager/DebugConsole are shared singletons re-added to every Scene; detach them here
    // instead of letting FlxState.destroy() cascade-destroy them, or every later scene using them would crash.
    override public function destroy():Void {
        if (NotificationManager.instance != null) remove(NotificationManager.instance);
        if (DebugConsole.instance != null) remove(DebugConsole.instance);
        super.destroy();
    }

    public function stepHit(step:Int):Void {
        curStep = step;
        if (curStep % 4 == 0) {
            beatHit(Math.floor(curStep / 4));
        }
    }

    public function beatHit(beat:Int):Void {
        curBeat = beat;
        if (curBeat % 4 == 0) {
            measureHit(Math.floor(curBeat / 4));
        }
    }

    public function measureHit(measure:Int):Void {
        curMeasure = measure;
    }

    public function switchScene(nextScene:Scene):Void {
        if (isTransitioning) return;
        isTransitioning = true;
        controlsEnabled = false;
        Runtime.engine.onSceneSwitch.dispatch(this);
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