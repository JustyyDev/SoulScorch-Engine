@echo off
rem stage_fmod_after_build.bat - helper to auto-copy FMOD runtime and NDLL into engine bin
if "%FMOD_SDK%"=="" (
  echo ERROR: FMOD_SDK not set. Set FMOD_SDK to your FMOD Studio SDK root.
  exit /b 1
)

set SCRIPT_DIR=%~dp0
set LINC_FMOD_DIR=%SCRIPT_DIR%..\.haxelib\linc_fmod
if not exist "%LINC_FMOD_DIR%" (
  echo WARNING: expected %LINC_FMOD_DIR% not found. Adjust path.
)

echo Invoking linc_fmod installer...
call "%LINC_FMOD_DIR%\install_windows_runtime.bat"

echo staging complete.
exit /b 0
