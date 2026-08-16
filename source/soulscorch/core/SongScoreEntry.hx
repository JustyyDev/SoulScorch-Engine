package soulscorch.core;

/**
 * Persistent record of a single song run's best result.
 */
typedef SongScoreEntry = {
    var score:Int;
    var accuracy:Float;
    var misses:Int;
    var rating:String;
}
