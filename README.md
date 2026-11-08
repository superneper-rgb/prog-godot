# PROG (Godot)

## First-time setup

1. **Install Git LFS.** GitHub Desktop already includes it. With command-line git, install it from https://git-lfs.com and run `git lfs install` once.
2. **Get Godot 4.7.2** (the standard Windows build, not .NET): https://godotengine.org/download/archive/ . Use this exact version.
3. **Clone this repo.** It's about 1 GB because of the levels, sounds and textures, which come down through LFS.
   Check: `assets/levels/hub/scene.glb` should be about 110 MB. If it's a tiny text file, LFS wasn't installed when you cloned. Run `git lfs pull` to fix it.
4. **Open the project.** Double-click `edit.bat` (editor) or `run.bat` (play).
   If it says it can't find Godot, make a file called `godot.path` next to `run.bat` that contains just the full path to `Godot_v4.7.2-stable_win64.exe`.
   The first open imports every asset and takes several minutes. That's normal and only happens once.

## Playing

- `run.bat` starts at the main menu.
- `run.bat <level id> [prog|tommy]` jumps straight to a level, e.g. `run.bat warehouse tommy`.
- In the editor, F5 runs the game.

## Working together

- Pull before you start, and commit and push when you're done.
- Two people editing the same level or the same `.glb` at once can't be merged, so say who's working on what.
- Never commit `.godot/`; it's your own import cache (already ignored).
