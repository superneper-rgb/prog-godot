class_name OmSkyFoes
extends RefCounted
## OMNISPHERE sky foes (JS skyfoes.js): everything that comes at PROG in the opening freefall. FOINT HORNET gun drones, WASP ram drones, the MULE missile carrier, the REPO-MAN gunship, homing missiles, flak, the burning wreck of Tug 9. Whatever flies is simulated in the FALLING FRAME (positions relative to the frame origin F that falls with PROG) and drawn at F + rel; smoke, flak puffs and fireballs stay put in the world, so they rush up past him. Every foe is a combat target. Bodies are the exporter's hidden templates, copied per foe.

const HP := {"hornet": 60.0, "wasp": 18.0, "mule": 260.0, "ship": 1400.0, "missile": 9.0}
static var tid := 9300


class Frame:
	var F := Vector3.ZERO
	var dF := Vector3.ZERO
	var P: Player
	var pc := Vector3.ZERO
	var pv := Vector3.ZERO
	var fwd := Vector3.BACK
	var right := Vector3.RIGHT
	var t := 0.0
	var dodging := false


class Foe:
	var kind := ""
	var hp := 0.0
	var rel := Vector3.ZERO
	var vel := Vector3.ZERO
	var t := 0.0
	var st := "rise"
	var dead := false
	var gone := false
	var dead_t := 0.0
	var g: Node3D
	var ship: OmCraft.Gunship = null
	var T: OmProp = null
	var hb: OmCraft.Hitboxes = null
	var eye: MeshInstance3D = null
	var jets: Array[MeshInstance3D] = []
	var fans: Array[Node3D] = []
	var side := 0.0
	var ang := 0.0
	var dir := 1.0
	var fire_t := 1.0
	var ph := 0.0
	var R_ := -1.0
	var hy := -999.0
	var burst := 0
	var dive_end := -1.0
	var leave_at := 0.0
	var salvo_t := 4.0
	var ng := 0.0


class Msl:
	var rel := Vector3.ZERO
	var vel := Vector3.ZERO
	var speed := 36.0
	var turn := 1.5
	var dmg := 20.0
	var arm_t := .35
	var life := 7.0
	var t := 0.0
	var lost := false
	var gone := false
	var closing := 99.0
	var g: Node3D
	var flame: MeshInstance3D
	var T: OmProp
	var smoke_t := 0.0


class ChunkC:
	var g: Node3D
	var r := 1.0
	var rel := Vector3.ZERO
	var vel := Vector3.ZERO
	var w := Vector3.ZERO
	var t := 0.0
	var hit := false
	var fall := 15.0
	var big := false
	var gone := false


var lv: ExportedLevel
var craft: OmCraft
var audio: OmAudio
var group: Node3D
var smoke: OmPuffs
var fire: OmPuffs
var foes: Array[Foe] = []
var missiles: Array[Msl] = []
var chunks: Array[ChunkC] = []
var tracers: Array = []
var tr_mm := MultiMesh.new()
var fr: Frame = null
var clock := 0.0
var tpl := {}
var chunk_r: Array[float] = []
var _lock: Array = []


static func _rr(a: float, c: float) -> float:
	return a + randf() * (c - a)


func _init(p_lv: ExportedLevel, p_craft: OmCraft, p_audio: OmAudio) -> void:
	lv = p_lv
	craft = p_craft
	audio = p_audio
	group = Node3D.new()
	group.name = "freefall sky"
	lv.add_child(group)
	smoke = OmPuffs.new(group, 900, false)
	fire = OmPuffs.new(group, 500, true)
	for k: String in ["hornet", "wasp", "mule", "missile", "chunk0", "chunk1", "chunk2", "chunk3", "chunk4", "chunk5"]:
		var n := VhKit.one(lv, "om-tpl-" + k)
		n.visible = false
		tpl[k] = n
	for i in 6:
		var ab := _aabb(tpl["chunk%d" % i])
		chunk_r.append(maxf(maxf(ab.x, ab.y), ab.z) * .55)
	# tracers (AA streams rising from the plant): thin additive boxes
	tr_mm.transform_format = MultiMesh.TRANSFORM_3D
	var bm := BoxMesh.new()
	tr_mm.mesh = bm
	tr_mm.instance_count = 96
	tr_mm.visible_instance_count = 0
	var tn := MultiMeshInstance3D.new()
	tn.multimesh = tr_mm
	tn.material_override = VhKit.unlit(0xffc070, .9)
	(tn.material_override as StandardMaterial3D).blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	(tn.material_override as StandardMaterial3D).disable_fog = true
	tn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tn.custom_aabb = AABB(Vector3.ONE * -100000.0, Vector3.ONE * 200000.0)
	group.add_child(tn)


