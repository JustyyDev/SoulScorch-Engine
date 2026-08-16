package soulscorch.gameplay;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.ui.FlxBar;
import flixel.util.FlxColor;
import flixel.util.FlxSort;

import soulscorch.assets.AssetHelper;
import soulscorch.core.Runtime;
import soulscorch.core.Scene;
import soulscorch.core.SaveData;
import soulscorch.core.Achievements;
import soulscorch.gameplay.modchart.ModchartManager;
import soulscorch.input.InputMap;
import soulscorch.modding.ModLoader;
import soulscorch.modding.ScriptManager;
import soulscorch.ui.ScriptedSubState;
import soulscorch.ui.menus.ResultsState;

class PlayState extends Scene {
    public static var instance:PlayState;
    public static var curSong:String = "bopeebo";
    public static var curDifficulty:String = "normal";

    public static var gameplayFlags:Map<String, Dynamic> = new Map();

    public var songData:Song;
    public var audio:AudioManager;
    public var scripts:ScriptManager;
    public var modcharts:ModchartManager;

    public var camGame:FlxCamera;
    public var camHUD:FlxCamera;

    public var playerStrums:FlxTypedGroup<StrumArrow>;
    public var opponentStrums:FlxTypedGroup<StrumArrow>;
    public var grpNoteSplashes:FlxTypedGroup<NoteSplash>;
    public var notes:FlxTypedGroup<NoteSprite>;
    public var unspawnNotes:Array<Note> = [];

    public var health:Float = 1.0;
    public var maxHealth:Float = 2.0;
    public var songScore:Int = 0;
    public var songMisses:Int = 0;
    public var songHits:Int = 0;
    public var totalNotesHit:Float = 0;
    public var accuracy:Float = 0.00;

    public var healthBarBG:FlxSprite;
    public var healthBar:FlxBar;
    public var scoreTxt:FlxText;

    public var songSpeed:Float = 2.2;
    public var paused:Bool = false;
    public var isEnding:Bool = false;
    public var startedCountdown:Bool = false;
    public var ghostTapping:Bool = true;
    public var downscroll:Bool = false;
    public var cameraZoomOnBeat:Bool = true;
    public var comboFlashOnHit:Bool = true;
    public var allowPause:Bool = true;
    public var hudAlpha:Float = 1.0;
    public var noteSplashEnabled:Bool = true;
    public var judgeWindow:Float = 166.0;
    public var songTimer:Float = 0.0;
    public var beatPulse:Int = 0;
    public var lastCameraZoom:Float = 1.0;

    public function new(?songId:String = null, ?difficulty:String = null) {
        super();
        if (songId != null && songId != "") {
            curSong = songId;
        }
        if (difficulty != null && difficulty != "") {
            curDifficulty = difficulty;
        }
    }

    override public function create():Void {
        super.create();
        instance = this;

        // Freeplay/menu song previews use FlxG.sound.music directly; make sure they don't keep playing under gameplay audio.
        if (FlxG.sound.music != null) {
            FlxG.sound.music.stop();
            FlxG.sound.music = null;
        }

        GameplayFlags.initDefaults();
        GameplayFlags.resolveModFlags();
        applyGameplayFlags();

        setupCameras();
        initializeSystems();
        generateStrumLines();
        loadSong(curSong, curDifficulty);

        add(opponentStrums);
        add(playerStrums);
        add(grpNoteSplashes);
        add(notes);

        setupHUD();
        setupScriptRuntime();
        startCountdown();
    }

