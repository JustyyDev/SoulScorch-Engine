package soulscorch.gameplay;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.ui.FlxBar;
import flixel.util.FlxColor;
import flixel.util.FlxSort;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;

import soulscorch.core.Scene;
import soulscorch.assets.AssetHelper;
import soulscorch.assets.AssetResolver;
import soulscorch.input.InputMap;
import soulscorch.modding.ModLoader;
import soulscorch.modding.ScriptManager;
import soulscorch.gameplay.modchart.ModchartManager;
import soulscorch.ui.ScriptedSubState;

class PlayState extends Scene {
    public static var instance:PlayState;
    public static var curSong:String = "bopeebo";
    public static var curDifficulty:String = "normal";

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
    public var startedCountdown:Bool = false;

    override public function create():Void {
        super.create();
        instance = this;

        // Multi-Camera Setup
        camGame = new FlxCamera();
        camHUD = new FlxCamera();
        camHUD.bgColor.alpha = 0;

        FlxG.cameras.reset(camGame);
        FlxG.cameras.add(camHUD, false);
        FlxG.cameras.setDefaultDrawTarget(camGame, true);

        // Core Systems Initialization
        audio = new AudioManager();
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

        generateStrumLines();
        loadSong(curSong, curDifficulty);

        add(opponentStrums);
        add(playerStrums);
        add(grpNoteSplashes);
        add(notes);

        setupHUD();

        // Load Mod Scripts
        scripts.loadScriptsFromDir("assets/data/scripts");
        scripts.loadScript('assets/data/songs/$curSong/script.hx');

        scripts.set("game", this);
        scripts.set("audio", audio);
        scripts.set("modcharts", modcharts);
        scripts.set("Conductor", Conductor);
        scripts.set("playerStrums", playerStrums);
        scripts.set("opponentStrums", opponentStrums);

        scripts.call("create");
        scripts.call("onCreate");

        startCountdown();
    }

