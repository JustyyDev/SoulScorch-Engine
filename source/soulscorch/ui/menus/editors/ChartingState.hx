package soulscorch.ui.menus.editors;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.system.FlxSound;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import haxe.Json;
import openfl.events.Event;
import openfl.net.FileReference;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.input.Controls;
import soulscorch.backend.utils.Logger;
import soulscorch.gameplay.chart.Song;
import soulscorch.gameplay.song.Difficulty;
import soulscorch.gameplay.song.SongLoader;
import soulscorch.ui.menus.states.MainMenuState;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

class ChartingState extends MusicBeatState {
    public static var curSong:String = "tutorial";
    public static var curDifficulty:String = "normal";

    private var _song:SwagSong;

    // --- Cameras ---
    private var camGrid:FlxCamera;
    private var camHUD:FlxCamera;

    // --- Grid Constants ---
    public static inline var GRID_SIZE:Int = 40;
    public static inline var STRUM_COLS:Int = 8;
    public static inline var ROWS_PER_SECTION:Int = 16;

    // --- Grid Visuals ---
    private var gridBG:FlxSprite;
    private var gridSectionLine:FlxSprite;
    private var curSectionMarker:FlxSprite;
    private var cursorSprite:FlxSprite;

    // --- Note Rendering ---
    private var grpNotes:FlxSpriteGroup;
    private var grpSustains:FlxSpriteGroup;

    // --- Audio ---
    private var vocals:FlxSound;

    // --- State Variables ---
    private var curSection:Int = 0;
    private var curStepSelected:Int = 0;
    private var isPlaying:Bool = false;
    private var playbackSpeed:Float = 1.0;

    // --- HUD Overlay ---
    private var infoTxt:FlxText;
    private var helpTxt:FlxText;
    private var sectionTxt:FlxText;

    public function new(?song:String = "tutorial", ?difficulty:String = "normal") {
        super();
        if (song != null && song.length > 0) curSong = song.toLowerCase().trim();
        if (difficulty != null && difficulty.length > 0) curDifficulty = difficulty.toLowerCase().trim();
    }

    override public function create():Void {
        super.create();

        // 1. Setup Cameras
        camGrid = new FlxCamera();
        camHUD = new FlxCamera();
        camHUD.bgColor.alpha = 0;

        FlxG.cameras.reset(camGrid);
        FlxG.cameras.add(camHUD, false);
        FlxG.cameras.setDefaultDrawTarget(camGrid, true);

        // 2. Load Chart Data
        loadChart();

        // 3. Setup Grid Canvas
        createGridCanvas();

        // 4. Note Layers
        grpSustains = new FlxSpriteGroup();
        add(grpSustains);

        grpNotes = new FlxSpriteGroup();
        add(grpNotes);

        // 5. Cursor Indicator
        cursorSprite = new FlxSprite().makeGraphic(GRID_SIZE, GRID_SIZE, 0x44FFFFFF);
        cursorSprite.visible = false;
        add(cursorSprite);

        // 6. Setup Audio
        loadAudio();

        // 7. Setup Editor HUD
        setupHUD();

        // 8. Render Current Section Notes
        refreshSectionNotes();
        updateInfoText();

        FlxG.mouse.visible = true;
    }

    private function loadChart():Void {
        _song = Song.loadFromJson(curSong, curDifficulty);

        if (_song == null) {
            _song = {
                song: curSong,
                bpm: 100.0,
                speed: 2.0,
                player1: "bf",
                player2: "dad",
                gfVersion: "gf",
                stage: "stage",
                notes: []
            };
        }

        if (_song.notes == null || _song.notes.length == 0) {
            _song.notes = [];
            createSection();
        }

        Conductor.changeBPM(_song.bpm);
    }

    private function createSection():SwagSection {
        var sec:SwagSection = {
            sectionNotes: [],
            mustHitSection: true,
            bpm: _song.bpm,
            changeBPM: false,
            altAnim: false,
            lengthInSteps: ROWS_PER_SECTION
        };
        _song.notes.push(sec);
        return sec;
    }

