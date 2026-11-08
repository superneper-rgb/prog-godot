class_name WhSetPieces
extends RefCounted
## "The building fights back" (JS levels/warehouse/setpieces.js): shootable Volt Drums, telegraphed falling freight, Freight-pit crew lifts up to the staging gantries (whose staged loads can be released onto the lane below) and the escape-wing Slag Compactor. No rendering here (the visuals read `S`).

var K: Dictionary = WhData.TUNING.setpieces
var world: World
var level: WarehouseLevel
var C: Combat = null
var stage := ""
var drums: Array[Dictionary] = []
var drops: Array[Dictionary] = []
var pads: Array[Dictionary] = []
var loads: Array[Dictionary] = []
var chase := {"phase": "idle", "x": 0.0, "t": 0.0, "rise": 0.0, "retries": 0, "dist": 99.0, "speed": 0.0, "danger": false}
var stats := {"blasts": 0, "blast_kills": 0, "hauled": 0, "launches": 0, "retries": 0, "compacted": 0, "released": 0}
var drop_taught := false
var _seed := 1987
var _next_id := 98000
var _drop_clock := 1e9
var _load_solids: Dictionary = {}
var _env_alive := 0
var _env_busy := false


func _init(p_level: WarehouseLevel) -> void:
	level = p_level
	world = p_level.world
	# Staged loads are physical: each owns a collision box, solid only while staged.
	var list: Dictionary = WhData.PROPS.loads
	for st: String in list:
		for q: Array in list[st]:
			for s: World.Solid in world.solids:
				if s.tag != "guard" and s.data.get("id", "") == "freight staged load" and is_equal_approx(s.cx, float(q[0])) and is_equal_approx(s.cz, float(q[1])):
					_load_solids["%s%s,%s" % [st, q[0], q[1]]] = s
	for s: World.Solid in _load_solids.values():
		s.set_off(true)