static func _aabb(n: Node3D) -> Vector3:
	var out := AABB()
	var first := true
	for mi in VhKit.meshes(n):
		if first:
			out = mi.get_aabb()
			first = false
		else:
			out = out.merge(mi.get_aabb())
	return out.size


func _copy(k: String) -> Node3D:
	var g: Node3D = (tpl[k] as Node3D).duplicate()
	g.visible = true
	group.add_child(g)
	return g


func _world(rel: Vector3) -> Vector3:
	return rel + fr.F


func _sp(f: Node3D, c: int, s: float, x: float, y: float, z: float) -> MeshInstance3D:
	var g := MsKit.sprite8(f, c, 1.0, s)
	g.position = Vector3(x, y, z)
	return g


## a combat target that follows a foe (the game's guns, rockets and kill rewards all work on it)
func _target(hp: float, r: float, h: float) -> OmProp:
	var T := OmProp.make(tid, 0.0, 0.0, 0.0, r, h, hp)
	tid += 1
	T.dead = false
	if Game.combat != null:
		Game.combat.targets.append(T)
	return T


func _drop_target(T: OmProp, hb: OmCraft.Hitboxes = null) -> void:
	if hb != null:
		hb.drop()
	if T != null and Game.combat != null:
		Game.combat.targets.erase(T)


func _sync_target(f: Foe) -> void:
	var T := f.T
	if T == null:
		return
	var v := _world(f.rel)
	T.x = v.x
	T.bx = v.x
	T.z = v.z
	T.bz = v.z
	T.y = v.y - T.h / 2.0
	T.kx = 0.0
	T.kz = 0.0
	if f.hb != null:
		var d: Vector3 = f.g.global_transform.basis.z
		f.hb.sync(v.x, v.y, v.z, atan2(d.x, d.z))


## a fireball where it happened (world): fx flash + light, rolling fire, dark smoke; dmg hurts PROG and other foes inside r
func blast(pw: Vector3, r: float = 3.0, o: Dictionary = {}) -> void:
	var fx: Variant = Game.fx
	if r <= 3.0:
		fx.explosion(pw, r * .45)
	else:
		fx.light.position = pw
		fx.light.light_energy = 40.0 / PI
		fx.light_t = .5
	fire.emit(pw.x, pw.y, pw.z, {"size": r * 3.2, "grow": .5, "life": .18, "col": 0xfff0c0, "alpha": 1.0, "fade": .02})      # the flash
	var cols := [0xffd080, 0xff8030, 0xffb050]
	for i in int(10.0 + r * 3.0):
		var a := _rr(0, 6.3)
		var e := _rr(-1, 1)
		var s := _rr(2, 6) * r * .5
		fire.emit(pw.x, pw.y, pw.z, {"vx": cos(a) * s, "vy": e * s, "vz": sin(a) * s, "size": r * _rr(.9, 1.6), "grow": 1.4, "life": _rr(.35, .7), "col": cols[i % 3], "alpha": .9, "drag": 3.5, "fade": .05})
	for _i in int(6.0 + r * 2.0):
		var a := _rr(0, 6.3)
		var s := _rr(1, 3.5) * r * .4
		smoke.emit(pw.x + _rr(-1, 1) * r * .4, pw.y + _rr(-1, 1) * r * .4, pw.z + _rr(-1, 1) * r * .4, {"vx": cos(a) * s, "vy": _rr(-.5, 1.5) * s, "vz": sin(a) * s, "size": r * _rr(1.4, 2.4), "grow": 1.8, "life": _rr(2, 3.6), "col": 0x2a2420, "alpha": .75, "drag": 1.4, "fade": .1})
	if not o.get("quiet", false):
		audio.play_at(o.get("sound", "boom"), pw)
	var C: Combat = Game.combat
	var dmg: float = o.get("dmg", 0.0)
	var foe_dmg: float = o.get("foe_dmg", 0.0)
	if dmg != 0.0 and fr != null and fr.P != null and not fr.P.dead:
		var d := _world(fr.pc).distance_to(pw)
		if d < r * 1.6:
			C.hurt_player(fr.P, dmg * (1.0 - d / (r * 1.6) * .5), pw.x, pw.z, "melee")
		fx.shake = maxf(fx.shake, clampf(2.2 - d / 8.0, .3, 1.6))
	if foe_dmg != 0.0:
		for f in foes:
			if not f.dead and f.T != null:
				var d := _world(f.rel).distance_to(pw)
				if d < r * 2.0:
					C.damage(f.T, foe_dmg * (1.0 - d / (r * 2.0) * .5), {"x": pw.x, "z": pw.z}, 0.0)