    function generateStrumLines():Void {
        for (i in 0...4) {
            var opp = new StrumArrow(100 + (i * 140), 50, i, 0);
            opponentStrums.add(opp);

            var ply = new StrumArrow(720 + (i * 140), 50, i, 1);
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
        add(healthBarBG);

        healthBar = new FlxBar(healthBarBG.x + 4, healthBarBG.y + 4, RIGHT_TO_LEFT, Std.int(healthBarBG.width - 8), Std.int(healthBarBG.height - 8), this, 'health', 0, 2);
        healthBar.createFilledBar(0xFFFF0000, 0xFF66FF33);
        healthBar.scrollFactor.set();
        healthBar.cameras = [camHUD];
        add(healthBar);

        scoreTxt = new FlxText(0, healthBarBG.y + 36, FlxG.width, "Score: 0 | Misses: 0 | Accuracy: 0%", 20);
        scoreTxt.setFormat("_sans", 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        scoreTxt.scrollFactor.set();
        scoreTxt.cameras = [camHUD];
        add(scoreTxt);
    }

    function loadSong(songId:String, difficulty:String):Void {
        songData = SongLoader.load(songId, difficulty);
        songSpeed = songData.scrollSpeed;
        Conductor.changeBPM(songData.bpm);
        Conductor.mapBpmChanges(songData.chart);

        unspawnNotes = [];
        for (n in songData.chart.notes) {
            unspawnNotes.push(n);

            // Generate sustain hold pieces
            if (n.sustainLength > 0) {
                var totalSustains = Math.floor(n.sustainLength / Conductor.stepCrochet);

                for (sus in 0...totalSustains) {
                    var susTime = n.strumTime + (Conductor.stepCrochet * (sus + 1));
                    var isEnd = (sus == totalSustains - 1);
                    var sustainData = new Note(susTime, n.direction, 0, n.mustPress, true, n.noteType);
                    var susSprite = new NoteSprite(sustainData, true, isEnd);
                    susSprite.cameras = [camHUD];
                    notes.add(susSprite);
                }
            }
        }

        unspawnNotes.sort(function(a, b) return FlxSort.byValues(FlxSort.ASCENDING, a.strumTime, b.strumTime));
        audio.loadSong(songId);
    }

    function startCountdown():Void {
        startedCountdown = true;
        Conductor.songPosition = -Conductor.crochet * 5;
        audio.play();

        #if desktop
        var totalSongSeconds = (audio.inst != null ? audio.inst.length : 180000) / 1000.0;
        soulscorch.backend.DiscordRPC.updateSongPresence(curSong, curDifficulty, totalSongSeconds, accuracy, songScore);
        #end
    }

    override public function update(elapsed:Float):Void {
        if (paused) return;

        scripts.call("update", [elapsed]);
        scripts.call("onUpdate", [elapsed]);

        audio.update(elapsed);
        modcharts.update(elapsed);

        super.update(elapsed);

        // Spawn Pending Notes
        while (unspawnNotes.length > 0 && unspawnNotes[0].strumTime - Conductor.songPosition < 1800 / songSpeed) {
            var n = unspawnNotes.shift();
            var noteSprite = new NoteSprite(n, false, false);
            noteSprite.cameras = [camHUD];
            notes.add(noteSprite);
        }

        // Position Active Notes
        notes.forEachAlive(function(daNote:NoteSprite) {
            var targetStrum = daNote.noteData.mustPress ? playerStrums.members[daNote.noteData.direction] : opponentStrums.members[daNote.noteData.direction];
            if (targetStrum != null) {
                daNote.x = targetStrum.x + daNote.offsetX;
                daNote.y = targetStrum.y + (0.45 * (Conductor.songPosition - daNote.noteData.strumTime) * songSpeed) + daNote.offsetY;

                // Opponent Autoplay
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

            // Hit Windows
            if (daNote.noteData.strumTime > Conductor.songPosition - Conductor.safeZoneOffset && daNote.noteData.strumTime < Conductor.songPosition + Conductor.safeZoneOffset) {
                daNote.noteData.canBeHit = true;
            } else {
                daNote.noteData.canBeHit = false;
            }

            // Miss Late Notes
            if (daNote.noteData.strumTime < Conductor.songPosition - Conductor.safeZoneOffset && !daNote.noteData.wasGoodHit) {
                daNote.noteData.tooLate = true;
                daNote.active = false;
                daNote.visible = false;
                noteMiss(daNote.noteData.direction);
                notes.remove(daNote, true);
                daNote.destroy();
            }
        });

        handleInput();

        if (InputMap.justPressed("pause")) {
            openPauseMenu();
        }

        scripts.call("updatePost", [elapsed]);
        scripts.call("onUpdatePost", [elapsed]);
    }

    function handleInput():Void {
        var keys = ["left", "down", "up", "right"];
        for (i in 0...keys.length) {
            if (InputMap.justPressed(keys[i])) {
                pressStrum(i);
            }
            if (InputMap.justReleased(keys[i])) {
                releaseStrum(i);
            }
        }
    }

    function pressStrum(dir:Int):Void {
        var pStrum = playerStrums.members[dir];
        if (pStrum != null) pStrum.playAnim('pressed');

        var possibleNotes:Array<NoteSprite> = [];
        notes.forEachAlive(function(daNote:NoteSprite) {
            if (daNote.noteData.mustPress && daNote.noteData.direction == dir && daNote.noteData.canBeHit && !daNote.noteData.wasGoodHit) {
                possibleNotes.push(daNote);
            }
        });

        if (possibleNotes.length > 0) {
            possibleNotes.sort(function(a, b) return FlxSort.byValues(FlxSort.ASCENDING, Math.abs(a.noteData.strumTime - Conductor.songPosition), Math.abs(b.noteData.strumTime - Conductor.songPosition)));
            goodNoteHit(possibleNotes[0]);
        }
    }

    function releaseStrum(dir:Int):Void {
        var pStrum = playerStrums.members[dir];
        if (pStrum != null) pStrum.playAnim('static');
    }

    function goodNoteHit(noteSprite:NoteSprite):Void {
        var note = noteSprite.noteData;
        note.wasGoodHit = true;

        var diff = Math.abs(note.strumTime - Conductor.songPosition);
        var judgment = Judgment.fromDifference(diff, Conductor.safeZoneOffset);

        songHits++;
        songScore += Judgment.score(judgment);
        totalNotesHit += Judgment.accuracyWeight(judgment);
        health = Math.min(2.0, health + Judgment.healthModifier(judgment));
        audio.muteVocal(true, false);

        var pStrum = playerStrums.members[note.direction];
        if (pStrum != null) {
            pStrum.playAnim('confirm', true);
            pStrum.resetAnim = 0.15;
        }

        if (Judgment.triggersSplash(judgment)) {
            spawnSplash(pStrum.x, pStrum.y, note.direction);
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
        songMisses++;
        songScore = Math.max(0, songScore - 10) > 0 ? songScore - 10 : 0;
        health = Math.max(0.0, health - 0.085);
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

    override public function beatHit(beat:Int):Void {
        super.beatHit(beat);

        if (beat % 4 == 0) {
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

        openSubState(new ScriptedSubState("PauseSubState"));
    }

    public function gameOver():Void {
        paused = true;
        audio.stop();
        var pStrum = playerStrums.members[0];
        openSubState(new GameOverSubState(pStrum != null ? pStrum.x : 100, pStrum != null ? pStrum.y : 100));
    }

    override public function destroy():Void {
        if (scripts != null) scripts.destroy();
        if (audio != null) audio.clear();
        super.destroy();
    }
}