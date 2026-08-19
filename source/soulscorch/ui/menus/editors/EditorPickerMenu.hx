package soulscorch.ui.menus.editors;

import flixel.FlxG;
import flixel.FlxSprite;
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
import soulscorch.backend.input.MobilePad;
import soulscorch.backend.system.modules.discord.DiscordRPC;
import soulscorch.ui.hud.Alphabet;
import soulscorch.ui.menus.editors.CharacterEditorState;
import soulscorch.ui.menus.editors.ChartingState;
import soulscorch.ui.menus.editors.ModchartWorkspaceState;
import soulscorch.ui.menus.editors.StageEditorState;
import soulscorch.ui.menus.editors.editorui.EditorTheme;
import soulscorch.ui.menus.states.MainMenuState;

class EditorPickerMenu extends MusicBeatState {
    public static var curSelected:Int = 0;

    private var options:Array<String> = [
        "Chart Studio",
        "Actor Studio",
        "Stage Architect",
        "Modchart Matrix"
    ];

    private var descriptions:Array<String> = [
        "Interactive audio-synced node mapping with Codename/Psych event pipelines.",
        "Character offset calibrator, animation matrices, and canvas ghost overlays.",
        "Layered stage layout builder, viewport anchors, and multi-parallax editors.",
        "Visual real-time receptor modifier suite, math matrix curves, and live tests."
    ];

    private var grpCards:FlxTypedGroup<FlxSprite>;
    private var grpTexts:FlxTypedGroup<Alphabet>;
    private var bg:FlxSprite;
    private var descText:FlxText;
    private var mobileControls:MobilePad;

    override public function create():Void {
        super.create();

        #if desktop
        DiscordRPC.changePresence("Developer Suite", "Browsing Engine Editors");
        #end

        bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, EditorTheme.BG_DARK);
        add(bg);

        var gridLines = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, FlxColor.TRANSPARENT);
        for (i in 0...Std.int(FlxG.width / 40)) {
            gridLines.pixels.fillRect(new openfl.geom.Rectangle(i * 40, 0, 1, FlxG.height), 0x0CFFFFFF);
        }
        for (i in 0...Std.int(FlxG.height / 40)) {
            gridLines.pixels.fillRect(new openfl.geom.Rectangle(0, i * 40, FlxG.width, 1), 0x0CFFFFFF);
        }
        gridLines.dirty = true;
        add(gridLines);

        var topBar = new FlxSprite(0, 0).makeGraphic(FlxG.width, 70, EditorTheme.PANEL_HEADER);
        add(topBar);

        var accentTag = new FlxSprite(30, 20).makeGraphic(5, 30, EditorTheme.ACCENT_CYAN);
        add(accentTag);

        var headerTitle = new FlxText(45, 18, FlxG.width, "SOULSCORCH // CREATIVE STUDIO SUITE", 22);
        headerTitle.setFormat(Paths.font("vcr"), 22, EditorTheme.TEXT_PRIMARY, LEFT);
        add(headerTitle);

        grpCards = new FlxTypedGroup<FlxSprite>();
        add(grpCards);

        grpTexts = new FlxTypedGroup<Alphabet>();
        add(grpTexts);

        for (i in 0...options.length) {
            var card = new FlxSprite(80, 110 + (i * 115)).makeGraphic(FlxG.width - 160, 95, EditorTheme.PANEL_BG);
            card.ID = i;
            grpCards.add(card);

            var title = new Alphabet(110, 125 + (i * 115), options[i], true);
            title.ID = i;
            title.scale.set(0.8, 0.8);
            grpTexts.add(title);
        }

        var footer = new FlxSprite(0, FlxG.height - 60).makeGraphic(FlxG.width, 60, EditorTheme.PANEL_HEADER);
        add(footer);

        descText = new FlxText(30, FlxG.height - 42, FlxG.width - 60, "", 16);
        descText.setFormat(Paths.font("vcr"), 16, EditorTheme.ACCENT_CYAN, LEFT);
        add(descText);

        #if (mobile || debug)
        mobileControls = new MobilePad(FULL, A_B);
        add(mobileControls);
        Controls.instance.bindMobilePad(mobileControls);
        #end

        changeSelection();
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (Controls.instance.UI_UP_P) changeSelection(-1);
        if (Controls.instance.UI_DOWN_P) changeSelection(1);

        if (Controls.instance.BACK) {
            AssetHelper.playSoundSafely("cancelMenu", 0.7);
            MusicBeatState.switchState(new MainMenuState());
        }

        if (Controls.instance.ACCEPT) {
            AssetHelper.playSoundSafely("confirmMenu", 0.7);
            launchEditor(curSelected);
        }
    }

    private function changeSelection(change:Int = 0):Void {
        curSelected = FlxMath.wrap(curSelected + change, 0, options.length - 1);
        AssetHelper.playSoundSafely("scrollMenu", 0.7);

        for (card in grpCards.members) {
            var isSel = (card.ID == curSelected);
            card.color = isSel ? EditorTheme.PANEL_BORDER : EditorTheme.PANEL_BG;
            card.x = isSel ? 95 : 80;
        }

        for (text in grpTexts.members) {
            text.alpha = (text.ID == curSelected ? 1.0 : 0.4);
            text.x = (text.ID == curSelected ? 125 : 110);
        }

        descText.text = descriptions[curSelected];
    }

    private function launchEditor(index:Int):Void {
        switch (index) {
            case 0: MusicBeatState.switchState(new ChartingState("tutorial", "normal"));
            case 1: MusicBeatState.switchState(new CharacterEditorState("dad", false));
            case 2: MusicBeatState.switchState(new StageEditorState("stage"));
            case 3: MusicBeatState.switchState(new ModchartWorkspaceState());
        }
    }

    override public function destroy():Void {
        Controls.instance.unbindMobilePad();
        super.destroy();
    }
}