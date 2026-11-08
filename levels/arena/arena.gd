extends Level
## The movement test ground (JS buildArena): stairs, ramps, ledge towers, slabs, corridor, crouch tunnel, pillars. Same numbers as the original,
## so golden movement measurements can be compared one to one.

const COL := {
	"floor": Color(0.27, 0.29, 0.31), "wall": Color(0.45, 0.47, 0.5), "stairs": Color(0.55, 0.5, 0.42), "plat": Color(0.4, 0.45, 0.55),
	"ramp": Color(0.5, 0.42, 0.36), "box": Color(0.62, 0.45, 0.25), "tower": Color(0.3, 0.5, 0.42), "slab": Color(0.55, 0.32, 0.45), "tunnel": Color(0.35, 0.33, 0.45),
}


func build() -> void:
	var w := world
	w.add({"kind": "box", "cx": 0.0, "cz": 0.0, "hx": 65.0, "hz": 65.0, "bottom": -10.0, "top": 0.0, "tag": "floor"})
	var P := 65.0
	w.box(0, P + 1, 134, 2, 9, {"tag": "wall"})
	w.box(0, -P - 1, 134, 2, 9, {"tag": "wall"})
	w.box(P + 1, 0, 2, 134, 9, {"tag": "wall"})
	w.box(-P - 1, 0, 2, 134, 9, {"tag": "wall"})
	# staircase A (14 x 0.25) -> platform 3.5
	for i in range(1, 15):
		w.box(-16, 6 + 0.8 * (i - 0.5), 4, 0.8, 0.25 * i, {"tag": "stairs"})
	w.box(-16, 21.2, 8, 8, 3.5, {"tag": "plat"})
	# gentle ramp (rise 3.2 / run 12) + platform
	w.add({"kind": "ramp", "cx": 16.0, "cz": 14.0, "hx": 3.0, "hz": 6.0, "top_low": 0.0, "top": 3.2, "tag": "ramp"})
	w.box(16, 24, 10, 8, 3.2, {"tag": "plat"})
	# steep ramp (rise 4 / run 7.5, ~28deg) + platform
	w.add({"kind": "ramp", "cx": 34.0, "cz": 14.0, "hx": 2.5, "hz": 3.75, "top_low": 0.0, "top": 4.0, "tag": "ramp"})
	w.box(34, 21.5, 8, 7.5, 4, {"tag": "plat"})
	# box ladder
	var hs := [0.6, 1.2, 1.8, 2.4, 3.0]
	for i in hs.size():
		w.box(-4, 14 + 3.5 * i, 2.4, 2.4, hs[i], {"tag": "box"})
	# ledge-grab towers: single jump / double jump / high jump
	w.box(-12, 40, 5, 5, 3.0, {"tag": "tower"})
	w.box(0, 40, 5, 5, 5.2, {"tag": "tower"})
	w.box(12, 40, 5, 5, 7.4, {"tag": "tower"})
	# floating slabs
	for s: Array in [[20, -20, 2.2], [26, -22, 3.8], [32, -19, 5.4], [38, -23, 7.0], [44, -20, 8.6]]:
		w.box(s[0], s[1], 4, 4, s[2], {"bottom": float(s[2]) - 0.5, "tag": "slab"})
	# wall corridor (camera collision)
	w.box(-44, -10, 1, 20, 6, {"tag": "wall"})
	w.box(-39, -10, 1, 20, 6, {"tag": "wall"})
	w.box(-41.5, -20.5, 6, 1, 6, {"tag": "wall"})
	# low tunnel: ceiling underside 1.3 (crouch to pass)
	w.box(-22, -18, 1, 12, 3.0, {"tag": "wall"})
	w.box(-18, -18, 1, 12, 3.0, {"tag": "wall"})
	w.box(-20, -18, 5, 12, 3.0, {"bottom": 1.3, "tag": "tunnel"})
	# near spawn: rotated box, angled wall, little hops
	w.box(6, 8, 3, 3, 1.0, {"yaw": 0.6, "tag": "box"})
	w.add({"kind": "box", "cx": -7.0, "cz": 8.0, "hx": 0.4, "hz": 3.0, "top": 3.0, "yaw": -0.5, "tag": "wall"})
	w.box(9, -7, 2, 2, 0.5, {"tag": "box"})
	w.box(12, -7, 2, 2, 1.0, {"tag": "box"})
	w.box(15, -7, 2, 2, 1.5, {"tag": "box"})
	# tall pillar field for camera testing
	for q: Array in [[-30, 20], [-34, 26], [-28, 30], [-24, 36]]:
		w.box(q[0], q[1], 2, 2, 6, {"tag": "wall"})
	w.spawn = {"x": 0.0, "y": 0.0, "z": 0.0, "yaw": 0.0}

	SolidView.build(w, self, COL)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sky.sky_material = sm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.environment = e
	add_child(env)
