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
import soulscorch.backend.system.XMSoul;
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
import soulscorch.gameplay.song.SongRegistry;
import soulscorch.scripting.FileWatcher;
import soulscorch.scripting.mod.ModManager;
import soulscorch.scripting.mod.SoulGlobalScript;
import soulscorch.ui.menus.editors.EditorPickerMenu;
import soulscorch.ui.menus.states.TitleState;
import soulscorch.ui.menus.substate.ModSwitchMenu;

#if cpp
import cpp.vm.Gc;
#end

using StringTools;

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

            var game = new FlxGame(gameWidth, gameHeight, initialState, framerate, framerate, skipSplash, startFullscreen);
            addChild(game);

            Lib.current.stage.align = StageAlign.TOP_LEFT;
            Lib.current.stage.scaleMode = StageScaleMode.NO_SCALE;

            // Zero-Lag Engine Execution Setup
            FlxG.fixedTimestep = false;
            FlxG.autoPause = false;
            FlxG.mouse.useSystemCursor = false;

            #if (cpp && windows)
            cpp.vm.ExecutionTrace.setLevel(0);
            #end

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
            SongRegistry.scanAll();
            SoulGlobalScript.init();

            applyWindowConfiguration();

            #if desktop
            try {
                DiscordRPC.changePresence("Exploring SoulScorch Engine", "Booting Suite");
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

            Logger.info('Engine boot complete [${Version.fullVersion()}]', "main");
        } catch (e:Dynamic) {
            CrashHandler.handleCrash(Std.string(e), CallStack.exceptionStack(true));
        }
    }

    private function applyWindowConfiguration():Void {
        #if windows
        var access = XMSoul.parse("config/window");
        if (access == null) access = XMSoul.parse("data/config/window");

        if (access != null) {
            var darkMode = XMSoul.getBoolAttr(access, "darkMode", true);
            var alpha = XMSoul.getFloatAttr(access, "alpha", 1.0);
            var topmost = XMSoul.getBoolAttr(access, "topmost", false);
            var preventSleep = XMSoul.getBoolAttr(access, "preventSleep", true);

            NativeAPI.setDarkMode(darkMode);
            NativeAPI.setWindowAlpha(alpha);
            NativeAPI.setWindowTopmost(topmost);
            NativeAPI.setPreventSleep(preventSleep);

            if (access.hasNode.titlebar) {
                var tb = access.node.titlebar;
                if (tb.has.color) {
                    var col = tb.att.color.split(",").map(function(s) return Std.parseInt(s.trim()));
                    if (col.length >= 3) NativeAPI.setTitleBarColor(col[0], col[1], col[2]);
                }
                if (tb.has.borderColor) {
                    var bCol = tb.att.borderColor.split(",").map(function(s) return Std.parseInt(s.trim()));
                    if (bCol.length >= 3) NativeAPI.setBorderColor(bCol[0], bCol[1], bCol[2]);
                }
                if (tb.has.textColor) {
                    var tCol = tb.att.textColor.split(",").map(function(s) return Std.parseInt(s.trim()));
                    if (tCol.length >= 3) NativeAPI.setTitleTextColor(tCol[0], tCol[1], tCol[2]);
                }
            }
            Logger.info("Applied native window settings from window.xmsoul.", "main");
        } else {
            NativeAPI.setDarkMode(true);
        }
        #end
    }

    private function setupStateSwitchOptimization():Void {
        FlxG.signals.preStateSwitch.add(function() {
            Paths.clearUnusedMemory();
            EngineOptimizer.runMemorySweep();
        });
    }

    private function onKeyDown(event:KeyboardEvent):Void {
        if (FlxG.stage == null || FlxG.state == null) return;

        if (event.keyCode == Keyboard.F3 && fpsCounter != null) {
            fpsCounter.visible = !fpsCounter.visible;
        }

        if (event.keyCode == Keyboard.F5) {
            HotReloader.reload();
            XMSoul.clearCache();
            SongRegistry.scanAll();
            applyWindowConfiguration();
            Logger.info("Hot-reloaded engine assets, scanned songs, and cleared XMSoul cache.", "main");
        }

        if (event.keyCode == Keyboard.TAB && FlxG.state != null && FlxG.state.subState == null) {
            if (!FlxG.keys.pressed.CONTROL && !FlxG.keys.pressed.ALT) {
                FlxG.state.openSubState(new ModSwitchMenu());
            }
        }

        if (event.keyCode == Keyboard.NUMBER_7 && FlxG.state != null && FlxG.state.subState == null) {
            MusicBeatState.switchState(new EditorPickerMenu());
        }
    }

    private function onEnterFrame(event:Event):Void {
        var safeElapsed:Float = (FlxG.elapsed > 0) ? Math.min(FlxG.elapsed, 0.1) : (1.0 / framerate);

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