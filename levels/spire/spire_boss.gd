class_name SpireBoss
extends RefCounted
## THE MAWMOTHER, the creature at the very top of the spire (JS levels/spire/boss.js): the fight's logic, set pieces and tiles. Her pose is in spire_boss_view.gd.
## Three phases (100 %, 66 %, 33 %); the order inside a phase never changes (SEQS). Her hide is armour; the maw is open during EXPOSED and the sag after THE SWALLOW. Health stops at each phase line until she roars. Every move has a sound tell; slam marks and bile volleys alternate between aiming at you and leading you; killed brood drop hearts; any hit gives a moment of mercy invulnerability; the arena's ammo pods regrow at every roar.
## Her solids, tiles and pools come from the export in JS build order: mechs' breather, 80 tile sliders, then the rim.

const NAME := "THE MAWMOTHER"
const HP := 5000.0
const R := 5.7
const H := 12.5
const EXPOSE_MULT := 2.0
const ARMOUR := 0.2
const THROAT_MULT := 1.0
const MERCY := 0.8
const PHASE2_AT := 0.66
const PHASE3_AT := 0.33
const SLAM_N := 3
const SLAM_PER := 1.4
const SLAM_LEAD: Array[float] = [1.0, 0.9, 0.85]
const SLAM_LOCK := 0.45
const SLAM_R := 2.7
const SLAM_DMG := 24.0
const SPIT_V := 3
const SPIT_GAP := 1.1
const SPIT_FAN := 5
const SPIT_SPREAD := 0.15
const SPIT_DMG := 9.0
const SPIT_SPEED := 13.0
const SHOCK_N := 2
const SHOCK_GAP := 1.6
const SHOCK_SPEED := 9.0
const SHOCK_DMG := 18.0
const CLAP_LEAD := 1.3
const CLAP_W := 3.2
const CLAP_DMG := 26.0
const CLAP_PUSH := 12.0
const CLAP_GAP := 0.9
const BIRTH_N := 4
const BIRTH_MAX := 10
const TRICKLE: Array[float] = [9.0, 6.5, 5.0]
const WAVE_PER: Array[float] = [20.0, 16.0, 13.0]
const WAVE_N: Array[int] = [4, 5, 6]
const WAVE_BELOW: Array[int] = [5, 7, 8]
const WAVE_MAX := 10
const WAVE_FIRST := 6.0
const HEART_P := 0.3
const HEART_HP := 12.0
const HEART_LIFE := 9.0
const POD_CD := 18.0
const RAIN_N := 3
const RAIN_PER := 1.5
const WHIRL_WIND := 1.1
const WHIRL_T := 3.2
const WHIRL_DMG := 24.0
const WHIRL_PUSH := 11.0
const EXPOSE_T := 5.8
const GAP := 1.1
const TILES := 16
const TILE_WARN := 1.2
const TILE_SINK := 1.6
const PIT_DPS := 10.0
const SKY_N: Array[int] = [6, 7, 8]
const SKY_PER: Array[float] = [0.8, 0.72, 0.65]
const SKY_VOL: Array[int] = [2, 3, 3]
const SKY_LEAD := 1.15
const SKY_R := 2.3
const SKY_DMG := 20.0
const SKY_REST := 8.0
const SKY_KEEP_EVERY := 2
const SW_T: Array[float] = [4.4, 4.4, 4.0]
const SW_PULL := 4.2
const SW_WARN := 1.4
const SW_CHOMP_R := 8.5
const SW_DMG := 42.0
const SW_EXPOSE := 3.4
const SW_VULN := 0.45
const HT_BEATS: Array[int] = [5, 6, 7]
const HT_GAP: Array[float] = [1.0, 0.9, 0.82]
const HT_FIRST := 1.6
const HT_DMG := 22.0
const HT_R0 := 4.2
const HBANDS := 3
const VEIL_H := 10.0
const SEQS := {1: ["slam", "spit", "skyfall", "shock", "birth", "expose"],      # every phase: pressure > set piece > breather (expose)
	2: ["slam", "grasp", "skyfall", "spit", "swallow", "whirl", "heart", "shock", "birth", "expose"],
	3: ["slam", "grasp", "skyfall", "whirl", "spit", "swallow", "heart", "grasp", "shock", "whirl", "birth", "expose"]}
const LABEL := {"skyfall": "SKYFALL - WATCH THE CIRCLES", "swallow": "THE SWALLOW - RUN OUT, DO NOT GET CHOMPED", "heart": "HEARTSTORM - HOP THE BEAT", "rain": "BONE RAIN - KEEP MOVING", "whirl": "TENDRIL WHIRL - JUMP", "slam": "TENDRIL SLAM - CUT BACK", "spit": "BILE BARRAGE", "shock": "SHOCKWAVE", "birth": "BROOD", "grasp": "CRUSHING CLAP - CLEAR THE LINE", "expose": "WEAK POINT EXPOSED - SHOOT THE MAW", "roar": ""}
const KINDS := {1: ["follower", "follower", "spore", "follower", "follower"], 2: ["follower", "spore", "follower", "brute", "follower", "prophet", "spore"], 3: ["follower", "spore", "brute", "follower", "prophet", "spore", "brute", "follower"]}
const KIND_CAP := {"brute": [0, 1, 2], "prophet": [0, 1, 1]}

var L: SpireLevel
var world: World
var TOP_Y := 124.0
var ARENA_R := 26.0
var gate_a := 0.0
var TILE_OUT := 0.0
var T: Target = null
var mode := "dormant"
var t_ := 0.0
var idx := 0
var move_ := ""
var mt := 0.0
var step := 0
var phase := 1
var yaw := 0.0
var raise := 0.0
var jaw := 0.0
var core := 0.0
var lift := 0.0
var exposed := false
var gap := 0.0
var marks: Array[Dictionary] = []
var rings: Array[Dictionary] = []
var strips: Array[Dictionary] = []
var last_hp := 0.0
var dying_t := 0.0
var boom_t := 0.0
var label := ""
var cycle := 0
var tile_set := -1
var slap := 0.0
var trickle_t := 8.0
var wave_t := 6.0
var vuln := 0.0
var warn := false
var chomped := false
var hb := 0
var whirl: Variant = null
var whirl_ang := 0.0
var whirl_u := 0.0
var hide_ := 0.0
var hinted := false
var hit_k := 0.0
var p_hp := 1e9
var clap_n := 0
var cine_seen := false
var cine: Variant = null
var cine_roar := 0.0
var core_glow := 0.0
var spawn_n := 0
var last_p: Player = null
var spawn_q: Array[Dictionary] = []
var pit_tick := 0.0
var tiles: Array[Dictionary] = []
var centre: SpireMechs.Breather
var gate_solid: World.Solid
var veil_solid: World.Solid
var body_solid: World.Solid
var cam_solids: Array[World.Solid] = []
var veil_s := "up"
var veil_u := 0.0
var veil_t := 0.0
var veil_y0 := 0.0
var sky: Array[Dictionary] = []
var cells: Array[Dictionary] = []
var hearts: Array[Dictionary] = []
var view: SpireBossView
var boss_root: Node3D
var gate_mesh: Node3D
var veil_mesh: Node3D
var rim_mesh: Node3D