    private function createGridCanvas():Void {
        var gridW = GRID_SIZE * STRUM_COLS;
        var gridH = GRID_SIZE * ROWS_PER_SECTION;

        gridBG = new FlxSprite(0, 0).makeGraphic(gridW, gridH, 0xFF181520);
        gridBG.screenCenter(X);

        // Draw grid checkering
        for (row in 0...ROWS_PER_SECTION) {
            for (col in 0...STRUM_COLS) {
                var isEven = (row + col) % 2 == 0;
                var color:FlxColor = isEven ? 0xFF231F2E : 0xFF2A2538;
                if (col == 4) color = 0xFF352F46; // Strumline divider

                var cell = new FlxSprite(gridBG.x + (col * GRID_SIZE), gridBG.y + (row * GRID_SIZE)).makeGraphic(GRID_SIZE - 1, GRID_SIZE - 1, color);
                add(cell);
            }
        }

        // Beat line separators
        for (i in 0...4) {
            var beatLine = new FlxSprite(gridBG.x, gridBG.y + (i * 4 * GRID_SIZE)).makeGraphic(gridW, 2, 0xFF665F7A);
            add(beatLine);
        }

        // Section bounds marker
        gridSectionLine = new FlxSprite(gridBG.x, gridBG.y).makeGraphic(gridW, 4, 0xFFFF0055);
        add(gridSectionLine);

        // Tracker line following current song step
        curSectionMarker = new FlxSprite(gridBG.x, gridBG.y).makeGraphic(gridW, 3, 0xFF00FFCC);
        add(curSectionMarker);
    }

    private function loadAudio():Void {
        FlxG.sound.music = Paths.inst(curSong);
        if (FlxG.sound.music != null) {
            FlxG.sound.music.pause();
            FlxG.sound.music.onComplete = function() {
                pausePlayback();
            };
        }

        var voiceSound = Paths.voices(curSong);
        if (voiceSound != null) {
            vocals = new FlxSound().loadEmbedded(voiceSound);
            FlxG.sound.list.add(vocals);
        }
    }

    private function setupHUD():Void {
        var bgHUD = new FlxSprite(0, 0).makeGraphic(320, FlxG.height, 0xDD110E17);
        bgHUD.scrollFactor.set();
        bgHUD.cameras = [camHUD];
        add(bgHUD);

        infoTxt = new FlxText(15, 15, 290, "", 14);
        infoTxt.setFormat(Paths.font("vcr"), 14, FlxColor.WHITE, LEFT);
        infoTxt.scrollFactor.set();
        infoTxt.cameras = [camHUD];
        add(infoTxt);

        sectionTxt = new FlxText(15, 220, 290, "", 14);
        sectionTxt.setFormat(Paths.font("vcr"), 14, 0xFF00FFCC, LEFT);
        sectionTxt.scrollFactor.set();
        sectionTxt.cameras = [camHUD];
        add(sectionTxt);

        var rightHUD = new FlxSprite(FlxG.width - 320, 0).makeGraphic(320, FlxG.height, 0xDD110E17);
        rightHUD.scrollFactor.set();
        rightHUD.cameras = [camHUD];
        add(rightHUD);

        helpTxt = new FlxText(FlxG.width - 305, 15, 290,
            "CONTROLS:\n\n" +
            "[L-Click] - Place Note\n" +
            "[R-Click] - Remove Note\n" +
            "[MouseWheel] - Note Sustain\n" +
            "[SPACE] - Play / Pause\n" +
            "[W / S] - Move Steps\n" +
            "[Q / E] - Previous / Next Sec\n" +
            "[TAB] - Toggle Section Turn\n" +
            "[A / D] - Playback Speed\n" +
            "[CTRL + S] - Save Chart JSON\n" +
            "[ESCAPE] - Exit Editor",
            13
        );
        helpTxt.setFormat(Paths.font("vcr"), 13, 0xFFDDDDDD, LEFT);
        helpTxt.scrollFactor.set();
        helpTxt.cameras = [camHUD];
        add(helpTxt);
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (isPlaying) {
            updateAudioPlayback();
        } else {
            handleNavigationInput();
            handleMouseInput();
        }

        handleKeyboardShortcuts();
        updateInfoText();
    }

    private function updateAudioPlayback():Void {
        if (FlxG.sound.music == null || !FlxG.sound.music.playing) return;

        Conductor.songPosition = FlxG.sound.music.time;

        if (vocals != null && Math.abs(vocals.time - FlxG.sound.music.time) > 20) {
            vocals.time = FlxG.sound.music.time;
        }

        var totalSteps = Math.floor(Conductor.songPosition / Conductor.stepCrochet);
        var targetSection = Math.floor(totalSteps / ROWS_PER_SECTION);

        if (targetSection != curSection && targetSection < _song.notes.length) {
            curSection = targetSection;
            refreshSectionNotes();
        }

        var stepInSection = totalSteps % ROWS_PER_SECTION;
        curSectionMarker.y = gridBG.y + (stepInSection * GRID_SIZE);
    }

