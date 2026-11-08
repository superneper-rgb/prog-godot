class_name FointGoon
extends Robot
## FOINT GOON (JS enemies/foint-goon.js): an orange toad on FOINT's (or GOINT's) payroll. Costumes and jobs (spawn kind "goon", spec costume / gun):
##   security  (default) pistol or SMG. Fights from a "post": a spot on a ring round you that is walkable, reachable, has a line of fire and keeps clear of the other goons. He walks to it, holds a beat, fires, then picks the next one along the same orbit, so a squad spreads out and circles instead of milling. Every burst is telegraphed and is one of a few patterns. The first bursts of a fight are loose and tighten up. Hit hard, or caught in your sights, he may juke sideways; after a hard hit, or now and then, he drops to one knee. A post behind a waist-high crate is preferred sometimes: there he ducks between bursts. At most FIRING goons shoot at once, never on the same beat, only while on screen. The gun has a magazine and he reloads on the move. A goon going down nearby makes the others look, shout, and fire angrier for a few seconds.
##   hazmat    slow and tough, same post logic further out. Lobs globs of green acid in an arc: onto you, ahead of you, or a three-glob fan; a glob that lands leaves a hissing puddle.
##   labcoat   not a fighter. On alert he panics: runs for the nearest alarm panel and slaps it (every goon within 45 m comes running). Cornered he fires a shaky pistol.
##   goint_guard     prison guard = the security job, with a flashlight (beam = the cone in world space, for stealth checks).
##   goint_adjuster  heavy, own job: armour and a blue energy shield. A shot that crosses the raised shield is soaked and drains it; empty, it overloads, down for a few seconds. A core hit takes full damage, anything else on the armour half. One-handed past a shield he is sloppy.
## The look lives in enemies/foint_goon_view.gd.

const SEC_HP := 110.0
const HAZ_HP := 170.0
const LAB_HP := 55.0
const NOTICE := 22.0
const POISE_M := 100.0
const WALK := 2.0
const RUN := 4.4
const HAZ_RUN := 3.2
const LAB_RUN := 5.4
const ACCEL := 8.0
const TURN := 7.0
const JUKE := 0.35
const RING_MIN := 7.0
const RING_MAX := 15.0
const FIRING := 2
const AIM := 0.45
const BURST_PAUSE := 1.6
const BOLT_SPEED := 30.0
const PISTOL_DMG := 6.0
const PISTOL_N := 3
const PISTOL_GAP := 0.22
const PISTOL_SPREAD := 0.035
const SMG_DMG := 3.5
const SMG_N := 7
const SMG_GAP := 0.085
const SMG_SPREAD := 0.07
const CROUCH := 0.3
const ACID_DMG := 10.0
const ACID_POOL_DPS := 9.0
const ACID_POOL_R := 1.7
const ACID_POOL_T := 4.5
const ACID_CD := 2.8
const ACID_WIND := 0.6
const ACID_RING_MIN := 6.0
const ACID_RING_MAX := 13.0
const LAB_SHOT_DMG := 4.0
const CORNERED := 5.0
const ALARM_T := 1.4
const PISTOL_MAG := 9.0
const SMG_MAG := 22.0
const RELOAD := 1.5
const SHUFFLE := 0.62
const RAGE := 6.0
const ADJ_HP := 240.0
const ADJ_WALK := 1.35
const ADJ_RUN := 2.5
const ADJ_RING_MIN := 4.5
const ADJ_RING_MAX := 10.0
const ADJ_SHIELD := 130.0
const ADJ_SHIELD_REGEN := 30.0
const ADJ_SHIELD_DELAY := 1.6
const ADJ_SHIELD_DOWN := 3.5
const ADJ_CORE := 1.0
const ADJ_ARMOUR := 0.5
const ADJ_TRACK := 2.2
const ADJ_SPREAD := 1.6
const ADJ_DMG := 2.2
const ADJ_PAUSE := 1.5
const ACID_G := 14.0

# deadpan: people with a job, a badge and a shift to finish
const GOON_BARKS := {
	"security": {
		"alert": ["Hey. HEY. That is a restricted floor.", "Unauthorized personnel. Lovely.", "Contact. Somebody write this down.", "Visitor badge? No? Okay.", "Security. Do not make this a whole thing."],
		"shoot": ["Company policy, pal.", "Stay down!", "Suppressing!", "I am authorised for this.", "Hold still. I get paid either way."],
		"pain": ["That is going in the incident report.", "Ow. Okay. Ow.", "Medic! Is anyone on shift?", "This vest was a rental.", "I have a review on Friday!"],
		"die": ["Tell HR... I tried...", "Three weeks... to the pension...", "Clock me... out..."],
		"reload": ["Reloading!", "Changing mags!", "Cover me, I am dry!", "Hang on. Hang on."],
		"mate": ["Man down! MAN DOWN!", "He got Gary!", "Oh, that is paperwork.", "You will pay for that. Literally. There is a form."],
		"move": ["Flank him!", "Moving up!", "Go left! My left!", "Cut him off!", "Spread out, spread out!"],
	},
	"hazmat": {
		"alert": ["Containment breach. Great. Of course.", "You are not cleared for this room.", "Step away from the vats, sir.", "Do NOT touch anything green."],
		"shoot": ["Decontaminating!", "Hold still, this stings.", "Flushing the area!", "That is a lot of acid. Sorry."],
		"pain": ["My seal! My SEAL!", "Do you know what this suit costs?", "Ow. Breach. Ow.", "Suit integrity... fine. Mostly."],
		"die": ["Log it... as an accident...", "The suit... was rated...", "Tell them... I wore it right..."],
		"mate": ["Casualty! Bag him!", "That is a containment failure.", "Oh, he is not getting up."],
		"move": ["Repositioning!", "Flooding the left!", "Moving the hose!"],
	},
	"labcoat": {
		"alert": ["Oh no. Oh no no no.", "I am NOT paid for this!", "SECURITY! SECURITY!", "I just do the paperwork!", "Somebody hit the alarm! Me. I will."],
		"shoot": ["Stay back! I have a... thing!", "I am warning you! Probably!", "Get AWAY from me!", "I took a course on this!"],
		"pain": ["My grant!", "Ow! I have tenure!", "Not the hands! I need the hands!", "That is a lab coat, not armour!"],
		"die": ["The data... back it up...", "Peer review... this...", "I was going... to publish..."],
		"mate": ["They shot him! THEY SHOT HIM!", "I am going home. I am going HOME.", "Nope. Nope nope nope."],
	},
	# GOINT: earnest, procedural, everyone covered by something
	"goint_guard": {
		"alert": ["Inmate out of bounds!", "Hold it. You are not on the roster.", "Lights on him! Lights on him!", "Unscheduled movement, cell block!", "Stop right there. This is a covered premises."],
		"shoot": ["Return to your cell!", "Premium coverage, pal!", "Lethal force is pre-approved!", "Stay in the light!", "Down on the floor!"],
		"pain": ["I am filing a claim!", "That is a workplace incident!", "My deductible!", "Medic! GOINT medic!", "Ow. That is not covered."],
		"die": ["Tell my... beneficiary...", "Policy... lapsed...", "Coverage... ending..."],
		"reload": ["Reloading!", "Changing mags!", "Cover me, I am dry!", "Hang on. Hang on."],
		"mate": ["Officer down! OFFICER DOWN!", "They got Pelling!", "That is a payout. Somebody notify the family.", "Lock it down! Lock the whole block down!"],
		"move": ["Flank him!", "Block the corridor!", "Go left! My left!", "Cut him off!", "Spread out, sweep it!"],
	},
	"goint_adjuster": {
		"alert": ["Incident detected. Assessing.", "Claim opened.", "You will be adjusted.", "Damages are about to occur.", "Please remain where you are."],
		"shoot": ["Claim denied.", "Pre-existing condition.", "Adjusting.", "Liability: yours.", "Coverage does not extend to you."],
		"pain": ["Noted.", "Minor depreciation.", "Within tolerance.", "That will be reflected in your premium."],
		"die": ["Claim... closed...", "Total... loss...", "File... it..."],
		"reload": ["Reloading.", "Processing.", "One moment."],
		"mate": ["Loss of personnel. Logged.", "That is a total loss.", "Adjusting the estimate."],
		"move": ["Advancing.", "Closing the claim.", "Moving in."],
		"exposed": ["Shield is down!", "Barrier failure. Recalibrating!", "Cover lapsed! Cover lapsed!", "Coverage interrupted!"],
		"shieldUp": ["Coverage restored.", "Barrier online.", "Back on policy."],
	},
}
const NAMES := {"security": ["FOINT SECURITY", "SGT. CROAKLEY", "OFFICER BUFO", "GUARD 7"], "hazmat": ["HAZMAT TECH", "DECON UNIT 3", "TECH WARTZ"], "labcoat": ["DR. TADPOLE", "LAB TECH", "DR. KERMAN", "RESEARCH ASSOCIATE"],
	"goint_guard": ["GOINT GUARD", "C.O. BUFORD", "OFFICER PELLING", "GUARD 12"], "goint_adjuster": ["CLAIMS ADJUSTER", "SENIOR ADJUSTER", "ADJUSTER MOSS"]}
