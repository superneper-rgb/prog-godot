class_name World
extends RefCounted
## The collision world of one level. Same query API as the three.js game's World (groundHeight, blocked, ceiling, surfaceIn,
## pointSolid, rayClear), so the player, camera, AI and level logic port as written; the queries run natively on Jolt instead
## of looping over solids in script. A solid is still what it was: an oriented footprint with a vertical span [bottom, top].
## Kinds: box, ramp (sloped top rising along local +z from top_low to top), disc (round), field (top is a height function),
## mesh (trimesh from triangles, for real geometry; new in the Godot port).

const LAYER_SOLID := 1   # bodies, bullets, AI, ground
const LAYER_CAM := 2     # the camera boom

const INF_NEG := -INF


class Solid:
	var mesh: Variant = null    # what a level draws for it, if anything (JS s.mesh)
	var kind := "box"
	var cx := 0.0
	var cz := 0.0
	var hx := 1.0
	var hz := 1.0
	var yaw := 0.0
	var bottom := 0.0
	var top := 1.0
	var top_low := 0.0
	var tag := "box"
	var off := false
	var r := 0.0
	var no_cam := false
	var cam_only := false
	var fn: Callable
	var floor_y := -INF
	var holes: Array = []
	var world: World
	var body: RID
	var shape: RID
	var data: Dictionary = {}   # anything else a level attached
	# last frame's pose (levels/spire/spire_mechs.gd: the carry and the push-out compare)
	var p_cx := 0.0
	var p_cz := 0.0
	var p_top := 0.0
	var p_bottom := 0.0
	var p_yaw := 0.0
	var p_low := 0.0
	var p_off := false
	var p_r := 0.0
	var p_hx := 0.0
	var p_hz := 0.0

	## move / turn / resize the footprint
	func place(ncx: float, ncz: float, nyaw: float = NAN, nhx: float = NAN, nhz: float = NAN) -> void:
		var resized := false
		cx = ncx
		cz = ncz
		if not is_nan(nyaw):
			yaw = nyaw
		if not is_nan(nhx) and nhx != hx:
			hx = nhx
			resized = true
		if not is_nan(nhz) and nhz != hz:
			hz = nhz
			resized = true
		if resized:
			world._rebuild_shape(self)
		else:
			world._sync_xform(self)

	## change the vertical span (a platform moving up and down)
	func set_span(nbottom: float, ntop: float, ntop_low: float = NAN) -> void:
		var same_h := is_equal_approx(ntop - nbottom, top - bottom) and kind == "box"
		bottom = nbottom
		top = ntop
		if not is_nan(ntop_low):
			top_low = ntop_low
		if same_h:
			world._sync_xform(self)
		else:
			world._rebuild_shape(self)

	func set_no_cam(v: bool) -> void:
		if v == no_cam:
			return
		no_cam = v
		world._sync_layers(self)

	func set_off(v: bool) -> void:
		if v == off:
			return
		off = v
		world._sync_layers(self)

	## analytic top under a point, null if outside; for code that needs a specific solid's height (JS Solid.topAt).
	func top_at(x: float, z: float) -> Variant:
		if off:
			return null
		var dx := x - cx
		var dz := z - cz
		if kind == "disc":
			if dx * dx + dz * dz >= r * r:
				return null
			for h: Array in holes:
				var ex: float = x - h[0]
				var ez: float = z - h[1]
				if ex * ex + ez * ez < h[2] * h[2]:
					return null
			return top
		if kind == "field":
			if dx * dx + dz * dz >= r * r:
				return null
			var fh: float = fn.call(x, z)
			return fh if fh > floor_y else null
		var c := cos(yaw)
		var s := sin(yaw)
		var lx := dx * c - dz * s
		var lz := dx * s + dz * c
		if lx <= -hx or lx >= hx or lz <= -hz or lz >= hz:
			return null
		if kind == "ramp":
			return top_low + (top - top_low) * ((lz + hz) / (2.0 * hz))
		return top


var solids: Array[Solid] = []
var cam_solids: Array[Solid] = []
var spawn := {"x": 0.0, "y": 0.0, "z": 0.0, "yaw": 0.0}

