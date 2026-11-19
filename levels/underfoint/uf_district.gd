class_name UfDistrict
extends RefCounted
## UNDERFOINT's first finished district: the old square with the market hall on its north side, the west avenue's tram line from where you land up to it, and the outcasts' camps.
## Hand-placed, built out of UfBuild / UfArch pieces and the Poly Haven props (assets/third-party/polyhaven). The level calls build() once while it is building.
## Layout (the square's block is x -30..30, z 6..54): the fountain at (0, 20); stalls down the west side; the hall's steps from z 39.6, its portico to z 44, the hall itself z 44..53.4, its floor 0.75 m up.

const Y := 0.15                 # the pavement
const HALL_X := 20.0            # the hall is x -20..20
const HALL_Z0 := 44.0
const HALL_Z1 := 53.4
const HALL_FLOOR := 0.9
const HALL_TOP := 8.4
const PROPS := "res://assets/third-party/polyhaven/%s/%s.gltf"

var lv: UnderfointLevel
var b: UfBuild
var arch: UfArch
var rng: RandomNumberGenerator
var _scenes: Dictionary = {}


func _init(p_lv: UnderfointLevel, p_b: UfBuild, p_arch: UfArch, p_rng: RandomNumberGenerator) -> void:
	lv = p_lv
	b = p_b
	arch = p_arch
	rng = p_rng


func build() -> void:
	_square()
	_hall()
	_tram_line()
	_street_lamps()
	_roots()
	_camps()
	b.commit(lv, "_district")


## (the level calls this before anything is built: the sewer uses these too)
func materials() -> void:
	b.mat("castiron", Color(0.035, 0.04, 0.04), {"rough": 0.45, "metal": 0.7, "scale": 0.6})
	b.mat("root", Color(0.07, 0.06, 0.04), {"rough": 0.9, "scale": 0.8})
	b.mat("cloth_a", Color(0.34, 0.12, 0.1), {"rough": 0.95, "scale": 0.9})
	b.mat("cloth_b", Color(0.36, 0.33, 0.24), {"rough": 0.95, "scale": 0.9})
	b.mat("cloth_c", Color(0.12, 0.2, 0.22), {"rough": 0.95, "scale": 0.9})
	b.mat("mattress", Color(0.3, 0.29, 0.25), {"rough": 0.95, "scale": 1.2})
	b.tex("tiles", "dirty_tiles", {"tile": 2.0, "tint": Color(0.6, 0.62, 0.58), "puddles": 0.5, "growth": 0.5})
	b.tex("bark", "distressed_painted_planks", {"tile": 1.2, "tint": Color(0.16, 0.14, 0.11), "growth": 1.4})
	b.tex("tram_a", "distressed_painted_planks", {"tile": 2.2, "tint": Color(0.5, 0.17, 0.12), "growth": 0.7})
	b.tex("tram_b", "distressed_painted_planks", {"tile": 2.2, "tint": Color(0.66, 0.6, 0.42), "growth": 0.7})


# ---- pieces ----------------------------------------------------------------------------------------------------------------------------------------------------------------

