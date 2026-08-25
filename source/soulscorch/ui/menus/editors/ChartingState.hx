package soulscorch.ui.menus.editors;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxSort;
import flixel.graphics.frames.FlxAtlasFrames;
import haxe.Json;
import openfl.display.BitmapData;
import openfl.geom.Rectangle;
import openfl.net.FileReference;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.system.modules.discord.DiscordRPC;
import soulscorch.backend.utils.Logger;
import soulscorch.gameplay.PlayState;
import soulscorch.gameplay.chart.Chart;
import soulscorch.gameplay.chart.Song;
import soulscorch.gameplay.chart.events.EventManager;
import soulscorch.gameplay.chart.events.EventMarker;
import soulscorch.gameplay.chart.events.SongEvents;
import soulscorch.gameplay.notes.Note;
import soulscorch.gameplay.notes.NoteSkinManager;
import soulscorch.gameplay.notes.StrumArrow;
import soulscorch.gameplay.song.SongLoader;
import soulscorch.scripting.mod.ModManager;
import soulscorch.ui.menus.editors.editorui.*;
import soulscorch.ui.menus.states.MainMenuState;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

typedef ChartEditorNote = {
    var time:Float;
    var lane:Int;
    var sustainLength:Float;
    var type:String;
    var mustPress:Bool;
}

typedef ChartEditorEvent = {
    var time:Float;
    var name:String;
    var val1:String;
    var val2:String;
}

class ChartingState extends MusicBeatState {
    public static var curSongName:String = "tutorial";
    public static var curDifficultyName:String = "normal";

    private var camEditor:FlxCamera;
    private var camUI:FlxCamera;

    // --- Audio System ---
    private var inst:FlxSound;
    private var vocals:FlxSound;
    private var isPlaying:Bool = false;
    private var playbackRate:Float = 1.0;
    private var hitsoundsEnabled:Bool = true;
    private var playedHitsounds:Map<Int, Bool> = new Map<Int, Bool>();

    // --- Grid Metrics & Lanes ---
    public static inline var GRID_SIZE:Int = 40;
    public static inline var STEPS_PER_SECTION:Int = 16;
    public var currentTotalLanes:Int = 8; // Scalable strumline channels

    private var curSection:Int = 0;
    private var curSelectedNote:ChartEditorNote = null;
    private var curSelectedEvent:ChartEditorEvent = null;
    private var activeQuantization:Int = 16;

    // --- Visual Layers ---
    private var gridBG:FlxSprite;
    private var gridGroup:FlxSpriteGroup;
    private var renderedNotesGroup:FlxTypedGroup<FlxSprite>;
    private var sustainNotesGroup:FlxTypedGroup<FlxSprite>;
    private var renderedEventsGroup:FlxTypedGroup<FlxSprite>;
    private var laneHeaderGroup:FlxTypedGroup<FlxText>;
    private var beatLabelGroup:FlxTypedGroup<FlxText>;
    private var receptorGroup:FlxSpriteGroup;
    private var gridCursor:FlxSprite;
    private var sectionIndicator:FlxSprite;
    private var strumLine:FlxSprite;
    private var camFollow:FlxObject;

    // --- Cached Note Assets (real note graphics) ---
    private static var _cachedGridBitmap:BitmapData = null;
    private static var _noteAtlas:FlxAtlasFrames = null;
    private static var _eventMarker:FlxSprite = null;

    // --- Chart Data ---
    private var songData:Song;
    private var chartNotes:Array<ChartEditorNote> = [];
    private var chartEvents:Array<ChartEditorEvent> = [];
    private var undoStack:Array<String> = [];
    private var redoStack:Array<String> = [];
    private var sectionClipboardNotes:Array<ChartEditorNote> = [];
    private var sectionClipboardEvents:Array<ChartEditorEvent> = [];
    private static inline var MAX_UNDO_DEPTH:Int = 50;
    private static inline var AUTOSAVE_INTERVAL:Float = 45.0;
    private var autosaveTimer:Float = 0.0;
    private var dirtySinceAutosave:Bool = false;

    // --- UI Modals & Panels ---
    private var topBar:EditorTopBar;
    private var songPropertiesWindow:EditorWindow;
    private var sectionWindow:EditorWindow;
    private var metadataWindow:EditorWindow;
    private var eventConfigWindow:EditorWindow;
    private var songPickerModal:EditorWindow;

    private var stepperBPM:EditorNumericStepper;
    private var stepperSpeed:EditorNumericStepper;
    private var stepperSustain:EditorNumericStepper;
    private var checkHitsounds:EditorCheckbox;
    private var infoText:FlxText;
    private var statsText:FlxText;
    private var sectionOverviewText:FlxText;
    private var btnQuantization:EditorButton;
    private var btnPlaybackRate:EditorButton;

    // Metadata Fields
    private var inputPlayer1:EditorInputText;
    private var inputPlayer2:EditorInputText;
    private var inputGF:EditorInputText;
    private var inputStage:EditorInputText;
    private var inputDifficulty:EditorInputText;

    // Event Fields
    private var inputEventName:EditorInputText;
    private var inputEventVal1:EditorInputText;
    private var inputEventVal2:EditorInputText;
    private var eventDescText:FlxText;

    // Note Type Selector
    private var currentNoteType:String = "normal";
    private var noteTypes:Array<String> = ["normal", "Hurt Note", "Mine", "Instakill", "No Animation", "Alt Animation"];
    private var curNoteTypeIdx:Int = 0;
    private var btnCycleType:EditorButton;

    public function new(?songId:String = "tutorial", ?difficulty:String = "normal") {
        super();
        if (songId != null && songId.length > 0) curSongName = songId;
        if (difficulty != null && difficulty.length > 0) curDifficultyName = difficulty;
    }

    override public function create():Void {
        super.create();

        #if desktop
        DiscordRPC.changePresence("Chart Studio Ultra", 'Composing: ${curSongName.toUpperCase()} [${curDifficultyName.toUpperCase()}]');
        #end

        setupCameras();
        setupAudio();
        loadChartData(curSongName, curDifficultyName);

        var vignette = EditorTheme.makeVignette(FlxG.width, FlxG.height);
        vignette.scrollFactor.set(0, 0);
        vignette.cameras = [camEditor];
        add(vignette);

        buildPrecachedGraphics();
        rebuildGridGraphics();
        createReceptorsAndIndicators();
        setupUI();
        buildSongPickerModal();

        pushUndoSnapshot();
        updateSectionView();
        updateDisplayInfo();

        add(new EditorToast());
        FlxG.mouse.visible = true;
    }

    override public function setupCameras():Void {
        camEditor = new FlxCamera();
        camUI = new FlxCamera();
        camUI.bgColor = FlxColor.TRANSPARENT;

        FlxG.cameras.reset(camEditor);
        FlxG.cameras.add(camUI, false);
        FlxG.cameras.setDefaultDrawTarget(camEditor, true);

        camFollow = new FlxObject(0, 0, 1, 1);
        add(camFollow);
        camEditor.follow(camFollow, LOCKON, 0.2);
    }

    private function setupAudio():Void {
        if (FlxG.sound.music != null) {
            FlxTween.cancelTweensOf(FlxG.sound.music);
            FlxG.sound.music.stop();
            FlxG.sound.music = null;
        }

        var instSound = Paths.inst(curSongName);
        if (instSound != null) {
            inst = new FlxSound().loadEmbedded(instSound);
            FlxG.sound.list.add(inst);
        }

        var vocalSound = Paths.voices(curSongName);
        if (vocalSound != null) {
            vocals = new FlxSound().loadEmbedded(vocalSound);
            FlxG.sound.list.add(vocals);
        }
    }

