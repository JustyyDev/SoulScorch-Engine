package soulscorch.ui.menus.editors;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.input.Controls;
import soulscorch.backend.input.MobilePad;
import soulscorch.backend.system.modules.discord.DiscordRPC;
import soulscorch.ui.hud.Alphabet;
import soulscorch.ui.menus.editors.CharacterEditorState;
import soulscorch.ui.menus.editors.ChartingState;
import soulscorch.ui.menus.editors.ModchartWorkspaceState;
import soulscorch.ui.menus.editors.StageEditorState;
import soulscorch.ui.menus.editors.XMSoulEditorState;
import soulscorch.ui.menus.editors.editorui.EditorTheme;
import soulscorch.ui.menus.states.MainMenuState;

#if sys
import sys.FileSystem;
#end

using StringTools;

typedef EditorOptionDef = {
    var title:String;
    var tag:String;
    var shortcut:String;
    var desc:String;
    var color:FlxColor;
    var details:Array<String>;
    @:optional var layoutPath:String;
    @:optional var onLaunch:Void->Void;
}

class EditorPickerMenu extends MusicBeatState {
    public static var curSelected:Int = 0;

    private var options:Array<EditorOptionDef> = [];

    private var grpCards:FlxTypedGroup<FlxSpriteGroup>;
    private var cardBgs:Array<FlxSprite> = [];
    private var cardBorders:Array<FlxSprite> = [];
    private var cardGlows:Array<FlxSprite> = [];

    private var bg:FlxSprite;
    private var descText:FlxText;
    private var detailsGroup:FlxSpriteGroup;
    private var detailsTitleText:FlxText;
    private var detailsListText:FlxText;
    private var detailsBox:FlxSprite;
    private var selectorArrow:FlxSprite;
    private var mobileControls:MobilePad;

