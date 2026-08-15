package soulscorch.gameplay;

import soulscorch.gameplay.Chart.BPMChangeEvent;

class Conductor {
    public static var bpm:Float = 100.0;
    public static var crochet:Float = ((60.0 / 100.0) * 1000.0);
    public static var stepCrochet:Float = crochet / 4.0;
    public static var songPosition:Float = 0.0;
    public static var safeZoneOffset:Float = 166.0;
    public static var bpmChangeMap:Array<BPMChangeEvent> = [];
    public static var timeScale:Float = 1.0;

    public static function changeBPM(newBpm:Float):Void {
        bpm = newBpm;
        crochet = ((60.0 / bpm) * 1000.0);
        stepCrochet = crochet / 4.0;
    }

    public static function mapBpmChanges(chart:Chart):Void {
        bpmChangeMap = [];
        var curBPM:Float = chart.bpm;
        var totalSteps:Int = 0;
        var totalTime:Float = 0.0;

        for (change in chart.bpmChanges) {
            if (change.bpm != curBPM) {
                curBPM = change.bpm;
                bpmChangeMap.push({
                    stepTime: totalSteps,
                    time: totalTime,
                    bpm: curBPM
                });
            }
        }
    }

    public static function getBPMAtTime(time:Float):Float {
        var lastBPM = bpm;
        for (change in bpmChangeMap) {
            if (time >= change.time) {
                lastBPM = change.bpm;
            }
        }
        return lastBPM;
    }
}