## One of the downloaded props, stood at (x, y, z). r > 0 makes it solid (a disc that wide, h tall).
func prop(nm: String, x: float, y: float, z: float, yaw: float = 0.0, s: float = 1.0, tilt: Vector3 = Vector3.ZERO, r: float = 0.0, h: float = 0.8) -> Node3D:
	if not _scenes.has(nm):
		_scenes[nm] = load(PROPS % [nm, nm])
	var n: Node3D = (_scenes[nm] as PackedScene).instantiate()
	n.position = Vector3(x, y, z)
	n.rotation = Vector3(tilt.x, yaw, tilt.z)
	n.scale = Vector3(s, s, s)
	var stack: Array[Node] = [n]
	while not stack.is_empty():
		var q: Node = stack.pop_back()
		stack.append_array(q.get_children())
		if q is GeometryInstance3D:
			(q as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			(q as GeometryInstance3D).visibility_range_end = 90.0
	lv.add_child(n)
	if r > 0.0:
		b.world.add({"kind": "disc", "cx": x, "cz": z, "r": r, "bottom": y, "top": y + h, "tag": "prop"})
	return n


## A wall along face f from y0 to y1 with holes in it. A hole is [u0, u1, bottom, top, what is behind it ("" = open right through)]; `depth` is how deep the hole's sides go.
func holes(f: UfArch.Face, tag: String, trim: String, y0: float, y1: float, holes: Array, depth: float) -> void:
	var u := 0.0
	for h: Array in holes:
		arch._front(tag, f, u, h[0], y0, y1, 0.0)
		arch._front(tag, f, h[0], h[1], y0, h[2], 0.0)
		arch._front(tag, f, h[0], h[1], h[3], y1, 0.0)
		if depth > 0.0:
			arch._side(tag, f, h[0], h[2], h[3], -depth, 0.0, 1.0)
			arch._side(tag, f, h[1], h[2], h[3], -depth, 0.0, -1.0)
			arch._flat(tag, f, h[0], h[1], h[3], -depth, 0.0, false)
			if h[2] > y0 + 0.01:
				arch._flat(trim, f, h[0], h[1], h[2], -depth, 0.0, true)
			if h[4] != "":
				arch._front(h[4], f, h[0], h[1], h[2], h[3], -depth)
		u = h[1]
	arch._front(tag, f, u, f.length, y0, y1, 0.0)


## A cast-iron street lamp. yaw: which way its arm reaches. lit: one of the few that still burn.
func lamp(x: float, z: float, yaw: float, lit: bool, y: float = Y) -> void:
	b.base_y = y
	b.box("castiron", x - 0.17, x + 0.17, y, y + 0.55, z - 0.17, z + 0.17, false, false)
	b.box("castiron", x - 0.11, x + 0.11, y + 0.55, y + 0.7, z - 0.11, z + 0.11, false, false)
	b.box("castiron", x - 0.065, x + 0.065, y + 0.7, y + 4.5, z - 0.065, z + 0.065, false, false)
	b.turned("castiron", x, z, 0.035, 0.035, y + 4.2, y + 4.75, yaw, Vector2(0.0, 0.75))
	var hx := x + sin(yaw) * 0.75
	var hz := z + cos(yaw) * 0.75
	b.box("castiron", hx - 0.17, hx + 0.17, y + 4.62, y + 4.74, hz - 0.17, hz + 0.17, false)
	b.box("lamp" if lit else "window", hx - 0.11, hx + 0.11, y + 4.3, y + 4.62, hz - 0.11, hz + 0.11, false)
	b.world.add({"kind": "disc", "cx": x, "cz": z, "r": 0.14, "bottom": y, "top": y + 4.5, "tag": "lamp", "no_cam": true})
	b.base_y = -1000.0
	if lit:
		lv.lamps.append(lv._light(Vector3(hx, y + 4.0, hz), Color("ffb060"), 1.5, 14.0))


## A dead street tree: a trunk in leaning lengths, a few bare limbs, an iron grate at its foot
func tree(x: float, z: float, h: float) -> void:
	b.base_y = Y
	b.grow = 0.3
	b.box("castiron", x - 0.75, x + 0.75, Y, Y + 0.04, z - 0.75, z + 0.75, false, false)
	var cx := x
	var cz := z
	var r := 0.26
	var y := Y
	var seg := h / 5.0
	for k in 5:
		var lean := Vector2(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.2, 0.2))
		var yaw := rng.randf() * TAU
		b.turned("bark", cx, cz, r, r, y, y + seg, yaw, lean)
		if k >= 2:      # limbs
			for n in 2:
				var a := rng.randf() * TAU
				var reach := rng.randf_range(0.9, 2.0) * (1.0 - k * 0.1)
				b.turned("bark", cx, cz, r * 0.4, r * 0.4, y + seg * 0.4, y + seg * 0.4 + rng.randf_range(0.6, 1.4), a, Vector2(0.0, reach))
		cx += lean.x * cos(yaw) + lean.y * sin(yaw)
		cz += -lean.x * sin(yaw) + lean.y * cos(yaw)
		y += seg
		r *= 0.76
	b.world.add({"kind": "disc", "cx": x, "cz": z, "r": 0.3, "bottom": Y, "top": Y + h * 0.6, "tag": "tree", "no_cam": true})
	b.grow = 0.0
	b.base_y = -1000.0


## A market stall: four iron poles, what is left of its awning, a plank counter
func stall(cx: float, cz: float, yaw: float, cloth: String) -> void:
	b.base_y = Y
	var c := cos(yaw)
	var s := sin(yaw)
	for k: Array in [[-1.5, -1.0], [1.5, -1.0], [1.5, 1.0], [-1.5, 1.0]]:
		var px: float = cx + k[0] * c + k[1] * s
		var pz: float = cz - k[0] * s + k[1] * c
		b.box("castiron", px - 0.035, px + 0.035, Y, Y + (2.25 if k[1] < 0.0 else 2.65), pz - 0.035, pz + 0.035, false, false)
	b.ramp(cloth, cx, cz, 1.7, 1.2, Y + 2.25, Y + 2.65, yaw, 0.03, false)
	b.turned("planks", cx + 0.55 * s, cz + 0.55 * c, 1.5, 0.35, Y, Y + 0.95, yaw)
	b.world.add({"kind": "box", "cx": cx + 0.55 * s, "cz": cz + 0.55 * c, "hx": 1.5, "hz": 0.35, "yaw": yaw, "bottom": Y, "top": Y + 0.95, "tag": "stall"})
	b.base_y = -1000.0


## Somewhere to sleep: a mattress, a blanket thrown over half of it, something for a pillow
func bed(x: float, y: float, z: float, yaw: float, cloth: String) -> void:
	b.turned("mattress", x, z, 0.45, 0.95, y, y + 0.16, yaw)
	b.turned(cloth, x + sin(yaw) * 0.3, z + cos(yaw) * 0.3, 0.48, 0.6, y + 0.16, y + 0.2, yaw + rng.randf_range(-0.15, 0.15))
	b.turned("cloth_b", x - sin(yaw) * 0.72, z - cos(yaw) * 0.72, 0.28, 0.16, y + 0.16, y + 0.27, yaw)


