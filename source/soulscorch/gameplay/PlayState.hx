package soulscorch.gameplay;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import soulscorch.core.Scene;
import soulscorch.core.Runtime;
import soulscorch.stage.Stage;
import soulscorch.stage.StageLoader;
import soulscorch.modding.ScriptManager;
import soulscorch.ui.menus.PauseSubState;
import soulscorch.ui.menus.TitleState;
import soulscorch.ui.HealthBar;
import soulscorch.input.InputMap;
import soulscorch.gameplay.Judgment;

class PlayState extends Scene {
    static inline var SPAWN_DISTANCE:Float = 2000;
    
    public var songId:String;
    public var difficulty:String;
    public var song:Song;
    public var stage:Stage;
    public var conductor:Conductor;
    public var scripts:ScriptManager;

    public var bf:Character;
    public var dad:Character;
    public var gf:Character;
    
    public var activeNotes:FlxTypedGroup<NoteSprite>;
    public var opponentStrums:FlxTypedGroup<FlxSprite>;
    public var playerStrums:FlxTypedGroup<FlxSprite>;
    public var noteSplashes:FlxTypedGroup<NoteSplash>;
    
    public var nextNoteIndex:Int = 0;
    
    public var score:Int = 0;
    public var misses:Int = 0;
    public var combo:Int = 0;
    public var highestCombo:Int = 0;
    public var health:Float = 1.0;
    public var accuracyTotal:Float = 0;
    public var judgedNotes:Int = 0;
    
    public var songStarted:Bool = false;
    public var songFinished:Bool = false;
    
    public var healthBar:HealthBar;
    public var hud:FlxText;
    public var judgmentText:FlxText;

    public function new(songId:String = "engine-test", difficulty:String = "normal") {
        super();
        this.songId = songId;
        this.difficulty = difficulty;
    }

    override public function create():Void {
        super.create();

        scripts = new ScriptManager();
        scripts.set("PlayState", this);
        scripts.set("FlxG", FlxG);

        song = SongLoader.load(songId, difficulty);
        scripts.set("song", song);

        conductor = new Conductor(song.bpm);
        conductor.mapBpmChanges(song.chart);
        scripts.set("conductor", conductor);
        
        stage = StageLoader.load(song.stage);
        stage.load();
        add(stage);
        scripts.set("stage", stage);

        gf = new Character(stage.gfPosition[0], stage.gfPosition[1], song.gfVersion, false);
        dad = new Character(stage.dadPosition[0], stage.dadPosition[1], song.player2, false);
        bf = new Character(stage.bfPosition[0], stage.bfPosition[1], song.player1, true);

        scripts.set("gf", gf);
        scripts.set("dad", dad);
        scripts.set("bf", bf);

        add(gf);
        add(dad);
        add(bf);

        scripts.loadScript('assets/data/stages/${song.stage}.hx');
        scripts.loadScript('assets/songs/${song.id}/script.hx');
        
        scripts.call("onCreate");

        opponentStrums = new FlxTypedGroup<FlxSprite>();
        playerStrums = new FlxTypedGroup<FlxSprite>();
        activeNotes = new FlxTypedGroup<NoteSprite>();
        noteSplashes = new FlxTypedGroup<NoteSplash>();
        
        add(opponentStrums);
        add(playerStrums);
        add(activeNotes);
        add(noteSplashes);

        createStrumLines();
        createHud();
        
        scripts.call("onCreatePost");

        FlxG.sound.playMusic('assets/songs/${song.id}/Inst.ogg', 1, false);
        FlxG.sound.music.onComplete = function() { finishSong(true); };
        songStarted = true;
    }

    override public function update(elapsed:Float):Void {
        if (songFinished) {
            handlePostSongInput();
            return;
        }

        scripts.call("onUpdate", [elapsed]);

        if (songStarted) {
            conductor.update(elapsed);
            
            var oldStep = curStep;
            var newStep = Math.floor(Conductor.songPosition / conductor.stepCrochet);
            if (newStep > oldStep) {
                for (i in (oldStep + 1)...(newStep + 1)) {
                    stepHit(i);
                }
            }

            spawnNotes();
            updateNotes(elapsed);
            checkInput();
        }

        if (InputMap.justPressed("pause")) {
            FlxG.sound.music.pause();
            persistentUpdate = false;
            openSubState(new PauseSubState());
            return;
        }

        if (FlxG.keys.justPressed.R) {
            FlxG.resetState();
            return;
        }

        if (health <= 0) {
            finishSong(false);
            return;
        }

        scripts.call("onUpdatePost", [elapsed]);
        super.update(elapsed);
    }

