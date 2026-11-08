class_name WhForeman
extends RefCounted
## THE FOREMAN (JS levels/warehouse/boss.js, foreman-pose.js): the export loader that walks the apron. One pose drives render geometry, weapon origins and damage contacts. Armour takes a quarter, the open eye double.

const ID := 97000

var K: Dictionary = WhData.TUNING.boss
var world: World
var crates: Array[World.Solid] = []
var arm: World.Solid = null
var on_message: Callable
var on_sound: Callable
var B: Dictionary = {}
var combat: Combat = null
var targets: Array[Target] = []
var step := 0
var locked: Variant = null
var recovery := 0.0
var stride: Variant = null
var walk_time := 0.0
var next_foot := 0


static func _clamp(v: float, a: float = 0.0, b: float = 1.0) -> float:
	return clampf(v, a, b)


static func _smooth(v: float) -> float:
	v = clampf(v, 0.0, 1.0)
	return v * v * (3.0 - 2.0 * v)


## JS worldPoint(B, x, y, z); B may be any {x, z, yaw}
static func world_point(b: Dictionary, x: float, y: float, z: float) -> Vector3:
	var c := cos(float(b.yaw))
	var s := sin(float(b.yaw))
	return Vector3(float(b.x) + x * c + z * s, y, float(b.z) + z * c - x * s)


static func local_point(b: Dictionary, p: Vector3) -> Vector3:
	var c := cos(float(b.yaw))
	var s := sin(float(b.yaw))
	var x := p.x - float(b.x)
	var z := p.z - float(b.z)
	return Vector3(x * c - z * s, p.y, z * c + x * s)


func core_aperture() -> float:
	if B.mode != "fight" or B.move != "recover":
		return 0.0
	var duration := float(K.recovery[int(B.phase) - 1])
	return minf(_smooth(float(B.mt) / 0.45), _smooth((duration - float(B.mt)) / 0.55))


func sweep_frame() -> Dictionary:
	var S: Dictionary = K.sweep
	var u := _smooth((float(B.mt) - float(S.warning)) / float(S.duration))
	var a := -0.85 + 1.7 * u
	var settle := _smooth(float(B.mt) / float(S.warning))
	return {"x": -4.7 + sin(a) * 5.0, "y": 3.1 - 2.45 * settle, "z": 1.5 + cos(a) * 5.0, "yaw": a}


