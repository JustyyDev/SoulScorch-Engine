package soulscorch.system;

import flixel.FlxG;
import soulscorch.core.Runtime;

class HotReloader {
    public static function update():Void {
        #if sys
        if (FlxG.keys.justPressed.F5) {
            reloadEngineAssets();
        }
        #end
    }

    private static function reloadEngineAssets():Void {
        Sys.println("[HOT RELOAD] F5 pressed. Refreshing assets and scripts...");
        
        if (Runtime.engine != null) {
            var modLoader:Dynamic = Runtime.engine.resolve("modLoader");
            if (modLoader != null) {
                modLoader.scan();
            }
        }

        FlxG.sound.play('assets/sounds/scrollMenu.ogg', 0.8);
        
        if (FlxG.state != null) {
            FlxG.resetState();
        }
    }
}