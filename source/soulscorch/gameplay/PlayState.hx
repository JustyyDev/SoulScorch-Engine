package soulscorch.gameplay;

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
import soulscorch.backend.input.MobilePad;
import soulscorch.backend.system.SaveData;
import soulscorch.backend.system.XMSoul;
import soulscorch.backend.system.engine.Runtime;
import soulscorch.backend.system.modules.discord.DiscordRPC;
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
import soulscorch.scripting.ScriptManager;
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
    public var camControls:FlxCamera;
    public var defaultHUDZoom:Float = 1.0;
    public var camFollow:FlxObject;
    public var camFollowPos:FlxObject;
    public var camZooming:Bool = true;
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
    public var unspawnNotes:Array<Note> = [];
    public var eventNotes:Array<ParsedChartEvent> = [];

    // --- HUD & Score Stats ---
    public var health(get, set):Float;
    inline function get_health():Float return judgementManager != null ? judgementManager.health : 1.0;
    inline function set_health(val:Float):Float {
        if (judgementManager != null) judgementManager.health = Math.max(0.0, Math.min(maxHealth, val));
        return val;
    }

    public var maxHealth:Float = 2.0;
    public var songScore(get, never):Int;
    inline function get_songScore():Int return judgementManager != null ? judgementManager.combo * 100 : 0;
    public var songMisses(get, never):Int;
    inline function get_songMisses():Int return judgementManager != null ? judgementManager.misses : 0;
    public var songHits(get, never):Int;
    inline function get_songHits():Int return judgementManager != null ? judgementManager.totalNotesHit : 0;
    public var combo(get, never):Int;
    inline function get_combo():Int return judgementManager != null ? judgementManager.combo : 0;
    public var accuracy(get, never):Float;
    inline function get_accuracy():Float return judgementManager != null ? judgementManager.accuracy : 0.0;

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
    public var cameraZoomOnBeat:Bool = true;
    public var allowPause:Bool = true;
    public var noteSplashEnabled:Bool = true;
    public var noteOffset:Float = 0.0;
    public var mustHitSection:Bool = false;
    public var passiveHealthDrain:Float = 0.0;

    private var keysHeld:Array<Bool> = [false, false, false, false];
    private var countdownTimer:FlxTimer;
    private var hudConfig:Access = null;

    public function new(?songId:String, ?difficulty:String) {
        super();
        if (songId != null && songId != "") curSong = songId;
        if (difficulty != null && difficulty != "") curDifficulty = difficulty;
    }

    override public function create():Void {
        super.create();
        instance = this;
        defaultCamZoom = 0.9;

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
        loadSongModifiers(curSong);
        loadExternalEvents(curSong);
        spawnStageAndCharacters();
        generateStrumLines();

        add(currentStage);
        add(opponentStrumline);
        add(playerStrumline);
        add(grpNoteSplashes);
        add(notes);
        add(judgementManager);

        setupHUD();
        setupMobileControls();
        setupScriptRuntime();

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
    }

    private function loadSongModifiers(songId:String):Void {
        var clean = songId.toLowerCase().trim();
        var paths = [
            'songs/$clean/modifiers.xmsoul',
            'data/$clean/modifiers.xmsoul',
            'assets/preload/songs/$clean/modifiers.xmsoul'
        ];

        for (p in paths) {
            var access = XMSoul.parse(p);
            if (access != null) {
                try {
                    songSpeed *= XMSoul.getFloatAttr(access, "scrollSpeedMultiplier", 1.0);
                    ghostTapping = XMSoul.getBoolAttr(access, "ghostTapping", ghostTapping);
                    passiveHealthDrain = XMSoul.getFloatAttr(access, "healthDrain", 0.0);
                    maxHealth = XMSoul.getFloatAttr(access, "maxHealth", maxHealth);
                    Logger.info('Successfully loaded .xmsoul modifiers for $clean', "modifiers");
                    break;
                } catch (e:Dynamic) {
                    Logger.warn('Failed parsing modifiers.xmsoul for $clean: $e', "modifiers");
                }
            }
        }
    }

    override public function setupCameras():Void {
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

        judgementManager = new JudgementManager(camHUD);
        judgementManager.onHealthChange = function(newHealth:Float) {
            if (newHealth <= 0 && !isEnding) gameOver();
            updateScoreText();
        };

        grpNoteSplashes = new FlxTypedGroup<NoteSplash>();
        notes = new FlxTypedGroup<Note>();

        grpNoteSplashes.cameras = [camHUD];
        notes.cameras = [camHUD];
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
            var bfVocals = 'songs/$clean/Voices-bf';
            var oppVocals = 'songs/$clean/Voices-puff';
            if (AssetResolver.resolveFile(bfVocals, [".ogg", ".mp3"]) != null) {
                audio.loadVocalStem(bfVocals, true);
            }
            if (AssetResolver.resolveFile(oppVocals, [".ogg", ".mp3"]) != null) {
                audio.loadVocalStem(oppVocals, false);
            }

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
                    } catch (e:Dynamic) {
                        Logger.warn('Failed parsing events.json for $cleanSong: $e', "events");
                    }
                }
            }
        }

        eventNotes.sort(function(a:ParsedChartEvent, b:ParsedChartEvent):Int {
            return (a.time < b.time) ? -1 : 1;
        });
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
            var resolved = AssetResolver.resolveFile(p, [".hx", ".soul"]);
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

        centerCameraOnDad();
        camFollowPos.setPosition(camFollow.x, camFollow.y);
        camGame.zoom = defaultCamZoom;
        camGame.focusOn(camFollow.getPosition());
    }

    private function generateStrumLines():Void {
        var strumY:Float = downscroll ? FlxG.height - 155 : 50;
        var noteSkinToUse:String = NoteSkinManager.getNoteSkinName();

        if (Runtime.config != null && Runtime.config.defaultNoteSkin != null && Runtime.config.defaultNoteSkin != "default") {
            noteSkinToUse = Runtime.config.defaultNoteSkin;
        }

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

        if (NoteSkinManager.getSkinAtlas(noteSkinToUse) != null) {
            NoteSkinManager.applySkin(playerStrumline, noteSkinToUse);
            NoteSkinManager.applySkin(opponentStrumline, noteSkinToUse);
        }

        modcharts = new ModchartManager(playerStrumline, opponentStrumline);
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

        scoreTxt = new FlxText(0, healthBarBG.y + scoreYOffset, FlxG.width, "Score: 0 | Misses: 0 | Accuracy: 0% [?]", scoreFontSize);
        scoreTxt.setFormat(Paths.font(fontName), scoreFontSize, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        scoreTxt.borderSize = 1.5;
        scoreTxt.scrollFactor.set(0, 0);
        scoreTxt.cameras = [camHUD];
        add(scoreTxt);

        botplayTxt = new FlxText(0, healthBarBG.y + (downscroll ? 58 : -38), FlxG.width, "BOTPLAY", 24);
        botplayTxt.setFormat(Paths.font(fontName), 24, 0xFFFFCC00, CENTER, OUTLINE, FlxColor.BLACK);
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
        var singleScripts = [
            'songs/$curSong/script',
            'data/$curSong/script',
            'songs/$curSong/events',
            'data/$curSong/events'
        ];

        for (s in singleScripts) {
            var file = AssetResolver.resolveFile(s, [".hx", ".soul", ".lua", ".py", ".js"]);
            if (file != null) scripts.loadScript(file);
        }

        #if sys
        var scriptDirs = [
            'songs/$curSong/scripts',
            'data/$curSong/scripts',
            'assets/preload/songs/$curSong/scripts'
        ];

        for (d in scriptDirs) {
            if (FileSystem.exists(d) && FileSystem.isDirectory(d)) {
                for (f in FileSystem.readDirectory(d)) {
                    if (f.endsWith(".hx") || f.endsWith(".soul") || f.endsWith(".lua") || f.endsWith(".py") || f.endsWith(".js")) {
                        scripts.loadScript('$d/$f');
                    }
                }
            }
        }
        #end

        scripts.setAll("game", this);
        scripts.setAll("audio", audio);
        scripts.setAll("modcharts", modcharts);
        scripts.setAll("boyfriend", boyfriend);
        scripts.setAll("dad", dad);
        scripts.setAll("gf", gf);
        scripts.setAll("stage", currentStage);
        scripts.setAll("camGame", camGame);
        scripts.setAll("camHUD", camHUD);
        scripts.setAll("camOther", camOther);

        scripts.callAll("onCreate");
    }

    private function prepareChartNotes():Void {
        unspawnNotes = [];
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
                if (audio != null) audio.play();
                scripts.callAll("onSongStart", []);
                #if desktop
                DiscordRPC.updateSongPresence(
                    songData != null ? songData.title : curSong,
                    curDifficulty,
                    songLength,
                    0.0,
                    0.0,
                    0,
                    songMisses
                );
                #end
            }

            countdownIndex++;
        }, 5);
    }

    override public function update(elapsed:Float):Void {
        if (paused || isEnding) return;

        if (scripts != null) {
            scripts.setAll("curBeat", Conductor.curBeat);
            scripts.setAll("curStep", Conductor.curStep);
            scripts.setAll("songPosition", Conductor.songPosition);
            scripts.callAll("onUpdate", [elapsed]);
        }

        audio.update(elapsed);
        ShaderManager.instance.update(elapsed);

        if (passiveHealthDrain > 0 && countdownEnded) {
            health = Math.max(0.0, health - (passiveHealthDrain * elapsed));
            if (health <= 0) gameOver();
        }

        if (countdownEnded && audio != null && audio.inst != null && audio.inst.playing) {
            var audioTime:Float = audio.inst.time;
            if (Math.abs(Conductor.songPosition - audioTime) > 35.0) {
                Conductor.songPosition = audioTime;
            } else {
                Conductor.songPosition = FlxMath.lerp(Conductor.songPosition, audioTime, FlxMath.bound(elapsed * 25.0, 0, 1));
            }
        } else {
            Conductor.songPosition += elapsed * 1000.0;
        }

        Conductor.update(elapsed);

        if (currentStage != null) currentStage.updateStage(elapsed);
        if (modcharts != null) modcharts.update(elapsed);

        super.update(elapsed);

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
        handleInput(elapsed);
        updateNotePositions();
        updateIconPositions();
        updateTimeBar();

        if (Controls.instance.PAUSE && allowPause && countdownEnded) {
            openPauseMenu();
        }

        if (scripts != null) {
            scripts.callAll("onUpdatePost", [elapsed]);
        }
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

                if ((!daNote.mustPress || botplay) && daNote.strumTime <= Conductor.songPosition) {
                    if (daNote.mustPress) {
                        goodNoteHit(daNote);
                    } else {
                        targetStrum.playAnim("confirm", true);
                        targetStrum.resetAnim = 0.15;

                        if (dad != null && daNote.playSingAnim) {
                            dad.playSingAnim(daNote.noteData);
                            setCamDisplacement(daNote.noteData);
                            centerCameraOnDad();
                        }

                        if (audio != null) audio.muteVocal(false, false);
                        scripts.callAll("onOpponentHit", [daNote]);
                        daNote.kill();
                        notes.remove(daNote, false);
                        daNote.destroy();
                    }
                    return;
                }
            }

            if (daNote.mustPress && !botplay && daNote.strumTime < Conductor.songPosition - Conductor.safeZoneOffset && !daNote.wasGoodHit) {
                daNote.tooLate = true;
                noteMiss(daNote.noteData);
                daNote.kill();
                notes.remove(daNote, false);
                daNote.destroy();
            }
        });
    }

    private function handleInput(elapsed:Float):Void {
        if (ReplayManager.playing) {
            var replayEvents = ReplayManager.getNextPlaybackEvents();
            for (ev in replayEvents) {
                if (ev.pressed) pressStrum(ev.direction); else releaseStrum(ev.direction);
            }
            return;
        }

        if (botplay) return;

        var keyPressed:Array<Bool> = [
            FlxG.keys.pressed.LEFT || FlxG.keys.pressed.A || Controls.instance.notePressed(0),
            FlxG.keys.pressed.DOWN || FlxG.keys.pressed.S || Controls.instance.notePressed(1),
            FlxG.keys.pressed.UP || FlxG.keys.pressed.W || Controls.instance.notePressed(2),
            FlxG.keys.pressed.RIGHT || FlxG.keys.pressed.D || Controls.instance.notePressed(3)
        ];

        var keyJustPressed:Array<Bool> = [
            FlxG.keys.justPressed.LEFT || FlxG.keys.justPressed.A || Controls.instance.noteJustPressed(0),
            FlxG.keys.justPressed.DOWN || FlxG.keys.justPressed.S || Controls.instance.noteJustPressed(1),
            FlxG.keys.justPressed.UP || FlxG.keys.justPressed.W || Controls.instance.noteJustPressed(2),
            FlxG.keys.justPressed.RIGHT || FlxG.keys.justPressed.D || Controls.instance.noteJustPressed(3)
        ];

        var keyJustReleased:Array<Bool> = [
            FlxG.keys.justReleased.LEFT || FlxG.keys.justReleased.A || Controls.instance.noteJustReleased(0),
            FlxG.keys.justReleased.DOWN || FlxG.keys.justReleased.S || Controls.instance.noteJustReleased(1),
            FlxG.keys.justReleased.UP || FlxG.keys.justReleased.W || Controls.instance.noteJustReleased(2),
            FlxG.keys.justReleased.RIGHT || FlxG.keys.justReleased.D || Controls.instance.noteJustReleased(3)
        ];

        for (i in 0...4) {
            keysHeld[i] = keyPressed[i];

            if (keyJustPressed[i]) {
                pressStrum(i);
                ReplayManager.recordInput(i, true);
            }
            if (keyJustReleased[i]) {
                releaseStrum(i);
                ReplayManager.recordInput(i, false);
            }

            if (keysHeld[i]) {
                notes.forEachAlive(function(daNote:Note) {
                    if (daNote.mustPress && daNote.noteData == i && daNote.isSustainNote && daNote.canBeHit && !daNote.wasGoodHit) {
                        if (daNote.strumTime <= Conductor.songPosition + (Conductor.stepCrochet * 0.75)) {
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

        if (note.causesMiss) {
            judgementManager.miss(note);
            note.kill();
            notes.remove(note, false);
            note.destroy();
            return;
        }

        var diff:Float = Math.abs(note.strumTime - (Conductor.songPosition - noteOffset));
        var result:Judgment = judgementManager.judge(note, Conductor.songPosition - noteOffset);

        if (!note.isSustainNote) {
            if (Judgment.triggersSplash(result) && noteSplashEnabled && note.noteSplashes && playerStrumline.receptors[note.noteData] != null) {
                spawnSplash(playerStrumline.receptors[note.noteData].x, playerStrumline.receptors[note.noteData].y, note.noteData);
            }
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

        note.kill();
        notes.remove(note, false);
        note.destroy();
    }

    private function spawnSplash(x:Float, y:Float, dir:Int):Void {
        var splash:NoteSplash = grpNoteSplashes.recycle(NoteSplash);
        splash.spawn(x, y, dir);
        grpNoteSplashes.add(splash);
    }

    private function noteMiss(dir:Int):Void {
        judgementManager.miss(null);
        if (audio != null) audio.muteVocal(true, true);

        if (boyfriend != null) {
            boyfriend.playSingAnim(dir, true);
            setCamDisplacement(dir);
            centerCameraOnBF();
        }

        updateScoreText();
        scripts.callAll("onPlayerMiss", [dir]);
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
        var acc = Math.round(accuracy * 100) / 100;
        var rank = getRatingString(accuracy);
        scoreTxt.text = 'Score: $songScore | Misses: $songMisses | Accuracy: $acc% [$rank]';
    }

    private function getRatingString(acc:Float):String {
        if (songHits == 0 && songMisses == 0) return "?";
        if (songMisses == 0) {
            if (acc >= 100.0) return "SFC";
            if (acc >= 90.0) return "GFC";
            return "FC";
        }
        if (acc >= 80.0) return "SDC";
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

        if (cameraZoomOnBeat && beat % 4 == 0) {
            JuiceManager.bumpCamera(camGame, 0.035, 0.02);
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

        scripts.callAll("onBeatHit", [beat]);
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

                    if (isBfFocus != mustHitSection) {
                        mustHitSection = isBfFocus;
                        if (mustHitSection) centerCameraOnBF(); else centerCameraOnDad();
                    }
                }
            }
        }

        if (currentStage != null) currentStage.stepHit(step);
        scripts.callAll("onStepHit", [step]);
    }

    public function triggerEvent(name:String, val1:Dynamic, val2:Dynamic):Void {
        var strV1 = Std.string(val1);
        var strV2 = Std.string(val2);

        switch (name) {
            case "Camera Zoom" | "Set Cam Zoom":
                var zoom = Std.parseFloat(strV1);
                if (!Math.isNaN(zoom)) defaultCamZoom = zoom;

            case "Screen Shake":
                var intensity = Std.parseFloat(strV1);
                var duration = Std.parseFloat(strV2);
                JuiceManager.shake(camGame, Math.isNaN(intensity) ? 0.01 : intensity, Math.isNaN(duration) ? 0.2 : duration);

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
        }
        scripts.callAll("onEvent", [name, val1, val2]);
    }

    public function openPauseMenu():Void {
        paused = true;
        if (audio != null) audio.pause();
        scripts.callAll("onPause", []);
        openSubState(new PauseSubState());
    }

    public function resumeSong():Void {
        if (paused) {
            paused = false;
            if (audio != null) audio.resume();
            scripts.callAll("onResume", []);
        }
    }

    public function gameOver():Void {
        paused = true;
        if (audio != null) audio.stop();
        scripts.callAll("onGameOver", []);
        openSubState(new GameOverSubState(boyfriend != null ? boyfriend.x : 100, boyfriend != null ? boyfriend.y : 100));
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