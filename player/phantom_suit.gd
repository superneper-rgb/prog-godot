class_name PhantomSuit
extends RefCounted
## The armor suits on the characters (JS phantom-suit.js): wear_suit_by_id(animator, id) dresses Prog or Tommy in whichever wearable suit has that catalogue id and undresses for anything else.
## The pieces come baked from the JS specs: assets/suits/<id>_<character>.glb (tools/export/export.mjs suits), one skinned mesh per material, bound by bone name to the character's own skeleton,
## so they stay rigid and follow every animation for free. <id>_<character>.json says what the suit does to the body itself:
##   - Prog has a tank top, shorts and boots (separate materials): while the suit is on those are swapped for its cloth (retint), and his skin below the collar is painted so it can never show through.
##   - Tommy is one white mesh: the suit is painted onto him from a per-vertex flag, so his head and hands stay white.

const SHADER_CLOTH := preload("res://player/suit_cloth.gdshader")
const SHADER_PAINT := preload("res://player/suit_paint.gdshader")

## catalogue ids a character can wear (JS WEARABLE_SUITS: phantom_suit, schleedtech_combat, goint_gear_xl, omen)
const WEARABLE_SUITS: Array[String] = ["phantom_suit", "schleedtech_combat", "goint_gear_xl", "omen"]
const CUSTOM_FLAGS := (Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RG_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)

static var _cloth_mats: Dictionary = {}     # suit id:colour key -> material, shared by every character
static var _body_meshes: Dictionary = {}    # character file + mesh name + paint rules -> the mesh with the bind pose and paint flags per vertex


## What is on him, and how to take it off again.
class Worn:
	var id := ""
	var added: Array[MeshInstance3D] = []
	var undo_mesh: Array = []       # [mesh instance, its own mesh]
	var undo_mat: Array = []        # [mesh instance, surface, its own material]

	func undress() -> void:
		for m in added:
			if is_instance_valid(m):
				m.get_parent().remove_child(m)
				m.free()
		for u: Array in undo_mesh:
			if is_instance_valid(u[0]):
				(u[0] as MeshInstance3D).mesh = u[1]
		for u: Array in undo_mat:
			if is_instance_valid(u[0]):
				(u[0] as MeshInstance3D).set_surface_override_material(u[1], u[2])


## dress `an` for the armor with this catalogue id: a wearable suit gets its pieces, every other id strips them. Safe to call repeatedly;
## switching suits takes the old one off first, so his own clothes are always what is underneath.
static func wear_suit_by_id(an: Animator, id: String) -> bool:
	if an == null or an.model == null:
		return false
	if an.suit != null and an.suit.id == id:
		return true
	if an.suit != null:
		an.suit.undress()
		an.suit = null
	if not WEARABLE_SUITS.has(id):
		return false
	an.suit = _dress(an, id)
	return an.suit != null


## put the Phantom Suit on (on = true) or take any suit off an Animator
static func set_phantom_suit(an: Animator, on: bool) -> bool:
	return wear_suit_by_id(an, "phantom_suit" if on else "")


static func _skinned(n: Node, out: Array[MeshInstance3D]) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).skin != null:
		out.append(n)
	for c: Node in n.get_children():
		_skinned(c, out)


## like suitMat, but double-sided, to stand in for Prog's own cloth materials
static func _cloth_mat(suit_id: String, k: String, hex: int) -> ShaderMaterial:
	var key := suit_id + ":" + k
	if _cloth_mats.has(key):
		return _cloth_mats[key]
	var m := ShaderMaterial.new()
	m.resource_name = "suit_" + k
	m.shader = SHADER_CLOTH
	m.set_shader_parameter(&"color", Color.hex((hex << 8) | 0xff))
	m.set_shader_parameter(&"cell", 9.0)
	m.set_shader_parameter(&"bands", k == "navy" or k == "blue" or k == "under")
	m.set_shader_parameter(&"amp", 0.2)
	_cloth_mats[key] = m
	return m


