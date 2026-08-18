package soulscorch.ui.menus.substate;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.MusicBeatSubstate;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.input.Controls;
import soulscorch.gameplay.PlayState;
import soulscorch.ui.menus.states.MainMenuState;

class GameOverSubState extends MusicBeatSubstate {
    private var bfDead:FlxSprite;
    private var bg:FlxSprite;
    private var isEnding:Bool = false;

    public function new(x:Float, y:Float) {
        super();

        bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        bg.alpha = 0.0;
        add(bg);
        FlxTween.tween(bg, {alpha: 0.85}, 0.7, {ease: FlxEase.quadOut});

        bfDead = new FlxSprite(x, y);
        AssetHelper.loadSparrowSafely(bfDead, "characters/BOYFRIEND_DEAD");
        if (bfDead.frames != null) {
            bfDead.animation.addByPrefix("firstDeath", "BF dies", 24, false);
            bfDead.animation.addByPrefix("deathLoop", "BF Dead Loop", 24, true);
            bfDead.animation.addByPrefix("deathConfirm", "BF Dead Confirm", 24, false);
            bfDead.animation.play("firstDeath");
        }
        bfDead.antialiasing = true;
        add(bfDead);

        AssetHelper.playSoundSafely("fnf_loss_sfx", 0.8);
        FlxG.camera.follow(bfDead, LOCKON, 0.06);
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (bfDead.animation != null && bfDead.animation.curAnim != null && bfDead.animation.curAnim.name == "firstDeath" && bfDead.animation.curAnim.finished) {
            bfDead.animation.play("deathLoop");
            FlxG.sound.playMusic(Paths.music("gameOver"), 0.7);
        }

        if (Controls.instance.ACCEPT && !isEnding) {
            isEnding = true;
            if (bfDead.animation != null && bfDead.animation.exists("deathConfirm")) {
                bfDead.animation.play("deathConfirm");
            }
            if (FlxG.sound.music != null) FlxG.sound.music.stop();
            AssetHelper.playSoundSafely("gameOverEnd", 0.8);

            new flixel.util.FlxTimer().start(2.0, function(_) {
                if (PlayState.instance != null) PlayState.instance.paused = false;
                FlxG.resetState();
            });
        }

        if (Controls.instance.BACK && !isEnding) {
            isEnding = true;
            if (FlxG.sound.music != null) FlxG.sound.music.stop();
            if (PlayState.instance != null) PlayState.instance.paused = false;
            MusicBeatState.switchState(new MainMenuState());
        }
    }
}