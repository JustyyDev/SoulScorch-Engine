package soulscorch.menus.substate;

import flixel.FlxG;
import flixel.FlxSprite;
import soulscorch.backend.MusicBeatSubstate;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.input.Controls;
import soulscorch.gameplay.PlayState;
import soulscorch.menus.states.MainMenuState;

class GameOverSubState extends MusicBeatSubstate {
    private var bfDead:FlxSprite;
    private var isEnding:Bool = false;

    public function new(x:Float, y:Float) {
        super();

        bfDead = new FlxSprite(x, y);
        AssetHelper.loadSparrowSafely(bfDead, "characters/BOYFRIEND_DEAD");
        bfDead.animation.addByPrefix("firstDeath", "BF dies", 24, false);
        bfDead.animation.addByPrefix("deathLoop", "BF Dead Loop", 24, true);
        bfDead.animation.addByPrefix("deathConfirm", "BF Dead Confirm", 24, false);
        bfDead.animation.play("firstDeath");
        bfDead.antialiasing = true;
        add(bfDead);

        AssetHelper.playSoundSafely("fnf_loss_sfx", 0.8);
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (bfDead.animation.curAnim.name == "firstDeath" && bfDead.animation.curAnim.finished) {
            bfDead.animation.play("deathLoop");
            FlxG.sound.playMusic(Paths.music("gameOver"), 0.7);
        }

        if (Controls.instance.ACCEPT && !isEnding) {
            isEnding = true;
            bfDead.animation.play("deathConfirm");
            FlxG.sound.music.stop();
            AssetHelper.playSoundSafely("gameOverEnd", 0.8);

            new flixel.util.FlxTimer().start(2.0, function(_) {
                if (PlayState.instance != null) PlayState.instance.paused = false;
                FlxG.resetState();
            });
        }

        if (Controls.instance.BACK && !isEnding) {
            isEnding = true;
            FlxG.sound.music.stop();
            if (PlayState.instance != null) PlayState.instance.paused = false;
            MusicBeatState.switchState(new MainMenuState());
        }
    }
}