## One pose drives render geometry, weapon origins, and damage contacts.
func pose() -> Dictionary:
	var t := float(B.mt)
	var P := {"press": Vector3(5.2, 2.8, 3.0), "fork": Vector3(-5.2, 3.1, 3.0), "bob": float(B.bob), "lean": 0.0, "cannon_yaw": 0.0, "cannon_pitch": 0.0, "sweep": false}
	var mv: String = B.move
	if mv == "stamp" and (B.marks as Array).size() > 0:
		var p := local_point(B, B.marks[0])
		var S: Dictionary = K.stamp
		var rise := _smooth(t / 0.75)
		var strike := _smooth((t - float(S.warning) + 0.25) / 0.25)
		var retract := _smooth((t - float(S.warning) - 0.24) / 0.65)
		P.press = Vector3(5.2 + (p.x - 5.2) * rise, 2.8 + 8.0 * rise - (10.8 - p.y) * strike + 2.8 * retract, 3.0 + (p.z - 3.0) * rise)
		P.lean = -0.13 * rise + 0.24 * strike
	if mv == "sweep":
		var f := sweep_frame()
		var v := _smooth(t / 0.85)
		P.fork = Vector3(-5.2 + (float(f.x) + 5.2) * v, f.y, 3.0 + (float(f.z) - 3.0) * v)
		P.cannon_yaw = float(f.yaw) * v
		P.lean = 0.06 * sin(float(f.yaw))
		P.sweep = true
	if mv == "burst":
		var S: Dictionary = K.burst
		var recoil := exp(-fposmod(t - float(S.warning), float(S.gap)) * 16.0) if t >= float(S.warning) else 0.0
		var v := _smooth(t / 0.9)
		P.fork = Vector3(-5.2 + 0.4 * v, 3.1 + 3.9 * v, 3.0 + 3.0 * v - recoil * 0.7)
		P.lean = -recoil * 0.065
	if mv == "pound":
		var S: Dictionary = K.pound
		var repeat: bool = int(B.phase) == 3 and t > float(S.warning) + 0.22 and t < float(S.warning) + float(S.interval)
		var clock := t - float(S.warning) - 0.22 if repeat else t
		var windup := float(S.interval) - 0.22 if repeat else float(S.warning)
		var strike := _smooth((clock - windup + 0.3) / 0.3)
		var lift := _smooth(clock / (0.4 if repeat else 0.9))
		P.press = Vector3(4.5, 2.8 + 8.0 * lift - 10.8 * strike, 5.0)
		P.fork = Vector3(-4.5, 3.0 + 6.0 * lift - 8.4 * strike, 5.0)
		P.bob = float(P.bob) - strike * 0.55
		P.lean = -0.12 * lift + 0.22 * strike
	if mv == "drop":
		var lift := _smooth(t / 0.75)
		var release := _smooth((t - float(K.drop.warning) + 0.3) / 0.3)
		P.press = Vector3(6.8, 2.8 + 5.2 * lift - 0.8 * release, 4.0)
		P.fork = Vector3(-6.8, 3.1 + 4.9 * lift - 0.8 * release, 4.0)
		P.lean = -0.09 * lift
	if B.walking:
		var swing := sin(float(B.time) * PI / float(K.pursuit.stride))
		P.press.z += swing * 0.45
		P.fork.z -= swing * 0.45
	if mv == "ram":
		var u := _smooth(t / float(K.ram.warning))
		P.press = Vector3(5.5, 3.5 + u, 4.5)
		P.fork = Vector3(-5.5, 3.5 + u, 4.5)
		P.lean = 0.18 * u
	if mv == "salvo":
		P.lean = -0.1
		P.press.y += 0.6 * sin(t * 3.0)
		P.fork.y += 0.5
	if mv == "purge":
		var u := _smooth(t / 0.75)
		P.press = Vector3(5.8, 2.8 + 4.0 * u, 3.0)
		P.fork = Vector3(-5.8, 3.1 + 4.0 * u, 3.0)
		P.lean = -0.08 * u
	if mv == "recover" or mv == "link":
		var u := _smooth(t / 0.65)
		var old: Variant = B.release_pose
		if old != null:
			P.press = (old.press as Vector3).lerp(P.press, u)
			P.fork = (old.fork as Vector3).lerp(P.fork, u)
			P.lean = float(old.lean) * (1.0 - u)
			P.cannon_yaw = float(old.cannon_yaw) * (1.0 - u)
			P.cannon_pitch = float(old.cannon_pitch) * (1.0 - u)
		P.bob = float(P.bob) - 0.18 * sin(minf(1.0, t / 0.8) * PI)
	if mv == "burst" and B.aim != null:
		var aim := local_point(B, B.aim)
		var fork: Vector3 = P.fork
		var dx := aim.x - fork.x
		var dz := aim.z - fork.z
		P.cannon_yaw = atan2(dx, dz)
		P.cannon_pitch = atan2(fork.y - aim.y, U.hyp(dx, dz))
	return P


func _init(p_world: World, p_crates: Array[World.Solid], p_arm: World.Solid, msg: Callable, sound: Callable) -> void:
	world = p_world
	crates = p_crates
	arm = p_arm
	on_message = msg
	on_sound = sound
	B = {"mode": "waiting", "hp": K.hp, "max": K.hp, "phase": 1, "time": 0.0, "move": "", "mt": 0.0, "index": 0, "label": "CLEAR THE APRON", "exposed": false, "flash": 0.0, "eye_hit_time": -100.0, "eye_hit_open": false, "hit_part": "", "marks": [], "rings": [], "cargo": [], "sweep": 0.0, "dead": false, "x": K.x, "z": K.z, "yaw": 0.0, "bob": 0.0, "feet": [], "steps": 0, "walking": false, "chain": 0, "salvos": [], "grid": [], "ram": null, "next_move": null, "release_pose": null, "aim": null, "closing": false}
	reset()