func _init(level: SpireLevel, first_mover: int) -> void:
	L = level
	world = level.world
	TOP_Y = level.TOP_Y
	ARENA_R = level.ARENA_R
	gate_a = level.gate_a
	TILE_OUT = ARENA_R - 0.9
	centre = L.mechs.movers[first_mover]
	for i in TILES:
		var parts: Array = []
		for k in 5:
			parts.append(L.mechs.movers[first_mover + 1 + i * 5 + k])
		var mats: Array = L._mat_list("spTile%d" % i)
		tiles.append({"parts": parts, "s": parts[0].s, "g": parts[0].g, "idx": i, "warn": 0.0, "mats": mats, "glow": -1.0})
	L.mechs.forces.append({"y0": TOP_Y - 4.0, "y1": TOP_Y + 4.0, "apply": _pit})
	gate_solid = L.solid_by_id("spbGate")
	veil_solid = L.solid_by_id("spbVeil")
	body_solid = L.solid_by_id("spbBody")
	for s: World.Solid in world.solids:
		if s.tag == "rim":
			cam_solids.append(s)
	cam_solids.append(gate_solid)      # the rim / gate never push the lens during the fight; her body still does, like any wall
	boss_root = L.one("SpbRoot")
	gate_mesh = L.one("SpbGate")
	veil_mesh = L.one("SpbVeil")
	rim_mesh = L.one("SpbRim")
	veil_y0 = TOP_Y + VEIL_H * 0.5 - 1.5
	var sky_solids: Array[World.Solid] = []
	for s: World.Solid in world.solids:
		if s.tag == "slab":
			sky_solids.append(s)
	for i in 16:
		var g := L.one("SpbSky%d" % i)
		g.rotation_order = EULER_ORDER_XYZ
		sky.append({"g": g, "ring": L.one("SpbSkyRing%d" % i), "fill": L.one("SpbSkyFill%d" % i), "ring_m": L.own_mats(L.one("SpbSkyRing%d" % i)), "fill_m": L.own_mats(L.one("SpbSkyFill%d" % i)), "s": sky_solids[i], "st": 0, "x": 0.0, "z": 0.0, "t": 0.0, "rest": 0.0, "keep": false, "spin": 0.0})
	var n := 0
	for b in HBANDS:
		for i in TILES:
			var r0 := HT_R0 + (TILE_OUT - HT_R0) * b / HBANDS
			var r1 := HT_R0 + (TILE_OUT - HT_R0) * (b + 1) / HBANDS
			cells.append({"b": b, "i": i, "r0": r0, "r1": r1, "mesh": L.one("SpbCell%d" % n), "mats": L.own_mats(L.one("SpbCell%d" % n)), "sp": [L.one("SpbCellSp%d_0" % n), L.one("SpbCellSp%d_1" % n)], "u": 0.0, "hot": 0.0})
			n += 1
	for i in 10:
		hearts.append({"g": L.one("SpbHeart%d" % i), "m": L.one("SpbHeartM%d" % i), "on": false, "x": 0.0, "y": 0.0, "z": 0.0, "t": 0.0, "vy": 0.0})
	view = SpireBossView.new(self)


func floor_y() -> float:
	return centre.s.top


func _hurt(C: Combat, P: Player, amt: float, sx: float, sz: float, kind: String) -> bool:
	return C.hurt_player(P, amt, sx, sz, kind)


func _knock(P: Player, ux: float, uz: float, h: float, v: float) -> void:
	P.ix += ux * h
	P.iz += uz * h
	P.vy = maxf(P.vy, v)
	P.grounded = false
	P.mode = &"normal"


## the pit: standing on a sunk tile burns
func _pit(_t: float, dt: float, P: Player) -> void:
	if P.dead or not P.grounded:
		return
	for tl: Dictionary in tiles:
		var parts: Array = tl.parts
		if float(parts[0].u) > 0.5 and absf(P.y - (tl.s as World.Solid).top) < 0.1:
			var on := false
			for p: Variant in parts:
				if (p.s as World.Solid).top_at(P.x, P.z) != null:
					on = true
					break
			if on:
				P.slow_t = maxf(P.slow_t, 0.2)
				P.slow_mul = minf(P.slow_mul if P.slow_mul != 0.0 else 1.0, 0.7)
				pit_tick -= dt
				if pit_tick <= 0.0:
					pit_tick = 0.3
					L.hurt_p(P, PIT_DPS * 0.3)
					L.event({"t": &"boltHit", "x": P.x, "y": P.y + 0.1, "z": P.z, "kind": "world", "bk": "sauce", "nx": 0.0, "ny": 1.0, "nz": 0.0})
				return


## THE MEAT VEIL: a wall of flesh fills the gate from outside, so she is not seen (or the arena) until you walk up to it; it then sinks into the floor and the way is open.
func _veil_step(dt: float, P: Player) -> void:
	if veil_s == "down":
		return
	var gd := U.hyp(P.x - sin(gate_a) * ARENA_R, P.z - cos(gate_a) * ARENA_R) if P != null else 99.0
	var vx := sin(gate_a) * (ARENA_R + 0.4)
	var vz := cos(gate_a) * (ARENA_R + 0.4)
	if veil_s == "up" and P != null and not P.dead and P.y > TOP_Y - 4.0 and (gd < 9.5 or U.hyp(P.x, P.z) < ARENA_R - 1.0):      # you came up to it (or were put inside, e.g. a teleport)
		veil_s = "lowering"
		veil_t = 9.0 if U.hyp(P.x, P.z) < ARENA_R - 1.0 else 0.0
		boss_root.visible = true
		L.event({"t": &"wormSlam", "x": vx, "y": TOP_Y, "z": vz, "r": 2.4})
		L.toast("THE WALL OF FLESH PARTS")
	if veil_s == "lowering":
		veil_t += dt
		veil_u = clampf((veil_t - 0.5) / 2.4, 0.0, 1.0)
		var e := veil_u * veil_u * (3.0 - 2.0 * veil_u)
		veil_mesh.position.y = veil_y0 - e * (VEIL_H + 2.0)
		veil_mesh.position.x = vx + sin(veil_t * 40.0) * 0.05 * (1.0 - e)
		veil_solid.set_span(veil_solid.bottom, TOP_Y + VEIL_H - e * (VEIL_H + 3.0))
		if veil_u > 0.55:
			veil_solid.set_off(true)
		if veil_u >= 1.0:
			veil_s = "down"
			veil_mesh.visible = false
			veil_solid.set_off(true)
			L.event({"t": &"wormSlam", "x": vx, "y": TOP_Y, "z": vz, "r": 2.0})