## mark every vertex of a skinned surface as body cloth / boot (or glove) / untouched by the spec's rules: two floats per vertex for the paint shader
static func _paint_flags(a: Array, skin: Skin, rules: Array, eight: bool) -> PackedFloat32Array:
	var pos: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var si: PackedInt32Array = a[Mesh.ARRAY_BONES]
	var sw: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
	var stride := 8 if eight else 4
	var names: PackedStringArray = []
	for b in skin.get_bind_count():
		names.append(String(skin.get_bind_name(b)))
	var flags := PackedFloat32Array()
	flags.resize(pos.size() * 2)
	for v in pos.size():
		var best := 0
		var bw := -1.0
		for c in stride:
			var w := sw[v * stride + c]
			if w > bw:
				bw = w
				best = si[v * stride + c]
		var nm: String = names[best] if best < names.size() else ""
		var p := pos[v]
		for r: Dictionary in rules:
			var hit := false
			for pf: String in r.bones:
				if nm.begins_with(pf):
					hit = true
					break
			if not hit:
				continue
			if r.get("maxY") != null and not (p.y < float(r.maxY) + float(r.get("curve", 0.0)) * p.x * p.x):
				continue
			if r.color == "navy":
				flags[v * 2] = 1.0
			elif r.color == "boot":
				flags[v * 2 + 1] = 1.0
			break
	return flags


## The mesh again with what the suit's shaders read: the bind pose on the surfaces it re-colours, the paint flags on the surfaces it paints. Built once per body and paint rule set.
static func _suited_mesh(an: Animator, mi: MeshInstance3D, retint: Dictionary, paint_mats: Array, rules: Array) -> ArrayMesh:
	var key := an.B.file + "/" + String(mi.name) + "/" + JSON.stringify(rules) + "/" + JSON.stringify(retint.keys())
	if _body_meshes.has(key):
		return _body_meshes[key]
	var src := mi.mesh
	var out := ArrayMesh.new()
	for i in src.get_surface_count():
		var a: Array = src.surface_get_arrays(i)
		var mat := src.surface_get_material(i)
		var nm: String = mat.resource_name if mat != null else ""
		var flags := 0
		if a[Mesh.ARRAY_CUSTOM0] != null:
			flags = Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
		if retint.has(nm) or paint_mats.has(nm):
			a[Mesh.ARRAY_CUSTOM0] = (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).to_byte_array().to_float32_array()
			flags = Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
		if paint_mats.has(nm):
			a[Mesh.ARRAY_CUSTOM1] = _paint_flags(a, mi.skin, rules, (src.surface_get_format(i) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS) != 0)
			flags = CUSTOM_FLAGS
		out.add_surface_from_arrays(src.surface_get_primitive_type(i), a, [], {}, flags)
		out.surface_set_material(i, mat)
	_body_meshes[key] = out
	return out


