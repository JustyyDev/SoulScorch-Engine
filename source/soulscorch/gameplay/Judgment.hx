package soulscorch.gameplay;

enum abstract Judgment(String) from String to String {
    var SICK = "Sick";
    var GOOD = "Good";
    var BAD = "Bad";
    var SHIT = "Shit";
    var MISS = "Miss";

    public static function fromDifference(milliseconds:Float, safeZone:Float):Judgment {
        var difference = Math.abs(milliseconds);
        if (difference <= safeZone * 0.25) return SICK;
        if (difference <= safeZone * 0.50) return GOOD;
        if (difference <= safeZone * 0.75) return BAD;
        if (difference <= safeZone) return SHIT;
        return MISS;
    }

    public static function score(judgment:Judgment):Int {
        return switch (judgment) {
            case SICK: 350;
            case GOOD: 200;
            case BAD: 100;
            case SHIT: 50;
            case MISS: -10;
        }
    }
    
    public static function accuracyWeight(judgment:Judgment):Float {
        return switch (judgment) {
            case SICK: 1.0;
            case GOOD: 0.75;
            case BAD: 0.5;
            case SHIT: 0.25;
            case MISS: 0.0;
        }
    }

    public static function healthModifier(judgment:Judgment):Float {
        return switch (judgment) {
            case SICK: 0.04;
            case GOOD: 0.02;
            case BAD: 0.0;
            case SHIT: -0.06;
            case MISS: -0.15;
        }
    }
}