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
import haxe.Json;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.net.FileReference;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.input.Controls;
import soulscorch.backend.system.modules.discord.DiscordRPC;
import soulscorch.backend.utils.Logger;
import soulscorch.gameplay.PlayState;
import soulscorch.gameplay.chart.Chart;
import soulscorch.gameplay.chart.Song;
import soulscorch.gameplay.notes.NoteSkinManager;
import soulscorch.gameplay.song.Difficulty;
import soulscorch.gameplay.song.SongLoader;
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

typedef ChartEditorNote = {
    var time:Float;
    var lane:Int;
    var sustainLength:Float;
    var type:String;
    var mustPress:Bool;
}

class ChartingState extends MusicBeatState {
    public static var curSongName:String = "tutorial";
    public static var curDifficultyName:String = "normal";

    private var camEditor:FlxCamera;
    private var camUI:FlxCamera;

    // --- Audio Tracks ---
    private var inst:FlxSound;
    private var vocals:FlxSound;
    private var isPlaying:Bool = false;

    // --- Grid Constants & Virtualization ---
    public static inline var GRID_SIZE:Int = 40;
    public static inline var LANES:Int = 8;
    public static inline var STEPS_PER_SECTION:Int = 16;

    private var curSection:Int = 0;
    private var curStepSelected:Int = 0;
    private var curLaneSelected:Int = 0;

    private var gridBG:FlxSprite;
    private var gridGroup:FlxSpriteGroup;
    private var renderedNotesGroup:FlxTypedGroup<FlxSprite>;
    private var sustainNotesGroup:FlxTypedGroup<FlxSprite>;
    private var gridCursor:FlxSprite;
    private var sectionIndicator:FlxSprite;
    private var camFollow:FlxObject;

    // --- Song & Note Storage ---
    private var songData:Song;
    private var chartNotes:Array<ChartEditorNote> = [];
    private var curSelectedNote:ChartEditorNote = null;

    // --- UI Windows ---
    private var topBar:EditorTopBar;
    private var songPropertiesWindow:EditorWindow;
    private var sectionWindow:EditorWindow;
    private var notePropertiesWindow:EditorWindow;

    private var stepperBPM:EditorNumericStepper;
    private var stepperSpeed:EditorNumericStepper;
    private var stepperSustain:EditorNumericStepper;
    private var checkMustHit:EditorCheckbox;
    private var checkAltAnim:EditorCheckbox;
    private var checkChangeBPM:EditorCheckbox;
    private var stepperSectionBPM:EditorNumericStepper;

    private var infoText:FlxText;
    private var noteCountText:FlxText;

    // Note Type Selector
    private var currentNoteType:String = "normal";
    private var noteTypes:Array<String> = ["normal", "Hurt Note", "Mine", "Instakill", "No Animation"];
    private var curNoteTypeIdx:Int = 0;

    private static var _cachedGridBitmap:openfl.display.BitmapData = null;

    public function new(?songId:String = "tutorial", ?difficulty:String = "normal") {
        super();
        if (songId != null && songId.length > 0) curSongName = songId;
        if (difficulty != null && difficulty.length > 0) curDifficultyName = difficulty;
    }

