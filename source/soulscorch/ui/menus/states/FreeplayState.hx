package soulscorch.ui.menus.states;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import haxe.Json;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.input.Controls;
import soulscorch.backend.input.InputMap;
import soulscorch.backend.input.MobilePad;
import soulscorch.backend.localization.LanguageManager;
import soulscorch.backend.system.SaveData;
import soulscorch.backend.system.engine.Runtime;
import soulscorch.backend.system.modules.discord.DiscordRPC;
import soulscorch.gameplay.PlayState;
import soulscorch.gameplay.actors.HealthIcon;
import soulscorch.gameplay.song.Difficulty;
import soulscorch.gameplay.song.SongRegistry;
import soulscorch.gameplay.song.SongRegistry.RegisteredSong;
import soulscorch.scripting.ScriptManager;
import soulscorch.ui.hud.Alphabet;
import soulscorch.ui.menus.editors.editorui.EditorTheme;
import soulscorch.ui.menus.states.MainMenuState;

using StringTools;

class FreeplayState extends MusicBeatState {
    public static var curSelected:Int = 0;
    public static var curDifficulty:Int = 1;
    public static var lastSelectedDifficultyName:String = "normal";

    private var songs:Array<RegisteredSong> = [];

    // --- High-Performance Virtual Window Pool ---
    private static inline var VISIBLE_ITEMS_COUNT:Int = 11;
    private static inline var ITEM_SPACING:Float = 120.0;
    private var alphabetPool:Array<Alphabet> = [];
    private var iconPool:Array<HealthIcon> = [];
    private var itemSlotIndices:Array<Int> = [];

    private static var _chartMetaCache:Map<String, {bpm:Float, speed:Float}> = new Map<String, {bpm:Float, speed:Float}>();

    private var bg:FlxSprite;
    private var selectionHighlight:FlxSprite;
    private var scorePanel:FlxSpriteGroup;
    private var scoreText:FlxText;
    private var diffText:FlxText;
    private var bpmText:FlxText;
    private var speedText:FlxText;
    private var mobileControls:MobilePad;
    private var scripts:ScriptManager;
    private var shuffleBanner:FlxText;

    private var lerpScore:Int = 0;
    private var intendedScore:Int = 0;
    private var intendedAccuracy:Float = 0.0;
    private var intendedRating:String = "N/A";

    private var curBpm:Float = 100.0;
    private var curSpeed:Float = 2.0;

    private var instPreview:FlxSound;
    private var previewTimer:FlxTimer;
    private var curPlayingSong:String = "";
    private var previewVolume:Float = 0.0;
    private var previewTargetVolume:Float = 0.75;
    private var menuTargetVolume:Float = 0.7;

    private var colorTween:FlxTween;
    private var holdTimer:Float = 0.0;
    private var shuffleActive:Bool = false;
    private var shuffleElapsed:Float = 0.0;
    private var shuffleSwapElapsed:Float = 0.0;
    private var shuffleDuration:Float = 2.5;
    private var shuffleEligibleIndices:Array<Int> = [];
    private var shuffleLaunchTimer:FlxTimer;
    private var shuffleConfetti:FlxTypedGroup<FlxSprite>;

    override public function create():Void {
        super.create();

        #if desktop
        DiscordRPC.changePresence("Freeplay Library", "Selecting Track");
        #end

        scripts = new ScriptManager();
        initFreeplayScripts();

        SongRegistry.scanAll();
        songs = [];
        var scannedSongs = (SongRegistry.songs != null) ? SongRegistry.songs : [];
        for (entry in scannedSongs) {
            if (entry != null && entry.id != null && entry.id.trim().length > 0) {
                songs.push(entry);
            }
        }

        bg = new FlxSprite();
        if (!AssetHelper.loadGraphicSafely(bg, "ui/menubgs/menuDesat")) {
            if (!AssetHelper.loadGraphicSafely(bg, "menuDesat")) {
                bg.makeGraphic(FlxG.width, FlxG.height, 0xFF5B82F9);
            }
        }
        bg.screenCenter();
        bg.antialiasing = true;
        bg.color = 0xFF5B82F9;
        add(bg);

        var grid = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.TRANSPARENT);
        for (i in 0...Std.int(FlxG.width / 50)) {
            grid.pixels.fillRect(new openfl.geom.Rectangle(i * 50, 0, 1, FlxG.height), 0x08FFFFFF);
        }
        for (i in 0...Std.int(FlxG.height / 50)) {
            grid.pixels.fillRect(new openfl.geom.Rectangle(0, i * 50, FlxG.width, 1), 0x08FFFFFF);
        }
        grid.dirty = true;
        grid.scrollFactor.set(0, 0);
        add(grid);

