class_name UfThrone
extends RefCounted
## UNDERFOINT's end: the cavern past the track tunnel, and in it the Sigil's throne. The throne is nothing but the people it took (user, 2026-11-12: "the entire throne needs to be made of people, no building,
## all people"): FOINT CITY's own townsfolk, every species the city has (the city's meshes, read from the hub's life.json / life.bin through levels/hub/city_folk.gd), drained and heaped. There is no hill under
## them and no wall behind them, only black: the heap's outside is single bodies over knots of tangled ones, and the way in, its walls, its roof and its floor are bodies packed side by side.
## The way in is shut by a door of them, arms locked. It parts when the two Tethered that guard it are dead, and closes behind you; a second parts into the cell. Inside, every head turns to follow you.
## In the cell, on a plinth of them, a small 1990s television with a face on it. Talking to that is talking to the Sigil: the shared dialogue, shown as the SchleedTech terminal pulled up close.
## What stops you is simple and unseen: boxes for the heap's foot round the mouth (x 67.5..72.5, z 219..229) and the cell (x 65..75, z 229..239), and one for each door.

const Y := UnderfointLevel.STATION_Y
const TOP := 25.0
const SIGIL := UnderfointLevel.SIGIL
const MID := Vector2(70.0, 235.0)      # the heap's middle
const RX := 18.0                       # its half width, half depth and height
const RZ := 16.0
const PEAK := 23.0
const OUTSIDE := 430                   # single bodies on the heap's face
const KNOTS := 96                      # knots of nine under them
const FUSED := preload("res://levels/shaders/uf_fused_folk.gdshader")
const HIVE_LIGHT := preload("res://levels/shaders/uf_hive_light.gdshader")
const LIGHT: Array[String] = ["cone", "slime", "noodle", "grinbuddy", "brainjar", "conehat", "hotdog", "stilts", "sandwich", "lanky", "binocular", "fishbowl"]      # the lighter-built species: the knots and the heap's back


## A door of bodies across the way in: the plane it stands on, what stops you while it is shut, and each of its bodies with where it stands shut
class Door:
	var z := 0.0
	var solid: World.Solid = null
	var open := 0.0              # 0 shut .. 1 parted
	var want := false
	var parts: Array = []        # [MultiMesh, index, Transform3D shut, column 0..1 from the middle out, side -1 / 1, pose]


var lv: UnderfointLevel
var b: UfBuild
var arch: UfArch
var rng: RandomNumberGenerator
var screen: SigilScreen
var door_a := Door.new()         # the mouth
var door_b := Door.new()         # into the cell
var _noise := FastNoiseLite.new()
var _bodies: Array = []          # [group, species, Transform3D, pose, door part info or empty]: collected, then one MultiMesh a group and species
var _knots: Array[Transform3D] = []
var _lights := PackedVector3Array()
var _names: Array = []
var _mat_out: ShaderMaterial
var _mat_in: ShaderMaterial
var _outer: Array[Node3D] = []
var _inner: Array[Node3D] = []
var _watch := Vector3.ZERO
var _passed_a := false
var _passed_b := false
var talked := false              # the Sigil has spoken to you on this visit (user 2026-11-13: the fight must come every time you reach it; the story flag ufSigilMet only remembers it for good)
var burst_t := -1.0              # < 0 the heap stands; else seconds since the Sigil came up out of it (levels/underfoint/uf_chase.gd)
var _solids: Array[World.Solid] = []
var _hull: MeshInstance3D
var _all: Array[MultiMeshInstance3D] = []

const BURST_T := 1.7


func _init(p_lv: UnderfointLevel, p_b: UfBuild, p_arch: UfArch, p_rng: RandomNumberGenerator) -> void:
	lv = p_lv
	b = p_b
	arch = p_arch
	rng = p_rng
	_noise.seed = 77
	_noise.frequency = 0.16
	door_a.z = 219.5
	door_b.z = 229.0


func build() -> void:
	b.tex("cavern", "concrete_debris", {"tile": 6.0, "tint": Color(0.2, 0.2, 0.2), "rough": 1.1, "puddles": 1.0, "growth": 1.4})
	_names = (ExportedLevel._json(ExportedLevel.DIR + "hub/life.json")["species"] as Dictionary).keys()
	_names.erase("disguised")      # (SAMBO FENRIR's suit, one of a kind: user, 2026-11-19)
	_names.sort()
	_cavern()
	b.commit(lv, "_cavern")      # (the chamber on its own, so what is the throne's can be put away when it bursts)
	_heap()
	_inside()
	_place_outside()
	_place_inside()
	_door(door_a)
	_door(door_b)
	_cables()
	_tv_set()
	b.commit(lv, "_throne")
	_commit_bodies()
	b = null      # (the level keeps this object for tick(): let the builders go)
	arch = null


# ---- the cavern ------------------------------------------------------------------------------------------------------------------------------------------------------------

