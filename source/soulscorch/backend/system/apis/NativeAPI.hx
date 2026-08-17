package soulscorch.backend.system.apis;

import soulscorch.backend.utils.Logger;

#if windows
@:buildXml('
<target id="haxe">
    <lib name="dwmapi.lib" if="windows" />
    <lib name="user32.lib" if="windows" />
    <lib name="shell32.lib" if="windows" />
</target>
')
@:cppFileCode('
#include <windows.h>
#include <dwmapi.h>
#include <iostream>
#pragma comment(lib, "dwmapi.lib")
#pragma comment(lib, "user32.lib")
#pragma comment(lib, "shell32.lib")
')
#end
class NativeAPI {
    #if windows
    @:functionCode('
        HWND hwnd = GetActiveWindow();
        if (hwnd == NULL) return;

        BOOL darkMode = enable ? TRUE : FALSE;
        // DWMWA_USE_IMMERSIVE_DARK_MODE attribute = 20
        DwmSetWindowAttribute(hwnd, 20, &darkMode, sizeof(darkMode));
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
        AllocConsole();
        FILE* fDummy;
        freopen_s(&fDummy, "CONIN$", "r", stdin);
        freopen_s(&fDummy, "CONOUT$", "w", stdout);
        freopen_s(&fDummy, "CONOUT$", "w", stderr);
    ')
    public static function allocConsole():Void {}
    #else
    public static function setDarkMode(enable:Bool):Void {}

    public static function showMessageError(title:String, message:String):Void {
        Logger.error('[$title] $message');
    }

    public static function showMessageInfo(title:String, message:String):Void {
        Logger.info('[$title] $message');
    }

    public static function allocConsole():Void {}
    #end
}