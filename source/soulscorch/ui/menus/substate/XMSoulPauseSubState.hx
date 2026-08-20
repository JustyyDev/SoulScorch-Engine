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
        if (pauseConfig == null) return;

        var bgAlpha = XMSoul.getFloatAttr(pauseConfig, "bgAlpha", 0.7);
        var fontName = XMSoul.getAttr(pauseConfig, "font", "vcr");
        var itemSpacing = XMSoul.getFloatAttr(pauseConfig, "itemSpacing", 45);
        var startX = XMSoul.getFloatAttr(pauseConfig, "menuX", 80);
        var startY = XMSoul.getFloatAttr(pauseConfig, "menuY", 220);

        try {
            if (pauseConfig.hasNode != null && pauseConfig.hasNode.resolve("items")) {
                var itemsNode = pauseConfig.node.resolve("items");
                if (itemsNode != null && itemsNode.nodes != null) {
                    var parsedItems:Array<String> = [];
                    
                    for (item in itemsNode.nodes.resolve("item")) {
                        if (item != null) {
                            parsedItems.push(XMSoul.getAttr(item, "label", "Option"));
                        }
                    }

                    if (parsedItems.length > 0) {
                        // Modify parent class menuItems array safely
                        menuItems = parsedItems;
                        rebuildMenu();
                    }
                }
            }
        } catch (e:Dynamic) {
            // Fallback safely to parent defaults if xml structure mismatches
        }
    }
}