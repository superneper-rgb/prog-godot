class_name MsEntrances
extends RefCounted
## THE MOTHERSHIP's ENTRANCES (JS levels/mothership/entrances.js). Nobody in this house appears out of thin air: every gray the level sends at you comes in through somewhere real: a doorway, a stair, the cellar steps, or one of the house's
## gold SERVICE HATCHES (an iris in the ceiling that opens and lowers him on a tractor beam). He walks (or floats) in to his first spot and only then starts fighting, or at once, if you shoot him on the way.
## ENGINE DIFFERENCE: the JS swaps r.update for the walk; here Enemies.update asks r.entry first (a Robot field for exactly this).


class Hatch:
	var g: Node3D
	var leaves: Array[Node3D] = []
	var lens: MeshInstance3D
	var shaft: MeshInstance3D
	var light: OmniLight3D
	var open := 0.0
	var want := 0.0
	var busy := true
	var drop := 4.0
	var open_at: Variant = null


class Pt:
	var x := 0.0
	var y := 0.0
	var z := 0.0
	var air := false
	func _init(p_x: float, p_y: float, p_z: float, p_air: bool) -> void:
		x = p_x
		y = p_y
		z = p_z
		air = p_air


class Entry:
	extends RefCounted
	var host: MsEntrances
	var r: Robot
	var pts: Array[Pt] = []
	var i := 1
	var fly := false
	var speed := 4.6
	var drop_speed := 6.5
	var delay := 0.0
	var hp0 := 0.0
	var H: Hatch = null
	var cloak := false
	var x := 0.0
	var y := 0.0
	var z := 0.0

	func park() -> void:
		r.x = x
		r.z = z
		r.y = -400.0 if delay > 0.0 else y
		r.vx = 0.0
		r.vz = 0.0
		r.hx = x
		r.hz = z

	## JS the swapped r.update. True: he is still on his way (the fight's own update is skipped).
	func step(dt: float, P: Player) -> bool:
		if H != null and H.open_at != null:
			H.open_at = float(H.open_at) - dt
			if float(H.open_at) <= 0.0:
				H.want = 1.0
				H.open_at = null
				MsSound.tone(0.6, 150.0, 90.0, 0.14, &"sawtooth")
				MsSound.tone(0.5, 500.0, 900.0, 0.05)
		if delay > 0.0:
			delay -= dt
			park()
			if delay > 0.0:
				return true
			r.y = y
		if r.hp < hp0 or r.dead:      # shot on the way in: he's done walking
			host.finish(self, P)
			return false
		var q: Pt = pts[i]
		var air := q.air
		var dx := q.x - x
		var dz := q.z - z
		var dy := q.y - y
		var hh := U.hyp(dx, dz)
		var d := sqrt(hh * hh + (dy * dy if air else 0.0))
		var sp := drop_speed if air and absf(dy) > hh else speed
		var st := minf(d, sp * dt)
		if d > 1e-4:
			x += dx / d * st
			z += dz / d * st
			if air:
				y += dy / d * st
		if not air:
			var f: float = host.world.ground_height(x, z, 0.3, maxf(y, q.y) + 1.3)
			y = f if is_finite(f) and f > y - 3.0 else y + (q.y - y) * minf(1.0, dt * 4.0)
		var walk := hh > 1e-3 and not (air and absf(dy) > hh)
		r.vx = dx / hh * minf(sp, speed) if walk else 0.0
		r.vz = dz / hh * minf(sp, speed) if walk else 0.0
		r.x = x
		r.z = z
		r.y = y
		r.hx = x
		r.hz = z
		if walk:
			r.yaw = MsEntrances.damp_yaw(r.yaw, atan2(dx, dz), 10.0, dt)
		elif P != null:
			r.yaw = MsEntrances.damp_yaw(r.yaw, atan2(P.x - x, P.z - z), 4.0, dt)
		if d - st < 0.04:
			i += 1
			if i >= pts.size():
				host.finish(self, P)
		return true


var world: World
var root: Node3D
var live: Array[Entry] = []
var pool: Array[Hatch] = []
var _rim: StandardMaterial3D
var _leaf: StandardMaterial3D
var _leaf_mesh: ArrayMesh = null


func _init(p_world: World, p_root: Node3D) -> void:
	world = p_world
	root = p_root
	_rim = MsKit.std(0xd6a23a, 0.3, 0.8)
	_leaf = MsKit.std(0x2a2630, 0.45, 0.7)


static func damp_yaw(a: float, b: float, k: float, dt: float) -> float:
	var d := atan2(sin(b - a), cos(b - a))
	return a + d * minf(1.0, k * dt)


## JS CylinderGeometry(1, 1, 0.07, 3, 1, false, -PI / 6, PI / 3) moved so its point is at the middle of the iris: one blade.
func _blade() -> ArrayMesh:
	if _leaf_mesh != null:
		return _leaf_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := 0.035
	var apex := Vector3(0.0, 0.0, -1.0)
	var pts: Array[Vector3] = []
	for k in 4:
		var a := -PI / 6.0 + float(k) / 3.0 * PI / 3.0
		pts.append(Vector3(sin(a), 0.0, cos(a) - 1.0))
	for k in 3:
		var a := pts[k]
		var b := pts[k + 1]
		for p: Vector3 in [apex + Vector3.UP * h, b + Vector3.UP * h, a + Vector3.UP * h, apex - Vector3.UP * h, a - Vector3.UP * h, b - Vector3.UP * h,
				a + Vector3.UP * h, b + Vector3.UP * h, b - Vector3.UP * h, a + Vector3.UP * h, b - Vector3.UP * h, a - Vector3.UP * h]:
			st.add_vertex(p)
	st.generate_normals()
	_leaf_mesh = st.commit()
	return _leaf_mesh


