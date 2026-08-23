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
import soulscorch.backend.input.MobilePad;
import soulscorch.backend.system.SaveData;
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

    override public function create():Void {
        super.create();

        #if desktop
        DiscordRPC.changePresence("Freeplay Library", "Selecting Track");
        #end

        scripts = new ScriptManager();
        initFreeplayScripts();

        SongRegistry.scanAll();
        songs = (SongRegistry.songs != null) ? SongRegistry.songs : [];

        bg = new FlxSprite();
        if (!AssetHelper.loadGraphicSafely(bg, "ui/menubgs/menuDesat")) {
            if (!AssetHelper.loadGraphicSafely(bg, "menuDesat")) {
                bg.makeGraphic(FlxG.width, FlxG.height, 0xFF282035);
            }
        }
        bg.screenCenter();
        bg.antialiasing = true;
        bg.color = 0xFF282035;
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

        if (songs.length > 0) {
            curSelected = FlxMath.wrap(curSelected, 0, songs.length - 1);

            var poolSize = Std.int(Math.min(songs.length, VISIBLE_ITEMS_COUNT));
            for (i in 0...poolSize) {
                var alphabet = new Alphabet(0, 0, "", true);
                alphabet.isMenuItem = true;
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
            var emptyText = new FlxText(0, 0, FlxG.width, "NO SONGS FOUND IN ASSETS OR MODS", 20);
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

        speedText = new FlxText(16, 98, 380, "SCROLL SPEED: 2.0x  |  [SPACE] PREVIEW", 12);
        speedText.setFormat(Paths.font("vcr"), 12, EditorTheme.TEXT_MUTED, RIGHT);
        scorePanel.add(speedText);
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
            scoreText.text = 'PERSONAL BEST: $lerpScore  •  ${Math.round(intendedAccuracy * 10) / 10}% [$intendedRating]';
        }

        handleNavigationInput(elapsed);

        if (FlxG.keys.justPressed.SPACE) {
            scheduleSongPreview(true);
        }

        if (Controls.instance.BACK) {
            cancelPreviewTimer();
            stopPreview();
            restoreMenuMusic();
            AssetHelper.playSoundSafely("cancelMenu", 0.7);
            MusicBeatState.switchState(new MainMenuState());
        }

        if (Controls.instance.ACCEPT && songs.length > 0) {
            cancelPreviewTimer();
            stopPreview();
            var selected = songs[curSelected];
            var diffs = (selected.difficulties != null && selected.difficulties.length > 0) ? selected.difficulties : Difficulty.defaultList;
            curDifficulty = FlxMath.wrap(curDifficulty, 0, diffs.length - 1);

            PlayState.curSong = selected.id;
            PlayState.curDifficulty = diffs[curDifficulty];
            PlayState.isStoryMode = false;
            if (scripts != null) scripts.callAll("onSelectSong", [selected]);
            MusicBeatState.switchState(new PlayState());
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
        if (Controls.instance.UI_LEFT_P) changeDiff(-1);
        if (Controls.instance.UI_RIGHT_P) changeDiff(1);

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

    private function changeSelection(change:Int = 0):Void {
        if (songs.length == 0) return;
        curSelected = FlxMath.wrap(curSelected + change, 0, songs.length - 1);
        if (change != 0) AssetHelper.playSoundSafely("scrollMenu", 0.65);

        if (bg != null) {
            var targetColor:FlxColor = songs[curSelected].color;
            if (colorTween != null) colorTween.cancel();
            bg.color = bg.color;
            colorTween = FlxTween.color(bg, 0.25, bg.color, targetColor, {ease: FlxEase.quartOut});
        }

        var halfWindow = Math.floor(alphabetPool.length / 2);
        for (slot in 0...alphabetPool.length) {
            var offset = slot - halfWindow;
            var songIndex = curSelected + offset;

            if (songIndex >= 0 && songIndex < songs.length) {
                var alphabet = alphabetPool[slot];
                var icon = iconPool[slot];

                alphabet.visible = true;
                icon.visible = true;
                alphabet.targetY = offset;

                if (itemSlotIndices[slot] != songIndex) {
                    // Song names are navigation data and should remain immediately readable.
                    alphabet.text = songs[songIndex].title;
                    icon.changeIcon(songs[songIndex].character != null ? songs[songIndex].character : "face");
                    itemSlotIndices[slot] = songIndex;

                    if (change == 0) {
                        alphabet.y = (offset * ITEM_SPACING) + (FlxG.height * 0.48);
                        alphabet.x = (offset * 20.0) + 90.0;
                    }
                }

                // Track the selected (center) slot for the highlight bar
                if (offset == 0 && selectionHighlight != null) {
                    selectionHighlight.visible = true;
                    selectionHighlight.color = songs[songIndex].color;
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

        var selected = songs[curSelected];
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
        scheduleSongPreview(false);
        if (scripts != null) scripts.callAll("onChangeSelection", [curSelected]);
    }

    private function changeDiff(change:Int = 0):Void {
        if (songs.length == 0) return;
        var selected = songs[curSelected];
        var diffs = (selected.difficulties != null && selected.difficulties.length > 0) ? selected.difficulties : Difficulty.defaultList;
        curDifficulty = FlxMath.wrap(curDifficulty + change, 0, diffs.length - 1);
        lastSelectedDifficultyName = diffs[curDifficulty].toLowerCase().trim();

        var diffName = diffs[curDifficulty].toUpperCase();
        if (diffText != null) {
            diffText.text = '< $diffName >';
            diffText.color = Difficulty.getColor(diffs[curDifficulty]);
        }

        var meta = getCachedChartMeta(selected.id, diffs[curDifficulty], selected.bpm, selected.speed);
        curBpm = meta.bpm;
        curSpeed = meta.speed;

        if (bpmText != null) bpmText.text = 'TEMPO: ${Math.round(curBpm)} BPM';
        if (speedText != null) speedText.text = 'SCROLL SPEED: ${curSpeed}x  |  [SPACE] PREVIEW';

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