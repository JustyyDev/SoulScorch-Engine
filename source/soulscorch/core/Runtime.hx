package soulscorch.core;

import flixel.FlxG;
import openfl.events.UncaughtErrorEvent;
import openfl.Lib;
import soulscorch.ui.menus.TitleState;
import soulscorch.backend.CrashHandler;

class Runtime {
    public static var engine(default, null):Engine;

    public static function bootstrap(config:GameConfig):Engine {
        engine = Engine.boot(config);
        engine.init();
        CrashHandler.install();

        // Setup global crash handler early
        Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onCrash);

        return engine;
    }

    // Call this AFTER new FlxGame() is added to the stage
    public static function setupFlixel():Void {
        FlxG.save.bind("soulscorch_system");
        FlxG.fixedTimestep = false;
        
        if (engine.config != null) {
            FlxG.updateFramerate = engine.config.framerate;
            FlxG.drawFramerate = engine.config.framerate;
        }
        
        FlxG.autoPause = false;
        FlxG.mouse.visible = false;
        
        FlxG.signals.preStateSwitch.add(engine.notifyStateSwitch);
    }

    public static function setupInitialState():Void {
        FlxG.switchState(new TitleState());
    }

    private static function onCrash(e:UncaughtErrorEvent):Void {
        var errMsg:String = "";
        if (e.error != null) {
            errMsg = Std.string(e.error);
        }
        Sys.println("FATAL ENGINE CRASH: " + errMsg);
        Sys.exit(1);
    }
}