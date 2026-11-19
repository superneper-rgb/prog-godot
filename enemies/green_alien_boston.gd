class_name GreenAlienBoston
extends RefCounted
## The green alien in Boston / Brooklyn clothes (2026-11-17, Pauly: CLUB 9's man on the phone, the user's scene): the punk export (assets/objects/green_alien_punk.glb) re-dressed in code
## and kept as its own model, "green_alien_boston", so it batches and animates like every other green alien. An open navy track jacket with white sleeve stripes over a white
## ribbed tank, dark jeans on a black belt, tan work boots, a gold chain where the punk's choker was, and a tweed flat cap.

const NAME := "green_alien_boston"
const BASE := "res://assets/objects/green_alien_punk.glb"


## A new one, harmless and directable (GrayAlienNpc), gun put away.
static func make() -> GrayAlienNpc:
	ensure()
	var a := GrayAlienNpc.new({"green": true, "outfit": "boston"})
	a.view.gun_hidden = true
	return a


## The model, built once a session (AlienView keeps it).
static func ensure() -> void:
	var root: Node3D = (load(BASE) as PackedScene).instantiate()
	_dress(root)
	AlienView.put_model(NAME, root)


static func _mat(nm: String, hex: int, rough: float, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = nm + "_0"      # (CreatureModel reads a row's name up to the last "_")
	m.albedo_color = Color.hex((hex << 8) | 0xff)
	m.roughness = rough
	m.metallic = metal
	return m


## The joint a node hangs from, by its JS name without the J_ ("head", "shL"...), or "".
static func _joint(n: Node) -> String:
	var q: Node = n
	while q != null:
		var x: Dictionary = q.get_meta("extras", {})
		var js := String(x.get("js_name", ""))
		if js.begins_with("J_"):
			return js.substr(2)
		q = q.get_parent()
	return ""


static func _joint_node(root: Node, j: String) -> Node3D:
	for n: Node in root.find_children("*", "Node3D", true, false):
		if String((n.get_meta("extras", {}) as Dictionary).get("js_name", "")) == "J_" + j:
			return n
	return null


## A mesh of its own from a primitive (CreatureModel reads surface arrays and the surface's material), under a joint.
static func _part(root: Node, j: String, prim: PrimitiveMesh, mat: Material, at: Transform3D) -> void:
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, prim.get_mesh_arrays())
	am.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.mesh = am
	mi.transform = at
	_joint_node(root, j).add_child(mi)


static func _recolor(mi: MeshInstance3D, mat: Material) -> void:
	mi.mesh = mi.mesh.duplicate()
	for s in mi.mesh.get_surface_count():
		mi.mesh.surface_set_material(s, mat)


