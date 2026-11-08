extends KitLevel
## BLOCKOUT DEMO (JS levels/blockout-demo/level.js): the kit's own small test level: a walk, a climb, a lever and an ambush.


func kit_options() -> Dictionary:
	return {"id": "blockout-demo", "name": "BLOCKOUT DEMO", "spawn": {"x": 0.0, "y": 1.0, "z": 0.0, "yaw": 0.0}}


func setup() -> void:
	bo.stage({"id": "approach", "name": "Approach", "spawn": {"x": 0.0, "y": 1.0, "z": 0.0, "yaw": 0.0}, "task": "Get to the high deck.",
		"objectives": [
			{"id": "walk", "label": "Walk to the step", "text": "Walk to the first step.", "at": [0, 3, 12], "radius": 3.0},
			{"id": "climb", "label": "Climb the ramp", "text": "Climb the ramp.", "at": [0, 6, 28], "radius": 3.0, "via": [[0, 3, 20]]},
		]})
	bo.stage({"id": "deck", "name": "High deck", "task": "Secure the deck.",
		"objectives": [
			{"id": "lever", "label": "Throw lever", "text": "Hold E at the lever.", "kind": "hold", "at": [-3, 6, 30], "prompt": "THROW LEVER"},
			{"id": "ambush", "label": "Ambush", "text": "Defeat the guards.", "spawns": [{"x": 0.0, "y": 6.0, "z": 31.0}, {"x": 3.0, "y": 6.0, "z": 29.0}]},
		]})
