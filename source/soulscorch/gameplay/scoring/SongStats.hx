package soulscorch.gameplay.scoring;

import soulscorch.backend.system.SaveData.SongScoreEntry;
import soulscorch.gameplay.scoring.Judgment;

class SongStats {
    public var songId:String;
    public var difficulty:String;

    public var score:Int;
    public var misses:Int;
    public var hits:Int;
    public var accuracy:Float;
    public var health:Float;
    public var maxHealth:Float;

    public var marvelouses:Int = 0;
    public var sicks:Int = 0;
    public var goods:Int = 0;
    public var bads:Int = 0;
    public var shits:Int = 0;

    public var combo:Int = 0;
    public var maxCombo:Int = 0;

    public var rating:String;
    public var clearType:String;
    public var isNewBest:Bool = false;
    public var cleared:Bool;
    public var fc:Bool;

    public function new(
        songId:String,
        difficulty:String,
        score:Int,
        misses:Int,
        hits:Int,
        accuracy:Float,
        health:Float,
        maxHealth:Float,
        cleared:Bool
    ) {
        this.songId = songId;
        this.difficulty = difficulty;
        this.score = score;
        this.misses = misses;
        this.hits = hits;
        this.accuracy = Math.isNaN(accuracy) ? 0.0 : accuracy;
        this.health = health;
        this.maxHealth = maxHealth;
        this.cleared = cleared;
        this.fc = (cleared && misses == 0 && bads == 0 && shits == 0);
        this.rating = computeRating(this.accuracy, cleared);
        this.clearType = computeClearType(this.accuracy, misses, bads, shits, cleared);
    }

    public function registerJudgment(judg:Judgment):Void {
        switch (judg) {
            case MARVELOUS: marvelouses++;
            case SICK: sicks++;
            case GOOD: goods++;
            case BAD: bads++;
            case SHIT: shits++;
            case MISS: misses++;
        }
        hits = marvelouses + sicks + goods + bads + shits;
        fc = (cleared && misses == 0 && bads == 0 && shits == 0);
        rating = computeRating(accuracy, cleared);
        clearType = computeClearType(accuracy, misses, bads, shits, cleared);
    }

    public static function computeRating(acc:Float, hasCleared:Bool):String {
        if (!hasCleared) return "F";
        if (acc >= 100.0) return "S+";
        if (acc >= 95.0) return "S";
        if (acc >= 90.0) return "A";
        if (acc >= 80.0) return "B";
        if (acc >= 70.0) return "C";
        if (acc >= 60.0) return "D";
        return "E";
    }

    public static function computeClearType(acc:Float, missCount:Int, badCount:Int, shitCount:Int, hasCleared:Bool):String {
        if (!hasCleared) return "Loss";
        if (missCount == 0 && badCount == 0 && shitCount == 0) {
            if (acc >= 100.0) return "MFC";
            if (acc >= 90.0) return "GFC";
            return "FC";
        }
        if (missCount < 10) return "SDCB";
        return "Clear";
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