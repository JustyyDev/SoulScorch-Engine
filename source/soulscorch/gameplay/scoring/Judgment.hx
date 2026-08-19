package soulscorch.gameplay.scoring;

import flixel.util.FlxColor;

enum abstract Judgment(String) from String to String {
    var MARVELOUS = "Marvelous";
    var SICK = "Sick";
    var GOOD = "Good";
    var BAD = "Bad";
    var SHIT = "Shit";
    var MISS = "Miss";

    public static function fromDifference(diffMs:Float, safeZone:Float = 166.0):Judgment {
        var diff:Float = Math.abs(diffMs);
        if (diff <= 22.5) return MARVELOUS;
        if (diff <= 45.0) return SICK;
        if (diff <= 90.0) return GOOD;
        if (diff <= 135.0) return BAD;
        if (diff <= safeZone) return SHIT;
        return MISS;
    }

    public static function fromWindow(diffMs:Float, windowMultiplier:Float = 1.0, safeZone:Float = 166.0):Judgment {
        var scale = Math.max(0.1, windowMultiplier);
        var diff:Float = Math.abs(diffMs);
        if (diff <= 22.5 * scale) return MARVELOUS;
        if (diff <= 45.0 * scale) return SICK;
        if (diff <= 90.0 * scale) return GOOD;
        if (diff <= 135.0 * scale) return BAD;
        if (diff <= safeZone * scale) return SHIT;
        return MISS;
    }

    public static inline function name(judgment:Judgment):String {
        return Std.string(judgment);
    }

    public static function score(judgment:Judgment):Int {
        return switch (judgment) {
            case MARVELOUS: 400;
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
            case MARVELOUS, SICK: 1.0;
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
            case MARVELOUS: 0.045;
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
        return judgment == MARVELOUS || judgment == SICK;
    }

    public static inline function doesTriggerSplash(judgment:Judgment):Bool {
        return triggersSplash(judgment);
    }

    public static inline function isNoteHit(judgment:Judgment):Bool {
        return judgment != MISS;
    }

    public static inline function breaksCombo(judgment:Judgment):Bool {
        return judgment == MISS || judgment == SHIT || judgment == BAD;
    }

    public static function getColor(judgment:Judgment):FlxColor {
        return switch (judgment) {
            case MARVELOUS: 0xFFFF00FF;
            case SICK: 0xFF00FFFF;
            case GOOD: 0xFF55E055;
            case BAD: 0xFFE08833;
            case SHIT, MISS: 0xFFE03333;
        };
    }
}