    override public function create():Void {
        super.create();

        #if desktop
        DiscordRPC.changePresence("Chart Studio Pro", 'Editing: ${curSongName.toUpperCase()} [${curDifficultyName.toUpperCase()}]');
        #end

        setupCameras();
        setupAudio();
        loadChartData(curSongName, curDifficultyName);

        createGridGraphics();
        createCursorAndIndicators();
        setupUI();

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
        camEditor.follow(camFollow, LOCKON, 0.25);
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

    private function createGridGraphics():Void {
        var gridX = (FlxG.width * 0.5) - ((LANES * GRID_SIZE) * 0.5) - 60;

        gridGroup = new FlxSpriteGroup(gridX, 0);
        add(gridGroup);

        if (_cachedGridBitmap == null) {
            _cachedGridBitmap = new openfl.display.BitmapData(LANES * GRID_SIZE, STEPS_PER_SECTION * GRID_SIZE, true, 0x0);
            for (col in 0...LANES) {
                for (row in 0...STEPS_PER_SECTION) {
                    var isEven = (col + row) % 2 == 0;
                    var cellColor = isEven ? 0xFF2A2238 : 0xFF201A2C;
                    if (col == 4) cellColor = isEven ? 0xFF352B47 : 0xFF2D243D;

                    _cachedGridBitmap.fillRect(new openfl.geom.Rectangle(col * GRID_SIZE, row * GRID_SIZE, GRID_SIZE, GRID_SIZE), cellColor);
                    _cachedGridBitmap.fillRect(new openfl.geom.Rectangle(col * GRID_SIZE, row * GRID_SIZE, GRID_SIZE, 1), 0x22FFFFFF);
                }
            }
            _cachedGridBitmap.fillRect(new openfl.geom.Rectangle(4 * GRID_SIZE - 1, 0, 2, STEPS_PER_SECTION * GRID_SIZE), 0x8800FFFF);
        }

        gridBG = new FlxSprite(0, 0);
        gridBG.loadGraphic(_cachedGridBitmap);
        gridGroup.add(gridBG);

        var strumLine = new FlxSprite(-10, 0).makeGraphic((LANES * GRID_SIZE) + 20, 3, EditorTheme.ACCENT_CYAN);
        gridGroup.add(strumLine);

        sustainNotesGroup = new FlxTypedGroup<FlxSprite>();
        add(sustainNotesGroup);

        renderedNotesGroup = new FlxTypedGroup<FlxSprite>();
        add(renderedNotesGroup);
    }

    private function createCursorAndIndicators():Void {
        gridCursor = new FlxSprite(0, 0).makeGraphic(GRID_SIZE, GRID_SIZE, FlxColor.TRANSPARENT);
        gridCursor.pixels.fillRect(new openfl.geom.Rectangle(0, 0, GRID_SIZE, 2), 0xFF00FFFF);
        gridCursor.pixels.fillRect(new openfl.geom.Rectangle(0, GRID_SIZE - 2, GRID_SIZE, 2), 0xFF00FFFF);
        gridCursor.pixels.fillRect(new openfl.geom.Rectangle(0, 0, 2, GRID_SIZE), 0xFF00FFFF);
        gridCursor.pixels.fillRect(new openfl.geom.Rectangle(GRID_SIZE - 2, 0, 2, GRID_SIZE), 0xFF00FFFF);
        gridCursor.dirty = true;
        gridGroup.add(gridCursor);

        sectionIndicator = new FlxSprite(-25, 0).makeGraphic(15, GRID_SIZE, EditorTheme.ACCENT_MAGENTA);
        gridGroup.add(sectionIndicator);

        if (camFollow != null && gridGroup != null) {
            camFollow.setPosition(gridGroup.x + ((LANES * GRID_SIZE) * 0.5), (STEPS_PER_SECTION * GRID_SIZE) * 0.5);
        }
    }

    private function setupUI():Void {
        topBar = new EditorTopBar("CHART STUDIO PRO // [ULTRA PERFORMANCE MATRIX]");
        topBar.cameras = [camUI];
        topBar.addAction("Play/Pause (Space)", togglePlayback);
        topBar.addAction("Save Chart (Ctrl+S)", saveChartDirectly);
        topBar.addAction("Clear Section", clearCurrentSection);
        topBar.addAction("Test in Game (Enter)", testInGame);
        topBar.addAction("Exit", function() MusicBeatState.switchState(new MainMenuState()));
        add(topBar);

        songPropertiesWindow = new EditorWindow(15, 45, 260, 310, "Song Properties");
        songPropertiesWindow.cameras = [camUI];
        add(songPropertiesWindow);

        stepperBPM = new EditorNumericStepper(10, 10, 240, "Tempo (BPM)", songData != null ? songData.bpm : 120.0, 30.0, 400.0, 1.0, 1, function(v) {
            if (songData != null) songData.bpm = v;
            Conductor.changeBPM(v);
            updateDisplayInfo();
        });
        songPropertiesWindow.addElement(stepperBPM);

        stepperSpeed = new EditorNumericStepper(10, 50, 240, "Scroll Speed", songData != null ? songData.scrollSpeed : 2.0, 0.5, 6.0, 0.1, 2, function(v) {
            if (songData != null) songData.scrollSpeed = v;
        });
        songPropertiesWindow.addElement(stepperSpeed);

        var btnCycleType = new EditorButton(10, 95, 240, 26, "Type: " + currentNoteType, function() {
            curNoteTypeIdx = (curNoteTypeIdx + 1) % noteTypes.length;
            currentNoteType = noteTypes[curNoteTypeIdx];
            EditorToast.show('Note Type: $currentNoteType');
        });
        songPropertiesWindow.addElement(btnCycleType);

        var btnSwapSides = new EditorButton(10, 130, 240, 26, "Swap Section Lanes", swapCurrentSectionNotes);
        songPropertiesWindow.addElement(btnSwapSides);

        var btnSaveJson = new EditorButton(10, 165, 240, 26, "Export Chart (.json)", exportJsonDialog);
        songPropertiesWindow.addElement(btnSaveJson);

        sectionWindow = new EditorWindow(FlxG.width - 285, 45, 270, 270, "Section Inspector");
        sectionWindow.cameras = [camUI];
        add(sectionWindow);

        infoText = new FlxText(10, 10, 250, "", 12);
        infoText.setFormat(Paths.font("vcr"), 12, EditorTheme.TEXT_PRIMARY, LEFT);
        sectionWindow.addElement(infoText);

        stepperSustain = new EditorNumericStepper(10, 130, 250, "Sustain Length (Steps)", 0, 0, 64, 1, 0, function(v) {
            if (curSelectedNote != null) {
                curSelectedNote.sustainLength = v * Conductor.stepCrochet;
                updateSectionView();
            }
        });
        sectionWindow.addElement(stepperSustain);

        var btnDelNote = new EditorButton(10, 175, 250, 26, "Delete Selected Note (Del)", function() {
            if (curSelectedNote != null) {
                chartNotes.remove(curSelectedNote);
                curSelectedNote = null;
                updateSectionView();
                EditorToast.show("Deleted note");
            }
        });
        sectionWindow.addElement(btnDelNote);
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        handleKeyboardShortcuts();
        handleMouseGridInput();

        if (isPlaying) {
            if (inst != null && inst.playing) {
                Conductor.songPosition = inst.time;
                if (vocals != null && vocals.playing && Math.abs(inst.time - vocals.time) > 20) {
                    vocals.time = inst.time;
                }
            } else {
                Conductor.songPosition += elapsed * 1000.0;
            }

            var calculatedStep = Math.floor(Conductor.songPosition / Conductor.stepCrochet);
            var targetSection = Math.floor(calculatedStep / STEPS_PER_SECTION);

            if (targetSection != curSection && targetSection >= 0) {
                curSection = targetSection;
                updateSectionView();
                updateDisplayInfo();
            }

            var stepRemainder = calculatedStep % STEPS_PER_SECTION;
            if (sectionIndicator != null) {
                sectionIndicator.y = stepRemainder * GRID_SIZE;
            }
        }
    }

    private function handleKeyboardShortcuts():Void {
        if (FlxG.keys.justPressed.SPACE) togglePlayback();

        if (!isPlaying) {
            if (FlxG.keys.justPressed.W || FlxG.keys.justPressed.UP) changeSection(-1);
            if (FlxG.keys.justPressed.S || FlxG.keys.justPressed.DOWN) changeSection(1);
            if (FlxG.keys.justPressed.A || FlxG.keys.justPressed.LEFT) changeSection(-4);
            if (FlxG.keys.justPressed.D || FlxG.keys.justPressed.RIGHT) changeSection(4);

            if (FlxG.keys.justPressed.DELETE || FlxG.keys.justPressed.BACKSPACE) {
                if (curSelectedNote != null) {
                    chartNotes.remove(curSelectedNote);
                    curSelectedNote = null;
                    updateSectionView();
                    EditorToast.show("Deleted Note");
                }
            }
        }

        if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.S) saveChartDirectly();
        if (FlxG.keys.justPressed.ENTER) testInGame();
        if (FlxG.keys.justPressed.ESCAPE) MusicBeatState.switchState(new MainMenuState());
    }

