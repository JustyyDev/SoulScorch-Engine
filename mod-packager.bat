@echo off
setlocal enabledelayedexpansion

title SoulScorch Engine - Universal Standalone Mod Packager
color 0b

cd /d "%~dp0"
set "ROOT_DIR=%~dp0"
set "TOOLS_DIR=%ROOT_DIR%.tools"

set "HAXE_DIR=%TOOLS_DIR%\haxe"
set "NEKO_DIR=%TOOLS_DIR%\neko"
set "HAXELIB_DIR=%ROOT_DIR%.haxelib"

if not exist "%HAXELIB_DIR%" set "HAXELIB_DIR=%TOOLS_DIR%\haxelib"
if not exist "%HAXE_DIR%\haxe.exe" if exist "%TOOLS_DIR%\haxe.exe" set "HAXE_DIR=%TOOLS_DIR%"
if not exist "%NEKO_DIR%\neko.exe" if exist "%TOOLS_DIR%\neko.exe" set "NEKO_DIR=%TOOLS_DIR%"

if exist "%HAXE_DIR%\haxelib.exe" (
    set "PATH=%HAXE_DIR%;%NEKO_DIR%;%PATH%"
    set "HAXELIB_CMD=%HAXE_DIR%\haxelib.exe"
) else (
    set "HAXELIB_CMD=haxelib"
)

if exist "%HAXELIB_DIR%" set "HAXELIB_PATH=%HAXELIB_DIR%"

echo ================================================================
echo           SOULSCORCH ENGINE // UNIVERSAL MOD PACKAGER
echo ================================================================
echo.

set "MODS_ROOT="
for %%R in ("mods" "bin\windows\bin\mods" "bin\linux\bin\mods" "bin\macos\bin\mods" "bin\hl\bin\mods") do (
    if not defined MODS_ROOT call :TRY_MOD_ROOT "%%~R"
)

if not defined MODS_ROOT (
    echo [ERROR] No mod folders found in known roots.
    echo         Checked: mods, bin\windows\bin\mods, bin\linux\bin\mods, bin\macos\bin\mods, bin\hl\bin\mods
    pause
    exit /b 1
)

set /a MOD_COUNT=0

echo Available Mods in Repository:
echo ----------------------------------------------------------------
for /d %%D in ("%MODS_ROOT%\*") do (
    echo   - %%~nxD
    set /a MOD_COUNT+=1
)
echo ----------------------------------------------------------------
echo.

if %MOD_COUNT%==0 (
    echo [ERROR] No mod subfolders found in: %MODS_ROOT%
    pause
    exit /b 1
)

set /p MOD_NAME="Enter the target mod folder name to package: "
call :TRIM_VAR MOD_NAME

if "%MOD_NAME%"=="" (
    echo.
    echo [ERROR] No mod name entered.
    pause
    exit /b 1
)

if not exist "%MODS_ROOT%\%MOD_NAME%" (
    echo.
    echo [ERROR] Mod directory '%MODS_ROOT%\%MOD_NAME%' does not exist!
    pause
    exit /b 1
)

:: Inspect the selected mod for custom default noteskins or fallback to default
set "DEFAULT_SKIN=default"
call :DETECT_SKIN "%MODS_ROOT%\%MOD_NAME%\data\noteskins"
if /I "%DEFAULT_SKIN%"=="default" call :DETECT_SKIN "%MODS_ROOT%\%MOD_NAME%\data\config\noteskins"

echo.
echo [*] Detected Mod ID: %MOD_NAME%
echo [*] Detected Target Skin: %DEFAULT_SKIN%
echo [*] Mod Source Root: %MODS_ROOT%
echo.
echo Select Target Compiler:
echo   [1] Windows 64-Bit Native (C++/MSVC - Optimized Release)
echo   [2] HashLink 64-Bit (Fast JIT Export)
set /p TARGET_CHOICE="Enter 1 or 2 [Default: 1]: "
call :TRIM_VAR TARGET_CHOICE

