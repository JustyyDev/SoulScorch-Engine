package soulscorch.backend.system.apis;

import soulscorch.backend.utils.Logger;

#if windows
@:buildXml('
<target id="haxe">
    <lib name="dwmapi.lib" if="windows" />
    <lib name="user32.lib" if="windows" />
    <lib name="shell32.lib" if="windows" />
    <lib name="gdi32.lib" if="windows" />
    <lib name="psapi.lib" if="windows" />
</target>
')
@:cppFileCode('
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <dwmapi.h>
#include <psapi.h>
#include <shellapi.h>
#include <iostream>
#include <string>

// Undefine conflicting Windows SDK macros to keep OpenFL/Flixel compiling cleanly
#undef ERROR
#undef DELETE
#undef TRANSPARENT
#undef OPAQUE
#undef IN
#undef OUT
#undef NO_ERROR
#undef min
#undef max

#pragma comment(lib, "dwmapi.lib")
#pragma comment(lib, "user32.lib")
#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "gdi32.lib")
#pragma comment(lib, "psapi.lib")

// Reliable fallback window finder across active threads
static HWND getEngineHWND() {
    HWND hwnd = GetActiveWindow();
    if (hwnd == NULL) hwnd = GetForegroundWindow();
    if (hwnd == NULL) {
        DWORD currentProcId = GetCurrentProcessId();
        HWND found = NULL;
        do {
            found = FindWindowExA(NULL, found, NULL, NULL);
            DWORD procId = 0;
            GetWindowThreadProcessId(found, &procId);
            if (procId == currentProcId && IsWindowVisible(found)) {
                return found;
            }
        } while (found != NULL);
    }
    return hwnd;
}
')
#end
class NativeAPI {
    #if windows

    // ==========================================
    // WINDOW THEME & CHROME (Win10 / Win11 DWM)
    // ==========================================

    @:functionCode('
        HWND hwnd = getEngineHWND();
        if (hwnd == NULL) return;

        BOOL darkMode = enable ? TRUE : FALSE;
        // DWMWA_USE_IMMERSIVE_DARK_MODE (20 on Win11/modern Win10, 19 on early Win10)
        if (FAILED(DwmSetWindowAttribute(hwnd, 20, &darkMode, sizeof(darkMode)))) {
            DwmSetWindowAttribute(hwnd, 19, &darkMode, sizeof(darkMode));
        }
        UpdateWindow(hwnd);
    ')
    public static function setDarkMode(enable:Bool):Void {}

    @:functionCode('
        HWND hwnd = getEngineHWND();
        if (hwnd == NULL) return;

        // COLORREF is 0x00BBGGRR
        COLORREF color = RGB(r, g, b);
        // DWMWA_CAPTION_COLOR = 35 (Windows 11 Build 22000+)
        DwmSetWindowAttribute(hwnd, 35, &color, sizeof(color));
        UpdateWindow(hwnd);
    ')
    public static function setTitleBarColor(r:Int, g:Int, b:Int):Void {}

    @:functionCode('
        HWND hwnd = getEngineHWND();
        if (hwnd == NULL) return;

        COLORREF color = RGB(r, g, b);
        // DWMWA_BORDER_COLOR = 34 (Windows 11 Build 22000+)
        DwmSetWindowAttribute(hwnd, 34, &color, sizeof(color));
        UpdateWindow(hwnd);
    ')
    public static function setBorderColor(r:Int, g:Int, b:Int):Void {}

    @:functionCode('
        HWND hwnd = getEngineHWND();
        if (hwnd == NULL) return;

        COLORREF color = RGB(r, g, b);
        // DWMWA_TEXT_COLOR = 36 (Windows 11 Build 22000+)
        DwmSetWindowAttribute(hwnd, 36, &color, sizeof(color));
        UpdateWindow(hwnd);
    ')
    public static function setTitleTextColor(r:Int, g:Int, b:Int):Void {}

    // ==========================================
    // WINDOW POSITION, SIZE & TRANSPARENCY
    // ==========================================

    @:functionCode('
        HWND hwnd = getEngineHWND();
        if (hwnd == NULL) return;

        LONG style = GetWindowLong(hwnd, GWL_EXSTYLE);
        if (alpha < 1.0f) {
            SetWindowLong(hwnd, GWL_EXSTYLE, style | WS_EX_LAYERED);
            BYTE bAlpha = (BYTE)(alpha * 255.0f);
            SetLayeredWindowAttributes(hwnd, 0, bAlpha, LWA_ALPHA);
        } else {
            SetWindowLong(hwnd, GWL_EXSTYLE, style & ~WS_EX_LAYERED);
        }
        UpdateWindow(hwnd);
    ')
    public static function setWindowAlpha(alpha:Float):Void {}

    @:functionCode('
        HWND hwnd = getEngineHWND();
        if (hwnd != NULL) {
            SetWindowPos(hwnd, NULL, x, y, 0, 0, SWP_NOZORDER | SWP_NOSIZE);
        }
    ')
    public static function setWindowPosition(x:Int, y:Int):Void {}

    @:functionCode('
        HWND hwnd = getEngineHWND();
        if (hwnd != NULL) {
            SetWindowPos(hwnd, NULL, 0, 0, width, height, SWP_NOZORDER | SWP_NOMOVE);
        }
    ')
    public static function setWindowSize(width:Int, height:Int):Void {}

    @:functionCode('
        HWND hwnd = getEngineHWND();
        if (hwnd != NULL) {
            RECT rect;
            GetWindowRect(hwnd, &rect);
            int winWidth = rect.right - rect.left;
            int winHeight = rect.bottom - rect.top;
            int screenWidth = GetSystemMetrics(SM_CXSCREEN);
            int screenHeight = GetSystemMetrics(SM_CYSCREEN);
            int posX = (screenWidth - winWidth) / 2;
            int posY = (screenHeight - winHeight) / 2;
            SetWindowPos(hwnd, NULL, posX, posY, 0, 0, SWP_NOZORDER | SWP_NOSIZE);
        }
    ')
    public static function centerWindow():Void {}

    @:functionCode('
        HWND hwnd = getEngineHWND();
        if (hwnd != NULL) {
            SetWindowPos(hwnd, topmost ? HWND_TOPMOST : HWND_NOTOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE);
        }
    ')
    public static function setWindowTopmost(topmost:Bool):Void {}

    @:functionCode('
        HWND hwnd = getEngineHWND();
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
        HWND hwnd = getEngineHWND();
        if (hwnd != NULL) ShowWindow(hwnd, SW_MINIMIZE);
    ')
    public static function minimizeWindow():Void {}

    @:functionCode('
        HWND hwnd = getEngineHWND();
        if (hwnd != NULL) ShowWindow(hwnd, SW_MAXIMIZE);
    ')
    public static function maximizeWindow():Void {}

    @:functionCode('
        HWND hwnd = getEngineHWND();
        if (hwnd != NULL) ShowWindow(hwnd, SW_RESTORE);
    ')
    public static function restoreWindow():Void {}

    @:functionCode('
        HWND hwnd = getEngineHWND();
        return (hwnd != NULL && GetForegroundWindow() == hwnd);
    ')
    public static function isWindowFocused():Bool { return true; }

    @:functionCode('
        HWND hwnd = getEngineHWND();
        if (hwnd != NULL) SetWindowTextA(hwnd, title.c_str());
    ')
    public static function setWindowTitle(title:String):Void {}

    // ==========================================
    // HARDWARE & SYSTEM METRICS
    // ==========================================

    @:functionCode('
        PROCESS_MEMORY_COUNTERS_EX pmc;
        if (GetProcessMemoryInfo(GetCurrentProcess(), (PROCESS_MEMORY_COUNTERS*)&pmc, sizeof(pmc))) {
            return (Float)(pmc.WorkingSetSize / (1024 * 1024));
        }
        return 0.0;
    ')
    public static function getProcessMemoryUsedMB():Float { return 0.0; }

    @:functionCode('
        MEMORYSTATUSEX memInfo;
        memInfo.dwLength = sizeof(MEMORYSTATUSEX);
        if (GlobalMemoryStatusEx(&memInfo)) {
            return (Float)(memInfo.ullTotalPhys / (1024 * 1024));
        }
        return 0.0;
    ')
    public static function getTotalSystemMemoryMB():Float { return 0.0; }

    @:functionCode('
        DEVMODE dm;
        dm.dmSize = sizeof(DEVMODE);
        if (EnumDisplaySettings(NULL, ENUM_CURRENT_SETTINGS, &dm)) {
            return dm.dmDisplayFrequency;
        }
        return 60;
    ')
    public static function getDisplayRefreshRate():Int { return 60; }

    @:functionCode('
        if (prevent) {
            SetThreadExecutionState(ES_CONTINUOUS | ES_DISPLAY_REQUIRED | ES_SYSTEM_REQUIRED);
        } else {
            SetThreadExecutionState(ES_CONTINUOUS);
        }
    ')
    public static function setPreventSleep(prevent:Bool):Void {}

    // ==========================================
    // DESKTOP INTERACTION & SYSTEM UTILITIES
    // ==========================================

    @:functionCode('
        if (!OpenClipboard(NULL)) return String("");
        HANDLE hData = GetClipboardData(CF_TEXT);
        if (hData == NULL) {
            CloseClipboard();
            return String("");
        }
        char* pszText = static_cast<char*>(GlobalLock(hData));
        String result = String(pszText);
        GlobalUnlock(hData);
        CloseClipboard();
        return result;
    ')
    public static function getClipboardText():String { return ""; }

    @:functionCode('
        if (!OpenClipboard(NULL)) return;
        EmptyClipboard();
        HGLOBAL hGlob = GlobalAlloc(GMEM_FIXED, text.length + 1);
        if (hGlob != NULL) {
            memcpy(hGlob, text.c_str(), text.length + 1);
            SetClipboardData(CF_TEXT, hGlob);
        }
        CloseClipboard();
    ')
    public static function setClipboardText(text:String):Void {}

    @:functionCode('
        std::string param = "/select,\"" + path + "\"";
        ShellExecuteA(NULL, "open", "explorer.exe", param.c_str(), NULL, SW_SHOWNORMAL);
    ')
    public static function revealInExplorer(path:String):Void {}

    @:functionCode('
        HWND hwnd = getEngineHWND();
        int result = MessageBoxA(hwnd, message.c_str(), title.c_str(), MB_YESNO | MB_ICONQUESTION);
        return (result == IDYES);
    ')
    public static function showMessagePrompt(title:String, message:String):Bool { return true; }

    @:functionCode('
        HWND hwnd = getEngineHWND();
        MessageBoxA(hwnd, message.c_str(), title.c_str(), MB_OK | MB_ICONERROR);
    ')
    public static function showMessageError(title:String, message:String):Void {}

    @:functionCode('
        HWND hwnd = getEngineHWND();
        MessageBoxA(hwnd, message.c_str(), title.c_str(), MB_OK | MB_ICONINFORMATION);
    ')
    public static function showMessageInfo(title:String, message:String):Void {}

    @:functionCode('
        HWND hwnd = getEngineHWND();
        MessageBoxA(hwnd, message.c_str(), title.c_str(), MB_OK | MB_ICONWARNING);
    ')
    public static function showMessageWarning(title:String, message:String):Void {}

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

    #else

    // ==========================================
    // CROSS-PLATFORM FALLBACK IMPLEMENTATION
    // ==========================================

    public static function setDarkMode(enable:Bool):Void {}
    public static function setTitleBarColor(r:Int, g:Int, b:Int):Void {}
    public static function setBorderColor(r:Int, g:Int, b:Int):Void {}
    public static function setTitleTextColor(r:Int, g:Int, b:Int):Void {}
    public static function setWindowAlpha(alpha:Float):Void {}
    public static function setWindowPosition(x:Int, y:Int):Void {}
    public static function setWindowSize(width:Int, height:Int):Void {}
    public static function centerWindow():Void {}
    public static function setWindowTopmost(topmost:Bool):Void {}
    public static function flashWindow():Void {}
    public static function minimizeWindow():Void {}
    public static function maximizeWindow():Void {}
    public static function restoreWindow():Void {}
    public static function isWindowFocused():Bool { return true; }
    public static function setWindowTitle(title:String):Void {}
    public static function getProcessMemoryUsedMB():Float { return 0.0; }
    public static function getTotalSystemMemoryMB():Float { return 0.0; }
    public static function getDisplayRefreshRate():Int { return 60; }
    public static function setPreventSleep(prevent:Bool):Void {}
    public static function getClipboardText():String { return ""; }
    public static function setClipboardText(text:String):Void {}

    public static function revealInExplorer(path:String):Void {
        #if linux
        try { Sys.command("xdg-open", [path]); } catch (e:Dynamic) {}
        #elseif mac
        try { Sys.command("open", ["-R", path]); } catch (e:Dynamic) {}
        #end
    }

    public static function showMessagePrompt(title:String, message:String):Bool {
        Logger.info('[$title Prompt] $message', "native");
        return true;
    }

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

    public static function allocConsole():Void {}
    public static function freeConsole():Void {}

    #end
}