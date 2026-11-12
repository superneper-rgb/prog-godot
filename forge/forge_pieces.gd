class_name ForgePieces
extends RefCounted
## FORGE: the original level, piece by piece. Reads assets/levels/<id>/pieces.json (tools/export/page.js writePieces) and lets the editor pick, hide, move, turn and tint
## what the three.js level built, with the colliders that go with it. The level stays merged: only what an edit touches is cut out of its merged mesh (once, when the edit
## is applied), and only a moved or tinted piece draws on its own. Instanced things (MultiMesh) are edited in place, one instance's transform at a time.
##
## Finding a piece's triangles: Godot reorders triangles inside a merged mesh on import, so pieces.json gives each part's bounds in the mesh's own space and the rule is
## "a triangle belongs to the smallest part whose bounds (grown by EPS) hold its three corners"; the exporter lists the triangles that rule gets wrong by their centre (exc).
## An object (one source object of the JS scene, by its path) may have parts in several meshes (one per material) and colliders (indices into colliders.json).

const EPS := 0.01
const EXC_CELL := 0.05

class Bucket:
	var name := ""
	var mi: MeshInstance3D
	var orig: Mesh                     # as imported (put back when nothing in it is edited)
	var boxes: Array[AABB] = []        # per part, in the mesh's own space
	var owner: PackedInt32Array        # per part: its object
	var order: PackedInt32Array        # parts, smallest first
	var vol: PackedFloat32Array
	var exc := {}                      # Vector3i cell -> [[centre, part], ...]
	var tol := 0.003                   # how far a centre may sit from the exporter's (vertex compression)
	var tris := {}                     # part -> PackedInt32Array of its triangles in orig (found once)
	var exc_tri: Variant = null        # triangle -> part, for the triangles the exceptions claim (found once)
	var faces := PackedVector3Array()  # current mesh's triangles, for picking
	var tm: TriangleMesh = null
	var cut := {}                      # part -> true: drawn elsewhere or not at all
	var eps := EPS                     # how far past its bounds a part still holds a triangle (pieces.json: grows with the mesh, for the vertex compression)


class Obj:
	var id := ""
	var name := ""
	var box: AABB                      # world bounds as exported
	var parts: Array = []              # [[bucket name, part]]
	var solids: Array = []             # World.Solid
	var dyn := false                   # moves or switches in play: not editable here
	var inst: Array = []               # [tpl, ordinal, index] for an instanced thing
	var lifted: Array[MeshInstance3D] = []
	var saved := {}                    # Solid -> its exported state; MultiMesh instance -> transform


var level: ExportedLevel
var buckets := {}       # name -> Bucket
var objs: Array[Obj] = []
var by_id := {}         # id -> Obj
var _mm := {}           # "tpl#ord" -> MultiMeshInstance3D
var _mm_list: Array[MultiMeshInstance3D] = []


static func load_for(lv: Level) -> ForgePieces:
	if not lv is ExportedLevel:
		return null
	var p := "res://assets/levels/%s/pieces.json" % lv.id
	if not FileAccess.file_exists(p):
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
	if not data is Dictionary:
		push_warning("forge: %s is not readable" % p)
		return null
	var P := ForgePieces.new()
	P.level = lv
	P._read(data)
	return P


static func _aabb(a: Array, at: int) -> AABB:
	var lo := Vector3(float(a[at]), float(a[at + 1]), float(a[at + 2]))
	return AABB(lo, Vector3(float(a[at + 3]), float(a[at + 4]), float(a[at + 5])) - lo)


