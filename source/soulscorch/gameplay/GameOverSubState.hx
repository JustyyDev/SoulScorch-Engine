package soulscorch.gameplay;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.sound.FlxSound;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import soulscorch.assets.AssetHelper;
import soulscorch.input.InputMap;
import soulscorch.ui.menus.MainMenuState;

class GameOverSubState extends FlxSubState {
    public static var instance:GameOverSubState;

    public var bf:FlxSprite;
    public var deathSound:FlxSound;
    public var music:FlxSound;
    public var endSound:FlxSound;

    var isEnding:Bool = false;
    var deathMusicName:String = "gameOver";
    var deathSoundName:String = "fnf_loss_sfx";
    var endSoundName:String = "gameOverEnd";

    public function new(x:Float, y:Float) {
        super();
        instance = this;

        bf = new FlxSprite(x, y);
        if (!AssetHelper.loadSparrowSafely(bf, "assets/images/characters/BOYFRIEND_DEAD.png", "assets/images/characters/BOYFRIEND_DEAD.xml")) {
            bf.makeGraphic(128, 128, FlxColor.RED);
        } else {
            bf.animation.addByPrefix('firstDeath', "BF dies", 24, false);
            bf.animation.addByPrefix('deathLoop', "BF Dead Loop", 24, true);
            bf.animation.addByPrefix('deathConfirm', "BF Dead confirm", 24, false);
            bf.animation.play('firstDeath');
        }
        bf.antialiasing = true;
        add(bf);

        Conductor.songPosition = 0;
        deathSound = AssetHelper.playSoundSafely('assets/sounds/$deathSoundName.ogg', 1.0);

        FlxG.camera.target = bf;
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (bf.animation.getByName('firstDeath') != null && bf.animation.curAnim.name == 'firstDeath') {
            if (bf.animation.curAnim.finished) {
                bf.animation.play('deathLoop');
                playDeathMusic();
            }
        }

        if (!isEnding) {
            if (InputMap.justPressed("accept")) {
                endBullshit();
            }

            if (InputMap.justPressed("back")) {
                if (music != null) music.stop();
                FlxG.switchState(new MainMenuState());
            }
        }
    }

    function playDeathMusic():Void {
        music = AssetHelper.playSoundSafely('assets/music/$deathMusicName.ogg', 1.0);
        if (music != null) {
            music.looped = true;
        }
    }

    function endBullshit():Void {
        isEnding = true;
        if (music != null) music.stop();
        endSound = AssetHelper.playSoundSafely('assets/music/$endSoundName.ogg', 1.0);

        if (bf.animation.getByName('deathConfirm') != null) {
            bf.animation.play('deathConfirm');
        }

        FlxTween.tween(FlxG.camera, {alpha: 0}, 2.0, {
            ease: FlxEase.quartOut,
            onComplete: function(t:FlxTween) {
                FlxG.switchState(new PlayState());
            }
        });
    }

    override public function destroy():Void {
        if (deathSound != null) deathSound.destroy();
        if (music != null) music.destroy();
        if (endSound != null) endSound.destroy();
        super.destroy();
    }
}