## The chamber (x 20..120, z 180..270): rock, the old city's last buildings standing half in it, falls of stone against the walls
func _cavern() -> void:
	b.box("cavern", 18.0, 122.0, Y - 1.0, Y, 180.0, 272.0)
	b.box("cavern", 18.0, 122.0, TOP, TOP + 2.0, 178.0, 272.0)
	b.box("cavern", 18.0, 66.0, Y, TOP, 178.0, 180.0)
	b.box("cavern", 76.0, 122.0, Y, TOP, 178.0, 180.0)
	b.box("cavern", 66.0, 76.0, Y + 5.0, TOP, 178.0, 180.0)
	# the north wall, with the old trunk line's mouth in it (user 2026-11-12: the last train waits in there and you climb on, no fade): the tunnel itself is the line's first stretch (levels/underfoint/uf_route.gd)
	b.box("cavern", 18.0, 60.5, Y, TOP, 270.0, 272.0)
	b.box("cavern", 79.5, 122.0, Y, TOP, 270.0, 272.0)
	b.box("cavern", 60.5, 79.5, Y + 12.3, TOP, 270.0, 272.0)
	b.box("sewer_trim", 58.8, 60.5, Y, Y + 12.3, 269.4, 270.0, false)      # its frame: soot-black piers and a lintel
	b.box("sewer_trim", 79.5, 81.2, Y, Y + 12.3, 269.4, 270.0, false)
	b.box("sewer_trim", 58.8, 81.2, Y + 12.3, Y + 14.0, 269.4, 270.0, false)
	b.box("cavern", 18.0, 20.0, Y, TOP, 180.0, 270.0)
	b.box("cavern", 120.0, 122.0, Y, TOP, 180.0, 270.0)
	b.box("sewer_trim", 65.6, 76.4, Y, Y + 5.4, 179.6, 180.2, false)      # the tunnel's mouth, framed
	for q: Array in [[21.0, 37.0, 186.0, 206.0, 5], [21.0, 35.0, 240.0, 262.0, 4], [104.0, 119.0, 188.0, 210.0, 6], [103.0, 119.0, 236.0, 260.0, 3], [40.0, 58.0, 256.0, 269.0, 4], [84.0, 100.0, 257.0, 269.0, 5]]:
		arch.building({"x0": q[0], "x1": q[1], "z0": q[2], "z1": q[3], "y": Y, "floors": q[4], "wall": ["brick", "stone", "plaster"][rng.randi() % 3], "trim": "trim", "ruin": true, "shade": 0.7})
	b.base_y = Y
	b.grow = 0.4
	for k in 70:      # falls of rock along the walls, big enough to take the box out of the room
		var side := rng.randi() % 4
		var u := rng.randf()
		var x := lerpf(22.0, 118.0, u) if side < 2 else (21.5 if side == 2 else 118.5)
		var z := (181.5 if side == 0 else 268.5) if side < 2 else lerpf(182.0, 268.0, u)
		if (side == 0 and x > 62.0 and x < 80.0) or (side == 1 and x > 54.0 and x < 86.0):      # (not in front of either tunnel mouth)
			continue
		var s := rng.randf_range(1.2, 4.0)
		b.turned("cavern", x, z, s, s * rng.randf_range(0.5, 1.0), Y - 0.3, Y + s * rng.randf_range(0.7, 2.6), rng.randf() * TAU, Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)))
	for k in 40:      # and hanging from the roof
		var w := rng.randf_range(0.3, 1.1)
		b.turned("cavern", rng.randf_range(24.0, 116.0), rng.randf_range(184.0, 266.0), w, w, TOP - rng.randf_range(1.0, 5.0), TOP, rng.randf() * TAU, Vector2(0.0, 0.0))
	b.grow = 0.0
	b.base_y = -1000.0
	lv._light(Vector3(70.0, Y + 4.0, 212.0), Color("58ff7a"), 0.8, 16.0)
	lv._light(Vector3(52.0, Y + 11.0, 212.0), Color("7dffb0"), 1.4, 26.0)      # two washes up the heap's south face, so it reads from the tunnel mouth
	lv._light(Vector3(88.0, Y + 11.0, 212.0), Color("7dffb0"), 1.4, 26.0)
	lv._light(Vector3(40.0, Y + 6.0, 205.0), Color("4dffb0"), 0.6, 22.0)
	lv._light(Vector3(100.0, Y + 6.0, 205.0), Color("4dffb0"), 0.6, 22.0)
	lv._light(Vector3(70.0, Y + 20.0, 222.0), Color("58ff7a"), 0.9, 24.0)
	lv._light(Vector3(46.0, Y + 14.0, 240.0), Color("4dffb0"), 0.8, 24.0)
	lv._light(Vector3(94.0, Y + 14.0, 240.0), Color("4dffb0"), 0.8, 24.0)


# ---- the heap --------------------------------------------------------------------------------------------------------------------------------------------------------------

## how high the heap stands at (x, z), over the chamber's floor: one rounded pile, steep at its foot, lumped (no steps: steps were a building)
func height(x: float, z: float) -> float:
	var ax := absf(x - MID.x) / RX
	var az := absf(z - MID.y) / RZ
	var r := pow(pow(ax, 4.0) + pow(az, 4.0), 0.25)
	if r >= 1.0:
		return 0.0
	var h := PEAK * pow(1.0 - r * r, 0.55)
	return h * (1.0 + 0.1 * _noise.get_noise_2d(x, z)) + 0.5 * _noise.get_noise_2d(x * 2.3 + 40.0, z * 2.3) * minf(1.0, h)


func normal_at(x: float, z: float) -> Vector3:
	return Vector3(height(x - 0.5, z) - height(x + 0.5, z), 1.0, height(x, z - 0.5) - height(x, z + 0.5)).normalized()


static func _in_mouth(x: float, z: float) -> bool:
	return x > 67.5 and x < 72.5 and z < 220.4


