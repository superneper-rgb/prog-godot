class_name MsBeams
extends RefCounted
## THE MOTHERSHIP's TRACTOR BEAMS (JS levels/mothership/beams.js), the house's appliances and the level's signature traversal.
##   LIFT (blue)   a column from a floor emitter. Inside it you rise to its top and hover there (double jump refreshed); steer out with air control, or jump out. `on(t)` 0..1 lets a beam run on a cycle: it FLICKERS and buzzes before it cuts out.
##   RAIL (cyan)   a trolley running along a ceiling track; under it a cone of light holds you at its ride height and CARRIES you along (you can still aim and shoot). Jump to let go, or steer out of the cone. It waits at both ends, or follows `keys`.
##   ABDUCTION (red) a hostile beam from a ceiling emitter that roams a path. Caught in it you are dragged up toward the probe arm: JUMP repeatedly to struggle free (3 jumps), or get probed at the top. `carry` beams you ride on purpose, up to a ledge.
## Physics: the level's update runs just before the player's, so a beam sets velocity and carries position; the player's own collision still applies, so a beam never pushes you into a wall.

const NEAR := 30.0


class Hoop:
	var m: MeshInstance3D
	var u := 0.0


class Mote:
	var a := 0.0
	var rr := 0.0
	var u := 0.0


class Lift:
	var x := 0.0
	var z := 0.0
	var y0 := 0.0
	var y1 := 0.0
	var r := 1.3
	var color := 0x4ab8ff
	var on := Callable()
	var warn_at := Callable()
	var decor := false
	var to: Variant = null      # [x, z]: a landing it drifts you onto at the top
	var pull := 0.0
	var speed := 0.0
	var k := 1.0
	var drop_t := 0.0
	var g: Node3D = null
	var col: MeshInstance3D = null
	var core: MeshInstance3D = null
	var lens_mat: StandardMaterial3D = null
	var light: OmniLight3D = null
	var hoops: Array[Hoop] = []
	var motes: Array[Mote] = []
	var mm: MultiMesh = null


class Rail:
	var a: Array = [0.0, 0.0]
	var b: Array = [0.0, 0.0]
	var y := 0.0
	var ride := 0.0
	var r := 1.25
	var wait := 1.4
	var travel := 4.0
	var phase := 0.0
	var rate := 1.0
	var linear := false
	var keys: Array = []
	var x := 0.0
	var z := 0.0
	var px := 0.0
	var pz := 0.0
	var u := 0.0
	var ch := 0.0
	var heading: Variant = null
	var flash := 0.0
	var trolley: Node3D = null
	var cone: MeshInstance3D = null
	var pool: MeshInstance3D = null
	var hoops: Array[Hoop] = []
	var cargo: Node3D = null


class Abduct:
	var path := Callable()
	var y := 0.0
	var floor_ := 0.0
	var r := 1.4
	var dmg := 14.0
	var hurt := Callable()
	var carry: Variant = null      # {to: [x, y, z]}
	var x := 0.0
	var z := 0.0
	var g: Node3D = null
	var cone: MeshInstance3D = null
	var ring: MeshInstance3D = null
	var arm: Node3D = null


var root: Node3D
var lifts: Array[Lift] = []
var rails: Array[Rail] = []
var abducts: Array[Abduct] = []
var riding: Rail = null
var release_t := 0.0
var last_in: Lift = null
var last_rail: Rail = null
var last_rail_t := 0.0
var ride_t := 0.0
var guard: Variant = null      # a checkpoint / respawn under a parked rail: THAT rail leaves you be until it has moved off (any rail that arrives later picks you up)
var held_vy := 0.0
var held: Abduct = null
var held_t := 0.0
var struggles := 0
var immune_t := 0.0
var last_vy := 0.0
var gold: StandardMaterial3D
var iron: StandardMaterial3D
var _ring_mesh: TorusMesh


