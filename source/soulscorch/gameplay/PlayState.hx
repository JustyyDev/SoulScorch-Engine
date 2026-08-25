package soulscorch.gameplay;

import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.ui.FlxBar;
import flixel.util.FlxColor;
import flixel.util.FlxSort;
import flixel.util.FlxStringUtil;
import flixel.util.FlxTimer;
import haxe.Json;
import haxe.xml.Access;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.MusicBeatSubstate;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.audio.AudioManager;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.input.Controls;
import soulscorch.backend.input.InputMap;
import soulscorch.backend.input.MobilePad;
import soulscorch.backend.localization.LanguageManager;
import soulscorch.backend.system.SaveData;
import soulscorch.backend.system.XMSoul;
import soulscorch.backend.system.engine.EngineOptimizer;
import soulscorch.backend.system.engine.HardwareConductor;
import soulscorch.backend.system.engine.Runtime;
import soulscorch.backend.system.modules.discord.DiscordRPC;
import soulscorch.backend.utils.ColorUtil;
import soulscorch.backend.utils.Logger;
import soulscorch.gameplay.GameplayFlags;
import soulscorch.gameplay.JudgementManager;
import soulscorch.gameplay.actors.Character;
import soulscorch.gameplay.actors.HealthIcon;
import soulscorch.gameplay.chart.Chart;
import soulscorch.gameplay.chart.Song;
import soulscorch.gameplay.cutscenes.CutsceneSubState;
import soulscorch.gameplay.cutscenes.DialogueSubState;
import soulscorch.gameplay.modchart.ModchartManager;
import soulscorch.gameplay.modchart.ModchartTypes.ModTarget;
import soulscorch.gameplay.notes.Note;
import soulscorch.gameplay.notes.NoteSkinManager;
import soulscorch.gameplay.notes.NoteSplash;
import soulscorch.gameplay.notes.StrumArrow;
import soulscorch.gameplay.notes.Strumline;
import soulscorch.gameplay.replays.ReplayManager;
import soulscorch.gameplay.scoring.Judgment;
import soulscorch.gameplay.scoring.SongStats;
import soulscorch.gameplay.song.Difficulty;
import soulscorch.gameplay.song.SongLoader;
import soulscorch.gameplay.stage.Stage;
import soulscorch.graphics.FunkinSprite;
import soulscorch.graphics.JuiceManager;
import soulscorch.graphics.shaders.ShaderManager;
import soulscorch.graphics.shaders.SoulCamera;
import soulscorch.scripting.ScriptManager;
import soulscorch.scripting.mod.ModFeatureRegistry;
import soulscorch.ui.menus.states.ResultsState;
import soulscorch.ui.menus.substate.GameOverSubState;
import soulscorch.ui.menus.substate.PauseSubState;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

typedef ParsedChartEvent = {
    var time:Float;
    var name:String;
    var val1:Dynamic;
    var val2:Dynamic;
}

class PlayState extends MusicBeatState {
    public static var instance:PlayState;
    public static var curSong:String = "tutorial";
    public static var curDifficulty:String = "normal";
    public static var isStoryMode:Bool = false;
    public static var chartingMode:Bool = false;

    public var songData:Song;
    public var audio:AudioManager;
    public var scripts:ScriptManager;
    public var modcharts:ModchartManager;
    public var judgementManager:JudgementManager;

    // --- Cameras & Viewports ---
    public var camControls:SoulCamera;
    public var defaultHUDZoom:Float = 1.0;
    public var camFollow:FlxObject;
    public var camFollowPos:FlxObject;
    public var camZooming:Bool = true;
    public var cameraZoomBeatInterval:Int = 4;
    public var cameraZoomBeatOffset:Int = 0;
    public var cameraSpeed:Float = 1.0;

    public var camDisplaceX:Float = 0.0;
    public var camDisplaceY:Float = 0.0;
    public var camDisplaceOffset:Float = 24.0;

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
    public var sustainsGroup:FlxTypedGroup<Note>;
    public var unspawnNotes:Array<Note> = [];
    public var eventNotes:Array<ParsedChartEvent> = [];
    private var unspawnCursor:Int = 0;
    private var eventCursor:Int = 0;

    // --- HUD & Score Stats ---
    public var health(get, set):Float;
    inline function get_health():Float return judgementManager != null ? judgementManager.health : 1.0;
    inline function set_health(val:Float):Float {
        var clamped = Math.max(0.0, Math.min(maxHealth, val));
        if (judgementManager != null) judgementManager.health = clamped;
        if (clamped <= 0.0 && !isEnding && !practiceMode && startedCountdown) {
            gameOver();
        }
        return clamped;
    }

    public var maxHealth:Float = 2.0;
    public var songScore:Int = 0;
    public var songMisses:Int = 0;
    public var songHits:Int = 0;
    public var combo:Int = 0;
    public var maxCombo:Int = 0;
    public var totalNotesPassed:Int = 0;
    public var totalAccuracyScore:Float = 0.0;
    public var accuracy:Float = 0.0;

    public var sicks:Int = 0;
    public var goods:Int = 0;
    public var bads:Int = 0;
    public var shits:Int = 0;

    public var healthBarBG:FlxSprite;
    public var healthBar:FlxBar;
    public var iconP1:HealthIcon;
    public var iconP2:HealthIcon;
    public var scoreTxt:FlxText;
    public var botplayTxt:FlxText;
    public var judgementCounterTxt:FlxText;

    // --- Time Bar ---
    public var timeBarBG:FlxSprite;
    public var timeBar:FlxBar;
    public var timeTxt:FlxText;
    public var songLength:Float = 0.0;

    public var mobileControls:MobilePad;

    // --- Configuration & Flags ---
    public var songSpeed:Float = 2.2;
    public var paused:Bool = false;
    public var isEnding:Bool = false;
    public var startedCountdown:Bool = false;
    public var countdownEnded:Bool = false;
    public var ghostTapping:Bool = true;
    public var downscroll:Bool = false;
    public var middlescroll:Bool = false;
    public var botplay:Bool = false;
    public var practiceMode:Bool = false;
    public var cameraZoomOnBeat:Bool = true;
    public var allowPause:Bool = true;
    public var noteSplashEnabled:Bool = true;
    public var noteOffset:Float = 0.0;
    public var mustHitSection:Bool = false;
    public var passiveHealthDrain:Float = 0.0;
    public var healthDrainFloor:Float = 0.1;
    public var randomModchartsEnabled:Bool = false;

    private var keysHeld:Array<Bool> = [false, false, false, false];
    private var keysPressed:Array<Bool> = [false, false, false, false];
    private var keysReleased:Array<Bool> = [false, false, false, false];
    private var pausePressed:Bool = false;
    private var countdownTimer:FlxTimer;
    private var hudConfig:Access = null;
    private var lastScriptSection:Int = -1;
    private var forcedSongNoteSkin:String = null;

    // Reusable array caches to eliminate per-frame allocations
    private var _playElapsedArgCache:Array<Dynamic> = [0.0];
    private var _intArgCache:Array<Dynamic> = [0];
    private var _lastTimeBarSecond:Int = -1;
    private var _lastTimeBarTitle:String = "";
    private var splashPoolSize:Int = 32;
    private var splashMaxConcurrent:Int = 24;

    private static inline var QUEUE_COMPACT_THRESHOLD:Int = 512;

    private inline function isValidLane(lane:Int):Bool {
        return lane >= 0 && lane < 4;
    }

    public function new(?songId:String, ?difficulty:String) {
        super();
        if (songId != null && songId != "") curSong = songId;
        if (difficulty != null && difficulty != "") curDifficulty = difficulty;
    }

    override public function create():Void {
        super.create();
        instance = this;
        Controls.instance.enabled = true;
        InputMap.claimKeyboardFocus();
        defaultCamZoom = 0.9;
        FlxG.camera.bgColor = FlxColor.BLACK;

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

        initializeSystems();
        ModFeatureRegistry.preloadForSong(curSong);

        loadSongData(curSong, curDifficulty);
        loadSongModifiers(curSong);
        applyModSongRulePack();
        judgementManager.maxHealth = maxHealth;
        judgementManager.health = Math.min(judgementManager.health, maxHealth);
        loadExternalEvents(curSong);
        spawnStageAndCharacters();
        generateStrumLines();

        add(currentStage);
        add(opponentStrumline);
        add(playerStrumline);
        add(sustainsGroup);
        add(notes);
        add(grpNoteSplashes);
        add(judgementManager);

        setupHUD();
        setupMobileControls();
        setupScriptRuntime();

        if (scripts != null) {
            scripts.callAll("onPostCreate", []);
        }

        checkAndRunCutscenes(function() {
            startCountdown();
        });

        if (!ReplayManager.playing) {
            ReplayManager.startRecording(curSong, curDifficulty);
        }
    }