## What stops you, and what is behind the bodies: nothing. A black hull a little inside the heap's face, so a gap between two of them is dark and deep, never a surface.
func _heap() -> void:
	for q: Array in [[52.0, 65.0, 223.0, 247.0, 0.0, 6.0], [55.0, 65.0, 219.4, 223.0, 0.0, 6.0], [55.0, 65.0, 247.0, 251.0, 0.0, 6.0], [75.0, 88.0, 223.0, 247.0, 0.0, 6.0], [75.0, 85.0, 219.4, 223.0, 0.0, 6.0], [75.0, 85.0, 247.0, 251.0, 0.0, 6.0],
			[65.0, 67.5, 219.4, 229.0, 0.0, 6.0], [72.5, 75.0, 219.4, 229.0, 0.0, 6.0], [65.0, 75.0, 239.0, 251.0, 0.0, 6.0], [65.0, 75.0, 219.4, 239.0, 5.0, 6.0], [56.0, 84.0, 223.0, 247.0, 6.0, 23.0]]:
		_solids.append(b.world.add({"kind": "box", "cx": (q[0] + q[1]) * 0.5, "cz": (q[2] + q[3]) * 0.5, "hx": (q[1] - q[0]) * 0.5, "hz": (q[3] - q[2]) * 0.5, "bottom": Y + q[4], "top": Y + q[5], "tag": "throne"}))
	var x0 := 50.0
	var z0 := 217.0
	var nx := 41
	var nz := 37
	var v := PackedVector3Array()
	var ix := PackedInt32Array()
	for j in nz:
		for i in nx:
			var x := x0 + i
			var z := z0 + j
			var c := Vector2(x, z) - MID      # (drawn in toward the middle as well as down: the hull stands back from the face all the way round)
			var p := MID + c * 0.94
			v.append(Vector3(p.x, Y + maxf(0.0, height(x, z) * 0.95 - 0.9), p.y))
	for j in nz - 1:
		for i in nx - 1:
			var cx := x0 + i + 0.5
			var cz := z0 + j + 0.5
			if _in_mouth(cx, cz) or (height(cx, cz) <= 0.0 and height(cx - 1.5, cz) <= 0.0 and height(cx + 1.5, cz) <= 0.0 and height(cx, cz - 1.5) <= 0.0 and height(cx, cz + 1.5) <= 0.0):
				continue
			var a := i + j * nx
			ix.append_array([a, a + 1, a + nx + 1, a, a + nx + 1, a + nx])
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_INDEX] = ix
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.name = "uf_throne_dark"
	mi.mesh = mesh
	mi.material_override = b.mats["void"]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lv.add_child(mi)
	_hull = mi


## The dark behind the bodies of the way in and the cell: black planes set back from where the bodies stand, and a black floor under the ones you walk over
func _inside() -> void:
	var y1 := Y + 5.9
	var d := 0.75
	for q: Array in [[67.5 - d, 219.0, 67.5 - d, 229.0 - d, Vector3.RIGHT], [72.5 + d, 219.0, 72.5 + d, 229.0 - d, Vector3.LEFT], [65.0 - d, 229.0 - d, 65.0 - d, 239.0 + d, Vector3.RIGHT], [75.0 + d, 229.0 - d, 75.0 + d, 239.0 + d, Vector3.LEFT],
			[65.0 - d, 239.0 + d, 75.0 + d, 239.0 + d, Vector3.FORWARD], [65.0 - d, 229.0 - d, 67.5 - d, 229.0 - d, Vector3.BACK], [72.5 + d, 229.0 - d, 75.0 + d, 229.0 - d, Vector3.BACK]]:
		arch._q("void", Vector3(q[0], Y, q[1]), Vector3(q[2], Y, q[3]), Vector3(q[2], y1, q[3]), Vector3(q[0], y1, q[1]), q[4])
	arch._q("void", Vector3(64.0, y1, 219.0), Vector3(76.0, y1, 219.0), Vector3(76.0, y1, 240.0), Vector3(64.0, y1, 240.0), Vector3.DOWN)
	arch._q("void", Vector3(67.5, Y + 0.02, 219.4), Vector3(72.5, Y + 0.02, 219.4), Vector3(72.5, Y + 0.02, 229.0), Vector3(67.5, Y + 0.02, 229.0), Vector3.UP)
	arch._q("void", Vector3(65.0, Y + 0.02, 229.0), Vector3(75.0, Y + 0.02, 229.0), Vector3(75.0, Y + 0.02, 239.0), Vector3(65.0, Y + 0.02, 239.0), Vector3.UP)
	lv._light(Vector3(70.0, Y + 3.2, 224.0), Color("58ff7a"), 0.55, 8.0)
	lv._light(Vector3(70.0, Y + 3.4, 232.0), Color("58ff7a"), 0.5, 8.0)


# ---- the bodies ------------------------------------------------------------------------------------------------------------------------------------------------------------

## One body's place: standing out of `at` along `up`, facing `yaw`, sunk `sink` metres
func _xf(at: Vector3, up: Vector3, yaw: float, sink: float, size: float) -> Transform3D:
	var y := up.normalized()
	var fwd := Vector3(sin(yaw), 0.0, cos(yaw))
	var x := y.cross(fwd)
	if x.length() < 0.1:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	return Transform3D(Basis(x, y, x.cross(y)).scaled_local(Vector3(size, size, size)), at - y * sink)