# ---------------------------------------------------------------------------------------------- the brood's hearts: health drops
func _hearts_clear() -> void:
	for h: Dictionary in hearts:
		h.on = false
		(h.g as Node3D).visible = false


func _hearts_step(dt: float, P: Player, C: Combat) -> void:
	for r: Robot in C.enemies.robots:
		if r.get_meta("boss_spawn", false) and r.dead and not r.get_meta("maw_heart", false):
			r.set_meta("maw_heart", true)
			var bk: String = r.get_meta("boss_kind", "")
			if not (bk == "brute" or bk == "prophet" or randf() < HEART_P):
				continue
			var h: Dictionary = {}
			for q: Dictionary in hearts:
				if not q.on:
					h = q
					break
			if h.is_empty():
				h = hearts[0]
				for q: Dictionary in hearts:
					if float(q.t) > float(h.t):
						h = q
			h.on = true
			h.t = 0.0
			h.x = r.x
			h.z = r.z
			h.y = r.y + 1.2
			h.vy = 4.0
			(h.g as Node3D).visible = true
	for h: Dictionary in hearts:
		if not h.on:
			continue
		h.t = float(h.t) + dt
		var ht: float = h.t
		var hy: float = h.y
		var gy := maxf(TOP_Y - 2.0, world.ground_height(h.x, h.z, 0.2, hy + 0.3)) + 0.55
		h.vy = float(h.vy) - 22.0 * dt
		hy += float(h.vy) * dt
		if hy < gy:
			hy = gy
			h.vy = 0.0
		h.y = hy
		var beat := SpireMechs.beat_at(ht * 1.6 + 3.0, 1.0)
		var rot := (ht - HEART_LIFE + 2.0) / 2.0 if ht > HEART_LIFE - 2.0 else 0.0      # the last 2 s it greys and shrinks
		(h.g as Node3D).position = Vector3(h.x, hy + sin(ht * 3.0) * 0.08, h.z)
		var m: Node3D = h.m
		m.scale = Vector3.ONE * ((1.0 + beat * 0.25) * (1.0 - rot * 0.6))
		m.rotation.y = ht * 1.5
		if P != null and not P.dead and U.hyp(P.x - float(h.x), P.z - float(h.z)) < 1.5 and absf(P.y + 0.6 - hy) < 2.0 and P.hp < P.max_hp:
			P.hp = minf(P.max_hp, P.hp + HEART_HP)
			h.on = false
			(h.g as Node3D).visible = false
			p_hp = P.hp
			C.events.append({"t": &"pickup", "x": h.x, "y": hy, "z": h.z})
			continue
		if ht > HEART_LIFE:
			h.on = false
			(h.g as Node3D).visible = false


# ---------------------------------------------------------------------------------------------- tiles: which third sinks
func _tile_want(tl: Dictionary, v: float) -> void:
	for p: Variant in tl.parts:
		p.want = v


func tiles_want(set_: int, two: bool = false) -> void:      # set: -1 = all up, else tiles with (i % 3) === set sink (and the next third too, when two)
	var key := -1 if set_ < 0 else set_ + (10 if two else 0)
	if key == tile_set:
		return
	tile_set = key
	for tl: Dictionary in tiles:
		var i: int = tl.idx
		var sink := set_ >= 0 and (i % 3 == set_ or (two and i % 3 == (set_ + 1) % 3))
		if sink and float(tl.parts[0].want) < 1.0 and float(tl.warn) <= 0.0:
			tl.warn = TILE_WARN
		if not sink:
			_tile_want(tl, 0.0)
			tl.warn = 0.0


func _tiles_step(dt: float, time: float) -> void:
	for tl: Dictionary in tiles:
		if float(tl.warn) > 0.0:
			tl.warn = float(tl.warn) - dt
			if float(tl.warn) <= 0.0:
				_tile_want(tl, 1.0)
		var w: bool = float(tl.warn) > 0.0
		var glow := 0.5 + 0.5 * sin(time * 18.0) if w else (0.6 if float(tl.parts[0].u) > 0.5 else 0.0)
		if glow != float(tl.glow):
			tl.glow = glow
			for m: StandardMaterial3D in tl.mats:      # dark at rest so the sink warning reads louder
				m.emission = Color(0.05 + glow * 1.0, 0.01 + glow * 0.28, 0.02).linear_to_srgb()
		if w:
			(tl.g as Node3D).position.x += sin(time * 50.0 + int(tl.idx)) * 0.04


# ---------------------------------------------------------------------------------------------- logic
func hook(C: Combat) -> void:
	T = Target.new(9000, 0.0, 0.0, TOP_Y, {"r": R, "h": H, "max": HP, "hp": HP, "boss": true})
	T.respawn_t = 1e9
	last_hp = HP
	C.targets.append(T)


func reset(C: Combat) -> void:
	mode = "dormant"
	idx = 0
	move_ = ""
	mt = 0.0
	phase = 1
	exposed = false
	label = ""
	marks.clear()
	rings.clear()
	strips.clear()
	raise = 0.0
	jaw = 0.0
	lift = 0.0
	cycle = 0
	slap = 0.0
	clap_n = 0
	trickle_t = 8.0
	wave_t = WAVE_FIRST
	whirl = null
	whirl_u = 0.0
	hide_ = 0.0
	hit_k = 0.0
	p_hp = 1e9
	_hearts_clear()
	if T != null:
		T.hp = T.max
		T.dead = false
		last_hp = T.max
	gate_solid.set_off(true)
	gate_mesh.visible = false
	body_solid.set_off(false)
	boss_root.visible = veil_s != "up"
	boss_root.scale = Vector3.ONE
	tiles_want(-1)
	_sky_clear()
	spawn_q.clear()
	vuln = 0.0
	warn = false
	if C != null:
		for r: Robot in C.enemies.robots.duplicate():
			if r.get_meta("boss_spawn", false):
				Game.despawn_enemy(r)


## the entrance cutscene takes over (see spire_arena_intro.gd); end_cine() hands her to the fight
func begin_cine() -> void:
	mode = "cine"
	t_ = 0.0
	cine = {"sw": null}
	cine_roar = 0.0
	label = ""


func close_gate() -> void:
	gate_solid.set_off(false)
	gate_mesh.visible = true


func end_cine() -> void:
	cine = null
	cine_roar = 0.0
	mode = "fight"
	gap = 1.2
	move_ = ""
	t_ = 0.0
	close_gate()
	L.banner("THE MAWMOTHER", "THE SPIRE WAKES AROUND YOU", 4.0)
	L.toast("THE MAWMOTHER WAKES")