## JS rng: mulberry32
func _rand() -> float:
	_seed = (_seed + 0x6D2B79F5) & 0xFFFFFFFF
	var a := _seed
	var t := _imul(a ^ (a >> 15), 1 | a)
	t = ((t + _imul(t ^ (t >> 7), 61 | t)) & 0xFFFFFFFF) ^ t
	return ((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0


static func _imul(a: int, b: int) -> int:
	return (a * b) & 0xFFFFFFFF


func _detach(t: Target) -> void:
	if C != null:
		C.targets.erase(t)


func _floor_at(x: float, z: float, y: float) -> Variant:
	var g := world.ground_height(x, z, 0.4, y + 0.6)
	return g if is_finite(g) and absf(g - y) < 0.8 else null


func bind(combat: Combat) -> void:
	if combat == null or combat == C:
		return
	C = combat
	for p: Dictionary in drums + loads:
		if p.alive and not C.targets.has(p.target):
			C.targets.append(p.target)


func _make(kind: String, x: float, z: float, g: float, r: float, h: float, hp: float) -> Dictionary:
	var t := Target.new(_next_id, x, z, g, {"r": r, "h": h, "max": hp, "hp": hp, "w": 0.0})
	_next_id += 1
	var p := {"kind": kind, "x": x, "y": g, "z": z, "target": t, "alive": true, "fuse": 0.0, "flash": 0.0, "id": t.id}
	t.data["setpiece"] = kind
	t.data["ref"] = p
	if C != null:
		C.targets.append(t)
	return p


## Stage entry (progression, retry or F6): props, pads and hazards are re-armed.
func enter(next: String, opts: Dictionary, combat: Combat) -> void:
	for p: Dictionary in drums:
		_detach(p.target)
	for p: Dictionary in loads:
		_detach(p.target)
	if combat != null:
		C = combat
	stage = next
	drums.clear()
	drops.clear()
	loads.clear()
	for s: World.Solid in _load_solids.values():
		s.set_off(true)
	var all_loads: Dictionary = WhData.PROPS.loads
	for q: Array in all_loads.get(next, []):
		var solid: World.Solid = _load_solids.get("%s%s,%s" % [next, q[0], q[1]])
		if solid == null:
			continue
		var p := _make("load", q[0], q[1], solid.bottom, 1.1, 1.7, K.load.hp)
		p.side = float(q[2])
		p.solid = solid
		p.drop_z = float(q[2]) * 14.2
		solid.set_off(false)
		loads.append(p)
	var all_drums: Dictionary = WhData.PROPS.drums
	for q: Array in all_drums.get(next, []):
		var g: Variant = _floor_at(q[0], q[1], q[2])
		if g != null:
			drums.append(_make("drum", q[0], q[1], g, 0.5, K.drum.height, K.drum.hp))
	pads.clear()
	for p: Dictionary in WhData.PADS:
		if p.stage == next:
			var c := p.duplicate()
			c.cool = 0.0
			c.flash = 0.0
			pads.append(c)
	var h: Variant = K.hauler.get(next)
	_drop_clock = float(h.first) if h != null else 1e9
	if opts.get("retry", false):
		stats.retries += 1
	var DX := float(WhData.DEPTH_X)
	if next == "escape":
		chase.retries = chase.retries + 1 if opts.get("retry", false) else 0
		chase.t = 0.0
		chase.rise = 0.0
		chase.speed = 0.0
		chase.dist = 99.0
		chase.danger = false
		if int(opts.get("index", 0)) == 1:
			chase.phase = "run"
			chase.x = DX + float(WhData.TUNING.variants.escape["1"].x) - 30.0 - float(K.chase.depth) / 2.0
			chase.rise = 1.0
		else:
			chase.phase = "rise"
			chase.x = DX + float(K.chase.riseX)
	elif not (next == "finale" and chase.phase == "done"):
		chase.phase = "idle"
		if not opts.get("retry", false):
			chase.retries = 0


# ---- Volt Drums ----
func _arm(d: Dictionary, fuse: float) -> void:
	if d.alive and float(d.fuse) <= 0.0:
		d.fuse = fuse
		d.flash = 0.0


func _detonate(d: Dictionary, P: Player) -> void:
	d.alive = false
	_detach(d.target)
	stats.blasts += 1
	var R := float(K.drum.radius)
	var kills := 0
	var dx: float = d.x
	var dy: float = d.y
	var dz: float = d.z
	C.events.append({"t": "explode", "x": dx, "y": dy + 0.7, "z": dz, "r": R * 0.85})
	for T: Target in C.targets.duplicate():
		if T == d.target or T.dead or T.npc or T.boss:
			continue
		var dist := U.hyp(T.x - dx, T.z - dz)
		if T.data.get("setpiece", "") == "drum":
			if dist < R + 1.2:
				_arm(T.data.ref, K.drum.chainFuse)
			continue
		var reach := R + T.r
		if dist > reach or absf(T.y - dy) > 4.0:
			continue
		var f := 1.0 - minf(1.0, dist / reach) * 0.5
		C.damage(T, float(K.drum.enemyDamage) * f, {"x": dx, "z": dz}, float(K.drum.knock) * f)
		if T.dead or T.hp <= 0.0:
			kills += 1
	var pd := U.hyp(P.x - dx, P.z - dz)
	if not P.dead and pd < float(K.drum.playerRadius) and absf(P.y - dy) < 2.6:
		C.hurt_player(P, float(K.drum.playerDamage) * (1.0 - pd / float(K.drum.playerRadius) * 0.5), dx, dz, "bolt")
	if kills > 0:
		stats.blast_kills += kills
		level.dir_message("VOLT BLAST x%d" % kills if kills > 1 else "VOLT BLAST")


# ---- Falling freight ----
func _pick_spot(P: Player, cfg: Dictionary) -> Variant:
	var robots: Array[Robot] = []
	for r: Robot in C.enemies.robots:
		if not r.dead and absf(r.y - float(cfg.floorY)) < 4.5 and U.hyp(r.x - P.x, r.z - P.z) < 24.0:
			robots.append(r)
	for _k in 12:
		var x: float
		var z: float
		if robots.size() > 0 and _rand() < float(cfg.targeted):
			var r: Robot = robots[int(_rand() * robots.size())]
			x = r.x + (_rand() - 0.5) * 1.5
			z = r.z + (_rand() - 0.5) * 1.5
		else:
			var a := _rand() * TAU
			var d := 4.0 + _rand() * 6.0
			x = P.x + sin(a) * d
			z = P.z + cos(a) * d
		var g := world.ground_height(x, z, 0.4, float(cfg.floorY) + 0.6)
		# Drops only ever land on the stage's base floor: raised perches stay safe.
		if not is_finite(g) or absf(g - float(cfg.floorY)) > 0.8 or world.blocked(x, z, g, 1.8, 0.4, 0.42):
			continue
		return {"x": x, "y": g, "z": z}
	return null


func _impact(q: Dictionary, P: Player) -> void:
	stats.hauled += 1
	var cfg: Dictionary = q.cfg
	var R := float(cfg.radius)
	var qx: float = q.x
	var qy: float = q.y
	var qz: float = q.z
	C.events.append({"t": "explode", "x": qx, "y": qy + 0.3, "z": qz, "r": R * 0.6})
	for T: Target in C.targets.duplicate():
		if T.dead or T.npc or T.boss:
			continue
		var dist := U.hyp(T.x - qx, T.z - qz)
		if dist > R + T.r or absf(T.y - qy) > 3.5:
			continue
		if T.data.get("setpiece", "") == "drum":
			_arm(T.data.ref, K.drum.chainFuse)
			continue
		C.damage(T, cfg.enemyDamage, {"x": qx, "z": qz}, 6.0)
	if not P.dead and U.hyp(P.x - qx, P.z - qz) < R and absf(P.y - qy) < 2.2:
		C.hurt_player(P, cfg.playerDamage, qx, qz, "bolt")


func _update_drops(dt: float, P: Player) -> void:
	var cfg: Variant = K.hauler.get(stage)
	if cfg != null and _env_alive > 0 and not _env_busy:
		_drop_clock -= dt
		if _drop_clock <= 0.0:
			_drop_clock = float(cfg.period[0]) + _rand() * (float(cfg.period[1]) - float(cfg.period[0]))
			var spot: Variant = _pick_spot(P, cfg)
			if spot != null:
				drops.append({"x": spot.x, "y": spot.y, "z": spot.z, "cfg": cfg, "t": 0.0, "landed": false, "land_t": 0.0})
				if not drop_taught:
					drop_taught = true
					level.dir_beat("firstDrop")
	for q: Dictionary in drops:
		q.t = float(q.t) + dt
		if not q.landed and float(q.t) >= float(q.cfg.warn):
			q.landed = true
			_impact(q, P)
		elif q.landed:
			q.land_t = float(q.land_t) + dt
	var i := drops.size() - 1
	while i >= 0:
		if float(drops[i].land_t) > 0.7:
			drops.remove_at(i)
		i -= 1


# ---- Staged gantry loads ----
func _update_loads() -> void:
	for p: Dictionary in loads:
		if not p.alive:
			continue
		var t: Target = p.target
		t.kx = 0.0
		t.kz = 0.0
		t.x = p.x
		t.bx = p.x
		t.z = p.z
		t.bz = p.z
		if t.hp >= t.max and not t.dead:
			continue
		# Clamp shot: the load tips off the lip onto the lane below, telegraphed.
		p.alive = false
		(p.solid as World.Solid).set_off(true)
		_detach(t)
		stats.released += 1
		var fl: Variant = _floor_at(p.x, p.drop_z, K.hauler.freight.floorY)
		var y: float = fl if fl != null else float(K.hauler.freight.floorY)
		var cfg: Dictionary = (K.hauler.freight as Dictionary).duplicate()
		cfg.warn = K.load.warn
		drops.append({"x": p.x, "y": y, "z": p.drop_z, "cfg": cfg, "t": 0.0, "landed": false, "land_t": 0.0, "gantry": {"x": p.x, "y": p.y, "z": p.z}})
		level.dir_message("GANTRY LOAD RELEASED")


# ---- Crew lift pads ----
func _update_pads(dt: float, P: Player) -> void:
	for p: Dictionary in pads:
		p.cool = maxf(0.0, float(p.cool) - dt)
		p.flash = maxf(0.0, float(p.flash) - dt * 3.0)
		if float(p.cool) > 0.0 or not P.grounded or P.dead or P.mode != &"normal":
			continue
		if U.hyp(P.x - float(p.x), P.z - float(p.z)) > float(K.pad.radius) or absf(P.y - float(p.y)) > 0.6:
			continue
		P.vy = K.pad.vy
		P.grounded = false
		P.air_jump = true
		P.jumping = false
		P.coyote_t = 0.0
		p.cool = K.pad.cooldown
		p.flash = 1.0
		stats.launches += 1
		C.events.append({"t": "respawn", "x": p.x, "y": float(p.y) + 0.5, "z": p.z})


# ---- Slag Compactor ----
func _update_chase(dt: float, P: Player) -> void:
	var ch := chase
	var cfg: Dictionary = K.chase
	if ch.phase == "rise":
		ch.t = float(ch.t) + dt
		ch.rise = minf(1.0, float(ch.t) / float(cfg.rise))
		if float(ch.t) >= float(cfg.rise):
			ch.phase = "run"
			level.dir_message("SLAG COMPACTOR / RUN FOR THE APRON")
	if ch.phase == "run":
		ch.speed = float(cfg.speed) * maxf(float(cfg.minMul), 1.0 - int(ch.retries) * float(cfg.retryEase))
		ch.x = float(ch.x) + float(ch.speed) * dt
		var stop := float(WhData.DEPTH_X) + float(cfg.stopX)
		if float(ch.x) >= stop:
			ch.x = stop
			ch.phase = "done"
			ch.speed = 0.0
			level.dir_message("COMPACTOR JAMMED AT THE DOCK")
	var front := float(ch.x) + float(cfg.depth) / 2.0
	ch.dist = P.x - front
	ch.danger = ch.phase == "run" and float(ch.dist) < float(cfg.warnAt)
	if ch.phase == "run" and not P.dead and float(ch.dist) < 0.0 and stage == "escape":
		ch.phase = "caught"
		stats.compacted += 1
		level.dir_message("COMPACTED / BACK TO THE VAULT DOOR")
		level.director.restore(P, C)


func update(dt: float, P: Player, combat: Combat, alive: int, busy: bool) -> void:
	_env_alive = alive
	_env_busy = busy
	bind(combat)
	if P == null or dt <= 0.0 or C == null:
		return
	for d: Dictionary in drums:
		if not d.alive:
			continue
		var t: Target = d.target
		t.kx = 0.0
		t.kz = 0.0
		t.x = d.x
		t.bx = d.x
		t.z = d.z
		t.bz = d.z
		if float(d.fuse) > 0.0:
			d.flash = float(d.flash) + dt
			d.fuse = float(d.fuse) - dt
			if float(d.fuse) <= 0.0:
				_detonate(d, P)
		elif t.hp < t.max or t.dead:
			_arm(d, K.drum.fuse)
	_update_loads()
	_update_drops(dt, P)
	_update_pads(dt, P)
	_update_chase(dt, P)


func reset_stats() -> void:
	for k: String in stats:
		stats[k] = 0


func rating(seconds: float) -> Dictionary:
	var R: Dictionary = K.rating
	var score := roundi(float(R.base) - seconds * float(R.perSecond) - int(stats.retries) * float(R.perRetry) + int(stats.blast_kills) * float(R.perBlastKill))
	var grade := "C"
	for g: Array in R.grades:
		if score >= float(g[0]):
			grade = g[1]
			break
	return {"score": score, "grade": grade, "blast_kills": stats.blast_kills, "retries": stats.retries}