if "%TARGET_CHOICE%"=="2" (
    set "TARGET_NAME=HashLink"
    set "BUILD_ARGS=hl -release"
    set "BIN_PRIMARY=bin\hl\bin"
    set "BIN_FALLBACK=export\release\hl\bin"
    set "IS_HL=1"
) else (
    set "TARGET_NAME=Windows"
    set "BUILD_ARGS=windows -release"
    set "BIN_PRIMARY=bin\windows\bin"
    set "BIN_FALLBACK=export\release\windows\bin"
    set "IS_HL=0"
)

set "DIST_DIR=export\standalone_%MOD_NAME%"

echo.
echo [*] Compiling Engine Binaries...
call "%HAXELIB_CMD%" run lime build %BUILD_ARGS%
if errorlevel 1 (
    echo.
    echo [ERROR] Compilation failed with code %ERRORLEVEL%.
    pause
    exit /b %ERRORLEVEL%
)

set "BIN_DIR=%BIN_PRIMARY%"
if not exist "%BIN_DIR%" if exist "%BIN_FALLBACK%" set "BIN_DIR=%BIN_FALLBACK%"

if not exist "%BIN_DIR%" (
    echo.
    echo [ERROR] Build output directory not found: %BIN_DIR%
    pause
    exit /b 1
)

echo.
echo [*] Assembling Clean Standalone Distribution: '%DIST_DIR%'...

if exist "%DIST_DIR%" rd /s /q "%DIST_DIR%"
mkdir "%DIST_DIR%"
if errorlevel 1 (
    echo [ERROR] Failed to create distribution directory: %DIST_DIR%
    pause
    exit /b 1
)

if "%IS_HL%"=="0" (
    echo  - Bundling Engine Executable ^& Dynamic Libraries...
    set "GAME_EXE="
    for %%E in ("%BIN_DIR%\SoulScorch*.exe") do (
        if exist "%%~fE" if /I not "%%~nxE"=="hl.exe" set "GAME_EXE=%%~fE"
    )
    if not defined GAME_EXE (
        for %%E in ("%BIN_DIR%\*.exe") do (
            if exist "%%~fE" if /I not "%%~nxE"=="hl.exe" set "GAME_EXE=%%~fE"
        )
    )

    if not defined GAME_EXE (
        echo.
        echo [ERROR] Could not find built game executable in %BIN_DIR%
        pause
        exit /b 1
    )

    copy /Y "%GAME_EXE%" "%DIST_DIR%\%MOD_NAME%.exe" >nul
    if errorlevel 1 (
        echo [ERROR] Failed to copy executable to distribution folder.
        pause
        exit /b 1
    )
    xcopy /Y /Q "%BIN_DIR%\*.dll" "%DIST_DIR%\" >nul 2>&1
    xcopy /Y /Q "%BIN_DIR%\*.hdll" "%DIST_DIR%\" >nul 2>&1
    xcopy /Y /Q "%BIN_DIR%\*.ndll" "%DIST_DIR%\" >nul 2>&1
) else (
    echo  - Bundling HashLink Runtime ^& Bytecode...
    set "HL_FILE="
    set "HL_FILE_NAME="
    for %%H in ("%BIN_DIR%\*.hl") do (
        if exist "%%~fH" (
            set "HL_FILE=%%~fH"
            set "HL_FILE_NAME=%%~nxH"
        )
    )

    if not defined HL_FILE (
        echo.
        echo [ERROR] No .hl bytecode file found in %BIN_DIR%
        pause
        exit /b 1
    )

    copy /Y "%HL_FILE%" "%DIST_DIR%\%HL_FILE_NAME%" >nul
    if errorlevel 1 (
        echo [ERROR] Failed to copy HashLink bytecode file to distribution folder.
        pause
        exit /b 1
    )

    set "HL_EXE_SOURCE="
    if exist "%BIN_DIR%\hl.exe" set "HL_EXE_SOURCE=%BIN_DIR%\hl.exe"
    if not defined HL_EXE_SOURCE if exist "%TOOLS_DIR%\hashlink\hl.exe" set "HL_EXE_SOURCE=%TOOLS_DIR%\hashlink\hl.exe"

    if not defined HL_EXE_SOURCE (
        for /f "delims=" %%P in ('where hl 2^>nul') do (
            if not defined HL_EXE_SOURCE set "HL_EXE_SOURCE=%%P"
        )
    )

    if defined HL_EXE_SOURCE (
        copy /Y "%HL_EXE_SOURCE%" "%DIST_DIR%\hl.exe" >nul
    ) else (
        echo [!] Could not locate hl.exe automatically. The package will require HashLink in PATH.
    )

    (
        echo @echo off
        echo cd /d "%%~dp0"
        if defined HL_EXE_SOURCE (
            echo .\hl.exe "%HL_FILE_NAME%"
        ) else (
            echo hl "%HL_FILE_NAME%"
        )
        echo pause
    ) > "%DIST_DIR%\run_%MOD_NAME%_hl.bat"
)

