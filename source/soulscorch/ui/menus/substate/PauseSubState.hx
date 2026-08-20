package soulscorch.ui.menus.substate;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.MusicBeatSubstate;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.input.Controls;
import soulscorch.backend.system.modules.discord.DiscordRPC;
import soulscorch.gameplay.GameplayFlags;
import soulscorch.gameplay.PlayState;
import soulscorch.gameplay.song.Difficulty;
import soulscorch.ui.hud.Alphabet;
import soulscorch.ui.menus.editors.editorui.EditorTheme;
import soulscorch.ui.menus.editors.editorui.EditorToast;
import soulscorch.ui.menus.option.OptionsMenuState;
import soulscorch.ui.menus.states.MainMenuState;

using StringTools;

class PauseSubState extends MusicBeatSubstate {
    public static var curSelected:Int = 0;

    private var menuItems:Array<String> = [
        "Resume",
        "Restart Song",
        "Toggle Practice Mode",
        "Toggle Botplay",
        "Options",
        "Exit to Main Menu"
    ];

    private var grpMenu:FlxTypedGroup<FlxSpriteGroup>;
    private var itemBgs:Array<FlxSprite> = [];
    private var itemIndicators:Array<FlxSprite> = [];
    private var bg:FlxSprite;
    private var pauseMusic:FlxSound;

    private var headerCard:FlxSpriteGroup;
    private var statsCard:FlxSpriteGroup;
    private var subCamera:FlxCamera;
    private var isLeaving:Bool = false;

    public function new() {
        super();

        this.persistentUpdate = false;
        this.persistentDraw = true;

        #if desktop
        DiscordRPC.changePresence(
            'Paused: ${PlayState.curSong.toUpperCase()}',
            'Score: ${(PlayState.instance != null ? PlayState.instance.songScore : 0)} | Difficulty: ${PlayState.curDifficulty.toUpperCase()}'
        );
        #end

        subCamera = new FlxCamera();
        subCamera.bgColor = FlxColor.TRANSPARENT;
        FlxG.cameras.add(subCamera, false);
        cameras = [subCamera];

        bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        bg.alpha = 0.0;
        bg.scrollFactor.set(0, 0);
        add(bg);
        FlxTween.tween(bg, {alpha: 0.72}, 0.35, {ease: FlxEase.quadOut});

        setupHeaderCard();
        setupStatsCard();

        grpMenu = new FlxTypedGroup<FlxSpriteGroup>();
        add(grpMenu);

        rebuildMenu();

        var pMusic = Paths.music("breakfast");
        if (pMusic == null) pMusic = Paths.music("pause");
        if (pMusic != null) {
            pauseMusic = new FlxSound().loadEmbedded(pMusic, true, true);
            pauseMusic.volume = 0;
            pauseMusic.play(false, FlxG.random.int(0, Std.int(pauseMusic.length / 2)));
            FlxG.sound.list.add(pauseMusic);
            pauseMusic.fadeIn(1.5, 0, 0.65);
        }

        changeSelection(0);
    }

    private function setupHeaderCard():Void {
        headerCard = new FlxSpriteGroup(60, 40);
        add(headerCard);

        var title = (PlayState.instance != null && PlayState.instance.songData != null) ? PlayState.instance.songData.title : PlayState.curSong;
        var artist = (PlayState.instance != null && PlayState.instance.songData != null) ? PlayState.instance.songData.artist : "Unknown Artist";
        var diff = PlayState.curDifficulty.toUpperCase();

        var titleTxt = new FlxText(0, 0, 500, title.toUpperCase(), 26);
        titleTxt.setFormat(Paths.font("vcr"), 26, EditorTheme.ACCENT_CYAN, LEFT, OUTLINE, FlxColor.BLACK);
        headerCard.add(titleTxt);

        var subTxt = new FlxText(0, 32, 500, 'By $artist  •  BPM: ${Math.round(Conductor.bpm)}', 14);
        subTxt.setFormat(Paths.font("vcr"), 14, EditorTheme.TEXT_MUTED, LEFT);
        headerCard.add(subTxt);

        var diffTag = new FlxText(0, 54, 200, '[ $diff ]', 14);
        diffTag.setFormat(Paths.font("vcr"), 14, Difficulty.getColor(PlayState.curDifficulty), LEFT);
        headerCard.add(diffTag);
    }

    private function setupStatsCard():Void {
        statsCard = new FlxSpriteGroup(FlxG.width - 360, 40);
        add(statsCard);

        var statsBox = new FlxSprite(0, 0).makeGraphic(300, 85, EditorTheme.PANEL_BG);
        statsBox.alpha = 0.85;
        statsCard.add(statsBox);

        var border = new FlxSprite(-1, -1).makeGraphic(302, 87, EditorTheme.PANEL_BORDER);
        statsCard.add(border);

        var accent = new FlxSprite(0, 0).makeGraphic(3, 85, EditorTheme.ACCENT_CYAN);
        statsCard.add(accent);

        var score = (PlayState.instance != null) ? PlayState.instance.songScore : 0;
        var misses = (PlayState.instance != null) ? PlayState.instance.songMisses : 0;
        var acc = (PlayState.instance != null) ? Math.round(PlayState.instance.accuracy * 10) / 10 : 0.0;

        var statsTxt = new FlxText(14, 12, 280, 'Score: $score\nAccuracy: $acc%\nMisses: $misses', 14);
        statsTxt.setFormat(Paths.font("vcr"), 14, EditorTheme.TEXT_PRIMARY, LEFT);
        statsCard.add(statsTxt);
    }