    private function loadChartData(songId:String, difficulty:String):Void {
        chartNotes = [];
        chartEvents = [];
        songData = SongLoader.load(songId, difficulty);

        if (songData != null && songData.chart != null) {
            Conductor.changeBPM(songData.bpm > 0 ? songData.bpm : 120.0);
            Conductor.mapBpmChanges(songData.chart);

            for (n in songData.chart.notes) {
                var laneIdx = n.mustPress ? (n.direction % 4) + 4 : (n.direction % 4);
                chartNotes.push({
                    time: n.time,
                    lane: laneIdx,
                    sustainLength: n.sustainLength,
                    type: (n.type != null && n.type.length > 0) ? n.type : "normal",
                    mustPress: n.mustPress
                });
            }

            if (songData.chart.events != null) {
                for (e in songData.chart.events) {
                    chartEvents.push({
                        time: e.time,
                        name: e.name,
                        val1: e.val1 != null ? Std.string(e.val1) : "",
                        val2: e.val2 != null ? Std.string(e.val2) : ""
                    });
                }
            }
        } else {
            songData = new Song(songId, songId);
            songData.bpm = 120.0;
            songData.scrollSpeed = 2.0;
            songData.player1 = "bf";
            songData.player2 = "dad";
            songData.gfVersion = "gf";
            songData.stage = "stage";
            songData.chart = new Chart(120.0, 2.0);
            Conductor.changeBPM(120.0);
        }
    }

    private function buildPrecachedGraphics():Void {
        if (_noteAtlas != null) return;

        // Load the real note skin atlas (falls back to NOTE_assets)
        _noteAtlas = NoteSkinManager.getSkinAtlas(NoteSkinManager.defaultSkin);
        if (_noteAtlas == null) _noteAtlas = Paths.getSparrowAtlas("ui/game/notes/NOTE_assets");
        if (_noteAtlas == null) _noteAtlas = Paths.getSparrowAtlas("NOTE_assets");

        // Glowing event-node marker
        _eventMarker = EditorTheme.makeEventMarker(GRID_SIZE);
    }

    private function rebuildGridGraphics():Void {
        if (gridGroup != null) {
            remove(gridGroup, true);
            gridGroup.destroy();
        }
        if (beatLabelGroup != null) {
            remove(beatLabelGroup, true);
            beatLabelGroup.destroy();
            beatLabelGroup = null;
        }

        var totalCols = currentTotalLanes + 1;
        var totalGridW = totalCols * GRID_SIZE;
        var gridX = (FlxG.width * 0.5) - (totalGridW * 0.5);

        gridGroup = new FlxSpriteGroup(gridX, GRID_SIZE);
        add(gridGroup);

        _cachedGridBitmap = new BitmapData(totalGridW, STEPS_PER_SECTION * GRID_SIZE, true, 0x0);

        for (col in 0...totalCols) {
            for (row in 0...STEPS_PER_SECTION) {
                var isEven = (col + row) % 2 == 0;
                var cellColor = isEven ? 0xFF110E18 : 0xFF171321;

                if (col == 0) {
                    cellColor = isEven ? 0xFF241B08 : 0xFF1B1405; // Gold Event Column
                } else if (col > 4) {
                    cellColor = isEven ? 0xFF161220 : 0xFF1E182C; // Player Columns
                }

                _cachedGridBitmap.fillRect(new Rectangle(col * GRID_SIZE, row * GRID_SIZE, GRID_SIZE, GRID_SIZE), cellColor);

            }
        }

        var gridHeight = STEPS_PER_SECTION * GRID_SIZE;
        var divisionsPerBeat = Std.int(activeQuantization / 4);
        for (division in 0...activeQuantization) {
            var guideY = Std.int(division * gridHeight / activeQuantization);
            var isBeat = division % divisionsPerBeat == 0;
            var lineColor = isBeat ? 0x6600FFCC : 0x22FFFFFF;
            _cachedGridBitmap.fillRect(new Rectangle(0, guideY, totalGridW, isBeat ? 2 : 1), lineColor);
        }

        _cachedGridBitmap.fillRect(new Rectangle(GRID_SIZE - 1, 0, 2, STEPS_PER_SECTION * GRID_SIZE), 0xFFFFCC00);
        _cachedGridBitmap.fillRect(new Rectangle((5 * GRID_SIZE) - 1, 0, 2, STEPS_PER_SECTION * GRID_SIZE), 0xFF00FFCC);
        _cachedGridBitmap.fillRect(new Rectangle(totalGridW - 2, 0, 2, STEPS_PER_SECTION * GRID_SIZE), 0xFF2A233D);

        gridBG = new FlxSprite(0, 0);
        gridBG.loadGraphic(_cachedGridBitmap);
        gridGroup.add(gridBG);

        beatLabelGroup = new FlxTypedGroup<FlxText>();
        add(beatLabelGroup);
        for (row in 0...STEPS_PER_SECTION) {
            if (row % 4 == 0) {
                var beat = Std.int(row / 4);
                var label = new FlxText(gridGroup.x - 54, gridGroup.y + (row * GRID_SIZE) + 11, 48, 'B$beat', 10);
                label.setFormat(Paths.font("vcr"), 10, row == 0 ? EditorTheme.ACCENT_YELLOW : EditorTheme.TEXT_MUTED, RIGHT);
                beatLabelGroup.add(label);
            }
        }

        if (sustainNotesGroup == null) {
            sustainNotesGroup = new FlxTypedGroup<FlxSprite>();
            add(sustainNotesGroup);
        }
        if (renderedNotesGroup == null) {
            renderedNotesGroup = new FlxTypedGroup<FlxSprite>();
            add(renderedNotesGroup);
        }
        if (renderedEventsGroup == null) {
            renderedEventsGroup = new FlxTypedGroup<FlxSprite>();
            add(renderedEventsGroup);
        }
    }