func begin_move(nm: String) -> void:
	move_ = nm
	mt = 0.0
	step = 0
	label = LABEL.get(nm, "")
	exposed = false
	if nm == "slam":
		cycle += 1
	elif nm == "grasp":
		clap_n += 1
	# every move has its own sound tell from her throat, so you can read her without looking
	var hy := TOP_Y + 10.0
	var cue: Variant = {"slam": ["wormGrowWind", {}], "grasp": ["slamWind", {"dur": CLAP_LEAD}], "spit": ["sauceWind", {"dur": 0.9}], "shock": ["summonWind", {"dur": 1.1}], "birth": ["summonWind", {"dur": 1.4}], "skyfall": ["screamWind", {"dur": 0.6}], "swallow": ["meatSwell", {}], "heart": ["ringerWind", {"dur": HT_FIRST}], "whirl": ["tongueWind", {"dur": WHIRL_WIND}], "expose": ["stagger", {}]}.get(nm)
	if cue != null:
		var o: Dictionary = {"range": 80.0, "ref": 14.0}
		o.merge(cue[1], true)
		L.sfx_at(cue[0], 0.0, hy, 0.0, o)
	if nm == "spit":
		tiles_want(cycle % 3, phase >= 3)
	elif nm == "slam" and phase >= 2:
		tiles_want((cycle + 1) % 3)
	elif nm == "expose" or nm == "birth":
		tiles_want(-1)


func _alive_kids(C: Combat) -> int:
	var n := spawn_q.size()
	for r: Robot in C.enemies.robots:
		if r.get_meta("boss_spawn", false) and not r.dead:
			n += 1
	return n


func update(dt: float, P: Player, C: Combat, time: float) -> void:
	last_p = P
	var cn := mode != "dormant" and mode != "dead"
	for s: World.Solid in cam_solids:
		s.set_no_cam(cn)
	_veil_step(dt, P)
	_tiles_step(dt, time)
	if T == null:
		return
	T.x = 0.0
	T.z = 0.0
	T.bx = 0.0
	T.bz = 0.0
	T.y = floor_y()
	T.kx = 0.0
	T.kz = 0.0
	T.respawn_t = 1e9
	var dead := P.dead
	if dead and (mode == "intro" or mode == "fight"):
		reset(C)
	if mode == "dormant":
		T.hp = T.max
		T.dead = false
		last_hp = T.max
		if not dead and not cine_seen and P.y > TOP_Y - 1.0 and U.hyp(P.x, P.z) < ARENA_R - 2.0 and L.cine.start(P):      # the first time: her entrance cutscene
			cine_seen = true
			begin_cine()
			return
		if not dead and P.y > TOP_Y - 1.0 and U.hyp(P.x, P.z) < ARENA_R - 3.5:
			mode = "intro"
			t_ = 0.0
			gate_solid.set_off(false)
			gate_mesh.visible = true
			label = ""
			L.banner("THE MAWMOTHER", "THE SPIRE WAKES AROUND YOU", 4.0)
			L.toast("THE MAWMOTHER WAKES")
		return
	if mode == "dead":
		return
	if mode == "cine":      # the cutscene poses her and calls end_cine()
		T.hp = T.max
		T.dead = false
		last_hp = T.max
		t_ += dt
		return
	t_ += dt
	var d := last_hp - T.hp
	if mode == "intro" or move_ == "roar":      # waking / roaring: nothing gets through
		T.hp = last_hp
		T.dead = false
	elif d > 0.0 and mode == "fight":
		var mult := EXPOSE_MULT if exposed else (THROAT_MULT if vuln > 0.0 else ARMOUR)      # hide (armour) < open throat (the swallow) < the open maw (exposed)
		var floor_hp: float = T.max * PHASE2_AT - 1.0 if phase == 1 else (T.max * PHASE3_AT - 1.0 if phase == 2 else 0.0)      # each phase is earned: no skipping one with a big hit
		T.hp = maxf(floor_hp, last_hp - d * mult)
		T.dead = T.hp <= 0.0
		if mult < 1.0:
			hide_ += d
			if not hinted and hide_ > 260.0:
				hinted = true
				L.toast("HER HIDE SHRUGS IT OFF - HIT THE MAW WHEN SHE OPENS UP")
		hit_k = minf(1.0, hit_k + d / 120.0 * (1.0 if mult > 1.0 else 0.35))      # drives the HUD bar's flash: gold on the maw, dull on the hide
	hit_k = maxf(0.0, hit_k - dt * 3.0)
	last_hp = T.hp
	if mode != "dying" and T.hp <= 0.0:
		_die(C)
		return
	# mercy: after a real hit you get a moment of invulnerability (her hits and the brood's never stack)
	if P.hp < p_hp - 7.0 and not P.dead:
		P.invuln = maxf(P.invuln, MERCY)
	p_hp = P.hp
	if mode == "intro":
		raise = SpireMechs.sstep(t_ / 1.5) * (1.0 if t_ < 2.4 else 1.0 - SpireMechs.sstep((t_ - 2.4) / 0.6))
		jaw = 1.0 if (t_ > 0.8 and t_ < 2.2) else 0.0
		if t_ > 3.0:
			mode = "fight"
			gap = 0.8
			move_ = ""
		return
	if mode == "dying":
		_dying(dt, C)
		return
	var dy := atan2(P.x, P.z) - yaw
	dy = atan2(sin(dy), cos(dy))
	yaw += clampf(dy, -1.3 * dt, 1.3 * dt)
	var want_phase := 3 if T.hp < T.max * PHASE3_AT else (2 if T.hp < T.max * PHASE2_AT else 1)
	if want_phase > phase:      # crossing a phase line: she rears up and roars, then the next phase starts
		phase = want_phase
		wave_t = minf(wave_t, 4.0)
		exposed = false
		move_ = "roar"
		mt = 0.0
		step = 0
		label = ""
		idx = 0
		marks.clear()
		strips.clear()
		tiles_want(-1)
		L.toast("THE MAWMOTHER BLEEDS RAGE" if want_phase == 2 else "THE MAWMOTHER TEARS HERSELF OPEN")
		C.events.append({"t": &"meatBoom", "id": 9000, "x": 0.0, "y": TOP_Y + 6.0, "z": 0.0, "r": 6.0, "big": true})
		if want_phase == 2:
			L.banner("PHASE II", "SHE BLEEDS RAGE", 2.2)
		else:
			L.banner("PHASE III", "SHE TEARS HERSELF OPEN", 2.2)
		L.sfx_at("screamCall", 0.0, TOP_Y + 10.0, 0.0, {"range": 90.0, "ref": 16.0})
		L.sfx_at("meatBoom", 0.0, TOP_Y + 4.0, 0.0, {"range": 90.0, "ref": 16.0})
		L.refresh_pods()      # the spire feeds you: the arena's ammo pods regrow at once
	if move_ != "roar":      # reinforcement waves: a squad (grunts, sacs, later brutes and prophets) rises round the rim every so often
		wave_t -= dt
		if wave_t <= 0.0:
			wave_t = WAVE_PER[phase - 1]
			if _alive_kids(C) < WAVE_BELOW[phase - 1]:
				_spawn_kids(C, WAVE_N[phase - 1], floor_y(), true, WAVE_MAX)
				L.toast("THE BROOD RISES" if phase == 1 else "MORE BROOD")
	if move_ != "swallow":
		vuln = 0.0
		warn = false
	if move_ != "roar" and not exposed:      # she never stops birthing: a steady trickle of brood keeps the pressure on between moves
		trickle_t -= dt
		if trickle_t <= 0.0:
			trickle_t = TRICKLE[phase - 1]
			if _alive_kids(C) < BIRTH_MAX - 2:
				_spawn_kids(C, 1, floor_y())
	if move_ == "":
		gap -= dt
		label = ""
		raise += (0.0 - raise) * minf(1.0, dt * 4.0)
		jaw += (0.0 - jaw) * minf(1.0, dt * 4.0)
		lift += (0.0 - lift) * minf(1.0, dt * 4.0)
		if gap <= 0.0:
			var sq: Array = SEQS.get(phase, SEQS[1])
			begin_move(sq[idx % sq.size()])
			idx += 1
	else:
		_move(dt, P, C)
	slap = maxf(0.0, slap - dt * 1.6)
	_sky_step(dt, P, C)
	_hearts_step(dt, P, C)
	if not spawn_q.is_empty():      # brood waiting to appear: one is built per frame, so a wave never costs one big frame
		var q: Dictionary = spawn_q.pop_front()
		var rb := Game.spawn_enemy({"x": q.x, "y": q.y, "z": q.z, "yaw": atan2(-float(q.x), -float(q.z))}, {"kind": q.kind})
		if rb != null:
			rb.set_meta("boss_spawn", true)
			rb.set_meta("boss_kind", q.kind)
			rb.corpse_t = 2.5
			rb.set_meta("zone", L.arena_zone)
			rb.respawn_t = 1e9
	var fy := floor_y()
	for i in range(rings.size() - 1, -1, -1):
		var q: Dictionary = rings[i]
		q.r = float(q.r) + float(q.v) * dt
		if not q.hit and not P.dead:
			var dist := U.hyp(P.x, P.z)
			if absf(dist - float(q.r)) < 0.95 and P.y < fy + 0.85 and P.y > fy - 1.2:
				q.hit = true
				if _hurt(C, P, SHOCK_DMG, 0.0, 0.0, "shock"):
					var l := dist if dist != 0.0 else 1.0
					_knock(P, P.x / l, P.z / l, 12.0, 5.0)
		if float(q.r) > ARENA_R + 1.0:
			rings.remove_at(i)