func bind(C: Combat) -> void:
	if combat == C:
		return
	if combat != null:
		for t: Target in targets:
			combat.targets.erase(t)
	combat = C
	if C == null:
		return
	targets = [Target.new(ID, float(B.x), float(B.z), 4.0, {"r": 3.4, "h": 6.0, "max": 1e6, "hp": 1e6, "boss": true, "w": 0.0}), Target.new(ID + 1, float(B.x), float(B.z) + 3.7, 5.9, {"r": 1.3, "h": 2.6, "max": 1e6, "hp": 1e6, "boss": true, "w": 0.0})]
	for i in targets.size():
		targets[i].boss = true
		targets[i].data["foreman_part"] = "core" if i == 1 else "armor"
		C.targets.append(targets[i])
	_sync_targets()


func _sync_targets() -> void:
	if targets.is_empty():
		return
	var p := pose()
	var pitch: float = p.lean
	var core := world_point(B, 0.0, 7.2 * cos(pitch) - 3.7 * sin(pitch) + float(p.bob), 7.2 * sin(pitch) + 3.7 * cos(pitch))
	for i in targets.size():
		var t := targets[i]
		t.x = core.x if i == 1 else float(B.x)
		t.bx = t.x
		t.z = core.z if i == 1 else float(B.z)
		t.bz = t.z
		t.y = core.y - 1.3 if i == 1 else 4.0 + float(B.bob)
		t.hp = t.max
		t.dead = B.mode != "fight"
		t.respawn_t = 1e9
		t.kx = 0.0
		t.kz = 0.0


func _clear_bolts() -> void:
	if combat == null:
		return
	var L: Array = combat.enemies.bolts
	var i := L.size() - 1
	while i >= 0:
		if L[i].owner == ID:
			L.remove_at(i)
		i -= 1


func reset(phase: int = 0) -> void:
	_clear_bolts()
	B.mode = "intro" if phase != 0 else "waiting"
	B.phase = phase if phase != 0 else 1
	B.hp = float(K.hp) * (0.32 if phase == 3 else (0.65 if phase == 2 else 1.0))
	B.time = 0.0
	B.move = ""
	B.mt = 0.0
	B.index = 0
	B.dead = false
	B.exposed = false
	B.flash = 0.0
	B.eye_hit_time = -100.0
	B.eye_hit_open = false
	B.hit_part = ""
	B.marks = []
	B.rings = []
	B.cargo = []
	B.x = K.x
	B.z = K.z
	B.yaw = 0.0
	B.bob = 0.0
	B.steps = 0
	B.walking = false
	B.chain = 0
	B.salvos = []
	B.grid = []
	B.ram = null
	B.next_move = null
	B.release_pose = null
	B.label = "FOREMAN POWERING UP" if phase != 0 else "CLEAR THE APRON"
	var feet := []
	for s: float in [-1.0, 1.0]:
		var w := world_point(B, s * 2.35, 0.0, 0.7)
		feet.append({"x": w.x, "y": w.y, "z": w.z, "yaw": 0.0})
	B.feet = feet
	step = 0
	locked = null
	stride = null
	walk_time = 0.0
	next_foot = 0
	for s: World.Solid in crates:
		s.set_off(true)
	if arm != null:
		arm.set_off(true)
	_sync_targets()


func _hurt(P: Player, d: float) -> void:
	if combat != null:
		combat.hurt_player(P, d, B.x, B.z, "bolt")


func _contact(P: Player) -> Vector3:
	var dx := P.x - float(B.x)
	var dz := P.z - float(B.z)
	var d := U.hyp(dx, dz)
	if d == 0.0:
		d = 1.0
	var r := minf(12.0, d)
	return Vector3(float(B.x) + dx / d * r, 0.0, float(B.z) + dz / d * r)