func _hatch() -> Hatch:
	for x: Hatch in pool:
		if not x.busy:
			x.busy = true
			return x
	var h := Hatch.new()
	var g := Node3D.new()
	g.name = "service hatch"
	root.add_child(g)
	h.g = g
	MsKit.part(g, MsKit.torus(1.05, 0.13, 28, 8), _rim)
	for i in 6:      # six leaves hinged at the rim: they fold up into the ceiling
		var p := Node3D.new()
		p.rotation.y = float(i) / 6.0 * TAU
		g.add_child(p)
		var hinge := Node3D.new()
		hinge.position.z = 1.0
		p.add_child(hinge)
		MsKit.part(hinge, _blade(), _leaf)
		h.leaves.append(hinge)
	h.lens = MsKit.glow(g, MsKit.disc(0.98, 24), 0, 0xfff0c0, 0.0)
	h.lens.position.y = 0.05
	var cm := MsKit.cyl(0.85, 1.25, 1.0, 20, true)
	h.shaft = MsKit.glow(g, cm, 0, 0xffd890, 0.0)
	h.light = MsKit.light(g, 0xffd890, 0.0, 12.0, Vector3(0.0, -1.5, 0.0))
	pool.append(h)
	return h


## the underside of whatever is over (x, z) above height y (the ceiling the hatch sits in); a fallback height if nothing is
func ceiling_at(x: float, z: float, y: float) -> float:
	var best := INF
	for s: World.Solid in world.solids:
		if s.off or not (s.bottom > y + 2.6) or s.bottom >= best:
			continue
		if s.top_at(x, z) != null:
			best = s.bottom
	return best if is_finite(best) and best < y + 30.0 else y + 7.0


## r = a freshly spawned enemy; path = [[x, y, z(, "air")], ...] from the way in to the spot inside the room (the last point). o: hatch (lowered from a ceiling hatch over path[0]), delay (s, out of sight, before he comes), speed, fly (follow the path's heights: the drones), cloak (the Button Man: walks in as a shimmer)
func enter(r: Robot, path: Array, o: Dictionary = {}) -> Robot:
	if r == null or path.is_empty():
		return r
	var is_flyer: bool = r.get(&"butler") == true or r is Consigliere or r is ProbeButler or r.drone
	var fly: bool = o.get("fly", is_flyer)
	var E := Entry.new()
	E.host = self
	E.r = r
	E.fly = fly
	for p: Array in path:      # a 4th entry "air": this leg is airborne (down a lift, a hop off a rail)
		E.pts.append(Pt.new(p[0], p[1], p[2], fly or p.size() > 3))
	var H: Hatch = null
	var o_delay: float = o.get("delay", 0.0)
	if o.get("hatch", false):      # lowered from the ceiling over the first point
		var p0: Pt = E.pts[0]
		var cy := ceiling_at(p0.x, p0.z, p0.y)
		H = _hatch()
		H.g.position = Vector3(p0.x, cy - 0.04, p0.z)
		H.g.visible = true
		H.want = 0.0
		H.open = 0.0
		H.drop = maxf(1.0, cy - p0.y)
		E.pts.insert(0, Pt.new(p0.x, cy - 2.1, p0.z, true))      # the iris opens first, then he comes down
		E.pts[1].air = true
		H.open_at = o_delay
	E.H = H
	var is_muscle: bool = r.get(&"muscle") == true
	E.speed = o.get("speed", 5.5 if fly else (3.6 if is_muscle else 4.6))
	E.delay = o_delay + (0.7 if H != null else 0.0)
	E.hp0 = r.hp
	E.cloak = o.get("cloak", false) or r is ButtonMan
	E.x = E.pts[0].x
	E.y = E.pts[0].y
	E.z = E.pts[0].z
	r.entering = true
	r.slot = &""
	E.park()
	if E.cloak and r is ButtonMan:
		(r as ButtonMan).cloaked = true
	r.entry = E
	live.append(E)
	return r


func finish(E: Entry, P: Player) -> void:
	var r := E.r
	if not r.entering:
		return
	r.entering = false
	r.entry = null
	r.vx = 0.0
	r.vz = 0.0
	r.hx = r.x
	r.hz = r.z
	if E.cloak and r is ButtonMan:
		(r as ButtonMan).cloaked = false
	if P != null and not r.dead:
		r._know(P.x, P.z)
		r.seen_t = 0.0
		r.set_(&"alert")
	if E.H != null:
		E.H.want = 0.0
	live.erase(E)


func update(dt: float, robots: Array) -> void:
	var i := live.size() - 1
	while i >= 0:
		var E: Entry = live[i]
		if not robots.has(E.r):      # despawned on the way (a checkpoint)
			if E.H != null:
				E.H.want = 0.0
			live.remove_at(i)
		i -= 1
	for h: Hatch in pool:
		if not h.busy:
			continue
		h.open += (h.want - h.open) * minf(1.0, dt * (5.0 if h.want != 0.0 else 3.0))
		for l: Node3D in h.leaves:
			l.rotation.x = h.open * 1.45
		MsKit.opa(h.lens, h.open * 0.9)
		h.shaft.scale = Vector3(1.0, h.drop + 0.4, 1.0)
		h.shaft.position.y = -(h.drop + 0.4) * 0.5
		MsKit.opa(h.shaft, h.open * 0.2)
		h.light.light_energy = h.open * 6.0 / PI
		if h.want == 0.0 and h.open_at == null and h.open < 0.02:
			h.busy = false
			h.g.visible = false


func clear() -> void:
	for E: Entry in live:
		E.r.entering = false
		E.r.entry = null
	live.clear()
	for h: Hatch in pool:
		h.busy = false
		h.g.visible = false
		h.want = 0.0
		h.open = 0.0
		h.open_at = null
