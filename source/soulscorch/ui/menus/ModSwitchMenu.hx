package soulscorch.ui.menus;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import soulscorch.modding.ModManager;
import soulscorch.core.NotificationManager;

class ModSwitchMenu extends FlxSubState {
    var bg:FlxSprite;
    var grpText:FlxTypedGroup<FlxText>;
    var curSelected:Int = 0;

    override public function create():Void {
        super.create();

        bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        bg.alpha = 0.7;
        add(bg);

        var titleText = new FlxText(50, 50, 0, "MOD SWITCH MENU (Press R to Reload, ESC to Close)", 24);
        titleText.setFormat(null, 24, FlxColor.WHITE, LEFT);
        add(titleText);

        grpText = new FlxTypedGroup<FlxText>();
        add(grpText);

        reloadModList();
    }

    function reloadModList():Void {
        grpText.clear();
        ModManager.reloadMods();

        for (i in 0...ModManager.activeMods.length) {
            var modName = ModManager.activeMods[i];
            var config = ModManager.modConfigs.get(modName);
            var displayStr = (config != null ? config.name : modName);
            
            var txt = new FlxText(80, 120 + (i * 50), 0, "> " + displayStr, 24);
            txt.ID = i;
            grpText.add(txt);
        }
        updateSelection();
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (FlxG.keys.justPressed.UP) {
            curSelected--;
            if (curSelected < 0) curSelected = ModManager.activeMods.length - 1;
            updateSelection();
        }
        if (FlxG.keys.justPressed.DOWN) {
            curSelected++;
            if (curSelected >= ModManager.activeMods.length) curSelected = 0;
            updateSelection();
        }

        if (FlxG.keys.justPressed.R) {
            ModManager.reloadMods();
            reloadModList();
            if (NotificationManager.instance != null) {
                NotificationManager.instance.notify("Mods Reloaded", "Active mod list refreshed.");
            }
        }

        if (FlxG.keys.justPressed.ESCAPE || FlxG.keys.justPressed.BACKSPACE) {
            close();
        }
    }

    function updateSelection():Void {
        grpText.forEach(function(txt:FlxText) {
            if (txt.ID == curSelected) {
                txt.color = FlxColor.YELLOW;
            } else {
                txt.color = FlxColor.WHITE;
            }
        });
    }
}