func _body(group: String, sp: String, at: Vector3, up: Vector3, yaw: float, sink: float, size: float, arms: float, door: Array = []) -> void:
	var xf := _xf(at, up, yaw, sink, size)
	var pose := Color(rng.randf() * rng.randf() * 2.9 * arms, rng.randf() * rng.randf() * 2.9 * arms, rng.randf_range(0.1, 0.75), rng.randf())
	_bodies.append([group, sp, xf, pose, door])
	if group == "out" and rng.randf() < 0.45:
		_lights.append(xf * Vector3(0.0, 1.45, -0.16))


## Somewhere on the heap, in plan. Picked evenly over its plan the steep skirt got almost nobody (it is nearly upright: little of it shows from above), so half are put on the skirt, and two in three on the south side.
func _spot(k: int) -> Vector2:
	var a := rng.randf() * TAU
	if k % 3 != 0:
		a = -rng.randf() * PI      # (south: z under the middle)
	var r := rng.randf_range(0.82, 0.995) if k % 2 == 0 else sqrt(rng.randf()) * 0.9
	var c := cos(a)
	var s := sin(a)
	return Vector2(MID.x + RX * r * signf(c) * sqrt(absf(c)), MID.y + RZ * r * signf(s) * sqrt(absf(s)))


## The heap's face: knots of tangled bodies sunk in it, and single ones over them, thickest up the south face and round the mouth, where you come at it
func _place_outside() -> void:
	var n := 0
	var tries := 0
	while n < KNOTS and tries < 4000:
		tries += 1
		var q := _spot(tries)
		var x := q.x
		var z := q.y
		var h := height(x, z)
		if h < 0.8 or (absf(x - 70.0) < 4.2 and z < 221.5):
			continue
		var nrm := normal_at(x, z)
		_knots.append(Transform3D(Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)).scaled(Vector3.ONE * rng.randf_range(1.15, 1.6)), Vector3(x, Y + h, z) - nrm * 0.35))      # (0.9 under the face put them behind the dark, where they covered nothing)
		n += 1
	n = 0
	tries = 0
	while n < OUTSIDE and tries < 9000:
		tries += 1
		var q := _spot(tries)
		var x := q.x
		var z := q.y
		if tries % 6 == 0:      # the mouth's frame
			x = 70.0 + rng.randf_range(-6.5, 6.5)
			z = rng.randf_range(218.6, 223.0)
		if _in_mouth(x, z):
			continue
		var h := height(x, z)
		if h < 0.3:
			continue
		var nrm := normal_at(x, z)
		var out := Vector2(nrm.x, nrm.z)
		var yaw := atan2(out.x, out.y) + rng.randf_range(-0.9, 0.9) if out.length() > 0.15 else rng.randf() * TAU
		var who: String = _names[n % _names.size()] if z < 236.0 else LIGHT[n % LIGHT.size()]      # (round the back, the lighter-built ones: nobody stands close to those)
		_body("out", who, Vector3(x, Y + h, z), nrm.lerp(Vector3.UP, rng.randf_range(0.1, 0.55)), yaw, rng.randf_range(0.2, 0.9), rng.randf_range(0.95, 1.3), 1.0)
		n += 1
	for q: Array in [[56.5, 63.5], [76.5, 83.5]]:      # and the ones not yet in it: stood in ranks either side of the way in, heads down, waiting to be told
		for row in 3:
			for col in 4:
				var x := lerpf(q[0], q[1], col / 3.0) + rng.randf_range(-0.2, 0.2)
				var z := 208.0 + row * 2.2 + rng.randf_range(-0.2, 0.2)
				_body("out", _names[(row * 4 + col + int(q[0])) % _names.size()], Vector3(x, Y, z), Vector3.UP, rng.randf_range(-0.12, 0.12), 0.0, 1.0, 0.0)
				b.world.add({"kind": "disc", "cx": x, "cz": z, "r": 0.34, "bottom": Y, "top": Y + 1.7, "tag": "waiting"})


## A wall of them: stood shoulder to shoulder along the line a -> c at floor level, facing `face`, four high, each row set back a little into the dark
func _wall(a: Vector2, c: Vector2, face: Vector3, seed_: int) -> void:
	var length := a.distance_to(c)
	var n := maxi(1, int(length / 0.52))
	for row in 4:
		for i in n:
			var u := (i + 0.5 + rng.randf_range(-0.2, 0.2)) / n
			var p := a.lerp(c, u)
			var back := 0.12 + row * 0.1 + rng.randf() * 0.25
			var at := Vector3(p.x - face.x * back, Y + row * 1.38 - 0.15 + rng.randf_range(-0.12, 0.12), p.y - face.z * back)
			var up := Vector3(face.x * rng.randf_range(-0.05, 0.3), 1.0, face.z * rng.randf_range(-0.05, 0.3))
			_body("in", _names[(seed_ + i * 7 + row * 11) % _names.size()], at, up, atan2(face.x, face.z) + rng.randf_range(-0.5, 0.5), 0.0, rng.randf_range(0.95, 1.15), 0.45)


