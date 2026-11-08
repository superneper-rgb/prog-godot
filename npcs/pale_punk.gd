class_name PalePunk
extends Node3D
## The Pale Punk, the gunshop clerk (JS index.html createPalePunkNPC): assets/pale-punk.bin and its rig. A breathing, swaying idle reset from the bind pose every frame, and eyelids that work in bind-space face coordinates, so they follow the skinned head and cover every UV island of the atlas. update(time) each frame.

var skel: Skeleton3D
var _mat: ShaderMaterial
var _j := {}
var _rest := {}
var _spine_rest := Vector3.ZERO
var _next_blink := 2.0 + randf() * 3.0
var _blink_start := -INF
var _last_was_double := false


func _init() -> void:
	name = "Pale Punk (gunshop clerk)"
	var buf := FileAccess.get_file_as_bytes("res://assets/pale-punk.bin")
	var rig: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/pale-punk-rig.json"))
	if buf.size() < 4 or buf.slice(0, 4).get_string_from_ascii() != "NPC1":
		push_error("Invalid NPC asset")
		return
	var offset := 4
	var vertices := buf.decode_u32(offset)
	offset += 4
	var count := buf.decode_u32(offset)
	offset += 4
	var lo: Array[float] = []
	var hi: Array[float] = []
	for i in 3:
		lo.append(buf.decode_float(offset))
		offset += 4
	for i in 3:
		hi.append(buf.decode_float(offset))
		offset += 4
	var P := PackedVector3Array()
	P.resize(vertices)
	for i in vertices:
		var p := Vector3.ZERO
		for k in 3:
			p[k] = lo[k] + buf.decode_u16(offset) / 65535.0 * (hi[k] - lo[k])
			offset += 2
		P[i] = p
	var uv := PackedVector2Array()
	uv.resize(vertices)
	for i in vertices:
		uv[i] = Vector2(buf.decode_u16(offset) / 65535.0, buf.decode_u16(offset + 2) / 65535.0)
		offset += 4
	var I := PackedInt32Array()
	I.resize(count)
	for i in count:
		I[i] = buf.decode_u16(offset)
		offset += 2
	var bones := PackedInt32Array()
	bones.resize(vertices * 4)
	for i in vertices * 4:
		bones[i] = buf[offset + i]
	offset += vertices * 4
	var weights := PackedFloat32Array()
	weights.resize(vertices * 4)
	for i in vertices * 4:
		weights[i] = buf[offset + i] / 255.0
	var face := PackedFloat32Array()      # (Godot skins before vertex(): the eyelids' bind-space position has to travel in its own attribute)
	face.resize(vertices * 4)
	for i in vertices:
		face[i * 4] = P[i].x
		face[i * 4 + 1] = P[i].y
		face[i * 4 + 2] = P[i].z
	var arr := Goggles.indexed_mesh(P, I, uv).surface_get_arrays(0)
	arr[Mesh.ARRAY_BONES] = bones
	arr[Mesh.ARRAY_WEIGHTS] = weights
	arr[Mesh.ARRAY_CUSTOM0] = face
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	skel = Skeleton3D.new()
	add_child(skel)
	var list: Array = rig.bones
	for d: Dictionary in list:
		skel.add_bone(d.name)
	for i in list.size():
		var d: Dictionary = list[i]
		if int(d.parent) >= 0:
			skel.set_bone_parent(i, int(d.parent))
		var q := Quaternion(d.rotation[0], d.rotation[1], d.rotation[2], d.rotation[3])
		var pos := Vector3(d.position[0], d.position[1], d.position[2])
		var scl := Vector3(d.scale[0], d.scale[1], d.scale[2])
		skel.set_bone_rest(i, Transform3D(Basis(q).scaled(scl), pos))
		skel.set_bone_pose_position(i, pos)
		skel.set_bone_pose_rotation(i, q)
		skel.set_bone_pose_scale(i, scl)
		_j[String(d.name)] = i
		_rest[String(d.name)] = q
	var skin := Skin.new()
	var inv: Array = rig.inverse
	for i in inv.size():
		var e: Array = inv[i]      # column-major, like three.js
		skin.add_named_bind(String(list[i].name), Transform3D(Vector3(e[0], e[1], e[2]), Vector3(e[4], e[5], e[6]), Vector3(e[8], e[9], e[10]), Vector3(e[12], e[13], e[14])))
	_spine_rest = skel.get_bone_pose_position(_j["spine"])
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://npcs/pale_punk.gdshader")
	_mat.set_shader_parameter(&"map", load("res://assets/pale-punk.jpg"))
	var mi := MeshInstance3D.new()
	mi.name = "PalePunk"
	mi.mesh = mesh
	mi.skin = skin
	mi.material_override = _mat
	mi.extra_cull_margin = 2.0
	skel.add_child(mi)
	mi.skeleton = mi.get_path_to(skel) if mi.is_inside_tree() else NodePath("..")
	update_at(0.0)


func _rotate(nm: String, x: float, y: float, z: float) -> void:
	skel.set_bone_pose_rotation(_j[nm], (_rest[nm] as Quaternion) * Animator.q_xyz(x, y, z))


static func _ss(x: float, a: float, b: float) -> float:
	return smoothstep(a, b, x)


func update_at(time: float) -> void:
	if skel == null:
		return
	# reset from the bind pose every frame so the idle never accumulates drift
	var breath := sin(time * 1.45)
	var sway := sin(time * 0.7)
	skel.set_bone_pose_position(_j["spine"], _spine_rest + Vector3(0.0, breath * 0.006, 0.0))
	_rotate("spine", breath * 0.016, 0.0, sway * 0.014)
	_rotate("chest", breath * 0.025, sin(time * 0.65) * 0.045, -sway * 0.022)
	_rotate("head", sin(time * 0.9 + 0.6) * 0.045, sin(time * 0.38) * 0.18, sin(time * 0.53) * 0.025)
	_rotate("upper_arm_L", breath * 0.03, 0.0, sin(time * 0.8) * 0.025)
	_rotate("upper_arm_R", -breath * 0.025, 0.0, -sin(time * 0.8 + 0.4) * 0.025)
	_rotate("forearm_L", sin(time * 0.75 + 0.5) * 0.035, 0.0, 0.0)
	_rotate("forearm_R", sin(time * 0.8 + 1.0) * 0.035, 0.0, 0.0)
	if time >= _next_blink:
		_blink_start = time
		var dbl := not _last_was_double and randf() < 0.12
		_last_was_double = dbl
		_next_blink = time + (0.34 if dbl else 3.0 + randf() * 4.0)
	var e := time - _blink_start
	_mat.set_shader_parameter(&"npc_blink", _ss(e, 0.0, 0.075) if e < 0.075 else (1.0 if e < 0.10 else 1.0 - _ss(e, 0.10, 0.23)))