    private function applyGameplayFlags():Void {
        if (Runtime.config != null) {
            GameplayFlags.set("ghostTapping", Runtime.config.ghostTapping);
            GameplayFlags.set("downscroll", Runtime.config.downscroll);
            GameplayFlags.set("middlescroll", Runtime.config.middlescroll);
            GameplayFlags.set("randomModcharts", Runtime.config.randomModcharts);
        }

        ghostTapping = GameplayFlags.getBool("ghostTapping", true);
        downscroll = GameplayFlags.getBool("downscroll", false);
        middlescroll = GameplayFlags.getBool("middlescroll", false);
        botplay = GameplayFlags.getBool("botplay", false);
        practiceMode = GameplayFlags.getBool("practiceMode", false);
        allowPause = GameplayFlags.getBool("allowPause", true);
        cameraZoomOnBeat = GameplayFlags.getBool("cameraZoomOnBeat", true);
        randomModchartsEnabled = GameplayFlags.getBool("randomModcharts", Runtime.config != null ? Runtime.config.randomModcharts : false);
        noteSplashEnabled = GameplayFlags.getBool("noteSplash", true);
        if (GameplayFlags.getBool("lowEndMode", false) || GameplayFlags.getBool("lowQuality", false)) {
            noteSplashEnabled = GameplayFlags.getBool("noteSplash", false);
        }
        maxHealth = GameplayFlags.getFloat("maxHealth", 2.0);
        noteOffset = GameplayFlags.getFloat("noteOffset", 0.0);
        cameraSpeed = GameplayFlags.getFloat("cameraSpeed", 1.0);

        splashPoolSize = GameplayFlags.getInt("splashPoolSize", 32);
        splashMaxConcurrent = GameplayFlags.getInt("maxNoteSplashes", 24);
        if (GameplayFlags.getBool("lowEndMode", false) || GameplayFlags.getBool("lowQuality", false)) {
            splashPoolSize = Std.int(Math.min(splashPoolSize, 16));
            splashMaxConcurrent = Std.int(Math.min(splashMaxConcurrent, 10));
        }

        ScriptManager.mobileConservativeMode = GameplayFlags.getBool("scriptingMobileConservative", ScriptManager.mobileConservativeMode);
        ScriptManager.luaEnabled = GameplayFlags.getBool("scriptingEnableLua", ScriptManager.luaEnabled);
        ScriptManager.pythonEnabled = GameplayFlags.getBool("scriptingEnablePython", ScriptManager.pythonEnabled);
        ScriptManager.soulScriptEnabled = GameplayFlags.getBool("scriptingEnableSoulScript", ScriptManager.soulScriptEnabled);
        ScriptManager.hscriptEnabled = GameplayFlags.getBool("scriptingEnableHScript", ScriptManager.hscriptEnabled);

        Conductor.safeFrames = GameplayFlags.getInt("safeFrames", Conductor.safeFrames);
        Conductor.safeZoneOffset = GameplayFlags.getFloat("safeZoneOffset", (Conductor.safeFrames / 60.0) * 1000.0);
    }

    private function loadSongModifiers(songId:String):Void {
        var clean = songId.toLowerCase().trim();
        var paths = [
            'songs/$clean/modifiers.xmsoul',
            'data/$clean/modifiers.xmsoul',
            'assets/preload/songs/$clean/modifiers.xmsoul'
        ];

        for (p in paths) {
            var mods = XMSoul.loadModifiers(p);
            if (mods != null) {
                songSpeed *= mods.scrollSpeedMultiplier;
                ghostTapping = mods.ghostTapping;
                passiveHealthDrain = mods.healthDrain;
                healthDrainFloor = mods.drainFloor;
                maxHealth = mods.maxHealth;
                Logger.info('Loaded modifiers for $clean (Drain: $passiveHealthDrain, Floor: $healthDrainFloor)', "modifiers");
                break;
            }
        }
    }

    override public function setupCameras():Void {
        camGame = new SoulCamera();
        camHUD = new SoulCamera();
        camHUD.bgColor = FlxColor.TRANSPARENT;

        camControls = new SoulCamera();
        camControls.bgColor = FlxColor.TRANSPARENT;

        camOther = new SoulCamera();
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

        judgementManager = new JudgementManager(camHUD);
        judgementManager.onHealthChange = function(newHealth:Float) {
            syncJudgementState();
            if (scripts != null) scripts.callAll("onHealthChange", [newHealth, maxHealth]);
            if (newHealth <= 0 && !isEnding && !practiceMode) {
                gameOver();
            }
            updateScoreText();
        };

        grpNoteSplashes = new FlxTypedGroup<NoteSplash>();
        sustainsGroup = new FlxTypedGroup<Note>();
        notes = new FlxTypedGroup<Note>();

        grpNoteSplashes.cameras = [camHUD];
        sustainsGroup.cameras = [camHUD];
        notes.cameras = [camHUD];

        if (noteSplashEnabled) {
            var splashSkin = GameplayFlags.getString("defaultSplashSkin", "default");
            for (_ in 0...splashPoolSize) {
                var pooled:NoteSplash = grpNoteSplashes.recycle(NoteSplash);
                if (pooled.splashSkin != splashSkin) pooled.loadSplashSkin(splashSkin);
                pooled.kill();
            }
        }
    }

    private function loadSongData(songId:String, difficulty:String):Void {
        songData = SongLoader.load(songId, difficulty);
        if (songData != null) {
            songSpeed = songData.scrollSpeed * GameplayFlags.getFloat("songSpeedMultiplier", 1.0);
            Conductor.changeBPM(songData.bpm);
            Conductor.mapBpmChanges(songData.chart);
            prepareChartNotes();

            audio.loadSong(songId);
            var clean = songId.toLowerCase().trim();
            loadSongVocals(clean);

            if (audio.inst != null && audio.inst.length > 0) {
                songLength = audio.inst.length;
            } else if (unspawnNotes.length > 0) {
                songLength = unspawnNotes[unspawnNotes.length - 1].strumTime + 3000;
            } else {
                songLength = 60000;
            }
        }
    }

    private function loadExternalEvents(songId:String):Void {
        eventNotes = [];
        eventCursor = 0;
        if (songData != null && songData.chart != null && songData.chart.events.length > 0) {
            for (event in songData.chart.events) {
                eventNotes.push({time: event.time, name: event.name, val1: event.val1, val2: event.val2});
            }
            expandEventMacros();
            eventNotes.sort(function(a:ParsedChartEvent, b:ParsedChartEvent):Int {
                return (a.time < b.time) ? -1 : (a.time > b.time ? 1 : 0);
            });
            return;
        }

        var cleanSong = songId.toLowerCase().trim();

        var eventsXml:Access = XMSoul.parse('songs/$cleanSong/events');
        if (eventsXml == null) eventsXml = XMSoul.parse('data/$cleanSong/events');

        if (eventsXml != null) {
            for (evNode in eventsXml.nodes.resolve("event")) {
                eventNotes.push({
                    time: XMSoul.getFloatAttr(evNode, "time", 0.0),
                    name: XMSoul.getAttr(evNode, "name", ""),
                    val1: XMSoul.getAttr(evNode, "target", XMSoul.getAttr(evNode, "val1", "")),
                    val2: XMSoul.getAttr(evNode, "anim", XMSoul.getAttr(evNode, "val2", ""))
                });
            }
            expandEventMacros();
            eventNotes.sort(function(a:ParsedChartEvent, b:ParsedChartEvent):Int {
                return (a.time < b.time) ? -1 : 1;
            });
            return;
        }

        var eventPaths = [
            'songs/$cleanSong/events.json',
            'data/$cleanSong/events.json',
            'assets/preload/songs/$cleanSong/events.json'
        ];

        for (p in eventPaths) {
            var resolved = AssetResolver.resolveFile(p, [".json", ""]);
            if (resolved != null) {
                var content = AssetResolver.getText(resolved);
                if (content != null && content.length > 0) {
                    try {
                        var parsed:Dynamic = Json.parse(content);
                        if (parsed != null && Reflect.hasField(parsed, "events")) {
                            var rawEvents:Array<Dynamic> = cast Reflect.field(parsed, "events");
                            if (rawEvents != null) {
                                for (ev in rawEvents) {
                                    if (ev != null && Reflect.hasField(ev, "name") && Reflect.hasField(ev, "time")) {
                                        var params:Array<Dynamic> = Reflect.hasField(ev, "params") ? cast Reflect.field(ev, "params") : [];
                                        eventNotes.push({
                                            time: Std.parseFloat(Std.string(Reflect.field(ev, "time"))),
                                            name: Std.string(Reflect.field(ev, "name")),
                                            val1: (params != null && params.length > 0) ? params[0] : "",
                                            val2: (params != null && params.length > 1) ? params[1] : ""
                                        });
                                    }
                                }
                            }
                        }
                    } catch (e:Dynamic) {}
                }
            }
        }

        expandEventMacros();
        eventNotes.sort(function(a:ParsedChartEvent, b:ParsedChartEvent):Int {
            return (a.time < b.time) ? -1 : 1;
        });
        eventCursor = 0;
    }

    private function expandEventMacros():Void {
        if (eventNotes == null || eventNotes.length == 0) return;

        var expanded:Array<ParsedChartEvent> = [];
        for (event in eventNotes) {
            var macroSteps = ModFeatureRegistry.getEventMacro(event.name);
            if (macroSteps != null && macroSteps.length > 0) {
                for (step in macroSteps) {
                    expanded.push({
                        time: event.time + step.delay,
                        name: step.name,
                        val1: (step.val1 != null && Std.string(step.val1).length > 0) ? step.val1 : event.val1,
                        val2: (step.val2 != null && Std.string(step.val2).length > 0) ? step.val2 : event.val2
                    });
                }
            } else {
                expanded.push(event);
            }
        }

        eventNotes = expanded;
    }

    private function checkAndRunCutscenes(onComplete:Void->Void):Void {
        var cleanSong = curSong.toLowerCase().trim();

        var cutscenePaths = [
            'songs/$cleanSong/cutscene.hx',
            'songs/$cleanSong/intro.hx',
            'songs/$cleanSong/$cleanSong.hx',
            'data/$cleanSong/cutscene.hx',
            'data/$cleanSong/$cleanSong.hx'
        ];

        for (p in cutscenePaths) {
            var resolved = AssetResolver.resolveFile(p, [".hx", ".soul", ".lua", ".py"]);
            if (resolved != null) {
                openSubState(new CutsceneSubState(resolved, onComplete));
                return;
            }
        }

        var dialoguePaths = [
            'songs/$cleanSong/dialogue.xmsoul',
            'data/$cleanSong/dialogue.xmsoul',
            'songs/$cleanSong/dialogue.xml',
            'data/$cleanSong/dialogue.xml'
        ];

        for (dp in dialoguePaths) {
            var resolved = AssetResolver.resolveFile(dp, [".xmsoul", ".xml", ""]);
            if (resolved != null) {
                var xmlText = AssetResolver.getText(resolved);
                if (xmlText != null && xmlText.length > 0) {
                    openSubState(new DialogueSubState(xmlText, onComplete));
                    return;
                }
            }
        }

        onComplete();
    }

