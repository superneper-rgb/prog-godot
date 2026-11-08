class_name ZiplineKit
extends RefCounted
## ZIPLINE (kit, JS levels/_kit/zipline.js): a sagging cable between two points that the player rides down hanging from a trolley. X at the top end hooks on; gravity along the cable (minus drag) sets the speed; the camera trails behind and above looking down the line; he lets go just short of the far anchor and lands.
## The ride is a level cine (the level moves the body and owns the camera; the player's own input is ignored meanwhile). from / to are the cable's ends (the hands hang there, the feet ~2 m below). o.cable = false skips the cable mesh.

const HANG := 2.08      # from the hands on the trolley down to the feet
# arms straight up on the handle (the animator's ledge-hang values), legs tucked a little, looking down the line
const POSE := {&"upper_armL": [-2.95, 0.0, -0.12], &"upper_armR": [-2.95, 0.0, 0.12], &"forearmL": [-0.3, 0.0, 0.0], &"forearmR": [-0.3, 0.0, 0.0], &"clavicleL": [0.0, 0.0, 0.05], &"clavicleR": [0.0, 0.0, -0.05],
	&"spine1": [0.06, 0.0, 0.0], &"head": [-0.2, 0.0, 0.0], &"thighL": [-0.45, 0.0, 0.06], &"thighR": [-0.25, 0.0, -0.06], &"shinL": [0.75, 0.0, 0.0], &"shinR": [0.5, 0.0, 0.0]}

var A: Vector3
var B: Vector3
var mid: Vector3
var land: Variant
var max_speed := 21.0
var start_v := 3.0
var grab_r := 2.4
var len_ := 0.0
var on_start := Callable()
var on_land := Callable()
var group: Node3D
var trolley: Node3D
var wheels: Array[Node3D] = []
var on := false
var play := false
var phase := "off"
var u := 0.0
var v := 0.0
var v_prev := 0.0
var t := 0.0
var done := false
var grain_t := 0.0
var th := 0.0
var th_v := 0.0
var ph := 0.0
var ph_v := 0.0
var gust := 0.0
var from_p := Vector3.ZERO
var was_armed: Variant = null
var camera := View.Shot.new(Vector3.ZERO, Vector3.FORWARD, 64.0)
var P0 := Vector3.ZERO
var F := Vector3.FORWARD
var an: Variant = null
var action: Dictionary
var _sp_i := 0
var _sparks: Array = []
var _spark_nodes: Array[MeshInstance3D] = []
var _table := PackedFloat32Array()      # arc length table, for getPointAt


func _init(root: Node3D, o: Dictionary) -> void:
	A = _v(o.from)
	B = _v(o.to)
	land = o.get("land")
	max_speed = o.get("max_speed", 21.0)
	start_v = o.get("start", 3.0)
	grab_r = o.get("grab", 2.4)
	on_start = o.get("on_start", Callable())
	on_land = o.get("on_land", Callable())
	mid = A.lerp(B, 0.5)
	mid.y -= float(o.get("sag", 2.5)) * 2.0
	_build_table()
	group = Node3D.new()
	group.name = "zipline"
	root.add_child(group)
	var steel := MsKit.std(0x2a2c30, 0.45, 0.7)
	if o.get("cable", true):
		var pts := PackedVector3Array()
		var n := ceili(len_ / 1.2)
		for i in n + 1:
			pts.append(_bez(float(i) / n))
		MsKit.part(group, MsKit.tube(pts, 0.03), steel)
	# the trolley: two sheaves in a side plate, a T-handle on a drop bar
	trolley = Node3D.new()
	group.add_child(trolley)
	MsKit.part(trolley, MsKit.box(0.06, 0.26, 0.42), steel)
	for z: float in [-0.12, 0.12]:
		var w := MsKit.part(trolley, MsKit.cyl(0.07, 0.07, 0.1, 12), steel, Vector3(0.0, 0.06, z))
		w.rotation.z = PI / 2.0
		wheels.append(w)
	MsKit.part(trolley, MsKit.box(0.04, 0.42, 0.04), steel, Vector3(0.0, -0.3, 0.0))
	var handle := MsKit.part(trolley, MsKit.cyl(0.025, 0.025, 0.5, 8), MsKit.std(0x8a2a1a, 0.6), Vector3(0.0, -0.5, 0.0))
	handle.rotation.z = PI / 2.0
	# sparks off the sheaves at speed
	var q := MsKit.quad()
	for i in 24:
		var s := MsKit.glow(group, q, 4, 0xffc070, 1.0)
		s.scale = Vector3.ONE * 0.06
		s.visible = false
		_spark_nodes.append(s)
		_sparks.append({"p": Vector3.ZERO, "v": Vector3.ZERO, "life": 0.0})
	_place_trolley(0.0)
	action = {"x": A.x, "z": A.z, "label": o.get("label", "ZIPLINE"), "active": func(P: Player) -> bool: return not on and U.hyp(P.x - A.x, P.z - A.z) < grab_r and absf(P.y + HANG - A.y) < 1.9, "run": begin}