    override public function stepHit(step:Int):Void {
        super.stepHit(step);
        scripts.call("onStepHit", [step]);
    }

    override public function beatHit(beat:Int):Void {
        super.beatHit(beat);
        scripts.call("onBeatHit", [beat]);

        if (beat % 2 == 0) {
            gf.dance();
        }

        if (bf.animation.curAnim != null && !StringTools.startsWith(bf.animation.curAnim.name, "sing") && !bf.stunned) {
            bf.dance();
        }

        if (dad.animation.curAnim != null && !StringTools.startsWith(dad.animation.curAnim.name, "sing") && !dad.stunned) {
            dad.dance();
        }

        if (healthBar != null) {
            healthBar.bop();
        }
    }

    function createStrumLines():Void {
        var strumY:Float = Runtime.engine.config.downscroll ? FlxG.height - 150 : 50;
        
        for (i in 0...4) {
            var oppStrum = new FlxSprite(92 + (112 * i), strumY);
            oppStrum.makeGraphic(NoteSprite.WIDTH, NoteSprite.HEIGHT, NoteSprite.colorForDirection(i));
            oppStrum.alpha = 0.5;
            opponentStrums.add(oppStrum);

            var playerStrum = new FlxSprite((FlxG.width / 2) + 92 + (112 * i), strumY);
            playerStrum.makeGraphic(NoteSprite.WIDTH, NoteSprite.HEIGHT, NoteSprite.colorForDirection(i));
            playerStrum.alpha = 0.8;
            playerStrums.add(playerStrum);
        }
    }

    function createHud():Void {
        var barY:Float = Runtime.engine.config.downscroll ? 40 : FlxG.height - 100;
        healthBar = new HealthBar((FlxG.width - 600) / 2, barY, bf.healthIcon, dad.healthIcon);
        add(healthBar);

        var hudY:Float = Runtime.engine.config.downscroll ? 20 : FlxG.height - 40;
        hud = new FlxText(0, hudY, FlxG.width, "", 20);
        hud.alignment = CENTER;
        add(hud);

        judgmentText = new FlxText(0, FlxG.height * 0.4, FlxG.width, "", 48);
        judgmentText.alignment = CENTER;
        add(judgmentText);
    }

    function spawnNotes():Void {
        while (nextNoteIndex < song.chart.notes.length) {
            var nData = song.chart.notes[nextNoteIndex];
            if (nData.time - Conductor.songPosition > SPAWN_DISTANCE) break;

            var note = new NoteSprite(nData);
            
            var targetGroup = nData.mustPress ? playerStrums : opponentStrums;
            var targetStrum = targetGroup.members[nData.direction];
            note.x = targetStrum.x;
            
            activeNotes.add(note);
            nextNoteIndex++;
        }
    }

    function updateNotes(elapsed:Float):Void {
        activeNotes.forEachAlive(function(note:NoteSprite) {
            var difference = note.data.time - Conductor.songPosition;
            var strumY:Float = Runtime.engine.config.downscroll ? FlxG.height - 150 : 50;
            var scrollMult:Int = Runtime.engine.config.downscroll ? -1 : 1;
            
            note.y = strumY - (difference * song.scrollSpeed * scrollMult);

            if (!note.data.mustPress && difference <= 0) {
                dad.playSingAnim(note.data.direction);
                scripts.call("onOpponentNoteHit", [note]);
                note.kill();
                opponentStrums.members[note.data.direction].scale.set(0.9, 0.9);
            }

            if (note.data.mustPress && difference < -conductor.safeZoneOffset) {
                noteMiss(note.data.direction);
                note.kill();
            }
        });

        opponentStrums.forEachAlive(function(strum:FlxSprite) {
            strum.scale.set(Math.min(1, strum.scale.x + elapsed * 2), Math.min(1, strum.scale.y + elapsed * 2));
        });
        playerStrums.forEachAlive(function(strum:FlxSprite) {
            strum.scale.set(Math.min(1, strum.scale.x + elapsed * 2), Math.min(1, strum.scale.y + elapsed * 2));
        });

        updateHud();
    }