    private function createReceptorsAndIndicators():Void {
        if (receptorGroup != null) {
            remove(receptorGroup, true);
            receptorGroup.destroy();
        }
        if (strumLine != null) {
            remove(strumLine, true);
            strumLine.destroy();
        }
        if (sectionIndicator != null) {
            remove(sectionIndicator, true);
            sectionIndicator.destroy();
        }
        if (laneHeaderGroup != null) {
            remove(laneHeaderGroup, true);
            laneHeaderGroup.destroy();
            laneHeaderGroup = null;
        }

        receptorGroup = new FlxSpriteGroup(gridGroup.x + GRID_SIZE, gridGroup.y - GRID_SIZE - 10);
        add(receptorGroup);

        laneHeaderGroup = new FlxTypedGroup<FlxText>();
        add(laneHeaderGroup);

        var eventLabel = new FlxText(gridGroup.x, gridGroup.y - GRID_SIZE - 30, GRID_SIZE, "EV", 10);
        eventLabel.setFormat(Paths.font("vcr"), 10, EditorTheme.ACCENT_YELLOW, CENTER);
        laneHeaderGroup.add(eventLabel);

        for (i in 0...currentTotalLanes) {
            var rec = new StrumArrow(i * GRID_SIZE, 0, i % 4, (i >= 4), false, NoteSkinManager.defaultSkin);
            rec.playAnim("static", true);
            // Scale the receptor down to fit the grid cell
            rec.scale.set(GRID_SIZE / rec.frameWidth, GRID_SIZE / rec.frameHeight);
            rec.offset.set(0, 0);
            rec.updateHitbox();
            rec.alpha = 0.45;
            receptorGroup.add(rec);

            var side = i < 4 ? "O" : "P";
            var dir = switch (i % 4) {
                case 0: "L";
                case 1: "D";
                case 2: "U";
                default: "R";
            };
            var laneLabel = new FlxText(gridGroup.x + GRID_SIZE + (i * GRID_SIZE), gridGroup.y - GRID_SIZE - 30, GRID_SIZE, '$side$dir', 10);
            laneLabel.setFormat(Paths.font("vcr"), 10, i < 4 ? EditorTheme.TEXT_MUTED : EditorTheme.ACCENT_CYAN, CENTER);
            laneHeaderGroup.add(laneLabel);
        }

        var totalGridW = (currentTotalLanes + 1) * GRID_SIZE;
        strumLine = new FlxSprite(gridGroup.x - 12, gridGroup.y - 12).makeGraphic(totalGridW + 24, 3, EditorTheme.ACCENT_CYAN);
        add(strumLine);

        gridCursor = new FlxSprite(0, 0);
        refreshGridCursor();
        gridGroup.add(gridCursor);

        sectionIndicator = new FlxSprite(gridGroup.x - 22, gridGroup.y).makeGraphic(14, GRID_SIZE, EditorTheme.ACCENT_MAGENTA);
        add(sectionIndicator);

        if (camFollow != null && gridGroup != null) {
            camFollow.setPosition(gridGroup.x + (totalGridW * 0.5), gridGroup.y + (STEPS_PER_SECTION * GRID_SIZE) * 0.5);
        }
    }

    private function refreshGridCursor():Void {
        if (gridCursor == null) return;
        var cursorHeight = Std.int(Math.max(4, GRID_SIZE * STEPS_PER_SECTION / activeQuantization));
        gridCursor.makeGraphic(GRID_SIZE, cursorHeight, FlxColor.TRANSPARENT);
        gridCursor.pixels.fillRect(new Rectangle(0, 0, GRID_SIZE, 3), 0xFF00FFFF);
        gridCursor.pixels.fillRect(new Rectangle(0, cursorHeight - 3, GRID_SIZE, 3), 0xFF00FFFF);
        gridCursor.pixels.fillRect(new Rectangle(0, 0, 3, cursorHeight), 0xFF00FFFF);
        gridCursor.pixels.fillRect(new Rectangle(GRID_SIZE - 3, 0, 3, cursorHeight), 0xFF00FFFF);
        gridCursor.dirty = true;
    }

