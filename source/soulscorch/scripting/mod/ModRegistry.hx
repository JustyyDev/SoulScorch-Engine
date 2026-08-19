package soulscorch.scripting.mod;

import flixel.FlxG;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.mod.ModManager;
import soulscorch.scripting.mod.SoulModData;

class ModRegistry {
    public static var instance(get, null):ModRegistry;
    private static var _instance:ModRegistry;

    public var enabledMods:Array<String> = [];

    public function new() {
        _instance = this;
        loadConfig();
    }

    public static inline function get_instance():ModRegistry {
        if (_instance == null) {
            _instance = new ModRegistry();
        }
        return _instance;
    }

    public function loadConfig():Void {
        enabledMods = [];

        if (FlxG.save != null && FlxG.save.data != null && FlxG.save.data.enabledMods != null) {
            try {
                var list:Array<Dynamic> = cast FlxG.save.data.enabledMods;
                for (item in list) {
                    var str = Std.string(item);
                    if (!enabledMods.contains(str)) {
                        enabledMods.push(str);
                    }
                }
            } catch (e:Dynamic) {
                Logger.warn('Failed restoring enabled mods list: $e', "mods");
            }
        }

        // If no saved list exists, enable all discovered mods by default
        if (enabledMods.length == 0 && ModManager.allMods != null) {
            enabledMods = ModManager.allMods.copy();
        }

        sortMods();
    }

    public function saveConfig():Void {
        if (FlxG.save != null && FlxG.save.data != null) {
            FlxG.save.data.enabledMods = enabledMods.copy();
            FlxG.save.flush();
            Logger.info('Mod configuration saved (${enabledMods.length} active).', "mods");
        }
    }

    public function isEnabled(modName:String):Bool {
        if (modName == null) return false;
        return enabledMods.contains(modName);
    }

    public function setEnabled(modName:String, enable:Bool):Void {
        if (modName == null) return;

        if (enable) {
            if (!enabledMods.contains(modName)) {
                enabledMods.push(modName);
            }
        } else {
            enabledMods.remove(modName);
        }

        sortMods();
        saveConfig();
    }

    public function sortMods():Void {
        enabledMods.sort(function(a:String, b:String):Int {
            var dataA:Null<SoulModData> = ModManager.modConfigs.get(a);
            var dataB:Null<SoulModData> = ModManager.modConfigs.get(b);

            var prioA = (dataA != null && dataA.load_priority != null) ? dataA.load_priority : ((dataA != null && dataA.priority != null) ? dataA.priority : 0);
            var prioB = (dataB != null && dataB.load_priority != null) ? dataB.load_priority : ((dataB != null && dataB.priority != null) ? dataB.priority : 0);

            return prioB - prioA; // Higher priority loads first
        });
    }
}