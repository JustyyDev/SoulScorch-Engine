@echo off
setlocal EnableDelayedExpansion
title SoulScorch Engine - High-Speed Build Pipeline

echo ===================================================
echo   SoulScorch Engine - High-Speed Build Pipeline
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

:: Fallback if tools are at the root of .tools
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

:: 3. Multithreaded C++ Compilation Optimization
if defined NUMBER_OF_PROCESSORS (
    set "HXCPP_COMPILE_THREADS=%NUMBER_OF_PROCESSORS%"
) else (
    set "HXCPP_COMPILE_THREADS=8"
)
set "HXCPP_VERBOSE=0"

:: 4. Configure Git Safe Directories
where git >nul 2>&1
if %ERRORLEVEL% equ 0 git config --global --add safe.directory "*" >nul 2>&1

echo [OK] Using Haxe:        "%HAXE_DIR%"
echo [OK] Using Neko:        "%NEKO_DIR%"
echo [OK] Compiling Threads: %HXCPP_COMPILE_THREADS%
if exist "%MINGW_DIR%" echo [OK] Using MinGW:       "%MINGW_DIR%"
if defined HAXELIB_PATH echo [OK] Using Haxelib:     "%HAXELIB_PATH%"
echo.

:: 5. Build Menu
echo Select Build Target:
echo [1] Fast Test (Neko VM - Instant launch)
echo [2] Fast CPPIA Test (Direct C++ host runner)
echo [3] Windows C++ Test (Multithreaded Release)
echo [4] Windows C++ Debug (With Crash Tracing)
echo [5] Clean and Rebuild C++
echo [6] Install / Setup Required Haxelibs
echo.
set /p target="Choice (default 1): "
if "%target%"=="" set "target=1"

if "%target%"=="1" (
    echo [*] Launching Neko Fast VM Test...
    "%HAXE_DIR%\haxelib.exe" run lime test windows -neko
) else if "%target%"=="2" (
    echo [*] Running CPPIA Bytecode Test...
    "%HAXE_DIR%\haxelib.exe" run lime test windows -cppia
) else if "%target%"=="3" (
    echo [*] Compiling Multithreaded Windows C++ build...
    if exist "%MINGW_DIR%" (
        "%HAXE_DIR%\haxelib.exe" run lime test windows -DHXCPP_MINGW -DHXCPP_PCH
    ) else (
        "%HAXE_DIR%\haxelib.exe" run lime test windows -DHXCPP_PCH
    )
) else if "%target%"=="4" (
    echo [*] Compiling Windows C++ with Debug Tracing...
    "%HAXE_DIR%\haxelib.exe" run lime test windows -debug -DHXCPP_STACK_LINE
) else if "%target%"=="5" (
    echo [*] Terminating lingering game processes...
    taskkill /F /IM SoulScorch.exe /T 2>nul
    taskkill /F /IM SoulScorch-debug.exe /T 2>nul
    timeout /t 1 /nobreak >nul

    echo [*] Cleaning export and bin directories...
    if exist "export\release" rd /s /q "export\release" 2>nul
    if exist "export" rd /s /q "export" 2>nul
    if exist "bin" rd /s /q "bin" 2>nul

    echo [*] Rebuilding C++...
    "%HAXE_DIR%\haxelib.exe" run lime test windows -DHXCPP_PCH
) else if "%target%"=="6" (
    if not exist "%HAXELIB_DIR%" mkdir "%HAXELIB_DIR%"
    "%HAXE_DIR%\haxelib.exe" setup "%HAXELIB_DIR%"
    "%HAXE_DIR%\haxelib.exe" install lime 8.1.3 --always
    "%HAXE_DIR%\haxelib.exe" install openfl 9.3.3 --always
    "%HAXE_DIR%\haxelib.exe" install flixel 5.6.2 --always
    "%HAXE_DIR%\haxelib.exe" install flixel-addons 3.2.3 --always
    "%HAXE_DIR%\haxelib.exe" install flixel-ui 2.6.1 --always
    "%HAXE_DIR%\haxelib.exe" install hscript 2.5.0 --always
    "%HAXE_DIR%\haxelib.exe" set hscript 2.5.0
    "%HAXE_DIR%\haxelib.exe" install hscript-iris 1.1.0 --always
    "%HAXE_DIR%\haxelib.exe" install away3d --always
    "%HAXE_DIR%\haxelib.exe" git linc_luajit https://github.com/AndreiRudenko/linc_luajit.git --always
    "%HAXE_DIR%\haxelib.exe" git hxdiscord_rpc https://github.com/MAJigsaw77/hxdiscord_rpc --always
    "%HAXE_DIR%\haxelib.exe" run lime setup -y
)

echo.
if %ERRORLEVEL% neq 0 (
    echo [x] Process failed with exit code %ERRORLEVEL%.
) else (
    echo [OK] Done.
)

pause