## A lean-to: two poles, a sheet of roofing iron run down to the ground behind, a bed under it
func lean_to(x: float, z: float, yaw: float, cloth: String, y: float = Y) -> void:
	b.base_y = y
	var c := cos(yaw)
	var s := sin(yaw)
	for sx: float in [-1.15, 1.15]:
		var px := x + sx * c + 1.0 * s
		var pz := z - sx * s + 1.0 * c
		b.box("planks", px - 0.04, px + 0.04, y, y + 1.75, pz - 0.04, pz + 0.04, false, false)
	b.ramp("iron", x, z, 1.3, 1.15, y + 0.1, y + 1.78, yaw, 0.03, false)
	b.turned(cloth, x - 1.28 * c + 0.2 * s, z + 1.28 * s + 0.2 * c, 0.015, 0.8, y, y + 1.2, yaw)
	bed(x + 0.15 * s, y, z + 0.15 * c, yaw + PI * 0.5, cloth)
	b.base_y = -1000.0


## A line strung between two points with the washing still on it
func washing(x0: float, z0: float, x1: float, z1: float, y: float) -> void:
	var n := 7
	var yaw := atan2(x1 - x0, z1 - z0)
	var length := Vector2(x1 - x0, z1 - z0).length()
	b.turned("cable", (x0 + x1) * 0.5, (z0 + z1) * 0.5, 0.008, length * 0.5, y, y + 0.016, yaw)
	for k in n:
		var u := (k + 0.5 + rng.randf_range(-0.2, 0.2)) / n
		var hh := rng.randf_range(0.45, 1.05)
		b.turned(["cloth_a", "cloth_b", "cloth_c", "tarp"][rng.randi() % 4], lerpf(x0, x1, u), lerpf(z0, z1, u), 0.012, rng.randf_range(0.18, 0.34), y - hh, y, yaw, Vector2(rng.randf_range(-0.05, 0.05), 0.0))


# ---- the square --------------------------------------------------------------------------------------------------------------------------------------------------------------

func _square() -> void:
	b.box("walk", -30.0, 30.0, 0.0, Y, 6.0, 54.0)
	# the fountain: an eight-sided basin of standing water, and the plinth of whoever the old city put up
	var fx := 0.0
	var fz := 20.0
	b.base_y = Y
	b.grow = 0.2
	for k in 8:
		var a := k * TAU / 8.0
		b.turned("trim", fx + sin(a) * 3.55, fz + cos(a) * 3.55, 1.52, 0.28, Y, Y + 0.7, a)
		b.turned("stone", fx + sin(a) * 3.55, fz + cos(a) * 3.55, 1.62, 0.36, Y + 0.7, Y + 0.82, a)
	b.grow = 0.0
	b.base_y = -1000.0
	b.quad("slime", Vector3(fx - 3.4, Y + 0.5, fz - 3.4), Vector3(fx + 3.4, Y + 0.5, fz - 3.4), Vector3(fx + 3.4, Y + 0.5, fz + 3.4), Vector3(fx - 3.4, Y + 0.5, fz + 3.4))
	b.base_y = Y
	b.box("trim", fx - 0.9, fx + 0.9, Y, Y + 1.5, fz - 0.9, fz + 0.9, false, false)
	b.box("stone", fx - 1.05, fx + 1.05, Y + 1.5, Y + 1.72, fz - 1.05, fz + 1.05, false)
	b.turned("trim", fx - 0.28, fz, 0.17, 0.2, Y + 1.72, Y + 2.7, 0.2, Vector2(0.05, 0.0))      # two legs to the knee: the rest of him is in the basin
	b.turned("trim", fx + 0.3, fz + 0.05, 0.17, 0.2, Y + 1.72, Y + 2.35, -0.1)
	b.turned("trim", fx + 1.9, fz - 1.2, 0.45, 0.85, Y + 0.3, Y + 0.95, 0.9, Vector2(0.1, 0.2))
	b.turned("trim", fx + 2.4, fz + 0.3, 0.3, 0.3, Y + 0.3, Y + 0.85, 0.3)
	b.base_y = -1000.0
	b.world.add({"kind": "disc", "cx": fx, "cz": fz, "r": 3.95, "bottom": Y, "top": Y + 0.82, "tag": "fountain"})
	b.world.add({"kind": "box", "cx": fx, "cz": fz, "hx": 1.05, "hz": 1.05, "bottom": Y, "top": Y + 1.72, "tag": "plinth"})
	lv._light(Vector3(fx, Y + 1.2, fz + 2.2), Color("4dffb0"), 0.5, 7.0)      # the water has gone the colour of the fungus
	# trees in their grates, benches, lamps: the square as it was laid out
	for q: Array in [[-13.0, 12.0], [13.0, 12.0], [-13.0, 29.0], [13.0, 29.0], [-24.0, 36.0], [24.0, 36.0]]:
		tree(q[0], q[1], rng.randf_range(5.5, 8.0))
	for q: Array in [[-7.5, 12.5, 0.0], [7.5, 12.5, 0.0], [-13.0, 20.5, PI * 0.5], [13.0, 20.5, PI * 0.5], [7.0, 30.5, 0.0]]:
		_bench(q[0], q[1], q[2])
	var li := 0
	for q: Array in [[-27.0, 9.0, 0.8], [0.0, 9.0, 0.0], [27.0, 9.0, -0.8], [-27.0, 24.0, PI * 0.5], [27.0, 24.0, -PI * 0.5], [-10.0, 38.0, PI], [10.0, 38.0, PI], [-27.0, 38.0, 2.3], [27.0, 38.0, -2.3]]:
		lamp(q[0], q[1], q[2], li in [1, 3, 5, 6])
		li += 1
	# the market: stalls down the west side, half of them fallen in
	stall(-22.0, 14.0, PI * 0.5, "cloth_a")
	stall(-22.0, 19.5, PI * 0.5, "cloth_b")
	stall(-22.0, 27.0, PI * 0.5 + 0.12, "cloth_c")
	stall(20.5, 15.0, -PI * 0.5, "cloth_b")
	arch.heap(22.0, 31.0, 2.2, Y, "brick")
	arch.heap(-17.0, 33.5, 1.6, Y, "stone")


