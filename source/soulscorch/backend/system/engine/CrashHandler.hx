package soulscorch.backend.system.engine;

import haxe.CallStack;
import openfl.Lib;
import openfl.errors.Error;
import openfl.events.UncaughtErrorEvent;
import soulscorch.backend.system.apis.NativeAPI;
import soulscorch.backend.utils.GameTime;
import soulscorch.backend.utils.Logger;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

class CrashHandler {
    public static function install():Void {
        Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onUncaughtError);
        #if cpp
        untyped __global__.__hxcpp_set_critical_error_handler(onCriticalError);
        #end
    }

    private static function onUncaughtError(e:UncaughtErrorEvent):Void {
        var errorMessage:String = "";
        var stack = CallStack.exceptionStack(true);

        if (Std.isOfType(e.error, Error)) {
            var err:openfl.errors.Error = cast e.error;
            errorMessage = '${err.message}\n${err.getStackTrace()}';
        } else if (e.error != null) {
            errorMessage = Std.string(e.error);
        }

        handleCrash(errorMessage, stack);
    }

    #if cpp
    private static function onCriticalError(message:String):Void {
        handleCrash(message, CallStack.callStack());
    }
    #end

    public static function handleCrash(error:String, stack:Array<StackItem>):Void {
        var stackFormatted:String = CallStack.toString(stack);
        var dateFormatted:String = StringTools.replace(GameTime.dateString(), ":", "-");
        var logContent:String = '==============================\n'
            + '${Version.fullVersion()}\n'
            + 'CRASH REPORT - $dateFormatted\n'
            + '==============================\n\n'
            + 'ERROR:\n$error\n\n'
            + 'CALL STACK:\n$stackFormatted\n';

        Logger.error('FATAL ENGINE CRASH:\n$error\n$stackFormatted');

        #if sys
        try {
            if (!FileSystem.exists("crash")) FileSystem.createDirectory("crash");
            File.saveContent('crash/SoulScorch_$dateFormatted.txt', logContent);
        } catch (e:Dynamic) {
            Logger.error('Failed to write crash dump to file: $e');
        }
        #end

        NativeAPI.showMessageError("SoulScorch Engine - Crash Detected", 'An unhandled exception occurred:\n\n$error\n\nA crash log was generated in the crash/ folder.');
        #if sys
        Sys.exit(1);
        #end
    }
}