extends Node3D
## The root scene: hands itself to Game, which runs everything else. With `-- --anim-viewer` (anim_viewer.bat) it holds the animation viewer (tools/anim_viewer) instead and Game stays idle.


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--anim-viewer" or a == "--level=anim-viewer":      # (the second form is what `node tools/peek.mjs start anim-viewer` passes)
			add_child((load("res://tools/anim_viewer/anim_viewer.gd") as GDScript).new())      # (by path: the game itself never loads it)
			return
	Game.boot(self)
