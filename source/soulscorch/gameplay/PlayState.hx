package soulscorch.gameplay;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.ui.FlxBar;
import flixel.util.FlxColor;
import flixel.util.FlxSort;
import flixel.math.FlxMath;

import soulscorch.assets.AssetHelper;
import soulscorch.core.Runtime;
import soulscorch.core.Scene;
import soulscorch.core.SaveData;
import soulscorch.gameplay.modchart.ModchartManager;
import soulscorch.input.InputMap;
import soulscorch.modding.ScriptManager;
import soulscorch.ui.ScriptedSubState;
import soulscorch.ui.menus.ResultsState;

#if sys
import sys.FileSystem;
#end

class PlayState extends Scene {
    public static var instance:PlayState;
    public static var curSong:String = "tutorial";
    public static var curDifficulty:String = "normal";

    public static var gameplayFlags:Map<String, Dynamic> = new Map();

    public var songData:Song;
    public var audio:AudioManager;
    public var scripts:ScriptManager;
    public var modcharts:ModchartManager;

    // --- Cameras & Tracking ---
    public var camGame:FlxCamera;
    public var camHUD:FlxCamera;
    public var defaultCamZoom:Float = 0.9;
    public var defaultHUDZoom:Float = 1.0;
    public var camFollow:FlxObject;
    public var camZooming:Bool = true;

    // --- Characters & Stage ---
    public var boyfriend:Character;
    public var dad:Character;
    public var gf:Character;
    public var stageGroup:FlxTypedGroup<FlxSprite>;

    // --- Strums, Notes & Pools ---
    public var playerStrums:FlxTypedGroup<StrumArrow>;
    public var opponentStrums:FlxTypedGroup<StrumArrow>;
    public var grpNoteSplashes:FlxTypedGroup<NoteSplash>;
    public var notes:FlxTypedGroup<NoteSprite>;
    public var unspawnNotes:Array<Note> = [];

    // --- HUD Elements ---
    public var health:Float = 1.0;
    public var maxHealth:Float = 2.0;
    public var songScore:Int = 0;
    public var songMisses:Int = 0;
    public var songHits:Int = 0;
    public var combo:Int = 0;
    public var totalNotesHit:Float = 0;
    public var accuracy:Float = 0.00;

    public var healthBarBG:FlxSprite;
    public var healthBar:FlxBar;
    public var iconP1:FlxSprite;
    public var iconP2:FlxSprite;
    public var scoreTxt:FlxText;

    // --- State Config ---
    public var songSpeed:Float = 2.2;
    public var paused:Bool = false;
    public var isEnding:Bool = false;
    public var startedCountdown:Bool = false;
    public var ghostTapping:Bool = true;
    public var downscroll:Bool = false;
    public var cameraZoomOnBeat:Bool = true;
    public var allowPause:Bool = true;
    public var hudAlpha:Float = 1.0;
    public var noteSplashEnabled:Bool = true;

    // --- Keys State ---
    private var keysHeld:Array<Bool> = [false, false, false, false];

    public function new(?songId:String = null, ?difficulty:String = null) {
        super();
        if (songId != null && songId != "") curSong = songId;
        if (difficulty != null && difficulty != "") curDifficulty = difficulty;
    }

    override public function create():Void {
        super.create();
        instance = this;

        if (FlxG.sound.music != null) {
            FlxG.sound.music.stop();
            FlxG.sound.music = null;
        }

        GameplayFlags.initDefaults();
        GameplayFlags.resolveModFlags();
        applyGameplayFlags();

        setupCameras();
        initializeSystems();

        loadSong(curSong, curDifficulty);
        spawnStageAndCharacters();
        generateStrumLines();

        add(stageGroup);
        add(gf);
        add(dad);
        add(boyfriend);
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
        }

