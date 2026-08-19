package soulscorch.gameplay;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.ui.FlxBar;
import flixel.util.FlxColor;
import flixel.util.FlxSort;
import flixel.util.FlxTimer;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.audio.AudioManager;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.input.Controls;
import soulscorch.backend.input.MobilePad;
import soulscorch.backend.system.EventBus;
import soulscorch.backend.system.SaveData;
import soulscorch.backend.system.engine.Runtime;
import soulscorch.backend.system.modules.discord.DiscordRPC;
import soulscorch.backend.utils.Logger;
import soulscorch.gameplay.GameplayFlags;
import soulscorch.gameplay.actors.Character;
import soulscorch.gameplay.actors.HealthIcon;
import soulscorch.gameplay.chart.Chart;
import soulscorch.gameplay.chart.Song;
import soulscorch.gameplay.modchart.ModchartManager;
import soulscorch.gameplay.notes.Note;
import soulscorch.gameplay.notes.NoteSplash;
import soulscorch.gameplay.notes.Strumline;
import soulscorch.gameplay.scoring.Judgment;
import soulscorch.gameplay.scoring.SongStats;
import soulscorch.gameplay.song.SongLoader;
import soulscorch.gameplay.stage.Stage;
import soulscorch.graphics.shaders.ShaderManager;
import soulscorch.scripting.ScriptManager;
import soulscorch.ui.menus.states.ResultsState;
import soulscorch.ui.menus.substate.GameOverSubState;
import soulscorch.ui.menus.substate.PauseSubState;

using StringTools;

class PlayState extends MusicBeatState {
    public static var instance:PlayState;
    public static var curSong:String = "tutorial";
    public static var curDifficulty:String = "normal";

    public var songData:Song;
    public var audio:AudioManager;
    public var scripts:ScriptManager;
    public var modcharts:ModchartManager;

    // --- Cameras & Viewports ---
    public var camGame:FlxCamera;
    public var camHUD:FlxCamera;
    public var camControls:FlxCamera;
    public var camOther:FlxCamera;
    public var defaultCamZoom:Float = 0.9;
    public var defaultHUDZoom:Float = 1.0;
    public var camFollow:FlxObject;
    public var camFollowPos:FlxObject;
    public var camZooming:Bool = true;

    // --- Stage & Actors ---
    public var currentStage:Stage;
    public var boyfriend:Character;
    public var dad:Character;
    public var gf:Character;

    // --- Strums, Splashes & Notes ---
    public var playerStrumline:Strumline;
    public var opponentStrumline:Strumline;
    public var grpNoteSplashes:FlxTypedGroup<NoteSplash>;
    public var notes:FlxTypedGroup<Note>;
    public var unspawnNotes:Array<Note> = [];
    public var eventNotes:Array<ChartEvent> = [];

    // --- Ratings & Popups ---
    public var grpRatings:FlxSpriteGroup;
    public var grpComboNumbers:FlxSpriteGroup;

    // --- HUD & Score ---
    public var health:Float = 1.0;
    public var maxHealth:Float = 2.0;
    public var songScore:Int = 0;
    public var songMisses:Int = 0;
    public var songHits:Int = 0;
    public var combo:Int = 0;
    public var totalNotesHit:Float = 0.0;
    public var accuracy:Float = 0.0;
    public var ratingName:String = "?";

    public var healthBarBG:FlxSprite;
    public var healthBar:FlxBar;
    public var iconP1:HealthIcon;
    public var iconP2:HealthIcon;
    public var scoreTxt:FlxText;
    public var botplayTxt:FlxText;

    // --- Time Bar ---
    public var timeBarBG:FlxSprite;
    public var timeBar:FlxBar;
    public var timeTxt:FlxText;
    public var songLength:Float = 0.0;

    // --- Mobile Virtual Controls ---
    public var mobileControls:MobilePad;

    // --- Configuration State ---
    public var songSpeed:Float = 2.2;
    public var paused:Bool = false;
    public var isEnding:Bool = false;
    public var startedCountdown:Bool = false;
    public var countdownEnded:Bool = false;
    public var ghostTapping:Bool = true;
    public var downscroll:Bool = false;
    public var middlescroll:Bool = false;
    public var botplay:Bool = false;
    public var cameraZoomOnBeat:Bool = true;
    public var allowPause:Bool = true;
    public var noteSplashEnabled:Bool = true;
    public var noteOffset:Float = 0.0;

