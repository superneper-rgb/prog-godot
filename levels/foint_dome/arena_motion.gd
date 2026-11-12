class_name ArenaMotion
extends RefCounted
## FOINT DOME's mechanism clips (JS motion.js, lightning.js and the tracks in arena.js): platform flips, fan rotation, bullpen gates, hovering screens, the crowd and the edge lightning. three.js plays them from AnimationClips; here the same keys are worked out directly, so nothing walks a track list per frame.
## ENGINE DIFFERENCE: the JS bolts are morph targets with a draw range; here enemies/levels/shaders/arena_bolt.gdshader bends them in the vertex shader with the same noise and reveals them along the arc.

const CYCLE := 14.0
const SPIN := 2.0
const HOVER := 4.0
const CROWD := 3.0
const GATE_LEN := 14.0
const CARRIAGE_T := [0.0, 1.0, 2.2, 5.5, 6.7, 8.0, 14.0]
const CARRIAGE_Z := [2.1, 2.1, -5.6, -5.6, 2.1, 2.1, 2.1]
const SHUTTER_T := [0.0, 2.2, 3.2, 4.5, 5.5, 14.0]
const SHUTTER_Y := [0.0, 0.0, 3.8, 3.8, 0.0, 0.0]
const HOVER_Y := [1.7, 1.84, 1.7, 1.56, 1.7]
const X_AXIS := Vector3(1.0, 0.0, 0.0)
const Y_AXIS := Vector3(0.0, 1.0, 0.0)
const BOLT_SHADER := "res://levels/shaders/arena_bolt.gdshader"


class Arc:
	var seed_ := 0.0
	var period := 1.0
	var bolts: Array[MeshInstance3D] = []
	var kinds: Array[int] = []             # 0 halo, 1 sheath, 2 core, 3 branch
	var shown: Array[bool] = []
	var t0: Node3D
	var t1: Node3D
	var front: Node3D


var mode := "auto"
var paused := false
var time := 0.0
var cycle_t := 0.0
var cycle_paused := false
var spin_t := 0.0
var gate_t := 0.0
var gate_paused := false
var gate_target := NAN
var hover_t := 0.0
var crowd_t := 0.0
var pivots: Array[Node3D] = []
var rotors: Array[Node3D] = []
var carriages: Array[Node3D] = []
var shutters: Array[Node3D] = []
var hovers: Array[Node3D] = []
var cohorts: Array[Dictionary] = []    # node, amp, phase
var arcs: Array[Arc] = []
var glow_mats: Array[StandardMaterial3D] = []
var _th := -1.0


func _init(level: ExportedLevel) -> void:
	for i in 6:
		pivots.append(_one(level, "Flip_drum_Upper_%d" % i))
		pivots.append(_one(level, "Flip_drum_Lower_%d" % i))
		rotors.append(_one(level, "Rotor_Upper_%d" % i))
		rotors.append(_one(level, "Rotor_Lower_%d" % i))
		var g := 2 + i * 4
		carriages.append(_one(level, "Bullpen_carriage_%d" % g))
		shutters.append(_one(level, "Bullpen_shutter_%d" % g))
	for i in range(3, 18):
		hovers.append(_one(level, "Hover_billboard_%d" % i))
	for k: String in level.by_name.keys():
		if k.begins_with("Cheering_"):
			var phase := float(k.get_slice("_", k.get_slice_count("_") - 1))
			var amp := 0.018 if k.begins_with("Cheering_Seated") else (0.04 if k.begins_with("Cheering_Fist") else 0.055)
			cohorts.append({"node": level.node_named(k)[0], "amp": amp, "phase": phase})
	_build_arcs(level)
	update(0.0, 0.0)


static func _one(level: ExportedLevel, nm: String) -> Node3D:
	var a: Array = level.node_named(nm)
	if a.is_empty():
		push_error("FOINT DOME: missing " + nm)
		return Node3D.new()
	return a[0]


static func _rand(n: float) -> float:
	var v := sin(n * 127.1) * 43758.5453
	return v - floorf(v)


static func _mesh_of(n: Node) -> MeshInstance3D:
	for c: Node in n.get_children():
		if c is MeshInstance3D:
			return c
	return null


