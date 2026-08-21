package soulscorch.ui.menus.substate;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import soulscorch.backend.MusicBeatSubstate;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.input.Controls;
import soulscorch.backend.system.modules.discord.DiscordRPC;
import soulscorch.backend.system.modules.workshop.HomeSoulDBModule;
import soulscorch.scripting.ScriptManager;
import soulscorch.scripting.mod.ModManager;
import soulscorch.scripting.mod.ModRegistry;
import soulscorch.scripting.mod.SoulGlobalScript;
import soulscorch.scripting.mod.SoulModData;
import soulscorch.ui.hud.Alphabet;
import soulscorch.ui.menus.editors.editorui.EditorTheme;
import soulscorch.ui.menus.states.HomeSoulState;

using StringTools;

class ModSwitchMenu extends MusicBeatSubstate {
    public static var curSelected:Int = 0;

    private var modList:Array<String> = [];
    private var grpRows:FlxTypedGroup<FlxSpriteGroup>;
    private var rowBgs:Array<FlxSprite> = [];
    private var statusPills:Array<FlxSprite> = [];
    private var modIcons:Array<FlxSprite> = [];

    private var bg:FlxSprite;
    private var inspectorPanel:FlxSpriteGroup;
    private var inspectorBg:FlxSprite;
    private var modTitleText:FlxText;
    private var authorText:FlxText;
    private var versionBadge:FlxText;
    private var descText:FlxText;
    private var priorityText:FlxText;
    private var pathText:FlxText;

    private var initialEnabledMods:Array<String> = [];
    private var hasChanges:Bool = false;
    private var targetListY:Float = 0.0;
    private var curListY:Float = 0.0;
    private var scripts:ScriptManager;

    override public function create():Void {
        super.create();

        this.persistentUpdate = false;
        this.persistentDraw = true;

        #if desktop
        DiscordRPC.changePresence("Mod Manager", "Configuring Mod Loadout");
        #end

        scripts = new ScriptManager();
        initModManagerScripts();

        bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        bg.alpha = 0.0;
        add(bg);
        FlxTween.tween(bg, {alpha: 0.85}, 0.35, {ease: FlxEase.quadOut});

        ModManager.reloadMods();
        modList = ModManager.allMods.copy();
        initialEnabledMods = ModRegistry.instance.enabledMods.copy();

        grpRows = new FlxTypedGroup<FlxSpriteGroup>();
        add(grpRows);

        var topBar = new FlxSprite(0, 0).makeGraphic(FlxG.width, 60, EditorTheme.PANEL_HEADER);
        topBar.scrollFactor.set(0, 0);
        add(topBar);

        var accentTag = new FlxSprite(25, 16).makeGraphic(4, 28, EditorTheme.ACCENT_CYAN);
        add(accentTag);

        var titleText = new FlxText(36, 17, 400, "SOULSCORCH // MOD REPOSITORY", 18);
        titleText.setFormat(Paths.font("vcr"), 18, EditorTheme.TEXT_PRIMARY, LEFT);
        add(titleText);

        var workshopBanner = new FlxText(FlxG.width - 440, 20, 400, "[TAB] Open HomeSoulDB Workshop", 14);
        workshopBanner.setFormat(Paths.font("vcr"), 14, EditorTheme.ACCENT_YELLOW, RIGHT);
        add(workshopBanner);

        setupInspectorPanel();

        var footer = new FlxSprite(0, FlxG.height - 45).makeGraphic(FlxG.width, 45, EditorTheme.PANEL_HEADER);
        add(footer);

        var helpText = new FlxText(0, FlxG.height - 32, FlxG.width, "[SPACE] Toggle  |  [W/S] Shift Priority  |  [TAB] Workshop  |  [SHIFT+S] Submit  |  [ESC] Save & Apply", 12);
        helpText.setFormat(Paths.font("vcr"), 12, EditorTheme.TEXT_MUTED, CENTER);
        add(helpText);

        rebuildList();
        changeSelection(0);

        if (scripts != null) scripts.callAll("onPostCreate");
    }

    private function initModManagerScripts():Void {
        var paths = [
            "data/scripts/substates/modmanager",
            "scripts/substates/modmanager",
            "data/scripts/modManagerSubstate"
        ];
        for (p in paths) {
            var file = soulscorch.backend.assets.AssetResolver.resolveFile(p, [".soul", ".hx", ".lua", ".py", ".js"]);
            if (file != null) scripts.loadScript(file);
        }
        scripts.setAll("substate", this);
        scripts.callAll("onCreate");
    }

