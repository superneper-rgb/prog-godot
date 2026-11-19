class_name UfSewer
extends RefCounted
## UNDERFOINT's way in: the storm drain under FOINT CITY, built to look like nothing more than a sewer. The plan is the level's (UnderfointLevel.SEWER, a 2 m grid: an open cell is tunnel, a closed cell beside
## one is wall) and so is what you can walk on; this draws it as brick tunnels with a coved roof, a plinth, a channel of moving water between kerbs, pipes, lamps in cages, and the things that wash up.
## The one thing that is not what it seems is the floor grate in the cabled branch (`grate`, `grate_node`): the level lets it take your weight for a moment, then drops it and you with it.

const S := UnderfointLevel.SEW
const TOP := UnderfointLevel.SEW_TOP
const CELL := UnderfointLevel.CELL
const GX0 := UnderfointLevel.GX0
const GZ0 := UnderfointLevel.GZ0
const GNX := UnderfointLevel.GNX
const GNZ := UnderfointLevel.GNZ
const HOLE := UnderfointLevel.HOLE
const WATER := preload("res://levels/shaders/uf_water.gdshader")

var lv: UnderfointLevel
var b: UfBuild
var arch: UfArch
var rng: RandomNumberGenerator
var grate: World.Solid = null
var grate_node: Node3D = null
var _open := PackedByteArray()


func _init(p_lv: UnderfointLevel, p_b: UfBuild, p_arch: UfArch, p_rng: RandomNumberGenerator) -> void:
	lv = p_lv
	b = p_b
	arch = p_arch
	rng = p_rng


func build() -> void:
	_materials()
	_shell()
	_water()
	_pipes()
	_things()
	_grate()
	_lamps()
	b.commit(lv, "_sewer")


func _materials() -> void:
	b.tex("sewer", "brick_wall_001", {"tile": 2.2, "tint": Color(0.42, 0.4, 0.34), "rough": 0.7, "growth": 1.3})
	b.tex("sewer_floor", "cracked_concrete_wall", {"tile": 2.6, "tint": Color(0.4, 0.42, 0.38), "rough": 0.8, "puddles": 1.0, "growth": 1.2})
	b.tex("sewer_trim", "cracked_concrete_wall", {"tile": 1.4, "tint": Color(0.5, 0.5, 0.44), "growth": 1.4})
	b.tex("pipe", "corrugated_iron_02", {"tile": 0.9, "tint": Color(0.42, 0.27, 0.2), "growth": 0.6})
	var w := ShaderMaterial.new()
	w.shader = WATER
	w.set_shader_parameter(&"noise_tex", b._stain)
	b.mats["water"] = w


func _is_open(i: int, j: int) -> bool:
	return i >= 0 and i < GNX and j >= 0 and j < GNZ and _open[i + j * GNX] == 1


## 0 = solid ground, 1 = tunnel, 2 = tunnel over the shaft, 3 = wall (closed, with a tunnel cell beside it)
func _cell(i: int, j: int) -> int:
	if _is_open(i, j):
		var x := GX0 + i * CELL
		var z := GZ0 + j * CELL
		return 2 if x >= HOLE[0] and x < HOLE[1] and z >= HOLE[2] and z < HOLE[3] else 1
	for dj in [-1, 0, 1]:
		for di in [-1, 0, 1]:
			if _is_open(i + di, j + dj):
				return 3
	return 0


## the crawl pipe's lane: its roof is down at 1.25 m, so it gets no cove and no plinth
static func _in_crawl(x: float, z: float) -> bool:
	return x >= -74.0 and x < -66.0 and z >= -98.0 and z < -96.0


