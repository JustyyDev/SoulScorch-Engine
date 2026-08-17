package soulscorch.backend.system.engine;

import flixel.FlxG;
import soulscorch.backend.system.engine.GameConfig;
import soulscorch.ui.menus.states.TitleState;

class Runtime {
    public static var engine(default, null):Engine;
    public static var config(get, never):GameConfig;

    public static inline function get_config():GameConfig {
        return engine != null ? engine.config : null;
    }

    public static function bootstrap(cfg:GameConfig):Engine {
        CrashHandler.install();
        engine = Engine.boot(cfg);
        engine.init();
        return engine;
    }

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
        DevConsole.instance;
    }

    public static function setupInitialState():Void {
        FlxG.switchState(new TitleState());
    }
}