package soulscorch.backend.system;

import flixel.FlxG;
import flixel.util.FlxSave;
import haxe.Json;
import soulscorch.backend.utils.GameTime;
import soulscorch.backend.utils.Logger;

using StringTools;

typedef SongScoreEntry = {
    var score:Int;
    var accuracy:Float;
    var misses:Int;
    var rating:String;
    var ?letterRank:String;
    var ?date:String;
}

typedef WeekScoreEntry = {
    var score:Int;
    var misses:Int;
    var accuracy:Float;
    var ?date:String;
}

class SaveData {
    public static var instance(get, null):SaveData;
    private static var _instance:SaveData;

    public static inline var CURRENT_SAVE_VERSION:Int = 2;

    public var songScores:Map<String, SongScoreEntry> = new Map<String, SongScoreEntry>();
    public var weekScores:Map<String, WeekScoreEntry> = new Map<String, WeekScoreEntry>();
    public var settings:Map<String, Dynamic> = new Map<String, Dynamic>();
    public var unlocks:Map<String, Bool> = new Map<String, Bool>();

    private var save:FlxSave;
    private var isDirty:Bool = false;

    public function new() {
        save = new FlxSave();
        bind("soulscorch_savedata");
    }

    public static inline function get_instance():SaveData {
        if (_instance == null) _instance = new SaveData();
        return _instance;
    }

    public function bind(name:String = "soulscorch_savedata"):Bool {
        var bound = save.bind(name, "JustyyDev");
        if (bound) {
            load();
        }
        return bound;
    }

    public function load():Void {
        songScores.clear();
        weekScores.clear();
        settings.clear();
        unlocks.clear();

        if (save.data == null) return;

        // Song Scores
        if (save.data.songScores != null) {
            var raw:Dynamic = save.data.songScores;
            for (key in Reflect.fields(raw)) {
                var entry:SongScoreEntry = cast Reflect.field(raw, key);
                if (entry != null) songScores.set(key, entry);
            }
        }

        // Week Scores
        if (save.data.weekScores != null) {
            var raw:Dynamic = save.data.weekScores;
            for (key in Reflect.fields(raw)) {
                var entry:WeekScoreEntry = cast Reflect.field(raw, key);
                if (entry != null) weekScores.set(key, entry);
            }
        }

        // Settings Map
        if (save.data.settings != null) {
            var raw:Dynamic = save.data.settings;
            for (key in Reflect.fields(raw)) {
                settings.set(key, Reflect.field(raw, key));
            }
        }

        // Unlocked Items & Characters
        if (save.data.unlocks != null) {
            var raw:Dynamic = save.data.unlocks;
            for (key in Reflect.fields(raw)) {
                unlocks.set(key, Reflect.field(raw, key) == true);
            }
        }

        Logger.info('[SaveData] Loaded ${Lambda.count(songScores)} song scores and ${Lambda.count(settings)} settings.', "save");
    }

    // ==========================================
    // SCORE MANAGEMENT
    // ==========================================

    public function submitScore(song:String, diff:String, entry:SongScoreEntry):Bool {
        var key = formatKey(song, diff);
        var currentBest = songScores.get(key);

        if (entry.date == null || entry.date.length == 0) {
            entry.date = GameTime.dateString();
        }

        if (currentBest == null || entry.score > currentBest.score) {
            songScores.set(key, entry);
            isDirty = true;
            persist();
            return true;
        }
        return false;
    }

    public function submitWeekScore(week:String, diff:String, score:Int, misses:Int, accuracy:Float):Bool {
        var key = formatKey(week, diff);
        var current = weekScores.get(key);

        if (current == null || score > current.score) {
            weekScores.set(key, {
                score: score,
                misses: misses,
                accuracy: accuracy,
                date: GameTime.dateString()
            });
            isDirty = true;
            persist();
            return true;
        }
        return false;
    }

    public inline function getScore(song:String, diff:String):Null<SongScoreEntry> {
        return songScores.get(formatKey(song, diff));
    }

    public inline function getWeekScore(week:String, diff:String):Null<WeekScoreEntry> {
        return weekScores.get(formatKey(week, diff));
    }

    // ==========================================
    // TYPE-SAFE SETTINGS & UNLOCKS
    // ==========================================

    public function setSetting(key:String, value:Dynamic, autoFlush:Bool = true):Void {
        settings.set(key, value);
        isDirty = true;
        if (autoFlush) persist();
    }

    public function getSetting(key:String, defaultValue:Dynamic):Dynamic {
        return settings.exists(key) ? settings.get(key) : defaultValue;
    }

    public function getBool(key:String, defaultValue:Bool = false):Bool {
        return cast(getSetting(key, defaultValue), Bool);
    }

    public function getInt(key:String, defaultValue:Int = 0):Int {
        return Std.int(getSetting(key, defaultValue));
    }

    public function getFloat(key:String, defaultValue:Float = 0.0):Float {
        return Std.parseFloat(Std.string(getSetting(key, defaultValue)));
    }

    public function getString(key:String, defaultValue:String = ""):String {
        return Std.string(getSetting(key, defaultValue));
    }

    public function setUnlock(unlockID:String, unlocked:Bool = true):Void {
        unlocks.set(unlockID, unlocked);
        isDirty = true;
        persist();
    }

    public function isUnlocked(unlockID:String):Bool {
        return unlocks.exists(unlockID) && unlocks.get(unlockID) == true;
    }

    // ==========================================
    // PERSISTENCE & FLUSHING
    // ==========================================

    public function persist():Void {
        if (save.data == null) return;

        var serializedScores:Dynamic = {};
        for (key => val in songScores) Reflect.setField(serializedScores, key, val);
        save.data.songScores = serializedScores;

        var serializedWeeks:Dynamic = {};
        for (key => val in weekScores) Reflect.setField(serializedWeeks, key, val);
        save.data.weekScores = serializedWeeks;

        var serializedSettings:Dynamic = {};
        for (key => val in settings) Reflect.setField(serializedSettings, key, val);
        save.data.settings = serializedSettings;

        var serializedUnlocks:Dynamic = {};
        for (key => val in unlocks) Reflect.setField(serializedUnlocks, key, val);
        save.data.unlocks = serializedUnlocks;

        save.data.saveVersion = CURRENT_SAVE_VERSION;
        flush();
    }

    public inline function flush():Void {
        if (save != null) {
            try {
                save.flush();
                isDirty = false;
            } catch (e:Dynamic) {
                Logger.warn('Save flush failed: $e', "save");
            }
        }
    }

    public function wipeData():Void {
        songScores.clear();
        weekScores.clear();
        settings.clear();
        unlocks.clear();
        if (save != null) {
            save.erase();
            save.flush();
        }
        Logger.info("[SaveData] Engine save file completely wiped.", "save");
    }

    private inline function formatKey(song:String, diff:String):String {
        var s = (song != null) ? song.toLowerCase().trim() : "tutorial";
        var d = (diff != null) ? diff.toLowerCase().trim() : "normal";
        return '${s}_${d}';
    }
}