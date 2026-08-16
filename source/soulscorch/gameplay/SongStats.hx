package soulscorch.gameplay;

import soulscorch.core.SongScoreEntry;

/**
 * Computed results for a finished song run.
 * Used by ResultsState and SaveData.
 */
class SongStats {
    public var songId:String;
    public var difficulty:String;
    public var score:Int;
    public var misses:Int;
    public var hits:Int;
    public var accuracy:Float;
    public var health:Float;
    public var maxHealth:Float;
    public var rating:String;
    public var isNewBest:Bool;
    public var cleared:Bool;
    public var fc:Bool;

    public function new(songId:String, difficulty:String, score:Int, misses:Int, hits:Int, accuracy:Float, health:Float, maxHealth:Float, cleared:Bool) {
        this.songId = songId;
        this.difficulty = difficulty;
        this.score = score;
        this.misses = misses;
        this.hits = hits;
        this.accuracy = accuracy;
        this.health = health;
        this.maxHealth = maxHealth;
        this.cleared = cleared;
        this.fc = cleared && misses == 0;
        this.rating = computeRating(accuracy, fc);
        this.isNewBest = false;
    }

    public static function computeRating(accuracy:Float, fc:Bool):String {
        if (accuracy >= 100.0 && fc) return "S+";
        if (accuracy >= 95.0) return "S";
        if (accuracy >= 90.0) return "A";
        if (accuracy >= 80.0) return "B";
        if (accuracy >= 70.0) return "C";
        if (accuracy >= 60.0) return "D";
        return "F";
    }

    public function toSaveEntry():SongScoreEntry {
        return {
            score: score,
            accuracy: accuracy,
            misses: misses,
            rating: rating
        };
    }
}
