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
import haxe.xml.Access;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.input.Controls;
import soulscorch.backend.input.MobilePad;
import soulscorch.backend.system.XMSoul;
import soulscorch.backend.system.modules.discord.DiscordRPC;
import soulscorch.backend.utils.Logger;
import soulscorch.gameplay.PlayState;
import soulscorch.gameplay.song.Difficulty;
import soulscorch.scripting.ScriptManager;
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
    var sprite:String;
    var songs:Array<String>;
    var characters:Array<String>;
    var ?color:String;
    var ?difficulties:Array<String>;
}

class StoryMenuState extends MusicBeatState {
    public static var curWeek:Int = 0;
    public static var curDifficulty:Int = 1;

    private var weeks:Array<WeekData> = [];
    private var grpWeekTitles:FlxTypedGroup<FlxSprite>;
    private var grpWeekPortraits:FlxTypedGroup<FlxSprite>;
    private var diffText:FlxText;
    private var tracklistText:FlxText;
    private var weekNameText:FlxText;
    private var stageBanner:FlxSprite;
    private var mobileControls:MobilePad;
    private var scripts:ScriptManager;
    private var movedBack:Bool = false;
    private var selectedWeek:Bool = false;

    override public function create():Void {
        super.create();

        #if desktop
        DiscordRPC.changePresence("Story Campaign", "Selecting Week");
        #end

        if (FlxG.sound.music == null || !FlxG.sound.music.playing) {
            FlxG.sound.playMusic(Paths.music("freakyMenu"), 0.7);
        }

        scripts = new ScriptManager();
        initStoryScripts();

        loadWeeks();

        var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, EditorTheme.BG_DARK);
        bg.scrollFactor.set(0, 0);
        add(bg);

        stageBanner = new FlxSprite(0, 60).makeGraphic(FlxG.width, 340, 0xFFF9CF51);
        stageBanner.scrollFactor.set(0, 0);
        add(stageBanner);

        grpWeekPortraits = new FlxTypedGroup<FlxSprite>();
        add(grpWeekPortraits);

        var topBar = new FlxSprite(0, 0).makeGraphic(FlxG.width, 60, EditorTheme.PANEL_HEADER);
        topBar.scrollFactor.set(0, 0);
        add(topBar);

        var topBorder = new FlxSprite(0, 59).makeGraphic(FlxG.width, 1, EditorTheme.PANEL_BORDER);
        topBorder.scrollFactor.set(0, 0);
        add(topBorder);

        var accentTag = new FlxSprite(25, 16).makeGraphic(4, 28, EditorTheme.ACCENT_CYAN);
        accentTag.scrollFactor.set(0, 0);
        add(accentTag);

        var headerTitle = new FlxText(38, 17, 450, "SOULSCORCH // STORY CAMPAIGN", 18);
        headerTitle.setFormat(Paths.font("vcr"), 18, EditorTheme.TEXT_PRIMARY, LEFT);
        headerTitle.scrollFactor.set(0, 0);
        add(headerTitle);

        grpWeekTitles = new FlxTypedGroup<FlxSprite>();
        add(grpWeekTitles);

        for (i in 0...weeks.length) {
            var week = weeks[i];
            var weekSpriteKey = (week.sprite != null && week.sprite.length > 0) ? week.sprite : week.id;

            var sprTitle = new FlxSprite(0, (i * 105) + 420);
            var loaded = AssetHelper.loadGraphicSafely(sprTitle, 'ui/storymenu/$weekSpriteKey');
            if (!loaded) loaded = AssetHelper.loadGraphicSafely(sprTitle, 'storymenu/$weekSpriteKey');
            if (!loaded) loaded = AssetHelper.loadGraphicSafely(sprTitle, 'ui/storymenu/weeks/$weekSpriteKey');
            if (!loaded) loaded = AssetHelper.loadGraphicSafely(sprTitle, weekSpriteKey);

            if (loaded) {
                sprTitle.screenCenter(X);
                sprTitle.ID = i;
                grpWeekTitles.add(sprTitle);
            } else {
                var weekText = new Alphabet(0, (i * 105) + 420, (week.name.length > 0 ? week.name : week.id).toUpperCase(), true);
                weekText.scale.set(0.75, 0.75);
                weekText.screenCenter(X);
                weekText.ID = i;
                grpWeekTitles.add(cast weekText);
            }
        }