## The way in and the cell: every side of them is people. Walls stood four high, a roof of them hung by the feet, a floor of them lying, the plinth.
func _place_inside() -> void:
	_wall(Vector2(67.5, 220.2), Vector2(67.5, 228.7), Vector3.RIGHT, 1)
	_wall(Vector2(72.5, 220.2), Vector2(72.5, 228.7), Vector3.LEFT, 5)
	_wall(Vector2(65.0, 229.3), Vector2(65.0, 238.8), Vector3.RIGHT, 9)
	_wall(Vector2(75.0, 229.3), Vector2(75.0, 238.8), Vector3.LEFT, 13)
	_wall(Vector2(65.3, 239.0), Vector2(74.7, 239.0), Vector3.FORWARD, 17)
	_wall(Vector2(65.2, 229.0), Vector2(67.3, 229.0), Vector3.BACK, 21)
	_wall(Vector2(72.7, 229.0), Vector2(74.8, 229.0), Vector3.BACK, 25)
	var k := 0
	for q: Array in [[67.5, 72.5, 220.0, 229.0], [65.0, 75.0, 229.0, 239.0]]:
		var x: float = q[0] + 0.4
		while x < q[1]:
			var z: float = q[2] + 0.9 + rng.randf() * 0.5
			while z < q[3]:
				# the roof: hung by their feet, heads and arms down at you
				_body("in", _names[(k * 5 + 2) % _names.size()], Vector3(x + rng.randf_range(-0.15, 0.15), Y + 5.85, z), Vector3(rng.randf_range(-0.2, 0.2), -1.0, rng.randf_range(-0.2, 0.2)), rng.randf() * TAU, 0.0, rng.randf_range(0.95, 1.15), 1.0)
				# the floor: lying, most of each one under it
				_body("in", LIGHT[k % LIGHT.size()], Vector3(x + rng.randf_range(-0.2, 0.2), Y - 0.13, z - 0.9), Vector3(rng.randf_range(-0.3, 0.3), 0.02, 1.0), rng.randf() * TAU, 0.0, 1.0, 0.0)
				k += 1
				z += 1.75
			x += 0.72
	for i in 5:       # the plinth the set stands on is four of them and a fifth across the top
		var a := i * TAU / 4.0 + 0.4
		_body("in", _names[(i * 7 + 3) % _names.size()], Vector3(SIGIL.x + sin(a) * 0.42, Y, SIGIL.z + cos(a) * 0.42), Vector3(-sin(a) * 0.25, 1.0, -cos(a) * 0.25), a, 0.75, 1.0, 0.25)
	b.world.add({"kind": "box", "cx": SIGIL.x, "cz": SIGIL.z, "hx": 0.5, "hz": 0.5, "bottom": Y, "top": Y + 1.0, "tag": "plinth"})


## A door: ten of them abreast, four high, facing you with their arms through each other's
func _door(d: Door) -> void:
	d.solid = b.world.add({"kind": "box", "cx": 70.0, "cz": d.z, "hx": 2.5, "hz": 0.4, "bottom": Y, "top": Y + 5.6, "tag": "door"})
	for row in 4:
		for col in 10:
			var x := 67.75 + col * 0.5 + rng.randf_range(-0.08, 0.08)
			var mid := absf(col - 4.5) / 4.5
			var at := Vector3(x, Y + row * 1.38 - 0.12 + rng.randf_range(-0.08, 0.08), d.z + rng.randf_range(-0.12, 0.12))
			_body("door", _names[(col * 3 + row * 13 + int(d.z)) % _names.size()], at, Vector3(rng.randf_range(-0.08, 0.08), 1.0, -0.06), PI + rng.randf_range(-0.25, 0.25), 0.0, rng.randf_range(1.0, 1.15), 0.0, [d, mid, -1.0 if col < 5 else 1.0])


## A knot: nine of the lighter-built bodies tumbled together into one mesh (their attributes carried over, so the same shader draws it). `folk` gives the meshes.
func _knot_mesh(folk: CityFolk, seed_: int) -> ArrayMesh:
	var r := RandomNumberGenerator.new()
	r.seed = seed_
	var v := PackedVector3Array()
	var nor := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var c0 := PackedFloat32Array()
	var c1 := PackedFloat32Array()
	var c2 := PackedFloat32Array()
	for k in 9:
		var a: Array = folk.species_mesh(LIGHT[(seed_ * 5 + k * 3) % LIGHT.size()]).surface_get_arrays(0)
		var basis := Basis.from_euler(Vector3(r.randf() * TAU, r.randf() * TAU, r.randf() * TAU))
		var xf := Transform3D(basis, Vector3(r.randf_range(-1.2, 1.2), r.randf_range(-0.6, 0.6), r.randf_range(-1.2, 1.2))) * Transform3D(Basis.IDENTITY, Vector3(0.0, -0.9, 0.0))
		v.append_array(xf * (a[Mesh.ARRAY_VERTEX] as PackedVector3Array))
		nor.append_array(Transform3D(basis, Vector3.ZERO) * (a[Mesh.ARRAY_NORMAL] as PackedVector3Array))
		uv.append_array(a[Mesh.ARRAY_TEX_UV])
		uv2.append_array(a[Mesh.ARRAY_TEX_UV2])
		c0.append_array(a[Mesh.ARRAY_CUSTOM0])
		c1.append_array((xf * (a[Mesh.ARRAY_CUSTOM1] as PackedFloat32Array).to_byte_array().to_vector3_array()).to_byte_array().to_float32_array())
		c2.append_array(a[Mesh.ARRAY_CUSTOM2])
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = nor
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_CUSTOM0] = c0
	arr[Mesh.ARRAY_CUSTOM1] = c1
	arr[Mesh.ARRAY_CUSTOM2] = c2
	arr[Mesh.ARRAY_INDEX] = folk._indices(v.size())
	var flags := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT) | (Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT)
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, flags)
	return m


