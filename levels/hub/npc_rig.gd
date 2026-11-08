class_name NpcRig
extends Node3D
## A talker's body in the hub (the exporter's rigJSON: a bone per JS Object3D, a skinned surface per material, life.json + life.bin): the model of JS npcs/*.js. The JS merges these parts into one skinned mesh per material (enemies/rigid-merge.js) and moves them by their joints; so does this.
## A subclass ports the JS actor's update() and moves joints through rot / pos / scl by the JS's own numbers. The actor interface of core/dialogue.gd: look_at_point, look_away, set_talk, mouth_world.

var skeleton: Skeleton3D
var bones: Dictionary = {}       # JS name -> bone index
var _rest_s: PackedVector3Array  # (a hidden part goes back to its own scale when it shows)
var _hidden: PackedByteArray
var surfaces: Array[MeshInstance3D] = []


## The skinned model under this node.
func build(data: Dictionary, bin: PackedByteArray) -> void:
	skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton"
	add_child(skeleton)
	var list: Array = data["bones"]
	var skin := Skin.new()
	var globals: Array[Transform3D] = []
	var used_names := {}
	for i in list.size():
		var b: Dictionary = list[i]
		var nm := String(b["name"])
		if nm == "" or used_names.has(nm):
			nm = "b%d" % i
		used_names[nm] = true
		skeleton.add_bone(nm)
		bones[nm] = i
		var p := int(b["parent"])
		if p >= 0:
			skeleton.set_bone_parent(i, p)
		var q: Array = b["q"]
		var s: Array = b["s"]
		var c: Array = b["p"]
		var quat := Quaternion(q[0], q[1], q[2], q[3])
		var sc := Vector3(s[0], s[1], s[2])
		if sc.x == 0.0 or sc.y == 0.0 or sc.z == 0.0:      # (a blink caught at zero: a bind has to invert)
			sc = Vector3(sc.x if sc.x != 0.0 else 0.001, sc.y if sc.y != 0.0 else 0.001, sc.z if sc.z != 0.0 else 0.001)
		var pos := Vector3(c[0], c[1], c[2])
		var local := Transform3D(Basis(quat) * Basis.from_scale(sc), pos)
		if i == 0:      # the root's own place and yaw are this node's
			local = Transform3D(Basis.IDENTITY, Vector3.ZERO)
			quat = Quaternion.IDENTITY
			sc = Vector3.ONE
			pos = Vector3.ZERO
		skeleton.set_bone_rest(i, local)
		skeleton.set_bone_pose_position(i, pos)
		skeleton.set_bone_pose_rotation(i, quat)
		skeleton.set_bone_pose_scale(i, sc)
		_rest_s.append(sc)
		_hidden.append(1 if b.get("hidden", false) else 0)
		var g: Transform3D = globals[p] * local if p >= 0 else local
		globals.append(g)
		skin.add_bind(i, g.affine_inverse())
		if b.get("hidden", false):
			skeleton.set_bone_pose_scale(i, Vector3.ONE * 0.0001)
	var skin_ref := skeleton.register_skin(skin)
	for s: Dictionary in data["surfaces"]:
		var mi := MeshInstance3D.new()
		mi.mesh = _surface_mesh(s, bin, true)
		mi.skin = skin
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 1.0
		skeleton.add_child(mi)
		mi.skeleton = NodePath("..")
		surfaces.append(mi)
	_keep = skin_ref


var _keep: SkinReference


static func _surface_mesh(s: Dictionary, bin: PackedByteArray, skinned: bool) -> ArrayMesh:
	var n := int(s["n"])
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = bin.slice(int(s["pos"]), int(s["pos"]) + n * 12).to_vector3_array()
	arr[Mesh.ARRAY_NORMAL] = bin.slice(int(s["nor"]), int(s["nor"]) + n * 12).to_vector3_array()
	var uv: PackedVector2Array = bin.slice(int(s["uv"]), int(s["uv"]) + n * 8).to_vector2_array()
	arr[Mesh.ARRAY_TEX_UV] = _flip_v(uv) if s.get("flip_y", false) else uv
	var col: PackedVector3Array = bin.slice(int(s["col"]), int(s["col"]) + n * 12).to_vector3_array()
	if s.get("vc", false):
		var ca := PackedColorArray()
		ca.resize(n)
		for i in n:
			ca[i] = Color(col[i].x, col[i].y, col[i].z)
		arr[Mesh.ARRAY_COLOR] = ca
	if skinned:
		arr[Mesh.ARRAY_BONES] = bin.slice(int(s["bi"]), int(s["bi"]) + n * 16).to_int32_array()
		arr[Mesh.ARRAY_WEIGHTS] = bin.slice(int(s["bw"]), int(s["bw"]) + n * 16).to_float32_array()
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, _material(s))
	return m