    private function setupUI():Void {
        topBar = new EditorTopBar("CHART EDITOR");
        topBar.cameras = [camUI];
        topBar.addAction("Play", togglePlayback);
        topBar.addAction("Rate", cyclePlaybackRate);
        topBar.addAction("Songs", function() toggleAuxiliaryWindow(songPickerModal));
        topBar.addAction("Meta", function() toggleAuxiliaryWindow(metadataWindow));
        topBar.addAction("Events", function() toggleAuxiliaryWindow(eventConfigWindow));
        topBar.addAction("XMSoul", saveChartToXMSoul);
        topBar.addAction("JSON", saveChartDirectly);
        topBar.addAction("Test", testInGame);
        topBar.addAction("Exit", function() MusicBeatState.switchState(new MainMenuState()));
        add(topBar);

        // --- Left Panel ---
        songPropertiesWindow = new EditorWindow(15, 56, 260, 440, "Chart Setup");
        songPropertiesWindow.cameras = [camUI];
        add(songPropertiesWindow);

        var propertiesLayout = new EditorVStack(10, 8, 240, 8);
        songPropertiesWindow.addElement(propertiesLayout);

        // --- Right Panel ---
        sectionWindow = new EditorWindow(FlxG.width - 275, 56, 260, 380, "Section & Note Details");
        sectionWindow.cameras = [camUI];
        add(sectionWindow);

        var sectionLayout = new EditorVStack(10, 8, 240, 8);
        sectionWindow.addElement(sectionLayout);

        sectionLayout.addSection("Position");

        infoText = new FlxText(0, 0, 240, "", 12);
        infoText.setFormat(Paths.font("vcr"), 12, EditorTheme.TEXT_PRIMARY, LEFT);
        sectionLayout.addItem(infoText, 76);

        statsText = new FlxText(0, 0, 240, "", 11);
        statsText.setFormat(Paths.font("vcr"), 11, EditorTheme.ACCENT_CYAN, LEFT);
        sectionLayout.addItem(statsText, 42);

        sectionLayout.addSection("Section Overview");

        sectionOverviewText = new FlxText(0, 0, 240, "", 11);
        sectionOverviewText.setFormat(Paths.font("vcr"), 11, EditorTheme.TEXT_MUTED, LEFT);
        sectionLayout.addItem(sectionOverviewText, 68);

        sectionLayout.addSection("Selected Note");

        propertiesLayout.addSection("Timing");

        stepperBPM = new EditorNumericStepper(0, 0, 240, "Tempo (BPM)", (songData != null && songData.bpm > 0) ? songData.bpm : 120.0, 30.0, 500.0, 1.0, 1, function(v) {
            pushUndoSnapshot();
            if (songData != null) songData.bpm = v;
            Conductor.changeBPM(v);
            updateDisplayInfo();
        });
        propertiesLayout.addItem(stepperBPM, 32);

        stepperSpeed = new EditorNumericStepper(0, 0, 240, "Scroll Speed", (songData != null && songData.scrollSpeed > 0) ? songData.scrollSpeed : 2.0, 0.5, 8.0, 0.1, 2, function(v) {
            pushUndoSnapshot();
            if (songData != null) songData.scrollSpeed = v;
        });
        propertiesLayout.addItem(stepperSpeed, 32);

        propertiesLayout.addSection("Note Placement");

        btnCycleType = new EditorButton(0, 0, 240, 26, "Type: " + currentNoteType, function() {
            curNoteTypeIdx = (curNoteTypeIdx + 1) % noteTypes.length;
            currentNoteType = noteTypes[curNoteTypeIdx];
            btnCycleType.label.text = "Type: " + currentNoteType;
            EditorToast.show('Note Type: $currentNoteType');
        });
        propertiesLayout.addItem(btnCycleType, 26);

        checkHitsounds = new EditorCheckbox(0, 0, "Metronome & Hitsounds", hitsoundsEnabled, function(c) {
            hitsoundsEnabled = c;
            EditorToast.show("Hitsounds: " + (hitsoundsEnabled ? "ON" : "OFF"));
        });
        propertiesLayout.addItem(checkHitsounds, 26);

        btnQuantization = new EditorButton(0, 0, 240, 26, getQuantizationLabel(), cycleQuantization);
        propertiesLayout.addItem(btnQuantization, 26);

        btnPlaybackRate = new EditorButton(0, 0, 240, 26, getPlaybackRateLabel(), cyclePlaybackRate);
        propertiesLayout.addItem(btnPlaybackRate, 26);

        propertiesLayout.addSection("Section Tools");

        var btnAddLane = new EditorButton(0, 0, 115, 26, "+ Add Lane", function() {
            if (currentTotalLanes < 16) {
                currentTotalLanes += 4;
                rebuildGridGraphics();
                createReceptorsAndIndicators();
                updateSectionView();
                EditorToast.show('Strumline expanded to $currentTotalLanes Lanes');
            }
        });

        var btnRemLane = new EditorButton(125, 0, 115, 26, "- Remove Lane", function() {
            if (currentTotalLanes > 4) {
                currentTotalLanes -= 4;
                rebuildGridGraphics();
                createReceptorsAndIndicators();
                updateSectionView();
                EditorToast.show('Strumline reduced to $currentTotalLanes Lanes');
            }
        });
        propertiesLayout.addRow([btnAddLane, btnRemLane], 26);

        var btnSwapSides = new EditorButton(0, 0, 240, 26, "Swap Opponent / Player", swapCurrentSectionNotes);
        propertiesLayout.addItem(btnSwapSides, 26);

        var btnMirror = new EditorButton(0, 0, 240, 26, "Mirror Section Lanes", mirrorSectionLanes);
        propertiesLayout.addItem(btnMirror, 26);

        var btnClearSec = new EditorButton(0, 0, 240, 26, "Clear Current Section", clearCurrentSection);
        propertiesLayout.addItem(btnClearSec, 26, 0);

        stepperSustain = new EditorNumericStepper(0, 0, 240, "Sustain Length (Steps)", 0, 0, 64, 0.5, 1, function(v) {
            if (curSelectedNote != null) {
                pushUndoSnapshot();
                curSelectedNote.sustainLength = v * Conductor.stepCrochet;
                updateSectionView();
            }
        });
        sectionLayout.addItem(stepperSustain, 32);

        var btnDel = new EditorButton(0, 0, 240, 26, "Delete Selected (Del)", deleteSelectedElement);
        sectionLayout.addItem(btnDel, 26);

        sectionLayout.addSection("Clipboard");

        var btnCopySection = new EditorButton(0, 0, 115, 26, "Copy Section", copyCurrentSection);
        var btnPasteSection = new EditorButton(125, 0, 115, 26, "Paste Section", pasteSection);
        sectionLayout.addRow([btnCopySection, btnPasteSection], 26, 0);

        // Metadata Window
        metadataWindow = new EditorWindow((FlxG.width - 320) * 0.5, 60, 320, 380, "Song Metadata & Characters");
        metadataWindow.cameras = [camUI];
        metadataWindow.visible = false;
        add(metadataWindow);

        inputPlayer1 = new EditorInputText(10, 6, 300, "Player 1 (Boyfriend)", songData != null ? songData.player1 : "bf");
        metadataWindow.addElement(inputPlayer1);

        inputPlayer2 = new EditorInputText(10, 48, 300, "Player 2 (Opponent)", songData != null ? songData.player2 : "dad");
        metadataWindow.addElement(inputPlayer2);

        inputGF = new EditorInputText(10, 90, 300, "Girlfriend", songData != null ? songData.gfVersion : "gf");
        metadataWindow.addElement(inputGF);

        inputStage = new EditorInputText(10, 132, 300, "Stage ID", songData != null ? songData.stage : "stage");
        metadataWindow.addElement(inputStage);

        inputDifficulty = new EditorInputText(10, 174, 300, "Custom Difficulty Tag", curDifficultyName);
        metadataWindow.addElement(inputDifficulty);

        var btnApplyMeta = new EditorButton(10, 230, 300, 28, "Apply Song Metadata", function() {
            if (songData != null) {
                songData.player1 = inputPlayer1.text.trim();
                songData.player2 = inputPlayer2.text.trim();
                songData.gfVersion = inputGF.text.trim();
                songData.stage = inputStage.text.trim();
                curDifficultyName = inputDifficulty.text.trim();
                metadataWindow.visible = false;
                EditorToast.show("Applied Song Metadata!");
            }
        });
        metadataWindow.addElement(btnApplyMeta);

        // Event Inspector Window
        eventConfigWindow = new EditorWindow(FlxG.width - 275, 395, 260, 280, "Event Parameters");
        eventConfigWindow.cameras = [camUI];
        eventConfigWindow.visible = false;
        add(eventConfigWindow);

        inputEventName = new EditorInputText(10, 6, 240, "Event Key (e.g. Camera Pan)", "Camera Pan");
        eventConfigWindow.addElement(inputEventName);

        inputEventVal1 = new EditorInputText(10, 48, 240, "Value 1 (e.g. dad / bf)", "dad");
        eventConfigWindow.addElement(inputEventVal1);

        inputEventVal2 = new EditorInputText(10, 90, 240, "Value 2 (e.g. 0.4)", "0.4");
        eventConfigWindow.addElement(inputEventVal2);

        eventDescText = new FlxText(10, 135, 240, "Pans camera to character or stage focus point.", 11);
        eventDescText.setFormat(Paths.font("vcr"), 11, EditorTheme.TEXT_MUTED, LEFT);
        eventConfigWindow.addElement(eventDescText);

        var btnUpdateEv = new EditorButton(10, 185, 240, 26, "Update Selected Event", function() {
            if (curSelectedEvent != null) {
                pushUndoSnapshot();
                curSelectedEvent.name = inputEventName.text.trim();
                curSelectedEvent.val1 = inputEventVal1.text.trim();
                curSelectedEvent.val2 = inputEventVal2.text.trim();
                updateSectionView();
                eventConfigWindow.visible = false;
                EditorToast.show('Updated Event: ${curSelectedEvent.name}');
            }
        });
        eventConfigWindow.addElement(btnUpdateEv);

        var btnCloseEvent = new EditorButton(10, 221, 240, 26, "Close", function() eventConfigWindow.visible = false);
        eventConfigWindow.addElement(btnCloseEvent);
    }

    private function toggleAuxiliaryWindow(target:EditorWindow):Void {
        var shouldOpen = target != null && !target.visible;
        if (songPickerModal != null) songPickerModal.visible = false;
        if (metadataWindow != null) metadataWindow.visible = false;
        if (eventConfigWindow != null) eventConfigWindow.visible = false;
        if (shouldOpen) target.visible = true;
    }

    private function isTextInputFocused():Bool {
        return (inputPlayer1 != null && inputPlayer1.isFocused)
            || (inputPlayer2 != null && inputPlayer2.isFocused)
            || (inputGF != null && inputGF.isFocused)
            || (inputStage != null && inputStage.isFocused)
            || (inputDifficulty != null && inputDifficulty.isFocused)
            || (inputEventName != null && inputEventName.isFocused)
            || (inputEventVal1 != null && inputEventVal1.isFocused)
            || (inputEventVal2 != null && inputEventVal2.isFocused);
    }

    private function buildSongPickerModal():Void {
        songPickerModal = new EditorWindow((FlxG.width - 440) * 0.5, (FlxG.height - 480) * 0.5, 440, 480, "Select Song & Difficulty to Chart");
        songPickerModal.cameras = [camUI];
        songPickerModal.visible = true; // Auto-open on launch
        add(songPickerModal);

        var songsFound:Array<String> = [];
        #if sys
        var searchDirs = ["songs", "assets/songs", "assets/preload/songs", "data/songs"];
        if (ModManager.activeMods != null) {
            for (m in ModManager.activeMods) searchDirs.unshift('mods/$m/songs');
        }

        for (d in searchDirs) {
            if (FileSystem.exists(d) && FileSystem.isDirectory(d)) {
                for (item in FileSystem.readDirectory(d)) {
                    if (FileSystem.isDirectory('$d/$item') && !songsFound.contains(item)) {
                        songsFound.push(item);
                    }
                }
            }
        }
        #end
        if (!songsFound.contains("tutorial")) songsFound.push("tutorial");

        var songListTxt = new FlxText(10, 6, 420, "AVAILABLE SONG DIRECTORIES:", 12);
        songListTxt.setFormat(Paths.font("vcr"), 12, EditorTheme.ACCENT_CYAN, LEFT);
        songPickerModal.addElement(songListTxt);

        for (i in 0...Std.int(Math.min(8, songsFound.length))) {
            var s = songsFound[i];
            var btn = new EditorButton(10, 30 + (i * 34), 420, 28, s.toUpperCase() + ' [${curDifficultyName.toUpperCase()}]', function() {
                curSongName = s;
                loadChartData(curSongName, curDifficultyName);
                setupAudio();
                songPickerModal.visible = false;
                updateSectionView();
                updateDisplayInfo();
                EditorToast.show('Loaded song: $s');
            });
            songPickerModal.addElement(btn);
        }

        var btnClose = new EditorButton(10, 410, 420, 28, "Start Editing Blank / Current", function() {
            songPickerModal.visible = false;
        });
        songPickerModal.addElement(btnClose);
    }

