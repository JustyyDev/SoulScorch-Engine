package soulscorch.ui.menus.editors;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import haxe.Json;
import openfl.geom.Rectangle;
import openfl.media.Sound;
import openfl.net.FileReference;
import openfl.utils.ByteArray;
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
    public static inline var ROWS_PER_SECTION:Int = 16;
    public static inline var VISIBLE_SECTIONS:Int = 4;

    public var keyCount:Int = 4;
    public var totalCols:Int = 8;

    private var gridCanvas:FlxSpriteGroup;
    private var curSectionMarker:FlxSprite;
    private var playheadMarker:FlxSprite;
    private var cursorSprite:FlxSprite;

    // --- Audio Waveform Visualizers ---
    private var waveformSpriteInst:FlxSprite;
    private var waveformSpriteVocals:FlxSprite;
    private var rawInstSound:Sound;
    private var rawVocalsSound:Sound;

    // --- Object Pooling Pipelines ---
    private var grpNotes:FlxTypedGroup<FlxSprite>;
    private var grpSustains:FlxTypedGroup<FlxSprite>;
    private var grpEvents:FlxTypedGroup<FlxSprite>;
    private var grpEventLabels:FlxTypedGroup<FlxText>;

    private var vocals:FlxSound;
    private var curSection:Int = 0;
    private var curStepSelected:Int = 0;
    private var isPlaying:Bool = false;
    private var playbackSpeed:Float = 1.0;
    private var metronomeEnabled:Bool = false;
    private var hitsoundsEnabled:Bool = true;

    // --- Selection Box & Multi-Selection ---
    private var selectionBox:FlxSprite;
    private var isBoxSelecting:Bool = false;
    private var boxStartPoint:FlxPoint;
    private var selectedNotes:Array<Array<Dynamic>> = [];

    // --- Undo / Redo History Stack ---
    private var undoStack:Array<String> = [];
    private var redoStack:Array<String> = [];
    private static inline var MAX_UNDO_DEPTH:Int = 40;

    // --- Mania Snapping Matrix ---
    private var snapList:Array<Int> = [4, 8, 12, 16, 24, 32, 48, 64];
    private var snapColors:Array<FlxColor> = [
        0xFFFF0055, 0xFF00AAFF, 0xFFAA00FF, 0xFFFFD700,
        0xFFFF69B4, 0xFFFFA500, 0xFF00FFFF, 0xFF00FF66
    ];
    private var curSnapIdx:Int = 3;

    // --- UI Toolboxes ---
    private var topBar:EditorTopBar;
    private var songPropsWindow:EditorWindow;
    private var sectionToolsWindow:EditorWindow;
    private var eventMasterWindow:EditorWindow;
    private var maniaToolWindow:EditorWindow;

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
    private var noteSkinAtlas:FlxAtlasFrames;

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

        noteSkinAtlas = NoteSkinManager.getSkinAtlas("NOTE_assets");
        boxStartPoint = FlxPoint.get(0, 0);

        loadChart();

        var bg = new FlxSprite().makeGraphic(FlxG.width * 2, FlxG.height * 4, EditorTheme.BG_DARK);
        bg.screenCenter();
        bg.scrollFactor.set(0, 0);
        add(bg);

        gridCanvas = new FlxSpriteGroup();
        add(gridCanvas);

        waveformSpriteInst = new FlxSprite(0, 0);
        add(waveformSpriteInst);

        waveformSpriteVocals = new FlxSprite(0, 0);
        add(waveformSpriteVocals);

        createMultiSectionGrid();

        grpSustains = new FlxTypedGroup<FlxSprite>();
        add(grpSustains);

        grpNotes = new FlxTypedGroup<FlxSprite>();
        add(grpNotes);

        grpEvents = new FlxTypedGroup<FlxSprite>();
        add(grpEvents);

        grpEventLabels = new FlxTypedGroup<FlxText>();
        add(grpEventLabels);

        cursorSprite = new FlxSprite().makeGraphic(GRID_SIZE, GRID_SIZE, 0x4400FFCC);
        cursorSprite.visible = false;
        add(cursorSprite);

        selectionBox = new FlxSprite().makeGraphic(1, 1, 0x3300FFFF);
        selectionBox.visible = false;
        add(selectionBox);

        playheadMarker = new FlxSprite(0, 0).makeGraphic(GRID_SIZE * totalCols, 3, 0xFFFFFFFF);
        add(playheadMarker);

        loadAudio();
        generateWaveforms();
        setupWindows();

        pushUndoSnapshot();
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

        keyCount = Reflect.hasField(_song, "keyCount") ? Std.int(Reflect.field(_song, "keyCount")) : 4;
        totalCols = keyCount * 2;

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

        var gridW = GRID_SIZE * totalCols;
        var gridH = GRID_SIZE * ROWS_PER_SECTION * VISIBLE_SECTIONS;
        var startX = (FlxG.width - gridW) * 0.5;

        // Waveform gutters
        waveformSpriteInst.setPosition(startX - 26, 40);
        waveformSpriteVocals.setPosition(startX + gridW + 8, 40);

        var bg = new FlxSprite(startX, 40).makeGraphic(gridW, gridH, EditorTheme.GRID_EVEN);
        gridCanvas.add(bg);

        for (row in 0...(ROWS_PER_SECTION * VISIBLE_SECTIONS)) {
            for (col in 0...totalCols) {
                var isEven = (row + col) % 2 == 0;
                var color:FlxColor = isEven ? EditorTheme.GRID_EVEN : EditorTheme.GRID_ODD;
                if (col == keyCount) color = EditorTheme.GRID_SEPARATOR;

                var cell = new FlxSprite(startX + (col * GRID_SIZE), 40 + (row * GRID_SIZE)).makeGraphic(GRID_SIZE - 1, GRID_SIZE - 1, color);
                gridCanvas.add(cell);
            }

            if (row % 4 == 0) {
                var beatLine = new FlxSprite(startX, 40 + (row * GRID_SIZE)).makeGraphic(gridW, 2, EditorTheme.ACCENT_PURPLE);
                gridCanvas.add(beatLine);
            }
        }

        for (s in 0...VISIBLE_SECTIONS) {
            var sectionSep = new FlxSprite(startX, 40 + (s * ROWS_PER_SECTION * GRID_SIZE)).makeGraphic(gridW, 3, EditorTheme.ACCENT_MAGENTA);
            gridCanvas.add(sectionSep);
        }

        curSectionMarker = new FlxSprite(startX, 40).makeGraphic(gridW, 4, EditorTheme.ACCENT_CYAN);
        gridCanvas.add(curSectionMarker);
        playheadMarker.setPosition(startX, 40);
    }

    private function loadAudio():Void {
        var instSound = Paths.inst(curSong);
        if (instSound != null) {
            rawInstSound = instSound;
            FlxG.sound.playMusic(instSound, 0, false);
            if (FlxG.sound.music != null) FlxG.sound.music.pause();
        }

        var voiceSound = Paths.voices(curSong);
        if (voiceSound != null) {
            rawVocalsSound = voiceSound;
            vocals = new FlxSound().loadEmbedded(voiceSound);
            FlxG.sound.list.add(vocals);
        }
    }

    private function generateWaveforms():Void {
        var gridH = GRID_SIZE * ROWS_PER_SECTION * VISIBLE_SECTIONS;
        waveformSpriteInst.makeGraphic(18, gridH, FlxColor.TRANSPARENT);
        waveformSpriteVocals.makeGraphic(18, gridH, FlxColor.TRANSPARENT);

        var secStart = curSection * ROWS_PER_SECTION * Conductor.stepCrochet;
        var totalSecDur = (VISIBLE_SECTIONS * ROWS_PER_SECTION * Conductor.stepCrochet);

        for (y in 0...gridH) {
            var progress = y / gridH;
            var sampleTime = secStart + (progress * totalSecDur);
            var ampInst = Math.abs(Math.sin(sampleTime * 0.02) * Math.cos(sampleTime * 0.005));
            var barW = Std.int(ampInst * 16);

            for (x in 0...barW) {
                waveformSpriteInst.pixels.setPixel32(x, y, 0xFF00FFCC);
            }
        }
        waveformSpriteInst.dirty = true;
    }

    private function setupWindows():Void {
        topBar = new EditorTopBar('SOULSCORCH CHART STUDIO PRO // [${curSong.toUpperCase()}]');
        topBar.cameras = [camHUD];
        topBar.addAction("Save (Ctrl+S)", saveChartJson);
        topBar.addAction("Undo (Ctrl+Z)", undo);
        topBar.addAction("Redo (Ctrl+Y)", redo);
        topBar.addAction("Export Formats", exportFormatMenu);
        topBar.addAction("Exit", function() {
            if (FlxG.sound.music != null) FlxG.sound.music.stop();
            if (vocals != null) vocals.stop();
            MusicBeatState.switchState(new MainMenuState());
        });
        add(topBar);

        // --- 1. Song & Metronome Window ---
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
            generateWaveforms();
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

        // --- 2. Mania Key Scaling Tool ---
        maniaToolWindow = new EditorWindow(15, 395, 300, 170, "Mania Key Matrix");
        maniaToolWindow.cameras = [camHUD];
        add(maniaToolWindow);

        var stepperKeys = new EditorNumericStepper(10, 8, 280, "Key Count (1K - 9K)", keyCount, 1, 9, 1, 0, function(v) {
            changeKeyCount(Std.int(v));
        });
        maniaToolWindow.addElement(stepperKeys);

        var btnNormalize = new EditorButton(10, 52, 280, 26, "Auto-Quantize Section", autoQuantizeSection);
        maniaToolWindow.addElement(btnNormalize);

        var btnMirror = new EditorButton(10, 84, 280, 26, "Mirror Section Pattern", mirrorSectionPattern);
        maniaToolWindow.addElement(btnMirror);

        // --- 3. Section Utilities Window ---
        sectionToolsWindow = new EditorWindow(FlxG.width - 315, 45, 300, 210, "Section Utilities");
        sectionToolsWindow.cameras = [camHUD];
        add(sectionToolsWindow);

        checkMustHit = new EditorCheckbox(10, 4, "Must Hit (BF Focus)", _song.notes[curSection] != null && _song.notes[curSection].mustHitSection, function(checked) {
            if (_song.notes[curSection] != null) {
                pushUndoSnapshot();
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

        // --- 4. Event Automator Window ---
        eventMasterWindow = new EditorWindow(FlxG.width - 315, 265, 300, 270, "Event Automator");
        eventMasterWindow.cameras = [camHUD];
        add(eventMasterWindow);

        inputEventName = new EditorInputText(10, 4, 280, "Event Name", "Camera Zoom");
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
            updateAudioPlayback(elapsed);
        } else {
            handleNavigationInput();
            handleMouseInput();
            handleMarqueeSelection();
        }

        if (FlxG.keys.justPressed.SPACE) togglePlayback();
        if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.S) saveChartJson();
        if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.Z) undo();
        if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.Y) redo();
        if (FlxG.keys.justPressed.ESCAPE) {
            if (FlxG.sound.music != null) FlxG.sound.music.stop();
            if (vocals != null) vocals.stop();
            MusicBeatState.switchState(new MainMenuState());
        }

        updateInfoText();
    }

    private function updateAudioPlayback(elapsed:Float):Void {
        if (FlxG.sound.music == null || !FlxG.sound.music.playing) return;
        Conductor.songPosition = FlxG.sound.music.time;

        if (vocals != null && Math.abs(vocals.time - FlxG.sound.music.time) > 20) {
            vocals.time = FlxG.sound.music.time;
        }

        var totalSteps = Math.floor(Conductor.songPosition / Conductor.stepCrochet);
        var targetSection = Math.floor(totalSteps / ROWS_PER_SECTION);

        if (targetSection != curSection && targetSection < _song.notes.length) {
            curSection = targetSection;
            generateWaveforms();
            refreshSectionNotes();
        }

        var stepInSection = (Conductor.songPosition / Conductor.stepCrochet) % ROWS_PER_SECTION;
        var startX = (FlxG.width - (GRID_SIZE * totalCols)) * 0.5;
        playheadMarker.setPosition(startX, 40 + (stepInSection * GRID_SIZE));

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
        if (FlxG.keys.justPressed.E) changeSection(1);
        if (FlxG.keys.justPressed.Q) changeSection(-1);
        if (FlxG.keys.justPressed.W) changeStep(-1);
        if (FlxG.keys.justPressed.S) changeStep(1);

        if (FlxG.keys.justPressed.RIGHT) changeSnap(1);
        if (FlxG.keys.justPressed.LEFT) changeSnap(-1);

        if (FlxG.keys.justPressed.A) adjustRate(-0.25);
        if (FlxG.keys.justPressed.D) adjustRate(0.25);

        if (FlxG.keys.justPressed.TAB) flipCurrentSectionLanes();

        if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.C) copyCurrentSection();
        if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.V) pasteCurrentSection();
    }

    private function handleMouseInput():Void {
        var startX = (FlxG.width - (GRID_SIZE * totalCols)) * 0.5;
        var gridW = GRID_SIZE * totalCols;
        var gridH = GRID_SIZE * ROWS_PER_SECTION;

        var mx = FlxG.mouse.x;
        var my = FlxG.mouse.y;

        if (mx >= startX && mx < startX + gridW && my >= 40 && my < 40 + gridH) {
            var col = Math.floor((mx - startX) / GRID_SIZE);
            var row = Math.floor((my - 40) / GRID_SIZE);

            cursorSprite.visible = true;
            cursorSprite.setPosition(startX + (col * GRID_SIZE), 40 + (row * GRID_SIZE));

            var snapDiv = snapList[curSnapIdx];
            var stepUnit = (16.0 / snapDiv);
            var quantizedRow = Math.round(row / stepUnit) * stepUnit;
            var noteTime = ((curSection * ROWS_PER_SECTION) + quantizedRow) * Conductor.stepCrochet;

            if (FlxG.mouse.justPressed && !FlxG.keys.pressed.SHIFT) addNote(noteTime, col);
            if (FlxG.mouse.justPressedRight) deleteNote(noteTime, col);
            if (FlxG.mouse.wheel != 0) adjustSustain(noteTime, col, FlxG.mouse.wheel);
        } else {
            cursorSprite.visible = false;
        }
    }

    private function handleMarqueeSelection():Void {
        var startX = (FlxG.width - (GRID_SIZE * totalCols)) * 0.5;

        if (FlxG.keys.pressed.SHIFT && FlxG.mouse.justPressed) {
            isBoxSelecting = true;
            boxStartPoint.set(FlxG.mouse.x, FlxG.mouse.y);
            selectionBox.visible = true;
        }

        if (isBoxSelecting) {
            var boxX = Math.min(boxStartPoint.x, FlxG.mouse.x);
            var boxY = Math.min(boxStartPoint.y, FlxG.mouse.y);
            var boxW = Math.abs(FlxG.mouse.x - boxStartPoint.x);
            var boxH = Math.abs(FlxG.mouse.y - boxStartPoint.y);

            selectionBox.setPosition(boxX, boxY);
            selectionBox.setGraphicSize(Std.int(Math.max(1, boxW)), Std.int(Math.max(1, boxH)));
            selectionBox.updateHitbox();

            if (FlxG.mouse.justReleased) {
                isBoxSelecting = false;
                selectionBox.visible = false;

                var selectedBounds = new Rectangle(boxX, boxY, boxW, boxH);
                selectedNotes = [];
                var sec = _song.notes[curSection];
                if (sec != null) {
                    for (n in sec.sectionNotes) {
                        var stepIdx = (n[0] - (curSection * ROWS_PER_SECTION * Conductor.stepCrochet)) / Conductor.stepCrochet;
                        var nx = startX + (Std.int(n[1]) * GRID_SIZE);
                        var ny = 40 + (stepIdx * GRID_SIZE);
                        if (selectedBounds.contains(nx + 10, ny + 10)) {
                            selectedNotes.push(n);
                        }
                    }
                }
                EditorToast.show('Selected ${selectedNotes.length} notes.');
            }
        }
    }

    private function changeKeyCount(newKeyCount:Int):Void {
        pushUndoSnapshot();
        keyCount = Std.int(Math.max(1, Math.min(9, newKeyCount)));
        totalCols = keyCount * 2;
        Reflect.setField(_song, "keyCount", keyCount);
        createMultiSectionGrid();
        refreshSectionNotes();
        EditorToast.show('Matrix scaled to ${keyCount}K (${totalCols} Strum Columns)');
    }

    private function pushUndoSnapshot():Void {
        var snapshot = Json.stringify({song: _song});
        undoStack.push(snapshot);
        if (undoStack.length > MAX_UNDO_DEPTH) undoStack.shift();
        redoStack = [];
    }

    private function undo():Void {
        if (undoStack.length <= 1) {
            EditorToast.show("No more undos available.", true);
            return;
        }
        var current = undoStack.pop();
        redoStack.push(current);
        var prev = undoStack[undoStack.length - 1];
        var parsed:Dynamic = Json.parse(prev);
        _song = parsed.song;
        refreshSectionNotes();
        generateWaveforms();
        EditorToast.show("Undone last action.");
    }

    private function redo():Void {
        if (redoStack.length == 0) {
            EditorToast.show("No redos available.", true);
            return;
        }
        var next = redoStack.pop();
        undoStack.push(next);
        var parsed:Dynamic = Json.parse(next);
        _song = parsed.song;
        refreshSectionNotes();
        generateWaveforms();
        EditorToast.show("Redone action.");
    }

    private function autoQuantizeSection():Void {
        pushUndoSnapshot();
        var sec = _song.notes[curSection];
        if (sec == null) return;
        var snapDiv = snapList[curSnapIdx];
        var stepUnit = (16.0 / snapDiv);

        for (n in sec.sectionNotes) {
            var stepRel = (n[0] - (curSection * ROWS_PER_SECTION * Conductor.stepCrochet)) / Conductor.stepCrochet;
            var quantized = Math.round(stepRel / stepUnit) * stepUnit;
            n[0] = ((curSection * ROWS_PER_SECTION) + quantized) * Conductor.stepCrochet;
        }
        refreshSectionNotes();
        EditorToast.show("Quantized section notes!");
    }

    private function mirrorSectionPattern():Void {
        pushUndoSnapshot();
        var sec = _song.notes[curSection];
        if (sec == null) return;

        for (n in sec.sectionNotes) {
            var lane = Std.int(n[1]);
            if (lane < keyCount) {
                n[1] = (keyCount - 1) - lane;
            } else {
                var oppLane = lane - keyCount;
                n[1] = keyCount + ((keyCount - 1) - oppLane);
            }
        }
        refreshSectionNotes();
        EditorToast.show("Mirrored pattern!");
    }

    private function exportFormatMenu():Void {
        #if sys
        var exportDir = 'assets/data/${curSong.toLowerCase().trim()}';
        if (!FileSystem.exists(exportDir)) FileSystem.createDirectory(exportDir);

        // 1. Export Osu!Mania .osu format
        var osuData = '[General]\nAudioFilename: Inst.ogg\nMode: 3\n\n[Difficulty]\nCircleSize: $keyCount\nOverallDifficulty: ${_song.speed * 3}\n\n[HitObjects]\n';
        for (sec in _song.notes) {
            for (n in sec.sectionNotes) {
                if (n[1] < keyCount) {
                    var xPos = Math.floor((n[1] * (512 / keyCount)) + (256 / keyCount));
                    osuData += '$xPos,192,${Math.round(n[0])},1,0,0:0:0:0:\n';
                }
            }
        }
        File.saveContent('$exportDir/${curSong}_mania.osu', osuData);
        EditorToast.show("Exported to Osu!Mania .osu format!");
        #else
        saveChartJson();
        #end
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

        var startX = (FlxG.width - (GRID_SIZE * totalCols)) * 0.5;
        curSectionMarker.setPosition(startX, 40);
        playheadMarker.setPosition(startX, 40);

        if (checkMustHit != null && _song.notes[curSection] != null) {
            checkMustHit.checked = _song.notes[curSection].mustHitSection;
        }
        generateWaveforms();
        refreshSectionNotes();
    }

    private function changeStep(change:Int):Void {
        curStepSelected = FlxMath.wrap(curStepSelected + change, 0, ROWS_PER_SECTION - 1);
        var startX = (FlxG.width - (GRID_SIZE * totalCols)) * 0.5;
        curSectionMarker.setPosition(startX, 40 + (curStepSelected * GRID_SIZE));
        playheadMarker.setPosition(startX, 40 + (curStepSelected * GRID_SIZE));

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

        pushUndoSnapshot();
        sec.sectionNotes.push([time, data, 0.0]);
        if (hitsoundsEnabled) AssetHelper.playSoundSafely("scrollMenu", 0.5);
        refreshSectionNotes();
    }

    private function deleteNote(time:Float, data:Int):Void {
        var sec = _song.notes[curSection];
        if (sec == null) return;
        for (i in 0...sec.sectionNotes.length) {
            if (Math.abs(sec.sectionNotes[i][0] - time) < 5 && sec.sectionNotes[i][1] == data) {
                pushUndoSnapshot();
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
                pushUndoSnapshot();
                n[2] = Math.max(0, n[2] + (change * Conductor.stepCrochet));
                break;
            }
        }
        refreshSectionNotes();
    }

    private function flipCurrentSectionLanes():Void {
        var sec = _song.notes[curSection];
        if (sec == null) return;
        pushUndoSnapshot();
        for (n in sec.sectionNotes) {
            n[1] = (Std.int(n[1]) + keyCount) % totalCols;
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

        pushUndoSnapshot();
        if (_song.events == null) _song.events = [];
        _song.events.push([eTime, [[eName, v1, v2]]]);
        refreshSectionNotes();
        EditorToast.show('Injected Event: $eName at ${Math.round(eTime)}ms');
    }

    private function refreshSectionNotes():Void {
        grpNotes.forEachAlive(function(spr:FlxSprite) spr.kill());
        grpSustains.forEachAlive(function(spr:FlxSprite) spr.kill());
        grpEvents.forEachAlive(function(spr:FlxSprite) spr.kill());
        grpEventLabels.forEachAlive(function(txt:FlxText) txt.kill());

        var sec = _song.notes[curSection];
        if (sec == null) return;

        var startX = (FlxG.width - (GRID_SIZE * totalCols)) * 0.5;
        var dirNames:Array<String> = ["purple", "blue", "green", "red", "purple", "blue", "green", "red"];

        for (n in sec.sectionNotes) {
            var time:Float = n[0];
            var noteData:Int = Std.int(n[1]) % totalCols;
            var susLen:Float = n[2];

            var stepIdx = (time - (curSection * ROWS_PER_SECTION * Conductor.stepCrochet)) / Conductor.stepCrochet;
            var nx = startX + (noteData * GRID_SIZE);
            var ny = 40 + (stepIdx * GRID_SIZE);

            var noteSpr:FlxSprite = grpNotes.recycle(FlxSprite);
            if (noteSkinAtlas != null) {
                noteSpr.frames = noteSkinAtlas;
                var color = dirNames[noteData % 4];
                noteSpr.animation.addByPrefix("idle", color + "0", 24, false);
                noteSpr.animation.play("idle");
                noteSpr.setGraphicSize(GRID_SIZE - 4, GRID_SIZE - 4);
                noteSpr.updateHitbox();
            } else {
                noteSpr.makeGraphic(GRID_SIZE - 4, GRID_SIZE - 4, FlxColor.WHITE);
            }
            noteSpr.setPosition(nx + 2, ny + 2);
            noteSpr.alpha = 1.0;
            grpNotes.add(noteSpr);

            if (susLen > 0) {
                var susH = Std.int((susLen / Conductor.stepCrochet) * GRID_SIZE);
                var susSpr:FlxSprite = grpSustains.recycle(FlxSprite);
                var color = dirNames[noteData % 4];

                if (noteSkinAtlas != null) {
                    susSpr.frames = noteSkinAtlas;
                    susSpr.animation.addByPrefix("hold", color + " hold piece0", 24, true);
                    susSpr.animation.play("hold");
                    susSpr.setGraphicSize(Std.int(GRID_SIZE * 0.35), susH);
                    susSpr.updateHitbox();
                } else {
                    susSpr.makeGraphic(Std.int(GRID_SIZE * 0.35), susH, FlxColor.WHITE);
                }
                susSpr.setPosition(nx + (GRID_SIZE * 0.325), ny + GRID_SIZE);
                susSpr.alpha = 0.6;
                grpSustains.add(susSpr);
            }
        }

        if (_song.events != null) {
            var secStart = curSection * ROWS_PER_SECTION * Conductor.stepCrochet;
            var secEnd = (curSection + 1) * ROWS_PER_SECTION * Conductor.stepCrochet;

            for (ev in _song.events) {
                var evTime:Float = ev[0];
                if (evTime >= secStart && evTime < secEnd) {
                    var evStep = (evTime - secStart) / Conductor.stepCrochet;
                    var evMarker:FlxSprite = grpEvents.recycle(FlxSprite);
                    evMarker.makeGraphic(14, 14, EditorTheme.ACCENT_CYAN);
                    evMarker.setPosition(startX - 18, 40 + (evStep * GRID_SIZE));
                    grpEvents.add(evMarker);

                    var label:FlxText = grpEventLabels.recycle(FlxText);
                    var evArr:Array<Dynamic> = ev[1];
                    var evName:String = (evArr != null && evArr.length > 0) ? Std.string(evArr[0][0]) : "Event";
                    label.text = evName;
                    label.setFormat(Paths.font("vcr"), 10, EditorTheme.ACCENT_CYAN, RIGHT);
                    label.setPosition(startX - 150, 40 + (evStep * GRID_SIZE));
                    grpEventLabels.add(label);
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
            pushUndoSnapshot();
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
            pushUndoSnapshot();
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
            'KEYS: ${keyCount}K | FOCUS: ${(sec != null && sec.mustHitSection) ? "Boyfriend" : "Opponent"}';
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

    override public function destroy():Void {
        if (boxStartPoint != null) {
            boxStartPoint.put();
            boxStartPoint = null;
        }
        super.destroy();
    }
}