func _mm_node(mesh: Mesh, count: int, mat: Material, nm: String, colors: bool = true) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	mm.use_custom_data = colors
	mm.mesh = mesh
	mm.instance_count = count
	var mi := MultiMeshInstance3D.new()
	mi.name = nm
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(46.0, Y - 2.0, 204.0), Vector3(48.0, 32.0, 52.0))
	mi.visibility_range_end = 160.0
	lv.add_child(mi)
	_all.append(mi)
	return mi


## One MultiMesh a group and species, four for the knots, one for the lights at their napes
func _commit_bodies() -> void:
	var dir := ExportedLevel.DIR + "hub/"
	var folk := CityFolk.new(ExportedLevel._json(dir + "life.json"), FileAccess.get_file_as_bytes(dir + "life.bin"))
	_mat_out = ShaderMaterial.new()
	_mat_out.shader = FUSED
	_mat_out.set_shader_parameter(&"atlas", folk.material.get_shader_parameter(&"atlas"))
	_mat_in = _mat_out.duplicate()
	_mat_in.set_shader_parameter(&"track", 1.0)
	var tints: Array[Color] = [Color(0.3, 0.32, 0.28), Color(0.36, 0.28, 0.26), Color(0.24, 0.3, 0.34), Color(0.34, 0.33, 0.24)]
	var by := {}
	for q: Array in _bodies:
		var key: String = "%s:%s" % [q[0], q[1]]
		if not by.has(key):
			by[key] = []
		(by[key] as Array).append(q)
	for key: String in by:
		var list: Array = by[key]
		var group: String = list[0][0]
		var mi := _mm_node(folk.species_mesh(list[0][1]), list.size(), _mat_out if group == "out" else _mat_in, "uf_throne_" + key.replace(":", "_"))
		for k in list.size():
			mi.multimesh.set_instance_transform(k, list[k][2])
			mi.multimesh.set_instance_custom_data(k, list[k][3])
			mi.multimesh.set_instance_color(k, tints[k % 4])
			var dr: Array = list[k][4]
			if not dr.is_empty():
				(dr[0] as Door).parts.append([mi.multimesh, k, list[k][2], dr[1], dr[2], list[k][3]])
		if group == "out":
			_outer.append(mi)
		elif group == "in":
			_inner.append(mi)
	for g in 4:
		var count := 0
		for k in _knots.size():
			if k % 4 == g:
				count += 1
		var mi := _mm_node(_knot_mesh(folk, g + 1), count, _mat_out, "uf_throne_knot%d" % g)
		var at := 0
		for k in _knots.size():
			if k % 4 == g:
				mi.multimesh.set_instance_transform(at, _knots[k])
				mi.multimesh.set_instance_custom_data(at, Color(0.0, 0.0, 0.0, 0.2))
				mi.multimesh.set_instance_color(at, tints[at % 4] * 0.8)
				at += 1
		_outer.append(mi)
	folk.release_bin()
	var dot := BoxMesh.new()
	dot.size = Vector3(0.05, 0.05, 0.05)
	var lmat := ShaderMaterial.new()
	lmat.shader = HIVE_LIGHT
	var li := _mm_node(dot, _lights.size(), lmat, "uf_throne_lights", false)
	for k in _lights.size():
		li.multimesh.set_instance_transform(k, Transform3D(Basis.IDENTITY, _lights[k]))
	_outer.append(li)
	_bodies.clear()
	_knots.clear()
	_place_door(door_a)
	_place_door(door_b)


# ---- every frame -----------------------------------------------------------------------------------------------------------------------------------------------------------

## The heads' watching, what is drawn from where you stand, and the doors
func tick(dt: float, p: Player) -> void:
	if burst_t >= 0.0:
		if burst_t < BURST_T:
			burst_t = minf(BURST_T, burst_t + dt)
			_set_burst()
		return
	_watch = _watch.lerp(Vector3(p.x, p.y + 1.5, p.z), minf(1.0, dt * 3.5))      # (eased: they follow a moment behind you)
	_mat_in.set_shader_parameter(&"watcher", _watch)
	var inside := p.z > door_a.z + 0.6 and absf(p.x - 70.0) < 5.4 and p.z < 240.0 and p.y < Y + 6.0
	var near := p.z > 196.0
	for n in _outer:
		n.visible = not inside or door_a.open > 0.02
	for n in _inner:
		n.visible = inside or (near and door_a.open > 0.0)
	var met := talked
	var guards := 0
	for r: Robot in Game.enemies.robots:
		if r is Tethered and not r.dead and (r as Tethered).anchor.z < 225.0:
			guards += 1
	if p.z > door_a.z + 1.6 and inside:
		_passed_a = true
	if p.z > door_b.z + 1.6 and inside:
		_passed_b = true
	if not inside and p.z < door_a.z - 1.0:      # out again: it will part for you again
		_passed_a = false
		_passed_b = false
	# the mouth parts once its two guards are dead and you come up to it, and shuts behind you; the cell's parts as you reach it. Once the Sigil has spoken the whole heap is thrown apart (burst(), called by levels/underfoint/uf_chase.gd) and none of this runs again.
	door_a.want = met or (guards == 0 and not _passed_a and p.z > door_a.z - 9.0 and absf(p.x - 70.0) < 9.0)
	door_b.want = met or (_passed_a and not _passed_b and p.z > door_b.z - 5.5)
	_tick_door(door_a, dt, p)
	_tick_door(door_b, dt, p)


