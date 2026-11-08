class_name WhDirector
extends RefCounted
## The warehouse's progression (JS levels/warehouse/director.js): rooms, waves, the plan's steps, checkpoints, the lift, the course and the finale. No rendering: the level is its api, as in the JS.

const LIMITS := {"robot": 24, "drone": 8, "mech": 4, "guard": 6, "spider": 10, "total": 32}
const CLEARANCE := {"racks": ["rackRelayA", "rackRelayB"], "sorting": ["sortRelayA", "sortRelayB"], "security": ["reserveA", "reserveB"], "reclamation": ["cageA", "cageB"], "vault": ["clampA", "clampB"]}
const STAGE_ORDER: Array[String] = ["roof", "racks", "sorting", "freight", "transfer", "security", "reclamation", "vault", "escape", "finale"]
const MIN_Y := {"roof": 20.0, "racks": 10.5, "sorting": 3.0, "freight": 2.0, "transfer": -12.8, "security": -19.0, "reclamation": -25.0, "vault": -30.0, "escape": -30.0, "finale": -3.0}
const CARGO_TEXT := {0: "Land on the receiving deck", 1: "Jump onto the raised crate", 2: "Jump to the crane station", 3: "Jump onto the crane when it stops", 4: "Ride across, jump off at the far station", 5: "Jump onto the piston and ride it up", 6: "Jump to the upper landing", 7: "Jump onto the moving beam", 8: "Ride it across, jump to the refuge", 9: "Jump to the waiting bay", 10: "Cross under the press when the lamp is green", 11: "Jump onto the press exit", 12: "Jump onto the first shuttle", 13: "Jump onto the lower shuttle", 14: "Jump onto the exit landing"}

var api: WarehouseLevel
var K: Dictionary = WhData.TUNING
var stage := "roof"
var time := 0.0
var age := 0.0
var queue: Array[Dictionary] = []
var units: Array[Dictionary] = []
var flags: Dictionary = {}
var hold_id := ""
var hold := 0.0
var checkpoint := "roof"
var lift_y := 4.0
var lift_x := 0.0
var lifting := false
var freight_released_at: Variant = null
var finished := false
var batch := 0
var spawn_clock := 0.0
var alarm := false
var kills := 0
var clearance_at: Variant = null
var course_index := 0
var lesson: Variant = null
var lesson_text := ""
var lesson_until := 0.0
var blocked_entry: Variant = null
var finale_retry := 0
var last_player: Player = null
var enter_opts := {"retry": false, "index": 0}
var initialized := false
var controls: Array[Dictionary] = []
var stats := {"spawned": 0, "recovered": 0, "peak": 0, "retired": 0}
var boss_checkpoint: Dictionary


func _init(p_api: WarehouseLevel, p_controls: Array) -> void:
	api = p_api
	for c: Dictionary in p_controls:
		controls.append(c.duplicate())
	boss_checkpoint = {"x": float(K.boss.x), "y": 0.0, "z": 190.0, "yaw": PI}


func _schedule(nm: String, delay: float = 0.0, override_door: Variant = null) -> void:
	var list: Array = WhData.WAVES.get(nm, [])
	for i in list.size():
		var w: Array = list[i]
		var types: Array[String] = []
		var kinds := ["robot", "drone", "mech", "guard", "spider"]
		for k in kinds.size():
			for _n in int(w[k]) if k < w.size() else 0:
				types.append(kinds[k])
		var intro: Variant = K.introductions.get(nm)
		var introduction: Variant = intro.kind if intro != null and int(intro.batch) == i else null
		if introduction != null:
			var first := types.find(introduction)
			if first >= 0:
				types.remove_at(first)
				types.push_front(introduction)
		var door: int
		if override_door != null:
			door = override_door
		elif nm == "finale":
			door = i % 4
		elif nm == "freightA":
			door = 1
		elif nm == "freightB":
			door = 2 if i == 0 else 1
		elif nm == "clampA":
			door = 1
		else:
			door = i % 2
		var interval := 26.0 if nm == "finale" else float(K.pacing.followup)
		# A room's first wave meets the player at the door; each later one answers a step of the plan (the room's own "the alarm heard that"), or walks in on its own if the player camps.
		var paced := CLEARANCE.has(nm) and i > 0
		batch += 1
		queue.append({"id": batch, "at": INF if paced else time + delay + i * interval, "after": i if paced else 0, "fallback": time + float(K.pacing.camp) * i if paced else 0.0, "types": types, "index": 0, "name": nm, "door": door, "round": i + 1, "introduction": introduction, "followup": i > 0 and nm != "finale" and not paced, "warned": false, "flanked": false, "blocked_at": 0.0})


