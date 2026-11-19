class_name FolkSkin
extends RefCounted
## One species of FOINT CITY's new townsfolk (built by tools/folk, assets/folk/<id>/<id>.gltf): its mesh with bone indices and weights moved into custom channels, its idle, walk and run
## sampled into a bone texture at level load, and the material (levels/shaders/folk_skinned.gdshader) that skins every instance on the GPU, so a crowd of it is one MultiMesh.
## Walk and run are one cycle each, played by phase (the crowd advances it by distance over the species' stride, so the feet stay planted); idle plays by the street clock.

## What the species is like comes with it: assets/folk/<id>/<id>.json (tools/folk/build.py writes it from the recipe): height, strides, walking pace, what turns to look.

const CLIPS := [&"idle", &"walk", &"run"]
const ROWS := {&"idle": 180, &"walk": 32, &"run": 24}      # bone texture rows per clip

var id := ""
var mesh: ArrayMesh
var material: ShaderMaterial
var stride_walk := 1.1          # metres per walk cycle (two steps)
var stride_run := 1.9
var speed := 1.0                # its walking pace against the crowd's
var height := 1.8
var radius := 0.4               # its combat target's


## is the species built (its model and its species file both there)?
static func available(sid: String) -> bool:
	return ResourceLoader.exists(model_path(sid)) and FileAccess.file_exists(meta_path(sid))


## where a species' files are: assets/folk/<id>/<id>.gltf (its maps beside it) and <id>.json
static func model_path(sid: String) -> String:
	return "res://assets/folk/%s/%s.gltf" % [sid, sid]


static func meta_path(sid: String) -> String:
	return "res://assets/folk/%s/%s.json" % [sid, sid]


## the species, baked at level load (a few milliseconds); `holder` (a node under the level) hosts the model while it is sampled.
## `idle_pose` (CLUB 9's dances) replaces the idle clip with its own loop of `idle_seconds`, sampled into `idle_rows` rows (0: the street idle's 180).
static func make(sid: String, holder: Node, idle_pose: Callable = Callable(), idle_seconds: float = 0.0, idle_rows: int = 0) -> FolkSkin:
	var s := FolkSkin.new()
	s._build(sid, holder, idle_pose, idle_seconds, idle_rows)
	return s


