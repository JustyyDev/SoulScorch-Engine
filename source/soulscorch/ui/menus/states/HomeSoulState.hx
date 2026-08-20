package soulscorch.ui.menus.states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.ui.FlxBar;
import flixel.util.FlxColor;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.input.Controls;
import soulscorch.backend.input.MobilePad;
import soulscorch.backend.system.modules.discord.DiscordRPC;
import soulscorch.backend.system.modules.workshop.HomeSoulDBModule;
import soulscorch.ui.hud.Alphabet;
import soulscorch.ui.menus.editors.editorui.EditorTheme;
import soulscorch.ui.menus.editors.editorui.EditorToast;
import soulscorch.ui.menus.states.MainMenuState;

using StringTools;

class HomeSoulState extends MusicBeatState {
    public static var curSelected:Int = 0;

    private var entries:Array<SoulModEntry> = [];
    private var filteredEntries:Array<SoulModEntry> = [];
    private var categories:Array<String> = ["ALL", "RELEASED", "WIP", "CUSTOM WEEKS", "SHADERS"];
    private var curCategoryIdx:Int = 0;

    private var bg:FlxSprite;
    private var grpCards:FlxTypedGroup<FlxSpriteGroup>;
    private var cardBgs:Array<FlxSprite> = [];
    private var cardBorders:Array<FlxSprite> = [];

    // --- Side Inspector Panel ---
    private var sidePanel:FlxSpriteGroup;
    private var statusPill:FlxSprite;
    private var statusBadge:FlxText;
    private var modTitleText:FlxText;
    private var authorText:FlxText;
    private var descText:FlxText;
    private var statsText:FlxText;
    private var categoryTabsText:FlxText;
    private var loadingText:FlxText;

    private var downloadBarBG:FlxSprite;
    private var downloadBar:FlxBar;
    public var downloadProgress:Float = 0.0;
    private var isDownloading:Bool = false;
    private var mobileControls:MobilePad;

    private var curScrollY:Float = 0.0;
    private var targetScrollY:Float = 0.0;

    override public function create():Void {
        super.create();

        #if desktop
        DiscordRPC.changePresence("HomeSoulDB Workshop", "Browsing Community Packages");
        #end

        bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, EditorTheme.BG_DARK);
        bg.scrollFactor.set(0, 0);
        add(bg);