func _clear() -> void:
	for u: Dictionary in units:
		api.dir_remove(u.actor)
	units.clear()
	queue.clear()
	api.dir_clear_projectiles()
	lesson = null
	lesson_text = ""
	lesson_until = 0.0
	blocked_entry = null


func enter(next: String, P: Player, C: Combat, variant: int = 0) -> void:
	var raised_alarm := not alarm and next != "roof"
	alarm = next != "roof"
	_clear()
	stage = next
	age = 0.0
	hold = 0.0
	hold_id = ""
	checkpoint = next
	kills = 0
	clearance_at = null
	course_index = 0
	spawn_clock = 0.0
	for s: String in STAGE_ORDER:
		api.dir_exit_gate(s, STAGE_ORDER.find(s) < STAGE_ORDER.find(next))
	flags = {}
	freight_released_at = null
	lifting = false
	if STAGE_ORDER.find(next) >= 4:
		lift_y = -4.0
		lift_x = WhData.DEPTH_X
	else:
		lift_y = 4.0
		lift_x = 0.0
	api.dir_lift(lift_y, lift_x)
	api.dir_gate(next == "escape" or next == "finale")
	api.dir_dock_bridge(next == "finale")
	if next == "escape" or next == "finale":
		flags = {"clampA": true, "clampB": true, "cartridge": true}
	finale_retry = variant if next == "finale" else 0
	api.dir_boss_reset(variant if next == "finale" else 0)
	if next == "finale" and variant != 0:
		flags["bossReady"] = true
		flags["bossStarted"] = true
	api.dir_checkpoint(boss_checkpoint if variant != 0 else WhData.CHECKPOINTS[next], P, C)
	if variant == 0:
		_schedule(next, K.pacing.arrival)
	api.dir_stage_entered(next, enter_opts)
	enter_opts = {"retry": false, "index": 0}
	if raised_alarm:
		api.dir_alarm()


func restore(P: Player, C: Combat) -> void:
	var next := checkpoint
	var variant := finale_retry
	enter_opts = {"retry": true, "index": 0}
	enter(next, P, C, variant)
	api.dir_teleport(boss_checkpoint if variant != 0 else WhData.CHECKPOINTS[next], P)