# things a level can set on its world (same meanings as the JS world's optional fields)
var water: Object = null                 # at(x, z) -> surface height or null; level; ladders
var poles: Array = []                    # { x, y, z, axis: "x"|"z", half, r }
var fall_reset_y := -25.0
var camera_zone_weight: Callable         # (player) -> 0..1, how far into a marked room
var camera_room_dist := 0.0              # the world's own indoor boom (0 = 3.05)
var camera_room_lens_max := 0.0
var camera_no_swing := false
var target_spots: Variant = null         # [[x, z, ax, az, w], ...]: the robots Combat builds here. null = the original range's ten; [] = none
var clerk_spot: Variant = null           # [x, z] of the gunshop clerk's target. null = the original spot
var pod_style: Variant = null            # JS world.podStyle: the ammo pods' colours ({color, band})
var pickup_spots: Variant = null         # [[x, z] or [x, z, y], ...]: ammo pods. null = the original three; [] = none
var projectile_floor_y := 0.02           # height below which a rocket / stone / bolt counts as having hit the ground
var projectile_floor_at: Callable        # (x, z) -> that height, for a world whose ground is not one level (the hub's FOINT CITY)
var drone_leash := false                 # levels over a void / magma: open air with no floor under it counts as a wall for a Gun Drone

var _space: RID
var _fields: Array[Solid] = []
var _ray := PhysicsRayQueryParameters3D.new()
var _shape_q := PhysicsShapeQueryParameters3D.new()
var _point_q := PhysicsPointQueryParameters3D.new()
var _cyl: Dictionary = {}     # "r|h" -> shape RID
var _sph: Dictionary = {}     # r -> shape RID
var _active := true
var _state: PhysicsDirectSpaceState3D

static var RING: Array[Vector2] = _make_ring()


static func _make_ring() -> Array[Vector2]:
	var a: Array[Vector2] = []
	for i in 8:
		a.append(Vector2(cos(i * PI / 4.0), sin(i * PI / 4.0)))
	return a


func _init(space: RID) -> void:
	_space = space
	_ray.collision_mask = LAYER_SOLID
	_ray.hit_from_inside = false
	_ray.hit_back_faces = false
	_shape_q.collision_mask = LAYER_SOLID
	_point_q.collision_mask = LAYER_SOLID
	_state = PhysicsServer3D.space_get_direct_state(_space)


## Free everything this world put into the physics server.
func dispose() -> void:
	for s in solids:
		_free_solid(s)
	for s in cam_solids:
		_free_solid(s)
	solids.clear()
	cam_solids.clear()
	_fields.clear()
	for k: String in _cyl:
		PhysicsServer3D.free_rid(_cyl[k])
	for k: float in _sph:
		PhysicsServer3D.free_rid(_sph[k])
	_cyl.clear()
	_sph.clear()


## JS world.solids.splice: a solid taken out for good (the DEV tools)
func remove(s: Solid) -> void:
	solids.erase(s)
	_free_solid(s)


func _free_solid(s: Solid) -> void:
	if s.body.is_valid():
		PhysicsServer3D.free_rid(s.body)
	if s.shape.is_valid():
		PhysicsServer3D.free_rid(s.shape)
	s.body = RID()
	s.shape = RID()


## Parked (the hub while another level runs): its solids stop answering queries.
func set_active(on: bool) -> void:
	_active = on
	for s in solids:
		_sync_layers(s)
	for s in cam_solids:
		_sync_layers(s)


## JS world.add({ kind, cx, cz, hx, hz, yaw, bottom, top, topLow, tag, off, r, holes, fn, floor, noCam })
func add(o: Dictionary) -> Solid:
	var s := _make(o)
	solids.append(s)
	return s


## camera-only blocker: the camera boom treats it as solid, nothing else does.
func add_camera_blocker(o: Dictionary) -> Solid:
	var s := _make(o)
	s.cam_only = true
	_sync_layers(s)
	cam_solids.append(s)
	return s


## JS `box(cx, cz, wd, dp, top, o)` helper every level writes for itself.
func box(cx: float, cz: float, wd: float, dp: float, top: float, o: Dictionary = {}) -> Solid:
	var d := {"kind": "box", "cx": cx, "cz": cz, "hx": wd / 2.0, "hz": dp / 2.0, "top": top}
	d.merge(o, true)
	return add(d)


## Trimesh solid from real geometry (triangle soup: three Vector3 per triangle, world space).
func add_mesh(tris: PackedVector3Array, tag: String = "mesh", no_cam: bool = false) -> Solid:
	var s := Solid.new()
	s.world = self
	s.kind = "mesh"
	s.tag = tag
	s.no_cam = no_cam
	s.shape = PhysicsServer3D.concave_polygon_shape_create()
	PhysicsServer3D.shape_set_data(s.shape, {"faces": tris, "backface_collision": false})
	_make_body(s)
	PhysicsServer3D.body_add_shape(s.body, s.shape)
	PhysicsServer3D.body_set_state(s.body, PhysicsServer3D.BODY_STATE_TRANSFORM, Transform3D.IDENTITY)
	_sync_layers(s)
	solids.append(s)
	return s


