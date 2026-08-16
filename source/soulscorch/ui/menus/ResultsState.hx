package soulscorch.ui.menus;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import soulscorch.core.Scene;
import soulscorch.core.SaveData;
import soulscorch.core.Achievements;
import soulscorch.gameplay.SongStats;
import soulscorch.assets.Paths;

/**
 * Post-song results screen. Shows score, accuracy, rating, and new best state.
 */
class ResultsState extends Scene {
    var stats:SongStats;
    var bg:FlxSprite;
    var titleText:FlxText;
    var infoText:FlxText;
    var ratingText:FlxText;
    var bestText:FlxText;
    var enterDelay:Float = 0.0;

    public function new(stats:SongStats) {
        super();
        this.stats = stats;
    }

    override public function create():Void {
        super.create();

        bg = new FlxSprite().loadGraphic(Paths.image('images/menus/menuBG'));
        bg.scrollFactor.set(0, 0);
        bg.screenCenter();
        bg.antialiasing = true;
        add(bg);

        var dim = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0x99000000);
        add(dim);

        titleText = new FlxText(0, 60, FlxG.width, stats.songId.toUpperCase() + " [" + stats.difficulty.toUpperCase() + "]", 36);
        titleText.setFormat(null, 36, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        titleText.borderSize = 3;
        add(titleText);

        ratingText = new FlxText(0, 140, FlxG.width, "Rating: " + stats.rating, 48);
        ratingText.setFormat(null, 48, stats.fc ? FlxColor.YELLOW : FlxColor.CYAN, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        ratingText.borderSize = 3;
        add(ratingText);

        infoText = new FlxText(0, 230, FlxG.width,
            "Score: " + stats.score + "\n" +
            "Accuracy: " + Math.round(stats.accuracy * 100) / 100 + "%\n" +
            "Misses: " + stats.misses + "\n" +
            "Hits: " + stats.hits + "\n" +
            (stats.fc ? "FULL COMBO!" : ""), 24);
        infoText.setFormat(null, 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        infoText.borderSize = 2;
        add(infoText);

        var best = SaveData.instance.getBest(stats.songId, stats.difficulty);
        bestText = new FlxText(0, 430, FlxG.width,
            stats.isNewBest ? "NEW PERSONAL BEST!" : "Personal Best: " + best.score, 22);
        bestText.setFormat(null, 22, stats.isNewBest ? FlxColor.LIME : FlxColor.GRAY, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        bestText.borderSize = 2;
        add(bestText);

        var hint = new FlxText(0, FlxG.height - 50, FlxG.width, "Press ENTER to continue", 18);
        hint.setFormat(null, 18, FlxColor.WHITE, CENTER);
        add(hint);

        // Animate rating pop
        ratingText.scale.set(0, 0);
        FlxTween.tween(ratingText.scale, {x: 1, y: 1}, 0.5, {ease: FlxEase.backOut});

        evaluateAchievements();
    }

    function evaluateAchievements():Void {
        if (stats.cleared) Achievements.instance.unlock("first_clear");
        if (stats.fc) Achievements.instance.unlock("fc_master");
        if (stats.accuracy >= 95.0) Achievements.instance.unlock("s_rank");
        if (stats.score >= 100000) Achievements.instance.unlock("score_100k");
        if (stats.accuracy >= 100.0 && stats.fc) Achievements.instance.unlock("no_miss_streak");
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        enterDelay += elapsed;

        if (enterDelay > 0.5 && FlxG.keys.justPressed.ENTER) {
            FlxG.switchState(new FreeplayState());
        }
    }
}
