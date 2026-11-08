class_name WhGuidance
extends Node
## Where to go next and what the Foreman is about to do (JS levels/warehouse/arrows.js, foreman-effects.js). One fixed breadcrumb at a time; reaching it reveals the next route step; chevrons flow along the walking route from the player's feet. Telegraphs on the floor: missile rings, the ram's lane, the purge lanes. Not yet: the purge's electric arcs and sparks and the eye's hit arcs (foreman-electricity.js, foreman-eye-hit.js): the lanes light up without them.

const TRAIL := 9
const TRAIL_STEP := 2.6
const DEEP := {"security": 1, "reclamation": 1, "vault": 1, "escape": 1, "finale": 1}
const ROUTE_PATHS := {
	"roof": [[0, 24, -45], [0, 24, -28], [0, 24, -26], [0, 18, -14]],
	"racks": [[-8, 18, -19], [-23, 18, -19], [-23, 18, 10], [-23, 18, 16], [6, 18, 16], [6, 18, -20], [20, 18, -20], [20, 17.8, -13], [20, 12, 10], [24, 12, 14], [26, 12, 14], [26, 12, -17], [30, 12, -17]],
	"sorting": [[30, 12, -22], [58, 12, -22], [70, 12, -22], [70, 9, -6], [44, 9, -6], [44, 9, -10], [34, 9, -10], [34, 6, 6], [34, 6, 16], [44, 6, 16], [34, 6, 16], [22, 4, 16]],
	"freight": [[22, 4, 16], [25, 4, 4], [25, 4, 8], [0, 4, 8], [-25, 4, 8], [-25, 4, -4], [-25, 4, -8], [0, 4, -8], [0, 4, 0]],
	"security": [[12, -12, 44], [-25, -12, 44], [-25, -12, 53], [-25, -12, 72], [25, -12, 72], [26, -12, 78], [26, -18, 106]],
	"reclamation": [[26, -18, 110], [26, -18, 132], [26, -18, 142], [-26, -18, 142], [-26, -24, 170], [-14, -24, 172]],
	"vault": [[-14, -24, 172], [-17, -24, 184], [-17, -24, 194], [13, -24, 194], [13, -24, 190], [8, -24, 179.2], [0, -24, 179.2], [8, -24, 184], [23, -23.5, 184]],
	"escape": [[23, -23.5, 184], [65, -16.5, 182], [67, -16.1667, 182], [113, -8.5, 182], [115, -8.1667, 182], [164, 0, 184], [178, 0, 184], [186, 0, 184]],
	"finale": [[186, 0, 184], [196, 0, 184], [208, 0, 200]],
}

var L: WarehouseLevel
var world: World
var route_arrow: MeshInstance3D
var markers: Array[Dictionary] = []
var destination: Node3D
var trail: MultiMeshInstance3D
var poly: Array[Vector3] = []
var poly_at := 0
var last_build := 0.0
var cached: Array[Dictionary] = []
var key := ""
var cursor := 0
var last_target: Variant = null
var last_player: Variant = null
var time_ := 0.0
# the Foreman's telegraphs
var amber: StandardMaterial3D
var hot: StandardMaterial3D
var white: StandardMaterial3D
var missiles: Array[Dictionary] = []
var ram_strip: MeshInstance3D
var chevrons: Array[MeshInstance3D] = []
var lanes: Array[Dictionary] = []


func _init(level: WarehouseLevel) -> void:
	L = level
	world = level.world


static func _unlit(hex: int, a: float = 1.0, add: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color.hex((hex << 8) | 0xff)
	m.albedo_color.a = a
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if a < 1.0 or add:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	if add:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.disable_fog = true
	return m


static func _poly_mesh(pts: Array, closed_tris: Array) -> ArrayMesh:
	var v := PackedVector3Array()
	for p: Array in pts:
		v.append(Vector3(p[0], 0.0, p[1]))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_INDEX] = PackedInt32Array(closed_tris)
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


