package soulscorch.ui.menus.states;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
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
import soulscorch.ui.menus.states.MainMenuState;

class FreeplayState extends MusicBeatState {
    public static var curSelected:Int = 0;
    public static var curDifficulty:Int = 1;

    private var songs:Array<RegisteredSong> = [];
    private var grpSongs:FlxTypedGroup<Alphabet>;
    private var iconArray:Array<HealthIcon> = [];

    private var bg:FlxSprite;
    private var scoreText:FlxText;
    private var diffText:FlxText;
    private var mobileControls:MobilePad;

    private var lerpScore:Int = 0;
    private var intendedScore:Int = 0;
    private var intendedAccuracy:Float = 0.0;
    private var intendedRating:String = "N/A";

    private var instPreview:FlxSound;

    override public function create():Void {
        super.create();

        #if desktop
        DiscordRPC.changePresence("Freeplay Menu", "Browsing Songs");
        #end

        SongRegistry.scanAll();
        songs = (SongRegistry.songs != null) ? SongRegistry.songs : [];

        bg = new FlxSprite();
        if (!AssetHelper.loadGraphicSafely(bg, "menuDesat")) {
            bg.makeGraphic(FlxG.width, FlxG.height, 0xFF444444);
        }
        bg.screenCenter();
        bg.antialiasing = true;
        add(bg);

        grpSongs = new FlxTypedGroup<Alphabet>();
        add(grpSongs);

        if (songs.length > 0) {
            curSelected = FlxMath.wrap(curSelected, 0, songs.length - 1);

            for (i in 0...songs.length) {
                var songText:Alphabet = new Alphabet(0, (70 * i) + 30, songs[i].title, true);
                songText.isMenuItem = true;
                songText.targetY = i;
                songText.snapToPosition();
                grpSongs.add(songText);

                var icon:HealthIcon = new HealthIcon(songs[i].character != null ? songs[i].character : "face", false);
                icon.sprTracker = songText;
                iconArray.push(icon);
                add(icon);
            }

            var scoreBG = new FlxSprite(FlxG.width - 420, 0).makeGraphic(420, 96, 0xAA000000);
            add(scoreBG);

            scoreText = new FlxText(FlxG.width - 410, 10, 400, "PERSONAL BEST: 0", 18);
            scoreText.setFormat(Paths.font("vcr"), 18, FlxColor.WHITE, RIGHT, OUTLINE, FlxColor.BLACK);
            add(scoreText);

            diffText = new FlxText(FlxG.width - 410, 48, 400, "< NORMAL >", 22);
            diffText.setFormat(Paths.font("vcr"), 22, FlxColor.WHITE, RIGHT, OUTLINE, FlxColor.BLACK);
            add(diffText);

            changeSelection();
        } else {
            var emptyText = new FlxText(0, 0, FlxG.width, "NO SONGS FOUND IN ASSETS OR MODS", 22);
            emptyText.setFormat(Paths.font("vcr"), 22, FlxColor.RED, CENTER, OUTLINE, FlxColor.BLACK);
            emptyText.screenCenter();
            add(emptyText);
        }

        #if (mobile || debug)
        mobileControls = new MobilePad(FULL, A_B);
        add(mobileControls);
        Controls.instance.bindMobilePad(mobileControls);
        #end
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
            scoreText.text = 'PERSONAL BEST: $lerpScore\nACC: ${Math.round(intendedAccuracy * 100) / 100}% [$intendedRating]';
        }

        if (Controls.instance.UI_UP_P) changeSelection(-1);
        if (Controls.instance.UI_DOWN_P) changeSelection(1);
        if (Controls.instance.UI_LEFT_P) changeDiff(-1);
        if (Controls.instance.UI_RIGHT_P) changeDiff(1);

        if (Controls.instance.BACK) {
            stopPreview();
            AssetHelper.playSoundSafely("cancelMenu", 0.7);
            MusicBeatState.switchState(new MainMenuState());
        }

        if (Controls.instance.ACCEPT && songs.length > 0) {
            stopPreview();
            var selected = songs[curSelected];
            var diffs = (selected.difficulties != null && selected.difficulties.length > 0) ? selected.difficulties : Difficulty.defaultList;
            PlayState.curSong = selected.id;
            PlayState.curDifficulty = diffs[curDifficulty];
            MusicBeatState.switchState(new PlayState());
        }

        for (i in 0...grpSongs.members.length) {
            var item = grpSongs.members[i];
            item.alpha = (i == curSelected ? 1.0 : 0.45);

            if (iconArray.length > i && iconArray[i] != null) {
                iconArray[i].alpha = item.alpha;
                iconArray[i].visible = item.visible;
            }
        }
    }

    private function changeSelection(change:Int = 0):Void {
        if (songs.length == 0) return;
        curSelected = FlxMath.wrap(curSelected + change, 0, songs.length - 1);
        AssetHelper.playSoundSafely("scrollMenu", 0.7);

        if (bg != null) {
            var targetColor:FlxColor = songs[curSelected].color;
            FlxTween.cancelTweensOf(bg);
            FlxTween.color(bg, 0.25, bg.color, targetColor);
        }

        var bullShit:Int = 0;
        for (item in grpSongs.members) {
            item.targetY = bullShit - curSelected;
            bullShit++;
        }

        curDifficulty = 0;
        changeDiff();
        playSongPreview();
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

    private function playSongPreview():Void {
        stopPreview();
        var selected = songs[curSelected];
        var instSound = Paths.inst(selected.id);
        if (instSound != null) {
            instPreview = new FlxSound().loadEmbedded(instSound, true);
            instPreview.volume = 0.7;
            instPreview.play();
            FlxG.sound.list.add(instPreview);
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
        stopPreview();
        Controls.instance.unbindMobilePad();
        super.destroy();
    }
}