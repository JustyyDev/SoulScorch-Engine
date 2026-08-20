package soulscorch.ui.menus.states;

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
import flixel.util.FlxTimer;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.input.Controls;
import soulscorch.backend.input.MobilePad;
import soulscorch.backend.system.SaveData;
import soulscorch.backend.system.modules.discord.DiscordRPC;
import soulscorch.gameplay.PlayState;
import soulscorch.gameplay.actors.HealthIcon;
import soulscorch.gameplay.song.Difficulty;
import soulscorch.gameplay.song.SongRegistry;
import soulscorch.gameplay.song.SongRegistry.RegisteredSong;
import soulscorch.ui.hud.Alphabet;
import soulscorch.ui.menus.editors.editorui.EditorTheme;
import soulscorch.ui.menus.states.MainMenuState;

using StringTools;

class FreeplayState extends MusicBeatState {
    public static var curSelected:Int = 0;
    public static var curDifficulty:Int = 1;

    private var songs:Array<RegisteredSong> = [];
    private var grpSongs:FlxTypedGroup<Alphabet>;
    private var iconArray:Array<HealthIcon> = [];

    private var bg:FlxSprite;
    private var scorePanel:FlxSpriteGroup;
    private var scoreText:FlxText;
    private var diffText:FlxText;
    private var bpmText:FlxText;
    private var mobileControls:MobilePad;

    private var lerpScore:Int = 0;
    private var intendedScore:Int = 0;
    private var intendedAccuracy:Float = 0.0;
    private var intendedRating:String = "N/A";

    private var instPreview:FlxSound;
    private var previewTimer:FlxTimer;
    private var colorTween:FlxTween;

    override public function create():Void {
        super.create();

        #if desktop
        DiscordRPC.changePresence("Freeplay Library", "Selecting Track");
        #end

        SongRegistry.scanAll();
        songs = (SongRegistry.songs != null) ? SongRegistry.songs : [];

        bg = new FlxSprite();
        if (!AssetHelper.loadGraphicSafely(bg, "ui/menubgs/menuDesat")) {
            if (!AssetHelper.loadGraphicSafely(bg, "menuDesat")) {
                bg.makeGraphic(FlxG.width, FlxG.height, 0xFF282035);
            }
        }
        bg.screenCenter();
        bg.antialiasing = true;
        add(bg);

        var grid = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.TRANSPARENT);
        for (i in 0...Std.int(FlxG.width / 40)) {
            grid.pixels.fillRect(new openfl.geom.Rectangle(i * 40, 0, 1, FlxG.height), 0x08FFFFFF);
        }
        for (i in 0...Std.int(FlxG.height / 40)) {
            grid.pixels.fillRect(new openfl.geom.Rectangle(0, i * 40, FlxG.width, 1), 0x08FFFFFF);
        }
        grid.dirty = true;
        add(grid);

        grpSongs = new FlxTypedGroup<Alphabet>();
        add(grpSongs);

        if (songs.length > 0) {
            curSelected = FlxMath.wrap(curSelected, 0, songs.length - 1);

            for (i in 0...songs.length) {
                var songText:Alphabet = new Alphabet(0, (75 * i) + 30, songs[i].title, true);
                songText.isMenuItem = true;
                songText.targetY = i;
                songText.snapToPosition();
                grpSongs.add(songText);

                var icon:HealthIcon = new HealthIcon(songs[i].character != null ? songs[i].character : "face", false);
                icon.sprTracker = songText;
                iconArray.push(icon);
                add(icon);
            }

            setupScorePanel();
            changeSelection(0);
        } else {
            var emptyText = new FlxText(0, 0, FlxG.width, "NO SONGS FOUND IN ASSETS OR MODS", 20);
            emptyText.setFormat(Paths.font("vcr"), 20, EditorTheme.ACCENT_MAGENTA, CENTER, OUTLINE, FlxColor.BLACK);
            emptyText.screenCenter();
            add(emptyText);
        }