    private var keysHeld:Array<Bool> = [false, false, false, false];
    private var countdownTimer:FlxTimer;

    public function new(?songId:String, ?difficulty:String) {
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

        ShaderManager.instance.clearShaders();
        FlxG.camera.setFilters([]);

        GameplayFlags.reset();
        GameplayFlags.initDefaults();
        GameplayFlags.resolveModFlags();
        applyGameplayFlags();

        setupCameras();
        initializeSystems();

        loadSongData(curSong, curDifficulty);
        spawnStageAndCharacters();
        generateStrumLines();

        add(currentStage);
        add(opponentStrumline);
        add(playerStrumline);
        add(grpNoteSplashes);
        add(notes);
        add(grpRatings);
        add(grpComboNumbers);

        setupHUD();
        setupMobileControls();
        setupScriptRuntime();
        startCountdown();
    }

    private function applyGameplayFlags():Void {
        if (Runtime.config != null) {
            GameplayFlags.set("ghostTapping", Runtime.config.ghostTapping);
            GameplayFlags.set("downscroll", Runtime.config.downscroll);
            GameplayFlags.set("middlescroll", Runtime.config.middlescroll);
        }

        ghostTapping = GameplayFlags.getBool("ghostTapping", true);
        downscroll = GameplayFlags.getBool("downscroll", false);
        middlescroll = GameplayFlags.getBool("middlescroll", false);
        botplay = GameplayFlags.getBool("botplay", false);
        allowPause = GameplayFlags.getBool("allowPause", true);
        cameraZoomOnBeat = GameplayFlags.getBool("cameraZoomOnBeat", true);
        noteSplashEnabled = GameplayFlags.getBool("noteSplash", true);
        maxHealth = GameplayFlags.getFloat("maxHealth", 2.0);
        noteOffset = GameplayFlags.getFloat("noteOffset", 0.0);
        health = Math.min(maxHealth, Math.max(0.0, health));
    }

    private function setupCameras():Void {
        camGame = new FlxCamera();
        camHUD = new FlxCamera();
        camHUD.bgColor = FlxColor.TRANSPARENT;

        camControls = new FlxCamera();
        camControls.bgColor = FlxColor.TRANSPARENT;

        camOther = new FlxCamera();
        camOther.bgColor = FlxColor.TRANSPARENT;

        FlxG.cameras.reset(camGame);
        FlxG.cameras.add(camHUD, false);
        FlxG.cameras.add(camControls, false);
        FlxG.cameras.add(camOther, false);
        FlxG.cameras.setDefaultDrawTarget(camGame, true);

        camFollow = new FlxObject(0, 0, 1, 1);
        camFollowPos = new FlxObject(0, 0, 1, 1);
        add(camFollow);
        add(camFollowPos);

        camGame.follow(camFollowPos, LOCKON, 1.0);
    }

    private function initializeSystems():Void {
        audio = new AudioManager();
        audio.onSongComplete = onSongFinished;
        scripts = new ScriptManager();

        grpNoteSplashes = new FlxTypedGroup<NoteSplash>();
        notes = new FlxTypedGroup<Note>();
        grpRatings = new FlxSpriteGroup();
        grpComboNumbers = new FlxSpriteGroup();

        grpNoteSplashes.cameras = [camHUD];
        notes.cameras = [camHUD];
        grpRatings.cameras = [camHUD];
        grpComboNumbers.cameras = [camHUD];
    }

    private function loadSongData(songId:String, difficulty:String):Void {
        songData = SongLoader.load(songId, difficulty);
        if (songData != null) {
            songSpeed = songData.scrollSpeed * GameplayFlags.getFloat("songSpeedMultiplier", 1.0);
            Conductor.changeBPM(songData.bpm);
            Conductor.mapBpmChanges(songData.chart);
            prepareChartNotes();
            audio.loadSong(songId);
            songLength = (audio.inst != null && audio.inst.length > 0) ? audio.inst.length : 180000;
        }
    }

