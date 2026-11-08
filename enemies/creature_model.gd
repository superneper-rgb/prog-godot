class_name CreatureModel
extends RefCounted
## A jointed enemy model exported from the JS game (tools/export/export.mjs object), turned into one RigidBatch: every part merged per the whole model, each vertex tagged with its joint and material row, so any number of copies is a handful of draws. Nodes the JS view animates are named J_<name> in the export.
## A view keeps a pose per joint (see `Pose`) and uploads world matrices. Sprites and the health bar are the batch's own layers. See-through parts (a jar, a cockpit dome) get a blended layer of their own.

const MAX_ROWS := 24

var batch: RigidBatch
var names: Dictionary = {}                # joint name -> index
var parent := PackedInt32Array()          # index of each joint's parent (-1 = the model's root)
var rest: Array[Transform3D] = []         # each joint relative to its parent, as exported
var rows: Dictionary = {}                 # JS material name -> row
var body_mat: ShaderMaterial = null       # the solid layer's material
var clear_mat: ShaderMaterial = null      # the see-through layer's
var textures: Dictionary = {}             # a material's map, for parts the batch does not draw: its last name part -> Texture2D


## The pose of one copy: position, rotation and scale per joint. Starts at the exported rest pose; compose() makes the world matrices.
class Pose:
	var model: CreatureModel
	var pos := PackedVector3Array()
	var rot: Array[Basis] = []
	var scl := PackedVector3Array()
	var world: Array[Transform3D] = []

	func _init(m: CreatureModel) -> void:
		model = m
		var n := m.rest.size()
		pos.resize(n)
		scl.resize(n)
		rot.resize(n)
		world.resize(n)
		for i in n:
			pos[i] = m.rest[i].origin
			scl[i] = m.rest[i].basis.get_scale()
			rot[i] = m.rest[i].basis.orthonormalized()

	## three.js rotation.set(x, y, z): XYZ order
	func euler(j: int, x: float, y: float, z: float) -> void:
		rot[j] = Basis.from_euler(Vector3(x, y, z), EULER_ORDER_XYZ)

	## Parents come first in the arrays, so one pass composes everything.
	func compose(root: Transform3D) -> void:
		var par := model.parent
		for i in pos.size():
			var l := Transform3D(rot[i].scaled_local(scl[i]), pos[i])
			world[i] = (world[par[i]] * l) if par[i] >= 0 else (root * l)


## One merged mesh and its material table.
class Parts:
	var v := PackedVector3Array()
	var nor := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var col := PackedColorArray()
	var ix := PackedInt32Array()
	var mats: Array[Material] = []
	var keys := {}

	func row_of(mat: Material, path: String) -> int:
		var key := CreatureModel._mat_key(mat)
		var row: int = keys.get(key, -1)
		if row < 0:
			row = mats.size()
			mats.append(mat)
			keys[key] = row
			if row >= CreatureModel.MAX_ROWS:
				push_error("%s: more materials than the batch shader has rows" % path)
		return mini(row, CreatureModel.MAX_ROWS - 1)

	## The row of the material the export named so (last part of its name, before the index the exporter adds).
	func row_named(tag: String) -> int:
		for i in mats.size():
			var rn := mats[i].resource_name
			if rn.contains(tag):
				return i
		push_error("no material named " + tag)
		return 0

	func commit() -> ArrayMesh:
		var arr: Array = []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = nor
		arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_TEX_UV2] = uv2
		arr[Mesh.ARRAY_COLOR] = col
		arr[Mesh.ARRAY_INDEX] = ix
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		return m


## A joint no node stands for. parent_joint: -1 = the model's root. Parents must exist first.
func add_joint(nm: String, parent_joint: int) -> int:
	var i := rest.size()
	names[nm] = i
	parent.append(parent_joint)
	rest.append(Transform3D.IDENTITY)
	return i