        #if (mobile || debug)
        mobileControls = new MobilePad(FULL, A_B);
        add(mobileControls);
        Controls.instance.bindMobilePad(mobileControls);
        #end
    }

    private function setupScorePanel():Void {
        scorePanel = new FlxSpriteGroup(FlxG.width - 430, 20);
        add(scorePanel);

        var pBg = new FlxSprite(0, 0).makeGraphic(400, 110, EditorTheme.PANEL_BG);
        pBg.alpha = 0.85;
        scorePanel.add(pBg);

        var pBorder = new FlxSprite(-1, -1).makeGraphic(402, 112, EditorTheme.PANEL_BORDER);
        scorePanel.add(pBorder);

        var accent = new FlxSprite(0, 0).makeGraphic(4, 110, EditorTheme.ACCENT_CYAN);
        scorePanel.add(accent);

        scoreText = new FlxText(16, 12, 370, "PERSONAL BEST: 0", 16);
        scoreText.setFormat(Paths.font("vcr"), 16, EditorTheme.TEXT_PRIMARY, RIGHT);
        scorePanel.add(scoreText);

        diffText = new FlxText(16, 44, 370, "< NORMAL >", 22);
        diffText.setFormat(Paths.font("vcr"), 22, EditorTheme.ACCENT_CYAN, RIGHT);
        scorePanel.add(diffText);

        bpmText = new FlxText(16, 80, 370, "BPM: 100", 13);
        bpmText.setFormat(Paths.font("vcr"), 13, EditorTheme.TEXT_MUTED, RIGHT);
        scorePanel.add(bpmText);
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (songs.length == 0) {
            if (Controls.instance.BACK) {
                AssetHelper.playSoundSafely("cancelMenu", 0.7);
                MusicBeatState.switchState(new MainMenuState());
            }
            return;
        }

        lerpScore = Math.floor(FlxMath.lerp(intendedScore, lerpScore, Math.exp(-elapsed * 24.0)));
        if (scoreText != null) {
            scoreText.text = 'PERSONAL BEST: $lerpScore  •  ${Math.round(intendedAccuracy * 10) / 10}% [$intendedRating]';
        }

        if (Controls.instance.UI_UP_P) changeSelection(-1);
        if (Controls.instance.UI_DOWN_P) changeSelection(1);
        if (Controls.instance.UI_LEFT_P) changeDiff(-1);
        if (Controls.instance.UI_RIGHT_P) changeDiff(1);

        if (Controls.instance.BACK) {
            cancelPreviewTimer();
            stopPreview();
            AssetHelper.playSoundSafely("cancelMenu", 0.7);
            MusicBeatState.switchState(new MainMenuState());
        }

        if (Controls.instance.ACCEPT && songs.length > 0) {
            cancelPreviewTimer();
            stopPreview();
            var selected = songs[curSelected];
            var diffs = (selected.difficulties != null && selected.difficulties.length > 0) ? selected.difficulties : Difficulty.defaultList;
            PlayState.curSong = selected.id;
            PlayState.curDifficulty = diffs[curDifficulty];
            MusicBeatState.switchState(new PlayState());
        }

        for (i in 0...grpSongs.members.length) {
            var item = grpSongs.members[i];
            item.alpha = (i == curSelected ? 1.0 : 0.4);

            if (iconArray.length > i && iconArray[i] != null) {
                iconArray[i].alpha = item.alpha;
                iconArray[i].visible = item.visible;
            }
        }
    }

    private function changeSelection(change:Int = 0):Void {
        if (songs.length == 0) return;
        curSelected = FlxMath.wrap(curSelected + change, 0, songs.length - 1);
        if (change != 0) AssetHelper.playSoundSafely("scrollMenu", 0.7);

        if (bg != null) {
            var targetColor:FlxColor = songs[curSelected].color;
            if (colorTween != null) colorTween.cancel();
            colorTween = FlxTween.color(bg, 0.35, bg.color, targetColor, {ease: FlxEase.quartOut});
        }

        var bullShit:Int = 0;
        for (item in grpSongs.members) {
            item.targetY = bullShit - curSelected;
            bullShit++;
        }

        if (bpmText != null) bpmText.text = 'TEMPO: ${Math.round(songs[curSelected].bpm)} BPM';

        curDifficulty = 0;
        changeDiff(0);
        scheduleSongPreview();
    }

    private function changeDiff(change:Int = 0):Void {
        if (songs.length == 0) return;
        var diffs = (songs[curSelected].difficulties != null && songs[curSelected].difficulties.length > 0) ? songs[curSelected].difficulties : Difficulty.defaultList;
        curDifficulty = FlxMath.wrap(curDifficulty + change, 0, diffs.length - 1);

        var diffName = diffs[curDifficulty].toUpperCase();
        if (diffText != null) {
            diffText.text = '< $diffName >';
            diffText.color = Difficulty.getColor(diffs[curDifficulty]);
        }

        var saveEntry = SaveData.instance != null ? SaveData.instance.getScore(songs[curSelected].id, diffs[curDifficulty]) : null;
        if (saveEntry != null) {
            intendedScore = saveEntry.score;
            intendedAccuracy = saveEntry.accuracy;
            intendedRating = saveEntry.rating;
        } else {
            intendedScore = 0;
            intendedAccuracy = 0.0;
            intendedRating = "N/A";
        }
    }

    private function scheduleSongPreview():Void {
        cancelPreviewTimer();

        previewTimer = new FlxTimer().start(0.35, function(_) {
            if (songs.length == 0 || curSelected >= songs.length) return;
            var selected = songs[curSelected];
            var instSound = Paths.inst(selected.id);

            if (instSound != null) {
                stopPreview();
                instPreview = new FlxSound().loadEmbedded(instSound, true);
                instPreview.volume = 0;
                instPreview.play();
                instPreview.fadeIn(0.6, 0.0, 0.7);
                FlxG.sound.list.add(instPreview);
            }
        });
    }

    private function cancelPreviewTimer():Void {
        if (previewTimer != null) {
            previewTimer.cancel();
            previewTimer.destroy();
            previewTimer = null;
        }
    }

    private function stopPreview():Void {
        if (instPreview != null) {
            instPreview.stop();
            FlxG.sound.list.remove(instPreview, true);
            instPreview.destroy();
            instPreview = null;
        }
    }

    override public function destroy():Void {
        cancelPreviewTimer();
        stopPreview();
        if (colorTween != null) colorTween.cancel();
        Controls.instance.unbindMobilePad();
        super.destroy();
    }
}