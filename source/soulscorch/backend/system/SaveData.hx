package soulscorch.backend.system;

import flixel.FlxG;
import flixel.util.FlxSave;
import soulscorch.backend.utils.Logger;

using StringTools;

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
    public var settings:Map<String, Dynamic> = new Map();
    private var save:FlxSave;

    public function new() {
        save = new FlxSave();
        bind();
    }

    public static inline function get_instance():SaveData {
        if (_instance == null) {
            _instance = new SaveData();
        }
        return _instance;
    }

    public function bind(name:String = "soulscorch_save"):Bool {
        var bound = save.bind(name);
        if (bound) {
            load();
        }
        return bound;
    }

    public function load():Void {
        if (save.data.songScores != null) {
            songScores = save.data.songScores;
        }
        if (save.data.settings != null) {
            settings = save.data.settings;
        }
    }

    public function submitScore(song:String, diff:String, entry:SongScoreEntry):Bool {
        var key = formatKey(song, diff);
        var currentBest = songScores.get(key);

        if (currentBest == null || entry.score > currentBest.score) {
            songScores.set(key, entry);
            save.data.songScores = songScores;
            flush();
            return true;
        }
        return false;
    }

    public function getScore(song:String, diff:String):SongScoreEntry {
        return songScores.get(formatKey(song, diff));
    }

    public function setSetting(key:String, value:Dynamic):Void {
        settings.set(key, value);
        save.data.settings = settings;
        flush();
    }

    public function getSetting(key:String, defaultValue:Dynamic):Dynamic {
        if (settings.exists(key)) {
            return settings.get(key);
        }
        return defaultValue;
    }

    public inline function flush():Void {
        if (save != null) {
            save.flush();
        }
    }

    private inline function formatKey(song:String, diff:String):String {
        return '${song.toLowerCase().trim()}_${diff.toLowerCase().trim()}';
    }
}