func _read(data: Dictionary) -> void:
	var lv := level
	var bd: Dictionary = data.get("buckets", {})
	for name: String in bd:
		var nd: Variant = lv._nodes.get(StringName(name))
		if nd == null or not is_instance_valid(nd) or not nd is MeshInstance3D or (nd as MeshInstance3D).mesh == null:
			continue      # (a level script freed or replaced it: not editable here)
		var mi := nd as MeshInstance3D
		var b := Bucket.new()
		b.name = name
		b.mi = mi
		b.orig = mi.mesh
		var d: Dictionary = bd[name]
		b.eps = float(d.get("eps", EPS))
		var parts: Array = d.parts
		b.owner.resize(parts.size())
		b.vol.resize(parts.size())
		for i in parts.size():
			var q: Array = parts[i]
			b.owner[i] = int(q[0])
			var bx := _aabb(q, 1)
			b.boxes.append(bx)
			b.vol[i] = maxf(bx.size.x, 0.01) * maxf(bx.size.y, 0.01) * maxf(bx.size.z, 0.01)
		var ord := range(parts.size())
		ord.sort_custom(func(x: int, y: int) -> bool: return b.vol[x] < b.vol[y] or (b.vol[x] == b.vol[y] and x < y))
		b.order = PackedInt32Array(ord)
		var ext := b.orig.get_aabb().size
		b.tol = maxf(0.004, maxf(ext.x, maxf(ext.y, ext.z)) / 12000.0)
		var ex: Array = d.get("exc", [])
		for i in range(0, ex.size(), 4):
			var c := Vector3(float(ex[i]), float(ex[i + 1]), float(ex[i + 2]))
			var k := Vector3i((c / EXC_CELL).floor())
			if not b.exc.has(k):
				b.exc[k] = []
			b.exc[k].append([c, int(ex[i + 3]), i / 4])
		buckets[name] = b
	var ol: Array = data.get("objects", [])
	for j: Dictionary in ol:
		var o := Obj.new()
		o.id = String(j.id)
		o.name = String(j.get("name", ""))
		o.box = _aabb(j.box, 0)
		o.parts = j.get("parts", [])
		o.dyn = j.has("dyn")
		o.inst = j.get("inst", [])
		for si: Variant in j.get("solids", []):
			var s: Variant = lv.solid_at[int(si)] if int(si) < lv.solid_at.size() else null
			if s != null:
				o.solids.append(s)
		objs.append(o)
		by_id[o.id] = o
	var seen := {}
	for e: Array in lv.inst_nodes:
		var tpl := String(e[0])
		var n: int = seen.get(tpl, 0)
		seen[tpl] = n + 1
		if e[1] != null:
			_mm["%s#%d" % [tpl, n]] = e[1]
			if (e[1] as MultiMeshInstance3D).multimesh.instance_count <= 4096:      # (grass and reeds by the thousand are not picked one by one)
				_mm_list.append(e[1])


# ---- which part a triangle belongs to ----

func _inside(bx: AABB, p: Vector3, e: float) -> bool:
	return p.x >= bx.position.x - e and p.y >= bx.position.y - e and p.z >= bx.position.z - e and p.x <= bx.end.x + e and p.y <= bx.end.y + e and p.z <= bx.end.z + e


## the exception entry whose centre is this triangle's (and, given `used`, one not already claimed: two identical triangles stacked in one place are two entries, one each)
func _exception(b: Bucket, c: Vector3, used: Variant = null) -> Variant:
	if b.exc.is_empty():
		return null
	var f := c / EXC_CELL
	var k := Vector3i(f.floor())
	for dx in [0, -1, 1]:
		for dy in [0, -1, 1]:
			for dz in [0, -1, 1]:
				if (dx != 0 and absf(f.x - roundf(f.x)) > 0.2) or (dy != 0 and absf(f.y - roundf(f.y)) > 0.2) or (dz != 0 and absf(f.z - roundf(f.z)) > 0.2):
					continue      # (only the cells next door when the centre sits near their edge)
				for it: Array in b.exc.get(k + Vector3i(dx, dy, dz), []):
					if (it[0] as Vector3).distance_to(c) <= b.tol and (used == null or not (used as Dictionary).has(it[2])):
						return it
	return null


func _rule(b: Bucket, p0: Vector3, p1: Vector3, p2: Vector3) -> int:
	for pi in b.order:
		var bx := b.boxes[pi]
		if _inside(bx, p0, b.eps) and _inside(bx, p1, b.eps) and _inside(bx, p2, b.eps):
			return pi
	return -1


