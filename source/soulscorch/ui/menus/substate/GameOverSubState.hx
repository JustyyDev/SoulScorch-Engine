package soulscorch.ui.menus.substate;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.MusicBeatSubstate;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.input.Controls;
import soulscorch.backend.system.modules.discord.DiscordRPC;
import soulscorch.gameplay.PlayState;
import soulscorch.ui.hud.Alphabet;
import soulscorch.ui.menus.editors.editorui.EditorTheme;
import soulscorch.ui.menus.states.MainMenuState;

using StringTools;

class GameOverSubState extends MusicBeatSubstate {
    public static var deathCharacter:String = "bf-dead";
    public static var deathSoundName:String = "fnf_loss_sfx";
    public static var loopMusicName:String = "gameOver";
    public static var endSoundName:String = "gameOverEnd";

    private var bfDead:FlxSprite;
    private var bgOverlay:FlxSprite;
    private var letterboxTop:FlxSprite;
    private var letterboxBottom:FlxSprite;
    private var statsCard:FlxSpriteGroup;

    private var isEnding:Bool = false;
    private var isStartedLoop:Bool = false;
    private var targetCamFollow:FlxPoint;

    public function new(x:Float, y:Float) {
        super();

        this.persistentUpdate = false;
        this.persistentDraw = true;

        #if desktop
        DiscordRPC.changePresence("Game Over", PlayState.curSong != null ? 'Fallen in ${PlayState.curSong.toUpperCase()}' : "Defeated");
        #end

        targetCamFollow = FlxPoint.get(x + 50, y + 50);

        bgOverlay = new FlxSprite().makeGraphic(FlxG.width * 2, FlxG.height * 2, FlxColor.BLACK);
        bgOverlay.alpha = 0.0;
        bgOverlay.scrollFactor.set(0, 0);
        bgOverlay.screenCenter();
        add(bgOverlay);
        FlxTween.tween(bgOverlay, {alpha: 0.75}, 0.8, {ease: FlxEase.quadOut});

        // Cinematic Letterbox Bars
        letterboxTop = new FlxSprite(0, -90).makeGraphic(FlxG.width, 90, FlxColor.BLACK);
        letterboxTop.scrollFactor.set(0, 0);
        add(letterboxTop);
        FlxTween.tween(letterboxTop, {y: 0}, 0.5, {ease: FlxEase.cubeOut});

        letterboxBottom = new FlxSprite(0, FlxG.height).makeGraphic(FlxG.width, 90, FlxColor.BLACK);
        letterboxBottom.scrollFactor.set(0, 0);
        add(letterboxBottom);
        FlxTween.tween(letterboxBottom, {y: FlxG.height - 90}, 0.5, {ease: FlxEase.cubeOut});

        // Character Death Sprite with smart fallbacks
        bfDead = new FlxSprite(x, y);
        var charToLoad = (PlayState.instance != null && PlayState.instance.boyfriend != null) ? PlayState.instance.boyfriend.curCharacter : "bf";

        var loaded = AssetHelper.loadSparrowSafely(bfDead, 'characters/${charToLoad}-dead');
        if (!loaded) loaded = AssetHelper.loadSparrowSafely(bfDead, 'characters/${charToLoad}_dead');
        if (!loaded) loaded = AssetHelper.loadSparrowSafely(bfDead, "characters/BOYFRIEND_DEAD");
        if (!loaded) loaded = AssetHelper.loadSparrowSafely(bfDead, "BOYFRIEND_DEAD");

        if (loaded && bfDead.frames != null) {
            bfDead.animation.addByPrefix("firstDeath", "BF dies", 24, false);
            bfDead.animation.addByPrefix("deathLoop", "BF Dead Loop", 24, true);
            bfDead.animation.addByPrefix("deathConfirm", "BF Dead Confirm", 24, false);
            bfDead.animation.play("firstDeath");
        } else {
            bfDead.makeGraphic(130, 150, EditorTheme.ACCENT_MAGENTA);
        }

        bfDead.antialiasing = true;
        add(bfDead);

        createRunStatsCard();

        AssetHelper.playSoundSafely(deathSoundName, 0.85);

        FlxG.camera.target = null;
        FlxG.camera.follow(bfDead, LOCKON, 0.04);
    }

    private function createRunStatsCard():Void {
        statsCard = new FlxSpriteGroup(40, -200);
        statsCard.scrollFactor.set(0, 0);
        add(statsCard);

        var cardBg = new FlxSprite(0, 0).makeGraphic(320, 110, EditorTheme.PANEL_BG);
        cardBg.alpha = 0.9;
        statsCard.add(cardBg);

        var cardBorder = new FlxSprite(-1, -1).makeGraphic(322, 112, EditorTheme.PANEL_BORDER);
        statsCard.add(cardBorder);

        var accent = new FlxSprite(0, 0).makeGraphic(4, 110, EditorTheme.ACCENT_MAGENTA);
        statsCard.add(accent);

        var titleTxt = new FlxText(14, 8, 300, "SESSION RECAP", 12);
        titleTxt.setFormat(Paths.font("vcr"), 12, EditorTheme.ACCENT_MAGENTA, LEFT);
        statsCard.add(titleTxt);

        var score = (PlayState.instance != null) ? PlayState.instance.songScore : 0;
        var misses = (PlayState.instance != null) ? PlayState.instance.songMisses : 0;
        var acc = (PlayState.instance != null) ? Math.round(PlayState.instance.accuracy * 10) / 10 : 0.0;
        var progress = (PlayState.instance != null) ? Math.round(PlayState.instance.songLengthProgress * 100) : 0;

        var statsTxt = new FlxText(14, 28, 300, 'Score: $score\nAccuracy: $acc%\nMisses: $misses\nTrack Progress: $progress%', 13);
        statsTxt.setFormat(Paths.font("vcr"), 13, EditorTheme.TEXT_PRIMARY, LEFT);
        statsCard.add(statsTxt);

        FlxTween.tween(statsCard, {y: 110}, 0.7, {ease: FlxEase.backOut, startDelay: 0.3});
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (!isStartedLoop && bfDead.animation != null && bfDead.animation.curAnim != null) {
            if (bfDead.animation.curAnim.name == "firstDeath" && bfDead.animation.curAnim.finished) {
                bfDead.animation.play("deathLoop");
                isStartedLoop = true;
                FlxG.sound.playMusic(Paths.music(loopMusicName), 0.75);
            }
        }

        if (Controls.instance.ACCEPT && !isEnding) {
            isEnding = true;
            if (bfDead.animation != null && bfDead.animation.exists("deathConfirm")) {
                bfDead.animation.play("deathConfirm");
            }
            if (FlxG.sound.music != null) FlxG.sound.music.stop();
            AssetHelper.playSoundSafely(endSoundName, 0.85);

            FlxTween.tween(statsCard, {y: -200, alpha: 0}, 0.5, {ease: FlxEase.cubeIn});

            new FlxTimer().start(2.2, function(_) {
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

    override public function destroy():Void {
        if (targetCamFollow != null) {
            targetCamFollow.put();
            targetCamFollow = null;
        }
        super.destroy();
    }
}