## The tunnels themselves: floor, roof and walls from the plan (these are what you walk on and into), then what makes them a sewer: the roof coved down to the walls, a plinth along every wall's foot
func _shell() -> void:
	_open.resize(GNX * GNZ)
	for r: Array in UnderfointLevel.SEWER:
		for j in range(int((r[2] - GZ0) / CELL), int((r[3] - GZ0) / CELL)):
			for i in range(int((r[0] - GX0) / CELL), int((r[1] - GX0) / CELL)):
				_open[i + j * GNX] = 1
	b.base_y = S
	for j in GNZ:
		var z0 := GZ0 + j * CELL
		var i := 0
		while i < GNX:
			var kind := _cell(i, j)
			var i1 := i
			while i1 < GNX and _cell(i1, j) == kind:
				i1 += 1
			var x0 := GX0 + i * CELL
			var x1 := GX0 + i1 * CELL
			if kind == 1:
				b.box("sewer_floor", x0, x1, S - 0.6, S, z0, z0 + CELL)
				b.box("sewer", x0, x1, TOP, TOP + 0.6, z0, z0 + CELL)
			elif kind == 2:
				b.box("sewer", x0, x1, TOP, TOP + 0.6, z0, z0 + CELL)
			elif kind == 3:
				b.box("sewer", x0, x1, S - 0.6, TOP + 0.6, z0, z0 + CELL)
			i = i1
	b.box("sewer", -74.0, -66.0, S + 1.25, TOP, -98.0, -96.0)      # the crawl pipe: the grid's 2 m lane with its roof down at 1.25 m (a 1.2 m wide pipe was tried: he caught on its lip unless he walked in dead straight)
	for q: Array in [[-74.02, -97.0], [-65.98, -97.0]]:              # a concrete collar round each of its mouths
		b.box("sewer_trim", q[0] - 0.14, q[0] + 0.14, S + 1.25, S + 1.6, -98.0, -96.0, false)
	for j in GNZ:
		for i in GNX:
			if not _is_open(i, j):
				continue
			var x0 := GX0 + i * CELL
			var z0 := GZ0 + j * CELL
			var x1 := x0 + CELL
			var z1 := z0 + CELL
			if _in_crawl(x0, z0):
				continue
			var cy := S + 2.25      # where the cove leaves the wall
			if not _is_open(i - 1, j):
				arch._q("sewer", Vector3(x0, cy, z0), Vector3(x0, cy, z1), Vector3(x0 + 0.95, TOP, z1), Vector3(x0 + 0.95, TOP, z0), Vector3(1.0, -1.0, 0.0))
				b.box("sewer_trim", x0, x0 + 0.14, S, S + 0.45, z0, z1, false, false)
			if not _is_open(i + 1, j):
				arch._q("sewer", Vector3(x1, cy, z0), Vector3(x1, cy, z1), Vector3(x1 - 0.95, TOP, z1), Vector3(x1 - 0.95, TOP, z0), Vector3(-1.0, -1.0, 0.0))
				b.box("sewer_trim", x1 - 0.14, x1, S, S + 0.45, z0, z1, false, false)
			if not _is_open(i, j - 1):
				arch._q("sewer", Vector3(x0, cy, z0), Vector3(x1, cy, z0), Vector3(x1, TOP, z0 + 0.95), Vector3(x0, TOP, z0 + 0.95), Vector3(0.0, -1.0, 1.0))
				b.box("sewer_trim", x0, x1, S, S + 0.45, z0, z0 + 0.14, false, false)
			if not _is_open(i, j + 1):
				arch._q("sewer", Vector3(x0, cy, z1), Vector3(x1, cy, z1), Vector3(x1, TOP, z1 - 0.95), Vector3(x0, TOP, z1 - 0.95), Vector3(0.0, -1.0, -1.0))
				b.box("sewer_trim", x0, x1, S, S + 0.45, z1 - 0.14, z1, false, false)
	# brick ribs across the long tunnels, one every 8 m: they are what tells you how far the dark goes
	var z := -100.0
	while z < -40.0:
		_rib(-66.0, -62.0, z, true)
		z += 8.0
	var x := -86.0
	while x < -36.0:
		if absf(x + 64.0) > 3.0 and absf(x + 36.0) > 3.0:
			_rib(-42.0, -38.0, x, false)
		x += 8.0
	z = -56.0
	while z < -34.0:
		_rib(-38.0, -34.0, z, true)
		z += 8.0
	b.base_y = -1000.0


