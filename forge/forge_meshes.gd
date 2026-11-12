class_name ForgeMeshes
extends RefCounted
## FORGE: one ArrayMesh per catalogue entry and colour, shared by every copy (ForgeLayer draws the copies as one MultiMesh). Built once per session from the entry's own builder
## (DevProps.build_object for shapes and props, the imported .glb for a model), flattened into one mesh with a surface per material, centred on its bounds like the dev props.
## A model's real bounds replace the CREDITS estimate in its entry's `base`, so its size is exact from the first copy on.

static var _cache := {}      # key -> ArrayMesh


## the scale that draws this entry's mesh at `size` (the mesh's own bounds, not the entry's base: the dev shapes are unit meshes, the dev props are built at their real size)
static func scale_for(e: Dictionary, color: String, size: Vector3) -> Vector3:
	var b := mesh_for(e, color).get_aabb().size
	return Vector3(size.x / b.x if b.x > 1e-4 else 1.0, size.y / b.y if b.y > 1e-4 else 1.0, size.z / b.z if b.z > 1e-4 else 1.0)


static func key_for(e: Dictionary, color: String) -> String:
	if e.kind == "copy":
		return "copy:%s:%s" % [e.key, color]
	return "%s:%s" % [e.id, color] if e.kind != "model" else "model:%s:%s" % [e.id, color]


static func mesh_for(e: Dictionary, color: String) -> ArrayMesh:
	var k := key_for(e, color)
	if _cache.has(k):
		return _cache[k]
	if String(e.kind) == "copy":      # a piece of the original level (ForgeCatalogue.copy_entry): its mesh is made already
		var cm: ArrayMesh = e.mesh
		if color != "":
			cm = cm.duplicate() as ArrayMesh
			_tint(cm, color)
		_cache[k] = cm
		return cm
	var root: Node3D
	var is_model := String(e.kind) == "model"
	if is_model:
		var ps: PackedScene = load(String(e.file))
		root = ps.instantiate() if ps != null else Node3D.new()
	else:
		root = DevProps.build_object(e, color if color != "" else String(e.color), Vector3(e.base[0], e.base[1], e.base[2]))
		root.scale = Vector3.ONE
	var out := flatten(root, is_model)
	root.free()
	if is_model and color != "":      # a tinted copy: the polyfork models are plain white, their levels colour them
		_tint(out, color)
	if is_model:
		var sz := out.get_aabb().size
		e.base = [maxf(sz.x, 0.01), maxf(sz.y, 0.01), maxf(sz.z, 0.01)]
	_cache[k] = out
	return out


## a node's transform relative to an ancestor (the tree is not entered, so no global transforms)
static func _rel(n: Node, root: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	while n != null and n != root:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


## Every MeshInstance3D under root as one ArrayMesh in root's space (materials kept, one surface each). centre: move the bounds' centre to the origin.
static func flatten(root: Node3D, centre: bool) -> ArrayMesh:
	var parts: Array = []      # [arrays, material]
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var xf := _rel(mi, root)
		var nb := xf.basis.inverse().transposed()
		for s in mi.mesh.get_surface_count():
			if mi.mesh is ArrayMesh and (mi.mesh as ArrayMesh).surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:      # (a PrimitiveMesh is always triangles)
				continue
			var a := mi.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = xf * (a[Mesh.ARRAY_VERTEX] as PackedVector3Array)
			a[Mesh.ARRAY_VERTEX] = v
			if a[Mesh.ARRAY_NORMAL] != null:
				a[Mesh.ARRAY_NORMAL] = Transform3D(nb, Vector3.ZERO) * (a[Mesh.ARRAY_NORMAL] as PackedVector3Array)
			if a[Mesh.ARRAY_TANGENT] != null:
				var t: PackedFloat32Array = a[Mesh.ARRAY_TANGENT]
				for i in range(0, t.size(), 4):
					var tv := (xf.basis * Vector3(t[i], t[i + 1], t[i + 2])).normalized()
					t[i] = tv.x
					t[i + 1] = tv.y
					t[i + 2] = tv.z
				a[Mesh.ARRAY_TANGENT] = t
			for k: int in [Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS, Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
				a[k] = null
			for p in v:
				lo = lo.min(p)
				hi = hi.max(p)
			var mat: Material = mi.get_surface_override_material(s)
			if mat == null:
				mat = mi.material_override
			if mat == null:
				mat = mi.mesh.surface_get_material(s)
			parts.append([a, mat])
	var out := ArrayMesh.new()
	if parts.is_empty():
		return out
	var shift := -(lo + hi) * 0.5 if centre else Vector3.ZERO
	for pa: Array in parts:
		var a: Array = pa[0]
		if shift != Vector3.ZERO:
			a[Mesh.ARRAY_VERTEX] = Transform3D(Basis.IDENTITY, shift) * (a[Mesh.ARRAY_VERTEX] as PackedVector3Array)
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		out.surface_set_material(out.get_surface_count() - 1, pa[1])
	return out


## every plain material of a mesh, recoloured (shader materials are left as they are)
static func _tint(m: ArrayMesh, color: String) -> void:
	for i in m.get_surface_count():
		var src := m.surface_get_material(i)
		if src is BaseMaterial3D:
			var t := (src as BaseMaterial3D).duplicate() as BaseMaterial3D
			t.albedo_color = Color(color)
			m.surface_set_material(i, t)
