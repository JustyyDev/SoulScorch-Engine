package soulscorch.backend.system.framerate;

import openfl.system.System;

#if cpp
import cpp.vm.Gc;
#end

class SystemInfo {
    public static var osInfo(get, never):String;
    public static var archInfo(get, never):String;
    public static var memoryMegabytes(get, never):Float;

    public static inline function getSystemMemoryMB():Float {
        #if cpp
        return Math.round((Gc.memInfo64(Gc.MEM_INFO_USAGE) / (1024 * 1024)) * 100) / 100;
        #elseif sys
        return Math.round((System.totalMemory / (1024 * 1024)) * 100) / 100;
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
        #elseif android
        return "Android";
        #elseif ios
        return "iOS";
        #elseif html5
        return "Browser";
        #else
        return "Unknown OS";
        #end
    }

    private static function get_archInfo():String {
        #if (cpp && HXCPP_ARM64)
        return "ARM64";
        #elseif (cpp && HXCPP_M64)
        return "x86_64";
        #elseif (cpp && HXCPP_M32)
        return "x86";
        #else
        return "Generic";
        #end
    }
}