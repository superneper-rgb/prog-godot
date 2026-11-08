class_name GristleBrute
extends Robot
## GRISTLE BRUTE (JS enemies/gristle-brute.js): a shield carrier with a grinding chest bellow.
##   Shield   fused torsos holding a huge rib-cage carapace of bone up front. Hits from the front are mostly BLOCKED (sparks off the carapace).
##   Back     it turns slowly: circle-strafe round it and shoot its exposed back (the glowing spine takes extra damage).
##   Bellows  a BELLOWS BEAST blast knocks the carapace wide open for a few seconds: then it takes full damage from anywhere.
##   Charge   it roars and plants its feet (the carapace rises, its eyes go red), then charges in a straight line: a big shove (off narrow ledges!). It stops at ledge edges. If it misses, it skids and is wide open from behind for a moment.
##   Slam     up close it brings the carapace down on you.
## The JS swaps its numbers into the shared AI table around each update; every brute here holds its own table, kept current in update().

const HP := 320.0
const SPEED := 2.4
const TURN := 2.0
const BLOCK := 0.85
const ARC := 1.6
const BACK_MULT := 1.5
const EXPOSED := 3.4
const CHARGE_WIND := 0.9
const CHARGE_SPEED := 11.0
const CHARGE_DIST := 8.0
const CHARGE_DMG := 18.0
const CHARGE_PUSH := 14.0
const CHARGE_CD := 3.2
const SKID := 1.4
const SLAM_WIND := 0.7
const SLAM_DMG := 20.0
const SLAM_REACH := 2.6
const B_R := 1.0
const B_H := 2.7

## JS this.ch
class Charge:
	var d := 0.0
	var hit := false
	var missed := false

var brute := true
var exposed_t := 0.0
var charge_cd := 1.5
var ch: Charge = null
var block_t := 0.0


func _init(w: World, p_id: int, p_x: float, p_z: float, p_y: float, o: Dictionary = {}) -> void:
	ai = AiTable.new()
	ai.r = B_R
	ai.h = B_H
	ai.walk = SPEED * 0.7
	ai.run = SPEED
	ai.accel = 6.0
	ai.alert_delay = 0.3
	ai.reach = SLAM_REACH
	ai.m_wind = SLAM_WIND
	ai.m_act = 0.3
	ai.m_hit = 0.15
	ai.m_rec = 0.9
	ai.m_dmg = SLAM_DMG
	ai.s_wind = CHARGE_WIND
	ai.s_act = 99.0
	ai.flinch = 0.1
	ai.stagger_immune = 1.2
	ai.poise_max = 260.0
	super._init(w, p_id, p_x, p_z, p_y, o)
	meat = true
	heavy = true
	name = "GRISTLE BRUTE"
	bark_set = {}
	speech = false
	mute = true
	voice = 0.45 + randf() * 0.1
	r = B_R
	h = B_H
	max = HP
	hp = HP


func reset(first: bool) -> void:
	super.reset(first)
	exposed_t = 0.0
	charge_cd = 1.5
	ch = null
	block_t = 0.0
	shot_cd = 1e9


func _face(dt: float, ang: float, _rate: float = 0.0) -> void:
	var k := 0.5 if exposed_t > 0.0 else 1.0
	yaw += clampf(U.wrap_angle(ang - yaw), -TURN * k * dt, TURN * k * dt)


func hurt(amount: float, from: Variant, kb: float, pt: Variant, kill: bool) -> void:
	var rel := absf(U.wrap_angle(atan2(from.x - x, from.z - z) - yaw))
	var w: Variant = E.c.weapon if E != null and E.c != null else null
	var bellows: bool = w != null and w.get(&"special") == "bellows" and kb >= 6.0
	if bellows and not dead:
		exposed_t = EXPOSED
		if E != null:
			E.push({"t": "ring_hit", "x": x, "y": y + 1.5, "z": z})
	if not bellows and exposed_t <= 0.0 and rel < ARC:      # BLOCKED by the carapace
		var back := amount * BLOCK
		hp += back
		amount -= back
		kb *= 0.15
		block_t = 0.25
		if kill and hp > 0.0:
			kill = false
			dead = false
		var s := sin(yaw)
		var c := cos(yaw)
		if E != null:
			E.push({"t": "bolt_hit", "x": x + s * 1.1, "y": y + 1.5, "z": z + c * 1.1, "kind": "world", "bk": "ring", "nx": s, "ny": 0.2, "nz": c})
	elif rel > PI - 1.3 or exposed_t > 0.0:                 # the soft back
		var extra := amount * (BACK_MULT - 1.0)
		hp -= extra
		amount += extra
		if not kill and hp <= 0.0:
			kill = true
			dead = true
	super.hurt(amount, from, kb, pt, kill)


