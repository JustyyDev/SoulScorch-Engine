package soulscorch.core;

import flixel.FlxG;
import openfl.events.UncaughtErrorEvent;
import openfl.Lib;
import soulscorch.ui.menus.TitleState;

class Runtime {
    public static var engine(default, null):Engine;

    public static function bootstrap(config:GameConfig):Engine {
        engine = Engine.boot(config);
        engine.init();

        FlxG.save.bind("soulscorch_system");
        FlxG.fixedTimestep = false;
        FlxG.updateFramerate = config.framerate;
        FlxG.drawFramerate = config.framerate;
        FlxG.autoPause = false;
        FlxG.mouse.visible = false;
        
        FlxG.signals.preStateSwitch.add(engine.notifyStateSwitch);

        Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onCrash);

        return engine;
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