    private function setupInspectorPanel():Void {
        inspectorPanel = new FlxSpriteGroup(FlxG.width - 430, 80);
        add(inspectorPanel);

        inspectorBg = new FlxSprite(0, 0).makeGraphic(400, FlxG.height - 145, EditorTheme.PANEL_BG);
        inspectorPanel.add(inspectorBg);

        var border = new FlxSprite(-1, -1).makeGraphic(402, FlxG.height - 143, EditorTheme.PANEL_BORDER);
        inspectorPanel.add(border);

        var head = new FlxSprite(0, 0).makeGraphic(400, 32, EditorTheme.PANEL_HEADER);
        inspectorPanel.add(head);

        var headTag = new FlxSprite(10, 8).makeGraphic(3, 16, EditorTheme.ACCENT_CYAN);
        inspectorPanel.add(headTag);

        var headTxt = new FlxText(20, 8, 300, "PACKAGE INSPECTOR", 12);
        headTxt.setFormat(Paths.font("vcr"), 12, EditorTheme.TEXT_PRIMARY, LEFT);
        inspectorPanel.add(headTxt);

        modTitleText = new FlxText(20, 48, 360, "", 20);
        modTitleText.setFormat(Paths.font("vcr"), 20, EditorTheme.ACCENT_CYAN, LEFT);
        inspectorPanel.add(modTitleText);

        versionBadge = new FlxText(20, 78, 360, "", 12);
        versionBadge.setFormat(Paths.font("vcr"), 12, EditorTheme.ACCENT_YELLOW, LEFT);
        inspectorPanel.add(versionBadge);

        authorText = new FlxText(20, 98, 360, "", 13);
        authorText.setFormat(Paths.font("vcr"), 13, EditorTheme.TEXT_MUTED, LEFT);
        inspectorPanel.add(authorText);

        priorityText = new FlxText(20, 122, 360, "", 13);
        priorityText.setFormat(Paths.font("vcr"), 13, EditorTheme.TEXT_PRIMARY, LEFT);
        inspectorPanel.add(priorityText);

        descText = new FlxText(20, 155, 360, "", 13);
        descText.setFormat(Paths.font("vcr"), 13, EditorTheme.TEXT_PRIMARY, LEFT);
        inspectorPanel.add(descText);

        pathText = new FlxText(20, inspectorBg.height - 40, 360, "", 11);
        pathText.setFormat(Paths.font("vcr"), 11, EditorTheme.TEXT_MUTED, LEFT);
        inspectorPanel.add(pathText);
    }

    private function rebuildList():Void {
        grpRows.clear();
        rowBgs = [];
        statusPills = [];
        modIcons = [];

        var rowW = FlxG.width - 480;

        for (i in 0...modList.length) {
            var modFolder = modList[i];
            var isEnabled = ModRegistry.instance.isEnabled(modFolder);

            var rowGroup = new FlxSpriteGroup(40, 80 + (i * 68));
            rowGroup.ID = i;

            var rBg = new FlxSprite(0, 0).makeGraphic(rowW, 58, EditorTheme.PANEL_BG);
            rowGroup.add(rBg);
            rowBgs.push(rBg);

            var rBorder = new FlxSprite(0, 57).makeGraphic(rowW, 1, EditorTheme.PANEL_BORDER);
            rowGroup.add(rBorder);

            var pill = new FlxSprite(14, 18).makeGraphic(6, 22, isEnabled ? EditorTheme.ACCENT_CYAN : EditorTheme.ACCENT_MAGENTA);
            rowGroup.add(pill);
            statusPills.push(pill);

            var iconSpr = new FlxSprite(32, 10);
            var iconLoaded = AssetHelper.loadGraphicSafely(iconSpr, 'mods/$modFolder/_icon');
            if (!iconLoaded) iconLoaded = AssetHelper.loadGraphicSafely(iconSpr, 'mods/$modFolder/icon');
            if (!iconLoaded) iconSpr.makeGraphic(38, 38, isEnabled ? 0x4400FFCC : 0x44FF0055);
            iconSpr.setGraphicSize(38, 38);
            iconSpr.updateHitbox();
            rowGroup.add(iconSpr);
            modIcons.push(iconSpr);

            var modNameText = new FlxText(80, 10, rowW - 190, modFolder, 16);
            modNameText.setFormat(Paths.font("vcr"), 16, EditorTheme.TEXT_PRIMARY, LEFT);
            rowGroup.add(modNameText);

            var stateLabel = new FlxText(rowW - 130, 20, 110, isEnabled ? "[ ACTIVE ]" : "[ DISABLED ]", 13);
            stateLabel.setFormat(Paths.font("vcr"), 13, isEnabled ? EditorTheme.ACCENT_CYAN : EditorTheme.ACCENT_MAGENTA, RIGHT);
            rowGroup.add(stateLabel);

            grpRows.add(rowGroup);
        }
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        if (scripts != null) scripts.callAll("onUpdate", [elapsed]);

        if (Controls.instance.UI_UP_P) changeSelection(-1);
        if (Controls.instance.UI_DOWN_P) changeSelection(1);

        if (FlxG.keys.justPressed.SPACE && modList.length > 0) {
            var targetMod = modList[curSelected];
            var nowActive = !ModRegistry.instance.isEnabled(targetMod);
            ModRegistry.instance.setEnabled(targetMod, nowActive);
            hasChanges = true;
            AssetHelper.playSoundSafely("scrollMenu", 0.7);
            rebuildList();
            changeSelection(0);
            if (scripts != null) scripts.callAll("onToggleMod", [targetMod, nowActive]);
        }

        if (FlxG.keys.justPressed.W && curSelected > 0) {
            var temp = modList[curSelected];
            modList[curSelected] = modList[curSelected - 1];
            modList[curSelected - 1] = temp;
            syncActiveModOrder();
            curSelected--;
            hasChanges = true;
            AssetHelper.playSoundSafely("scrollMenu", 0.7);
            rebuildList();
            changeSelection(0);
        }

        if (FlxG.keys.justPressed.S && !FlxG.keys.pressed.SHIFT && curSelected < modList.length - 1) {
            var temp = modList[curSelected];
            modList[curSelected] = modList[curSelected + 1];
            modList[curSelected + 1] = temp;
            syncActiveModOrder();
            curSelected++;
            hasChanges = true;
            AssetHelper.playSoundSafely("scrollMenu", 0.7);
            rebuildList();
            changeSelection(0);
        }

        if (FlxG.keys.justPressed.TAB) {
            AssetHelper.playSoundSafely("confirmMenu", 0.7);
            MusicBeatState.switchState(new HomeSoulState());
        }

        if (FlxG.keys.justPressed.S && FlxG.keys.pressed.SHIFT) {
            if (HomeSoulDBModule.instance != null) {
                HomeSoulDBModule.instance.openSubmissionPage();
            } else {
                FlxG.openURL("https://github.com/JustyyDev/HomeSoulDB/issues/new?template=mod_submission.yml");
            }
        }

        if (Controls.instance.BACK) {
            AssetHelper.playSoundSafely("confirmMenu", 0.7);
            applyAndExit();
        }

        targetListY = -(curSelected * 68) + (FlxG.height * 0.38) - 80;
        curListY = FlxMath.lerp(curListY, targetListY, FlxMath.bound(elapsed * 12.0, 0, 1));

        for (i in 0...grpRows.members.length) {
            var row = grpRows.members[i];
            var isCur = (i == curSelected);
            rowBgs[i].color = isCur ? EditorTheme.BTN_HOVER : EditorTheme.PANEL_BG;
            row.x = isCur ? 52 : 40;
            row.y = 80 + (i * 68) + curListY;
            row.alpha = isCur ? 1.0 : 0.55;
        }
    }