## an arch rib across a 4 m tunnel: a0..a1 is the tunnel's width, `at` where along it; along_z: the tunnel runs along z
func _rib(a0: float, a1: float, at: float, along_z: bool) -> void:
	var w := 0.22
	for q: Array in [[a0, a0 + 0.3, S, S + 2.3], [a1 - 0.3, a1, S, S + 2.3], [a0, a1, TOP - 0.28, TOP]]:
		if along_z:
			b.box("sewer_trim", q[0], q[1], q[2], q[3], at - w, at + w, false, false)
		else:
			b.box("sewer_trim", at - w, at + w, q[2], q[3], q[0], q[1], false, false)
	for k in 2:      # the haunches
		var p0: float = a0 + 0.3 if k == 0 else a1 - 0.3
		var p1: float = a0 + 1.15 if k == 0 else a1 - 1.15
		var inward := 1.0 if k == 0 else -1.0
		if along_z:
			arch._q("sewer_trim", Vector3(p0, S + 2.3, at - w), Vector3(p0, S + 2.3, at + w), Vector3(p1, TOP - 0.28, at + w), Vector3(p1, TOP - 0.28, at - w), Vector3(inward, -1.0, 0.0))
		else:
			arch._q("sewer_trim", Vector3(at - w, S + 2.3, p0), Vector3(at + w, S + 2.3, p0), Vector3(at + w, TOP - 0.28, p1), Vector3(at - w, TOP - 0.28, p1), Vector3(0.0, -1.0, inward))


## What runs down the middle of the tunnels: a channel between two kerbs. [x0, x1, z0, z1, kerbs along z?]. The flooded branch is water wall to wall.
func _water() -> void:
	for q: Array in [[-64.8, -63.2, -104.0, -38.0, true], [-90.0, -34.0, -40.8, -39.2, false], [-36.8, -35.2, -60.0, -32.2, true]]:
		b.quad("water", Vector3(q[0], S + 0.03, q[2]), Vector3(q[1], S + 0.03, q[2]), Vector3(q[1], S + 0.03, q[3]), Vector3(q[0], S + 0.03, q[3]))
		if q[4]:
			b.box("sewer_trim", q[0] - 0.16, q[0], S, S + 0.11, q[2], q[3], false, false)
			b.box("sewer_trim", q[1], q[1] + 0.16, S, S + 0.11, q[2], q[3], false, false)
		else:
			b.box("sewer_trim", q[0], q[1], S, S + 0.11, q[2] - 0.16, q[2], false, false)
			b.box("sewer_trim", q[0], q[1], S, S + 0.11, q[3], q[3] + 0.16, false, false)
	b.quad("water", Vector3(-86.0, S + 0.09, -72.0), Vector3(-74.0, S + 0.09, -72.0), Vector3(-74.0, S + 0.09, -68.0), Vector3(-86.0, S + 0.09, -68.0))


