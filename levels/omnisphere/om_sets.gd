class_name OmSets
extends RefCounted
## OMNISPHERE set pieces of the opening (JS setpieces.js): shootable fuel cells that blow (and chain), pylon 4 blowing its transformer and sinking into the magma, and the FOINT-N-SHOOT kiosk on the pad. Moving solids go through the Meat Spire's mover glue (carry, push-out); `mechs` is shared with the tram. (The parked tug and its flyby are retired in the JS too: PROG arrives by air.)

const P4 := [-112.0, 16.0, -46.0]
const KIOSK := [7.0, 6.0, 3.6]


class Tank:
	var T: OmProp
	var m: Node3D
	var s: World.Solid
	var gone := false
	var home := Vector3.ZERO


var lv: ExportedLevel
var audio: OmAudio
var mechs: SpireMechs
var clock := 0.0
var timers: Array = []
var tanks: Array[Tank] = []
var armed := false
var kiosk_cd := 0.0
var p4_g: Node3D
var p4_s: World.Solid
var p4_state := "up"
var p4_t := 0.0


func _init(p_lv: ExportedLevel, p_audio: OmAudio, TANKS: Array) -> void:
	lv = p_lv
	audio = p_audio
	mechs = SpireMechs.new(lv, func(_e: Dictionary) -> void: pass, func(_id: String, _x: float, _y: float, _z: float, _o: Dictionary) -> void: pass, func(P: Player, amt: float, sx: float, sz: float, kind: String) -> bool: return Game.combat.hurt_player(P, amt, sx, sz, kind))
	var sol := VhKit.solids(lv.world)
	for i in TANKS.size():
		var q: Array = TANKS[i]
		var t := Tank.new()
		var k := OmSecurity.key(q[0], q[2])
		t.m = VhKit.one(lv, "om-tank-" + k)
		t.s = (sol.get("tank-" + k, [null]) as Array)[0]
		t.home = Vector3(q[0], q[1], q[2])
		t.T = OmProp.make(9000 + i, q[0], q[2], q[1], 0.7, 1.6, 25.0)
		t.T.dead = false
		tanks.append(t)
	p4_g = VhKit.one(lv, "om-p4")
	p4_s = (sol.get("p4", [null]) as Array)[0]
	mechs.add_custom([p4_s], true, _p4_step)


func _p4_step(_t: float, dt: float, _P: Player) -> void:
	if p4_state != "sink":
		return
	p4_t += dt
	var u := minf(1.0, p4_t / 4.5)
	var top: float = P4[1]
	var drop := u * u * (top + 4.0)
	p4_g.position.y = top - drop
	p4_g.rotation = Vector3(u * 0.3, 0.0, u * 0.7)
	p4_s.set_span(top - drop - 1.0, top - drop)
	if u >= 1.0:
		p4_s.set_off(true)
		p4_state = "gone"
		p4_g.visible = false


func after(s: float, fn: Callable) -> void:
	timers.append({"t": clock + s, "fn": fn})


## an explosion with damage: player and enemies within r take up to dmg (falloff), shake scales with size
func boom(x: float, y: float, z: float, r: float = 4.0, dmg: float = 60.0, o: Dictionary = {}) -> void:
	var p := Vector3(x, y, z)
	var C: Combat = Game.combat
	var P: Player = Game.player
	if Game.fx != null:
		Game.fx.explosion(p, r * 0.9)
		Game.fx.shake = maxf(Game.fx.shake, minf(2.2, r / 3.0))
	audio.play_at("boomBig" if r > 5.0 else "boom", p)
	if o.get("harmless", false):
		return
	if P != null and not P.dead:
		var d := p.distance_to(Vector3(P.x, P.y + 1.0, P.z))
		if d < r:
			C.hurt_player(P, dmg * (1.0 - d / r * 0.6), x, z, "melee")
			P.vy = maxf(P.vy, 6.0)
			P.grounded = false
	if C != null:
		for e: Robot in C.enemies.robots:
			if e.dead:
				continue
			var d := p.distance_to(Vector3(e.x, e.y + 1.0, e.z))
			if d < r * 1.2:
				C.damage(e, dmg * 1.6 * (1.0 - d / (r * 1.2) * 0.5), {"x": x, "z": z}, 6.0)
	for t in tanks:
		if not t.T.dead and U.hyp(t.T.x - x, t.T.z - z) < r * 1.1 and t.T != o.get("self"):
			t.T.hp = 0.0


