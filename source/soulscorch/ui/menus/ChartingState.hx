package soulscorch.ui.menus;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import soulscorch.core.Scene;
import soulscorch.gameplay.Conductor;
import soulscorch.gameplay.NoteSprite;
import soulscorch.gameplay.Note;
import soulscorch.gameplay.EventMarker;
import soulscorch.gameplay.Chart.NoteData;
import soulscorch.gameplay.Chart.BPMChangeEvent;
#if sys
import sys.io.File;
#end
import haxe.Json;

class ChartingState extends Scene {
    var gridBG:FlxSprite;
    var eventLaneBG:FlxSprite;
    var gridGroup:FlxTypedGroup<FlxSprite>;
    var noteGroup:FlxTypedGroup<NoteSprite>;
    var eventGroup:FlxTypedGroup<EventMarker>;
    var strumLine:FlxSprite;
    
    var uiSidebar:FlxSprite;
    var infoText:FlxText;
    var propertiesText:FlxText;

    var curSong:String;
    var gridSnap:Int = 16;
    var currentSV:Float = 1.0;
    
    static inline var GRID_SIZE:Int = 40;
    static inline var GRID_COLS:Int = 8;
    static inline var EVENT_LANE_COLS:Int = 2;
    
    var chartNotes:Array<NoteData> = [];
    var bpmChanges:Array<BPMChangeEvent> = [];
    var svChanges:Array<Dynamic> = [];
    var isPlaying:Bool = false;
    
    var selectedEvent:EventMarker = null;

    public function new(songId:String = "engine-test") {
        super();
        this.curSong = songId;
    }

    override public function create():Void {
        super.create();

        FlxG.mouse.visible = true;
        Conductor.changeBPM(190);

        gridGroup = new FlxTypedGroup<FlxSprite>();
        add(gridGroup);
        
        eventLaneBG = new FlxSprite(0, 0).makeGraphic(GRID_SIZE * EVENT_LANE_COLS, FlxG.height * 2, 0xFF151515);
        eventLaneBG.screenCenter(X);
        eventLaneBG.x -= (GRID_SIZE * 5);
        add(eventLaneBG);

        gridBG = new FlxSprite(eventLaneBG.x + eventLaneBG.width + 10, 0).makeGraphic(GRID_SIZE * GRID_COLS, FlxG.height * 2, 0xFF202020);
        add(gridBG);
        
        drawGridLines();

        strumLine = new FlxSprite(eventLaneBG.x, FlxG.height / 2).makeGraphic(Std.int(eventLaneBG.width + 10 + gridBG.width), 4, 0xFFFFFFFF);
        add(strumLine);

        noteGroup = new FlxTypedGroup<NoteSprite>();
        add(noteGroup);
        
        eventGroup = new FlxTypedGroup<EventMarker>();
        add(eventGroup);

        buildSidebar();
    }

    function buildSidebar():Void {
        uiSidebar = new FlxSprite(FlxG.width - 300, 0).makeGraphic(300, FlxG.height, 0xFF101010);
        add(uiSidebar);

        infoText = new FlxText(uiSidebar.x + 10, 10, 280, "", 18);
        add(infoText);

        propertiesText = new FlxText(uiSidebar.x + 10, 200, 280, "NO EVENT SELECTED", 16);
        propertiesText.color = 0xFFAAAAAA;
        add(propertiesText);
    }

    function drawGridLines():Void {
        for (i in 0...EVENT_LANE_COLS + 1) {
            var line = new FlxSprite(eventLaneBG.x + (i * GRID_SIZE), 0).makeGraphic(2, FlxG.height * 2, 0xFF303030);
            line.scrollFactor.set(1, 0);
            gridGroup.add(line);
        }

        for (i in 0...GRID_COLS + 1) {
            var line = new FlxSprite(gridBG.x + (i * GRID_SIZE), 0).makeGraphic(2, FlxG.height * 2, 0xFF404040);
            line.scrollFactor.set(1, 0);
            gridGroup.add(line);
        }
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (FlxG.keys.justPressed.SPACE) {
            isPlaying = !isPlaying;
        }

        if (isPlaying) {
            Conductor.songPosition += elapsed * 1000;
        } else {
            if (FlxG.mouse.wheel != 0) {
                Conductor.songPosition += (FlxG.mouse.wheel * -0.05) * (1 / currentSV) * 1000;
            }
        }

        if (Conductor.songPosition < 0) Conductor.songPosition = 0;

        handleMouseInput();
        updateVisualRendering();

        infoText.text = 'TIMELINE\n\nPos: ${Math.floor(Conductor.songPosition)}ms\nSnap: 1/$gridSnap\nSV: ${currentSV}x';

        if (FlxG.keys.justPressed.ESCAPE) {
            FlxG.mouse.visible = false;
            FlxG.switchState(new MainMenuState());
        }
    }

