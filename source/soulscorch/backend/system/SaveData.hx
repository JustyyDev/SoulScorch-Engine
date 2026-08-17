package soulscorch.backend.system;

import flixel.util.FlxSave;

typedef SongScoreEntry = {
    var score:Int;
    var accuracy:Float;
    var misses:Int;
    var rating:String;
    var ?date:String;
}

class SaveData {
    public static var instance(get, null):SaveData;
    private static var _instance:SaveData;

    public var songScores:Map<String, SongScoreEntry> = new Map();
    private var save:FlxSave;

    public function new() {
        save = new FlxSave();
        save.bind("soulscorch_scores");
        load();
    }

    public static inline function get_instance():SaveData {
        if (_instance == null) {
            _instance = new SaveData();
        }
        return _instance;
    }

    public function load():Void {
        if (save.data.songScores != null) {
            songScores = save.data.songScores;
        }
    }

    public function submitScore(song:String, diff:String, entry:SongScoreEntry):Bool {
        var key = formatKey(song, diff);
        var currentBest = songScores.get(key);

        if (currentBest == null || entry.score > currentBest.score) {
            songScores.set(key, entry);
            save.data.songScores = songScores;
            save.flush();
            return true;
        }
        return false;
    }

    public function getScore(song:String, diff:String):SongScoreEntry {
        return songScores.get(formatKey(song, diff));
    }

    private inline function formatKey(song:String, diff:String):String {
        return '${song.toLowerCase().trim()}_${diff.toLowerCase().trim()}';
    }
}