    function checkInput():Void {
        var pressed = [
            InputMap.justPressed("left"),
            InputMap.justPressed("down"),
            InputMap.justPressed("up"),
            InputMap.justPressed("right")
        ];

        for (dir in 0...4) {
            if (pressed[dir]) {
                playerStrums.members[dir].scale.set(0.8, 0.8);
                tryHit(dir);
            }
        }
    }

    function tryHit(direction:Int):Void {
        var hittableNotes:Array<NoteSprite> = [];

        activeNotes.forEachAlive(function(note:NoteSprite) {
            if (note.data.mustPress && note.data.direction == direction) {
                var difference = Math.abs(note.data.time - Conductor.songPosition);
                if (difference <= conductor.safeZoneOffset) {
                    hittableNotes.push(note);
                }
            }
        });

        if (hittableNotes.length > 0) {
            hittableNotes.sort(function(a, b) return Std.int(a.data.time - b.data.time));
            var target = hittableNotes[0];
            var diff = target.data.time - Conductor.songPosition;
            
            bf.playSingAnim(direction);
            scripts.call("onPlayerNoteHit", [target]);
            
            var judgment = Judgment.fromDifference(diff, conductor.safeZoneOffset);
            if (judgment == Judgment.SICK) {
                var targetStrum = playerStrums.members[direction];
                var splash = new NoteSplash(targetStrum.x, targetStrum.y, direction);
                noteSplashes.add(splash);
            }

            judge(target, judgment);
        } else if (!Runtime.engine.config.ghostTapping) {
            noteMiss(direction);
        }
    }

    function noteMiss(direction:Int):Void {
        bf.playSingAnim(direction, true);
        misses++;
        combo = 0;
        health -= Judgment.healthModifier(Judgment.MISS);
        scripts.call("onNoteMiss", [direction]);
        updateHud();
    }

    function judge(note:NoteSprite, judgment:Judgment):Void {
        note.kill();
        score += Judgment.score(judgment);
        
        if (judgment != Judgment.MISS) {
            combo++;
            judgedNotes++;
            accuracyTotal += Judgment.accuracyWeight(judgment);
            if (combo > highestCombo) highestCombo = combo;
        } else {
            combo = 0;
        }

        health += Judgment.healthModifier(judgment);
        if (health > 2.0) health = 2.0;
        if (health < 0.0) health = 0.0;

        if (healthBar != null) {
            healthBar.value = health;
        }

        judgmentText.text = judgment;
        judgmentText.alpha = 1;
    }

    function updateHud():Void {
        var acc = judgedNotes == 0 ? 100.0 : (accuracyTotal / judgedNotes) * 100;
        var displayAcc = Math.round(acc * 100) / 100;
        hud.text = 'Score: $score | Misses: $misses | Accuracy: $displayAcc%';
        
        if (judgmentText.alpha > 0) {
            judgmentText.alpha -= FlxG.elapsed * 2;
        }
    }

    function handlePostSongInput():Void {
        if (FlxG.keys.justPressed.R) {
            FlxG.resetState();
        } else if (InputMap.justPressed("accept") || InputMap.justPressed("back")) {
            FlxG.switchState(new TitleState());
        }
    }

    function finishSong(completed:Bool):Void {
        songFinished = true;
        if (FlxG.sound.music != null) FlxG.sound.music.stop();
        
        scripts.call("onEndSong", [completed]);

        var acc = judgedNotes == 0 ? 0.0 : Math.round((accuracyTotal / judgedNotes) * 100);
        judgmentText.alpha = 1.0;
        judgmentText.text = completed
            ? 'CLEARED\nScore: $score | Best: $highestCombo | Acc: $acc%\n[ENTER] to continue'
            : 'GAME OVER\n[ENTER] to quit | [R] to retry';
    }

    override public function destroy():Void {
        if (scripts != null) {
            scripts.destroy();
        }
        super.destroy();
    }
}