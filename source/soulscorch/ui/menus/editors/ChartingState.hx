package soulscorch.ui.menus.editors;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import haxe.Json;
import openfl.net.FileReference;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.audio.Conductor;
import soulscorch.gameplay.chart.Chart;
import soulscorch.gameplay.chart.Song;
import soulscorch.gameplay.notes.Note;
import soulscorch.gameplay.notes.NoteSkinManager;
import soulscorch.gameplay.notes.Strumline;
import soulscorch.scripting.mod.ModManager;
import soulscorch.ui.menus.editors.editorui.EditorButton;
import soulscorch.ui.menus.editors.editorui.EditorCheckbox;
import soulscorch.ui.menus.editors.editorui.EditorInputText;
import soulscorch.ui.menus.editors.editorui.EditorNumericStepper;
import soulscorch.ui.menus.editors.editorui.EditorTheme;
import soulscorch.ui.menus.editors.editorui.EditorToast;
import soulscorch.ui.menus.editors.editorui.EditorTopBar;
import soulscorch.ui.menus.editors.editorui.EditorWindow;
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
    private var copiedSection:SwagSection = null;

    private var camGrid:FlxCamera;

    public static inline var GRID_SIZE:Int = 40;
    public static inline var STRUM_COLS:Int = 8;
    public static inline var ROWS_PER_SECTION:Int = 16;
    public static inline var VISIBLE_SECTIONS:Int = 3;

    private var gridCanvas:FlxSpriteGroup;
    private var curSectionMarker:FlxSprite;
    private var cursorSprite:FlxSprite;

    private var grpNotes:FlxSpriteGroup;
    private var grpSustains:FlxSpriteGroup;
    private var grpEvents:FlxSpriteGroup;

    private var vocals:FlxSound;
    private var curSection:Int = 0;
    private var curStepSelected:Int = 0;
    private var isPlaying:Bool = false;
    private var playbackSpeed:Float = 1.0;
    private var metronomeEnabled:Bool = false;
    private var hitsoundsEnabled:Bool = true;

    // --- Mania Snapping Matrix ---
    private var snapList:Array<Int> = [4, 8, 12, 16, 24, 32, 48, 64];
    private var snapColors:Array<FlxColor> = [
        0xFFFF0055, // 1/4 (Red)
        0xFF00AAFF, // 1/8 (Blue)
        0xFFAA00FF, // 1/12 (Purple)
        0xFFFFD700, // 1/16 (Yellow)
        0xFFFF69B4, // 1/24 (Pink)
        0xFFFFA500, // 1/32 (Orange)
        0xFF00FFFF, // 1/48 (Cyan)
        0xFF00FF66  // 1/64 (Green)
    ];
    private var curSnapIdx:Int = 3; // Default: 1/16

    // --- Top Bar & UI Toolboxes ---
    private var topBar:EditorTopBar;
    private var songPropsWindow:EditorWindow;
    private var sectionToolsWindow:EditorWindow;
    private var eventMasterWindow:EditorWindow;

    private var stepperBPM:EditorNumericStepper;
    private var stepperSpeed:EditorNumericStepper;
    private var checkMustHit:EditorCheckbox;
    private var checkMetronome:EditorCheckbox;
    private var checkHitsounds:EditorCheckbox;

    private var inputEventName:EditorInputText;
    private var inputEventVal1:EditorInputText;
    private var inputEventVal2:EditorInputText;

    private var infoTxt:FlxText;
    private var snapIndicatorTxt:FlxText;
    private var lastHitNoteTimes:Array<Float> = [];

    public function new(?song:String = "tutorial", ?difficulty:String = "normal") {
        super();
        if (song != null && song.length > 0) curSong = song.toLowerCase().trim();
        if (difficulty != null && difficulty.length > 0) curDifficulty = difficulty.toLowerCase().trim();
    }

    override public function create():Void {
        super.create();

        camGrid = new FlxCamera();
        camHUD = new FlxCamera();
        camHUD.bgColor.alpha = 0;

        FlxG.cameras.reset(camGrid);
        FlxG.cameras.add(camHUD, false);
        FlxG.cameras.setDefaultDrawTarget(camGrid, true);

        loadChart();

        var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, EditorTheme.BG_DARK);
        bg.scrollFactor.set(0, 0);
        add(bg);

        gridCanvas = new FlxSpriteGroup();
        add(gridCanvas);
        createMultiSectionGrid();

        grpSustains = new FlxSpriteGroup();
        add(grpSustains);

        grpNotes = new FlxSpriteGroup();
        add(grpNotes);

        grpEvents = new FlxSpriteGroup();
        add(grpEvents);

        cursorSprite = new FlxSprite().makeGraphic(GRID_SIZE, GRID_SIZE, 0x4400FFCC);
        cursorSprite.visible = false;
        add(cursorSprite);

        loadAudio();
        setupWindows();

        refreshSectionNotes();
        add(new EditorToast());
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
                notes: [],
                events: []
            };
        }

        if (_song.notes == null || _song.notes.length == 0) createSection();
        if (_song.events == null) _song.events = [];
        Conductor.changeBPM(_song.bpm > 0 ? _song.bpm : 100.0);
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

    private function createMultiSectionGrid():Void {
        gridCanvas.clear();

        var gridW = GRID_SIZE * STRUM_COLS;
        var gridH = GRID_SIZE * ROWS_PER_SECTION * VISIBLE_SECTIONS;
        var startX = (FlxG.width - gridW) * 0.5;

        // Base Grid Texture
        var bg = new FlxSprite(startX, 40).makeGraphic(gridW, gridH, EditorTheme.GRID_EVEN);
        gridCanvas.add(bg);

        for (row in 0...(ROWS_PER_SECTION * VISIBLE_SECTIONS)) {
            for (col in 0...STRUM_COLS) {
                var isEven = (row + col) % 2 == 0;
                var color:FlxColor = isEven ? EditorTheme.GRID_EVEN : EditorTheme.GRID_ODD;
                if (col == 4) color = EditorTheme.GRID_SEPARATOR;

                var cell = new FlxSprite(startX + (col * GRID_SIZE), 40 + (row * GRID_SIZE)).makeGraphic(GRID_SIZE - 1, GRID_SIZE - 1, color);
                gridCanvas.add(cell);
            }

            // Beat separator lines
            if (row % 4 == 0) {
                var beatLine = new FlxSprite(startX, 40 + (row * GRID_SIZE)).makeGraphic(gridW, 2, EditorTheme.ACCENT_PURPLE);
                gridCanvas.add(beatLine);
            }
        }

        // Major Section Boundaries
        for (s in 0...VISIBLE_SECTIONS) {
            var sectionSep = new FlxSprite(startX, 40 + (s * ROWS_PER_SECTION * GRID_SIZE)).makeGraphic(gridW, 3, EditorTheme.ACCENT_MAGENTA);
            gridCanvas.add(sectionSep);
        }

        curSectionMarker = new FlxSprite(startX, 40).makeGraphic(gridW, 4, EditorTheme.ACCENT_CYAN);
        gridCanvas.add(curSectionMarker);
    }

    private function loadAudio():Void {
        var instSound = Paths.inst(curSong);
        if (instSound != null) {
            FlxG.sound.playMusic(instSound, 0, false);
            if (FlxG.sound.music != null) FlxG.sound.music.pause();
        }

        var voiceSound = Paths.voices(curSong);
        if (voiceSound != null) {
            vocals = new FlxSound().loadEmbedded(voiceSound);
            FlxG.sound.list.add(vocals);
        }
    }

    private function setupWindows():Void {
        topBar = new EditorTopBar('MANIA CHART STUDIO // [${curSong.toUpperCase()}]');
        topBar.cameras = [camHUD];
        topBar.addAction("Save (Ctrl+S)", saveChartJson);
        topBar.addAction("Rate Up", function() adjustRate(0.25));
        topBar.addAction("Rate Down", function() adjustRate(-0.25));
        topBar.addAction("Exit", function() {
            if (FlxG.sound.music != null) FlxG.sound.music.stop();
            if (vocals != null) vocals.stop();
            MusicBeatState.switchState(new MainMenuState());
        });
        add(topBar);

        // --- 1. Song Metronome & Quantization Window ---
        songPropsWindow = new EditorWindow(15, 45, 300, 340, "Song & Quantization");
        songPropsWindow.cameras = [camHUD];
        add(songPropsWindow);

        infoTxt = new FlxText(10, 4, 280, "", 13);
        infoTxt.setFormat(Paths.font("vcr"), 13, EditorTheme.TEXT_PRIMARY, LEFT);
        songPropsWindow.addElement(infoTxt);

        snapIndicatorTxt = new FlxText(10, 110, 280, "SNAP: 1/16", 16);
        snapIndicatorTxt.setFormat(Paths.font("vcr"), 16, snapColors[curSnapIdx], LEFT);
        songPropsWindow.addElement(snapIndicatorTxt);

        stepperBPM = new EditorNumericStepper(10, 140, 280, "Song BPM", _song.bpm, 1.0, 600.0, 1.0, 1, function(v) {
            _song.bpm = v;
            Conductor.changeBPM(v);
            updateInfoText();
        });
        songPropsWindow.addElement(stepperBPM);

        stepperSpeed = new EditorNumericStepper(10, 180, 280, "Scroll Speed", _song.speed, 0.5, 8.0, 0.1, 2, function(v) {
            _song.speed = v;
            updateInfoText();
        });
        songPropsWindow.addElement(stepperSpeed);

        checkHitsounds = new EditorCheckbox(10, 225, "Hitsounds On Hit", hitsoundsEnabled, function(c) hitsoundsEnabled = c);
        songPropsWindow.addElement(checkHitsounds);

        checkMetronome = new EditorCheckbox(10, 255, "Beat Metronome", metronomeEnabled, function(c) metronomeEnabled = c);
        songPropsWindow.addElement(checkMetronome);

        // --- 2. Section Utilities Window ---
        sectionToolsWindow = new EditorWindow(FlxG.width - 315, 45, 300, 210, "Section Utilities");
        sectionToolsWindow.cameras = [camHUD];
        add(sectionToolsWindow);

        checkMustHit = new EditorCheckbox(10, 4, "Must Hit (BF Focus)", _song.notes[curSection] != null && _song.notes[curSection].mustHitSection, function(checked) {
            if (_song.notes[curSection] != null) {
                _song.notes[curSection].mustHitSection = checked;
                refreshSectionNotes();
                updateInfoText();
            }
        });
        sectionToolsWindow.addElement(checkMustHit);

        var btnCopy = new EditorButton(10, 40, 135, 26, "Copy (Ctrl+C)", copyCurrentSection);
        sectionToolsWindow.addElement(btnCopy);

        var btnPaste = new EditorButton(155, 40, 135, 26, "Paste (Ctrl+V)", pasteCurrentSection);
        sectionToolsWindow.addElement(btnPaste);

        var btnClear = new EditorButton(10, 75, 280, 26, "Clear Section Notes", clearCurrentSection);
        sectionToolsWindow.addElement(btnClear);

        var btnFlipLanes = new EditorButton(10, 110, 280, 26, "Flip Section Lanes (Tab)", function() {
            flipCurrentSectionLanes();
        });
        sectionToolsWindow.addElement(btnFlipLanes);

        // --- 3. Events & Automator Window ---
        eventMasterWindow = new EditorWindow(FlxG.width - 315, 265, 300, 270, "Event Automator");
        eventMasterWindow.cameras = [camHUD];
        add(eventMasterWindow);

        inputEventName = new EditorInputText(10, 4, 280, "Event Name (e.g. Camera Zoom)", "Camera Zoom");
        eventMasterWindow.addElement(inputEventName);

        inputEventVal1 = new EditorInputText(10, 48, 135, "Value 1", "1.2");
        eventMasterWindow.addElement(inputEventVal1);

        inputEventVal2 = new EditorInputText(155, 48, 135, "Value 2", "0.05");
        eventMasterWindow.addElement(inputEventVal2);

        var btnPlaceEvent = new EditorButton(10, 105, 280, 28, "Place Event At Step", function() {
            placeEventNode();
        });
        eventMasterWindow.addElement(btnPlaceEvent);

        updateInfoText();
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (isPlaying) {
            updateAudioPlayback();
        } else {
            handleNavigationInput();
            handleMouseInput();
        }

        if (FlxG.keys.justPressed.SPACE) togglePlayback();
        if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.S) saveChartJson();
        if (FlxG.keys.justPressed.ESCAPE) {
            if (FlxG.sound.music != null) FlxG.sound.music.stop();
            if (vocals != null) vocals.stop();
            MusicBeatState.switchState(new MainMenuState());
        }

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
        var startX = (FlxG.width - (GRID_SIZE * STRUM_COLS)) * 0.5;
        curSectionMarker.setPosition(startX, 40 + (stepInSection * GRID_SIZE));

        checkHitsoundTrigger(Conductor.songPosition);
    }

    private function checkHitsoundTrigger(songPos:Float):Void {
        if (!hitsoundsEnabled || _song.notes[curSection] == null) return;

        for (n in _song.notes[curSection].sectionNotes) {
            var nTime:Float = n[0];
            if (Math.abs(songPos - nTime) < 15.0 && !lastHitNoteTimes.contains(nTime)) {
                AssetHelper.playSoundSafely("scrollMenu", 0.45);
                lastHitNoteTimes.push(nTime);
                if (lastHitNoteTimes.length > 32) lastHitNoteTimes.shift();
                break;
            }
        }
    }

    override public function stepHit(step:Int):Void {
        super.stepHit(step);
        if (metronomeEnabled && step % 4 == 0) {
            AssetHelper.playSoundSafely("scrollMenu", 0.6);
        }
    }

    private function handleNavigationInput():Void {
        // Section & Step navigation
        if (FlxG.keys.justPressed.E) changeSection(1);
        if (FlxG.keys.justPressed.Q) changeSection(-1);
        if (FlxG.keys.justPressed.W) changeStep(-1);
        if (FlxG.keys.justPressed.S) changeStep(1);

        // Snap quantization switching
        if (FlxG.keys.justPressed.RIGHT) changeSnap(1);
        if (FlxG.keys.justPressed.LEFT) changeSnap(-1);

        // Hotkey rate adjustments
        if (FlxG.keys.justPressed.A) adjustRate(-0.25);
        if (FlxG.keys.justPressed.D) adjustRate(0.25);

        // Flip section lanes
        if (FlxG.keys.justPressed.TAB) flipCurrentSectionLanes();

        // Copy/Paste shortcuts
        if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.C) copyCurrentSection();
        if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.V) pasteCurrentSection();
    }

    private function handleMouseInput():Void {
        var startX = (FlxG.width - (GRID_SIZE * STRUM_COLS)) * 0.5;
        var gridW = GRID_SIZE * STRUM_COLS;
        var gridH = GRID_SIZE * ROWS_PER_SECTION;

        var mx = FlxG.mouse.x;
        var my = FlxG.mouse.y;

        if (mx >= startX && mx < startX + gridW && my >= 40 && my < 40 + gridH) {
            var col = Math.floor((mx - startX) / GRID_SIZE);
            var row = Math.floor((my - 40) / GRID_SIZE);

            cursorSprite.visible = true;
            cursorSprite.setPosition(startX + (col * GRID_SIZE), 40 + (row * GRID_SIZE));

            // Quantized note placement based on active snap divider
            var snapDiv = snapList[curSnapIdx];
            var stepUnit = (16.0 / snapDiv);
            var quantizedRow = Math.round(row / stepUnit) * stepUnit;
            var noteTime = ((curSection * ROWS_PER_SECTION) + quantizedRow) * Conductor.stepCrochet;

            if (FlxG.mouse.justPressed) addNote(noteTime, col);
            if (FlxG.mouse.justPressedRight) deleteNote(noteTime, col);
            if (FlxG.mouse.wheel != 0) adjustSustain(noteTime, col, FlxG.mouse.wheel);
        } else {
            cursorSprite.visible = false;
        }
    }

    private function changeSnap(delta:Int):Void {
        curSnapIdx = FlxMath.wrap(curSnapIdx + delta, 0, snapList.length - 1);
        snapIndicatorTxt.text = 'SNAP: 1/${snapList[curSnapIdx]}';
        snapIndicatorTxt.color = snapColors[curSnapIdx];
        EditorToast.show('Quantization: 1/${snapList[curSnapIdx]} Beat Snap');
        AssetHelper.playSoundSafely("scrollMenu", 0.5);
    }

    private function adjustRate(delta:Float):Void {
        playbackSpeed = Math.max(0.25, Math.min(2.0, Math.round((playbackSpeed + delta) * 100) / 100));
        if (FlxG.sound.music != null) FlxG.sound.music.pitch = playbackSpeed;
        if (vocals != null) vocals.pitch = playbackSpeed;
        EditorToast.show('Playback Rate: ${playbackSpeed}x');
    }

    private function changeSection(change:Int):Void {
        curSection = Std.int(Math.max(0, curSection + change));
        while (curSection >= _song.notes.length) createSection();

        Conductor.songPosition = curSection * ROWS_PER_SECTION * Conductor.stepCrochet;
        if (FlxG.sound.music != null) FlxG.sound.music.time = Conductor.songPosition;
        if (vocals != null) vocals.time = Conductor.songPosition;

        var startX = (FlxG.width - (GRID_SIZE * STRUM_COLS)) * 0.5;
        curSectionMarker.setPosition(startX, 40);

        if (checkMustHit != null && _song.notes[curSection] != null) {
            checkMustHit.checked = _song.notes[curSection].mustHitSection;
        }
        refreshSectionNotes();
    }

    private function changeStep(change:Int):Void {
        curStepSelected = FlxMath.wrap(curStepSelected + change, 0, ROWS_PER_SECTION - 1);
        var startX = (FlxG.width - (GRID_SIZE * STRUM_COLS)) * 0.5;
        curSectionMarker.setPosition(startX, 40 + (curStepSelected * GRID_SIZE));

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
            if (FlxG.sound.music != null) FlxG.sound.music.pause();
            if (vocals != null) vocals.pause();
        }
    }

    private function addNote(time:Float, data:Int):Void {
        var sec = _song.notes[curSection];
        if (sec == null) return;
        for (n in sec.sectionNotes) if (Math.abs(n[0] - time) < 5 && n[1] == data) return;

        sec.sectionNotes.push([time, data, 0.0]);
        if (hitsoundsEnabled) AssetHelper.playSoundSafely("scrollMenu", 0.5);
        refreshSectionNotes();
    }

    private function deleteNote(time:Float, data:Int):Void {
        var sec = _song.notes[curSection];
        if (sec == null) return;
        for (i in 0...sec.sectionNotes.length) {
            if (Math.abs(sec.sectionNotes[i][0] - time) < 5 && sec.sectionNotes[i][1] == data) {
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

    private function flipCurrentSectionLanes():Void {
        var sec = _song.notes[curSection];
        if (sec == null) return;
        for (n in sec.sectionNotes) {
            n[1] = (Std.int(n[1]) + 4) % 8;
        }
        sec.mustHitSection = !sec.mustHitSection;
        if (checkMustHit != null) checkMustHit.checked = sec.mustHitSection;
        refreshSectionNotes();
        EditorToast.show("Flipped Section Strum Lanes!");
    }

    private function placeEventNode():Void {
        var eName = inputEventName.text.trim();
        var v1 = inputEventVal1.text.trim();
        var v2 = inputEventVal2.text.trim();
        var eTime = ((curSection * ROWS_PER_SECTION) + curStepSelected) * Conductor.stepCrochet;

        if (_song.events == null) _song.events = [];
        _song.events.push([eTime, [[eName, v1, v2]]]);
        refreshSectionNotes();
        EditorToast.show('Injected Event: $eName at ${Math.round(eTime)}ms');
    }

    private function refreshSectionNotes():Void {
        grpNotes.clear();
        grpSustains.clear();
        grpEvents.clear();

        var sec = _song.notes[curSection];
        if (sec == null) return;

        var startX = (FlxG.width - (GRID_SIZE * STRUM_COLS)) * 0.5;
        var noteColors = [0xFFC24B99, 0xFF00FFFF, 0xFF12FA05, 0xFFF9393F, 0xFFC24B99, 0xFF00FFFF, 0xFF12FA05, 0xFFF9393F];

        // 1. Render Section Notes & Sustains
        for (n in sec.sectionNotes) {
            var time:Float = n[0];
            var noteData:Int = Std.int(n[1]) % STRUM_COLS;
            var susLen:Float = n[2];

            var stepIdx = (time - (curSection * ROWS_PER_SECTION * Conductor.stepCrochet)) / Conductor.stepCrochet;
            var nx = startX + (noteData * GRID_SIZE);
            var ny = 40 + (stepIdx * GRID_SIZE);

            var noteSpr = new FlxSprite(nx + 2, ny + 2).makeGraphic(GRID_SIZE - 4, GRID_SIZE - 4, noteColors[noteData]);
            grpNotes.add(noteSpr);

            if (susLen > 0) {
                var susH = Std.int((susLen / Conductor.stepCrochet) * GRID_SIZE);
                var susSpr = new FlxSprite(nx + (GRID_SIZE * 0.35), ny + GRID_SIZE).makeGraphic(Std.int(GRID_SIZE * 0.3), susH, noteColors[noteData]);
                susSpr.alpha = 0.6;
                grpSustains.add(susSpr);
            }
        }

        // 2. Render Chart Events in current Section
        if (_song.events != null) {
            var secStart = curSection * ROWS_PER_SECTION * Conductor.stepCrochet;
            var secEnd = (curSection + 1) * ROWS_PER_SECTION * Conductor.stepCrochet;

            for (ev in _song.events) {
                var evTime:Float = ev[0];
                if (evTime >= secStart && evTime < secEnd) {
                    var evStep = (evTime - secStart) / Conductor.stepCrochet;
                    var evMarker = new FlxSprite(startX - 18, 40 + (evStep * GRID_SIZE)).makeGraphic(14, 14, EditorTheme.ACCENT_CYAN);
                    grpEvents.add(evMarker);
                }
            }
        }
    }

    private function copyCurrentSection():Void {
        var sec = _song.notes[curSection];
        if (sec != null) {
            copiedSection = {
                sectionNotes: [for (n in sec.sectionNotes) [n[0], n[1], n[2]]],
                mustHitSection: sec.mustHitSection,
                bpm: sec.bpm,
                changeBPM: sec.changeBPM,
                altAnim: sec.altAnim,
                lengthInSteps: sec.lengthInSteps
            };
            EditorToast.show("Section Data Copied!");
        }
    }

    private function pasteCurrentSection():Void {
        if (copiedSection != null && _song.notes[curSection] != null) {
            var sec = _song.notes[curSection];
            sec.sectionNotes = [];
            var timeOffset = curSection * ROWS_PER_SECTION * Conductor.stepCrochet;
            var baseTime = copiedSection.sectionNotes.length > 0 ? copiedSection.sectionNotes[0][0] : 0;

            for (n in copiedSection.sectionNotes) {
                sec.sectionNotes.push([timeOffset + (n[0] - baseTime), n[1], n[2]]);
            }
            refreshSectionNotes();
            EditorToast.show("Section Data Pasted!");
        }
    }

    private function clearCurrentSection():Void {
        var sec = _song.notes[curSection];
        if (sec != null) {
            sec.sectionNotes = [];
            refreshSectionNotes();
            EditorToast.show("Section Cleared!");
        }
    }

    private function updateInfoText():Void {
        var sec = _song.notes[curSection];
        infoTxt.text = 'SONG: ${curSong.toUpperCase()} [${curDifficulty.toUpperCase()}]\n' +
            'BPM: ${_song.bpm} | SPEED: ${_song.speed}\n' +
            'SECTION: $curSection / ${_song.notes.length - 1}\n' +
            'RATE: ${playbackSpeed}x | STEP: $curStepSelected\n' +
            'FOCUS: ${(sec != null && sec.mustHitSection) ? "Boyfriend" : "Opponent"}';
    }

    private function saveChartJson():Void {
        var formatted = Json.stringify({song: _song}, "\t");
        var fileName = curSong.toLowerCase().trim() + (curDifficulty == "normal" ? "" : '-$curDifficulty') + ".json";

        #if sys
        var targetDir = 'assets/data/${curSong.toLowerCase().trim()}';
        if (ModManager.activeMods != null && ModManager.activeMods.length > 0) targetDir = 'mods/${ModManager.activeMods[0]}/data/${curSong.toLowerCase().trim()}';
        var fullPath = '$targetDir/$fileName';

        try {
            if (!FileSystem.exists(targetDir)) FileSystem.createDirectory(targetDir);
            File.saveContent(fullPath, formatted);
            EditorToast.show("Mania Chart Exported Successfully!");
            AssetHelper.playSoundSafely("confirmMenu", 0.7);
        } catch (e:Dynamic) {
            EditorToast.show("Save Failed!", true);
        }
        #else
        var fileRef = new FileReference();
        fileRef.save(formatted, fileName);
        EditorToast.show("Chart File Exported!");
        #end
    }
}