# ---- foes
func spawn(kind: String, o: Dictionary = {}) -> Foe:
	var f := Foe.new()
	f.kind = kind
	f.hp = o.get("hp", HP[kind])
	f.side = o.get("side", _rr(-1.2, 1.2))
	f.leave_at = o.get("leave_at", 0.0)
	if kind == "ship":
		f.ship = craft.gunship()
		f.ship.group.scale = Vector3.ONE * 1.25
		f.g = f.ship.group
	else:
		f.g = _copy(kind)
	if kind == "hornet":
		f.eye = _sp(f.g, 0xff2a14, 1.1, 0, .04, .78)
		f.jets = [_sp(f.g, 0x7af3ff, 1.1, .38, -1.1, -.05), _sp(f.g, 0x7af3ff, 1.1, -.38, -1.1, -.05)]
		f.T = _target(f.hp, .75, 1.4)
	elif kind == "wasp":
		f.eye = _sp(f.g, 0xff2010, .7, 0, .8, 0)
		f.jets = [_sp(f.g, 0xffa040, 1.4, 0, -1.05, 0)]
		f.T = _target(f.hp, .5, 1.3)
	elif kind == "mule":
		f.eye = _sp(f.g, 0xff3018, 1.6, 0, -.2, 2.05)
		f.jets = [_sp(f.g, 0x7af3ff, 2.2, 2.55, -.25, 0), _sp(f.g, 0x7af3ff, 2.2, -2.55, -.25, 0)]
		f.fans = OmCraft.parts(f.g, "om_fan")
		f.T = _target(f.hp, 2.2, 2.2)
	elif kind == "ship":
		f.T = _target(f.hp, 5.0, 4.0)
		f.hb = OmCraft.Hitboxes.new(f.T)
	# where it comes from: below (rel), off to a side of the heading
	var a := f.side
	var dist: float = o.get("dist", 40.0)
	var c := fr.fwd if fr != null else Vector3.BACK
	var rt := fr.right if fr != null else Vector3.RIGHT
	var from := c * (cos(a) * dist) + rt * (sin(a) * dist)
	from.y = o.get("y", -120.0)
	f.rel = from
	var pc := fr.pc if fr != null else Vector3.ZERO
	f.rel.x += pc.x
	f.rel.z += pc.z
	f.ang = atan2(f.rel.x - pc.x, f.rel.z - pc.z)
	f.dir = 1.0 if randf() < .5 else -1.0
	f.fire_t = _rr(1.2, 2.4)
	f.ph = _rr(0, 6)
	if fr != null:
		if kind == "wasp":
			audio.play_at("ffRam", _world(f.rel))
		if kind == "hornet" or kind == "mule":
			audio.play_at("ffDrone", _world(f.rel))
	foes.append(f)
	return f


## homing missile from rel position from; o = {speed, turn, dmg, arm_t, life, vel (rel start velocity), v0}
func missile(from: Vector3, o: Dictionary = {}) -> Msl:
	var m := Msl.new()
	m.rel = from
	m.vel = (o.get("vel", Vector3.UP) as Vector3).normalized() * float(o.get("v0", 14.0))
	m.speed = o.get("speed", 36.0)
	m.turn = o.get("turn", 1.5)
	m.dmg = o.get("dmg", 20.0)
	m.arm_t = o.get("arm_t", .35)
	m.life = o.get("life", 7.0)
	m.g = _copy("missile")
	m.flame = _sp(m.g, 0xffb050, 1.6, 0, -1, 0)
	m.T = _target(HP.missile, .55, 1.6)
	missiles.append(m)
	if fr != null:
		audio.play_at("ffMissile", _world(m.rel))
	return m


func _kill_missile(m: Msl, boom: bool) -> void:
	if m.gone:
		return
	m.gone = true
	_drop_target(m.T)
	m.g.queue_free()
	if boom:
		blast(_world(m.rel), 2.2, {"foe_dmg": 30.0, "sound": "boom"})


## the wreck of Tug 9 (rel): chunks flung out of the fireball, burning, falling faster than PROG (they come down past him: dodge them)
func wreck(at: Vector3) -> void:
	for k in 9:
		var c := ChunkC.new()
		c.g = _copy("chunk%d" % (k % 6))
		c.r = chunk_r[k % 6]
		var a := _rr(0, 6.3)
		var s := _rr(3, 9)
		c.rel = at + Vector3(_rr(-2, 2), _rr(-1, 1), _rr(-2, 2))
		c.vel = Vector3(cos(a) * s, _rr(-2, 4), sin(a) * s)
		c.w = Vector3(_rr(-3, 3), _rr(-3, 3), _rr(-3, 3))
		c.fall = _rr(11, 20)
		chunks.append(c)
	# the big piece: the hull, straight down past him
	var c := ChunkC.new()
	c.g = _copy("chunk0")
	c.g.scale = Vector3.ONE * 2.6
	c.r = chunk_r[0] * 2.6
	c.rel = at + Vector3(0, 4, 0)
	var pc := fr.pc if fr != null else Vector3.ZERO
	c.vel = Vector3(pc.x - at.x, 0.0, pc.z - at.z) * .25
	c.w = Vector3(.4, .2, .7)
	c.fall = 16.0
	c.big = true
	chunks.append(c)


