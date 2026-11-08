class_name OmDive
extends RefCounted
## OMNISPHERE: THE JUMP (JS dive.js). Off the containment ring 170 m up and down into the heavy lifter's open bay, a short playable dive in the live world. The jump: a low shot as he goes over the rail. The fall: the view hangs above and behind him looking down at the lifter; the stick steers him round the line, a leash pulls him back; wreckage falls with him, slower than he does, and hit a piece and it knocks you off line. The flare: the pack lights on its own and he swings onto the ramp, into the bay; then the fly-off.

class Chunk:
	var g: MeshInstance3D
	var r := 1.0
	var v := Vector3.ZERO
	var w := Vector3.ZERO
	var fire: MeshInstance3D = null
	var hit := false


class CineApi:
	var D: OmDive
	var on: bool:
		get:
			return D.st_on
	var play := false
	var camera: View.Shot:
		get:
			return D.cam
	func pose_player(a: Variant) -> void:
		D.pose_player(a)


var summit: OmSummit
var audio: OmAudio
var on_land: Callable
var L: OmCraft.Cargo
var root: Node3D
var cam := View.Shot.new()
var cine := CineApi.new()
var S0 := Vector3.ZERO
var C1 := Vector3.ZERO
var A := Vector3.ZERO
var B1 := Vector3.ZERO
var E := Vector3.ZERO
var F0 := Vector3.ZERO
var off := Vector3.ZERO
var ov := Vector3.ZERO
var cam_p := Vector3.ZERO
var cam_l := Vector3.ZERO
var st_on := false
var ph := "off"
var t := 0.0
var u := 0.0
var v := 0.0
var len_ := 1.0
var ft := 0.0
var done := false
var hit_cd := 0.0
var cam_init := false
var by := 0.0
var bp := 1.3
var bdive := 1.0
var bbrake := 0.0
var bbank := 0.0
var flut := 0.0
var an: Variant = null
var chunks: Array[Chunk] = []
var _hook := Callable()


func _init(p_lv: ExportedLevel, p_summit: OmSummit, p_audio: OmAudio, p_on_land: Callable) -> void:
	summit = p_summit
	audio = p_audio
	on_land = p_on_land
	L = summit.lifter
	cine.D = self
	_hook = _pose
	root = Node3D.new()
	root.name = "OmDive"
	p_lv.add_child(root)
	# ---- the wreckage that falls with him
	var mats := [MsKit.std(0xa02818, .8, .2), MsKit.std(0x3a3f46, .8, .4), MsKit.std(0x14161a, .8, .3)]
	for k in 14:
		var c := Chunk.new()
		var w := 2.0 + randf() * 5.0
		var h := .6 + randf() * 1.6
		var d := 2.0 + randf() * 6.0
		var bm := BoxMesh.new()
		bm.size = Vector3(w, h, d)
		c.g = MsKit.part(root, bm, mats[k % 3], Vector3.ZERO, false)
		c.g.visible = false
		if k % 3 == 0:
			c.fire = MsKit.sprite8(c.g, 0xff7a22, .85, maxf(w, d) * 1.4)
		c.r = maxf(w, d) * .55
		chunks.append(c)


func _local(x: float, y: float, z: float) -> Vector3:
	return L.group.quaternion * Vector3(x, y, z) + L.group.position


func _bez(q: float) -> Vector3:
	var w := 1.0 - q
	return S0 * (w * w) + C1 * (2.0 * w * q) + A * (q * q)


static func _ease(q: float) -> float:
	q = clampf(q, 0.0, 1.0)
	return q * q * (3.0 - 2.0 * q)


static func _damp(a: float, b: float, k: float, dt: float) -> float:
	return a + (b - a) * (1.0 - exp(-k * dt))


static func _wrap(a: float) -> float:
	return atan2(sin(a), cos(a))