static func _v(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])


func _bez(s: float) -> Vector3:
	var i := 1.0 - s
	return A * (i * i) + mid * (2.0 * i * s) + B * (s * s)


func _tan(s: float) -> Vector3:
	return ((mid - A) * (2.0 * (1.0 - s)) + (B - mid) * (2.0 * s)).normalized()


func _build_table() -> void:
	_table.resize(201)
	var p := _bez(0.0)
	var acc := 0.0
	_table[0] = 0.0
	for i in range(1, 201):
		var q := _bez(float(i) / 200.0)
		acc += p.distance_to(q)
		_table[i] = acc
		p = q
	len_ = acc


## three.js getPointAt / getTangentAt: u along the length
func _s_of(uu: float) -> float:
	var want := clampf(uu, 0.0, 1.0) * len_
	var lo := _table.bsearch(want)
	if lo <= 0:
		return 0.0
	if lo >= 201:
		return 1.0
	var a := _table[lo - 1]
	var b := _table[lo]
	return ((lo - 1) + (want - a) / maxf(b - a, 1e-6)) / 200.0


func _place_trolley(uu: float) -> void:
	P0 = _bez(_s_of(uu))
	F = _tan(_s_of(clampf(uu, 0.001, 0.999)))
	trolley.position = P0
	trolley.rotation = Vector3(0.0, atan2(F.x, F.z), 0.0)


