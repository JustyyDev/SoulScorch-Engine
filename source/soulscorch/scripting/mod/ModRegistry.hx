package soulscorch.scripting.mod;

import soulscorch.scripting.mod.SoulModData;

class ModRegistry {
    public static var instance(get, null):ModRegistry;
    private static var _instance:ModRegistry;

    public var registeredMods:Map<String, SoulModData> = new Map();
    public var enabledMods:Array<String> = [];

    public function new() {
        _instance = this;
    }

    public static inline function get_instance():ModRegistry {
        if (_instance == null) {
            _instance = new ModRegistry();
        }
        return _instance;
    }

    public function register(folder:String, data:SoulModData):Void {
        registeredMods.set(folder, data);
    }

    public function isEnabled(folder:String):Bool {
        return enabledMods.contains(folder);
    }

    public function setEnabled(folder:String, enabled:Bool):Void {
        if (enabled && !enabledMods.contains(folder) && registeredMods.exists(folder)) {
            enabledMods.push(folder);
            sortPriority();
        } else if (!enabled) {
            enabledMods.remove(folder);
        }
    }

    public function sortPriority():Void {
        enabledMods.sort(function(a:String, b:String):Int {
            var dataA = registeredMods.get(a);
            var dataB = registeredMods.get(b);
            var prioA = dataA != null ? dataA.load_priority : 0;
            var prioB = dataB != null ? dataB.load_priority : 0;

            if (prioA > prioB) return -1;[cite: 62]
            if (prioA < prioB) return 1;[cite: 62]
            return 0;[cite: 62]
        });
    }

    public function clear():Void {
        registeredMods.clear();
        enabledMods = [];
    }
}