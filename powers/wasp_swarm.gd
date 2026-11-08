class_name WaspSwarm
extends Node3D
## SWARM (JS powers/wasp-swarm.js, the wasp implant): wasps crawling over the player's left arm while it is equipped, and the swarm itself. Cast from the left hand: the swarm flies at the enemy under / near the crosshair, covers it and stings it; when that enemy dies it goes after the nearest other enemy it can see. After LIFE seconds it breaks up and is gone. One MultiMesh for the bodies, one for the wings, one for the distant motes that thicken each swarm.

const LIFE := 10.0          # seconds a swarm lives (the last FADE of it is the break-up)
const FADE := 1.3
const SPEED := 14.0         # m/s while flying to a target
const DPS := 20.0           # damage per second to the enemy it is on (a 60 hp robot takes 3 s)
const TICK := 0.5           # seconds between stings (dps * tick each)
const RANGE := 45.0         # how far the cast looks for an enemy near the aim
const SEEK_R := 18.0        # how far a swarm looks for its next enemy after a kill / while hunting
const WASPS := 40           # modelled wasps per swarm
const WASP_SIZE := 0.07     # their length (m): bigger than life so the swarm reads from across a room
const MOTES := 110          # extra dots per swarm (thicken the cloud cheaply)
const MAX_SWARMS := 3
const ARM_WASPS := 18       # wasps crawling on the arm
const ARM_SIZE := 0.07      # their length (m): bigger than life so they read from the gameplay camera
const MAXW := WASPS * MAX_SWARMS + ARM_WASPS + 4
const MAXM := MOTES * MAX_SWARMS
const BODY_PTS: Array[Vector2] = [Vector2(0, -0.5), Vector2(0.07, -0.44), Vector2(0.15, -0.32), Vector2(0.17, -0.2), Vector2(0.14, -0.08), Vector2(0.05, 0.0), Vector2(0.035, 0.03), Vector2(0.1, 0.08), Vector2(0.115, 0.15), Vector2(0.08, 0.22), Vector2(0.045, 0.26), Vector2(0.1, 0.31), Vector2(0.105, 0.38), Vector2(0.06, 0.45), Vector2(0, 0.48)]


class Wasp:
	var ax := Vector3.ZERO
	var b := Vector3.ZERO
	var w := 0.0
	var r := 0.0
	var ph := 0.0
	var fl := 0.0
	var lag := 0.0
	var p := Vector3.ZERO
	var last := Vector3.ZERO


class Swarm:
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var goal := Vector3.ZERO
	var target: Target = null
	var state := &"seek"
	var t := 0.0
	var st := 0.0
	var sting := 0.2
	var look := 0.0
	var kills := 0
	var w: Array[Wasp] = []
	var m: Array[Wasp] = []
	var voice: AudioStreamPlayer = null


class Crawl:
	var s := 0.0
	var a := 0.0
	var vs := 0.0
	var va := 0.0
	var pause := 0.0
	var fl := 0.0
	var p := Vector3.ZERO


var swarms: Array[Swarm] = []
var _bodies: MultiMesh
var _wings: MultiMesh
var _motes: MultiMesh
var _motes_node: MultiMeshInstance3D
var _n := 0
var _t := 0.0
var _arm_launch := 0.0
var _crawl: Array[Crawl] = []
var _buzz: AudioStreamWAV = null
var _cast_snd: AudioStreamWAV = null


static func _rnd(a: float, b: float) -> float:
	return a + randf() * (b - a)


static func _eligible(t: Target) -> bool:
	return t != null and not t.dead and not t.npc and t.actor_state == null and not t.data.get("ally", false)


## wasp body: a lathe along +Z (head forward), unit length, yellow / black bands baked into vertex colours
static func _body_mesh() -> ArrayMesh:
	var P := PackedVector3Array()
	var C := PackedColorArray()
	var uv := PackedVector2Array()
	var I := PackedInt32Array()
	var seg := 8
	var rows := BODY_PTS.size()
	var Y := Color(1.0, 0.72, 0.05)
	var K := Color(0.05, 0.035, 0.02)
	var B := Color(0.22, 0.12, 0.03)
	for s in seg + 1:
		var a := TAU * s / seg
		for j in rows:
			var q := BODY_PTS[j]
			var v := Vector3(q.x * sin(a), -q.x * cos(a), q.y)      # (lathe axis Y -> Z)
			P.append(v)
			var z := v.z
			var c: Color
			if z < -0.02:
				c = Y if sin((z + 0.5) * 30.0) > -0.15 else K      # banded abdomen
			elif z > 0.27:
				c = Y if v.y < -0.02 else B      # black waist + thorax, yellow face
			else:
				c = K
			C.append(c)
	for s in seg:
		for j in rows - 1:
			var a := s * rows + j
			var b := (s + 1) * rows + j
			I.append_array([a, b, b + 1, a, b + 1, a + 1])
	var mesh := Goggles.indexed_mesh(P, I)
	var arr := mesh.surface_get_arrays(0)
	arr[Mesh.ARRAY_COLOR] = C
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return out