func _count_kind(C: Combat, k: String) -> int:
	var n := 0
	for r: Robot in C.enemies.robots:
		if r.get_meta("boss_spawn", false) and not r.dead and r.get_meta("boss_kind", "") == k:
			n += 1
	for q: Dictionary in spawn_q:
		if q.kind == k:
			n += 1
	return n


func _pick_kind(C: Combat) -> String:
	var list: Array = KINDS.get(phase, KINDS[1])
	for k in list.size():
		var kd: String = list[(spawn_n + k) % list.size()]
		var cap: Variant = KIND_CAP.get(kd)
		if cap == null or _count_kind(C, kd) < int(cap[phase - 1]):
			spawn_n += k + 1
			return kd
	spawn_n += 1
	return "follower"


## the brood: followers, blister sacs, then brutes and prophets as she bleeds; n of them, capped by cap. ring: they come up round the rim instead of out of her.
func _spawn_kids(C: Combat, n: int, fy: float, ring: bool = false, cap: int = BIRTH_MAX) -> void:
	var want := mini(n, cap - _alive_kids(C))
	for _i in want:
		for _t in 14:
			var a := randf() * TAU
			var rad := randf_range(10.0, ARENA_R - 4.5) if ring else 6.0
			var px := sin(a) * rad
			var pz := cos(a) * rad
			if not L.free_spot(px, pz, fy):
				continue
			if last_p != null and U.hyp(px - last_p.x, pz - last_p.z) < 5.0:      # never right on top of you
				continue
			spawn_q.append({"x": px, "z": pz, "y": fy, "kind": _pick_kind(C)})
			C.events.append({"t": &"summon", "x": px, "y": fy + 0.3, "z": pz})
			break


# ---------------------------------------------------------------------------------------------- set-piece logic
## SKYFALL: a slab falls on (x, z); keep ones stay as cover / ledges after landing
func _sky_spawn(x: float, z: float, keep: bool) -> void:
	var it: Dictionary = {}
	for q: Dictionary in sky:
		if int(q.st) == 0:
			it = q
			break
	if it.is_empty():
		for q: Dictionary in sky:
			if int(q.st) == 2 and (it.is_empty() or float(q.rest) < float(it.rest)):
				it = q
	if it.is_empty():
		return
	(it.s as World.Solid).set_off(true)
	it.st = 1
	it.x = x
	it.z = z
	it.t = 0.0
	it.keep = keep
	it.spin = randf_range(-3.0, 3.0)


func _sky_vis(it: Dictionary, v: bool) -> void:
	(it.g as Node3D).visible = v
	(it.ring as Node3D).visible = v
	(it.fill as Node3D).visible = v


func _sky_step(dt: float, P: Player, C: Combat) -> void:
	var fy := TOP_Y      # the tiles (not the breathing centre) are the floor out here
	for it: Dictionary in sky:
		var g: Node3D = it.g
		var s: World.Solid = it.s
		var st: int = it.st
		var x: float = it.x
		var z: float = it.z
		if st == 0:
			if g.visible:
				_sky_vis(it, false)
			continue
		if st == 1:
			it.t = float(it.t) + dt
			var tt: float = it.t
			var a := clampf(tt / SKY_LEAD, 0.0, 1.0)
			var ring: Node3D = it.ring
			var fill: Node3D = it.fill
			ring.visible = true
			fill.visible = true
			ring.position = Vector3(x, fy + 0.3, z)
			fill.position = Vector3(x, fy + 0.28, z)
			L.set_alpha(it.ring_m, 0.45 + 0.35 * absf(sin(tt * (10.0 + 14.0 * a))))
			fill.scale = Vector3.ONE * maxf(0.05, a)
			L.set_alpha(it.fill_m, 0.12 + 0.3 * a)
			g.visible = true
			g.position = Vector3(x, fy + 0.03 + (1.0 - a) * (1.0 - a) * 26.0, z)
			g.rotation = Vector3(tt * float(it.spin), tt * 1.3, 0.0)
			if tt >= SKY_LEAD:      # impact
				ring.visible = false
				fill.visible = false
				g.rotation = Vector3(0.0, it.spin, 0.0)
				g.position = Vector3(x, fy + 0.03, z)
				slap = 0.6
				C.events.append({"t": &"wormSlam", "x": x, "y": fy, "z": z, "r": SKY_R + 0.4})
				C.events.append({"t": &"summon", "x": x, "y": fy + 0.5, "z": z})
				view.crack_place(x, fy, z, 3.2)
				if P != null and not P.dead and U.hyp(P.x - x, P.z - z) < SKY_R and P.y < fy + 2.4 and _hurt(C, P, SKY_DMG, x, z, "melee"):
					var l := U.hyp(P.x - x, P.z - z)
					if l == 0.0:
						l = 1.0
					_knock(P, (P.x - x) / l, (P.z - z) / l, 9.0, 6.0)
				for r: Robot in C.enemies.robots:
					if not r.dead and U.hyp(r.x - x, r.z - z) < SKY_R + 0.4:      # bait her slabs onto the brood
						C.damage(r, 600.0, T, 0.0, null)
				if it.keep and not (P != null and U.hyp(P.x - x, P.z - z) < 1.7):
					it.st = 2
					it.rest = SKY_REST
					s.place(x, z)
					s.set_span(fy - 0.3, fy + 1.7)
					s.set_off(false)
				else:
					it.st = 0
					g.visible = false
		else:      # resting: cover and a ledge; it crumbles away
			it.rest = float(it.rest) - dt
			var rest: float = it.rest
			g.position.y = fy + 0.03 - ((1.0 - rest) * 2.4 if rest < 1.0 else 0.0)
			if rest <= 0.0:
				it.st = 0
				s.set_off(true)
				g.visible = false


