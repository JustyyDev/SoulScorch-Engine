package soulscorch.gameplay.chart;

import flixel.util.FlxColor;
import soulscorch.gameplay.chart.Chart;

class Song {
    public var id:String;
    public var song:String;
    public var title:String;
    public var artist:String = "Unknown";
    public var charter:String = "Unknown";

    public var bpm:Float = 100.0;
    public var difficulty:String = "normal";
    public var scrollSpeed:Float = 2.0;
    public var stage:String = "stage";

    public var player1:String = "bf";
    public var player2:String = "dad";
    public var gfVersion:String = "gf";

    public var needsVoices:Bool = true;
    public var color:Null<FlxColor> = null;
    public var chart:Chart;

    public function new(id:String, title:String = "") {
        this.id = id;
        this.song = id;
        this.title = (title != null && title.length > 0) ? title : id;
        this.chart = new Chart(bpm, scrollSpeed);
    }
}