package soulscorch.backend.system.engine;

import flixel.util.FlxSignal.FlxTypedSignal;
import openfl.system.System;
import soulscorch.backend.localization.LanguageManager;
import soulscorch.backend.system.Achievements;
import soulscorch.backend.system.EventBus;
import soulscorch.backend.system.GameConfig;
import soulscorch.backend.system.Module;
import soulscorch.backend.system.NotificationManager;
import soulscorch.backend.system.SaveData;
import soulscorch.backend.system.Scene;
import soulscorch.backend.system.framerate.EngineProfiler;
import soulscorch.backend.utils.Logger;
import soulscorch.backend.utils.Scheduler;
import soulscorch.scripting.ModLoader;
import soulscorch.scripting.ModRegistry;
import soulscorch.scripting.ScriptManager;

class Engine {
    public static var instance(default, null):Engine;

    public var config:GameConfig;
    public var services:Map<String, Dynamic>;
    public var modules:Map<String, Module>;
    public var initialized:Bool = false;
    
    public var onInit:FlxTypedSignal<Void->Void>;
    public var onSceneCreate:FlxTypedSignal<Scene->Void>;
    public var onSceneSwitch:FlxTypedSignal<Scene->Void>;

    public function new(config:GameConfig) {
        if (instance != null) {
            throw "Engine already initialized.";
        }

        this.config = config;
        services = new Map<String, Dynamic>();
        modules = new Map<String, Module>();
        
        onInit = new FlxTypedSignal<Void->Void>();
        onSceneCreate = new FlxTypedSignal<Scene->Void>();
        onSceneSwitch = new FlxTypedSignal<Scene->Void>();
        
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

        config.load();

        register("config", config);
        register("mods", new ModRegistry());

        ModLoader.scan();
        register("modLoader", ModLoader);

        register("save", new SaveData());
        register("achievements", new Achievements());
        register("events", EventBus);
        register("scheduler", new Scheduler());
        register("notifications", new NotificationManager());
        register("scripts", new ScriptManager());
        
        LanguageManager.instance.load();

        registerModule(new EngineProfiler());

        Logger.info('${Version.fullVersion()} initialized.');

        initialized = true;
        onInit.dispatch();
    }

    public function registerModule(module:Module):Void {
        if (modules.exists(module.name)) return;
        module.initialize();
        modules.set(module.name, module);
    }

    public function removeModule(name:String):Void {
        if (!modules.exists(name)) return;
        var mod = modules.get(name);
        mod.destroy();
        modules.remove(name);
    }

    public function updateModules(elapsed:Float):Void {
        HotReloader.update();
        for (module in modules) {
            if (module.active) module.update(elapsed);
        }
    }

    public function notifyStateSwitch():Void {
        for (module in modules) {
            module.onStateSwitch();
        }
        System.gc();
    }

    public function register<T>(name:String, value:T):Void {
        services.set(name, value);
    }

    public function resolve<T>(name:String):Null<T> {
        if (!services.exists(name)) return null;
        return cast services.get(name);
    }
}