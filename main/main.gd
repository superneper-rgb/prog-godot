extends Node3D
## The root scene: hands itself to Game, which runs everything else.


func _ready() -> void:
	Game.boot(self)