func _mi(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var q := MeshInstance3D.new()
	q.mesh = mesh
	q.material_override = mat
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	q.visible = false
	add_child(q)
	return q


func _ready() -> void:
	# the export caught these at one moment: they are all drawn here instead
	for nm: String in ["Blue objective guidance", "Foreman arena effects", "Route trail"]:
		for n: Node3D in L.node_named(nm):
			n.visible = false
	var arrow := _poly_mesh([[0, 1.5], [-0.85, 0.2], [-0.3, 0.2], [-0.3, -1], [0.3, -1], [0.3, 0.2], [0.85, 0.2]], [0, 1, 6, 2, 3, 4, 2, 4, 5])
	var blue := _unlit(0x39caff)
	route_arrow = _mi(arrow, blue)
	var ring := WhSetpieceViews._ring_mesh(1.15, 1.3, 40)
	var beam_mat := _unlit(0x39caff, 0.34, true)
	var beam := CylinderMesh.new()
	beam.top_radius = 1.0
	beam.bottom_radius = 1.0
	beam.height = 16.0
	beam.radial_segments = 24
	beam.rings = 1
	beam.cap_top = false
	beam.cap_bottom = false
	for c: Dictionary in L.director.controls:
		var g := Node3D.new()
		g.position = Vector3(c.x, c.y, c.z)
		g.visible = false
		add_child(g)
		var r := MeshInstance3D.new()
		r.mesh = ring
		r.material_override = blue
		r.position.y = 0.055
		g.add_child(r)
		var b := MeshInstance3D.new()
		b.mesh = beam
		b.material_override = beam_mat
		b.position.y = 8.0
		b.scale = Vector3(0.85, 1.0, 0.85)
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.add_child(b)
		markers.append({"c": c, "g": g, "beam": b})
	destination = Node3D.new()
	destination.visible = false
	add_child(destination)
	var dr := MeshInstance3D.new()
	dr.mesh = WhSetpieceViews._ring_mesh(1.2, 1.45, 40)
	dr.material_override = blue
	destination.add_child(dr)
	var db := MeshInstance3D.new()
	db.mesh = beam
	db.material_override = beam_mat
	db.position.y = 8.0
	db.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	destination.add_child(db)
	# The trail: chevrons flowing along the walking route from the player's feet. Whatever the camera does, some of them show past the character.
	var chev := _poly_mesh([[-0.62, -0.32], [0, 0.32], [0.62, -0.32], [0.62, -0.68], [0, -0.04], [-0.62, -0.68]], [0, 1, 4, 0, 4, 5, 1, 2, 3, 1, 3, 4])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = chev
	mm.instance_count = TRAIL
	trail = MultiMeshInstance3D.new()
	trail.multimesh = mm
	var tm := _unlit(0xffffff, 1.0, true)
	tm.vertex_color_use_as_albedo = true
	trail.material_override = tm
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trail.extra_cull_margin = 16384.0
	trail.visible = false
	add_child(trail)
	# Foreman
	amber = _unlit(0xffb52e, 0.55)
	hot = _unlit(0xff4829, 0.7)
	white = _unlit(0xffeeb5)
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	var steel := _unlit(0x334b57)
	var cone := WhSetpieceViews._cyl(0.0, 0.28, 1.5, 8)
	var tr := WhSetpieceViews._cyl(0.06, 0.24, 3.0, 8)
	var mring := WhSetpieceViews._ring_mesh(2.1, 2.35, 40)
	var mfill := WhSetpieceViews._ring_mesh(0.0, 2.1, 40)
	for _i in 6:
		var bolt := _mi(cone, steel)
		bolt.rotation.z = PI
		missiles.append({"ring": _mi(mring, amber), "fill": _mi(mfill, hot), "bolt": bolt, "trail": _mi(tr, white)})
	ram_strip = _mi(plane, amber)
	var bx := BoxMesh.new()
	for _i in 6:
		chevrons.append(_mi(bx, white))
	for _i in 2:
		lanes.append({"floor": _mi(plane, _unlit(0x167bdc, 0.13, true))})


func _dist(a: Vector3, b: Vector3) -> float:
	return U.hyp(a.x - b.x, a.z - b.z) + absf(a.y - b.y) * 3.0


func _fallback(P: Vector3, target: Vector3, stage: String) -> Array[Vector3]:
	var off := float(WhData.DEPTH_X) if DEEP.has(stage) else 0.0
	var pts: Array[Vector3] = []
	for q: Array in ROUTE_PATHS.get(stage, []):
		pts.append(Vector3(float(q[0]) + off, q[1], q[2]))
	var out: Array[Vector3] = [P]
	if pts.is_empty():
		out.append(target)
		return out
	var start := 0
	var end_ := 0
	for i in pts.size():
		if _dist(pts[i], P) < _dist(pts[start], P):
			start = i
		if _dist(pts[i], target) < _dist(pts[end_], target):
			end_ = i
	if start <= end_:
		out.append_array(pts.slice(start, end_ + 1))
	else:
		var seg := pts.slice(end_, start + 1)
		seg.reverse()
		out.append_array(seg)
	out.append(target)
	return out


func _build_route(P: Vector3, target: Vector3, stage: String) -> void:
	var route: Array[Vector3] = L.nav.route(P.x, P.y, P.z, target.x, target.y, target.z)
	if route.size() < 2:
		route = _fallback(P, target, stage)
	else:
		route.push_front(P)
		route.append(target)
	poly.clear()
	for i in route.size():
		if i == 0 or U.hyp(route[i].x - route[i - 1].x, route[i].z - route[i - 1].z) > 0.01:
			poly.append(route[i])
	poly_at = 0
	last_build = time_
	var steps: Array[Dictionary] = []
	var travelled := 0.0
	for i in range(1, route.size()):
		var a := route[i - 1]
		var b := route[i]
		var len_ := U.hyp(b.x - a.x, b.z - a.z)
		var d := 7.0 - travelled
		while d <= len_:
			var u := d / (len_ if len_ != 0.0 else 1.0)
			steps.append({"p": a.lerp(b, u), "dx": b.x - a.x, "dz": b.z - a.z})
			d += 7.0
		travelled = fposmod(travelled + len_, 7.0)
		# Show corners before asking the player to continue around them.
		if i + 1 < route.size() and travelled > 3.0 and len_ > 0.01:
			var c := route[i + 1]
			var nl := U.hyp(c.x - b.x, c.z - b.z)
			if nl > 0.01 and ((b.x - a.x) * (c.x - b.x) + (b.z - a.z) * (c.z - b.z)) / (len_ * nl) < 0.75:
				steps.append({"p": b, "dx": c.x - b.x, "dz": c.z - b.z})
				travelled = 0.0
	var before := route[route.size() - 2] if route.size() >= 2 else P
	if steps.is_empty() or _dist(steps[steps.size() - 1].p, target) > 2.0:
		steps.append({"p": target, "dx": target.x - before.x, "dz": target.z - before.z})
	# Skip unsupported floor samples, never place guidance through a floor.
	cached.clear()
	for s: Dictionary in steps:
		var q: Vector3 = s.p
		var fl := world.ground_height(q.x, q.z, 0.15, q.y + 0.7)
		if is_finite(fl) and absf(fl - q.y) <= 0.75:
			q.y = fl
			s.p = q
			cached.append(s)
	cursor = 0
	last_target = target


func _update_trail(P: Vector3, urgent: bool) -> void:
	trail.visible = false
	if poly.size() < 2:
		return
	# Find where the player is along the route, never moving backwards past a corner already rounded.
	var best := INF
	var best_i := poly_at
	var best_u := 0.0
	for i in range(poly_at, mini(poly.size() - 1, poly_at + 6)):
		var a := poly[i]
		var b := poly[i + 1]
		var dx := b.x - a.x
		var dz := b.z - a.z
		var l2 := dx * dx + dz * dz
		if l2 == 0.0:
			l2 = 1.0
		var u := clampf(((P.x - a.x) * dx + (P.z - a.z) * dz) / l2, 0.0, 1.0)
		var d := U.hyp(a.x + dx * u - P.x, a.z + dz * u - P.z) + absf(a.y + (b.y - a.y) * u - P.y) * 2.0
		if d < best:
			best = d
			best_i = i
			best_u = u
	poly_at = best_i
	var flow := fposmod(time_ * (5.5 if urgent else 3.0), TRAIL_STEP)
	var seg := best_i
	var into := best_u * U.hyp(poly[seg + 1].x - poly[seg].x, poly[seg + 1].z - poly[seg].z)
	var walked := 0.0
	var shown := 0
	var mm := trail.multimesh
	for i in TRAIL:
		var want := 1.4 + flow + i * TRAIL_STEP
		var d := want - walked
		var ok := false
		while seg < poly.size() - 1:
			var a := poly[seg]
			var b := poly[seg + 1]
			var len_ := U.hyp(b.x - a.x, b.z - a.z)
			if into + d <= len_:
				into += d
				walked = want
				var u := into / len_ if len_ != 0.0 else 0.0
				var q := a.lerp(b, u)
				var fl := world.ground_height(q.x, q.z, 0.15, q.y + 0.7)
				if is_finite(fl) and absf(fl - q.y) < 0.9:
					var fade := minf(1.0, (want - 1.0) / 1.6) * minf(1.0, (TRAIL * TRAIL_STEP + 1.4 - want) / 5.0)
					var k := 0.85 * fade * (1.25 if urgent else 1.0)
					mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, atan2(b.x - a.x, b.z - a.z)).scaled(Vector3(0.9, 0.9, 0.9)), Vector3(q.x, fl + 0.07, q.z)))
					mm.set_instance_color(i, Color(0.22 * k, 0.79 * k, k))
					ok = true
					shown += 1
				break
			d -= len_ - into
			walked += len_ - into
			into = 0.0
			seg += 1
		if not ok:
			mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
	trail.visible = shown > 0


