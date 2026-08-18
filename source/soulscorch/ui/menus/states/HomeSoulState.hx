package soulscorch.ui.menus.states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.input.Controls;
import soulscorch.backend.system.modules.discord.DiscordRPC;
import soulscorch.backend.system.modules.workshop.HomeSoulDBModule;
import soulscorch.ui.hud.Alphabet;

class HomeSoulState extends MusicBeatState {
    public static var curSelected:Int = 0;

    private var entries:Array<SoulModEntry> = [];
    private var filteredEntries:Array<SoulModEntry> = [];
    private var categories:Array<String> = ["ALL", "RELEASED", "WIP", "CUSTOM WEEKS", "SHADERS"];
    private var curCategoryIdx:Int = 0;

    private var bg:FlxSprite;
    private var grpCards:FlxTypedGroup<Alphabet>;
    private var grpTags:FlxTypedGroup<FlxText>;

    private var sidePanel:FlxSprite;
    private var statusPill:FlxSprite;
    private var statusBadge:FlxText;
    private var modTitleText:FlxText;
    private var authorText:FlxText;
    private var descText:FlxText;
    private var statsText:FlxText;
    private var categoryTabsText:FlxText;
    private var helpText:FlxText;
    private var loadingText:FlxText;

    private var isDownloading:Bool = false;

    override public function create():Void {
        super.create();

        #if (cpp && !neko)
        DiscordRPC.changePresence("Browsing HomeSoulDB", "Exploring community mods");
        #end

        bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF0D0B12);
        add(bg);

        var topBar = new FlxSprite().makeGraphic(FlxG.width, 65, 0xFF171320);
        add(topBar);

        var header = new FlxText(40, 18, 0, "HOMESOULDB WORKSHOP", 24);
        header.setFormat(Paths.font("vcr"), 24, 0xFF00FFCC, LEFT, OUTLINE, FlxColor.BLACK);
        header.borderSize = 1.5;
        add(header);

        categoryTabsText = new FlxText(FlxG.width - 620, 24, 580, "", 15);
        categoryTabsText.setFormat(Paths.font("vcr"), 15, 0xFFFFFFFF, RIGHT);
        add(categoryTabsText);

        grpCards = new FlxTypedGroup<Alphabet>();
        grpTags = new FlxTypedGroup<FlxText>();
        add(grpCards);
        add(grpTags);

        // Sidebar detail inspection card
        sidePanel = new FlxSprite(FlxG.width - 460, 85).makeGraphic(420, FlxG.height - 150, 0xEE161224);
        add(sidePanel);

        statusPill = new FlxSprite(sidePanel.x + 25, sidePanel.y + 25).makeGraphic(12, 12, FlxColor.GREEN);
        add(statusPill);

        statusBadge = new FlxText(sidePanel.x + 45, sidePanel.y + 22, sidePanel.width - 70, "PLAYABLE", 14);
        statusBadge.setFormat(Paths.font("vcr"), 14, FlxColor.GREEN, LEFT);
        add(statusBadge);

        modTitleText = new FlxText(sidePanel.x + 25, sidePanel.y + 55, sidePanel.width - 50, "", 22);
        modTitleText.setFormat(Paths.font("vcr"), 22, 0xFFFFCC00, LEFT);
        add(modTitleText);

        authorText = new FlxText(sidePanel.x + 25, sidePanel.y + 90, sidePanel.width - 50, "", 16);
        authorText.setFormat(Paths.font("vcr"), 16, 0xFF9A8CC8, LEFT);
        add(authorText);

        statsText = new FlxText(sidePanel.x + 25, sidePanel.y + 120, sidePanel.width - 50, "", 14);
        statsText.setFormat(Paths.font("vcr"), 14, 0xFF00FFAA, LEFT);
        add(statsText);

        descText = new FlxText(sidePanel.x + 25, sidePanel.y + 160, sidePanel.width - 50, "", 15);
        descText.setFormat(Paths.font("vcr"), 15, FlxColor.WHITE, LEFT);
        add(descText);

        helpText = new FlxText(0, FlxG.height - 45, FlxG.width, "[ENTER] Install / Open | [B] Bump Mod | [Q / E] Category | [S] Submit | [ESC] Back", 14);
        helpText.setFormat(Paths.font("vcr"), 14, 0xFF88829C, CENTER);
        add(helpText);

        loadingText = new FlxText(0, FlxG.height * 0.5 - 20, FlxG.width, "Fetching HomeSoulDB Catalog...", 20);
        loadingText.setFormat(Paths.font("vcr"), 20, FlxColor.YELLOW, CENTER);
        add(loadingText);

