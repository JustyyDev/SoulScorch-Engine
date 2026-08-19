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
import soulscorch.backend.input.Controls;
import soulscorch.backend.utils.Logger;
import soulscorch.gameplay.chart.Chart;
import soulscorch.gameplay.chart.Song;
import soulscorch.gameplay.song.SongLoader;
import soulscorch.scripting.mod.ModManager;
import soulscorch.ui.menus.editors.editorui.EditorButton;
import soulscorch.ui.menus.editors.editorui.EditorCheckbox;
import soulscorch.ui.menus.editors.editorui.EditorNumericStepper;
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
    private var gridSectionLine:FlxSprite;
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
    private var snapDivider:Int = 16;
    private var metronomeEnabled:Bool = false;

    // --- Editor Windows ---
    private var toolWindow:EditorWindow;
    private var actionWindow:EditorWindow;
    private var stepperBPM:EditorNumericStepper;
    private var stepperSpeed:EditorNumericStepper;
    private var checkMustHit:EditorCheckbox;
    private var checkMetronome:EditorCheckbox;

    // --- HUD Texts ---
    private var infoTxt:FlxText;
    private var helpTxt:FlxText;
    private var sectionTxt:FlxText;
    private var statusTxt:FlxText;
    private var statusTimer:Float = 0.0;

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
        createGridCanvas();

        grpSustains = new FlxSpriteGroup();
        add(grpSustains);

        grpNotes = new FlxSpriteGroup();
        add(grpNotes);

        grpEvents = new FlxSpriteGroup();
        add(grpEvents);

        cursorSprite = new FlxSprite().makeGraphic(GRID_SIZE, GRID_SIZE, 0x55FFFFFF);
        cursorSprite.visible = false;
        add(cursorSprite);

        loadAudio();
        setupHUD();
        setupToolboxes();

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

        var validBpm = (_song.bpm > 0) ? _song.bpm : 100.0;
        Conductor.changeBPM(validBpm);
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

        for (row in 0...ROWS_PER_SECTION) {
            for (col in 0...STRUM_COLS) {
                var isEven = (row + col) % 2 == 0;
                var color:FlxColor = isEven ? 0xFF231F2E : 0xFF2A2538;
                if (col == 4) color = 0xFF352F46;

                var cell = new FlxSprite(gridBG.x + (col * GRID_SIZE), gridBG.y + (row * GRID_SIZE)).makeGraphic(GRID_SIZE - 1, GRID_SIZE - 1, color);
                add(cell);
            }
        }

        for (i in 0...4) {
            var beatLine = new FlxSprite(gridBG.x, gridBG.y + (i * 4 * GRID_SIZE)).makeGraphic(gridW, 2, 0xFF665F7A);
            add(beatLine);
        }

        gridSectionLine = new FlxSprite(gridBG.x, gridBG.y).makeGraphic(gridW, 4, 0xFFFF0055);
        add(gridSectionLine);

        curSectionMarker = new FlxSprite(gridBG.x, gridBG.y).makeGraphic(gridW, 3, 0xFF00FFCC);
        add(curSectionMarker);
    }

    private function loadAudio():Void {
        var instSound = Paths.inst(curSong);
        if (instSound != null) {
            FlxG.sound.playMusic(instSound, 0, false);
            if (FlxG.sound.music != null) {
                FlxG.sound.music.pause();
                FlxG.sound.music.onComplete = function() {
                    pausePlayback();
                };
            }
        }

        var voiceSound = Paths.voices(curSong);
        if (voiceSound != null) {
            vocals = new FlxSound().loadEmbedded(voiceSound);
            FlxG.sound.list.add(vocals);
        }
    }

    private function setupHUD():Void {
        var bgHUD = new FlxSprite(0, 0).makeGraphic(330, FlxG.height, 0xEE120E1A);
        bgHUD.scrollFactor.set();
        bgHUD.cameras = [camHUD];
        add(bgHUD);

        infoTxt = new FlxText(15, 15, 300, "", 13);
        infoTxt.setFormat(Paths.font("vcr"), 13, FlxColor.WHITE, LEFT);
        infoTxt.scrollFactor.set();
        infoTxt.cameras = [camHUD];
        add(infoTxt);

        sectionTxt = new FlxText(15, 220, 300, "", 13);
        sectionTxt.setFormat(Paths.font("vcr"), 13, 0xFF00FFCC, LEFT);
        sectionTxt.scrollFactor.set();
        sectionTxt.cameras = [camHUD];
        add(sectionTxt);

        statusTxt = new FlxText(15, FlxG.height - 40, 300, "", 14);
        statusTxt.setFormat(Paths.font("vcr"), 14, 0xFF00FFCC, LEFT, OUTLINE, FlxColor.BLACK);
        statusTxt.scrollFactor.set();
        statusTxt.cameras = [camHUD];
        add(statusTxt);

        var rightHUD = new FlxSprite(FlxG.width - 330, 0).makeGraphic(330, FlxG.height, 0xEE120E1A);
        rightHUD.scrollFactor.set();
        rightHUD.cameras = [camHUD];
        add(rightHUD);

        helpTxt = new FlxText(FlxG.width - 315, 15, 300,
            "SOULSCORCH CHART STUDIO:\n\n" +
            "[L-CLICK] - Place Note / Sustain\n" +
            "[R-CLICK] - Delete Note\n" +
            "[SCROLL WHEEL] - Adjust Sustain Length\n" +
            "[SPACE] - Play / Pause Song\n" +
            "[W / S] - Step Navigation (1-16)\n" +
            "[Q / E] - Previous / Next Section\n" +
            "[TAB] - Toggle Must-Hit Section\n" +
            "[A / D] - Adjust Playback Speed\n" +
            "[1 / 2 / 3] - Snap Division (4/8/16)\n" +
            "[CTRL + C / V] - Copy / Paste Section\n" +
            "[CTRL + S] - Export Chart JSON\n" +
            "[ESCAPE] - Return to Main Menu",
            12
        );
        helpTxt.setFormat(Paths.font("vcr"), 12, 0xFFDDDDDD, LEFT);
        helpTxt.scrollFactor.set();
        helpTxt.cameras = [camHUD];
        add(helpTxt);
    }

    private function setupToolboxes():Void {
        toolWindow = new EditorWindow(10, FlxG.height - 270, 310, 260, "Song & Chart Properties");
        toolWindow.cameras = [camHUD];
        add(toolWindow);

        stepperBPM = new EditorNumericStepper(10, 8, 290, "Song BPM", _song.bpm, 1.0, 500.0, 1.0, 1, function(v) {
            _song.bpm = v;
            Conductor.changeBPM(v);
            updateInfoText();
        });
        toolWindow.addElement(stepperBPM);

        stepperSpeed = new EditorNumericStepper(10, 44, 290, "Scroll Speed", _song.speed, 0.5, 8.0, 0.1, 2, function(v) {
            _song.speed = v;
            updateInfoText();
        });
        toolWindow.addElement(stepperSpeed);

        checkMustHit = new EditorCheckbox(10, 82, "Must Hit Section", _song.notes[curSection] != null && _song.notes[curSection].mustHitSection, function(checked) {
            if (_song.notes[curSection] != null) {
                _song.notes[curSection].mustHitSection = checked;
                refreshSectionNotes();
                updateInfoText();
            }
        });
        toolWindow.addElement(checkMustHit);

        checkMetronome = new EditorCheckbox(160, 82, "Metronome", metronomeEnabled, function(checked) {
            metronomeEnabled = checked;
        });
        toolWindow.addElement(checkMetronome);

        var btnSave = new EditorButton(10, 116, 290, 32, "Export Chart JSON (Ctrl+S)", function() {
            saveChartJson();
        });
        toolWindow.addElement(btnSave);

        // --- Action Toolbox Window ---
        actionWindow = new EditorWindow(10, FlxG.height - 430, 310, 150, "Section Utilities");
        actionWindow.cameras = [camHUD];
        add(actionWindow);

        var btnCopy = new EditorButton(10, 8, 140, 30, "Copy Section", function() {
            copyCurrentSection();
        });
        actionWindow.addElement(btnCopy);

        var btnPaste = new EditorButton(160, 8, 140, 30, "Paste Section", function() {
            pasteCurrentSection();
        });
        actionWindow.addElement(btnPaste);

        var btnClear = new EditorButton(10, 46, 290, 30, "Clear All Notes in Section", function() {
            clearCurrentSection();
        });
        actionWindow.addElement(btnClear);
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (statusTimer > 0) {
            statusTimer -= elapsed;
            if (statusTimer <= 0) statusTxt.text = "";
        }

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

    override public function stepHit(step:Int):Void {
        super.stepHit(step);
        if (metronomeEnabled && (step % 4 == 0)) {
            AssetHelper.playSoundSafely("scrollMenu", 0.3);
        }
    }

    private function handleNavigationInput():Void {
        if (FlxG.keys.justPressed.E) changeSection(1);
        if (FlxG.keys.justPressed.Q) changeSection(-1);

        if (FlxG.keys.justPressed.W) changeStep(-1);
        if (FlxG.keys.justPressed.S) changeStep(1);

        if (FlxG.keys.justPressed.A) playbackSpeed = Math.max(0.25, playbackSpeed - 0.25);
        if (FlxG.keys.justPressed.D) playbackSpeed = Math.min(3.0, playbackSpeed + 0.25);

        if (FlxG.keys.justPressed.ONE) snapDivider = 4;
        if (FlxG.keys.justPressed.TWO) snapDivider = 8;
        if (FlxG.keys.justPressed.THREE) snapDivider = 16;

        if (FlxG.keys.justPressed.TAB) {
            if (_song.notes[curSection] != null) {
                _song.notes[curSection].mustHitSection = !_song.notes[curSection].mustHitSection;
                checkMustHit.checked = _song.notes[curSection].mustHitSection;
                refreshSectionNotes();
            }
        }

        if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.C) {
            copyCurrentSection();
        }

        if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.V) {
            pasteCurrentSection();
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

            if (FlxG.mouse.justPressed) {
                addNote(noteTime, col);
            }

            if (FlxG.mouse.justPressedRight) {
                deleteNote(noteTime, col);
            }

            if (FlxG.mouse.wheel != 0) {
                adjustSustain(noteTime, col, FlxG.mouse.wheel);
            }
        } else {
            cursorSprite.visible = false;
        }
    }

    private function handleKeyboardShortcuts():Void {
        if (FlxG.keys.justPressed.SPACE) {
            togglePlayback();
        }

        if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.S) {
            saveChartJson();
        }

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
        if (checkMustHit != null && _song.notes[curSection] != null) {
            checkMustHit.checked = _song.notes[curSection].mustHitSection;
        }
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

    private function copyCurrentSection():Void {
        var sec = _song.notes[curSection];
        if (sec != null) {
            copiedSection = {
                sectionNotes: [],
                mustHitSection: sec.mustHitSection,
                bpm: sec.bpm,
                changeBPM: sec.changeBPM,
                altAnim: sec.altAnim,
                lengthInSteps: sec.lengthInSteps
            };
            for (n in sec.sectionNotes) {
                copiedSection.sectionNotes.push([n[0], n[1], n[2]]);
            }
            statusTxt.text = "Section copied!";
            statusTimer = 2.0;
            AssetHelper.playSoundSafely("confirmMenu", 0.5);
        }
    }

    private function pasteCurrentSection():Void {
        if (copiedSection != null && _song.notes[curSection] != null) {
            var sec = _song.notes[curSection];
            sec.mustHitSection = copiedSection.mustHitSection;
            sec.bpm = copiedSection.bpm;
            sec.changeBPM = copiedSection.changeBPM;
            sec.altAnim = copiedSection.altAnim;
            sec.sectionNotes = [];

            var timeOffset = curSection * ROWS_PER_SECTION * Conductor.stepCrochet;
            var baseTime = copiedSection.sectionNotes.length > 0 ? copiedSection.sectionNotes[0][0] : 0;

            for (n in copiedSection.sectionNotes) {
                var relativeTime = n[0] - baseTime;
                sec.sectionNotes.push([timeOffset + relativeTime, n[1], n[2]]);
            }

            if (checkMustHit != null) checkMustHit.checked = sec.mustHitSection;
            refreshSectionNotes();
            statusTxt.text = "Section pasted!";
            statusTimer = 2.0;
        }
    }

    private function clearCurrentSection():Void {
        var sec = _song.notes[curSection];
        if (sec != null) {
            sec.sectionNotes = [];
            refreshSectionNotes();
            statusTxt.text = "Section cleared!";
            statusTimer = 2.0;
        }
    }

    private function addNote(time:Float, data:Int):Void {
        var sec = _song.notes[curSection];
        if (sec == null) return;

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

            var noteSpr = new FlxSprite(noteX + 2, noteY + 2).makeGraphic(GRID_SIZE - 4, GRID_SIZE - 4, noteColors[noteData]);
            grpNotes.add(noteSpr);

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

        infoTxt.text = 'CHART STUDIO\n\n' +
            'Song: ${_song.song}\n' +
            'Difficulty: ${curDifficulty.toUpperCase()}\n' +
            'BPM: ${_song.bpm}\n' +
            'Speed: ${_song.speed}\n' +
            'Playback: ${playbackSpeed}x\n' +
            'Snap: 1/$snapDivider\n' +
            'Time: ${Math.floor(Conductor.songPosition / 1000)}s';

        sectionTxt.text = 'SECTION STATS\n\n' +
            'Section: $curSection / ${_song.notes.length - 1}\n' +
            'Camera Focus: ${isPlayer ? "Boyfriend" : "Opponent"}\n' +
            'Steps in Sec: ${sec != null ? sec.lengthInSteps : 16}';
    }

    private function saveChartJson():Void {
        var formatted = Json.stringify({song: _song}, "\t");
        var fileName = curSong.toLowerCase().trim() + (curDifficulty == "normal" ? "" : '-$curDifficulty') + ".json";

        #if sys
        var targetDir = 'assets/data/${curSong.toLowerCase().trim()}';
        if (ModManager.activeMods != null && ModManager.activeMods.length > 0) {
            targetDir = 'mods/${ModManager.activeMods[0]}/data/${curSong.toLowerCase().trim()}';
        }
        var fullPath = '$targetDir/$fileName';

        try {
            if (!FileSystem.exists(targetDir)) {
                FileSystem.createDirectory(targetDir);
            }
            File.saveContent(fullPath, formatted);
            Logger.info('Successfully saved chart to $fullPath', "charting");
            statusTxt.text = "Chart saved successfully!";
            statusTimer = 2.5;
            AssetHelper.playSoundSafely("confirmMenu", 0.7);
        } catch (e:Dynamic) {
            Logger.error('Failed saving chart JSON: $e', "charting");
            statusTxt.text = "Save failed!";
            statusTimer = 2.5;
        }
        #else
        var fileRef = new FileReference();
        fileRef.save(formatted, fileName);
        statusTxt.text = "Chart exported!";
        statusTimer = 2.5;
        #end
    }
}