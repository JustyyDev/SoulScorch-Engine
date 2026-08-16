package soulscorch.ui.menus;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.sound.FlxSound;
import flixel.util.FlxColor;
import soulscorch.backend.MusicBeatSubstate;
import soulscorch.core.EventBus;
import soulscorch.core.Runtime;
import soulscorch.modding.ModManager;
import soulscorch.ui.Alphabet;
#if sys
import sys.FileSystem;
#end

class PauseSubState extends MusicBeatSubstate {
    var menuItems:Array<String> = ['Resume', 'Restart Song', 'Change Difficulty', 'Toggle Practice Mode', 'Exit to Menu'];
    var grpMenuShit:Array<Alphabet> = [];
    var curSelected:Int = 0;
    var overlay:FlxSprite;
    var fadeAlpha:Float = 0.0;
    var pauseMusic:FlxSound;

    public function new() {
        super();

        startPauseMusic();

        overlay = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        overlay.alpha = 0.0;
        add(overlay);

        for (i in 0...menuItems.length) {
            var text = new Alphabet(0, 120 + (50 * i), menuItems[i], true);
            text.scaleMultiplier = 0.5;
            text.screenCenter(X);
            text.ID = i;
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
            playMenuSound("sounds/menu/confirm");
            var daChoice = menuItems[curSelected];
            switch (daChoice) {
                case "Resume":
                    if (FlxG.sound.music != null) FlxG.sound.music.resume();
                    stopPauseMusic();
                    EventBus.publish("pause/resume", {});
                    close();
                case "Restart Song":
                    stopPauseMusic();
                    EventBus.publish("pause/restart", {});
                    FlxG.resetState();
                case "Change Difficulty":
                    EventBus.publish("pause/difficulty", {direction: 1});
                    updateLabels();
                case "Toggle Practice Mode":
                    if (Runtime.engine != null && Runtime.engine.config != null) {
                        Runtime.engine.config.botplay = !Runtime.engine.config.botplay;
                        Runtime.engine.config.save();
                    }
                    EventBus.publish("pause/practice", {enabled: Runtime.engine != null && Runtime.engine.config != null ? Runtime.engine.config.botplay : false});
                    updateLabels();
                case "Exit to Menu":
                    stopPauseMusic();
                    if (FlxG.sound.music != null) FlxG.sound.music.stop();
                    EventBus.publish("pause/exit", {});
                    FlxG.switchState(new TitleState());
            }
        }
    }

    function changeSelection(change:Int = 0):Void {
        if (change != 0) playMenuSound("sounds/menu/scroll");
        curSelected += change;
        if (curSelected < 0) curSelected = menuItems.length - 1;
        if (curSelected >= menuItems.length) curSelected = 0;

        for (i in 0...grpMenuShit.length) {
            grpMenuShit[i].alpha = (i == curSelected) ? 1.0 : 0.6;
            grpMenuShit[i].scale.set(1.0, 1.0);
        }
    }

    override public function beatHit(beat:Int):Void {
        for (text in grpMenuShit) if (text != null && text.ID == curSelected) text.scale.set(1.05, 1.05);
    }

    private function updateLabels():Void {
        if (grpMenuShit.length > 3) {
            var practice:Bool = Runtime.engine != null && Runtime.engine.config != null && Runtime.engine.config.botplay;
            grpMenuShit[3].text = practice ? "Practice Mode: ON" : "Practice Mode: OFF";
            grpMenuShit[3].screenCenter(X);
        }
    }

    private function playMenuSound(relativePath:String):Void {
        var path:String = ModManager.getPath(relativePath);
        #if sys
        if (path != null && FileSystem.exists(path)) FlxG.sound.play(path);
        #end
    }

    private function startPauseMusic():Void {
        var path:String = ModManager.getPath("music/pauseMenu.ogg");
        #if sys
        if (path == null || !FileSystem.exists(path)) path = ModManager.getPath("music/breakfast.ogg");
        if (path != null && FileSystem.exists(path)) {
            pauseMusic = FlxG.sound.load(path);
            if (pauseMusic != null) {
                pauseMusic.looped = true;
                pauseMusic.volume = 0.0;
                pauseMusic.play();
                pauseMusic.fadeIn(0.8, 0.0, 0.35);
            }
        }
        #end
    }

    private function stopPauseMusic():Void {
        if (pauseMusic != null) {
            pauseMusic.stop();
            pauseMusic.destroy();
            pauseMusic = null;
        }
    }
}