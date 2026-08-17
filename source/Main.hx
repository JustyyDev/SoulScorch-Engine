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
import openfl.events.UncaughtErrorEvent;
import openfl.ui.Keyboard;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

import soulscorch.backend.MusicBeatState;
import soulscorch.backend.system.apis.NativeAPI;
import soulscorch.backend.system.engine.DevConsole;
import soulscorch.backend.system.engine.Engine;
import soulscorch.backend.system.engine.GameConfig;
import soulscorch.backend.system.engine.Version;
import soulscorch.backend.system.framerate.Framerate;
import soulscorch.backend.system.modules.discord.DiscordRPC;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.FileWatcher;
import soulscorch.ui.menus.editors.EditorPickerMenu;
import soulscorch.ui.menus.states.TitleState;
import soulscorch.ui.menus.substate.ModSwitchMenu;

class Main extends Sprite {
    var gameWidth:Int = 1280;
    var gameHeight:Int = 720;
    var initialState:Class<FlxState> = TitleState;
    var zoom:Float = -1.0;
    var framerate:Int = 120;
    var skipSplash:Bool = true;
    var startFullscreen:Bool = false;

    public static var fpsCounter:Framerate;
    public static var fileWatcher:FileWatcher;

    public function new() {
        super();

        Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onUncaughtError);

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
        var config = new GameConfig();
        config.framerate = framerate;
        Engine.boot(config).init();

        #if desktop
        DiscordRPC.changePresence("Starting Engine...", "Booting");
        Lib.current.stage.application.onExit.add(function(exitCode:Int) {
            DiscordRPC.shutdown();
        });
        #end

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

        var devConsole = new DevConsole();
        addChild(devConsole);

        fpsCounter = new Framerate(10, 10, 0xFFFFFF);
        fpsCounter.visible = true;
        addChild(fpsCounter);

        fileWatcher = new FileWatcher();

        Lib.current.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
        addEventListener(Event.ENTER_FRAME, onEnterFrame);

        haxe.Timer.delay(function() {
            #if windows
            NativeAPI.setDarkMode(true);
            #end
        }, 100);

        Logger.info('Engine boot complete [${Version.fullVersion()}]', "main");
    }

    private function onKeyDown(event:KeyboardEvent):Void {
        if (event.keyCode == Keyboard.F3 && fpsCounter != null) {
            fpsCounter.visible = !fpsCounter.visible;
        }

        if (event.keyCode == Keyboard.TAB && FlxG.state != null && FlxG.state.subState == null) {
            FlxG.state.openSubState(new ModSwitchMenu());
        }

        if (event.keyCode == Keyboard.NUMBER_7 && FlxG.state != null && FlxG.state.subState == null) {
            MusicBeatState.switchState(new EditorPickerMenu());
        }
    }

    private function onEnterFrame(event:Event):Void {
        if (fileWatcher != null) {
            fileWatcher.update(FlxG.elapsed);
        }
    }

    private function onUncaughtError(e:UncaughtErrorEvent):Void {
        var errorMessage:String = "";
        var stack:Array<StackItem> = CallStack.exceptionStack(true);

        if (Std.isOfType(e.error, haxe.Exception)) {
            var err:haxe.Exception = cast e.error;
            errorMessage = err.message;
        } else {
            errorMessage = Std.string(e.error);
        }

        var stackTrace:String = CallStack.toString(stack);
        var fullCrashLog:String = 'Uncaught Fatal Exception:\n$errorMessage\n\nStack Trace:\n$stackTrace';

        #if sys
        try {
            if (!FileSystem.exists("crash")) FileSystem.createDirectory("crash");
            var dateStr = Date.now().toString().split(" ").join("_").split(":").join("-");
            var crashPath = 'crash/SoulScorch_Crash_$dateStr.txt';
            File.saveContent(crashPath, fullCrashLog);
            Sys.println('[FATAL CRASH LOGGED TO $crashPath]');
        } catch (err:Dynamic) {
            Sys.println('[COULD NOT SAVE CRASH FILE: $err]');
        }
        #end

        #if windows
        NativeAPI.showMessageError("SoulScorch Engine - Fatal Crash", fullCrashLog);
        #else
        Sys.println(fullCrashLog);
        #end

        Sys.exit(1);
    }
}