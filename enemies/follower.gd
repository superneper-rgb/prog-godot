class_name Follower
extends Robot
## The Flayed Prophet's brood (JS enemies/meatball-prophet.js class Follower): a skinless, fetal lump of meat the size of a dog's head that rushes you on four long human fingers and bites. Melee only. If its owner is removed, so is the flock.

const HP := 20.0
const RUN := 5.4
const DMG := 7.0
const F_R := 0.28
const F_H := 0.6
const FOLLOWER_BARKS := {"pain": ["*squish*"], "die": ["*splat*"], "alert": ["*gurgle*"], "shoot": [""], "summon": [""], "mind": [""]}

var waddle := randf() * 6.0
var reaped := false


func _init(w: World, p_id: int, p_x: float, p_z: float, p_y: float, o: Dictionary = {}) -> void:
	ai = AiTable.new()
	ai.r = F_R
	ai.h = F_H
	ai.walk = RUN * 0.5
	ai.run = RUN
	ai.accel = 22.0
	ai.alert_delay = 0.1
	ai.reach = 1.05
	ai.m_wind = 0.38
	ai.m_act = 0.26
	ai.m_hit = 0.10
	ai.m_rec = 0.8
	ai.m_dmg = DMG
	ai.flinch = 0.15
	ai.stagger = 0.4
	ai.stagger_immune = 1.5
	ai.poise_max = 45.0
	super._init(w, p_id, p_x, p_z, p_y, o)
	meat = true
	follower = true
	mute = true
	bark_set = FOLLOWER_BARKS
	voice = 1.6
	r = F_R
	h = F_H
	max = HP
	hp = HP


func reset(first: bool) -> void:
	super.reset(first)
	shot_cd = 1e9
	respawn_t = 1e9


func _die() -> void:
	super._die()
	respawn_t = 1e9


func update(dt: float, en: Enemies, P: Player) -> void:
	E = en
	shot_cd = 1e9                                  # melee only
	if state == &"dead":
		if dead_t > 3.0 and not reaped:
			reaped = true
			en.reap.append(self)
	else:
		if owner != null and not en.robots.has(owner):      # owner was removed: so is the flock
			hp = 0.0
			reaped = true
			en.reap.append(self)
			return
		if P != null and not P.dead and (state == &"idle" or state == &"return" or state == &"search"):
			known = Known.at(P.x, P.z)
			seen_t = 0.0
			alert_why = "spawn"
			set_(&"pursue")
	super.update(dt, en, P)


func _pursue(dt: float, P: Player, dx: float, dz: float, dist: float, sees: bool) -> void:
	known = Known.at(P.x, P.z)
	seen_t = 0.0
	super._pursue(dt, P, dx, dz, dist, sees)
