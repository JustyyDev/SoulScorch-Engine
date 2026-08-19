package soulscorch.gameplay.stage;

typedef StageAnimationDef = {
    var anim:String;
    var name:String;
    var ?fps:Float;
    var ?loop:Bool;
    var ?indices:Array<Int>;
    var ?offsets:Array<Float>;
}

typedef StagePieceJson = {
    var ?id:String;
    var ?name:String;
    var image:String;
    var ?position:Array<Float>;
    var ?x:Float;
    var ?y:Float;
    var ?scroll:Array<Float>;
    var ?scrollX:Float;
    var ?scrollY:Float;
    var ?scale:Array<Float>;
    var ?scaleX:Float;
    var ?scaleY:Float;
    var ?layer:String; // "background", "behindGF", "behindDad", "behindBF", "foreground"
    var ?animated:Bool;
    var ?animations:Array<StageAnimationDef>;
    var ?antialiasing:Bool;
    var ?alpha:Float;
    var ?color:String;
}

typedef CharacterSpawnJson = {
    var ?position:Array<Float>;
    var ?scale:Float;
    var ?cameraOffset:Array<Float>;
    var ?camera_offsets:Array<Float>;
}

typedef StageJson = {
    var ?name:String;
    var ?stage:String;
    var ?defaultZoom:Float;
    var ?cameraSpeed:Float;
    var ?camera_speed:Float;
    var ?hideGirlfriend:Bool;
    var ?hide_girlfriend:Bool;

    // Supports both object spawn declarations and flat float arrays
    var ?boyfriend:Dynamic;
    var ?opponent:Dynamic;
    var ?dad:Dynamic;
    var ?girlfriend:Dynamic;
    var ?gf:Dynamic;

    var ?pieces:Array<StagePieceJson>;
    var ?sprites:Array<StagePieceJson>;
    var ?objects:Array<StagePieceJson>;
}