        // Single reusable highlight bar behind the selected row (cheap, no per-item sprites)
        selectionHighlight = new FlxSprite(0, 0).makeGraphic(FlxG.width, 60, FlxColor.WHITE);
        selectionHighlight.alpha = 0.12;
        selectionHighlight.scrollFactor.set(0, 0);
        selectionHighlight.visible = false;
        add(selectionHighlight);

        shuffleConfetti = new FlxTypedGroup<FlxSprite>();
        add(shuffleConfetti);

        shuffleBanner = new FlxText(0, 74, FlxG.width, LanguageManager.getString("freeplay.shuffleMode", "SHUFFLE MODE"), 28);
        shuffleBanner.setFormat(Paths.font("vcr"), 28, EditorTheme.ACCENT_CYAN, CENTER, OUTLINE, FlxColor.BLACK);
        shuffleBanner.borderSize = 1.4;
        shuffleBanner.alpha = 0.0;
        add(shuffleBanner);

        if (songs.length > 0) {
            curSelected = FlxMath.wrap(curSelected, 0, songs.length - 1);

            var poolSize = Std.int(Math.min(songs.length, VISIBLE_ITEMS_COUNT));
            for (i in 0...poolSize) {
                var alphabet = new Alphabet(0, 0, "", true);
                alphabet.isMenuItem = true;
                alphabet.changeX = false;
                alphabet.changeY = false;
                add(alphabet);
                alphabetPool.push(alphabet);

                var icon = new HealthIcon("face", false);
                icon.sprTracker = alphabet;
                add(icon);
                iconPool.push(icon);

                itemSlotIndices.push(-1);
            }

            setupScorePanel();
            changeSelection(0);
        } else {
            var emptyText = new FlxText(0, 0, FlxG.width, LanguageManager.getString("freeplay.noSongs", "NO SONGS FOUND IN ASSETS OR MODS"), 20);
            emptyText.setFormat(Paths.font("vcr"), 20, EditorTheme.ACCENT_MAGENTA, CENTER, OUTLINE, FlxColor.BLACK);
            emptyText.screenCenter();
            add(emptyText);
        }

        #if (mobile || debug)
        mobileControls = new MobilePad(FULL, A_B);
        add(mobileControls);
        Controls.instance.bindMobilePad(mobileControls);
        #end

