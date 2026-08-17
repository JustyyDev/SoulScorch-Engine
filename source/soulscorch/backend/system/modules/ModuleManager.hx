package soulscorch.backend.system.modules;

import soulscorch.backend.utils.Logger;

class ModuleManager {
    public static var instance(get, null):ModuleManager;
    private static var _instance:ModuleManager;

    public var modules:Map<String, Module> = new Map();
    private var moduleList:Array<Module> = [];

    public function new() {}

    public static inline function get_instance():ModuleManager {
        if (_instance == null) {
            _instance = new ModuleManager();
        }
        return _instance;
    }

    public function register(module:Module):Void {
        if (module == null || modules.exists(module.name)) return;

        try {
            module.initialize();
            modules.set(module.name, module);
            moduleList.push(module);
            Logger.info('Module registered: [${module.name}]');
        } catch (e:Dynamic) {
            Logger.error('Failed to initialize module [${module.name}]: $e');
        }
    }

    public function remove(name:String):Void {
        if (!modules.exists(name)) return;

        var module = modules.get(name);
        module.destroy();
        modules.remove(name);
        moduleList.remove(module);
        Logger.info('Module removed: [$name]');
    }

    public function get<T:Module>(name:String):Null<T> {
        if (!modules.exists(name)) return null;
        return cast modules.get(name);
    }

    public function update(elapsed:Float):Void {
        for (i in 0...moduleList.length) {
            var mod = moduleList[i];
            if (mod != null && mod.active) {
                mod.update(elapsed);
            }
        }
    }

    public function draw():Void {
        for (i in 0...moduleList.length) {
            var mod = moduleList[i];
            if (mod != null && mod.active) {
                mod.draw();
            }
        }
    }

    public function notifyStateSwitch():Void {
        for (i in 0...moduleList.length) {
            var mod = moduleList[i];
            if (mod != null && mod.active) {
                mod.onStateSwitch();
            }
        }
    }

    public function dispatchEvent(eventName:String, ?data:Dynamic):Void {
        for (i in 0...moduleList.length) {
            var mod = moduleList[i];
            if (mod != null && mod.active) {
                mod.onEvent(eventName, data);
            }
        }
    }

    public function destroy():Void {
        for (mod in moduleList) {
            mod.destroy();
        }
        modules.clear();
        moduleList = [];
    }
}