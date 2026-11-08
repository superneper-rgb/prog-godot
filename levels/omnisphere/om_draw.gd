class_name OmDraw
extends RefCounted
## THE DRAW (JS draw.js): every few seconds the siphon pulls on Juniper and the whole plant browns out. One clock for the level: warn (lights stutter, conductors glow amber, the whine climbs) -> surge (power drops to emergency, arcs crawl over every live deck and arc plate and shock whatever metal stands on them) -> recover. It drives omni_power (every lamp, screen and window in the level), the layout's lights and cones, and hands phase changes to the level. Robots on a live plate during a surge take a big hit; drones fly over it, and FOINT goons wear rubber boots. PROG on one gets thrown. A deck with disc: [x, z, r] is round (the containment floor during the cuff surges).

const WARN := 1.7
const SURGE := 1.35
const RECOVER := 1.1
const MAX_PTS := 2400
const PERIOD := 10.5


class Lamp:
	var light: Light3D = null
	var cone: Material = null
	var base := 0.0


var live_decks: Array = []      # {x0, x1, z0, z1, top, plate, big, disc}
var lamps: Array[Lamp] = []
var fields: Array[ShaderMaterial] = []
var on_phase := Callable()
var t := 3.5
var phase := "idle"
var forced: Variant = null
var blackout := 0.0
var hit_cd := 0.0
var stopped := false
var power := 1.0
var rebuild_t := 0.0
var mesh := ArrayMesh.new()
var node: MeshInstance3D
var shock_t := {}
var _pts := PackedVector3Array()
var _cols := PackedColorArray()


func _init(root: Node3D, p_decks: Array, p_lamps: Array[Lamp], p_fields: Array[ShaderMaterial], p_on_phase: Callable) -> void:
	live_decks = p_decks
	lamps = p_lamps
	fields = p_fields
	on_phase = p_on_phase
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_fog = true
	node = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = m
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.extra_cull_margin = 16384.0
	root.add_child(node)


## one jagged bolt from A to B, w wide, colour c, into the buffer
func _bolt(A: Vector3, B: Vector3, w: float, c: Color, jag: float, segs: int, cam: Vector3) -> void:
	var prev := A
	for i in range(1, segs + 1):
		if _pts.size() + 6 > MAX_PTS:
			return
		var u := float(i) / segs
		var nx := A.lerp(B, u)
		if i < segs:
			nx += Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * (jag * 2.0 * sin(u * PI))
		var side := (prev - cam).cross(nx - prev).normalized() * w
		var q0 := prev + side
		var q1 := prev - side
		var q2 := nx + side
		var q3 := nx - side
		_pts.append_array(PackedVector3Array([q0, q1, q2, q1, q3, q2]))
		for _k in 6:
			_cols.append(c)
		prev = nx


## a random point on a deck (round decks: uniform over the disc)
static func _spot(L: Dictionary, y: float) -> Vector3:
	if not L.has("disc"):
		return Vector3(float(L.x0) + randf() * (float(L.x1) - float(L.x0)), y, float(L.z0) + randf() * (float(L.z1) - float(L.z0)))
	var q := randf() * TAU
	var d: Array = L.disc
	var r := sqrt(randf()) * float(d[2])
	return Vector3(float(d[0]) + cos(q) * r, y, float(d[1]) + sin(q) * r)


## force a Draw now: {big: true} = a full blackout that lasts hold s, alarm on
func trigger(o: Dictionary = {}) -> void:
	forced = o
	t = PERIOD - WARN - 0.01


## the plant is dead (Juniper is free): emergency power only, no more Draws
func stop(v: bool = true) -> void:
	stopped = v


## is (x, y, z) standing on a deck the surge is live on right now
func live_at(x: float, y: float, z: float) -> Variant:
	if phase != "surge":
		return null
	for L: Dictionary in live_decks:
		if absf(y - float(L.top)) >= 0.35:
			continue
		if L.has("disc"):
			if U.hyp(x - float(L.disc[0]), z - float(L.disc[1])) < float(L.disc[2]):
				return L
		elif x > float(L.x0) and x < float(L.x1) and z > float(L.z0) and z < float(L.z1):
			return L
	return null


func _set_power(pw: float) -> void:
	power = pw
	RenderingServer.global_shader_parameter_set(&"omni_power", pw)
	for f in fields:
		f.set_shader_parameter(&"uOp", 0.15 + 0.85 * pw)
	for L in lamps:
		if L.light != null:
			L.light.light_energy = L.base * pw / PI
		if L.cone != null:
			OmDraw.set_opacity(L.cone, L.base * pw)


static func set_opacity(m: Material, a: float) -> void:
	if m is StandardMaterial3D:
		(m as StandardMaterial3D).albedo_color.a = a
	elif m is ShaderMaterial:
		(m as ShaderMaterial).set_shader_parameter(&"opacity", a)