func _bench(x: float, z: float, yaw: float) -> void:
	b.base_y = Y
	b.turned("planks", x, z, 0.95, 0.22, Y + 0.4, Y + 0.47, yaw)
	b.turned("planks", x - sin(yaw) * 0.24, z - cos(yaw) * 0.24, 0.95, 0.03, Y + 0.5, Y + 0.95, yaw, Vector2(0.0, -0.08))
	for sx: float in [-0.8, 0.8]:
		b.turned("castiron", x + sx * cos(yaw), z - sx * sin(yaw), 0.03, 0.24, Y, Y + 0.4, yaw)
	b.world.add({"kind": "box", "cx": x, "cz": z, "hx": 0.95, "hz": 0.25, "yaw": yaw, "bottom": Y, "top": Y + 0.47, "tag": "bench"})
	b.base_y = -1000.0


# ---- the market hall ---------------------------------------------------------------------------------------------------------------------------------------------------------

## The square's north side: a long stone hall behind a portico of six columns, up five steps. Its door stands open, and the outcasts live in it.
func _hall() -> void:
	var x0 := -HALL_X
	var x1 := HALL_X
	var z0 := HALL_Z0
	var z1 := HALL_Z1
	var fy := HALL_FLOOR
	var top := HALL_TOP
	var T := 0.6
	var door0 := 17.8      # along the south face
	var door1 := 22.2
	var door_top := fy + 4.4
	b.base_y = Y
	# outside: tall dead windows between the door and the corners, a cornice, the roof
	var win := func(u: float) -> Array: return [u - 0.8, u + 0.8, fy + 1.3, fy + 5.2, "void"]
	var south := UfArch._mk(x0, z0, 1.0, 0.0, 0.0, -1.0, x1 - x0)
	holes(south, "stone", "trim", Y, top, [win.call(3.5), win.call(8.5), win.call(13.5), [door0, door1, fy, door_top, ""], win.call(26.5), win.call(31.5), win.call(36.5)], T)
	var north := UfArch._mk(x0, z1, 1.0, 0.0, 0.0, 1.0, x1 - x0)
	holes(north, "stone", "trim", Y, top, [win.call(5.0), win.call(12.0), win.call(20.0), win.call(28.0), win.call(35.0)], 0.4)
	for f: UfArch.Face in [UfArch._mk(x0, z0, 0.0, 1.0, -1.0, 0.0, z1 - z0), UfArch._mk(x1, z0, 0.0, 1.0, 1.0, 0.0, z1 - z0)]:
		holes(f, "stone", "trim", Y, top, [win.call(2.6), win.call(6.8)], 0.4)
	for f: UfArch.Face in [south, north, UfArch._mk(x0, z0, 0.0, 1.0, -1.0, 0.0, z1 - z0), UfArch._mk(x1, z0, 0.0, 1.0, 1.0, 0.0, z1 - z0)]:
		arch._slab("trim", f, 0.0, f.length, top - 0.45, top, 0.0, 0.22)
		arch._slab("trim", f, 0.0, f.length, top, top + 0.25, 0.0, 0.42)
		arch._slab("trim", f, 0.0, f.length, Y, Y + 0.75, 0.0, 0.1)
	b.base_y = top - 1.0
	b.quad("roof", Vector3(x0, top + 0.25, z0), Vector3(x1, top + 0.25, z0), Vector3(x1, top + 0.25, z1), Vector3(x0, top + 0.25, z1))
	# inside: one long room, tiled, the plaster coming off
	b.base_y = fy
	b.foot_shade = 0.7
	b.box("tiles", x0 + T, x1 - T, fy - 0.3, fy, z0 + T, z1 - T)
	b.quad("inner", Vector3(x0 + T, top - 0.6, z0 + T), Vector3(x0 + T, top - 0.6, z1 - T), Vector3(x1 - T, top - 0.6, z1 - T), Vector3(x1 - T, top - 0.6, z0 + T))
	var in_s := UfArch._mk(x0 + T, z0 + T, 1.0, 0.0, 0.0, 1.0, x1 - x0 - T * 2.0)
	holes(in_s, "inner", "trim", fy, top - 0.6, [[door0 - T, door1 - T, fy, door_top, ""]], 0.0)
	arch._front("inner", UfArch._mk(x0 + T, z1 - T, 1.0, 0.0, 0.0, -1.0, x1 - x0 - T * 2.0), 0.0, x1 - x0 - T * 2.0, fy, top - 0.6, 0.0)
	arch._front("inner", UfArch._mk(x0 + T, z0 + T, 0.0, 1.0, 1.0, 0.0, z1 - z0 - T * 2.0), 0.0, z1 - z0 - T * 2.0, fy, top - 0.6, 0.0)
	arch._front("inner", UfArch._mk(x1 - T, z0 + T, 0.0, 1.0, -1.0, 0.0, z1 - z0 - T * 2.0), 0.0, z1 - z0 - T * 2.0, fy, top - 0.6, 0.0)
	for cx: float in [-12.0, -4.0, 4.0, 12.0]:      # iron columns down the middle that hold the roof
		b.box("castiron", cx - 0.14, cx + 0.14, fy, top - 0.6, 48.6, 48.88, false, false)
		b.box("castiron", cx - 0.26, cx + 0.26, top - 0.95, top - 0.6, 48.48, 49.0, false)
		b.world.add({"kind": "disc", "cx": cx, "cz": 48.74, "r": 0.2, "bottom": fy, "top": top, "tag": "column", "no_cam": true})
	b.foot_shade = 0.5
	# the portico: a platform up five steps, six columns (one down), the beam and what is left of the gable
	b.base_y = Y
	b.box("trim", x0 + 1.0, x1 - 1.0, Y, fy, 41.0, z0)
	for k in range(1, 5):
		b.box("trim", x0 + 1.0, x1 - 1.0, Y, fy - k * 0.15, 41.0 - k * 0.35, 41.0 - (k - 1) * 0.35, false, false)
	b.world.add({"kind": "ramp", "cx": 0.0, "cz": 40.3, "hx": HALL_X - 1.0, "hz": 0.7, "yaw": 0.0, "bottom": Y - 0.3, "top": fy, "top_low": Y, "tag": "steps"})
	b.world.add({"kind": "box", "cx": 0.0, "cz": z0 + T * 0.5, "hx": (door1 - door0) * 0.5, "hz": T * 0.5, "bottom": Y, "top": fy, "tag": "sill"})
	var n := 0
	for cx: float in [-15.0, -9.0, -3.0, 3.0, 9.0, 15.0]:
		var broken := n == 4
		var ch := fy + (2.3 if broken else 5.7)
		b.box("trim", cx - 0.58, cx + 0.58, fy, fy + 0.3, 41.52, 42.68, false, false)
		b.box("stone", cx - 0.42, cx + 0.42, fy + 0.3, ch, 41.68, 42.52, false, false)
		if broken:
			b.turned("stone", cx + 1.2, 39.0, 0.42, 1.5, Y, Y + 0.84, 0.5)
			b.turned("stone", cx - 0.6, 37.6, 0.42, 0.7, Y, Y + 0.84, -0.9)
			b.world.add({"kind": "disc", "cx": cx + 1.2, "cz": 39.0, "r": 0.9, "bottom": Y, "top": Y + 0.84, "tag": "column"})
		else:
			b.box("trim", cx - 0.58, cx + 0.58, ch, ch + 0.3, 41.52, 42.68, false)
		b.world.add({"kind": "box", "cx": cx, "cz": 42.1, "hx": 0.45, "hz": 0.45, "bottom": fy, "top": ch, "tag": "column", "no_cam": true})
		n += 1
	b.base_y = fy + 5.0
	b.box("stone", x0 + 2.4, 6.2, fy + 6.0, fy + 7.1, 41.4, 42.8, false)      # the beam: gone over the broken column and east of it
	b.box("trim", x0 + 2.2, 6.4, fy + 7.1, fy + 7.35, 41.2, 43.0, false)
	b.box("roof", x0 + 2.4, 6.2, fy + 6.9, fy + 7.1, 42.8, z0, false)
	b.box("stone", -13.0, 5.0, fy + 7.35, fy + 8.2, 41.6, 42.6, false)
	b.box("stone", -8.5, 2.0, fy + 8.2, fy + 9.0, 41.6, 42.6, false)
	b.box("stone", -4.0, 0.5, fy + 9.0, fy + 9.7, 41.6, 42.6, false)
	arch.heap(11.5, 40.0, 2.4, Y, "stone")
	b.base_y = -1000.0
	# what holds you out: the walls (the south one in two, with the lintel over the door) and the roof
	var dw := (x1 - x0) * 0.5
	var dc0 := x0 + door0
	var dc1 := x0 + door1
	b.world.add({"kind": "box", "cx": (x0 + dc0) * 0.5, "cz": z0 + T * 0.5, "hx": (dc0 - x0) * 0.5, "hz": T * 0.5, "bottom": Y, "top": top, "tag": "hall"})
	b.world.add({"kind": "box", "cx": (dc1 + x1) * 0.5, "cz": z0 + T * 0.5, "hx": (x1 - dc1) * 0.5, "hz": T * 0.5, "bottom": Y, "top": top, "tag": "hall"})
	b.world.add({"kind": "box", "cx": 0.0, "cz": z0 + T * 0.5, "hx": (dc1 - dc0) * 0.5, "hz": T * 0.5, "bottom": door_top, "top": top, "tag": "hall"})
	b.world.add({"kind": "box", "cx": 0.0, "cz": z1 - T * 0.5, "hx": dw, "hz": T * 0.5, "bottom": Y, "top": top, "tag": "hall"})
	b.world.add({"kind": "box", "cx": x0 + T * 0.5, "cz": (z0 + z1) * 0.5, "hx": T * 0.5, "hz": (z1 - z0) * 0.5, "bottom": Y, "top": top, "tag": "hall"})
	b.world.add({"kind": "box", "cx": x1 - T * 0.5, "cz": (z0 + z1) * 0.5, "hx": T * 0.5, "hz": (z1 - z0) * 0.5, "bottom": Y, "top": top, "tag": "hall"})
	b.world.add({"kind": "box", "cx": 0.0, "cz": (z0 + z1) * 0.5, "hx": dw, "hz": (z1 - z0) * 0.5, "bottom": top - 0.6, "top": top + 0.25, "tag": "hall"})