    function applyGameplayFlags():Void {
        if (Runtime.engine != null && Runtime.engine.config != null) {
            GameplayFlags.set("ghostTapping", Runtime.engine.config.ghostTapping);
            GameplayFlags.set("downscroll", Runtime.engine.config.downscroll);
            GameplayFlags.set("antialiasing", Runtime.engine.config.antialiasing);
            GameplayFlags.set("flashingLights", Runtime.engine.config.flashingLights);
            GameplayFlags.set("safeZoneOffset", Runtime.engine.config.safeWindow * 16.6);
        }

        ghostTapping = GameplayFlags.getBool("ghostTapping", true);
        downscroll = GameplayFlags.getBool("downscroll", false);
        allowPause = GameplayFlags.getBool("allowPause", true);
        cameraZoomOnBeat = GameplayFlags.getBool("cameraZoomOnBeat", true);
        comboFlashOnHit = GameplayFlags.getBool("comboFlashOnHit", true);
        noteSplashEnabled = GameplayFlags.getBool("noteSplash", true);
        hudAlpha = GameplayFlags.getFloat("hudAlpha", 1.0);
        judgeWindow = GameplayFlags.getFloat("judgeWindow", Conductor.safeZoneOffset);
        maxHealth = GameplayFlags.getFloat("maxHealth", 2.0);
        health = Math.min(maxHealth, Math.max(0.0, health));

        if (!Math.isNaN(GameplayFlags.getFloat("safeZoneOffset", -1))) {
            Conductor.safeZoneOffset = GameplayFlags.getFloat("safeZoneOffset", Conductor.safeZoneOffset);
        }

        if (GameplayFlags.getBool("modchartEnabled", true)) {
            modcharts = new ModchartManager(cast playerStrums, cast opponentStrums);
        }
    }

    function setupCameras():Void {
        camGame = new FlxCamera();
        camHUD = new FlxCamera();
        camHUD.bgColor.alpha = 0;

        FlxG.cameras.reset(camGame);
        FlxG.cameras.add(camHUD, false);
        FlxG.cameras.setDefaultDrawTarget(camGame, true);
    }

    function initializeSystems():Void {
        audio = new AudioManager();
        audio.onSongComplete = onSongFinished;
        scripts = new ScriptManager();

        playerStrums = new FlxTypedGroup<StrumArrow>();
        opponentStrums = new FlxTypedGroup<StrumArrow>();
        grpNoteSplashes = new FlxTypedGroup<NoteSplash>();
        notes = new FlxTypedGroup<NoteSprite>();

        playerStrums.cameras = [camHUD];
        opponentStrums.cameras = [camHUD];
        grpNoteSplashes.cameras = [camHUD];
        notes.cameras = [camHUD];

        modcharts = new ModchartManager(cast playerStrums, cast opponentStrums);
    }

    function setupScriptRuntime():Void {
        scripts.loadScriptsFromDir("assets/data/scripts");
        scripts.loadScript('assets/data/songs/$curSong/script.hx');

        scripts.set("game", this);
        scripts.set("audio", audio);
        scripts.set("modcharts", modcharts);
        scripts.set("Conductor", Conductor);
        scripts.set("playerStrums", playerStrums);
        scripts.set("opponentStrums", opponentStrums);
        scripts.set("flags", GameplayFlags.active);
        scripts.set("GameplayFlags", GameplayFlags);

        scripts.call("create");
        scripts.call("onCreate");
    }

    function generateStrumLines():Void {
        var strumY:Float = downscroll ? FlxG.height - 180 : 90;

        for (i in 0...4) {
            var opp:StrumArrow = new StrumArrow(100 + (i * 140), strumY, i, 0);
            opp.alpha = 0.9;
            opponentStrums.add(opp);

            var ply:StrumArrow = new StrumArrow(720 + (i * 140), strumY, i, 1);
            ply.alpha = 0.9;
            playerStrums.add(ply);
        }
    }

