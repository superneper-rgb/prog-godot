@echo off
rem Open PROG in the Godot editor. F5 runs the game.
cd /d "%~dp0"
call "%~dp0find_godot.bat" || exit /b 1
start "" "%GODOT%" --path . --editor