const COSTUMES: Array[String] = ["security", "security", "hazmat", "labcoat"]      # "random" / no costume picks from these (FOINT staff)
const ROLE := {"security": "security", "hazmat": "hazmat", "labcoat": "labcoat", "goint_guard": "security", "goint_adjuster": "adjuster"}

## JS this.fire
class Fire:
	var ph := &"idle"
	var t := 0.0
	var n := 0
	var k := 0
	var pat: Dictionary = {}
	var side := 1.0
	var ax := 0.0
	var az := 0.0

## JS this.post
class Post:
	var x := 0.0
	var z := 0.0
	var los := false
	var cover := false

## Acid in flight and on the floor, shared per fight (on the enemy manager).
class AcidState:
	var world: World = null
	var globs: Array[Dictionary] = []
	var pools: Array[Dictionary] = []
	var t := -1.0
	var tick := 0.0

var goon := true
var costume := "security"
var role := "security"
var gun := "pistol"
var alarm_at: Variant = null                 # Vector2 x, z
var flashlight := true
var fire := Fire.new()
var strafe_dir := 1.0
var strafe_t := 0.0
var crouch_t := 0.0
var crouch_cd := 0.0
var recoil := 0.0
var alarm_t := 0.0
var alarm_done := false
var panic := 0.0
var cornered := false
var pressing := false
var look_at: Variant = null                  # Vector3
var muzzle: Variant = null                   # Vector3: the real muzzle, from the view
var muzzle_t := -1.0
var post: Post = null
var post_t := 0.0
var plan_cd := 0.0
var plan_stuck := 0
var arrived := false
var orbit_dir := 1.0
var juke := 0.0
var juke_a := 0.0
var juke_req := false
var engage_t := 0.0
var cover_duck := false
var mag := 0.0
var reload_t := 0.0
var reload_dur := 1.0
var shuf := false
var shuf_t := 0.0
var shuf_a := 0.0
var mate_t := 0.0
var mate_at: Variant = null                  # Vector2 x, z
var rage_t := 0.0
var signal_t := 0.0
var signal_at: Variant = null                # Vector2 x, z
var hit_t := 9.0
var hit_amt := 0.0
var move_t := 0.0
var det_until := 0.0
var det_off := 0.0
var on_break := false                        # set by a level (OMNISPHERE's pad dockhand)
var drag := 0.0
var mouth_at: Variant = null                 # JS R.mouth
var beam: Dictionary = {}                    # set by the view: the flashlight's cone, for stealth checks
# the adjuster
var shield_max := 0.0
var shield := 0.0
var shield_down_t := 0.0
var shield_regen_t := 0.0
var shield_geo: Variant = null               # Dictionary, from the view
var core_at: Variant = null                  # Dictionary, from the view
var core_hit_t := 9.0
var shield_ups := 0
var shield_breaks := 0
var shield_hits := 0
var shield_hit_at: Variant = null


static func _rnd(a: float, b: float) -> float:
	return a + randf() * (b - a)


func _init(w: World, p_id: int, p_x: float, p_z: float, p_y: float, o: Dictionary = {}) -> void:
	var sp: Dictionary = o.get("spawn", {})
	var want := String(sp.get("costume", ""))
	costume = want if ROLE.has(want) else (COSTUMES[p_id % COSTUMES.size()] if want == "random" or want == "" else "security")
	role = ROLE[costume]
	var sg := String(sp.get("gun", ""))
	gun = "acid" if role == "hazmat" else ("pistol" if role == "labcoat" else ("smg" if role == "adjuster" else (sg if sg == "pistol" or sg == "smg" else ("smg" if p_id % 2 == 1 else "pistol"))))
	var helmet := costume == "goint_guard" or role == "adjuster"      # the pointed helmet stands up past the head
	var tank := role == "adjuster"
	var rr := 0.58 if tank else 0.48
	var hh := 1.85 if role == "hazmat" else (1.8 if helmet else 1.6)
	ai = AiTable.new()
	ai.r = rr
	ai.h = hh
	ai.walk = ADJ_WALK if tank else WALK
	ai.run = HAZ_RUN if role == "hazmat" else (LAB_RUN if role == "labcoat" else (ADJ_RUN if tank else RUN))
	ai.accel = ACCEL
	ai.alert_delay = 0.15 if role == "labcoat" else 0.7
	ai.flinch = 0.22
	ai.flinch_cd = 0.35
	ai.stagger = 0.8
	ai.stagger_immune = 1.6
	ai.poise_max = POISE_M * (1.5 if role == "hazmat" else (2.2 if tank else 1.0))
	super._init(w, p_id, p_x, p_z, p_y, o)
	human = true                          # blood and grunts, no robot beeps
	if sp.has("alarm"):
		alarm_at = Vector2(sp["alarm"][0], sp["alarm"][1])
	flashlight = sp.get("flashlight", true) != false
	var N: Array = NAMES[costume]
	name = N[p_id % N.size()]
	bark_set = GOON_BARKS[costume]
	speech = false
	voice = 0.95 if role == "labcoat" else (0.4 if tank else 0.5 + randf() * 0.15)
	r = rr
	h = hh
	max = HAZ_HP if role == "hazmat" else (LAB_HP if role == "labcoat" else (ADJ_HP if tank else SEC_HP))
	hp = max
	_goon_init()


func reset(first: bool) -> void:
	super.reset(first)
	_goon_init()


func _goon_init() -> void:
	fire = Fire.new()
	strafe_dir = -1.0 if randf() < 0.5 else 1.0
	strafe_t = _rnd(0.5, 1.5)
	crouch_t = 0.0
	crouch_cd = _rnd(3.0, 6.0)
	recoil = 0.0
	alarm_t = 0.0
	alarm_done = false
	panic = 0.0
	cornered = false
	pressing = false
	aim = 0.0
	look_at = null
	muzzle = null
	post = null
	post_t = 0.0
	plan_cd = 0.0
	plan_stuck = 0
	los_t = 0.0
	arrived = false
	orbit_dir = -1.0 if randf() < 0.5 else 1.0
	juke = 0.0
	juke_a = 0.0
	engage_t = 0.0
	cover_duck = false
	mag = _mag_size()
	reload_t = 0.0
	reload_dur = 1.0
	shuf = false
	shuf_t = 0.0
	shuf_a = 0.0
	mate_t = 0.0
	mate_at = null
	rage_t = 0.0
	signal_t = 0.0
	signal_at = null
	hit_t = 9.0
	hit_amt = 0.0
	if role == "adjuster":
		shield_max = ADJ_SHIELD
		shield = ADJ_SHIELD
		shield_down_t = 0.0
		shield_regen_t = 0.0
		shield_geo = null
		core_at = null


