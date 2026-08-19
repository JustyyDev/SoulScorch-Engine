package soulscorch.backend.system.engine;

import flixel.FlxG;
import flixel.FlxState;
import flixel.math.FlxMath;
import openfl.Lib;
import openfl.display.StageAlign;
import openfl.display.StageScaleMode;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.system.SaveData;
import soulscorch.backend.system.engine.GameConfig;
import soulscorch.backend.utils.Logger;
import soulscorch.ui.menus.states.TitleState;

class Runtime {
    public static var engine(default, null):Engine;
    public static var config(get, never):GameConfig;
    public static var runningTime(default, null):Float = 0.0;
    public static var targetFramerate(get, set):Int;

    public static inline function get_config():GameConfig {
        return engine != null ? engine.config : null;
    }

    private static inline function get_targetFramerate():Int {
        return FlxG.drawFramerate;
    }

    private static inline function set_targetFramerate(value:Int):Int {
        FlxG.updateFramerate = value;
        FlxG.drawFramerate = value;
        return value;
    }

    public static function bootstrap(cfg:GameConfig):Engine {
        CrashHandler.install();
        engine = Engine.boot(cfg);
        engine.init();
        return engine;
    }

    public static function setupFlixel():Void {
        FlxG.save.bind("soulscorch_system");
        SaveData.instance.bind("soulscorch_scores");

        FlxG.fixedTimestep = false;
        FlxG.maxElapsed = 0.1;
        FlxG.autoPause = false;
        FlxG.mouse.visible = false;

        #if cpp
        cpp.vm.Gc.enable(true);
        #end

        if (engine != null && engine.config != null) {
            targetFramerate = engine.config.framerate;
        } else {
            targetFramerate = 120;
        }

        if (Lib.current != null && Lib.current.stage != null) {
            Lib.current.stage.scaleMode = StageScaleMode.NO_SCALE;
            Lib.current.stage.align = StageAlign.TOP_LEFT;
        }

        FlxG.signals.preStateSwitch.add(function() {
            if (engine != null) {
                engine.notifyStateSwitch();
            }
            Paths.clearUnusedMemory();
        });

        FlxG.signals.focusLost.add(onFocusLost);
        FlxG.signals.focusGained.add(onFocusGained);

        Logger.info("Flixel core environment configured successfully.", "runtime");
        DevConsole.instance;
    }

    public static function setupInitialState():Void {
        switchState(new TitleState());
    }

    public static function switchState(nextState:FlxState):Void {
        if (nextState == null) return;
        FlxG.switchState(nextState);
    }

    public static function update(elapsed:Float):Void {
        runningTime += elapsed;
    }

    private static function onFocusLost():Void {
        if (engine != null && engine.config != null) {
            // Focus loss handling
        }
    }

    private static function onFocusGained():Void {
        if (engine != null && engine.config != null) {
            // Focus gain handling
        }
    }

    public static function getMemoryUsage():Float {
        #if cpp
        return cpp.vm.Gc.memInfo(cpp.vm.Gc.MEM_INFO_USAGE) / (1024 * 1024);
        #else
        return 0.0;
        #end
    }

    public static function forceGC():Void {
        Paths.clearUnusedMemory();
    }
}