func _init(p_root: Node3D) -> void:
	root = p_root
	gold = MsKit.std(0xd6a23a, 0.32, 0.75)
	iron = MsKit.std(0x2b2a30, 0.5, 0.7)
	_ring_mesh = MsKit.torus(1.0, 0.035, 32, 4)


# a real jump: while a beam holds you it sets air_jump = true, jumping = false and a little coyote time every frame, so the jump button always works (even with a floor just below, where a mid-air jump
# would be refused) and only the player's jump code can flip those flags (a quick tap starts and trims the jump in the same frame, clearing `jumping`: the upward kick it leaves, vy above what the beam last set, gives it away)
func _jumped_off(P: Player) -> bool:
	return (P.air_jump == false or P.jumping == true or P.vy > held_vy + 2.5) and not P.grounded


func _hold(P: Player) -> void:
	P.grounded = false
	P.jumping = false
	P.coyote_t = 0.12
	P.air_jump = true
	held_vy = P.vy


func _hoops(parent: Node3D, n: int, hex: int) -> Array[Hoop]:
	var out: Array[Hoop] = []
	for i in n:
		var q := Hoop.new()
		q.m = MsKit.glow(parent, _ring_mesh, 0, hex, 0.0)
		q.u = float(i) / n
		out.append(q)
	return out


## LIFT: {x, z, y0 (emitter floor), y1 (hover height for the feet), r, color, on, warn_at, emitter, to, parent, invisible (force only: the Spine Beam draws itself), pull, speed, decor}
func lift(o: Dictionary) -> Lift:
	var L := Lift.new()
	L.x = o.x
	L.z = o.z
	L.y0 = o.y0
	L.y1 = o.y1
	L.r = o.get("r", 1.3)
	L.color = o.get("color", 0x4ab8ff)
	L.on = o.get("on", Callable())
	L.warn_at = o.get("warn_at", Callable())
	L.decor = o.get("decor", false)
	L.to = o.get("to")
	L.pull = o.get("pull", 0.0)
	L.speed = o.get("speed", 0.0)
	lifts.append(L)
	if o.get("invisible", false):
		return L
	var parent: Node3D = o.get("parent", root)
	var g := Node3D.new()
	g.position = Vector3(L.x, 0.0, L.z)
	parent.add_child(g)
	L.g = g
	var r := L.r
	var h := L.y1 - L.y0 + 2.2
	L.col = MsKit.glow(g, MsKit.cyl(r, r * 1.08, h, 24, true), 1, L.color, 0.55)
	L.col.position.y = L.y0 + h / 2.0
	L.core = MsKit.glow(g, MsKit.cyl(r * 0.45, r * 0.5, h, 16, true), 1, 0xffffff, 0.25)
	L.core.position.y = L.y0 + h / 2.0
	if o.get("emitter", true):
		MsKit.part(g, MsKit.cyl(r + 0.35, r + 0.5, 0.25, 28), iron, Vector3(0.0, L.y0 + 0.12, 0.0))
		MsKit.part(g, MsKit.torus(r + 0.18, 0.11, 28), gold, Vector3(0.0, L.y0 + 0.27, 0.0))
		L.lens_mat = MsKit.flat(L.color)
		MsKit.part(g, MsKit.disc(r), L.lens_mat, Vector3(0.0, L.y0 + 0.26, 0.0), false)
	# (the JS's ten mote sprites: one MultiMesh of them)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = MsKit.quad()
	mm.instance_count = 10
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = MsKit.glow_mat(7)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.extra_cull_margin = 40.0
	g.add_child(mmi)
	MsKit.tint(mmi, MsKit.lin(L.color), 1.0)
	L.mm = mm
	for i in 10:
		var q := Mote.new()
		q.a = randf() * 6.28
		q.rr = randf() * r * 0.8
		q.u = randf()
		L.motes.append(q)
	L.light = MsKit.light(g, L.color, 4.0, 9.0, Vector3(0.0, L.y0 + 1.2, 0.0))
	L.hoops = _hoops(g, 4, o.get("color", 0x9ad8ff))
	return L