static func _dress(root: Node3D) -> void:
	var jacket := _mat("boston_jacket", 0x1b2747, 0.42, 0.05)      # nylon: a soft sheen
	var stripe := _mat("boston_stripe", 0xe6e4de, 0.5)
	var tank := _mat("boston_tank", 0xe9e3d3, 0.85)
	var denim := _mat("boston_denim", 0x26324f, 0.9)
	var belt := _mat("boston_belt", 0x17110e, 0.55)
	var boots := _mat("boston_boots", 0xa8722f, 0.82)
	var sole := _mat("boston_sole", 0x2a1d14, 0.9)
	var gold := _mat("boston_gold", 0xd9ad45, 0.28, 1.0)
	var tweed := _mat("boston_tweed", 0x5a4c3e, 0.95)
	var tweed_dk := _mat("boston_brim", 0x3e342b, 0.95)
	var drop: Array[Node] = []
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var m := mi.mesh.surface_get_material(0)
		var nm := m.resource_name if m != null else ""
		var j := _joint(mi)
		var size := mi.get_aabb().size
		match nm:
			"standard_9":      # the punk's crop top: gone under the jacket (_shell); its short sleeves: the jacket's shoulders
				if j == "belly":
					drop.append(mi)
				else:
					_recolor(mi, jacket)
			"standard_11":      # the shirt's front print: the tank top the open jacket shows; its little badge: the chain's medallion
				_recolor(mi, tank if size.y > 0.1 else gold)
			"standard_12":      # the waistband
				_recolor(mi, belt)
			"standard_13":      # the trousers
				_recolor(mi, denim)
			"standard_5":
				if j == "hips":      # (the head's is his lips)
					_recolor(mi, denim)
			"standard_3":
				if j == "ankL" or j == "ankR":
					_recolor(mi, boots)
				elif j == "knL" or j == "knR":      # the turn-ups
					_recolor(mi, denim)
				elif j == "neck":      # the choker: a heavy gold chain
					_recolor(mi, gold)
			"standard_7":
				if j == "neck":      # its studs: links
					_recolor(mi, gold)
				else:      # the punk boots' buckles
					drop.append(mi)
	for n in drop:
		n.free()
	# long sleeves over the arms, two white stripes down the outside of each (a track jacket)
	for s: String in ["L", "R"]:
		var out := 1.0 if s == "L" else -1.0      # (the model's left is +x)
		var up := CylinderMesh.new()
		up.top_radius = 0.088
		up.bottom_radius = 0.078
		up.height = 0.25
		up.radial_segments = 12
		_part(root, "sh" + s, up, jacket, Transform3D(Basis.IDENTITY, Vector3(0.0, -0.13, 0.0)))
		var fore := CylinderMesh.new()
		fore.top_radius = 0.07
		fore.bottom_radius = 0.06
		fore.height = 0.17
		fore.radial_segments = 12
		_part(root, "el" + s, fore, jacket, Transform3D(Basis.IDENTITY, Vector3(0.0, -0.075, 0.0)))
		var cuff := CylinderMesh.new()
		cuff.top_radius = 0.062
		cuff.bottom_radius = 0.062
		cuff.height = 0.03
		cuff.radial_segments = 12
		_part(root, "el" + s, cuff, stripe, Transform3D(Basis.IDENTITY, Vector3(0.0, -0.17, 0.0)))
		for k: float in [-0.022, 0.022]:
			var st := BoxMesh.new()
			st.size = Vector3(0.012, 0.25, 0.014)
			_part(root, "sh" + s, st, stripe, Transform3D(Basis.IDENTITY, Vector3(out * 0.085, -0.13, k)))
			var st2 := BoxMesh.new()
			st2.size = Vector3(0.012, 0.15, 0.012)
			_part(root, "el" + s, st2, stripe, Transform3D(Basis.IDENTITY, Vector3(out * 0.066, -0.07, k * 0.8)))
		# the boots' soles
		var so := BoxMesh.new()
		so.size = Vector3(0.24, 0.035, 0.33)
		_part(root, "ank" + s, so, sole, Transform3D(Basis.IDENTITY, Vector3(0.0, -0.105, 0.05)))
	# the body: a ribbed tank over the whole belly, and the jacket over that, open down the front and ending at the waist
	var gut: MeshInstance3D = null
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var m := mi.mesh.surface_get_material(0)
		if m != null and m.resource_name == "standard_0" and _joint(mi) == "belly":
			gut = mi
	if gut != null:
		_shell(gut, 1.03, tank, -1.0, 9.0)
		_shell(gut, 1.075, jacket, 0.42, 0.2)
	# a long gold chain hanging on the tank, and its medallion
	var ch := TorusMesh.new()
	ch.inner_radius = 0.158
	ch.outer_radius = 0.172
	ch.rings = 24
	ch.ring_segments = 6
	_part(root, "belly", ch, gold, Transform3D(Basis(Vector3.RIGHT, -0.62), Vector3(0.0, 0.38, 0.1)))
	var med := CylinderMesh.new()
	med.top_radius = 0.028
	med.bottom_radius = 0.028
	med.height = 0.008
	med.radial_segments = 14
	_part(root, "belly", med, gold, Transform3D(Basis(Vector3.RIGHT, PI / 2.0 - 0.3), Vector3(0.0, 0.27, 0.315)))
	# the flat cap: a tweed crown pulled forward over the dome of the head, a short stiff brim
	var crown := SphereMesh.new()
	crown.radius = 0.2
	crown.height = 0.2
	crown.is_hemisphere = true
	crown.radial_segments = 20
	crown.rings = 6
	_part(root, "head", crown, tweed, Transform3D(Basis(Vector3.RIGHT, 0.22).scaled(Vector3(1.04, 0.62, 1.12)), Vector3(0.0, 0.33, 0.0)))
	var band := CylinderMesh.new()
	band.top_radius = 0.205
	band.bottom_radius = 0.207
	band.height = 0.03
	band.radial_segments = 20
	_part(root, "head", band, tweed_dk, Transform3D(Basis(Vector3.RIGHT, 0.22).scaled(Vector3(1.04, 1.0, 1.12)), Vector3(0.0, 0.335, 0.0)))
	var brim := CylinderMesh.new()
	brim.top_radius = 0.12
	brim.bottom_radius = 0.125
	brim.height = 0.014
	brim.radial_segments = 16
	_part(root, "head", brim, tweed_dk, Transform3D(Basis(Vector3.RIGHT, 0.32).scaled(Vector3(1.25, 1.0, 0.75)), Vector3(0.0, 0.31, 0.2)))


## A layer of clothing over a body part: its mesh grown `grow` times about its own middle, without the triangles in the front opening (within `open` rad of straight ahead;
## < 0: none) or below `hem` (metres under the middle).
static func _shell(src: MeshInstance3D, grow: float, mat: Material, open: float, hem: float) -> void:
	var a: Array = src.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var nor: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var ix: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if ix.is_empty():
		for i in v.size():
			ix.append(i)
	var c := src.mesh.get_aabb().get_center()
	var nv := PackedVector3Array()
	for p in v:
		nv.append(c + (p - c) * grow)
	var keep := PackedInt32Array()
	var i := 0
	while i < ix.size():
		var m := (v[ix[i]] + v[ix[i + 1]] + v[ix[i + 2]]) / 3.0 - c
		var front := open >= 0.0 and m.z > 0.0 and absf(atan2(m.x, m.z)) < open
		if not front and m.y > -hem:
			keep.append_array([ix[i], ix[i + 1], ix[i + 2]])
		i += 3
	var out: Array = []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = nv
	out[Mesh.ARRAY_NORMAL] = nor
	if a[Mesh.ARRAY_TEX_UV] != null:
		out[Mesh.ARRAY_TEX_UV] = a[Mesh.ARRAY_TEX_UV]
	out[Mesh.ARRAY_INDEX] = keep
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	am.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.mesh = am
	mi.transform = src.transform
	src.get_parent().add_child(mi)
