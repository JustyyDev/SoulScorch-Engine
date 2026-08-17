package soulscorch.ui.menus.editors.chart;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.display.FlxGridOverlay;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import haxe.Json;
import lime.system.Clipboard;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.audio.AudioManager;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.input.Controls;
import soulscorch.backend.system.modules.discord.DiscordRPC;
import soulscorch.gameplay.chart.Chart;
import soulscorch.gameplay.chart.Song;
import soulscorch.gameplay.notes.Note;
import soulscorch.gameplay.song.SongLoader;
import soulscorch.ui.menus.editors.EditorPickerMenu;

class ChartEditor extends MusicBeatState {
    public static var GRID_SIZE:Int = 40;
    public static var LANES:Int = 8;

    public var songData:Song;
    public var audio:AudioManager;

    public var gridGroup:FlxTypedGroup<FlxSprite>;
    public var noteGroup:FlxTypedGroup<FlxSprite>;
    public var curSection:Int = 0;

    private var strumLine:FlxSprite;
    private var infoText:FlxText;
    private var selectedNoteType:String = "Default";

    public var camGrid:FlxCamera;
    public var camHUD:FlxCamera;

    override public function create():Void {
        super.create();

        DiscordRPC.changePresence("Chart Editor", "Editing Chart Timeline");

        camGrid = new FlxCamera();
        camHUD = new FlxCamera();
        camHUD.bgColor.alpha = 0;

        FlxG.cameras.reset(camGrid);
        FlxG.cameras.add(camHUD, false);
        FlxG.cameras.setDefaultDrawTarget(camGrid, true);

        audio = new AudioManager();

        loadSong("tutorial", "normal");

        setupGrid();
        setupHUD();
    }

    private function loadSong(songId:String, diff:String):Void {
        try {
            songData = SongLoader.load(songId, diff);
        } catch (e:Dynamic) {
            songData = new Song(songId, songId);
        }

        Conductor.changeBPM(songData.bpm);
        audio.loadSong(songId);
    }

    private function setupGrid():Void {
        gridGroup = new FlxTypedGroup<FlxSprite>();
        noteGroup = new FlxTypedGroup<FlxSprite>();
        add(gridGroup);
        add(noteGroup);

        rebuildGrid();

        strumLine = new FlxSprite(0, 0).makeGraphic(LANES * GRID_SIZE, 4, 0xFF00FFFF);
        strumLine.x = (FlxG.width - (LANES * GRID_SIZE)) * 0.5;
        add(strumLine);
    }

    private function rebuildGrid():Void {
        gridGroup.clear();

        var gridX = (FlxG.width - (LANES * GRID_SIZE)) * 0.5;
        var totalSteps = 16;
        var grid = FlxGridOverlay.create(GRID_SIZE, GRID_SIZE, LANES * GRID_SIZE, totalSteps * GRID_SIZE, true, 0xFF353545, 0xFF2A2A38);
        grid.x = gridX;
        grid.y = 0;
        gridGroup.add(grid);

        // Center lane divider separating opponent and player sides
        var divider = new FlxSprite(gridX + (4 * GRID_SIZE) - 1, 0).makeGraphic(2, totalSteps * GRID_SIZE, 0xFFFFFFFF);
        gridGroup.add(divider);

        renderNotes();
    }

    private function renderNotes():Void {
        noteGroup.clear();

        var gridX = (FlxG.width - (LANES * GRID_SIZE)) * 0.5;
        var stepTime = Conductor.stepCrochet;
        var sectionStart = curSection * 16 * stepTime;
        var sectionEnd = (curSection + 1) * 16 * stepTime;

        if (songData == null || songData.chart == null) return;

        for (n in songData.chart.notes) {
            if (n.time >= sectionStart && n.time < sectionEnd) {
                var lane = n.direction + (n.mustPress ? 4 : 0);
                var relY = ((n.time - sectionStart) / stepTime) * GRID_SIZE;

                var noteSpr = new FlxSprite(gridX + (lane * GRID_SIZE) + 2, relY + 2);
                noteSpr.makeGraphic(GRID_SIZE - 4, GRID_SIZE - 4, Note.colorForDirection(n.direction));
                noteGroup.add(noteSpr);

                if (n.sustainLength > 0) {
                    var susHeight = (n.sustainLength / stepTime) * GRID_SIZE;
                    var susSpr = new FlxSprite(noteSpr.x + (GRID_SIZE * 0.4), noteSpr.y + GRID_SIZE).makeGraphic(6, Std.int(susHeight), noteSpr.color);
                    susSpr.alpha = 0.6;
                    noteGroup.add(susSpr);
                }
            }
        }
    }