func _build_arcs(level: ExportedLevel) -> void:
	var mats := {}
	var kinds := {"Arc_soft_halo": 0, "Blue_arc_sheath": 1, "White_hot_arc_core": 2, "Arc_branch": 3}
	var shader: Shader = load(BOLT_SHADER)
	for k: String in level.by_name.keys():
		if not k.begins_with("Electric_arc_"):
			continue
		var seed_num := float(k.get_slice("_", k.get_slice_count("_") - 1))
		var node: Node = level.node_named(k)[0]
		var A := Arc.new()
		A.seed_ = seed_num
		A.period = 0.55 + _rand(seed_num + 3.0) * 0.3
		for c: Node in node.get_children():
			var js := String((c.get_meta("extras", {}) as Dictionary).get("js_name", ""))
			if js.begins_with("Electric_terminal_"):
				if A.t0 == null:
					A.t0 = c
				else:
					A.t1 = c
				for g: Node in c.get_children():
					var gn := String((g.get_meta("extras", {}) as Dictionary).get("js_name", ""))
					if gn.begins_with("Terminal_glow_"):
						var gm: MeshInstance3D = _mesh_of(g)
						var mt := gm.mesh.surface_get_material(0) as StandardMaterial3D if gm != null else null
						if mt != null and not glow_mats.has(mt):      # (one shared material per ring, as in the JS: the last arc's value wins)
							glow_mats.append(mt)
							mt.set_meta("ring", int(gn.get_slice("_", 2)))
			elif js.begins_with("Traveling_charge_front"):
				A.front = c
			else:
				for kn: String in kinds:
					if js.begins_with(kn):
						var mi: MeshInstance3D = _mesh_of(c)
						if mi == null:
							continue
						var kind: int = kinds[kn]
						if not mats.has(kind):
							mats[kind] = _bolt_mat(shader, mi.mesh.surface_get_material(0) as StandardMaterial3D)
						mi.material_override = mats[kind]
						mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
						mi.set_instance_shader_parameter(&"seed_", seed_num)
						mi.visible = false
						A.bolts.append(mi)
						A.kinds.append(kind)
						A.shown.append(false)
		arcs.append(A)


static func _bolt_mat(shader: Shader, src: StandardMaterial3D) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	var a := src.albedo_color.srgb_to_linear()
	m.set_shader_parameter(&"base", Vector3(a.r, a.g, a.b))
	var e := src.emission.srgb_to_linear() if src.emission_enabled else Color.BLACK
	m.set_shader_parameter(&"emit", Vector3(e.r, e.g, e.b))
	return m


func set_mode(v: String) -> void:
	mode = v
	cycle_paused = v != "auto"
	if v == "platforms":
		cycle_t = 0.0
	if v == "fans":
		cycle_t = 5.0
	if v == "auto":
		cycle_t = 0.0
	_apply()


## Reverse the same deployment track to close: shutter first, then carriage.
func set_gates(v: String) -> void:
	gate_paused = v != "auto"
	gate_target = 3.7 if v == "open" else (0.0 if v == "closed" else NAN)
	if v == "auto":
		gate_t = 0.0
	else:
		gate_t = minf(3.7, gate_t)
	_apply()


func update(dt: float, gate_dt: float) -> void:
	if paused:
		return
	time += dt
	if not is_nan(gate_target):
		var step := maxf(0.0, gate_dt)
		gate_t += clampf(gate_target - gate_t, -step, step)
	if not cycle_paused:
		cycle_t = fposmod(cycle_t + dt, CYCLE)
	spin_t = fposmod(spin_t + dt, SPIN)
	if not gate_paused:
		gate_t = fposmod(gate_t + dt, GATE_LEN)
	hover_t = fposmod(hover_t + dt, HOVER)
	crowd_t = fposmod(crowd_t + dt, CROWD)
	_apply()
	_discharges()


static func _key(ts: Array, vs: Array, t: float) -> float:
	for i in range(1, ts.size()):
		if t <= float(ts[i]):
			return lerpf(vs[i - 1], vs[i], (t - float(ts[i - 1])) / (float(ts[i]) - float(ts[i - 1])))
	return vs[vs.size() - 1]


