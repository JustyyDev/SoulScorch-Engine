package soulscorch.gameplay.actors;

typedef AnimationData = {
    var anim:String;
    var name:String;
    var fps:Float;
    var loop:Bool;
    var indices:Array<Int>;
    var offsets:Array<Float>;
}

typedef CharacterJson = {
    var animations:Array<AnimationData>;
    var image:String;
    var scale:Float;
    var singDuration:Float;
    var healthIcon:String;
    var position:Array<Float>;
    var cameraPosition:Array<Float>;
    var flipX:Bool;
    var noAntialiasing:Bool;
    var healthBarColor:Array<Int>;
}