## two wings off the thorax, lying back over the abdomen (flapped by squashing the instance's X scale)
static func _wing_mesh() -> ArrayMesh:
	var L := [Vector3(0.03, 0.09, 0.16), Vector3(0.46, 0.11, -0.02), Vector3(0.4, 0.1, -0.2), Vector3(0.05, 0.08, 0.04)]
	var v := PackedVector3Array()
	var idx := PackedInt32Array()
	for s: float in [1.0, -1.0]:
		var b := v.size()
		for q: Vector3 in L:
			v.append(Vector3(q.x * s, q.y, q.z))
		idx.append_array([b, b + 1, b + 2, b, b + 2, b + 3])
	return Goggles.indexed_mesh(v, idx)


static func _multi(mesh: Mesh, mat: Material, count: int, parent: Node3D) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	mm.visible_instance_count = 0
	var o := MultiMeshInstance3D.new()
	o.multimesh = mm
	o.material_override = mat
	o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	o.custom_aabb = AABB(Vector3.ONE * -100000.0, Vector3.ONE * 200000.0)
	o.name = "wasps"
	parent.add_child(o)
	return mm


func _ready() -> void:
	name = "WaspSwarm"
	var bm := StandardMaterial3D.new()
	bm.vertex_color_use_as_albedo = true
	bm.roughness = 0.45
	bm.metallic = 0.15
	bm.emission_enabled = true      # a little self-lit so the yellow reads on the night street
	bm.emission = Color.hex(0x5a3800ff)
	bm.emission_energy_multiplier = 0.85
	_bodies = _multi(_body_mesh(), bm, MAXW, self)
	var wm := StandardMaterial3D.new()
	wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wm.albedo_color = Color(Color.hex(0xe8f4ffff), 0.42)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_wings = _multi(_wing_mesh(), wm, MAXW, self)
	var mo := StandardMaterial3D.new()
	mo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mo.albedo_color = Color(Color.hex(0x3a2a06ff), 0.95)
	mo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mo.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mo.billboard_keep_scale = true
	var q := QuadMesh.new()
	q.size = Vector2(0.055, 0.055)
	_motes = _multi(q, mo, MAXM, self)
	for i in ARM_WASPS:
		var c := Crawl.new()
		c.s = _rnd(0.08, 0.95)
		c.a = _rnd(0.0, 6.28)
		c.vs = _rnd(0.05, 0.16) * (-1.0 if randf() < 0.5 else 1.0)
		c.va = _rnd(-2.2, 2.2)
		c.fl = _rnd(0.0, 6.0)
		_crawl.append(c)


## write one wasp: position p, facing f (need not be normalised), up hint u, length s, wing flap phase ph
func _put(p: Vector3, f: Vector3, u: Vector3, s: float, ph: float) -> void:
	if _n >= MAXW:
		return
	var fw := f
	if fw.length_squared() < 1e-8:
		fw = Vector3(0.0, 0.0, 1.0)
	fw = fw.normalized()
	var up := u
	var rt := up.cross(fw)
	if rt.length_squared() < 1e-6:
		up = Vector3.UP
		rt = up.cross(fw)
		if rt.length_squared() < 1e-6:
			rt = Vector3.RIGHT
	rt = rt.normalized()
	up = fw.cross(rt)
	_bodies.set_instance_transform(_n, Transform3D(Basis(rt * s, up * s, fw * s), p))
	var flap := 0.25 + 0.75 * absf(sin(ph))
	_wings.set_instance_transform(_n, Transform3D(Basis(rt * (s * flap), up * s, fw * s), p))
	_n += 1


# ---------------- audio: a buzzing voice per swarm (two detuned saws + a fluttering amplitude), quieter with distance ----------------