## flak: a shell bursting somewhere around (world, stays put: it rushes up past him). near = it is meant to be close
func flak(near: bool = false) -> void:
	if fr == null:
		return
	var a := _rr(0, 6.3)
	var d := _rr(5, 10) if near else _rr(14, 45)
	var y := _rr(-14, -6) if near else _rr(-70, -18)
	var p := _world(Vector3(fr.pc.x + cos(a) * d, y, fr.pc.z + sin(a) * d))
	fire.emit(p.x, p.y, p.z, {"size": 4.5, "grow": .6, "life": .22, "col": 0xffe0a0, "alpha": 1.0, "fade": .02})
	for _i in 9:
		smoke.emit(p.x + _rr(-1.5, 1.5), p.y + _rr(-1.5, 1.5), p.z + _rr(-1.5, 1.5), {"vx": _rr(-2, 2), "vy": _rr(-2, 2), "vz": _rr(-2, 2), "size": _rr(3, 5), "grow": 1.2, "life": _rr(2.5, 4), "col": 0x141210, "alpha": .85, "drag": 1.5, "fade": .05})
	for _i in 8:
		fire.emit(p.x, p.y, p.z, {"vx": _rr(-14, 14), "vy": _rr(-14, 14), "vz": _rr(-14, 14), "size": .35, "grow": 0.0, "life": _rr(.3, .6), "col": 0xffc060, "alpha": 1.0, "drag": .5, "fade": .02})
	audio.play_at("ffFlak", p)
	if near and _world(fr.pc).distance_to(p) < 7.0:
		Game.combat.hurt_player(fr.P, 7.0, p.x, p.z, "melee")
		Game.fx.shake = maxf(Game.fx.shake, 1.0)


## an AA tracer stream climbing from the plant somewhere around him (visual)
func stream() -> void:
	if fr == null:
		return
	var a := _rr(0, 6.3)
	var d := _rr(20, 70)
	var base := _world(Vector3(fr.pc.x + cos(a) * d, -320.0, fr.pc.z + sin(a) * d))
	var dir := Vector3(_rr(-.25, .25), 1.0, _rr(-.25, .25)).normalized()
	for k in 7:
		tracers.append({"p": base - dir * (k * 9.0), "v": dir * 170.0, "life": 3.2})


func _aim_at(from: Vector3, lead: float = .5) -> Vector3:      # world direction from `from` to PROG's body, leading him a little
	var o := _world(fr.pc)
	return (o + fr.pv * (lead * from.distance_to(o) / 30.0) - from).normalized()


func _bolt_from(f: Foe, pw: Vector3, dir: Vector3, o: Dictionary) -> void:
	Game.combat.enemies.fire_from(f.T.id if f.T != null else 0, pw.x, pw.y, pw.z, dir.x, dir.y, dir.z, o)


## keep a circling foe in the half of the sky the camera sees (round the heading, +-lim): it turns back at the edges
func _arc(f: Foe, lim: float) -> void:
	var psi := atan2(fr.fwd.x, fr.fwd.z)
	var d := atan2(sin(f.ang - psi), cos(f.ang - psi))
	if absf(d) > lim:
		f.dir = -signf(d)
		f.ang = psi + signf(d) * lim


