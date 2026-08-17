package soulscorch.backend.system.engine;

import soulscorch.backend.system.EventBus;
import soulscorch.backend.utils.GameTime;
import soulscorch.scripting.mod.ModLoader;

class HotReloader {
    public static var enabled:Bool = true;

    public static function update():Void {}

    public static function reload():Void {
        ModLoader.scan();
        EventBus.instance.emit("engine/hotreload", {time: GameTime.now()});
    }
}