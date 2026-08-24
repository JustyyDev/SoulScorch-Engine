package soulscorch.gameplay;

import flixel.FlxG;
import flixel.util.FlxColor;
import haxe.Json;
import haxe.xml.Access;
import soulscorch.backend.system.SaveData;
import soulscorch.backend.system.XMSoul;
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
        defaults.clear();
        defaults.set("ghostTapping", true);
        defaults.set("downscroll", false);
        defaults.set("middlescroll", false);
        defaults.set("allowPause", true);
        defaults.set("cameraZoomOnBeat", true);
        defaults.set("cameraSpeed", 1.0);
        defaults.set("comboFlashOnHit", true);
        defaults.set("noteSplash", true);
        defaults.set("hudAlpha", 1.0);
        defaults.set("safeZoneOffset", 166.0);
        defaults.set("safeFrames", 10);
        defaults.set("judgeWindow", 166.0);
        defaults.set("maxHealth", 2.0);
        defaults.set("songSpeedMultiplier", 1.0);
        defaults.set("missPenalty", 0.085);
        defaults.set("modchartEnabled", true);
        defaults.set("antialiasing", true);
        defaults.set("flashingLights", true);
        defaults.set("botplay", false);
        defaults.set("noteOffset", 0.0);
        defaults.set("practiceMode", false);
        defaults.set("lowQuality", false);
        defaults.set("cacheGlyphPrefixes", true);
        defaults.set("lowEndMode", false);
        defaults.set("maxNoteSplashes", 24);
        defaults.set("splashPoolSize", 32);
        defaults.set("scriptingMobileConservative", false);
        defaults.set("scriptingEnableLua", true);
        defaults.set("scriptingEnablePython", true);
        defaults.set("scriptingEnableSoulScript", true);
        defaults.set("scriptingEnableHScript", true);

        if (Runtime.config != null) {
            defaults.set("ghostTapping", Runtime.config.ghostTapping);
            defaults.set("downscroll", Runtime.config.downscroll);
            defaults.set("flashingLights", Runtime.config.flashingLights);
            defaults.set("antialiasing", Runtime.config.antialiasing);
            defaults.set("framerate", Runtime.config.framerate);
        }

        if (FlxG.save != null && FlxG.save.data != null) {
            if (FlxG.save.data.ghostTapping != null) defaults.set("ghostTapping", FlxG.save.data.ghostTapping);
            if (FlxG.save.data.downscroll != null) defaults.set("downscroll", FlxG.save.data.downscroll);
            if (FlxG.save.data.middlescroll != null) defaults.set("middlescroll", FlxG.save.data.middlescroll);
            if (FlxG.save.data.botplay != null) defaults.set("botplay", FlxG.save.data.botplay);
            if (FlxG.save.data.noteOffset != null) defaults.set("noteOffset", FlxG.save.data.noteOffset);
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
        if (active.exists(normKey)) return active.get(normKey);
        if (defaults.exists(normKey)) return defaults.get(normKey);
        return fallback;
    }

    public static function getBool(key:String, fallback:Bool = false):Bool {
        var value:Dynamic = get(key, fallback);
        return value == true || value == "true" || value == 1 || value == "1";
    }

    public static function getFloat(key:String, fallback:Float = 0.0):Float {
        var value:Dynamic = get(key, fallback);
        if (Std.isOfType(value, Float) || Std.isOfType(value, Int)) return cast value;
        if (Std.isOfType(value, String)) {
            var parsed = Std.parseFloat(cast value);
            return Math.isNaN(parsed) ? fallback : parsed;
        }
        return fallback;
    }

    public static function getInt(key:String, fallback:Int = 0):Int {
        var value:Dynamic = get(key, fallback);
        if (Std.isOfType(value, Int)) return cast value;
        if (Std.isOfType(value, Float)) return Std.int(cast value);
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

    public static function normalizeKey(rawKey:String):String {
        if (rawKey == null) return "";
        var key:String = rawKey.trim().toLowerCase();
        if (key.indexOf(".") != -1) {
            var parts:Array<String> = key.split(".");
            key = parts[parts.length - 1];
        }
        key = key.replace("-", "");
        key = key.replace("_", "");

        switch (key) {
            case "middlescroll", "middlestrum", "middlenotes": return "middlescroll";
            case "ghosttapping", "ghosttap": return "ghostTapping";
            case "notesplash", "notesplashes": return "noteSplash";
            case "noteoffset": return "noteOffset";
            case "camerazoomonbeat", "beatzoom": return "cameraZoomOnBeat";
            case "cameraspeed": return "cameraSpeed";
            case "safeframes": return "safeFrames";
            case "safezoneoffset": return "safeZoneOffset";
            case "modchartenabled", "modcharts": return "modchartEnabled";
            case "allowpause": return "allowPause";
            case "practice", "practicemode": return "practiceMode";
            case "lowquality": return "lowQuality";
            case "lowend", "lowendmode": return "lowEndMode";
            case "maxnotesplashes", "splashlimit": return "maxNoteSplashes";
            case "splashpool", "splashpoolsize": return "splashPoolSize";
            case "scriptingmobileconservative", "mobileconservativescripting": return "scriptingMobileConservative";
            case "scriptingenablelua": return "scriptingEnableLua";
            case "scriptingenablepython": return "scriptingEnablePython";
            case "scriptingenablesoulscript", "scriptingenablesoul": return "scriptingEnableSoulScript";
            case "scriptingenablehscript", "scriptingenablehx": return "scriptingEnableHScript";
        }

        return key;
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
        var xmlPaths = [
            '$modDirectory/config/flags.xmsoul',
            '$modDirectory/flags.xmsoul',
            '$modDirectory/mod.xmsoul'
        ];

        for (xp in xmlPaths) {
            if (FileSystem.exists(xp)) {
                try {
                    var access = new Access(Xml.parse(File.getContent(xp)).firstElement());
                    loadFlagNodes(access);
                } catch (e:Dynamic) {
                    Logger.warn('Failed parsing flags in $xp: $e', "flags");
                }
                break;
            }
        }
        #end
    }

    private static function loadFlagNodes(parent:Access):Void {
        for (node in parent.elements) {
            switch (node.name.toLowerCase()) {
                case "flag":
                    var name = XMSoul.getAttr(node, "name", "");
                    var val = XMSoul.getAttr(node, "value", "true");
                    if (name.length > 0) set(name, val);
                case "notecolors":
                    for (colorNode in node.elements) {
                        var lane = XMSoul.getIntAttr(colorNode, "lane", -1);
                        var colorVal = XMSoul.getColorAttr(colorNode, "color", FlxColor.WHITE);
                        if (lane >= 0) set('forcedLaneColor_$lane', colorVal);
                    }
                default:
                    loadFlagNodes(node);
            }
        }
    }
}