func load_checkpoint(next: String, P: Player, C: Combat, index: int = 0) -> bool:
	if not WhData.CHECKPOINTS.has(next) or P == null or C == null:
		return false
	if next == "finale":
		index = clampi(index, 0, 3)
	var variants: Dictionary = K.variants.get(next, {})
	var override: Variant = variants.get(str(index))
	finished = false
	initialized = true
	enter_opts = {"retry": false, "index": index if override != null else 0}
	enter(next, P, C, index if next == "finale" else 0)
	var point: Dictionary = boss_checkpoint if next == "finale" and index != 0 else WhData.CHECKPOINTS[next]
	if override != null:
		# Optional F6 entries (Freight catwalk, mid-chase escape) start mid-stage: skip what they pass.
		point = override.duplicate()
		point.x = float(override.x) + (float(WhData.DEPTH_X) if override.get("local", false) else 0.0)
		for beat: Dictionary in K.beats:
			if beat.stage == next and beat.has("x") and float(WhData.DEPTH_X) + float(beat.x) < float(point.x):
				flags[beat.id] = true
		if override.get("skipWave", false):
			var kept: Array[Dictionary] = []
			for w: Dictionary in queue:
				if w.name != next:
					kept.append(w)
			queue = kept
	if next == "transfer":
		var pads := api.dir_transfer_pads()
		index = clampi(index, 0, pads.size() - 1)
		if index < pads.size():
			point = pads[index]
		course_index = index + 1
		# Testing a late subsection must not summon the skipped course's fights.
		for beat: Dictionary in K.beats:
			if beat.stage == next and beat.has("course") and int(beat.course) < course_index:
				flags[beat.id] = true
	var tp := point.duplicate()
	tp.yaw = point.get("yaw", PI / 2.0)
	api.dir_teleport(tp, P)
	P.hp = P.max_hp
	P.dead = false
	P.invuln = 2.5
	api.dir_message("TEST CHECKPOINT / " + next.to_upper())
	return true


func recover_course(P: Player, reason: String = "MISSED LANDING") -> void:
	var pads := api.dir_transfer_pads()
	var i := maxi(0, course_index - 1)
	while i > 0 and not (i < pads.size() and pads[i].get("checkpoint", false)):
		i -= 1
	var safe: Dictionary = pads[i] if i < pads.size() else WhData.CHECKPOINTS["transfer"]
	course_index = i + 1
	var tp := safe.duplicate()
	tp.yaw = PI / 2.0
	api.dir_teleport(tp, P)
	stats.recovered += 1
	api.dir_message(reason + " / BACK TO THE LAST LANDING")


func available(c: Dictionary) -> bool:
	if c.stage != stage or flags.get(c.id, false) or finished or lifting:
		return false
	if c.id == "lift":
		return flags.get("liftReady", false)
	if c.id == "cartridge":
		return flags.get("clearance", false)
	if c.id == "getaway":
		return flags.get("finaleClear", false)
	if c.id == "foreman":
		return flags.get("bossReady", false) and not flags.get("bossStarted", false)
	return true


func activate(id: String, P: Player, C: Combat) -> bool:
	var c: Variant = null
	for q: Dictionary in controls:
		if q.id == id:
			c = q
	if c == null or not available(c):
		return false
	flags[id] = true
	hold = 0.0
	api.dir_operated(id)
	if id == "lift":
		lifting = true
		queue.clear()
		for u: Dictionary in units:
			api.dir_remove(u.actor)
		units.clear()
		api.dir_clear_projectiles()
		_schedule("freightRide", 0.0, 3)
	elif id == "cartridge":
		enter("escape", P, C)
		api.dir_gate(true)
	elif id == "getaway":
		finished = true
		_clear()
	elif id == "foreman":
		flags["bossStarted"] = true
		finale_retry = 1
		api.dir_boss_reset(1)
		api.dir_checkpoint(boss_checkpoint, P, C)
	else:
		_schedule(id, 1.5)
	if flags.get("freightA", false) and flags.get("freightB", false) and freight_released_at == null:
		freight_released_at = time
	return true


func _queued_left() -> int:
	var n := 0
	for w: Dictionary in queue:
		n += (w.types as Array).size() - int(w.index)
	return n


func _alive_units() -> Array[Dictionary]:
	var a: Array[Dictionary] = []
	for u: Dictionary in units:
		if not (u.actor as Robot).dead:
			a.append(u)
	return a


