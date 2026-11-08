class_name AlleyProps
extends Node
## What moves on the BACK ALLEY's set pieces (JS levels/worldbackalley/props.js; the rest of it comes with the export): the rain rings in the puddles, a big splash when something falls in, the club door's bulb and neon sign flickering, the dying tube over Prog's stoop.

const BIG_N := 12

var _rings: Array[Dictionary] = []
var _big: Array[Dictionary] = []
var _flicker: Array[Dictionary] = []
var _mm: MultiMesh
var _t := 0.0
var _next_big := 0


func _init(level: ExportedLevel, puddles: Array) -> void:
	name = "AlleyProps"
	for n: Node in level.node_named("AlleyRing"):      # (the export's still copies: the pool below draws them)
		if n is Node3D:
			(n as Node3D).visible = false
	var ring := _ring_mesh(0.8, 1.0, 24)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = false
	for p: Dictionary in puddles:
		for i in roundi(float(p["rx"]) * float(p["rz"]) * 3.0) + 2:
			_rings.append({"p": p, "t": randf(), "sp": 1.4 + randf(), "x": p["x"], "z": p["z"]})
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.mesh = ring
	_mm.instance_count = _rings.size() + BIG_N
	for i in BIG_N:
		_big.append({"t": 99.0, "k": 1.0, "x": 0.0, "z": 0.0, "on": false})
		_mm.set_instance_color(_rings.size() + i, Color(1, 1, 1, 0))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = _mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-60, -1, -150), Vector3(120, 3, 300))
	add_child(mi)
	_fl(level, "AlleyBulbGlow", "AlleyBulb", 0.9, 1.3, &"bulb")
	_fl(level, "AlleyNeonGlow", "AlleyNeonSign", 0.35, 4.1, &"neon")
	_fl(level, "AlleyTubeGlow", "AlleyTube", 0.6, 0.4, &"dying")


func _fl(level: ExportedLevel, glow: String, part: String, base: float, ph: float, kind: StringName) -> void:
	var g := level.node_named(glow)
	var m := level.node_named(part)
	var gs: Node = g[0] if not g.is_empty() else null
	var ms: Node = m[0] if not m.is_empty() else null
	_flicker.append({"s": gs, "m": _own_mat(ms), "gm": _own_mat(gs), "base": base, "ph": ph, "kind": kind, "c0": Color.WHITE})
	var f: Dictionary = _flicker[_flicker.size() - 1]
	if f["m"] != null:
		f["c0"] = (f["m"] as StandardMaterial3D).albedo_color
	if f["gm"] is BaseMaterial3D:
		f["c1"] = (f["gm"] as BaseMaterial3D).albedo_color


## (this part's own copy of its material, or null)
static func _own_mat(n: Node) -> Material:
	var mi: MeshInstance3D = null
	if n is MeshInstance3D:
		mi = n
	elif n != null:
		var k := n.find_children("*", "MeshInstance3D", true, false)
		if not k.is_empty():
			mi = k[0]
	if mi == null or mi.mesh == null:
		return null
	var m: Material = mi.material_override if mi.material_override != null else mi.mesh.surface_get_material(0)
	if m == null:
		return null
	var c: Material = m.duplicate()
	mi.material_override = c
	return c


static func _ring_mesh(r0: float, r1: float, seg: int) -> ArrayMesh:
	var v := PackedVector3Array()
	var idx := PackedInt32Array()
	for i in seg + 1:
		var a := TAU * i / seg
		v.append(Vector3(cos(a) * r0, 0.0, sin(a) * r0))
		v.append(Vector3(cos(a) * r1, 0.0, sin(a) * r1))
	for i in seg:
		var o := i * 2
		idx.append_array([o, o + 2, o + 1, o + 1, o + 2, o + 3])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## a big ring set (something fell in): x, z, strength
func splash(x: float, z: float, k: float = 1.0) -> void:
	for i in 4:
		var b := _big[_next_big % BIG_N]
		_next_big += 1
		b["t"] = -i * 0.18
		b["k"] = k
		b["x"] = x
		b["z"] = z
		b["on"] = true


func update(dt: float) -> void:
	_t += dt
	var t := _t
	var c_ring := Color.hex(0xa8c0d8ff)
	for i in _rings.size():
		var q := _rings[i]
		q["t"] += dt * float(q["sp"])
		if float(q["t"]) >= 1.0:
			q["t"] = 0.0
			var a := randf() * TAU
			var d := sqrt(randf()) * 0.8
			var p: Dictionary = q["p"]
			q["x"] = float(p["x"]) + cos(a) * d * float(p["rx"])
			q["z"] = float(p["z"]) + sin(a) * d * float(p["rz"])
		var u: float = q["t"]
		var s := 0.02 + u * 0.16
		_mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), Vector3(q["x"], 0.02, q["z"])))
		_mm.set_instance_color(i, Color(c_ring, (1.0 - u) * 0.5))
	var c_big := Color.hex(0xc8dcf0ff)
	for i in BIG_N:
		var q := _big[i]
		if not q["on"]:
			continue
		q["t"] += dt
		var j := _rings.size() + i
		if float(q["t"]) < 0.0:
			continue
		var u: float = float(q["t"]) / 1.6
		_mm.set_instance_transform(j, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * (0.1 + u * 1.6 * float(q["k"]))), Vector3(q["x"], 0.025, q["z"])))
		_mm.set_instance_color(j, Color(c_big, maxf(0.0, 1.0 - u) * 0.7))
		if u >= 1.0:
			q["on"] = false
			_mm.set_instance_color(j, Color(1, 1, 1, 0))
	for f: Dictionary in _flicker:
		var k := 1.0
		var ph: float = f["ph"]
		match f["kind"]:
			&"dying":
				var burst := sin(t * 0.9 + ph) * sin(t * 0.37) > 0.55
				k = 0.08 if burst and sin(t * 37.0) * sin(t * 9.1) > 0.3 else 1.0
			&"neon":
				k = 0.25 if sin(t * 0.5 + ph) > 0.97 and sin(t * 40.0) > 0.0 else 1.0
			_:
				k = 0.92 + 0.08 * sin(t * 13.0 + ph) * sin(t * 3.1)
		_set_glow(f, float(f["base"]) * k)
		var m: Material = f["m"]
		if m is StandardMaterial3D:
			var v := 0.4 + 0.6 * k if f["kind"] == &"neon" else k
			var c: Color = f["c0"]
			(m as StandardMaterial3D).albedo_color = Color(c.r * v, c.g * v, c.b * v, c.a)


func _set_glow(f: Dictionary, a: float) -> void:
	var gm: Material = f["gm"]
	if gm is BaseMaterial3D:
		var c: Color = f["c1"]
		c.a = a
		(gm as BaseMaterial3D).albedo_color = c
	elif gm is ShaderMaterial:
		(gm as ShaderMaterial).set_shader_parameter(&"opacity", a)