    private function spawnStageAndCharacters():Void {
        var stageId = (songData != null && songData.stage != null) ? songData.stage : "stage";
        currentStage = new Stage(stageId);
        defaultCamZoom = currentStage.defaultZoom;

        var playerChar:String = (songData != null && songData.player1 != null) ? songData.player1 : "bf";
        var oppChar:String = (songData != null && songData.player2 != null) ? songData.player2 : "dad";
        var gfChar:String = (songData != null && songData.gfVersion != null) ? songData.gfVersion : "gf";

        gf = new Character(0, 0, gfChar, false);
        dad = new Character(0, 0, oppChar, false);
        boyfriend = new Character(0, 0, playerChar, true);

        currentStage.positionCharacters(boyfriend, dad, gf);

        currentStage.layers.get("behindGF").add(gf);
        currentStage.layers.get("behindDad").add(dad);
        currentStage.layers.get("behindBF").add(boyfriend);
        currentStage.load();

        camFollow.setPosition(dad.getMidpoint().x + 150 + dad.cameraOffset[0], dad.getMidpoint().y - 100 + dad.cameraOffset[1]);
        camFollowPos.setPosition(camFollow.x, camFollow.y);
        camGame.zoom = defaultCamZoom;
        camGame.focusOn(camFollow.getPosition());
    }

    private function generateStrumLines():Void {
        var strumY:Float = downscroll ? FlxG.height - 150 : 50;

        if (middlescroll) {
            var playerX:Float = (FlxG.width * 0.5) - ((Strumline.STRUM_SPACING * 4) * 0.5) + 10;
            playerStrumline = new Strumline(playerX, strumY, true, downscroll);
            playerStrumline.cameras = [camHUD];

            opponentStrumline = new Strumline(40, strumY, false, downscroll);
            opponentStrumline.cameras = [camHUD];
            opponentStrumline.alpha = 0.35;
        } else {
            opponentStrumline = new Strumline(92, strumY, false, downscroll);
            opponentStrumline.cameras = [camHUD];

            playerStrumline = new Strumline(FlxG.width - 480, strumY, true, downscroll);
            playerStrumline.cameras = [camHUD];
        }

        modcharts = new ModchartManager(playerStrumline, opponentStrumline);
    }