    private function handleNavigationInput():Void {
        // Section Navigation
        if (FlxG.keys.justPressed.E) changeSection(1);
        if (FlxG.keys.justPressed.Q) changeSection(-1);

        // Step Navigation
        if (FlxG.keys.justPressed.W) changeStep(-1);
        if (FlxG.keys.justPressed.S) changeStep(1);

        // Playback Speed
        if (FlxG.keys.justPressed.A) playbackSpeed = Math.max(0.25, playbackSpeed - 0.25);
        if (FlxG.keys.justPressed.D) playbackSpeed = Math.min(3.0, playbackSpeed + 0.25);

        // Turn Switcher
        if (FlxG.keys.justPressed.TAB) {
            if (_song.notes[curSection] != null) {
                _song.notes[curSection].mustHitSection = !_song.notes[curSection].mustHitSection;
                refreshSectionNotes();
            }
        }
    }

    private function handleMouseInput():Void {
        var mx = FlxG.mouse.x;
        var my = FlxG.mouse.y;

        if (mx >= gridBG.x && mx < gridBG.x + gridBG.width && my >= gridBG.y && my < gridBG.y + gridBG.height) {
            var col = Math.floor((mx - gridBG.x) / GRID_SIZE);
            var row = Math.floor((my - gridBG.y) / GRID_SIZE);

            cursorSprite.visible = true;
            cursorSprite.setPosition(gridBG.x + (col * GRID_SIZE), gridBG.y + (row * GRID_SIZE));

            var noteTime = ((curSection * ROWS_PER_SECTION) + row) * Conductor.stepCrochet;

            // Place Note
            if (FlxG.mouse.justPressed) {
                addNote(noteTime, col);
            }

            // Remove Note
            if (FlxG.mouse.justPressedRight) {
                deleteNote(noteTime, col);
            }

            // Sustain Adjustment
            if (FlxG.mouse.wheel != 0) {
                adjustSustain(noteTime, col, FlxG.mouse.wheel);
            }
        } else {
            cursorSprite.visible = false;
        }
    }

    private function handleKeyboardShortcuts():Void {
        // Spacebar Play/Pause
        if (FlxG.keys.justPressed.SPACE) {
            togglePlayback();
        }

        // Save Chart
        if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.S) {
            saveChartJson();
        }

