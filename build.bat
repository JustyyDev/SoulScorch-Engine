@echo off
setlocal enabledelayedexpansion
title SoulScorch Fast Builder

:: Set environment variables for multi-threading and caching
if not defined HXCPP_COMPILE_CACHE (
    set "HXCPP_COMPILE_CACHE=%USERPROFILE%\.hxcpp_cache"
)
if not exist "%HXCPP_COMPILE_CACHE%" mkdir "%HXCPP_COMPILE_CACHE%"

:: Force kill lingering game processes to prevent 'Permission Denied' linker locks
taskkill /F /IM SoulScorch.exe >nul 2>&1

echo ======================================================
echo  SOULSCORCH ENGINE FAST COMPILER
echo  Threads: %NUMBER_OF_PROCESSORS% ^| Cache: %HXCPP_COMPILE_CACHE%
echo ======================================================

:: Check if the compilation server is actively listening on port 6000
netstat -ano | findstr /R /C:":6000 " >nul 2>&1
if errorlevel 1 (
    echo [*] Starting background Haxe Compilation Server on port 6000...
    start /B haxe --wait 6000
    timeout /t 1 /nobreak >nul
)

:: Set core compiler definitions
set "TARGET=windows"
set "FLAGS=-DHXCPP_COMPILE_THREADS=%NUMBER_OF_PROCESSORS%"

:: Handle CLI arguments or prompt if launched directly
set "MODE=%~1"
if "%MODE%"=="" (
    echo [1] Release Build (Standard)
    echo [2] Debug Build (Traces + Callstack)
    echo [3] Clean and Full Rebuild
    echo.
    set /p CHOICE="Select build mode [1-3] (Default: 1): "
    if "!CHOICE!"=="2" set "MODE=debug"
    if "!CHOICE!"=="3" set "MODE=clean"
)

if "%MODE%"=="clean" (
    echo [*] Purging previous build artifacts...
    if exist "bin\windows" rd /s /q "bin\windows"
    echo [*] Clean complete. Starting full rebuild...
    lime test %TARGET% %FLAGS%
    goto end
)

if "%MODE%"=="debug" (
    echo [*] Compiling in DEBUG mode...
    lime test %TARGET% -debug %FLAGS%
    goto end
)

echo [*] Compiling in RELEASE mode...
lime test %TARGET% %FLAGS%

:end
if errorlevel 1 (
    echo.
    echo [x] BUILD FAILED! Check the compiler errors above.
) else (
    echo.
    echo [*] Build finished successfully.
)

pause