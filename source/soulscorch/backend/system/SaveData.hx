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
    var ?cleared:Bool;
}

typedef WeekScoreEntry = {
    var score:Int;
    var misses:Int;
    var accuracy:Float;
    var ?date:String;
}

typedef ReplayDataEntry = {
    var id:String;
    var songId:String;
    var difficulty:String;
    var timestamp:Float;
    var dateString:String;
    var score:Int;
    var accuracy:Float;
    var misses:Int;
    var replayPath:String;
    var ?mp4Path:String;
}

class SaveData {
    public static var instance(get, null):SaveData;
    private static var _instance:SaveData;

    public static inline var CURRENT_SAVE_VERSION:Int = 4;

    public var songScores:Map<String, SongScoreEntry> = new Map<String, SongScoreEntry>();
    public var weekScores:Map<String, WeekScoreEntry> = new Map<String, WeekScoreEntry>();
    public var settings:Map<String, Dynamic> = new Map<String, Dynamic>();
    public var unlocks:Map<String, Bool> = new Map<String, Bool>();
    public var enabledMods:Array<String> = [];
    public var customFlags:Map<String, Dynamic> = new Map<String, Dynamic>();
    public var savedReplays:Array<ReplayDataEntry> = [];

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
        customFlags.clear();
        enabledMods = [];
        savedReplays = [];

        if (save.data == null) return;

        if (save.data.songScores != null) {
            var raw:Dynamic = save.data.songScores;
            for (key in Reflect.fields(raw)) {
                var entry:SongScoreEntry = cast Reflect.field(raw, key);
                if (entry != null) songScores.set(key, entry);
            }
        }

        if (save.data.weekScores != null) {
            var raw:Dynamic = save.data.weekScores;
            for (key in Reflect.fields(raw)) {
                var entry:WeekScoreEntry = cast Reflect.field(raw, key);
                if (entry != null) weekScores.set(key, entry);
            }
        }

        if (save.data.settings != null) {
            var raw:Dynamic = save.data.settings;
            for (key in Reflect.fields(raw)) {
                settings.set(key, Reflect.field(raw, key));
            }
        }

        if (save.data.unlocks != null) {
            var raw:Dynamic = save.data.unlocks;
            for (key in Reflect.fields(raw)) {
                unlocks.set(key, Reflect.field(raw, key) == true);
            }
        }

        if (save.data.enabledMods != null && Std.isOfType(save.data.enabledMods, Array)) {
            for (mod in (cast save.data.enabledMods : Array<Dynamic>)) {
                enabledMods.push(Std.string(mod));
            }
        }

        if (save.data.customFlags != null) {
            var raw:Dynamic = save.data.customFlags;
            for (key in Reflect.fields(raw)) {
                customFlags.set(key, Reflect.field(raw, key));
            }
        }

        if (save.data.savedReplays != null && Std.isOfType(save.data.savedReplays, Array)) {
            for (item in (cast save.data.savedReplays : Array<Dynamic>)) {
                if (item != null) savedReplays.push(cast item);
            }
        }

