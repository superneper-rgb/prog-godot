class_name WhNav
extends RefCounted
## Small multi-floor graph for warehouse robots (JS levels/warehouse/navigation.js). The stock AI still steers, attacks and separates. ENGINE DIFFERENCE: the JS re-queries the world for this graph at load; with Jolt that is ~35 000 calls, so it is built at load once and kept in packed arrays.

const STEP := 2

var world: World
var nx := PackedFloat32Array()
var ny := PackedFloat32Array()
var nz := PackedFloat32Array()
var cells: Dictionary = {}             # "x,z" -> PackedInt32Array of nodes
var edges: Array[PackedInt32Array] = []
var lane_serial := 0


func _init(w: World) -> void:
	world = w
	var b: Dictionary = WhData.BOUNDS
	var x0 := int(ceilf(float(b.minX) / STEP)) * STEP
	var z0 := int(ceilf(float(b.minZ) / STEP)) * STEP
	var offs := [[0.0, 0.0], [0.1, 0.0], [-0.1, 0.0], [0.0, 0.1], [0.0, -0.1]]
	# per column: the solids over it, so the corners are not asked of the whole list (JS world.solids per sample): a coarse grid of who can be where
	var buckets := {}
	for s: World.Solid in world.solids:
		if s.off:      # (a solid that is off answers null in the JS too; the graph is built with the level's starting state)
			continue
		var e := s.r if s.kind == "disc" else s.hx + s.hz
		for bx in range(floori((s.cx - e - 0.2) / 8.0), floori((s.cx + e + 0.2) / 8.0) + 1):
			for bz in range(floori((s.cz - e - 0.2) / 8.0), floori((s.cz + e + 0.2) / 8.0) + 1):
				var bk := Vector2i(bx, bz)
				if not buckets.has(bk):
					buckets[bk] = []
				(buckets[bk] as Array).append(s)
	var x := x0
	while x <= float(b.maxX):
		var z := z0
		while z <= float(b.maxZ):
			var heights := {}
			for s: World.Solid in buckets.get(Vector2i(floori(x / 8.0), floori(z / 8.0)), []):
				for o: Array in offs:
					var y: Variant = s.top_at(x + float(o[0]), z + float(o[1]))
					if y != null:
						heights[roundf(float(y) * 100.0) / 100.0] = true
			for y: float in heights:
				if not world.blocked(x, z, y, 2.05, 0.6, 0.42):
					var key := "%d,%d" % [x, z]
					var c: PackedInt32Array = cells.get(key, PackedInt32Array())
					c.append(nx.size())
					cells[key] = c
					nx.append(x)
					ny.append(y)
					nz.append(z)
			z += STEP
		x += STEP
	edges.resize(nx.size())
	for a in nx.size():
		var out := PackedInt32Array()
		for d: Array in [[2, 0], [-2, 0], [0, 2], [0, -2]]:
			var key := "%d,%d" % [int(nx[a]) + int(d[0]), int(nz[a]) + int(d[1])]
			if not cells.has(key):
				continue
			for bi: int in cells[key]:
				if absf(ny[a] - ny[bi]) > 1.1:
					continue
				var valid := true
				for k in range(1, 5):
					var u := k / 5.0
					var qx: float = nx[a] + float(d[0]) * u
					var qz: float = nz[a] + float(d[1]) * u
					var expected: float = ny[a] + (ny[bi] - ny[a]) * u
					var y := world.ground_height(qx, qz, 0.52, expected + 0.45)
					if not is_finite(y) or absf(y - expected) > 0.45 or world.blocked(qx, qz, y, 2.05, 0.6, 0.42):
						valid = false
						break
				if valid:
					out.append(bi)
		edges[a] = out


func _nearest(px: float, py: float, pz: float) -> int:
	var best := -1
	var score := INF
	for n in nx.size():
		var dy := absf(ny[n] - py)
		if dy < 2.0:
			var d := U.hyp(nx[n] - px, nz[n] - pz) + dy * 3.0
			if d < score:
				score = d
				best = n
	return best