func begin(nm: String, P: Player) -> void:
	if nm == "recover":
		_expose()
		return
	on_sound.call("charge")
	B.salvos = []
	B.grid = []
	B.ram = null
	B.aim = null
	B.move = nm
	B.mt = 0.0
	step = 0
	locked = null
	B.exposed = false
	B.marks = []
	B.rings = []
	B.walking = false
	B.bob = 0.0
	stride = null
	B.label = {"ram": "FREIGHT RAM", "salvo": "MISSILE SALVO", "purge": "DECK PURGE", "stamp": "PRESS / Dodge the raised hammer.", "sweep": "FORK / Jump the low sweep.", "burst": "RIVETS / Strafe through the gaps.", "pound": "PILE DRIVER / Jump the shockwave.", "drop": "CARGO / Clear the falling freight."}[nm]
	if nm == "ram":
		var dx := P.x - float(B.x)
		var dz := P.z - float(B.z)
		var d := U.hyp(dx, dz)
		if d == 0.0:
			d = 1.0
		var reach := 0.0
		var r := 0.5
		while r <= minf(float(K.ram.reach), d):
			if not _free(float(B.x) + dx / d * r, float(B.z) + dz / d * r):
				break
			reach = r
			r += 0.5
		if reach < 2.0:
			begin("salvo", P)
			return
		var fs := []
		for f: Dictionary in B.feet:
			fs.append(f.duplicate())
		B.ram = {"x": B.x, "z": B.z, "tx": float(B.x) + dx / d * reach, "tz": float(B.z) + dz / d * reach, "feet": fs, "hit": false}
		B.yaw = atan2(dx, dz)
	if nm == "purge":
		var lane := clampi(int(floorf((P.x - 266.0) / 11.3)), 0, 2)
		var g := []
		var lanes := [lane]
		if int(B.phase) == 3:
			lanes.append((lane + 1) % 3)
		for i: int in lanes:
			g.append({"x": 271.5 + i * 11.3, "z": 184.0, "hx": 4.65, "hz": 26.0, "cooldown": 0.0})
		B.grid = g
	if nm == "stamp":
		B.marks = [_contact(P)]
	if nm == "drop":
		var m := []
		for i in (3 if int(B.phase) == 3 else 2):
			m.append(Vector3(crates[i].cx, 0.0, crates[i].cz))
		B.marks = m


func _expose() -> void:
	B.release_pose = pose()
	B.move = "recover"
	B.mt = 0.0
	B.exposed = false
	B.closing = false
	B.marks = []
	B.rings = []
	B.label = "EYE OPENING / Get ready."
	on_sound.call("vent")
	recovery = K.recovery[int(B.phase) - 1]


func _finish(_P: Player) -> void:
	var next: Variant = {"ram": "stamp", "purge": "salvo", "drop": "burst"}.get(B.move)
	if B.move == "burst" and int(B.phase) == 3:
		next = "salvo"
	if int(B.phase) >= 2 and int(B.chain) < (2 if int(B.phase) == 3 else 1) and next != null:
		B.chain = int(B.chain) + 1
		B.release_pose = pose()
		B.move = "link"
		B.next_move = next
		B.mt = 0.0
		B.marks = []
		B.rings = []
		B.grid = []
		B.salvos = []
		B.label = "OVERTIME"
		return
	_expose()


func _fire(P: Player) -> void:
	on_sound.call("rivet")
	var aim: Variant = locked if locked != null else Vector3(P.x, P.y, P.z)
	var p := pose()
	var fork: Vector3 = p.fork
	var cy: float = p.cannon_yaw
	var cp: float = p.cannon_pitch
	var o := world_point(B, fork.x + sin(cy) * cos(cp) * 3.45, fork.y - sin(cp) * 3.45, fork.z + cos(cy) * cos(cp) * 3.45)
	var dx: float = aim.x - o.x
	var dy: float = aim.y + 1.0 - o.y
	var dz: float = aim.z - o.z
	var l := Vector3(dx, dy, dz).length()
	if l == 0.0:
		l = 1.0
	var S: Dictionary = K.burst
	var n := int(S.rays[int(B.phase) - 1])
	for i in n:
		var a := (i - (n - 1) / 2.0) * float(S.spread)
		var c := cos(a)
		var s := sin(a)
		combat.enemies.fire_from(ID, o.x, o.y, o.z, (dx * c + dz * s) / l, dy / l, (dz * c - dx * s) / l, {"dmg": S.damage, "speed": S.speed, "r": 0.22})