    private function spawnStageAndCharacters():Void {
        var stageId = (songData != null && songData.stage != null && songData.stage.length > 0) ? songData.stage : "stage";
        currentStage = new Stage(stageId);
        currentStage.load();
        defaultCamZoom = currentStage.defaultZoom;

        var playerChar:String = (songData != null && songData.player1 != null) ? songData.player1 : "bf";
        var oppChar:String = (songData != null && songData.player2 != null) ? songData.player2 : "dad";
        var gfChar:String = (songData != null && songData.gfVersion != null) ? songData.gfVersion : "gf";

        gf = new Character(0, 0, gfChar, false);
        dad = new Character(0, 0, oppChar, false);
        boyfriend = new Character(0, 0, playerChar, true);

        currentStage.positionCharacters(boyfriend, dad, gf);
        currentStage.addCharacters(boyfriend, dad, gf);

        currentStage.cameras = [camGame];
        gf.cameras = [camGame];
        dad.cameras = [camGame];
        boyfriend.cameras = [camGame];

        if (currentStage.startCamPos != null) {
            camFollow.setPosition(currentStage.startCamPos.x, currentStage.startCamPos.y);
        } else {
            centerCameraOnDad();
        }
        camFollowPos.setPosition(camFollow.x, camFollow.y);
        camGame.zoom = defaultCamZoom;
        camGame.focusOn(camFollow.getPosition());
    }

    private function generateStrumLines():Void {
        var strumY:Float = downscroll ? FlxG.height - 155 : 50;
        var noteSkinToUse = getActiveNoteSkin();

        if (middlescroll) {
            playerStrumline = new Strumline((FlxG.width * 0.5) - (Strumline.STRUM_SPACING * 2), strumY, true, downscroll);
            playerStrumline.cameras = [camHUD];

            opponentStrumline = new Strumline(40, strumY, false, downscroll);
            opponentStrumline.cameras = [camHUD];
            opponentStrumline.alpha = 0.35;
        } else {
            opponentStrumline = new Strumline(90, strumY, false, downscroll);
            opponentStrumline.cameras = [camHUD];

            var playerX = FlxG.width - (Strumline.STRUM_SPACING * 4) - 90;
            playerStrumline = new Strumline(playerX, strumY, true, downscroll);
            playerStrumline.cameras = [camHUD];
        }

        playerStrumline.changeSkin(noteSkinToUse);
        opponentStrumline.changeSkin(noteSkinToUse);

        modcharts = new ModchartManager(playerStrumline, opponentStrumline);
        if (randomModchartsEnabled) {
            queueSafeRandomModchartPreset();
        }
    }

    private function queueSafeRandomModchartPreset():Void {
        if (modcharts == null || songData == null || songData.chart == null) return;

        var totalSteps:Int = 192;
        if (unspawnNotes != null && unspawnNotes.length > 0) {
            var lastTime = unspawnNotes[unspawnNotes.length - 1].strumTime;
            var stepCrochet = Conductor.stepCrochet > 0 ? Conductor.stepCrochet : 150.0;
            totalSteps = Std.int(Math.max(192, (lastTime / stepCrochet) + 32));
        }
        var segment = Std.int(Math.max(48, Math.floor(totalSteps / 5)));

        var candidates = [
            {name: "wave", min: 0.06, max: 0.14, target: ModTarget.PLAYER},
            {name: "drunk", min: 0.04, max: 0.1, target: ModTarget.PLAYER},
            {name: "tipsy", min: 0.04, max: 0.1, target: ModTarget.PLAYER},
            {name: "confusion", min: 0.015, max: 0.035, target: ModTarget.PLAYER},
            {name: "mini", min: 0.03, max: 0.08, target: ModTarget.PLAYER},
            {name: "bumpy", min: 0.03, max: 0.08, target: ModTarget.PLAYER},
            {name: "alpha", min: -0.08, max: -0.02, target: ModTarget.OPPONENT}
        ];

        var used:Map<String, Bool> = new Map<String, Bool>();
        var stageCount = FlxG.random.int(2, 4);
        var cursor = Std.int(Math.max(16, Conductor.curBeat * 4));

        for (i in 0...stageCount) {
            var pick = candidates[FlxG.random.int(0, candidates.length - 1)];
            var guard = 0;
            while (used.exists(pick.name) && guard < 8) {
                pick = candidates[FlxG.random.int(0, candidates.length - 1)];
                guard++;
            }
            used.set(pick.name, true);

            var value = FlxG.random.float(pick.min, pick.max);
            modcharts.queueEvent(cursor, pick.name, value, 0.7, "quadOut", pick.target, -1);

            var releaseStep = cursor + Std.int(segment * FlxG.random.float(0.75, 1.15));
            modcharts.queueEvent(releaseStep, pick.name, 0.0, 0.7, "quadInOut", pick.target, -1);

            cursor += segment;
            if (cursor >= totalSteps - 24) break;
        }
    }

    private function getActiveNoteSkin():String {
        if (forcedSongNoteSkin != null && forcedSongNoteSkin.length > 0 && forcedSongNoteSkin != "default") return forcedSongNoteSkin;
        if (songData != null && songData.noteSkin != null && songData.noteSkin != "default") return songData.noteSkin;

        var flagSkin = GameplayFlags.getString("defaultNoteSkin", "default");
        if (flagSkin != "default") return flagSkin;

        if (Runtime.config != null && Runtime.config.defaultNoteSkin != null && Runtime.config.defaultNoteSkin != "default") {
            return Runtime.config.defaultNoteSkin;
        }

        return NoteSkinManager.getNoteSkinName();
    }

    private function applyModSongRulePack():Void {
        var rule = ModFeatureRegistry.getSongRule(curSong);
        if (rule == null) return;

        if (rule.noteSkin != null && rule.noteSkin.length > 0) {
            forcedSongNoteSkin = rule.noteSkin;
        }
        if (rule.defaultCamZoom != null && !Math.isNaN(rule.defaultCamZoom)) {
            defaultCamZoom = rule.defaultCamZoom;
        }
        if (rule.defaultHUDZoom != null && !Math.isNaN(rule.defaultHUDZoom)) {
            defaultHUDZoom = rule.defaultHUDZoom;
            camHUD.zoom = defaultHUDZoom;
        }
        if (rule.cameraZoomBeatInterval != null && rule.cameraZoomBeatInterval > 0) {
            cameraZoomBeatInterval = rule.cameraZoomBeatInterval;
        }
        if (rule.cameraZoomBeatOffset != null) {
            cameraZoomBeatOffset = rule.cameraZoomBeatOffset;
        }
        if (rule.allowPause != null) {
            allowPause = rule.allowPause;
        }
        if (rule.judgeProfile != null && judgementManager != null) {
            judgementManager.applyModJudgmentProfile(rule.judgeProfile);
        }
    }

    private function applyRuntimeNoteSkin(skin:String):Void {
        if (skin == null || skin.trim().length == 0) return;
        var cleanSkin = skin.trim();

        forcedSongNoteSkin = cleanSkin;
        if (songData != null) songData.noteSkin = cleanSkin;

        if (playerStrumline != null) playerStrumline.changeSkin(cleanSkin);
        if (opponentStrumline != null) opponentStrumline.changeSkin(cleanSkin);

        if (notes != null) {
            notes.forEachAlive(function(n:Note) {
                n.skinName = cleanSkin;
                n.loadNoteSkin(cleanSkin);
                n.playAnim();
            });
        }

        if (sustainsGroup != null) {
            sustainsGroup.forEachAlive(function(n:Note) {
                n.skinName = cleanSkin;
                n.loadNoteSkin(cleanSkin);
                n.playAnim();
            });
        }

        if (unspawnNotes != null) {
            for (n in unspawnNotes) {
                if (n != null) {
                    n.skinName = cleanSkin;
                    n.loadNoteSkin(cleanSkin);
                    n.playAnim();
                }
            }
        }
    }

