@echo off
rem Play PROG (Godot build). Optional: run.bat <level id> [prog^|tommy]   e.g. run.bat warehouse tommy
cd /d "%~dp0"
call "%~dp0find_godot.bat" || exit /b 1
if "%~1"=="" (
  start "" "%GODOT%" --path .
) else (
  start "" "%GODOT%" --path . -- --level=%1 --char=%2
)
