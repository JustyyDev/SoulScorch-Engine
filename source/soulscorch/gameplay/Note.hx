package soulscorch.gameplay;

class Note {
    public var time:Float;
    public var direction:Int;
    public var hit:Bool;
    public var sustainLength:Float;
    public var isSustainNote:Bool;
    public var mustPress:Bool;
    public var wasGoodHit:Bool;
    public var tooLate:Bool;
    public var canBeHit:Bool;

    public function new(time:Float, direction:Int, sustainLength:Float = 0, mustPress:Bool = true, isSustainNote:Bool = false) {
        this.time = time;
        this.direction = direction;
        this.sustainLength = sustainLength;
        this.mustPress = mustPress;
        this.isSustainNote = isSustainNote;
        
        this.hit = false;
        this.wasGoodHit = false;
        this.tooLate = false;
        this.canBeHit = false;
    }
}