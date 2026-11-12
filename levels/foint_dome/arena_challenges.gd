class_name ArenaChallenges
extends RefCounted
## FOINT DOME's finite tournament runs (JS challenges.js): the six events, the roster of each round, spawning from the bullpens, prizes and the wins kept in the save.

const CHALLENGES: Array[Dictionary] = [
	{"id": "rookie", "name": "OPENING NIGHT", "tag": "OPEN CIRCUIT", "rounds": 4, "prize": 1500, "repeat": 500, "tier": 0, "hazards": false, "desc": "Four rounds. Learn the floor, watch the gates and clear every contender."},
	{"id": "hazard", "name": "HAZARD PAY", "tag": "WATCH YOUR STEP", "rounds": 5, "prize": 2400, "repeat": 750, "tier": 0, "hazards": true, "desc": "Five rounds with live turbines. The floor changes beneath the fight."},
	{"id": "clock", "name": "BEAT THE BROADCAST", "tag": "TIME ATTACK", "rounds": 4, "prize": 3200, "repeat": 1000, "tier": 1, "time": 150, "hazards": false, "desc": "Clear four escalating squads in 150 seconds. Intermissions count."},
	{"id": "pistol", "name": "ONE GUN SHOW", "tag": "PISTOL ONLY", "rounds": 5, "prize": 3800, "repeat": 1200, "tier": 1, "weapon": "deagle", "hazards": false, "desc": "Five rounds using the hand cannon and melee. Ammo outlets are disabled; bring ammunition."},
	{"id": "endurance", "name": "THE LONG HAUL", "tag": "ENDURANCE", "rounds": 10, "prize": 6500, "repeat": 2000, "tier": 2, "hazards": true, "desc": "Ten rounds. New enemy roles enter as the crowd gets louder. Stay mobile."},
	{"id": "champion", "name": "MAIN EVENT", "tag": "CHAMPIONSHIP", "rounds": 8, "prize": 9000, "repeat": 3000, "tier": 2, "hazards": true, "desc": "Eight rounds of mixed opposition. Finish against the Marrow Warden and its escort."},
]

var level: FointDomeLevel
var wins: Dictionary = {}
var state := &"inactive"
var round_ := 0
var queue: Array[Dictionary] = []
var t := 0.0
var elapsed := 0.0
var spawn_clock := 0.0
var run := 0
var result: Variant = null
var challenge: Variant = null          # Dictionary
var count := 0
var spawn_index := 0


static func round_roster(c: Dictionary, rnd: int) -> Array[Dictionary]:
	var lv: int = rnd + int(c.tier) * 2
	var n: int = mini(14, 3 + rnd + int(c.tier))
	var roster: Array[Dictionary] = []
	for i in n:
		if lv >= 6 and i == 0:
			roster.append({"kind": "brute"})
		elif lv >= 4 and i == 1:
			roster.append({"kind": "alien"})
		elif lv >= 7 and i == 2:
			roster.append({"kind": "scream"})
		elif lv >= 5 and i == 3:
			roster.append({"drone": true})
		elif lv >= 3 and i % 4 == 2:
			roster.append({"kind": "follower"})
		else:
			roster.append({"kind": "robot", "heavy": lv >= 5 and i % 6 == 4})
	if c.id == "pistol":
		for i in roster.size():
			roster[i] = {"kind": "follower"} if i % 3 == 2 else {"kind": "robot"}
	if c.id == "champion" and rnd == int(c.rounds):
		roster.clear()
		roster.append_array([{"kind": "warden"}, {"kind": "alien"}, {"kind": "robot"}, {"kind": "robot"}] as Array[Dictionary])
	return roster


func _init(p_level: FointDomeLevel) -> void:
	level = p_level
	var a: Dictionary = Game.save_data.arena
	wins = (a.get("wins", {}) as Dictionary).duplicate()


var playable: bool:
	get:
		return state == &"fight" or state == &"between" or state == &"death_hold"


var blocked: bool:
	get:
		return not playable


var unique_wins: int:
	get:
		var n := 0
		for c: Dictionary in CHALLENGES:
			if int(wins.get(c.id, 0)) > 0:
				n += 1
		return n


func unlocked(c: Dictionary) -> bool:
	return int(c.tier) == 0 or (unique_wins >= 1 if int(c.tier) == 1 else unique_wins >= 3)


func prize(c: Dictionary) -> int:
	return c.repeat if int(wins.get(c.id, 0)) > 0 else c.prize


func clear() -> void:
	var C := Game.combat
	for r: Robot in C.enemies.robots.duplicate():
		Game.despawn_enemy(r)
	C.enemies.bolts.clear()
	C.enemies.creature_last_attack = {}
	C.projs.clear()
	C.saws.clear()
	C.rocks.clear()
	C.wells.clear()
	C.rl = null
	C.cool = 0.0
	C.buffer = 0.0
	C.yoke.holding = false
	C.yoke.charge = 0.0
	C.arc.on = false
	C.punch.stage = 0
	C.punch.queued = false
	C.punch.chain_t = 0.0
	C.events.clear()


func menu(reason: String = "welcome") -> void:
	clear()
	queue.clear()
	state = &"menu"
	t = 0.0
	level.motion.set_mode("platforms")
	level.motion.set_gates("closed")
	Game.player.respawn()
	Game.rig.snap_to(Game.player)
	Game.save_data.arena["wins"] = wins
	Game.save_game(true)
	Game.hud.dead(false)
	Game.wheel.close()
	level.tv.menu(reason)


