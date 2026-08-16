package soulscorch.backend;

import openfl.Lib;
import openfl.events.UncaughtErrorEvent;
import haxe.CallStack;
import haxe.io.Path;
import soulscorch.core.Logger;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

class CrashHandler {
    private static var installed:Bool = false;
    public static function install():Void { if (installed || Lib.current == null || Lib.current.loaderInfo == null) return; installed = true; Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onUncaughtError); }
    private static function onUncaughtError(event:UncaughtErrorEvent):Void {
        var message:String = event.error == null ? "Unknown error" : Std.string(event.error); var stack:String = CallStack.toString(CallStack.exceptionStack(true));
        #if sys
        if (!FileSystem.exists("logs")) FileSystem.createDirectory("logs");
        var stamp:String = Date.now().toString().split(" ").join("_").split(":").join("-");
        File.saveContent(Path.join(["logs", "SoulScorch_Crash_" + stamp + ".txt"]), "SoulScorch Engine Crash\n\n" + message + "\n\n" + stack);
        #end
        Logger.error("crash", message);
    }
}