func _make_sounds() -> void:
	if _buzz != null:
		return
	# the buzz: one loop of the JS's two saws through its band-pass with its 23 Hz flutter (the loop holds whole cycles of each: 1 s holds 196, 211 and 23), pitch and level are live
	var rate := 22050
	var b := OfflineSynth.make(1.0, rate)
	var y0 := 0.0
	var y1 := 0.0
	var x1 := 0.0
	var x2 := 0.0
	var w0 := TAU * 900.0 / rate
	var alpha := sin(w0) / (2.0 * 0.8)
	var a0 := 1.0 + alpha
	var c1 := 2.0 * cos(w0) / a0
	var c2 := (alpha - 1.0) / a0
	var d0 := alpha / a0
	for pass_i in 2:      # (twice round, so the filter's start is gone from the part kept)
		for i in b.size():
			var u := float(i) / rate
			var x := (fposmod(u * 196.0, 1.0) * 2.0 - 1.0) + (fposmod(u * 211.0, 1.0) * 2.0 - 1.0)
			var y := d0 * x - d0 * x2 + c1 * y0 + c2 * y1
			x2 = x1
			x1 = x
			y1 = y0
			y0 = y
			if pass_i == 1:
				b[i] = y * (0.65 + 0.35 * sin(TAU * 23.0 * u))
	_buzz = OfflineSynth.wav(b, rate, true)
	var c := OfflineSynth.make(0.5, 44100)
	OfflineSynth.noise(c, 44100, 0.0, {"type": &"bandpass", "f0": 500.0, "f1": 1600.0, "q": 1.4, "gain": 0.35, "attack": 0.03, "dur": 0.45})
	OfflineSynth.tone(c, 44100, 0.0, {"type": &"sawtooth", "f0": 150.0, "f1": 260.0, "gain": 0.08, "attack": 0.02, "dur": 0.35})
	_cast_snd = OfflineSynth.wav(c, 44100)


func _voice() -> AudioStreamPlayer:
	_make_sounds()
	var v := AudioStreamPlayer.new()
	v.stream = _buzz
	v.bus = &"SFX"
	v.volume_db = -80.0
	add_child(v)
	v.play()
	return v


func _kill(v: AudioStreamPlayer) -> void:
	if v != null:
		var tw := v.create_tween()
		tw.tween_property(v, "volume_db", -60.0, 0.3)
		tw.tween_callback(v.queue_free)


static func _loud(p: Vector3) -> float:
	var L: Vector3 = Game.rig.pos if Game.rig != null else p
	return 1.0 / (1.0 + L.distance_to(p) * 0.3)


func _cast_sound(p: Vector3) -> void:
	_make_sounds()
	Game.sfx.clip(_cast_snd, {"gain": 0.4 + 0.6 * _loud(p), "wet": 0.22})


# ---------------- targets ----------------

static func _centre(t: Target) -> Vector3:
	return Vector3(t.x, t.y + (t.h if t.h != 0.0 else 1.8) * 0.55, t.z)


func _visible_from(from: Vector3, t: Target) -> bool:
	var c := _centre(t)
	var v := c - from
	var d := v.length()
	if d < 0.0001:
		d = 1.0
	return Game.world.ray_clear(from.x, from.y, from.z, v.x / d, v.y / d, v.z / d, d, 0.01) >= d - 0.6


## the enemy closest to the aim line from `from` toward `to` (forgiving up close, tight far away)
func _pick_aimed(from: Vector3, to: Vector3) -> Target:
	var dv := to - from
	var dl := dv.length()
	if dl < 0.0001:
		dl = 1.0
	var best: Target = null
	var bs := INF
	for t: Target in Game.combat.targets:
		if not _eligible(t):
			continue
		var v := _centre(t) - from
		var d := v.length()
		if d > RANGE or d < 0.3:
			continue
		var cs := v.dot(dv) / (d * dl)
		var ang := acos(clampf(cs, -1.0, 1.0))
		if ang > 0.16 + 1.2 / maxf(1.0, d):
			continue
		var s := ang * 10.0 + d * 0.02
		if s < bs and _visible_from(from, t):
			bs = s
			best = t
	return best


func _pick_nearest(from: Vector3, skip: Target = null) -> Target:
	var best: Target = null
	var bd := SEEK_R
	for t: Target in Game.combat.targets:
		if not _eligible(t) or t == skip:
			continue
		var d := Vector3(t.x - from.x, t.y + 1.0 - from.y, t.z - from.z).length()
		if d < bd and _visible_from(from, t):
			bd = d
			best = t
	return best


