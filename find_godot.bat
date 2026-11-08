@echo off
rem Finds Godot 4.7.2 and puts its path in GODOT. Order: GODOT already set, godot.path file next to this script, PATH, common folders.
if defined GODOT if exist "%GODOT%" exit /b 0
if exist "%~dp0godot.path" set /p GODOT=<"%~dp0godot.path"
if defined GODOT if exist "%GODOT%" exit /b 0
set "GODOT="
for %%G in (Godot_v4.7.2-stable_win64.exe godot.exe) do if not defined GODOT for %%P in (%%G) do if not "%%~$PATH:P"=="" set "GODOT=%%~$PATH:P"
if defined GODOT exit /b 0
for %%D in ("F:\godot" "C:\godot" "%USERPROFILE%\Desktop" "%USERPROFILE%\Downloads" "%ProgramFiles%\Godot" "%LOCALAPPDATA%\Godot") do if not defined GODOT if exist "%%~D\Godot_v4.7.2-stable_win64.exe" set "GODOT=%%~D\Godot_v4.7.2-stable_win64.exe"
if defined GODOT exit /b 0
echo Could not find Godot 4.7.2.
echo Put the full path to Godot_v4.7.2-stable_win64.exe in a file called godot.path next to run.bat, then try again.
pause
exit /b 1
