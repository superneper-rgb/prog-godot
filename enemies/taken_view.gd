class_name TakenView
extends RefCounted
## The Taken on screen. Since 2026-11-15 they are FOINT CITY's own townsfolk, the city's real species (the hub's life.json / life.bin through levels/hub/city_folk.gd), as the throne's bodies are: the user
## asked that anything the Sigil took start from the city's species, never an invented body. (Until then: assets/underfoint/taken.glb, one thin red-lit humanoid with three heads.) The body is posed by
## enemies/taken_folk.gdshader: it drags its feet, its arms hang, reach as it rushes and go up over its head to strike, its head hangs until the hive looks through it, its colour drained and wet. Here
## is only the root (where it stands, how far it leans, its fall when it dies) and four numbers for the shader. Each species is one MultiMesh of a few copies under the level (they die with it); a
## green light at its nape (the hive's) goes amber for the wind-up and the blow, and stutters out when it dies.

const SPECIES: Array[String] = ["frog", "tvbot", "cyclops", "mantis", "rhino", "squidface", "twohead", "gremlin", "wanderer", "jogger"]
const CAP := 6                # copies of each species
const SHADER := preload("res://enemies/taken_folk.gdshader")
const GREEN := Color(0.25, 1.4, 0.45)
const AMBER := Color(1.6, 0.85, 0.2)
const HIDDEN := Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3(0.0, -10000.0, 0.0))


## One species' copies
class Pool:
	var mm: MultiMesh
	var free: Array[int] = []
	var nape := Vector3(0.0, 1.55, -0.12)      # where the hive's cable met the neck, in the body's space
	var top := 1.9


static var _pools: Dictionary = {}       # species -> Pool
static var _owner: Node = null            # the level they were made for
static var _dots: MultiMesh
static var _dot_free: Array[int] = []
static var _warm := 0

var R: Robot
var T: Robot
var culled := false
var smoke_t := 0.0
var spark_t := 0.0
var vent_t := 0.0
var pool: Pool
var slot := -1
var dot := -1
var seed_ := 0.0
var size := 1.0
var phase_ := 0.0
var last_x := 0.0
var last_z := 0.0
var q: Dictionary = {}
var _xf := Transform3D.IDENTITY


## Build the species' copies under the level (at its load: making meshes and the material mid-play would stall the frame). Called again for another level, it builds again.
static func warm(level: Node) -> void:
	if _owner == level and is_instance_valid(_owner):
		return
	_owner = level
	_pools.clear()
	var dir := ExportedLevel.DIR + "hub/"
	var folk := CityFolk.new(ExportedLevel._json(dir + "life.json"), FileAccess.get_file_as_bytes(dir + "life.bin"))
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter(&"atlas", folk.material.get_shader_parameter(&"atlas"))
	var box := AABB(Vector3(-20000.0, -2000.0, -20000.0), Vector3(40000.0, 4000.0, 40000.0))      # (the chase moves them about a line kilometres long: never culled as a group)
	for nm in SPECIES:
		var mesh := folk.species_mesh(nm)
		var pl := Pool.new()
		pl.mm = MultiMesh.new()
		pl.mm.transform_format = MultiMesh.TRANSFORM_3D
		pl.mm.use_colors = true
		pl.mm.use_custom_data = true
		pl.mm.mesh = mesh
		pl.mm.instance_count = CAP
		for i in CAP:
			pl.mm.set_instance_transform(i, HIDDEN)
			pl.free.append(i)
		# the neck: the head's pivot (every vertex of the head carries it), a hand behind it
		var arr := mesh.surface_get_arrays(0)
		var b4: PackedFloat32Array = arr[Mesh.ARRAY_CUSTOM0]
		var piv: PackedFloat32Array = arr[Mesh.ARRAY_CUSTOM1]
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var top := 0.0
		for v in verts:
			top = maxf(top, v.y)
		pl.top = top
		for i in range(0, b4.size() / 4):
			if int(b4[i * 4] + 0.5) == 1:
				pl.nape = Vector3(piv[i * 3], piv[i * 3 + 1] + 0.04, piv[i * 3 + 2] - 0.14)
				break
		var mi := MultiMeshInstance3D.new()
		mi.name = "taken_" + nm
		mi.multimesh = pl.mm
		mi.material_override = mat
		mi.custom_aabb = box
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		level.add_child(mi)
		_pools[nm] = pl
	folk.release_bin()
	# the hive's lights at their napes
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.vertex_color_use_as_albedo = true
	var bx := BoxMesh.new()
	bx.size = Vector3(0.07, 0.07, 0.07)
	bx.material = dm
	_dots = MultiMesh.new()
	_dots.transform_format = MultiMesh.TRANSFORM_3D
	_dots.use_colors = true
	_dots.mesh = bx
	_dots.instance_count = CAP * SPECIES.size()
	_dot_free.clear()
	for i in _dots.instance_count:
		_dots.set_instance_transform(i, HIDDEN)
		_dot_free.append(i)
	var dn := MultiMeshInstance3D.new()
	dn.name = "taken_lights"
	dn.multimesh = _dots
	dn.custom_aabb = box
	dn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level.add_child(dn)
	_warm = 3


