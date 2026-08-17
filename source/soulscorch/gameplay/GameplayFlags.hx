package soulscorch.gameplay;

import haxe.Json;
import soulscorch.backend.system.engine.Runtime;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.mod.ModManager;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

class GameplayFlags {
    public static var active:Map<String, Dynamic> = new Map();
    public static var defaults:Map<String, Dynamic> = new Map();

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

        for (key => value in defaults) {
            if (!active.exists(key)) {
                active.set(key, value);
            }
        }
    }

    public static function set(key:String, value:Dynamic):Dynamic {
        active.set(normalizeKey(key), value);
        return value;
    }

    public static function get(key:String, fallback:Dynamic = null):Dynamic {
        var normalized:String = normalizeKey(key);
        if (active.exists(normalized)) {
            return active.get(normalized);
        }
        if (defaults.exists(normalized)) {
            return defaults.get(normalized);
        }
        return fallback;
    }

    public static function getBool(key:String, fallback:Bool = false):Bool {
        var value:Dynamic = get(key, fallback);
        return value == true || value == "true" || value == 1;
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

    public static function normalizeKey(rawKey:String):String {
        if (rawKey == null) return "";
        var key:String = StringTools.trim(rawKey);
        if (key.indexOf(".") != -1) {
            var parts:Array<String> = key.split(".");
            return parts[parts.length - 1];
        }
        return key;
    }

    public static function applyFlagString(flagString:String):Void {
        if (flagString == null) return;
        var cleaned:String = StringTools.trim(flagString);
        if (cleaned == "") return;

        if (cleaned.indexOf("=") == -1) {
            set(cleaned, true);
            return;
        }

        var parts:Array<String> = cleaned.split("=");
        if (parts.length < 2) return;

        var key:String = StringTools.trim(parts[0]);
        var valueString:String = StringTools.trim(parts.slice(1).join("="));
        set(key, parseScalar(valueString));
    }

    static function parseScalar(rawValue:String):Dynamic {
        if (rawValue == null) return true;
        var value:String = StringTools.trim(rawValue);

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
        // Load exclusively from active enabled mods to prevent inactive mods leaking flags
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
        var jsonPath:String = '$modDirectory/soulmod.json';
        if (FileSystem.exists(jsonPath)) {
            try {
                var raw:String = File.getContent(jsonPath);
                var parsed:Dynamic = Json.parse(raw);

                if (Reflect.hasField(parsed, "flags")) {
                    var flags:Array<Dynamic> = Reflect.field(parsed, "flags");
                    for (flag in flags) {
                        if (Std.isOfType(flag, String)) {
                            applyFlagString(cast flag);
                        }
                    }
                }
            } catch (e:Dynamic) {
                Logger.warn('Failed parsing flags in $jsonPath: $e', "flags");
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