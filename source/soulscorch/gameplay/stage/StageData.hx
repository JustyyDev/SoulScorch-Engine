package soulscorch.gameplay.stage;

typedef StageSpriteData = {
    var name:String;
    var image:String;
    var ?x:Float;
    var ?y:Float;
    var ?scrollX:Float;
    var ?scrollY:Float;
    var ?scaleX:Float;
    var ?scaleY:Float;
    var ?layer:String;
    var ?antialiasing:Bool;
    var ?alpha:Float;
    var ?animated:Bool;
    var ?animations:Array<{
        name:String,
        prefix:String,
        fps:Int,
        loop:Bool,
        ?indices:Array<Int>
    }>;
    var ?firstAnimation:String;
}

typedef StageJson = {
    var name:String;
    var defaultZoom:Float;
    var ?cameraSpeed:Float;
    var ?boyfriend:Array<Float>;
    var ?girlfriend:Array<Float>;
    var ?opponent:Array<Float>;
    var ?hideGirlfriend:Bool;
    var ?sprites:Array<StageSpriteData>;
    var ?model3D:String;
    var ?modelTexture:String;
}