package soulscorch.backend.system.engine;

import flixel.FlxG;
import flixel.FlxState;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.MusicBeatTransition;
import soulscorch.backend.TransitionData;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.system.EventBus;
import soulscorch.backend.utils.GameTime;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.GlobalScriptManager;
import soulscorch.scripting.mod.ModLoader;
import soulscorch.scripting.mod.ModManager;
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
        if (!enabled || MusicBeatTransition.isTransitioning) return;

        hotReloadCount++;
        Logger.info('Executing Engine HotReload (Sequence #$hotReloadCount)...', "engine");

        try {
            ModLoader.scan();
            ModManager.reloadMods();

            AssetResolver.clearCache();
            AssetHelper.clearAtlasCache();
            if (AlphaCharacter.cachedFrames != null) {
                AlphaCharacter.cachedFrames = null;
            }
            FlxG.bitmap.dumpCache();

            if (GlobalScriptManager.instance != null) {
                GlobalScriptManager.instance.reload();
            }

            EventBus.instance.emit("engine/hotreload", {time: GameTime.now(), sequence: hotReloadCount});

            if (FlxG.state != null) {
                var curStateClass:Class<FlxState> = cast Type.getClass(FlxG.state);
                if (curStateClass != null) {
                    var newState:FlxState = Type.createInstance(curStateClass, []);
                    if (newState != null) {
                        MusicBeatState.switchState(newState, new TransitionData(FADE, OUT, 0.25));
                        Logger.info("[HOTRELOAD] Active state hot-swapped successfully.", "engine");
                    } else {
                        FlxG.resetState();
                    }
                } else {
                    FlxG.resetState();
                }
            }
        } catch (e:Dynamic) {
            Logger.error('[HOTRELOAD ERROR] Failed to complete hot-reload sequence: $e', "engine");
        }
    }
}