static func _dress(an: Animator, suit_id: String) -> Worn:
	var base := "res://assets/suits/%s_%s" % [suit_id, an.B.id]
	if not ResourceLoader.exists(base + ".glb"):
		push_warning("suit not exported: %s.glb (node tools/export/export.mjs suits)" % base)
		return null
	var spec: Variant = JSON.parse_string(FileAccess.get_file_as_string(base + ".json"))
	if not (spec is Dictionary):
		push_warning("suit data unreadable: %s.json" % base)
		return null
	var colors: Dictionary = spec.colors
	# the host: the skinned mesh with the most bones; every piece goes on its skeleton
	var meshes: Array[MeshInstance3D] = []
	_skinned(an.model, meshes)
	if meshes.is_empty():
		return null
	var host := meshes[0]
	for m in meshes:
		if m.skin.get_bind_count() > host.skin.get_bind_count():
			host = m
	var worn := Worn.new()
	worn.id = suit_id
	var ps: PackedScene = load(base + ".glb")
	var scene: Node = ps.instantiate()
	var parts: Array[MeshInstance3D] = []
	_skinned(scene, parts)
	# the export carries the JS's bone names (three.js takes the dots out); this skeleton keeps the model's own
	var bone_by_js := {}
	for b in an.skel.get_bone_count():
		bone_by_js[Animator.san(an.skel.get_bone_name(b))] = an.skel.get_bone_name(b)
	for p in parts:
		for b in p.skin.get_bind_count():
			var real: String = bone_by_js.get(Animator.san(String(p.skin.get_bind_name(b))), "")
			if real != "":
				p.skin.set_bind_name(b, real)
		p.get_parent().remove_child(p)
		p.owner = null
		p.transform = host.transform
		host.get_parent().add_child(p)
		p.skeleton = p.get_path_to(an.skel)
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		p.custom_aabb = AABB(Vector3(-4.0, -4.0, -4.0), Vector3(8.0, 8.0, 8.0))      # JS frustumCulled = false
		p.ignore_occlusion_culling = true
		for i in p.mesh.get_surface_count():         # (a new JS mesh does not receive shadows)
			var pm := p.mesh.surface_get_material(i) as BaseMaterial3D
			if pm != null:
				pm.disable_receive_shadows = true
		worn.added.append(p)
	scene.free()
	# Prog: swap his tank top / shorts / boots for the suit's cloth, remembering the originals; paint onto a skinned mesh: Tommy's body (the whole suit), Prog's skin (everything under the suit, gloves)
	var retint: Dictionary = spec.retint if spec.get("retint") is Dictionary else {}
	var paint: Variant = spec.get("paint")
	var paint_mats: Array = []
	var rules: Array = []
	if paint is Dictionary:
		paint_mats = paint.mat if paint.mat is Array else [paint.mat]
		rules = paint.rules
	for mi in meshes:
		var src := mi.mesh
		var touches := false
		for i in src.get_surface_count():
			var mat := src.surface_get_material(i)
			if mat != null and (retint.has(mat.resource_name) or paint_mats.has(mat.resource_name)):
				touches = true
		if not touches:
			continue
		worn.undo_mesh.append([mi, src])
		var overrides: Array[Material] = []
		for i in src.get_surface_count():
			overrides.append(mi.get_surface_override_material(i))
		mi.mesh = _suited_mesh(an, mi, retint, paint_mats, rules)
		for i in src.get_surface_count():
			mi.set_surface_override_material(i, overrides[i])
			var mat := src.surface_get_material(i) as BaseMaterial3D
			if mat == null:
				continue
			var nm := mat.resource_name
			if retint.has(nm):
				var k: String = retint[nm]
				worn.undo_mat.append([mi, i, overrides[i]])
				mi.set_surface_override_material(i, _cloth_mat(suit_id, k, int(colors[k])))
			elif paint_mats.has(nm):
				worn.undo_mat.append([mi, i, overrides[i]])
				var pm := ShaderMaterial.new()
				pm.resource_name = nm
				pm.shader = SHADER_PAINT
				pm.set_shader_parameter(&"albedo", mat.albedo_color)
				pm.set_shader_parameter(&"map", mat.albedo_texture)
				pm.set_shader_parameter(&"has_map", mat.albedo_texture != null)
				pm.set_shader_parameter(&"use_vcol", (src.surface_get_format(i) & Mesh.ARRAY_FORMAT_COLOR) != 0)
				pm.set_shader_parameter(&"u_suit_navy", Color.hex((int(colors[paint.get("body", "boot")]) << 8) | 0xff))
				pm.set_shader_parameter(&"u_suit_boot", Color.hex((int(colors[paint.get("boot", "boot")]) << 8) | 0xff))
				pm.set_shader_parameter(&"ink", paint.get("ink", false))
				mi.set_surface_override_material(i, pm)
	return worn
