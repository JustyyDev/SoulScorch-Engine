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
import soulscorch.backend.system.modules.discord.DiscordRPC;
import soulscorch.gameplay.PlayState;
import soulscorch.gameplay.song.Difficulty;
import soulscorch.ui.menus.states.MainMenuState;

typedef WeekData = {
    var id:String;
    var name:String;
    var songs:Array<String>;
    var characters:Array<String>;
}

class StoryMenuState extends MusicBeatState {
    public static var curWeek:Int = 0;
    public static var curDifficulty:Int = 1;

    private var weeks:Array<WeekData> = [
        {
            id: "week0",
            name: "TEACHING TIME",
            songs: ["Tutorial"],
            characters: ["dad", "bf", "gf"]
        },
        {
            id: "week1",
            name: "SCORCHED WEEK IDK",
            songs: ["Bopeebo", "Fresh", "Dad Battle"],
            characters: ["dad", "bf", "gf"]
        }
    ];

    private var grpWeekTitles:FlxTypedGroup<FlxText>;
    private var diffText:FlxText;
    private var tracklistText:FlxText;
    private var yellowBg:FlxSprite;

    override public function create():Void {
        super.create();

        DiscordRPC.changePresence("Story Menu", "Selecting Campaign Week");

        yellowBg = new FlxSprite(0, 56).makeGraphic(FlxG.width, 380, 0xFFF9CF51);
        add(yellowBg);

        grpWeekTitles = new FlxTypedGroup<FlxText>();
        add(grpWeekTitles);

        for (i in 0...weeks.length) {
            var weekText = new FlxText(0, (i * 45) + 470, FlxG.width, weeks[i].name, 28);
            weekText.setFormat(Paths.font("vcr"), 28, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
            weekText.borderSize = 1.5;
            weekText.ID = i;
            grpWeekTitles.add(weekText);
        }

        diffText = new FlxText(FlxG.width - 320, 480, 300, "< NORMAL >", 24);
        diffText.setFormat(Paths.font("vcr"), 24, FlxColor.WHITE, CENTER);
        add(diffText);

        tracklistText = new FlxText(30, 480, 300, "TRACKS\n\n", 18);
        tracklistText.setFormat(Paths.font("vcr"), 18, 0xFFE55777, CENTER);
        add(tracklistText);

        changeWeek();
        changeDifficulty();
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (Controls.instance.UI_UP_P) changeWeek(-1);
        if (Controls.instance.UI_DOWN_P) changeWeek(1);
        if (Controls.instance.UI_LEFT_P) changeDifficulty(-1);
        if (Controls.instance.UI_RIGHT_P) changeDifficulty(1);

        if (Controls.instance.BACK) {
            AssetHelper.playSoundSafely("cancelMenu", 0.7);
            MusicBeatState.switchState(new MainMenuState());
        }

        if (Controls.instance.ACCEPT && weeks.length > 0) {
            var currentWeek = weeks[curWeek];
            PlayState.curSong = currentWeek.songs[0].toLowerCase();
            PlayState.curDifficulty = Difficulty.defaultList[curDifficulty];
            MusicBeatState.switchState(new PlayState());
        }
    }

    private function changeWeek(change:Int = 0):Void {
        curWeek = FlxMath.wrap(curWeek + change, 0, weeks.length - 1);
        AssetHelper.playSoundSafely("scrollMenu", 0.7);

        for (item in grpWeekTitles.members) {
            item.alpha = (item.ID == curWeek) ? 1.0 : 0.4;
        }

        var trackStr = "TRACKS\n\n";
        for (song in weeks[curWeek].songs) {
            trackStr += song.toUpperCase() + "\n";
        }
        tracklistText.text = trackStr;
    }

    private function changeDifficulty(change:Int = 0):Void {
        curDifficulty = FlxMath.wrap(curDifficulty + change, 0, Difficulty.defaultList.length - 1);
        var diff = Difficulty.defaultList[curDifficulty];
        diffText.text = '< ${diff.toUpperCase()} >';
        diffText.color = Difficulty.getColor(diff);
    }
}