func _arm_tanks() -> void:
	for t in tanks:
		t.T.dead = false
		t.T.hp = t.T.max
		t.gone = false
		t.m.visible = true
		if t.s != null:
			t.s.set_off(false)
		OmProp.arm(t.T)


func blow_p4() -> void:
	if p4_state != "up":
		return
	p4_state = "blowing"
	audio.pa("pylon")
	var cx: float = P4[0]
	var top: float = P4[1]
	var cz: float = P4[2]
	boom(cx + 1.2, top + 1.5, cz - 1.6, 5.0, 40.0)
	after(0.45, func() -> void: boom(cx - 1.5, top - 2.0, cz + 1.0, 4.0, 0.0, {"harmless": true}))
	after(0.9, func() -> void:
		boom(cx, top - 6.0, cz, 7.0, 0.0, {"harmless": true})
		p4_state = "sink"
		p4_t = 0.0
		audio.play_at("groan", Vector3(cx, top, cz)))


func _reset_p4() -> void:
	p4_state = "up"
	p4_t = 0.0
	p4_g.visible = true
	p4_g.position = Vector3(P4[0], P4[1], P4[2])
	p4_g.rotation = Vector3.ZERO
	p4_s.set_off(false)
	p4_s.set_span(float(P4[1]) - 1.0, P4[1])


# FOINT-N-SHOOT kiosk on the pad: walk up to it and it refills you (and bills you)
func _kiosk(dt: float, P: Player, C: Combat) -> void:
	kiosk_cd = maxf(0.0, kiosk_cd - dt)
	if P == null or C == null or kiosk_cd > 0.0:
		return
	if U.hyp(P.x - float(KIOSK[0]), P.z - float(KIOSK[2])) < 2.2 and absf(P.y - float(KIOSK[1])) < 1.0:
		kiosk_cd = 25.0
		for i: int in C.owned:
			var w: Variant = Weapons.WEAPONS[i]
			if w != null:
				C.ammo[i] = w.mag_size
				C.reserve[i] = w.max - w.mag_size
		Game.hud.toast("FOINT-N-SHOOT: AMMO RESTOCKED  -  CHARGED TO YOUR ACCOUNT")
		audio.play_at("kiosk", Vector3(KIOSK[0], KIOSK[1], KIOSK[2]))


## call on every (re)start of a stage: puts the pieces back into the state that stage expects
func reset(stage: String, objective: int = 0, retry: bool = false) -> void:
	timers.clear()      # (a queued blow_p4 step must not land on the restored pylon)
	if retry or not armed:
		armed = true
		_arm_tanks()
	var late := stage == "gamma" or (stage == "cableway" and objective >= 3)
	if late:
		p4_state = "gone"
		p4_s.set_off(true)
		p4_g.visible = false
	else:
		_reset_p4()


func update(dt: float, P: Player, C: Combat) -> void:
	clock += dt
	mechs.update(clock, dt, P)
	for i in range(timers.size() - 1, -1, -1):
		if clock >= float(timers[i].t):
			var f: Callable = timers[i].fn
			timers.remove_at(i)
			f.call()
	# fuel cells
	for t in tanks:
		if not t.gone and not t.T.dead and t.T.hp <= 0.0:
			t.T.dead = true
	for t in tanks:
		if t.T.dead and not t.gone:
			t.gone = true
			t.m.visible = false
			if t.s != null:
				t.s.set_off(true)
			var h := t.home
			var self_t := t.T
			after(0.08, func() -> void: boom(h.x, h.y + 0.8, h.z, 5.0, 70.0, {"self": self_t}))
	_kiosk(dt, P, C)
