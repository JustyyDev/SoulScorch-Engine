package soulscorch.ui.menus;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import soulscorch.gameplay.PlayState;

class PauseSubState extends FlxSubState {
    var menuItems:Array<String> = ['Resume', 'Restart Song', 'Exit to Menu'];
    var grpMenuShit:Array<FlxText> = [];
    var curSelected:Int = 0;

    public function new() {
        super();

        var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        bg.alpha = 0.6;
        add(bg);

        for (i in 0...menuItems.length) {
            var text = new FlxText(20, 150 + (60 * i), 0, menuItems[i], 32);
            text.screenCenter(X);
            add(text);
            grpMenuShit.push(text);
        }

        changeSelection(0);
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (FlxG.keys.justPressed.UP) changeSelection(-1);
        if (FlxG.keys.justPressed.DOWN) changeSelection(1);

        if (FlxG.keys.justPressed.ENTER) {
            var daChoice = menuItems[curSelected];
            switch (daChoice) {
                case "Resume":
                    if (FlxG.sound.music != null) FlxG.sound.music.resume();
                    close();
                case "Restart Song":
                    FlxG.resetState();
                case "Exit to Menu":
                    if (FlxG.sound.music != null) FlxG.sound.music.stop();
                    FlxG.switchState(new TitleState());
            }
        }
    }

    function changeSelection(change:Int = 0):Void {
        curSelected += change;
        if (curSelected < 0) curSelected = menuItems.length - 1;
        if (curSelected >= menuItems.length) curSelected = 0;

        for (i in 0...grpMenuShit.length) {
            grpMenuShit[i].alpha = (i == curSelected) ? 1.0 : 0.6;
        }
    }
}