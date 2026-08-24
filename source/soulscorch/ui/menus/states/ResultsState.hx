package soulscorch.ui.menus.states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
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
import soulscorch.backend.localization.LanguageManager;
import soulscorch.backend.system.modules.discord.DiscordRPC;
import soulscorch.gameplay.scoring.SongStats;
import soulscorch.ui.hud.Alphabet;
import soulscorch.ui.menus.editors.editorui.EditorTheme;
import soulscorch.ui.menus.states.FreeplayState;

using StringTools;

class ResultsState extends MusicBeatState {
    private var stats:SongStats;
    private var bg:FlxSprite;

    private var rankCard:FlxSpriteGroup;
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

        var resultsMusic = Paths.music("results");
        if (resultsMusic == null) resultsMusic = Paths.music("breakfast");
        if (resultsMusic != null) {
            FlxG.sound.playMusic(resultsMusic, 0);
            if (FlxG.sound.music != null) {
                FlxTween.cancelTweensOf(FlxG.sound.music);
                FlxG.sound.music.fadeIn(1.0, 0, 0.7);
            }
        }

        bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, EditorTheme.BG_DARK);
        bg.scrollFactor.set(0, 0);
        add(bg);

        var grid = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.TRANSPARENT);
        for (i in 0...Std.int(FlxG.width / 40)) {
            grid.pixels.fillRect(new openfl.geom.Rectangle(i * 40, 0, 1, FlxG.height), 0x08FFFFFF);
        }
        for (i in 0...Std.int(FlxG.height / 40)) {
            grid.pixels.fillRect(new openfl.geom.Rectangle(0, i * 40, FlxG.width, 1), 0x08FFFFFF);
        }
        grid.dirty = true;
        add(grid);

        var topBar = new FlxSprite(0, 0).makeGraphic(FlxG.width, 68, EditorTheme.PANEL_HEADER);
        add(topBar);

        var topBorder = new FlxSprite(0, 67).makeGraphic(FlxG.width, 1, EditorTheme.PANEL_BORDER);
        add(topBorder);

        var accentTag = new FlxSprite(25, 18).makeGraphic(4, 28, EditorTheme.ACCENT_CYAN);
        add(accentTag);

        var songTitle = stats != null ? stats.songId.toUpperCase() : "TUTORIAL";
        var songDiff = stats != null ? stats.difficulty.toUpperCase() : "NORMAL";

        var headerTitle = new FlxText(38, 16, 500, '$songTitle [$songDiff]', 20);
        headerTitle.setFormat(Paths.font("vcr"), 20, EditorTheme.TEXT_PRIMARY, LEFT);
        add(headerTitle);

        var headerSub = new FlxText(38, 38, 500, LanguageManager.getString("results.summary", "PERFORMANCE METRICS & CLEAR SUMMARY"), 11);
        headerSub.setFormat(Paths.font("vcr"), 11, EditorTheme.TEXT_MUTED, LEFT);
        add(headerSub);

        var leftCard = new FlxSpriteGroup(40, 95);
        add(leftCard);

        var cardBg = new FlxSprite(0, 0).makeGraphic(Std.int(FlxG.width * 0.52), 480, EditorTheme.PANEL_BG);
        leftCard.add(cardBg);

        var cardBorder = new FlxSprite(-1, -1).makeGraphic(Std.int(FlxG.width * 0.52) + 2, 482, EditorTheme.PANEL_BORDER);
        leftCard.add(cardBorder);

        var cardHead = new FlxSprite(0, 0).makeGraphic(Std.int(FlxG.width * 0.52), 32, EditorTheme.PANEL_HEADER);
        leftCard.add(cardHead);

        var cardHeadTxt = new FlxText(16, 8, 300, LanguageManager.getString("results.accuracyScore", "ACCURACY & SCORE TALLY"), 12);
        cardHeadTxt.setFormat(Paths.font("vcr"), 12, EditorTheme.TEXT_PRIMARY, LEFT);
        leftCard.add(cardHeadTxt);

        var scoreVal = stats != null ? stats.score : 0;
        var accVal = stats != null ? Math.round(stats.accuracy * 100) / 100 : 0;
        var missesVal = stats != null ? stats.misses : 0;

        var lblTotalScore = LanguageManager.getString("results.totalScore", "TOTAL SCORE: {0}", [scoreVal]);
        var lblAccRating = LanguageManager.getString("results.accuracyRating", "ACCURACY RATING: {0}%", [accVal]);
        var lblComboBreaks = LanguageManager.getString("results.comboBreaks", "COMBO BREAKS (MISSES): {0}", [missesVal]);

        scoreText = new FlxText(24, 52, cardBg.width - 48,
            '$lblTotalScore\n\n' +
            '$lblAccRating\n\n' +
            '$lblComboBreaks',
            20
        );
        scoreText.setFormat(Paths.font("vcr"), 20, EditorTheme.TEXT_PRIMARY, LEFT);
        leftCard.add(scoreText);

        var sicks = stats != null ? stats.sicks : 0;
        var marvels = stats != null ? stats.marvelouses : 0;
        var goods = stats != null ? stats.goods : 0;
        var bads = stats != null ? stats.bads : 0;
        var shits = stats != null ? stats.shits : 0;

        var lblBreakdown = LanguageManager.getString("results.breakdown", "JUDGMENT BREAKDOWN:");
        hitStatsText = new FlxText(24, 220, cardBg.width - 48,
            '$lblBreakdown\n\n' +
            '  ★ MARVELOUS: $marvels\n' +
            '  • SICK: $sicks\n' +
            '  • GOOD: $goods\n' +
            '  • BAD: $bads\n' +
            '  • SHIT: $shits',
            16
        );
        hitStatsText.setFormat(Paths.font("vcr"), 16, EditorTheme.TEXT_MUTED, LEFT);
        leftCard.add(hitStatsText);

        rankCard = new FlxSpriteGroup(FlxG.width - 420, 95);
        add(rankCard);

        var rankBg = new FlxSprite(0, 0).makeGraphic(380, 480, EditorTheme.PANEL_BG);
        rankCard.add(rankBg);

        var rankBorder = new FlxSprite(-1, -1).makeGraphic(382, 482, EditorTheme.PANEL_BORDER);
        rankCard.add(rankBorder);

        var rankHead = new FlxSprite(0, 0).makeGraphic(380, 32, EditorTheme.PANEL_HEADER);
        rankCard.add(rankHead);

        var rankHeadTxt = new FlxText(16, 8, 300, LanguageManager.getString("results.finalRank", "FINAL CLEAR RANK"), 12);
        rankHeadTxt.setFormat(Paths.font("vcr"), 12, EditorTheme.TEXT_PRIMARY, LEFT);
        rankCard.add(rankHeadTxt);

        var rankStr = stats != null ? stats.rating : "?";
        rankAlphabet = new Alphabet(0, 110, rankStr, true);
        rankAlphabet.scale.set(0.01, 0.01);
        rankAlphabet.alignment = CENTER;
        rankAlphabet.screenCenter(X);
        rankCard.add(rankAlphabet);

        var clearType = stats != null && stats.clearType != null ? stats.clearType : "Clear";
        clearTypeText = new FlxText(0, 340, 380, '[ $clearType ]', 24);
        clearTypeText.setFormat(Paths.font("vcr"), 24, (clearType == "MFC" || clearType == "GFC" || clearType == "FC") ? EditorTheme.ACCENT_CYAN : EditorTheme.ACCENT_YELLOW, CENTER);
        rankCard.add(clearTypeText);

        var footer = new FlxSprite(0, FlxG.height - 48).makeGraphic(FlxG.width, 48, EditorTheme.PANEL_HEADER);
        add(footer);

        var footerBorder = new FlxSprite(0, FlxG.height - 48).makeGraphic(FlxG.width, 1, EditorTheme.PANEL_BORDER);
        add(footerBorder);

        var continueText = new FlxText(0, FlxG.height - 32, FlxG.width, LanguageManager.getString("results.continue", "PRESS [ENTER] TO RETURN TO FREEPLAY MENU"), 12);
        continueText.setFormat(Paths.font("vcr"), 12, EditorTheme.ACCENT_CYAN, CENTER);
        add(continueText);

        #if (mobile || debug)
        mobileControls = new MobilePad(NONE, A);
        add(mobileControls);
        Controls.instance.bindMobilePad(mobileControls);
        #end

        FlxTween.tween(rankAlphabet.scale, {x: 1.3, y: 1.3}, 0.6, {ease: FlxEase.backOut, startDelay: 0.2});
        AssetHelper.playSoundSafely("confirmMenu", 0.7);
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (Controls.instance.ACCEPT || Controls.instance.BACK) {
            if (FlxG.sound.music != null) {
                FlxTween.cancelTweensOf(FlxG.sound.music);
                FlxG.sound.music.stop();
            }
            MusicBeatState.switchState(new FreeplayState());
        }
    }

    override public function destroy():Void {
        if (FlxG.sound.music != null) {
            FlxTween.cancelTweensOf(FlxG.sound.music);
        }
        Controls.instance.unbindMobilePad();
        super.destroy();
    }
}