    function handleMouseInput():Void {
        var mouseX = FlxG.mouse.x;
        var mouseY = FlxG.mouse.y;
        var timeOffset = (strumLine.y - mouseY) / (currentSV * 0.45);
        var hoverTime = Conductor.songPosition + timeOffset;
        var snapTime = Math.round(hoverTime / (Conductor.stepCrochet / (gridSnap / 4))) * (Conductor.stepCrochet / (gridSnap / 4));

        if (mouseX >= gridBG.x && mouseX <= gridBG.x + gridBG.width) {
            var col = Math.floor((mouseX - gridBG.x) / GRID_SIZE);
            if (FlxG.mouse.justPressed) placeNote(snapTime, col);
            if (FlxG.mouse.justPressedRight) removeNoteAt(snapTime, col);
        }

        if (mouseX >= eventLaneBG.x && mouseX <= eventLaneBG.x + eventLaneBG.width) {
            var col = Math.floor((mouseX - eventLaneBG.x) / GRID_SIZE);
            if (FlxG.mouse.justPressed) {
                selectEventAt(mouseY);
                if (selectedEvent == null) placeEvent(snapTime, col == 0 ? "BPM" : "SV");
            }
            if (FlxG.mouse.justPressedRight) removeEventAt(snapTime, col == 0 ? "BPM" : "SV");
        }
    }

    function placeNote(time:Float, col:Int):Void {
        var dir = col % 4;
        var mustPress = col > 3;

        for (n in chartNotes) {
            if (Math.abs(n.time - time) < 1.0 && n.direction == dir && n.mustPress == mustPress) return; 
        }

        chartNotes.push({ time: time, direction: dir, sustainLength: 0, type: "", mustPress: mustPress });
        refreshVisuals();
    }

    function removeNoteAt(time:Float, col:Int):Void {
        var dir = col % 4;
        var mustPress = col > 3;
        var i = chartNotes.length;
        
        while (i-- > 0) {
            var n = chartNotes[i];
            if (Math.abs(n.time - time) < 5.0 && n.direction == dir && n.mustPress == mustPress) chartNotes.splice(i, 1);
        }
        refreshVisuals();
    }

    function placeEvent(time:Float, type:String):Void {
        var marker = new EventMarker(time, type, type == "BPM" ? 190.0 : 1.0);
        eventGroup.add(marker);
        selectEventNode(marker);
    }

    function removeEventAt(time:Float, type:String):Void {
        for (marker in eventGroup.members) {
            if (marker != null && marker.type == type && Math.abs(marker.time - time) < 5.0) {
                if (selectedEvent == marker) selectEventNode(null);
                marker.kill();
                eventGroup.remove(marker, true);
                break;
            }
        }
    }

    function selectEventAt(mouseY:Float):Void {
        selectedEvent = null;
        for (marker in eventGroup.members) {
            if (marker != null && marker.overlapsPoint(FlxG.mouse.getWorldPosition())) {
                selectEventNode(marker);
                return;
            }
        }
        selectEventNode(null);
    }

    function selectEventNode(marker:EventMarker):Void {
        selectedEvent = marker;
        if (selectedEvent != null) {
            propertiesText.text = 'PROPERTIES\n\nType: ${marker.type}\nTime: ${marker.time}ms\nValue: ${marker.value}';
            propertiesText.color = 0xFFFFFFFF;
        } else {
            propertiesText.text = "NO EVENT SELECTED";
            propertiesText.color = 0xFFAAAAAA;
        }
    }

    function refreshVisuals():Void {
        noteGroup.clear();
        for (n in chartNotes) {
            var spr = new NoteSprite(new Note(n.time, n.direction, n.sustainLength, n.mustPress));
            spr.setGraphicSize(GRID_SIZE, GRID_SIZE);
            spr.updateHitbox();
            noteGroup.add(spr);
        }
    }

    function updateVisualRendering():Void {
        for (spr in noteGroup.members) {
            if (spr == null) continue;
            var col = spr.noteData.direction + (spr.noteData.mustPress ? 4 : 0);
            spr.x = gridBG.x + (col * GRID_SIZE);
            spr.y = strumLine.y + ((Conductor.songPosition - spr.noteData.strumTime) * (currentSV * 0.45));
        }

        for (marker in eventGroup.members) {
            if (marker == null) continue;
            var col = marker.type == "BPM" ? 0 : 1;
            marker.x = eventLaneBG.x + (col * GRID_SIZE);
            marker.y = strumLine.y + ((Conductor.songPosition - marker.time) * (currentSV * 0.45));
            marker.alpha = marker == selectedEvent ? 1.0 : 0.7;
        }

        var gridScrollOffset = (Conductor.songPosition * (currentSV * 0.45)) % GRID_SIZE;
        gridBG.y = -gridScrollOffset;
        eventLaneBG.y = -gridScrollOffset;
    }
}