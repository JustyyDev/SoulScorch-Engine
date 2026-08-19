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
import soulscorch.backend.input.MobilePad;
import soulscorch.backend.system.modules.discord.DiscordRPC;
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
    private var bg:FlxSprite;
    private var descText:FlxText;
    private var mobileControls:MobilePad;

    private var descriptions:Array<String> = [
        "Edit note placements, BPM changes, and timing charts.",
        "Configure character sprites, Sparrow atlases, and animation offsets.",
        "Construct stage layouts, parallax backgrounds, and actor spawns.",
        "Program custom camera modcharts, receptor rotations, and lane shaders."
    ];

    override public function create():Void {
        super.create();

        #if desktop
        DiscordRPC.changePresence("Developer Suite", "Browsing Engine Editors");
        #end

        bg = new FlxSprite();
        if (!AssetHelper.loadGraphicSafely(bg, "menuDesat")) {
            bg.makeGraphic(FlxG.width, FlxG.height, 0xFF1B1424);
        }
        bg.color = 0xFF2A2035;
        bg.screenCenter();
        bg.antialiasing = true;
        add(bg);

        var titleBox = new FlxSprite(0, 0).makeGraphic(FlxG.width, 85, 0xEE0B0910);
        add(titleBox);

        var title = new Alphabet(0, 16, "SOULSCORCH EDITORS", true);
        title.screenCenter(X);
        add(title);

        grpOptions = new FlxTypedGroup<Alphabet>();
        add(grpOptions);

        for (i in 0...options.length) {
            var opt = new Alphabet(0, (i * 90) + 140, options[i], true);
            opt.isMenuItem = true;
            opt.targetY = i;
            opt.screenCenter(X);
            opt.ID = i;
            grpOptions.add(opt);
        }

        var descBox = new FlxSprite(0, FlxG.height - 65).makeGraphic(FlxG.width, 65, 0xEE0B0910);
        add(descBox);

        descText = new FlxText(20, FlxG.height - 44, FlxG.width - 40, "", 16);
        descText.setFormat(Paths.font("vcr"), 16, 0xFF00FFCC, CENTER, OUTLINE, FlxColor.BLACK);
        descText.borderSize = 1.0;
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
            selectOption(options[curSelected]);
        }
    }

    private function changeSelection(change:Int = 0):Void {
        curSelected = FlxMath.wrap(curSelected + change, 0, options.length - 1);
        AssetHelper.playSoundSafely("scrollMenu", 0.7);

        for (i in 0...grpOptions.members.length) {
            var item = grpOptions.members[i];
            item.targetY = i - curSelected;
            item.alpha = (i == curSelected ? 1.0 : 0.4);
        }

        descText.text = descriptions[curSelected];
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

    override public function destroy():Void {
        Controls.instance.unbindMobilePad();
        super.destroy();
    }
}