        if (scripts != null) scripts.callAll("onPostCreate");
    }

    private function initFreeplayScripts():Void {
        var paths = [
            "data/scripts/menus/freeplay",
            "scripts/menus/freeplay",
            "data/scripts/freeplayState"
        ];
        for (p in paths) {
            var file = AssetResolver.resolveFile(p, [".soul", ".hx", ".lua", ".py", ".js"]);
            if (file != null) scripts.loadScript(file);
        }
        scripts.setAll("state", this);
        scripts.setAll("songs", songs);
        scripts.callAll("onCreate");
    }

    private function setupScorePanel():Void {
        scorePanel = new FlxSpriteGroup(FlxG.width - 440, 20);
        add(scorePanel);

        var pBorder = new FlxSprite(-1, -1).makeGraphic(412, 127, EditorTheme.PANEL_BORDER);
        scorePanel.add(pBorder);

        var pBg = new FlxSprite(0, 0).makeGraphic(410, 125, EditorTheme.PANEL_BG);
        pBg.alpha = 0.88;
        scorePanel.add(pBg);

        var accent = new FlxSprite(0, 0).makeGraphic(4, 125, EditorTheme.ACCENT_CYAN);
        scorePanel.add(accent);

        scoreText = new FlxText(16, 10, 380, "PERSONAL BEST: 0", 16);
        scoreText.setFormat(Paths.font("vcr"), 16, EditorTheme.TEXT_PRIMARY, RIGHT);
        scorePanel.add(scoreText);

        diffText = new FlxText(16, 42, 380, "< NORMAL >", 22);
        diffText.setFormat(Paths.font("vcr"), 22, EditorTheme.ACCENT_CYAN, RIGHT);
        scorePanel.add(diffText);

        bpmText = new FlxText(16, 78, 380, "TEMPO: 100 BPM", 14);
        bpmText.setFormat(Paths.font("vcr"), 14, EditorTheme.TEXT_MUTED, RIGHT);
        scorePanel.add(bpmText);

        speedText = new FlxText(16, 98, 380, "", 12);
        speedText.setFormat(Paths.font("vcr"), 12, EditorTheme.TEXT_MUTED, RIGHT);
        scorePanel.add(speedText);
        updateSpeedHint();
    }

    private inline function isShuffleEnabledByConfig():Bool {
        return Runtime.config == null || Runtime.config.freeplayShuffleEnabled;
    }

    private inline function isShuffleConfettiEnabled():Bool {
        return Runtime.config == null || Runtime.config.shuffleConfettiEnabled;
    }

    private inline function getShuffleConfettiIntensity():Float {
        return Runtime.config != null ? FlxMath.bound(Runtime.config.shuffleConfettiIntensity, 0.3, 2.5) : 1.0;
    }

    private inline function getShuffleDurationSeconds():Float {
        var pace = Runtime.config != null ? FlxMath.bound(Runtime.config.shufflePaceMultiplier, 0.6, 1.8) : 1.0;
        return 2.5 / pace;
    }

    private inline function isShuffleIconRandomizationEnabled():Bool {
        return Runtime.config == null || Runtime.config.shuffleIconRandomization;
    }

    private inline function isShuffleTitleScrambleEnabled():Bool {
        return Runtime.config == null || Runtime.config.shuffleTitleScramble;
    }

    private inline function isRandomDifficultyEnabled():Bool {
        return Runtime.config != null && Runtime.config.randomDifficulty;
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        if (scripts != null) scripts.callAll("onUpdate", [elapsed]);

        updateAudioFades(elapsed);

        if (songs.length == 0) {
            if (Controls.instance.BACK) {
                restoreMenuMusic();
                AssetHelper.playSoundSafely("cancelMenu", 0.7);
                MusicBeatState.switchState(new MainMenuState());
            }
            return;
        }

        lerpScore = Math.floor(FlxMath.lerp(intendedScore, lerpScore, Math.exp(-elapsed * 24.0)));
        if (scoreText != null) {
            var scoreLabel = LanguageManager.getString("freeplay.score", "PERSONAL BEST: {0}", [lerpScore]);
            scoreText.text = '$scoreLabel  •  ${Math.round(intendedAccuracy * 10) / 10}% [$intendedRating]';
        }

        if (!shuffleActive) {
            handleNavigationInput(elapsed);
        }

        if (!shuffleActive && isShuffleEnabledByConfig() && InputMap.justPressed("freeplay_shuffle")) {
            startShuffleMode();
        }

        if (shuffleActive) {
            updateShuffleMode(elapsed);
        }

        if (!shuffleActive && FlxG.keys.justPressed.SPACE) {
            scheduleSongPreview(true);
        }

        if (Controls.instance.BACK) {
            cancelShuffleMode();
            cancelPreviewTimer();
            stopPreview();
            restoreMenuMusic();
            AssetHelper.playSoundSafely("cancelMenu", 0.7);
            MusicBeatState.switchState(new MainMenuState());
            return;
        }

        if (!shuffleActive && Controls.instance.ACCEPT && songs.length > 0) {
            startSelectedSong();
        }

        if (shuffleBanner != null) {
            var targetAlpha = shuffleActive ? 1.0 : 0.0;
            shuffleBanner.alpha = FlxMath.lerp(shuffleBanner.alpha, targetAlpha, FlxMath.bound(elapsed * 10.0, 0, 1));
            if (shuffleActive) {
                shuffleBanner.y = 74 + Math.sin(shuffleElapsed * 8.0) * 3.5;
            } else {
                shuffleBanner.y = FlxMath.lerp(shuffleBanner.y, 74, FlxMath.bound(elapsed * 10.0, 0, 1));
            }
        }

        for (i in 0...alphabetPool.length) {
            var item = alphabetPool[i];
            if (item.visible) {
                var targetY = (item.targetY * ITEM_SPACING) + (FlxG.height * 0.48);
                item.y = FlxMath.lerp(item.y, targetY, FlxMath.bound(elapsed * 15.0, 0, 1));
                item.x = FlxMath.lerp(item.x, (item.targetY * 20.0) + 90.0, FlxMath.bound(elapsed * 15.0, 0, 1));

                var isSelected = (item.targetY == 0);
                item.alpha = isSelected ? 1.0 : 0.4;
                if (iconPool[i] != null) {
                    iconPool[i].alpha = item.alpha;
                }

                // Smoothly follow the selected row with the highlight bar
                if (isSelected && selectionHighlight != null) {
                    selectionHighlight.y = FlxMath.lerp(selectionHighlight.y, targetY - 30, FlxMath.bound(elapsed * 15.0, 0, 1));
                }
            }
        }
    }

    private function handleNavigationInput(elapsed:Float):Void {
        var upP = Controls.instance.UI_UP_P;
        var downP = Controls.instance.UI_DOWN_P;

        if (upP) changeSelection(-1);
        if (downP) changeSelection(1);
        if (!shuffleActive && Controls.instance.UI_LEFT_P) changeDiff(-1);
        if (!shuffleActive && Controls.instance.UI_RIGHT_P) changeDiff(1);

        var upHold = Controls.instance.UI_UP;
        var downHold = Controls.instance.UI_DOWN;

        if (upHold || downHold) {
            holdTimer += elapsed;
            if (holdTimer > 0.35) {
                changeSelection(upHold ? -1 : 1);
                holdTimer = 0.28;
            }
        } else {
            holdTimer = 0;
        }
    }

    private function updateAudioFades(elapsed:Float):Void {
        var fadeStep:Float = elapsed * 4.0;

        if (instPreview != null && instPreview.playing) {
            previewVolume = FlxMath.lerp(previewVolume, previewTargetVolume, FlxMath.bound(fadeStep, 0, 1));
            instPreview.volume = previewVolume;
        }

        if (FlxG.sound.music != null && FlxG.sound.music.playing) {
            var curMenuVol:Float = FlxG.sound.music.volume;
            var newMenuVol = FlxMath.lerp(curMenuVol, menuTargetVolume, FlxMath.bound(fadeStep, 0, 1));
            FlxG.sound.music.volume = newMenuVol;
        }
    }

    private inline function safeSongAt(index:Int):Null<RegisteredSong> {
        if (index < 0 || index >= songs.length) return null;
        return songs[index];
    }

    private inline function safeSongColor(song:Null<RegisteredSong>):FlxColor {
        return song != null ? song.color : 0xFF5B82F9;
    }

    private inline function safeSongTitle(song:Null<RegisteredSong>):String {
        if (song == null) return "UNKNOWN SONG";
        if (song.title != null && song.title.trim().length > 0) return song.title;
        if (song.id != null && song.id.trim().length > 0) return song.id;
        return "UNKNOWN SONG";
    }

    private inline function safeSongCharacter(song:Null<RegisteredSong>):String {
        if (song != null && song.character != null && song.character.trim().length > 0) return song.character;
        return "face";
    }

    private function changeSelection(
        change:Int = 0,
        playSfx:Bool = true,
        refreshMeta:Bool = true,
        animateBg:Bool = true,
        notifyScripts:Bool = true
    ):Void {
        if (songs.length == 0) return;
        curSelected = FlxMath.wrap(curSelected + change, 0, songs.length - 1);
        if (playSfx && change != 0) AssetHelper.playSoundSafely("scrollMenu", 0.65);

        var currentSong = safeSongAt(curSelected);

        if (bg != null) {
            var targetColor:FlxColor = safeSongColor(currentSong);
            if (targetColor != bg.color) {
                if (animateBg) {
                    if (colorTween != null) colorTween.cancel();
                    colorTween = FlxTween.color(bg, 0.25, bg.color, targetColor, {ease: FlxEase.quartOut});
                } else {
                    if (colorTween != null) colorTween.cancel();
                    bg.color = targetColor;
                }
            }
        }

        var halfWindow = Math.floor(alphabetPool.length / 2);
        for (slot in 0...alphabetPool.length) {
            var offset = slot - halfWindow;
            var songIndex = curSelected + offset;

            if (songIndex >= 0 && songIndex < songs.length) {
                var alphabet = alphabetPool[slot];
                var icon = iconPool[slot];
                var song = safeSongAt(songIndex);

                alphabet.visible = true;
                icon.visible = true;
                alphabet.targetY = offset;

                if (itemSlotIndices[slot] != songIndex) {
                    // Song names are navigation data and should remain immediately readable.
                    if (offset == 0 && !shuffleActive && isShuffleTitleScrambleEnabled() && change != 0) {
                        alphabet.scrambleTo(safeSongTitle(song), 0.014);
                    } else {
                        alphabet.text = safeSongTitle(song);
                    }
                    icon.changeIcon(safeSongCharacter(song));
                    itemSlotIndices[slot] = songIndex;

                    if (change == 0) {
                        alphabet.y = (offset * ITEM_SPACING) + (FlxG.height * 0.48);
                        alphabet.x = (offset * 20.0) + 90.0;
                    }
                }

                // Track the selected (center) slot for the highlight bar
                if (offset == 0 && selectionHighlight != null) {
                    selectionHighlight.visible = true;
                    selectionHighlight.color = safeSongColor(song);
                    if (change == 0) {
                        selectionHighlight.y = (offset * ITEM_SPACING) + (FlxG.height * 0.48) - 30;
                    }
                }
            } else {
                alphabetPool[slot].visible = false;
                iconPool[slot].visible = false;
                itemSlotIndices[slot] = -1;
            }
        }

        if (refreshMeta) {
            refreshSelectionMeta();
            if (!shuffleActive) {
                scheduleSongPreview(false);
            }
        }

        if (notifyScripts && scripts != null) scripts.callAll("onChangeSelection", [curSelected]);
    }

    private function refreshSelectionMeta():Void {
        if (songs.length == 0) return;

        var selected = safeSongAt(curSelected);
        if (selected == null) return;
        var diffs = (selected.difficulties != null && selected.difficulties.length > 0) ? selected.difficulties : Difficulty.defaultList;

        var matchingIndex:Int = -1;
        for (i in 0...diffs.length) {
            if (diffs[i].toLowerCase().trim() == lastSelectedDifficultyName.toLowerCase().trim()) {
                matchingIndex = i;
                break;
            }
        }

        if (matchingIndex != -1) {
            curDifficulty = matchingIndex;
        } else {
            var normalIdx = diffs.indexOf("normal");
            curDifficulty = (normalIdx != -1) ? normalIdx : (diffs.length > 1 ? 1 : 0);
        }

        changeDiff(0);
    }

    private function changeDiff(change:Int = 0):Void {
        if (songs.length == 0) return;
        var selected = safeSongAt(curSelected);
        if (selected == null) return;
        var diffs = (selected.difficulties != null && selected.difficulties.length > 0) ? selected.difficulties : Difficulty.defaultList;
        curDifficulty = FlxMath.wrap(curDifficulty + change, 0, diffs.length - 1);
        lastSelectedDifficultyName = diffs[curDifficulty].toLowerCase().trim();

        var diffName = diffs[curDifficulty].toUpperCase();
        var diffDisplayName = Difficulty.getLocalizedName(diffs[curDifficulty]).toUpperCase();
        if (diffText != null) {
            diffText.text = '< $diffDisplayName >';
            diffText.color = Difficulty.getColor(diffs[curDifficulty]);
        }

        var meta = getCachedChartMeta(selected.id, diffs[curDifficulty], selected.bpm, selected.speed);
        curBpm = meta.bpm;
        curSpeed = meta.speed;

        if (bpmText != null) bpmText.text = LanguageManager.getString("freeplay.tempo", "TEMPO: {0} BPM", [Math.round(curBpm)]);
        updateSpeedHint();

        Conductor.changeBPM(curBpm);

        var saveEntry = SaveData.instance != null ? SaveData.instance.getScore(selected.id, diffs[curDifficulty]) : null;
        if (saveEntry != null) {
            intendedScore = saveEntry.score;
            intendedAccuracy = saveEntry.accuracy;
            intendedRating = saveEntry.rating;
        } else {
            intendedScore = 0;
            intendedAccuracy = 0.0;
            intendedRating = "N/A";
        }
        if (scripts != null) scripts.callAll("onChangeDifficulty", [curDifficulty, diffs[curDifficulty]]);
    }

    private function updateSpeedHint():Void {
        if (speedText == null) return;
        var shuffleKey = InputMap.getKeyLabel("freeplay_shuffle");
        var shuffleState = isShuffleEnabledByConfig() ? "ON" : "OFF";
        speedText.text = LanguageManager.getString("freeplay.scrollSpeed", 'SCROLL SPEED: {0}x  |  SHUFFLE[{1}:{2}]  |  [SPACE] PREVIEW', [curSpeed, shuffleState, shuffleKey]);
    }

    private function getShuffleEligibleIndices():Array<Int> {
        var eligible:Array<Int> = [];
        for (i in 0...songs.length) {
            var s = songs[i];
            var canShuffle = (s != null && s.shuffleEnabled != null) ? s.shuffleEnabled : true;
            if (canShuffle) eligible.push(i);
        }
        if (eligible.length == 0) {
            for (i in 0...songs.length) eligible.push(i);
        }
        return eligible;
    }

    private function startShuffleMode():Void {
        if (songs.length == 0 || shuffleActive) return;

        shuffleEligibleIndices = getShuffleEligibleIndices();
        if (shuffleEligibleIndices.length == 0) return;

        cancelPreviewTimer();
        stopPreview();

        if (shuffleLaunchTimer != null) {
            shuffleLaunchTimer.cancel();
            shuffleLaunchTimer.destroy();
            shuffleLaunchTimer = null;
        }

        shuffleActive = true;
        shuffleElapsed = 0.0;
        shuffleSwapElapsed = 0.0;
        shuffleDuration = getShuffleDurationSeconds();
        menuTargetVolume = 0.35;
        holdTimer = 0.0;

        if (selectionHighlight != null) {
            selectionHighlight.alpha = 0.2;
        }

        AssetHelper.playSoundSafely("scrollMenu", 0.75);
        performShuffleStep();
    }

    private function updateShuffleMode(elapsed:Float):Void {
        if (!shuffleActive) return;

        shuffleElapsed += elapsed;
        shuffleSwapElapsed += elapsed;

        var t = FlxMath.bound(shuffleElapsed / shuffleDuration, 0, 1);
        var interval = FlxMath.lerp(0.045, 0.16, t * t);

        var hopsThisFrame = 0;
        while (shuffleSwapElapsed >= interval && hopsThisFrame < 2) {
            shuffleSwapElapsed -= interval;
            performShuffleStep();
            hopsThisFrame++;
        }

        if (shuffleElapsed >= shuffleDuration) {
            finalizeShuffleMode();
        }
    }

    private function performShuffleStep():Void {
        if (shuffleEligibleIndices.length == 0 || songs.length == 0) return;

        var nextIndex = curSelected;
        if (shuffleEligibleIndices.length == 1) {
            nextIndex = shuffleEligibleIndices[0];
        } else {
            for (_ in 0...8) {
                var candidate = shuffleEligibleIndices[FlxG.random.int(0, shuffleEligibleIndices.length - 1)];
                if (candidate != curSelected) {
                    nextIndex = candidate;
                    break;
                }
            }
        }

        changeSelection(nextIndex - curSelected, false, false, false, false);

        for (i in 0...alphabetPool.length) {
            var item = alphabetPool[i];
            if (item != null && item.visible && item.targetY == 0) {
                var selectedSong = safeSongAt(curSelected);
                item.text = safeSongTitle(selectedSong);
                var icon = iconPool[i];
                if (icon != null) icon.changeIcon(pickShuffleIcon(selectedSong));
                break;
            }
        }
    }

    private function pickShuffleIcon(song:RegisteredSong):String {
        if (song == null) return "face";
        if (!isShuffleIconRandomizationEnabled()) {
            if (song != null && song.character != null && song.character.length > 0) return song.character;
            return "face";
        }

        if (song != null && song.shuffleIconPool != null && song.shuffleIconPool.length > 0) {
            return song.shuffleIconPool[FlxG.random.int(0, song.shuffleIconPool.length - 1)];
        }

        if (songs.length > 0 && FlxG.random.bool(35)) {
            var randSong = songs[FlxG.random.int(0, songs.length - 1)];
            if (randSong != null && randSong.character != null && randSong.character.length > 0) {
                return randSong.character;
            }
        }

        if (song != null && song.character != null && song.character.length > 0) {
            return song.character;
        }
        return "face";
    }

    private function finalizeShuffleMode():Void {
        if (!shuffleActive) return;
        shuffleActive = false;

        refreshSelectionMeta();

        triggerShuffleReveal();
        menuTargetVolume = 0.0;

        if (shuffleLaunchTimer != null) {
            shuffleLaunchTimer.cancel();
            shuffleLaunchTimer.destroy();
        }

        shuffleLaunchTimer = new FlxTimer().start(0.7, function(_) {
            shuffleLaunchTimer = null;
            startSelectedSong();
        });
    }

    private function cancelShuffleMode():Void {
        shuffleActive = false;
        shuffleElapsed = 0.0;
        shuffleSwapElapsed = 0.0;

        if (shuffleLaunchTimer != null) {
            shuffleLaunchTimer.cancel();
            shuffleLaunchTimer.destroy();
            shuffleLaunchTimer = null;
        }

        menuTargetVolume = 0.7;
        if (selectionHighlight != null) selectionHighlight.alpha = 0.12;
    }

    private function triggerShuffleReveal():Void {
        if (!isShuffleConfettiEnabled()) {
            if (selectionHighlight != null) {
                selectionHighlight.alpha = 0.26;
                FlxTween.tween(selectionHighlight, {alpha: 0.12}, 0.45, {ease: FlxEase.quartOut});
            }
            return;
        }

        if (selectionHighlight != null) {
            selectionHighlight.alpha = 0.35;
            FlxTween.tween(selectionHighlight, {alpha: 0.12}, 0.6, {ease: FlxEase.quartOut});
        }

        FlxG.camera.flash(FlxColor.WHITE, 0.18);

        if (shuffleConfetti == null) return;

        while (shuffleConfetti.members.length > 0) {
            var oldPiece = shuffleConfetti.members.pop();
            if (oldPiece != null) {
                shuffleConfetti.remove(oldPiece, true);
                oldPiece.destroy();
            }
        }

        var confettiIntensity = getShuffleConfettiIntensity();
        var colors = [0xFFFF4D6D, 0xFFFFC857, 0xFF4DFFB8, 0xFF5DA9FF, 0xFFFF7AF6];
        var centerX = FlxG.width * 0.5;
        var centerY = FlxG.height * 0.48;
        var pieces = Std.int(Math.round(16 + (20 * confettiIntensity)));
        pieces = Std.int(FlxMath.bound(pieces, 8, 52));
        var spread = 1.0 + (confettiIntensity - 1.0) * 0.65;

        for (i in 0...pieces) {
            var w = FlxG.random.int(4, 9);
            var h = FlxG.random.int(6, 16);
            var piece = new FlxSprite(centerX + FlxG.random.float(-28, 28), centerY + FlxG.random.float(-16, 16));
            piece.makeGraphic(w, h, colors[FlxG.random.int(0, colors.length - 1)]);
            piece.scrollFactor.set(0, 0);
            piece.angle = FlxG.random.float(0, 360);
            shuffleConfetti.add(piece);

            var targetX = piece.x + FlxG.random.float(-260 * spread, 260 * spread);
            var targetY = piece.y + FlxG.random.float(-180 * spread, 210 * spread);
            var targetAngle = piece.angle + FlxG.random.float(180, 720);
            var life = FlxG.random.float(0.55, 0.95 + (confettiIntensity - 1.0) * 0.2);
            var confettiPiece = piece;

            FlxTween.tween(confettiPiece, {x: targetX, y: targetY, alpha: 0, angle: targetAngle}, life, {
                ease: FlxEase.quadOut,
                onComplete: function(_) {
                    if (confettiPiece != null && shuffleConfetti != null) {
                        shuffleConfetti.remove(confettiPiece, true);
                        confettiPiece.destroy();
                    }
                }
            });
        }
    }

    private function startSelectedSong():Void {
        if (songs.length == 0) return;

        cancelPreviewTimer();
        stopPreview();

        var selected = safeSongAt(curSelected);
        if (selected == null) return;
        var diffs = (selected.difficulties != null && selected.difficulties.length > 0) ? selected.difficulties : Difficulty.defaultList;
        if (isRandomDifficultyEnabled() && diffs.length > 1) {
            curDifficulty = FlxG.random.int(0, diffs.length - 1);
        } else {
            curDifficulty = FlxMath.wrap(curDifficulty, 0, diffs.length - 1);
        }

        PlayState.curSong = selected.id;
        PlayState.curDifficulty = diffs[curDifficulty];
        PlayState.isStoryMode = false;
        if (scripts != null) scripts.callAll("onSelectSong", [selected]);
        MusicBeatState.switchState(new PlayState());
    }

    private function getCachedChartMeta(songId:String, diff:String, fallbackBpm:Float, fallbackSpeed:Float):{bpm:Float, speed:Float} {
        var key = songId.toLowerCase().trim() + "_" + diff.toLowerCase().trim();
        if (_chartMetaCache.exists(key)) {
            return _chartMetaCache.get(key);
        }

        var cleanSong = songId.toLowerCase().trim();
        var cleanDiff = diff.toLowerCase().trim();
        var diffSuffix = (cleanDiff == "normal") ? "" : '-$cleanDiff';

        var possibleChartPaths = [
            'songs/$cleanSong/charts/$cleanDiff.json',
            'songs/$cleanSong/charts/$cleanDiff.xmsoul',
            'songs/$cleanSong/chart$diffSuffix.json',
            'songs/$cleanSong/$cleanSong$diffSuffix.json',
            'data/$cleanSong/$cleanSong$diffSuffix.json',
            'assets/preload/songs/$cleanSong/charts/$cleanDiff.json'
        ];

        var bpmVal:Float = fallbackBpm > 0 ? fallbackBpm : 100.0;
        var speedVal:Float = fallbackSpeed > 0 ? fallbackSpeed : 2.0;

        for (path in possibleChartPaths) {
            var resolved = AssetResolver.resolveFile(path, [".json", ".xmsoul", ""]);
            if (resolved != null) {
                var content = AssetResolver.getText(resolved);
                if (content != null && content.length > 0) {
                    try {
                        if (resolved.endsWith(".xmsoul") || content.trim().startsWith("<")) {
                            var xml = Xml.parse(content);
                            var root = xml.firstElement();
                            if (root.exists("speed")) speedVal = Std.parseFloat(root.get("speed"));
                            if (root.exists("bpm")) bpmVal = Std.parseFloat(root.get("bpm"));
                        } else {
                            var parsed:Dynamic = Json.parse(content);
                            var sObj:Dynamic = Reflect.hasField(parsed, "song") ? Reflect.field(parsed, "song") : parsed;
                            if (Reflect.hasField(sObj, "bpm")) bpmVal = Std.parseFloat(Reflect.field(sObj, "bpm"));
                            if (Reflect.hasField(sObj, "speed")) speedVal = Std.parseFloat(Reflect.field(sObj, "speed"));
                            else if (Reflect.hasField(sObj, "scrollSpeed")) speedVal = Std.parseFloat(Reflect.field(sObj, "scrollSpeed"));
                        }
                        break;
                    } catch (e:Dynamic) {}
                }
            }
        }

        var result = {bpm: bpmVal, speed: speedVal};
        _chartMetaCache.set(key, result);
        return result;
    }

    private function scheduleSongPreview(immediate:Bool = false):Void {
        cancelPreviewTimer();

        var delay = immediate ? 0.01 : 0.42;
        previewTimer = new FlxTimer().start(delay, function(_) {
            if (songs.length == 0 || curSelected >= songs.length) return;
            var selected = songs[curSelected];
            if (curPlayingSong == selected.id && instPreview != null && instPreview.playing) return;

            var instSound = Paths.inst(selected.id);
            if (instSound != null) {
                menuTargetVolume = 0.0;

                stopPreview();
                curPlayingSong = selected.id;

                instPreview = new FlxSound().loadEmbedded(instSound, true);
                instPreview.volume = 0.0;
                previewVolume = 0.0;
                previewTargetVolume = 0.75;
                instPreview.play(false, FlxG.random.int(0, Std.int(Math.max(0, (instPreview.length * 0.15)))));
                FlxG.sound.list.add(instPreview);
            }
        });
    }

    private function cancelPreviewTimer():Void {
        if (previewTimer != null) {
            previewTimer.cancel();
            previewTimer.destroy();
            previewTimer = null;
        }
    }

    private function stopPreview():Void {
        if (instPreview != null) {
            instPreview.stop();
            if (FlxG.sound.list != null) FlxG.sound.list.remove(instPreview, true);
            instPreview.destroy();
            instPreview = null;
        }
        curPlayingSong = "";
        previewVolume = 0.0;
    }

    private function restoreMenuMusic():Void {
        menuTargetVolume = 0.7;
        if (FlxG.sound.music != null) {
            if (!FlxG.sound.music.playing) {
                FlxG.sound.music.volume = 0.0;
                FlxG.sound.music.play();
            }
        } else {
            FlxG.sound.playMusic(Paths.music("freakyMenu"), 0.7);
        }
    }

    override public function beatHit(beat:Int):Void {
        super.beatHit(beat);
        if (scripts != null) scripts.callAll("onBeatHit", [beat]);

        // Bop every visible icon cheaply. HealthIcon.beatHit() sets the bop scale/angle
        // and its own update() lerps back each frame, so no per-beat FlxTween allocation.
        for (i in 0...iconPool.length) {
            var icon = iconPool[i];
            if (icon != null && icon.visible) {
                icon.beatHit(beat);
            }
        }
    }

    override public function destroy():Void {
        cancelShuffleMode();
        cancelPreviewTimer();
        stopPreview();
        if (colorTween != null) colorTween.cancel();
        if (scripts != null) {
            scripts.callAll("onDestroy");
            scripts.clear();
        }
        Controls.instance.unbindMobilePad();
        super.destroy();
    }
}