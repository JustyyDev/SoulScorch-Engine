package soulscorch.ui.menus.states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.input.Controls;
import soulscorch.backend.system.modules.discord.DiscordRPC;
import soulscorch.gameplay.scoring.SongStats;
import soulscorch.ui.menus.states.FreeplayState;

class ResultsState extends MusicBeatState {
    private var stats:SongStats;
    private var bg:FlxSprite;

    private var rankText:FlxText;
    private var scoreText:FlxText;
    private var hitStatsText:FlxText;

    public function new(stats:SongStats) {
        super();
        this.stats = stats;
    }

    override public function create():Void {
        super.create();

        DiscordRPC.changePresence("Results Screen", 'Rating: ${stats.rating} | Acc: ${Math.round(stats.accuracy * 100) / 100}%');

        bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF181420);
        add(bg);

        var title = new FlxText(40, 30, 0, '${stats.songId.toUpperCase()} - [${stats.difficulty.toUpperCase()}]', 28);
        title.setFormat(Paths.font("vcr"), 28, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
        add(title);

        rankText = new FlxText(FlxG.width - 320, 80, 260, stats.rating, 100);
        rankText.setFormat(Paths.font("vcr"), 100, 0xFFFFCC00, CENTER, OUTLINE, FlxColor.BLACK);
        rankText.borderSize = 4.0;
        rankText.scale.set(0, 0);
        add(rankText);

        scoreText = new FlxText(40, 120, 600, 'Score: ${stats.score}\nAccuracy: ${Math.round(stats.accuracy * 100) / 100}%\nCombo Break / Misses: ${stats.misses}', 24);
        scoreText.setFormat(Paths.font("vcr"), 24, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
        scoreText.borderSize = 2.0;
        add(scoreText);

        hitStatsText = new FlxText(40, 280, 600, 'Sicks: ${stats.sicks}\nGoods: ${stats.goods}\nBads: ${stats.bads}\nShits: ${stats.shits}', 20);
        hitStatsText.setFormat(Paths.font("vcr"), 20, 0xFFBBBBBB, LEFT, OUTLINE, FlxColor.BLACK);
        add(hitStatsText);

        var continueTxt = new FlxText(0, FlxG.height - 50, FlxG.width, "Press ACCEPT to Continue", 18);
        continueTxt.setFormat(Paths.font("vcr"), 18, FlxColor.WHITE, CENTER);
        add(continueTxt);

        FlxTween.tween(rankText.scale, {x: 1.0, y: 1.0}, 0.6, {ease: FlxEase.backOut});
        AssetHelper.playSoundSafely("confirmMenu", 0.7);
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (Controls.instance.ACCEPT || Controls.instance.BACK) {
            MusicBeatState.switchState(new FreeplayState());
        }
    }
}