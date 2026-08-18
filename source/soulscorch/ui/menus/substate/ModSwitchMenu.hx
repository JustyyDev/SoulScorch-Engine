package soulscorch.ui.menus.substate;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import soulscorch.backend.MusicBeatSubstate;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.input.Controls;
import soulscorch.scripting.mod.ModManager;
import soulscorch.scripting.mod.ModRegistry;
import soulscorch.scripting.mod.SoulModData;
import soulscorch.ui.hud.Alphabet;

class ModSwitchMenu extends MusicBeatSubstate {
    public static var curSelected:Int = 0;

    private var modList:Array<String> = [];
    private var grpRows:FlxTypedGroup<Alphabet>;
    private var grpStatusPills:FlxTypedGroup<FlxSprite>;

    private var bg:FlxSprite;
    private var sidePanel:FlxSprite;
    private var titleText:FlxText;
    private var modTitleText:FlxText;
    private var authorText:FlxText;
    private var descText:FlxText;
    private var helpText:FlxText;

    public function new() {
        super();

        // 1. Smooth backdrop fade
        bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        bg.alpha = 0.0;
        add(bg);
        FlxTween.tween(bg, {alpha: 0.8}, 0.4, {ease: FlxEase.quadOut});

        ModManager.reloadMods();
        modList = ModManager.allMods.copy();

        // 2. Header Title
        titleText = new FlxText(50, 30, 0, "SOULSCORCH MOD MANAGER", 24);
        titleText.setFormat(Paths.font("vcr"), 24, 0xFF00FFCC, LEFT, OUTLINE, FlxColor.BLACK);
        titleText.borderSize = 1.5;
        add(titleText);

        grpRows = new FlxTypedGroup<Alphabet>();
        grpStatusPills = new FlxTypedGroup<FlxSprite>();
        add(grpStatusPills);
        add(grpRows);

        // 3. Side Information Panel (Glassmorphism style)
        sidePanel = new FlxSprite(FlxG.width - 440, 90).makeGraphic(390, FlxG.height - 180, 0xEE14101E);
        sidePanel.scrollFactor.set();
        add(sidePanel);

        modTitleText = new FlxText(sidePanel.x + 25, sidePanel.y + 25, sidePanel.width - 50, "", 22);
        modTitleText.setFormat(Paths.font("vcr"), 22, 0xFF6BFF8E, LEFT);
        add(modTitleText);

        authorText = new FlxText(sidePanel.x + 25, sidePanel.y + 60, sidePanel.width - 50, "", 16);
        authorText.setFormat(Paths.font("vcr"), 16, 0xFF9A8CC8, LEFT);
        add(authorText);

        descText = new FlxText(sidePanel.x + 25, sidePanel.y + 110, sidePanel.width - 50, "", 15);
        descText.setFormat(Paths.font("vcr"), 15, FlxColor.WHITE, LEFT);
        add(descText);

        // 4. Bottom Help Bar
        helpText = new FlxText(0, FlxG.height - 45, FlxG.width, "[SPACE] Toggle Enabled  |  [W / S] Reorder Priority  |  [ESC] Apply & Exit", 15);
        helpText.setFormat(Paths.font("vcr"), 15, 0xFF88829C, CENTER);
        add(helpText);

        rebuildList();
        changeSelection();
    }

    private function rebuildList():Void {
        grpRows.clear();
        grpStatusPills.clear();

        for (i in 0...modList.length) {
            var modFolder = modList[i];
            var isEnabled = ModRegistry.instance.isEnabled(modFolder);

            var row = new Alphabet(0, (65 * i) + 110, modFolder, true);
            row.scale.set(0.65, 0.65);
            row.isMenuItem = true;
            row.targetY = i;
            row.ID = i;
            grpRows.add(row);

            // Glowing status indicator pill
            var pill = new FlxSprite();
            pill.makeGraphic(16, 16, isEnabled ? 0xFF6BFF8E : 0xFFFF4444);
            pill.ID = i;
            grpStatusPills.add(pill);
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
            row.alpha = (i == curSelected ? 1.0 : 0.4);

            if (grpStatusPills.members.length > i) {
                var pill = grpStatusPills.members[i];
                pill.x = row.x - 35;
                pill.y = row.y + 14;
                pill.alpha = row.alpha;
            }
        }
    }

    private function changeSelection(change:Int = 0):Void {
        if (modList.length == 0) return;
        curSelected = FlxMath.wrap(curSelected + change, 0, modList.length - 1);
        AssetHelper.playSoundSafely("scrollMenu", 0.7);

        var bullShit:Int = 0;
        for (item in grpRows.members) {
            item.targetY = bullShit - curSelected;
            bullShit++;
        }

        var config:SoulModData = ModManager.modConfigs.get(modList[curSelected]);
        if (config != null) {
            modTitleText.text = config.name;
            authorText.text = 'Version ${config.version} • By ${config.author}';
            descText.text = config.description;
        } else {
            modTitleText.text = modList[curSelected];
            authorText.text = "Internal Package";
            descText.text = "Standard SoulScorch modification package with no custom metadata config provided.";
        }
    }
}