func update(dt: float, P: Player, C: Combat, cam: Vector3) -> void:
	t += dt
	hit_cd = maxf(0.0, hit_cd - dt)
	if stopped:
		_set_power(0.1 + (0.3 if randf() < 0.03 else 0.0))
		mesh.clear_surfaces()
		phase = "idle"
		return
	var m := fmod(t, PERIOD)
	var was := phase
	phase = "idle" if m < PERIOD - WARN - SURGE - RECOVER else ("warn" if m < PERIOD - SURGE - RECOVER else ("surge" if m < PERIOD - RECOVER else "recover"))
	if phase != was:
		if on_phase.is_valid():
			on_phase.call(phase)
		if phase == "idle" and was == "recover":
			if forced != null and forced.get("big", false):
				blackout = float(forced.get("hold", 3.0))
			forced = null
	blackout = maxf(0.0, blackout - dt)
	# power: 1 normally, stutters in warn, emergency in surge, ramps back; a forced big draw holds the blackout a little longer
	var u := 0.0
	if phase == "warn":
		u = (m - (PERIOD - WARN - SURGE - RECOVER)) / WARN
	elif phase == "recover":
		u = (m - (PERIOD - RECOVER)) / RECOVER
	var pw := 1.0
	if phase == "warn":
		pw = 1.0 - 0.35 * u + (-0.4 if randf() < 0.25 * u else 0.0)
	elif phase == "surge":
		pw = 0.08 + randf() * 0.05
	elif phase == "recover":
		pw = 0.15 + 0.85 * u * u
	if blackout > 0.0:
		pw = minf(pw, 0.06 + (0.5 if randf() < 0.04 else 0.0))
	_set_power(maxf(0.0, pw))
	# arcs on the live decks during the surge (and a few warning sparks crawling along the conductors in warn)
	rebuild_t -= dt
	if rebuild_t <= 0.0:
		rebuild_t = 0.045
		_pts.clear()
		_cols.clear()
		var amt := phase == "surge"
		var warn := u if phase == "warn" else 0.0
		if amt or warn > 0.4:
			for L: Dictionary in live_decks:
				if U.hyp((float(L.x0) + float(L.x1)) / 2.0 - cam.x, (float(L.z0) + float(L.z1)) / 2.0 - cam.z) > 160.0:
					continue
				var big: bool = L.get("big", false)
				var n := (3 if L.get("plate", false) else (34 if big else 5)) if amt else (8 if big else 1)
				var top: float = L.top
				for _k in n:
					var a := _spot(L, top + 0.1)
					var b := _spot(L, top + 0.1 + (randf() * 1.6 if amt else 0.0))
					if big:
						b = b.lerp(a, 0.55)
					_bolt(a, b, 0.06 + randf() * 0.05 if amt else 0.03, Color(1.4, 2.4, 2.1) if amt else Color(2.2, 1.2, 0.3), 0.5 if amt else 0.2, 9, cam)
				if amt and not L.get("plate", false):
					var p0 := Vector3((float(L.x0) + float(L.x1)) / 2.0, top + 0.2, (float(L.z0) + float(L.z1)) / 2.0)
					_bolt(p0, p0 + Vector3(0.0, 7.0 + randf() * 3.0, -4.0), 0.1, Color(1.2, 2.6, 2.2), 1.1, 14, cam)
		mesh.clear_surfaces()
		if _pts.size() >= 3:
			var arr: Array = []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = _pts
			arr[Mesh.ARRAY_COLOR] = _cols
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	# the shock: PROG on a live deck gets thrown; a robot on a live plate gets cooked; drones (flying) do not care
	if phase == "surge" and C != null:
		if P != null and not P.dead and hit_cd <= 0.0:
			var L: Variant = live_at(P.x, P.y, P.z)
			if L != null:
				hit_cd = 0.7
				C.hurt_player(P, 22.0, (float(L.x0) + float(L.x1)) / 2.0, (float(L.z0) + float(L.z1)) / 2.0, "bolt")
				P.vy = 9.0
				P.grounded = false
				if Game.fx != null:
					Game.fx.sparks(Vector3(P.x, P.y + 0.3, P.z), 30, 7.0, null, 0x9ffff0)
		for r: Robot in C.enemies.robots:
			if r.dead or r.drone or r is FointGoon or float(shock_t.get(r.id, 0.0)) > t:      # goons: rubber boots
				continue
			if live_at(r.x, r.y, r.z) != null:
				shock_t[r.id] = t + 0.8
				C.damage(r, 75.0, {"x": r.x + 0.1, "z": r.z}, 0.0)
				if Game.fx != null:
					Game.fx.sparks(Vector3(r.x, r.y + 1.0, r.z), 40, 8.0, null, 0x9ffff0)
