package soulscorch.ui.menus.editors;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import haxe.Json;
import openfl.net.FileReference;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.audio.Conductor;
import soulscorch.gameplay.chart.Chart;
import soulscorch.gameplay.chart.Song;
import soulscorch.scripting.mod.ModManager;
import soulscorch.ui.menus.editors.editorui.EditorButton;
import soulscorch.ui.menus.editors.editorui.EditorCheckbox;
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
    private var camHUD:FlxCamera;

    public static inline var GRID_SIZE:Int = 40;
    public static inline var STRUM_COLS:Int = 8;
    public static inline var ROWS_PER_SECTION:Int = 16;

    private var gridBG:FlxSprite;
    private var curSectionMarker:FlxSprite;
    private var cursorSprite:FlxSprite;

    private var grpNotes:FlxSpriteGroup;
    private var grpSustains:FlxSpriteGroup;

    private var vocals:FlxSound;
    private var curSection:Int = 0;
    private var curStepSelected:Int = 0;
    private var isPlaying:Bool = false;
    private var playbackSpeed:Float = 1.0;
    private var metronomeEnabled:Bool = false;

    private var topBar:EditorTopBar;
    private var infoTxt:FlxText;

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

        createGridCanvas();

        grpSustains = new FlxSpriteGroup();
        add(grpSustains);

        grpNotes = new FlxSpriteGroup();
        add(grpNotes);

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
                notes: []
            };
        }

        if (_song.notes == null || _song.notes.length == 0) createSection();
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

    private function createGridCanvas():Void {
        var gridW = GRID_SIZE * STRUM_COLS;
        var gridH = GRID_SIZE * ROWS_PER_SECTION;

        gridBG = new FlxSprite(0, 40).makeGraphic(gridW, gridH, EditorTheme.GRID_EVEN);
        gridBG.screenCenter(X);
        add(gridBG);

        for (row in 0...ROWS_PER_SECTION) {
            for (col in 0...STRUM_COLS) {
                var isEven = (row + col) % 2 == 0;
                var color:FlxColor = isEven ? EditorTheme.GRID_EVEN : EditorTheme.GRID_ODD;
                if (col == 4) color = EditorTheme.GRID_SEPARATOR;

                var cell = new FlxSprite(gridBG.x + (col * GRID_SIZE), gridBG.y + (row * GRID_SIZE)).makeGraphic(GRID_SIZE - 1, GRID_SIZE - 1, color);
                add(cell);
            }
        }

        for (i in 0...4) {
            var beatLine = new FlxSprite(gridBG.x, gridBG.y + (i * 4 * GRID_SIZE)).makeGraphic(gridW, 2, EditorTheme.ACCENT_PURPLE);
            add(beatLine);
        }

        curSectionMarker = new FlxSprite(gridBG.x, gridBG.y).makeGraphic(gridW, 3, EditorTheme.ACCENT_CYAN);
        add(curSectionMarker);
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
        topBar = new EditorTopBar('CHART STUDIO [${curSong.toUpperCase()}]');
        topBar.cameras = [camHUD];
        topBar.addAction("Save (Ctrl+S)", saveChartJson);
        topBar.addAction("Exit", function() {
            if (FlxG.sound.music != null) FlxG.sound.music.stop();
            if (vocals != null) vocals.stop();
            MusicBeatState.switchState(new MainMenuState());
        });
        add(topBar);

        var infoWindow = new EditorWindow(15, 45, 290, 240, "Song Metronome");
        infoWindow.cameras = [camHUD];
        add(infoWindow);

        infoTxt = new FlxText(10, 8, 270, "", 13);
        infoTxt.setFormat(Paths.font("vcr"), 13, EditorTheme.TEXT_PRIMARY, LEFT);
        infoWindow.addElement(infoTxt);

        var controlWindow = new EditorWindow(FlxG.width - 305, 45, 290, 240, "Section Tools");
        controlWindow.cameras = [camHUD];
        add(controlWindow);

        var btnCopy = new EditorButton(10, 8, 130, 28, "Copy Section", copyCurrentSection);
        controlWindow.addElement(btnCopy);

        var btnPaste = new EditorButton(150, 8, 130, 28, "Paste Section", pasteCurrentSection);
        controlWindow.addElement(btnPaste);

        var btnClear = new EditorButton(10, 44, 270, 28, "Clear Notes", clearCurrentSection);
        controlWindow.addElement(btnClear);

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
        if (FlxG.keys.justPressed.E) changeSection(1);
        if (FlxG.keys.justPressed.Q) changeSection(-1);
        if (FlxG.keys.justPressed.W) changeStep(-1);
        if (FlxG.keys.justPressed.S) changeStep(1);

        if (FlxG.keys.justPressed.TAB && _song.notes[curSection] != null) {
            _song.notes[curSection].mustHitSection = !_song.notes[curSection].mustHitSection;
            refreshSectionNotes();
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

            if (FlxG.mouse.justPressed) addNote(noteTime, col);
            if (FlxG.mouse.justPressedRight) deleteNote(noteTime, col);
            if (FlxG.mouse.wheel != 0) adjustSustain(noteTime, col, FlxG.mouse.wheel);
        } else {
            cursorSprite.visible = false;
        }
    }

    private function changeSection(change:Int):Void {
        curSection = Std.int(Math.max(0, curSection + change));
        while (curSection >= _song.notes.length) createSection();

        Conductor.songPosition = curSection * ROWS_PER_SECTION * Conductor.stepCrochet;
        if (FlxG.sound.music != null) FlxG.sound.music.time = Conductor.songPosition;
        curSectionMarker.y = gridBG.y;
        refreshSectionNotes();
    }

    private function changeStep(change:Int):Void {
        curStepSelected = FlxMath.wrap(curStepSelected + change, 0, ROWS_PER_SECTION - 1);
        curSectionMarker.y = gridBG.y + (curStepSelected * GRID_SIZE);

        Conductor.songPosition = ((curSection * ROWS_PER_SECTION) + curStepSelected) * Conductor.stepCrochet;
        if (FlxG.sound.music != null) FlxG.sound.music.time = Conductor.songPosition;
    }

    private function togglePlayback():Void {
        isPlaying = !isPlaying;
        if (isPlaying) {
            Conductor.songPosition = ((curSection * ROWS_PER_SECTION) + curStepSelected) * Conductor.stepCrochet;
            if (FlxG.sound.music != null) { FlxG.sound.music.time = Conductor.songPosition; FlxG.sound.music.play(); }
            if (vocals != null) { vocals.time = Conductor.songPosition; vocals.play(); }
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

    private function refreshSectionNotes():Void {
        grpNotes.clear();
        grpSustains.clear();

        var sec = _song.notes[curSection];
        if (sec == null) return;
        var noteColors = [0xFFC24B99, 0xFF00FFFF, 0xFF12FA05, 0xFFF9393F, 0xFFC24B99, 0xFF00FFFF, 0xFF12FA05, 0xFFF9393F];

        for (n in sec.sectionNotes) {
            var time:Float = n[0];
            var noteData:Int = Std.int(n[1]) % STRUM_COLS;
            var susLen:Float = n[2];

            var stepIdx = Math.floor((time - (curSection * ROWS_PER_SECTION * Conductor.stepCrochet)) / Conductor.stepCrochet);
            var nx = gridBG.x + (noteData * GRID_SIZE);
            var ny = gridBG.y + (stepIdx * GRID_SIZE);

            var noteSpr = new FlxSprite(nx + 2, ny + 2).makeGraphic(GRID_SIZE - 4, GRID_SIZE - 4, noteColors[noteData]);
            grpNotes.add(noteSpr);

            if (susLen > 0) {
                var susH = Std.int((susLen / Conductor.stepCrochet) * GRID_SIZE);
                var susSpr = new FlxSprite(nx + (GRID_SIZE * 0.35), ny + GRID_SIZE).makeGraphic(Std.int(GRID_SIZE * 0.3), susH, noteColors[noteData]);
                susSpr.alpha = 0.6;
                grpSustains.add(susSpr);
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
        infoTxt.text = 'BPM: ${_song.bpm}\nSpeed: ${_song.speed}\nSection: $curSection / ${_song.notes.length - 1}\nFocus: ${(sec != null && sec.mustHitSection) ? "Boyfriend" : "Opponent"}\nPlayback: ${playbackSpeed}x';
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
            EditorToast.show("Chart Exported Successfully!");
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