package soulscorch.gameplay.chart;

typedef NoteData = {
    var time:Float;
    var direction:Int;
    var sustainLength:Float;
    var type:String;
    var mustPress:Bool;
}

typedef BPMChangeEvent = {
    var stepTime:Int;
    var time:Float;
    var bpm:Float;
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
    public var bpmChanges:Array<BPMChangeEvent> = [];
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
            type: type,
            mustPress: mustPress
        });
    }

    public function addEvent(time:Float, name:String, val1:String = "", val2:String = ""):Void {
        events.push({
            time: time,
            name: name,
            val1: val1,
            val2: val2
        });
    }

    public function sortNotes():Void {
        notes.sort(function(a, b) return (a.time < b.time) ? -1 : (a.time > b.time) ? 1 : 0);
    }

    public function sortEvents():Void {
        events.sort(function(a, b) return (a.time < b.time) ? -1 : (a.time > b.time) ? 1 : 0);
    }
}