## The central apron is clear; probe the complete body radius against authored solids so edge decks / cargo remain real obstacles. Own animated solids excluded.
func _free(x: float, z: float) -> bool:
	if x < 273.0 or x > 293.0 or z < 164.0 or z > 203.0:
		return false
	for s: World.Solid in world.solids:
		if s.off or s.tag == "boss" or s.bottom > 4.0:
			continue
		for i in 9:
			var a := i / 8.0 * TAU
			var r := 0.0 if i == 8 else 3.9
			var top: Variant = s.top_at(x + sin(a) * r, z + cos(a) * r)
			if top != null and float(top) > 0.35:
				return false
	return true


func _walk(dt: float, P: Player) -> void:
	walk_time += dt
	B.walking = true
	B.label = "FOREMAN ADVANCING / Keep your distance."
	if stride == null:
		var dx := P.x - float(B.x)
		var dz := P.z - float(B.z)
		var d := U.hyp(dx, dz)
		var want := atan2(dx, dz)
		var turn := U.wrap_angle(want - float(B.yaw))
		if walk_time > float(K.pursuit.maxWait) or (walk_time > 0.7 and absf(turn) < 0.32 and (d < 14.0 or walk_time > 1.5)):
			B.walking = false
			B.bob = 0.0
			var seq: Array = K.sequences[str(B.phase)]
			var mv: String = seq[int(B.index) % seq.size()]
			B.index = int(B.index) + 1
			# A circling player or blocked path must not switch off the boss's offense.
			if absf(turn) > 0.65:
				mv = "salvo"
			elif d > 15.0 and (mv == "stamp" or mv == "sweep"):
				mv = "salvo" if d > 23.0 else "ram"
			begin(mv, P)
			return
		var yaw := float(B.yaw) + clampf(turn, -float(K.pursuit.turn), float(K.pursuit.turn))
		var x := float(B.x)
		var z := float(B.z)
		if (d > 10.0 or d < 8.0) and absf(turn) < 1.3:
			for offset: float in [0.0, 0.7, -0.7, 1.3, -1.3]:
				var dist := -1.2 if d < 8.0 else float(K.pursuit.step)
				var nx := float(B.x) + sin(yaw + offset) * dist
				var nz := float(B.z) + cos(yaw + offset) * dist
				if _free(nx, nz):
					x = nx
					z = nz
					break
		var future := {"x": x, "z": z, "yaw": yaw}
		var foot := next_foot
		next_foot = 1 - next_foot
		var dest := world_point(future, 2.35 if foot == 1 else -2.35, 0.0, 1.1)
		stride = {"t": 0.0, "x": B.x, "z": B.z, "yaw": B.yaw, "to": future, "foot": foot, "from": (B.feet[foot] as Dictionary).duplicate(), "dest": dest}
	var s: Dictionary = stride
	s.t = float(s.t) + dt
	var u := clampf(float(s.t) / float(K.pursuit.stride), 0.0, 1.0)
	var v := _smooth(u)
	var to: Dictionary = s.to
	B.x = float(s.x) + (float(to.x) - float(s.x)) * v
	B.z = float(s.z) + (float(to.z) - float(s.z)) * v
	B.yaw = float(s.yaw) + (float(to.yaw) - float(s.yaw)) * v
	B.bob = -0.17 * sin(u * PI)
	var f: Dictionary = B.feet[s.foot]
	var fr: Dictionary = s.from
	var de: Vector3 = s.dest
	f.x = float(fr.x) + (de.x - float(fr.x)) * v
	f.z = float(fr.z) + (de.z - float(fr.z)) * v
	f.y = sin(u * PI) * 1.05
	f.yaw = float(fr.yaw) + (float(to.yaw) - float(fr.yaw)) * v
	if u >= 1.0:
		f.y = 0.0
		B.steps = int(B.steps) + 1
		on_sound.call("step")
		if combat != null:
			combat.events.append({"t": "explode", "x": f.x, "y": 0.05, "z": f.z, "r": 0.55})
		stride = null


