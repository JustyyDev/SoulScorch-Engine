package soulscorch.gameplay;

class Song {
    public var id:String;
    public var title:String;
    public var bpm:Float;
    public var difficulty:String;
    public var stage:String;
    public var scrollSpeed:Float;
    
    public var player1:String;
    public var player2:String;
    public var gfVersion:String;
    
    public var chart:Chart;

    public function new(id:String, title:String) {
        this.id = id;
        this.title = title;
        this.bpm = 140.0;
        this.difficulty = "normal";
        this.stage = "stage";
        this.scrollSpeed = 1.0;
        
        this.player1 = "bf";
        this.player2 = "dad";
        this.gfVersion = "gf";
        
        chart = new Chart(bpm);
    }
}

typedef SongMetadata = {
    var id:String;
    var title:String;
    var bpm:Float;
    var difficulties:Array<String>;
    var stage:String;
    var scrollSpeed:Float;
    var player1:String;
    var player2:String;
    var gfVersion:String;
}