        applyMissingDefaults();
        syncToFlxGSave();
    }

    private function applyMissingDefaults():Void {
        if (!settings.exists("downscroll")) settings.set("downscroll", false);
        if (!settings.exists("middlescroll")) settings.set("middlescroll", false);
        if (!settings.exists("ghostTapping")) settings.set("ghostTapping", true);
        if (!settings.exists("noteSplash")) settings.set("noteSplash", true);
        if (!settings.exists("flashingLights")) settings.set("flashingLights", true);
        if (!settings.exists("cameraZoomOnBeat")) settings.set("cameraZoomOnBeat", true);
        if (!settings.exists("framerate")) settings.set("framerate", 120);
        if (!settings.exists("antialiasing")) settings.set("antialiasing", true);
        if (!settings.exists("noteOffset")) settings.set("noteOffset", 0.0);
        if (!settings.exists("botplay")) settings.set("botplay", false);
        if (!settings.exists("songSpeedMultiplier")) settings.set("songSpeedMultiplier", 1.0);
        if (!settings.exists("exportReplayMp4")) settings.set("exportReplayMp4", false);
    }

    private function syncToFlxGSave():Void {
        if (FlxG.save == null || FlxG.save.data == null) return;
        for (key => val in settings) {
            Reflect.setField(FlxG.save.data, key, val);
        }
        FlxG.save.flush();
    }

    public function registerReplay(entry:ReplayDataEntry):Void {
        if (entry == null) return;
        savedReplays.unshift(entry);
        if (savedReplays.length > 100) savedReplays.pop();
        isDirty = true;
        persist();
    }

    public function getReplays():Array<ReplayDataEntry> {
        return savedReplays;
    }

    public function deleteReplay(id:String):Void {
        savedReplays = savedReplays.filter(function(r) return r.id != id);
        isDirty = true;
        persist();
    }

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

    public function setSetting(key:String, value:Dynamic, autoFlush:Bool = true):Void {
        settings.set(key, value);
        if (FlxG.save != null && FlxG.save.data != null) {
            Reflect.setField(FlxG.save.data, key, value);
        }
        isDirty = true;
        if (autoFlush) persist();
    }

    public function getSetting(key:String, defaultValue:Dynamic):Dynamic {
        if (settings.exists(key)) return settings.get(key);
        if (FlxG.save != null && FlxG.save.data != null && Reflect.hasField(FlxG.save.data, key)) {
            var val = Reflect.field(FlxG.save.data, key);
            settings.set(key, val);
            return val;
        }
        return defaultValue;
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

    public function setFlag(flagName:String, value:Dynamic, autoFlush:Bool = true):Void {
        customFlags.set(flagName, value);
        isDirty = true;
        if (autoFlush) persist();
    }

    public function getFlag(flagName:String, defaultValue:Dynamic):Dynamic {
        return customFlags.exists(flagName) ? customFlags.get(flagName) : defaultValue;
    }

    public function setEnabledMods(mods:Array<String>):Void {
        enabledMods = mods.copy();
        isDirty = true;
        persist();
    }

    public function setUnlock(unlockID:String, unlocked:Bool = true):Void {
        unlocks.set(unlockID, unlocked);
        isDirty = true;
        persist();
    }

    public function isUnlocked(unlockID:String):Bool {
        return unlocks.exists(unlockID) && unlocks.get(unlockID) == true;
    }

    public function persist():Void {
        if (save.data == null) return;

        var serializedScores:Dynamic = {};
        for (key => val in songScores) Reflect.setField(serializedScores, key, val);
        save.data.songScores = serializedScores;

        var serializedWeeks:Dynamic = {};
        for (key => val in weekScores) Reflect.setField(serializedWeeks, key, val);
        save.data.weekScores = serializedWeeks;

        var serializedSettings:Dynamic = {};
        for (key => val in settings) {
            Reflect.setField(serializedSettings, key, val);
            if (FlxG.save != null && FlxG.save.data != null) {
                Reflect.setField(FlxG.save.data, key, val);
            }
        }
        save.data.settings = serializedSettings;

        var serializedUnlocks:Dynamic = {};
        for (key => val in unlocks) Reflect.setField(serializedUnlocks, key, val);
        save.data.unlocks = serializedUnlocks;

        var serializedFlags:Dynamic = {};
        for (key => val in customFlags) Reflect.setField(serializedFlags, key, val);
        save.data.customFlags = serializedFlags;

        save.data.savedReplays = savedReplays;
        save.data.enabledMods = enabledMods.copy();
        save.data.saveVersion = CURRENT_SAVE_VERSION;

        flush();
    }

    public inline function flush():Void {
        if (save != null) {
            try {
                save.flush();
                if (FlxG.save != null) FlxG.save.flush();
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
        customFlags.clear();
        savedReplays = [];
        enabledMods = [];
        if (save != null) {
            save.erase();
            save.flush();
        }
        if (FlxG.save != null) {
            FlxG.save.erase();
            FlxG.save.flush();
        }
        Logger.info("[SaveData] Engine save file completely wiped.", "save");
    }

    private inline function formatKey(song:String, diff:String):String {
        var s = (song != null) ? song.toLowerCase().trim() : "tutorial";
        var d = (diff != null) ? diff.toLowerCase().trim() : "normal";
        return '${s}_${d}';
    }
}