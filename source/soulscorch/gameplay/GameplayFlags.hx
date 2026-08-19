package soulscorch.gameplay;

import flixel.FlxG;
import haxe.Json;
import soulscorch.backend.system.SaveData;
import soulscorch.backend.system.engine.Runtime;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.mod.ModManager;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

class GameplayFlags {
    public static var active:Map<String, Dynamic> = new Map<String, Dynamic>();
    public static var defaults:Map<String, Dynamic> = new Map<String, Dynamic>();

    public static function reset():Void {
        active.clear();
        initDefaults();
    }

    public static function initDefaults():Void {
        defaults.set("ghostTapping", true);
        defaults.set("downscroll", false);
        defaults.set("middlescroll", false);
        defaults.set("allowPause", true);
        defaults.set("cameraZoomOnBeat", true);
        defaults.set("comboFlashOnHit", true);
        defaults.set("noteSplash", true);
        defaults.set("hudAlpha", 1.0);
        defaults.set("safeZoneOffset", 166.0);
        defaults.set("judgeWindow", 166.0);
        defaults.set("maxHealth", 2.0);
        defaults.set("songSpeedMultiplier", 1.0);
        defaults.set("missPenalty", 0.085);
        defaults.set("modchartEnabled", true);
        defaults.set("antialiasing", true);
        defaults.set("flashingLights", true);
        defaults.set("botplay", false);

        if (Runtime.config != null) {
            defaults.set("ghostTapping", Runtime.config.ghostTapping);
            defaults.set("downscroll", Runtime.config.downscroll);
            defaults.set("flashingLights", Runtime.config.flashingLights);
            defaults.set("antialiasing", Runtime.config.antialiasing);
        }

        if (FlxG.save != null && FlxG.save.data != null) {
            if (FlxG.save.data.ghostTapping != null) defaults.set("ghostTapping", FlxG.save.data.ghostTapping);
            if (FlxG.save.data.downscroll != null) defaults.set("downscroll", FlxG.save.data.downscroll);
            if (FlxG.save.data.middlescroll != null) defaults.set("middlescroll", FlxG.save.data.middlescroll);
            if (FlxG.save.data.botplay != null) defaults.set("botplay", FlxG.save.data.botplay);
        }

        for (key => value in defaults) {
            if (!active.exists(key)) {
                active.set(key, value);
            }
        }
    }

    public static function set(key:String, value:Dynamic):Dynamic {
        var normKey = normalizeKey(key);
        active.set(normKey, value);
        return value;
    }

    public static function has(key:String):Bool {
        var normKey = normalizeKey(key);
        return active.exists(normKey) || defaults.exists(normKey);
    }

    public static function get(key:String, fallback:Dynamic = null):Dynamic {
        var normKey = normalizeKey(key);
        if (active.exists(normKey)) {
            return active.get(normKey);
        }
        if (defaults.exists(normKey)) {
            return defaults.get(normKey);
        }
        return fallback;
    }

    public static function getBool(key:String, fallback:Bool = false):Bool {
        var value:Dynamic = get(key, fallback);
        return value == true || value == "true" || value == 1 || value == "1";
    }

    public static function getFloat(key:String, fallback:Float = 0.0):Float {
        var value:Dynamic = get(key, fallback);
        if (Std.isOfType(value, Float) || Std.isOfType(value, Int)) {
            return cast value;
        }
        if (Std.isOfType(value, String)) {
            var parsed = Std.parseFloat(cast value);
            return Math.isNaN(parsed) ? fallback : parsed;
        }
        return fallback;
    }

    public static function getInt(key:String, fallback:Int = 0):Int {
        var value:Dynamic = get(key, fallback);
        if (Std.isOfType(value, Int)) {
            return cast value;
        }
        if (Std.isOfType(value, Float)) {
            return Std.int(cast value);
        }
        if (Std.isOfType(value, String)) {
            var parsed = Std.parseInt(cast value);
            return parsed != null ? parsed : fallback;
        }
        return fallback;
    }

    public static function getString(key:String, fallback:String = ""):String {
        var value:Dynamic = get(key, fallback);
        return (value != null) ? Std.string(value) : fallback;
    }

    public static function toggle(key:String):Bool {
        var current = getBool(key, false);
        set(key, !current);
        return !current;
    }

    public static function remove(key:String):Void {
        active.remove(normalizeKey(key));
    }

    public static function normalizeKey(rawKey:String):String {
        if (rawKey == null) return "";
        var key:String = rawKey.trim();
        if (key.indexOf(".") != -1) {
            var parts:Array<String> = key.split(".");
            return parts[parts.length - 1];
        }
        return key;
    }

    public static function applyFlagString(flagString:String):Void {
        if (flagString == null) return;
        var cleaned:String = flagString.trim();
        if (cleaned.length == 0) return;

        if (cleaned.indexOf("=") == -1) {
            set(cleaned, true);
            return;
        }

        var parts:Array<String> = cleaned.split("=");
        if (parts.length < 2) return;

        var key:String = parts[0].trim();
        var valueString:String = parts.slice(1).join("=").trim();
        set(key, parseScalar(valueString));
    }

    static function parseScalar(rawValue:String):Dynamic {
        if (rawValue == null) return true;
        var value:String = rawValue.trim();

        if (value == "true") return true;
        if (value == "false") return false;
        if (value.toLowerCase() == "null") return null;

        var intValue:Null<Int> = Std.parseInt(value);
        if (intValue != null && Std.string(intValue) == value) {
            return intValue;
        }

        var floatValue:Float = Std.parseFloat(value);
        if (!Math.isNaN(floatValue)) {
            return floatValue;
        }

        return value;
    }

    public static function resolveModFlags():Void {
        reset();

        #if sys
        if (ModManager.activeMods != null && ModManager.activeMods.length > 0) {
            for (modName in ModManager.activeMods) {
                var fullDir:String = 'mods/$modName';
                if (FileSystem.exists(fullDir) && FileSystem.isDirectory(fullDir)) {
                    loadModFlags(fullDir);
                }
            }
        }
        #end
    }

    public static function loadModFlags(modDirectory:String):Void {
        #if sys
        var manifestCandidates = [
            '$modDirectory/soulmod.json',
            '$modDirectory/mod.json',
            '$modDirectory/config.json'
        ];

        for (jsonPath in manifestCandidates) {
            if (FileSystem.exists(jsonPath)) {
                try {
                    var raw:String = File.getContent(jsonPath);
                    var parsed:Dynamic = Json.parse(raw);

                    if (Reflect.hasField(parsed, "flags")) {
                        var flags:Array<Dynamic> = Reflect.field(parsed, "flags");
                        if (flags != null) {
                            for (flag in flags) {
                                if (Std.isOfType(flag, String)) {
                                    applyFlagString(cast flag);
                                }
                            }
                        }
                    }
                } catch (e:Dynamic) {
                    Logger.warn('Failed parsing flags in $jsonPath: $e', "flags");
                }
                break;
            }
        }

        var flagsPath:String = '$modDirectory/flags.json';
        if (FileSystem.exists(flagsPath)) {
            try {
                var raw:String = File.getContent(flagsPath);
                var parsed:Dynamic = Json.parse(raw);
                if (parsed != null) {
                    for (key in Reflect.fields(parsed)) {
                        set(key, Reflect.field(parsed, key));
                    }
                }
            } catch (e:Dynamic) {
                Logger.warn('Failed parsing flags in $flagsPath: $e', "flags");
            }
        }
        #end
    }
}