# ---- the streets -------------------------------------------------------------------------------------------------------------------------------------------------------------

## The west avenue's tram line: two rails from end to end, cut wherever FOINT drove a pile through them, the wire's posts, and the last tram, stopped short of the pile at z 30
func _tram_line() -> void:
	for seg: Array in [[-100.0, -87.0], [-81.0, -49.0], [-43.0, -33.0], [-27.0, 27.0], [33.0, 100.0]]:
		for rx: float in [-36.72, -35.28]:
			b.box("castiron", rx - 0.035, rx + 0.035, 0.0, 0.045, seg[0], seg[1], false, false)
	var z := -92.0
	while z < 96.0:      # the posts that carried the wire, and the wire where it still hangs
		if absf(z - 30.0) > 6.0 and absf(z + 30.0) > 6.0 and absf(z + 46.0) > 5.0 and absf(z + 84.0) > 5.0:
			b.base_y = 0.0
			b.box("castiron", -41.2, -41.06, 0.15, 6.3, z - 0.07, z + 0.07, false, false)
			b.box("castiron", -41.2, -35.9, 6.0, 6.07, z - 0.03, z + 0.03, false)
			b.world.add({"kind": "disc", "cx": -41.13, "cz": z, "r": 0.12, "bottom": 0.15, "top": 6.3, "tag": "post", "no_cam": true})
		z += 23.0
	b.base_y = -1000.0
	b.box("cable", -36.01, -35.99, 5.92, 5.94, -27.0, 26.0, false)
	b.turned("cable", -36.0, 62.0, 0.01, 30.0, 5.92, 5.94, 0.0)
	b.turned("cable", -36.0, -18.0, 0.01, 4.0, 1.4, 1.42, 0.3, Vector2(0.0, 0.0))
	car(-36.0, 19.5)


