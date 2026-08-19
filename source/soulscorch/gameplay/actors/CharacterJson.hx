package soulscorch.gameplay.actors;

typedef AnimationData = {
    var anim:String;
    var name:String;
    var ?fps:Float;
    var ?loop:Bool;
    var ?indices:Array<Int>;
    var ?offsets:Array<Float>;
}

typedef CharacterJson = {
    var ?animations:Array<AnimationData>;
    var ?image:String;
    var ?scale:Float;
    var ?sing_duration:Float;
    var ?singDuration:Float;
    var ?healthicon:String;
    var ?healthIcon:String;
    var ?position:Array<Float>;
    var ?camera_position:Array<Float>;
    var ?cameraPosition:Array<Float>;
    var ?flip_x:Bool;
    var ?flipX:Bool;
    var ?no_antialiasing:Bool;
    var ?noAntialiasing:Bool;
    var ?healthbar_colors:Array<Int>;
    var ?healthBarColor:Array<Int>;
    var ?vocals_file:String;

    // 3D Model Properties
    var ?is3D:Bool;
    var ?modelPath:String;
    var ?texturePath:String;
    var ?meshScale:Float;
    var ?meshRotation:Array<Float>;
    var ?meshOffset:Array<Float>;
}