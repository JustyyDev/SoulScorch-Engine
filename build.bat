@echo off
setlocal enabledelayedexpansion
title SoulScorch Engine - Master Multi-Platform Build Matrix
color 0b

:: 1. Force Working Directory
cd /d "%~dp0"
set "ROOT_DIR=%~dp0"
set "TOOLS_DIR=%ROOT_DIR%.tools"

:: 2. Redirect Temp & Build Cache (Prevents C: drive memory/space exhaustion)
if not exist "%ROOT_DIR%.build_temp" mkdir "%ROOT_DIR%.build_temp"
set "TEMP=%ROOT_DIR%.build_temp"
set "TMP=%ROOT_DIR%.build_temp"
set "HXCPP_CACHE_DIR=%ROOT_DIR%.build_temp\hxcpp_cache"

:: 3. Local Tooling Paths
set "HAXE_DIR=%TOOLS_DIR%\haxe"
set "NEKO_DIR=%TOOLS_DIR%\neko"
set "HAXELIB_DIR=%ROOT_DIR%.haxelib"
if not exist "%HAXELIB_DIR%" set "HAXELIB_DIR=%TOOLS_DIR%\haxelib"

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

if exist "%HAXELIB_DIR%" set "HAXELIB_PATH=%HAXELIB_DIR%"

:: 4. Locate MinGW GCC Toolchain (Root or Bin)
set "MINGW_BIN="
set "MINGW_BASE="

if exist "%TOOLS_DIR%\mingw\bin\gcc.exe" (
    set "MINGW_BIN=%TOOLS_DIR%\mingw\bin"
    set "MINGW_BASE=%TOOLS_DIR%\mingw"
) else if exist "%TOOLS_DIR%\mingw\gcc.exe" (
    set "MINGW_BIN=%TOOLS_DIR%\mingw"
    set "MINGW_BASE=%TOOLS_DIR%\mingw"
) else if exist "%TOOLS_DIR%\mingw\w64devkit\bin\gcc.exe" (
    set "MINGW_BIN=%TOOLS_DIR%\mingw\w64devkit\bin"
    set "MINGW_BASE=%TOOLS_DIR%\mingw\w64devkit"
)

if defined MINGW_BIN (
    set "PATH=%MINGW_BIN%;%PATH%"
)

:: 5. Multithreaded Core Optimization
if defined NUMBER_OF_PROCESSORS (
    set "HXCPP_COMPILE_THREADS=%NUMBER_OF_PROCESSORS%"
) else (
    set "HXCPP_COMPILE_THREADS=8"
)

:: 6. Locate Visual Studio / MSVC via vswhere or System Probing
set "VCVARS_PATH="
set "VSWHERE_PATH=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"

