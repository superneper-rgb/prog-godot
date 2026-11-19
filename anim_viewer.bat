@echo off
rem PROG animation viewer: every character, move and weapon on one stage (tools/anim_viewer). Not the game.
cd /d "%~dp0"
call "%~dp0find_godot.bat" || exit /b 1
start "" "%GODOT%" --path . -- --anim-viewer