    function setupHUD():Void {
        healthBarBG = new FlxSprite(0, FlxG.height * 0.9);
        if (!AssetHelper.loadGraphicSafely(healthBarBG, "assets/images/gameplay/healthBar.png")) {
            healthBarBG.makeGraphic(604, 24, 0xFF000000);
        }
        healthBarBG.screenCenter(X);
        healthBarBG.scrollFactor.set();
        healthBarBG.cameras = [camHUD];
        healthBarBG.alpha = hudAlpha;
        add(healthBarBG);

        healthBar = new FlxBar(
            healthBarBG.x + 4,
            healthBarBG.y + 4,
            RIGHT_TO_LEFT,
            Std.int(healthBarBG.width - 8),
            Std.int(healthBarBG.height - 8),
            this,
            'health',
            0,
            maxHealth
        );
        healthBar.createFilledBar(0xFFFF0000, 0xFF66FF33);
        healthBar.scrollFactor.set();
        healthBar.cameras = [camHUD];
        healthBar.alpha = hudAlpha;
        add(healthBar);

        scoreTxt = new FlxText(
            0,
            healthBarBG.y + 36,
            FlxG.width,
            "Score: 0 | Misses: 0 | Accuracy: 0%",
            20
        );
        scoreTxt.setFormat("_sans", 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        scoreTxt.scrollFactor.set();
        scoreTxt.cameras = [camHUD];
        scoreTxt.alpha = hudAlpha;
        add(scoreTxt);
    }

    function loadSong(songId:String, difficulty:String):Void {
        songData = SongLoader.load(songId, difficulty);
        songSpeed = songData.scrollSpeed * GameplayFlags.getFloat("songSpeedMultiplier", 1.0);
        Conductor.changeBPM(songData.bpm);
        Conductor.mapBpmChanges(songData.chart);
        Conductor.safeZoneOffset = GameplayFlags.getFloat("safeZoneOffset", Conductor.safeZoneOffset);

        prepareChartNotes();
        audio.loadSong(songId);
    }

    function prepareChartNotes():Void {
        unspawnNotes = [];

        for (n in songData.chart.notes) {
            unspawnNotes.push(n);

            if (n.sustainLength > 0) {
                var totalSustains:Int = Math.floor(n.sustainLength / Conductor.stepCrochet);
                for (sus in 0...totalSustains) {
                    var susTime:Float = n.strumTime + (Conductor.stepCrochet * (sus + 1));
                    var isEnd:Bool = (sus == totalSustains - 1);
                    var sustainData:Note = new Note(susTime, n.direction, 0, n.mustPress, true, n.noteType);
                    var susSprite:NoteSprite = new NoteSprite(sustainData, true, isEnd);
                    susSprite.cameras = [camHUD];
                    notes.add(susSprite);
                }
            }
        }

        unspawnNotes.sort(function(a:Note, b:Note):Int {
            return FlxSort.byValues(FlxSort.ASCENDING, a.strumTime, b.strumTime);
        });
    }

    function startCountdown():Void {
        startedCountdown = true;
        Conductor.songPosition = -Conductor.crochet * 5;
        audio.play();

        #if desktop
        var totalSongSeconds:Float = (audio.inst != null ? audio.inst.length : 180000) / 1000.0;
        soulscorch.backend.DiscordRPC.updateSongPresence(curSong, curDifficulty, totalSongSeconds, accuracy, songScore);
        #end
    }

    override public function update(elapsed:Float):Void {
        if (paused) {
            return;
        }

        scripts.call("update", [elapsed]);
        scripts.call("onUpdate", [elapsed]);

        songTimer += elapsed;
        audio.update(elapsed);

        if (modcharts != null) {
            modcharts.update(elapsed);
        }

        super.update(elapsed);
        updateNoteSpawns();
        updateNotePositions();
        handleInput();

        if (InputMap.justPressed("pause") && allowPause) {
            openPauseMenu();
        }

        updateCameraMotion();
        scripts.call("updatePost", [elapsed]);
        scripts.call("onUpdatePost", [elapsed]);
    }

    function updateNoteSpawns():Void {
        while (unspawnNotes.length > 0 && unspawnNotes[0].strumTime - Conductor.songPosition < 1800 / songSpeed) {
            var noteData:Note = unspawnNotes.shift();
            var noteSprite:NoteSprite = new NoteSprite(noteData, false, false);
            noteSprite.cameras = [camHUD];
            notes.add(noteSprite);
        }
    }

    function updateNotePositions():Void {
        notes.forEachAlive(function(daNote:NoteSprite) {
            var targetStrum:StrumArrow = daNote.noteData.mustPress ? playerStrums.members[daNote.noteData.direction] : opponentStrums.members[daNote.noteData.direction];
            if (targetStrum != null) {
                daNote.x = targetStrum.x + daNote.offsetX;
                daNote.y = targetStrum.y + (0.45 * (Conductor.songPosition - daNote.noteData.strumTime) * songSpeed) + daNote.offsetY;

                if (!daNote.noteData.mustPress && daNote.noteData.strumTime <= Conductor.songPosition) {
                    targetStrum.playAnim('confirm', true);
                    targetStrum.resetAnim = 0.15;
                    audio.muteVocal(false, false);
                    daNote.kill();
                    notes.remove(daNote, true);
                    daNote.destroy();
                    return;
                }
            }

            if (daNote.noteData.strumTime > Conductor.songPosition - Conductor.safeZoneOffset && daNote.noteData.strumTime < Conductor.songPosition + Conductor.safeZoneOffset) {
                daNote.noteData.canBeHit = true;
            } else {
                daNote.noteData.canBeHit = false;
            }

            if (daNote.noteData.strumTime < Conductor.songPosition - Conductor.safeZoneOffset && !daNote.noteData.wasGoodHit) {
                daNote.noteData.tooLate = true;
                daNote.active = false;
                daNote.visible = false;
                noteMiss(daNote.noteData.direction);
                notes.remove(daNote, true);
                daNote.destroy();
            }
        });
    }

    function handleInput():Void {
        var keyNames:Array<String> = ["left", "down", "up", "right"];
        for (i in 0...keyNames.length) {
            if (InputMap.justPressed(keyNames[i])) {
                pressStrum(i);
            }
            if (InputMap.justReleased(keyNames[i])) {
                releaseStrum(i);
            }
        }
    }

    function pressStrum(dir:Int):Void {
        var pStrum:StrumArrow = playerStrums.members[dir];
        if (pStrum != null) {
            pStrum.playAnim('pressed');
        }

        var possibleNotes:Array<NoteSprite> = [];
        notes.forEachAlive(function(daNote:NoteSprite) {
            if (daNote.noteData.mustPress && daNote.noteData.direction == dir && daNote.noteData.canBeHit && !daNote.noteData.wasGoodHit) {
                possibleNotes.push(daNote);
            }
        });

        if (possibleNotes.length > 0) {
            possibleNotes.sort(function(a:NoteSprite, b:NoteSprite):Int {
                return FlxSort.byValues(
                    FlxSort.ASCENDING,
                    Math.abs(a.noteData.strumTime - Conductor.songPosition),
                    Math.abs(b.noteData.strumTime - Conductor.songPosition)
                );
            });
            goodNoteHit(possibleNotes[0]);
        }
    }

    function releaseStrum(dir:Int):Void {
        var pStrum:StrumArrow = playerStrums.members[dir];
        if (pStrum != null) {
            pStrum.playAnim('static');
        }
    }

    function goodNoteHit(noteSprite:NoteSprite):Void {
        var note:Note = noteSprite.noteData;
        note.wasGoodHit = true;

        var diff:Float = Math.abs(note.strumTime - Conductor.songPosition);
        var judgment:Judgment = Judgment.fromDifference(diff, Conductor.safeZoneOffset);

        songHits += 1;
        songScore += Judgment.score(judgment);
        totalNotesHit += Judgment.accuracyWeight(judgment);
        health = Math.min(maxHealth, health + Judgment.healthModifier(judgment));
        audio.muteVocal(true, false);

        var pStrum:StrumArrow = playerStrums.members[note.direction];
        if (pStrum != null) {
            pStrum.playAnim('confirm', true);
            pStrum.resetAnim = 0.15;
        }

        if (Judgment.triggersSplash(judgment) && noteSplashEnabled) {
            if (pStrum != null) {
                spawnSplash(pStrum.x, pStrum.y, note.direction);
            }
        }

        updateScoreText();
        scripts.call("goodNoteHit", [noteSprite]);

        notes.remove(noteSprite, true);
        noteSprite.destroy();
    }

    function spawnSplash(x:Float, y:Float, dir:Int):Void {
        var splash:NoteSplash = grpNoteSplashes.recycle(NoteSplash);
        splash.setup(x, y, dir);
        grpNoteSplashes.add(splash);
    }

    function noteMiss(dir:Int):Void {
        if (ghostTapping) {
            var anyGhost:Bool = false;
            notes.forEachAlive(function(daNote:NoteSprite) {
                if (daNote.noteData.mustPress && daNote.noteData.direction == dir && !daNote.noteData.wasGoodHit && daNote.noteData.canBeHit) {
                    anyGhost = true;
                }
            });
            if (anyGhost) {
                scripts.call("noteMissGhost", [dir]);
                return;
            }
        }

        songMisses += 1;
        songScore = Std.int(Math.max(0, songScore - 10));
        health = Math.max(0.0, health - GameplayFlags.getFloat("missPenalty", 0.085));
        audio.muteVocal(true, true);

        updateScoreText();
        scripts.call("noteMiss", [dir]);

        if (health <= 0) {
            gameOver();
        }
    }

    function updateScoreText():Void {
        accuracy = songHits > 0 ? (totalNotesHit / songHits) * 100.0 : 0.0;
        scoreTxt.text = 'Score: $songScore | Misses: $songMisses | Accuracy: ${Math.round(accuracy * 100) / 100}%';
    }

    function updateCameraMotion():Void {
        if (cameraZoomOnBeat && beatPulse > 0) {
            var targetZoom:Float = 1.0 + (beatPulse * 0.0125);
            FlxG.camera.zoom = FlxG.camera.zoom + ((targetZoom - FlxG.camera.zoom) * 0.08);
            camHUD.zoom = camHUD.zoom + ((1.0 + (beatPulse * 0.0065) - camHUD.zoom) * 0.08);
        }
    }

    override public function beatHit(beat:Int):Void {
        super.beatHit(beat);
        beatPulse = beat % 4;

        if (cameraZoomOnBeat && beat % 4 == 0) {
            camGame.zoom += 0.035;
            camHUD.zoom += 0.02;
            FlxTween.tween(camGame, {zoom: 1.0}, 0.25, {ease: FlxEase.quadOut});
            FlxTween.tween(camHUD, {zoom: 1.0}, 0.25, {ease: FlxEase.quadOut});
        }

        scripts.call("beatHit", [beat]);
        scripts.call("onBeatHit", [beat]);
    }

    override public function stepHit(step:Int):Void {
        super.stepHit(step);
        scripts.call("stepHit", [step]);
        scripts.call("onStepHit", [step]);
    }

    public function openPauseMenu():Void {
        paused = true;
        audio.pause();

        #if desktop
        soulscorch.backend.DiscordRPC.changePresence('Paused - $curSong [${curDifficulty.toUpperCase()}]', 'Score: $songScore | Acc: ${Math.round(accuracy * 100) / 100}%');
        #end

        openSubState(new soulscorch.ui.menus.PauseSubState());
    }

    public function resumeSong():Void {
        if (paused) {
            paused = false;
            audio.resume();
        }
    }

    public function gameOver():Void {
        paused = true;
        audio.stop();
        var pStrum:StrumArrow = playerStrums.members[0];
        openSubState(new GameOverSubState(pStrum != null ? pStrum.x : 100, pStrum != null ? pStrum.y : 100));
    }

    function onSongFinished():Void {
        if (paused) return;
        endSong();
    }

    public function endSong():Void {
        if (isEnding) return;
        isEnding = true;

        var cleared = health > 0;
        var stats = new SongStats(curSong, curDifficulty, songScore, songMisses, songHits, accuracy, health, maxHealth, cleared);

        if (SaveData.instance != null) {
            stats.isNewBest = SaveData.instance.submitScore(curSong, curDifficulty, stats.toSaveEntry());
        }

        scripts.call("onSongEnd", [stats]);

        FlxG.switchState(new ResultsState(stats));
    }

    public function reloadModFlags():Void {
        GameplayFlags.resolveModFlags();
        applyGameplayFlags();
    }

    public function getFlagValue(key:String, fallback:Dynamic):Dynamic {
        return GameplayFlags.get(key, fallback);
    }

    public function setFlagValue(key:String, value:Dynamic):Dynamic {
        return GameplayFlags.set(key, value);
    }

    public function isGameplayFlagSet(key:String):Bool {
        return GameplayFlags.getBool(key, false);
    }

    public function computeJudgment(diff:Float):Judgment {
        return Judgment.fromDifference(diff, Conductor.safeZoneOffset);
    }

    public function updateHUDFromFlags():Void {
        healthBar.alpha = hudAlpha;
        scoreTxt.alpha = hudAlpha;
        healthBarBG.alpha = hudAlpha;
    }

    public function handleGhostTapCheck():Void {
        if (!ghostTapping) {
            return;
        }
    }

    public function queueMissAtPlayer(dir:Int):Void {
        noteMiss(dir);
    }

    public function queueComboBurst():Void {
        if (!comboFlashOnHit) {
            return;
        }
    }

    public function applyModdedGameplayTweaks():Void {
        var scrollScale:Float = GameplayFlags.getFloat("scrollSpeedMultiplier", 1.0);
        songSpeed *= scrollScale;

        if (GameplayFlags.getBool("disablePause", false)) {
            allowPause = false;
        }

        if (GameplayFlags.getBool("disableNoteSplash", false)) {
            noteSplashEnabled = false;
        }
    }

    public function updateSongStateFromModFlags():Void {
        applyGameplayFlags();
        updateHUDFromFlags();
        applyModdedGameplayTweaks();
    }

    public function scriptHook(name:String, ?args:Array<Dynamic>):Dynamic {
        if (scripts == null) {
            return null;
        }
        return scripts.call(name, args);
    }

    public function safeNoteCheck():Bool {
        return notes != null && notes.members != null;
    }

    public function getCurrentAccuracyPercent():Float {
        return accuracy;
    }

    public function getCurrentSongPosition():Float {
        return Conductor.songPosition;
    }

    public function getCameraZoom():Float {
        return FlxG.camera.zoom;
    }

    public function setCameraZoom(value:Float):Void {
        FlxG.camera.zoom = value;
        camHUD.zoom = value;
    }

    public function preUpdateGameplayData():Void {
        if (health > maxHealth) {
            health = maxHealth;
        }
        if (health < 0) {
            health = 0;
        }
        updateScoreText();
    }

    public function refreshGameplayFlagsFromConfig():Void {
        if (Runtime.engine != null && Runtime.engine.config != null) {
            GameplayFlags.set("ghostTapping", Runtime.engine.config.ghostTapping);
            GameplayFlags.set("downscroll", Runtime.engine.config.downscroll);
            GameplayFlags.set("antialiasing", Runtime.engine.config.antialiasing);
            GameplayFlags.set("flashingLights", Runtime.engine.config.flashingLights);
        }
        applyGameplayFlags();
    }

    public function onSceneReady():Void {
        scripts.call("onSceneReady", [this]);
    }

    public function onStageReady():Void {
        scripts.call("onStageReady", [this]);
    }

    public function updateSongProgressFromAudio():Void {
        if (audio != null && audio.inst != null && audio.inst.playing) {
            Conductor.songPosition = audio.inst.time;
        }
    }

    public function prepareRuntimeDefaults():Void {
        health = 1.0;
        accuracy = 0.0;
        songScore = 0;
        songMisses = 0;
        songHits = 0;
        totalNotesHit = 0.0;
    }

    override public function destroy():Void {
        if (scripts != null) {
            scripts.destroy();
        }
        if (audio != null) {
            audio.clear();
        }
        super.destroy();
    }
}