if exist "%VSWHERE_PATH%" (
    for /f "usebackq tokens=*" %%i in (`"%VSWHERE_PATH%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do (
        if exist "%%i\VC\Auxiliary\Build\vcvars64.bat" (
            set "VCVARS_PATH=%%i\VC\Auxiliary\Build\vcvars64.bat"
        )
    )
)

if not defined VCVARS_PATH (
    for %%D in (C D E F K) do (
        if not defined VCVARS_PATH (
            if exist "%%D:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" set "VCVARS_PATH=%%D:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
            if exist "%%D:\Program Files\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" set "VCVARS_PATH=%%D:\Program Files\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
            if exist "%%D:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvars64.bat" set "VCVARS_PATH=%%D:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvars64.bat"
        )
    )
)

:MENU
cls
echo ==============================================================================
echo                      SOULSCORCH ENGINE // MASTER MATRIX                         
echo ==============================================================================
echo.
echo   --- DESKTOP (WINDOWS & LINUX) ---
echo   [1] Windows C++ (MinGW GCC 64-Bit - Portable / Patched GCC 13 Flags)
echo   [2] Windows C++ (MSVC 64-Bit Release)
echo   [3] Windows C++ (MSVC 64-Bit Debug Mode)
echo   [4] Linux C++ (x64 Native / Release Target)
echo.
echo   --- CONSOLE HOMEBREW & MOBILE ---
echo   [5] Nintendo Switch (Homebrew Target - devkitA64 / libnx)
echo   [6] Android Release Package (APK / ARM64)
echo.
echo   --- WEB & RAPID BYTECODE VM ---
echo   [7] WebGL / HTML5 (Browser Export ^& Local HTTP Server)
echo   [8] Fast HashLink 64-Bit (Instant Bytecode Execution)
echo   [9] Fast CPPIA Host Test (Instant Scripting Sandbox)
echo.
echo   --- UTILITIES & TOOLCHAINS ---
echo   [D] Download / Repair Portable MinGW GCC
echo   [C] Deep Cache Purge ^& Workspace Clean
echo   [S] Install / Synchronize Engine Haxelibs
echo   [0] Exit Engine Suite
echo.
echo ==============================================================================
set /p choice="Select target platform / option: "

if /i "%choice%"=="1" goto BUILD_MINGW
if /i "%choice%"=="2" goto BUILD_MSVC_RELEASE
if /i "%choice%"=="3" goto BUILD_MSVC_DEBUG
if /i "%choice%"=="4" goto BUILD_LINUX
if /i "%choice%"=="5" goto BUILD_SWITCH
if /i "%choice%"=="6" goto BUILD_ANDROID
if /i "%choice%"=="7" goto BUILD_HTML5
if /i "%choice%"=="8" goto BUILD_HASHLINK
if /i "%choice%"=="9" goto BUILD_CPPIA
if /i "%choice%"=="D" goto DOWNLOAD_MINGW
if /i "%choice%"=="C" goto DEEP_CLEAN
if /i "%choice%"=="S" goto SETUP_LIBS
if /i "%choice%"=="0" exit /b 0

goto BUILD_MINGW

:BUILD_MINGW
cls
echo [*] Checking portable MinGW GCC toolchain...
if not defined MINGW_BIN (
    echo [!] MinGW GCC not found in .tools\mingw.
    goto DOWNLOAD_MINGW_INTERNAL
)
:RUN_MINGW_BUILD
echo [*] Configuring HXCPP for MinGW GCC...
set "PATH=%MINGW_BIN%;%PATH%"
set "HXCPP_MINGW=1"
set "MINGW_ROOT=%MINGW_BASE%"

set "MINGW_XML_PATH=%MINGW_BASE:\=/%"
set "MINGW_BIN_XML_PATH=%MINGW_BIN:\=/%"

:: Inject GCC flags to silence strict ANSI warnings and ignore header redeclarations
(
echo ^<xml^>
echo     ^<set name="HXCPP_MINGW" value="1" /^>
echo     ^<set name="MINGW_ROOT" value="%MINGW_XML_PATH%" /^>
echo     ^<setenv name="PATH" value="%MINGW_BIN_XML_PATH%;%%PATH%%" /^>
echo     ^<compiler id="GCC" title="MinGW GCC"^>
echo         ^<flag value="-Wno-cpp" /^>
echo         ^<flag value="-Wno-attributes" /^>
echo         ^<flag value="-Wno-unused-value" /^>
echo         ^<flag value="-Wno-macro-redefined" /^>
echo         ^<flag value="-fpermissive" /^>
echo         ^<flag value="-O2" /^>
echo     ^</compiler^>
echo ^</xml^>
) > "%USERPROFILE%\.hxcpp_config.xml"

echo [*] Compiling Windows 64-Bit with MinGW (Lua + Iris Enabled)...
"%HAXELIB_CMD%" run lime test windows -release -DHXCPP_MINGW -DHXCPP_CPP11 -DSOULSCORCH_LUA
goto BUILD_END

:BUILD_MSVC_RELEASE
cls
echo [*] Compiling Windows 64-Bit Release Build (MSVC - Lua + Iris Enabled)...
if exist "%USERPROFILE%\.hxcpp_config.xml" del /f /q "%USERPROFILE%\.hxcpp_config.xml" >nul 2>&1
if defined VCVARS_PATH call "%VCVARS_PATH%"
"%HAXELIB_CMD%" run lime test windows -release -DSOULSCORCH_LUA
goto BUILD_END

:BUILD_MSVC_DEBUG
cls
echo [*] Compiling Windows 64-Bit Debug Build (MSVC - Lua + Iris Enabled)...
if exist "%USERPROFILE%\.hxcpp_config.xml" del /f /q "%USERPROFILE%\.hxcpp_config.xml" >nul 2>&1
if defined VCVARS_PATH call "%VCVARS_PATH%"
"%HAXELIB_CMD%" run lime test windows -debug -DHXCPP_STACK_LINE -DHXCPP_CHECK_POINTER -DSOULSCORCH_LUA
goto BUILD_END

:BUILD_LINUX
cls
echo [*] Compiling Linux 64-Bit C++ Target (Lua + Iris Enabled)...
"%HAXELIB_CMD%" run lime build linux -release -DSOULSCORCH_LUA
goto BUILD_END

:BUILD_SWITCH
cls
echo [*] Compiling Nintendo Switch Homebrew Target (.nro)...
if not defined DEVKITPRO (
    echo [!] Warning: DEVKITPRO environment variable is not defined.
    echo     Please verify devkitA64 and libnx are installed.
)
"%HAXELIB_CMD%" run lime build switch -release
goto BUILD_END

:BUILD_ANDROID
cls
echo [*] Compiling Android Package (APK)...
if not defined ANDROID_SDK_ROOT if not defined ANDROID_HOME (
    echo [!] Warning: ANDROID_SDK_ROOT or ANDROID_HOME not detected.
)
"%HAXELIB_CMD%" run lime test android -release
goto BUILD_END

:BUILD_HTML5
cls
echo [*] Compiling HTML5 / WebGL target and launching local HTTP server...
"%HAXELIB_CMD%" run lime test html5
goto BUILD_END

:BUILD_HASHLINK
cls
echo [*] Compiling and Launching 64-Bit HashLink...
"%HAXELIB_CMD%" run lime test hl
goto BUILD_END

:BUILD_CPPIA
cls
echo [*] Running CPPIA Bytecode Test Host...
"%HAXELIB_CMD%" run lime test windows -cppia
goto BUILD_END

:DOWNLOAD_MINGW
cls
:DOWNLOAD_MINGW_INTERNAL
echo [*] Downloading standalone MinGW-w64 (w64devkit) to .tools\mingw...
if not exist "%TOOLS_DIR%" mkdir "%TOOLS_DIR%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$zipPath = Join-Path '%TOOLS_DIR%' 'w64devkit.zip'; $target = Join-Path '%TOOLS_DIR%' 'mingw'; Write-Host '[*] Downloading...'; Invoke-WebRequest -Uri 'https://github.com/skeeto/w64devkit/releases/download/v1.20.0/w64devkit-1.20.0.zip' -OutFile $zipPath; Write-Host '[*] Extracting...'; if (Test-Path $target) { Remove-Item -Recurse -Force $target }; Expand-Archive -Path $zipPath -DestinationPath '%TOOLS_DIR%' -Force; Move-Item -Path (Join-Path '%TOOLS_DIR%' 'w64devkit') -Destination $target -Force; Remove-Item -Force $zipPath; Write-Host '[OK] MinGW extracted successfully.'"

if exist "%TOOLS_DIR%\mingw\bin\gcc.exe" (
    set "MINGW_BIN=%TOOLS_DIR%\mingw\bin"
    set "MINGW_BASE=%TOOLS_DIR%\mingw"
) else if exist "%TOOLS_DIR%\mingw\gcc.exe" (
    set "MINGW_BIN=%TOOLS_DIR%\mingw"
    set "MINGW_BASE=%TOOLS_DIR%\mingw"
)

if defined MINGW_BIN (
    echo [OK] MinGW GCC configured at: %MINGW_BIN%
    if "%choice%"=="1" goto RUN_MINGW_BUILD
    if "%choice%"=="" goto RUN_MINGW_BUILD
) else (
    echo [X] Failed to configure MinGW toolchain.
)
pause
goto MENU

:DEEP_CLEAN
cls
echo [*] Terminating running game instances...
taskkill /F /IM SoulScorch.exe /T >nul 2>&1
taskkill /F /IM SoulScorch-debug.exe /T >nul 2>&1

echo [*] Purging build directories and config locks...
if exist "export" rd /s /q "export" >nul 2>&1
if exist "bin" rd /s /q "bin" >nul 2>&1
if exist "%ROOT_DIR%.build_temp" rd /s /q "%ROOT_DIR%.build_temp" >nul 2>&1
if exist "%USERPROFILE%\.hxcpp" rd /s /q "%USERPROFILE%\.hxcpp" >nul 2>&1
if exist "%USERPROFILE%\.hxcpp_config.xml" del /f /q "%USERPROFILE%\.hxcpp_config.xml" >nul 2>&1

echo [OK] All temp caches and exports purged.
pause
goto MENU

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
"%HAXELIB_CMD%" install hscript 2.4.0 --always
"%HAXELIB_CMD%" set hscript 2.4.0
"%HAXELIB_CMD%" install hscript-iris 1.1.0 --always
"%HAXELIB_CMD%" install away3d --always
"%HAXELIB_CMD%" install hxcpp 4.3.2 --always
"%HAXELIB_CMD%" install hashlink --always
"%HAXELIB_CMD%" install linc_fmod --always
"%HAXELIB_CMD%" git linc_luajit https://github.com/JustyyDev/linc_luajit.git --always
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
    echo [OK] Build completed successfully.
)
echo.
pause
goto MENU