    private function handleMouseGridInput():Void {
        if (gridGroup == null || isPlaying) return;

        var mx = FlxG.mouse.x - gridGroup.x;
        var my = FlxG.mouse.y - gridGroup.y;

        if (mx >= 0 && mx < (LANES * GRID_SIZE) && my >= 0 && my < (STEPS_PER_SECTION * GRID_SIZE)) {
            var hoveredLane = Math.floor(mx / GRID_SIZE);
            var hoveredStep = Math.floor(my / GRID_SIZE);

            if (gridCursor != null) {
                gridCursor.visible = true;
                gridCursor.setPosition(hoveredLane * GRID_SIZE, hoveredStep * GRID_SIZE);
            }

            if (FlxG.mouse.justPressed) {
                var stepTime = (curSection * STEPS_PER_SECTION + hoveredStep) * Conductor.stepCrochet;
                var existingNote = findNoteAt(hoveredLane, stepTime);

                if (existingNote != null) {
                    curSelectedNote = existingNote;
                    stepperSustain.value = Math.round(existingNote.sustainLength / Conductor.stepCrochet);
                    EditorToast.show('Selected Note [Lane $hoveredLane]');
                } else {
                    var newNote:ChartEditorNote = {
                        time: stepTime,
                        lane: hoveredLane,
                        sustainLength: 0.0,
                        type: currentNoteType,
                        mustPress: (hoveredLane >= 4)
                    };
                    chartNotes.push(newNote);
                    curSelectedNote = newNote;
                    AssetHelper.playSoundSafely("scrollMenu", 0.4);
                }
                updateSectionView();
            } else if (FlxG.mouse.justPressedRight) {
                var stepTime = (curSection * STEPS_PER_SECTION + hoveredStep) * Conductor.stepCrochet;
                var existingNote = findNoteAt(hoveredLane, stepTime);
                if (existingNote != null) {
                    chartNotes.remove(existingNote);
                    if (curSelectedNote == existingNote) curSelectedNote = null;
                    updateSectionView();
                    AssetHelper.playSoundSafely("cancelMenu", 0.5);
                }
            }
        } else {
            if (gridCursor != null) gridCursor.visible = false;
        }
    }

