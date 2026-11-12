class_name ForgeLayer
extends Node3D
## FORGE: what the editor placed in this level, built from assets/levels/<id>/edits.json every time the level is built (Game.enter_level calls attach() right after Level.build, before the colliders settle).
## It is a child of the Level, so it goes when the level goes. Copies of one thing share one mesh and draw as one MultiMesh. Each copy gets solids in the level's World
## (DevProps' yaw-only footprints when it stands upright; a tilted one gets a convex box, which the dev tools never had). The editor changes it only through apply(op).

class Placed:
	var uid := ""
	var key := ""             # ForgeMeshes key: which MultiMesh it draws in
	var solids: Array[World.Solid] = []


class Group:
	var mmi: MultiMeshInstance3D
	var uids: Array[String] = []
	var dirty := true


var edits: ForgeEdits
var world: World
var pieces: ForgePieces = null     # the original level, piece by piece (loaded when an edit or the editor needs it)
var _pieces_tried := false
var load_ms := 0.0                 # what applying edits.json cost this level's load
var placed := {}      # uid -> Placed
var groups := {}      # key -> Group
var held := {}        # uid -> true: no solids while it is being moved (the pointer passes through it)
var _missing := {}    # uids whose catalogue entry is gone (kept in the file, not drawn)
var _by_body := {}    # solid body RID -> Solid, for telling what the pointer hit
const SEE_THROUGH := ["bound", "guard"]      # the levels' invisible boundary walls: the pointer passes through them


static func attach(level: Level) -> ForgeLayer:
	var t0 := Time.get_ticks_usec()
	var l := ForgeLayer.new()
	l.name = "ForgeLayer"
	l.world = level.world
	l.edits = ForgeEdits.load_for(level.id)
	level.add_child(l)
	for uid: String in l.edits.objects:
		l._sync(uid)
	l._flush()
	l.load_ms = (Time.get_ticks_usec() - t0) / 1000.0
	return l


## the original level's pieces (null on a level with no pieces.json)
func get_pieces() -> ForgePieces:
	if not _pieces_tried:
		_pieces_tried = true
		pieces = ForgePieces.load_for(get_parent() as Level)
	return pieces


static func is_orig(uid: String) -> bool:
	return uid.begins_with("o:")


func entry(o: ForgeEdits.Obj) -> Variant:
	if o.type == "copy":
		return ForgeCatalogue.copy_entry(self, o.id)
	return ForgeCatalogue.find(o.type, o.id)


## THE way the editor changes the level: the data first, then what is drawn and solid. Returns the op that undoes it.
func apply(op: Dictionary) -> Dictionary:
	var inv := edits.apply_op(op)
	for uid in ForgeEdits.op_uids(op):
		_sync(uid)
	_flush()
	return inv


## the transform a placed object draws with: rotation, then its size over the mesh's own size
func xform(o: ForgeEdits.Obj, e: Dictionary) -> Transform3D:
	return Transform3D(obj_basis(o) * Basis.from_scale(ForgeMeshes.scale_for(e, o.color, o.size)), o.pos)


func _sync(uid: String) -> void:
	if is_orig(uid):      # an edit of the original level
		var P := get_pieces()
		if P != null:
			P.apply(uid.substr(2), edits.objects.get(uid))
		return
	var o: ForgeEdits.Obj = edits.objects.get(uid)
	var p: Placed = placed.get(uid)
	var e: Variant = entry(o) if o != null else null
	if o != null and e == null and not _missing.has(uid):
		_missing[uid] = true
		push_warning("forge: %s places %s/%s, which is not in the catalogue any more: kept in edits.json, not drawn" % [uid, o.type, o.id])
	if o == null or e == null:
		if p != null:
			_drop_solids(p)
			_group_remove(p)
			placed.erase(uid)
		return
	_missing.erase(uid)
	ForgeMeshes.mesh_for(e, o.color)      # (a model's exact size first)
	var key := ForgeMeshes.key_for(e, o.color)
	if p == null:
		p = Placed.new()
		p.uid = uid
		placed[uid] = p
	if p.key != key:
		_group_remove(p)
		p.key = key
		_group_add(p, e, o.color)
	else:
		var g: Group = groups[key]
		if not g.dirty:
			g.mmi.multimesh.set_instance_transform(g.uids.find(uid), xform(o, e))
	_drop_solids(p)
	if not held.has(uid):
		_make_solids(p, o, e)


func _group_add(p: Placed, e: Dictionary, color: String) -> void:
	var g: Group = groups.get(p.key)
	if g == null:
		g = Group.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = ForgeMeshes.mesh_for(e, color)
		g.mmi = MultiMeshInstance3D.new()
		g.mmi.name = "Forge_" + p.key.replace(":", "_")
		g.mmi.multimesh = mm
		add_child(g.mmi)
		groups[p.key] = g
	g.uids.append(p.uid)
	g.dirty = true


func _group_remove(p: Placed) -> void:
	var g: Group = groups.get(p.key)
	if g == null:
		return
	g.uids.erase(p.uid)
	g.dirty = true
	p.key = ""


## rebuild the MultiMeshes whose list of copies changed
func _flush() -> void:
	for key: String in groups.keys():
		var g: Group = groups[key]
		if not g.dirty:
			continue
		if g.uids.is_empty():
			g.mmi.queue_free()
			groups.erase(key)
			continue
		var mm := g.mmi.multimesh
		mm.instance_count = g.uids.size()
		for i in g.uids.size():
			var o: ForgeEdits.Obj = edits.objects[g.uids[i]]
			mm.set_instance_transform(i, xform(o, entry(o)))
		g.dirty = false