## Pipes: a main along the long tunnel's west wall and the cross tunnel's north, a thinner pair opposite, and the pump they all come from
func _pipes() -> void:
	b.base_y = S
	_pipe_z(-65.72, S + 2.0, -103.0, -43.0, 0.16, "pipe")
	_pipe_z(-62.24, S + 1.5, -95.0, -43.0, 0.07, "castiron")
	_pipe_z(-62.24, S + 1.72, -95.0, -43.0, 0.07, "castiron")
	_pipe_x(-37.72, S + 2.0, -61.0, -44.0, 0.16, "pipe")
	_pipe_x(-37.72, S + 2.0, -89.0, -67.0, 0.16, "pipe")
	_pipe_z(-37.76, S + 2.0, -59.0, -43.5, 0.12, "pipe")
	for q: Array in [[-65.72, -78.0], [-65.72, -52.0], [-37.76, -50.0]]:      # valve wheels
		b.box("castiron", q[0] + 0.14, q[0] + 0.3, S + 1.96, S + 2.04, q[1] - 0.03, q[1] + 0.03, false)
		_wheel(q[0] + 0.3, S + 2.0, q[1], 0.2, 0.035, "sign_a")
	# outfalls in the walls: a collar, a black mouth, the stain under it
	for q: Array in [[-62.0, -70.0, -1.0], [-62.0, -48.0, -1.0], [-66.0, -88.0, 1.0], [-38.0, -46.0, 1.0]]:
		var x: float = q[0]
		var d: float = q[2]
		b.box("sewer_trim", x, x + d * 0.12, S + 0.7, S + 1.5, q[1] - 0.4, q[1] + 0.4, false)
		b.box("void", x + d * 0.12, x + d * 0.125, S + 0.8, S + 1.4, q[1] - 0.3, q[1] + 0.3, false)
		b.box("slime", x + d * 0.01, x + d * 0.02, S, S + 0.8, q[1] - 0.22, q[1] + 0.22, false)
	# the pump room: the engine on its bed, its flywheel, the riser through the roof, a board of dead gauges and one set that is on
	b.box("sewer_trim", -38.0, -34.0, S, S + 0.25, -65.8, -62.8)
	b.box("shutter", -37.4, -34.6, S + 0.25, S + 1.7, -65.4, -63.2)      # the housing: louvred iron, rusted shut
	b.box("castiron", -37.5, -34.5, S + 0.25, S + 0.45, -65.5, -63.1, false, false)
	b.box("castiron", -37.5, -34.5, S + 1.62, S + 1.74, -65.5, -63.1, false)
	for k in 3:      # three cylinder heads, a bolt at each corner
		var hx := -36.9 + k * 0.85
		b.box("pipe", hx - 0.3, hx + 0.3, S + 1.74, S + 2.15, -64.75, -63.85, false, false)
		b.box("castiron", hx - 0.34, hx + 0.34, S + 2.15, S + 2.22, -64.8, -63.8, false)
		for q: Array in [[-0.27, -64.72], [0.27, -64.72], [-0.27, -63.88], [0.27, -63.88]]:
			b.box("castiron", hx + q[0] - 0.035, hx + q[0] + 0.035, S + 2.22, S + 2.28, q[1] - 0.035, q[1] + 0.035, false, false)
	b.box("sign_c", -36.4, -35.6, S + 0.95, S + 1.2, -63.2, -63.18, false)      # the maker's plate
	_wheel(-34.45, S + 1.0, -64.3, 0.62, 0.1, "castiron")
	b.box("castiron", -34.56, -34.34, S + 0.9, S + 1.1, -64.4, -64.2, false)
	b.box("pipe", -34.95, -34.65, S + 2.2, TOP, -65.2, -64.9, false, false)
	b.box("rust", -41.6, -41.2, S + 0.6, S + 1.0, -66.0, -60.0, false)
	b.box("castiron", -41.94, -41.86, S + 1.1, S + 2.1, -64.6, -62.6, false)
	for k in 5:
		b.box("window", -41.86, -41.84, S + 1.6, S + 1.9, -64.45 + k * 0.38, -64.2 + k * 0.38, false)
	b.base_y = -1000.0
	lv._tv(-41.4, S, -61.2)


## a wheel standing in the y-z plane at x: a ring of eight blocks and a hub
func _wheel(x: float, y: float, z: float, r: float, t: float, tag: String) -> void:
	for k in 8:
		var a := k * TAU / 8.0
		b.box(tag, x - t * 0.5, x + t * 0.5, y + cos(a) * r - t, y + cos(a) * r + t, z + sin(a) * r - t, z + sin(a) * r + t, false)
	b.box(tag, x - t * 0.5, x + t * 0.5, y - t, y + t, z - r, z + r, false)
	b.box(tag, x - t * 0.5, x + t * 0.5, y - r, y + r, z - t, z + t, false)