func _build(sid: String, holder: Node, idle_pose: Callable, idle_seconds: float, idle_rows: int) -> void:
	id = sid
	var info: Dictionary = {}
	if FileAccess.file_exists(meta_path(sid)):
		info = JSON.parse_string(FileAccess.get_file_as_string(meta_path(sid)))
	stride_walk = info.get("stride_walk", 1.1)
	stride_run = info.get("stride_run", 1.9)
	speed = info.get("speed", 1.0)
	height = info.get("height", 1.8)
	radius = info.get("radius", 0.4)
	var sc: Node3D = (load(model_path(sid)) as PackedScene).instantiate()
	holder.add_child(sc)
	sc.visible = false
	var mi: MeshInstance3D = sc.find_children("*", "MeshInstance3D", true, false)[0]
	var sk: Skeleton3D = sc.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = sc.find_children("*", "AnimationPlayer", true, false)[0]
	var skin := mi.skin
	var nb := skin.get_bind_count()
	var bone_of := PackedInt32Array()
	var binds: Array[Transform3D] = []
	for i in nb:
		bone_of.append(sk.find_bone(skin.get_bind_name(i)))
		binds.append(skin.get_bind_pose(i))
	var rel := sk.global_transform.affine_inverse() * mi.global_transform      # mesh space -> skeleton space (identity from the kit)
	# the bone texture: 3 texels a bind (the rows of its 3x4 skinning matrix), one row per sampled frame, the clips one under the other
	var rows_of := ROWS.duplicate()
	if idle_pose.is_valid() and idle_rows > 0:
		rows_of[&"idle"] = idle_rows
	var total := 0
	for c: StringName in CLIPS:
		total += rows_of[c]
	var img := Image.create_empty(nb * 3, total, false, Image.FORMAT_RGBAF)
	var row := 0
	var clip_at := {}
	for c: StringName in CLIPS:
		var a := ap.get_animation(c)
		var n: int = rows_of[c]
		clip_at[c] = Vector2i(row, n)
		ap.play(c)
		for f in n:
			var u := float(f) / float(n)
			# CLUB 9 bakes its own dances over the first idle pose at load time. Street clips keep their original sampling and playback.
			if c == &"idle" and idle_pose.is_valid():
				ap.seek(0.0, true)
				idle_pose.call(sk, u)
			else:
				ap.seek(a.length * u, true)
			for i in nb:
				var m := sk.get_bone_global_pose(bone_of[i]) * binds[i] * rel
				var b := m.basis
				img.set_pixel(i * 3, row, Color(b.x.x, b.y.x, b.z.x, m.origin.x))
				img.set_pixel(i * 3 + 1, row, Color(b.x.y, b.y.y, b.z.y, m.origin.y))
				img.set_pixel(i * 3 + 2, row, Color(b.x.z, b.y.z, b.z.z, m.origin.z))
			row += 1
	ap.stop()
	# the mesh: bones and weights into CUSTOM0 / CUSTOM1 (a MultiMesh has no skeleton to skin with)
	var src := mi.mesh as ArrayMesh
	var arr := src.surface_get_arrays(0)
	var bi: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var bw: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var cb := PackedFloat32Array()
	cb.resize(bi.size())
	for k in bi.size():
		cb[k] = float(bi[k])
	var out: Array = []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = arr[Mesh.ARRAY_VERTEX]
	out[Mesh.ARRAY_NORMAL] = arr[Mesh.ARRAY_NORMAL]
	out[Mesh.ARRAY_TANGENT] = arr[Mesh.ARRAY_TANGENT]
	out[Mesh.ARRAY_TEX_UV] = arr[Mesh.ARRAY_TEX_UV]
	out[Mesh.ARRAY_INDEX] = arr[Mesh.ARRAY_INDEX]
	out[Mesh.ARRAY_CUSTOM0] = cb
	out[Mesh.ARRAY_CUSTOM1] = bw
	var flags := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out, [], {}, flags)
	mesh.custom_aabb = AABB(Vector3(-0.9, -0.1, -0.9), Vector3(1.8, height + 0.4, 1.8))      # (the clips swing arms, cases and fins well past the rest pose's box)
	# the material
	var sm := src.surface_get_material(0) as StandardMaterial3D
	material = ShaderMaterial.new()
	material.shader = load("res://levels/shaders/folk_skinned.gdshader")
	material.set_shader_parameter(&"albedo_tex", sm.albedo_texture)
	material.set_shader_parameter(&"normal_tex", sm.normal_texture)
	material.set_shader_parameter(&"orm_tex", sm.roughness_texture)
	material.set_shader_parameter(&"bones_tex", ImageTexture.create_from_image(img))
	material.set_shader_parameter(&"clip_idle", clip_at[&"idle"])
	material.set_shader_parameter(&"clip_walk", clip_at[&"walk"])
	material.set_shader_parameter(&"clip_run", clip_at[&"run"])
	material.set_shader_parameter(&"idle_len", idle_seconds if idle_seconds > 0.0 else ap.get_animation(&"idle").length)
	var look: Array = info.get("look", ["head"])
	var lb := Vector4i(-1, -1, -1, -1)
	for i in nb:
		var bn := String(skin.get_bind_name(i))
		var k := look.find(bn)
		if k >= 0 and k < 3:
			lb[k] = i
		elif bn == String(info.get("neck", "neck")):
			lb.w = i
	material.set_shader_parameter(&"look_binds", lb)
	var pv: Array = info.get("pivot", [0.0, height * 0.83, 0.0])
	material.set_shader_parameter(&"look_pivot", Vector3(pv[0], pv[1], pv[2]))
	sc.queue_free()
