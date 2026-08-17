package soulscorch.menus.substate;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import soulscorch.backend.MusicBeatSubstate;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.input.Controls;
import soulscorch.gameplay.PlayState;
import soulscorch.menus.states.MainMenuState;

class PauseSubState extends MusicBeatSubstate {
    public static var curSelected:Int = 0;

    private var menuItems:Array<String> = ["Resume", "Restart Song", "Exit to Menu"];
    private var grpMenu:FlxTypedGroup<FlxText>;
    private var bg:FlxSprite;

    public function new() {
        super();

        bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        bg.alpha = 0.6;
        add(bg);

        grpMenu = new FlxTypedGroup<FlxText>();
        add(grpMenu);

        for (i in 0...menuItems.length) {
            var item = new FlxText(0, (i * 60) + 260, FlxG.width, menuItems[i], 32);
            item.setFormat(Paths.font("vcr"), 32, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
            item.borderSize = 2.0;
            item.ID = i;
            grpMenu.add(item);
        }

        changeSelection();
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (Controls.instance.UI_UP_P) changeSelection(-1);
        if (Controls.instance.UI_DOWN_P) changeSelection(1);

        if (Controls.instance.ACCEPT) {
            selectOption(menuItems[curSelected]);
        }
    }

    private function changeSelection(change:Int = 0):Void {
        curSelected = FlxMath.wrap(curSelected + change, 0, menuItems.length - 1);
        AssetHelper.playSoundSafely("scrollMenu", 0.7);

        for (item in grpMenu.members) {
            item.alpha = (item.ID == curSelected) ? 1.0 : 0.5;
        }
    }

    private function selectOption(option:String):Void {
        switch (option) {
            case "Resume":
                if (PlayState.instance != null) PlayState.instance.resumeSong();
                close();
            case "Restart Song":
                if (PlayState.instance != null) {
                    PlayState.instance.paused = false;
                    FlxG.resetState();
                }
            case "Exit to Menu":
                if (PlayState.instance != null) PlayState.instance.paused = false;
                MusicBeatState.switchState(new MainMenuState());
        }
    }
}