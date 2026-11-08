class_name MawLedge
extends Robot
## MAWLEDGE (JS enemies/maw-ledge.js): a ledge that eats you, with a sticky, snapping jaw.
##   Disguise  it looks like one more fleshy ledge on the route. A few tells: it is a little too purple, an eye in its rim blinks now and then, a tongue tip peeks out of its lip.
##   Bite      stand on it and its lips peel back along the rim, its teeth come up and it shudders (0.55 s: jump off!), then it CHOMPS: damage, and it spits you up into the air. After that it is awake: come within reach and it bites again (same tell).
##   Weakness  its open mouth (winding up / biting) takes double damage. It never moves.
## It brings its own collider (a disc you can stand on; gone when it dies). surface_at (set by the level) = the height of its back; otherwise 0.5 m above where it spawned.

const HP := 160.0
const MIMIC_R := 1.9
const WIND := 0.55
const BITE_DMG := 22.0
const TOSS := 9.5
const PUSH := 6.0
const REACH := 2.8
const CD := 1.4
const OPEN_MULT := 2.0

var awake := false
var cd := 0.0
var surface_at := NAN
var top := 0.0
var solid: World.Solid = null
var _is_set := false


func _init(w: World, p_id: int, p_x: float, p_z: float, p_y: float, o: Dictionary = {}) -> void:
	ai = AiTable.new()
	ai.walk = 0.0
	ai.run = 0.0
	ai.accel = 1.0
	ai.alert_delay = 0.2
	ai.s_wind = WIND
	ai.s_act = 0.3
	ai.s_rec = 0.9
	ai.flinch = 0.1
	ai.stagger = 0.4
	ai.stagger_immune = 2.0
	ai.poise_max = 400.0
	super._init(w, p_id, p_x, p_z, p_y, o)
	meat = true
	mimic = true
	name = "MAWLEDGE"
	bark_set = {}
	speech = false
	mute = true
	voice = 0.55
	r = MIMIC_R * 0.9
	h = 1.8
	ai.r = r
	ai.h = h
	max = HP
	hp = HP
	no_leash = true
	awake = false


func reset(first: bool) -> void:
	super.reset(first)
	cd = 0.0
	shot_cd = 1e9
	if solid != null:
		solid.set_off(false)


func setup() -> void:
	_is_set = true
	top = surface_at if not is_nan(surface_at) else hy + 0.5
	hy = top - 1.3
	y = hy
	if solid == null:
		solid = world.add({"kind": "disc", "cx": hx, "cz": hz, "r": MIMIC_R, "top": top, "bottom": top - 1.3, "tag": "mimic"})


func _go(_dt: float, _ang: float, _speed: float, _still: bool) -> void:
	x = hx
	z = hz
	y = hy
	vx = 0.0
	vz = 0.0
	kvx = 0.0
	kvz = 0.0
	lvx = 0.0
	lvz = 0.0


func _on_top(P: Player) -> bool:
	return not P.dead and P.mode == &"normal" and solid != null and solid.top_at(P.x, P.z) != null and absf(P.y - top) < 0.25


func hurt(amount: float, from: Variant, _kb: float, pt: Variant, kill: bool) -> void:
	if (state == &"windup" or state == &"attack") and not kill:
		var extra := amount * (OPEN_MULT - 1.0)
		hp -= extra
		amount += extra
		if hp <= 0.0:
			kill = true
			dead = true
	awake = true
	super.hurt(amount, from, 0.0, pt, kill)


func update(dt: float, en: Enemies, P: Player) -> void:
	E = en
	if not _is_set:
		setup()
	cd -= dt
	shot_cd = 1e9
	_go(dt, 0.0, 0.0, true)
	if solid != null:
		solid.set_off(state == &"dead")
	if P != null and state != &"dead" and state != &"windup" and state != &"attack" and state != &"stagger" and cd <= 0.0:
		var d := U.hyp(P.x - x, P.z - z)
		if _on_top(P) or (awake and not P.dead and d < REACH + MIMIC_R * 0.6 and absf(P.y - top) < 1.6):
			atk = &"bite"
			slot = &""
			a_u = 0.0
			shot_done = false
			known = Known.at(P.x, P.z)
			set_(&"windup")
			E.push({"t": "robot_atk", "id": id, "kind": "whip", "ph": "windup", "x": x, "y": top, "z": z})
			E.barks.say(self, "alert")
	super.update(dt, en, P)
	if not awake and state != &"dead" and state != &"windup" and state != &"attack" and state != &"recover":
		if state != &"idle":
			state = &"idle"
			state_t = 0.0


func _pursue(dt: float, P: Player, dx: float, dz: float, _dist: float, _sees: bool) -> void:
	known = Known.at(P.x, P.z)
	seen_t = 0.0
	_face(dt, atan2(dx, dz), 2.0)


func _attack(_dt: float, P: Player, _dx: float, _dz: float, _dist: float) -> void:
	if not shot_done and state_t >= 0.11:
		shot_done = true
		awake = true
		cd = CD
		var d := U.hyp(P.x - x, P.z - z)
		var hit := _on_top(P) or (not P.dead and d < REACH + MIMIC_R * 0.6 and absf(P.y - top) < 1.6)
		E.push({"t": "robot_atk", "id": id, "kind": "melee", "ph": "hit" if hit else "miss", "x": x, "y": top + 0.3, "z": z})
		if hit and E.c.hurt_player(P, BITE_DMG, x, z, "melee"):
			var l := d if d != 0.0 else 1.0
			P.vy = maxf(P.vy, TOSS)
			P.grounded = false
			P.mode = &"normal"
			P.ix += (P.x - x) / l * PUSH
			P.iz += (P.z - z) / l * PUSH
			E.barks.say(self, "shoot")
	if state_t >= ai.s_act:
		set_(&"recover")


func _die() -> void:
	super._die()
	respawn_t = 1e9
	if solid != null:
		solid.set_off(true)