func _step_foe(f: Foe, dt: float) -> void:
	var pc := fr.pc
	f.t += dt
	var T := f.T
	if not f.dead and T != null and (T.dead or T.hp <= 0.0):
		_die(f)
	if f.dead:      # falls away, spinning, trailing smoke, then goes up
		f.dead_t += dt
		f.vel.y -= 22.0 * dt
		f.rel += f.vel * dt
		f.g.rotation.x += dt * 4.0
		f.g.rotation.z += dt * 6.0
		var pw := _world(f.rel)
		var is_ship := f.kind == "ship"
		if randf() < dt * 30.0:
			smoke.emit(pw.x, pw.y, pw.z, {"size": 5.0 if is_ship else 1.8, "grow": 2.0, "life": 2.5, "col": 0x1c1816, "alpha": .7})
			fire.emit(pw.x, pw.y, pw.z, {"size": 4.0 if is_ship else 1.5, "grow": .5, "life": .3, "col": 0xff8030, "alpha": .9})
		if f.dead_t > (5.0 if is_ship else (2.2 if f.kind == "mule" else 1.4)):
			blast(pw, 9.0 if is_ship else (5.0 if f.kind == "mule" else 2.5), {"sound": "boomBig" if is_ship or f.kind == "mule" else "boom"})
			f.gone = true
		return
	if f.st == "leave" and f.kind != "ship":      # breaking off: straight up and away (the plant does not shoot at its own pad)
		f.vel.y = minf(45.0, f.vel.y + 35.0 * dt)
		f.rel += f.vel * dt
		if f.rel.y > pc.y + 140.0:
			f.gone = true
		_sync_target(f)
		return
	if f.kind == "hornet":
		# rise to a slot on a ring round him, strafe along it; eye charges, a three-bolt burst
		if f.R_ < 0.0:
			f.R_ = _rr(12, 18)
			f.hy = _rr(-16, -5)
		f.ang += f.dir * (.32 + .12 * sin(f.t * .7 + f.ph)) * dt
		if randf() < dt * .15:
			f.dir *= -1.0
		_arc(f, 1.35)
		var tx := pc.x + sin(f.ang) * f.R_
		var tz := pc.z + cos(f.ang) * f.R_
		var ty := f.hy + sin(f.t * 1.3 + f.ph) * 1.2
		var k := 1.2 if f.st == "rise" else 3.2
		f.vel.x += ((tx - f.rel.x) * k * k - 2.0 * k * f.vel.x) * dt
		f.vel.z += ((tz - f.rel.z) * k * k - 2.0 * k * f.vel.z) * dt
		if f.st == "rise":
			f.vel.y = minf(32.0, (ty - f.rel.y) * 1.4 + 4.0)
			if f.rel.y > ty - 3.0:
				f.st = "hold"
		else:
			f.vel.y += ((ty - f.rel.y) * k * k - 2.0 * k * f.vel.y) * dt
		f.rel += f.vel * dt
		var yaw := atan2(pc.x - f.rel.x, pc.z - f.rel.z)
		var up := atan2(pc.y - f.rel.y, U.hyp(pc.x - f.rel.x, pc.z - f.rel.z))
		f.g.rotation = Vector3(-clampf(up, -.8, 1.2) + sin(f.t * 2.1 + f.ph) * .06, yaw, clampf(-f.vel.x * .03, -.4, .4))
		f.fire_t -= dt
		MsKit.opa(f.eye, .7)
		if f.st != "rise" and f.fire_t < .7:
			var u := 1.0 - maxf(0.0, f.fire_t) / .7
			f.eye.scale = Vector3.ONE * (1.1 + u * 1.4)
			MsKit.opa(f.eye, 1.0 if sin(f.t * (20.0 + u * 30.0)) > 0.0 else .4)
		else:
			f.eye.scale = Vector3.ONE * 1.1
		if f.st != "rise" and f.fire_t <= 0.0:
			f.burst += 1
			f.fire_t = .13 if f.burst < 3 else _rr(2.2, 3.4)
			if f.burst >= 3:
				f.burst = 0
			var pw := _world(f.rel) + Vector3(0, .1, 0)
			var d := (_aim_at(pw, .5) + Vector3(_rr(-.07, .07), _rr(-.07, .07), _rr(-.07, .07))).normalized()
			_bolt_from(f, pw + d * .8, d, {"kind": "bolt", "speed": 28.0, "dmg": 4.0, "r": .2})
		for j in f.jets:
			MsKit.opa(j, .55 + .35 * sin(f.t * 40.0 + j.get_instance_id()))
	elif f.kind == "wasp":
		# climbs at him weaving, then commits: a straight dive at where he is; contact = boom
		var to := pc - f.rel
		var d := to.length()
		to = to.normalized()
		if f.st == "rise" and d < 26.0:
			f.st = "dive"
			f.vel = to * 30.0
			audio.play_at("ffRam", _world(f.rel))
		if f.st == "rise":
			var w := Vector3(sin(f.t * 3.0 + f.ph), 0.0, cos(f.t * 2.3 + f.ph)) * 6.0
			f.vel = f.vel.lerp(to * 24.0 + w, minf(1.0, dt * 2.5))
		elif f.dive_end < 0.0 or f.t < f.dive_end:
			if f.dive_end < 0.0:
				f.dive_end = f.t + 2.2
			f.vel = f.vel.lerp(to * 30.0, minf(1.0, dt * .9))
		f.rel += f.vel * dt
		f.g.quaternion = Quaternion(Vector3.UP, f.vel.normalized())
		MsKit.opa(f.eye, 1.0 if sin(f.t * (40.0 if f.st == "dive" else 14.0)) > 0.0 else .2)
		var pw := _world(f.rel)
		if randf() < dt * 40.0:
			smoke.emit(pw.x, pw.y, pw.z, {"size": .9, "grow": 2.5, "life": 1.4, "col": 0x6a625c, "alpha": .45})
		if d < 1.7:
			if not fr.dodging:
				Game.combat.hurt_player(fr.P, 16.0, pw.x, pw.z, "melee")
			f.hp = 0.0
			T.dead = true
			_die(f, true)
		if f.dive_end >= 0.0 and f.t > f.dive_end + 1.5:
			_die(f, true)
	elif f.kind == "mule":
		# holds out in front and below, drifting side to side; a pair of missiles every few seconds
		var sw := sin(f.t * .4 + f.ph) * 9.0 + f.side * 6.0
		var tx := pc.x + fr.fwd.x * 22.0 + fr.right.x * sw
		var tz := pc.z + fr.fwd.z * 22.0 + fr.right.z * sw
		var ty := -14.0 + sin(f.t * .6) * 2.0
		var k := .9 if f.st == "rise" else 1.8
		f.vel.x += ((tx - f.rel.x) * k * k - 2.0 * k * f.vel.x) * dt
		f.vel.z += ((tz - f.rel.z) * k * k - 2.0 * k * f.vel.z) * dt
		if f.st == "rise":
			f.vel.y = minf(28.0, (ty - f.rel.y) * 1.2 + 3.0)
			if f.rel.y > ty - 3.0:
				f.st = "hold"
		else:
			f.vel.y += ((ty - f.rel.y) * k * k - 2.0 * k * f.vel.y) * dt
		f.rel += f.vel * dt
		f.g.rotation = Vector3(-clampf(atan2(pc.y - f.rel.y, U.hyp(pc.x - f.rel.x, pc.z - f.rel.z)), 0.0, 1.0) * .8, atan2(pc.x - f.rel.x, pc.z - f.rel.z), clampf(-f.vel.x * .02, -.3, .3))
		for c in f.fans:
			c.rotation.y += dt * 40.0
		f.fire_t -= dt
		if f.st != "rise" and f.fire_t <= 0.0:
			f.fire_t = _rr(4.8, 6)
			for sx: float in [-1.0, 1.0]:
				var p := f.g.global_transform * Vector3(sx * 1.45, -.5, 1.6) - fr.F
				missile(p, {"vel": (pc - p).normalized() + Vector3(sx * .4, .5, 0), "v0": 10.0, "speed": 30.0, "turn": 1.4, "dmg": 18.0})
	elif f.kind == "ship":
		# REPO-MAN: climbs out from below, then orbits him, nose on him; chin cannon bursts and missile salvos. Leaves at leave_at if still flying
		var s := f.ship
		s.update(dt)
		if f.leave_at != 0.0 and fr.t > f.leave_at and f.st != "leave":
			f.st = "leave"
			Game.hud.toast("THE GUNSHIP IS PULLING UP", 2.0)
		if f.st == "leave":
			f.vel.y = minf(60.0, f.vel.y + 30.0 * dt)
			f.rel += f.vel * dt
			if f.rel.y > 160.0:
				f.gone = true
		else:
			f.ang += .3 * f.dir * dt
			_arc(f, 1.25)
			var R := 44.0 if f.st == "rise" else 30.0 + sin(f.t * .3) * 4.0      # out in front and below: in the view, firing up at him
			var ty := -26.0 + sin(f.t * .5) * 6.0
			var tx := pc.x + sin(f.ang) * R
			var tz := pc.z + cos(f.ang) * R
			var k := .8 if f.st == "rise" else 1.3
			f.vel.x += ((tx - f.rel.x) * k * k - 2.0 * k * f.vel.x) * dt
			f.vel.z += ((tz - f.rel.z) * k * k - 2.0 * k * f.vel.z) * dt
			if f.st == "rise":
				f.vel.y = minf(40.0, (ty - f.rel.y) * 1.1 + 6.0)
				if f.rel.y > ty - 4.0:
					f.st = "fight"
					Game.hud.toast("GUNSHIP!", 1.6)
			else:
				f.vel.y += ((ty - f.rel.y) * k * k - 2.0 * k * f.vel.y) * dt
			f.rel += f.vel * dt
			if f.st == "fight":
				f.fire_t -= dt
				f.salvo_t -= dt
				if f.fire_t <= 0.0:
					f.burst += 1
					f.fire_t = .12 if f.burst < 7 else 3.0
					if f.burst >= 7:
						f.burst = 0
					var pw: Vector3 = s.gun.global_transform * Vector3(0, -.1, 2.4)
					var d := _aim_at(pw, .4)
					d.x += _rr(-.05, .05)
					d.z += _rr(-.05, .05)
					d = d.normalized()
					_bolt_from(f, pw, d, {"kind": "plasma", "speed": 40.0, "dmg": 6.0, "r": .22})
					Game.fx.tracer(pw, pw + d * 3.0, .08, .05, 0xa0ffb0)
				if f.salvo_t <= 0.0:
					f.salvo_t = _rr(6.5, 8)
					for i in 3:
						var side := 3.2 if i % 2 != 0 else -3.2
						_salvo(f, side, i * .28)
		var yaw := atan2(pc.x - f.rel.x, pc.z - f.rel.z)
		var up := atan2(pc.y - f.rel.y, U.hyp(pc.x - f.rel.x, pc.z - f.rel.z))
		f.ng += ((-.5 if f.st == "leave" else -clampf(up, 0.0, 1.1) * .75) - f.ng) * minf(1.0, dt * 2.0)      # nose up at him: the chin gun points where it shoots
		f.g.rotation = Vector3(f.ng, yaw, -.22)
	_sync_target(f)


