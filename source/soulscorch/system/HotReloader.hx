package soulscorch.system;

import flixel.FlxG;
import soulscorch.core.Runtime;
import soulscorch.core.Logger;
import soulscorch.core.EventBus;
import soulscorch.core.NotificationManager;

class HotReloader {
    public static function update():Void {
        #if sys
        if (FlxG.keys.justPressed.F5) {
            reloadEngineAssets();
        }
        #end
    }

    private static function reloadEngineAssets():Void {
        Logger.info("hotreload", "F5 pressed. Refreshing assets and scripts...");

        if (Runtime.engine != null) {
            var modLoader:Dynamic = Runtime.engine.resolve("modLoader");
            if (modLoader != null) {
                modLoader.scan();
            }
        }

        EventBus.publish("engine/hotreload", {time: soulscorch.core.GameTime.now()});

        FlxG.sound.play('assets/sounds/scrollMenu.ogg', 0.8);

        if (NotificationManager.instance != null) {
            NotificationManager.instance.notify("Hot Reload", "Assets and scripts refreshed.");
        }

        if (FlxG.state != null) {
            FlxG.resetState();
        }
    }
}