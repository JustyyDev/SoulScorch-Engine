package soulscorch;

import flixel.FlxGame;
import flixel.FlxG;
import openfl.display.Sprite;
import openfl.display.StageScaleMode;
import openfl.display.StageAlign;
import openfl.events.Event;
import openfl.events.UncaughtErrorEvent;
import openfl.Lib;
import openfl.text.TextField;
import openfl.text.TextFormat;
import haxe.CallStack;
import haxe.io.Path;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

import soulscorch.core.Runtime;
import soulscorch.core.GameConfig;
import soulscorch.backend.NativeAPI;
import soulscorch.media.AudioSpectrum;
import soulscorch.modding.FileWatcher;
import soulscorch.ui.DevConsole;
import soulscorch.ui.menus.TitleState;

class Main extends Sprite {
    var gameWidth:Int = 1280;
    var gameHeight:Int = 720;
    var initialState:Class<flixel.FlxState> = TitleState;
    var zoom:Float = -1.0;
    var framerate:Int = 60;
    var skipSplash:Bool = true;
    var startFullscreen:Bool = false;
    var lastTime:Float = 0;
    var frameCount:Int = 0;
    var currentFPS:Int = 0;

    public static var fpsCounter:TextField;
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
        #if desktop
        soulscorch.backend.DiscordRPC.initialize();
        openfl.Lib.current.stage.application.onExit.add(function(exitCode:Int) {
            soulscorch.backend.DiscordRPC.shutdown();
        });
        #end

        var config = new GameConfig(gameWidth, gameHeight, "SoulScorch Engine", framerate);
        Runtime.bootstrap(config);

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

        soulscorch.core.Runtime.setupFlixel();

        Lib.current.stage.align = StageAlign.TOP_LEFT;
        Lib.current.stage.scaleMode = StageScaleMode.NO_SCALE;

        var devConsole = new DevConsole();
        addChild(devConsole);

        setupPerformanceOverlay();

        fileWatcher = new FileWatcher();

        addEventListener(Event.ENTER_FRAME, onEnterFrame);

        haxe.Timer.delay(function() {
            #if windows
            NativeAPI.setDarkMode(true);
            #end
        }, 100);
    }

    private function setupPerformanceOverlay():Void {
        fpsCounter = new TextField();
        fpsCounter.x = 10;
        fpsCounter.y = 5;
        fpsCounter.selectable = false;
        fpsCounter.mouseEnabled = false;
        fpsCounter.defaultTextFormat = new TextFormat("_sans", 12, 0xFFFFFF);
        fpsCounter.text = "FPS: 0\nRAM: 0 MB";
        addChild(fpsCounter);
    }

    private function onEnterFrame(event:Event):Void {
        AudioSpectrum.update();

        if (fileWatcher != null) {
            fileWatcher.update(FlxG.elapsed);
        }

        var now = openfl.Lib.getTimer();
        frameCount++;
        if (now - lastTime >= 1000) {
            currentFPS = frameCount;
            frameCount = 0;
            lastTime = now;
        }

        if (fpsCounter != null && fpsCounter.visible) {
            #if cpp
            var mem:Float = Math.round((cpp.vm.Gc.memInfo64(cpp.vm.Gc.MEM_INFO_USAGE) / (1024 * 1024)) * 100) / 100;
            #else
            var mem:Float = Math.round((openfl.system.System.totalMemory / (1024 * 1024)) * 100) / 100;
            #end
            fpsCounter.text = 'FPS: ${currentFPS}\nRAM: ${mem} MB';
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