var _timers: Array = []


func _salvo(f: Foe, side: float, delay: float) -> void:
	_timers.append({"t": clock + delay, "f": f, "side": side})


func _die(f: Foe, boom: bool = false) -> void:
	if f.dead:
		return
	f.dead = true
	_drop_target(f.T, f.hb)
	var pw := _world(f.rel)
	if f.kind == "wasp" or boom:
		blast(pw, 2.6 if f.kind == "wasp" else 2.0, {"foe_dmg": 70.0 if f.kind == "wasp" else 0.0, "sound": "boom"})
		f.gone = true
		return
	blast(pw, 5.0 if f.kind == "ship" else (3.2 if f.kind == "mule" else 1.6), {"sound": "boomBig" if f.kind == "ship" else "boom"})
	f.vel = Vector3(_rr(-4, 4), -2.0 if f.kind == "ship" else 2.0, _rr(-4, 4))
	if f.kind == "ship":
		Game.hud.toast("GUNSHIP DOWN", 2.0)


func _step_missile(m: Msl, dt: float) -> void:
	m.t += dt
	if m.T.dead or m.T.hp <= 0.0:
		_kill_missile(m, true)
		return
	var pc := fr.pc
	var to := pc - m.rel
	var d := to.length()
	to = to.normalized()
	var sp := minf(m.speed, m.vel.length() + 40.0 * dt)
	var v := m.vel.normalized()
	if m.t > m.arm_t and not m.lost:      # home: turn toward him at a limited rate; a hard dodge past it breaks the lock
		var ang := v.angle_to(to)
		if ang > 1.9 and d < 18.0:
			m.lost = true
		elif ang > 1e-3:
			v = v.lerp(to, minf(1.0, m.turn * dt / ang)).normalized()
	m.vel = v * sp
	m.rel += m.vel * dt
	m.closing = d / maxf(1.0, sp) if not m.lost and m.t > m.arm_t and v.dot(to) > .5 else 99.0      # seconds to impact (HUD lock warning)
	m.g.quaternion = Quaternion(Vector3.UP, v)
	var pw := _world(m.rel)
	m.g.position = pw
	MsKit.opa(m.flame, .7 + .3 * randf())
	m.flame.scale = Vector3.ONE * (1.2 + randf() * .8)
	m.smoke_t -= dt
	if m.smoke_t <= 0.0:
		m.smoke_t = .025
		var q := pw - v * .8
		smoke.emit(q.x, q.y, q.z, {"size": .8, "grow": 3.5, "life": _rr(2, 3), "col": 0xb8b0a8, "alpha": .5, "drag": .6})
		fire.emit(q.x, q.y, q.z, {"size": .9, "grow": -.5, "life": .12, "col": 0xffa040, "alpha": .8})
	m.T.x = pw.x
	m.T.bx = pw.x
	m.T.z = pw.z
	m.T.bz = pw.z
	m.T.y = pw.y - .8
	m.T.kx = 0.0
	m.T.kz = 0.0
	if d < 2.4 and not m.lost:
		if not fr.dodging:
			Game.combat.hurt_player(fr.P, m.dmg, pw.x, pw.z, "melee")
		_kill_missile(m, false)
		blast(pw, 2.6, {"sound": "boom"})
		Game.fx.shake = maxf(Game.fx.shake, 1.4)
	elif m.t > m.life:
		_kill_missile(m, true)