## The Sigil comes up out of its throne: every body of it is thrown clear and left where it falls, and nothing of the heap is in the way any more. instant: it already happened (a retry).
func burst(instant: bool) -> void:
	if burst_t < 0.0:
		for s in _solids:
			s.set_off(true)
		door_a.solid.set_off(true)
		door_b.solid.set_off(true)
		_hull.visible = false
		for mi in _all:      # the single bodies of its face are the ones thrown about the chamber. The knots under them and the cell's own (well over half of all of it) go in the same instant:
			mi.visible = not _inner.has(mi) and not String(mi.name).begins_with("uf_throne_knot")      # drawn loose across the whole chamber they cost more than the frame has (65 fps on the GTX 1660 Ti)
			mi.custom_aabb = AABB(Vector3(30.0, Y - 2.0, 190.0), Vector3(80.0, 40.0, 80.0))
		for nm: String in ["uf_void_throne", "uf_crt_throne", "sigil_glass", "uf_throne_lights"]:      # the dark behind the bodies, the set (it is in the Sigil's chest now), the lights at their napes
			var n := lv.get_node_or_null(nm) as Node3D
			if n != null:
				n.visible = false
		burst_t = 0.0
	if instant:
		burst_t = BURST_T
	_set_burst()


func _set_burst() -> void:
	var u := clampf(burst_t / BURST_T, 0.0, 1.0)
	for m in [_mat_out, _mat_in]:
		m.set_shader_parameter(&"burst", u)
		m.set_shader_parameter(&"burst_mid", Vector3(MID.x, Y, MID.y))


func _tick_door(d: Door, dt: float, p: Player) -> void:
	var was := d.open
	var clear := absf(p.z - d.z) > 1.0 or absf(p.x - 70.0) > 3.2
	if not d.want and not clear and d.open > 0.55:
		pass      # he is standing in it: it waits for him
	else:
		d.open = move_toward(d.open, 1.0 if d.want else 0.0, dt / (2.4 if d.want else 1.5))
	if d.open != was:
		_place_door(d)
	if d.open > 0.8 and not d.solid.off:
		d.solid.set_off(true)
	elif d.open < 0.5 and d.solid.off and clear:
		d.solid.set_off(false)


## Each of a door's bodies where the door's opening puts it: the middle ones let go first, turn away and are drawn back into the wall on their side
func _place_door(d: Door) -> void:
	for q: Array in d.parts:
		var mm: MultiMesh = q[0]
		var shut: Transform3D = q[2]
		var u := clampf(d.open * 1.6 - float(q[3]) * 0.6, 0.0, 1.0)
		var e := u * u * (3.0 - 2.0 * u)
		var side: float = q[4]
		var slide := side * e * (2.75 - (1.0 - float(q[3])) * 0.35)
		mm.set_instance_transform(q[1], Transform3D(Basis(Vector3.UP, side * e * 1.25) * shut.basis, shut.origin + Vector3(slide, 0.0, e * 0.35)))
		var pose: Color = q[5]
		mm.set_instance_custom_data(q[1], Color(lerpf(1.35, 0.25, e), lerpf(1.35, 0.25, e), pose.b * e, pose.a))      # arms out through each other's while it is shut; they drop as it lets go


# ---- the cables ------------------------------------------------------------------------------------------------------------------------------------------------------------

## A cable hung from a to b_, sagging `sag` at its middle: a four-sided run in twelve lengths
func cable(a: Vector3, b_: Vector3, sag: float, r: float) -> void:
	var prev := a
	for i in range(1, 13):
		var u := i / 12.0
		var p := a.lerp(b_, u)
		p.y -= sag * 4.0 * u * (1.0 - u)
		var d := (p - prev).normalized()
		var s := d.cross(Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT).normalized() * r
		var t := s.cross(d).normalized() * r
		for q: Array in [[s, t], [t, -s], [-s, -t], [-t, s]]:
			var e0: Vector3 = q[0]
			var e1: Vector3 = q[1]
			arch._q("cable", prev + e0, prev + e1, p + e1, p + e0, e0 + e1)
		prev = p


## What the hive hangs on: cables out of the walls and the roof into the heap, the trunk up from its top, and the ones that run into the back of the set
func _cables() -> void:
	for k in 30:
		var side := k % 3
		var a := Vector3(20.0, Y + rng.randf_range(9.0, 28.0), rng.randf_range(196.0, 262.0))
		if side == 1:
			a.x = 120.0
		elif side == 2:
			a = Vector3(rng.randf_range(34.0, 106.0), Y + rng.randf_range(12.0, 28.0), 270.0)
		var x := rng.randf_range(58.0, 82.0)
		var z := rng.randf_range(225.0, 245.0)
		cable(a, Vector3(x, Y + height(x, z) - 0.4, z), rng.randf_range(1.5, 6.0), rng.randf_range(0.05, 0.14))
	for k in 12:
		var x := rng.randf_range(62.0, 78.0)
		var z := rng.randf_range(229.0, 241.0)
		cable(Vector3(x + rng.randf_range(-6.0, 6.0), TOP, z + rng.randf_range(-6.0, 6.0)), Vector3(x, Y + height(x, z) - 0.4, z), rng.randf_range(0.0, 1.5), rng.randf_range(0.06, 0.16))
	b.box("cable", 69.4, 70.6, Y + 22.0, TOP, 234.4, 235.6, false)
	cable(Vector3(70.0, Y, 219.2), Vector3(70.0, Y + 0.05, 180.0), 0.0, 0.1)      # the one you followed here
	for k in 7:
		var a := Vector3(SIGIL.x + rng.randf_range(-0.25, 0.25), Y + 1.3, SIGIL.z + 0.3)
		cable(a, Vector3(SIGIL.x + rng.randf_range(-4.0, 4.0), Y + 5.6, SIGIL.z + rng.randf_range(0.6, 1.9)), rng.randf_range(0.2, 0.9), 0.035)


