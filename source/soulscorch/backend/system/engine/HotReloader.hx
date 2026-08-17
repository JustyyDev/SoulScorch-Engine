package soulscorch.backend.system.engine;

import flixel.FlxG;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.system.EventBus;
import soulscorch.backend.system.NotificationManager;
import soulscorch.backend.utils.GameTime;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.ModLoader;

class HotReloader {
    public static function update():Void {
        #if sys
        if (FlxG.keys.justPressed.F5) {
            reloadEngineAssets();
        }
        #end
    }

    public static function reloadEngineAssets():Void {
        Logger.info("F5 pressed. Refreshing assets and script registry...");

        ModLoader.scan();

        EventBus.emit("engine/hotreload", {time: GameTime.now()});

        AssetHelper.playSoundSafely("scrollMenu", 0.8);

        if (NotificationManager.instance != null) {
            NotificationManager.instance.notify("Hot Reload", "Assets and scripts refreshed.");
        }

        if (FlxG.state != null) {
            FlxG.resetState();
        }
    }
}