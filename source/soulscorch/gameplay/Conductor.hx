package soulscorch.gameplay;

class Conductor {
    public static var songPosition:Float = 0;
    public var safeZoneOffset:Float = 45; // Standard FNF hit window
    public var bpm:Float = 100;
    public var crochet:Float = ((60 / 100) * 1000);
    public var stepCrochet:Float = (((60 / 100) * 1000) / 4);
    public var songOffset:Float = 0;

    public function new(bpm:Float) {
        this.bpm = bpm;
        updateBpm(bpm);
        songPosition = 0;
    }

    public function updateBpm(newBpm:Float):Void {
        bpm = newBpm;
        crochet = ((60 / bpm) * 1000);
        stepCrochet = crochet / 4;
    }

    public function update(elapsed:Float):Void {
        songPosition += elapsed * 1000;
    }

    public function mapBpmChanges(chart:Dynamic):Void {
    }
}