# ---------------- the swarm ----------------

static func _rand_unit() -> Vector3:
	return Vector3(_rnd(-1.0, 1.0), _rnd(-1.0, 1.0), _rnd(-1.0, 1.0)).normalized()


func cast(origin: Vector3, aim_point: Vector3) -> Swarm:
	while swarms.size() >= MAX_SWARMS:
		var o: Swarm = swarms.pop_front()
		_kill(o.voice)
	var pos := origin
	var to := aim_point
	var dir := to - pos
	var dl := dir.length()
	if dl < 0.0001:
		dl = 1.0
	dir /= dl
	if dl > RANGE:
		to = pos + dir * RANGE
	var sw := Swarm.new()
	sw.pos = pos
	sw.vel = dir * SPEED
	sw.goal = to
	sw.target = _pick_aimed(pos, to)
	sw.voice = _voice()
	if sw.target == null:
		sw.state = &"fly"
	for i in WASPS:
		var w := Wasp.new()
		w.ax = _rand_unit()
		w.b = Vector3(_rnd(-1.0, 1.0), _rnd(-1.0, 1.0), _rnd(-1.0, 1.0)).cross(w.ax).normalized()
		w.w = _rnd(2.5, 6.0) * (-1.0 if randf() < 0.5 else 1.0)
		w.r = _rnd(0.35, 1.0)
		w.ph = _rnd(0.0, 6.28)
		w.fl = _rnd(0.0, 6.28)
		w.lag = _rnd(5.0, 11.0)
		w.p = pos + Vector3(_rnd(-0.06, 0.06), _rnd(-0.06, 0.06), _rnd(-0.06, 0.06))
		w.last = pos
		sw.w.append(w)
	for i in MOTES:
		var m := Wasp.new()
		m.ax = _rand_unit()
		m.b = Vector3(_rnd(-1.0, 1.0), _rnd(-1.0, 1.0), _rnd(-1.0, 1.0)).cross(m.ax).normalized()
		m.w = _rnd(2.0, 7.0) * (-1.0 if randf() < 0.5 else 1.0)
		m.r = _rnd(0.3, 1.1)
		m.ph = _rnd(0.0, 6.28)
		m.lag = _rnd(4.0, 10.0)
		m.p = pos
		sw.m.append(m)
	swarms.append(sw)
	_cast_sound(pos)
	_arm_launch = 0.9
	Game.combat.events.append({"t": "swarmCast", "x": pos.x, "y": pos.y, "z": pos.z})
	return sw


## move the swarm's centre: steer toward the goal at speed, rising over anything solid in the way
func _steer(sw: Swarm, g: Vector3, speed: float, k: float, dt: float) -> float:
	var dv := g - sw.pos
	var d := dv.length()
	if d < 0.0001:
		d = 1.0
	var sp := minf(speed, d * 4.0)
	var kk := 1.0 - exp(-k * dt)
	sw.vel += (dv / d * sp - sw.vel) * kk
	var nx := sw.pos + sw.vel * dt
	if Game.world.point_solid(nx.x, nx.y, nx.z):
		sw.pos.y += maxf(2.0, absf(sw.vel.y)) * dt
		sw.vel *= 0.6
		return d
	sw.pos = Vector3(nx.x, maxf(0.25, nx.y), nx.z)
	return d