static func _ease(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


## the pose: arms rise onto the handle while he grabs; a few running steps as it bites; legs trail and flutter at speed; tucked forward on the brake
func _hook(a: Variant) -> void:
	if not on:
		return
	var Pl := Game.player
	if Pl != null:      # hands on the handle, not the gun (the animator's gun layer would pull the arms down)
		if was_armed == null:
			was_armed = Pl.armed
		Pl.armed = false
		Pl.aiming = false
		Pl.ads = false
	var grab := _ease(clampf(t / 0.45, 0.0, 1.0)) if phase == "grab" else 1.0
	var k := clampf(v / max_speed, 0.0, 1.0)
	var brake := clampf((u - 0.9) / 0.08, 0.0, 1.0)
	var run := clampf(1.0 - t / 0.9, 0.0, 1.0) if phase == "ride" else 0.0
	for n: StringName in POSE:
		var i: int = Animator.KEYS.find(n)
		if i < 0:
			continue
		var val: Array = POSE[n]
		var ns := String(n)
		var w := grab if ns.begins_with("upper_arm") or ns.begins_with("forearm") or ns.begins_with("clavicle") else 1.0
		a.pose[i] = (a.pose[i] as Vector3).lerp(Vector3(val[0], val[1], val[2]), w)
	var st := t * 13.0
	var fl := sin(t * 17.0) * 0.1 * k      # running stride off the deck, then the flutter of the wind
	_set_p(a, &"thighL", Vector3(-0.45 + sin(st) * 0.7 * run + fl - 0.5 * brake, 0.0, 0.06))
	_set_p(a, &"thighR", Vector3(-0.25 - sin(st) * 0.7 * run - fl - 0.55 * brake, 0.0, -0.06))
	_set_p(a, &"shinL", Vector3(0.75 + maxf(0.0, cos(st)) * 0.6 * run + 0.4 * brake, 0.0, 0.0))
	_set_p(a, &"shinR", Vector3(0.5 + maxf(0.0, -cos(st)) * 0.6 * run + 0.45 * brake, 0.0, 0.0))
	var flex := clampf(-th * 0.6, -0.3, 0.3)      # arms take the swing
	_add_x(a, &"forearmL", -flex)
	_add_x(a, &"forearmR", -flex)
	_set_p(a, &"head", Vector3(-0.2 - 0.15 * k + 0.2 * brake, 0.0, 0.0))


func _set_p(a: Variant, n: StringName, val: Vector3) -> void:
	var i: int = Animator.KEYS.find(n)
	if i >= 0:
		a.pose[i] = val


func _add_x(a: Variant, n: StringName, dx: float) -> void:
	var i: int = Animator.KEYS.find(n)
	if i >= 0:
		a.pose[i] = (a.pose[i] as Vector3) + Vector3(dx, 0.0, 0.0)


func begin() -> void:
	var P := Game.player
	if P == null or on:
		return
	on = true
	phase = "grab"
	u = 0.0
	v = 0.0
	v_prev = 0.0
	t = 0.0
	done = false
	th = 0.0
	th_v = 0.0
	ph = 0.0
	ph_v = 0.0
	from_p = Vector3(P.x, P.y, P.z)
	P.vx = 0.0
	P.vy = 0.0
	P.vz = 0.0
	an = Game.animator
	_place_trolley(0.0)
	var fw0 := Vector3(F.x, 0.0, F.z).normalized()
	camera.pos = Vector3(P0.x, P0.y - 0.4, P0.z) + fw0 * 2.8 + Vector3(fw0.z, 0.0, -fw0.x) * -2.4
	camera.look = Vector3(P0.x, P0.y - 1.1, P0.z) + F * -0.5
	MsSound.play([["noise", 0.3, {"type": &"bandpass", "f0": 2600.0, "q": 3.0, "gain": 0.35, "dur": 0.12}], ["tone", 0.3, {"type": &"sine", "f0": 900.0, "f1": 600.0, "gain": 0.15, "dur": 0.1}], ["noise", 0.38, {"type": &"highpass", "f0": 3000.0, "gain": 0.3, "dur": 0.06}]], 0.1)
	if on_start.is_valid():
		on_start.call()


func _finish_ride(P: Player) -> void:
	on = false
	phase = "off"
	done = true
	if an != null:
		an.pose_hook = Callable()
		an.actor.rotation = Vector3.ZERO
	if was_armed == true:
		P.armed = true
	was_armed = null
	var L: Vector3 = _v(land) if land != null else Vector3(B.x, B.y - HANG, B.z)
	F = _tan(_s_of(0.99))
	P.x = L.x
	P.y = L.y + 0.35
	P.z = L.z
	P.vx = F.x * 2.0
	P.vz = F.z * 2.0
	P.vy = -1.0
	P.yaw = atan2(F.x, F.z)      # a short drop off the handle onto the walk
	Game.rig.snap_to(P)
	MsSound.play([["noise", 0.12, {"type": &"lowpass", "f0": 600.0, "f1": 120.0, "gain": 0.5, "dur": 0.18}], ["tone", 0.12, {"type": &"sine", "f0": 110.0, "f1": 50.0, "gain": 0.4, "dur": 0.16}], ["noise", 0.0, {"type": &"bandpass", "f0": 1800.0, "q": 4.0, "gain": 0.2, "dur": 0.2}]], 0.15)
	if Game.fx != null:
		Game.fx.shake = maxf(Game.fx.shake, 0.45)
	if on_land.is_valid():
		on_land.call()


func update(dt: float, P: Player) -> void:
	for i in _sparks.size():
		var s: Dictionary = _sparks[i]
		if s.life > 0.0:
			s.life = float(s.life) - dt
			s.v = (s.v as Vector3) + Vector3(0.0, -9.8 * dt, 0.0)
			s.p = (s.p as Vector3) + (s.v as Vector3) * dt
			_spark_nodes[i].position = s.p
			_spark_nodes[i].visible = s.life > 0.0
	if not on or P == null:
		if not on and not done:
			_place_trolley(0.0)
		return
	t += dt
	if phase == "grab":      # reach up, hook on; he is lifted off the deck as he takes his weight
		_place_trolley(0.0)
		var k := _ease(clampf(t / 0.45, 0.0, 1.0))
		P.x = lerpf(from_p.x, P0.x, k)
		P.z = lerpf(from_p.z, P0.z, k)
		P.y = lerpf(from_p.y, P0.y - HANG, k)
		P.vx = 0.0
		P.vy = 0.0
		P.vz = 0.0
		P.yaw = atan2(F.x, F.z)
		if t >= 0.45:
			phase = "ride"
			t = 0.0
			v = start_v
	else:
		F = _tan(_s_of(minf(0.999, u)))
		var slope := -F.y      # sine of the drop angle
		v = minf(max_speed, maxf(2.5, v + (9.8 * slope - 0.012 * v * v) * dt))
		if u > 0.93:      # the brake block before the anchor
			v = maxf(4.0, v - 22.0 * dt)
		var acc := (v - v_prev) / maxf(dt, 1e-3)
		v_prev = v
		u = minf(1.0, u + v * dt / len_)
		_place_trolley(u)
		# the swing: a pendulum (1.6 m) about the hands, kicked back by the acceleration, damped; a wind sway on top
		th_v += (-9.8 / 1.6 * sin(th) - clampf(acc, -25.0, 25.0) / 1.6 * 0.9 - 1.6 * th_v) * dt
		th = clampf(th + th_v * dt, -0.7, 0.7)
		gust += dt
		var wind := 0.1 * sin(gust * 1.3) + 0.05 * sin(gust * 3.7)
		ph_v += (-6.0 * (ph - wind) - 1.2 * ph_v) * dt
		ph += ph_v * dt
		P.x = P0.x
		P.y = P0.y - HANG
		P.z = P0.z
		P.vx = 0.0
		P.vy = 0.0
		P.vz = 0.0
		P.yaw = atan2(F.x, F.z)
		P.grounded = false
		for w: Node3D in wheels:      # the sheaves spin
			w.rotate_object_local(Vector3.UP, v * dt / 0.07)
		# sparks: the sheaves on the wet cable, more the faster it goes
		var k := v / max_speed
		if randf() < k * k * 1.6:
			_sp_i = (_sp_i + 1) % _sparks.size()
			_sparks[_sp_i] = {"p": Vector3(P0.x, P0.y + 0.05, P0.z), "v": Vector3(-F.x * v * 0.3 + (randf() - 0.5) * 2.0, randf() * 2.0, -F.z * v * 0.3 + (randf() - 0.5) * 2.0), "life": 0.3 + randf() * 0.3}
		grain_t -= dt
		if grain_t <= 0.0:
			grain_t = 0.09
			MsSound.noise(0.14, &"bandpass", snappedf(1400.0 + 1800.0 * k, 200.0), snappedf(1400.0 + 1800.0 * k, 200.0), snappedf(0.05 + 0.16 * k, 0.03), 6.0, 0.2)
		if u >= 0.995:
			_finish_ride(P)
			return
	if an != null and an.pose_hook != _hook:
		an.pose_hook = _hook
	# camera: behind and above, looking down the line; it shakes with speed and banks a little with his sway
	var yaw := atan2(F.x, F.z)
	var side := Vector3(cos(yaw), 0.0, -sin(yaw))
	var k2 := clampf(v / max_speed, 0.0, 1.0)
	var lead := 0.0 if phase == "grab" else clampf((t - 0.3) / 1.6, 0.0, 1.0)      # a three-quarter view from behind his right: the swing and the legs read
	var lb := _ease(lead)      # the hook-on is seen from out in front (the mast behind him); then the camera swings round behind
	var fw := Vector3(F.x, 0.0, F.z).normalized()
	var cp := P0 + fw * lerpf(2.8, -3.6 - 0.9 * k2, lb) + side * lerpf(-2.4, -2.1, lb) + Vector3.UP * lerpf(-0.4, 0.6, lb)
	cp.x += (randf() - 0.5) * 0.05 * k2
	cp.y += (randf() - 0.5) * 0.05 * k2
	var cl := Vector3(P0.x, P0.y - 1.1, P0.z) + F * lerpf(-0.5, 9.0, lb)
	var kk := 1.0 - exp(-dt * 5.0)
	camera.pos = camera.pos.lerp(cp, kk)
	camera.look = camera.look.lerp(cl, kk)
	camera.fov = 64.0 + 8.0 * k2
	var bank := -ph * 0.5
	camera.up = Vector3(side.x * bank, 1.0, side.z * bank)


func reset() -> void:
	on = false
	done = false
	u = 0.0
	if an != null and an.pose_hook == _hook:
		an.pose_hook = Callable()
	_place_trolley(0.0)


func pose_player(a: Variant) -> void:
	if not on:
		return
	if a.pose_hook != _hook:
		an = a
		a.pose_hook = _hook
	if phase != "ride":
		return
	# the whole body swings about the hands: fore-aft with the pendulum, side to side in the wind
	var A2: Node3D = a.actor
	var yaw := atan2(F.x, F.z)
	var Q := Quaternion(Vector3.UP, yaw) * Quaternion(Vector3.RIGHT, -th) * Quaternion(Vector3.BACK, ph)
	A2.quaternion = Q
	var hands := P0 - Vector3(0.0, 0.5, 0.0)
	var up: float = HANG - 0.5 - float(a.B.pivot) * float(a.B.scale)
	A2.position = hands - Q * Vector3(0.0, up, 0.0)
	A2.visible = true