func _mag_size() -> float:
	if gun == "smg":
		return SMG_MAG
	return PISTOL_MAG if gun == "pistol" and role == "security" else INF


## JS ALIEN.fair.onScreen: nobody opens fire from off screen
func _on_screen() -> bool:
	var cam := Game.camera
	if cam == null:
		return true
	var v := Vector3(x, y + 1.0, z) - cam.global_position
	var L := v.length()
	if L < 4.0:      # right next to you: always counts as seen
		return true
	var f := -cam.global_transform.basis.z
	var vp := cam.get_viewport().get_visible_rect().size
	var half := atan(tan(deg_to_rad(cam.fov) * 0.5) * (vp.x / maxf(vp.y, 1.0)))      # horizontal half-angle
	return acos(clampf(v.dot(f) / L, -1.0, 1.0)) < half + 0.15


# ---- shooting tokens: at most FIRING goons in a burst at once ----
func _token_free() -> bool:
	var m: Dictionary = E.goon_fire
	for tid: int in m.keys():
		var live := false
		for o: Robot in E.robots:
			if o.id == tid and not o.dead:
				live = true
				break
		if float(m[tid]) < E.t or not live:
			m.erase(tid)
	return m.has(id) or m.size() < FIRING


func _token_take(s: float) -> void:
	E.goon_fire[id] = E.t + s


func _token_drop() -> void:
	if E != null:
		E.goon_fire.erase(id)


# ---- acid: globs in flight and puddles ----
func _acid() -> AcidState:
	if E.goon_acid == null or E.goon_acid.world != world:      # a new level starts clean
		E.goon_acid = AcidState.new()
		E.goon_acid.world = world
	return E.goon_acid


func _acid_update(dt: float, P: Player) -> void:
	var A := _acid()
	if A.t == E.t:
		return
	A.t = E.t
	var W := world
	var i := A.globs.size() - 1
	while i >= 0:
		var q: Dictionary = A.globs[i]
		q.life = float(q.life) + dt
		q.vy = float(q.vy) - ACID_G * dt
		var nx: float = q.x + q.vx * dt
		var ny: float = q.y + q.vy * dt
		var nz: float = q.z + q.vz * dt
		var hit := ""
		if P != null and not P.dead and U.hyp(nx - P.x, nz - P.z) < Config.radius + 0.3 and ny > P.y - 0.2 and ny < P.y + P.h + 0.2:
			hit = "player"
		elif W.point_solid(nx, ny, nz):
			hit = "world"
		else:
			var g := W.ground_height(nx, nz, 0.2, float(q.y) + 0.5)
			if g > -INF and ny <= g:
				hit = "ground"
		if hit == "" and float(q.life) < 4.0:
			q.x = nx
			q.y = ny
			q.z = nz
			i -= 1
			continue
		A.globs.remove_at(i)
		i -= 1
		if hit == "":
			continue
		if hit == "player":
			E.c.hurt_player(P, ACID_DMG, float(q.x) - float(q.vx), float(q.z) - float(q.vz), "bolt")
		E.push({"t": "bolt_hit", "x": nx, "y": ny, "z": nz, "kind": "player" if hit == "player" else "world", "bk": "bile", "nx": 0.0, "ny": 1.0, "nz": 0.0})
		var gy := W.ground_height(nx, nz, 0.3, ny + 1.5)      # the puddle lands on whatever floor is under the splash
		if gy > -INF and ny - gy < 3.0:
			A.pools.append({"x": nx, "y": gy, "z": nz, "r": ACID_POOL_R * _rnd(0.85, 1.1), "t": 0.0, "life": ACID_POOL_T, "seed": randf() * 10.0})
	A.tick -= dt
	i = A.pools.size() - 1
	while i >= 0:
		var p: Dictionary = A.pools[i]
		p.t = float(p.t) + dt
		if float(p.t) > float(p.life):
			A.pools.remove_at(i)
		i -= 1
	if A.tick <= 0.0 and P != null and not P.dead:
		A.tick = 0.25
		for p: Dictionary in A.pools:
			if U.hyp(P.x - float(p.x), P.z - float(p.z)) < float(p.r) * minf(1.0, (float(p.life) - float(p.t)) / 0.6 + 0.3) and absf(P.y - float(p.y)) < 0.6 and P.grounded:
				E.c.hurt_player(P, ACID_POOL_DPS * 0.25, float(p.x), float(p.z), "acid")
				break


func update(dt: float, en: Enemies, P: Player) -> void:
	E = en
	if en != null:
		_acid_update(dt, P)
	recoil = maxf(0.0, recoil - dt * 6.0)
	crouch_t = maxf(0.0, crouch_t - dt)
	crouch_cd -= dt
	mate_t = maxf(0.0, mate_t - dt)
	rage_t = maxf(0.0, rage_t - dt)
	signal_t = maxf(0.0, signal_t - dt)
	hit_t += dt
	if reload_t > 0.0:
		reload_t -= dt
		if reload_t <= 0.0:
			reload_t = 0.0
			mag = _mag_size()
	if role == "adjuster":
		_shield_tick(dt)
	if state == &"dead" or state == &"stagger":
		_token_drop()
		fire.ph = &"idle"
		crouch_t = 0.0
		juke = 0.0
	if state != &"pursue":
		post = null
		cover_duck = false
		if state == &"idle" or state == &"return":
			engage_t = 0.0
	# goons spot you themselves: a view cone + line of sight inside NOTICE
	if P != null and not P.dead and state == &"idle" and not dev_passive and Config.ai_freeze == 0 and U.hyp(P.x - x, P.z - z) < NOTICE and _look(dt, P, false):
		alert_why = "sight"
		known = Known.at(P.x, P.z)
		seen_t = 0.0
		set_(&"alert")
		en.barks.say(self, "alert")
		en.broadcast(self, false)
	if P != null and state != &"dead":
		aim = clampf(atan2(P.y + 1.0 - (y + 1.2), maxf(0.5, U.hyp(P.x - x, P.z - z))), -0.6, 0.7)
	look_at = Vector3(P.x, P.y + 1.2, P.z) if P != null and state != &"idle" and state != &"return" and state != &"dead" else null
	if mate_t > 0.45 and mate_at != null and state != &"dead":      # a glance at the body
		look_at = Vector3(mate_at.x, y + 0.3, mate_at.y)
	super.update(dt, en, P)


func hurt(amount: float, from: Variant, kb: float, pt: Variant, kill: bool) -> void:
	if role == "adjuster":
		var a: Variant = _absorb(amount, from, pt, kill)
		if a == null:
			return
		amount = a[0]
		kill = a[1]
		kb *= 0.35
	if role == "hazmat":
		kb *= 0.6
	super.hurt(amount, from, kb, pt, kill)
	hit_t = 0.0
	hit_amt = clampf(amount / 22.0, 0.45, 1.4)      # the view snaps him away from the hit
	if role == "labcoat":
		panic = 1.0
		return
	if kill or state == &"stagger":
		return
	if fire.ph == &"aim" and role != "adjuster" and randf() < 0.5:      # a hit can spoil his aim
		fire.ph = &"idle"
		_token_drop()
		shot_cd = maxf(shot_cd, _rnd(0.4, 0.8))
	var sec := role == "security"
	if sec and crouch_cd <= 0.0 and fire.ph == &"idle" and randf() < CROUCH * 1.6:
		crouch_t = _rnd(2.2, 3.6)
		crouch_cd = _rnd(6.0, 9.0)
	elif sec and crouch_t <= 0.0 and fire.ph == &"idle" and randf() < JUKE:
		juke_req = true
	else:
		post_t = minf(post_t, _rnd(0.15, 0.5))      # stung: move soon


