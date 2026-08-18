package soulscorch.gameplay.stage;

typedef StagePieceJson = {
    var name:String;
    var image:String;
    var position:Array<Float>;
    var scroll:Array<Float>;
    var scale:Array<Float>;
    var layer:String; // "behindGF", "behindDad", "behindBF", "foreground"
    var ?animated:Bool;
    var ?antialiasing:Bool;
    var ?alpha:Float;
}

typedef CharacterSpawnJson = {
    var position:Array<Float>;
    var scale:Float;
    var ?cameraOffset:Array<Float>;
}

typedef StageJson = {
    var name:String;
    var defaultZoom:Float;
    var boyfriend:CharacterSpawnJson;
    var dad:CharacterSpawnJson;
    var girlfriend:CharacterSpawnJson;
    var pieces:Array<StagePieceJson>;
    var ?hideGirlfriend:Bool;
}