## A rail car, its nose to the north: the tram in the avenue (9.6 m, with its pole up and one headlamp lit) or a train in the station (pass its half width and length, the floor it stands on, tram = false).
## Shut: nobody has got its doors open in fifty years.
func car(x: float, z: float, hw: float = 1.2, hl: float = 4.8, base: float = 0.0, tram: bool = true) -> void:
	var y0 := base + 0.42
	var h := 2.55 if tram else 2.95      # the body's height
	b.base_y = base
	b.grow = 0.15
	for bz: float in [z - hl * 0.62, z + hl * 0.62]:      # the trucks
		b.box("castiron", x - hw * 0.8, x + hw * 0.8, base + 0.05, y0, bz - 0.9, bz + 0.9, false, false)
		for wz: float in [bz - 0.55, bz + 0.55]:
			b.box("rust", x - hw * 0.67, x + hw * 0.67, base + 0.05, base + 0.7, wz - 0.3, wz + 0.3, false, false)
	var faces: Array[UfArch.Face] = [UfArch._mk(x - hw, z - hl, 1.0, 0.0, 0.0, -1.0, hw * 2.0), UfArch._mk(x - hw, z + hl, 1.0, 0.0, 0.0, 1.0, hw * 2.0),
		UfArch._mk(x - hw, z - hl, 0.0, 1.0, -1.0, 0.0, hl * 2.0), UfArch._mk(x + hw, z - hl, 0.0, 1.0, 1.0, 0.0, hl * 2.0)]
	for fi in 4:
		var f := faces[fi]
		arch._front("tram_a", f, 0.0, f.length, y0, y0 + 1.05, 0.0)
		arch._slab("castiron", f, 0.0, f.length, y0 + 1.0, y0 + 1.08, 0.0, 0.04)
		arch._front("tram_b", f, 0.0, f.length, y0 + 2.1, y0 + h, 0.0)
		var u := 0.0      # the window band: glass where it has held, a hole where it has not
		var step := 1.2 if fi >= 2 else f.length
		while u < f.length - 0.01:
			var u1 := minf(f.length, u + step)
			arch._front("tram_b", f, u, u + 0.09, y0 + 1.05, y0 + 2.1, 0.0)
			arch._front("tram_b", f, u1 - 0.09, u1, y0 + 1.05, y0 + 2.1, 0.0)
			arch._front("window" if rng.randf() < 0.6 else "void", f, u + 0.09, u1 - 0.09, y0 + 1.05, y0 + 2.1, -0.05)
			u = u1
	b.box("iron", x - hw - 0.06, x + hw + 0.06, y0 + h, y0 + h + 0.15, z - hl - 0.1, z + hl + 0.1, false)
	b.box("iron", x - hw * 0.7, x + hw * 0.7, y0 + h + 0.15, y0 + h + 0.27, z - hl + 0.3, z + hl - 0.3, false, false)
	if tram:
		b.turned("castiron", x, z + 1.0, 0.03, 0.03, y0 + 2.8, y0 + 5.5, 0.0, Vector2(0.0, -2.2))      # the pole, still up against the wire
		b.box("lamp", x - 0.16, x + 0.16, y0 + 1.25, y0 + 1.5, z + hl, z + hl + 0.04, false)        # one headlamp that never went out
		lv._light(Vector3(x, y0 + 1.4, z + hl + 1.4), Color("ffcf8a"), 0.7, 8.0)
		lv._light(Vector3(x + 2.6, 2.4, z - 2.0), Color("7dffb0"), 0.55, 11.0)      # and the fungus under its skirts lights its flank
	b.world.add({"kind": "box", "cx": x, "cz": z, "hx": hw, "hz": hl, "bottom": base, "top": y0 + h + 0.15, "tag": "tram"})
	b.grow = 0.0
	b.base_y = -1000.0


