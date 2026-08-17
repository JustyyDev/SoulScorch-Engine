package soulscorch.ui.menus.editors;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.input.Controls;
import soulscorch.backend.system.modules.discord.DiscordRPC;
import soulscorch.menus.states.MainMenuState;
import soulscorch.ui.menus.editors.character.CharacterEditorState;
import soulscorch.ui.menus.editors.chart.ChartEditor;
import soulscorch.ui.menus.editors.modchart.ModchartEditorState;
import soulscorch.ui.menus.editors.stage.StageEditorState;

class EditorPickerMenu extends MusicBeatState {
    public static var curSelected:Int = 0;

    private var editors:Array<{name:String, desc:String}> = [
        {name: "Chart Editor", desc: "Place notes, sustain trails, BPM events, and song metadata."},
        {name: "Character Editor", desc: "Adjust animation frame alignments, offsets, and camera targets."},
        {name: "Stage Editor", desc: "Position 2D parallax layers, Stage3D models, and actor slots."},
        {name: "Modchart Editor", desc: "Graph and preview live strumline modifier eases and trajectories."}
    ];

    private var grpOptions:FlxTypedGroup<FlxText>;
    private var bg:FlxSprite;
    private var descBox:FlxSprite;
    private var descText:FlxText;

    override public function create():Void {
        super.create();

        DiscordRPC.changePresence("Editor Picker", "Selecting Development Tool");

        bg = new FlxSprite();
        AssetHelper.loadGraphicSafely(bg, "menus/menuDesat");
        bg.color = 0xFF282438;
        bg.screenCenter();
        bg.antialiasing = true;
        add(bg);

        var header = new FlxText(60, 40, FlxG.width - 120, "SOULSCORCH DEVELOPER SUITE", 36);
        header.setFormat(Paths.font("vcr"), 36, 0xFFFFCC00, LEFT, OUTLINE, FlxColor.BLACK);
        header.borderSize = 2.0;
        add(header);

        grpOptions = new FlxTypedGroup<FlxText>();
        add(grpOptions);

        for (i in 0...editors.length) {
            var item = new FlxText(80, (i * 70) + 150, FlxG.width - 160, editors[i].name, 32);
            item.setFormat(Paths.font("vcr"), 32, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
            item.borderSize = 2.0;
            item.ID = i;
            grpOptions.add(item);
        }

        descBox = new FlxSprite(0, FlxG.height - 85).makeGraphic(FlxG.width, 85, 0xDD0D111A);
        add(descBox);

        descText = new FlxText(20, FlxG.height - 68, FlxG.width - 40, "", 20);
        descText.setFormat(Paths.font("vcr"), 20, FlxColor.WHITE, CENTER);
        add(descText);

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
            switch (curSelected) {
                case 0: MusicBeatState.switchState(new ChartEditor());
                case 1: MusicBeatState.switchState(new CharacterEditorState());
                case 2: MusicBeatState.switchState(new StageEditorState());
                case 3: MusicBeatState.switchState(new ModchartEditorState());
            }
        }
    }

    private function changeSelection(change:Int = 0):Void {
        curSelected = FlxMath.wrap(curSelected + change, 0, editors.length - 1);
        AssetHelper.playSoundSafely("scrollMenu", 0.7);

        for (item in grpOptions.members) {
            item.alpha = (item.ID == curSelected) ? 1.0 : 0.45;
            item.x = (item.ID == curSelected) ? 110 : 80;
        }

        descText.text = editors[curSelected].desc;
    }
}