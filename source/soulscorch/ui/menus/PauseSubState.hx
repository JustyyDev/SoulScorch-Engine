package soulscorch.ui.menus;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import soulscorch.backend.MusicBeatSubstate;
import soulscorch.core.EventBus;
import soulscorch.core.Runtime;
import soulscorch.modding.ModManager;
#if sys
import sys.FileSystem;
#end

class PauseSubState extends MusicBeatSubstate {
    var menuItems:Array<String> = ['Resume', 'Restart Song', 'Toggle Practice Mode', 'Exit to Menu'];
    var grpMenuShit:Array<FlxText> = [];
    var curSelected:Int = 0;
    var overlay:FlxSprite;
    var fadeAlpha:Float = 0.0;

    public function new() {
        super();

        overlay = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        overlay.alpha = 0.0;
        add(overlay);

        for (i in 0...menuItems.length) {
            var text = new FlxText(20, 140 + (52 * i), 0, menuItems[i], 28);
            text.screenCenter(X);
            add(text);
            grpMenuShit.push(text);
        }

        changeSelection(0);
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        fadeAlpha = Math.min(0.6, fadeAlpha + elapsed * 2.5);
        overlay.alpha = fadeAlpha;

        if (FlxG.keys.justPressed.UP) changeSelection(-1);
        if (FlxG.keys.justPressed.DOWN) changeSelection(1);

        if (FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE) {
            playMenuSound("sounds/confirmMenu");
            var daChoice = menuItems[curSelected];
            switch (daChoice) {
                case "Resume":
                    if (FlxG.sound.music != null) FlxG.sound.music.resume();
                    EventBus.publish("pause/resume", {});
                    close();
                case "Restart Song":
                    EventBus.publish("pause/restart", {});
                    FlxG.resetState();
                case "Toggle Practice Mode":
                    if (Runtime.engine != null && Runtime.engine.config != null) {
                        Runtime.engine.config.botplay = !Runtime.engine.config.botplay;
                        Runtime.engine.config.save();
                    }
                    EventBus.publish("pause/practice", {enabled: Runtime.engine != null && Runtime.engine.config != null ? Runtime.engine.config.botplay : false});
                    changeSelection();
                case "Exit to Menu":
                    if (FlxG.sound.music != null) FlxG.sound.music.stop();
                    EventBus.publish("pause/exit", {});
                    FlxG.switchState(new TitleState());
            }
        }
    }

    function changeSelection(change:Int = 0):Void {
        if (change != 0) playMenuSound("sounds/scrollMenu");
        curSelected += change;
        if (curSelected < 0) curSelected = menuItems.length - 1;
        if (curSelected >= menuItems.length) curSelected = 0;

        for (i in 0...grpMenuShit.length) {
            grpMenuShit[i].alpha = (i == curSelected) ? 1.0 : 0.6;
        }
    }

    override public function beatHit(beat:Int):Void {
        for (text in grpMenuShit) if (text != null && text.ID == curSelected) text.scale.set(1.05, 1.05);
    }

    private function playMenuSound(relativePath:String):Void {
        var path:String = ModManager.getPath(relativePath);
        #if sys
        if (path != null && FileSystem.exists(path)) FlxG.sound.play(path);
        #end
    }
}