    override public function update(elapsed:Float):Void {
        var textInputWasFocused = isTextInputFocused();
        super.update(elapsed);

        updateAutosave(elapsed);

        if (!textInputWasFocused) handleKeyboardShortcuts();
        handleMouseGridInput();

        if (isPlaying) {
            if (inst != null && inst.playing) {
                Conductor.songPosition = inst.time;
                if (vocals != null && vocals.playing && Math.abs(inst.time - vocals.time) > 20) {
                    vocals.time = inst.time;
                }
            } else {
                Conductor.songPosition += elapsed * 1000.0 * playbackRate;
            }

            var calculatedStep = Math.floor(Conductor.songPosition / Conductor.stepCrochet);
            var targetSection = Math.floor(calculatedStep / STEPS_PER_SECTION);

            if (targetSection != curSection && targetSection >= 0) {
                curSection = targetSection;
                playedHitsounds.clear();
                updateSectionView();
                updateDisplayInfo();
            }

            var stepRemainder = calculatedStep % STEPS_PER_SECTION;
            if (sectionIndicator != null) {
                sectionIndicator.y = gridGroup.y + stepRemainder * GRID_SIZE;
            }

            if (hitsoundsEnabled) checkAndPlayHitsounds();
        }
    }

    private function checkAndPlayHitsounds():Void {
        var threshold = 25.0;
        for (i in 0...chartNotes.length) {
            var n = chartNotes[i];
            if (Math.abs(n.time - Conductor.songPosition) < threshold && !playedHitsounds.exists(i)) {
                playedHitsounds.set(i, true);
                AssetHelper.playSoundSafely("scrollMenu", 0.5);
                if (receptorGroup != null && receptorGroup.members.length > n.lane) {
                    var rec = receptorGroup.members[n.lane];
                    rec.alpha = 1.0;
                    FlxTween.tween(rec, {alpha: 0.45}, 0.15);
                }
            }
        }
    }

