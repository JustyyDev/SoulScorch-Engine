package soulscorch.ui.menus.states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import haxe.Json;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.input.Controls;
import soulscorch.backend.input.MobilePad;
import soulscorch.backend.system.modules.discord.DiscordRPC;
import soulscorch.backend.utils.Logger;
import soulscorch.gameplay.PlayState;
import soulscorch.gameplay.actors.Character;
import soulscorch.gameplay.song.Difficulty;
import soulscorch.scripting.mod.ModManager;
import soulscorch.ui.hud.Alphabet;
import soulscorch.ui.menus.editors.editorui.EditorTheme;
import soulscorch.ui.menus.states.MainMenuState;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

typedef WeekData = {
    var id:String;
    var name:String;
    var songs:Array<String>;
    var characters:Array<String>;
    var ?color:String;
    var ?difficulties:Array<String>;
}

class StoryMenuState extends MusicBeatState {
    public static var curWeek:Int = 0;
    public static var curDifficulty:Int = 1;

    private var weeks:Array<WeekData> = [];
    private var grpWeekTitles:FlxTypedGroup<Alphabet>;
    private var grpWeekCharacters:FlxTypedGroup<Character>;
    private var diffText:FlxText;
    private var tracklistText:FlxText;
    private var stageBanner:FlxSprite;
    private var mobileControls:MobilePad;

    override public function create():Void {
        super.create();

        #if desktop
        DiscordRPC.changePresence("Story Campaign", "Selecting Week");
        #end

        loadWeeks();

        var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, EditorTheme.BG_DARK);
        bg.scrollFactor.set(0, 0);
        add(bg);

        stageBanner = new FlxSprite(0, 60).makeGraphic(FlxG.width, 360, 0xFFF9CF51);
        add(stageBanner);

        grpWeekCharacters = new FlxTypedGroup<Character>();
        add(grpWeekCharacters);

        // Top Banner Header
        var topBar = new FlxSprite(0, 0).makeGraphic(FlxG.width, 60, EditorTheme.PANEL_HEADER);
        add(topBar);

        var topBorder = new FlxSprite(0, 59).makeGraphic(FlxG.width, 1, EditorTheme.PANEL_BORDER);
        add(topBorder);

        var accentTag = new FlxSprite(25, 16).makeGraphic(4, 28, EditorTheme.ACCENT_CYAN);
        add(accentTag);

        var headerTitle = new FlxText(38, 17, 450, "SOULSCORCH // STORY CAMPAIGN", 18);
        headerTitle.setFormat(Paths.font("vcr"), 18, EditorTheme.TEXT_PRIMARY, LEFT);
        add(headerTitle);

        grpWeekTitles = new FlxTypedGroup<Alphabet>();
        add(grpWeekTitles);

        for (i in 0...weeks.length) {
            var weekText = new Alphabet(0, (i * 48) + 450, weeks[i].name, true);
            weekText.scale.set(0.7, 0.7);
            weekText.alignment = CENTER;
            weekText.screenCenter(X);
            weekText.ID = i;
            grpWeekTitles.add(weekText);
        }

        diffText = new FlxText(FlxG.width - 340, 460, 300, "< NORMAL >", 22);
        diffText.setFormat(Paths.font("vcr"), 22, EditorTheme.ACCENT_CYAN, CENTER, OUTLINE, FlxColor.BLACK);
        add(diffText);

        tracklistText = new FlxText(40, 460, 320, "TRACKLIST:\n\n", 16);
        tracklistText.setFormat(Paths.font("vcr"), 16, EditorTheme.TEXT_PRIMARY, LEFT);
        add(tracklistText);

        #if (mobile || debug)
        mobileControls = new MobilePad(FULL, A_B);
        add(mobileControls);
        Controls.instance.bindMobilePad(mobileControls);
        #end

        changeWeek(0);
        changeDifficulty(0);
    }

    private function loadWeeks():Void {
        weeks = [];

        #if sys
        var weekDirs = ["data/weeks", "assets/data/weeks", "assets/preload/data/weeks"];
        if (ModManager.activeMods != null) {
            for (m in ModManager.activeMods) {
                weekDirs.unshift('mods/$m/data/weeks');
                weekDirs.unshift('mods/$m/weeks');
            }
        }

        for (dir in weekDirs) {
            if (FileSystem.exists(dir) && FileSystem.isDirectory(dir)) {
                for (file in FileSystem.readDirectory(dir)) {
                    if (file.endsWith(".json")) {
                        try {
                            var content = File.getContent('$dir/$file');
                            var data:WeekData = Json.parse(content);
                            if (data.id == null) data.id = file.substr(0, file.length - 5);
                            weeks.push(data);
                        } catch (e:Dynamic) {
                            Logger.warn('Failed parsing week file $file: $e', "weeks");
                        }
                    }
                }
            }
        }
        #end

        if (weeks.length == 0) {
            weeks = [
                {
                    id: "week0",
                    name: "TEACHING TIME",
                    songs: ["Tutorial"],
                    characters: ["dad", "bf", "gf"]
                },
                {
                    id: "week1",
                    name: "SCORCHED CAMPAIGN",
                    songs: ["Bopeebo", "Fresh", "Dad Battle"],
                    characters: ["dad", "bf", "gf"]
                }
            ];
        }
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
            if (currentWeek.songs != null && currentWeek.songs.length > 0) {
                PlayState.curSong = currentWeek.songs[0].toLowerCase();
            }
            var diffs = (currentWeek.difficulties != null && currentWeek.difficulties.length > 0) ? currentWeek.difficulties : Difficulty.defaultList;
            PlayState.curDifficulty = diffs[curDifficulty];
            MusicBeatState.switchState(new PlayState());
        }
    }

    private function changeWeek(change:Int = 0):Void {
        if (weeks.length == 0) return;
        curWeek = FlxMath.wrap(curWeek + change, 0, weeks.length - 1);
        if (change != 0) AssetHelper.playSoundSafely("scrollMenu", 0.7);

        for (item in grpWeekTitles.members) {
            item.alpha = (item.ID == curWeek ? 1.0 : 0.4);
        }

        var trackStr = "TRACKLIST:\n\n";
        var currentSongs = weeks[curWeek].songs;
        if (currentSongs != null) {
            for (song in currentSongs) {
                trackStr += '• ' + song.toUpperCase() + "\n";
            }
        }
        tracklistText.text = trackStr;

        if (weeks[curWeek].color != null) {
            stageBanner.color = FlxColor.fromString(weeks[curWeek].color);
        } else {
            stageBanner.color = 0xFFF9CF51;
        }

        curDifficulty = 0;
        changeDifficulty(0);
    }

    private function changeDifficulty(change:Int = 0):Void {
        var diffs = (weeks[curWeek].difficulties != null && weeks[curWeek].difficulties.length > 0) ? weeks[curWeek].difficulties : Difficulty.defaultList;
        curDifficulty = FlxMath.wrap(curDifficulty + change, 0, diffs.length - 1);
        var diff = diffs[curDifficulty];
        diffText.text = '< ${diff.toUpperCase()} >';
        diffText.color = Difficulty.getColor(diff);
    }

    override public function destroy():Void {
        Controls.instance.unbindMobilePad();
        super.destroy();
    }
}