func _die() -> void:
	_token_drop()
	super._die()
	_mate_down()


# ---- the adjuster's shield ----
func _shield_tick(dt: float) -> void:
	core_hit_t += dt
	if dead:
		return
	if shield_down_t > 0.0:
		shield_down_t -= dt
		if shield_down_t <= 0.0:
			shield_down_t = 0.0
			shield = shield_max
			shield_ups += 1
			post = null
			if E != null:
				E.barks.say(self, "shieldUp")
		return
	if shield_regen_t > 0.0:
		shield_regen_t -= dt
	else:
		shield = minf(shield_max, shield + ADJ_SHIELD_REGEN * dt)


func _overload() -> void:
	shield = 0.0
	shield_down_t = ADJ_SHIELD_DOWN
	shield_breaks += 1
	post = null
	post_t = 0.0
	flinch_t = maxf(flinch_t, ai.flinch)
	hit_t = 0.0
	hit_amt = 1.0                          # jolted: he backs off
	if fire.ph == &"aim":
		fire.ph = &"idle"
		_token_drop()
	if E != null:
		E.barks.say(self, "exposed")


## where a shot landed: "shield" (crossed the raised shield from its front), "core" (passed within reach of the hex core), else "armour"; q = the point on the shield. Without a hit point (blasts, punches) the line from his middle toward the attacker is used.
func _hit_where(from: Variant, pt: Variant) -> Dictionary:
	var o: Vector3
	var d: Vector3
	var has_n: bool = pt != null and pt.get("nx") != null
	if has_n:
		o = Vector3(pt.x, pt.y, pt.z)
		d = Vector3(pt.nx, pt.ny, pt.nz)
	else:
		o = Vector3(x, y + 1.0, z)
		var fy: Variant = from.get("y")
		d = Vector3(float(from.x) - o.x, (float(fy) if fy != null else y) + 1.0 - o.y, float(from.z) - o.z)
	var L := d.length()
	if L == 0.0:
		L = 1.0
	d /= L
	if shield_geo != null and shield_down_t <= 0.0:
		var G: Dictionary = shield_geo
		var n: Vector3 = G.n
		var den := d.dot(n)
		if den > 0.05:
			var c: Vector3 = G.c
			var t2 := (c - o).dot(n) / den
			var qv := o + d * t2 - c
			if t2 > -0.8 and t2 < 4.0 and absf(qv.dot(G.u)) < float(G.hw) and absf(qv.dot(G.v)) < float(G.hh):
				return {"v": "shield", "q": {"x": qv.x + c.x, "y": qv.y + c.y, "z": qv.z + c.z, "nx": n.x, "ny": n.y, "nz": n.z}}
	if core_at != null and has_n:
		var K: Dictionary = core_at
		var kc: Vector3 = K.c
		if d.dot(K.n) > 0.2:
			var wv := kc - o
			var ww := wv.dot(d)
			if (wv - d * ww).length() < 0.13:
				return {"v": "core"}
	return {"v": "armour"}


## the adjuster's side of a hit. Combat has already taken the hp and queued its hit / kill events, so they are corrected here. Returns the [amount, kill] the normal reaction should see, or null when the shield soaked it.
func _absorb(amount: float, from: Variant, pt: Variant, kill: bool) -> Variant:
	var ev: Array = E.c.events if E != null and E.c != null else []
	var H := _hit_where(from, pt)
	var take := 0.0 if H.v == "shield" else amount * (ADJ_CORE if H.v == "core" else ADJ_ARMOUR)
	hp = minf(max, hp + amount - take)
	if kill and hp > 0.0:
		dead = false
		respawn_t = 0.0
		kill = false
	var k := -1
	var i := ev.size() - 1
	while i >= maxi(0, ev.size() - 6):
		var e: Dictionary = ev[i]
		if (e.t == "hit" or e.t == "kill") and int(e.get("tid", -1)) == id:
			k = i
			break
		i -= 1
	if k >= 0:
		var hit_e: Dictionary = ev[k]
		var dmg_e: Variant = ev[k - 1] if k > 0 and ev[k - 1].t == "dmg" else null
		if take == 0.0:
			hit_e.t = "goon_shield"          # a soaked shot: no blood, no hit marker, no number
		elif hit_e.t == "kill" and not kill:
			hit_e.t = "hit"
		if dmg_e != null:
			if take == 0.0:
				dmg_e.t = "goon_shield"
			else:
				dmg_e.amount = roundi(take)
				dmg_e.kill = kill
	if H.v == "core":
		core_hit_t = 0.0
	if take != 0.0:
		return [take, kill]
	shield = maxf(0.0, shield - amount)
	shield_regen_t = ADJ_SHIELD_DELAY
	shield_hits += 1
	shield_hit_at = H.q
	if shield <= 0.0:
		_overload()
	if E != null and E.P != null:
		known = Known.at(E.P.x, E.P.z)
		seen_t = 0.0
	if state == &"idle" or state == &"return" or state == &"search":
		alert_why = "hit"
		set_(&"alert")
	return null


## the others near him see him drop: a look at the body, one of them shouts, and they fire harder for a while (a labcoat just panics)
func _mate_down() -> void:
	if E == null:
		return
	var said := false
	for o: Robot in E.robots:
		var g := o as FointGoon
		if g == null or g == self or g.dead or g.state == &"idle" or g.state == &"return" or U.hyp(g.x - x, g.z - z) > 18.0:
			continue
		g.mate_t = 1.1
		g.mate_at = Vector2(x, z)
		g.rage_t = RAGE
		g.flinch_t = maxf(g.flinch_t, 0.15)
		if not said:
			said = E.barks.say(g, "mate")
		if g.role == "labcoat":
			g.panic = 1.0
		elif g.role == "security" and g.fire.ph == &"idle" and g.crouch_t <= 0.0 and randf() < 0.35:
			g.juke_req = true


# ---- the fight ----
## [closest, furthest, preferred] distance from the player: pistols hang back, SMGs press in, the hazmat lobs from mid range
func _band() -> Vector3:
	if role == "hazmat":
		return Vector3(ACID_RING_MIN, ACID_RING_MAX, lerpf(ACID_RING_MIN, ACID_RING_MAX, 0.45))
	if role == "adjuster":      # presses in behind the shield; backs off while it is down
		return Vector3(ADJ_RING_MIN + 4.0, ADJ_RING_MAX + 5.0, ADJ_RING_MAX + 1.0) if shield_down_t > 0.0 else Vector3(ADJ_RING_MIN, ADJ_RING_MAX, lerpf(ADJ_RING_MIN, ADJ_RING_MAX, 0.35))
	var a := RING_MIN
	var b := maxf(a + 2.0, RING_MAX)
	return Vector3(a - 1.5, lerpf(a, b, 0.55), lerpf(a, b, 0.18)) if gun == "smg" else Vector3(a, b, lerpf(a, b, 0.45))


## turn toward ang: eased, but never faster than max_w rad/s, so a big about-face reads as a turn, not a snap
func _turn(dt: float, ang: float, rate: float, max_w: float) -> void:
	var d := U.wrap_angle(ang - yaw) * (1.0 - exp(-rate * dt))
	var m := max_w * dt
	yaw = U.wrap_angle(yaw + clampf(d, -m, m))