func _scatter() -> void:
	for k in chunks.size():
		var c := chunks[k]
		var q := .12 + (float(k) / chunks.size()) * .78
		var p := _bez(q)
		var on_line := k % 4 == 1      # every few pieces sit right on the line
		p.x += (randf() - .5) * 3.0 if on_line else (randf() - .5) * 26.0
		p.z += (randf() - .5) * 3.0 if on_line else (randf() - .5) * 26.0
		p.y += 6.0 + randf() * 10.0
		c.g.position = p
		c.g.visible = true
		c.hit = false
		c.v = Vector3((randf() - .5) * 4.0, -10.0 - randf() * 6.0, (randf() - .5) * 4.0)
		c.w = Vector3(randf() - .5, randf() - .5, randf() - .5) * 2.5


func start(P: Player) -> void:
	if st_on:
		return
	st_on = true
	ph = "jump"
	t = 0.0
	u = 0.0
	v = maxf(4.0, -P.vy)
	done = false
	hit_cd = 0.0
	cam_init = false
	summit.take_lifter()
	S0 = Vector3(P.x, P.y, P.z)
	A = _local(0, 9, -34)
	B1 = _local(0, 3.5, -17)
	E = _local(0, .05, -5)
	var out := Vector3(P.x - OmMarks.OMNI.x, 0.0, P.z - OmMarks.OMNI.z).normalized()
	C1 = S0 + out * 22.0
	C1.y = lerpf(S0.y, A.y, .45)
	var brg := atan2(P.z - OmMarks.OMNI.z, P.x - OmMarks.OMNI.x)
	var dr := _wrap(brg - PI)      # gone off the ring by the feed riser: swing out round its tower
	if absf(dr) < .34:
		C1 += Vector3(-out.z, 0.0, out.x) * ((1.0 if dr >= 0.0 else -1.0) * 34.0)
	var ln := 0.0
	for i in range(1, 21):
		ln += _bez(i / 20.0).distance_to(_bez((i - 1) / 20.0))
	len_ = ln
	off = Vector3.ZERO
	ov = Vector3(P.vx * .3, 0.0, P.vz * .3)
	by = atan2(A.x - P.x, A.z - P.z)
	bp = .3
	bdive = 1.0
	bbrake = 0.0
	_scatter()
	Game.hud.hide_xhair = true
	audio.loop("ffWind", 1.0)
	audio.play("ffJump")
	audio.play("sphereBreak")
	P.grounded = false
	P.invuln = maxf(P.invuln, .5)
	P.jet_on = false
	P.jetting = false
	an = Game.animator
	if an != null:
		an.pose_hook = _hook


func stop() -> void:
	done = false
	if not st_on and ph == "off":
		return
	st_on = false
	ph = "off"
	Game.hud.hide_xhair = false
	audio.loop("ffWind", 0.0)
	if an != null and an.pose_hook == _hook:
		an.pose_hook = Callable()
	for c in chunks:
		c.g.visible = false
	var P: Player = Game.player
	if P != null:
		P.jet_on = false
		P.jetting = false


func _steer(dt: float) -> void:
	var m := Vector2(Inp.move.x, Inp.move.y)
	var fwd := Vector3(A.x - S0.x, 0.0, A.z - S0.z).normalized()
	var right := Vector3(-fwd.z, 0.0, fwd.x)
	ov.x += (right.x * m.x + fwd.x * m.y) * 40.0 * dt
	ov.z += (right.z * m.x + fwd.z * m.y) * 40.0 * dt
	ov *= exp(-2.6 * dt)
	var sp := U.hyp(ov.x, ov.z)
	if sp > 16.0:
		ov *= 16.0 / sp
	off += ov * dt
	var Rl := lerpf(14.0, 1.0, _ease((u - .55) / .4))
	var d := U.hyp(off.x, off.z)
	if d > Rl:
		var k := (d - Rl) * 4.0 * dt
		off.x -= off.x / d * k
		off.z -= off.z / d * k
	bbank = _damp(bbank, clampf((ov.x * right.x + ov.z * right.z) * .04, -.6, .6), 6.0, dt)


