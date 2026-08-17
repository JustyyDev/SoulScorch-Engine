package soulscorch.menus.substate;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import soulscorch.backend.MusicBeatSubstate;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.input.Controls;
import soulscorch.scripting.mod.ModManager;
import soulscorch.scripting.mod.ModRegistry;
import soulscorch.scripting.mod.SoulModData;

class ModSwitchMenu extends MusicBeatSubstate {
    public static var curSelected:Int = 0;

    private var modList:Array<String> = [];
    private var grpRows:FlxTypedGroup<FlxText>;
    private var grpCheckboxes:FlxTypedGroup<FlxSprite>;

    private var bg:FlxSprite;
    private var descBox:FlxSprite;
    private var descText:FlxText;
    private var authorText:FlxText;

    public function new() {
        super();

        bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xDD0C1017);
        add(bg);

        ModManager.reloadMods();
        modList = ModManager.allMods.copy();

        var title = new FlxText(40, 25, 0, "MOD MANAGER", 28);
        title.setFormat(Paths.font("vcr"), 28, 0xFFFFCC00, LEFT, OUTLINE, FlxColor.BLACK);
        add(title);

        grpRows = new FlxTypedGroup<FlxText>();
        grpCheckboxes = new FlxTypedGroup<FlxSprite>();
        add(grpCheckboxes);
        add(grpRows);

        descBox = new FlxSprite(FlxG.width - 420, 80).makeGraphic(380, FlxG.height - 160, 0xEE141C28);
        add(descBox);

        authorText = new FlxText(descBox.x + 20, descBox.y + 20, descBox.width - 40, "", 20);
        authorText.setFormat(Paths.font("vcr"), 20, 0xFF7AD1FF, LEFT);
        add(authorText);

        descText = new FlxText(descBox.x + 20, descBox.y + 60, descBox.width - 40, "", 16);
        descText.setFormat(Paths.font("vcr"), 16, FlxColor.WHITE, LEFT);
        add(descText);

        var help = new FlxText(20, FlxG.height - 40, FlxG.width - 40, "[SPACE] Toggle Mod | [W/S] Reorder Priority | [ESC] Apply & Exit", 16);
        help.setFormat(Paths.font("vcr"), 16, 0xFFAAAAAA, CENTER);
        add(help);

        rebuildList();
        changeSelection();
    }

    private function rebuildList():Void {
        grpRows.clear();
        grpCheckboxes.clear();

        for (i in 0...modList.length) {
            var modFolder = modList[i];
            var isEnabled = ModRegistry.instance.isEnabled(modFolder);

            var cb = new FlxSprite(50, (i * 50) + 90);
            cb.makeGraphic(24, 24, isEnabled ? 0xFF6BFF8E : 0xFFFF4444);
            cb.ID = i;
            grpCheckboxes.add(cb);

            var row = new FlxText(90, cb.y - 2, 0, modFolder, 24);
            row.setFormat(Paths.font("vcr"), 24, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
            row.borderSize = 1.5;
            row.ID = i;
            grpRows.add(row);
        }
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (Controls.instance.UI_UP_P) changeSelection(-1);
        if (Controls.instance.UI_DOWN_P) changeSelection(1);

        if (FlxG.keys.justPressed.SPACE && modList.length > 0) {
            var targetMod = modList[curSelected];
            var nowActive = !ModRegistry.instance.isEnabled(targetMod);
            ModRegistry.instance.setEnabled(targetMod, nowActive);
            AssetHelper.playSoundSafely("scrollMenu", 0.7);
            rebuildList();
            changeSelection();
        }

        // Shift priority up/down
        if (FlxG.keys.justPressed.W && curSelected > 0) {
            var temp = modList[curSelected];
            modList[curSelected] = modList[curSelected - 1];
            modList[curSelected - 1] = temp;
            curSelected--;
            AssetHelper.playSoundSafely("scrollMenu", 0.7);
            rebuildList();
            changeSelection();
        }

        if (FlxG.keys.justPressed.S && curSelected < modList.length - 1) {
            var temp = modList[curSelected];
            modList[curSelected] = modList[curSelected + 1];
            modList[curSelected + 1] = temp;
            curSelected++;
            AssetHelper.playSoundSafely("scrollMenu", 0.7);
            rebuildList();
            changeSelection();
        }

        if (Controls.instance.BACK) {
            ModManager.activeMods = ModRegistry.instance.enabledMods.copy();
            AssetHelper.playSoundSafely("confirmMenu", 0.7);
            close();
        }

        for (i in 0...grpRows.members.length) {
            var row = grpRows.members[i];
            var cb = grpCheckboxes.members[i];
            var targetY = ((i - curSelected) * 50) + (FlxG.height * 0.45);

            row.y = FlxMath.lerp(targetY, row.y, Math.exp(-elapsed * 14.0));
            cb.y = row.y + 2;

            row.alpha = (i == curSelected ? 1.0 : 0.4);
            cb.alpha = row.alpha;
        }
    }

    private function changeSelection(change:Int = 0):Void {
        if (modList.length == 0) return;
        curSelected = FlxMath.wrap(curSelected + change, 0, modList.length - 1);
        AssetHelper.playSoundSafely("scrollMenu", 0.7);

        var config:SoulModData = ModManager.modConfigs.get(modList[curSelected]);
        if (config != null) {
            authorText.text = '${config.name}\nv${config.version} by ${config.author}';
            descText.text = config.description;
        } else {
            authorText.text = modList[curSelected];
            descText.text = "Standard SoulScorch modification package.";
        }
    }
}