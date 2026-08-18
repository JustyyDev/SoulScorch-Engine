package soulscorch.gameplay.scoring;

enum abstract Judgment(String) from String to String {
    var SICK = "Sick";
    var GOOD = "Good";
    var BAD = "Bad";
    var SHIT = "Shit";
    var MISS = "Miss";

    public static function fromDifference(diffMs:Float, safeZone:Float = 166.0):Judgment {
        var diff = Math.abs(diffMs);
        if (diff <= 45.0) return SICK;
        if (diff <= 90.0) return GOOD;
        if (diff <= 135.0) return BAD;
        if (diff <= safeZone) return SHIT;
        return MISS;
    }

    public static inline function name(judgment:Judgment):String {
        return Std.string(judgment);
    }

    public static function score(judgment:Judgment):Int {
        return switch (judgment) {
            case SICK: 350;
            case GOOD: 200;
            case BAD: 100;
            case SHIT: 50;
            case MISS: -10;
        };
    }

    public static inline function getScore(judgment:Judgment):Int {
        return score(judgment);
    }

    public static function accuracyWeight(judgment:Judgment):Float {
        return switch (judgment) {
            case SICK: 1.0;
            case GOOD: 0.75;
            case BAD: 0.5;
            case SHIT: 0.25;
            case MISS: 0.0;
        };
    }

    public static inline function getAccuracyWeight(judgment:Judgment):Float {
        return accuracyWeight(judgment);
    }

    public static function healthModifier(judgment:Judgment):Float {
        return switch (judgment) {
            case SICK: 0.04;
            case GOOD: 0.025;
            case BAD: 0.0;
            case SHIT: -0.05;
            case MISS: -0.085;
        };
    }

    public static inline function getHealthModifier(judgment:Judgment):Float {
        return healthModifier(judgment);
    }

    public static inline function triggersSplash(judgment:Judgment):Bool {
        return judgment == SICK;
    }

    public static inline function doesTriggerSplash(judgment:Judgment):Bool {
        return triggersSplash(judgment);
    }
}