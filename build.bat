@echo off
setlocal EnableDelayedExpansion
title SoulScorch Engine - Build & Compilation Suite
color 0b

:: 1. Force Working Directory & Locate Environment
cd /d "%~dp0"
set "ROOT_DIR=%~dp0"
set "TOOLS_DIR=%ROOT_DIR%.tools"

set "HAXE_DIR=%TOOLS_DIR%\haxe"
set "NEKO_DIR=%TOOLS_DIR%\neko"
set "MINGW_DIR=%TOOLS_DIR%\mingw\bin"
set "HAXELIB_DIR=%ROOT_DIR%.haxelib"
if not exist "%HAXELIB_DIR%" set "HAXELIB_DIR=%TOOLS_DIR%\haxelib"

:: Fallback if tools are installed locally in .tools root
if not exist "%HAXE_DIR%\haxe.exe" if exist "%TOOLS_DIR%\haxe.exe" set "HAXE_DIR=%TOOLS_DIR%"
if not exist "%NEKO_DIR%\neko.exe" if exist "%TOOLS_DIR%\neko.exe" set "NEKO_DIR=%TOOLS_DIR%"

if exist "%HAXE_DIR%\haxe.exe" (
    set "PATH=%HAXE_DIR%;%NEKO_DIR%;%PATH%"
    set "HAXEPATH=%HAXE_DIR%"
    set "NEKOPATH=%NEKO_DIR%"
    set "HAXE_STD_PATH=%HAXE_DIR%\std"
    set "HAXELIB_CMD=%HAXE_DIR%\haxelib.exe"
) else (
    set "HAXELIB_CMD=haxelib"
)

if exist "%MINGW_DIR%" set "PATH=%MINGW_DIR%;%PATH%"
if exist "%HAXELIB_DIR%" set "HAXELIB_PATH=%HAXELIB_DIR%"

:: 2. Multithreaded Core Optimization
if defined NUMBER_OF_PROCESSORS (
    set "HXCPP_COMPILE_THREADS=%NUMBER_OF_PROCESSORS%"
) else (
    set "HXCPP_COMPILE_THREADS=8"
)

:: 3. Clear Broken HXCPP Config Cache
if exist "%USERPROFILE%\.hxcpp_config.xml" del /f /q "%USERPROFILE%\.hxcpp_config.xml" >nul 2>&1