        ghostTapping = GameplayFlags.getBool("ghostTapping", true);
        downscroll = GameplayFlags.getBool("downscroll", false);
        allowPause = GameplayFlags.getBool("allowPause", true);
        cameraZoomOnBeat = GameplayFlags.getBool("cameraZoomOnBeat", true);
        noteSplashEnabled = GameplayFlags.getBool("noteSplash", true);
        hudAlpha = GameplayFlags.getFloat("hudAlpha", 1.0);
        maxHealth = GameplayFlags.getFloat("maxHealth", 2.0);
        health = Math.min(maxHealth, Math.max(0.0, health));
    }

    function setupCameras():Void {
        camGame = new FlxCamera();
        camHUD = new FlxCamera();
        camHUD.bgColor.alpha = 0;

        FlxG.cameras.reset(camGame);
        FlxG.cameras.add(camHUD, false);
        FlxG.cameras.setDefaultDrawTarget(camGame, true);

        camFollow = new FlxObject(0, 0, 1, 1);
        add(camFollow);
        camGame.follow(camFollow, LOCKON, 0.04);
    }

    function initializeSystems():Void {
        audio = new AudioManager();
        audio.onSongComplete = onSongFinished;
        scripts = new ScriptManager();
        stageGroup = new FlxTypedGroup<FlxSprite>();

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

    function spawnStageAndCharacters():Void {
        var playerChar:String = (songData != null && songData.player1 != null) ? songData.player1 : "bf";
        var oppChar:String = (songData != null && songData.player2 != null) ? songData.player2 : "dad";
        var gfChar:String = (songData != null && songData.gfVersion != null) ? songData.gfVersion : "gf";

        gf = new Character(400, 130, gfChar);
        dad = new Character(100, 100, oppChar);
        boyfriend = new Character(770, 450, playerChar, true);

        camFollow.setPosition(dad.getMidpoint().x + 150, dad.getMidpoint().y - 100);
        camGame.zoom = defaultCamZoom;
        camGame.focusOn(camFollow.getPosition());
    }

    function setupScriptRuntime():Void {
        scripts.loadScriptsFromDir("assets/data/scripts");
        scripts.loadScript('assets/data/songs/$curSong/script.soul');
        scripts.loadScript('assets/data/songs/$curSong/script.hx');
        scripts.loadScript('assets/data/songs/$curSong/events.soul');
        scripts.loadScript('assets/data/songs/$curSong/events.hx');

        scripts.set("game", this);
        scripts.set("PlayState", PlayState);
        scripts.set("audio", audio);
        scripts.set("modcharts", modcharts);
        scripts.set("Conductor", Conductor);
        scripts.set("boyfriend", boyfriend);
        scripts.set("dad", dad);
        scripts.set("gf", gf);
        scripts.set("playerStrums", playerStrums);
        scripts.set("opponentStrums", opponentStrums);
        scripts.set("camGame", camGame);
        scripts.set("camHUD", camHUD);

        scripts.call("create");
        scripts.call("onCreate");
        scripts.call("postCreate");
    }

    function generateStrumLines():Void {
        var strumY:Float = downscroll ? FlxG.height - 150 : 50;
        for (i in 0...4) {
            var opp:StrumArrow = new StrumArrow(92 + (i * 112), strumY, i, 0);
            opp.cameras = [camHUD];
            opponentStrums.add(opp);

            var ply:StrumArrow = new StrumArrow(FlxG.width - 480 + (i * 112), strumY, i, 1);
            ply.cameras = [camHUD];
            playerStrums.add(ply);
        }
    }

    function setupHUD():Void {
        healthBarBG = new FlxSprite(0, downscroll ? 60 : FlxG.height * 0.9);
        if (!AssetHelper.loadGraphicSafely(healthBarBG, "assets/images/gameplay/healthBar.png")) {
            healthBarBG.makeGraphic(604, 22, 0xFF000000);
        }
        healthBarBG.screenCenter(X);
        healthBarBG.scrollFactor.set();
        healthBarBG.cameras = [camHUD];
        add(healthBarBG);

        healthBar = new FlxBar(
            healthBarBG.x + 4, healthBarBG.y + 4, RIGHT_TO_LEFT, 
            Std.int(healthBarBG.width - 8), Std.int(healthBarBG.height - 8), 
            this, 'health', 0, maxHealth
        );
        healthBar.createFilledBar(0xFFFF0000, 0xFF66FF33);
        healthBar.scrollFactor.set();
        healthBar.cameras = [camHUD];
        add(healthBar);

        iconP1 = new FlxSprite().makeGraphic(80, 80, 0xFF66FF33);
        iconP1.cameras = [camHUD];
        add(iconP1);

        iconP2 = new FlxSprite().makeGraphic(80, 80, 0xFFFF0000);
        iconP2.cameras = [camHUD];
        add(iconP2);

        scoreTxt = new FlxText(0, healthBarBG.y + 30, FlxG.width, "Score: 0 | Misses: 0 | Accuracy: 0%", 18);
        scoreTxt.setFormat(null, 18, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        scoreTxt.scrollFactor.set();
        scoreTxt.cameras = [camHUD];
        add(scoreTxt);

        updateIconPositions();
    }

    function loadSong(songId:String, difficulty:String):Void {
        songData = SongLoader.load(songId, difficulty);
        if (songData != null) {
            songSpeed = songData.scrollSpeed * GameplayFlags.getFloat("songSpeedMultiplier", 1.0);
            Conductor.changeBPM(songData.bpm);
            Conductor.mapBpmChanges(songData.chart);
            prepareChartNotes();
            audio.loadSong(songId);
        }
    }

    function prepareChartNotes():Void {
        unspawnNotes = [];
        if (songData == null || songData.chart == null) return;

        for (n in songData.chart.notes) {
            unspawnNotes.push(n);
            if (n.sustainLength > 0) {
                var totalSustains:Int = Math.floor(n.sustainLength / Conductor.stepCrochet);
                for (sus in 0...totalSustains) {
                    var susTime:Float = n.strumTime + (Conductor.stepCrochet * (sus + 1));
                    var isEnd:Bool = (sus == totalSustains - 1);
                    var sustainData:Note = new Note(susTime, n.direction, 0, n.mustPress, true, n.noteType);
                    unspawnNotes.push(sustainData);
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
    }

    // Framerate independent lerp
    inline function camLerp(a:Float, b:Float, ratio:Float, elapsed:Float):Float {
        return a + (b - a) * (1 - Math.exp(-ratio * (elapsed * 60)));
    }

    override public function update(elapsed:Float):Void {
        if (paused) return;

        scripts.call("update", [elapsed]);
        scripts.call("onUpdate", [elapsed]);

        audio.update(elapsed);
        updateSongProgressFromAudio();

        if (modcharts != null) modcharts.update(elapsed);

        super.update(elapsed);

        if (camZooming) {
            camGame.zoom = camLerp(camGame.zoom, defaultCamZoom, 0.04, elapsed);
            camHUD.zoom = camLerp(camHUD.zoom, defaultHUDZoom, 0.04, elapsed);
        }

        updateNoteSpawns();
        handleInput();
        updateNotePositions();
        updateIconPositions();

        if (InputMap.justPressed("pause") && allowPause) openPauseMenu();

        scripts.call("updatePost", [elapsed]);
        scripts.call("onUpdatePost", [elapsed]);
    }

    function updateNoteSpawns():Void {
        while (unspawnNotes.length > 0 && unspawnNotes[0].strumTime - Conductor.songPosition < 1800 / songSpeed) {
            var noteData:Note = unspawnNotes.shift();
            // NoteSprite initialization mapped to standard API
            var noteSprite:NoteSprite = new NoteSprite(noteData, noteData.isSustainNote, false);
            noteSprite.cameras = [camHUD];
            notes.add(noteSprite);
        }
    }

    function updateNotePositions():Void {
        notes.forEachAlive(function(daNote:NoteSprite) {
            var targetStrum:StrumArrow = daNote.noteData.mustPress ? playerStrums.members[daNote.noteData.direction] : opponentStrums.members[daNote.noteData.direction];
            if (targetStrum != null) {
                var distance = (Conductor.songPosition - daNote.noteData.strumTime) * (0.45 * songSpeed);
                daNote.x = targetStrum.x + daNote.offsetX;
                daNote.y = targetStrum.y + (downscroll ? -distance : distance) + daNote.offsetY;

                // Sustain Clipping
                if (daNote.noteData.isSustainNote) {
                    if (downscroll && daNote.y - daNote.offsetY * 0.5 > targetStrum.y) {
                        daNote.clipRect = new flixel.math.FlxRect(0, 0, daNote.frameWidth, (targetStrum.y - daNote.y));
                    } else if (!downscroll && daNote.y + daNote.offsetY * 0.5 < targetStrum.y) {
                        daNote.clipRect = new flixel.math.FlxRect(0, (targetStrum.y - daNote.y), daNote.frameWidth, daNote.frameHeight);
                    }
                }

                // Opponent auto-hit
                if (!daNote.noteData.mustPress && daNote.noteData.strumTime <= Conductor.songPosition) {
                    targetStrum.playAnim('confirm', true);
                    targetStrum.resetAnim = 0.15;
                    if (dad != null) {
                        dad.playAnim(["singLEFT", "singDOWN", "singUP", "singRIGHT"][daNote.noteData.direction], true);
                        camFollow.setPosition(dad.getMidpoint().x + 150, dad.getMidpoint().y - 100);
                    }
                    audio.muteVocal(false, false);
                    daNote.kill();
                    notes.remove(daNote, true);
                    daNote.destroy();
                    return;
                }
            }

            daNote.noteData.canBeHit = (daNote.noteData.strumTime > Conductor.songPosition - Conductor.safeZoneOffset 
                && daNote.noteData.strumTime < Conductor.songPosition + Conductor.safeZoneOffset);

            // Miss logic
            if (daNote.noteData.strumTime < Conductor.songPosition - Conductor.safeZoneOffset && !daNote.noteData.wasGoodHit) {
                daNote.noteData.tooLate = true;
                noteMiss(daNote.noteData.direction);
                daNote.kill();
                notes.remove(daNote, true);
                daNote.destroy();
            }

            // Continuous Sustain logic
            if (daNote.noteData.isSustainNote && daNote.noteData.canBeHit && daNote.noteData.mustPress && daNote.noteData.strumTime <= Conductor.songPosition) {
                if (keysHeld[daNote.noteData.direction]) goodNoteHit(daNote);
            }
        });
    }

    function handleInput():Void {
        var keyNames:Array<String> = ["left", "down", "up", "right"];
        for (i in 0...keyNames.length) {
            keysHeld[i] = InputMap.pressed(keyNames[i]);

            if (InputMap.justPressed(keyNames[i])) pressStrum(i);
            if (InputMap.justReleased(keyNames[i])) releaseStrum(i);
        }
    }

    function pressStrum(dir:Int):Void {
        var pStrum:StrumArrow = playerStrums.members[dir];
        if (pStrum != null) pStrum.playAnim('pressed');

        var possibleNotes:Array<NoteSprite> = [];
        notes.forEachAlive(function(daNote:NoteSprite) {
            if (daNote.noteData.mustPress && daNote.noteData.direction == dir && daNote.noteData.canBeHit && !daNote.noteData.wasGoodHit && !daNote.noteData.isSustainNote) {
                possibleNotes.push(daNote);
            }
        });

        if (possibleNotes.length > 0) {
            possibleNotes.sort(function(a:NoteSprite, b:NoteSprite):Int {
                return FlxSort.byValues(FlxSort.ASCENDING, Math.abs(a.noteData.strumTime - Conductor.songPosition), Math.abs(b.noteData.strumTime - Conductor.songPosition));
            });
            goodNoteHit(possibleNotes[0]);
        } else if (!ghostTapping) {
            noteMiss(dir);
        }
    }

    function releaseStrum(dir:Int):Void {
        var pStrum:StrumArrow = playerStrums.members[dir];
        if (pStrum != null) pStrum.playAnim('static');
    }

    function goodNoteHit(noteSprite:NoteSprite):Void {
        var note:Note = noteSprite.noteData;
        note.wasGoodHit = true;
        combo++;

        if (!note.isSustainNote) {
            var diff:Float = Math.abs(note.strumTime - Conductor.songPosition);
            var judgment:Judgment = Judgment.fromDifference(diff, Conductor.safeZoneOffset);

            songHits += 1;
            songScore += Judgment.score(judgment);
            totalNotesHit += Judgment.accuracyWeight(judgment);
            health = Math.min(maxHealth, health + Judgment.healthModifier(judgment));
            
            popRating(diff);
            if (Judgment.triggersSplash(judgment) && noteSplashEnabled && playerStrums.members[note.direction] != null) {
                spawnSplash(playerStrums.members[note.direction].x, playerStrums.members[note.direction].y, note.direction);
            }
        } else {
            health = Math.min(maxHealth, health + 0.005);
            songScore += 10;
        }

        audio.muteVocal(true, false);

        var pStrum:StrumArrow = playerStrums.members[note.direction];
        if (pStrum != null) {
            pStrum.playAnim('confirm', true);
            pStrum.resetAnim = 0.15;
        }

        if (boyfriend != null) {
            boyfriend.playAnim(["singLEFT", "singDOWN", "singUP", "singRIGHT"][note.direction], true);
            camFollow.setPosition(boyfriend.getMidpoint().x - 100, boyfriend.getMidpoint().y - 100);
        }

        updateScoreText();
        scripts.call("goodNoteHit", [noteSprite]);
        scripts.call("onNoteHit", [noteSprite]);

        noteSprite.kill();
        notes.remove(noteSprite, true);
        noteSprite.destroy();
    }

    function popRating(diff:Float):Void {
        var ratingName:String = "sick";
        if (diff > Conductor.safeZoneOffset * 0.9) ratingName = "shit";
        else if (diff > Conductor.safeZoneOffset * 0.75) ratingName = "bad";
        else if (diff > Conductor.safeZoneOffset * 0.2) ratingName = "good";

        var ratingSpr:FlxSprite = new FlxSprite().loadGraphic('assets/images/ui/ratings/$ratingName.png');
        ratingSpr.screenCenter();
        ratingSpr.x += FlxG.random.int(-20, 20);
        ratingSpr.y -= 60 + FlxG.random.int(-10, 10);
        ratingSpr.acceleration.y = 550;
        ratingSpr.velocity.y -= FlxG.random.int(140, 175);
        ratingSpr.velocity.x -= FlxG.random.int(0, 10);
        ratingSpr.cameras = [camHUD];
        add(ratingSpr);

        FlxTween.tween(ratingSpr, {alpha: 0}, 0.2, {
            startDelay: Conductor.crochet * 0.001,
            onComplete: function(_) { ratingSpr.destroy(); }
        });

        // Combo Logic
        var comboStr:String = Std.string(combo);
        for (i in 0...comboStr.length) {
            var numSpr:FlxSprite = new FlxSprite().loadGraphic('assets/images/ui/numbers/num' + comboStr.charAt(i) + '.png');
            numSpr.screenCenter();
            numSpr.x += (43 * i) - 90;
            numSpr.y += 80;
            numSpr.acceleration.y = FlxG.random.int(200, 300);
            numSpr.velocity.y -= FlxG.random.int(140, 160);
            numSpr.cameras = [camHUD];
            add(numSpr);

            FlxTween.tween(numSpr, {alpha: 0}, 0.2, {
                startDelay: Conductor.crochet * 0.002,
                onComplete: function(_) { numSpr.destroy(); }
            });
        }
    }

    function spawnSplash(x:Float, y:Float, dir:Int):Void {
        var splash:NoteSplash = grpNoteSplashes.recycle(NoteSplash);
        // Assuming splash setup uses standard arguments
        splash.setPosition(x, y);
        grpNoteSplashes.add(splash);
    }

    function noteMiss(dir:Int):Void {
        songMisses += 1;
        combo = 0;
        songScore = Std.int(Math.max(0, songScore - 10));
        health = Math.max(0.0, health - GameplayFlags.getFloat("missPenalty", 0.085));
        audio.muteVocal(true, true);

        if (boyfriend != null) {
            boyfriend.playAnim(["singLEFTmiss", "singDOWNmiss", "singUPmiss", "singRIGHTmiss"][dir], true);
            camFollow.setPosition(boyfriend.getMidpoint().x - 100, boyfriend.getMidpoint().y - 100);
        }

        updateScoreText();
        scripts.call("noteMiss", [dir]);
        scripts.call("onPlayerMiss", [dir]);

        if (health <= 0) gameOver();
    }

    function updateScoreText():Void {
        accuracy = songHits > 0 ? (totalNotesHit / songHits) * 100.0 : 0.0;
        scoreTxt.text = 'Score: $songScore | Misses: $songMisses | Accuracy: ${Math.round(accuracy * 100) / 100}%';
    }

    private function updateIconPositions():Void {
        var percent:Float = (health / maxHealth);
        var iconOffset:Float = 26;
        iconP1.x = healthBar.x + (healthBar.width * (1 - percent)) - iconOffset;
        iconP2.x = healthBar.x + (healthBar.width * (1 - percent)) - (iconP2.width - iconOffset);
        iconP1.y = healthBar.y - (iconP1.height / 2);
        iconP2.y = healthBar.y - (iconP2.height / 2);
    }

    override public function beatHit(beat:Int):Void {
        super.beatHit(beat);

        if (cameraZoomOnBeat && beat % 4 == 0) {
            camGame.zoom += 0.035;
            camHUD.zoom += 0.02;
        }

        iconP1.scale.set(1.2, 1.2);
        iconP2.scale.set(1.2, 1.2);
        FlxTween.tween(iconP1.scale, {x: 1.0, y: 1.0}, 0.2, {ease: FlxEase.cubeOut});
        FlxTween.tween(iconP2.scale, {x: 1.0, y: 1.0}, 0.2, {ease: FlxEase.cubeOut});

        if (boyfriend != null && !StringTools.startsWith(boyfriend.animation.curAnim.name, "sing")) boyfriend.dance();
        if (dad != null && !StringTools.startsWith(dad.animation.curAnim.name, "sing")) dad.dance();
        if (gf != null && beat % 2 == 0 && !StringTools.startsWith(gf.animation.curAnim.name, "sing")) gf.dance();

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

        if (SaveData.instance != null) SaveData.instance.submitScore(curSong, curDifficulty, stats.toSaveEntry());

        scripts.call("onSongEnd", [stats]);
        FlxG.switchState(new ResultsState(stats));
    }

    public function updateSongProgressFromAudio():Void {
        if (audio != null && audio.inst != null && audio.inst.playing) Conductor.songPosition = audio.inst.time;
    }

    override public function destroy():Void {
        if (scripts != null) {
            scripts.call("onDestroy");
            scripts.clear();
        }
        if (audio != null) audio.clear();
        super.destroy();
    }
}