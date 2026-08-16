package soulscorch.core;

import flixel.util.FlxSave;

/**
 * Persistent save data layer for SoulScorch.
 * Stores per-song highscores, unlocked achievements, and global play stats.
 */
class SaveData {
    public static var instance(default, null):SaveData;

    static inline var SAVE_BIND:String = "soulscorch_save";

    var save:FlxSave;

    // songId_difficulty => best score entry
    public var songScores:Map<String, SongScoreEntry> = new Map();
    public var unlockedAchievements:Map<String, Bool> = new Map();
    public var totalPlays:Int = 0;
    public var totalClears:Int = 0;
    public var totalMisses:Int = 0;

    public function new() {
        save = new FlxSave();
        save.bind(SAVE_BIND);
        load();
        instance = this;
    }

    public function load():Void {
        if (save.data.songScores != null) {
            songScores = cast save.data.songScores;
        }
        if (save.data.unlockedAchievements != null) {
            unlockedAchievements = cast save.data.unlockedAchievements;
        }
        if (save.data.totalPlays != null) totalPlays = save.data.totalPlays;
        if (save.data.totalClears != null) totalClears = save.data.totalClears;
        if (save.data.totalMisses != null) totalMisses = save.data.totalMisses;
    }

    public function flush():Void {
        save.data.songScores = songScores;
        save.data.unlockedAchievements = unlockedAchievements;
        save.data.totalPlays = totalPlays;
        save.data.totalClears = totalClears;
        save.data.totalMisses = totalMisses;
        save.flush();
    }

    public static function key(songId:String, difficulty:String):String {
        return '${songId}_${difficulty}';
    }

    public function getBest(songId:String, difficulty:String):SongScoreEntry {
        var k = key(songId, difficulty);
        if (!songScores.exists(k)) {
            songScores.set(k, {score: 0, accuracy: 0.0, misses: 0, rating: "N/A"});
        }
        return songScores.get(k);
    }

    /**
     * Returns true if this run set a new personal best.
     */
    public function submitScore(songId:String, difficulty:String, entry:SongScoreEntry):Bool {
        var k = key(songId, difficulty);
        var best = getBest(songId, difficulty);
        var isNewBest = entry.score > best.score;

        if (isNewBest) {
            songScores.set(k, entry);
        }

        totalPlays += 1;
        totalMisses += entry.misses;
        if (entry.misses == 0) {
            totalClears += 1;
        }

        flush();
        return isNewBest;
    }

    public function isAchievementUnlocked(id:String):Bool {
        return unlockedAchievements.exists(id) && unlockedAchievements.get(id);
    }

    public function unlockAchievement(id:String):Bool {
        if (isAchievementUnlocked(id)) return false;
        unlockedAchievements.set(id, true);
        flush();
        return true;
    }
}
