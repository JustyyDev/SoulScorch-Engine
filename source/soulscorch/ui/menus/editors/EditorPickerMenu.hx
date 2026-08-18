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
import soulscorch.ui.hud.Alphabet;
import soulscorch.ui.menus.editors.CharacterEditorState;
import soulscorch.ui.menus.editors.ChartingState;
import soulscorch.ui.menus.editors.ModchartWorkspaceState;
import soulscorch.ui.menus.editors.StageEditorState;
import soulscorch.ui.menus.states.MainMenuState;

class EditorPickerMenu extends MusicBeatState {
    public static var curSelected:Int = 0;

    private var options:Array<String> = [
        "Chart Editor",
        "Character Editor",
        "Stage Editor",
        "Modchart Workspace"
    ];

    private var grpOptions:FlxTypedGroup<Alphabet>;

    override public function create():Void {
        super.create();

        var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF1B1424);
        add(bg);

        var title = new Alphabet(0, 40, "SOULSCORCH EDITORS", true);
        title.screenCenter(X);
        add(title);

        grpOptions = new FlxTypedGroup<Alphabet>();
        add(grpOptions);

        for (i in 0...options.length) {
            var opt = new Alphabet(0, (i * 90) + 160, options[i], true);
            opt.isMenuItem = true;
            opt.targetY = i;
            opt.screenCenter(X);
            opt.ID = i;
            grpOptions.add(opt);
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
            AssetHelper.playSoundSafely("confirmMenu", 0.7);
            selectOption(options[curSelected]);
        }
    }

    private function changeSelection(change:Int = 0):Void {
        curSelected = FlxMath.wrap(curSelected + change, 0, options.length - 1);
        AssetHelper.playSoundSafely("scrollMenu", 0.7);

        for (i in 0...grpOptions.members.length) {
            var item = grpOptions.members[i];
            item.targetY = i - curSelected;
            item.alpha = (i == curSelected ? 1.0 : 0.45);
        }
    }

    private function selectOption(option:String):Void {
        switch (option) {
            case "Chart Editor":
                MusicBeatState.switchState(new ChartingState("tutorial", "normal"));
            case "Character Editor":
                MusicBeatState.switchState(new CharacterEditorState("dad", false));
            case "Stage Editor":
                MusicBeatState.switchState(new StageEditorState("stage"));
            case "Modchart Workspace":
                MusicBeatState.switchState(new ModchartWorkspaceState());
            default:
                AssetHelper.playSoundSafely("cancelMenu", 0.7);
        }
    }
}