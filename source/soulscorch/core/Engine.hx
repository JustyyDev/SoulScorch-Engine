package soulscorch.core;

import soulscorch.modding.ModRegistry;
import soulscorch.modding.ModLoader;
import flixel.util.FlxSignal.FlxTypedSignal;
import openfl.system.System;
import soulscorch.scripting.ScriptManager;
import soulscorch.backend.localization.LanguageManager;

class Engine {
    public static var instance(default, null):Engine;

    public var config:GameConfig;
    public var services:Map<String, Dynamic>;
    public var initialized:Bool;
    
    public var modules:Map<String, Module>;
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
        
        initialized = false;
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

        var modLoader = new ModLoader();
        modLoader.scan();
        register("modLoader", modLoader);

        register("save", new SaveData());
        register("achievements", new Achievements());

        register("logger", new Logger());
        register("events", new EventBus());
        register("scheduler", new Scheduler());
        register("i18n", new Localization());
        register("notifications", new NotificationManager());
        register("scripts", new ScriptManager());
        LanguageManager.instance.load();

        registerModule(new EngineProfiler());

        Logger.info("engine", "SoulScorch " + Version.fullVersion() + " initialized.");

        initialized = true;
        onInit.dispatch();
    }

    public function registerModule(module:Module):Void {
        if (modules.exists(module.name)) return;
        module.initialize(this);
        modules.set(module.name, module);
    }

    public function removeModule(name:String):Void {
        if (!modules.exists(name)) return;
        var mod = modules.get(name);
        mod.destroy();
        modules.remove(name);
    }

    public function updateModules(elapsed:Float):Void {
        var scripts:ScriptManager = resolve("scripts");
        if (scripts != null) scripts.updateHotReload();
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