package soulscorch.backend.interfaces;

interface IBeatReceiver {
    function beatHit(beat:Int):Void;
    function stepHit(step:Int):Void;
}