    private function setupHUD():Void {
        hudConfig = XMSoul.parse("ui/game/hudLayout");
        if (hudConfig == null) hudConfig = XMSoul.parse("data/ui/hudLayout");

        var defaultTimeY:Float = downscroll ? FlxG.height - 40 : 18;
        var timeBarY:Float = defaultTimeY;
        var timeBarWidth:Int = 400;
        var timeBarHeight:Int = 16;

        if (hudConfig != null && hudConfig.hasNode.resolve("timebar")) {
            var tbNode = hudConfig.node.resolve("timebar");
            timeBarY = XMSoul.getFloatAttr(tbNode, downscroll ? "yDown" : "yUp", defaultTimeY);
            timeBarWidth = XMSoul.getIntAttr(tbNode, "width", 400);
            timeBarHeight = XMSoul.getIntAttr(tbNode, "height", 16);
        }

        timeBarBG = new FlxSprite(0, timeBarY).makeGraphic(timeBarWidth, timeBarHeight, 0xAA000000);
        timeBarBG.screenCenter(X);
        timeBarBG.scrollFactor.set(0, 0);
        timeBarBG.cameras = [camHUD];
        add(timeBarBG);

        timeBar = new FlxBar(timeBarBG.x + 2, timeBarBG.y + 2, LEFT_TO_RIGHT, timeBarWidth - 4, timeBarHeight - 4, this, 'songLengthProgress', 0, 1);
        timeBar.createFilledBar(0xFF222222, 0xFFFFFFFF);
        timeBar.scrollFactor.set(0, 0);
        timeBar.cameras = [camHUD];
        add(timeBar);

        timeTxt = new FlxText(0, timeBarBG.y - 3, FlxG.width, "", 14);
        timeTxt.setFormat(Paths.font("vcr"), 14, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        timeTxt.borderSize = 1.0;
        timeTxt.scrollFactor.set(0, 0);
        timeTxt.cameras = [camHUD];
        add(timeTxt);

        var defaultHealthY:Float = downscroll ? 60 : FlxG.height * 0.88;
        var healthBarY:Float = defaultHealthY;
        var healthBarW:Int = 604;
        var healthBarH:Int = 22;
        var bgGraphicName = "ui/game/healthBar";

        if (hudConfig != null && hudConfig.hasNode.resolve("healthbar")) {
            var hbNode = hudConfig.node.resolve("healthbar");
            healthBarY = XMSoul.getFloatAttr(hbNode, downscroll ? "yDown" : "yUp", defaultHealthY);
            healthBarW = XMSoul.getIntAttr(hbNode, "width", 604);
            healthBarH = XMSoul.getIntAttr(hbNode, "height", 22);
            bgGraphicName = XMSoul.getAttr(hbNode, "bgImage", "ui/game/healthBar");
        }

        healthBarBG = new FlxSprite(0, healthBarY);
        if (!AssetHelper.loadGraphicSafely(healthBarBG, bgGraphicName)) {
            healthBarBG.makeGraphic(healthBarW, healthBarH, 0xFF000000);
        }
        healthBarBG.screenCenter(X);
        healthBarBG.scrollFactor.set(0, 0);
        healthBarBG.cameras = [camHUD];
        add(healthBarBG);

        var p2Color:FlxColor = (dad != null) ? dad.healthColor : 0xFFFF0000;
        var p1Color:FlxColor = (boyfriend != null) ? boyfriend.healthColor : 0xFF66FF33;
        var activeUiSkin = ModFeatureRegistry.activeUiSkin;
        if (activeUiSkin != null) {
            if (activeUiSkin.healthP2Color != null) {
                p2Color = ColorUtil.fromHexSafe(activeUiSkin.healthP2Color, p2Color);
            }
            if (activeUiSkin.healthP1Color != null) {
                p1Color = ColorUtil.fromHexSafe(activeUiSkin.healthP1Color, p1Color);
            }
        }

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

        var scoreYOffset:Float = 32;
        var scoreFontSize:Int = 18;
        var fontName = "vcr";

        if (hudConfig != null && hudConfig.hasNode.resolve("scoretext")) {
            var stNode = hudConfig.node.resolve("scoretext");
            scoreYOffset = XMSoul.getFloatAttr(stNode, "yOffset", 32);
            scoreFontSize = XMSoul.getIntAttr(stNode, "size", 18);
            fontName = XMSoul.getAttr(stNode, "font", "vcr");
        }

        if (activeUiSkin != null && activeUiSkin.font != null && activeUiSkin.font.length > 0) {
            fontName = activeUiSkin.font;
        }

        var scoreColor:FlxColor = FlxColor.WHITE;
        if (activeUiSkin != null && activeUiSkin.scoreColor != null) {
            scoreColor = ColorUtil.fromHexSafe(activeUiSkin.scoreColor, scoreColor);
        }

        scoreTxt = new FlxText(0, healthBarBG.y + scoreYOffset, FlxG.width, "Score: 0 | Misses: 0 | Accuracy: 0% [?]", scoreFontSize);
        scoreTxt.setFormat(Paths.font(fontName), scoreFontSize, scoreColor, CENTER, OUTLINE, FlxColor.BLACK);
        scoreTxt.borderSize = 1.5;
        scoreTxt.scrollFactor.set(0, 0);
        scoreTxt.cameras = [camHUD];
        add(scoreTxt);

        judgementCounterTxt = new FlxText(20, healthBarBG.y - 40, 300, "", 14);
        judgementCounterTxt.setFormat(Paths.font(fontName), 14, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
        judgementCounterTxt.borderSize = 1.2;
        judgementCounterTxt.scrollFactor.set(0, 0);
        judgementCounterTxt.cameras = [camHUD];
        add(judgementCounterTxt);

        botplayTxt = new FlxText(0, healthBarBG.y + (downscroll ? 58 : -38), FlxG.width, LanguageManager.getString("game.botplay", "BOTPLAY"), 24);
        botplayTxt.setFormat(Paths.font(fontName), 24, 0xFFFFFFFF, CENTER, OUTLINE, FlxColor.BLACK);
        botplayTxt.borderSize = 1.5;
        botplayTxt.scrollFactor.set(0, 0);
        botplayTxt.cameras = [camHUD];
        botplayTxt.visible = botplay;
        add(botplayTxt);

        updateIconPositions();
        updateScoreText();
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
        var cleanSong = curSong.toLowerCase().trim();

        // Core State References
        scripts.setAll("game", this);
        scripts.setAll("state", this);
        scripts.setAll("PlayState", PlayState);
        scripts.setAll("songData", songData);
        scripts.setAll("curSong", curSong);
        scripts.setAll("curDifficulty", curDifficulty);
        scripts.setAll("modFeatureRegistry", ModFeatureRegistry);
        scripts.setAll("modUiSkin", ModFeatureRegistry.activeUiSkin);

        // Audio & Time
        scripts.setAll("audio", audio);
        scripts.setAll("Conductor", Conductor);
        scripts.setAll("curBeat", Conductor.curBeat);
        scripts.setAll("curStep", Conductor.curStep);
        scripts.setAll("songPosition", Conductor.songPosition);
        scripts.setAll("bpm", Conductor.bpm);
        scripts.setAll("stepCrochet", Conductor.stepCrochet);
        scripts.setAll("crochet", Conductor.crochet);

        // Strumlines & Notes
        scripts.setAll("playerStrumline", playerStrumline);
        scripts.setAll("opponentStrumline", opponentStrumline);
        scripts.setAll("playerStrums", playerStrumline != null ? playerStrumline.receptors : null);
        scripts.setAll("opponentStrums", opponentStrumline != null ? opponentStrumline.receptors : null);
        scripts.setAll("notes", notes);
        scripts.setAll("sustainsGroup", sustainsGroup);
        scripts.setAll("unspawnNotes", unspawnNotes);
        scripts.setAll("grpNoteSplashes", grpNoteSplashes);
        scripts.setAll("strumLines", {
            members: [null, opponentStrumline, playerStrumline]
        });
        scripts.setAll("strumlines", {
            members: [null, opponentStrumline, playerStrumline]
        });

        // Characters & Stage
        scripts.setAll("boyfriend", boyfriend);
        scripts.setAll("dad", dad);
        scripts.setAll("gf", gf);
        scripts.setAll("stage", currentStage);
        scripts.setAll("currentStage", currentStage);

        // HUD Elements
        scripts.setAll("healthBar", healthBar);
        scripts.setAll("healthBarBG", healthBarBG);
        scripts.setAll("iconP1", iconP1);
        scripts.setAll("iconP2", iconP2);
        scripts.setAll("scoreTxt", scoreTxt);
        scripts.setAll("timeBar", timeBar);
        scripts.setAll("timeTxt", timeTxt);
        scripts.setAll("botplayTxt", botplayTxt);
        scripts.setAll("judgementManager", judgementManager);

        // Cameras
        scripts.setAll("camGame", camGame);
        scripts.setAll("camHUD", camHUD);
        scripts.setAll("camOther", camOther);
        scripts.setAll("camControls", camControls);
        scripts.setAll("camFollow", camFollow);
        scripts.setAll("camFollowPos", camFollowPos);
        scripts.setAll("defaultCamZoom", defaultCamZoom);
        scripts.setAll("defaultHUDZoom", defaultHUDZoom);

        // Modcharts & VFX
        scripts.setAll("modcharts", modcharts);
        scripts.setAll("ModchartManager", soulscorch.gameplay.modchart.ModchartManager);
        scripts.setAll("PLAYER", soulscorch.gameplay.modchart.ModchartTypes.ModTarget.PLAYER);
        scripts.setAll("OPPONENT", soulscorch.gameplay.modchart.ModchartTypes.ModTarget.OPPONENT);
        scripts.setAll("BOTH", soulscorch.gameplay.modchart.ModchartTypes.ModTarget.BOTH);
        scripts.setAll("ShaderManager", soulscorch.graphics.shaders.ShaderManager.instance);
        scripts.setAll("SoulShader", soulscorch.graphics.shaders.SoulShader);
        scripts.setAll("CustomShader", soulscorch.graphics.shaders.SoulShader);
        scripts.setAll("ShaderFilter", openfl.filters.ShaderFilter);
        scripts.setAll("JuiceManager", soulscorch.graphics.JuiceManager);

        // Flixel Standard
        scripts.setAll("FlxG", flixel.FlxG);
        scripts.setAll("FlxSprite", flixel.FlxSprite);
        scripts.setAll("FlxText", flixel.text.FlxText);
        scripts.setAll("FlxMath", flixel.math.FlxMath);
        scripts.setAll("FlxPoint", {
            get: function(?x:Float = 0, ?y:Float = 0) return flixel.math.FlxPoint.get(x, y),
            weak: function(?x:Float = 0, ?y:Float = 0) return flixel.math.FlxPoint.weak(x, y)
        });
        scripts.setAll("FlxColor", {
            WHITE: flixel.util.FlxColor.WHITE,
            BLACK: flixel.util.FlxColor.BLACK,
            RED: flixel.util.FlxColor.RED,
            GREEN: flixel.util.FlxColor.GREEN,
            BLUE: flixel.util.FlxColor.BLUE,
            CYAN: flixel.util.FlxColor.CYAN,
            MAGENTA: flixel.util.FlxColor.MAGENTA,
            YELLOW: flixel.util.FlxColor.YELLOW,
            TRANSPARENT: flixel.util.FlxColor.TRANSPARENT,
            fromRGB: function(r, g, b, ?a = 255) return flixel.util.FlxColor.fromRGB(r, g, b, a),
            fromString: function(str) return ColorUtil.fromHexSafe(str, flixel.util.FlxColor.WHITE)
        });
        scripts.setAll("FlxTween", flixel.tweens.FlxTween);
        scripts.setAll("FlxEase", flixel.tweens.FlxEase);
        scripts.setAll("FlxTimer", flixel.util.FlxTimer);

        // Backend Utilities
        scripts.setAll("Paths", soulscorch.backend.assets.Paths);
        scripts.setAll("AssetHelper", soulscorch.backend.assets.AssetHelper);
        scripts.setAll("Logger", soulscorch.backend.utils.Logger);
        scripts.setAll("SaveData", SaveData);
        scripts.setAll("Runtime", Runtime);

        // Legacy script compatibility for older FNF/Codename-style song scripts.
        scripts.setAll("members", members);
        scripts.setAll("insert", function(index:Int, obj:FlxBasic) {
            insert(index, obj);
            return obj;
        });
        scripts.setAll("add", function(obj:FlxBasic) {
            add(obj);
            return obj;
        });
        scripts.setAll("remove", function(obj:FlxBasic, ?splice:Bool = false) {
            remove(obj, splice);
            return obj;
        });
        scripts.setAll("inCutscene", true);
        scripts.setAll("graphicCache", {
            cache: function(assetPath:String) {
                if (assetPath == null || assetPath.trim().length == 0) return null;
                return Paths.image(assetPath);
            }
        });

        // Advanced Scripting Helpers
        scripts.setAll("triggerEvent", function(name:String, ?val1:Dynamic = "", ?val2:Dynamic = "") {
            triggerEvent(name, val1, val2);
        });

        scripts.setAll("getGameplayFlag", function(name:String, ?fallback:Dynamic = null) {
            return GameplayFlags.get(name, fallback);
        });

        scripts.setAll("setGameplayFlag", function(name:String, value:Dynamic) {
            return GameplayFlags.set(name, value);
        });

        scripts.setAll("spawnNote", function(time:Float, direction:Int, ?mustPress:Bool = true, ?type:String = "normal", ?sustainLength:Float = 0.0) {
            return queueScriptNote(time, direction, mustPress, type, sustainLength);
        });

        scripts.setAll("queueEvent", function(time:Float, name:String, ?val1:Dynamic = "", ?val2:Dynamic = "") {
            queueScriptEvent(time, name, val1, val2);
        });

        scripts.setAll("setCameraZoom", function(zoom:Float) {
            defaultCamZoom = zoom;
            camGame.zoom = zoom;
        });

        scripts.setAll("bumpCamera", function(?intensity:Float = 0.035, ?hudIntensity:Float = 0.02) {
            JuiceManager.bumpCamera(camGame, intensity, hudIntensity);
        });

        scripts.setAll("addBehindGF", function(obj:FlxBasic) {
            var index = members.indexOf(gf);
            if (index != -1) insert(index, obj); else add(obj);
        });

        scripts.setAll("addBehindBF", function(obj:FlxBasic) {
            var index = members.indexOf(boyfriend);
            if (index != -1) insert(index, obj); else add(obj);
        });

        scripts.setAll("addBehindDad", function(obj:FlxBasic) {
            var index = members.indexOf(dad);
            if (index != -1) insert(index, obj); else add(obj);
        });

        scripts.setAll("resetStrumPositions", function(duration:Float = 0.5) {
            if (playerStrumline != null) {
                for (r in playerStrumline.receptors) {
                    flixel.tweens.FlxTween.tween(r, {x: r.baseX, y: r.baseY, angle: 0, alpha: 1.0}, duration, {ease: flixel.tweens.FlxEase.quadOut});
                }
            }
            if (opponentStrumline != null) {
                for (r in opponentStrumline.receptors) {
                    flixel.tweens.FlxTween.tween(r, {x: r.baseX, y: r.baseY, angle: 0, alpha: opponentStrumline.alpha}, duration, {ease: flixel.tweens.FlxEase.quadOut});
                }
            }
        });

        var scriptPaths = [
            'songs/$cleanSong/script',
            'data/$cleanSong/script',
            'songs/$cleanSong/events',
            'data/$cleanSong/events'
        ];

        for (s in scriptPaths) {
            var scriptExtensions = #if (cpp && LUA_ALLOWED) [".hx", ".lua", ".soul", ".py", ".hscript"] #else [".hx", ".soul", ".lua", ".py", ".hscript"] #end;
            var file = soulscorch.backend.assets.AssetResolver.resolveFile(s, scriptExtensions);
            if (file != null) {
                if (scripts.loadScript(file)) {
                    soulscorch.backend.utils.Logger.info('Loaded song script: $file', "script");
                } else {
                    soulscorch.backend.utils.Logger.error('Failed to load song script: $file', "script");
                }
            }
        }
    }

    private function prepareChartNotes():Void {
        unspawnNotes = [];
        unspawnCursor = 0;
        if (songData == null || songData.chart == null) return;
        var noteSkin = getActiveNoteSkin();

        for (n in songData.chart.notes) {
            var mainNote = new Note(n.time, n.direction, n.sustainLength, null, false, false, n.mustPress, n.type, noteSkin);
            unspawnNotes.push(mainNote);

            if (n.sustainLength > 0) {
                appendSustainTail(mainNote, n.time, n.direction, n.sustainLength, n.mustPress, n.type, noteSkin);
            }
        }

        unspawnNotes.sort(function(a:Note, b:Note):Int {
            return FlxSort.byValues(FlxSort.ASCENDING, a.strumTime, b.strumTime);
        });
        unspawnCursor = 0;
    }

    private function startCountdown():Void {
        startedCountdown = true;
        Conductor.songPosition = -(Conductor.crochet * 5);
        HardwareConductor.start(Conductor.songPosition);

        var countdownIndex:Int = 0;
        var introAssets = ["ready", "set", "go"];
        var introSounds = ["intro3", "intro2", "intro1", "introGo"];

        countdownTimer = new FlxTimer().start(Conductor.crochet / 1000.0, function(tmr:FlxTimer) {
            _intArgCache[0] = countdownIndex;
            scripts.callAll("onCountdownTick", _intArgCache);

            if (countdownIndex < 4) {
                AssetHelper.playSoundSafely(introSounds[countdownIndex], 0.7);

                if (countdownIndex > 0) {
                    var spr = new FlxSprite();
                    var loaded = AssetHelper.loadGraphicSafely(spr, "ui/game/countdown/" + introAssets[countdownIndex - 1]);
                    if (!loaded) AssetHelper.loadGraphicSafely(spr, "ui/countdown/" + introAssets[countdownIndex - 1]);

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

            if (countdownIndex == 4) {
                countdownEnded = true;
                scripts.setAll("inCutscene", false);
                if (audio != null) audio.play();
                scripts.callAll("onSongStart", []);
                #if desktop
                DiscordRPC.updateSongPresence(
                    songData != null ? songData.title : curSong,
                    curDifficulty,
                    songLength,
                    0.0,
                    0.0,
                    songScore,
                    songMisses
                );
                #end
            }

            countdownIndex++;
        }, 5);
    }

    override public function update(elapsed:Float):Void {
        if (paused || isEnding) return;

        _playElapsedArgCache[0] = elapsed;

        if (scripts != null) {
            scripts.callAll("onUpdate", _playElapsedArgCache);
        }

        if (!paused && !isEnding && startedCountdown && Controls.instance != null && !Controls.instance.enabled) {
            Controls.instance.enabled = true;
        }

        audio.update(elapsed);
        ShaderManager.instance.update(elapsed);

        if (passiveHealthDrain > 0 && countdownEnded) {
            if (health > healthDrainFloor) {
                health = Math.max(healthDrainFloor, health - (passiveHealthDrain * elapsed));
            }
        }

        if (health <= 0.0 && !isEnding && !practiceMode && countdownEnded) {
            gameOver();
            return;
        }

        if (countdownEnded && audio != null && audio.isPlaying()) {
            HardwareConductor.update(audio.getPosition(), elapsed);
        } else {
            Conductor.songPosition += elapsed * 1000.0;
        }

        Conductor.update(elapsed);

        if (currentStage != null) currentStage.updateStage(elapsed);
        if (modcharts != null) modcharts.update(elapsed);

        super.update(elapsed);

        captureInput();
        if (pausePressed && allowPause && startedCountdown) {
            openPauseMenu();
            return;
        }

        if (paused || isEnding) return;

        var camLerpRatio:Float = FlxMath.bound(elapsed * 4.0 * cameraSpeed, 0, 1);
        camFollowPos.setPosition(
            FlxMath.lerp(camFollowPos.x, camFollow.x + camDisplaceX, camLerpRatio),
            FlxMath.lerp(camFollowPos.y, camFollow.y + camDisplaceY, camLerpRatio)
        );

        camDisplaceX = FlxMath.lerp(camDisplaceX, 0, FlxMath.bound(elapsed * 5.0, 0, 1));
        camDisplaceY = FlxMath.lerp(camDisplaceY, 0, FlxMath.bound(elapsed * 5.0, 0, 1));

        if (camZooming) {
            var zoomLerpRatio:Float = FlxMath.bound(elapsed * 3.5, 0, 1);
            camGame.zoom = FlxMath.lerp(camGame.zoom, defaultCamZoom, zoomLerpRatio);
            camHUD.zoom = FlxMath.lerp(camHUD.zoom, defaultHUDZoom, zoomLerpRatio);
        }

        updateEvents();
        updateNoteSpawns();
        updateNotePositions();
        handleInput();
        resolveAutomaticNotes();
        updateIconPositions();
        updateTimeBar();

        if (scripts != null) {
            scripts.callAll("onUpdatePost", _playElapsedArgCache);
        }
    }

    private function captureInput():Void {
        if (!paused && !isEnding && startedCountdown && Controls.instance != null && !Controls.instance.enabled) {
            Controls.instance.enabled = true;
        }

        pausePressed = Controls.instance.PAUSE;
        if (ReplayManager.playing || botplay) {
            for (lane in 0...4) {
                keysHeld[lane] = false;
                keysPressed[lane] = false;
                keysReleased[lane] = false;
            }
            return;
        }

        for (lane in 0...4) {
            keysHeld[lane] = Controls.instance.notePressed(lane);
            keysPressed[lane] = Controls.instance.noteJustPressed(lane);
            keysReleased[lane] = Controls.instance.noteJustReleased(lane);
        }
    }

    private function updateEvents():Void {
        while (eventCursor < eventNotes.length && eventNotes[eventCursor].time <= Conductor.songPosition) {
            var event = eventNotes[eventCursor++];
            triggerEvent(event.name, event.val1, event.val2);
        }

        if (eventCursor >= QUEUE_COMPACT_THRESHOLD && eventCursor >= Std.int(eventNotes.length * 0.5)) {
            compactEventQueue();
        }
    }

    private function updateTimeBar():Void {
        if (songLength <= 0) return;

        var curTime = Math.max(0, Conductor.songPosition);
        var curSeconds:Int = Math.floor(curTime / 1000);
        var title = songData != null ? songData.title : curSong;

        if (curSeconds == _lastTimeBarSecond && title == _lastTimeBarTitle) {
            return;
        }

        _lastTimeBarSecond = curSeconds;
        _lastTimeBarTitle = title;

        var totalSeconds = Math.floor(songLength / 1000);

        var curMinutesStr = Std.string(Math.floor(curSeconds / 60));
        var curSecsStr = (curSeconds % 60 < 10 ? "0" : "") + Std.string(curSeconds % 60);

        var totalMinutesStr = Std.string(Math.floor(totalSeconds / 60));
        var totalSecsStr = (totalSeconds % 60 < 10 ? "0" : "") + Std.string(totalSeconds % 60);

        timeTxt.text = '$title ($curMinutesStr:$curSecsStr / $totalMinutesStr:$totalSecsStr)';
    }

    public var songLengthProgress(get, never):Float;
    inline function get_songLengthProgress():Float {
        return songLength > 0 ? Math.min(1.0, Math.max(0.0, Conductor.songPosition / songLength)) : 0.0;
    }

    private function updateNoteSpawns():Void {
        var songPos = Conductor.songPosition;
        var spawnThreshold = 1800 / songSpeed;
        while (unspawnCursor < unspawnNotes.length) {
            var note = unspawnNotes[unspawnCursor];
            if (note == null) {
                unspawnCursor++;
                continue;
            }
            if ((note.strumTime - songPos) >= spawnThreshold) break;

            unspawnCursor++;
            note.cameras = [camHUD];
            if (note.isSustainNote) {
                sustainsGroup.add(note);
            } else {
                notes.add(note);
            }
            scripts.callAll("onNoteSpawn", [note]);
        }

        if (unspawnCursor >= QUEUE_COMPACT_THRESHOLD && unspawnCursor >= Std.int(unspawnNotes.length * 0.5)) {
            compactUnspawnQueue();
        }
    }

    public function queueScriptNote(time:Float, direction:Int, mustPress:Bool = true, type:String = "normal", sustainLength:Float = 0.0):Note {
        if (unspawnCursor > 0) compactUnspawnQueue();

        direction = Std.int(FlxMath.bound(direction, 0, 3));
        sustainLength = Math.max(0.0, sustainLength);

        var noteSkin = getActiveNoteSkin();
        var mainNote = new Note(time, direction, sustainLength, null, false, false, mustPress, type, noteSkin);
        insertNoteSorted(mainNote);

        if (sustainLength > 0) {
            appendSustainTail(mainNote, time, direction, sustainLength, mustPress, type, noteSkin);
        }

        unspawnCursor = 0;
        return mainNote;
    }

    private function insertNoteSorted(note:Note):Void {
        if (note == null) return;
        var low = unspawnCursor;
        var high = unspawnNotes.length;
        while (low < high) {
            var mid = low + ((high - low) >> 1);
            if (unspawnNotes[mid].strumTime <= note.strumTime) low = mid + 1; else high = mid;
        }
        unspawnNotes.insert(low, note);
    }

    private function appendSustainTail(parent:Note, startTime:Float, direction:Int, length:Float, mustPress:Bool, type:String, skin:String):Void {
        var step = Math.max(Conductor.stepCrochet, 1.0);
        var fullSteps = Math.floor(length / step);

        for (index in 1...fullSteps) {
            var body = new Note(startTime + (step * index), direction, length, parent, true, false, mustPress, type, skin);
            parent.tail.push(body);
            insertNoteSorted(body);
        }

        var end = new Note(startTime + length, direction, length, parent, true, true, mustPress, type, skin);
        parent.tail.push(end);
        insertNoteSorted(end);
    }

    public function queueScriptEvent(time:Float, name:String, val1:Dynamic = "", val2:Dynamic = ""):Void {
        insertEventSorted({time: time, name: name, val1: val1, val2: val2});
    }

    private function updateNotePositions():Void {
        if (sustainsGroup != null && sustainsGroup.members != null) {
            var sustainMembers = sustainsGroup.members;
            for (i in 0...sustainMembers.length) {
                var n = sustainMembers[i];
                if (n != null && n.alive && n.exists) {
                    updateSingleNotePosition(n);
                }
            }
        }

        if (notes != null && notes.members != null) {
            var noteMembers = notes.members;
            for (i in 0...noteMembers.length) {
                var n = noteMembers[i];
                if (n != null && n.alive && n.exists) {
                    updateSingleNotePosition(n);
                }
            }
        }
    }

    private inline function updateSingleNotePosition(daNote:Note):Void {
        if (daNote == null || !isValidLane(daNote.noteData)) return;
        var targetStrum = daNote.mustPress ? playerStrumline.receptors[daNote.noteData] : opponentStrumline.receptors[daNote.noteData];
        if (targetStrum == null) return;

        daNote.updatePosition(targetStrum.x, targetStrum.y, songSpeed, downscroll, targetStrum.width);
        daNote.angle = targetStrum.angle;

        if (modcharts != null) {
            modcharts.modifyNote(daNote, daNote.noteData, daNote.mustPress ? PLAYER : OPPONENT, daNote.strumTime);
        }
    }

    private function resolveAutomaticNotes():Void {
        var songPos = Conductor.songPosition;
        var safeZone = Conductor.safeZoneOffset;

        if (sustainsGroup != null && sustainsGroup.members != null) {
            var sustainMembers = sustainsGroup.members;
            for (i in 0...sustainMembers.length) {
                var n = sustainMembers[i];
                if (n != null && n.alive && n.exists) {
                    resolveSingleNote(n, songPos, safeZone);
                }
            }
        }

        if (notes != null && notes.members != null) {
            var noteMembers = notes.members;
            for (i in 0...noteMembers.length) {
                var n = noteMembers[i];
                if (n != null && n.alive && n.exists) {
                    resolveSingleNote(n, songPos, safeZone);
                }
            }
        }
    }

    private inline function resolveSingleNote(daNote:Note, songPos:Float, safeZone:Float):Void {
        if (daNote == null || !isValidLane(daNote.noteData)) {
            removeResolvedNote(daNote);
            return;
        }
        var targetStrum = daNote.mustPress ? playerStrumline.receptors[daNote.noteData] : opponentStrumline.receptors[daNote.noteData];
        if (targetStrum == null) return;

        if (daNote.mustPress && botplay && daNote.strumTime <= songPos) {
            goodNoteHit(daNote, SICK);
            return;
        }

        if (!daNote.mustPress && daNote.strumTime <= songPos) {
            if (scripts.callAllCancelable("onBeforeOpponentNoteHit", [daNote])) {
                targetStrum.playAnim("confirm", true);
                targetStrum.resetAnim = 0.15;

                if (dad != null && daNote.playSingAnim) {
                    dad.playSingAnim(daNote.noteData);
                    setCamDisplacement(daNote.noteData);
                    centerCameraOnDad();
                }

                if (audio != null) audio.muteVocal(false, false);
            }
            scripts.callAll("onOpponentNoteHit", [daNote]);
            removeResolvedNote(daNote);
            return;
        }

        if (daNote.mustPress && !botplay && daNote.strumTime < songPos - safeZone && !daNote.wasGoodHit) {
            noteMiss(daNote.noteData, daNote);
            removeResolvedNote(daNote);
        }
    }

    private function handleInput():Void {
        if (ReplayManager.playing) {
            var replayEvents = ReplayManager.getNextPlaybackEvents();
            for (ev in replayEvents) {
                if (ev.pressed) pressStrum(ev.direction); else releaseStrum(ev.direction);
            }
            return;
        }

        if (botplay) return;

        for (i in 0...4) {
            if (keysPressed[i]) {
                pressStrum(i);
                ReplayManager.recordInput(i, true);
            }
            if (keysReleased[i]) {
                releaseStrum(i);
                ReplayManager.recordInput(i, false);
            }
        }

        processHeldSustains();
    }

    private function processHeldSustains():Void {
        if (!keysHeld[0] && !keysHeld[1] && !keysHeld[2] && !keysHeld[3]) return;

        var hitWindow = Conductor.songPosition + (Conductor.stepCrochet * 0.75);
        if (sustainsGroup == null || sustainsGroup.members == null) return;

        var sustainMembers = sustainsGroup.members;
        for (i in 0...sustainMembers.length) {
            var daNote = sustainMembers[i];
            if (daNote == null || !daNote.alive || !daNote.exists) continue;
            if (!daNote.mustPress || !daNote.isSustainNote || !daNote.canBeHit || daNote.wasGoodHit) continue;

            var lane = daNote.noteData;
            if (lane >= 0 && lane < keysHeld.length && keysHeld[lane] && daNote.strumTime <= hitWindow) {
                goodNoteHit(daNote);
            }
        }
    }

    private function compactUnspawnQueue():Void {
        if (unspawnCursor <= 0) return;
        unspawnNotes = unspawnNotes.slice(unspawnCursor);
        unspawnCursor = 0;
    }

    private function compactEventQueue():Void {
        if (eventCursor <= 0) return;
        eventNotes = eventNotes.slice(eventCursor);
        eventCursor = 0;
    }

    private function insertEventSorted(event:ParsedChartEvent):Void {
        if (event == null) return;

        var low = eventCursor;
        var high = eventNotes.length;
        while (low < high) {
            var mid = low + ((high - low) >> 1);
            if (eventNotes[mid].time <= event.time) low = mid + 1; else high = mid;
        }
        eventNotes.insert(low, event);
    }

    private function loadSongVocals(cleanSong:String):Void {
        if (audio == null) return;

        var playerName = (songData != null && songData.player1 != null && songData.player1.length > 0) ? songData.player1 : "bf";
        var opponentName = (songData != null && songData.player2 != null && songData.player2.length > 0) ? songData.player2 : "dad";

        var playerCandidates = buildVocalStemCandidates(cleanSong, playerName, true);
        var opponentCandidates = buildVocalStemCandidates(cleanSong, opponentName, false);

        for (cand in playerCandidates) {
            if (AssetResolver.resolveFile(cand, [".ogg", ".mp3", ".wav"]) != null) {
                audio.loadVocalStem(cand, true);
                break;
            }
        }

        for (cand in opponentCandidates) {
            if (AssetResolver.resolveFile(cand, [".ogg", ".mp3", ".wav"]) != null) {
                audio.loadVocalStem(cand, false);
                break;
            }
        }
    }

    private function buildVocalStemCandidates(cleanSong:String, characterName:String, isPlayer:Bool):Array<String> {
        var candidates:Array<String> = [];
        var tag = normalizeVocalTag(characterName);

        if (isPlayer) {
            candidates.push('songs/$cleanSong/Voices-Player');
            candidates.push('songs/$cleanSong/Voices-player');
            candidates.push('songs/$cleanSong/Voices-bf');
            candidates.push('songs/$cleanSong/Voices-BF');
            if (tag.length > 0) candidates.push('songs/$cleanSong/Voices-' + tag);
        } else {
            candidates.push('songs/$cleanSong/Voices-Opponent');
            candidates.push('songs/$cleanSong/Voices-opponent');
            candidates.push('songs/$cleanSong/Voices-dad');
            if (tag.length > 0) candidates.push('songs/$cleanSong/Voices-' + tag);
        }

        return candidates;
    }

    private function normalizeVocalTag(raw:String):String {
        if (raw == null) return "";
        var clean = raw.trim().toLowerCase();
        clean = clean.replace(" ", "-");
        clean = clean.replace("_", "-");
        while (clean.contains("--")) clean = clean.replace("--", "-");
        return clean;
    }

    private function pressStrum(dir:Int):Void {
        if (!isValidLane(dir)) return;
        _intArgCache[0] = dir;
        scripts.callAll("onKeyPress", _intArgCache);

        var pStrum = playerStrumline.receptors[dir];
        if (pStrum != null) pStrum.playAnim("pressed");

        var bestNote:Note = null;
        var bestDiff:Float = 9999999.0;
        var nowPos = Conductor.songPosition - noteOffset;

        if (notes != null && notes.members != null) {
            var noteMembers = notes.members;
            for (i in 0...noteMembers.length) {
                var daNote = noteMembers[i];
                if (daNote == null || !daNote.alive || !daNote.exists) continue;
                if (!daNote.mustPress || daNote.noteData != dir || !daNote.canBeHit || daNote.wasGoodHit || daNote.isSustainNote) continue;

                var diff = Math.abs(daNote.strumTime - nowPos);
                if (diff < bestDiff) {
                    bestDiff = diff;
                    bestNote = daNote;
                }
            }
        }

        if (bestNote != null) {
            goodNoteHit(bestNote);
        } else if (!ghostTapping) {
            noteMiss(dir);
        } else {
            _intArgCache[0] = dir;
            scripts.callAll("onGhostTap", _intArgCache);
        }
    }

    private function releaseStrum(dir:Int):Void {
        if (!isValidLane(dir)) return;
        _intArgCache[0] = dir;
        scripts.callAll("onKeyRelease", _intArgCache);

        var pStrum = playerStrumline.receptors[dir];
        if (pStrum != null) pStrum.playAnim("static");
    }

    private function goodNoteHit(note:Note, ?forcedJudgment:Judgment):Void {
        if (note == null || !isValidLane(note.noteData)) return;
        if (!scripts.callAllCancelable("onBeforeNoteHit", [note])) {
            note.wasGoodHit = true;
            note.kill();
            if (note.isSustainNote) sustainsGroup.remove(note, false); else notes.remove(note, false);
            note.destroy();
            return;
        }

        if (note.causesMiss) {
            noteMiss(note.noteData, note);
            note.kill();
            if (note.isSustainNote) sustainsGroup.remove(note, false); else notes.remove(note, false);
            note.destroy();
            return;
        }

        var diff = Math.abs(note.strumTime - (Conductor.songPosition - noteOffset));

        if (!note.isSustainNote) {
            var judgment = forcedJudgment != null ? forcedJudgment : Judgment.fromDifference(diff, Conductor.safeZoneOffset);
            if (judgment == MISS) {
                noteMiss(note.noteData, note);
                removeResolvedNote(note);
                return;
            }

            judgementManager.registerHit(note, judgment, diff, note.hitHealth);
            switch (judgment) {
                case MARVELOUS, SICK: sicks++;
                case GOOD: goods++;
                case BAD: bads++;
                case SHIT: shits++;
                case MISS:
            }
            syncJudgementState();
            if (combo > maxCombo) maxCombo = combo;

            if (Judgment.triggersSplash(judgment) && noteSplashEnabled && note.noteSplashes && playerStrumline.receptors[note.noteData] != null) {
                spawnSplash(playerStrumline.receptors[note.noteData].x, playerStrumline.receptors[note.noteData].y, note.noteData);
            }
        } else {
            note.wasGoodHit = true;
            judgementManager.score += 20;
            health = Math.min(maxHealth, health + (note.isSustainNote ? 0.0125 : note.hitHealth));
            syncJudgementState();
        }

        if (audio != null) audio.muteVocal(true, false);

        var pStrum = playerStrumline.receptors[note.noteData];
        if (pStrum != null) {
            pStrum.playAnim("confirm", true);
            pStrum.resetAnim = 0.15;
        }

        if (boyfriend != null && note.playSingAnim) {
            boyfriend.playSingAnim(note.noteData);
            setCamDisplacement(note.noteData);
            centerCameraOnBF();
        }

        updateScoreText();
        scripts.callAll("onNoteHit", [note]);

        removeResolvedNote(note);
    }

    private function spawnSplash(x:Float, y:Float, dir:Int):Void {
        if (!noteSplashEnabled) return;
        if (grpNoteSplashes != null && grpNoteSplashes.countLiving() >= splashMaxConcurrent) return;

        var splash:NoteSplash = grpNoteSplashes.recycle(NoteSplash);
        var splashSkin = GameplayFlags.getString("defaultSplashSkin", "default");
        if (splash.splashSkin != splashSkin) splash.loadSplashSkin(splashSkin);
        splash.spawnSplash(x, y, dir);
        grpNoteSplashes.add(splash);
    }

    private function noteMiss(dir:Int, ?note:Note):Void {
        if (!isValidLane(dir)) return;
        _intArgCache[0] = dir;
        if (!scripts.callAllCancelable("onBeforePlayerMiss", _intArgCache)) return;

        var penalty = note != null ? note.missHealth : GameplayFlags.getFloat("missPenalty", 0.085);
        judgementManager.registerMiss(note, penalty);
        syncJudgementState();

        if (audio != null) audio.muteVocal(true, true);

        if (boyfriend != null) {
            boyfriend.playSingAnim(dir, true);
            setCamDisplacement(dir);
            centerCameraOnBF();
        }

        updateScoreText();
        _intArgCache[0] = dir;
        scripts.callAll("onPlayerMiss", _intArgCache);
    }

    private function syncJudgementState():Void {
        songScore = judgementManager.score;
        songMisses = judgementManager.misses;
        songHits = judgementManager.totalNotesHit;
        combo = judgementManager.combo;
        totalNotesPassed = judgementManager.totalNotesJudged;
        totalAccuracyScore = judgementManager.totalWeight;
        accuracy = judgementManager.accuracy;
    }

    private function removeResolvedNote(note:Note):Void {
        if (note == null) return;
        note.kill();
        if (note.isSustainNote) sustainsGroup.remove(note, false); else notes.remove(note, false);
        note.destroy();
    }

    private function setCamDisplacement(dir:Int):Void {
        switch (dir) {
            case 0: camDisplaceX = -camDisplaceOffset; camDisplaceY = 0;
            case 1: camDisplaceX = 0; camDisplaceY = camDisplaceOffset;
            case 2: camDisplaceX = 0; camDisplaceY = -camDisplaceOffset;
            case 3: camDisplaceX = camDisplaceOffset; camDisplaceY = 0;
        }
    }

    private function updateScoreText():Void {
        var acc = totalNotesPassed > 0 ? (Math.round(accuracy * 100) / 100) : 0.0;
        var rank = getRatingString(acc);
        
        var scoreFormat = LanguageManager.getString("game.scoreHUD", "Score: {0} | Misses: {1} | Accuracy: {2}% [{3}]", [songScore, songMisses, acc, rank]);
        scoreTxt.text = scoreFormat;

        if (judgementCounterTxt != null) {
            judgementCounterTxt.text = 'Sicks: $sicks\nGoods: $goods\nBads: $bads\nShits: $shits\nCombo: $combo (Max: $maxCombo)';
        }
    }

    private function getRatingString(acc:Float):String {
        if (totalNotesPassed == 0) return "?";
        if (songMisses == 0) {
            if (acc >= 100.0) return "SFC";
            if (acc >= 90.0) return "GFC";
            return "FC";
        }
        if (acc >= 85.0) return "SDC";
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

    private inline function centerCameraOnBF():Void {
        if (boyfriend != null) {
            camFollow.setPosition(boyfriend.getMidpoint().x - 100 + boyfriend.cameraOffset[0], boyfriend.getMidpoint().y - 100 + boyfriend.cameraOffset[1]);
        }
    }

    private inline function centerCameraOnDad():Void {
        if (dad != null) {
            camFollow.setPosition(dad.getMidpoint().x + 150 + dad.cameraOffset[0], dad.getMidpoint().y - 100 + dad.cameraOffset[1]);
        }
    }

    override public function beatHit(beat:Int):Void {
        super.beatHit(beat);

        if (cameraZoomOnBeat && cameraZoomBeatInterval > 0
            && beat % cameraZoomBeatInterval == cameraZoomBeatOffset % cameraZoomBeatInterval) {
            camGame.zoom += 0.015;
            camHUD.zoom += 0.03;
        }

        if (iconP1 != null) {
            iconP1.scale.set(1.2, 1.2);
            FlxTween.cancelTweensOf(iconP1.scale);
            FlxTween.tween(iconP1.scale, {x: 1.0, y: 1.0}, 0.15, {ease: FlxEase.quadOut});
            iconP1.beatHit(beat);
        }

        if (iconP2 != null) {
            iconP2.scale.set(1.2, 1.2);
            FlxTween.cancelTweensOf(iconP2.scale);
            FlxTween.tween(iconP2.scale, {x: 1.0, y: 1.0}, 0.15, {ease: FlxEase.quadOut});
            iconP2.beatHit(beat);
        }

        if (currentStage != null) currentStage.beatHit(beat);
        if (gf != null && beat % 2 == 0) gf.dance();

        var holdingNote = keysHeld.contains(true);
        if (dad != null && (dad.animation.curAnim == null || dad.animation.curAnim.name.startsWith("idle"))) dad.dance();
        if (boyfriend != null && !holdingNote && (boyfriend.animation.curAnim == null || boyfriend.animation.curAnim.name.startsWith("idle"))) boyfriend.dance();

        _intArgCache[0] = beat;
        scripts.callAll("onBeatHit", _intArgCache);
        scripts.callAll("beatHit", _intArgCache);
    }

    override public function stepHit(step:Int):Void {
        super.stepHit(step);

        if (songData != null) {
            var secArray:Array<Dynamic> = null;
            if (Reflect.hasField(songData, "notes")) secArray = cast Reflect.field(songData, "notes");
            else if (Reflect.hasField(songData, "sections")) secArray = cast Reflect.field(songData, "sections");

            if (secArray != null && secArray.length > 0) {
                var curSecIdx = Math.floor(step / 16);
                if (curSecIdx >= 0 && curSecIdx < secArray.length && secArray[curSecIdx] != null) {
                    var secObj:Dynamic = secArray[curSecIdx];
                    var isBfFocus:Bool = Reflect.hasField(secObj, "mustHitSection") ? Reflect.field(secObj, "mustHitSection") == true : (Reflect.hasField(secObj, "mustHit") ? Reflect.field(secObj, "mustHit") == true : false);

                    if (curSecIdx != lastScriptSection) {
                        lastScriptSection = curSecIdx;
                        scripts.callAll("onSectionChange", [curSecIdx, isBfFocus]);
                    }

                    if (isBfFocus != mustHitSection) {
                        mustHitSection = isBfFocus;
                        if (mustHitSection) centerCameraOnBF(); else centerCameraOnDad();
                    }
                }
            }
        }

        if (currentStage != null) currentStage.stepHit(step);
        _intArgCache[0] = step;
        scripts.callAll("onStepHit", _intArgCache);
        scripts.callAll("stepHit", _intArgCache);
    }

    public function triggerEvent(name:String, val1:Dynamic, val2:Dynamic):Void {
        var macroSteps = ModFeatureRegistry.getEventMacro(name);
        if (macroSteps != null && macroSteps.length > 0) {
            for (step in macroSteps) {
                var outV1 = (step.val1 != null && Std.string(step.val1).length > 0) ? step.val1 : val1;
                var outV2 = (step.val2 != null && Std.string(step.val2).length > 0) ? step.val2 : val2;
                queueScriptEvent(Conductor.songPosition + step.delay, step.name, outV1, outV2);
            }
            scripts.callAll("onEvent", [name, val1, val2]);
            return;
        }

        var strV1 = Std.string(val1);
        var strV2 = Std.string(val2);

        if (scripts.callAllCancelable("onBeforeEvent", [name, val1, val2])) switch (name) {
            case "Camera Flash":
                var targetCam = (strV1.toLowerCase() == "hud" || strV1.toLowerCase() == "camhud") ? camHUD : camGame;
                var dur = Std.parseFloat(strV2);
                targetCam.flash(0xFFFFFFFF, Math.isNaN(dur) || dur <= 0 ? 0.8 : dur);

            case "Camera Bop":
                var intensity = Std.parseFloat(strV1);
                var hudIntensity = Std.parseFloat(strV2);
                JuiceManager.bumpCamera(camGame, Math.isNaN(intensity) ? 0.04 : intensity, Math.isNaN(hudIntensity) ? 0.02 : hudIntensity);

            case "Camera Modulo Change":
                var interval = Std.parseInt(strV1);
                var offset = Std.parseInt(strV2);
                if (interval != null && interval > 0) cameraZoomBeatInterval = interval;
                cameraZoomBeatOffset = offset != null ? offset : 0;

            case "Camera Zoom" | "Set Cam Zoom":
                var zoom = Std.parseFloat(strV1);
                if (!Math.isNaN(zoom)) defaultCamZoom = zoom;

            case "Screen Shake":
                var intensity = Std.parseFloat(strV1);
                var duration = Std.parseFloat(strV2);
                JuiceManager.shake(camGame, Math.isNaN(intensity) ? 0.01 : intensity, Math.isNaN(duration) ? 0.2 : duration);

            case "Camera Movement":
                if (strV1 == "0" || strV1 == "dad" || strV1 == "opponent") centerCameraOnDad();
                else if (strV1 == "1" || strV1 == "bf" || strV1 == "boyfriend") centerCameraOnBF();

            case "Alt Animation Toggle":
                var enabled = (val1 == true || strV1 == "true" || strV1 == "1");
                if (dad != null) dad.altAnim = enabled;

            case "Change Character":
                var targetType = strV1.toLowerCase().trim();
                var newCharName = strV2.trim();
                if (targetType == "dad" || targetType == "opponent") {
                    dad.curCharacter = newCharName;
                    dad.loadCharacter();
                    iconP2.changeIcon(dad.healthIcon);
                    if (healthBar != null) healthBar.createFilledBar(dad.healthColor, boyfriend.healthColor);
                } else if (targetType == "bf" || targetType == "boyfriend" || targetType == "player") {
                    boyfriend.curCharacter = newCharName;
                    boyfriend.loadCharacter();
                    iconP1.changeIcon(boyfriend.healthIcon);
                    if (healthBar != null) healthBar.createFilledBar(dad.healthColor, boyfriend.healthColor);
                }

            case "Set Noteskin" | "Change Noteskin":
                applyRuntimeNoteSkin(strV1);

            case "Set Judge Profile" | "Change Judge Profile":
                if (judgementManager != null) {
                    judgementManager.applyModJudgmentProfile(strV1);
                }
        }
        scripts.callAll("onEvent", [name, val1, val2]);
    }

    public function openPauseMenu():Void {
        if (!scripts.callAllCancelable("onBeforePause", [])) return;

        paused = true;
        if (audio != null) audio.pause();
        scripts.callAll("onPause", []);
        DiscordRPC.updateSongPresence(songData != null ? songData.title : curSong, curDifficulty, songLength, Conductor.songPosition, accuracy, songScore, songMisses, true);
        openSubState(new PauseSubState());
    }

    public function resumeSong():Void {
        if (paused) {
            paused = false;
            Controls.instance.enabled = true;
            InputMap.claimKeyboardFocus();
            keysHeld = [false, false, false, false];
            keysPressed = [false, false, false, false];
            keysReleased = [false, false, false, false];
            if (audio != null) audio.resume();
            scripts.callAll("onResume", []);
        }
    }

    public function gameOver():Void {
        if (!scripts.callAllCancelable("onBeforeGameOver", [])) return;

        isEnding = true;
        paused = true;
        if (audio != null) audio.stop();
        scripts.callAll("onGameOver", []);
        
        var bfX:Float = (boyfriend != null) ? boyfriend.x : 100;
        var bfY:Float = (boyfriend != null) ? boyfriend.y : 100;
        openSubState(new GameOverSubState(bfX, bfY));
    }

    private function onSongFinished():Void {
        if (paused || isEnding) return;
        endSong();
    }

    public function endSong():Void {
        if (isEnding) return;
        isEnding = true;
        paused = true;

        if (audio != null) audio.stop();

        var cleared = health > 0;
        var rank = getRatingString(accuracy);

        if (ReplayManager.recording) {
            ReplayManager.saveReplay(curSong, curDifficulty, songScore, accuracy, songMisses, rank);
        }

        var stats = new SongStats(curSong, curDifficulty, songScore, songMisses, songHits, accuracy, health, maxHealth, cleared);

        if (SaveData.instance != null) {
            SaveData.instance.submitScore(curSong, curDifficulty, stats.toSaveEntry());
        }

        scripts.callAll("onSongEnd", [stats]);
        MusicBeatState.switchState(new ResultsState(stats));
    }

    override public function destroy():Void {
        if (instance == this) instance = null;
        Controls.instance.unbindMobilePad();
        if (ReplayManager.playing) ReplayManager.stopPlayback();
        if (countdownTimer != null) countdownTimer.cancel();
        if (scripts != null) {
            scripts.callAll("onDestroy", []);
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