func _pursue(dt: float, P: Player, dx: float, dz: float, dist: float, sees_now: bool) -> void:
	var k := known
	if k == null:
		set_(&"search")
		return
	if role == "labcoat":
		_panic(dt, P, dx, dz, dist, sees_now)
		return
	var F := fire
	var kd := U.hyp(k.x - x, k.z - z)
	if not sees_now and ((seen_t > Config.ai_lose_time and kd < 1.6) or seen_t > Config.ai_lose_time + 6.0 or stuck_n >= 4):
		set_(&"search")
		scan_t = 0.0
		_token_drop()
		F.ph = &"idle"
		post = null
		return
	var haz := role == "hazmat"
	var tank := role == "adjuster"
	var band := _band()
	cover_duck = false
	if sees_now:
		engage_t += dt
	move_t = move_t + dt if U.hyp(vx, vz) > 1.0 else 0.0
	plan_cd -= dt
	post_t -= dt
	los_t -= dt
	# lost sight a moment ago (you ducked behind a crate): keep working the ring round where he last saw you, gun on that spot; only a longer blackout sends him to look. T is who the posts are planned round: you, or that last spot.
	var blind := not sees_now and seen_t > 3.0
	var tx := P.x if sees_now else k.x
	var tz := P.z if sees_now else k.z
	var tdist := dist if sees_now else kd
	# facing: squared up to the player while he can see him (slower through a burst, so you can out-run the stream), else the last spot, else where he walks
	if sees_now:
		_turn(dt, atan2(dx, dz), 5.0 if F.ph == &"burst" else 9.0, 3.5 if F.ph == &"burst" else TURN)
	elif not blind and kd > 1.0:
		_turn(dt, atan2(k.x - x, k.z - z), 6.0, TURN * 0.8)
	elif U.hyp(vx, vz) > 0.3:
		_turn(dt, atan2(vx, vz), 5.0, TURN * 0.7)
	if sees_now and not P.dead:
		if haz:
			_lob(dt, P, dist)
		else:
			_shoot(dt, P, dist)
	elif F.ph == &"aim":                   # nothing to aim at: lower the gun
		F.ph = &"idle"
		_token_drop()
	if crouch_t > 0.0:
		juke_req = false
		_go(dt, 0.0, 0.0, true)
		return
	if blind:
		post = null
		juke = 0.0
		_go(dt, _steer(k.x, k.z), ai.run if kd > 3.0 else ai.walk * 1.3, false)
		return
	# juke: a quick hop off the line of fire, after a hit (see hurt) or now and then while he sits in your sights
	if sees_now and not haz and not tank and F.ph == &"idle" and juke <= 0.0 and P.aiming and dist > 4.0 and absf(U.wrap_angle(atan2(x - P.x, z - P.z) - P.yaw)) < 0.14 and randf() < dt * JUKE * 1.2:
		juke_req = true
	if juke_req:
		juke_req = false
		if F.ph == &"idle":
			_juke(dx, dz, dist, band)
	if juke > 0.0:
		juke -= dt
		var s := sin(juke_a)
		var c := cos(juke_a)
		if _free(x + s * 0.8, z + c * 0.8) and _edge_ok(s, c):
			_go(dt, juke_a, ai.run * 1.2, false)
			if juke <= 0.0:
				post_t = 0.0
			return
		juke = 0.0
		post_t = 0.0
	# the post: a new one when the hold is up, the player moved off it, its line of fire closed, or he got stuck on the way
	var need := post == null or post_t <= 0.0 or stuck_n > plan_stuck
	if not need:
		var pd := U.hyp(post.x - tx, post.z - tz)
		if pd < band.x - 0.5 or pd > band.y + 2.0:
			need = true
		elif los_t <= 0.0:
			los_t = 0.5
			if post.los and not _los_from(post.x, post.z, tx, P.y, tz):      # a blind post was already the best there was: no thrash
				need = true
	if need and plan_cd <= 0.0:
		_plan(P, sees_now, tx, tz, band)
	var po := post
	if po == null:
		_go(dt, 0.0, 0.0, true)
		return
	var d := U.hyp(po.x - x, po.z - z)
	if d < 0.35 or (arrived and d < 1.6):
		if not arrived:
			arrived = true
			post_t = _rnd(3.0, 4.5) if po.cover else minf(post_t, _rnd(0.6, 1.5))      # cover is worth holding a little longer
			if po.cover:
				shot_cd = maxf(shot_cd, _rnd(0.6, 1.0))
		cover_duck = po.cover and sees_now and F.ph == &"idle" and shot_cd > 0.3      # behind a crate: down between bursts, up to fire
		if not _shuffle(dt, dx, dz, dist, po, F, sees_now):
			_go(dt, 0.0, 0.0, true)
		return
	shuf = false
	# on the way: run when it is far or you are on top of him, else a strafing walk; pistols and the sprayer plant to shoot, SMGs walk slowly through a burst
	var plant: bool = F.ph != &"idle" and (haz or F.pat.get("plant", false))
	var v := 0.0 if plant else (ai.walk * 0.55 if F.ph != &"idle" else (ai.run if d > 3.5 or tdist < band.x * 0.75 else ai.walk * 1.3))
	v = minf(v, 0.45 + d * 1.6)            # ease into the post instead of braking on it
	_go(dt, _steer(po.x, po.z), v, v < 0.2)


## holding a post: a step or two to one side, a beat, a step back the other way (kept within reach of the post), never through a planted shot
func _shuffle(dt: float, dx: float, dz: float, dist: float, po: Post, F: Fire, sees_now: bool) -> bool:
	if crouch_t > 0.0 or cover_duck:      # up off the knee first, then step
		strafe_t = maxf(strafe_t, 0.6)
	if po.cover or cover_duck or crouch_t > 0.0 or not sees_now or SHUFFLE <= 0.0 or (F.ph != &"idle" and (role == "hazmat" or F.pat.get("plant", false))):
		shuf = false
		return false
	strafe_t -= dt
	if shuf:
		shuf_t += dt
	if strafe_t <= 0.0:
		if shuf:
			shuf = false
			strafe_t = _rnd(0.5, 1.3)
		else:
			var L := dist if dist != 0.0 else 1.0
			var px := dz / L
			var pz := -dx / L
			var off := (x - po.x) * px + (z - po.z) * pz
			var dir := -signf(off) if absf(off) > 0.5 else (-strafe_dir if randf() < 0.7 else strafe_dir)
			var a := atan2(px * dir, pz * dir)
			var s := sin(a)
			var c := cos(a)
			if _free(x + s * 0.8, z + c * 0.8) and _edge_ok(s, c):
				shuf = true
				shuf_t = 0.0
				shuf_a = a
				strafe_dir = dir
				strafe_t = _rnd(0.6, 1.0)
			else:
				strafe_dir = -dir
				strafe_t = 0.35
	if not shuf:
		return false
	var s2 := sin(shuf_a)
	var c2 := cos(shuf_a)
	if not _free(x + s2 * 0.7, z + c2 * 0.7) or not _edge_ok(s2, c2):
		shuf = false
		strafe_t = 0.4
		return false
	_go(dt, shuf_a, ai.walk * SHUFFLE * (0.7 if F.ph != &"idle" else 1.0) * (0.8 if role == "hazmat" else 1.0), false)
	return true


func _clear_ahead(h2: float) -> bool:
	return _free(x + sin(h2) * 0.85, z + cos(h2) * 0.85) and _free(x + sin(h2) * 1.6, z + cos(h2) * 1.6)