        var grid = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.TRANSPARENT);
        for (i in 0...Std.int(FlxG.width / 40)) {
            grid.pixels.fillRect(new openfl.geom.Rectangle(i * 40, 0, 1, FlxG.height), 0x08FFFFFF);
        }
        for (i in 0...Std.int(FlxG.height / 40)) {
            grid.pixels.fillRect(new openfl.geom.Rectangle(0, i * 40, FlxG.width, 1), 0x08FFFFFF);
        }
        grid.dirty = true;
        grid.scrollFactor.set(0, 0);
        add(grid);

        var topBar = new FlxSprite().makeGraphic(FlxG.width, 68, EditorTheme.PANEL_HEADER);
        topBar.scrollFactor.set(0, 0);
        add(topBar);

        var topBorder = new FlxSprite(0, 67).makeGraphic(FlxG.width, 1, EditorTheme.PANEL_BORDER);
        topBorder.scrollFactor.set(0, 0);
        add(topBorder);

        var accentTag = new FlxSprite(25, 18).makeGraphic(4, 28, EditorTheme.ACCENT_CYAN);
        add(accentTag);

        var header = new FlxText(38, 16, 450, "HOMESOULDB // WORKSHOP", 20);
        header.setFormat(Paths.font("vcr"), 20, EditorTheme.TEXT_PRIMARY, LEFT);
        add(header);

        var headerSub = new FlxText(38, 38, 450, "COMMUNITY REPOSITORY & ONLINE MOD INSTALLER", 11);
        headerSub.setFormat(Paths.font("vcr"), 11, EditorTheme.TEXT_MUTED, LEFT);
        add(headerSub);

        categoryTabsText = new FlxText(FlxG.width - 660, 24, 620, "", 14);
        categoryTabsText.setFormat(Paths.font("vcr"), 14, EditorTheme.TEXT_PRIMARY, RIGHT);
        add(categoryTabsText);

        grpCards = new FlxTypedGroup<FlxSpriteGroup>();
        add(grpCards);

        setupSidePanel();

        var footer = new FlxSprite(0, FlxG.height - 48).makeGraphic(FlxG.width, 48, EditorTheme.PANEL_HEADER);
        add(footer);

        var footerBorder = new FlxSprite(0, FlxG.height - 48).makeGraphic(FlxG.width, 1, EditorTheme.PANEL_BORDER);
        add(footerBorder);

        var helpText = new FlxText(0, FlxG.height - 32, FlxG.width, "[ENTER] Install Package  |  [B] Bump Mod  |  [Q / E] Category  |  [SHIFT+S] Submit Mod  |  [ESC] Back", 12);
        helpText.setFormat(Paths.font("vcr"), 12, EditorTheme.TEXT_MUTED, CENTER);
        add(helpText);

        loadingText = new FlxText(0, FlxG.height * 0.5 - 20, FlxG.width, "CONNECTING TO HOMESOULDB API...", 18);
        loadingText.setFormat(Paths.font("vcr"), 18, EditorTheme.ACCENT_YELLOW, CENTER);
        add(loadingText);

        #if (mobile || debug)
        mobileControls = new MobilePad(FULL, A_B);
        add(mobileControls);
        Controls.instance.bindMobilePad(mobileControls);
        #end

        add(new EditorToast());
        updateCategoryDisplay();
        requestCatalogData();
    }

    private function setupSidePanel():Void {
        sidePanel = new FlxSpriteGroup(FlxG.width - 440, 85);
        add(sidePanel);

        var panelBg = new FlxSprite(0, 0).makeGraphic(400, FlxG.height - 150, EditorTheme.PANEL_BG);
        sidePanel.add(panelBg);

        var panelBorder = new FlxSprite(-1, -1).makeGraphic(402, FlxG.height - 148, EditorTheme.PANEL_BORDER);
        sidePanel.add(panelBorder);

        var head = new FlxSprite(0, 0).makeGraphic(400, 32, EditorTheme.PANEL_HEADER);
        sidePanel.add(head);

        var headTag = new FlxSprite(10, 8).makeGraphic(3, 16, EditorTheme.ACCENT_CYAN);
        sidePanel.add(headTag);

        var headTxt = new FlxText(20, 8, 300, "MOD SPECIFICATIONS", 12);
        headTxt.setFormat(Paths.font("vcr"), 12, EditorTheme.TEXT_PRIMARY, LEFT);
        sidePanel.add(headTxt);

        statusPill = new FlxSprite(20, 48).makeGraphic(8, 8, FlxColor.GREEN);
        sidePanel.add(statusPill);

        statusBadge = new FlxText(34, 44, 340, "PLAYABLE RELEASE", 12);
        statusBadge.setFormat(Paths.font("vcr"), 12, FlxColor.GREEN, LEFT);
        sidePanel.add(statusBadge);

        modTitleText = new FlxText(20, 68, 360, "", 22);
        modTitleText.setFormat(Paths.font("vcr"), 22, EditorTheme.ACCENT_CYAN, LEFT);
        sidePanel.add(modTitleText);

        authorText = new FlxText(20, 100, 360, "", 13);
        authorText.setFormat(Paths.font("vcr"), 13, EditorTheme.TEXT_MUTED, LEFT);
        sidePanel.add(authorText);

        statsText = new FlxText(20, 124, 360, "", 12);
        statsText.setFormat(Paths.font("vcr"), 12, EditorTheme.ACCENT_YELLOW, LEFT);
        sidePanel.add(statsText);

        descText = new FlxText(20, 155, 360, "", 13);
        descText.setFormat(Paths.font("vcr"), 13, EditorTheme.TEXT_PRIMARY, LEFT);
        sidePanel.add(descText);

        downloadBarBG = new FlxSprite(20, sidePanel.height - 45).makeGraphic(360, 16, EditorTheme.PANEL_BORDER);
        downloadBarBG.visible = false;
        sidePanel.add(downloadBarBG);

        downloadBar = new FlxBar(downloadBarBG.x + 2, downloadBarBG.y + 2, LEFT_TO_RIGHT, 356, 12, this, 'downloadProgress', 0, 1);
        downloadBar.createFilledBar(0xFF221A30, EditorTheme.ACCENT_CYAN);
        downloadBar.visible = false;
        sidePanel.add(downloadBar);
    }

    private function requestCatalogData():Void {
        var db = HomeSoulDBModule.instance != null ? HomeSoulDBModule.instance : new HomeSoulDBModule(false);

        db.fetchCatalog(function(list:Array<SoulModEntry>) {
            if (list != null && list.length > 0) {
                entries = list;
                loadingText.visible = false;
                applyFilter();
            } else {
                loadingText.text = "COULD NOT CONNECT TO HOMESOULDB REPOSITORY";
                loadingText.color = EditorTheme.ACCENT_MAGENTA;
            }
        });
    }

    private function updateCategoryDisplay():Void {
        var textBuffer:String = "";
        for (i in 0...categories.length) {
            if (i == curCategoryIdx) {
                textBuffer += '[ ${categories[i]} ]  ';
            } else {
                textBuffer += '${categories[i]}   ';
            }
        }
        categoryTabsText.text = textBuffer;
    }

    private function applyFilter():Void {
        var activeCategory = categories[curCategoryIdx];
        filteredEntries = [];

        for (item in entries) {
            switch (activeCategory) {
                case "ALL": filteredEntries.push(item);
                case "RELEASED": if (!item.isWIP) filteredEntries.push(item);
                case "WIP": if (item.isWIP) filteredEntries.push(item);
                case "CUSTOM WEEKS": if (item.category == "Custom Weeks") filteredEntries.push(item);
                case "SHADERS": if (item.category == "Visual Shaders") filteredEntries.push(item);
            }
        }

        rebuildList();
        changeSelection(0);
    }

    private function rebuildList():Void {
        grpCards.clear();
        cardBgs = [];
        cardBorders = [];

        var cardWidth = FlxG.width - 490;

        for (i in 0...filteredEntries.length) {
            var item = filteredEntries[i];
            var cardGroup = new FlxSpriteGroup(40, (i * 72) + 85);
            cardGroup.ID = i;

            var cBg = new FlxSprite(0, 0).makeGraphic(cardWidth, 62, EditorTheme.PANEL_BG);
            cardGroup.add(cBg);
            cardBgs.push(cBg);

            var cBorder = new FlxSprite(0, 61).makeGraphic(cardWidth, 1, EditorTheme.PANEL_BORDER);
            cardGroup.add(cBorder);
            cardBorders.push(cBorder);

            var tag = new FlxText(16, 12, 200, item.isWIP ? "• WORK IN PROGRESS" : '• v${item.version}', 11);
            tag.setFormat(Paths.font("vcr"), 11, item.isWIP ? EditorTheme.ACCENT_MAGENTA : EditorTheme.ACCENT_CYAN, LEFT);
            cardGroup.add(tag);

            var title = new FlxText(16, 28, cardWidth - 120, item.title, 18);
            title.setFormat(Paths.font("vcr"), 18, EditorTheme.TEXT_PRIMARY, LEFT);
            cardGroup.add(title);

            var author = new FlxText(cardWidth - 210, 24, 190, 'by ${item.author}', 13);
            author.setFormat(Paths.font("vcr"), 13, EditorTheme.TEXT_MUTED, RIGHT);
            cardGroup.add(author);

            grpCards.add(cardGroup);
        }
    }

    private function changeSelection(change:Int = 0):Void {
        if (filteredEntries.length == 0) {
            modTitleText.text = "No Mods Available";
            authorText.text = "";
            statsText.text = "";
            descText.text = "Try cycling categories with [Q / E] to find community packages.";
            statusBadge.text = "";
            statusPill.visible = false;
            return;
        }

        curSelected = FlxMath.wrap(curSelected + change, 0, filteredEntries.length - 1);
        if (change != 0) AssetHelper.playSoundSafely("scrollMenu", 0.6);

        var entry = filteredEntries[curSelected];
        modTitleText.text = entry.title;
        authorText.text = 'AUTHOR: ${entry.author}  •  CATEGORY: ${entry.category}';
        statsText.text = '★ BUMPS: ${entry.bumpCount}   |   RATING SCORE: ${Math.round(entry.streamerScore * 10) / 10}';
        descText.text = entry.description;

        statusPill.visible = true;
        if (entry.isWIP) {
            statusPill.makeGraphic(8, 8, EditorTheme.ACCENT_MAGENTA);
            statusBadge.text = "WORK IN PROGRESS / TEASER";
            statusBadge.color = EditorTheme.ACCENT_MAGENTA;
        } else {
            statusPill.makeGraphic(8, 8, FlxColor.GREEN);
            statusBadge.text = "PLAYABLE RELEASE PACKAGE";
            statusBadge.color = FlxColor.GREEN;
        }

        targetScrollY = -(curSelected * 72) + (FlxG.height * 0.35) - 85;

        for (i in 0...grpCards.members.length) {
            var card = grpCards.members[i];
            var isCur = (i == curSelected);
            cardBgs[i].color = isCur ? EditorTheme.BTN_HOVER : EditorTheme.PANEL_BG;
            card.x = isCur ? 52 : 40;
            card.alpha = isCur ? 1.0 : 0.55;
        }
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        curScrollY = FlxMath.lerp(curScrollY, targetScrollY, FlxMath.bound(elapsed * 12.0, 0, 1));
        for (i in 0...grpCards.members.length) {
            grpCards.members[i].y = 85 + (i * 72) + curScrollY;
        }

        if (Controls.instance.UI_UP_P) changeSelection(-1);
        if (Controls.instance.UI_DOWN_P) changeSelection(1);

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

        if (Controls.instance.ACCEPT && filteredEntries.length > 0 && !isDownloading) {
            var entry = filteredEntries[curSelected];
            if (entry.isWIP) {
                if (entry.teaserUrl != null && entry.teaserUrl.length > 0) {
                    FlxG.openURL(entry.teaserUrl);
                }
            } else {
                isDownloading = true;
                downloadBarBG.visible = true;
                downloadBar.visible = true;
                downloadProgress = 0.25;
                EditorToast.show('Downloading: ${entry.title}...');

                HomeSoulDBModule.instance.downloadMod(entry, function(p) {
                    downloadProgress = p;
                }, function(success:Bool) {
                    isDownloading = false;
                    downloadProgress = 1.0;
                    downloadBarBG.visible = false;
                    downloadBar.visible = false;
                    if (success) {
                        EditorToast.show('Extracted ${entry.title} to /mods!');
                        AssetHelper.playSoundSafely("confirmMenu", 0.7);
                    } else {
                        EditorToast.show('Failed installing package!', true);
                    }
                    changeSelection(0);
                });
            }
        }

        if (FlxG.keys.justPressed.B && filteredEntries.length > 0) {
            var entry = filteredEntries[curSelected];
            entry.bumpCount++;
            entry.streamerScore += 1.5;
            AssetHelper.playSoundSafely("confirmMenu", 0.7);
            EditorToast.show('Bumped ${entry.title}!');
            changeSelection(0);
        }

        if (FlxG.keys.justPressed.S && FlxG.keys.pressed.SHIFT) {
            if (HomeSoulDBModule.instance != null) {
                HomeSoulDBModule.instance.openSubmissionPage();
            } else {
                FlxG.openURL("https://github.com/JustyyDev/HomeSoulDB/issues/new?template=mod_submission.yml");
            }
        }

        if (Controls.instance.BACK) {
            AssetHelper.playSoundSafely("cancelMenu", 0.7);
            MusicBeatState.switchState(new MainMenuState());
        }
    }

    override public function destroy():Void {
        Controls.instance.unbindMobilePad();
        super.destroy();
    }
}