## RAIL: {a: [x, z], b: [x, z], y (track height), ride (feet height while carried), r, wait, travel, phase, color, keys, linear, rate, parent}
func rail(o: Dictionary) -> Rail:
	var R := Rail.new()
	var color: int = o.get("color", 0x3ff0e0)
	R.y = o.y
	R.ride = o.ride
	R.r = o.get("r", 1.25)
	R.wait = o.get("wait", 1.4)
	R.travel = o.get("travel", 4.0)
	R.phase = o.get("phase", 0.0)
	R.rate = o.get("rate", 1.0)
	R.linear = o.get("linear", false)
	R.keys = o.get("keys", [])
	var a0: Array = [R.keys[0][1], R.keys[0][2]] if not R.keys.is_empty() else o.a
	R.a = o.get("a", a0)
	R.b = o.get("b", a0)
	R.x = a0[0]
	R.z = a0[1]
	R.px = R.x
	R.pz = R.z
	var parent: Node3D = o.get("parent", root)
	var t := Node3D.new()
	parent.add_child(t)
	R.trolley = t
	MsKit.part(t, MsKit.cyl(0.75, 0.9, 0.55, 16), gold)
	var cap := SphereMesh.new()
	cap.radius = 0.5
	cap.height = 0.5
	cap.is_hemisphere = true
	cap.radial_segments = 14
	cap.rings = 8
	MsKit.part(t, cap, iron, Vector3(0.0, 0.25, 0.0))
	for s: float in [-1.0, 1.0]:
		var w := MsKit.part(t, MsKit.torus(0.2, 0.06, 12), iron, Vector3(s * 0.35, 0.45, 0.0))
		w.rotation = Vector3(0.0, 0.0, PI / 2.0)
	MsKit.part(t, MsKit.disc(0.62, 18), MsKit.flat(color), Vector3(0.0, -0.29, 0.0), false)
	R.ch = R.y - (R.ride - 0.4)
	R.cone = MsKit.glow(t, MsKit.cyl(0.62, R.r, R.ch, 24, true), 1, color, 0.55)
	R.cone.position.y = -0.29 - R.ch / 2.0
	R.pool = MsKit.glow(t, MsKit.ring(0.2, R.r, 24), 0, color, 0.35)
	R.pool.position.y = -R.ch - 0.29
	MsKit.light(t, color, 5.0, 10.0, Vector3(0.0, -1.5, 0.0))
	R.hoops = _hoops(t, 3, color)
	rails.append(R)
	return R


## a scheduled rail: position at time t from its keys [[t, x, z], ...] (eased per leg; `linear` for laps)
func _rail_key_pos(R: Rail, t: float) -> Vector2:
	var K := R.keys
	var cyc: float = K[K.size() - 1][0]
	var m := fposmod(t * R.rate + R.phase, cyc)
	for i in K.size() - 1:
		var a: Array = K[i]
		var b: Array = K[i + 1]
		if m <= b[0]:
			var u: float = (m - a[0]) / (b[0] - a[0]) if b[0] > a[0] else 0.0
			var e: float = u if R.linear else u * u * (3.0 - 2.0 * u)
			return Vector2(a[1] + (b[1] - a[1]) * e, a[2] + (b[2] - a[2]) * e)
	return Vector2(K[0][1], K[0][2])


## 0 at a, 1 at b, waits at both ends
func _rail_u(R: Rail, t: float) -> float:
	var w := R.wait
	var tr := R.travel
	var m := fposmod(t + R.phase, 2.0 * (w + tr))
	if m < w:
		return 0.0
	if m < w + tr:
		var u := (m - w) / tr
		return u * u * (3.0 - 2.0 * u)
	if m < 2.0 * w + tr:
		return 1.0
	var u2 := (m - 2.0 * w - tr) / tr
	return 1.0 - u2 * u2 * (3.0 - 2.0 * u2)