func _make(o: Dictionary) -> Solid:
	var s := Solid.new()
	s.world = self
	s.kind = o.get("kind", "box")
	s.cx = o.get("cx", 0.0)
	s.cz = o.get("cz", 0.0)
	s.hx = o.get("hx", 1.0)
	s.hz = o.get("hz", 1.0)
	s.yaw = o.get("yaw", 0.0)
	s.bottom = o.get("bottom", 0.0)
	s.top = o.get("top", 1.0)
	s.top_low = o.get("top_low", 0.0)
	s.tag = o.get("tag", "box")
	s.off = o.get("off", false)
	s.r = o.get("r", 0.0)
	s.no_cam = o.get("no_cam", false)
	if o.has("fn"):
		s.fn = o["fn"]
	s.floor_y = o.get("floor", -INF)
	s.holes = o.get("holes", [])
	s.data = o
	if s.kind == "disc" or s.kind == "field":
		s.hx = s.r
		s.hz = s.r
	_make_body(s)
	_rebuild_shape(s)
	if s.kind == "field":
		_fields.append(s)
	return s


func _make_body(s: Solid) -> void:
	s.body = PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(s.body, PhysicsServer3D.BODY_MODE_STATIC)
	PhysicsServer3D.body_set_space(s.body, _space)
	PhysicsServer3D.body_set_collision_mask(s.body, 0)


func _rebuild_shape(s: Solid) -> void:
	if s.shape.is_valid():
		PhysicsServer3D.body_clear_shapes(s.body)
		PhysicsServer3D.free_rid(s.shape)
		s.shape = RID()
	match s.kind:
		"box":
			s.shape = PhysicsServer3D.box_shape_create()
			PhysicsServer3D.shape_set_data(s.shape, Vector3(s.hx, maxf(0.005, (s.top - s.bottom) * 0.5), s.hz))
		"ramp":
			s.shape = PhysicsServer3D.convex_polygon_shape_create()
			var b := s.bottom
			var lo := s.top_low
			var hi := s.top
			var pts := PackedVector3Array([
				Vector3(-s.hx, b, -s.hz), Vector3(s.hx, b, -s.hz), Vector3(-s.hx, b, s.hz), Vector3(s.hx, b, s.hz),
				Vector3(-s.hx, hi, s.hz), Vector3(s.hx, hi, s.hz)])
			if lo > b + 0.001:
				pts.append(Vector3(-s.hx, lo, -s.hz))
				pts.append(Vector3(s.hx, lo, -s.hz))
			PhysicsServer3D.shape_set_data(s.shape, pts)
		"disc":
			if s.holes.is_empty():
				s.shape = PhysicsServer3D.cylinder_shape_create()
				PhysicsServer3D.shape_set_data(s.shape, {"radius": s.r, "height": maxf(0.01, s.top - s.bottom)})
			else:
				s.shape = PhysicsServer3D.concave_polygon_shape_create()
				PhysicsServer3D.shape_set_data(s.shape, {"faces": _disc_with_holes(s), "backface_collision": false})
		"field":
			s.shape = PhysicsServer3D.concave_polygon_shape_create()
			PhysicsServer3D.shape_set_data(s.shape, {"faces": _field_tris(s), "backface_collision": false})
	PhysicsServer3D.body_add_shape(s.body, s.shape)
	_sync_xform(s)
	_sync_layers(s)


func _sync_xform(s: Solid) -> void:
	var y := 0.0
	if s.kind == "box" or (s.kind == "disc" and s.holes.is_empty()):
		y = (s.bottom + s.top) * 0.5
	var t := Transform3D(Basis(Vector3.UP, s.yaw), Vector3(s.cx, y, s.cz))
	if s.kind == "field" or (s.kind == "disc" and not s.holes.is_empty()):
		t = Transform3D.IDENTITY   # built in world space
	PhysicsServer3D.body_set_state(s.body, PhysicsServer3D.BODY_STATE_TRANSFORM, t)


