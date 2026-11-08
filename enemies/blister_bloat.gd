class_name BlisterBloat
extends Robot
## BLISTERBLOAT (JS enemies/blister-bloat.js): a floating spore sac. "...SWELLING..."
##   Drifts  a bloated, blistered sac that floats towards you (slowly), bobbing; the breath of the spire pushes it about.
##   Bursts  close to you it swells for 0.7 s (it hisses and its blisters bulge), then pops into a green SPORE CLOUD: a little damage on the pop, then the cloud slows you and stings while you stand in it, for a few seconds.
##   Killing it also pops it, where it is. So shoot it at range, never up close. Very fragile.

const HP := 30.0
const SPEED := 1.8
const CLIMB := 1.0
const TRIGGER := 2.6
const FUSE := 0.7
const BURST_DMG := 8.0
const CLOUD_R := 3.2
const CLOUD_T := 4.0
const CLOUD_DPS := 6.0
const SLOW := 0.5
const ABOVE := 1.2
const N_R := 0.65
const N_H := 1.3

const BLOAT_BARKS := {
	"alert": ["*squelch*", "*gurgle*", "*wet breathing*"], "shoot": [""], "pain": ["*hiss*", "*weeping*"], "die": ["*POP*"], "summon": [""], "mind": [""],
}

var floater := true
var ty := 0.0
var has_cloud := false
var cloud := Vector3.ZERO
var cloud_t := 0.0
var burst := false
var tick_t := 0.0


func _init(w: World, p_id: int, p_x: float, p_z: float, p_y: float, o: Dictionary = {}) -> void:
	ai = AiTable.new()
	ai.r = N_R
	ai.h = N_H
	ai.walk = SPEED * 0.6
	ai.run = SPEED
	ai.accel = 3.0
	ai.alert_delay = 0.3
	ai.s_wind = FUSE
	ai.s_act = 0.05
	ai.s_rec = 0.3
	ai.flinch = 0.1
	ai.flinch_cd = 0.2
	ai.stagger = 0.3
	ai.stagger_immune = 0.5
	ai.poise_max = 999.0
	super._init(w, p_id, p_x, p_z, p_y, o)
	meat = true
	follower = true
	name = "BLISTERBLOAT"
	bark_set = BLOAT_BARKS
	mute = true
	voice = 1.8
	r = N_R
	h = N_H
	max = HP
	hp = HP
	ty = p_y
	corpse_t = CLOUD_T + 1.2


func reset(first: bool) -> void:
	super.reset(first)
	has_cloud = false
	burst = false
	ty = hy
	tick_t = 0.0
	shot_cd = 1e9


func update(dt: float, en: Enemies, P: Player) -> void:
	E = en
	shot_cd = 1e9
	if state != &"dead" and P != null and not P.dead and (state == &"idle" or state == &"return" or state == &"search"):      # JS aggro
		known = Known.at(P.x, P.z)
		seen_t = 0.0
		alert_why = "spawn"
		set_(&"pursue")
	if has_cloud:
		_cloud(dt, P)
	super.update(dt, en, P)


## floating: no ground snapping, drifts round solids, climbs / sinks towards its target height
func _go(dt: float, ang: float, speed: float, still: bool) -> void:
	var W := world
	var k := minf(1.0, ai.accel * dt)
	var tx := 0.0 if still else sin(ang) * speed
	var tz := 0.0 if still else cos(ang) * speed
	vx += (tx - vx) * k
	vz += (tz - vz) * k
	kvx *= exp(-2.5 * dt)
	kvz *= exp(-2.5 * dt)
	var mx := (vx + kvx) * dt
	var mz := (vz + kvz) * dt
	var cy := y + N_H * 0.5
	if not W.point_solid(x + mx + signf(mx) * N_R, cy, z):
		x += mx
	else:
		vx *= -0.3
		kvx *= -0.3
	if not W.point_solid(x, cy, z + mz + signf(mz) * N_R):
		z += mz
	else:
		vz *= -0.3
		kvz *= -0.3
	var dy := clampf(ty - y, -CLIMB * dt, CLIMB * dt)
	if not W.point_solid(x, cy + dy + signf(dy) * 0.7, z):
		y += dy
	var c := cos(yaw)
	var s := sin(yaw)
	var wx := vx + kvx
	var wz := vz + kvz
	lvz = wx * s + wz * c
	lvx = wx * c - wz * s


func _pursue(dt: float, P: Player, dx: float, dz: float, dist: float, _sees: bool) -> void:
	known = Known.at(P.x, P.z)
	seen_t = 0.0
	ty = clampf(P.y + ABOVE, hy - 6.0, hy + 4.0)
	var dv := P.y + 1.0 - (y + N_H * 0.5)
	var d3 := sqrt(dx * dx + dz * dz + dv * dv)
	_face(dt, atan2(dx, dz), 3.0)
	if not P.dead and d3 < TRIGGER:
		_begin(&"burst", dist)
		return
	_go(dt, atan2(dx, dz), SPEED, dist < 1.0)


func _begin(kind: StringName, _dist: float) -> void:
	atk = kind
	slot = &""
	a_u = 0.0
	shot_done = false
	set_(&"windup")
	wob = 0.0
	E.push({"t": "robot_atk", "id": id, "kind": "sauce", "ph": "windup", "x": x, "y": y, "z": z})


func _attack(_dt: float, _P: Player, _dx: float, _dz: float, _dist: float) -> void:
	if not shot_done:
		shot_done = true
		hp = 0.0
		dead = true
		_die()


func _die() -> void:
	super._die()
	respawn_t = 1e9
	if not burst:
		_burst()


func _burst() -> void:
	var P: Player = E.P if E != null else null
	burst = true
	has_cloud = true
	cloud = Vector3(x, y + N_H * 0.5, z)
	cloud_t = CLOUD_T
	if E != null:
		E.push({"t": "summon", "x": x, "y": y + 0.6, "z": z})
		E.push({"t": "bolt_hit", "x": x, "y": y + 0.6, "z": z, "kind": "world", "bk": "bile", "nx": 0.0, "ny": 1.0, "nz": 0.0})
	if P != null and not P.dead and Vector3(P.x - x, P.y + 1.0 - cloud.y, P.z - z).length() < CLOUD_R * 0.8:
		E.c.hurt_player(P, BURST_DMG, x, z, "bolt")
		P.slow_t = maxf(P.slow_t, 1.0)
		P.slow_mul = SLOW


func _cloud(dt: float, P: Player) -> void:
	cloud_t -= dt
	if cloud_t <= 0.0:
		has_cloud = false
		return
	if P == null or P.dead:
		return
	if U.hyp(P.x - cloud.x, P.z - cloud.z) < CLOUD_R and absf(P.y + 1.0 - cloud.y) < CLOUD_R:
		P.slow_t = maxf(P.slow_t, 0.35)
		P.slow_mul = minf(P.slow_mul, SLOW)
		tick_t -= dt
		if tick_t <= 0.0:
			tick_t = 0.5
			E.c.hurt_player(P, CLOUD_DPS * 0.5, P.x, P.z, "bolt")
