package soulscorch.backend.system.modules;

import soulscorch.backend.utils.Logger;

class ModuleManager {
    public static var instance(get, null):ModuleManager;
    private static var _instance:ModuleManager;

    public var modules:Map<String, Module> = new Map();
    private var moduleList:Array<Module> = [];
    private var isUpdating:Bool = false;
    private var pendingRegistrations:Array<Module> = [];
    private var pendingRemovals:Array<String> = [];

    public function new() {
        _instance = this;
    }

    public static inline function get_instance():ModuleManager {
        if (_instance == null) {
            _instance = new ModuleManager();
        }
        return _instance;
    }

    public function register(module:Module):Void {
        if (module == null || modules.exists(module.name)) return;

        // Defer registration if we are currently iterating through the loop
        if (isUpdating) {
            pendingRegistrations.push(module);
            return;
        }

        try {
            module.initialize();
            modules.set(module.name, module);
            moduleList.push(module);
            Logger.info('Module registered successfully: [${module.name}]', "modules");
        } catch (e:Dynamic) {
            Logger.error('Failed to initialize module [${module.name}]: $e', "modules");
        }
    }

    public function remove(name:String):Void {
        if (!modules.exists(name)) return;

        // Defer removal if we are currently iterating through the loop
        if (isUpdating) {
            pendingRemovals.push(name);
            return;
        }

        var module = modules.get(name);
        if (module != null) {
            try {
                module.destroy();
            } catch (e:Dynamic) {
                Logger.error('Error destroying module [$name]: $e', "modules");
            }
            modules.remove(name);
            moduleList.remove(module);
            Logger.info('Module removed: [$name]', "modules");
        }
    }

    public function get<T:Module>(name:String):Null<T> {
        if (!modules.exists(name)) return null;
        return cast modules.get(name);
    }

    public function update(elapsed:Float):Void {
        isUpdating = true;

        for (i in 0...moduleList.length) {
            var mod = moduleList[i];
            if (mod != null && mod.active) {
                try {
                    mod.update(elapsed);
                } catch (e:Dynamic) {
                    Logger.error('Runtime error in module [${mod.name}] update: $e', "modules");
                }
            }
        }

        isUpdating = false;
        processPendingChanges();
    }

    public function draw():Void {
        for (i in 0...moduleList.length) {
            var mod = moduleList[i];
            if (mod != null && mod.active) {
                try {
                    mod.draw();
                } catch (e:Dynamic) {
                    Logger.error('Runtime error in module [${mod.name}] draw: $e', "modules");
                }
            }
        }
    }

    public function notifyStateSwitch():Void {
        for (i in 0...moduleList.length) {
            var mod = moduleList[i];
            if (mod != null && mod.active) {
                try {
                    mod.onStateSwitch();
                } catch (e:Dynamic) {
                    Logger.error('Runtime error in module [${mod.name}] state switch: $e', "modules");
                }
            }
        }
    }

    public function dispatchEvent(eventName:String, ?data:Dynamic):Void {
        for (i in 0...moduleList.length) {
            var mod = moduleList[i];
            if (mod != null && mod.active) {
                try {
                    mod.onEvent(eventName, data);
                } catch (e:Dynamic) {
                    Logger.error('Runtime error in module [${mod.name}] event $eventName: $e', "modules");
                }
            }
        }
    }

    private function processPendingChanges():Void {
        if (pendingRegistrations.length > 0) {
            var regQueue = pendingRegistrations;
            pendingRegistrations = [];
            for (mod in regQueue) {
                register(mod);
            }
        }

        if (pendingRemovals.length > 0) {
            var remQueue = pendingRemovals;
            pendingRemovals = [];
            for (name in remQueue) {
                remove(name);
            }
        }
    }

    public function destroy():Void {
        isUpdating = false;
        for (mod in moduleList) {
            if (mod != null) {
                try {
                    mod.destroy();
                } catch (e:Dynamic) {}
            }
        }
        modules.clear();
        moduleList = [];
        pendingRegistrations = [];
        pendingRemovals = [];
        Logger.info("ModuleManager shut down cleanly.", "modules");
    }
}