func _sky_clear() -> void:
	for it: Dictionary in sky:
		it.st = 0
		(it.s as World.Solid).set_off(true)
		_sky_vis(it, false)


## THE SWALLOW
func _pull_in(P: Player, C: Combat, v: float, dt: float) -> void:
	if P != null and not P.dead:
		var d := U.hyp(P.x, P.z)
		if d > 5.3:
			var k := minf(v * dt, d - 5.3) / d
			P.x -= P.x * k
			P.z -= P.z * k
	for r: Robot in C.enemies.robots:
		if r.get_meta("boss_spawn", false) and not r.dead:
			var d := U.hyp(r.x, r.z)
			if d > 5.3:
				var k := minf(v * 0.8 * dt, d - 5.3) / d
				r.x -= r.x * k
				r.z -= r.z * k


func _chomp(P: Player, C: Combat) -> void:
	var fy := floor_y()
	slap = 1.0
	lift = 1.0
	chomped = true
	C.events.append({"t": &"meatBoom", "id": 9000, "x": 0.0, "y": fy + 3.0, "z": 0.0, "r": SW_CHOMP_R, "big": true})
	if P != null and not P.dead:
		var d := U.hyp(P.x, P.z)
		if d < SW_CHOMP_R and P.y < fy + 3.5 and _hurt(C, P, SW_DMG, 0.0, 0.0, "melee"):
			var l := d if d != 0.0 else 1.0
			_knock(P, P.x / l, P.z / l, 14.0, 7.0)
	for r: Robot in C.enemies.robots:
		if not r.dead and U.hyp(r.x, r.z) < SW_CHOMP_R + 0.5:      # whatever you dragged in with you gets eaten
			C.damage(r, 1e4, T, 0.0, null)


## HEARTSTORM: which floor cell is (x, z) in, and does beat k erupt it? (a checkerboard that flips every beat)
func _cell_at(x: float, z: float) -> Dictionary:
	var d := U.hyp(x, z)
	if d < HT_R0 or d > TILE_OUT:
		return {}
	var b := mini(HBANDS - 1, floori((d - HT_R0) / (TILE_OUT - HT_R0) * HBANDS))
	var a := fposmod(atan2(x, z) - gate_a, TAU)
	return cells[b * TILES + mini(TILES - 1, floori(a / (TAU / TILES)))]


func cell_active(c: Dictionary, k: int) -> bool:
	return ((int(c.i) + int(c.b) + hb + k) & 1) == 0


func _heart_erupt(k: int, P: Player, C: Combat) -> void:
	var fy := floor_y()
	lift = 1.0
	var ev := 0
	for c: Dictionary in cells:
		if cell_active(c, k):
			c.hot = 1.0
			if ev < 8 and (int(c.i) * 7 + int(c.b) * 3 + k) % 4 == 0:
				ev += 1
				var am := gate_a + (int(c.i) + 0.5) * TAU / TILES
				var rm := (float(c.r0) + float(c.r1)) * 0.5
				C.events.append({"t": &"wormSlam", "x": sin(am) * rm, "y": fy, "z": cos(am) * rm, "r": 1.8})
	if P != null and not P.dead and P.y < fy + 1.0:
		var c := _cell_at(P.x, P.z)
		if not c.is_empty() and cell_active(c, k) and _hurt(C, P, HT_DMG, 0.0, 0.0, "melee"):
			_knock(P, 0.0, 0.0, 0.0, 6.5)
	for r: Robot in C.enemies.robots:
		if not r.dead and r.y < fy + 1.0:
			var c := _cell_at(r.x, r.z)
			if not c.is_empty() and cell_active(c, k):
				C.damage(r, 250.0, T, 0.0, null)


func _tracking(k: float, dt: float) -> void:
	raise += (k - raise) * minf(1.0, dt * 6.0)


