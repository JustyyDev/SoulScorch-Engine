package;

import flixel.FlxG;
import flixel.FlxGame;
import flixel.FlxState;
import haxe.CallStack;
import openfl.Lib;
import openfl.display.Sprite;
import openfl.display.StageAlign;
import openfl.display.StageScaleMode;
import openfl.events.Event;
import openfl.events.KeyboardEvent;
import openfl.ui.Keyboard;

import soulscorch.backend.MusicBeatState;
import soulscorch.backend.system.apis.NativeAPI;
import soulscorch.backend.system.engine.CrashHandler;
import soulscorch.backend.system.engine.DevConsole;
import soulscorch.backend.system.engine.Engine;
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

            var devConsole = DevConsole.instance;
            if (devConsole.parent == null) {
                addChild(devConsole);
            }

            fpsCounter = new Framerate(10, 10, 0xFFFFFF);
            fpsCounter.visible = true;
            addChild(fpsCounter);

            // Configure Game Runtime, Settings & Mods
            var config = new GameConfig();
            config.framerate = framerate;
            Runtime.bootstrap(config);
            Runtime.setupFlixel();

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

    private function onKeyDown(event:KeyboardEvent):Void {
        // Toggle FPS Counter Display
        if (event.keyCode == Keyboard.F3 && fpsCounter != null) {
            fpsCounter.visible = !fpsCounter.visible;
        }

        // Live Hot-Reload
        if (event.keyCode == Keyboard.F5) {
            HotReloader.reload();
        }

        // Quick Mod Switcher SubState
        if (event.keyCode == Keyboard.TAB && FlxG.state != null && FlxG.state.subState == null) {
            FlxG.state.openSubState(new ModSwitchMenu());
        }

        // Quick Developer Editor Suite
        if (event.keyCode == Keyboard.NUMBER_7 && FlxG.state != null && FlxG.state.subState == null) {
            MusicBeatState.switchState(new EditorPickerMenu());
        }
    }

    private function onEnterFrame(event:Event):Void {
        if (fileWatcher != null) {
            fileWatcher.update(FlxG.elapsed);
        }
        HotReloader.update();
    }
}