## the part a triangle (corners in the mesh's own space) belongs to, -1 if none (for picking: one triangle, so a stacked twin may answer for the other)
func part_of(b: Bucket, p0: Vector3, p1: Vector3, p2: Vector3) -> int:
	var e: Variant = _exception(b, (p0 + p1 + p2) / 3.0)
	return int(e[1]) if e != null else _rule(b, p0, p1, p2)


## the triangles the exceptions claim, each entry claiming one triangle (one pass over the mesh, once)
func _exc_tris(b: Bucket, v: PackedVector3Array, ix: PackedInt32Array, n: int) -> Dictionary:
	if b.exc_tri != null:
		return b.exc_tri
	var out := {}
	if not b.exc.is_empty():
		var used := {}
		for t in n:
			var c := (v[ix[t * 3]] + v[ix[t * 3 + 1]] + v[ix[t * 3 + 2]]) / 3.0 if not ix.is_empty() else (v[t * 3] + v[t * 3 + 1] + v[t * 3 + 2]) / 3.0
			var it: Variant = _exception(b, c, used)
			if it != null:
				used[it[2]] = true
				out[t] = int(it[1])
	b.exc_tri = out
	return out


## a part's triangles in the imported mesh (found once, then kept)
func part_tris(b: Bucket, pi: int) -> PackedInt32Array:
	if b.tris.has(pi):
		return b.tris[pi]
	var a := b.orig.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var ix: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var n := ix.size() / 3 if not ix.is_empty() else v.size() / 3
	var ex := _exc_tris(b, v, ix, n)
	var bx := b.boxes[pi]
	var out := PackedInt32Array()
	for t in n:
		if ex.has(t):
			if int(ex[t]) == pi:
				out.append(t)
			continue
		var p0 := v[ix[t * 3]] if not ix.is_empty() else v[t * 3]
		var p1 := v[ix[t * 3 + 1]] if not ix.is_empty() else v[t * 3 + 1]
		var p2 := v[ix[t * 3 + 2]] if not ix.is_empty() else v[t * 3 + 2]
		if _inside(bx, p0, b.eps) and _inside(bx, p1, b.eps) and _inside(bx, p2, b.eps) and _rule(b, p0, p1, p2) == pi:
			out.append(t)
	b.tris[pi] = out
	return out


# ---- building the cut meshes ----

