class_name StandCanopy
extends RefCounted
## Fixes the FOINT DOGS stand's umbrella in FOINT CITY, which z-fought (user, 2026-11-16, at 16.3, -10, 191.8).
## The export draws the canopy as a stack of thin slabs, red squares and cream diamonds, whose tops all sit at exactly the same height (y -7.33): the JS hid the tie, a Godot depth buffer cannot.
## At level load each slab (a run of 10 triangles in the district's merged block) is lifted by a hair more than the one before, so the layers read in a fixed order and the red/cream pattern stays.

const AREA := AABB(Vector3(16.0, -7.45, 189.0), Vector3(6.0, 0.2, 6.0))      # the canopy's slabs: top at -7.33, bottom -7.39
const SLAB_TRIS := 10      # a slab is a top and four sides (no underside)
const LIFT := 0.006      # per slab; the slabs are 0.06 thick, the stack is about 0.1 m, nobody sees the steps


static func apply(level: Node) -> void:
	var st: Array[Node] = [level]
	while not st.is_empty():
		var n: Node = st.pop_back()
		for k in n.get_children():
			st.append(k)
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null or not mi.visible:
			continue
		var am := mi.mesh as ArrayMesh
		if am == null or am.get_surface_count() != 1 or am.surface_get_array_len(0) > 200000:
			continue
		if not (mi.global_transform * mi.get_aabb()).encloses(AREA):
			continue
		if _lift(mi, am):
			return


static func _lift(mi: MeshInstance3D, am: ArrayMesh) -> bool:
	var arr := am.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	# Other meshes enclosing the canopy can be unindexed; only its indexed slabs can be lifted.
	if not arr[Mesh.ARRAY_INDEX] is PackedInt32Array:
		return false
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	if idx.is_empty():
		return false
	var tris: Array[int] = []
	for t in idx.size() / 3:
		var c := (v[idx[t * 3]] + v[idx[t * 3 + 1]] + v[idx[t * 3 + 2]]) / 3.0
		if AREA.has_point(mi.global_transform * c):
			tris.append(t)
	if tris.is_empty() or tris.size() % SLAB_TRIS != 0:
		if not tris.is_empty():
			push_warning("StandCanopy: %d triangles in the canopy, not a whole number of slabs: left alone" % tris.size())
		return false
	var done := {}
	for j in tris.size():
		var dy := float(j / SLAB_TRIS) * LIFT
		for q in 3:
			var vi := idx[tris[j] * 3 + q]
			if not done.has(vi):
				done[vi] = true
				v[vi].y += dy
	arr[Mesh.ARRAY_VERTEX] = v
	var mat := am.surface_get_material(0)
	var fmt := am.surface_get_format(0)
	am.clear_surfaces()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, fmt & ~(Mesh.ARRAY_FORMAT_VERTEX | Mesh.ARRAY_FORMAT_NORMAL | Mesh.ARRAY_FORMAT_COLOR | Mesh.ARRAY_FORMAT_INDEX | Mesh.ARRAY_FORMAT_TEX_UV | Mesh.ARRAY_FORMAT_TANGENT))
	am.surface_set_material(0, mat)
	return true