func update(dt: float, P: Player) -> void:
	if not st_on or P == null:
		return
	t += dt
	hit_cd = maxf(0.0, hit_cd - dt)
	flut += dt
	L.update(dt)
	L.group.position.y += sin(t * 1.3) * .004
	# the fall: along the line at a speed that builds to ~34 m/s, steered round it
	if ph == "jump" or ph == "fall":
		if ph == "jump" and t > .9:
			ph = "fall"
		v = minf(34.0, v + dt * 22.0)
		u = minf(1.0, u + v * dt / len_)
		_steer(dt)
		var base := _bez(u)
		P.x = base.x + off.x
		P.y = base.y
		P.z = base.z + off.z
		P.vy = -v
		P.grounded = false
		var tgt := atan2(A.x - P.x, A.z - P.z)
		by += clampf(_wrap(tgt - by), -4.0 * dt, 4.0 * dt)
		bp = _damp(bp, 1.3, 3.0, dt)
		bdive = _damp(bdive, 1.0 if t < .6 else 0.0, 3.0, dt)
		if u >= 1.0:
			ph = "flare"
			ft = 0.0
			F0 = Vector3(P.x, P.y, P.z)
			audio.play("ffJet")
			P.jet_on = true
			P.jetting = true
	elif ph == "flare":
		ft += dt
		var q := clampf(ft / 1.5, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - q, 2.4)
		var w := 1.0 - e
		B1 = _local(0, 3.5, -17)      # (the lifter bobs: follow it)
		E = _local(0, .05, -5)
		var p := F0 * (w * w) + B1 * (2.0 * w * e) + E * (e * e)
		P.x = p.x
		P.y = p.y
		P.z = p.z
		P.vy = 0.0
		bbrake = _damp(bbrake, 1.0, 6.0, dt)
		bp = _damp(bp, .1, 5.0, dt)
		by += clampf(_wrap(L.group.rotation.y - by), -5.0 * dt, 5.0 * dt)
		if q >= 1.0:
			_land(P)
	# wreckage
	for c in chunks:
		if not c.g.visible:
			continue
		c.v.y -= 6.0 * dt
		c.g.position += c.v * dt
		c.g.rotation += c.w * dt
		if c.fire != null:
			MsKit.opa(c.fire, .6 + .3 * sin(t * 23.0 + c.r))
		if c.g.position.y < 2.0:
			c.g.visible = false
		if not c.hit and ph != "flare" and hit_cd <= 0.0 and c.g.position.distance_to(Vector3(P.x, P.y + .9, P.z)) < c.r + 1.1:
			c.hit = true
			hit_cd = .8
			ov += Vector3(P.x - c.g.position.x, 0.0, P.z - c.g.position.z).normalized() * 14.0
			if Game.combat != null and P.hp > 14.0:
				Game.combat.hurt_player(P, 12.0, c.g.position.x, c.g.position.z, "melee")
			Game.fx.sparks(Vector3(P.x, P.y + 1.0, P.z), 24, 9.0, null, 0xffc060)
			Game.fx.shake = maxf(Game.fx.shake, 1.0)
			audio.play_at("groan", Vector3(P.x, P.y, P.z))
	if st_on:
		_camera(dt, P)


func _land(P: Player) -> void:
	ph = "done"
	st_on = false
	done = true
	P.jet_on = false
	P.jetting = false
	var p := _local(0, .05, -5)
	P.x = p.x
	P.y = p.y
	P.z = p.z
	P.vy = 0.0
	P.grounded = true
	audio.play_at("ffLand", p)
	audio.loop("ffWind", 0.0)
	Game.fx.shake = maxf(Game.fx.shake, .8)
	Game.hud.hide_xhair = false
	for c in chunks:
		c.g.visible = false
	if an != null and an.pose_hook == _hook:
		an.pose_hook = Callable()
	if on_land.is_valid():
		on_land.call(P)


