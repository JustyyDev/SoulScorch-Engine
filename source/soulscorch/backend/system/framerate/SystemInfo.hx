package soulscorch.backend.system.framerate;

import openfl.system.System;
#if cpp
import cpp.vm.Gc;
#end

class SystemInfo {
    public static var osInfo(get, never):String;
    public static var memoryMegabytes(get, never):Float;

    public static inline function getSystemMemoryMB():Float {
        #if cpp
        // Direct C++ GC tracking provides exact process memory rather than virtual reservations
        return Gc.memInfo64(Gc.MEM_INFO_USAGE) / (1024 * 1024);
        #elseif sys
        return System.totalMemory / (1024 * 1024);
        #else
        return 0.0;
        #end
    }

    private static inline function get_memoryMegabytes():Float {
        return getSystemMemoryMB();
    }

    private static function get_osInfo():String {
        #if windows
        return "Windows";
        #elseif linux
        return "Linux";
        #elseif mac
        return "macOS";
        #elseif html5
        return "Browser";
        #else
        return "Unknown OS";
        #end
    }
}