## the stock steering, but a detour round a crate is held for a moment while it stays clear, instead of flicking between its two sides
func _steer(tx: float, tz: float) -> float:
	var base := atan2(tx - x, tz - z)
	var a := super._steer(tx, tz)
	var now: float = E.t if E != null else 0.0
	var off := U.wrap_angle(a - base)
	if unstick_t > 0.0:
		return a
	if absf(off) > 0.01:
		if now < det_until and signf(off) != signf(det_off) and _clear_ahead(base + det_off):
			return base + det_off
		det_off = off
		det_until = now + 0.45
		return a
	if now < det_until and _clear_ahead(base + det_off * 0.5):      # ease back onto the straight line
		return base + det_off * 0.5
	return a


## pick the next post: candidates along the ring round the player (mostly on along the way he is already circling), scored on distance, the trip, a clear walk and line of fire, room from the other goons and the acid, and not standing straight down the player's sights
func _plan(P: Player, sees_now: bool, tx: float, tz: float, band: Vector3) -> void:
	var W := world
	var pref := band.z
	var b0 := atan2(x - tx, z - tz)
	var pvx := P.vx if sees_now else 0.0
	var pvz := P.vz if sees_now else 0.0
	var fx := tx + pvx * 0.6               # where the player is going
	var fz := tz + pvz * 0.6
	var aiming: bool = sees_now and P.aiming
	var pyaw: float = P.yaw if sees_now else 0.0
	if stuck_n > plan_stuck or randf() < 0.12:
		orbit_dir = -orbit_dir
	var mates: Array[FointGoon] = []
	for o: Robot in E.robots:
		var g := o as FointGoon
		if g != null and g != self and not g.dead and g.state != &"idle":
			mates.append(g)
	var pools := _acid().pools
	var state_b := {"best": null, "bs": INF}
	var consider := func(px: float, pz: float, off: float, cover: bool) -> void:
		if not _free(px, pz):
			return
		var g := W.ground_height(px, pz, ai.r * 0.8, y + ai.step)
		if not (g > y - 1.2):
			return
		var trip := U.hyp(px - x, pz - z)
		var pd := U.hyp(px - fx, pz - fz)      # cover: anywhere in his range will do, and staying put behind it is fine
		var s := (absf(pd - pref) * 0.15 + maxf(maxf(0.0, band.x - pd), pd - band.y) * 0.5 - 0.5 if cover else absf(pd - pref) * 0.5 + (1.2 if trip < 1.5 else 0.0)) + maxf(0.0, trip - 4.0) * 0.25 + (0.9 if off < 0.0 else 0.0) + randf() * 0.5
		for o: FointGoon in mates:
			var od := U.hyp(px - (o.post.x if o.post != null else o.x), pz - (o.post.z if o.post != null else o.z))
			if od < 3.2:
				s += 3.0 * (1.0 - od / 3.2)
		for p2: Dictionary in pools:
			if U.hyp(px - float(p2.x), pz - float(p2.z)) < float(p2.r) + 0.6:
				s += 4.0
		if aiming and absf(U.wrap_angle(atan2(px - tx, pz - tz) - pyaw)) < 0.2:
			s += 0.6
		if s >= float(state_b.bs):
			return
		s += _path_cost(px, pz, trip)          # the rays last: only for spots still in the running
		if s >= float(state_b.bs):
			return
		var los := _los_from(px, pz, tx, P.y, tz)
		if not los:
			s += 4.0
		if s < float(state_b.bs):
			state_b.bs = s
			var b2 := Post.new()
			b2.x = px
			b2.z = pz
			b2.los = los
			b2.cover = cover and los
			state_b.best = b2
	# the ring first; if nowhere on it has a line of fire (crates), a wider and closer sweep round the side
	var rings: Array = [[[0.32, 0.62, 0.95, 0.0, -0.32, -0.62], [pref - 1.3, pref + 1.3]], [[1.3, 1.7, -0.95, -1.3], [maxf(band.x, pref - 3.0), pref]]]
	for ring: Array in rings:
		if state_b.best != null and state_b.best.los:
			break
		for off: float in ring[0]:
			for rr: float in ring[1]:
				var a := b0 + off * orbit_dir
				consider.call(tx + sin(a) * rr, tz + cos(a) * rr, off, false)
	# now and then a security goon also looks for cover on his side of the fight: a waist-high crate between him and you, a short walk away. An option, not a habit: it only wins when the spot behind it is about as good as the open ring.
	if role == "security" and randf() < 0.25:
		for off: float in [0.0, 0.35, -0.35, 0.7]:
			var a := b0 + off * orbit_dir
			var s := sin(a)
			var c := cos(a)
			var hd := W.ray_clear(tx, P.y + 0.9, tz, s, 0.0, c, band.y, 0.04)
			if hd >= band.y - 0.5:
				continue
			var e := hd + 0.2
			while e < hd + 3.5 and not _free(tx + s * e, tz + c * e):      # step out the far side of the crate
				e += 0.25
			var px := tx + s * (e + 0.1)
			var pz := tz + c * (e + 0.1)
			if e < hd + 3.5 and e >= band.x - 0.5 and e <= band.y and U.hyp(px - x, pz - z) < 6.0 and _cover(px, pz, tx, tz):
				consider.call(px, pz, off, true)
	var best: Post = state_b.best
	if best != null and U.hyp(best.x - x, best.z - z) < 0.8:      # as good as where he stands: no shuffle
		best.x = x
		best.z = z
	if best != null and sees and role != "labcoat" and fire.ph == &"idle" and reload_t <= 0.0 and U.hyp(best.x - x, best.z - z) > 4.5 and randf() < 0.3:
		signal_t = 1.0
		signal_at = Vector2(best.x, best.z)      # a wave at where he is going
		if randf() < 0.5:
			E.barks.say(self, "move")
	post = best
	arrived = false
	plan_cd = 0.4
	plan_stuck = stuck_n
	los_t = 0.5
	post_t = _rnd(2.5, 4.0) if best != null else 0.6


## 0 for a straight, walkable line to (px, pz); a penalty per blocked or dropped sample (the steering will try to go round)
func _path_cost(px: float, pz: float, d: float) -> float:
	var n := ceili(d / 0.7)
	var bad := 0
	for i in range(1, n):
		var u := float(i) / n
		var qx := x + (px - x) * u
		var qz := z + (pz - z) * u
		var g := world.ground_height(qx, qz, ai.r * 0.8, y + ai.step)
		if not _free(qx, qz) or not (g > y - 1.2):
			bad += 1
	return 2.0 + bad * 0.5 if bad > 0 else 0.0


## something waist-high between (px, pz) and the player, close in front: a kneeling goon is hidden behind it, a standing one shoots over it
func _cover(px: float, pz: float, tx: float, tz: float) -> bool:
	var dx := tx - px
	var dz := tz - pz
	var L := U.hyp(dx, dz)
	if L == 0.0:
		L = 1.0
	return world.ray_clear(px, y + 0.9, pz, dx / L, 0.0, dz / L, 1.8, 0.04) < 1.6


func _los_from(px: float, pz: float, tx: float, ty: float, tz: float) -> bool:
	var oy := y + 1.5
	var d := Vector3(tx - px, ty + 1.1 - oy, tz - pz)
	var L := d.length()
	if L == 0.0:
		L = 1.0
	return world.ray_clear(px, oy, pz, d.x / L, d.y / L, d.z / L, L, 0.04) >= L - 0.5


## a planted shot only from a standstill, his post, or well into a move: never a stop the moment he sets off
func _plant_ok() -> bool:
	return (arrived and not (shuf and shuf_t < 0.55)) or move_t > 0.6 or U.hyp(vx, vz) < 0.5