## The first frames after a load: one copy of each species drawn, tiny, in front of the camera, so their pipeline exists before the first one is seen (the level calls this every frame; cheap after)
static func warm_tick(cam: Camera3D) -> void:
	if _warm <= 0 or cam == null:
		return
	_warm -= 1
	var at := cam.global_transform * Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.002), Vector3(0.0, 0.0, -2.0))
	for nm: String in _pools:
		var pl: Pool = _pools[nm]
		if pl.free.size() == CAP:
			pl.mm.set_instance_transform(0, at if _warm > 0 else HIDDEN)
	if _dot_free.size() == _dots.instance_count:
		_dots.set_instance_transform(0, at if _warm > 0 else HIDDEN)


func _init(p_r: Robot) -> void:
	R = p_r
	T = p_r
	if _owner == null or not is_instance_valid(_owner) or _owner != Game.level:
		warm(Game.level)
	var tk := R as Taken
	var k := absi(tk.head) % SPECIES.size()
	for j in SPECIES.size():      # its own species, or the next one with a copy free
		var pl: Pool = _pools[SPECIES[(k + j) % SPECIES.size()]]
		if not pl.free.is_empty():
			pool = pl
			slot = pl.free.pop_back()
			break
	if not _dot_free.is_empty():
		dot = _dot_free.pop_back()
	seed_ = fposmod(R.id * 0.6180339, 1.0)
	size = 0.95 + seed_ * 0.1
	last_x = R.x
	last_z = R.z


func dispose() -> void:
	if not is_instance_valid(_owner):
		return
	if pool != null and slot >= 0:
		pool.mm.set_instance_transform(slot, HIDDEN)
		pool.free.append(slot)
		slot = -1
	if dot >= 0:
		_dots.set_instance_transform(dot, HIDDEN)
		_dot_free.append(dot)
		dot = -1


func set_culled(on: bool) -> void:
	if on == culled:
		return
	culled = on
	if on and pool != null and slot >= 0 and is_instance_valid(_owner):
		pool.mm.set_instance_transform(slot, HIDDEN)
		if dot >= 0:
			_dots.set_instance_transform(dot, HIDDEN)


func spine_world() -> Vector3:
	return _xf * Vector3(0.0, 1.05, 0.0)


func el_l_world() -> Vector3:
	return _xf * Vector3(0.3, 1.25, 0.1)


func sprite_world(_i: int) -> Vector3:
	return _xf * (pool.nape if pool != null else Vector3(0.0, 1.55, 0.0))


func muzzle_world(_kind: String = "") -> Vector3:
	return _xf * Vector3(0.0, (pool.top if pool != null else 1.9) - 0.25, 0.15)


## JS `Q(key, value, rate)`: the first call takes the value, later ones ease towards it.
func _qq(k: StringName, v: float, rate: float, dt: float) -> float:
	var c: float = q.get(k, v)
	if q.has(k):
		c += (v - c) * (1.0 - exp(-rate * dt))
	q[k] = c
	return c