func update(state: Dictionary, P: Player, urgent: bool) -> void:
	time_ = state.time
	var goal: Dictionary = state.objective
	route_arrow.visible = false
	destination.visible = false
	trail.visible = false
	for m: Dictionary in markers:
		var c: Dictionary = m.c
		var g: Node3D = m.g
		g.visible = not state.finished and goal.id == c.id
		if g.visible:
			(m.beam as Node3D).visible = U.hyp(P.x - float(c.x), P.z - float(c.z)) > 5.0
	if state.finished or goal.target == null:
		key = ""
		last_player = null
		return
	var pv := Vector3(P.x, P.y, P.z)
	# On an optional Freight perch the walking graph has no route down: point at the pit-side lip.
	if state.stage == "freight" and P.y > 7.0 and absf(P.z) > 16.0:
		var side := signf(P.z)
		route_arrow.position = Vector3(clampf(P.x, -5.0, 5.0), 7.89, side * (17.7 if absf(P.z) > 17.8 else absf(P.z)))
		route_arrow.rotation.y = 0.0 if side < 0.0 else PI
		var s := 0.7 + 0.035 * sin(time_ * 5.0)
		route_arrow.scale = Vector3(s, s, s)
		route_arrow.visible = true
		key = ""
		last_player = null
		return
	var t: Variant = goal.target
	var target := Vector3(float(t.x), float(t.get("y", P.y)), float(t.z))
	if goal.kind != "control":
		destination.visible = goal.kind != "boss"
		destination.position = target + Vector3(0.0, 0.09, 0.0)
	if goal.kind == "boss":
		key = ""
		return
	if goal.kind == "jump":
		var pads := L.transfer_pads
		var p: Dictionary = pads[maxi(0, int(state.course_index) - 1)]
		# The takeoff arrow disappears as soon as the jump is underway.
		route_arrow.visible = absf(P.y - float(p.y)) < 0.8 and U.hyp(P.x - float(p.x), P.z - float(p.z)) < U.hyp(p.hx, p.hz) + 1.0
		route_arrow.position = Vector3(p.x, float(p.y) + 0.09, p.z)
		var s := minf(0.75, minf(float(p.hx) * 0.55, float(p.hz) * 0.55))
		route_arrow.scale = Vector3(s, s, s)
		route_arrow.rotation.y = atan2(target.x - float(p.x), target.z - float(p.z))
		key = ""
		last_player = null
		return
	var teleported: bool = last_player != null and _dist(pv, last_player) > 24.0
	# Wandering well off the route rebuilds it from where the player is now.
	var strayed := false
	if poly.size() > 1 and time_ - last_build > 1.5:
		var nx := poly[mini(poly_at + 1, poly.size() - 1)]
		strayed = U.hyp(P.x - nx.x, P.z - nx.z) > U.hyp(poly[poly_at].x - nx.x, poly[poly_at].z - nx.z) + 7.0
	if key != goal.id or teleported or strayed or last_target == null or _dist(last_target, target) > 4.0:
		key = goal.id
		_build_route(pv, target, state.stage)
	if goal.kind != "combat":
		_update_trail(pv, urgent)
	last_player = pv
	# A breadcrumb stays in place until reached or crossed nearby on its floor.
	while cursor < cached.size():
		var c: Dictionary = cached[cursor]
		var q: Vector3 = c.p
		var dx := P.x - q.x
		var dz := P.z - q.z
		var ln := U.hyp(c.dx, c.dz)
		if ln == 0.0:
			ln = 1.0
		var near := U.hyp(dx, dz) < 2.5
		var passed: bool = (dx * float(c.dx) + dz * float(c.dz)) / ln > 0.0 and absf(dx * float(c.dz) - dz * float(c.dx)) / ln < 3.0 and U.hyp(dx, dz) < 7.0
		if absf(P.y - q.y) > 2.0 or (not near and not passed):
			break
		cursor += 1
	if cursor < cached.size():
		var c: Dictionary = cached[cursor]
		var q: Vector3 = c.p
		route_arrow.position = q + Vector3(0.0, 0.09, 0.0)
		route_arrow.rotation.y = atan2(float(c.dx), float(c.dz))
		var s := 0.6 + 0.08 * sin(time_ * 12.0) if urgent else 0.46 + 0.03 * sin(time_ * 5.0)
		route_arrow.scale = Vector3(s, s, s)
		route_arrow.visible = true