func tick(dt: float, P: Player, C: Combat) -> void:
	if P == null or dt <= 0.0 or P.dead or finished:
		return
	last_player = P
	time += dt
	age += dt
	spawn_clock -= dt
	if not initialized:
		initialized = true
		api.dir_checkpoint(WhData.CHECKPOINTS["roof"], P, C)
		_schedule("roof")
		api.dir_level_start()
	var DX := float(WhData.DEPTH_X)
	# Ordered route volumes: skipping floors returns to the current checkpoint.
	var cl: bool = flags.get("clearance", false)
	if stage == "roof" and P.z > -24.0 and P.y < 20.2 and P.y > 16.0:
		enter("racks", P, C)
	elif stage == "racks" and cl and P.x > 28.0 and P.z < -8.0 and P.y < 13.5:
		enter("sorting", P, C)
	elif stage == "sorting" and cl and P.x < 25.5 and P.z > 11.0 and P.y < 5.5:
		enter("freight", P, C)
	elif stage == "transfer" and course_index >= api.dir_transfer_pads().size() and P.z > 39.0 and P.y < -11.0:
		enter("security", P, C)
	elif stage == "security" and cl and P.z > 103.0 and P.y < -17.0:
		enter("reclamation", P, C)
	elif stage == "reclamation" and cl and P.z > 167.0 and P.y < -23.0:
		enter("vault", P, C)
	elif stage == "escape" and P.x > 183.0 + DX and P.y > -0.5:
		enter("finale", P, C)
	var min_y: float = MIN_Y[stage]
	if not lifting and (P.y < min_y or P.x < -35.0 or P.x > 218.0 + DX or P.z < -51.0 or P.z > 215.0):
		var locked_sorting: bool = stage == "racks" and not flags.get("clearance", false) and P.x > 28.0
		if stage == "transfer":
			recover_course(P)
		else:
			api.dir_teleport(WhData.CHECKPOINTS[checkpoint], P)
			stats.recovered += 1
			api.dir_message("SORTING LOCKED / FINISH DISPATCH FIRST" if locked_sorting else "FELL / BACK TO THE LAST CHECKPOINT")
	var i := units.size() - 1
	var cp_y := float(WhData.CHECKPOINTS[checkpoint].y)
	while i >= 0:
		var u: Dictionary = units[i]
		var r: Robot = u.actor
		if r.dead and not u.get("counted", false):
			u.counted = true
			kills += 1
		if (r.dead and r.dead_t > 4.0) or r.y < cp_y - 10.0 or time - float(u.at) > 180.0:
			api.dir_remove(r)
			units.remove_at(i)
			if not r.dead:
				stats.retired += 1
		i -= 1
	var alive := _alive_units()
	if lesson != null and time - float(lesson.at) >= float(K.pacing.introRead):
		flags["lessonComplete"] = true
		lesson = null
		lesson_until = time + 4.0
	for beat: Dictionary in K.beats:
		if stage == beat.stage and not flags.get(beat.id, false):
			var hit: bool = course_index >= int(beat.course) if beat.has("course") else P.x >= DX + float(beat.x)
			if hit:
				flags[beat.id] = true
				_schedule(beat.id, 0.0, beat.door)
	stats.peak = maxi(stats.peak, alive.size())
	var steps_done := 0
	for id: String in CLEARANCE.get(stage, []):
		if flags.get(id, false):
			steps_done += 1
	for q: Dictionary in queue:
		if int(q.after) != 0 and (steps_done >= int(q.after) or time >= float(q.fallback)):
			q.after = 0
			q.at = time + float(K.pacing.answer)
	var pending_intro: Variant = null
	for q: Dictionary in queue:
		if q.introduction != null and int(q.index) == 0:
			pending_intro = q
			break
	var w: Variant = null
	if lesson == null:
		for q: Dictionary in queue:
			if float(q.at) <= time and int(q.index) < (q.types as Array).size() and (pending_intro == null or int(q.id) <= int(pending_intro.id)) and (not q.followup or int(q.index) > 0 or alive.size() <= int(K.pacing.followupAlive)) and (q.introduction == null or int(q.index) > 0 or alive.is_empty()):
				w = q
				break
	if w != null and spawn_clock <= 0.0:
		# Later dock waves split into two clearly announced approaches. The first four arrivals establish one front before the opposite shutter opens.
		if w.name == "finale" and int(w.round) > 1 and int(w.index) == 4 and not w.flanked:
			w.flanked = true
			w.door = (int(w.door) + 2) % 4
			w.warned = false
		if not w.warned:
			w.warned = true
			api.dir_announce(stage, w.door)
			w.at = time + float(K.pacing.warning)
		else:
			var kind: String = w.types[w.index]
			var same := 0
			for u: Dictionary in alive:
				if u.kind == kind:
					same += 1
			if alive.size() < int(K.caps[stage]) and same < int(LIMITS[kind]):
				var actor: Robot = api.dir_spawn(kind, stage, w.door, P)
				if actor != null:
					units.append({"actor": actor, "kind": kind, "at": time})
					w.index = int(w.index) + 1
					stats.spawned += 1
					blocked_entry = null
				else:
					blocked_entry = int(w.door) + 1
					if float(w.blocked_at) == 0.0 or time - float(w.blocked_at) > 6.0:
						w.blocked_at = time
						w.warned = false
				var spacing: Dictionary = K.pacing.spacing
				spawn_clock = spacing.get(stage, spacing["default"])
				if actor != null and w.introduction != null and int(w.index) == 1:
					lesson = {"actor": actor, "kind": kind, "at": time}
					lesson_text = K.lessons[kind]
					lesson_until = INF
	i = queue.size() - 1
	while i >= 0:
		if int(queue[i].index) >= (queue[i].types as Array).size():
			queue.remove_at(i)
		i -= 1
	if stage == "finale" and not flags.get("bossReady", false) and queue.is_empty():
		if _alive_units().is_empty():
			flags["bossReady"] = true
			finale_retry = 1
			api.dir_clear_projectiles()
			P.hp = P.max_hp
			P.regen_t = 0.0
			api.dir_checkpoint(boss_checkpoint, P, C)
			api.dir_beat("apronClear")
	var B: Dictionary = api.dir_boss_state()
	if stage == "finale" and flags.get("bossStarted", false) and B.dead and not flags.get("finaleClear", false):
		flags["finaleClear"] = true
		_clear()
		api.dir_beat("foremanDown")
	# Paced shifts overlap up to five helpers; warn at doors during recovery.
	if stage == "finale" and flags.get("bossStarted", false) and not flags.get("finaleClear", false) and int(B.phase) >= 1 and (B.mode == "transition" or B.move == "recover") and queue.is_empty() and alive.size() <= 2 and time >= float(flags.get("nextBossWave", 0.0)):
		var support: Dictionary = K.boss.support
		var rnd: int = int(flags.get("bossWave", 0)) + 1
		flags["bossWave"] = rnd
		var ph: int = int(B.phase) - 1
		var types: Array[String] = []
		var wv: Array = support.waves[ph]
		for k in mini(wv.size(), int(support.cap) - alive.size()):
			types.append(wv[k])
		batch += 1
		queue.append({"id": batch, "at": time, "after": 0, "fallback": 0.0, "types": types, "index": 0, "name": "foremanSupport", "door": [1, 3, 2, 0][(rnd - 1) % 4], "round": rnd, "introduction": null, "followup": false, "warned": false, "flanked": false, "blocked_at": 0.0})
		flags["nextBossWave"] = time + float(support.interval[ph])
		# Physical flashing doors announce support without a mid-fight text toast.
	# The way on opens when the plan's steps are done and the room's waves are spent. The last straggler never holds a door shut.
	if CLEARANCE.has(stage):
		var all := true
		for id: String in CLEARANCE[stage]:
			if not flags.get(id, false):
				all = false
		if all:
			if clearance_at == null:
				clearance_at = time
			var introduced: bool = not K.introductions.has(stage) or flags.get("lessonComplete", false)
			if not flags.get("clearance", false) and queue.is_empty() and ((alive.size() <= int(K.pacing.straggler) and introduced) or (alive.size() <= 2 and time - float(clearance_at) >= float(K.pacing.clearTimeout))):
				flags["clearance"] = true
				api.dir_exit_gate(stage, true)
				api.dir_beat("cleared")
	if stage == "transfer":
		var pads := api.dir_transfer_pads()
		if course_index < pads.size():
			var nx: Dictionary = pads[course_index]
			if P.grounded and absf(P.y - float(nx.y)) < 0.35 and absf(P.x - float(nx.x)) < float(nx.get("hx", 1.5)) and absf(P.z - float(nx.z)) < float(nx.get("hz", 1.5)):
				course_index += 1
	# Kill pressure shortens the lift unlock, but stragglers can never lock the robbery.
	if stage == "freight" and freight_released_at != null and not flags.get("liftReady", false) and ((queue.is_empty() and alive.size() <= 4) or time - float(freight_released_at) >= 90.0):
		flags["liftReady"] = true
		api.dir_beat("liftReady")
	if lifting:
		var previous_x := lift_x
		if lift_y > -4.0:
			lift_y = maxf(-4.0, lift_y - 2.0 * dt)
		else:
			lift_x = minf(DX, lift_x + 12.0 * dt)
		api.dir_lift(lift_y, lift_x)
		P.x = clampf(P.x + lift_x - previous_x, lift_x - 4.0, lift_x + 4.0)
		P.z = clampf(P.z, -4.0, 4.0)
		P.y = lift_y
		P.vy = 0.0
		P.grounded = true
		P.mode = &"normal"
		if lift_y <= -4.0 and lift_x >= DX:
			enter("transfer", P, C)
	var near: Variant = null
	for c: Dictionary in controls:
		if available(c) and absf(P.y - float(c.y)) < 0.65 and U.hyp(P.x - float(c.x), P.z - float(c.z)) < float(c.get("reach", 1.8)):
			near = c
	if near != null and P.grounded and api.dir_interaction_held():
		if hold_id != near.id:
			hold_id = near.id
			hold = 0.0
		var ready: bool = api.dir_prepare_interaction(near, P, dt)
		if ready:
			hold += dt
			if hold >= float(K.interaction.hold):
				activate(near.id, P, C)
		else:
			hold = 0.0
	else:
		hold = 0.0
		hold_id = ""
	api.dir_hud({"near_id": near.id if near != null else "", "use_label": api.dir_interaction_label(near) if near != null else "", "progress": minf(1.0, hold / float(K.interaction.hold)) if near != null else 0.0, "blocked_entry": blocked_entry})