    private function handleKeyboardShortcuts():Void {
        if (songPickerModal.visible || metadataWindow.visible || eventConfigWindow.visible) {
            if (FlxG.keys.justPressed.ESCAPE) toggleAuxiliaryWindow(null);
            return;
        }

        if (FlxG.keys.justPressed.SPACE) togglePlayback();

        if (!isPlaying) {
            if (FlxG.keys.justPressed.W || FlxG.keys.justPressed.UP) changeSection(-1);
            if (FlxG.keys.justPressed.S || FlxG.keys.justPressed.DOWN) changeSection(1);
            if (FlxG.keys.justPressed.A || FlxG.keys.justPressed.LEFT) changeSection(-4);
            if (FlxG.keys.justPressed.D || FlxG.keys.justPressed.RIGHT) changeSection(4);

            if (FlxG.keys.justPressed.DELETE || FlxG.keys.justPressed.BACKSPACE) {
                deleteSelectedElement();
            }
        }

        if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.Z) undo();
        if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.Y) redo();
        if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.S) saveChartToXMSoul();
        if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.C) copyCurrentSection();
        if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.V) pasteSection();
        if (FlxG.keys.justPressed.Q) cycleQuantization();
        if (FlxG.keys.justPressed.ENTER) testInGame();
        if (FlxG.keys.justPressed.ESCAPE) MusicBeatState.switchState(new MainMenuState());
    }

    private function handleMouseGridInput():Void {
        if (gridGroup == null || isPlaying || metadataWindow.visible || songPickerModal.visible || eventConfigWindow.visible) return;

        var mx = FlxG.mouse.x - gridGroup.x;
        var my = FlxG.mouse.y - gridGroup.y;
        var totalGridW = (currentTotalLanes + 1) * GRID_SIZE;

        if (mx >= 0 && mx < totalGridW && my >= 0 && my < (STEPS_PER_SECTION * GRID_SIZE)) {
            var hoveredCol = Math.floor(mx / GRID_SIZE);
            var rawStep = my / GRID_SIZE;
            var quantStep = STEPS_PER_SECTION / activeQuantization;
            var hoveredStep = FlxMath.bound(Math.floor(rawStep / quantStep) * quantStep, 0, STEPS_PER_SECTION - quantStep);

            if (gridCursor != null) {
                gridCursor.visible = true;
                gridCursor.setPosition(hoveredCol * GRID_SIZE, hoveredStep * GRID_SIZE);
            }

            if (FlxG.mouse.justPressed) {
                var stepTime = (curSection * STEPS_PER_SECTION + hoveredStep) * Conductor.stepCrochet;

                if (hoveredCol == 0) {
                    var existingEv = findEventAt(stepTime);
                    if (existingEv != null) {
                        curSelectedEvent = existingEv;
                        curSelectedNote = null;
                        toggleAuxiliaryWindow(eventConfigWindow);
                        inputEventName.text = existingEv.name;
                        inputEventVal1.text = existingEv.val1;
                        inputEventVal2.text = existingEv.val2;
                        EditorToast.show('Selected Event: ${existingEv.name}');
                    } else {
                        pushUndoSnapshot();
                        var newEv:ChartEditorEvent = {
                            time: stepTime,
                            name: "Camera Pan",
                            val1: "dad",
                            val2: "0.4"
                        };
                        chartEvents.push(newEv);
                        curSelectedEvent = newEv;
                        toggleAuxiliaryWindow(eventConfigWindow);
                        AssetHelper.playSoundSafely("scrollMenu", 0.4);
                    }
                } else {
                    var targetLane = hoveredCol - 1;
                    var existingNote = findNoteAt(targetLane, stepTime);

                    if (existingNote != null) {
                        curSelectedNote = existingNote;
                        curSelectedEvent = null;
                        stepperSustain.value = Math.round((existingNote.sustainLength / Conductor.stepCrochet) * 10) / 10;
                        EditorToast.show('Selected Note [Lane $targetLane]');
                    } else {
                        pushUndoSnapshot();
                        var newNote:ChartEditorNote = {
                            time: stepTime,
                            lane: targetLane,
                            sustainLength: 0.0,
                            type: currentNoteType,
                            mustPress: (targetLane >= 4)
                        };
                        chartNotes.push(newNote);
                        curSelectedNote = newNote;
                        AssetHelper.playSoundSafely("scrollMenu", 0.4);
                    }
                }
                updateSectionView();
                updateDisplayInfo();
            } else if (FlxG.mouse.justPressedRight) {
                var stepTime = (curSection * STEPS_PER_SECTION + hoveredStep) * Conductor.stepCrochet;

                if (hoveredCol == 0) {
                    var existingEv = findEventAt(stepTime);
                    if (existingEv != null) {
                        pushUndoSnapshot();
                        chartEvents.remove(existingEv);
                        if (curSelectedEvent == existingEv) curSelectedEvent = null;
                        updateSectionView();
                        AssetHelper.playSoundSafely("cancelMenu", 0.5);
                    }
                } else {
                    var targetLane = hoveredCol - 1;
                    var existingNote = findNoteAt(targetLane, stepTime);
                    if (existingNote != null) {
                        pushUndoSnapshot();
                        chartNotes.remove(existingNote);
                        if (curSelectedNote == existingNote) curSelectedNote = null;
                        updateSectionView();
                        AssetHelper.playSoundSafely("cancelMenu", 0.5);
                    }
                }
            }
        } else {
            if (gridCursor != null) gridCursor.visible = false;
        }

        if (FlxG.mouse.wheel != 0) {
            changeSection(-FlxG.mouse.wheel);
        }
    }

    private function findNoteAt(lane:Int, time:Float):Null<ChartEditorNote> {
        var threshold = Conductor.stepCrochet * (STEPS_PER_SECTION / activeQuantization) * 0.45;
        for (n in chartNotes) {
            if (n.lane == lane && Math.abs(n.time - time) < threshold) return n;
        }
        return null;
    }

    private function findEventAt(time:Float):Null<ChartEditorEvent> {
        var threshold = Conductor.stepCrochet * (STEPS_PER_SECTION / activeQuantization) * 0.45;
        for (e in chartEvents) {
            if (Math.abs(e.time - time) < threshold) return e;
        }
        return null;
    }

    private function updateSectionView():Void {
        clearSpriteGroup(renderedNotesGroup);
        clearSpriteGroup(sustainNotesGroup);
        clearSpriteGroup(renderedEventsGroup);

        var sectionStartTime = curSection * STEPS_PER_SECTION * Conductor.stepCrochet;
        var sectionEndTime = (curSection + 1) * STEPS_PER_SECTION * Conductor.stepCrochet;

        // Render Events in Column 0 (glowing diamond nodes)
        for (e in chartEvents) {
            if (e.time >= (sectionStartTime - 20) && e.time < (sectionEndTime - 10)) {
                var stepOffset = (e.time - sectionStartTime) / Conductor.stepCrochet;
                var evY = gridGroup.y + (stepOffset * GRID_SIZE);
                var evX = gridGroup.x;

                var evSpr = new FlxSprite(evX, evY);
                if (_eventMarker != null && _eventMarker.graphic != null) {
                    evSpr.loadGraphic(_eventMarker.graphic);
                } else {
                    evSpr.makeGraphic(GRID_SIZE, GRID_SIZE, EditorTheme.ACCENT_YELLOW);
                }
                renderedEventsGroup.add(evSpr);
            }
        }

        // Render Notes in Columns 1..N using real gameplay note graphics, section-scoped for editor performance.
        for (n in chartNotes) {
            if (n.lane >= 0 && n.lane < currentTotalLanes && n.time >= (sectionStartTime - 20) && n.time < (sectionEndTime - 10)) {
                var stepOffset = (n.time - sectionStartTime) / Conductor.stepCrochet;
                var noteY = gridGroup.y + (stepOffset * GRID_SIZE);
                var noteX = gridGroup.x + GRID_SIZE + (n.lane * GRID_SIZE);
                var isSel = (n == curSelectedNote);

                if (n.sustainLength > 0) {
                    var holdSteps = n.sustainLength / Conductor.stepCrochet;
                    var holdHeight = Math.max(GRID_SIZE, holdSteps * GRID_SIZE);

                    var holdBody = new Note(n.time, n.lane % 4, n.sustainLength, null, true, false, n.mustPress, n.type, NoteSkinManager.defaultSkin);
                    holdBody.scrollFactor.set(1, 1);
                    holdBody.scale.set(GRID_SIZE / holdBody.frameWidth, holdHeight / holdBody.frameHeight);
                    holdBody.updateHitbox();
                    holdBody.x = noteX + (GRID_SIZE - holdBody.width) * 0.5;
                    holdBody.y = noteY + GRID_SIZE * 0.5;
                    holdBody.alpha = 0.55;
                    sustainNotesGroup.add(holdBody);

                    var holdEnd = new Note(n.time + n.sustainLength, n.lane % 4, 0, null, true, true, n.mustPress, n.type, NoteSkinManager.defaultSkin);
                    holdEnd.scrollFactor.set(1, 1);
                    holdEnd.scale.set(GRID_SIZE / holdEnd.frameWidth, GRID_SIZE / holdEnd.frameHeight);
                    holdEnd.updateHitbox();
                    holdEnd.x = noteX + (GRID_SIZE - holdEnd.width) * 0.5;
                    holdEnd.y = noteY + holdHeight;
                    sustainNotesGroup.add(holdEnd);
                }

                var sprNote = new Note(n.time, n.lane % 4, 0, null, false, false, n.mustPress, n.type, NoteSkinManager.defaultSkin);
                sprNote.scrollFactor.set(1, 1);
                sprNote.scale.set(GRID_SIZE / sprNote.frameWidth, GRID_SIZE / sprNote.frameHeight);
                sprNote.updateHitbox();
                sprNote.x = noteX + (GRID_SIZE - sprNote.width) * 0.5;
                sprNote.y = noteY + (GRID_SIZE - sprNote.height) * 0.5;

                if (isSel) {
                    var glow = EditorTheme.makeRoundedRect(GRID_SIZE + 8, GRID_SIZE + 8, 0xFFFFFFFF, EditorTheme.CORNER_SM, 0.24);
                    glow.x = noteX - 4;
                    glow.y = noteY - 4;
                    renderedNotesGroup.add(glow);

                    var border = new FlxSprite(noteX + 2, noteY + 2).makeGraphic(GRID_SIZE - 4, GRID_SIZE - 4, FlxColor.TRANSPARENT);
                    border.pixels.fillRect(new Rectangle(0, 0, GRID_SIZE - 4, 2), 0xFFFFFFFF);
                    border.pixels.fillRect(new Rectangle(0, GRID_SIZE - 6, GRID_SIZE - 4, 2), 0xFFFFFFFF);
                    border.pixels.fillRect(new Rectangle(0, 0, 2, GRID_SIZE - 4), 0xFFFFFFFF);
                    border.pixels.fillRect(new Rectangle(GRID_SIZE - 6, 0, 2, GRID_SIZE - 4), 0xFFFFFFFF);
                    border.dirty = true;
                    renderedNotesGroup.add(border);
                }
                renderedNotesGroup.add(sprNote);
            }
        }
    }

    private function clearSpriteGroup(group:FlxTypedGroup<FlxSprite>):Void {
        if (group == null || group.members == null) return;
        for (member in group.members) {
            if (member != null) member.destroy();
        }
        group.clear();
    }

    private function deleteSelectedElement():Void {
        if (curSelectedNote != null) {
            pushUndoSnapshot();
            chartNotes.remove(curSelectedNote);
            curSelectedNote = null;
            updateSectionView();
            updateDisplayInfo();
            EditorToast.show("Deleted note");
        } else if (curSelectedEvent != null) {
            pushUndoSnapshot();
            chartEvents.remove(curSelectedEvent);
            curSelectedEvent = null;
            eventConfigWindow.visible = false;
            updateSectionView();
            updateDisplayInfo();
            EditorToast.show("Deleted event");
        }
    }

    private function changeSection(delta:Int = 0):Void {
        curSection = Std.int(Math.max(0, curSection + delta));
        Conductor.songPosition = curSection * STEPS_PER_SECTION * Conductor.stepCrochet;

        if (inst != null) {
            inst.time = Conductor.songPosition;
            if (vocals != null) vocals.time = Conductor.songPosition;
        }

        updateSectionView();
        updateDisplayInfo();
        AssetHelper.playSoundSafely("scrollMenu", 0.5);
    }

    private function togglePlayback():Void {
        isPlaying = !isPlaying;
        playedHitsounds.clear();

        if (isPlaying) {
            Conductor.songPosition = curSection * STEPS_PER_SECTION * Conductor.stepCrochet;
            if (inst != null) {
                inst.time = Conductor.songPosition;
                inst.play();
            }
            if (vocals != null) {
                vocals.time = Conductor.songPosition;
                vocals.play();
            }
            EditorToast.show("Playing Timeline");
        } else {
            if (inst != null) inst.pause();
            if (vocals != null) vocals.pause();
            EditorToast.show("Paused Timeline");
        }
    }

    private function updateDisplayInfo():Void {
        if (infoText == null) return;

        var curTimeSec = Math.round(Conductor.songPosition * 0.001 * 10) / 10;
        var totalNotes = chartNotes != null ? chartNotes.length : 0;
        var totalEv = chartEvents != null ? chartEvents.length : 0;

        infoText.text = 'SECTION: $curSection\n' +
            'STEP: ${curSection * STEPS_PER_SECTION}\n' +
            'TIME: ${curTimeSec}s\n' +
            'BPM: ${songData != null ? songData.bpm : 120.0}\n' +
            'NOTES: $totalNotes | EVENTS: $totalEv';

        if (statsText != null) {
            statsText.text = 'Song: $curSongName\nDiff: $curDifficultyName\nLanes: $currentTotalLanes';
        }

        if (sectionOverviewText != null) {
            var sectionStartTime = curSection * STEPS_PER_SECTION * Conductor.stepCrochet;
            var sectionEndTime = (curSection + 1) * STEPS_PER_SECTION * Conductor.stepCrochet;
            var noteCount = 0;
            var holdCount = 0;
            var eventCount = 0;
            var playerCount = 0;
            var opponentCount = 0;

            for (note in chartNotes) {
                if (note.time >= sectionStartTime && note.time < sectionEndTime) {
                    noteCount++;
                    if (note.sustainLength > 0) holdCount++;
                    if (note.mustPress) playerCount++; else opponentCount++;
                }
            }

            for (event in chartEvents) {
                if (event.time >= sectionStartTime && event.time < sectionEndTime) eventCount++;
            }

            sectionOverviewText.text = 'Notes: $noteCount  Holds: $holdCount\nEvents: $eventCount\nPlayer: $playerCount  Opponent: $opponentCount';
        }
    }

    private function swapCurrentSectionNotes():Void {
        pushUndoSnapshot();
        var sectionStartTime = curSection * STEPS_PER_SECTION * Conductor.stepCrochet;
        var sectionEndTime = (curSection + 1) * STEPS_PER_SECTION * Conductor.stepCrochet;

        for (n in chartNotes) {
            if (n.time >= sectionStartTime && n.time < sectionEndTime) {
                n.lane = (n.lane < 4) ? (n.lane + 4) : (n.lane - 4);
                n.mustPress = (n.lane >= 4);
            }
        }
        updateSectionView();
        updateDisplayInfo();
        EditorToast.show("Swapped Section Lanes");
    }

    private function mirrorSectionLanes():Void {
        pushUndoSnapshot();
        var sectionStartTime = curSection * STEPS_PER_SECTION * Conductor.stepCrochet;
        var sectionEndTime = (curSection + 1) * STEPS_PER_SECTION * Conductor.stepCrochet;

        for (n in chartNotes) {
            if (n.time >= sectionStartTime && n.time < sectionEndTime) {
                var base = n.lane < 4 ? 0 : 4;
                var subLane = n.lane % 4;
                n.lane = base + (3 - subLane);
            }
        }
        updateSectionView();
        updateDisplayInfo();
        EditorToast.show("Mirrored Section Horizontally");
    }

    private function clearCurrentSection():Void {
        pushUndoSnapshot();
        var sectionStartTime = curSection * STEPS_PER_SECTION * Conductor.stepCrochet;
        var sectionEndTime = (curSection + 1) * STEPS_PER_SECTION * Conductor.stepCrochet;

        chartNotes = chartNotes.filter(function(n) {
            return !(n.time >= sectionStartTime && n.time < sectionEndTime);
        });
        chartEvents = chartEvents.filter(function(e) {
            return !(e.time >= sectionStartTime && e.time < sectionEndTime);
        });

        curSelectedNote = null;
        curSelectedEvent = null;
        updateSectionView();
        updateDisplayInfo();
        EditorToast.show("Cleared Section Data");
    }

    private function getQuantizationLabel():String {
        return 'Snap: 1/$activeQuantization (Q)';
    }

    private function getPlaybackRateLabel():String {
        return 'Playback Rate: ${Math.round(playbackRate * 100)}%';
    }

    private function cyclePlaybackRate():Void {
        var rates = [0.5, 0.75, 1.0, 1.25, 1.5];
        var idx = rates.indexOf(playbackRate);
        playbackRate = rates[(idx + 1) % rates.length];
        if (btnPlaybackRate != null) btnPlaybackRate.label.text = getPlaybackRateLabel();
        EditorToast.show(getPlaybackRateLabel());
    }

    private function cycleQuantization():Void {
        var quantizations = [4, 8, 12, 16, 24, 32];
        var index = quantizations.indexOf(activeQuantization);
        activeQuantization = quantizations[(index + 1) % quantizations.length];
        if (btnQuantization != null) btnQuantization.label.text = getQuantizationLabel();
        rebuildGridGraphics();
        createReceptorsAndIndicators();
        updateSectionView();
        EditorToast.show('Grid snap set to 1/$activeQuantization');
    }

    private function copyCurrentSection():Void {
        var sectionStartTime = curSection * STEPS_PER_SECTION * Conductor.stepCrochet;
        var sectionEndTime = sectionStartTime + (STEPS_PER_SECTION * Conductor.stepCrochet);
        sectionClipboardNotes = [];
        sectionClipboardEvents = [];

        for (note in chartNotes) {
            if (note.time >= sectionStartTime && note.time < sectionEndTime) {
                sectionClipboardNotes.push({
                    time: note.time - sectionStartTime,
                    lane: note.lane,
                    sustainLength: note.sustainLength,
                    type: note.type,
                    mustPress: note.mustPress
                });
            }
        }
        for (event in chartEvents) {
            if (event.time >= sectionStartTime && event.time < sectionEndTime) {
                sectionClipboardEvents.push({
                    time: event.time - sectionStartTime,
                    name: event.name,
                    val1: event.val1,
                    val2: event.val2
                });
            }
        }

        EditorToast.show('Copied ${sectionClipboardNotes.length} notes and ${sectionClipboardEvents.length} events');
    }

    private function pasteSection():Void {
        if (sectionClipboardNotes.length == 0 && sectionClipboardEvents.length == 0) {
            EditorToast.show("Section clipboard is empty", true);
            return;
        }

        pushUndoSnapshot();
        var sectionStartTime = curSection * STEPS_PER_SECTION * Conductor.stepCrochet;
        for (note in sectionClipboardNotes) {
            chartNotes.push({
                time: sectionStartTime + note.time,
                lane: note.lane,
                sustainLength: note.sustainLength,
                type: note.type,
                mustPress: note.mustPress
            });
        }
        for (event in sectionClipboardEvents) {
            chartEvents.push({
                time: sectionStartTime + event.time,
                name: event.name,
                val1: event.val1,
                val2: event.val2
            });
        }

        updateSectionView();
        updateDisplayInfo();
        EditorToast.show("Pasted section contents");
    }

    private function pushUndoSnapshot():Void {
        var snap = Json.stringify({notes: chartNotes, events: chartEvents});
        undoStack.push(snap);
        if (undoStack.length > MAX_UNDO_DEPTH) undoStack.shift();
        redoStack = [];
        dirtySinceAutosave = true;
    }

    private function updateAutosave(elapsed:Float):Void {
        #if sys
        if (!dirtySinceAutosave) return;
        autosaveTimer += elapsed;
        if (autosaveTimer < AUTOSAVE_INTERVAL) return;
        autosaveTimer = 0.0;
        dirtySinceAutosave = false;

        try {
            var dir = 'autosaves/charts/${curSongName.toLowerCase()}';
            if (!FileSystem.exists("autosaves")) FileSystem.createDirectory("autosaves");
            if (!FileSystem.exists("autosaves/charts")) FileSystem.createDirectory("autosaves/charts");
            if (!FileSystem.exists(dir)) FileSystem.createDirectory(dir);
            File.saveContent('$dir/${curDifficultyName.toLowerCase()}_autosave.json', serializeChartToJson());
            EditorToast.show("Chart autosaved.");
        } catch (e:Dynamic) {
            Logger.warn('Chart autosave failed: $e', "editor");
        }
        #end
    }

    private function undo():Void {
        if (undoStack.length <= 1) {
            EditorToast.show("No more undos available.", true);
            return;
        }
        var cur = undoStack.pop();
        redoStack.push(cur);
        var prev = undoStack[undoStack.length - 1];
        var data:Dynamic = Json.parse(prev);
        chartNotes = cast data.notes;
        chartEvents = cast data.events;
        curSelectedNote = null;
        curSelectedEvent = null;
        updateSectionView();
        updateDisplayInfo();
        EditorToast.show("Undone action.");
    }

    private function redo():Void {
        if (redoStack.length == 0) {
            EditorToast.show("No redos available.", true);
            return;
        }
        var next = redoStack.pop();
        undoStack.push(next);
        var data:Dynamic = Json.parse(next);
        chartNotes = cast data.notes;
        chartEvents = cast data.events;
        curSelectedNote = null;
        curSelectedEvent = null;
        updateSectionView();
        updateDisplayInfo();
        EditorToast.show("Redone action.");
    }

    public function saveChartToXMSoul():Void {
        #if sys
        chartNotes.sort(function(a, b) return (a.time < b.time) ? -1 : 1);
        var targetPath = 'assets/songs/${curSongName.toLowerCase()}/chart.xmsoul';

        var bpmVal = (songData != null) ? songData.bpm : 120.0;
        var speedVal = (songData != null) ? songData.scrollSpeed : 2.0;

        var xml = '<?xml version="1.0" encoding="utf-8"?>\n';
        xml += '<chart song="${curSongName.toLowerCase()}" bpm="$bpmVal" speed="$speedVal" player1="${songData.player1}" player2="${songData.player2}" stage="${songData.stage}">\n';
        xml += '    <events>\n';
        for (e in chartEvents) {
            xml += '        <event time="${e.time}" name="${e.name}" val1="${e.val1}" val2="${e.val2}" />\n';
        }
        xml += '    </events>\n';
        xml += '    <notes>\n';
        for (n in chartNotes) {
            xml += '        <note time="${n.time}" lane="${n.lane}" type="${n.type}" sustain="${n.sustainLength}" mustPress="${n.mustPress}" />\n';
        }
        xml += '    </notes>\n</chart>';

        try {
            var dir = haxe.io.Path.directory(targetPath);
            if (!FileSystem.exists(dir)) FileSystem.createDirectory(dir);
            File.saveContent(targetPath, xml);
            EditorToast.show('Saved .xmsoul to: $targetPath');
            AssetHelper.playSoundSafely("confirmMenu", 0.7);
        } catch (e:Dynamic) {
            EditorToast.show("Failed writing .xmsoul file", true);
        }
        #end
    }

    private function saveChartDirectly():Void {
        #if sys
        var formattedJson = serializeChartToJson();
        var targetPath = 'assets/preload/songs/${curSongName.toLowerCase()}/charts/${curDifficultyName.toLowerCase()}.json';
        var fallbackPath = 'songs/${curSongName.toLowerCase()}/charts/${curDifficultyName.toLowerCase()}.json';

        try {
            var dir = haxe.io.Path.directory(targetPath);
            if (!FileSystem.exists(dir)) FileSystem.createDirectory(dir);
            File.saveContent(targetPath, formattedJson);
            EditorToast.show('Saved JSON to: $targetPath');
            AssetHelper.playSoundSafely("confirmMenu", 0.7);
        } catch (e:Dynamic) {
            try {
                File.saveContent(fallbackPath, formattedJson);
                EditorToast.show('Saved JSON to: $fallbackPath');
                AssetHelper.playSoundSafely("confirmMenu", 0.7);
            } catch (err:Dynamic) {
                EditorToast.show("Failed to write chart JSON", true);
            }
        }
        #end
    }

    private function serializeChartToJson():String {
        chartNotes.sort(function(a, b) return (a.time < b.time) ? -1 : 1);

        var sectionList:Array<Dynamic> = [];
        var maxTime = (chartNotes.length > 0) ? chartNotes[chartNotes.length - 1].time : 10000;
        var totalSecs = Math.ceil(maxTime / (STEPS_PER_SECTION * Conductor.stepCrochet)) + 1;

        for (s in 0...totalSecs) {
            var sStart = s * STEPS_PER_SECTION * Conductor.stepCrochet;
            var sEnd = (s + 1) * STEPS_PER_SECTION * Conductor.stepCrochet;

            var secNotes:Array<Array<Dynamic>> = [];
            for (n in chartNotes) {
                if (n.time >= sStart && n.time < sEnd) {
                    secNotes.push([n.time, n.lane, n.sustainLength, n.type]);
                }
            }

            sectionList.push({
                sectionNotes: secNotes,
                lengthInSteps: 16,
                mustHitSection: true,
                changeBPM: false
            });
        }

        var rootData = {
            song: {
                song: curSongName,
                bpm: songData != null ? songData.bpm : 120.0,
                speed: songData != null ? songData.scrollSpeed : 2.0,
                player1: songData != null ? songData.player1 : "bf",
                player2: songData != null ? songData.player2 : "dad",
                gfVersion: songData != null ? songData.gfVersion : "gf",
                stage: songData != null ? songData.stage : "stage",
                notes: sectionList,
                events: chartEvents
            }
        };

        return Json.stringify(rootData, "\t");
    }

    private function testInGame():Void {
        if (inst != null) inst.stop();
        if (vocals != null) vocals.stop();

        PlayState.curSong = curSongName;
        PlayState.curDifficulty = curDifficultyName;
        MusicBeatState.switchState(new PlayState());
    }

    override public function destroy():Void {
        if (inst != null) {
            inst.stop();
            if (FlxG.sound.list != null) FlxG.sound.list.remove(inst, true);
            inst.destroy();
            inst = null;
        }
        if (vocals != null) {
            vocals.stop();
            if (FlxG.sound.list != null) FlxG.sound.list.remove(vocals, true);
            vocals.destroy();
            vocals = null;
        }
        super.destroy();
    }
}