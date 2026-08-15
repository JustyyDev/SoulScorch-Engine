package soulscorch.ui.menus;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import soulscorch.core.Scene;
import soulscorch.gameplay.PlayState;

class StoryMenuState extends Scene {
    var scoreText:FlxText;
    var curDifficulty:Int = 1;
    var curWeek:Int = 0;
    
    var txtWeekTitle:FlxText;
    
    var weekNames:Array<String> = ["Tutorial", "Week 1"];
    var weekSongs:Array<Array<String>> = [["tutorial"], ["bopeebo", "fresh", "dadbattle"]];
    var diffs:Array<String> = ["easy", "normal", "hard"];

    override public function create():Void {
        super.create();

        var bgYellow:FlxSprite = new FlxSprite(0, 56).makeGraphic(FlxG.width, 400, 0xFFF9CF51);
        add(bgYellow);

        scoreText = new FlxText(10, 10, 0, "SCORE: 0", 36);
        add(scoreText);

        txtWeekTitle = new FlxText(FlxG.width * 0.7, 10, 0, "", 32);
        txtWeekTitle.alignment = RIGHT;
        txtWeekTitle.alpha = 0.7;
        add(txtWeekTitle);

        changeWeek();
        changeDifficulty();
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (FlxG.keys.justPressed.UP) changeWeek(-1);
        if (FlxG.keys.justPressed.DOWN) changeWeek(1);
        if (FlxG.keys.justPressed.LEFT) changeDifficulty(-1);
        if (FlxG.keys.justPressed.RIGHT) changeDifficulty(1);

        if (FlxG.keys.justPressed.ENTER) {
            FlxG.switchState(new PlayState(weekSongs[curWeek][0], diffs[curDifficulty]));
        }

        if (FlxG.keys.justPressed.ESCAPE) {
            FlxG.switchState(new MainMenuState());
        }
    }

    function changeWeek(change:Int = 0):Void {
        curWeek += change;
        if (curWeek >= weekNames.length) curWeek = 0;
        if (curWeek < 0) curWeek = weekNames.length - 1;
        
        txtWeekTitle.text = weekNames[curWeek].toUpperCase();
    }

    function changeDifficulty(change:Int = 0):Void {
        curDifficulty += change;
        if (curDifficulty >= diffs.length) curDifficulty = 0;
        if (curDifficulty < 0) curDifficulty = diffs.length - 1;
    }
}