package soulscorch.ui.menus;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxGroup.FlxTypedGroup;
import soulscorch.backend.MusicBeatState;
import soulscorch.core.EventBus;
import soulscorch.gameplay.PlayState;
import soulscorch.assets.Paths;
import soulscorch.assets.AssetHelper;
import soulscorch.modding.ModManager;
import soulscorch.assets.AssetResolver;
#if sys
import sys.FileSystem;
#end

class StoryMenuState extends MusicBeatState {
    var scoreText:FlxText;
    var curDifficulty:Int = 1;
    var curWeek:Int = 0;
    
    var txtWeekTitle:FlxText;
    var songListText:FlxText;
    var difficultyText:FlxText;
    var hintText:FlxText;
    var weekPanel:FlxSprite;
    var characterGroup:FlxTypedGroup<FlxSprite>;
    var weekBanner:FlxSprite;
    
    var weekNames:Array<String> = ["Tutorial", "Week 1"];
    var weekSongs:Array<Array<String>> = [["tutorial"], ["bopeebo", "fresh", "dadbattle"]];
    var diffs:Array<String> = ["easy", "normal", "hard", "custom"];

    override public function create():Void {
        super.create();

        var background:FlxSprite = new FlxSprite();
        AssetHelper.loadGraphicSafely(background, 'images/menus/menuBG');
        background.scrollFactor.set(0, 0);
        background.screenCenter();
        add(background);

        var tint:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xB9101C2A);
        add(tint);

        weekPanel = new FlxSprite(72, 112).makeGraphic(FlxG.width - 144, FlxG.height - 210, 0xCC102638);
        add(weekPanel);

        weekBanner = new FlxSprite(FlxG.width * 0.5 - 150, 125);
        loadWeekBanner();
        add(weekBanner);

        characterGroup = new FlxTypedGroup<FlxSprite>();
        add(characterGroup);
        characterGroup.add(loadCharacter("dad", 260, 275, "Dad idle dance BLACK LINE"));
        characterGroup.add(loadCharacter("bf", 680, 330, "BF HEY!!"));
        characterGroup.add(loadCharacter("gf", 485, 325, "GF Dancing Beat WHITE"));

        scoreText = new FlxText(78, 28, 0, "WEEK SCORE: 0", 20);
        scoreText.color = FlxColor.CYAN;
        add(scoreText);

        txtWeekTitle = new FlxText(0, 36, 0, "", 30);
        txtWeekTitle.alignment = RIGHT;
        txtWeekTitle.color = FlxColor.WHITE;
        txtWeekTitle.x = FlxG.width - 350;
        txtWeekTitle.fieldWidth = 270;
        add(txtWeekTitle);

        songListText = new FlxText(120, 160, FlxG.width - 240, "", 26);
        songListText.color = FlxColor.WHITE;
        add(songListText);

        difficultyText = new FlxText(0, FlxG.height - 142, 0, "", 24);
        difficultyText.setFormat(null, 24, FlxColor.YELLOW, CENTER);
        difficultyText.screenCenter(X);
        add(difficultyText);

        hintText = new FlxText(0, FlxG.height - 66, 0, "UP/DOWN WEEK    LEFT/RIGHT DIFFICULTY    ENTER PLAY    ESC BACK", 13);
        hintText.setFormat(null, 13, 0xFF9FB6C7, CENTER);
        hintText.screenCenter(X);
        add(hintText);

        changeWeek();
        changeDifficulty();
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (FlxG.keys.justPressed.UP) { FlxG.sound.play(Paths.sound('sounds/menu/scroll')); changeWeek(-1); }
        if (FlxG.keys.justPressed.DOWN) { FlxG.sound.play(Paths.sound('sounds/menu/scroll')); changeWeek(1); }
        if (FlxG.keys.justPressed.LEFT) { FlxG.sound.play(Paths.sound('sounds/menu/scroll')); changeDifficulty(-1); }
        if (FlxG.keys.justPressed.RIGHT) { FlxG.sound.play(Paths.sound('sounds/menu/scroll')); changeDifficulty(1); }

        if (FlxG.keys.justPressed.ENTER) {
            FlxG.sound.play(Paths.sound('sounds/menu/confirm'));
            EventBus.publish("story/start", {song: weekSongs[curWeek][0], difficulty: diffs[curDifficulty]});
            FlxG.switchState(new PlayState(weekSongs[curWeek][0], diffs[curDifficulty]));
        }

        if (FlxG.keys.justPressed.ESCAPE) {
            FlxG.sound.play(Paths.sound('sounds/menu/cancel'));
            FlxG.switchState(new MainMenuState());
        }
    }

    override public function beatHit(beat:Int):Void {
        super.beatHit(beat);
        if (characterGroup == null) return;
        characterGroup.forEach(function(basic:flixel.FlxBasic):Void {
            var character:FlxSprite = cast basic;
            if (character != null && character.frames != null && character.animation.getByName("idle") != null) character.animation.play("idle", true);
        });
    }

    function changeWeek(change:Int = 0):Void {
        curWeek += change;
        if (curWeek >= weekNames.length) curWeek = 0;
        if (curWeek < 0) curWeek = weekNames.length - 1;
        
        txtWeekTitle.text = weekNames[curWeek].toUpperCase();
        updateWeekDetails();
        loadWeekBanner();
    }

    function changeDifficulty(change:Int = 0):Void {
        curDifficulty += change;
        if (curDifficulty >= diffs.length) curDifficulty = 0;
        if (curDifficulty < 0) curDifficulty = diffs.length - 1;
        updateWeekDetails();
    }

    function updateWeekDetails():Void {
        if (songListText == null || difficultyText == null) return;
        var lines:Array<String> = [];
        for (song in weekSongs[curWeek]) lines.push("  " + song.toUpperCase());
        songListText.text = "TRACKLIST\n\n" + lines.join("\n");
        difficultyText.text = "DIFFICULTY   <  " + diffs[curDifficulty].toUpperCase() + "  >";
        scoreText.text = "WEEK SCORE: 0\n" + weekSongs[curWeek].length + " TRACKS";
    }

    private function loadWeekBanner():Void {
        if (weekBanner == null) return;
        var bannerName:String = curWeek == 0 ? "tutorial" : "week1";
        var path:String = ModManager.getPath('images/menus/storymenu/weeks/$bannerName.png');
        #if sys
        if (path != null && FileSystem.exists(path)) {
            weekBanner.loadGraphic(path);
            weekBanner.setGraphicSize(300);
            weekBanner.updateHitbox();
            return;
        }
        #end
        weekBanner.makeGraphic(300, 64, 0xFF1E6684);
    }

    private function loadCharacter(id:String, x:Float, y:Float, prefix:String):FlxSprite {
        var character:FlxSprite = new FlxSprite(x, y);
        var imagePath:String = ModManager.getPath('images/menus/storymenu/characters/$id.png');
        var xmlPath:String = ModManager.getPath('images/menus/storymenu/characters/$id.xml');
        #if sys
        if (AssetHelper.loadSparrowSafely(character, 'images/menus/storymenu/characters/$id.png', 'images/menus/storymenu/characters/$id.xml')) {
            try {
                character.animation.addByPrefix("idle", prefix, 12, false);
                character.animation.play("idle");
                character.setGraphicSize(Std.int(character.width * 0.25));
                character.updateHitbox();
                return character;
            } catch (error:Dynamic) {}
        }
        #end
        character.makeGraphic(110, 180, id == "dad" ? 0xFF7C4BA5 : id == "bf" ? 0xFF3D7DCE : 0xFFD96BAA);
        return character;
    }
}