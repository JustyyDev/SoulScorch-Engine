package soulscorch.backend.system.engine;

import flixel.FlxG;
import flixel.FlxState;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.system.EventBus;
import soulscorch.backend.utils.GameTime;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.ScriptManager;
import soulscorch.scripting.mod.ModManager;
import soulscorch.scripting.mod.SoulGlobalScript;
import soulscorch.ui.hud.Alphabet.AlphaCharacter;

class HotReloader {
    public static var enabled:Bool = true;
    public static var hotReloadCount:Int = 0;

    public static function update():Void {
        #if debug
        if (enabled && FlxG.keys.justPressed.F5) {
            reload();
        }
        #end
    }

    public static function reload():Void {
        if (!enabled) return;

        hotReloadCount++;
        Logger.info('Executing Engine HotReload (Sequence #$hotReloadCount)...', "engine");

        try {
            ModManager.reloadMods();
            SoulGlobalScript.init();

            AssetResolver.clearCache();
            AssetHelper.clearAtlasCache();
            Paths.clearStoredMemory();

            AlphaCharacter.cachedFrames = null;
            AlphaCharacter.cachedBoldFrames = null;

            try {
                var bus:Dynamic = EventBus;
                if (Reflect.hasField(bus, "publish")) {
                    bus.publish("engine/hotreload", {time: GameTime.now(), sequence: hotReloadCount});
                } else if (Reflect.hasField(bus, "emit")) {
                    bus.emit("engine/hotreload", {time: GameTime.now(), sequence: hotReloadCount});
                }
            } catch (e:Dynamic) {}

            if (FlxG.state != null) {
                var curStateClass:Class<FlxState> = cast Type.getClass(FlxG.state);
                if (curStateClass != null) {
                    var newState:FlxState = Type.createInstance(curStateClass, []);
                    if (newState != null) {
                        FlxG.switchState(newState);
                        Logger.info("Active state hot-swapped successfully.", "engine");
                    } else {
                        FlxG.resetState();
                    }
                } else {
                    FlxG.resetState();
                }
            }
        } catch (e:Dynamic) {
            Logger.error('Failed hot-reload sequence: $e', "engine");
        }
    }
}