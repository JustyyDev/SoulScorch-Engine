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
import soulscorch.backend.input.MobilePad;
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
    private var clearTypeText:FlxText;
    private var mobileControls:MobilePad;

    public function new(stats:SongStats) {
        super();
        this.stats = stats;
    }

    override public function create():Void {
        super.create();

        #if desktop
        if (stats != null) {
            DiscordRPC.changePresence("Results Screen", 'Rating: ${stats.rating} | Acc: ${Math.round(stats.accuracy * 100) / 100}%');
        }
        #end

        bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF14101A);
        add(bg);

        var titleStr = stats != null ? '${stats.songId} [${stats.difficulty}]' : "Results";
        var titleAlphabet = new Alphabet(40, 25, titleStr, true);
        titleAlphabet.scale.set(0.65, 0.65);
        add(titleAlphabet);

        var rankStr = stats != null ? stats.rating : "?";
        rankAlphabet = new Alphabet(FlxG.width - 290, 100, rankStr, true);
        rankAlphabet.scale.set(0.001, 0.001);
        add(rankAlphabet);

        var clearType = stats != null && stats.clearType != null ? stats.clearType : "Clear";
        clearTypeText = new FlxText(FlxG.width - 320, 240, 300, clearType, 28);
        clearTypeText.setFormat(Paths.font("vcr"), 28, (clearType == "MFC" || clearType == "GFC" || clearType == "FC") ? 0xFF00FFCC : FlxColor.YELLOW, CENTER, OUTLINE, FlxColor.BLACK);
        clearTypeText.borderSize = 1.5;
        add(clearTypeText);

        var scoreVal = stats != null ? stats.score : 0;
        var accVal = stats != null ? Math.round(stats.accuracy * 100) / 100 : 0;
        var missesVal = stats != null ? stats.misses : 0;
        scoreText = new FlxText(40, 120, 600, 'Score: $scoreVal\nAccuracy: $accVal%\nCombo Breaks: $missesVal', 24);
        scoreText.setFormat(Paths.font("vcr"), 24, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
        scoreText.borderSize = 2.0;
        add(scoreText);

        var sicks = stats != null ? stats.sicks : 0;
        var goods = stats != null ? stats.goods : 0;
        var bads = stats != null ? stats.bads : 0;
        var shits = stats != null ? stats.shits : 0;
        hitStatsText = new FlxText(40, 260, 600, 'Sicks: $sicks\nGoods: $goods\nBads: $bads\nShits: $shits', 20);
        hitStatsText.setFormat(Paths.font("vcr"), 20, 0xFFCCCCCC, LEFT, OUTLINE, FlxColor.BLACK);
        add(hitStatsText);

        var continueAlphabet = new Alphabet(0, FlxG.height - 70, "PRESS ACCEPT TO CONTINUE", true);
        continueAlphabet.scale.set(0.5, 0.5);
        continueAlphabet.alignment = CENTER;
        continueAlphabet.screenCenter(X);
        add(continueAlphabet);

        #if (mobile || debug)
        mobileControls = new MobilePad(NONE, A);
        add(mobileControls);
        Controls.instance.bindMobilePad(mobileControls);
        #end

        FlxTween.tween(rankAlphabet.scale, {x: 1.0, y: 1.0}, 0.6, {ease: FlxEase.backOut});
        AssetHelper.playSoundSafely("confirmMenu", 0.7);
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (Controls.instance.ACCEPT || Controls.instance.BACK) {
            MusicBeatState.switchState(new FreeplayState());
        }
    }

    override public function destroy():Void {
        Controls.instance.unbindMobilePad();
        super.destroy();
    }
}