        updateCategoryDisplay();
        requestCatalogData();
    }

    private function requestCatalogData():Void {
        var db = HomeSoulDBModule.instance;
        if (db == null) {
            db = new HomeSoulDBModule(false);
        }

        db.fetchCatalog(function(list:Array<SoulModEntry>) {
            if (list != null && list.length > 0) {
                entries = list;
                loadingText.visible = false;
                applyFilter();
            } else {
                loadingText.text = "No mods found or network error.";
                loadingText.color = FlxColor.RED;
            }
        });
    }

    private function updateCategoryDisplay():Void {
        var textBuffer:String = "";
        for (i in 0...categories.length) {
            if (i == curCategoryIdx) {
                textBuffer += '[ ${categories[i]} ] ';
            } else {
                textBuffer += '${categories[i]}  ';
            }
        }
        categoryTabsText.text = textBuffer;
    }

    private function applyFilter():Void {
        var activeCategory = categories[curCategoryIdx];
        filteredEntries = [];

        for (item in entries) {
            switch (activeCategory) {
                case "ALL":
                    filteredEntries.push(item);
                case "RELEASED":
                    if (!item.isWIP) filteredEntries.push(item);
                case "WIP":
                    if (item.isWIP) filteredEntries.push(item);
                case "CUSTOM WEEKS":
                    if (item.category == "Custom Weeks") filteredEntries.push(item);
                case "SHADERS":
                    if (item.category == "Visual Shaders") filteredEntries.push(item);
            }
        }

        rebuildList();
        changeSelection(0);
    }

    private function rebuildList():Void {
        grpCards.clear();
        grpTags.clear();

        for (i in 0...filteredEntries.length) {
            var item = filteredEntries[i];
            var card = new Alphabet(0, (70 * i) + 110, item.title, true);
            card.scale.set(0.65, 0.65);
            card.isMenuItem = true;
            card.targetY = i;
            card.ID = i;
            grpCards.add(card);

            var tag = new FlxText(0, 0, 0, item.isWIP ? "WIP" : 'v${item.version}', 12);
            tag.setFormat(Paths.font("vcr"), 12, item.isWIP ? FlxColor.CYAN : FlxColor.GREEN, LEFT);
            tag.ID = i;
            grpTags.add(tag);
        }
    }

    private function changeSelection(change:Int = 0):Void {
        if (filteredEntries.length == 0) {
            modTitleText.text = "No Mods in Category";
            authorText.text = "";
            statsText.text = "";
            descText.text = "Try switching categories with [Q / E].";
            statusBadge.text = "";
            statusPill.visible = false;
            return;
        }

        curSelected = FlxMath.wrap(curSelected + change, 0, filteredEntries.length - 1);
        AssetHelper.playSoundSafely("scrollMenu", 0.7);

        var bullShit:Int = 0;
        for (item in grpCards.members) {
            item.targetY = bullShit - curSelected;
            bullShit++;
        }

        var entry = filteredEntries[curSelected];
        modTitleText.text = entry.title;
        authorText.text = 'Author: ${entry.author} • Category: ${entry.category}';
        statsText.text = 'Bumps: ${entry.bumpCount} | Streamer Score: ${Math.round(entry.streamerScore * 10) / 10}';
        descText.text = entry.description;

        statusPill.visible = true;
        if (entry.isWIP) {
            statusPill.makeGraphic(12, 12, FlxColor.CYAN);
            statusBadge.text = "WORK IN PROGRESS / TEASER";
            statusBadge.color = FlxColor.CYAN;
        } else {
            statusPill.makeGraphic(12, 12, FlxColor.GREEN);
            statusBadge.text = "PLAYABLE RELEASE";
            statusBadge.color = FlxColor.GREEN;
        }
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (Controls.instance.UI_UP_P) changeSelection(-1);
        if (Controls.instance.UI_DOWN_P) changeSelection(1);

        // Switch category tabs
        if (FlxG.keys.justPressed.Q) {
            curCategoryIdx = FlxMath.wrap(curCategoryIdx - 1, 0, categories.length - 1);
            curSelected = 0;
            updateCategoryDisplay();
            applyFilter();
            AssetHelper.playSoundSafely("scrollMenu", 0.7);
        } else if (FlxG.keys.justPressed.E) {
            curCategoryIdx = FlxMath.wrap(curCategoryIdx + 1, 0, categories.length - 1);
            curSelected = 0;
            updateCategoryDisplay();
            applyFilter();
            AssetHelper.playSoundSafely("scrollMenu", 0.7);
        }

        // Install playable mod or launch teaser page
        if (FlxG.keys.justPressed.ENTER && filteredEntries.length > 0 && !isDownloading) {
            var entry = filteredEntries[curSelected];
            if (entry.isWIP) {
                if (entry.teaserUrl != null && entry.teaserUrl.length > 0) {
                    FlxG.openURL(entry.teaserUrl);
                }
            } else {
                isDownloading = true;
                statsText.text = "DOWNLOADING PACKAGE...";
                HomeSoulDBModule.instance.downloadMod(entry, function(success:Bool) {
                    isDownloading = false;
                    changeSelection(0);
                });
            }
        }

        // Bump current mod
        if (FlxG.keys.justPressed.B && filteredEntries.length > 0) {
            var entry = filteredEntries[curSelected];
            entry.bumpCount++;
            entry.streamerScore += 1.5;
            AssetHelper.playSoundSafely("confirmMenu", 0.7);
            changeSelection(0);
        }

        // Open submission page
        if (FlxG.keys.justPressed.S && !FlxG.keys.pressed.CONTROL) {
            if (HomeSoulDBModule.instance != null) {
                HomeSoulDBModule.instance.openSubmissionPage();
            } else {
                FlxG.openURL("https://github.com/JustyyDev/HomeSoulDB/issues/new?template=mod_submission.yml");
            }
        }

        // Back to Mod Switch / Main Menu
        if (Controls.instance.BACK) {
            AssetHelper.playSoundSafely("confirmMenu", 0.7);
            FlxG.switchState(new soulscorch.ui.menus.states.MainMenuState());
        }

        for (i in 0...grpCards.members.length) {
            var card = grpCards.members[i];
            card.alpha = (i == curSelected ? 1.0 : 0.4);

            if (grpTags.members.length > i) {
                var tag = grpTags.members[i];
                tag.x = card.x + 20;
                tag.y = card.y + 45;
                tag.alpha = card.alpha;
            }
        }
    }
}