    override public function create():Void {
        super.create();

        #if desktop
        DiscordRPC.changePresence("Developer Suite", "Browsing Engine Editors");
        #end

        buildEditorList();

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

        var topBar = new FlxSprite(0, 0).makeGraphic(FlxG.width, 64, EditorTheme.PANEL_HEADER);
        topBar.scrollFactor.set(0, 0);
        add(topBar);

        var topBarBorder = new FlxSprite(0, 63).makeGraphic(FlxG.width, 1, EditorTheme.PANEL_BORDER);
        topBarBorder.scrollFactor.set(0, 0);
        add(topBarBorder);

        var accentTag = new FlxSprite(25, 18).makeGraphic(4, 28, EditorTheme.ACCENT_CYAN);
        accentTag.scrollFactor.set(0, 0);
        add(accentTag);

        var headerTitle = new Alphabet(38, 14, "SOULSCORCH // CREATIVE STUDIO SUITE", false);
        headerTitle.scrollFactor.set(0, 0);
        add(headerTitle);

        var headerSubtitle = new FlxText(40, 40, 600, "NATIVE COMPILED EDITORS & MODULAR XMSOUL EXTENSIONS", 11);
        headerSubtitle.setFormat(Paths.font("vcr"), 11, EditorTheme.TEXT_MUTED, LEFT);
        headerSubtitle.scrollFactor.set(0, 0);
        add(headerSubtitle);

        // FNF-style selection arrow that points at the active editor card
        selectorArrow = new FlxSprite(0, 0);
        if (!AssetHelper.loadGraphicSafely(selectorArrow, "ui/menus/arrow")) {
            selectorArrow.makeGraphic(28, 18, EditorTheme.ACCENT_CYAN);
        }
        selectorArrow.scrollFactor.set(0, 0);
        add(selectorArrow);

        grpCards = new FlxTypedGroup<FlxSpriteGroup>();
        add(grpCards);

        cardBgs = [];
        cardBorders = [];
        cardGlows = [];

        var cardWidth:Float = (FlxG.width * 0.52);
        var cardHeight:Float = 110;
        var startY:Float = 88;

        for (i in 0...options.length) {
            var opt = options[i];
            var cardGroup = new FlxSpriteGroup(50, startY + (i * 125));
            cardGroup.ID = i;

            var glow = new FlxSprite(-2, -2).makeGraphic(Std.int(cardWidth + 4), Std.int(cardHeight + 4), opt.color);
            glow.alpha = 0.0;
            cardGroup.add(glow);
            cardGlows.push(glow);

            var border = new FlxSprite(-1, -1).makeGraphic(Std.int(cardWidth + 2), Std.int(cardHeight + 2), EditorTheme.PANEL_BORDER);
            cardGroup.add(border);
            cardBorders.push(border);

            var cardBg = new FlxSprite(0, 0).makeGraphic(Std.int(cardWidth), Std.int(cardHeight), EditorTheme.PANEL_BG);
            cardGroup.add(cardBg);
            cardBgs.push(cardBg);

            var tagBox = new FlxSprite(16, 14).makeGraphic(Std.int((opt.tag.length * 7.5) + 12), 18, EditorTheme.BTN_IDLE);
            cardGroup.add(tagBox);

            var tagTxt = new FlxText(20, 16, 200, opt.tag, 10);
            tagTxt.setFormat(Paths.font("vcr"), 10, opt.color, LEFT);
            cardGroup.add(tagTxt);

            var shortcutTxt = new FlxText(cardWidth - 50, 16, 40, opt.shortcut, 11);
            shortcutTxt.setFormat(Paths.font("vcr"), 11, EditorTheme.TEXT_MUTED, RIGHT);
            cardGroup.add(shortcutTxt);

            var title = new Alphabet(16, 38, opt.title, true);
            title.scale.set(0.75, 0.75);
            cardGroup.add(title);

            var subDesc = new FlxText(20, 82, cardWidth - 40, opt.desc, 11);
            subDesc.setFormat(Paths.font("vcr"), 11, EditorTheme.TEXT_MUTED, LEFT);
            cardGroup.add(subDesc);

            grpCards.add(cardGroup);
        }

        detailsGroup = new FlxSpriteGroup(FlxG.width - 450, 88);
        add(detailsGroup);

        var detailsBorder = new FlxSprite(-1, -1).makeGraphic(412, 487, EditorTheme.PANEL_BORDER);
        detailsGroup.add(detailsBorder);

        detailsBox = new FlxSprite(0, 0).makeGraphic(410, 485, EditorTheme.PANEL_BG);
        detailsGroup.add(detailsBox);

        var detailsHeader = new FlxSprite(0, 0).makeGraphic(410, 36, EditorTheme.PANEL_HEADER);
        detailsGroup.add(detailsHeader);

        var detailsHeaderTag = new FlxSprite(12, 10).makeGraphic(3, 16, EditorTheme.ACCENT_CYAN);
        detailsGroup.add(detailsHeaderTag);

        detailsTitleText = new FlxText(22, 9, 380, "STUDIO INSPECTOR", 14);
        detailsTitleText.setFormat(Paths.font("vcr"), 14, EditorTheme.TEXT_PRIMARY, LEFT);
        detailsGroup.add(detailsTitleText);

        detailsListText = new FlxText(20, 55, 370, "", 13);
        detailsListText.setFormat(Paths.font("vcr"), 13, EditorTheme.TEXT_PRIMARY, LEFT);
        detailsGroup.add(detailsListText);

        var footer = new FlxSprite(0, FlxG.height - 56).makeGraphic(FlxG.width, 56, EditorTheme.PANEL_HEADER);
        footer.scrollFactor.set(0, 0);
        add(footer);

        var footerBorder = new FlxSprite(0, FlxG.height - 56).makeGraphic(FlxG.width, 1, EditorTheme.PANEL_BORDER);
        footerBorder.scrollFactor.set(0, 0);
        add(footerBorder);

        descText = new FlxText(25, FlxG.height - 38, FlxG.width - 50, "", 13);
        descText.setFormat(Paths.font("vcr"), 13, EditorTheme.ACCENT_CYAN, LEFT);
        descText.scrollFactor.set(0, 0);
        add(descText);

        #if (mobile || debug)
        mobileControls = new MobilePad(FULL, A_B);
        add(mobileControls);
        Controls.instance.bindMobilePad(mobileControls);
        #end

        curSelected = FlxMath.wrap(curSelected, 0, options.length - 1);
        changeSelection(0);
        FlxG.mouse.visible = true;
    }

