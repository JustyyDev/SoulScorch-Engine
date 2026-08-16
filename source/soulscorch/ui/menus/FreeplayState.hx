package soulscorch.ui.menus;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.math.FlxMath;
import soulscorch.core.Scene;
import soulscorch.core.Runtime;
import soulscorch.core.SaveData;
import soulscorch.core.EventBus;
import soulscorch.assets.Paths;
import soulscorch.assets.AssetHelper;
import soulscorch.ui.Alphabet;
import soulscorch.gameplay.PlayState;

class FreeplayState extends Scene {
    var curSelected:Int = 0;
    var songs:Array<String> = ["Test Song", "Soulburn", "Scorch", "Extinction"];
    var grpSongs:FlxTypedGroup<Alphabet>;
    var bg:FlxSprite;
    var scoreText:FlxText;
    var headerText:FlxText;
    var panel:FlxSprite;
    var lerpScore:Int = 0;
    var intendedScore:Int = 0;
    var difficultyText:FlxText;
    var difficultyIndex:Int = 1;
    var difficulties:Array<String> = [
        "easy",
        "normal",
        "hard"
    ];

    override public function create():Void {
        super.create();
        #if desktop
        soulscorch.backend.DiscordRPC.changePresence("In the Menus", "Freeplay Menu");
        #end

        bg = new FlxSprite();
        AssetHelper.loadGraphicSafely(bg, 'images/menus/menuBG');
        bg.scrollFactor.set(0, 0);
        bg.screenCenter();
        bg.antialiasing = Runtime.engine.config.antialiasing;
        add(bg);

        panel = new FlxSprite(60, 40).makeGraphic(FlxG.width - 120, FlxG.height - 80, 0x22000000);
        panel.alpha = 0.9;
        add(panel);

        headerText = new FlxText(0, 48, 0, "FREEPLAY", 28);
        headerText.setFormat(null, 28, 0xFFBEEBFF, CENTER, FlxTextBorderStyle.OUTLINE, 0xFF123D7A);
        headerText.borderSize = 2;
        headerText.screenCenter(X);
        add(headerText);

        grpSongs = new FlxTypedGroup<Alphabet>();
        add(grpSongs);

        for (i in 0...songs.length) {
            var songText:Alphabet = new Alphabet(0, (i * 70) + 30, songs[i], true);
            songText.isBold = true;
            songText.x += 100;
            grpSongs.add(songText);
        }

        scoreText = new FlxText(FlxG.width * 0.7, 5, 0, "", 32);
        scoreText.setFormat(null, 32, 0xFFB8F6FF, CENTER, FlxTextBorderStyle.OUTLINE, 0xFF123D7A);
        scoreText.borderSize = 2;
        
        var scoreBG:FlxSprite = new FlxSprite(scoreText.x - 6, 0).makeGraphic(Std.int(FlxG.width * 0.35), 66, 0xFF0A1428);
        scoreBG.alpha = 0.8;
        add(scoreBG);
        add(scoreText);

        difficultyText = new FlxText(FlxG.width * 0.68, FlxG.height - 92, FlxG.width * 0.25, "", 18);
        difficultyText.setFormat(null, 18, 0xFFFFFF00, CENTER);
        add(difficultyText);

        changeSelection();
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (FlxG.sound.music != null && FlxG.sound.music.volume < 0.7) {
            FlxG.sound.music.volume += 0.5 * elapsed;
        }

        lerpScore = Std.int(FlxMath.lerp(lerpScore, intendedScore, 0.4));
        scoreText.text = "PERSONAL BEST: " + lerpScore;

        if (FlxG.keys.justPressed.UP) {
            FlxG.sound.play(Paths.sound('sounds/menu/scroll'));
            changeSelection(-1);
        }
        if (FlxG.keys.justPressed.DOWN) {
            FlxG.sound.play(Paths.sound('sounds/menu/scroll'));
            changeSelection(1);
        }
        if (FlxG.keys.justPressed.LEFT) changeDifficulty(-1);
        if (FlxG.keys.justPressed.RIGHT) changeDifficulty(1);

        if (FlxG.keys.justPressed.BACKSPACE) {
            FlxG.sound.play(Paths.sound('sounds/menu/cancel'));
            FlxG.switchState(new MainMenuState());
        }

        if (FlxG.keys.justPressed.ENTER) {
            FlxG.sound.play(Paths.sound('sounds/menu/confirm'));
            var songId = StringTools.replace(songs[curSelected].toLowerCase(), " ", "-");
            var difficulty:String = difficulties[difficultyIndex];
            EventBus.publish("freeplay/start", {song: songId, difficulty: difficulty});
            FlxG.switchState(new PlayState(songId, difficulty));
        }
        
        if (FlxG.keys.justPressed.M) {
            openSubState(new ModSwitchMenu());
        }
    }

    function changeSelection(change:Int = 0):Void {
        curSelected += change;
        if (curSelected < 0) curSelected = songs.length - 1;
        if (curSelected >= songs.length) curSelected = 0;

        var songId = StringTools.replace(songs[curSelected].toLowerCase(), " ", "-");
        var best = SaveData.instance.getBest(songId, difficulties[difficultyIndex]);
        intendedScore = best != null ? best.score : 0;

        var bullShit:Int = 0;
        grpSongs.forEach(function(basic:flixel.FlxBasic):Void {
            var item:Alphabet = cast basic;
            if (item == null) return;
            item.y = (bullShit - curSelected) * 70 + (FlxG.height / 2);
            bullShit++;
            item.alpha = 0.6;
            item.color = 0xFFCEE9FF;
            if (item.y == (FlxG.height / 2)) {
                item.alpha = 1.0;
                item.color = 0xFF7AE8FF;
            }
        });
        if (difficultyText != null) difficultyText.text = "DIFFICULTY  < " + difficulties[difficultyIndex].toUpperCase() + " >";
    }

    function changeDifficulty(change:Int):Void {
        difficultyIndex = (difficultyIndex + change) % difficulties.length;
        if (difficultyIndex < 0) difficultyIndex += difficulties.length;
        changeSelection();
    }
}