    private function findNoteAt(lane:Int, time:Float):Null<ChartEditorNote> {
        var threshold = Conductor.stepCrochet * 0.45;
        for (n in chartNotes) {
            if (n.lane == lane && Math.abs(n.time - time) < threshold) {
                return n;
            }
        }
        return null;
    }

    private function updateSectionView():Void {
        renderedNotesGroup.clear();
        sustainNotesGroup.clear();

        var sectionStartTime = curSection * STEPS_PER_SECTION * Conductor.stepCrochet;
        var sectionEndTime = (curSection + 1) * STEPS_PER_SECTION * Conductor.stepCrochet;

        for (n in chartNotes) {
            if (n.time >= (sectionStartTime - 20) && n.time < (sectionEndTime - 10)) {
                var stepOffset = (n.time - sectionStartTime) / Conductor.stepCrochet;
                var noteY = gridGroup.y + (stepOffset * GRID_SIZE);
                var noteX = gridGroup.x + (n.lane * GRID_SIZE);

                var sprNote = new FlxSprite(noteX + 2, noteY + 2);
                sprNote.makeGraphic(GRID_SIZE - 4, GRID_SIZE - 4, getLaneColor(n.lane));
                if (n == curSelectedNote) {
                    sprNote.pixels.fillRect(new openfl.geom.Rectangle(4, 4, GRID_SIZE - 12, GRID_SIZE - 12), 0xFFFFFFFF);
                    sprNote.dirty = true;
                }
                renderedNotesGroup.add(sprNote);

                if (n.sustainLength > 0) {
                    var holdSteps = n.sustainLength / Conductor.stepCrochet;
                    var holdHeight = holdSteps * GRID_SIZE;
                    var sustainSpr = new FlxSprite(noteX + (GRID_SIZE * 0.35), noteY + GRID_SIZE);
                    sustainSpr.makeGraphic(Std.int(GRID_SIZE * 0.3), Std.int(holdHeight), getLaneColor(n.lane));
                    sustainSpr.alpha = 0.6;
                    sustainNotesGroup.add(sustainSpr);
                }
            }
        }
    }