func _step(sw: Swarm, dt: float) -> void:
	sw.t += dt
	sw.st += dt
	sw.look -= dt
	var fading := sw.t > LIFE - FADE
	if fading and sw.state != &"fade":
		sw.state = &"fade"
		sw.target = null
	if sw.state == &"fade":
		sw.vel *= exp(-2.0 * dt)
		sw.pos += sw.vel * dt
		sw.pos.y += 0.4 * dt
		return
	if sw.target != null and not _eligible(sw.target):      # it died (to us or to someone else): on to the next one
		var prev := sw.target
		if prev.dead and sw.state == &"attack":
			sw.kills += 1
		sw.target = _pick_nearest(sw.pos, prev)
		sw.state = &"seek" if sw.target != null else &"hunt"
		sw.st = 0.0
		if sw.target != null:
			Game.combat.events.append({"t": "swarmRetarget", "x": sw.pos.x, "y": sw.pos.y, "z": sw.pos.z})
	if sw.state == &"fly":      # no enemy at the cast: fly to the aim point, then look around
		var d := _steer(sw, sw.goal, SPEED, 5.0, dt)
		if sw.look <= 0.0:
			sw.look = 0.2
			var f := _pick_aimed(sw.pos, sw.goal)
			if f == null and d < 6.0:
				f = _pick_nearest(sw.pos)
			if f != null:
				sw.target = f
				sw.state = &"seek"
				sw.st = 0.0
		if d < 0.6 or sw.st > 3.5:
			sw.state = &"hunt"
			sw.st = 0.0
	elif sw.state == &"hunt":      # hover and buzz about, looking for something to sting
		sw.vel *= exp(-3.0 * dt)
		sw.pos += sw.vel * dt
		sw.pos.y += sin(sw.t * 2.1) * 0.25 * dt
		if sw.look <= 0.0:
			sw.look = 0.25
			var f := _pick_nearest(sw.pos)
			if f != null:
				sw.target = f
				sw.state = &"seek"
				sw.st = 0.0
	elif sw.state == &"seek":
		var tg := sw.target
		var d := _steer(sw, _centre(tg), SPEED, 6.0, dt)
		if d < (tg.r if tg.r != 0.0 else 0.5) + 0.7:
			sw.state = &"attack"
			sw.st = 0.0
			sw.sting = 0.15
		elif sw.st > 4.5:
			sw.target = _pick_nearest(sw.pos, tg)
			sw.state = &"seek" if sw.target != null else &"hunt"
			sw.st = 0.0
	elif sw.state == &"attack":      # ride the enemy and sting it
		var tg := sw.target
		var v := _centre(tg)
		var kk := 1.0 - exp(-10.0 * dt)
		sw.vel = Vector3((tg as Robot).vx, 0.0, (tg as Robot).vz) if tg is Robot else Vector3.ZERO
		sw.pos = sw.pos.lerp(v, kk)
		sw.sting -= dt
		if sw.sting <= 0.0:
			sw.sting += TICK
			Game.combat.damage(tg, DPS * TICK, {"x": sw.pos.x, "y": sw.pos.y, "z": sw.pos.z}, 0.0, {"x": v.x, "y": v.y, "z": v.z, "kind": "target", "nx": 0.0, "ny": 1.0, "nz": 0.0})
			Game.combat.events.append({"t": "swarmSting", "x": v.x, "y": v.y, "z": v.z, "kill": tg.dead})


## where each wasp wants to be this frame (relative to the swarm centre), and its smoothed flight toward it
func _draw_swarm(sw: Swarm, dt: float, mi0: int) -> int:
	var u := minf(1.0, (sw.t - (LIFE - FADE)) / FADE) if sw.state == &"fade" else 0.0
	var on := sw.state == &"attack" and sw.target != null
	var tg := sw.target
	var rx := maxf(0.35, (tg.r if tg.r != 0.0 else 0.5) + 0.18) if on else 0.32 + 0.1 * minf(1.0, sw.vel.length() / SPEED)
	var ry := maxf(0.4, (tg.h if tg.h != 0.0 else 1.8) * 0.48) if on else rx * 0.8
	var grow := 1.0 + 5.0 * u * u
	var intro := minf(1.0, sw.t / 0.35)
	var size := WASP_SIZE * (0.55 + 0.45 * intro) * (1.0 - u * 0.85)
	for w in sw.w:
		var a := sw.t * w.w + w.ph
		var v := w.b * cos(a) + w.ax.cross(w.b) * sin(a)
		v *= Vector3(rx * w.r * grow * intro, ry * w.r * grow * intro, rx * w.r * grow * intro)
		v.x += sin(_t * 7.0 + w.fl) * 0.05
		v.y += sin(_t * 9.0 + w.ph) * 0.05
		v += sw.pos
		w.last = w.p
		w.p = w.p.lerp(v, 1.0 - exp(-w.lag * dt))
		var fw := w.p - w.last
		if fw.length_squared() < 1e-7:
			fw = sw.vel
		w.fl += dt * 70.0
		_put(w.p, fw, Vector3.UP, size, w.fl)
	var mi := mi0
	for m in sw.m:
		if mi >= MAXM:
			break
		var a := sw.t * m.w + m.ph
		var v := m.b * cos(a) + m.ax.cross(m.b) * sin(a)
		v *= Vector3(rx * m.r * 1.15 * grow * intro, ry * m.r * 1.15 * grow * intro, rx * m.r * 1.15 * grow * intro)
		v += sw.pos
		m.p = m.p.lerp(v, 1.0 - exp(-m.lag * dt))
		if u > 0.0 and randf() < u * 0.6:      # breaking up: motes wink out
			continue
		_motes.set_instance_transform(mi, Transform3D(Basis.IDENTITY, m.p))
		mi += 1
	if sw.voice != null:
		var g := 0.05 * _loud(sw.pos) * (1.0 - u) * intro * (1.35 if sw.state == &"attack" else 1.0)
		sw.voice.volume_db = linear_to_db(maxf(g, 1e-5))
		sw.voice.pitch_scale = (1.12 if sw.state == &"attack" else 1.0) + sin(_t * 3.0) * 0.03
	return mi