:: 4. Auto-Detect 64-Bit MSVC Toolchain
if not defined VSCMD_VER (
    set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
    if exist "!VSWHERE!" (
        for /f "usebackq tokens=*" %%i in (`"!VSWHERE!" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do (
            set "VS_PATH=%%i"
        )
        if exist "!VS_PATH!\VC\Auxiliary\Build\vcvars64.bat" (
            call "!VS_PATH!\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1
        )
    )
)

:MENU
cls
echo ==============================================================================
echo                      SOULSCORCH ENGINE // BUILD MATRIX                         
echo ==============================================================================
echo.
echo   [1] Windows C++ (Release x64 - Standard Optimized Game)
echo   [2] Windows C++ (Debug Mode - Full Trace & Visual Debugger)
echo   [3] Windows C++ (MinGW GCC 64-Bit Alternate Toolchain)
echo   [4] Windows C++ (32-Bit x86 Compatibility Mode)
echo   [5] Fast Neko VM Test (Instant Logic & UI Sandbox)
echo   [6] Fast CPPIA Test (Bytecode Script Host)
echo   [7] Deep Cache Purge & Full Rebuild (Clears locks, bin & caches)
echo   [8] Install / Repair Engine Haxelib Dependencies
echo   [9] Exit
echo.
echo ==============================================================================
set /p choice="Enter option number [1-9] (Default: 1): "

if "%choice%"=="" goto BUILD_RELEASE
if "%choice%"=="1" goto BUILD_RELEASE
if "%choice%"=="2" goto BUILD_DEBUG
if "%choice%"=="3" goto BUILD_MINGW
if "%choice%"=="4" goto BUILD_X86
if "%choice%"=="5" goto BUILD_NEKO
if "%choice%"=="6" goto BUILD_CPPIA
if "%choice%"=="7" goto DEEP_CLEAN
if "%choice%"=="8" goto SETUP_LIBS
if "%choice%"=="9" exit /b 0

echo Invalid selection.
timeout /t 1 >nul
goto MENU

:BUILD_RELEASE
cls
echo [*] Compiling Windows C++ 64-Bit Release Build...
echo [*] Worker Threads: %HXCPP_COMPILE_THREADS%
"%HAXELIB_CMD%" run lime test windows -release -DHXCPP_NO_PCH -64
goto BUILD_END

:BUILD_DEBUG
cls
echo [*] Compiling Windows C++ 64-Bit Debug Build...
"%HAXELIB_CMD%" run lime test windows -debug -DHXCPP_STACK_LINE -DHXCPP_CHECK_POINTER -DHXCPP_NO_PCH -64
goto BUILD_END

:BUILD_MINGW
cls
echo [*] Compiling Windows 64-Bit with MinGW GCC...
"%HAXELIB_CMD%" run lime test windows -release -DHXCPP_MINGW -DHXCPP_NO_PCH -64
goto BUILD_END

:BUILD_X86
cls
echo [*] Compiling Windows 32-Bit (x86 Release)...
"%HAXELIB_CMD%" run lime test windows -release -DHXCPP_NO_PCH -32
goto BUILD_END

:BUILD_NEKO
cls
echo [*] Running Neko Bytecode Test...
"%HAXELIB_CMD%" run lime test windows -neko
goto BUILD_END

:BUILD_CPPIA
cls
echo [*] Running CPPIA Host Test...
"%HAXELIB_CMD%" run lime test windows -cppia
goto BUILD_END

:DEEP_CLEAN
cls
echo [*] Killing active game processes...
taskkill /F /IM SoulScorch.exe /T >nul 2>&1
taskkill /F /IM SoulScorch-debug.exe /T >nul 2>&1

echo [*] Purging build directories and config locks...
if exist "export" rd /s /q "export" >nul 2>&1
if exist "bin" rd /s /q "bin" >nul 2>&1
if exist "C:\hxcpp_cache" rd /s /q "C:\hxcpp_cache" >nul 2>&1
if exist "%USERPROFILE%\.hxcpp" rd /s /q "%USERPROFILE%\.hxcpp" >nul 2>&1
if exist "%USERPROFILE%\.hxcpp_config.xml" del /f /q "%USERPROFILE%\.hxcpp_config.xml" >nul 2>&1

echo [*] Starting fresh multithreaded rebuild...
"%HAXELIB_CMD%" run lime test windows -release -DHXCPP_NO_PCH -64
goto BUILD_END

:SETUP_LIBS
cls
echo [*] Installing and syncing required libraries...
if not exist "%HAXELIB_DIR%" mkdir "%HAXELIB_DIR%"
"%HAXELIB_CMD%" setup "%HAXELIB_DIR%"
"%HAXELIB_CMD%" install lime 8.1.3 --always --skip-dependencies
"%HAXELIB_CMD%" install openfl 9.3.3 --always --skip-dependencies
"%HAXELIB_CMD%" install flixel 5.6.2 --always --skip-dependencies
"%HAXELIB_CMD%" install flixel-addons 3.2.3 --always --skip-dependencies
"%HAXELIB_CMD%" install flixel-ui 2.6.1 --always --skip-dependencies
"%HAXELIB_CMD%" install hscript 2.5.0 --always
"%HAXELIB_CMD%" set hscript 2.5.0
"%HAXELIB_CMD%" install hscript-iris 1.1.0 --always
"%HAXELIB_CMD%" install away3d --always
"%HAXELIB_CMD%" install hxcpp 4.3.2 --always
"%HAXELIB_CMD%" git linc_luajit https://github.com/AndreiRudenko/linc_luajit.git --always
"%HAXELIB_CMD%" git hxdiscord_rpc https://github.com/MAJigsaw77/hxdiscord_rpc --always
"%HAXELIB_CMD%" run lime setup -y
goto BUILD_END

:BUILD_END
echo.
if %ERRORLEVEL% neq 0 (
    color 0c
    echo [X] Build process exited with error code %ERRORLEVEL%.
) else (
    color 0a
    echo [OK] Build pipeline completed successfully.
)
echo.
pause
goto MENU