    private function setupHUD():Void {
        // --- Time Bar ---
        timeBarBG = new FlxSprite(0, downscroll ? FlxG.height - 35 : 18).makeGraphic(400, 16, 0xAA000000);
        timeBarBG.screenCenter(X);
        timeBarBG.scrollFactor.set(0, 0);
        timeBarBG.cameras = [camHUD];
        add(timeBarBG);

        timeBar = new FlxBar(timeBarBG.x + 2, timeBarBG.y + 2, LEFT_TO_RIGHT, 396, 12, this, 'songLengthProgress', 0, 1);
        timeBar.createFilledBar(0xFF222222, 0xFFFFFFFF);
        timeBar.scrollFactor.set(0, 0);
        timeBar.cameras = [camHUD];
        add(timeBar);

        timeTxt = new FlxText(0, timeBarBG.y - 3, FlxG.width, (songData != null ? songData.title : curSong) + " (0:00 / 0:00)", 14);
        timeTxt.setFormat(Paths.font("vcr"), 14, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        timeTxt.borderSize = 1.0;
        timeTxt.scrollFactor.set(0, 0);
        timeTxt.cameras = [camHUD];
        add(timeTxt);

        // --- Health Bar ---
        healthBarBG = new FlxSprite(0, downscroll ? 60 : FlxG.height * 0.9);
        if (!AssetHelper.loadGraphicSafely(healthBarBG, "ui/healthBar")) {
            healthBarBG.makeGraphic(604, 22, 0xFF000000);
        }
        healthBarBG.screenCenter(X);
        healthBarBG.scrollFactor.set(0, 0);
        healthBarBG.cameras = [camHUD];
        add(healthBarBG);

        var p2Color:FlxColor = (dad != null) ? dad.healthColor : 0xFFFF0000;
        var p1Color:FlxColor = (boyfriend != null) ? boyfriend.healthColor : 0xFF66FF33;

        healthBar = new FlxBar(
            healthBarBG.x + 4, healthBarBG.y + 4, RIGHT_TO_LEFT,
            Std.int(healthBarBG.width - 8), Std.int(healthBarBG.height - 8),
            this, 'health', 0, maxHealth
        );
        healthBar.createFilledBar(p2Color, p1Color);
        healthBar.scrollFactor.set(0, 0);
        healthBar.cameras = [camHUD];
        add(healthBar);

        iconP1 = new HealthIcon(boyfriend != null ? boyfriend.healthIcon : "face", true);
        iconP1.cameras = [camHUD];
        add(iconP1);

        iconP2 = new HealthIcon(dad != null ? dad.healthIcon : "face", false);
        iconP2.cameras = [camHUD];
        add(iconP2);

        scoreTxt = new FlxText(0, healthBarBG.y + 30, FlxG.width, "Score: 0 | Misses: 0 | Accuracy: 0% [?]", 18);
        scoreTxt.setFormat(Paths.font("vcr"), 18, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        scoreTxt.borderSize = 1.5;
        scoreTxt.scrollFactor.set(0, 0);
        scoreTxt.cameras = [camHUD];
        add(scoreTxt);

        botplayTxt = new FlxText(0, healthBarBG.y + (downscroll ? 55 : -35), FlxG.width, "BOTPLAY", 24);
        botplayTxt.setFormat(Paths.font("vcr"), 24, 0xFFFFCC00, CENTER, OUTLINE, FlxColor.BLACK);
        botplayTxt.borderSize = 1.5;
        botplayTxt.scrollFactor.set(0, 0);
        botplayTxt.cameras = [camHUD];
        botplayTxt.visible = botplay;
        add(botplayTxt);

        updateIconPositions();
    }

    private function setupMobileControls():Void {
        #if (mobile || debug)
        mobileControls = new MobilePad(ARROWS_ONLY, NONE);
        mobileControls.cameras = [camControls];
        add(mobileControls);
        Controls.instance.bindMobilePad(mobileControls);
        #end
    }

    private function setupScriptRuntime():Void {
        var songScript = AssetResolver.resolveFile('songs/$curSong/script', [".hx", ".soul", ".lua"]);
        if (songScript != null) scripts.loadScript(songScript);

        var eventScript = AssetResolver.resolveFile('songs/$curSong/events', [".hx", ".soul", ".lua"]);
        if (eventScript != null) scripts.loadScript(eventScript);

        scripts.setAll("game", this);
        scripts.setAll("audio", audio);
        scripts.setAll("modcharts", modcharts);
        scripts.setAll("boyfriend", boyfriend);
        scripts.setAll("dad", dad);
        scripts.setAll("gf", gf);
        scripts.setAll("camGame", camGame);
        scripts.setAll("camHUD", camHUD);
        scripts.setAll("camOther", camOther);

        scripts.callAll("onCreate");
    }

    private function prepareChartNotes():Void {
        unspawnNotes = [];
        eventNotes = [];
        if (songData == null || songData.chart == null) return;

        for (n in songData.chart.notes) {
            var mainNote = new Note(n.time, n.direction, n.sustainLength, null, false, false, n.mustPress, n.type);
            unspawnNotes.push(mainNote);

            if (n.sustainLength > 0) {
                var stepCrochet = Conductor.stepCrochet;
                var totalSustains = Math.floor(n.sustainLength / stepCrochet);
                for (sus in 0...totalSustains) {
                    var susTime = n.time + (stepCrochet * (sus + 1));
                    var isEnd = (sus == totalSustains - 1);
                    var sustainNode = new Note(susTime, n.direction, n.sustainLength, mainNote, true, isEnd, n.mustPress, n.type);
                    mainNote.tail.push(sustainNode);
                    unspawnNotes.push(sustainNode);
                }
            }
        }

        if (songData.chart.events != null) {
            eventNotes = songData.chart.events.copy();
            eventNotes.sort(function(a:ChartEvent, b:ChartEvent):Int {
                return (a.time < b.time) ? -1 : 1;
            });
        }

        unspawnNotes.sort(function(a:Note, b:Note):Int {
            return FlxSort.byValues(FlxSort.ASCENDING, a.strumTime, b.strumTime);
        });
    }

    private function startCountdown():Void {
        startedCountdown = true;
        Conductor.songPosition = -(Conductor.crochet * 5);

        var countdownIndex:Int = 0;
        var introAssets = ["ready", "set", "go"];
        var introSounds = ["intro3", "intro2", "intro1", "introGo"];

        countdownTimer = new FlxTimer().start(Conductor.crochet / 1000.0, function(tmr:FlxTimer) {
            if (countdownIndex < 4) {
                AssetHelper.playSoundSafely(introSounds[countdownIndex], 0.7);

                if (countdownIndex > 0) {
                    var spr = new FlxSprite();
                    if (AssetHelper.loadGraphicSafely(spr, "ui/countdown/" + introAssets[countdownIndex - 1])) {
                        spr.scrollFactor.set();
                        spr.screenCenter();
                        spr.cameras = [camHUD];
                        add(spr);

                        FlxTween.tween(spr, {alpha: 0, "scale.x": 1.15, "scale.y": 1.15}, (Conductor.crochet / 1000.0) * 0.8, {
                            ease: FlxEase.cubeOut,
                            onComplete: function(_) {
                                remove(spr, true);
                                spr.destroy();
                            }
                        });
                    }
                }
            }

            if (countdownIndex == 4) {
                countdownEnded = true;
                audio.play();
                scripts.callAll("onSongStart", []);
                #if desktop
                DiscordRPC.updateSongPresence(
                    songData != null ? songData.title : curSong,
                    curDifficulty,
                    songLength,
                    0.0,
                    0.0,
                    0
                );
                #end
            }

            countdownIndex++;
        }, 5);
    }

    override public function update(elapsed:Float):Void {
        if (paused) return;

        scripts.callAll("onUpdate", [elapsed]);
        audio.update(elapsed);
        ShaderManager.instance.update(elapsed);

        if (countdownEnded && audio.inst != null && audio.inst.playing) {
            Conductor.songPosition = audio.inst.time;
        } else if (!countdownEnded) {
            Conductor.songPosition += elapsed * 1000.0;
        }

        Conductor.update(elapsed);

        if (modcharts != null) {
            modcharts.update(elapsed);
        }

        super.update(elapsed);

        camFollowPos.x = FlxMath.lerp(camFollow.x, camFollowPos.x, Math.exp(-elapsed * 4.0));
        camFollowPos.y = FlxMath.lerp(camFollow.y, camFollowPos.y, Math.exp(-elapsed * 4.0));

        if (camZooming) {
            camGame.zoom = FlxMath.lerp(defaultCamZoom, camGame.zoom, Math.exp(-elapsed * 3.0));
            camHUD.zoom = FlxMath.lerp(defaultHUDZoom, camHUD.zoom, Math.exp(-elapsed * 3.0));
        }

        updateEvents();
        updateNoteSpawns();
        handleInput();
        updateNotePositions();
        updateIconPositions();
        updateTimeBar();

        if (Controls.instance.PAUSE && allowPause && countdownEnded) {
            openPauseMenu();
        }

        scripts.callAll("onUpdatePost", [elapsed]);
    }

    private function updateEvents():Void {
        while (eventNotes.length > 0 && eventNotes[0].time <= Conductor.songPosition) {
            var event = eventNotes.shift();
            triggerEvent(event.name, event.val1, event.val2);
        }
    }

    private function updateTimeBar():Void {
        if (songLength <= 0) return;

        var curTime = Math.max(0, Conductor.songPosition);
        var curSeconds = Math.floor(curTime / 1000);
        var totalSeconds = Math.floor(songLength / 1000);

        var curMinutesStr = Std.string(Math.floor(curSeconds / 60));
        var curSecsStr = (curSeconds % 60 < 10 ? "0" : "") + Std.string(curSeconds % 60);

        var totalMinutesStr = Std.string(Math.floor(totalSeconds / 60));
        var totalSecsStr = (totalSeconds % 60 < 10 ? "0" : "") + Std.string(totalSeconds % 60);

        timeTxt.text = '${songData != null ? songData.title : curSong} ($curMinutesStr:$curSecsStr / $totalMinutesStr:$totalSecsStr)';
    }

    public var songLengthProgress(get, never):Float;
    inline function get_songLengthProgress():Float {
        return songLength > 0 ? Math.min(1.0, Math.max(0.0, Conductor.songPosition / songLength)) : 0.0;
    }

    private function updateNoteSpawns():Void {
        while (unspawnNotes.length > 0 && unspawnNotes[0].strumTime - Conductor.songPosition < (1800 / songSpeed)) {
            var note = unspawnNotes.shift();
            note.cameras = [camHUD];
            notes.add(note);
        }
    }

    private function updateNotePositions():Void {
        notes.forEachAlive(function(daNote:Note) {
            var targetStrum = daNote.mustPress ? playerStrumline.receptors[daNote.noteData] : opponentStrumline.receptors[daNote.noteData];

            if (targetStrum != null) {
                daNote.updatePosition(targetStrum.x, targetStrum.y, songSpeed, downscroll);

                if (modcharts != null) {
                    modcharts.modifyNote(daNote, daNote.noteData, daNote.mustPress ? PLAYER : OPPONENT, daNote.strumTime);
                }

                // Opponent & Botplay Auto-Hit
                if ((!daNote.mustPress || botplay) && daNote.strumTime <= Conductor.songPosition) {
                    if (daNote.mustPress) {
                        goodNoteHit(daNote);
                    } else {
                        targetStrum.playAnim("confirm", true);
                        targetStrum.resetAnim = 0.15;

                        if (dad != null) {
                            dad.playSingAnim(daNote.noteData);
                            camFollow.setPosition(dad.getMidpoint().x + 150 + dad.cameraOffset[0], dad.getMidpoint().y - 100 + dad.cameraOffset[1]);
                        }

                        audio.muteVocal(false, false);
                        daNote.kill();
                        notes.remove(daNote, true);
                        daNote.destroy();
                    }
                    return;
                }
            }

            // Miss detection
            if (daNote.mustPress && !botplay && daNote.strumTime < Conductor.songPosition - Conductor.safeZoneOffset && !daNote.wasGoodHit) {
                daNote.tooLate = true;
                noteMiss(daNote.noteData);
                daNote.kill();
                notes.remove(daNote, true);
                daNote.destroy();
            }
        });
    }

    private function handleInput():Void {
        if (botplay) return;

        for (i in 0...4) {
            keysHeld[i] = Controls.instance.notePressed(i);

            if (Controls.instance.noteJustPressed(i)) pressStrum(i);
            if (Controls.instance.noteJustReleased(i)) releaseStrum(i);

            if (keysHeld[i]) {
                notes.forEachAlive(function(daNote:Note) {
                    if (daNote.mustPress && daNote.noteData == i && daNote.isSustainNote && daNote.canBeHit && !daNote.wasGoodHit) {
                        if (daNote.strumTime <= Conductor.songPosition + (Conductor.stepCrochet * 0.5)) {
                            goodNoteHit(daNote);
                        }
                    }
                });
            }
        }
    }

    private function pressStrum(dir:Int):Void {
        var pStrum = playerStrumline.receptors[dir];
        if (pStrum != null) pStrum.playAnim("pressed");

        var possibleNotes:Array<Note> = [];
        notes.forEachAlive(function(daNote:Note) {
            if (daNote.mustPress && daNote.noteData == dir && daNote.canBeHit && !daNote.wasGoodHit && !daNote.isSustainNote) {
                possibleNotes.push(daNote);
            }
        });

        if (possibleNotes.length > 0) {
            possibleNotes.sort(function(a:Note, b:Note):Int {
                return FlxSort.byValues(FlxSort.ASCENDING, Math.abs(a.strumTime - (Conductor.songPosition - noteOffset)), Math.abs(b.strumTime - (Conductor.songPosition - noteOffset)));
            });
            goodNoteHit(possibleNotes[0]);
        } else if (!ghostTapping) {
            noteMiss(dir);
        } else {
            scripts.callAll("onGhostTap", [dir]);
        }
    }

    private function releaseStrum(dir:Int):Void {
        var pStrum = playerStrumline.receptors[dir];
        if (pStrum != null) pStrum.playAnim("static");
    }

    private function goodNoteHit(note:Note):Void {
        note.wasGoodHit = true;
        combo++;

        if (!note.isSustainNote) {
            var diff:Float = Math.abs(note.strumTime - (Conductor.songPosition - noteOffset));
            var judgment:Judgment = Judgment.fromDifference(diff, Conductor.safeZoneOffset);

            songHits++;
            songScore += Judgment.score(judgment);
            totalNotesHit += Judgment.accuracyWeight(judgment);
            health = Math.min(maxHealth, health + Judgment.healthModifier(judgment));

            popupRating(judgment);

            if (Judgment.triggersSplash(judgment) && noteSplashEnabled && playerStrumline.receptors[note.noteData] != null) {
                spawnSplash(playerStrumline.receptors[note.noteData].x, playerStrumline.receptors[note.noteData].y, note.noteData);
            }
        } else {
            health = Math.min(maxHealth, health + 0.005);
            songScore += 10;
        }

        audio.muteVocal(true, false);

        var pStrum = playerStrumline.receptors[note.noteData];
        if (pStrum != null) {
            pStrum.playAnim("confirm", true);
            pStrum.resetAnim = 0.15;
        }

        if (boyfriend != null) {
            boyfriend.playSingAnim(note.noteData);
            camFollow.setPosition(boyfriend.getMidpoint().x - 100 + boyfriend.cameraOffset[0], boyfriend.getMidpoint().y - 100 + boyfriend.cameraOffset[1]);
        }

        updateScoreText();
        scripts.callAll("onNoteHit", [note]);

        note.kill();
        notes.remove(note, true);
        note.destroy();
    }

    private function popupRating(judgment:Judgment):Void {
        var ratingSpr:FlxSprite = grpRatings.recycle(FlxSprite);
        var ratingName:String = Std.string(judgment).toLowerCase();

        AssetHelper.loadGraphicSafely(ratingSpr, 'ui/ratings/$ratingName');
        ratingSpr.screenCenter();
        ratingSpr.x = (FlxG.width * 0.55) - 40;
        ratingSpr.y -= 60;
        ratingSpr.acceleration.y = 550;
        ratingSpr.velocity.y = -FlxG.random.int(140, 175);
        ratingSpr.velocity.x = -FlxG.random.int(0, 10);
        ratingSpr.alpha = 1.0;
        ratingSpr.scale.set(0.7, 0.7);
        grpRatings.add(ratingSpr);

        FlxTween.tween(ratingSpr, {alpha: 0}, 0.2, {
            startDelay: Conductor.crochet * 0.001 * 0.8,
            onComplete: function(_) {
                ratingSpr.kill();
                grpRatings.remove(ratingSpr, true);
            }
        });

        // Combo Numbers Display
        var comboStr:String = Std.string(combo);
        var comboDigits:Array<String> = comboStr.split("");
        var startX:Float = ratingSpr.x + 20;

        for (i in 0...comboDigits.length) {
            var numSpr:FlxSprite = grpComboNumbers.recycle(FlxSprite);
            AssetHelper.loadGraphicSafely(numSpr, 'ui/ratings/num' + comboDigits[i]);
            numSpr.setPosition(startX + (i * 24), ratingSpr.y + 70);
            numSpr.acceleration.y = 550;
            numSpr.velocity.y = -FlxG.random.int(120, 150);
            numSpr.velocity.x = FlxG.random.float(-5, 5);
            numSpr.alpha = 1.0;
            numSpr.scale.set(0.5, 0.5);
            grpComboNumbers.add(numSpr);

            FlxTween.tween(numSpr, {alpha: 0}, 0.2, {
                startDelay: Conductor.crochet * 0.001 * 0.8,
                onComplete: function(_) {
                    numSpr.kill();
                    grpComboNumbers.remove(numSpr, true);
                }
            });
        }
    }

    private function spawnSplash(x:Float, y:Float, dir:Int):Void {
        var splash:NoteSplash = grpNoteSplashes.recycle(NoteSplash);
        splash.spawn(x, y, dir);
        grpNoteSplashes.add(splash);
    }

    private function noteMiss(dir:Int):Void {
        songMisses++;
        combo = 0;
        songScore = Std.int(Math.max(0, songScore - 10));
        health = Math.max(0.0, health - GameplayFlags.getFloat("missPenalty", 0.085));
        audio.muteVocal(true, true);

        if (boyfriend != null) {
            boyfriend.playSingAnim(dir, true);
            camFollow.setPosition(boyfriend.getMidpoint().x - 100 + boyfriend.cameraOffset[0], boyfriend.getMidpoint().y - 100 + boyfriend.cameraOffset[1]);
        }

        updateScoreText();
        scripts.callAll("onPlayerMiss", [dir]);

        if (health <= 0) {
            gameOver();
        }
    }

    private function updateScoreText():Void {
        accuracy = songHits > 0 ? (totalNotesHit / songHits) * 100.0 : 0.0;
        ratingName = getRatingString(accuracy);
        scoreTxt.text = 'Score: $songScore | Misses: $songMisses | Accuracy: ${Math.round(accuracy * 100) / 100}% [$ratingName]';
    }

    private function getRatingString(acc:Float):String {
        if (songHits == 0 && songMisses == 0) return "?";
        if (acc >= 100.0) return "SFC";
        if (acc >= 90.0) return "GFC";
        if (acc >= 80.0) return "FC";
        if (acc >= 70.0) return "Clear";
        return "Loss";
    }

    private function updateIconPositions():Void {
        var percent:Float = (health / maxHealth);
        var iconOffset:Float = 26;

        iconP1.x = healthBar.x + (healthBar.width * (1 - percent)) - iconOffset;
        iconP2.x = healthBar.x + (healthBar.width * (1 - percent)) - (iconP2.width - iconOffset);
        iconP1.y = healthBar.y - (iconP1.height / 2);
        iconP2.y = healthBar.y - (iconP2.height / 2);

        iconP1.updateHealth(percent * 100.0);
        iconP2.updateHealth((1.0 - percent) * 100.0);
    }

    override public function beatHit(beat:Int):Void {
        super.beatHit(beat);

        if (cameraZoomOnBeat && beat % 4 == 0) {
            camGame.zoom += 0.035;
            camHUD.zoom += 0.02;
        }

        iconP1.beatHit(beat);
        iconP2.beatHit(beat);

        if (currentStage != null) currentStage.beatHit(beat);
        if (gf != null) gf.dance();
        if (dad != null) dad.dance();
        if (boyfriend != null) boyfriend.dance();

        scripts.callAll("onBeatHit", [beat]);
    }

    override public function stepHit(step:Int):Void {
        super.stepHit(step);
        if (currentStage != null) currentStage.stepHit(step);
        scripts.callAll("onStepHit", [step]);
    }

    public function triggerEvent(name:String, val1:String, val2:String):Void {
        switch (name) {
            case "Camera Zoom" | "Set Cam Zoom":
                var zoom = Std.parseFloat(val1);
                if (!Math.isNaN(zoom)) defaultCamZoom = zoom;
            case "Screen Shake":
                var intensity = Std.parseFloat(val1);
                var duration = Std.parseFloat(val2);
                camGame.shake(Math.isNaN(intensity) ? 0.01 : intensity, Math.isNaN(duration) ? 0.2 : duration);
            case "Change Character":
                var targetType = val1.toLowerCase().trim();
                var newCharName = val2.trim();
                if (targetType == "dad" || targetType == "opponent") {
                    dad.curCharacter = newCharName;
                    dad.loadCharacter();
                    iconP2.changeIcon(dad.healthIcon);
                } else if (targetType == "bf" || targetType == "boyfriend" || targetType == "player") {
                    boyfriend.curCharacter = newCharName;
                    boyfriend.loadCharacter();
                    iconP1.changeIcon(boyfriend.healthIcon);
                }
        }
        scripts.callAll("onEvent", [name, val1, val2]);
    }

    public function openPauseMenu():Void {
        paused = true;
        audio.pause();
        scripts.callAll("onPause", []);
        openSubState(new PauseSubState());
    }

    public function resumeSong():Void {
        if (paused) {
            paused = false;
            audio.resume();
            scripts.callAll("onResume", []);
        }
    }

    public function gameOver():Void {
        paused = true;
        audio.stop();
        scripts.callAll("onGameOver", []);
        openSubState(new GameOverSubState(boyfriend != null ? boyfriend.x : 100, boyfriend != null ? boyfriend.y : 100));
    }

    private function onSongFinished():Void {
        if (paused) return;
        endSong();
    }

    public function endSong():Void {
        if (isEnding) return;
        isEnding = true;

        var cleared = health > 0;
        var stats = new SongStats(curSong, curDifficulty, songScore, songMisses, songHits, accuracy, health, maxHealth, cleared);

        if (SaveData.instance != null) {
            SaveData.instance.submitScore(curSong, curDifficulty, stats.toSaveEntry());
        }

        scripts.callAll("onSongEnd", [stats]);
        MusicBeatState.switchState(new ResultsState(stats));
    }

    override public function destroy():Void {
        Controls.instance.unbindMobilePad();
        if (countdownTimer != null) countdownTimer.cancel();
        if (scripts != null) {
            scripts.callAll("onDestroy");
            scripts.clear();
        }
        if (audio != null) {
            audio.clear();
        }
        ShaderManager.instance.clearShaders();
        FlxG.camera.setFilters([]);
        super.destroy();
    }
}