## (three.js reads its canvases upside down, flipY; the exporter's bake takes that out of UVs, these are as the JS has them. A loaded glTF's textures are not flipped.)
static func _flip_v(uv: PackedVector2Array) -> PackedVector2Array:
	for i in uv.size():
		uv[i].y = 1.0 - uv[i].y
	return uv


static func _material(s: Dictionary) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var c: Array = s["color"]
	m.albedo_color = Color(c[0], c[1], c[2]).linear_to_srgb()
	m.roughness = s["rough"]
	m.metallic = s["metal"]
	m.metallic_specular = s["spec"]
	if s.get("vc", false):
		m.vertex_color_use_as_albedo = true
	if s.get("tex") != null:
		m.albedo_texture = load("res://assets/" + String(s["tex"]))
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS if s.get("nearest", false) else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var e: Array = s["emissive"]
	if float(e[0]) + float(e[1]) + float(e[2]) > 0.0:
		var top := maxf(float(e[0]), maxf(float(e[1]), float(e[2])))
		m.emission_enabled = true
		m.emission = Color(float(e[0]) / maxf(top, 1.0), float(e[1]) / maxf(top, 1.0), float(e[2]) / maxf(top, 1.0)).linear_to_srgb()
		m.emission_energy_multiplier = maxf(top, 1.0)
	if String(s["kind"]) != "lit":
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if String(s["blend"]) == "add":
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.disable_fog = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = float(s["opacity"])
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	elif float(s["opacity"]) < 0.995 or not s.get("depth_write", true):
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = float(s["opacity"])
	if String(s["side"]) == "double":
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## A model that does not move: every surface in one mesh, no skeleton (the saucers' pilots until the alien views are ported).
static func flat_mesh(data: Dictionary, bin: PackedByteArray) -> ArrayMesh:
	var m := ArrayMesh.new()
	for s: Dictionary in data["surfaces"]:
		var sm := _surface_mesh(s, bin, false)
		var arr := sm.surface_get_arrays(0)
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		m.surface_set_material(m.get_surface_count() - 1, sm.surface_get_material(0))
	return m


func has_bone(nm: String) -> bool:
	return bones.has(nm)


## JS joint.rotation.set(x, y, z): three.js rotations are XYZ order
func rot(nm: String, x: float, y: float, z: float) -> void:
	skeleton.set_bone_pose_rotation(bones[nm], Basis.from_euler(Vector3(x, y, z), EULER_ORDER_XYZ).get_rotation_quaternion())


func pos(nm: String, p: Vector3) -> void:
	skeleton.set_bone_pose_position(bones[nm], p)


func get_pos(nm: String) -> Vector3:
	return skeleton.get_bone_pose_position(bones[nm])


func scl(nm: String, s: Vector3) -> void:
	skeleton.set_bone_pose_scale(bones[nm], s)


## JS part.visible: its joint shrinks to nothing (the part is merged into its material's surface)
func show_part(nm: String, v: bool, s: Variant = null) -> void:
	var i: int = bones[nm]
	skeleton.set_bone_pose_scale(i, (s if s != null else _rest_s[i]) if v else Vector3.ONE * 0.0001)


## world position of a point in a joint's space (JS joint.localToWorld)
func joint_point(nm: String, p: Vector3) -> Vector3:
	return skeleton.global_transform * skeleton.get_bone_global_pose(bones[nm]) * p


# ---- the actor interface (core/dialogue.gd), overridden by each talker ----
func look_at_point(_x: float, _z: float) -> void:
	pass


func look_away() -> void:
	pass


func set_talk(_v: bool) -> void:
	pass


func mouth_world() -> Vector3:
	return global_position + Vector3(0.0, 1.4, 0.0)


func update(_time: float, _dt: float) -> void:
	pass