## Lamps down both avenues and the cross streets, on the kerb. One in five still burns.
func _street_lamps() -> void:
	var n := 0
	for ax: float in [-42.6, 42.6, -29.4, 29.4]:
		var z := -90.0 + (11.0 if absf(ax) < 35.0 else 0.0)
		while z < 96.0:
			if not (ax > -31.0 and ax < 31.0 and z > 5.0 and z < 55.0) and absf(z) > 8.0 and absf(absf(z) - 60.0) > 8.0:
				lamp(ax, z, PI * 0.5 if (ax < -35.0 or (ax > 0.0 and ax < 35.0)) else -PI * 0.5, n % 5 == 2)
				n += 1
			z += 22.0
	for az: float in [-66.6, -53.4, -6.6, 6.6, 53.4, 66.6]:
		var x := -84.0
		while x < 90.0:
			if absf(absf(x) - 36.0) > 8.0 and not (az > 5.0 and az < 55.0 and absf(x) < 31.0):
				lamp(x, az, 0.0 if az in [-66.6, -6.6, 53.4] else PI, n % 5 == 2)
				n += 1
			x += 27.0


## What has come down through the slab over fifty years: roots, hanging in curtains over the square and round every pile
func _roots() -> void:
	var spots: Array = [[0.0, 22.0, 26, 7.0], [-18.0, 30.0, 14, 4.0], [16.0, 14.0, 14, 4.0], [-36.0, -28.0, 16, 3.5], [-36.0, 8.0, 12, 4.0], [-6.0, 44.0, 10, 5.0]]
	for q: Array in UnderfointLevel.PILES:
		spots.append([q[0], q[1], 18, 4.2])
	for q: Array in spots:
		for k in int(q[2]):
			var a := rng.randf() * TAU
			var d: float = (0.6 + 0.4 * rng.randf()) * float(q[3])
			var length := rng.randf_range(3.0, 15.0)
			var w := rng.randf_range(0.02, 0.06)
			var top: float = UnderfointLevel.SLAB
			b.turned("root", float(q[0]) + cos(a) * d, float(q[1]) + sin(a) * d, w, w, top - length, top, rng.randf() * TAU, Vector2(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.6, 0.6)))


# ---- the camps ---------------------------------------------------------------------------------------------------------------------------------------------------------------