## a pipe along z at (x, y), on brackets; r its half width
func _pipe_z(x: float, y: float, z0: float, z1: float, r: float, tag: String) -> void:
	b.box(tag, x - r, x + r, y - r * 0.42, y + r * 0.42, z0, z1, false)      # (two flats crossed: eight sides, near enough round in this light)
	b.box(tag, x - r * 0.42, x + r * 0.42, y - r, y + r, z0, z1, false)
	b.box(tag, x - r * 0.75, x + r * 0.75, y - r * 0.75, y + r * 0.75, z0, z1, false)
	var z := z0 + 1.5
	while z < z1:
		b.box("castiron", x - r - 0.03, x + r + 0.03, y - r - 0.03, y + r + 0.03, z - 0.05, z + 0.05, false)
		z += 4.0


func _pipe_x(z: float, y: float, x0: float, x1: float, r: float, tag: String) -> void:
	b.box(tag, x0, x1, y - r * 0.42, y + r * 0.42, z - r, z + r, false)
	b.box(tag, x0, x1, y - r, y + r, z - r * 0.42, z + r * 0.42, false)
	b.box(tag, x0, x1, y - r * 0.75, y + r * 0.75, z - r * 0.75, z + r * 0.75, false)
	var x := x0 + 1.5
	while x < x1:
		b.box("castiron", x - 0.05, x + 0.05, y - r - 0.03, y + r + 0.03, z - r - 0.03, z + r + 0.03, false)
		x += 4.0


## Dead ends and what has washed up at them: falls of brick, bars across the outfall and across the cabled branch, the rungs you came down, the city's rubbish
func _things() -> void:
	arch.heap(-88.0, -13.5, 2.0, S, "sewer")
	arch.heap(-88.0, -16.5, 1.6, S, "sewer")
	arch.heap(-84.8, -70.0, 1.8, S, "sewer")
	_bars(-66.0, -62.0, -102.0)
	_bars(-38.0, -34.0, -28.1, UnderfointLevel.SLAB)      # (just inside the grate's far edge and solid all the way down the shaft: with the floor behind them in reach he caught that ledge as he fell and climbed out)
	b.base_y = S
	for k in 9:      # the rungs under the drain, and the round of daylight they go up into
		b.box("rust", -80.0, -79.86, S + 0.35 + k * 0.36, S + 0.39 + k * 0.36, -100.95, -100.25, false)
	b.box("void", -79.4, -78.2, TOP - 0.02, TOP - 0.01, -101.2, -100.0, false)
	b.base_y = -1000.0
	lv._light(Vector3(-78.9, TOP - 0.5, -100.6), Color("a8c0ff"), 1.1, 6.0)
	var d: UfDistrict = lv.district
	d.prop("trashbag", -64.9, S, -100.9, 0.4)
	d.prop("trashbag", -63.2, S, -101.3, 2.0, 0.9)
	d.prop("old_tyre", -64.0, S + 0.1, -100.6, 0.0, 1.0, Vector3(1.35, 0.0, 0.2))
	d.prop("Barrel_01", -80.5, S - 0.12, -70.2, 0.6, 1.0, Vector3(1.2, 0.0, 0.3))
	d.prop("trashbag", -78.0, S - 0.1, -69.2, 1.2)
	d.prop("old_tyre", -36.9, S + 0.08, -33.4, 0.0, 1.0, Vector3(PI * 0.5, 0.0, 0.0))
	d.prop("trashbag", -89.0, S, -39.0, 2.6)
	for q: Array in [[-63.0, -60.0], [-50.0, -38.6], [-35.0, -47.0], [-76.0, -41.4]]:      # roots have found the joints in the roof here too
		for k in 7:
			var w := rng.randf_range(0.012, 0.03)
			b.turned("root", q[0] + rng.randf_range(-0.9, 0.9), q[1] + rng.randf_range(-0.9, 0.9), w, w, TOP - rng.randf_range(0.5, 1.9), TOP, rng.randf() * TAU, Vector2(rng.randf_range(-0.15, 0.15), rng.randf_range(-0.15, 0.15)))


