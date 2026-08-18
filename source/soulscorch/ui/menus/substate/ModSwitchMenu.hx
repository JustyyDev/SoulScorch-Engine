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
import soulscorch.backend.system.modules.workshop.HomeSoulDBModule;
import soulscorch.scripting.mod.ModManager;
import soulscorch.scripting.mod.ModRegistry;
import soulscorch.scripting.mod.SoulModData;
import soulscorch.ui.menus.states.HomeSoulState;
import soulscorch.ui.menus.states.TitleState;
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
    private var workshopBanner:FlxText;

    private var initialEnabledMods:Array<String> = [];
    private var hasChanges:Bool = false;

    override public function create():Void {
        super.create();

        // Lock down underlying menu input/updating
        if (_parentState != null) {
            _parentState.persistentUpdate = false;
            _parentState.persistentDraw = true;
        }

        bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        bg.alpha = 0.0;
        add(bg);
        FlxTween.tween(bg, {alpha: 0.8}, 0.4, {ease: FlxEase.quadOut});

        ModManager.reloadMods();
        modList = ModManager.allMods.copy();
        initialEnabledMods = ModRegistry.instance.enabledMods.copy();

        titleText = new FlxText(50, 30, 0, "SOULSCORCH MOD MANAGER", 24);
        titleText.setFormat(Paths.font("vcr"), 24, 0xFF00FFCC, LEFT, OUTLINE, FlxColor.BLACK);
        titleText.borderSize = 1.5;
        add(titleText);

        workshopBanner = new FlxText(FlxG.width - 450, 35, 400, "[TAB] Open HomeSoulDB Workshop", 16);
        workshopBanner.setFormat(Paths.font("vcr"), 16, 0xFFFFCC00, RIGHT, OUTLINE, FlxColor.BLACK);
        workshopBanner.borderSize = 1.2;
        add(workshopBanner);

        grpRows = new FlxTypedGroup<Alphabet>();
        grpStatusPills = new FlxTypedGroup<FlxSprite>();
        add(grpStatusPills);
        add(grpRows);

        sidePanel = new FlxSprite(FlxG.width - 440, 85).makeGraphic(390, FlxG.height - 170, 0xEE14101E);
        sidePanel.scrollFactor.set();
        add(sidePanel);

        modTitleText = new FlxText(sidePanel.x + 25, sidePanel.y + 20, sidePanel.width - 50, "", 22);
        modTitleText.setFormat(Paths.font("vcr"), 22, 0xFF6BFF8E, LEFT);
        add(modTitleText);

        authorText = new FlxText(sidePanel.x + 25, sidePanel.y + 55, sidePanel.width - 50, "", 16);
        authorText.setFormat(Paths.font("vcr"), 16, 0xFF9A8CC8, LEFT);
        add(authorText);

        descText = new FlxText(sidePanel.x + 25, sidePanel.y + 105, sidePanel.width - 50, "", 15);
        descText.setFormat(Paths.font("vcr"), 15, FlxColor.WHITE, LEFT);
        add(descText);

        helpText = new FlxText(0, FlxG.height - 45, FlxG.width, "[SPACE] Toggle | [W/S] Reorder | [TAB] HomeSoulDB | [SHIFT+S] Submit | [ESC] Apply & Restart", 14);
        helpText.setFormat(Paths.font("vcr"), 14, 0xFF88829C, CENTER);
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

        // Toggle Mod Status
        if (FlxG.keys.justPressed.SPACE && modList.length > 0) {
            var targetMod = modList[curSelected];
            var nowActive = !ModRegistry.instance.isEnabled(targetMod);
            ModRegistry.instance.setEnabled(targetMod, nowActive);
            hasChanges = true;
            AssetHelper.playSoundSafely("scrollMenu", 0.7);
            rebuildList();
            changeSelection();
        }

        // Priority Reordering
        if (FlxG.keys.justPressed.W && curSelected > 0) {
            var temp = modList[curSelected];
            modList[curSelected] = modList[curSelected - 1];
            modList[curSelected - 1] = temp;
            curSelected--;
            hasChanges = true;
            AssetHelper.playSoundSafely("scrollMenu", 0.7);
            rebuildList();
            changeSelection();
        }

        if (FlxG.keys.justPressed.S && !FlxG.keys.pressed.SHIFT && curSelected < modList.length - 1) {
            var temp = modList[curSelected];
            modList[curSelected] = modList[curSelected + 1];
            modList[curSelected + 1] = temp;
            curSelected++;
            hasChanges = true;
            AssetHelper.playSoundSafely("scrollMenu", 0.7);
            rebuildList();
            changeSelection();
        }

        // Workshop browser shortcut
        if (FlxG.keys.justPressed.TAB) {
            AssetHelper.playSoundSafely("confirmMenu", 0.7);
            FlxG.switchState(new HomeSoulState());
        }

        // Mod submission shortcut
        if (FlxG.keys.justPressed.S && FlxG.keys.pressed.SHIFT) {
            if (HomeSoulDBModule.instance != null) {
                HomeSoulDBModule.instance.openSubmissionPage();
            } else {
                FlxG.openURL("https://github.com/JustyyDev/HomeSoulDB/issues/new?template=mod_submission.yml");
            }
        }

        // Apply changes and reboot into the modded environment
        if (Controls.instance.BACK) {
            AssetHelper.playSoundSafely("confirmMenu", 0.7);
            applyAndRestart();
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

    private function applyAndRestart():Void {
        ModManager.activeMods = ModRegistry.instance.enabledMods.copy();

        var currentActive = ModRegistry.instance.enabledMods;
        if (hasChanges || currentActive.length != initialEnabledMods.length) {
            // Full engine asset & state reboot
            Paths.clearStoredMemory();
            Paths.clearUnusedMemory();
            ModManager.reloadMods();
            FlxG.resetGame();
        } else {
            if (_parentState != null) {
                _parentState.persistentUpdate = true;
            }
            close();
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