## 0 = platform face up, PI = fan face up
static func _flip(t: float) -> float:
	if t < 3.0:
		return 0.0
	if t < 4.4:
		return (t - 3.0) / 1.4 * PI
	if t < 9.0:
		return PI
	if t < 10.4:
		return PI * (1.0 - (t - 9.0) / 1.4)
	return 0.0


## cycle angle, as the colliders read it
var th: float:
	get:
		return _flip(cycle_t)


func _apply() -> void:
	var a := _flip(cycle_t)
	if a != _th:
		_th = a
		var q := Quaternion(X_AXIS, a)
		for p: Node3D in pivots:
			p.quaternion = q
	var sq := Quaternion(Y_AXIS, spin_t * TAU)
	for r: Node3D in rotors:
		r.quaternion = sq
	var z := _key(CARRIAGE_T, CARRIAGE_Z, gate_t)
	var y := _key(SHUTTER_T, SHUTTER_Y, gate_t)
	for i in carriages.size():
		carriages[i].position = Vector3(0.0, 0.0, z)
		shutters[i].position = Vector3(0.0, y, 0.0)
	var hk := hover_t
	var k := mini(int(hk), 3)
	var hy := lerpf(HOVER_Y[k], HOVER_Y[k + 1], hk - k)
	for h: Node3D in hovers:
		h.position.y = hy
	for c: Dictionary in cohorts:
		(c.node as Node3D).position.y = sin(crowd_t / CROWD * TAU + float(c.phase) * PI / 3.0) * float(c.amp)


var carriage_z: float:
	get:
		return carriages[0].position.z


var shutter_y: float:
	get:
		return shutters[0].position.y


## JS createDischarges.update: every arc strikes on its own period: the bolt runs along the arc, flashes, dies back
func _discharges() -> void:
	var last_flash := 0.0
	for A: Arc in arcs:
		var sd := A.seed_
		var t := time + _rand(sd + 17.0) * A.period
		var epoch := floorf(t / A.period)
		var age := fposmod(t, A.period)
		var progress := minf(age / 0.12, 1.0)
		var frame := floorf(age * 65.0)
		var shape := floorf(_rand(sd * 13.0 + epoch * 97.0 + frame * 3.0) * 4.0)
		var flash := 0.1 + 0.2 * progress if age < 0.12 else ((1.0 if _rand(sd + epoch * 31.0 + frame) > 0.25 else 0.12) if age < 0.24 else (exp(-(age - 0.24) * 19.0) * 0.48 if age < 0.44 else 0.008))
		for i in A.bolts.size():
			var mi := A.bolts[i]
			var kind := A.kinds[i]
			var vis := flash > 0.01 and (kind != 3 or progress > 0.55)
			if vis != A.shown[i]:
				A.shown[i] = vis
				mi.visible = vis
			if not vis:
				continue
			mi.set_instance_shader_parameter(&"shape", shape)
			mi.set_instance_shader_parameter(&"reveal", progress if age < 0.12 else 2.0)
			mi.set_instance_shader_parameter(&"opacity", flash * 0.19 if kind == 0 else (flash * 0.75 if kind == 3 else flash))
			mi.set_instance_shader_parameter(&"emit_k", (7.0 if kind == 2 else 4.0) * (0.4 + flash))
		if A.front != null and A.t0 != null and A.t1 != null:
			var on := age < 0.12
			A.front.visible = on
			if on:
				A.front.position = A.t0.position.lerp(A.t1.position, progress)
				var fs := 0.7 + flash * 1.5
				A.front.scale = Vector3(fs, fs, fs)
		if A.t0 != null:
			var s0 := 0.78 + flash * 0.48 + (0.2 if age < 0.12 else 0.0)
			A.t0.scale = Vector3(s0, s0, s0)
		if A.t1 != null:
			var s1 := 0.78 + flash * 0.48
			A.t1.scale = Vector3(s1, s1, s1)
		last_flash = flash
	for m: StandardMaterial3D in glow_mats:
		m.albedo_color.a = (0.06 + last_flash * 0.15) / (int(m.get_meta("ring", 0)) + 1)