func _step_text(id: String) -> Variant:
	var d: Dictionary = WhData.DEPARTMENTS.get(stage, {})
	for q: Array in d.get("steps", []):
		if q[0] == id:
			return q[1]
	return null


func objective() -> Dictionary:
	if finished:
		return {"id": "complete", "text": "Extraction complete.", "target": null, "kind": "complete"}
	for c: Dictionary in controls:
		if available(c):
			var st: Variant = _step_text(c.id)
			return {"id": c.id, "text": st if st != null else c.label, "target": c, "kind": "control"}
	if stage == "roof" and api.dir_gate_locked():
		return {"id": "door", "text": "Jack into the panel beside the door", "target": api.dir_gate_target(), "kind": "route"}
	if stage == "roof":
		return {"id": "entry", "text": "Down the ramp into Dispatch", "target": {"x": 0.0, "y": 18.0, "z": -14.0}, "kind": "route"}
	if stage == "transfer":
		var pads := api.dir_transfer_pads()
		if course_index < pads.size():
			var pad: Dictionary = pads[course_index]
			return {"id": "cargo-%d" % course_index, "text": CARGO_TEXT.get(course_index, "Jump to %s." % pad.name), "target": pad, "kind": "jump"}
		return {"id": "reserve-exit", "text": "Take the ramp down to Reserve", "target": WhData.CHECKPOINTS["security"], "kind": "route"}
	if stage == "freight" and lifting:
		return {"id": "ride", "text": "Ride the carriage down. Shoot the drones.", "target": null, "kind": "ride"}
	if stage == "finale" and flags.get("bossStarted", false) and not flags.get("finaleClear", false):
		var B: Dictionary = api.dir_boss_state()
		return {"id": "boss", "text": B.label if B.label != "" else "Shoot its open eye", "target": {"x": B.x, "y": 7.1, "z": B.z}, "kind": "boss"}
	if flags.get("clearance", false) or stage == "escape":
		var next: Variant = {"racks": "sorting", "sorting": "freight", "security": "reclamation", "reclamation": "vault", "escape": "finale"}.get(stage)
		if next != null:
			var ex: String = ("RUN. The Compactor is behind you. Jump the gaps or take the side lane." if api.dir_chase_active() else "Jump the gaps or take the side lane to the apron") if stage == "escape" else String(WhData.DEPARTMENTS[stage].get("exit", ""))
			return {"id": "exit-" + stage, "text": ex, "target": WhData.CHECKPOINTS[next], "kind": "route"}
	var best: Variant = null
	var bd := INF
	var lp := last_player
	for u: Dictionary in _alive_units():
		var r: Robot = u.actor
		var d := U.hyp(r.x - (lp.x if lp != null else 0.0), r.z - (lp.z if lp != null else 0.0))
		if d < bd:
			bd = d
			best = {"x": r.x, "y": r.y, "z": r.z}
	var target: Variant = best if best != null else api.dir_entry(stage, int(queue[0].door) if queue.size() > 0 else 0)
	return {"id": "patrol-" + stage, "text": "Clear the patrol" if best != null else "More security coming", "target": target, "kind": "combat"}