echo  - Bundling Core Engine Preload Assets (Fonts, Shaders, Fallbacks)...
if exist "assets\preload\fonts" xcopy /E /I /Y "assets\preload\fonts" "%DIST_DIR%\assets\preload\fonts" >nul
if exist "assets\preload\sounds" xcopy /E /I /Y "assets\preload\sounds" "%DIST_DIR%\assets\preload\sounds" >nul
if exist "assets\preload\music" xcopy /E /I /Y "assets\preload\music" "%DIST_DIR%\assets\preload\music" >nul
if exist "assets\preload\images\ui" xcopy /E /I /Y "assets\preload\images\ui" "%DIST_DIR%\assets\preload\images\ui" >nul
if exist "assets\preload\shaders" xcopy /E /I /Y "assets\preload\shaders" "%DIST_DIR%\assets\preload\shaders" >nul

echo  - Packaging Mod '%MOD_NAME%'...
xcopy /E /I /Y "%MODS_ROOT%\%MOD_NAME%" "%DIST_DIR%\mods\%MOD_NAME%" >nul
if errorlevel 1 (
    echo [ERROR] Failed to package mod folder: %MODS_ROOT%\%MOD_NAME%
    pause
    exit /b 1
)

echo  - Writing Dynamic Standalone Boot Configuration...
(
echo [Engine]
echo standaloneMod=%MOD_NAME%
echo defaultNoteSkin=%DEFAULT_SKIN%
echo autoLoadMod=true
echo isStandalone=true
echo target=%TARGET_NAME%
) > "%DIST_DIR%\engine.cfg"

echo.
echo ================================================================
echo [SUCCESS] Standalone Application Packaged Successfully!
echo   -> Location: %DIST_DIR%\
if "%IS_HL%"=="0" (
    echo   -> Executable: %DIST_DIR%\%MOD_NAME%.exe
) else (
    echo   -> Launcher: %DIST_DIR%\run_%MOD_NAME%_hl.bat
)
echo ================================================================
echo.
pause
exit /b 0

:DETECT_SKIN
set "SKIN_DIR=%~1"
if not exist "%SKIN_DIR%" goto :eof

for %%F in ("%SKIN_DIR%\*.xmsoul") do (
    if exist "%%~fF" (
        set "DEFAULT_SKIN=%%~nF"
        goto :eof
    )
)

for %%F in ("%SKIN_DIR%\*.xml") do (
    if exist "%%~fF" (
        set "DEFAULT_SKIN=%%~nF"
        goto :eof
    )
)

goto :eof

:TRY_MOD_ROOT
set "CANDIDATE=%~1"
if not exist "%CANDIDATE%" goto :eof
for /d %%D in ("%CANDIDATE%\*") do (
    set "MODS_ROOT=%CANDIDATE%"
    goto :eof
)
goto :eof

:TRIM_VAR
set "_TV=!%~1!"
if not defined _TV goto :eof
for /f "tokens=* delims= " %%A in ("!_TV!") do set "_TV=%%A"
:TRIM_VAR_TAIL
if "!_TV:~-1!"==" " (
    set "_TV=!_TV:~0,-1!"
    goto :TRIM_VAR_TAIL
)
set "%~1=!_TV!"
set "_TV="
goto :eof