func _sync_layers(s: Solid) -> void:
	var layer := 0
	if _active and not s.off:
		if s.cam_only:
			layer = LAYER_CAM
		else:
			layer = LAYER_SOLID | (0 if s.no_cam else LAYER_CAM)
	PhysicsServer3D.body_set_collision_layer(s.body, layer)


## A round slab with circular holes: a fine grid of quads, skipping what falls in a hole (only levels with such a floor pay for this).
func _disc_with_holes(s: Solid) -> PackedVector3Array:
	var tris := PackedVector3Array()
	var cell := clampf(s.r / 48.0, 0.15, 0.5)
	var y := s.top
	var n := int(ceil(s.r * 2.0 / cell))
	var inside := func(x: float, z: float) -> bool:
		var dx := x - s.cx
		var dz := z - s.cz
		if dx * dx + dz * dz >= s.r * s.r:
			return false
		for h: Array in s.holes:
			var ex: float = x - h[0]
			var ez: float = z - h[1]
			if ex * ex + ez * ez < h[2] * h[2]:
				return false
		return true
	for i in n:
		for j in n:
			var x0 := s.cx - s.r + i * cell
			var z0 := s.cz - s.r + j * cell
			if not inside.call(x0 + cell * 0.5, z0 + cell * 0.5):
				continue
			var a := Vector3(x0, y, z0)
			var b := Vector3(x0 + cell, y, z0)
			var c := Vector3(x0, y, z0 + cell)
			var d := Vector3(x0 + cell, y, z0 + cell)
			tris.append_array([a, b, c, c, b, d])
	return tris


## A height-function solid sampled into triangles (JS kind 'field'; the sampled grid comes from the same function).
func _field_tris(s: Solid) -> PackedVector3Array:
	var tris := PackedVector3Array()
	var cell: float = s.data.get("cell", clampf(s.r / 96.0, 0.25, 2.0))
	var n := int(ceil(s.r * 2.0 / cell))
	var hs := PackedFloat32Array()
	hs.resize((n + 1) * (n + 1))
	for i in n + 1:
		for j in n + 1:
			var x := s.cx - s.r + i * cell
			var z := s.cz - s.r + j * cell
			hs[i * (n + 1) + j] = s.fn.call(x, z)
	for i in n:
		for j in n:
			var x0 := s.cx - s.r + i * cell
			var z0 := s.cz - s.r + j * cell
			var h00 := hs[i * (n + 1) + j]
			var h10 := hs[(i + 1) * (n + 1) + j]
			var h01 := hs[i * (n + 1) + j + 1]
			var h11 := hs[(i + 1) * (n + 1) + j + 1]
			if maxf(maxf(h00, h10), maxf(h01, h11)) <= s.floor_y:
				continue
			var a := Vector3(x0, h00, z0)
			var b := Vector3(x0 + cell, h10, z0)
			var c := Vector3(x0, h01, z0 + cell)
			var d := Vector3(x0 + cell, h11, z0 + cell)
			tris.append_array([a, b, c, c, b, d])
	return tris


func _cyl_shape(r: float, h: float) -> RID:
	var k := "%.3f|%.3f" % [r, h]
	if _cyl.has(k):
		return _cyl[k]
	var rid := PhysicsServer3D.cylinder_shape_create()
	PhysicsServer3D.shape_set_data(rid, {"radius": r, "height": h})
	_cyl[k] = rid
	return rid


func _sph_shape(r: float) -> RID:
	var k := snappedf(r, 0.001)
	if _sph.has(k):
		return _sph[k]
	var rid := PhysicsServer3D.sphere_shape_create()
	PhysicsServer3D.shape_set_data(rid, k)
	_sph[k] = rid
	return rid


# ---------------------------------------------------------------- queries ----

## highest surface with top <= max_y under a single point; -INF if none
func ground_pt(x: float, z: float, max_y: float) -> float:
	_ray.from = Vector3(x, max_y + 1e-4, z)
	_ray.to = Vector3(x, max_y - 4000.0, z)
	_ray.collision_mask = LAYER_SOLID
	var r := _state.intersect_ray(_ray)
	if r.is_empty():
		return -INF
	var y: float = r.position.y
	return y


## support height under a circle (centre + 4 inner points, forgiving at edges)
func ground_height(x: float, z: float, r: float, max_y: float) -> float:
	var q := r * 0.55
	var best := ground_pt(x, z, max_y)
	best = maxf(best, ground_pt(x + q, z, max_y))
	best = maxf(best, ground_pt(x - q, z, max_y))
	best = maxf(best, ground_pt(x, z + q, max_y))
	best = maxf(best, ground_pt(x, z - q, max_y))
	return best


