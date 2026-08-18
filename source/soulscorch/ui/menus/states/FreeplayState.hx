package soulscorch.ui.menus.states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.input.Controls;
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

    private var lerpScore:Int = 0;
    private var intendedScore:Int = 0;
    private var intendedAccuracy:Float = 0.0;
    private var intendedRating:String = "N/A";

    override public function create():Void {
        super.create();

        DiscordRPC.changePresence("Freeplay Menu", "Selecting Track");

        SongRegistry.scanAll();
        songs = SongRegistry.songs;

        bg = new FlxSprite();
        AssetHelper.loadGraphicSafely(bg, "menuDesat");
        bg.screenCenter();
        bg.antialiasing = true;
        add(bg);

        grpSongs = new FlxTypedGroup<Alphabet>();
        add(grpSongs);

        for (i in 0...songs.length) {
            var songText:Alphabet = new Alphabet(0, (70 * i) + 30, songs[i].title, true);
            songText.isMenuItem = true;
            songText.targetY = i;
            grpSongs.add(songText);

            var icon:HealthIcon = new HealthIcon(songs[i].character, false);
            iconArray.push(icon);
            add(icon);
        }

        var scoreBG = new FlxSprite(FlxG.width - 360, 0).makeGraphic(360, 90, 0x99000000);
        add(scoreBG);

        scoreText = new FlxText(FlxG.width - 350, 10, 340, "PERSONAL BEST: 0", 18);
        scoreText.setFormat(Paths.font("vcr"), 18, FlxColor.WHITE, RIGHT);
        add(scoreText);

        diffText = new FlxText(FlxG.width - 350, 42, 340, "< NORMAL >", 22);
        diffText.setFormat(Paths.font("vcr"), 22, FlxColor.WHITE, RIGHT);
        add(diffText);

        changeSelection();
        changeDiff();
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        lerpScore = Math.floor(FlxMath.lerp(intendedScore, lerpScore, Math.exp(-elapsed * 24.0)));
        scoreText.text = 'PERSONAL BEST: $lerpScore\nACC: ${Math.round(intendedAccuracy * 100) / 100}% [$intendedRating]';

        if (Controls.instance.UI_UP_P) changeSelection(-1);
        if (Controls.instance.UI_DOWN_P) changeSelection(1);
        if (Controls.instance.UI_LEFT_P) changeDiff(-1);
        if (Controls.instance.UI_RIGHT_P) changeDiff(1);

        if (Controls.instance.BACK) {
            AssetHelper.playSoundSafely("cancelMenu", 0.7);
            MusicBeatState.switchState(new MainMenuState());
        }

        if (Controls.instance.ACCEPT && songs.length > 0) {
            var selected = songs[curSelected];
            PlayState.curSong = selected.id;
            PlayState.curDifficulty = selected.difficulties[curDifficulty];
            MusicBeatState.switchState(new PlayState());
        }

        for (i in 0...grpSongs.members.length) {
            var item = grpSongs.members[i];
            item.alpha = (i == curSelected ? 1.0 : 0.6);

            if (iconArray.length > i && iconArray[i] != null) {
                iconArray[i].x = item.x + item.width + 10;
                iconArray[i].y = item.y - 30;
            }
        }
    }

    private function changeSelection(change:Int = 0):Void {
        if (songs.length == 0) return;
        curSelected = FlxMath.wrap(curSelected + change, 0, songs.length - 1);
        AssetHelper.playSoundSafely("scrollMenu", 0.7);

        if (bg != null) {
            bg.color = songs[curSelected].color;
        }

        var bullShit:Int = 0;
        for (item in grpSongs.members) {
            item.targetY = bullShit - curSelected;
            bullShit++;
        }

        curDifficulty = 0;
        changeDiff();
    }

    private function changeDiff(change:Int = 0):Void {
        if (songs.length == 0) return;
        var diffs = songs[curSelected].difficulties;
        curDifficulty = FlxMath.wrap(curDifficulty + change, 0, diffs.length - 1);

        var diffName = diffs[curDifficulty].toUpperCase();
        diffText.text = '< $diffName >';
        diffText.color = Difficulty.getColor(diffs[curDifficulty]);

        var saveEntry = SaveData.instance.getScore(songs[curSelected].id, diffs[curDifficulty]);
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
}