    private function buildEditorList():Void {
        options = [
            {
                title: "Chart Studio",
                tag: "NATIVE / TIMING",
                shortcut: "[1]",
                desc: "Full interactive 8-lane note timeline, hitsound feedback, and section mapping.",
                color: 0xFF00FFCC,
                details: [
                    "• 1/4 to 1/64 Beat Quantization Snaps",
                    "• Real-time Audio Hitsound Engine",
                    "• Section Lane Inverter & Rate Scaler",
                    "• Dual .xmsoul & JSON Direct Exporter"
                ],
                onLaunch: function() MusicBeatState.switchState(new ChartingState("tutorial", "normal"))
            },
            {
                title: "Actor Studio",
                tag: "NATIVE / OFFSETS",
                shortcut: "[2]",
                desc: "Character offset calibrator, animation matrices, frame scrubbers, and ghost overlays.",
                color: 0xFFFF0055,
                details: [
                    "• Live Animation Injector & Offset Calibrator",
                    "• Interactive World Camera Focus Anchors",
                    "• Microsecond Frame Scrubbing & Looping",
                    "• Native Character JSON Serializer"
                ],
                onLaunch: function() MusicBeatState.switchState(new CharacterEditorState("dad", false))
            },
            {
                title: "Stage Architect",
                tag: "NATIVE / PARALLAX",
                shortcut: "[3]",
                desc: "Layered stage layout builder, viewport anchors, drag-and-drop props, and parallax editors.",
                color: 0xFF8A3FFC,
                details: [
                    "• Direct Mouse Drag-and-Drop Viewport",
                    "• Multi-layer Parallax Scroll Factor Matrix",
                    "• Character Spawn Anchor Configurator",
                    "• Stage Prop Injection & Stage JSON Export"
                ],
                onLaunch: function() MusicBeatState.switchState(new StageEditorState("stage"))
            },
            {
                title: "Modchart Matrix",
                tag: "NATIVE / MATH",
                shortcut: "[4]",
                desc: "Visual real-time receptor modifier suite, math matrix curves, and live notes stream tests.",
                color: 0xFFFFD700,
                details: [
                    "• Drunk, Tipsy, Beat Pulse, Bumpy & Invert",
                    "• Live Oscillator Math & Curve Formatter",
                    "• Continuous Test Stream Trajectory Matrix",
                    "• SoulScript, Lua & HScript Exporter"
                ],
                onLaunch: function() MusicBeatState.switchState(new ModchartWorkspaceState())
            }
        ];

        #if sys
        var layoutDirs = ["config/ui/menus", "data/config/ui/menus"];
        for (dir in layoutDirs) {
            if (FileSystem.exists(dir) && FileSystem.isDirectory(dir)) {
                for (file in FileSystem.readDirectory(dir)) {
                    if (file.endsWith(".xmsoul")) {
                        var baseName = file.substr(0, file.length - 7);
                        var formattedTitle = baseName.substr(0, 1).toUpperCase() + baseName.substr(1);
                        var path = '$dir/$file';

                        options.push({
                            title: formattedTitle + " (XMSoul)",
                            tag: "MODULAR / XML",
                            shortcut: "[+]",
                            desc: 'Custom data-driven layout loaded from $path.',
                            color: 0xFF00FF99,
                            details: [
                                '• Layout: $file',
                                "• Dynamic XML Widget Binding",
                                "• HScript Integration",
                                "• Custom Modular Workspace"
                            ],
                            layoutPath: path
                        });
                    }
                }
            }
        }
        #end
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        var mx = FlxG.mouse.screenX;
        var my = FlxG.mouse.screenY;
        var cardWidth:Float = (FlxG.width * 0.52);

        for (i in 0...grpCards.members.length) {
            var card = grpCards.members[i];
            if (mx >= card.x && mx <= card.x + cardWidth && my >= card.y && my <= card.y + 110) {
                if (curSelected != i) {
                    curSelected = i;
                    changeSelection(0);
                    AssetHelper.playSoundSafely("scrollMenu", 0.4);
                }
                if (FlxG.mouse.justPressed) {
                    launchEditor(curSelected);
                    return;
                }
            }
        }

        if (Controls.instance.UI_UP_P) changeSelection(-1);
        if (Controls.instance.UI_DOWN_P) changeSelection(1);

        if (FlxG.keys.justPressed.ONE && options.length > 0) launchEditor(0);
        if (FlxG.keys.justPressed.TWO && options.length > 1) launchEditor(1);
        if (FlxG.keys.justPressed.THREE && options.length > 2) launchEditor(2);
        if (FlxG.keys.justPressed.FOUR && options.length > 3) launchEditor(3);

        if (Controls.instance.BACK) {
            AssetHelper.playSoundSafely("cancelMenu", 0.7);
            MusicBeatState.switchState(new MainMenuState());
        }

        if (Controls.instance.ACCEPT) {
            launchEditor(curSelected);
        }
    }

