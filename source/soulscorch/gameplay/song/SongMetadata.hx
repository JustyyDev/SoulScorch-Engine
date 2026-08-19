package soulscorch.gameplay.song;

typedef SongMetadata = {
    var title:String;
    var ?artist:String;
    var ?charter:String;
    var ?bpm:Float;
    var ?stage:String;
    var ?player1:String;
    var ?player2:String;
    var ?gfVersion:String;
    var ?difficulties:Array<String>;
    var ?color:String;
    var ?freeplayIcon:String;
    var ?icon:String;
    var ?cutscene:String;
    var ?endCutscene:String;
    var ?needsVoices:Bool;
    var ?previewStart:Float;
    var ?previewEnd:Float;
    var ?week:Int;
    var ?locked:Bool;
}