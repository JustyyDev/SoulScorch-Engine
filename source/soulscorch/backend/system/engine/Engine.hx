package soulscorch.backend.system.engine;

import flixel.util.FlxSignal.FlxTypedSignal;
import openfl.system.System;
import soulscorch.backend.localization.LanguageManager;
import soulscorch.backend.system.Achievements;
import soulscorch.backend.system.EventBus;
import soulscorch.backend.system.NotificationManager;
import soulscorch.backend.system.SaveData;
import soulscorch.backend.system.Scene;
import soulscorch.backend.system.engine.GameConfig;
import soulscorch.backend.system.engine.HotReloader;
import soulscorch.backend.system.engine.Version;
import soulscorch.backend.system.modules.Module;
import soulscorch.backend.utils.Logger;
import soulscorch.backend.utils.Scheduler;
import soulscorch.scripting.ScriptManager;
import soulscorch.scripting.mod.ModLoader;
import soulscorch.scripting.mod.ModRegistry;

class Engine {
    public static var instance(default, null):Engine;

    public var config:GameConfig;
    public var services:Map<String, Dynamic>;
    public var modules:Map<String, Module>;
    public var initialized:Bool = false;
    public var currentScene:Scene;
    
    public var onInit:FlxTypedSignal<Void->Void>;
    public var onUpdate:FlxTypedSignal<Float->Void>;
    public var onSceneCreate:FlxTypedSignal<Scene->Void>;
    public var onSceneSwitch:FlxTypedSignal<Scene->Void>;
    public var onShutdown:FlxTypedSignal<Void->Void>;

    public function new(config:GameConfig) {
        this.config = config;
        services = new Map<String, Dynamic>();
        modules = new Map<String, Module>();
        
        onInit = new FlxTypedSignal<Void->Void>();
        onUpdate = new FlxTypedSignal<Float->Void>();
        onSceneCreate = new FlxTypedSignal<Scene->Void>();
        onSceneSwitch = new FlxTypedSignal<Scene->Void>();
        onShutdown = new FlxTypedSignal<Void->Void>();
        
        instance = this;
    }

    public static function boot(config:GameConfig):Engine {
        if (instance == null) {
            new Engine(config);
        }
        return instance;
    }

    public function init():Void {
        if (initialized) return;
        initialized = true;

        if (config != null) {
            config.load();
            register("config", config);
        }

        register("mods", new ModRegistry());
        ModLoader.scan();
        register("modLoader", ModLoader);

        register("save", SaveData.instance);
        register("achievements", Achievements.instance);
        register("events", EventBus.instance);
        register("scheduler", Scheduler.instance);
        register("notifications", NotificationManager.instance);
        register("scripts", new ScriptManager());
        
        LanguageManager.instance.load();

        Logger.info('${Version.fullVersion()} initialized successfully.', "engine");

        onInit.dispatch();
    }

    public function update(elapsed:Float):Void {
        if (!initialized) return;
        updateModules(elapsed);
        onUpdate.dispatch(elapsed);
    }

    public function registerModule(module:Module):Void {
        if (module == null || modules.exists(module.name)) return;
        module.initialize();
        modules.set(module.name, module);
        Logger.info('Module registered: ${module.name}', "engine");
    }

    public function removeModule(name:String):Void {
        if (!modules.exists(name)) return;
        var mod = modules.get(name);
        mod.destroy();
        modules.remove(name);
        Logger.info('Module removed: $name', "engine");
    }

    public function updateModules(elapsed:Float):Void {
        HotReloader.update();
        for (module in modules) {
            if (module.active) module.update(elapsed);
        }
    }

    public function notifySceneCreate(scene:Scene):Void {
        currentScene = scene;
        onSceneCreate.dispatch(scene);
    }

    public function notifyStateSwitch():Void {
        for (module in modules) {
            module.onStateSwitch();
        }
        System.gc();
    }

    public function notifySceneSwitch(scene:Scene):Void {
        currentScene = scene;
        notifyStateSwitch();
        onSceneSwitch.dispatch(scene);
    }

    public function register<T>(name:String, value:T):Void {
        services.set(name, value);
    }

    public function resolve<T>(name:String):Null<T> {
        if (!services.exists(name)) return null;
        return cast services.get(name);
    }

    public function shutdown():Void {
        if (!initialized) return;
        onShutdown.dispatch();

        for (name in modules.keys()) {
            removeModule(name);
        }

        services.clear();
        initialized = false;
        Logger.info("Engine shut down cleanly.", "engine");
    }
}