func update(dt: float, en: Enemies, P: Player) -> void:
	E = en
	exposed_t = maxf(0.0, exposed_t - dt)
	charge_cd -= dt
	block_t = maxf(0.0, block_t - dt)
	shot_cd = 1e9
	if state != &"dead" and P != null and not P.dead and (state == &"idle" or state == &"return" or state == &"search"):      # JS aggro
		known = Known.at(P.x, P.z)
		seen_t = 0.0
		alert_why = "spawn"
		set_(&"pursue")
	ai.s_rec = SKID if ch != null and ch.missed else 0.7
	ai.stagger = 1.2 if exposed_t > 0.0 else 0.6
	super.update(dt, en, P)


func _pursue(dt: float, P: Player, dx: float, dz: float, dist: float, sees: bool) -> void:
	known = Known.at(P.x, P.z)
	seen_t = 0.0
	var err := _face_err(P.x, P.z)
	if not P.dead and sees:
		if dist <= SLAM_REACH + 0.3 and err < 0.5 and E.slot_free(&"melee", self):
			_begin(&"melee", dist)
			return
		if dist > 3.6 and dist < 12.0 and err < 0.3 and charge_cd <= 0.0:
			_begin(&"charge", dist)
			return
	_go(dt, _steer(P.x, P.z), 0.0 if dist < 2.2 else ai.run, dist < 2.2)
	_face(dt, atan2(dx, dz))


func _begin(kind: StringName, dist: float) -> void:
	if kind != &"charge":
		super._begin(kind, dist)
		return
	atk = &"charge"
	slot = &""
	a_u = 0.0
	ch = null
	set_(&"windup")
	wob = 0.0
	E.push({"t": "robot_atk", "id": id, "kind": "slam", "ph": "windup", "x": x, "y": y, "z": z})
	E.barks.say(self, "alert")


func _attack(dt: float, P: Player, dx: float, dz: float, dist: float) -> void:
	if atk != &"charge":
		super._attack(dt, P, dx, dz, dist)
		return
	if ch == null:
		ch = Charge.new()
		charge_cd = CHARGE_CD
		E.barks.say(self, "shoot")
	var s := sin(yaw)
	var c := cos(yaw)
	var step := CHARGE_SPEED * dt
	var nx := x + s * step
	var nz := z + c * step
	var ground := world.ground_height(nx + s * 0.8, nz + c * 0.8, B_R * 0.6, y + 0.5)
	var stop := ch.d >= CHARGE_DIST or not _free(nx, nz) or ground < y - 0.6      # walls and ledge edges stop it
	if not stop:
		x = nx
		z = nz
		ch.d += step
		lvz = CHARGE_SPEED
		if ground > -INF:
			y = ground
	if not ch.hit and not P.dead and U.hyp(P.x - x, P.z - z) < B_R + 0.36 + 0.45 and absf(P.y - y) < 1.6:
		ch.hit = true
		stop = true
		if E.c.hurt_player(P, CHARGE_DMG, x, z, "melee"):
			P.ix += s * CHARGE_PUSH
			P.iz += c * CHARGE_PUSH
			P.vy = maxf(P.vy, 5.5)
			P.grounded = false
			P.mode = &"normal"
			P.ledge = null
		E.push({"t": "robot_atk", "id": id, "kind": "melee", "ph": "hit", "x": x + s * 1.2, "y": y + 1.2, "z": z + c * 1.2})
	if stop:
		if not ch.hit:
			ch.missed = true
			exposed_t = maxf(exposed_t, SKID)
			E.push({"t": "robot_atk", "id": id, "kind": "melee", "ph": "miss", "x": x, "y": y, "z": z})
		lvz = 0.0
		set_(&"recover")