func start(id: String) -> bool:
	var c: Variant = null
	for q: Dictionary in CHALLENGES:
		if q.id == id:
			c = q
	if state != &"menu" or c == null or not unlocked(c):
		return false
	clear()
	challenge = c
	result = null
	round_ = 0
	elapsed = 0.0
	run += 1
	Game.player.respawn()
	Game.rig.snap_to(Game.player)
	var C := Game.combat
	if c.has("weapon"):
		C.equip(Weapons.index_of(c.weapon))
	level.motion.set_mode("auto" if c.hazards else "platforms")
	level.motion.set_gates("open")
	level.update_arena(0.0, Game.player, 0.0)
	state = &"launch"
	t = 0.0
	level.tv.start()
	return true


func ready() -> void:
	if state == &"launch":
		state = &"countdown"
		t = 0.0
		count = 0
		_announce("3 · GET READY")


func next_round() -> void:
	round_ += 1
	queue = round_roster(challenge, round_)
	spawn_clock = 0.2
	state = &"fight"
	t = 0.0
	_announce("ROUND %d / %d · %d CONTENDERS" % [round_, challenge.rounds, queue.size()])


func finish(won: bool, reason: String = "") -> bool:
	if not (state == &"fight" or state == &"between" or state == &"death_hold" or state == &"countdown"):
		return false
	var c: Dictionary = challenge
	var pz := prize(c) if won else 0
	result = {"won": won, "reason": reason if reason != "" else ("CHALLENGE COMPLETE" if won else "CHALLENGE FAILED"), "prize": pz, "name": c.name, "rounds": round_, "elapsed": elapsed}
	if won:
		wins[c.id] = int(wins.get(c.id, 0)) + 1
		Game.add_money(pz)
	menu("victory" if won else "defeat")
	return true


func constrain() -> void:
	if challenge == null or not playable:
		return
	if challenge.has("weapon"):
		var C := Game.combat
		var index := Weapons.index_of(challenge.weapon)
		if C.cur != index:
			C.equip(index)
		for p: Variant in C.pickups:
			p.cd = maxf(p.cd, 0.2)


func _announce(m: String) -> void:
	Game.hud.toast(m, 2.3)


func update(dt: float) -> void:
	t += dt
	var C := Game.combat
	var P := Game.player
	if state == &"countdown":
		var n := 3 - int(floorf(t))
		if n > 0 and n != count:
			count = n
			_announce("%d · GET READY" % n)
		if t >= 3.0:
			count = 0
			next_round()
		return
	if state == &"death_hold":
		if t >= 0.85:
			finish(false, "CONTENDER DOWN")
		return
	if state != &"fight" and state != &"between":
		return
	if P.dead:
		state = &"death_hold"
		t = 0.0
		return
	elapsed += dt
	if challenge.has("time") and elapsed >= float(challenge.time):
		finish(false, "OUT OF TIME")
		return
	if state == &"between":
		if t > 2.8:
			next_round()
		return
	var alive := 0
	for r: Robot in C.enemies.robots.duplicate():
		if r.dead:
			r.respawn_t = 99999.0
			if r.dead_t > 2.5:
				Game.despawn_enemy(r)
			continue
		if r.y < -4.0 or U.hyp(r.x, r.z) > 40.0:
			Game.despawn_enemy(r)
			continue
		alive += 1
		if (r.state == &"idle" or r.state == &"return" or r.state == &"search") and r.state_t > 0.4:
			r.known = Robot.Known.at(P.x, P.z)
			r.seen_t = 0.0
			r.set_(&"pursue")
	spawn_clock -= dt
	if queue.size() > 0 and alive < mini(8, 4 + round_) and spawn_clock <= 0.0:
		var candidates: Array[FointDomeLevel.SpawnPoint] = []
		for s: FointDomeLevel.SpawnPoint in level.spawns:
			if not s.ready or U.hyp(s.x - P.x, s.z - P.z) <= 8.0:
				continue
			var taken := false
			for r: Robot in C.enemies.robots:
				if not r.dead and U.hyp(r.x - s.x, r.z - s.z) < 1.5:
					taken = true
					break
			if not taken:
				candidates.append(s)
		if candidates.size() > 0:
			spawn_index += 1
			var sp := candidates[spawn_index % candidates.size()]
			var options: Dictionary = queue.pop_front()
			var o := options.duplicate()
			if o.get("kind", "") == "robot":      # (the port's plain robot has no kind)
				o.erase("kind")
			var r := Game.spawn_enemy({"x": sp.x, "y": sp.y, "z": sp.z, "yaw": sp.yaw}, o)
			r.respawn_t = 99999.0
			if options.get("heavy", false):
				r.heavy = true
				r.max = 150.0 + round_ * 5.0
				r.hp = r.max
				r.r = 0.72
			r.max = minf(60.0, r.hp) if challenge.has("weapon") else float(roundi(r.hp * (1.0 + minf(0.35, (round_ - 1) * 0.035))))
			r.hp = r.max
			r.known = Robot.Known.at(P.x, P.z)
			r.seen_t = 0.0
			r.set_(&"alert")
			spawn_clock = 0.48
			alive += 1
	if queue.is_empty() and alive == 0 and t > 1.0:
		if round_ == int(challenge.rounds):
			finish(true)
		else:
			state = &"between"
			t = 0.0
			_announce("ROUND CLEAR · RELOAD & REPOSITION")
