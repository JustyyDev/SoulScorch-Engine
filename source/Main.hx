package;

import flixel.FlxG;
import flixel.FlxGame;
import flixel.FlxState;
import flixel.tweens.FlxTween;
import flixel.util.FlxTimer;
import haxe.CallStack;
import openfl.Lib;
import openfl.display.Sprite;
import openfl.display.StageAlign;
import openfl.display.StageScaleMode;
import openfl.events.Event;
import openfl.events.KeyboardEvent;
import openfl.ui.Keyboard;

import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.system.apis.NativeAPI;
import soulscorch.backend.system.engine.CrashHandler;
import soulscorch.backend.system.engine.DevConsole;
import soulscorch.backend.system.engine.Engine;
import soulscorch.backend.system.engine.EngineOptimizer;
import soulscorch.backend.system.engine.GameConfig;
import soulscorch.backend.system.engine.HotReloader;
import soulscorch.backend.system.engine.Runtime;
import soulscorch.backend.system.engine.Version;
import soulscorch.backend.system.framerate.Framerate;
import soulscorch.backend.system.modules.discord.DiscordRPC;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.FileWatcher;
import soulscorch.scripting.mod.ModManager;
import soulscorch.scripting.mod.SoulGlobalScript;
import soulscorch.ui.menus.editors.EditorPickerMenu;
import soulscorch.ui.menus.states.TitleState;
import soulscorch.ui.menus.substate.ModSwitchMenu;

#if cpp
import cpp.vm.Gc;
#end

class Main extends Sprite {
    public static var gameWidth:Int = 1280;
    public static var gameHeight:Int = 720;
    public static var initialState:Class<FlxState> = TitleState;
    public static var zoom:Float = -1.0;
    public static var framerate:Int = 120;
    public static var skipSplash:Bool = true;
    public static var startFullscreen:Bool = false;

    public static var fpsCounter:Framerate;
    public static var fileWatcher:FileWatcher;

    private static var fileWatchTimer:Float = 0.0;
    private static inline var FILE_WATCH_INTERVAL:Float = 0.5;

    public function new() {
        super();

        CrashHandler.install();

        if (stage != null) {
            init();
        } else {
            addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
        }
    }

    private function onAddedToStage(event:Event):Void {
        removeEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
        init();
    }

    private function init():Void {
        try {
            var stageWidth:Int = Lib.current.stage.stageWidth;
            var stageHeight:Int = Lib.current.stage.stageHeight;

            if (stageWidth <= 0) stageWidth = gameWidth;
            if (stageHeight <= 0) stageHeight = gameHeight;

            if (zoom == -1.0) {
                var ratioX:Float = stageWidth / gameWidth;
                var ratioY:Float = stageHeight / gameHeight;
                zoom = Math.min(ratioX, ratioY);
                gameWidth = Math.ceil(stageWidth / zoom);
                gameHeight = Math.ceil(stageHeight / zoom);
            }

            var game = new FlxGame(gameWidth, gameHeight, initialState, framerate, framerate, skipSplash, startFullscreen);
            addChild(game);

            Lib.current.stage.align = StageAlign.TOP_LEFT;
            Lib.current.stage.scaleMode = StageScaleMode.NO_SCALE;

            FlxG.fixedTimestep = false;
            FlxG.autoPause = false;
            FlxG.mouse.useSystemCursor = false;

            setupStateSwitchOptimization();

            var devConsole = DevConsole.instance;
            if (devConsole != null && devConsole.parent == null) {
                addChild(devConsole);
            }

            fpsCounter = new Framerate(10, 10, 0xFFFFFF);
            fpsCounter.visible = true;
            addChild(fpsCounter);

            var config = new GameConfig();
            config.framerate = framerate;
            Runtime.bootstrap(config);
            Runtime.setupFlixel();

            EngineOptimizer.init(framerate);

            ModManager.reloadMods();
            SoulGlobalScript.init();

            #if desktop
            try {
                DiscordRPC.changePresence("Starting Engine...", "Booting");
                Lib.current.stage.application.onExit.add(function(exitCode:Int) {
                    DiscordRPC.shutdown();
                });
            } catch (e:Dynamic) {
                Logger.warn('Discord RPC notice: $e', "discord");
            }
            #end

            fileWatcher = new FileWatcher();

            Lib.current.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
            addEventListener(Event.ENTER_FRAME, onEnterFrame);

            #if windows
            haxe.Timer.delay(function() {
                NativeAPI.setDarkMode(true);
            }, 100);
            #end

            Logger.info('Engine boot complete [${Version.fullVersion()}]', "main");
        } catch (e:Dynamic) {
            CrashHandler.handleCrash(Std.string(e), CallStack.exceptionStack(true));
        }
    }

    private function setupStateSwitchOptimization():Void {
        FlxG.signals.preStateSwitch.add(function() {
            FlxTween.globalManager.clear();
            FlxTimer.globalManager.clear();
            Paths.clearUnusedMemory();
        });

        FlxG.signals.postStateSwitch.add(function() {
            #if cpp
            Gc.run(false);
            #end
        });
    }

    private function onKeyDown(event:KeyboardEvent):Void {
        if (event.keyCode == Keyboard.F3 && fpsCounter != null) {
            fpsCounter.visible = !fpsCounter.visible;
        }

        if (event.keyCode == Keyboard.F5) {
            HotReloader.reload();
        }

        if (event.keyCode == Keyboard.TAB && FlxG.state != null && FlxG.state.subState == null) {
            FlxG.state.openSubState(new ModSwitchMenu());
        }

        if (event.keyCode == Keyboard.NUMBER_7 && FlxG.state != null && FlxG.state.subState == null) {
            MusicBeatState.switchState(new EditorPickerMenu());
        }
    }

    private function onEnterFrame(event:Event):Void {
        var safeElapsed:Float = Math.min(FlxG.elapsed, 0.1);

        fileWatchTimer += safeElapsed;
        if (fileWatchTimer >= FILE_WATCH_INTERVAL) {
            fileWatchTimer = 0.0;
            if (fileWatcher != null) {
                fileWatcher.update(FILE_WATCH_INTERVAL);
            }
        }

        HotReloader.update();
        EngineOptimizer.update(safeElapsed);

        #if (cpp && !mobile && !neko)
        DiscordRPC.poll();
        #end
    }
}