func route(ax: float, ay: float, az: float, bx: float, by: float, bz: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var a := _nearest(ax, ay, az)
	var b := _nearest(bx, by, bz)
	if a < 0 or b < 0:
		return out
	var q := PackedInt32Array([a])
	var prev := {a: -1}
	var k := 0
	while k < q.size():
		var i := q[k]
		if i == b:
			break
		for j: int in edges[i]:
			if not prev.has(j):
				prev[j] = i
				q.append(j)
		k += 1
	if not prev.has(b):
		return out
	var i2 := b
	while i2 != -1:
		out.push_front(Vector3(nx[i2], ny[i2], nz[i2]))
		i2 = prev[i2]
	return out


## Target on an unreachable platform: walk to the reachable spot nearest it (the cliff edge) instead of walking straight at it and off the edge.
func closest_reach(ax: float, ay: float, az: float, tx: float, ty: float, tz: float, limit: int = 400) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var a := _nearest(ax, ay, az)
	if a < 0:
		return out
	var q := PackedInt32Array([a])
	var prev := {a: -1}
	var best := a
	var score := INF
	var k := 0
	while k < q.size() and k < limit:
		var n := q[k]
		var d := U.hyp(nx[n] - tx, nz[n] - tz) + absf(ny[n] - ty) * 0.5
		if d < score:
			score = d
			best = n
		for j: int in edges[n]:
			if not prev.has(j):
				prev[j] = n
				q.append(j)
		k += 1
	var i := best
	while i != -1:
		out.push_front(Vector3(nx[i], ny[i], nz[i]))
		i = prev[i]
	return out


## What navigation.js's attach() kept in its closure: one per robot.
class Agent:
	var nav: WhNav
	var r: Robot
	var lane := 0
	var side := 1.0
	var support := false
	var path: Array[Vector3] = []
	var next := 0
	var age := 2.0
	var last_target: Variant = null
	var lane_angle: Variant = null
	var anchor: Variant = null
	var holding := false
	var unreachable := false

	func _init(p_nav: WhNav, p_r: Robot, kind: String) -> void:
		nav = p_nav
		r = p_r
		lane = nav.lane_serial
		nav.lane_serial += 1
		side = -1.0 if lane % 3 == 1 else 1.0
		# Enforcers hold a firing lane; red mechs keep the native closing pressure. This reuses the existing supported-floor / LOS positioning and native attacks.
		support = kind != "spider" and (kind == "guard" or (not r.heavy and lane % 3 != 0))

	func tick(dt: float) -> void:
		age += dt
		holding = false

	## Keep the native windups, attacks, recovery, shot limits and damage unchanged.
	func speed(s: float) -> float:
		return 0.0 if holding and r.state == &"pursue" else s

	func still(s: bool) -> bool:
		return s or (holding and r.state == &"pursue")

	func _safe(x: float, z: float) -> bool:
		var y := nav.world.ground_height(x, z, r.r, r.y + 0.42)
		return is_finite(y) and absf(y - r.y) < 0.65 and not nav.world.blocked(x, z, y, r.h, r.r, 0.42)

	func _avoid(angle: float) -> float:
		if r.state != &"pursue":
			return angle
		var px := 0.0
		var pz := 0.0
		for o: Robot in r.E.robots:
			if o == r or o.dead or o.drone or absf(o.y - r.y) > 1.1:
				continue
			var dx := r.x - o.x
			var dz := r.z - o.z
			var d := U.hyp(dx, dz)
			var rng := r.r + o.r + 2.0
			if d >= rng:
				continue
			var a := atan2(dx, dz) if d > 0.01 else lane * 2.39996
			var w := pow(1.0 - d / rng, 2.0)
			px += sin(a) * w
			pz += cos(a) * w
		var length := U.hyp(px, pz)
		var scale := 1.0 / length if length > 1.0 else 1.0
		var adjusted := atan2(sin(angle) + px * scale * 3.0, cos(angle) + pz * scale * 3.0)
		return adjusted if _safe(r.x + sin(adjusted) * 1.1, r.z + cos(adjusted) * 1.1) else angle

	## base: the robot's own steering
	func steer(x: float, z: float, base: Callable) -> float:
		var P: Player = r.E.P if r.E != null else null
		if P == null or r.state == &"return" or r.state == &"idle":
			return base.call(x, z)
		var target := Vector3(x, P.y, z)
		var distance := U.hyp(r.x - P.x, r.z - P.z)
		# A few bots close in; the others take readable left / right firing lanes. Only react to a visible player on this floor, without predicting through walls.
		if support and r.state == &"pursue" and r.sees and absf(r.y - P.y) < 1.1 and distance > 3.0 and distance < 24.0:
			if lane_angle == null or anchor == null or U.hyp(P.x - anchor.x, P.z - anchor.y) > 4.0:
				lane_angle = atan2(r.x - P.x, r.z - P.z) + side * (0.55 + (int(lane / 3.0) % 4) * 0.4)
				anchor = Vector2(P.x, P.z)
			var radius := 6.5 + (lane % 3) * 0.8
			for offset: float in [0.0, side * 0.35, -side * 0.35]:
				var a: float = float(lane_angle) + offset
				var tx := P.x + sin(a) * radius
				var tz := P.z + cos(a) * radius
				if not _safe(tx, tz):
					continue
				var dx := P.x - tx
				var dz := P.z - tz
				var d := U.hyp(dx, dz)
				if nav.world.ray_clear(tx, r.y + 1.6, tz, dx / d, 0.0, dz / d, d, 0.04) < d - 0.2:
					continue
				target = Vector3(tx, r.y, tz)
				holding = U.hyp(r.x - tx, r.z - tz) < 0.8
				if holding:
					for o: Robot in r.E.robots:
						if o != r and not o.dead and not o.drone and absf(o.y - r.y) < 1.1 and U.hyp(o.x - r.x, o.z - r.z) < 2.0:
							holding = false
							break
				break
		# Honor native orbit / search targets too: routing everybody to P erased those offsets.
		if age > 1.2 or last_target == null or U.hyp(target.x - last_target.x, target.z - last_target.z) > 3.0:
			path = nav.route(r.x, r.y, r.z, target.x, target.y, target.z)
			unreachable = false
			if path.size() < 2 and absf(r.y - target.y) > 1.1:
				path = nav.closest_reach(r.x, r.y, r.z, target.x, target.y, target.z)
				unreachable = true
			next = 1 if path.size() > 1 else 0
			age = 0.0
			last_target = target
		while next < path.size() - 1 and U.hyp(r.x - path[next].x, r.z - path[next].z) < 1.3:
			next += 1
		var has_wp := next < path.size()
		# Nothing walkable leads to the target: stand at the closest edge rather than chase across a gap.
		if unreachable and (not has_wp or (next >= path.size() - 1 and U.hyp(r.x - path[next].x, r.z - path[next].z) < 1.3)):
			holding = true
		if has_wp and (unreachable or U.hyp(path[next].x - target.x, path[next].z - target.z) > 2.0):
			return _avoid(base.call(path[next].x, path[next].z))
		return _avoid(base.call(target.x, target.z))
