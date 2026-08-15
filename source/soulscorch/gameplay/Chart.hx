package soulscorch.gameplay;

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

class Chart {
    public var bpm:Float = 100.0;
    public var scrollSpeed:Float = 2.0;
    public var notes:Array<Note> = [];
    public var bpmChanges:Array<BPMChangeEvent> = [];

    public function new(bpm:Float = 140.0, scrollSpeed:Float = 2.0) {
        this.bpm = bpm;
        this.scrollSpeed = scrollSpeed;
        this.notes = [];
        this.bpmChanges = [];
    }

    public function addNote(time:Float, direction:Int, sustainLength:Float = 0, type:String = "Default", mustPress:Bool = true):Void {
        notes.push(new Note(time, direction, sustainLength, mustPress, false, type));
    }
}