# ---------------- wasps on the arm ----------------

## arm: { agitated, S, E, H, r1, r2 }: left shoulder / elbow / wrist world positions, upper arm / forearm surface radius in m
func _draw_arm(arm: Dictionary, dt: float) -> void:
	var S: Vector3 = arm.S
	var E: Vector3 = arm.E
	var H: Vector3 = arm.H
	var L1 := S.distance_to(E)
	var L2 := E.distance_to(H)
	if L1 < 1e-3 or L2 < 1e-3:
		return
	var hide_n := ceili(ARM_WASPS * 0.5 * minf(1.0, _arm_launch / 0.5)) if _arm_launch > 0.0 else 0      # half of them left with the swarm; they crawl back
	var ag := 2.2 if arm.agitated else 1.0
	for i in range(hide_n, _crawl.size()):
		var c := _crawl[i]
		if c.pause > 0.0:
			c.pause -= dt
		else:
			c.s += c.vs * ag * dt
			c.a += c.va * ag * dt
			if c.s < 0.05 or c.s > 0.97:
				c.vs = -c.vs
				c.s = clampf(c.s, 0.05, 0.97)
			if randf() < dt * 0.5:
				c.va = _rnd(-2.4, 2.4)
				c.vs = _rnd(0.05, 0.16) * (-1.0 if randf() < 0.5 else 1.0)
			if randf() < dt * 0.35:
				c.pause = _rnd(0.2, 0.9) / ag
		# a point on the shoulder -> elbow -> wrist polyline, then out to the sleeve's surface around it
		var k := c.s * (L1 + L2)
		var first := k < L1
		var f := k / L1 if first else (k - L1) / L2
		var seg_a := S if first else E
		var seg_b := E if first else H
		var ax := (seg_b - seg_a).normalized()
		var bu := Vector3.UP if absf(ax.y) <= 0.9 else Vector3.RIGHT
		bu = (bu - ax * bu.dot(ax)).normalized()
		var bv := ax.cross(bu)
		var r1: float = arm.r1
		var r2: float = arm.r2
		var r := (r1 if (first and r1 != 0.0) else (L1 * 0.4 if first else (r2 if r2 != 0.0 else L2 * 0.33))) + 0.012      # sleeve surface (measured by the caller) + half a wasp
		var rad := bu * cos(c.a) + bv * sin(c.a)
		c.p = seg_a.lerp(seg_b, f) + rad * r
		var fwd := ax * (c.vs * (L1 + L2)) + (bv * cos(c.a) - bu * sin(c.a)) * (c.va * r)
		c.fl += dt * (6.0 if c.pause > 0.0 else 30.0)
		_put(c.p, fwd, rad, ARM_SIZE, 1.4 if c.pause > 0.0 else c.fl)


## tick the swarms + draw everything
func update(dt: float, arm: Variant) -> void:
	_t += dt
	_arm_launch = maxf(0.0, _arm_launch - dt)
	_n = 0
	for sw in swarms:
		_step(sw, dt)
	for i in range(swarms.size() - 1, -1, -1):
		if swarms[i].t >= LIFE:
			_kill(swarms[i].voice)
			swarms.remove_at(i)
	var mi := 0
	for sw in swarms:
		mi = _draw_swarm(sw, dt, mi)
	if arm != null:
		_draw_arm(arm, dt)
	_bodies.visible_instance_count = _n
	_wings.visible_instance_count = _n
	_motes.visible_instance_count = mi


func clear() -> void:
	for sw in swarms:
		_kill(sw.voice)
	swarms.clear()
	_n = 0
	_bodies.visible_instance_count = 0
	_wings.visible_instance_count = 0
	_motes.visible_instance_count = 0


## the game is frozen (pause / menu / wheel): mute the buzzing until update() runs again
func quiet() -> void:
	for sw in swarms:
		if sw.voice != null:
			sw.voice.volume_db = -80.0