func _juke(dx: float, dz: float, dist: float, band: Vector3) -> void:
	var base := atan2(dx, dz)
	var back := 0.4 if dist < band.x else 0.1
	for side: float in [orbit_dir, -orbit_dir]:
		var a := base + side * (PI / 2.0 + back)
		var s := sin(a)
		var c := cos(a)
		if _free(x + s * 0.9, z + c * 0.9) and _free(x + s * 1.8, z + c * 1.8) and _edge_ok(s, c):
			juke = 0.38
			juke_a = a
			orbit_dir = side
			post = null
			return


func _muzzle() -> Vector3:
	if muzzle != null and muzzle_t == E.t:
		return muzzle
	var s := sin(yaw)
	var c := cos(yaw)
	return Vector3(x + s * 0.7 - c * 0.15, y + (0.85 if crouch_t > 0.0 else 1.15), z + c * 0.7 + s * 0.15)


## the burst he is about to fire (pattern kind, aim time, rounds, gap, lead per round, spread, pause after x BURST_PAUSE)
func _pattern(dist: float) -> Dictionary:
	var rn := randf()
	var far := maxf(0.0, dist - 12.0) * 0.02
	var close := dist < 4.5
	if gun == "smg":
		if close or rn < 0.2:
			return {"k": "stab", "aim": AIM * 0.75 + far, "n": 4, "gap": SMG_GAP, "lead": [0.6], "sp": SMG_SPREAD, "cd": 0.55, "dmg": SMG_DMG}
		if rn < 0.5 and dist > 6.0:
			return {"k": "sweep", "aim": AIM * 1.15 + far, "n": SMG_N + 3, "gap": SMG_GAP * 1.15, "lead": [0.8], "sp": SMG_SPREAD * 0.5, "cd": 1.1, "dmg": SMG_DMG, "sweep": 2.6}
		return {"k": "spray", "aim": AIM + far, "n": SMG_N + randi() % 3, "gap": SMG_GAP, "lead": [0.5], "sp": SMG_SPREAD, "cd": 1.0, "dmg": SMG_DMG}
	if close or rn < 0.25:
		return {"k": "double", "aim": AIM * 0.8 + far, "n": 2, "gap": 0.13, "lead": [0.6], "sp": PISTOL_SPREAD, "cd": 0.65, "dmg": PISTOL_DMG, "plant": true}
	if rn < 0.45:
		return {"k": "bracket", "aim": AIM * 1.2 + far, "n": 4, "gap": 0.3, "lead": [0.0, 1.15, 0.0, 1.15], "sp": PISTOL_SPREAD * 0.8, "cd": 1.2, "dmg": PISTOL_DMG, "plant": true}
	return {"k": "aimed", "aim": AIM + far, "n": PISTOL_N, "gap": PISTOL_GAP, "lead": [0.4, 0.65, 0.9], "sp": PISTOL_SPREAD, "cd": 1.0, "dmg": PISTOL_DMG, "plant": true}


## pistol / SMG: aim (the gun comes up, LEDs flare) -> the pattern's burst -> a pause, and usually a new post
func _shoot(dt: float, P: Player, dist: float) -> void:
	var F := fire
	if F.ph == &"idle":
		if gun != "smg" and not _plant_ok():
			return
		if shot_cd > 0.0 or reload_t > 0.0 or signal_t > 0.4 or juke > 0.0 or _face_err(P.x, P.z) > 0.35 or dist < 1.2 or dist > 30.0 or not _on_screen() or not _token_free():
			return
		if not is_nan(E.goon_aim_at) and E.t - E.goon_aim_at < 0.45 and E.t >= E.goon_aim_at:      # two goons never open up on the same beat
			return
		var pat := _pattern(dist)
		var L := dist if dist != 0.0 else 1.0
		var px := (P.z - z) / L
		var pz := -(P.x - x) / L
		var lat := P.vx * px + P.vz * pz
		if rage_t > 0.0:      # a mate just went down: quicker on the trigger
			pat.aim = float(pat.aim) * 0.8
			pat.cd = float(pat.cd) * 0.65
		F.pat = pat
		F.ph = &"aim"
		F.t = pat.aim
		F.k = 0
		F.n = int(maxf(1.0, minf(float(pat.n), mag)))
		F.side = -1.0 if lat > 0.5 else (1.0 if lat < -0.5 else (-1.0 if randf() < 0.5 else 1.0))      # a sweep starts behind you
		E.goon_aim_at = E.t
		_token_take(float(pat.aim) + int(pat.n) * float(pat.gap) + 1.0)
		if arrived and not (post != null and post.cover) and crouch_t <= 0.0 and crouch_cd <= 0.0 and randf() < CROUCH:
			crouch_t = float(pat.aim) + _rnd(2.0, 3.5)
			crouch_cd = _rnd(6.0, 10.0)
		E.push({"t": "robot_atk", "id": id, "kind": "shot", "ph": "windup", "x": x, "y": y, "z": z})
		if pat.k == "sweep" and randf() < 0.5:
			E.barks.say(self, "shoot")
		return
	F.t -= dt
	if F.ph == &"aim":
		if F.t <= 0.0:
			F.ph = &"burst"
			F.t = 0.0
			F.ax = P.x
			F.az = P.z
		return
	if F.t > 0.0:
		return
	var pat: Dictionary = F.pat
	var i := F.k
	var m := _muzzle()
	var T := dist / BOLT_SPEED
	var leads: Array = pat.lead
	var lead: float = leads[i % leads.size()]
	var tx := P.x + P.vx * T * lead
	var tz := P.z + P.vz * T * lead
	var ty := P.y + (0.8 if P.crouching else 1.1)
	var adj := role == "adjuster"
	if adj:      # (the burst drags after you)
		var dx := P.x - F.ax
		var dz := P.z - F.az
		var d := U.hyp(dx, dz)
		var st := minf(d, ADJ_TRACK * maxf(float(pat.gap), 0.06))
		if d > 1e-4:
			F.ax += dx / d * st
			F.az += dz / d * st
		tx = F.ax
		tz = F.az
	if pat.has("sweep"):      # walks in onto you
		var u := 1.0 - float(i) / maxi(1, F.n - 1)
		var L := dist if dist != 0.0 else 1.0
		var o := F.side * float(pat.sweep) * u
		tx += (P.z - z) / L * o
		tz -= (P.x - x) / L * o
	var dv := Vector3(tx - m.x, ty - m.y, tz - m.z)
	var L2 := dv.length()
	if L2 == 0.0:
		L2 = 1.0
	dv /= L2
	var sp: float = float(pat.sp) * (1.7 - 0.7 * minf(1.0, engage_t / 4.0)) * (0.7 if crouch_t > 0.0 else 1.0) * (ADJ_SPREAD if adj else 1.0)      # loose at first, braced when kneeling
	var a := (randf() - 0.5) * 2.0 * sp
	var ca := cos(a)
	var sa := sin(a)
	E.fire(self, m.x, m.y, m.z, dv.x * ca + dv.z * sa, dv.y + (randf() - 0.5) * sp, -dv.x * sa + dv.z * ca, {"kind": "bolt", "speed": BOLT_SPEED, "dmg": ADJ_DMG if adj else pat.dmg, "r": 0.15})
	recoil = 1.0
	F.k += 1
	F.t = float(pat.gap) * _rnd(0.9, 1.1)
	mag -= 1.0
	if F.k >= F.n:
		F.ph = &"idle"
		shot_cd = BURST_PAUSE * float(pat.cd) * _rnd(0.8, 1.3) * (ADJ_PAUSE if adj else 1.0)
		_token_drop()
		if mag < (5.0 if gun == "smg" else 2.0):      # dry: reload, on the move to the next post
			reload_t = RELOAD * (1.15 if gun == "smg" else 0.9) * _rnd(0.9, 1.1)
			reload_dur = reload_t
			post_t = minf(post_t, _rnd(0.0, 0.3))
			if randf() < 0.55:
				E.barks.say(self, "reload")
			return
		if randf() < 0.3:
			E.barks.say(self, "shoot")
		if not (post != null and post.cover) and randf() < 0.65:      # shoot, then move (from cover: duck back down instead)
			post_t = minf(post_t, _rnd(0.0, 0.35))