    private function changeSelection(change:Int = 0):Void {
        curSelected = FlxMath.wrap(curSelected + change, 0, options.length - 1);
        if (change != 0) AssetHelper.playSoundSafely("scrollMenu", 0.6);

        var curOpt = options[curSelected];

        for (i in 0...grpCards.members.length) {
            var card = grpCards.members[i];
            var isSel = (i == curSelected);

            var targetX = isSel ? 68.0 : 50.0;
            FlxTween.cancelTweensOf(card);
            FlxTween.tween(card, {x: targetX}, 0.2, {ease: FlxEase.cubeOut});

            cardBorders[i].color = isSel ? curOpt.color : EditorTheme.PANEL_BORDER;
            cardGlows[i].alpha = isSel ? 0.35 : 0.0;
            cardBgs[i].color = isSel ? EditorTheme.BTN_HOVER : EditorTheme.PANEL_BG;

            if (isSel) {
                selectorArrow.x = card.x - selectorArrow.width - 8;
                FlxTween.cancelTweensOf(selectorArrow);
                FlxTween.tween(selectorArrow, {y: card.y + (110 - selectorArrow.height) * 0.5}, 0.2, {ease: FlxEase.cubeOut});
            }
        }

        descText.text = '${curOpt.title.toUpperCase()} — ${curOpt.desc}';

        detailsTitleText.text = '${curOpt.title.toUpperCase()} SPECS';
        detailsTitleText.color = curOpt.color;

        var specBuffer = '${curOpt.desc}\n\nCORE CAPABILITIES:\n\n';
        for (d in curOpt.details) {
            specBuffer += d + '\n\n';
        }
        detailsListText.text = specBuffer;
    }

    private function launchEditor(index:Int):Void {
        AssetHelper.playSoundSafely("confirmMenu", 0.7);

        var targetOpt = options[index];
        if (targetOpt == null) return;

        if (targetOpt.onLaunch != null) {
            targetOpt.onLaunch();
        } else if (targetOpt.layoutPath != null && targetOpt.layoutPath.length > 0) {
            MusicBeatState.switchState(new XMSoulEditorState(targetOpt.layoutPath));
        }
    }

    override public function destroy():Void {
        Controls.instance.unbindMobilePad();
        super.destroy();
    }
}