## the imported mesh's surface with only these triangles (null: all but the cut parts')
func _sub_mesh(b: Bucket, keep: Variant) -> ArrayMesh:
	var a := b.orig.surface_get_arrays(0)
	var ix: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var nv := (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var tri_count := ix.size() / 3 if not ix.is_empty() else nv / 3
	var list := PackedInt32Array()
	if keep is PackedInt32Array:
		list = keep
	else:
		var drop := {}
		for pi: int in b.cut:
			for t in part_tris(b, pi):
				drop[t] = true
		list.resize(tri_count - drop.size())
		var k := 0
		for t in tri_count:
			if not drop.has(t):
				list[k] = t
				k += 1
		list.resize(k)
	var out := PackedInt32Array()
	out.resize(list.size() * 3)
	for i in list.size():
		var t := list[i]
		for c in 3:
			out[i * 3 + c] = ix[t * 3 + c] if not ix.is_empty() else t * 3 + c
	a[Mesh.ARRAY_INDEX] = out
	for k2: int in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
		a[k2] = null
	var m := ArrayMesh.new()
	if out.is_empty():
		return m
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	m.surface_set_material(0, b.orig.surface_get_material(0))
	return m


func _rebuild(b: Bucket) -> void:
	if not is_instance_valid(b.mi):
		return
	b.mi.mesh = b.orig if b.cut.is_empty() else _sub_mesh(b, null)
	b.tm = null
	b.faces = PackedVector3Array()


# ---- edits ----

func obj(id: String) -> Obj:
	return by_id.get(id)


## the world transform an edit gives a piece: turn by rot (degrees, yaw only for level pieces) about its middle, then move by pos
static func delta(o: Obj, e: ForgeEdits.Obj) -> Transform3D:
	var c := o.box.get_center()
	var r := Basis(Vector3.UP, deg_to_rad(e.rot.y))
	return Transform3D(r, c + e.pos) * Transform3D(Basis.IDENTITY, -c)


## put an object the way its edit says (e null: as exported)
func apply(id: String, e: ForgeEdits.Obj) -> void:
	var o := obj(id)
	if o == null:
		return
	for m in o.lifted:
		m.queue_free()
	o.lifted.clear()
	var moved := e != null and (e.pos != Vector3.ZERO or not is_zero_approx(e.rot.y))
	var tinted := e != null and e.color != ""
	var gone := e != null and e.hidden
	var D := delta(o, e) if e != null else Transform3D.IDENTITY
	if not o.inst.is_empty():
		_apply_inst(o, e, D, gone)
	else:
		var touched := {}
		for pr: Array in o.parts:
			var b: Bucket = buckets.get(String(pr[0]))
			if b == null or not is_instance_valid(b.mi):
				continue
			var pi := int(pr[1])
			if e != null and (gone or moved or tinted):
				b.cut[pi] = true
			else:
				b.cut.erase(pi)
			touched[b] = true
			if e != null and not gone and (moved or tinted):
				_lift(o, b, pi, D, e.color)
		for b: Bucket in touched:
			_rebuild(b)
	_apply_solids(o, e, D, gone)


func _lift(o: Obj, b: Bucket, pi: int, D: Transform3D, color: String) -> void:
	var m := MeshInstance3D.new()
	m.name = "ForgePiece"
	m.mesh = _sub_mesh(b, part_tris(b, pi))
	m.material_override = b.mi.material_override
	if b.mi.get_surface_override_material_count() > 0 and b.mi.get_surface_override_material(0) != null:
		m.set_surface_override_material(0, b.mi.get_surface_override_material(0))
	m.cast_shadow = b.mi.cast_shadow
	m.layers = b.mi.layers
	if color != "":
		var src: Material = m.material_override if m.material_override != null else m.get_active_material(0)
		if src is BaseMaterial3D:
			var t := (src as BaseMaterial3D).duplicate() as BaseMaterial3D
			t.albedo_color = Color(color)
			m.material_override = t
	b.mi.get_parent().add_child(m)
	m.global_transform = D * b.mi.global_transform
	o.lifted.append(m)


func _apply_inst(o: Obj, e: ForgeEdits.Obj, D: Transform3D, gone: bool) -> void:
	var mmi: MultiMeshInstance3D = _mm.get("%s#%d" % [o.inst[0], int(o.inst[1])])
	if mmi == null:
		return
	var j := int(o.inst[2])
	var mm := mmi.multimesh
	if not o.saved.has(&"xf"):
		o.saved[&"xf"] = mm.get_instance_transform(j)
	var x0: Transform3D = o.saved[&"xf"]
	if e == null:
		mm.set_instance_transform(j, x0)
	elif gone:
		mm.set_instance_transform(j, Transform3D(Basis.from_scale(Vector3.ZERO), x0.origin))      # (a zero-size instance draws nothing)
	else:
		var G := mmi.global_transform
		mm.set_instance_transform(j, G.affine_inverse() * D * G * x0)


func _apply_solids(o: Obj, e: ForgeEdits.Obj, D: Transform3D, gone: bool) -> void:
	for s: World.Solid in o.solids:
		if not o.saved.has(s):
			o.saved[s] = [s.cx, s.cz, s.yaw, s.bottom, s.top, s.top_low, s.off]
		var v: Array = o.saved[s]
		if s.kind == "mesh" or s.kind == "field":
			continue
		var c := D * Vector3(float(v[0]), 0.0, float(v[1]))      # (the turn is about the vertical only, so the height does not mix in)
		var dy := e.pos.y if e != null else 0.0
		s.place(c.x, c.z, float(v[2]) + (deg_to_rad(e.rot.y) if e != null else 0.0))
		s.set_span(float(v[3]) + dy, float(v[4]) + dy, float(v[5]) + dy)
		s.set_off(bool(v[6]) or gone or (e != null and not e.collide))


## the pointer passes through an object's colliders while it is being moved
func hold(id: String, on: bool, e: ForgeEdits.Obj) -> void:
	var o := obj(id)
	if o == null:
		return
	for s: World.Solid in o.solids:
		if not o.saved.has(s):
			o.saved[s] = [s.cx, s.cz, s.yaw, s.bottom, s.top, s.top_low, s.off]
		var v: Array = o.saved[s]
		s.set_off(on or bool(v[6]) or (e != null and (e.hidden or not e.collide)))


# ---- where things are ----

## an object's world box as edited: centre, rotation, size
func oriented(id: String, e: ForgeEdits.Obj) -> Array:
	var o := obj(id)
	if o == null:
		return [Vector3.ZERO, Basis.IDENTITY, Vector3.ONE]
	var c := o.box.get_center() + (e.pos if e != null else Vector3.ZERO)
	return [c, Basis(Vector3.UP, deg_to_rad(e.rot.y)) if e != null else Basis.IDENTITY, o.box.size]


## the original piece under a ray: {id, t, n} or empty. Merged meshes by their exact triangles; moved pieces and instances by their own meshes / boxes.
func pick(ro: Vector3, rd: Vector3, edits: ForgeEdits) -> Dictionary:
	var best := {}
	var bt := INF
	var cands: Array = []
	for name: String in buckets:
		var b: Bucket = buckets[name]
		if not is_instance_valid(b.mi) or not b.mi.is_visible_in_tree():
			continue      # (a level script may free or hide a mesh while it plays)
		var g := b.mi.global_transform * b.mi.get_aabb()
		var hit: Variant = g.intersects_ray(ro, rd)
		if hit == null and not g.has_point(ro):
			continue
		cands.append([ro.distance_to(hit) if hit != null else 0.0, b])
	cands.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	for c: Array in cands:
		if float(c[0]) > bt:
			break
		var b: Bucket = c[1]
		if b.mi.mesh == null or b.mi.mesh.get_surface_count() == 0:
			continue
		if b.tm == null:
			b.faces = b.mi.mesh.get_faces()
			b.tm = TriangleMesh.new()
			b.tm.create_from_faces(b.faces)
		var inv := b.mi.global_transform.affine_inverse()
		var r := b.tm.intersect_ray(inv * ro, (inv.basis * rd).normalized())
		if r.is_empty():
			continue
		var wp: Vector3 = b.mi.global_transform * (r.position as Vector3)
		var t := ro.distance_to(wp)
		if t >= bt:
			continue
		var f := int(r.get("face_index", -1))
		if f < 0 or f * 3 + 2 >= b.faces.size():
			continue
		var pi := part_of(b, b.faces[f * 3], b.faces[f * 3 + 1], b.faces[f * 3 + 2])
		if pi < 0:
			continue
		bt = t
		best = {"id": objs[b.owner[pi]].id, "t": t, "n": (b.mi.global_transform.basis * (r.normal as Vector3)).normalized()}
	# moved pieces draw on their own
	for o in objs:
		for m in o.lifted:
			var h: Variant = ForgeLayer.box_hit(ro, rd, m.global_transform * m.get_aabb().get_center(), m.global_transform.basis.orthonormalized(), m.get_aabb().size * m.global_transform.basis.get_scale() / 2.0)
			if h != null and float(h[0]) < bt:
				bt = h[0]
				best = {"id": o.id, "t": bt, "n": h[1]}
	# instanced things, one box each
	for mmi in _mm_list:
		if not is_instance_valid(mmi) or not mmi.is_visible_in_tree():
			continue
		var g := mmi.global_transform * mmi.multimesh.get_aabb()
		if g.intersects_ray(ro, rd) == null:
			continue
		var mm := mmi.multimesh
		var mb := mm.mesh.get_aabb()
		for j in mm.instance_count:
			var x := mmi.global_transform * mm.get_instance_transform(j)
			var sc := x.basis.get_scale()
			if sc.x < 1e-5:
				continue
			var h: Variant = ForgeLayer.box_hit(ro, rd, x * mb.get_center(), x.basis.orthonormalized(), mb.size * sc / 2.0)
			if h != null and float(h[0]) < bt:
				var id := _inst_id(mmi, j)
				if id != "":
					bt = h[0]
					best = {"id": id, "t": bt, "n": h[1]}
	return best


func _inst_id(mmi: MultiMeshInstance3D, j: int) -> String:
	for k: String in _mm:
		if _mm[k] == mmi:
			var id := "inst:%s#%d" % [k, j]
			if not by_id.has(id):      # (an instance with no collider of its own is not in pieces.json: it is made known here)
				var p := k.rsplit("#", true, 1)
				var o := Obj.new()
				o.id = id
				o.name = String(p[0]).trim_prefix("i").lstrip("0123456789").trim_prefix("_").replace("_", " ")
				var x := mmi.global_transform * mmi.multimesh.get_instance_transform(j)
				o.box = x * mmi.multimesh.mesh.get_aabb()
				o.inst = [p[0], int(p[1]), j]
				objs.append(o)
				by_id[id] = o
			return id
	return ""


## the mesh of an original piece as a placeable thing (FORGE copies of a level piece): one ArrayMesh in the piece's own centred space, its size
func copy_mesh(id: String) -> Array:
	var o := obj(id)
	if o == null:
		return []
	var out := ArrayMesh.new()
	var c := o.box.get_center()
	if not o.inst.is_empty():
		var mmi: MultiMeshInstance3D = _mm.get("%s#%d" % [o.inst[0], int(o.inst[1])])
		if mmi == null:
			return []
		var src := mmi.multimesh.mesh
		var x: Transform3D = o.saved.get(&"xf", mmi.multimesh.get_instance_transform(int(o.inst[2])))
		var xf := Transform3D(Basis.IDENTITY, -c) * mmi.global_transform * x
		for s in src.get_surface_count():
			var a := src.surface_get_arrays(s)
			a[Mesh.ARRAY_VERTEX] = xf * (a[Mesh.ARRAY_VERTEX] as PackedVector3Array)
			if a[Mesh.ARRAY_NORMAL] != null:
				a[Mesh.ARRAY_NORMAL] = Transform3D(xf.basis.inverse().transposed(), Vector3.ZERO) * (a[Mesh.ARRAY_NORMAL] as PackedVector3Array)
			a[Mesh.ARRAY_TANGENT] = null
			for k2: int in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3, Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS]:
				a[k2] = null
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
			out.surface_set_material(out.get_surface_count() - 1, mmi.material_override if mmi.material_override != null else src.surface_get_material(s))
		return [out, o.box.size]
	for pr: Array in o.parts:
		var b: Bucket = buckets.get(String(pr[0]))
		if b == null:
			continue
		var sub := _sub_mesh(b, part_tris(b, int(pr[1])))
		if sub.get_surface_count() == 0:
			continue
		var a := sub.surface_get_arrays(0)
		var xf := Transform3D(Basis.IDENTITY, -c) * b.mi.global_transform
		a[Mesh.ARRAY_VERTEX] = xf * (a[Mesh.ARRAY_VERTEX] as PackedVector3Array)
		if a[Mesh.ARRAY_NORMAL] != null:
			a[Mesh.ARRAY_NORMAL] = Transform3D(xf.basis.inverse().transposed(), Vector3.ZERO) * (a[Mesh.ARRAY_NORMAL] as PackedVector3Array)
		a[Mesh.ARRAY_TANGENT] = null
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		var mat: Material = b.mi.material_override
		if mat == null and b.mi.get_surface_override_material_count() > 0:
			mat = b.mi.get_surface_override_material(0)
		out.surface_set_material(out.get_surface_count() - 1, mat if mat != null else b.orig.surface_get_material(0))
	return [out, o.box.size]
