package soulscorch.ui.menus.editors;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.util.FlxColor;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.input.Controls;
import soulscorch.backend.system.modules.discord.DiscordRPC;
import soulscorch.ui.hud.Alphabet;
import soulscorch.ui.menus.states.MainMenuState;

// Subpackage imports matching the directory structure
import soulscorch.ui.menus.editors.chart.ChartEditor;
import soulscorch.ui.menus.editors.character.CharacterEditorState;
import soulscorch.ui.menus.editors.stage.StageEditorState;
import soulscorch.ui.menus.editors.modchart.ModchartEditorState;

class EditorPickerMenu extends MusicBeatState {
    public static var curSelected:Int = 0;

    private var options:Array<String> = [
        "Chart Editor",
        "Character Editor",
        "Stage Editor",
        "Modchart Editor"
    ];

    private var grpOptions:FlxTypedGroup<Alphabet>;
    private var bg:FlxSprite;

    override public function create():Void {
        super.create();

        DiscordRPC.setEditorPresence("Editor Hub", "Selecting Tool");

        bg = new FlxSprite();
        AssetHelper.loadGraphicSafely(bg, "menuDesat");
        bg.color = 0xFF2A2D34;
        bg.screenCenter();
        bg.antialiasing = true;
        add(bg);

        grpOptions = new FlxTypedGroup<Alphabet>();
        add(grpOptions);

        for (i in 0...options.length) {
            var optText = new Alphabet(0, (70 * i) + 30, options[i], true);
            optText.isMenuItem = true;
            optText.targetY = i;
            optText.ID = i;
            grpOptions.add(optText);
        }

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
            selectOption(options[curSelected]);
        }

        for (i in 0...grpOptions.members.length) {
            var item = grpOptions.members[i];
            item.alpha = (i == curSelected ? 1.0 : 0.5);
        }
    }

    private function changeSelection(change:Int = 0):Void {
        curSelected = FlxMath.wrap(curSelected + change, 0, options.length - 1);
        AssetHelper.playSoundSafely("scrollMenu", 0.7);

        var bullShit:Int = 0;
        for (item in grpOptions.members) {
            item.targetY = bullShit - curSelected;
            bullShit++;
        }
    }

    private function selectOption(option:String):Void {
        AssetHelper.playSoundSafely("confirmMenu", 0.7);

        switch (option) {
            case "Chart Editor":
                MusicBeatState.switchState(new ChartEditor());
            case "Character Editor":
                MusicBeatState.switchState(new CharacterEditorState());
            case "Stage Editor":
                MusicBeatState.switchState(new StageEditorState());
            case "Modchart Editor":
                MusicBeatState.switchState(new ModchartEditorState());
            default:
                FlxG.camera.shake(0.01, 0.15);
        }
    }
}