    private function syncActiveModOrder():Void {
        var newEnabled:Array<String> = [];
        for (mod in modList) {
            if (ModRegistry.instance.isEnabled(mod)) {
                newEnabled.push(mod);
            }
        }
        ModRegistry.instance.enabledMods = newEnabled;
    }

    private function applyAndExit():Void {
        ModRegistry.instance.saveConfig();
        ModManager.activeMods = ModRegistry.instance.enabledMods.copy();

        var currentActive = ModRegistry.instance.enabledMods;
        if (hasChanges || currentActive.length != initialEnabledMods.length) {
            Paths.clearStoredMemory();
            Paths.clearUnusedMemory();
            ModManager.reloadMods();
            SoulGlobalScript.init();
            FlxG.resetState();
        } else {
            close();
        }
    }

    private function changeSelection(change:Int = 0):Void {
        if (modList.length == 0) {
            modTitleText.text = "No Mods Installed";
            authorText.text = "";
            descText.text = "Place custom modifications into the engine's 'mods/' directory.";
            return;
        }

        curSelected = FlxMath.wrap(curSelected + change, 0, modList.length - 1);
        if (change != 0) AssetHelper.playSoundSafely("scrollMenu", 0.6);

        var curMod = modList[curSelected];
        var config:SoulModData = ModManager.modConfigs.get(curMod);
        var isEnabled = ModRegistry.instance.isEnabled(curMod);

        modTitleText.text = (config != null && config.name != null) ? config.name : curMod;
        versionBadge.text = 'VERSION: ' + ((config != null && config.version != null) ? config.version : "1.0.0");
        authorText.text = 'AUTHOR: ' + ((config != null && config.author != null) ? config.author : "Community Developer");
        priorityText.text = 'LOAD PRIORITY: #${curSelected + 1}  •  STATUS: ${isEnabled ? "ENABLED" : "DISABLED"}';
        descText.text = (config != null && config.description != null) ? config.description : "Standard SoulScorch module package.";
        pathText.text = 'Path: mods/$curMod/';

        if (scripts != null) scripts.callAll("onChangeModSelection", [curSelected, curMod]);
    }

    override public function destroy():Void {
        if (scripts != null) {
            scripts.callAll("onDestroy");
            scripts.clear();
        }
        super.destroy();
    }
}