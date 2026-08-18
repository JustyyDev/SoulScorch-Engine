@echo off
setlocal EnableDelayedExpansion
title SoulScorch Engine - Portable Non-Admin Setup

echo =========================================================
echo   SoulScorch Engine - Portable Environment Installer
echo =========================================================
echo.

set "TOOLS_DIR=%~dp0.tools"
set "HAXE_DIR=%TOOLS_DIR%\haxe"
set "NEKO_DIR=%TOOLS_DIR%\neko"
set "LIB_DIR=%TOOLS_DIR%\haxelib"

if not exist "%TOOLS_DIR%" mkdir "%TOOLS_DIR%"
if not exist "%LIB_DIR%" mkdir "%LIB_DIR%"

:: 1. Download & Extract Neko 2.3.0 (Portable)
if not exist "%NEKO_DIR%\neko.exe" (
    echo [*] Downloading portable Neko 2.3.0...
    powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; (New-Object System.Net.WebClient).DownloadFile('https://github.com/HaxeFoundation/neko/releases/download/v2-3-0/neko-2.3.0-win64.zip', '%TOOLS_DIR%\neko.zip')"
    echo [*] Extracting Neko...
    powershell -Command "Expand-Archive -Path '%TOOLS_DIR%\neko.zip' -DestinationPath '%TOOLS_DIR%' -Force"
    ren "%TOOLS_DIR%\neko-2.3.0-win64" "neko"
    del /f /q "%TOOLS_DIR%\neko.zip"
)

:: 2. Download & Extract Haxe 4.3.4 (Portable)
if not exist "%HAXE_DIR%\haxe.exe" (
    echo [*] Downloading portable Haxe 4.3.4...
    powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; (New-Object System.Net.WebClient).DownloadFile('https://github.com/HaxeFoundation/haxe/releases/download/4.3.4/haxe-4.3.4-win64.zip', '%TOOLS_DIR%\haxe.zip')"
    echo [*] Extracting Haxe...
    powershell -Command "Expand-Archive -Path '%TOOLS_DIR%\haxe.zip' -DestinationPath '%TOOLS_DIR%' -Force"
    ren "%TOOLS_DIR%\haxe-4.3.4-win64" "haxe"
    del /f /q "%TOOLS_DIR%\haxe.zip"
)

:: 3. Configure Local Session Environment
set "PATH=%HAXE_DIR%;%NEKO_DIR%;%PATH%"
set "HAXEPATH=%HAXE_DIR%"
set "NEKOPATH=%NEKO_DIR%"

echo.
echo [*] Pointing haxelib to portable local folder: "%LIB_DIR%"...
"%HAXE_DIR%\haxelib.exe" setup "%LIB_DIR%"

:: 4. Install All Necessary Haxe Addons / Libraries
echo.
echo =========================================================
echo   Installing Engine Libraries
echo =========================================================
echo.

"%HAXE_DIR%\haxelib.exe" install lime 8.1.3 --always --quiet
"%HAXE_DIR%\haxelib.exe" install openfl 9.3.3 --always --quiet
"%HAXE_DIR%\haxelib.exe" install flixel 5.6.1 --always --quiet
"%HAXE_DIR%\haxelib.exe" install flixel-addons 3.2.3 --always --quiet
"%HAXE_DIR%\haxelib.exe" install flixel-ui 2.6.1 --always --quiet
"%HAXE_DIR%\haxelib.exe" install hscript 2.4.0 --always
"%HAXE_DIR%\haxelib.exe" set hscript 2.4.0
"%HAXE_DIR%\haxelib.exe" install hscript-iris 1.1.0 --always --quiet
"%HAXE_DIR%\haxelib.exe" install away3d --always --quiet

:: Optional C++ / native dependencies if Git is available
echo [*] Checking optional git dependencies...
"%HAXE_DIR%\haxelib.exe" git linc_luajit https://github.com/AndreiRudenko/linc_luajit.git --always --quiet >nul 2>&1
"%HAXE_DIR%\haxelib.exe" git hxdiscord_rpc https://github.com/MAJESTFormat/hxdiscord_rpc.git --always --quiet >nul 2>&1

echo.
echo =========================================================
echo [OK] Portable Haxe environment ready!
echo =========================================================
pause