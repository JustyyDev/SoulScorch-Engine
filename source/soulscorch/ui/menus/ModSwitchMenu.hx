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
    var hintText:FlxText;
    var curSelected:Int = 0;
    // Index 0 is always the "Mods Disabled" entry; the rest map to ModManager.allMods
    var entryNames:Array<String> = [];

    override public function create():Void {
        super.create();

        bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        bg.alpha = 0.7;
        add(bg);

        var titleText = new FlxText(50, 40, 0, "MOD SWITCH MENU", 24);
        titleText.setFormat(null, 24, FlxColor.WHITE, LEFT);
        add(titleText);

        hintText = new FlxText(50, 70, 0, "UP/DOWN Select   ENTER Apply   R Reload   ESC Close", 14);
        hintText.setFormat(null, 14, 0xFFAAAAAA, LEFT);
        add(hintText);

        grpText = new FlxTypedGroup<FlxText>();
        add(grpText);

        reloadModList();
    }

    function reloadModList():Void {
        ModManager.reloadMods();
        rebuildList();
    }

    function rebuildList():Void {
        grpText.clear();

        entryNames = ["Mods Disabled"];
        for (mod in ModManager.allMods) entryNames.push(mod);

        for (i in 0...entryNames.length) {
            var displayStr:String;
            if (i == 0) {
                displayStr = "Mods Disabled";
            } else {
                var modName = entryNames[i];
                var config = ModManager.modConfigs.get(modName);
                displayStr = (config != null ? config.name : modName);
            }

            var isActive = (i == 0) ? (ModManager.selectedMod == null) : (ModManager.selectedMod == entryNames[i]);
            var txt = new FlxText(80, 120 + (i * 40), 0, (isActive ? "[ACTIVE] " : "") + displayStr, 24);
            txt.ID = i;
            grpText.add(txt);
        }

        if (curSelected >= entryNames.length) curSelected = 0;
        updateSelection();
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (FlxG.keys.justPressed.UP) {
            curSelected--;
            if (curSelected < 0) curSelected = entryNames.length - 1;
            updateSelection();
        }
        if (FlxG.keys.justPressed.DOWN) {
            curSelected++;
            if (curSelected >= entryNames.length) curSelected = 0;
            updateSelection();
        }

        if (FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE) {
            var chosen = (curSelected == 0) ? null : entryNames[curSelected];
            ModManager.setSelectedMod(chosen);
            rebuildList();
            if (NotificationManager.instance != null) {
                NotificationManager.instance.notify("Mod Selection Changed", chosen == null ? "Mods Disabled" : chosen);
            }
        }

        if (FlxG.keys.justPressed.R) {
            ModManager.reloadMods();
            reloadModList();
            if (NotificationManager.instance != null) {
                NotificationManager.instance.notify("Mods Reloaded", "Active mod list refreshed.");
            }
        }

        if (FlxG.keys.justPressed.ESCAPE || FlxG.keys.justPressed.BACKSPACE || FlxG.keys.justPressed.TAB) {
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