# ---- camera: the low shot of the jump, then above and behind looking down the drop at the lifter, then in behind him onto the ramp
func _camera(dt: float, P: Player) -> void:
	var ctr := Vector3(P.x, P.y + .9, P.z)
	var D := (L.group.position - ctr).normalized()
	var hx := -D.x * D.y
	var hy := 1.0 - D.y * D.y
	var hz := -D.z * D.y
	var hl := sqrt(hx * hx + hy * hy + hz * hz)
	if hl == 0.0:
		hl = 1.0
	var p := ctr - D * 7.0 + Vector3(hx, hy, hz) / hl * 2.6
	var l := ctr + D * 30.0
	var fov := 78.0
	if ph == "jump":      # out beside him over the drop, looking back at him going over the rail, the sphere behind
		var out := Vector3(P.x - OmMarks.OMNI.x, 0.0, P.z - OmMarks.OMNI.z).normalized()
		var q := _ease(t / .9)
		var j := Vector3(ctr.x + out.x * 11.0 - out.z * 6.0, ctr.y + 1.5, ctr.z + out.z * 11.0 + out.x * 6.0)
		p = j.lerp(p, q * q)
		l = Vector3(lerpf(lerpf(ctr.x, OmMarks.OMNI.x, .15), l.x, q * q), lerpf(ctr.y + 6.0, l.y, q * q), lerpf(lerpf(ctr.z, OmMarks.OMNI.z, .15), l.z, q * q))
		fov = lerpf(64.0, 78.0, q)
	elif ph == "flare":      # tuck in behind him as he swings onto the ramp
		var q := _ease(ft / 1.5)
		p = p.lerp(_local(0, 5, -26), q)
		l = l.lerp(_local(0, 1.5, 4), q)
		fov = lerpf(78.0, 66.0, q)
	if not cam_init or t < dt * 1.5:
		cam_p = p
		cam_l = l
		cam_init = true
	var k := 1.0 - exp(-(7.0 if ph == "fall" else 12.0) * dt)
	cam_p = cam_p.lerp(p, k)
	cam_l = cam_l.lerp(l, k)
	var sh: float = Game.fx.shake
	cam.pos = cam_p + Vector3(_j(0.0, sh), _j(1.0, sh), _j(2.0, sh))
	cam.look = cam_l
	cam.fov = fov
	var fwd := (cam_l - cam_p).normalized()
	var r := Vector3.UP.cross(fwd).normalized()
	cam.up = fwd.cross(r).normalized().rotated(fwd, -bbank * .25)


func _j(s: float, sh: float) -> float:
	return sin(t * 41.0 + s) * .06 * sh + sin(t * 13.1 + s) * .05


# ---- PROG's body: the skydive pose set from the opening drop, turned into the fall
func _pose(a: Variant) -> void:
	if not st_on:
		return
	OmFreefall.set_pose(a, OmFreefall.ARCH, OmFreefall.DIVE, bdive, OmFreefall.BRAKE, bbrake)
	var f := .04 + .05 * clampf(v / 30.0, 0.0, 1.0) * (1.0 - bbrake)
	OmFreefall.flutter(a, flut, f)
	a.py = Vector3.ZERO
	var P: Player = Game.player
	if P != null:
		P.armed = false
		P.aiming = false


func pose_player(a: Variant) -> void:
	if not st_on:
		return
	an = a
	if a.pose_hook != _hook:
		a.pose_hook = _hook
	var P: Player = Game.player
	var Q := Quaternion(Vector3.UP, by) * Quaternion(Vector3.RIGHT, bp) * Quaternion(Vector3.UP, bbank * (1.0 - bbrake))
	var Ac: Node3D = a.actor
	Ac.quaternion = Q
	Ac.position = Vector3(P.x, P.y + float(a.B.pivot) * float(a.B.scale), P.z)
	Ac.visible = true