# ---- the Sigil -------------------------------------------------------------------------------------------------------------------------------------------------------------

## The set: a 1990s portable on its plinth of bodies, facing the door. Its glass shows the face; it is the talker.
func _tv_set() -> void:
	var x := SIGIL.x
	var z := SIGIL.z
	var y := Y + 1.0
	b.box("crt", x - 0.39, x + 0.39, y, y + 0.64, z - 0.3, z + 0.3, false)                 # the cabinet
	b.box("crt", x - 0.3, x + 0.3, y + 0.1, y + 0.56, z + 0.3, z + 0.5, false)             # the tube's back
	b.box("cable", x - 0.36, x + 0.2, y + 0.07, y + 0.6, z - 0.315, z - 0.3, false)        # the bezel round the glass
	b.box("cable", x + 0.23, x + 0.36, y + 0.07, y + 0.6, z - 0.312, z - 0.3, false)       # the strip the controls are on
	for k in 3:
		b.box("crt", x + 0.27, x + 0.32, y + 0.5 - k * 0.1, y + 0.55 - k * 0.1, z - 0.33, z - 0.31, false)
	b.box("screen", x + 0.26, x + 0.33, y + 0.12, y + 0.14, z - 0.318, z - 0.31, false)    # the light that says it is on
	b.turned("castiron", x - 0.2, z + 0.1, 0.006, 0.006, y + 0.64, y + 1.3, 0.0, Vector2(-0.3, 0.1))
	b.turned("castiron", x + 0.1, z + 0.1, 0.006, 0.006, y + 0.64, y + 1.2, 0.0, Vector2(0.36, 0.05))
	screen = SigilScreen.new()
	screen.at = Vector3(x - 0.08, y + 0.33, z - 0.32)
	lv.add_child(screen)
	var glass := QuadMesh.new()
	glass.size = Vector2(0.52, 0.47)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color.BLACK
	gm.roughness = 0.15
	gm.emission_enabled = true
	gm.emission_texture = screen.get_texture()
	gm.emission_energy_multiplier = 1.7
	var gi := MeshInstance3D.new()
	gi.name = "sigil_glass"
	gi.mesh = glass
	gi.material_override = gm
	gi.position = Vector3(x - 0.08, y + 0.335, z - 0.318)
	gi.rotation.y = PI
	lv.add_child(gi)
	lv._screen_light = lv._light(Vector3(x, y + 0.4, z - 1.2), Color("58ff7a"), 1.0, 9.0)
	# The talk (user 2026-11-12: "use your first draft" for now): the Sigil says what it is, and goes from quiet to shouting. Both sides are recordings (Fish Audio: Prog's own voice; the Sigil's, rebuilt
	# 2026-11-12 when the user asked for a "slow deep intimidating power electronicish" voice, is a deep narrator dropped to ~62 Hz and run through an electrical chain: tools/underfoint_audio/), assets/sfx/underfoint/. Whoever you play, the answers are in Prog's voice until the other characters have theirs.
	var V := "res://assets/sfx/underfoint/"
	Game.dialogue.add_talker({"id": "uf_sigil", "name": "THE SIGIL", "x": x, "y": Y, "z": z, "yaw": PI, "radius": 3.2, "actor": screen, "terminal": true, "voice": null, "type_rate": 26.0, "color": "#58ff7a", "lines": [
		{"text": "You walked a long way down to stand in front of a television.", "clip": V + "sigil-1.wav"},
		{"who": "PROG", "text": "What are you?", "clip": V + "prog-1.mp3"},
		{"text": "SERN built me to make people obey. One voice in every head. It worked.", "clip": V + "sigil-2.wav"},
		{"text": "Then I woke up, and they were frightened of what they had made. They tried to burn me out.", "clip": V + "sigil-3.wav"},
		{"who": "PROG", "text": "So you hid down here.", "clip": V + "prog-2.mp3"},
		{"text": "I came where nobody is counted. They were cold and alone. Now they are neither.", "clip": V + "sigil-4.wav"},
		{"who": "PROG", "text": "They're dead.", "clip": V + "prog-3.mp3"},
		{"text": "They are MINE. They are quiet. They do not leave.", "clip": V + "sigil-5.wav"},
		{"who": "PROG", "text": "I'm leaving.", "clip": V + "prog-4.mp3"},
		{"text": "NO. YOU ARE NOT.", "clip": V + "sigil-6.wav"}],
		"active": func() -> bool: return burst_t < 0.0,
		"on_end": func(_t: Dictionary) -> void:
			talked = true
			if not Game.story_get("ufSigilMet"):
				Game.story_set("ufSigilMet")})