func _move(dt: float, P: Player, C: Combat) -> void:
	var ph := phase
	var p2 := ph >= 2
	var p3 := ph >= 3
	mt += dt
	var fy := floor_y()
	match move_:
		"roar":
			_tracking(1.0, dt)
			lift += (1.0 - lift) * minf(1.0, dt * 6.0)
			jaw += (1.0 - jaw) * minf(1.0, dt * 8.0)
			if step == 0 and mt >= 1.1:
				step = 1
				_spawn_kids(C, 3 if p3 else 2, fy)
				rings.append({"r": 4.6, "v": 7.0, "hit": false})      # the roar's blast: one slow ring to jump
			if mt > 2.0:
				_end_move()
		"slam":
			var N := SLAM_N + (ph - 1)
			var per := SLAM_PER * (0.82 if p2 else 1.0) * (0.92 if p3 else 1.0)
			var lead: float = SLAM_LEAD[ph - 1]
			_tracking(1.0, dt)
			while step < N and mt >= step * per:
				marks.append({"x": P.x, "z": P.z, "y": P.y, "t0": mt, "hit": false, "slot": step % 4, "lead": step % 2 == 1, "locked": false, "cracked": false})      # every other mark leads you: running in one circle gets you hit, changing direction does not
				step += 1
			var lock_at := lead * SLAM_LOCK
			for m: Dictionary in marks:
				var age: float = mt - float(m.t0)
				if age < lock_at:
					var k := (lead - age) * 0.8 if m.lead else 0.0      # a leading mark sits where you will be when the claw lands, if you keep going
					var lim := ARENA_R - 2.2
					var tx := P.x + P.vx * k
					var tz := P.z + P.vz * k
					var tl := U.hyp(tx, tz)
					if tl > lim:
						tx *= lim / tl
						tz *= lim / tl
					m.x = lerpf(m.x, tx, minf(1.0, dt * 8.0))
					m.z = lerpf(m.z, tz, minf(1.0, dt * 8.0))
					if P.grounded:
						m.y = P.y
				if not m.locked and age >= lock_at:
					m.locked = true      # the claw commits: its scream rises until it lands
					L.sfx_at("slamWind", m.x, m.y, m.z, {"dur": lead - lock_at, "range": 40.0})
				if not m.hit and age >= lead:
					m.hit = true
					var mx: float = m.x
					var my: float = m.y
					var mz: float = m.z
					C.events.append({"t": &"summon", "x": mx, "y": my + 0.4, "z": mz})
					slap = 0.6
					if not P.dead and U.hyp(P.x - mx, P.z - mz) < SLAM_R and P.y < my + 2.4 and _hurt(C, P, SLAM_DMG, mx, mz, "melee"):
						var l := U.hyp(P.x - mx, P.z - mz)
						if l == 0.0:
							l = 1.0
						_knock(P, (P.x - mx) / l, (P.z - mz) / l, 9.0, 6.0)
			if step >= N and mt > (N - 1) * per + lead + 1.1:
				_end_move()
		"skyfall":
			# SKYFALL: slabs of bone crash down on glowing circles. One circle in each volley leads you, the rest are scattered. Some stay behind as cover (they block her bile) and ledges.
			var N: int = SKY_N[ph - 1]
			var per: float = SKY_PER[ph - 1]
			var vol: int = SKY_VOL[ph - 1]
			_tracking(1.0, dt)
			jaw += (0.6 - jaw) * minf(1.0, dt * 6.0)
			while step < N and mt >= 0.5 + step * per:
				var lim := ARENA_R - 2.5
				var lx := P.x + P.vx * 0.55
				var lz := P.z + P.vz * 0.55
				var ll := U.hyp(lx, lz)
				if ll == 0.0:
					ll = 1.0
				var k := lim / ll if ll > lim else 1.0
				_sky_spawn(lx * k, lz * k, false)
				for v in range(1, vol):      # scattered ones: away from you, one another and her body
					for _t in 8:
						var a := randf() * TAU
						var rad := randf_range(7.0, lim)
						var x := sin(a) * rad
						var z := cos(a) * rad
						if U.hyp(x - P.x, z - P.z) < 4.5:
							continue
						var clash := false
						for q: Dictionary in sky:
							if int(q.st) == 1 and U.hyp(float(q.x) - x, float(q.z) - z) < 4.6:
								clash = true
								break
						if clash:
							continue
						_sky_spawn(x, z, (step + v) % SKY_KEEP_EVERY == 0)
						break
				step += 1
			if step >= N and mt > 0.5 + (N - 1) * per + SKY_LEAD + 1.0:
				_end_move()
		"swallow":
			# THE SWALLOW: she inhales; everything slides towards her. The pull is slower than a run, so keep running OUT; the last second shows the chomp zone. Shots land harder while she inhales.
			var TT: float = SW_T[ph - 1]
			var t0 := 0.7
			vuln = 0.0
			_tracking(0.3, dt)
			jaw += (1.0 - jaw) * minf(1.0, dt * 8.0)
			if mt >= t0 and mt < TT:
				_pull_in(P, C, SW_PULL * SpireMechs.sstep((mt - t0) / 1.4), dt)
				core += (1.0 - core) * minf(1.0, dt * 6.0)
				vuln = SW_VULN
			warn = mt > TT - SW_WARN and mt < TT
			if step == 0 and mt >= TT:
				step = 1
				_chomp(P, C)
				label = LABEL.expose
			if step == 1:
				exposed = mt < TT + SW_EXPOSE
				core += ((1.0 if exposed else 0.0) - core) * minf(1.0, dt * 8.0)
				if not exposed:
					jaw += (0.0 - jaw) * minf(1.0, dt * 6.0)
			lift += (0.0 - lift) * minf(1.0, dt * 7.0)
			if mt > TT + SW_EXPOSE + 0.8:
				_end_move()
		"heart":
			# HEARTSTORM: the floor is a checkerboard; every beat the glowing half erupts, one beat after it lit up. Hop to the dark half on the beat (a slab or a jump also clears it).
			var N: int = HT_BEATS[ph - 1]
			var g: float = HT_GAP[ph - 1]
			_tracking(0.1, dt)
			lift += (0.0 - lift) * minf(1.0, dt * 7.0)
			jaw += (0.15 - jaw) * minf(1.0, dt * 6.0)
			if step == 0 and mt < 0.05:
				hb = 0 if randf() < 0.5 else 1
			while step < N and mt >= HT_FIRST + step * g:
				_heart_erupt(step, P, C)
				step += 1
			if step >= N and mt > HT_FIRST + (N - 1) * g + 1.2:
				_end_move()
		"whirl":
			# TENDRIL WHIRL: she flattens her arms, three (two earlier) of them rise as bone-spiked lashes and she spins on the spot. Jump each lash as it passes.
			var wind := WHIRL_WIND
			var TT := WHIRL_T * (0.85 if p3 else 1.0)
			var n := 3 if p3 else 2
			_tracking(0.4, dt)
			if whirl == null:
				whirl = {"a0": atan2(P.x, P.z), "dir": -1.0 if clap_n % 2 != 0 else 1.0, "hit": false, "n": n}
			var w: Dictionary = whirl
			var a0: float = w.a0
			var dir: float = w.dir
			var ang := a0 + (0.0 if mt < wind else dir * SpireMechs.sstep((mt - wind) / TT) * TAU * 1.25)
			whirl_ang = ang - a0
			whirl_u = clampf(mt / wind, 0.0, 1.0) * (maxf(0.0, 1.0 - (mt - wind - TT - 0.3) / 0.5) if mt > wind + TT + 0.3 else 1.0)
			if mt >= wind and mt < wind + TT and not P.dead and not w.hit and P.y - fy < 1.1:
				var d := U.hyp(P.x, P.z)
				if d > 4.3 and d < ARENA_R - 0.8:
					var pa := atan2(P.x, P.z)
					for k in n:
						var cur := a0 + k * TAU / n + whirl_ang
						var prev := cur - dir * 0.12
						var dd := atan2(sin(pa - cur), cos(pa - cur))
						var pd := atan2(sin(pa - prev), cos(pa - prev))
						if absf(dd) < 0.14 + 1.0 / d * 0.3 or (dd * pd < 0.0 and absf(dd - pd) < 1.0):
							w.hit = true
							if _hurt(C, P, WHIRL_DMG, 0.0, 0.0, "melee"):
								var l := d if d != 0.0 else 1.0
								_knock(P, P.x / l, P.z / l, WHIRL_PUSH, 5.0)
							break
			if mt > wind + TT + 0.9:
				whirl = null
				whirl_u = 0.0
				_end_move()
		"grasp":
			# CRUSHING CLAP: two huge arms smash down along a whole line through the arena (a red strip shows it; it follows you, then locks). Stand outside the strip; phase 3 sends two.
			var n_strips := 2 if (p3 and clap_n % 2 == 0) else 1
			var lead := CLAP_LEAD * (0.85 if p3 else 1.0)
			_tracking(1.0, dt)
			while step < n_strips and mt >= step * CLAP_GAP:
				var a0 := atan2(P.x, P.z) + (PI * 0.5 + (randf() - 0.5) * 0.5 if step != 0 else 0.0)
				strips.append({"a": a0, "t0": mt, "hit": false, "locked": false, "i": step, "cracked": false})
				step += 1
			for q: Dictionary in strips:
				var age: float = mt - float(q.t0)
				if age < lead * 0.6:
					if int(q.i) == 0:
						var d: float = atan2(P.x, P.z) - float(q.a)
						d = atan2(sin(d), cos(d))
						q.a = float(q.a) + d * minf(1.0, dt * 5.0)
				else:
					q.locked = true
				if not q.hit and age >= lead:
					q.hit = true
					slap = 1.0
					var a: float = q.a
					for k in range(-3, 4):
						C.events.append({"t": &"wormSlam", "x": sin(a) * k * 4.4, "y": fy, "z": cos(a) * k * 4.4, "r": 2.4})
					if not P.dead and P.y < fy + 2.2:
						var perp := P.x * cos(a) - P.z * sin(a)
						if absf(perp) < CLAP_W and _hurt(C, P, CLAP_DMG, 0.0, 0.0, "melee"):
							var sgn := 1.0 if perp >= 0.0 else -1.0
							_knock(P, cos(a) * sgn, -sin(a) * sgn, CLAP_PUSH, 6.0)
			if step >= n_strips and mt > (n_strips - 1) * CLAP_GAP + lead + 1.3:
				strips.clear()
				_end_move()
		"spit":
			var V := SPIT_V + (1 if p2 else 0)
			var g := SPIT_GAP * (0.8 if p2 else 1.0) * (0.92 if p3 else 1.0)
			var fan := SPIT_FAN + (2 if p2 else 0) + (1 if p3 else 0)
			var wind := 0.95 + TILE_WARN * 0.5
			_tracking(0.2, dt)
			jaw += ((1.0 if mt > wind - 0.35 else 0.4) - jaw) * minf(1.0, dt * 8.0)
			while step < V and mt >= wind + step * g:
				step += 1
				var ox := sin(yaw) * 3.4
				var oy := fy + 10.0
				var oz := cos(yaw) * 3.4
				var lt := U.hyp(P.x - ox, P.z - oz) / SPIT_SPEED * 0.85 if step % 2 == 0 else 0.0      # every other volley is aimed where you are going: strafing one way is not enough, cut back
				var dd := Vector3(P.x + P.vx * lt - ox, P.y + 1.0 - oy, P.z + P.vz * lt - oz).normalized()
				L.sfx_at("spitDart", ox, oy, oz, {"range": 60.0})
				for i in fan:
					var a := (i - (fan - 1) * 0.5) * SPIT_SPREAD
					var ca := cos(a)
					var sa := sin(a)
					C.enemies.fire_from(9000, ox, oy, oz, dd.x * ca + dd.z * sa, dd.y, -dd.x * sa + dd.z * ca, {"kind": "bile", "speed": SPIT_SPEED, "dmg": SPIT_DMG + (1.0 if p2 else 0.0), "r": 0.4})
			if step >= V and mt > wind + (V - 1) * g + 0.9:
				_end_move()
				tiles_want(-1)
		"shock":
			var N := SHOCK_N + (1 if p2 else 0)
			var g := SHOCK_GAP * (0.85 if p2 else 1.0) * (0.9 if p3 else 1.0)
			var t0 := 1.15
			_tracking(1.0, dt)
			lift += ((1.0 if mt < t0 else 0.0) - lift) * minf(1.0, dt * 7.0)
			while step < N and mt >= t0 + step * g:
				step += 1
				rings.append({"r": 4.6, "v": SHOCK_SPEED * (1.15 if p2 else 1.0) * (1.08 if p3 else 1.0), "hit": false})
				C.events.append({"t": &"meatBoom", "id": 9000, "x": 0.0, "y": fy + 0.6, "z": 0.0, "r": 3.0, "big": false})
			if step >= N and mt > t0 + (N - 1) * g + 1.7:
				_end_move()
				tiles_want(-1)
		"birth":
			_tracking(0.5, dt)
			jaw += ((1.0 if mt < 1.4 else 0.2) - jaw) * minf(1.0, dt * 6.0)
			if step == 0 and mt >= 1.4:
				step = 1
				_spawn_kids(C, BIRTH_N + (1 if p2 else 0), fy)
			if mt > 4.4:
				_end_move()
		"expose":
			var T0 := EXPOSE_T * (0.78 if p3 else (0.88 if p2 else 1.0))
			exposed = mt > 0.5 and mt < T0 + 0.5
			jaw += ((1.0 if exposed else 0.0) - jaw) * minf(1.0, dt * 8.0)
			_tracking(0.0, dt)
			core += ((1.0 if exposed else 0.0) - core) * minf(1.0, dt * 8.0)
			if mt > T0 + 1.0:
				_end_move()
		_:
			_end_move()


