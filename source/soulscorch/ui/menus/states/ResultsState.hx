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
import soulscorch.ui.hud.Alphabet;
import soulscorch.ui.menus.states.FreeplayState;

class ResultsState extends MusicBeatState {
    private var stats:SongStats;
    private var bg:FlxSprite;

    private var rankAlphabet:Alphabet;
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

        var titleAlphabet = new Alphabet(40, 25, '${stats.songId} [${stats.difficulty}]', true);
        titleAlphabet.scale.set(0.6, 0.6);
        add(titleAlphabet);

        rankAlphabet = new Alphabet(FlxG.width - 280, 100, stats.rating, true);
        rankAlphabet.scale.set(0, 0);
        add(rankAlphabet);

        scoreText = new FlxText(40, 120, 600, 'Score: ${stats.score}\nAccuracy: ${Math.round(stats.accuracy * 100) / 100}%\nCombo Breaks: ${stats.misses}', 24);
        scoreText.setFormat(Paths.font("vcr"), 24, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
        scoreText.borderSize = 2.0;
        add(scoreText);

        hitStatsText = new FlxText(40, 260, 600, 'Sicks: ${stats.sicks}\nGoods: ${stats.goods}\nBads: ${stats.bads}\nShits: ${stats.shits}', 20);
        hitStatsText.setFormat(Paths.font("vcr"), 20, 0xFFBBBBBB, LEFT, OUTLINE, FlxColor.BLACK);
        add(hitStatsText);

        var continueAlphabet = new Alphabet(0, FlxG.height - 70, "PRESS ACCEPT TO CONTINUE", true);
        continueAlphabet.scale.set(0.5, 0.5);
        continueAlphabet.alignment = CENTER;
        continueAlphabet.screenCenter(X);
        add(continueAlphabet);

        FlxTween.tween(rankAlphabet.scale, {x: 1.0, y: 1.0}, 0.6, {ease: FlxEase.backOut});
        AssetHelper.playSoundSafely("confirmMenu", 0.7);
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (Controls.instance.ACCEPT || Controls.instance.BACK) {
            MusicBeatState.switchState(new FreeplayState());
        }
    }
}