func _step_chunk(c: ChunkC, dt: float) -> void:
	c.t += dt
	c.vel.y += (-c.fall - c.vel.y) * minf(1.0, dt * 1.2)
	var dr := exp(-dt * .4)
	c.vel.x *= dr
	c.vel.z *= dr
	c.rel += c.vel * dt
	c.g.rotation += c.w * dt
	var pw := _world(c.rel)
	c.g.position = pw
	if randf() < dt * (50.0 if c.big else 22.0):
		fire.emit(pw.x + _rr(-.5, .5), pw.y, pw.z + _rr(-.5, .5), {"size": c.r * _rr(1, 1.8), "grow": .4, "life": _rr(.2, .4), "col": 0xff7a28, "alpha": .9})
		smoke.emit(pw.x, pw.y, pw.z, {"size": c.r * 1.6, "grow": 2.0, "life": _rr(2.5, 4), "col": 0x161210, "alpha": .7, "drag": .8})
	if not c.hit and fr.P != null and not fr.P.dead and c.rel.distance_to(fr.pc) < c.r + .8:
		c.hit = true
		if not fr.dodging:
			Game.combat.hurt_player(fr.P, 22.0 if c.big else 12.0, pw.x, pw.z, "melee")
		Game.fx.shake = maxf(Game.fx.shake, 1.2)
	if c.rel.y < fr.pc.y - 260.0:
		c.gone = true
		c.g.queue_free()