## JS foreman-effects.js
func update_foreman(B: Dictionary) -> void:
	var K: Dictionary = L.boss.K
	var active: bool = B.mode == "fight"
	var salvos: Array = B.salvos
	for i in missiles.size():
		var m: Dictionary = missiles[i]
		var q: Variant = salvos[i] if i < salvos.size() else null
		var show: bool = active and B.move == "salvo" and q != null and not q.hit
		for p: String in m:
			(m[p] as Node3D).visible = show
		if show:
			var u := clampf(float(q.age) / float(K.salvo.warning), 0.0, 1.0)
			var at := Vector3(q.x, q.y, q.z)
			(m.ring as Node3D).position = at + Vector3(0.0, 0.05, 0.0)
			(m.fill as Node3D).position = at + Vector3(0.0, 0.04, 0.0)
			(m.fill as Node3D).scale = Vector3(u, 1.0, u)
			var y := float(q.y) + 0.5 + 22.0 * (1.0 - u * u * u)
			(m.bolt as Node3D).position = Vector3(q.x, y, q.z)
			(m.trail as Node3D).position = Vector3(q.x, y + 2.2, q.z)
	var grid: Array = B.grid
	for i in lanes.size():
		var lane: Dictionary = lanes[i]
		var q: Variant = grid[i] if active and B.move == "purge" and i < grid.size() else null
		var fl: MeshInstance3D = lane.floor
		fl.visible = q != null
		if q != null:
			var live: bool = float(B.mt) >= float(K.purge.warning)
			var charge := clampf(float(B.mt) / float(K.purge.warning), 0.0, 1.0)
			fl.position = Vector3(q.x, 0.045, q.z)
			fl.scale = Vector3(float(q.hx) * 2.0, 1.0, float(q.hz) * 2.0)
			var fm: StandardMaterial3D = fl.material_override
			fm.albedo_color = Color.hex(0x167bdcff if live else 0xffa51eff)
			fm.albedo_color.a = 0.12 if live else 0.06 + charge * 0.08
	var r: Variant = B.ram
	var show_ram: bool = active and B.move == "ram" and r != null
	ram_strip.visible = show_ram
	for c: MeshInstance3D in chevrons:
		c.visible = show_ram
	if show_ram:
		var dx := float(r.tx) - float(r.x)
		var dz := float(r.tz) - float(r.z)
		var ln := U.hyp(dx, dz)
		var yaw := atan2(dx, dz)
		var rad := float(K.ram.radius)
		ram_strip.transform = Transform3D(Basis(Vector3.UP, yaw).scaled_local(Vector3(rad * 2.0, 1.0, ln + rad * 2.0)), Vector3((float(r.x) + float(r.tx)) / 2.0, 0.06, (float(r.z) + float(r.tz)) / 2.0))
		ram_strip.material_override = amber if float(B.mt) < float(K.ram.warning) else hot
		for i in chevrons.size():
			var t := (i + 1) / 7.0
			chevrons[i].transform = Transform3D(Basis(Vector3.UP, yaw).scaled_local(Vector3(3.0, 0.06, 0.15)), Vector3(float(r.x) + dx * t, 0.09, float(r.z) + dz * t))
	amber.albedo_color.a = 0.32 + 0.15 * sin(float(B.time) * 12.0)
	hot.albedo_color.a = 0.48 + 0.15 * sin(float(B.time) * 22.0)