## is the body cylinder (feet, height h) blocked at this xz? Surfaces within `step` of the feet are walkable.
func blocked(x: float, z: float, feet: float, h: float, r: float, step: float) -> bool:
	var span := h - step - 2e-4
	if span <= 0.001:
		return false
	_shape_q.shape_rid = _cyl_shape(r, span)
	_shape_q.transform = Transform3D(Basis.IDENTITY, Vector3(x, feet + step + 1e-4 + span * 0.5, z))
	_shape_q.collision_mask = LAYER_SOLID
	_shape_q.motion = Vector3.ZERO
	_shape_q.margin = 0.0
	return not _state.intersect_shape(_shape_q, 1).is_empty()


## lowest underside the head would hit moving from head_old to head_new; NAN if none
func ceiling(x: float, z: float, r: float, head_old: float, head_new: float) -> float:
	var best := NAN
	var rr := r * 0.9
	_ray.collision_mask = LAYER_SOLID
	for i in range(-1, 8, 1):
		var px := x
		var pz := z
		if i >= 0:
			px += RING[i].x * rr
			pz += RING[i].y * rr
		_ray.from = Vector3(px, head_old - 0.02, pz)
		_ray.to = Vector3(px, head_new + 1e-4, pz)
		var hit := _state.intersect_ray(_ray)
		if not hit.is_empty():
			var y: float = hit.position.y
			if is_nan(best) or y < best:
				best = y
	return best


## highest surface top within [lo, hi] at a point (for ledge probing); -INF if none
func surface_in(x: float, z: float, lo: float, hi: float) -> float:
	_ray.from = Vector3(x, hi + 1e-4, z)
	_ray.to = Vector3(x, lo - 1e-4, z)
	_ray.collision_mask = LAYER_SOLID
	var r := _state.intersect_ray(_ray)
	if r.is_empty():
		return -INF
	var y: float = r.position.y
	return y


func point_solid(x: float, y: float, z: float, cam: bool = false) -> bool:
	_point_q.position = Vector3(x, y, z)
	_point_q.collision_mask = LAYER_CAM if cam else LAYER_SOLID
	if not _state.intersect_point(_point_q, 1).is_empty():
		return true
	for s in _fields:     # a trimesh has no inside: answer from the height function
		if s.off or (cam and s.no_cam):
			continue
		var t: Variant = s.top_at(x, z)
		if t != null and y < float(t):
			return true
	return false


## furthest free distance along dir (a unit vector) from origin. rad >= 0.1: a camera probe (fat, sees camera-only blockers,
## skips no_cam solids); smaller: bullets and sight lines. `fine` kept for call-compatibility: the answer is always exact here.
func ray_clear(ox: float, oy: float, oz: float, dx: float, dy: float, dz: float, max_d: float, rad: float, _fine: bool = false) -> float:
	var cam := rad >= 0.1
	var mask := LAYER_CAM if cam else LAYER_SOLID
	if rad < 0.05:
		_ray.from = Vector3(ox, oy, oz)
		_ray.to = Vector3(ox + dx * max_d, oy + dy * max_d, oz + dz * max_d)
		_ray.collision_mask = mask
		var r := _state.intersect_ray(_ray)
		if r.is_empty():
			return max_d
		return Vector3(ox, oy, oz).distance_to(r.position)
	_shape_q.shape_rid = _sph_shape(rad)
	_shape_q.collision_mask = mask
	_shape_q.margin = 0.0
	_shape_q.transform = Transform3D(Basis.IDENTITY, Vector3(ox, oy, oz))
	_shape_q.motion = Vector3(dx, dy, dz) * max_d
	var f := _state.cast_motion(_shape_q)
	var safe: float = f[0]
	if safe > 0.0 or max_d <= 0.13:
		return safe * max_d
	# started touching something (the JS probes only tested from 12 cm out): try again from there
	var o2 := Vector3(ox + dx * 0.12, oy + dy * 0.12, oz + dz * 0.12)
	_shape_q.transform = Transform3D(Basis.IDENTITY, o2)
	_shape_q.motion = Vector3(dx, dy, dz) * (max_d - 0.12)
	var f2 := _state.cast_motion(_shape_q)
	var safe2: float = f2[0]
	if safe2 <= 0.0:
		return 0.0
	return 0.12 + safe2 * (max_d - 0.12)