func update(dt: float, P: Player, C: Combat) -> void:
	bind(C)
	if dt <= 0.0 or P == null or P.dead:
		return
	B.time = float(B.time) + dt
	B.flash = maxf(0.0, float(B.flash) - dt * 4.0)
	if B.mode == "fight":
		var damage := 0.0
		for i in targets.size():
			var t := targets[i]
			var raw := maxf(0.0, t.max - t.hp)
			if raw > 0.0:
				if i == 1:
					B.eye_hit_time = B.time
					B.eye_hit_open = B.exposed
				damage += raw * (float(K.exposeMult) if i == 1 and B.exposed else float(K.armor))
				B.flash = 1.0
				B.hit_part = "core" if i == 1 and B.exposed else "armor"
		B.hp = maxf(0.0, float(B.hp) - damage)
		if float(B.hp) <= 0.0:
			B.mode = "dying"
			B.mt = 0.0
			B.move = ""
			B.exposed = false
			B.walking = false
			B.label = "FOREMAN DISABLED"
			B.grid = []
			B.salvos = []
			B.ram = null
			on_sound.call("shutdown")
			_clear_bolts()
			B.rings = []
			B.marks = []
			B.cargo = []
			for s: World.Solid in crates:
				s.set_off(true)
		else:
			var ph := 3 if float(B.hp) <= float(K.hp) * float(K.phaseAt[1]) else (2 if float(B.hp) <= float(K.hp) * float(K.phaseAt[0]) else 1)
			if ph > int(B.phase):
				B.phase = ph
				B.chain = 0
				B.grid = []
				B.salvos = []
				B.ram = null
				B.mode = "transition"
				B.mt = 0.0
				B.index = 0
				B.move = ""
				B.exposed = false
				B.walking = false
				stride = null
				B.marks = []
				B.rings = []
				_clear_bolts()
				B.label = "PILE DRIVER ONLINE" if ph == 2 else "FOREMAN OVERDRIVE"
				on_message.call(String(B.label) + " / " + ("YOUR BREAK IS OVER." if ph == 2 else "OVERTIME. NO EXCEPTIONS."))
				on_sound.call("taunt")
	if B.mode != "fight":
		for f: Dictionary in B.feet:
			f.y = maxf(0.0, float(f.y) - dt * 4.0)
	_sync_targets()
	var cargo: Array = B.cargo
	var ci := cargo.size() - 1
	while ci >= 0:
		var q: Dictionary = cargo[ci]
		q.left = float(q.left) - dt
		if float(q.left) <= 0.0:
			(q.solid as World.Solid).set_off(true)
			cargo.remove_at(ci)
		ci -= 1
	if B.mode == "waiting" or B.mode == "dead":
		return
	B.mt = float(B.mt) + dt
	if B.mode == "dying":
		if float(B.mt) >= 1.8 and arm != null:
			arm.set_off(false)
		if float(B.mt) >= 3.2:
			B.mode = "dead"
			B.dead = true
			B.label = "BOARD THE GETAWAY"
			on_message.call("FOREMAN DOWN / GETAWAY READY")
		return
	if B.mode == "intro" or B.mode == "transition":
		if float(B.mt) >= (float(K.intro) if B.mode == "intro" else float(K.transition)):
			B.mode = "fight"
			B.move = ""
			B.mt = 0.0
			walk_time = 0.0
		return
	if B.move == "":
		_walk(dt, P)
		_sync_targets()
		return
	var t := float(B.mt)
	var mv: String = B.move
	# Track during the visible windup, then commit. No homing ram or last-frame hammer redirection: the existing dodge windows remain intact.
	var tracking: bool = mv == "salvo" or (mv == "stamp" and t < float(K.stamp.warning) - float(K.stamp.lock)) or (mv == "burst" and locked == null) or (mv == "sweep" and t < float(K.sweep.warning) - 0.4)
	if tracking:
		var dx := P.x - float(B.x)
		var dz := P.z - float(B.z)
		# The fork sweeps on the left of the chassis: face its working arc toward the target, rather than aiming the empty space between both shoulders.
		var want := atan2(dx, dz) + (atan2(4.7, maxf(6.0, U.hyp(dx, dz))) if mv == "sweep" else 0.0)
		var turn := U.wrap_angle(want - float(B.yaw))
		var lim := float(K.pursuit.windupTurn) * dt
		B.yaw = float(B.yaw) + clampf(turn, -lim, lim)
		_sync_targets()
	if mv == "link":
		if t >= 0.65:
			begin(B.next_move, P)
		return
	if mv == "recover":
		if t > recovery - 0.55 and not B.closing:
			B.closing = true
			on_sound.call("latch")
		B.exposed = core_aperture() > 0.9
		B.label = "EYE OPENING / Get ready." if t < 0.45 else ("EYE CLOSING / Move to the next perch." if t > recovery - 0.55 else "EYE OPEN / Shoot the blue pupil!")
		if t >= recovery:
			B.chain = 0
			B.exposed = false
			B.move = ""
			B.mt = 0.0
			walk_time = 0.0
		return
	match mv:
		"ram":
			var S: Dictionary = K.ram
			var q: Dictionary = B.ram
			var u := _smooth((t - float(S.warning)) / float(S.duration))
			var dx := (float(q.tx) - float(q.x)) * u
			var dz := (float(q.tz) - float(q.z)) * u
			B.x = float(q.x) + dx
			B.z = float(q.z) + dz
			B.bob = -0.45 * _smooth(t / float(S.warning)) if t < float(S.warning) else 0.35 * sin(u * PI)
			var fs := []
			for f: Dictionary in q.feet:
				fs.append({"x": float(f.x) + dx, "y": 0.25 * sin(u * PI), "z": float(f.z) + dz, "yaw": f.yaw})
			B.feet = fs
			if t >= float(S.warning) and not q.hit and U.hyp(P.x - float(B.x), P.z - float(B.z)) < float(S.radius) and P.y < 4.5:
				_hurt(P, S.damage)
				q.hit = true
			if step == 0 and t >= float(S.warning):
				step = 1
				on_sound.call("ram")
			_sync_targets()
			if t >= float(S.warning) + float(S.duration) + 0.25:
				B.bob = 0.0
				_finish(P)
		"salvo":
			var S: Dictionary = K.salvo
			var shots := int(S.shots[int(B.phase) - 1])
			if step < shots and t >= step * float(S.gap):
				var fl := world.ground_height(P.x, P.z, 0.2, P.y + 0.3)
				(B.salvos as Array).append({"x": P.x, "z": P.z, "y": fl if is_finite(fl) else maxf(0.0, P.y), "age": 0.0, "hit": false})
				step += 1
				on_sound.call("missile")
			for q: Dictionary in B.salvos:
				q.age = float(q.age) + dt
				if not q.hit and float(q.age) >= float(S.warning):
					q.hit = true
					on_sound.call("impact")
					C.events.append({"t": "explode", "x": q.x, "y": q.y, "z": q.z, "r": S.radius})
					if U.hyp(P.x - float(q.x), P.z - float(q.z)) < float(S.radius) and absf(P.y - float(q.y)) < 2.3:
						_hurt(P, S.damage)
			if t >= (shots - 1) * float(S.gap) + float(S.warning) + 0.45:
				_finish(P)
		"purge":
			var S: Dictionary = K.purge
			if step == 0 and t >= float(S.warning):
				step = 1
				on_sound.call("purge")
			for q: Dictionary in B.grid:
				q.cooldown = float(q.cooldown) - dt
				if t >= float(S.warning) and float(q.cooldown) <= 0.0 and absf(P.x - float(q.x)) < float(q.hx) and absf(P.z - float(q.z)) < float(q.hz) and P.y < float(S.height):
					_hurt(P, S.damage)
					q.cooldown = 0.85
			if t >= float(S.warning) + float(S.duration):
				_finish(P)
		"stamp":
			var S: Dictionary = K.stamp
			if t < float(S.warning) - float(S.lock):
				B.marks[0] = _contact(P)
			if step == 0 and t >= float(S.warning):
				step = 1
				on_sound.call("impact")
				var m: Vector3 = B.marks[0]
				if U.hyp(P.x - m.x, P.z - m.z) < float(S.radius) and absf(P.y - m.y) < 2.5:
					_hurt(P, S.damage)
				C.events.append({"t": "explode", "x": m.x, "y": m.y, "z": m.z, "r": 2.6})
			if t >= float(S.warning) + 0.8:
				_finish(P)
		"burst":
			var S: Dictionary = K.burst
			if locked == null:
				B.aim = Vector3(P.x, P.y + 1.0, P.z)
			if locked == null and t >= float(S.warning) * 0.65:
				locked = Vector3(P.x, P.y, P.z)
				B.aim = Vector3(P.x, P.y + 1.0, P.z)
			if step < int(S.shots) and t >= float(S.warning) + step * float(S.gap):
				_fire(P)
				step += 1
			if t >= float(S.warning) + int(S.shots) * float(S.gap) + 0.3:
				_finish(P)
		"sweep":
			var S: Dictionary = K.sweep
			var f := sweep_frame()
			B.sweep = f.yaw
			var hand := world_point(B, f.x, f.y, f.z)
			var a := float(B.yaw) + float(f.yaw)
			var dx := P.x - hand.x
			var dz := P.z - hand.z
			var along := dx * sin(a) + dz * cos(a)
			var cross := absf(dx * cos(a) - dz * sin(a))
			if step == 0 and t >= float(S.warning) and t <= float(S.warning) + float(S.duration) and absf(along) < 3.2 and cross < 1.55 and P.y < float(S.height):
				_hurt(P, S.damage)
				step = 1
			if t >= float(S.warning) + float(S.duration) + 0.35:
				_finish(P)
		"pound":
			var S: Dictionary = K.pound
			var pulses := 2 if int(B.phase) == 3 else 1
			if step < pulses and t >= float(S.warning) + step * float(S.interval):
				on_sound.call("impact")
				var w := world_point(B, 0.0, 0.0, 5.0)
				(B.rings as Array).append({"r": 0.0, "hit": false, "x": w.x, "y": 0.0, "z": w.z})
				C.events.append({"t": "explode", "x": B.x, "y": 0.1, "z": B.z, "r": 4.0})
				step += 1
			for q: Dictionary in B.rings:
				var prev: float = q.r
				q.r = prev + float(S.speed) * dt
				var d := U.hyp(P.x - float(q.x), P.z - float(q.z))
				if not q.hit and d >= prev - 0.65 and d <= float(q.r) + 0.65 and P.y < float(S.height):
					_hurt(P, S.damage)
					q.hit = true
			if t >= float(S.warning) + (pulses - 1) * float(S.interval) + float(S.maxRadius) / float(S.speed):
				_finish(P)
		"drop":
			var S: Dictionary = K.drop
			if step == 0 and t >= float(S.warning):
				step = 1
				on_sound.call("impact")
				var ms: Array = B.marks
				for i in ms.size():
					var m: Vector3 = ms[i]
					var solid := crates[i]
					solid.set_off(false)
					(B.cargo as Array).append({"solid": solid, "left": S.hold})
					if U.hyp(P.x - m.x, P.z - m.z) < float(S.radius) and P.y < 3.0:
						_hurt(P, S.damage)
						if absf(P.x - solid.cx) < 2.0 and absf(P.z - solid.cz) < 2.0:
							P.y = solid.top
							P.vy = 0.0
							P.grounded = true
			if t >= float(S.warning) + 0.5:
				_finish(P)