# ---- solids ----

func _drop_solids(p: Placed) -> void:
	for s in p.solids:
		world.remove(s)
	p.solids.clear()


func _make_solids(p: Placed, o: ForgeEdits.Obj, e: Dictionary) -> void:
	if not o.collide or String(e.get("col", "")) == "":
		return
	if is_zero_approx(o.rot.x) and is_zero_approx(o.rot.z):
		for sp: Dictionary in DevProps.colliders(e, o.pos.x, o.pos.y, o.pos.z, o.rot.y, o.size):
			sp.tag = "forge"
			sp["extra"] = {"forge": p.uid}
			p.solids.append(world.add(sp))
		return
	var b := Basis.from_euler(Vector3(deg_to_rad(o.rot.x), deg_to_rad(o.rot.y), deg_to_rad(o.rot.z)))
	var h := o.size / 2.0
	var pts := PackedVector3Array()
	for k in 8:
		pts.append(o.pos + b * Vector3(h.x * (1.0 if k & 1 else -1.0), h.y * (1.0 if k & 2 else -1.0), h.z * (1.0 if k & 4 else -1.0)))
	var pieces: Array[PackedVector3Array] = [pts]
	var s := world.add_convex(pieces, "forge")
	s.data = {"extra": {"forge": p.uid}}
	p.solids.append(s)


## take an object's solids out while the editor moves it (true), or put them back where it ended up (false)
func hold(uids: Array, on: bool) -> void:
	for uid: String in uids:
		if on:
			held[uid] = true
		else:
			held.erase(uid)
		if is_orig(uid):
			var P := get_pieces()
			if P != null:
				P.hold(uid.substr(2), on, edits.objects.get(uid))
			continue
		_sync(uid)
	_flush()


# ---- what the pointer is on ----

## a ray against an oriented box (centre c, rotation b, half size hs): [t, normal] or null. Same test as the dev tools' prop picking (levels/dev/dev_level.gd _prop_hit).
static func box_hit(ro: Vector3, rd: Vector3, c: Vector3, b: Basis, hs: Vector3) -> Variant:
	var inv := b.inverse()
	var lo := inv * (ro - c)
	var ld := inv * rd
	var t0 := -INF
	var t1 := INF
	var axis := 0
	for i in 3:
		if absf(ld[i]) < 1e-9:
			if absf(lo[i]) > hs[i]:
				return null
			continue
		var a := (-hs[i] - lo[i]) / ld[i]
		var z := (hs[i] - lo[i]) / ld[i]
		if a > z:
			var q := a
			a = z
			z = q
		if a > t0:
			t0 = a
			axis = i
		t1 = minf(t1, z)
		if t0 > t1:
			return null
	if t0 < 0.0:
		return null
	var n := Vector3.ZERO
	n[axis] = -signf(ld[axis])
	return [t0, b * n]


static func obj_basis(o: ForgeEdits.Obj) -> Basis:
	return Basis.from_euler(Vector3(deg_to_rad(o.rot.x), deg_to_rad(o.rot.y), deg_to_rad(o.rot.z)))


## the nearest placed object under a ray: {uid, t, n} or empty
func pick(ro: Vector3, rd: Vector3, skip: Dictionary = {}) -> Dictionary:
	var best := {}
	var bt := INF
	for uid: String in placed:
		if skip.has(uid):
			continue
		var o: ForgeEdits.Obj = edits.objects[uid]
		var h: Variant = box_hit(ro, rd, o.pos, obj_basis(o), o.size / 2.0)
		if h != null and float(h[0]) < bt:
			bt = h[0]
			best = {"uid": uid, "t": bt, "n": h[1]}
	return best


## the nearest surface under a ray, the level's solids and the placed objects alike (skip: uids to look through): {t, p, n} or empty
func surface(ro: Vector3, rd: Vector3, skip: Dictionary = {}, max_d: float = 400.0) -> Dictionary:
	var best := {}
	var r := _level_hit(ro, rd, max_d)
	if not r.is_empty():
		var p: Vector3 = r.position
		best = {"t": ro.distance_to(p), "p": p, "n": r.normal}
	var h := pick(ro, rd, skip)
	if not h.is_empty() and (best.is_empty() or float(h.t) < float(best.t)):
		best = {"t": h.t, "p": ro + rd * float(h.t), "n": h.n}
	return best


## the first visible solid on a ray (looking through invisible boundary walls)
func _level_hit(ro: Vector3, rd: Vector3, max_d: float) -> Dictionary:
	var skip: Array[RID] = []
	for i in 8:
		var r := world.ray_hit(ro, rd, max_d, skip)
		if r.is_empty():
			return r
		var s: World.Solid = _solid_of(r.rid)
		if s == null or not SEE_THROUGH.has(s.tag):
			return r
		skip.append(r.rid)
	return {}


func _solid_of(rid: RID) -> World.Solid:
	if not _by_body.has(rid):
		_by_body.clear()
		for s in world.solids:
			_by_body[s.body] = s
	return _by_body.get(rid)


## placed things and their draw groups, and edits of the original level, for the load meter
func counts() -> Vector3i:
	return Vector3i(placed.size(), groups.size(), edits.objects.size() - placed.size() - _missing.size())