    private function rebuildMenu():Void {
        grpMenu.clear();
        itemBgs = [];
        itemIndicators = [];

        var itemWidth = 420;

        for (i in 0...menuItems.length) {
            var itemGroup = new FlxSpriteGroup(60, 160 + (i * 64));
            itemGroup.ID = i;

            var bgSpr = new FlxSprite(0, 0).makeGraphic(itemWidth, 52, EditorTheme.PANEL_BG);
            bgSpr.alpha = 0.6;
            itemGroup.add(bgSpr);
            itemBgs.push(bgSpr);

            var borderSpr = new FlxSprite(0, 51).makeGraphic(itemWidth, 1, EditorTheme.PANEL_BORDER);
            itemGroup.add(borderSpr);

            var indicator = new FlxSprite(0, 0).makeGraphic(4, 52, EditorTheme.ACCENT_CYAN);
            indicator.alpha = 0.0;
            itemGroup.add(indicator);
            itemIndicators.push(indicator);

            var labelText = menuItems[i];
            if (labelText == "Toggle Practice Mode") {
                labelText += GameplayFlags.getBool("practiceMode", false) ? " [ON]" : " [OFF]";
            } else if (labelText == "Toggle Botplay") {
                labelText += (PlayState.instance != null && PlayState.instance.botplay) ? " [ON]" : " [OFF]";
            }

            var label = new FlxText(22, 14, itemWidth - 44, labelText, 18);
            label.setFormat(Paths.font("vcr"), 18, EditorTheme.TEXT_PRIMARY, LEFT);
            itemGroup.add(label);

            grpMenu.add(itemGroup);
        }
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        if (isLeaving) return;

        if (Controls.instance.UI_UP_P) changeSelection(-1);
        if (Controls.instance.UI_DOWN_P) changeSelection(1);

        if (Controls.instance.ACCEPT) {
            selectOption(menuItems[curSelected]);
        }

        if (Controls.instance.BACK) {
            resumeGame();
        }

        for (i in 0...grpMenu.members.length) {
            var item = grpMenu.members[i];
            var isCur = (i == curSelected);
            itemBgs[i].color = isCur ? EditorTheme.BTN_HOVER : EditorTheme.PANEL_BG;
            itemIndicators[i].alpha = isCur ? 1.0 : 0.0;
            item.x = FlxMath.lerp(item.x, isCur ? 75 : 60, FlxMath.bound(elapsed * 15, 0, 1));
            item.alpha = isCur ? 1.0 : 0.6;
        }
    }

    private function changeSelection(change:Int = 0):Void {
        curSelected = FlxMath.wrap(curSelected + change, 0, menuItems.length - 1);
        if (change != 0) AssetHelper.playSoundSafely("scrollMenu", 0.6);
    }

    private function resumeGame():Void {
        isLeaving = true;
        stopPauseMusic();
        if (PlayState.instance != null) PlayState.instance.resumeSong();
        cleanupCamera();
        close();
    }

    private function selectOption(option:String):Void {
        switch (option) {
            case "Resume":
                resumeGame();

            case "Restart Song":
                isLeaving = true;
                stopPauseMusic();
                cleanupCamera();
                if (PlayState.instance != null) {
                    PlayState.instance.paused = false;
                }
                MusicBeatState.resetState();

            case "Toggle Practice Mode":
                var current = GameplayFlags.getBool("practiceMode", false);
                GameplayFlags.set("practiceMode", !current);
                AssetHelper.playSoundSafely("confirmMenu", 0.7);
                rebuildMenu();
                changeSelection(0);

            case "Toggle Botplay":
                if (PlayState.instance != null) {
                    PlayState.instance.botplay = !PlayState.instance.botplay;
                    if (PlayState.instance.botplayTxt != null) {
                        PlayState.instance.botplayTxt.visible = PlayState.instance.botplay;
                    }
                }
                AssetHelper.playSoundSafely("confirmMenu", 0.7);
                rebuildMenu();
                changeSelection(0);

            case "Options":
                isLeaving = true;
                stopPauseMusic();
                cleanupCamera();
                if (PlayState.instance != null && PlayState.instance.audio != null) {
                    PlayState.instance.audio.stop();
                }
                MusicBeatState.switchState(new OptionsMenuState());

            case "Exit to Main Menu":
                isLeaving = true;
                stopPauseMusic();
                cleanupCamera();
                if (PlayState.instance != null && PlayState.instance.audio != null) {
                    PlayState.instance.audio.stop();
                }
                MusicBeatState.switchState(new MainMenuState());
        }
    }

    private function stopPauseMusic():Void {
        if (pauseMusic != null) {
            pauseMusic.stop();
            FlxG.sound.list.remove(pauseMusic, true);
            pauseMusic.destroy();
            pauseMusic = null;
        }
    }

    private function cleanupCamera():Void {
        if (subCamera != null && FlxG.cameras.list.contains(subCamera)) {
            FlxG.cameras.remove(subCamera, true);
        }
        subCamera = null;
    }

    override public function destroy():Void {
        stopPauseMusic();
        cleanupCamera();
        super.destroy();
    }
}