## ABDUCTION: {path(t) -> Vector2, y (emitter height), floor, r, dmg, carry: {to: [x, y, z]} (a beam you ride on purpose), hurt(P, amt, x, z), parent}
func abduct(o: Dictionary) -> Abduct:
	var A := Abduct.new()
	A.path = o.path
	A.y = o.y
	A.floor_ = o.floor
	A.r = o.get("r", 1.4)
	A.dmg = o.get("dmg", 14.0)
	A.hurt = o.get("hurt", Callable())
	A.carry = o.get("carry")
	var red: int = 0xff8a3a if A.carry != null else 0xff3a3a
	var g := Node3D.new()
	var parent: Node3D = o.get("parent", root)
	parent.add_child(g)
	A.g = g
	MsKit.part(g, MsKit.cyl(0.9, 1.15, 0.7, 16), iron)
	MsKit.part(g, MsKit.torus(1.0, 0.09, 22), gold, Vector3(0.0, -0.36, 0.0))
	MsKit.part(g, MsKit.disc(0.85, 20), MsKit.flat(red), Vector3(0.0, -0.37, 0.0), false)
	var arm := Node3D.new()      # the probe arm: folds down when it has you
	arm.position.y = -0.4
	g.add_child(arm)
	A.arm = arm
	MsKit.part(arm, MsKit.cyl(0.05, 0.05, 1.2, 6), gold, Vector3(0.0, -0.6, 0.0))
	var tip := MsKit.part(arm, MsKit.cyl(0.12, 0.0, 0.4, 8), iron, Vector3(0.0, -1.35, 0.0))
	tip.rotation.x = 0.0
	var h := maxf(1.0, A.y - A.floor_)
	A.cone = MsKit.glow(g, MsKit.cyl(0.85, A.r, h, 24, true), 1, red, 0.55)
	A.cone.position.y = -0.37 - h / 2.0
	A.ring = MsKit.glow(g, MsKit.ring(A.r * 0.8, A.r, 28), 0, red, 0.5)
	A.ring.position.y = -h - 0.33
	MsKit.light(g, red, 6.0, 11.0, Vector3(0.0, -2.0, 0.0))
	abducts.append(A)
	return A


func _abduct_step(t: float, dt: float, P: Player) -> void:
	immune_t = maxf(0.0, immune_t - dt)
	for A: Abduct in abducts:
		var p: Vector2 = A.path.call(t)
		A.x = p.x
		A.z = p.y
		A.g.position = Vector3(A.x, A.y, A.z)
		MsKit.scroll(A.cone, -t * 1.4)
		A.ring.scale = Vector3.ONE * (1.0 + 0.06 * sin(t * 8.0))
		A.arm.rotation.x = sin(t * 20.0) * 0.1 if held == A else 0.0
		A.arm.position.y = -0.9 if held == A else -0.4
	if P == null or P.dead:
		held = null
		return
	var jumped := _jumped_off(P) or (P.vy > 7.0 and last_vy < 5.0)
	last_vy = P.vy
	if held != null:
		var A := held
		held_t += dt
		if jumped:
			struggles += 1
			MsSound.tone(0.12, 500.0 + struggles * 120.0, 300.0, 0.1, &"sine", 0.5)
		var dx := A.x - P.x
		var dz := A.z - P.z
		var d := U.hyp(dx, dz)
		var top_out: bool = A.carry != null and P.y > float(A.carry.to[1]) - 0.4
		if d > 0.05 and not top_out:      # held in the column (a carry beam lets go of it at the top)
			var pull := minf(d, (5.0 if A.carry != null else 3.2) * dt)
			P.x += dx / d * pull
			P.z += dz / d * pull
		if A.carry != null:      # the beam you ride on purpose: up and over to its ledge, set down gently
			var tx: float = A.carry.to[0]
			var ty: float = A.carry.to[1]
			var tz: float = A.carry.to[2]
			var k := minf(1.0, dt * 2.6)
			P.vy = clampf((ty + 0.6 - P.y) * 4.0, -3.0, 7.0)
			if P.y > ty - 0.2:      # up first, then over (never under a ledge's lip)
				P.x += (tx - P.x) * k * 0.7
				P.z += (tz - P.z) * k * 0.7
			if U.hyp(tx - P.x, tz - P.z) < 0.8 and absf(P.y - (ty + 0.6)) < 0.5:      # set down on its ledge
				held = null
				immune_t = 1.5
				P.vy = 0.0
				MsSound.tone(0.3, 880.0, 440.0, 0.1, &"sine", 0.5)
			else:
				_hold(P)
		else:
			P.vy = minf(2.4, P.vy + 20.0 * dt)
			_hold(P)
			if struggles >= 3:
				held = null
				immune_t = 1.6
				P.vy = 7.0
				var dd := d if d != 0.0 else 1.0
				P.ix -= dx / dd * 6.0
				P.iz -= dz / dd * 6.0
				MsSound.tone(0.3, 300.0, 900.0, 0.12, &"sine", 0.5)
			elif P.y > A.y - 2.3:      # PROBED
				held = null
				immune_t = 2.2
				P.vy = -2.0
				if A.hurt.is_valid():
					A.hurt.call(P, A.dmg, A.x, A.z)
				MsSound.tone(0.5, 1400.0, 200.0, 0.18, &"sine", 0.5)
		return
	if immune_t > 0.0 or P.mode != &"normal":
		return
	for A: Abduct in abducts:
		if U.hyp(P.x - A.x, P.z - A.z) < A.r * (1.1 if A.carry != null else 0.85) and P.y < A.y - 1.0 and P.y > A.floor_ - 0.5:
			held = A
			held_t = 0.0
			struggles = 0
			_hold(P)
			last_vy = 99.0
			MsSound.tone(0.5, 180.0, 90.0, 0.14, &"sine", 0.5)
			break


