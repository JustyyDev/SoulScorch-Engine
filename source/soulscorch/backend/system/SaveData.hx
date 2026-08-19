package soulscorch.backend.system;

import flixel.FlxG;
import flixel.util.FlxSave;
import soulscorch.backend.utils.GameTime;
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

    public var songScores:Map<String, SongScoreEntry> = new Map<String, SongScoreEntry>();
    public var settings:Map<String, Dynamic> = new Map<String, Dynamic>();
    private var save:FlxSave;

    public function new() {
        save = new FlxSave();
        bind("soulscorch_scores");
    }

    public static inline function get_instance():SaveData {
        if (_instance == null) {
            _instance = new SaveData();
        }
        return _instance;
    }

    public function bind(name:String = "soulscorch_scores"):Bool {
        var bound = save.bind(name);
        if (bound) {
            load();
        }
        return bound;
    }

    public function load():Void {
        songScores.clear();
        settings.clear();

        if (save.data != null) {
            if (save.data.songScores != null) {
                var rawScores:Dynamic = save.data.songScores;
                for (key in Reflect.fields(rawScores)) {
                    var entry:SongScoreEntry = cast Reflect.field(rawScores, key);
                    if (entry != null) {
                        songScores.set(key, entry);
                    }
                }
            }

            if (save.data.settings != null) {
                var rawSettings:Dynamic = save.data.settings;
                for (key in Reflect.fields(rawSettings)) {
                    settings.set(key, Reflect.field(rawSettings, key));
                }
            }
        }
    }

    public function submitScore(song:String, diff:String, entry:SongScoreEntry):Bool {
        var key = formatKey(song, diff);
        var currentBest = songScores.get(key);

        if (entry.date == null || entry.date.length == 0) {
            entry.date = GameTime.dateString();
        }

        if (currentBest == null || entry.score > currentBest.score) {
            songScores.set(key, entry);
            persistScores();
            return true;
        }
        return false;
    }

    public function getScore(song:String, diff:String):Null<SongScoreEntry> {
        return songScores.get(formatKey(song, diff));
    }

    public function setSetting(key:String, value:Dynamic):Void {
        settings.set(key, value);
        persistSettings();
    }

    public function getSetting(key:String, defaultValue:Dynamic):Dynamic {
        if (settings.exists(key)) {
            return settings.get(key);
        }
        return defaultValue;
    }

    private function persistScores():Void {
        if (save.data == null) return;
        var serialized:Dynamic = {};
        for (key => val in songScores) {
            Reflect.setField(serialized, key, val);
        }
        save.data.songScores = serialized;
        flush();
    }

    private function persistSettings():Void {
        if (save.data == null) return;
        var serialized:Dynamic = {};
        for (key => val in settings) {
            Reflect.setField(serialized, key, val);
        }
        save.data.settings = serialized;
        flush();
    }

    public inline function flush():Void {
        if (save != null) {
            try {
                save.flush();
            } catch (e:Dynamic) {
                Logger.warn('Save flush warning: $e', "save");
            }
        }
    }

    private inline function formatKey(song:String, diff:String):String {
        var s = (song != null) ? song.toLowerCase().trim() : "tutorial";
        var d = (diff != null) ? diff.toLowerCase().trim() : "normal";
        return '${s}_${d}';
    }
}