    private function getLaneColor(lane:Int):FlxColor {
        return switch (lane % 4) {
            case 0: 0xFFC24B99;
            case 1: 0xFF00FFFF;
            case 2: 0xFF12FA05;
            case 3: 0xFFF9393F;
            default: 0xFFFFFFFF;
        };
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
            EditorToast.show("Playing Audio Timeline");
        } else {
            if (inst != null) inst.pause();
            if (vocals != null) vocals.pause();
            EditorToast.show("Paused Audio Timeline");
        }
    }

    private function updateDisplayInfo():Void {
        var curTimeSec = Math.round(Conductor.songPosition * 0.001 * 10) / 10;
        var totalNotes = chartNotes.length;

        infoText.text = 'SECTION: $curSection\n' +
            'STEP: ${curSection * STEPS_PER_SECTION}\n' +
            'TIME: ${curTimeSec}s\n' +
            'BPM: ${songData != null ? songData.bpm : 120.0}\n' +
            'TOTAL NOTES: $totalNotes';
    }

    private function swapCurrentSectionNotes():Void {
        var sectionStartTime = curSection * STEPS_PER_SECTION * Conductor.stepCrochet;
        var sectionEndTime = (curSection + 1) * STEPS_PER_SECTION * Conductor.stepCrochet;

        for (n in chartNotes) {
            if (n.time >= sectionStartTime && n.time < sectionEndTime) {
                n.lane = (n.lane < 4) ? (n.lane + 4) : (n.lane - 4);
                n.mustPress = (n.lane >= 4);
            }
        }
        updateSectionView();
        EditorToast.show("Swapped Section Lanes");
    }

    private function clearCurrentSection():Void {
        var sectionStartTime = curSection * STEPS_PER_SECTION * Conductor.stepCrochet;
        var sectionEndTime = (curSection + 1) * STEPS_PER_SECTION * Conductor.stepCrochet;

        chartNotes = chartNotes.filter(function(n) {
            return !(n.time >= sectionStartTime && n.time < sectionEndTime);
        });

        curSelectedNote = null;
        updateSectionView();
        updateDisplayInfo();
        EditorToast.show("Section Cleared");
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
            EditorToast.show('Saved to: $targetPath');
            AssetHelper.playSoundSafely("confirmMenu", 0.7);
        } catch (e:Dynamic) {
            try {
                File.saveContent(fallbackPath, formattedJson);
                EditorToast.show('Saved to: $fallbackPath');
                AssetHelper.playSoundSafely("confirmMenu", 0.7);
            } catch (err:Dynamic) {
                EditorToast.show("Failed to write chart to disk", true);
            }
        }
        #else
        exportJsonDialog();
        #end
    }

    private function exportJsonDialog():Void {
        var fileRef = new FileReference();
        fileRef.save(serializeChartToJson(), '${curDifficultyName.toLowerCase()}.json');
        EditorToast.show("Chart Export Initialized");
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
                notes: sectionList
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