## The outcasts' places. The three fires in the square and the hall they sleep in; the Ticket Man's corner; the Collector's.
func _camps() -> void:
	# FIREKEEPER's, west of the fountain: his fire, a sofa dragged out of somewhere, what he burns
	prop("sofa_03", -11.6, Y, 24.4, 2.5, 1.0, Vector3.ZERO, 0.9, 0.7)
	prop("ArmChair_01", -6.6, Y, 23.6, -2.2, 1.0, Vector3.ZERO, 0.45, 0.7)
	b.base_y = Y
	for k in 6:
		b.turned("planks", -11.4 + rng.randf_range(-0.5, 0.5), 21.0 + rng.randf_range(-0.4, 0.4), 0.07, 0.6, Y + k * 0.07, Y + 0.07 + k * 0.07, rng.randf() * 3.0)
	b.base_y = -1000.0
	prop("trashbag", -12.6, Y, 22.2, 0.4)
	prop("trashbag", -12.9, Y, 22.9, 2.1, 0.85)
	prop("old_tyre", -7.6, Y + 0.08, 20.6, 0.0, 1.0, Vector3(PI * 0.5, 0.0, 0.0))
	prop("old_tyre", -7.6, Y + 0.24, 20.65, 0.7, 1.0, Vector3(PI * 0.5, 0.0, 0.0))
	lean_to(-15.2, 23.6, PI * 0.5, "cloth_a")
	# RAG WOMAN's, east of it: her line, her tub, her chair
	washing(13.0, 20.6, 13.0, 29.0, Y + 2.3)
	washing(7.2, 30.6, 13.0, 29.2, Y + 2.2)
	b.box("planks", 7.14, 7.26, Y, Y + 2.3, 30.54, 30.66, false, false)
	prop("ArmChair_01", 10.2, Y, 27.4, 2.6, 1.0, Vector3.ZERO, 0.45, 0.7)
	prop("Barrel_01", 11.6, Y, 24.4, 1.0, 1.0, Vector3.ZERO, 0.3, 0.88)
	prop("propane_tank", 9.4, Y, 23.9, 0.5)
	lean_to(15.6, 25.6, -PI * 0.5, "cloth_b")
	prop("Lantern_01", 10.9, Y + 0.0, 28.3, 0.3, 1.6)
	lv._light(Vector3(10.9, Y + 0.5, 28.3), Color("ffb060"), 0.5, 5.0)
	# THE LISTENER's, in front of the hall's steps: pipes come up through the paving here, and the sets nobody plugged in
	b.base_y = Y
	for q: Array in [[-4.6, 34.2, 1.5], [-4.2, 34.9, 1.1], [-5.1, 35.0, 2.0]]:
		b.box("rust", q[0] - 0.09, q[0] + 0.09, Y, Y + q[2], q[1] - 0.09, q[1] + 0.09, false, false)
		b.box("rust", q[0] - 0.13, q[0] + 0.13, Y + q[2] - 0.12, Y + q[2], q[1] - 0.13, q[1] + 0.13, false)
	b.turned("rust", -4.6, 36.2, 0.09, 1.3, Y + 0.05, Y + 0.23, 0.2)
	b.base_y = -1000.0
	b.world.add({"kind": "disc", "cx": -4.6, "cz": 34.7, "r": 0.6, "bottom": Y, "top": Y + 1.1, "tag": "pipes"})
	lv._tv(0.6, Y, 36.6)
	prop("old_military_crate", 1.2, Y, 33.2, 0.4, 0.8)
	# inside the hall: where they sleep. A stove made of a barrel, beds down both walls, what they own.
	var fy := HALL_FLOOR
	prop("barrel_stove", -7.0, fy, 49.4, 0.6, 1.0, Vector3.ZERO, 0.32, 0.86)
	lv.lamps.append(lv._light(Vector3(-7.0, fy + 1.3, 49.0), Color("ff8a3a"), 1.6, 12.0))
	prop("sofa_03", -9.6, fy, 51.4, 0.15, 1.0, Vector3.ZERO, 0.9, 0.7)
	prop("ArmChair_01", -4.8, fy, 50.9, -0.7, 1.0, Vector3.ZERO, 0.45, 0.7)
	var i := 0
	for bx: float in [-17.6, -15.4, -13.2, 6.4, 8.8, 11.2, 13.6, 16.0]:
		bed(bx, fy, 52.0 if i % 2 == 0 else 51.7, 0.0 + rng.randf_range(-0.1, 0.1), ["cloth_a", "cloth_b", "cloth_c"][i % 3])
		i += 1
	for bx: float in [-17.0, -14.2, 9.5, 12.5, 15.5]:
		bed(bx, fy, 45.7, PI + rng.randf_range(-0.12, 0.12), ["cloth_c", "cloth_b", "cloth_a"][i % 3])
		i += 1
	washing(-12.0, 48.74, -4.0, 48.74, fy + 2.4)
	washing(4.0, 48.74, 12.0, 48.74, fy + 2.3)
	prop("old_military_crate", 4.6, fy, 51.9, 1.57, 0.9)
	prop("Barrel_01", 18.2, fy, 46.0, 0.0, 1.0, Vector3.ZERO, 0.3, 0.88)
	prop("Barrel_01", 17.6, fy, 46.8, 1.3, 1.0, Vector3.ZERO, 0.3, 0.88)
	prop("trashbag", 18.3, fy, 52.3, 0.9)
	prop("trashbag", 17.6, fy, 52.6, 2.4, 0.9)
	prop("propane_tank", -18.4, fy, 46.2, 0.2)
	prop("Lantern_01", 9.0, fy, 49.6, 0.0, 1.6)
	lv._light(Vector3(9.0, fy + 0.6, 49.6), Color("ffb060"), 0.9, 8.0)
	lv._light(Vector3(0.0, fy + 3.0, 45.6), Color("9fd8c0"), 0.4, 9.0)      # what comes in at the door
	# TICKET MAN's corner (east avenue, south) and the COLLECTOR's (far south-west): one fire each and a roof
	lean_to(39.6, -47.4, -PI * 0.5, "cloth_c", 0.0)
	prop("old_tyre", 37.6, 0.08, -46.0, 0.0, 1.0, Vector3(PI * 0.5, 0.0, 0.0))
	prop("trashbag", 34.2, 0.0, -45.2, 1.0)
	prop("WoodenChair_01", 37.6, 0.0, -43.0, 2.4, 0.42)
	lean_to(-73.6, -62.4, PI, "cloth_a", 0.0)
	prop("ArmChair_01", -68.2, 0.0, -59.6, -1.9, 1.0, Vector3.ZERO, 0.45, 0.7)
	prop("trashbag", -71.4, 0.0, -57.6, 0.0)
