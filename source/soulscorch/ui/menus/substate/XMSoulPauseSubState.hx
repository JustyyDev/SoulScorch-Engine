package soulscorch.ui.menus.substate;

import flixel.FlxG;
import flixel.FlxSprite;
import haxe.xml.Access;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.system.XMSoul;
import soulscorch.backend.system.modules.discord.DiscordRPC;
import soulscorch.gameplay.PlayState;
import soulscorch.scripting.ScriptManager;

class XMSoulPauseSubState extends PauseSubState {
    private var pauseConfig:Access;
    private var pauseScripts:ScriptManager;

    override public function create():Void {
        super.create();

        #if desktop
        var songName = (PlayState.instance != null && PlayState.instance.songData != null) ? PlayState.instance.songData.title : PlayState.curSong;
        DiscordRPC.changePresence('Paused - ${songName.toUpperCase()}', '[ ${PlayState.curDifficulty.toUpperCase()} ]');
        #end

        pauseScripts = new ScriptManager();
        initSubStateScripts();

        pauseConfig = XMSoul.parse("config/ui/menus/pauseMenu");
        if (pauseConfig == null) pauseConfig = XMSoul.parse("data/ui/menus/pauseMenu");
        if (pauseConfig == null) pauseConfig = XMSoul.parse("data/ui/pauseMenu");

        if (pauseConfig != null) {
            applyCustomPauseStyling();
        }

        if (pauseScripts != null) pauseScripts.callAll("onPostCreate");
    }

    private function initSubStateScripts():Void {
        var paths = [
            "data/scripts/substates/pause",
            "scripts/substates/pause",
            "data/scripts/pauseSubstate"
        ];
        for (p in paths) {
            var file = AssetResolver.resolveFile(p, [".soul", ".hx", ".lua", ".py", ".js"]);
            if (file != null) pauseScripts.loadScript(file);
        }
        pauseScripts.setAll("substate", this);
        pauseScripts.callAll("onCreate");
    }

    private function applyCustomPauseStyling():Void {
        if (pauseConfig == null) return;

        try {
            var bgAlpha = XMSoul.getFloatAttr(pauseConfig, "bgAlpha", 0.72);
            if (bg != null) bg.alpha = bgAlpha;

            if (pauseConfig.hasNode.resolve("items")) {
                var itemsNode = pauseConfig.node.resolve("items");
                if (itemsNode != null) {
                    var parsedItems:Array<String> = [];
                    for (item in itemsNode.nodes.resolve("item")) {
                        if (item != null && item.has.resolve("label")) {
                            parsedItems.push(item.att.resolve("label"));
                        }
                    }

                    if (parsedItems.length > 0) {
                        menuItems = parsedItems;
                        rebuildMenu();
                    }
                }
            }
        } catch (e:Dynamic) {
            soulscorch.backend.utils.Logger.warn('Failed parsing custom pause style: $e', "pause");
        }
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        if (pauseScripts != null) pauseScripts.callAll("onUpdate", [elapsed]);
    }

    override public function destroy():Void {
        if (pauseScripts != null) {
            pauseScripts.callAll("onDestroy");
            pauseScripts.clear();
        }
        super.destroy();
    }
}