## JS mission.js planFor: the plan as the HUD shows it right now: goal, the checklist (done / current / to do) and what's left of the room's security
func plan_for(left: int, objective_text: String) -> Variant:
	var d: Variant = WhData.DEPARTMENTS.get(stage)
	if d == null:
		return null
	var current := false
	var steps: Array[Dictionary] = []
	for q: Array in d.get("steps", []):
		var id: String = q[0]
		var ok: bool
		match id:
			"clear":
				ok = flags.get("clearance", false)
			"patrol":
				ok = flags.get("bossReady", false)
			"boss":
				ok = flags.get("finaleClear", false)
			"foreman":
				ok = flags.get("bossStarted", false)
			_:
				ok = flags.get(id, false)
		var now := not ok and not current
		if now:
			current = true
		var combat := id == "clear" or id == "patrol"
		steps.append({"id": id, "text": "%s: %d left" % [q[1], left] if combat and now and left > 0 else q[1], "done": ok, "now": now})
	var all_done := true
	for s: Dictionary in steps:
		if not s.done:
			all_done = false
	var exit_: bool = flags.get("clearance", false) and d.has("exit") and all_done
	return {"no": d.no, "name": d.name, "goal": "Robbery complete" if finished else (d.exit if exit_ else d.goal), "steps": [] if finished or exit_ else steps, "total": WhData.LEVEL_TOTAL, "hint": null if steps.size() > 0 else objective_text, "card": d.card}


## JS get state (the parts the level's views read)
func state() -> Dictionary:
	var alive := _alive_units().size()
	var left := alive + _queued_left()
	var o := objective()
	return {"stage": stage, "time": time, "age": age, "flags": flags, "checkpoint": checkpoint, "lift_y": lift_y, "lift_x": lift_x, "lifting": lifting, "alarm": alarm, "finished": finished, "kills": kills, "course_index": course_index, "lesson": lesson_text if time < lesson_until else null, "queue": queue.size(), "alive": alive, "left": left, "boss": api.dir_boss_state() if stage == "finale" else null, "objective": o, "plan": plan_for(maxi(0, left - int(K.pacing.straggler)), String(o.text))}