## hazmat: the canister glows, then one glob onto you, one ahead of you to cut you off, or a fan of three
func _lob(dt: float, P: Player, dist: float) -> void:
	var F := fire
	if F.ph == &"idle":
		if not _plant_ok():
			return
		if shot_cd > 0.0 or _face_err(P.x, P.z) > 0.45 or dist < 3.0 or dist > 22.0 or not _on_screen() or not _token_free():
			return
		if not is_nan(E.goon_aim_at) and E.t - E.goon_aim_at < 0.45 and E.t >= E.goon_aim_at:
			return
		var rn := randf()
		F.pat = {"k": "fan", "lead": 0.6, "fan": [-0.22, 0.0, 0.22]} if rn < 0.3 else ({"k": "cutoff", "lead": 1.15, "fan": [0.0]} if rn < 0.55 else {"k": "glob", "lead": 0.6, "fan": [0.0]})
		F.ph = &"aim"
		F.t = ACID_WIND
		E.goon_aim_at = E.t
		_token_take(ACID_WIND + 1.0)
		E.push({"t": "robot_atk", "id": id, "kind": "shot", "ph": "windup", "x": x, "y": y, "z": z})
		return
	F.t -= dt
	if F.t > 0.0:
		return
	var m := _muzzle()
	var A := _acid()
	for off: float in F.pat.fan:
		var T := clampf(dist / 13.0, 0.55, 1.4)
		var tx := P.x + P.vx * T * float(F.pat.lead)
		var tz := P.z + P.vz * T * float(F.pat.lead)
		var gx0 := tx - m.x
		var gz0 := tz - m.z
		var ca := cos(off)
		var sa := sin(off)
		var gx := gx0 * ca + gz0 * sa
		var gz := -gx0 * sa + gz0 * ca
		var vy2 := (P.y + 0.3 - m.y + 0.5 * ACID_G * T * T) / T
		A.globs.append({"x": m.x, "y": m.y, "z": m.z, "vx": gx / T, "vy": vy2, "vz": gz / T, "life": 0.0, "owner": id})
	var L := U.hyp(P.x - m.x, P.z - m.z)
	if L == 0.0:
		L = 1.0
	E.push({"t": "bolt", "id": id, "x": m.x, "y": m.y, "z": m.z, "dx": (P.x - m.x) / L, "dy": 0.4, "dz": (P.z - m.z) / L, "kind": "bile"})
	recoil = 1.0
	F.ph = &"idle"
	shot_cd = ACID_CD * _rnd(0.85, 1.25)
	_token_drop()
	if randf() < 0.35:
		E.barks.say(self, "shoot")
	if randf() < 0.5:
		post_t = minf(post_t, _rnd(0.2, 0.6))


## labcoat: run for the alarm, else away; cornered, a shaky pistol
func _panic(dt: float, P: Player, dx: float, dz: float, dist: float, sees_now: bool) -> void:
	panic = 1.0
	pressing = false
	if alarm_t > 0.0:                      # at the panel, slapping it
		alarm_t -= dt
		pressing = true
		_go(dt, 0.0, 0.0, true)
		var a0: Variant = _alarm()
		if a0 != null:
			_face(dt, atan2(a0.x - x, a0.y - z), 10.0)
		if alarm_t <= 0.0:
			_raise_alarm()
		return
	var near := sees_now and dist < CORNERED
	cornered = near or (cornered and dist < CORNERED + 3.0) or (stuck_n >= 2 and sees_now and dist < 10.0)
	if cornered and not P.dead:
		_face(dt, atan2(dx, dz), 9.0)
		_go(dt, 0.0, 0.0, true)
		var F := fire
		if F.ph == &"idle" and shot_cd <= 0.0 and _face_err(P.x, P.z) < 0.5:
			F.ph = &"aim"
			F.t = 0.4
			E.push({"t": "robot_atk", "id": id, "kind": "shot", "ph": "windup", "x": x, "y": y, "z": z})
			if randf() < 0.5:
				E.barks.say(self, "shoot")
		elif F.ph == &"aim":
			F.t -= dt
			if F.t <= 0.0:
				var m := _muzzle()
				var dv := Vector3(P.x - m.x, P.y + 1.1 - m.y, P.z - m.z)
				var L := dv.length()
				if L == 0.0:
					L = 1.0
				dv /= L
				var wob := 0.12
				var a := (randf() - 0.5) * 2.0 * wob
				var ca := cos(a)
				var sa := sin(a)
				E.fire(self, m.x, m.y, m.z, dv.x * ca + dv.z * sa, dv.y + (randf() - 0.5) * wob, -dv.x * sa + dv.z * ca, {"kind": "bolt", "speed": 26.0, "dmg": LAB_SHOT_DMG, "r": 0.14})
				recoil = 1.0
				F.n += 1
				if F.n >= (1 if randf() < 0.5 else 2):
					F.ph = &"idle"
					F.n = 0
					shot_cd = _rnd(1.2, 1.8)
					cornered = dist < CORNERED * 0.6
					stuck_n = 0
				else:
					F.t = 0.3
		return
	fire.ph = &"idle"
	var a1: Variant = _alarm() if not alarm_done else null
	if a1 != null:
		var d := U.hyp(a1.x - x, a1.y - z)
		if d < 1.3:
			alarm_t = ALARM_T
			return
		_go(dt, _steer(a1.x, a1.y), ai.run, false)
		_face(dt, atan2(vx, vz), 9.0)
		return
	# away from the player, a few metres at a time; if that runs into a wall the steering slides him along it
	var away := atan2(x - P.x, z - P.z) + sin(E.t * 0.7 + id) * 0.5
	if dist > 30.0 and not sees_now:      # far enough: catch his breath, keep an eye out
		_go(dt, 0.0, 0.0, true)
		_face(dt, atan2(dx, dz), 3.0)
		return
	_go(dt, _steer(x + sin(away) * 4.0, z + cos(away) * 4.0), ai.run, false)
	_face(dt, atan2(vx, vz), 9.0)


func _alarm() -> Variant:
	if alarm_at != null:
		return alarm_at
	if E == null or not E.goon_alarms.is_valid():
		return null
	var L: Array = E.goon_alarms.call()
	var best: Variant = null
	var bd := 60.0
	for a: Array in L:
		var d := U.hyp(a[0] - x, a[1] - z)
		if d < bd:
			bd = d
			best = Vector2(a[0], a[1])
	return best


func _raise_alarm() -> void:
	alarm_done = true
	E.push({"t": "goon_alarm", "id": id, "x": x, "y": y + 1.2, "z": z})
	if Game.sfx != null:
		Game.sfx.play("alertBeep")
	if E.on_goon_alarm.is_valid():
		E.on_goon_alarm.call(self)
		return
	for o: Robot in E.robots:
		var g := o as FointGoon
		if g != null and g != self and not g.dead and U.hyp(g.x - x, g.z - z) < 45.0 and (g.state == &"idle" or g.state == &"return" or g.state == &"search"):
			if E.P != null:
				g.known = Known.at(E.P.x, E.P.z)
			else:
				g.known = Known.at(x, z)
			g.seen_t = 0.0
			g.alert_why = "alarm"
			g.set_(&"alert")
