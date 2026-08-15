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
    public var bpm:Float;
    public var notes:Array<NoteData>;
    public var bpmChanges:Array<BPMChangeEvent>;

    public function new(bpm:Float = 140.0) {
        this.bpm = bpm;
        notes = [];
        bpmChanges = [];
    }

    public function addNote(time:Float, direction:Int, sustainLength:Float = 0, type:String = "", mustPress:Bool = true):Void {
        notes.push({ 
            time: time, 
            direction: direction, 
            sustainLength: sustainLength,
            type: type,
            mustPress: mustPress
        });
    }
}