package soulscorch.gameplay.chart;

typedef NoteData = {
    var time:Float;
    var direction:Int;
    var sustainLength:Float;
    var type:String;
    var mustPress:Bool;
}

typedef ChartBPMChange = {
    var stepTime:Int;
    var songTime:Float;
    var bpm:Float;
    var ?stepCrochet:Float;
}

typedef ChartEvent = {
    var time:Float;
    var name:String;
    var val1:String;
    var val2:String;
}

class Chart {
    public var bpm:Float = 100.0;
    public var scrollSpeed:Float = 2.0;
    public var notes:Array<NoteData> = [];
    public var bpmChanges:Array<ChartBPMChange> = [];
    public var events:Array<ChartEvent> = [];

    public function new(bpm:Float = 140.0, scrollSpeed:Float = 2.0) {
        this.bpm = bpm;
        this.scrollSpeed = scrollSpeed;
        this.notes = [];
        this.bpmChanges = [];
        this.events = [];
    }

    public function addNote(time:Float, direction:Int, sustainLength:Float = 0.0, type:String = "Default", mustPress:Bool = true):Void {
        notes.push({
            time: time,
            direction: direction,
            sustainLength: sustainLength,
            type: (type != null && type.length > 0) ? type : "Default",
            mustPress: mustPress
        });
    }

    public function addEvent(time:Float, name:String, val1:String = "", val2:String = ""):Void {
        events.push({
            time: time,
            name: (name != null) ? name : "",
            val1: (val1 != null) ? val1 : "",
            val2: (val2 != null) ? val2 : ""
        });
    }

    public function addBpmChange(stepTime:Int, songTime:Float, newBpm:Float):Void {
        var stepCrochet:Float = ((60.0 / newBpm) * 1000.0) / 4.0;
        bpmChanges.push({
            stepTime: stepTime,
            songTime: songTime,
            bpm: newBpm,
            stepCrochet: stepCrochet
        });
    }

    public function sortNotes():Void {
        notes.sort(function(a:NoteData, b:NoteData):Int {
            return (a.time < b.time) ? -1 : (a.time > b.time ? 1 : 0);
        });
    }

    public function sortEvents():Void {
        events.sort(function(a:ChartEvent, b:ChartEvent):Int {
            return (a.time < b.time) ? -1 : (a.time > b.time ? 1 : 0);
        });
    }

    public function getNotesInRange(minTime:Float, maxTime:Float):Array<NoteData> {
        return notes.filter(function(n:NoteData) return n.time >= minTime && n.time <= maxTime);
    }

    public function clone():Chart {
        var copy = new Chart(this.bpm, this.scrollSpeed);
        for (n in notes) copy.addNote(n.time, n.direction, n.sustainLength, n.type, n.mustPress);
        for (e in events) copy.addEvent(e.time, e.name, e.val1, e.val2);
        for (b in bpmChanges) copy.addBpmChange(b.stepTime, b.songTime, b.bpm);
        return copy;
    }

    public function clear():Void {
        notes = [];
        events = [];
        bpmChanges = [];
    }
}