    private function setupHUD():Void {
        var bg = new FlxSprite(0, 0).makeGraphic(FlxG.width, 40, 0xDD0D111A);
        bg.cameras = [camHUD];
        add(bg);

        infoText = new FlxText(15, 8, FlxG.width - 30, "", 18);
        infoText.setFormat(Paths.font("vcr"), 18, FlxColor.WHITE, LEFT);
        infoText.cameras = [camHUD];
        add(infoText);

        var bottomHelp = new FlxText(15, FlxG.height - 35, FlxG.width - 30, "[SPACE] Play/Pause | [A/D] Change Section | [L-CLICK] Place Note | [R-CLICK] Delete Note | [CTRL + S] Save", 16);
        bottomHelp.setFormat(Paths.font("vcr"), 16, 0xFFFFCC00, LEFT);
        bottomHelp.cameras = [camHUD];
        add(bottomHelp);
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        audio.update(elapsed);

        var stepTime = Conductor.stepCrochet;
        var sectionStart = curSection * 16 * stepTime;

        if (audio.isPlaying && audio.inst != null) {
            Conductor.songPosition = audio.inst.time;
            var relTime = Conductor.songPosition - sectionStart;
            strumLine.y = (relTime / stepTime) * GRID_SIZE;

            if (Conductor.songPosition >= (curSection + 1) * 16 * stepTime) {
                curSection++;
                rebuildGrid();
            }
        }

        // Section navigation
        if (FlxG.keys.justPressed.A) { changeSection(-1); }
        if (FlxG.keys.justPressed.D) { changeSection(1); }

        // Play / Pause audio playback
        if (FlxG.keys.justPressed.SPACE) {
            if (audio.isPlaying) {
                audio.pause();
            } else {
                audio.setTime(sectionStart);
                audio.play();
            }
        }

        // Mouse grid placement
        var gridX = (FlxG.width - (LANES * GRID_SIZE)) * 0.5;
        if (FlxG.mouse.x >= gridX && FlxG.mouse.x < gridX + (LANES * GRID_SIZE) && FlxG.mouse.y >= 0 && FlxG.mouse.y < 16 * GRID_SIZE) {
            var lane = Math.floor((FlxG.mouse.x - gridX) / GRID_SIZE);
            var stepRow = Math.floor(FlxG.mouse.y / GRID_SIZE);
            var noteTime = sectionStart + (stepRow * stepTime);

            if (FlxG.mouse.justPressed) {
                var direction = lane % 4;
                var mustPress = lane >= 4;
                songData.chart.addNote(noteTime, direction, 0, selectedNoteType, mustPress);
                renderNotes();
            }

            if (FlxG.mouse.justPressedRight) {
                deleteNoteAt(noteTime, lane);
                renderNotes();
            }
        }

        if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.S) {
            exportChartJson();
        }

        if (Controls.instance.BACK) {
            audio.stop();
            MusicBeatState.switchState(new EditorPickerMenu());
        }

        infoText.text = 'Song: ${songData.id} | BPM: ${songData.bpm} | Section: $curSection | Time: ${Math.floor(Conductor.songPosition)}ms';
    }

    private function deleteNoteAt(time:Float, lane:Int):Void {
        var direction = lane % 4;
        var mustPress = lane >= 4;

        for (n in songData.chart.notes) {
            if (Math.abs(n.time - time) < 10 && n.direction == direction && n.mustPress == mustPress) {
                songData.chart.notes.remove(n);
                break;
            }
        }
    }

    private function changeSection(change:Int):Void {
        curSection = Std.int(Math.max(0, curSection + change));
        audio.setTime(curSection * 16 * Conductor.stepCrochet);
        rebuildGrid();
    }

    private function exportChartJson():Void {
        var exportObj:Dynamic = {
            song: {
                song: songData.id,
                bpm: songData.bpm,
                speed: songData.scrollSpeed,
                player1: songData.player1,
                player2: songData.player2,
                gfVersion: songData.gfVersion,
                stage: songData.stage,
                notes: []
            }
        };

        var output = Json.stringify(exportObj, "\t");
        Clipboard.text = output;
        FlxG.camera.flash(FlxColor.GREEN, 0.4);
    }
}