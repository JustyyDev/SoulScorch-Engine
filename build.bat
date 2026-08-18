@echo off
setlocal EnableDelayedExpansion
title SoulScorch Engine - Local Build Pipeline

echo ===================================================
echo   SoulScorch Engine - Local Build Pipeline
echo ===================================================
echo.

:: 1. Explicit Paths to Portable Tools
set "ROOT_DIR=%~dp0"
set "TOOLS_DIR=%ROOT_DIR%.tools"

set "HAXE_DIR=%TOOLS_DIR%\haxe"
set "NEKO_DIR=%TOOLS_DIR%\neko"
set "MINGW_DIR=%TOOLS_DIR%\mingw\bin"
set "HAXELIB_DIR=%ROOT_DIR%.haxelib"
if not exist "%HAXELIB_DIR%" set "HAXELIB_DIR=%TOOLS_DIR%\haxelib"

:: Fallback if haxe or neko are at the root of .tools
if not exist "%HAXE_DIR%\haxe.exe" if exist "%TOOLS_DIR%\haxe.exe" set "HAXE_DIR=%TOOLS_DIR%"
if not exist "%NEKO_DIR%\neko.exe" if exist "%TOOLS_DIR%\neko.exe" set "NEKO_DIR=%TOOLS_DIR%"

if not exist "%HAXE_DIR%\haxe.exe" (
    echo [ERROR] haxe.exe not found in "%HAXE_DIR%".
    pause
    exit /b 1
)

:: 2. Set Session Environment Variables
set "PATH=%HAXE_DIR%;%NEKO_DIR%;%PATH%"
if exist "%MINGW_DIR%" set "PATH=%MINGW_DIR%;%PATH%"

set "HAXEPATH=%HAXE_DIR%"
set "NEKOPATH=%NEKO_DIR%"
set "HAXE_STD_PATH=%HAXE_DIR%\std"
if exist "%HAXELIB_DIR%" set "HAXELIB_PATH=%HAXELIB_DIR%"

:: 3. Configure Git Safe Directories Automatically
where git >nul 2>&1
if %ERRORLEVEL% equ 0 git config --global --add safe.directory "*" >nul 2>&1

echo [OK] Using Haxe:    "%HAXE_DIR%"
echo [OK] Using Neko:    "%NEKO_DIR%"
if exist "%MINGW_DIR%" echo [OK] Using MinGW:   "%MINGW_DIR%"
if defined HAXELIB_PATH echo [OK] Using Haxelib: "%HAXELIB_PATH%"
echo.

:: 4. Start Compilation Server on Port 6000
taskkill /f /im haxe.exe /fi "WINDOWTITLE eq HaxeServer*" >nul 2>&1
start "HaxeServer" /b "%HAXE_DIR%\haxe.exe" --wait 6000 >nul 2>&1
timeout /t 1 /nobreak >nul

:: 5. Build Menu
echo Select Build Target:
echo [1] Fast Test (Neko VM - Instant launch, no C++ compiler needed)
echo [2] Windows C++ Test (Default toolchain)
echo [3] Windows C++ Test (Force 32-bit MSVC)
echo [4] Clean and Rebuild (Neko)
echo [5] Install / Setup Required Haxelibs
echo.
set /p target="Choice (default 1): "
if "%target%"=="" set "target=1"

if "%target%"=="1" (
    echo [*] Launching Neko Fast VM Test...
    "%HAXE_DIR%\haxelib.exe" run lime test windows -neko --connect 6000
) else if "%target%"=="2" (
    echo [*] Compiling C++ Windows build...
    if exist "%MINGW_DIR%" (
        "%HAXE_DIR%\haxelib.exe" run lime test windows -DHXCPP_MINGW --connect 6000
    ) else (
        "%HAXE_DIR%\haxelib.exe" run lime test windows --connect 6000
    )
) else if "%target%"=="3" (
    echo [*] Compiling 32-bit Windows build...
    "%HAXE_DIR%\haxelib.exe" run lime test windows -32 --connect 6000
) else if "%target%"=="4" (
    echo [*] Cleaning export cache...
    if exist "export" rd /s /q "export"
    if exist "bin" rd /s /q "bin"
    "%HAXE_DIR%\haxelib.exe" run lime test windows -neko --connect 6000
) else if "%target%"=="5" (
    if not exist "%HAXELIB_DIR%" mkdir "%HAXELIB_DIR%"
    "%HAXE_DIR%\haxelib.exe" setup "%HAXELIB_DIR%"
    "%HAXE_DIR%\haxelib.exe" install lime 8.1.3 --always
    "%HAXE_DIR%\haxelib.exe" install openfl 9.3.3 --always
    "%HAXE_DIR%\haxelib.exe" install flixel 5.6.1 --always
    "%HAXE_DIR%\haxelib.exe" install flixel-addons 3.2.3 --always
    "%HAXE_DIR%\haxelib.exe" install flixel-ui 2.6.1 --always
    "%HAXE_DIR%\haxelib.exe" install hscript 2.4.0 --always
    "%HAXE_DIR%\haxelib.exe" install hscript-iris 1.1.0 --always
    "%HAXE_DIR%\haxelib.exe" install away3d --always
    "%HAXE_DIR%\haxelib.exe" git linc_luajit https://github.com/AndreiRudenko/linc_luajit.git --always
    "%HAXE_DIR%\haxelib.exe" git hxdiscord_rpc https://github.com/MAJESTFormat/hxdiscord_rpc.git --always
    "%HAXE_DIR%\haxelib.exe" run lime setup -y
)

echo.
if %ERRORLEVEL% neq 0 (
    echo [x] Process failed.
) else (
    echo [OK] Done.
)

pause