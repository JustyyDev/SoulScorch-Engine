package soulscorch.backend.audio;

import soulscorch.gameplay.chart.Chart;

typedef BPMChangeEvent = {
    var stepTime:Int;
    var songTime:Float;
    var bpm:Float;
    var ?stepCrochet:Float;
}

class Conductor {
    public static var bpm:Float = 100.0;
    public static var crochet:Float = ((60.0 / bpm) * 1000.0);
    public static var stepCrochet:Float = (crochet / 4.0);
    public static var songPosition:Float = 0.0;
    public static var offset:Float = 0.0;

    public static var safeFrames:Int = 10;
    public static var safeZoneOffset:Float = (safeFrames / 60.0) * 1000.0;

    public static var curBeat:Int = 0;
    public static var curStep:Int = 0;
    public static var curMeasure:Int = 0;

    public static var bpmChangeMap:Array<BPMChangeEvent> = [];

    public static function changeBPM(newBpm:Float):Void {
        bpm = (newBpm > 0) ? newBpm : 100.0;
        crochet = ((60.0 / bpm) * 1000.0);
        stepCrochet = (crochet / 4.0);
        safeZoneOffset = (safeFrames / 60.0) * 1000.0;
    }

    public static function mapBpmChanges(chart:Chart):Void {
        bpmChangeMap = [];

        var curBPM:Float = (chart != null && chart.bpm > 0) ? chart.bpm : bpm;
        var totalSteps:Int = 0;
        var totalPos:Float = 0.0;

        bpmChangeMap.push({
            stepTime: 0,
            songTime: 0.0,
            bpm: curBPM,
            stepCrochet: ((60.0 / curBPM) * 1000.0) / 4.0
        });

        if (chart != null && chart.events != null) {
            for (e in chart.events) {
                if (e != null && (e.name == "BPM Change" || e.name == "Change BPM")) {
                    var newBpmVal = Std.parseFloat(e.val1);
                    if (!Math.isNaN(newBpmVal) && newBpmVal > 0) {
                        var eventCrochet = ((60.0 / newBpmVal) * 1000.0) / 4.0;
                        bpmChangeMap.push({
                            stepTime: Math.floor(e.time / eventCrochet),
                            songTime: e.time,
                            bpm: newBpmVal,
                            stepCrochet: eventCrochet
                        });
                    }
                }
            }
        }

        safeZoneOffset = (safeFrames / 60.0) * 1000.0;
    }

    public static function getBPMAtTime(time:Float):BPMChangeEvent {
        var lastChange:BPMChangeEvent = {
            stepTime: 0,
            songTime: 0.0,
            bpm: bpm,
            stepCrochet: stepCrochet
        };

        for (i in 0...bpmChangeMap.length) {
            if (time >= bpmChangeMap[i].songTime) {
                lastChange = bpmChangeMap[i];
            }
        }

        return lastChange;
    }

    public static function update(elapsed:Float):Void {
        var lastChange = getBPMAtTime(songPosition);
        var currentStepCrochet = (lastChange.stepCrochet != null && lastChange.stepCrochet > 0) ? lastChange.stepCrochet : stepCrochet;

        curStep = lastChange.stepTime + Math.floor((songPosition - lastChange.songTime) / currentStepCrochet);
        curBeat = Math.floor(curStep / 4);
        curMeasure = Math.floor(curBeat / 4);
    }

    public static function reset():Void {
        bpm = 100.0;
        crochet = ((60.0 / bpm) * 1000.0);
        stepCrochet = (crochet / 4.0);
        songPosition = 0.0;
        curBeat = 0;
        curStep = 0;
        curMeasure = 0;
        bpmChangeMap = [];
    }
}