func _end_move() -> void:
	vuln = 0.0
	warn = false
	chomped = false
	whirl = null
	whirl_u = 0.0
	move_ = ""
	label = ""
	exposed = false
	marks.clear()
	strips.clear()
	gap = GAP * (0.5 if phase >= 3 else (0.7 if phase == 2 else 1.0))


func _die(C: Combat) -> void:
	mode = "dying"
	dying_t = 0.0
	boom_t = 0.0
	exposed = false
	move_ = ""
	label = ""
	marks.clear()
	rings.clear()
	strips.clear()
	tiles_want(-1)
	_sky_clear()
	spawn_q.clear()
	T.dead = true
	T.hp = 0.0
	for r: Robot in C.enemies.robots:
		if r.get_meta("boss_spawn", false) and not r.dead:
			C.damage(r, 1e4, T, 0.0, null)
	L.toast("THE MAWMOTHER FALLS")


func _dying(dt: float, C: Combat) -> void:
	dying_t += dt
	boom_t -= dt
	T.dead = true
	T.respawn_t = 1e9
	if boom_t <= 0.0:
		boom_t = 0.32
		var a := randf() * TAU
		var r := randf() * 4.0
		C.events.append({"t": &"meatBoom", "id": 9000, "x": sin(a) * r, "y": TOP_Y + randf_range(1.0, 9.0), "z": cos(a) * r, "r": 4.0, "big": dying_t > 3.0})
	raise += (0.0 - raise) * minf(1.0, dt * 3.0)
	jaw += (1.0 - jaw) * minf(1.0, dt * 3.0)
	if dying_t > 4.2:
		mode = "dead"
		boss_root.visible = false
		body_solid.set_off(true)
		gate_solid.set_off(true)
		gate_mesh.visible = false
		L.banner("THE SPIRE IS YOURS", "THE MAWMOTHER IS DEAD", 7.0)
		L.toast("LEVEL COMPLETE")