## bars across a tunnel at z, from x0 to x1: one collider, a rod every 0.4 m, two flats tying them
func _bars(x0: float, x1: float, z: float, bottom: float = S) -> void:
	var x := x0 + 0.2
	while x < x1:
		b.box("rust", x - 0.035, x + 0.035, S, TOP, z - 0.035, z + 0.035, false)
		x += 0.4
	for y: float in [S + 0.9, S + 2.4]:
		b.box("rust", x0, x1, y - 0.04, y + 0.04, z - 0.05, z + 0.05, false)
	b.world.add({"kind": "box", "cx": (x0 + x1) * 0.5, "cz": z, "hx": (x1 - x0) * 0.5, "hz": 0.1, "bottom": bottom, "top": TOP, "tag": "bars", "no_cam": true})


## The rotten grate over the shaft: a frame and its bars, one gone, as a thing of its own so the level can shake it and let it fall
func _grate() -> void:
	grate = b.world.add({"kind": "box", "cx": -36.0, "cz": -30.0, "hx": 2.0, "hz": 2.0, "bottom": S - 0.2, "top": S, "tag": "grate"})
	grate_node = Node3D.new()
	grate_node.name = "rotten_grate"
	grate_node.position = Vector3(-36.0, S, -30.0)
	lv.add_child(grate_node)
	var g := UfBuild.new(b.world)
	g.mats["rust"] = b.mats["rust"]
	for q: Array in [[-2.0, -1.88, -2.0, 2.0], [1.88, 2.0, -2.0, 2.0], [-2.0, 2.0, -2.0, -1.88], [-2.0, 2.0, 1.88, 2.0], [-2.0, 2.0, -0.06, 0.06]]:
		g.box("rust", q[0], q[1], -0.14, 0.0, q[2], q[3], false)
	var k := 0
	var x := -1.76
	while x < 1.8:
		if k != 6:      # (one bar rusted through already: the first thing wrong with it, if you look)
			g.box("rust", x - 0.035, x + 0.035, -0.1, -0.01, -1.9, 1.9, false)
		x += 0.22
		k += 1
	g.commit(grate_node)
	# the shaft under it, seen through the bars: FOINT's slab, wet, and the green coming up
	b.base_y = -1000.0
	for q: Array in [[HOLE[0] - 0.02, HOLE[0], HOLE[2], HOLE[3]], [HOLE[1], HOLE[1] + 0.02, HOLE[2], HOLE[3]], [HOLE[0], HOLE[1], HOLE[2] - 0.02, HOLE[2]], [HOLE[0], HOLE[1], HOLE[3], HOLE[3] + 0.02]]:
		b.box("sewer_trim", q[0], q[1], S - 0.6, S - 0.14, q[2], q[3], false)


## Lamps: caged bulbs on the roof, sodium and tired, and the one that is not a lamp: the green under the grate
func _lamps() -> void:
	for q: Array in [[-77.0, -98.4], [-64.0, -96.0], [-64.0, -80.0], [-64.0, -62.0], [-64.0, -44.0], [-50.0, -40.0], [-78.0, -40.0], [-88.0, -26.0], [-78.0, -70.0], [-36.0, -52.0], [-36.0, -62.0]]:
		b.box("castiron", q[0] - 0.2, q[0] + 0.2, TOP - 0.06, TOP, q[1] - 0.2, q[1] + 0.2, false)
		b.box("lamp", q[0] - 0.09, q[0] + 0.09, TOP - 0.3, TOP - 0.06, q[1] - 0.09, q[1] + 0.09, false)
		for s: float in [-0.13, 0.13]:      # the cage
			b.box("castiron", q[0] + s - 0.012, q[0] + s + 0.012, TOP - 0.36, TOP - 0.06, q[1] - 0.14, q[1] + 0.14, false)
			b.box("castiron", q[0] - 0.14, q[0] + 0.14, TOP - 0.36, TOP - 0.06, q[1] + s - 0.012, q[1] + s + 0.012, false)
		var l := lv._light(Vector3(q[0], TOP - 0.7, q[1]), Color("ffb46b"), 1.5, 10.0)
		if int(q[0] + q[1]) % 3 == 0:
			lv.lamps.append(l)      # some of them are on their way out
	lv._light(Vector3(-36.0, S - 1.5, -30.0), Color("58ff8a"), 1.6, 9.0)