        weekNameText = new FlxText(40, 75, FlxG.width - 80, "", 24);
        weekNameText.setFormat(Paths.font("vcr"), 24, EditorTheme.TEXT_PRIMARY, LEFT, OUTLINE, FlxColor.BLACK);
        weekNameText.borderSize = 1.5;
        add(weekNameText);

        diffText = new FlxText(FlxG.width - 340, 430, 300, "< NORMAL >", 22);
        diffText.setFormat(Paths.font("vcr"), 22, EditorTheme.ACCENT_CYAN, CENTER, OUTLINE, FlxColor.BLACK);
        diffText.borderSize = 1.5;
        add(diffText);

        tracklistText = new FlxText(40, 430, 320, "TRACKLIST:\n\n", 16);
        tracklistText.setFormat(Paths.font("vcr"), 16, EditorTheme.TEXT_PRIMARY, LEFT, OUTLINE, FlxColor.BLACK);
        tracklistText.borderSize = 1.0;
        add(tracklistText);

        #if (mobile || debug)
        mobileControls = new MobilePad(FULL, A_B);
        add(mobileControls);
        Controls.instance.bindMobilePad(mobileControls);
        #end

        changeWeek(0);
        changeDifficulty(0);

        if (scripts != null) scripts.callAll("onPostCreate");
    }

    private function initStoryScripts():Void {
        var paths = [
            "data/scripts/menus/story",
            "scripts/menus/story",
            "data/scripts/storyMenu"
        ];
        for (p in paths) {
            var file = AssetResolver.resolveFile(p, [".soul", ".hx", ".lua", ".py", ".js"]);
            if (file != null) scripts.loadScript(file);
        }
        scripts.setAll("state", this);
        scripts.setAll("weeks", weeks);
        scripts.callAll("onCreate");
    }

    private function loadWeeks():Void {
        weeks = [];

        #if sys
        var weekDirs = [
            "data/weeks/weeks",
            "assets/preload/data/weeks/weeks",
            "data/weeks",
            "assets/data/weeks",
            "assets/preload/data/weeks"
        ];

        if (ModManager.activeMods != null) {
            for (m in ModManager.activeMods) {
                weekDirs.unshift('mods/$m/data/weeks/weeks');
                weekDirs.unshift('mods/$m/data/weeks');
                weekDirs.unshift('mods/$m/weeks');
            }
        }

        var loadedWeekIds:Array<String> = [];

        for (dir in weekDirs) {
            if (FileSystem.exists(dir) && FileSystem.isDirectory(dir)) {
                for (file in FileSystem.readDirectory(dir)) {
                    var fullPath = '$dir/$file';
                    if (FileSystem.isDirectory(fullPath)) continue;

                    var fileId = file.substr(0, file.lastIndexOf("."));
                    if (loadedWeekIds.contains(fileId)) continue;

                    if (file.endsWith(".xmsoul") || file.endsWith(".xml")) {
                        try {
                            var access = XMSoul.parse(fullPath);
                            if (access != null) {
                                var weekName = XMSoul.getAttr(access, "name", fileId);
                                var charsStr = XMSoul.getAttr(access, "chars", "dad,bf,gf");
                                var spriteName = XMSoul.getAttr(access, "sprite", fileId);
                                var colorStr = access.has.resolve("color") ? access.att.resolve("color") : null;

                                var songsList:Array<String> = [];
                                if (access.hasNode.resolve("song")) {
                                    for (s in access.nodes.resolve("song")) {
                                        var songName = s.innerData.trim();
                                        if (songName.length > 0) songsList.push(songName);
                                    }
                                }

                                weeks.push({
                                    id: fileId,
                                    name: weekName,
                                    sprite: spriteName,
                                    songs: songsList,
                                    characters: charsStr.split(","),
                                    color: colorStr,
                                    difficulties: ["easy", "normal", "hard"]
                                });

                                loadedWeekIds.push(fileId);
                            }
                        } catch (e:Dynamic) {
                            Logger.warn('Failed parsing XML week $file: $e', "weeks");
                        }
                    } else if (file.endsWith(".json")) {
                        try {
                            var content = File.getContent(fullPath);
                            var data:WeekData = Json.parse(content);
                            if (data.id == null) data.id = fileId;
                            if (data.sprite == null) data.sprite = fileId;
                            weeks.push(data);
                            loadedWeekIds.push(fileId);
                        } catch (e:Dynamic) {
                            Logger.warn('Failed parsing JSON week $file: $e', "weeks");
                        }
                    }
                }
            }
        }
        #end

        if (weeks.length == 0) {
            weeks = [
                {
                    id: "tutorial",
                    name: "TEACHING TIME",
                    sprite: "tutorial",
                    songs: ["Tutorial"],
                    characters: ["dad", "bf", "gf"]
                },
                {
                    id: "week1",
                    name: "DADDY DEAREST",
                    sprite: "week1",
                    songs: ["Bopeebo", "Fresh", "Dadbattle"],
                    characters: ["dad", "bf", "gf"]
                }
            ];
        }
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        if (scripts != null) scripts.callAll("onUpdate", [elapsed]);

        if (!selectedWeek && !movedBack) {
            if (Controls.instance.UI_UP_P) changeWeek(-1);
            if (Controls.instance.UI_DOWN_P) changeWeek(1);
            if (Controls.instance.UI_LEFT_P) changeDifficulty(-1);
            if (Controls.instance.UI_RIGHT_P) changeDifficulty(1);

            if (Controls.instance.BACK) {
                movedBack = true;
                AssetHelper.playSoundSafely("cancelMenu", 0.7);
                MusicBeatState.switchState(new MainMenuState());
            }

            if (Controls.instance.ACCEPT && weeks.length > 0) {
                selectedWeek = true;
                AssetHelper.playSoundSafely("confirmMenu", 0.7);

                if (FlxG.sound.music != null) {
                    FlxTween.cancelTweensOf(FlxG.sound.music);
                    FlxG.sound.music.stop();
                }

                var currentWeek = weeks[curWeek];
                if (currentWeek.songs != null && currentWeek.songs.length > 0) {
                    PlayState.curSong = currentWeek.songs[0].toLowerCase().trim();
                }
                var diffs = (currentWeek.difficulties != null && currentWeek.difficulties.length > 0) ? currentWeek.difficulties : Difficulty.defaultList;
                PlayState.curDifficulty = diffs[curDifficulty];
                PlayState.isStoryMode = true;

                if (scripts != null) scripts.callAll("onSelectWeek", [currentWeek]);
                MusicBeatState.switchState(new PlayState());
            }
        }
    }

    private function changeWeek(change:Int = 0):Void {
        if (weeks.length == 0) return;
        curWeek = FlxMath.wrap(curWeek + change, 0, weeks.length - 1);
        if (change != 0) AssetHelper.playSoundSafely("scrollMenu", 0.7);

        var i = 0;
        for (item in grpWeekTitles.members) {
            item.alpha = (i == curWeek ? 1.0 : 0.35);
            item.y = ((i - curWeek) * 105) + 420;
            item.screenCenter(X);
            i++;
        }

        var week = weeks[curWeek];
        weekNameText.text = week.name.toUpperCase();

        var trackStr = "TRACKLIST:\n\n";
        var currentSongs = week.songs;
        if (currentSongs != null) {
            for (song in currentSongs) trackStr += '• ' + song.toUpperCase() + "\n";
        }
        tracklistText.text = trackStr;

        if (week.color != null && week.color.trim().length > 0) {
            stageBanner.color = FlxColor.fromString(week.color);
        } else {
            stageBanner.color = 0xFFF9CF51;
        }

        curDifficulty = 0;
        changeDifficulty(0);
        if (scripts != null) scripts.callAll("onChangeWeek", [curWeek]);
    }

    private function changeDifficulty(change:Int = 0):Void {
        var diffs = (weeks[curWeek].difficulties != null && weeks[curWeek].difficulties.length > 0) ? weeks[curWeek].difficulties : Difficulty.defaultList;
        curDifficulty = FlxMath.wrap(curDifficulty + change, 0, diffs.length - 1);
        var diff = diffs[curDifficulty];
        diffText.text = '< ${diff.toUpperCase()} >';
        diffText.color = Difficulty.getColor(diff);
        if (scripts != null) scripts.callAll("onChangeDifficulty", [curDifficulty, diff]);
    }

    override public function destroy():Void {
        Controls.instance.unbindMobilePad();
        if (scripts != null) {
            scripts.callAll("onDestroy");
            scripts.clear();
        }
        super.destroy();
    }
}