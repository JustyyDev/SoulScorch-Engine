package soulscorch.backend.system.apis;

import soulscorch.backend.utils.Logger;

#if windows
@:buildXml('
<target id="haxe">
    <lib name="dwmapi.lib" if="windows" />
    <lib name="user32.lib" if="windows" />
    <lib name="shell32.lib" if="windows" />
    <lib name="gdi32.lib" if="windows" />
</target>
')
@:cppFileCode('
#include <windows.h>
#include <dwmapi.h>
#include <iostream>
#include <shellapi.h>
#pragma comment(lib, "dwmapi.lib")
#pragma comment(lib, "user32.lib")
#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "gdi32.lib")
')
#end
class NativeAPI {
    #if windows
    @:functionCode('
        HWND hwnd = GetActiveWindow();
        if (hwnd == NULL) return;

        BOOL darkMode = enable ? TRUE : FALSE;
        // Attribute 20 (Windows 11 / modern Windows 10) & Attribute 19 (older builds)
        if (FAILED(DwmSetWindowAttribute(hwnd, 20, &darkMode, sizeof(darkMode)))) {
            DwmSetWindowAttribute(hwnd, 19, &darkMode, sizeof(darkMode));
        }
        UpdateWindow(hwnd);
    ')
    public static function setDarkMode(enable:Bool):Void {}

    @:functionCode('
        HWND hwnd = GetActiveWindow();
        MessageBoxA(hwnd, message.c_str(), title.c_str(), MB_OK | MB_ICONERROR);
    ')
    public static function showMessageError(title:String, message:String):Void {}

    @:functionCode('
        HWND hwnd = GetActiveWindow();
        MessageBoxA(hwnd, message.c_str(), title.c_str(), MB_OK | MB_ICONINFORMATION);
    ')
    public static function showMessageInfo(title:String, message:String):Void {}

    @:functionCode('
        HWND hwnd = GetActiveWindow();
        MessageBoxA(hwnd, message.c_str(), title.c_str(), MB_OK | MB_ICONWARNING);
    ')
    public static function showMessageWarning(title:String, message:String):Void {}

    @:functionCode('
        HWND hwnd = GetActiveWindow();
        return (hwnd != NULL && GetForegroundWindow() == hwnd);
    ')
    public static function isWindowFocused():Bool { return true; }

    @:functionCode('
        HWND hwnd = GetActiveWindow();
        if (hwnd != NULL) {
            SetWindowTextA(hwnd, title.c_str());
        }
    ')
    public static function setWindowTitle(title:String):Void {}

    @:functionCode('
        HWND hwnd = GetActiveWindow();
        if (hwnd != NULL) {
            POINT pt;
            GetCursorPos(&pt);
            ScreenToClient(hwnd, &pt);
            return (float)pt.x;
        }
        return 0.0f;
    ')
    public static function getWindowMouseX():Float { return 0.0; }

    @:functionCode('
        HWND hwnd = GetActiveWindow();
        if (hwnd != NULL) {
            POINT pt;
            GetCursorPos(&pt);
            ScreenToClient(hwnd, &pt);
            return (float)pt.y;
        }
        return 0.0f;
    ')
    public static function getWindowMouseY():Float { return 0.0; }

    @:functionCode('
        AllocConsole();
        FILE* fDummy;
        freopen_s(&fDummy, "CONIN$", "r", stdin);
        freopen_s(&fDummy, "CONOUT$", "w", stdout);
        freopen_s(&fDummy, "CONOUT$", "w", stderr);
        std::cout.clear();
        std::clog.clear();
        std::cerr.clear();
        std::cin.clear();
    ')
    public static function allocConsole():Void {}

    @:functionCode('
        FreeConsole();
    ')
    public static function freeConsole():Void {}

    @:functionCode('
        HWND hwnd = GetActiveWindow();
        if (hwnd != NULL) {
            SetWindowPos(hwnd, topmost ? HWND_TOPMOST : HWND_NOTOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE);
        }
    ')
    public static function setWindowTopmost(topmost:Bool):Void {}

    @:functionCode('
        HWND hwnd = GetActiveWindow();
        if (hwnd != NULL) {
            FLASHWINFO fi;
            fi.cbSize = sizeof(FLASHWINFO);
            fi.hwnd = hwnd;
            fi.dwFlags = FLASHW_ALL | FLASHW_TIMERNOFG;
            fi.uCount = 3;
            fi.dwTimeout = 0;
            FlashWindowEx(&fi);
        }
    ')
    public static function flashWindow():Void {}

    @:functionCode('
        HWND hwnd = GetActiveWindow();
        if (hwnd != NULL) {
            ShowWindow(hwnd, SW_MINIMIZE);
        }
    ')
    public static function minimizeWindow():Void {}

    @:functionCode('
        HWND hwnd = GetActiveWindow();
        if (hwnd != NULL) {
            ShowWindow(hwnd, SW_MAXIMIZE);
        }
    ')
    public static function maximizeWindow():Void {}

    @:functionCode('
        HWND hwnd = GetActiveWindow();
        if (hwnd != NULL) {
            ShowWindow(hwnd, SW_RESTORE);
        }
    ')
    public static function restoreWindow():Void {}
    #else
    public static function setDarkMode(enable:Bool):Void {}

    public static function showMessageError(title:String, message:String):Void {
        Logger.error('[$title] $message', "native");
        #if linux
        try { Sys.command("notify-send", [title, message, "-u", "critical"]); } catch (e:Dynamic) {}
        #end
    }

    public static function showMessageInfo(title:String, message:String):Void {
        Logger.info('[$title] $message', "native");
        #if linux
        try { Sys.command("notify-send", [title, message]); } catch (e:Dynamic) {}
        #end
    }

    public static function showMessageWarning(title:String, message:String):Void {
        Logger.warn('[$title] $message', "native");
        #if linux
        try { Sys.command("notify-send", [title, message, "-u", "normal"]); } catch (e:Dynamic) {}
        #end
    }

    public static function isWindowFocused():Bool { return true; }
    public static function setWindowTitle(title:String):Void {}
    public static function getWindowMouseX():Float { return 0.0; }
    public static function getWindowMouseY():Float { return 0.0; }
    public static function allocConsole():Void {}
    public static function freeConsole():Void {}
    public static function setWindowTopmost(topmost:Bool):Void {}
    public static function flashWindow():Void {}
    public static function minimizeWindow():Void {}
    public static function maximizeWindow():Void {}
    public static function restoreWindow():Void {}
    #end
}