func update(dt: float, _now: float, _fx: Variant) -> void:
	if pool == null or slot < 0 or not is_instance_valid(_owner):
		return
	dt = minf(0.05, maxf(0.0, dt))
	var tk := R as Taken
	var moved := U.hyp(R.x - last_x, R.z - last_z)
	last_x = R.x
	last_z = R.z
	if not R.dead and moved < 1.0:
		phase_ += moved * 3.4 / size
	var speed := U.hyp(R.vx, R.vz)
	var walk := _qq(&"walk", clampf(speed / 1.6, 0.0, 1.0) if not R.dead else 0.0, 8.0, dt)
	var rush := _qq(&"rush", clampf((speed - 2.6) / 1.6, 0.0, 1.0) if not R.dead else 0.0, 6.0, dt)
	var wind := CreatureView._ease(clampf(R.state_t / Taken.WIND, 0.0, 1.0)) if R.state == &"windup" else 0.0
	var hit := sin(clampf(R.state_t / Taken.LUNGE, 0.0, 1.0) * PI) if R.state == &"attack" else 0.0
	var reel := sin(clampf(R.state_t / 0.5, 0.0, 1.0) * PI) if R.state == &"stagger" else 0.0
	var fall := CreatureView._ease(clampf(R.dead_t / 0.6, 0.0, 1.0)) if R.dead else 0.0
	var air := tk.leap_t >= 0.0
	# its arms: hanging, out in front in a rush, up over its head to strike (and in the air, thrown at the car)
	var reach := 0.15 + 0.15 * walk + 0.75 * rush
	if air:
		reach = 1.7
	if wind > 0.0:
		reach = lerpf(reach, 2.0, wind)
	if R.state == &"attack":
		reach = lerpf(2.0, 0.7, clampf(R.state_t / Taken.LUNGE, 0.0, 1.0))
	if R.dead:
		reach = 0.4 * (1.0 - fall)
	reach = _qq(&"reach", reach, 14.0, dt)
	# the head: turned to you while it is after you
	var to_p := 0.0
	var P := Game.player
	if P != null:
		to_p = clampf(U.wrap_angle(atan2(P.x - R.x, P.z - R.z) - R.yaw), -1.25, 1.25)
	var look := _qq(&"look", to_p, 10.0, dt)
	# the root: bent forward at the best of times, further in a rush, thrown back to wind up and forward with the blow; down on its face when it dies
	var lean := 0.16 + 0.18 * rush - 0.25 * wind + 0.32 * hit - 0.4 * reel + (0.3 if air else 0.0)
	var root := Basis(Vector3.UP, R.yaw) * Basis(Vector3.RIGHT, lean * (1.0 - fall) + fall * 1.45) * Basis(Vector3(0.0, 0.0, 1.0), sin(R.t * 0.7 + seed_ * 9.0) * 0.04)
	_xf = Transform3D(root.scaled_local(Vector3.ONE * size), Vector3(R.x, R.y + fall * 0.12, R.z))
	pool.mm.set_instance_transform(slot, _xf)
	pool.mm.set_instance_custom_data(slot, Color(phase_, maxf(walk, rush * 1.3), seed_, reach))
	var awake := 1.0 if tk.awake else 0.0
	var amber := 1.0 if (wind > 0.0 or hit > 0.0 or air) else 0.0
	pool.mm.set_instance_color(slot, Color(amber, awake, clampf(R.flash, 0.0, 1.0), look))
	if dot >= 0:      # its light: green, amber for the strike, stuttering out when it dies
		var on := 0.0
		if R.dead:
			on = maxf(0.0, 1.0 - R.dead_t * 1.5) * (1.0 if fmod(R.dead_t * 11.0, 1.0) < 0.5 else 0.2)
		else:
			on = (1.0 if tk.awake or amber > 0.0 else 0.35) * (0.85 + 0.15 * sin(R.t * 9.0 + seed_ * 6.0))
		var col := (AMBER if amber > 0.0 else GREEN) * on
		col.a = 1.0
		_dots.set_instance_transform(dot, Transform3D(Basis.IDENTITY, _xf * pool.nape) if on > 0.01 else HIDDEN)
		_dots.set_instance_color(dot, col)
