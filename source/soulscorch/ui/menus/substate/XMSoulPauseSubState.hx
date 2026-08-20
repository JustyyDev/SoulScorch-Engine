package soulscorch.ui.menus.substate;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import haxe.xml.Access;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.input.Controls;
import soulscorch.backend.system.XMSoul;
import soulscorch.gameplay.PlayState;

class XMSoulPauseSubState extends PauseSubState {
    private var pauseConfig:Access;
    private var menuItems:Array<String> = ["Resume", "Restart Song", "Toggle Botplay", "Exit to Menu"];
    private var menuActions:Array<String> = ["resume", "restart", "toggleBotplay", "exit"];
    private var grpMenuTexts:FlxTypedGroup<FlxText>;
    private var customBG:FlxSprite;

    override public function create():Void {
        super.create();

        pauseConfig = XMSoul.parse("config/ui/menus/pauseMenu");
        if (pauseConfig == null) pauseConfig = XMSoul.parse("data/ui/menus/pauseMenu");

        if (pauseConfig != null) {
            applyCustomPauseStyling();
        }
    }

    private function applyCustomPauseStyling():Void {
        var bgAlpha = XMSoul.getFloatAttr(pauseConfig, "bgAlpha", 0.7);
        var fontName = XMSoul.getAttr(pauseConfig, "font", "vcr");
        var itemSpacing = XMSoul.getFloatAttr(pauseConfig, "itemSpacing", 45);
        var startX = XMSoul.getFloatAttr(pauseConfig, "menuX", 80);
        var startY = XMSoul.getFloatAttr(pauseConfig, "menuY", 220);

        if (pauseConfig.hasNode.resolve("items")) {
            menuItems = [];
            menuActions = [];
            for (item in pauseConfig.hasNode.resolve("items").nodes.resolve("item")) {
                menuItems.push(XMSoul.getAttr(item, "label", "Option"));
                menuActions.push(XMSoul.getAttr(item, "action", "resume"));
            }
        }
    }
}