## foes and missiles you can lock on to: [{x, y, z (world), r, T, kind}]
func lockables() -> Array:
	_lock.clear()
	for f in foes:
		if not f.dead and f.T != null and f.st != "leave":
			var v := _world(f.rel)
			_lock.append({"x": v.x, "y": v.y, "z": v.z, "r": f.T.r, "T": f.T, "kind": f.kind})
	for m in missiles:
		if not m.gone:
			_lock.append({"x": m.g.position.x, "y": m.g.position.y, "z": m.g.position.z, "r": .6, "T": m.T, "kind": "missile"})
	return _lock


## missiles homing on him now, nearest first
func threats() -> Array[Msl]:
	var out: Array[Msl] = []
	for m in missiles:
		if not m.gone and m.closing < 4.0:
			out.append(m)
	out.sort_custom(func(a: Msl, c: Msl) -> bool: return a.closing < c.closing)
	return out


func update(dt: float, frame: Frame) -> void:
	fr = frame
	clock += dt
	for i in range(_timers.size() - 1, -1, -1):
		var q: Dictionary = _timers[i]
		if clock >= float(q.t):
			_timers.remove_at(i)
			var f: Foe = q.f
			if not (f.dead or f.gone):
				var p: Vector3 = f.g.global_transform * Vector3(q.side, -.7, 2.6) - fr.F
				missile(p, {"vel": (fr.pc - p).normalized() + Vector3(_rr(-.6, .6), .8, _rr(-.6, .6)), "v0": 12.0, "speed": 34.0, "turn": 1.25, "dmg": 20.0})
	for f in foes:
		if not f.gone:
			_step_foe(f, dt)
			f.g.position = _world(f.rel)
	for i in range(foes.size() - 1, -1, -1):
		if foes[i].gone:
			var f := foes[i]
			_drop_target(f.T, f.hb)
			if f.ship != null:
				f.ship.free_model()
			else:
				f.g.queue_free()
			foes.remove_at(i)
	for m in missiles:
		if not m.gone:
			_step_missile(m, dt)
	for i in range(missiles.size() - 1, -1, -1):
		if missiles[i].gone:
			missiles.remove_at(i)
	for c in chunks:
		if not c.gone:
			_step_chunk(c, dt)
	for i in range(chunks.size() - 1, -1, -1):
		if chunks[i].gone:
			chunks.remove_at(i)
	var n := 0
	for i in range(tracers.size() - 1, -1, -1):
		var t: Dictionary = tracers[i]
		t.life = float(t.life) - dt
		t.p = (t.p as Vector3) + (t.v as Vector3) * dt
		if float(t.life) <= 0.0:
			tracers.remove_at(i)
	for t: Dictionary in tracers:
		if n >= 96:
			break
		var v: Vector3 = (t.v as Vector3).normalized()
		var bq := Basis(Quaternion(Vector3.BACK, v)).scaled_local(Vector3(.22, .22, 7.0))
		tr_mm.set_instance_transform(n, Transform3D(bq, t.p))
		n += 1
	tr_mm.visible_instance_count = n
	smoke.update(dt)
	fire.update(dt)


## off: everything gone (the targets out of the combat list too); puffs: false keeps the smoke already in the air
func clear(puffs: bool = true) -> void:
	for f in foes:
		f.gone = true
		_drop_target(f.T, f.hb)
		if f.ship != null:
			f.ship.free_model()
		else:
			f.g.queue_free()
	foes.clear()
	for m in missiles:
		_drop_target(m.T)
		m.g.queue_free()
	missiles.clear()
	for c in chunks:
		c.g.queue_free()
	chunks.clear()
	tracers.clear()
	_timers.clear()
	tr_mm.visible_instance_count = 0
	if puffs:
		smoke.clear()
		fire.clear()
