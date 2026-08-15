package soulscorch.gameplay;

class Note {
    public var strumTime:Float;
    public var direction:Int;
    public var noteData(get, set):Int;
    public var sustainLength:Float;
    public var isSustainNote:Bool;
    public var mustPress:Bool;
    public var noteType:String = "Default";

    public var hit:Bool = false;
    public var wasGoodHit:Bool = false;
    public var tooLate:Bool = false;
    public var canBeHit:Bool = false;

    public var hitHealth:Float = 0.025;
    public var missHealth:Float = 0.0475;
    public var rating:String = "sick";
    public var distance:Float = 2000;

    public function new(strumTime:Float, direction:Int, sustainLength:Float = 0, mustPress:Bool = true, isSustainNote:Bool = false, noteType:String = "Default") {
        this.strumTime = strumTime;
        this.direction = direction;
        this.sustainLength = sustainLength;
        this.mustPress = mustPress;
        this.isSustainNote = isSustainNote;
        this.noteType = noteType;
    }

    inline function get_noteData():Int return direction;
    inline function set_noteData(val:Int):Int return direction = val;
}