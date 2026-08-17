package soulscorch.backend.audio;

import soulscorch.gameplay.chart.Chart;
import soulscorch.gameplay.chart.Chart.BPMChangeEvent;

class Conductor {
    public static var bpm:Float = 100.0;
    public static var crochet:Float = ((60.0 / 100.0) * 1000.0); // Milliseconds per beat
    public static var stepCrochet:Float = crochet / 4.0; // Milliseconds per step
    public static var songPosition:Float = 0.0;
    public static var timeScale:Float = 1.0;
    public static var safeZoneOffset:Float = (10.0 / 60.0) * 1000.0; // Safe hit window (~166ms)

    public static var bpmChangeMap:Array<BPMChangeEvent> = [];

    public static function changeBPM(newBpm:Float):Void {
        bpm = newBpm;
        crochet = ((60.0 / bpm) * 1000.0);
        stepCrochet = crochet / 4.0;
    }

    public static function mapBpmChanges(chart:Chart):Void {
        bpmChangeMap = [];
        if (chart == null) return;

        var curBPM:Float = chart.bpm;
        var totalSteps:Int = 0;
        var totalTime:Float = 0.0;

        for (i in 0...chart.bpmChanges.length) {
            var change = chart.bpmChanges[i];
            if (change.bpm != curBPM) {
                curBPM = change.bpm;
                bpmChangeMap.push({
                    stepTime: change.stepTime,
                    time: change.time,
                    bpm: curBPM
                });
            }
        }
    }

    /**
     * Calculates the current BPM accounting for mid-song BPM changes.
     */
    public static function getBPMAtTime(time:Float):Float {
        var lastBPM = bpm;
        for (change in bpmChangeMap) {
            if (time >= change.time) {
                lastBPM = change.bpm;
            }
        }
        return lastBPM;
    }

    public static function reset():Void {
        bpm = 100.0;
        songPosition = 0.0;
        timeScale = 1.0;
        bpmChangeMap = [];
        changeBPM(100.0);
    }
}