## per frame. t = level clock (s). P = the player.
func update(t: float, dt: float, P: Player) -> void:
	release_t = maxf(0.0, release_t - dt)
	last_rail_t = maxf(0.0, last_rail_t - dt)
	_abduct_step(t, dt, P)
	# ---- lifts: look + force
	var in_lift: Lift = null
	for L: Lift in lifts:
		var k: float = clampf(L.on.call(t), 0.0, 1.0) if L.on.is_valid() else 1.0
		var warn: float = L.warn_at.call(t) if L.warn_at.is_valid() else 0.0
		var flick := (1.0 if sin(t * 46.0) > 0.0 else 0.25) if warn > 0.0 else 1.0
		L.k = k
		var near_l := P == null or U.hyp(P.x - L.x, P.z - L.z) < NEAR      # the hoops only draw near you (one draw call each)
		if L.g != null and L.g.visible:
			MsKit.opa(L.col, 0.55 * k * flick)
			MsKit.opa(L.core, 0.25 * k * flick)
			MsKit.scroll(L.col, -t * 0.9)
			MsKit.scroll(L.core, -t * 1.6)
			L.light.light_energy = 4.0 * k * flick / PI
			if L.lens_mat != null:
				L.lens_mat.albedo_color = Color.from_hsv(0.02 if L.color == 0xff5a3a else 0.56, 1.0, minf(1.0, 2.0 * (0.3 + 0.35 * k * flick)), 1.0)
			for q: Hoop in L.hoops:
				q.m.visible = near_l
				if not near_l:
					continue
				q.u = fmod(q.u + dt * 0.55 * (0.3 + k), 1.0)
				var s := L.r * (1.02 - q.u * 0.25)
				q.m.scale = Vector3(s, 1.0, s)
				q.m.position.y = L.y0 + 0.3 + q.u * (L.y1 - L.y0 + 1.8)
				MsKit.opa(q.m, k * flick * sin(q.u * PI) * 0.8)
			if near_l:
				for i in L.motes.size():
					var q: Mote = L.motes[i]
					q.u = fmod(q.u + dt * 0.45 * (0.3 + k), 1.0)
					L.mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * 0.35), Vector3(cos(q.a + t) * q.rr, L.y0 + 0.3 + q.u * (L.y1 - L.y0 + 1.6), sin(q.a + t) * q.rr)))
					L.mm.set_instance_color(i, Color(1.0, 1.0, 1.0, k * (1.0 - q.u) * 0.9))
		if P == null or P.dead or P.mode != &"normal" or k < 0.05 or L.decor:
			continue
		L.drop_t = maxf(0.0, L.drop_t - dt)
		if L.drop_t > 0.0:      # just set you down on its landing: let go
			continue
		var dx := L.x - P.x
		var dz := L.z - P.z
		var d := U.hyp(dx, dz)
		var reach := d      # a lift with a landing also holds you along the way over to it
		if L.to != null and P.y > L.y1 - 0.8:
			var sx: float = float(L.to[0]) - L.x
			var sz: float = float(L.to[1]) - L.z
			var sl := sx * sx + sz * sz
			if sl == 0.0:
				sl = 1.0
			var u := clampf(((P.x - L.x) * sx + (P.z - L.z) * sz) / sl, 0.0, 1.0)
			reach = U.hyp(P.x - L.x - sx * u, P.z - L.z - sz * u)
		if reach > L.r + 0.35 or P.y < L.y0 - 0.5 or P.y > L.y1 + 0.8:      # a forgiving catch: the edge of the glow counts
			continue
		if _jumped_off(P) and last_in == L and P.y > L.y1 - 0.8:      # jumping out of the top hover lets you go
			continue
		var rising := P.y < L.y1 - 0.4
		var top := P.y > L.y1 - 0.6
		if L.to != null and top:      # a lift with a landing carries you over and sets you down on it
			var ex: float = float(L.to[0]) - P.x
			var ez: float = float(L.to[1]) - P.z
			var ed := U.hyp(ex, ez)
			if ed < 0.3:
				L.drop_t = 1.2
				P.vy = 0.0
				continue
			var m := minf(ed, 3.2 * dt)
			P.x += ex / ed * m
			P.z += ez / ed * m
		else:      # held in the column (the Spine Beam threads you through the floor); weak at the top so you can steer off
			var pull: float = L.pull if L.pull != 0.0 else (1.6 if rising else 0.6)
			if d > 0.05:
				var m := minf(d, pull * dt)
				P.x += dx / d * m
				P.z += dz / d * m
		var cap: float = (L.speed if L.speed != 0.0 else 8.5) * k
		var want := clampf((L.y1 + 0.05 - P.y) * 5.0, -2.5, cap)      # rise fast, then settle into a steady hover at the top
		if top:
			P.vy = want * k + 15.0 * dt      # (+ half a frame of the player's gravity, so the hover sits AT the top, not half a metre under it)
		else:
			P.vy += (want - P.vy) * minf(1.0, (9.0 if want > P.vy else 6.0) * k * dt)
		_hold(P)
		in_lift = L
	if in_lift != null and last_in != in_lift:
		MsSound.tone(0.35, 220.0, 660.0, 0.1, &"sine", 0.5)
		MsSound.tone(0.5, 110.0, 330.0, 0.06, &"sine", 0.5)
	last_in = in_lift
	# ---- rails: move the trolleys, then carry the rider
	for R: Rail in rails:
		R.px = R.x
		R.pz = R.z
		if not R.keys.is_empty():
			var q := _rail_key_pos(R, t)
			R.x = q.x
			R.z = q.y
		else:
			R.u = _rail_u(R, t)
			R.x = float(R.a[0]) + (float(R.b[0]) - float(R.a[0])) * R.u
			R.z = float(R.a[1]) + (float(R.b[1]) - float(R.a[1])) * R.u
		var mv := U.hyp(R.x - R.px, R.z - R.pz)
		if mv > 1e-4:
			R.heading = atan2(R.x - R.px, R.z - R.pz)
		R.trolley.position = Vector3(R.x, R.y, R.z)
		R.trolley.rotation.y = R.heading if R.heading != null else atan2(float(R.b[0]) - float(R.a[0]), float(R.b[1]) - float(R.a[1]))
		R.flash = maxf(0.0, R.flash - dt * 2.5)
		MsKit.scroll(R.cone, -t * 1.6)
		MsKit.opa(R.cone, 0.55 + 0.35 * R.flash + (0.1 if riding == R else 0.0))
		MsKit.opa(R.pool, 0.35 + 0.3 * R.flash + 0.1 * sin(t * 6.0))
		var near_r := P == null or U.hyp(P.x - R.x, P.z - R.z) < NEAR
		for q: Hoop in R.hoops:
			q.m.visible = near_r
			if not near_r:
				continue
			q.u = fmod(q.u + dt * 0.8, 1.0)
			var s := 0.62 + (R.r - 0.62) * q.u
			q.m.scale = Vector3(s, 1.0, s)
			q.m.position.y = -0.29 - q.u * R.ch
			MsKit.opa(q.m, sin(q.u * PI) * (0.6 + 0.4 * R.flash))
		if R.cargo != null:
			R.cargo.position = Vector3(R.x + 0.9, R.ride + 0.6 + sin(t * 2.0) * 0.05, R.z)
	if P == null or P.dead:
		riding = null
		return
	if riding != null:
		var R := riding
		var off := U.hyp(P.x - R.x, P.z - R.z)
		ride_t += dt
		# let go only on a real jump, or when you steer well out of the cone (the old "moving up fast = jumped" test dropped you when it pulled you up from below)
		if (_jumped_off(P) and ride_t > 0.12) or off > R.r * 2.2 or P.mode != &"normal":
			riding = null
			release_t = 0.3
			last_rail = R
			last_rail_t = 0.9
			MsSound.tone(0.25, 700.0, 260.0, 0.08, &"sine", 0.5)
		else:
			var mx := R.x - R.px
			var mz := R.z - R.pz
			if _free(P, P.x + mx, P.z + mz):
				P.x += mx
				P.z += mz
			else:      # slide along a wall instead of being scraped off
				if _free(P, P.x + mx, P.z):
					P.x += mx
				if _free(P, P.x, P.z + mz):
					P.z += mz
			if off > 0.25:      # a firm grip back to the middle
				var pull := minf(off - 0.25, 6.0 * dt)
				P.x += (R.x - P.x) / off * pull
				P.z += (R.z - P.z) / off * pull
			P.vy = clampf((R.ride - P.y) * 7.0, -8.0, 9.0)
			_hold(P)
	if last_rail != null and U.hyp(P.x - last_rail.x, P.z - last_rail.z) > last_rail.r * 1.6:      # a rail you jumped off won't re-grab you (even standing under it) until you've left its cone
		last_rail = null
		last_rail_t = 0.0
	elif last_rail != null:
		last_rail_t = maxf(last_rail_t, 0.05)
	if guard is bool and guard == true:
		var g0: Array = []
		for R: Rail in rails:
			if U.hyp(P.x - R.x, P.z - R.z) < R.r * 1.3:
				g0.append(R)
		guard = g0
	if guard is Array:
		var g1: Array = []
		for R: Rail in guard:
			if U.hyp(P.x - R.x, P.z - R.z) <= R.r * 1.8:
				g1.append(R)
		guard = g1 if not g1.is_empty() else null
	if riding == null and release_t <= 0.0 and P.mode == &"normal":
		for R: Rail in rails:
			if (R != last_rail or last_rail_t <= 0.0) and not (guard is Array and (guard as Array).has(R)) and U.hyp(P.x - R.x, P.z - R.z) < R.r * 1.2 and P.y > R.ride - 3.2 and P.y < R.ride + 1.4:
				riding = R
				ride_t = 0.0
				R.flash = 1.0
				_hold(P)
				MsSound.tone(0.3, 330.0, 990.0, 0.1, &"sine", 0.5)
				break


func _free(P: Player, x: float, z: float) -> bool:
	return not P.world.blocked(x, z, P.y, P.h, 0.36, 0.42)


## drop everything (a checkpoint load)
func release() -> void:
	riding = null
	held = null
	immune_t = 1.0
	last_rail = null
	last_rail_t = 0.0
	guard = true