## Build from res://assets/objects/<name>.glb. `glow_fill(soup, model)` adds the sprites. `glow_joints` (joint name -> channel): the additive JS parts, drawn in the glow layer instead of the body. `row_kinds` (JS material name -> rigid_batch kind): a material that follows the copy's colour A / B. `extra(model, parts)`: geometry the JS rebuilds by hand each frame, added here with joints of its own (add_joint). Materials are read from the export.
static func build(path: String, glow_fill: Callable = Callable(), glow_joints: Dictionary = {}, row_kinds: Dictionary = {}, extra: Callable = Callable()) -> CreatureModel:
	var cm := CreatureModel.new()
	var ps: PackedScene = load(path)
	var root: Node3D = ps.instantiate()
	# ---- joints: everything named J_*, parents first ----
	var order: Array[Node3D] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_front()
		var x: Dictionary = n.get_meta("extras", {})
		if n is Node3D and String(x.get("js_name", "")).begins_with("J_"):
			cm.names[String(x["js_name"]).substr(2)] = order.size()
			order.append(n)
		stack.append_array(n.get_children())
	var world_of := func(n: Node3D) -> Transform3D:
		var t := Transform3D.IDENTITY
		var q: Node = n
		while q != null and q != root:
			if q is Node3D:
				t = (q as Node3D).transform * t
			q = q.get_parent()
		return t
	var index_of := {}
	for i in order.size():
		index_of[order[i]] = i
	var joint_of := func(n: Node) -> int:
		var q: Node = n
		while q != null and q != root:
			if index_of.has(q):
				return index_of[q]
			q = q.get_parent()
		return -1
	for i in order.size():
		var pj: int = joint_of.call(order[i].get_parent())
		cm.parent.append(pj)
		var w: Transform3D = world_of.call(order[i])
		cm.rest.append((world_of.call(order[pj]) as Transform3D).affine_inverse() * w if pj >= 0 else w)
	# ---- the merged meshes ----
	var body := Parts.new()
	var clear := Parts.new()
	var glow_parts: Array = []
	var glow_of := {}
	for k: String in glow_joints:
		glow_of[cm.names[k]] = glow_joints[k]
	stack = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if not (n is MeshInstance3D) or (n as MeshInstance3D).mesh == null:
			continue
		var mi := n as MeshInstance3D
		var j: int = joint_of.call(mi)
		if j < 0:
			push_warning("%s: a mesh outside every joint" % path)
			continue
		var to_joint: Transform3D = (world_of.call(order[j]) as Transform3D).affine_inverse() * (world_of.call(mi) as Transform3D)
		var nb := to_joint.basis.inverse().transposed()
		var mirrored := to_joint.basis.determinant() < 0.0      # a negative scale turns the triangles inside out
		for s in mi.mesh.get_surface_count():
			var a: Array = mi.mesh.surface_get_arrays(s)
			if glow_of.has(j):
				var g := MeshBuild.Geo.new()
				g.pos = a[Mesh.ARRAY_VERTEX]
				for i in g.pos.size():
					g.pos[i] = to_joint * g.pos[i]
				g.idx = a[Mesh.ARRAY_INDEX]
				glow_parts.append([g, j, glow_of[j]])
				continue
			var mat: Material = mi.mesh.surface_get_material(s)
			var b := mat as BaseMaterial3D
			var P: Parts = clear if b != null and b.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED else body
			var row := P.row_of(mat, path)
			var av: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var an: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
			var at: PackedVector2Array = a[Mesh.ARRAY_TEX_UV] if a[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var ac: PackedColorArray = a[Mesh.ARRAY_COLOR] if a[Mesh.ARRAY_COLOR] != null else PackedColorArray()
			var ai: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var base := P.v.size()
			for i in av.size():
				P.v.append(to_joint * av[i])
				P.nor.append((nb * an[i]).normalized() if i < an.size() else Vector3.UP)
				P.uv.append(at[i] if i < at.size() else Vector2.ZERO)
				P.uv2.append(Vector2(j, row))
				P.col.append(ac[i] if i < ac.size() else Color.WHITE)
			var first := P.ix.size()
			if ai.is_empty():
				for i in av.size():
					P.ix.append(base + i)
			else:
				for i in ai:
					P.ix.append(base + i)
			if mirrored:
				var ti := first
				while ti < P.ix.size():
					var sw := P.ix[ti + 1]
					P.ix[ti + 1] = P.ix[ti + 2]
					P.ix[ti + 2] = sw
					ti += 3
	if not extra.is_null():
		extra.call(cm, body)
	# ---- the layers ----
	cm.batch = RigidBatch.new(cm.rest.size(), 8)
	cm.body_mat = _table(cm, body, RigidBatch.MATRIX_SHADER, row_kinds)
	cm.batch.add_layer(body.commit(), cm.body_mat, true)
	if not clear.ix.is_empty():
		cm.clear_mat = _table(cm, clear, RigidBatch.CLEAR_SHADER, row_kinds)
		cm.batch.add_layer(clear.commit(), cm.clear_mat, false)
	if not glow_fill.is_null() or not glow_parts.is_empty():
		var soup := RobotGfx.SpriteSoup.new()
		if not glow_fill.is_null():
			glow_fill.call(soup, cm)
		for gp: Array in glow_parts:
			soup.solid(gp[0], gp[1], gp[2])
		var glow := ShaderMaterial.new()
		glow.shader = RigidBatch.GLOW_SHADER
		cm.batch.add_layer(soup.commit(), glow, false)
	var bar := ShaderMaterial.new()
	bar.shader = RigidBatch.BAR_SHADER
	bar.render_priority = 100
	cm.batch.add_layer(RobotGfx.build_bar_mesh(), bar, false)
	root.free()
	return cm


## The material table: one row per JS material. pbr.w: the opacity, in the blended layer.
static func _table(cm: CreatureModel, P: Parts, shader: Shader, row_kinds: Dictionary) -> ShaderMaterial:
	var albedo := PackedVector4Array()
	var pbr := PackedVector4Array()
	var emit := PackedVector4Array()
	var rim := PackedVector4Array()
	var images: Array[Image] = []
	var layers := {}
	var layer_of := func(t: Texture2D) -> float:
		var tid := t.get_instance_id()
		if not layers.has(tid):
			var img: Image = t.get_image()
			if img.is_compressed():
				img.decompress()
			img.convert(Image.FORMAT_RGBA8)
			img.resize(512, 512, Image.INTERPOLATE_LANCZOS)
			img.generate_mipmaps()
			layers[tid] = float(images.size())
			images.append(img)
		return layers[tid]
	for row in mini(P.mats.size(), MAX_ROWS):
		var b := P.mats[row] as BaseMaterial3D
		var c := b.albedo_color.srgb_to_linear() if b != null else Color.WHITE
		var layer := -1.0
		if b != null and b.albedo_texture != null:
			layer = layer_of.call(b.albedo_texture)
		albedo.append(Vector4(c.r, c.g, c.b, layer))
		var unlit: bool = b != null and b.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
		var kind := 4.0 if unlit else 0.0
		var nm := b.resource_name.rsplit("_", true, 1)[0] if b != null else ""      # (the exporter adds _<index>)
		cm.rows[nm] = row
		kind = float(row_kinds.get(nm, kind))
		# the JS's own emissive; wetSkin's rim and glow come through the name the expression gave it: wet_<sss hex>_<strength %>_<glow source>, or glow_<source>
		var e := Color.BLACK
		var e_layer := -1.0
		if b != null and b.emission_enabled:
			e = b.emission.srgb_to_linear() * b.emission_energy_multiplier
			if b.emission_texture != null:
				e_layer = layer_of.call(b.emission_texture)
		emit.append(Vector4(e.r, e.g, e.b, e_layer))
		var tag := nm.split("_")
		if b != null and b.albedo_texture != null:
			cm.textures[tag[tag.size() - 1]] = b.albedo_texture
		if tag[0] == "wet" and tag.size() >= 4:
			var sc := RigidBatch.lin(tag[1].hex_to_int()) * (float(tag[2]) / 100.0)
			rim.append(Vector4(sc.r, sc.g, sc.b, float(tag[3])))
		elif tag[0] == "glow" and tag.size() >= 2:
			rim.append(Vector4(0.0, 0.0, 0.0, float(tag[1])))
		else:
			rim.append(Vector4.ZERO)
		pbr.append(Vector4(b.roughness if b != null else 1.0, b.metallic if b != null else 0.0, kind, c.a if shader == RigidBatch.CLEAR_SHADER else 0.0))
	while albedo.size() < MAX_ROWS:
		albedo.append(Vector4(1, 1, 1, -1))
		pbr.append(Vector4(1, 0, 0, 1))
		emit.append(Vector4(0, 0, 0, -1))
		rim.append(Vector4.ZERO)
	if images.is_empty():
		var px := Image.create(4, 4, true, Image.FORMAT_RGBA8)
		px.fill(Color.WHITE)
		px.generate_mipmaps()
		images.append(px)
	var maps := Texture2DArray.new()
	maps.create_from_images(images)
	var mt := ShaderMaterial.new()
	mt.shader = shader
	mt.set_shader_parameter(&"maps", maps)
	mt.set_shader_parameter(&"mat_albedo", albedo)
	mt.set_shader_parameter(&"mat_pbr", pbr)
	mt.set_shader_parameter(&"mat_emit", emit)
	mt.set_shader_parameter(&"mat_rim", rim)
	return mt


## The importer makes one material per mesh even where the JS shared one: equal ones share a row.
static func _mat_key(m: Material) -> String:
	var b := m as BaseMaterial3D
	if b == null:
		return "none"
	return "%s|%.3f|%.3f|%d|%d|%s" % [b.albedo_color.to_html(), b.roughness, b.metallic, b.shading_mode, b.albedo_texture.get_instance_id() if b.albedo_texture != null else 0, b.resource_name]
