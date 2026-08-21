@echo off
setlocal enabledelayedexpansion

title SoulScorch Engine - Universal Standalone Mod Packager
color 0b

echo ================================================================
echo           SOULSCORCH ENGINE // UNIVERSAL MOD PACKAGER
echo ================================================================
echo.

if not exist "mods" (
    echo [ERROR] No 'mods/' directory found in root repository!
    pause
    exit /b
)

echo Available Mods in Repository:
echo ----------------------------------------------------------------
for /d %%D in (mods\*) do (
    echo   - %%~nxD
)
echo ----------------------------------------------------------------
echo.

set /p MOD_NAME="Enter the target mod folder name to package: "

if not exist "mods\%MOD_NAME%" (
    echo.
    echo [ERROR] Mod directory 'mods\%MOD_NAME%' does not exist!
    pause
    exit /b
)

:: Inspect the selected mod for custom default noteskins or fallback to default
set DEFAULT_SKIN=default
if exist "mods\%MOD_NAME%\data\noteskins" (
    for %%F in ("mods\%MOD_NAME%\data\noteskins\*.xmsoul" "mods\%MOD_NAME%\data\noteskins\*.xml") do (
        set DEFAULT_SKIN=%%~nF
    )
)
if exist "mods\%MOD_NAME%\data\config\noteskins" (
    for %%F in ("mods\%MOD_NAME%\data\config\noteskins\*.xmsoul" "mods\%MOD_NAME%\data\config\noteskins\*.xml") do (
        set DEFAULT_SKIN=%%~nF
    )
)

echo.
echo [*] Detected Mod ID: %MOD_NAME%
echo [*] Detected Target Skin: %DEFAULT_SKIN%
echo.
echo Select Target Compiler:
echo   [1] Windows 64-Bit Native (C++/MSVC - Optimized Release)
echo   [2] HashLink 64-Bit (Fast JIT Export)
set /p TARGET_CHOICE="Enter 1 or 2 [Default: 1]: "

if "%TARGET_CHOICE%"=="2" (
    set BUILD_CMD=haxelib run lime build hl -release -DHXCPP_NO_PCH
    set BIN_DIR=bin\hl\bin
    set EXE_FILE=SoulScorchEngine.exe
) else (
    set BUILD_CMD=haxelib run lime build windows -release -DHXCPP_NO_PCH
    set BIN_DIR=bin\windows\bin
    set EXE_FILE=SoulScorchEngine.exe
)

set DIST_DIR=export\standalone_%MOD_NAME%

echo.
echo [*] Compiling Engine Binaries...
call %BUILD_CMD%

if not exist "%BIN_DIR%\%EXE_FILE%" (
    echo.
    echo [ERROR] Compilation failed. Please check compiler output above.
    pause
    exit /b
)

echo.
echo [*] Assembling Clean Standalone Distribution: '%DIST_DIR%'...

if exist "%DIST_DIR%" rd /s /q "%DIST_DIR%"
mkdir "%DIST_DIR%"

echo  - Bundling Engine Executable & Dynamic Libraries...
copy /Y "%BIN_DIR%\%EXE_FILE%" "%DIST_DIR%\%MOD_NAME%.exe" >nul
xcopy /E /I /Y "%BIN_DIR%\*.dll" "%DIST_DIR%\" >nul 2>&1
xcopy /E /I /Y "%BIN_DIR%\*.hdll" "%DIST_DIR%\" >nul 2>&1

echo  - Bundling Core Engine Preload Assets (Fonts, Shaders, Fallbacks)...
if exist "assets\preload\fonts" xcopy /E /I /Y "assets\preload\fonts" "%DIST_DIR%\assets\preload\fonts" >nul
if exist "assets\preload\sounds" xcopy /E /I /Y "assets\preload\sounds" "%DIST_DIR%\assets\preload\sounds" >nul
if exist "assets\preload\music" xcopy /E /I /Y "assets\preload\music" "%DIST_DIR%\assets\preload\music" >nul
if exist "assets\preload\images\ui" xcopy /E /I /Y "assets\preload\images\ui" "%DIST_DIR%\assets\preload\images\ui" >nul
if exist "assets\preload\shaders" xcopy /E /I /Y "assets\preload\shaders" "%DIST_DIR%\assets\preload\shaders" >nul

echo  - Packaging Mod '%MOD_NAME%'...
xcopy /E /I /Y "mods\%MOD_NAME%" "%DIST_DIR%\mods\%MOD_NAME%" >nul

echo  - Writing Dynamic Standalone Boot Configuration...
(
echo [Engine]
echo standaloneMod=%MOD_NAME%
echo defaultNoteSkin=%DEFAULT_SKIN%
echo autoLoadMod=true
echo isStandalone=true
) > "%DIST_DIR%\engine.cfg"

echo.
echo ================================================================
echo [SUCCESS] Standalone Application Packaged Successfully!
echo   -> Location: %DIST_DIR%\
echo   -> Executable: %DIST_DIR%\%MOD_NAME%.exe
echo ================================================================
echo.
pause