        // Exit
        if (FlxG.keys.justPressed.ESCAPE) {
            if (FlxG.sound.music != null) FlxG.sound.music.stop();
            if (vocals != null) vocals.stop();
            MusicBeatState.switchState(new MainMenuState());
        }
    }

    private function changeSection(change:Int):Void {
        curSection = Std.int(Math.max(0, curSection + change));
        while (curSection >= _song.notes.length) {
            createSection();
        }

        Conductor.songPosition = curSection * ROWS_PER_SECTION * Conductor.stepCrochet;
        if (FlxG.sound.music != null) FlxG.sound.music.time = Conductor.songPosition;
        if (vocals != null) vocals.time = Conductor.songPosition;

        curSectionMarker.y = gridBG.y;
        refreshSectionNotes();
    }

    private function changeStep(change:Int):Void {
        curStepSelected = FlxMath.wrap(curStepSelected + change, 0, ROWS_PER_SECTION - 1);
        curSectionMarker.y = gridBG.y + (curStepSelected * GRID_SIZE);

        Conductor.songPosition = ((curSection * ROWS_PER_SECTION) + curStepSelected) * Conductor.stepCrochet;
        if (FlxG.sound.music != null) FlxG.sound.music.time = Conductor.songPosition;
        if (vocals != null) vocals.time = Conductor.songPosition;
    }

    private function togglePlayback():Void {
        isPlaying = !isPlaying;

        if (isPlaying) {
            Conductor.songPosition = ((curSection * ROWS_PER_SECTION) + curStepSelected) * Conductor.stepCrochet;
            if (FlxG.sound.music != null) {
                FlxG.sound.music.time = Conductor.songPosition;
                FlxG.sound.music.pitch = playbackSpeed;
                FlxG.sound.music.play();
            }
            if (vocals != null) {
                vocals.time = Conductor.songPosition;
                vocals.pitch = playbackSpeed;
                vocals.play();
            }
        } else {
            pausePlayback();
        }
    }

    private function pausePlayback():Void {
        isPlaying = false;
        if (FlxG.sound.music != null) FlxG.sound.music.pause();
        if (vocals != null) vocals.pause();
    }

    private function addNote(time:Float, data:Int):Void {
        var sec = _song.notes[curSection];
        if (sec == null) return;

        // Check if note already exists at this spot
        for (n in sec.sectionNotes) {
            if (Math.abs(n[0] - time) < 5 && n[1] == data) return;
        }

        sec.sectionNotes.push([time, data, 0.0]);
        refreshSectionNotes();
    }

    private function deleteNote(time:Float, data:Int):Void {
        var sec = _song.notes[curSection];
        if (sec == null) return;

        for (i in 0...sec.sectionNotes.length) {
            var n = sec.sectionNotes[i];
            if (Math.abs(n[0] - time) < 5 && n[1] == data) {
                sec.sectionNotes.splice(i, 1);
                break;
            }
        }
        refreshSectionNotes();
    }

    private function adjustSustain(time:Float, data:Int, change:Int):Void {
        var sec = _song.notes[curSection];
        if (sec == null) return;

        for (n in sec.sectionNotes) {
            if (Math.abs(n[0] - time) < 5 && n[1] == data) {
                n[2] = Math.max(0, n[2] + (change * Conductor.stepCrochet));
                break;
            }
        }
        refreshSectionNotes();
    }

    private function refreshSectionNotes():Void {
        grpNotes.clear();
        grpSustains.clear();

        var sec = _song.notes[curSection];
        if (sec == null) return;

        var noteColors:Array<Int> = [0xFFC24B99, 0xFF00FFFF, 0xFF12FA05, 0xFFF9393F, 0xFFC24B99, 0xFF00FFFF, 0xFF12FA05, 0xFFF9393F];

        for (n in sec.sectionNotes) {
            var time:Float = n[0];
            var noteData:Int = Std.int(n[1]) % STRUM_COLS;
            var susLen:Float = n[2];

            var stepIndex = Math.floor((time - (curSection * ROWS_PER_SECTION * Conductor.stepCrochet)) / Conductor.stepCrochet);
            var noteX = gridBG.x + (noteData * GRID_SIZE);
            var noteY = gridBG.y + (stepIndex * GRID_SIZE);

            // Note Head
            var noteSpr = new FlxSprite(noteX + 2, noteY + 2).makeGraphic(GRID_SIZE - 4, GRID_SIZE - 4, noteColors[noteData]);
            grpNotes.add(noteSpr);

            // Sustain Tail
            if (susLen > 0) {
                var susSteps = susLen / Conductor.stepCrochet;
                var susH = Std.int(susSteps * GRID_SIZE);
                var susSpr = new FlxSprite(noteX + (GRID_SIZE * 0.35), noteY + GRID_SIZE).makeGraphic(Std.int(GRID_SIZE * 0.3), susH, noteColors[noteData]);
                susSpr.alpha = 0.6;
                grpSustains.add(susSpr);
            }
        }
    }

    private function updateInfoText():Void {
        var sec = _song.notes[curSection];
        var isPlayer = sec != null ? sec.mustHitSection : true;

        infoTxt.text = 'CHART EDITOR\n\n' +
            'Song: ${_song.song}\n' +
            'Difficulty: ${curDifficulty.toUpperCase()}\n' +
            'BPM: ${_song.bpm}\n' +
            'Speed: ${_song.speed}\n' +
            'Playback: ${playbackSpeed}x\n' +
            'Time: ${Math.floor(Conductor.songPosition / 1000)}s';

        sectionTxt.text = 'SECTION INFO\n\n' +
            'Section: $curSection / ${_song.notes.length - 1}\n' +
            'Camera Focus: ${isPlayer ? "Boyfriend" : "Opponent"}\n' +
            'Steps in Sec: ${sec != null ? sec.lengthInSteps : 16}';
    }

    private function saveChartJson():Void {
        var formatted = Json.stringify({song: _song}, "\t");
        var fileName = curSong.toLowerCase().trim() + (curDifficulty == "normal" ? "" : '-$curDifficulty') + ".json";

        #if sys
        var targetDir = 'assets/data/${curSong.toLowerCase().trim()}';
        var fullPath = '$targetDir/$fileName';

        try {
            if (!FileSystem.exists(targetDir)) {
                FileSystem.createDirectory(targetDir);
            }
            File.saveContent(fullPath, formatted);
            Logger.info('Successfully saved chart to $fullPath', "charting");
            AssetHelper.playSoundSafely("confirmMenu", 0.7);
        } catch (e:Dynamic) {
            Logger.error('Failed saving chart JSON: $e', "charting");
        }
        #else
        var fileRef = new FileReference();
        fileRef.save(formatted, fileName);
        #end
    }
}