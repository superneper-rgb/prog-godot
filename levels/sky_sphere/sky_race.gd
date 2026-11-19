class_name SkyRace
extends Node3D
## One six-craft Overcurrent race, from the starting lamps to the finishing order. Every craft is driven physics (race_car.gd): the player's by
## the stick, the rivals' by race_brain.gd. On top: Burnout-style takedowns (slam a rival into a wall, shunt him, pin him, knock him off the
## edge) that fill and grow a boost meter; near misses, drafting, drifting and air fill it too; Mario Kart drift mini-turbos, boost pads, a
## rocket start and a trick off a jump; smashable stacks (sky_props.gd); slow-motion takedown and crash
## cameras with aftertouch; pickups from item boxes and Hydro Thunder boost icons (sky_items.gd), crushers, a collapsing gantry and a column
## (sky_set_pieces.gd). One long run, start line to finish, checkpoints on the way (user, 2026-11-18: it was 3 laps of a short circuit).
## Rebuilt 2026-11-18 (user: the old race felt "on an automatic track"; it moved points along the course by distance).

const SUB := 1.0 / 120.0
const START_LINE := SkyVenue.START_LINE
const CRAFT: Array[StringName] = [&"saucerB", &"saucerG", &"saucerN", &"skyDart", &"skyLimo", &"saucerG"]
const PAINT: Array[Color] = [Color("1f4fae"), Color("2dde7b"), Color("ffd577"), Color("f35292"), Color("c587fd"), Color("ed653b")]
const SIZE: Array[Vector3] = [Vector3.ONE, Vector3(0.90, 0.92, 0.92), Vector3(1.19, 1.04, 0.95), Vector3(1.06, 0.93, 1.06), Vector3(1.07, 0.98, 1.12), Vector3(1.33, 0.80, 1.19)]
const NAMES: Array[String] = ["PAULY", "GLIM", "OOZO", "VEXX", "BIG LIMO", "RUSTA"]
const GRID: Array[int] = [3, 0, 1, 2, 4, 5]
const MASS: Array[float] = [1.0, 0.86, 1.1, 0.94, 1.32, 0.95]
const TOP: Array[float] = [82.0, 80.5, 81.0, 83.0, 79.5, 81.0]
const SKILL: Array[float] = [1.0, 0.95, 0.96, 0.99, 0.93, 0.95]
const MEAN: Array[float] = [0.0, 0.25, 0.55, 0.4, 0.9, 0.5]
const WALL_WRECK := 33.0            # closing speed into a wall that wrecks a rival
const WALL_WRECK_SHAKEN := 10.0     # ... one that was just slammed (Burnout: a shove into the wall is a takedown)
const PLAYER_WALL_WRECK := 52.0     # the player only goes down near head-on (user, 2026-11-18: "you burnout too easy"; raised again 2026-11-19)
const PLAYER_WALL_SHAKEN := 40.0
const PLAYER_TOUGH := 1.3            # how much harder anything else (debris, the column, wreckage, a shunt) has to hit the player to wreck him
const GHOST_PLAYER := 2.6            # seconds untouchable after a respawn (user, 2026-11-19: a little longer; was 1.6)
const GHOST_RIVAL := 2.0
const SHUNT := 22.0                 # rear-end closing speed that wrecks the one in front
const HEAD_ON := 38.0
const SEGMENT_TIME := 1.9           # seconds of boost in one meter segment (was 2.4: with everything refilling it, the boost never ran out)
const POP_TIME := 1.7



class Racer:
	var model: CityCars.CarModel
	var car := RaceCar.new()
	var size := Vector3.ONE
	var jets: SkyDriveFx.Exhaust = null
	var brain: RaceBrain = null
	var controls := RaceCar.Controls.new()
	var index := 0
	var title := ""
	var progress := 0.0
	var last_s := 0.0
	var finished := false
	var meter := 1.0
	var meter_max := 2.0
	var takedowns := 0
	var wreck_t := 0.0
	var ghost := 0.0
	var hit_by: Racer = null
	var hit_t := -99.0
	var pinned := 0.0
	var pinned_by: Racer = null
	var touching: Racer = null
	var touch_t := -99.0
	var scrape := 0.0
	var flip_t := 0.0
	var safe_path := SkyCourse.MAIN
	var safe_i := 0
	var safe_u := 0.0
	var ahead_of: Dictionary = {}    # other racer -> it was ahead of me last frame (near misses)
	var trick := 0.0
	var tricked := false
	var fx_t := 0.0
	var air_paid := false
	var knock_t := -99.0             # when the player was last knocked about (he does not wreck)
	var rank := 1
	var base_mass := 1.0
	var hit_how := ""                # what last knocked it about (MINE, PULSE, RAM, HARPOON, SLAM): names the takedown
	var item := -1                   # SkyItems: what it holds
	var item_next := -1
	var roulette := 0.0
	var item_t := 0.0
	var shell := 0.0
	var harpoon := 0.0
	var harpoon_to: Racer = null
	var over := 0.0


class Callout:
	var text := ""
	var sub := ""
	var hot := false
	var big := false
	var age := 0.0


var on := false
var play := false
var camera := View.Shot.new()
var course: SkyCourse
var racers: Array[Racer] = []
var everyone: Array[Racer] = []
var popups: Array[Callout] = []
var place := 1
var checkpoint := 0                # checkpoints passed
var flash := 0.0
var draft := 0.0
var boost := 0.0
var results := false
var takedowns := 0
var wrong_way := false
var _venue: SkyVenue
var _props: SkyProps
var _set: SkySetPieces
var _items: SkyItems
var _driver: Racer
var _crew: RigCrew
var _pauly_waiting: GrayAlienNpc
var _audio: SkyDriveFx
var _count := 0.0
var _lamps := 0
var _race_time := 0.0
var _finish := 0.0
var _finished_n := 0
var _rocket_tried := false
var _rocket := false
var _bog := 0.0
var _slow_t := 0.0
var _cam_off := Vector3.ZERO
var _cam_up := Vector3.UP
var _cam_fwd := Vector3.BACK
var _cam_shake := 0.0
var _cam_snap := true
var _wrong_t := 0.0
var _steer_seen := 0.0
var wreck_log: Array[String] = []   # what took each craft out, for tests and tuning
var item_log: Array[String] = []    # who used what, when


func build(road: SkyCourse, paddock: SkyVenue, pauly: GrayAlienNpc) -> void:
	name = "OvercurrentRacers"
	course = road
	_venue = paddock
	_pauly_waiting = pauly
	var cars := CityCars.new()
	cars.set_sky(Vector3(0.042, 0.066, 0.11), Vector3(0.10, 0.09, 0.23), Vector3(0.03, 0.04, 0.11))
	for i in CRAFT.size():
		var r := _make(cars, CRAFT[i], PAINT[i], i + 2, SIZE[i], MASS[i])
		r.index = i
		r.title = NAMES[i]
		r.car.top = TOP[i]
		r.model.root.name = "Racer_%d" % (i + 1)
		var port := Vector3(0.67, 0.61, -1.79)
		if CRAFT[i] != &"saucerB":
			port = Vector3(0.69, 0.57, -1.48) * SIZE[i]
			if CRAFT[i] == &"skyLimo":
				port.z -= 1.0
		r.jets = SkyDriveFx.Exhaust.new(r.model.root, [port, Vector3(-port.x, port.y, port.z)], Color("59c9ff") if i == 0 else PAINT[i].lightened(0.21))
		var plate := SkyGeometry.sign_text(r.model.chassis, "%02d" % (i + 1), port + Vector3(-port.x, 0.32, -0.07), 0.004, Color("ceebff"), &"orb800")
		plate.rotation.y = PI
		if i > 0:
			r.brain = RaceBrain.new()
			r.brain.skill = SKILL[i]
			r.brain.mean = MEAN[i]
			r.brain.lane = (float(i % 3) - 1.0) * 1.4
		racers.append(r)
		everyone.append(r)
	_driver = racers[0]
	_crew = RigCrew.new(_driver.model)
	_crew.move_player = false
	HubRaceRig._scuff(_driver.model.root, 0.42, 1.0)
	HubRaceRig._scuff(_driver.model.door, 0.5, 1.0, Color.hex((HubRaceRig.RED << 8) | 0xff))
	_audio = SkyDriveFx.new()
	add_child(_audio)
	_audio.build()
	_props = SkyProps.new()
	add_child(_props)
	_props.build(course)
	_set = SkySetPieces.new()
	add_child(_set)
	_set.build(self)
	_items = SkyItems.new()
	add_child(_items)
	_items.build(self)
	_line_up()
	_park_saucer()


func _make(cars: CityCars, kind: StringName, paint: Color, seed: int, size: Vector3, mass: float) -> Racer:
	var r := Racer.new()
	r.model = cars.model(kind, paint, seed)
	add_child(r.model.root)
	r.size = size
	r.model.chassis.scale = size
	r.car.setup(size)
	r.car.mass = mass
	r.base_mass = mass
	return r


func set_pieces() -> SkySetPieces:
	return _set


func player_racer() -> Racer:
	return _driver


func racing() -> bool:
	return on and _count <= 0.0 and not results


func start() -> void:
	on = true
	results = false
	place = 4
	checkpoint = 0
	flash = 0.0
	draft = 0.0
	boost = 0.0
	takedowns = 0
	wrong_way = false
	popups.clear()
	wreck_log.clear()
	item_log.clear()
	_count = 3.6
	_race_time = 0.0
	_finish = 0.0
	_finished_n = 0
	_rocket_tried = false
	_rocket = false
	_bog = 0.0
	_slow(1.0, 0.0)
	_venue.set_start_lamps(0)
	_line_up()
	_props.reset()
	_set.reset()
	_items.reset()
	var p := Game.player
	p.vx = 0.0
	p.vz = 0.0
	p.vy = 0.0
	p.aiming = false
	p.ads = false
	p.scoped = false
	p.strafing = false
	p.sprinting = false
	p.crouching = false
	p.grounded = true
	p.mode = &"normal"
	_pauly_waiting.set_shown(false)
	_crew.brace = 0.0
	_crew.board()
	_update_riders(0.016)
	_cam_snap = true
	_update_camera(1.0, 1.0)
	_audio.suspend(false)
	_audio.start()
	Game.hud.set_suppressed(true)
	Inp.guard_arm()


func stop() -> void:
	if not on:
		return
	on = false
	results = false
	_slow(1.0, 0.0)
	_crew.leave()
	# The walking position stayed at the counter while the car was on the track.
	var animator := Game.animator
	if animator != null and animator.seat == null:
		animator.seat_last = null
		animator.w_seat = 0.0
	_pauly_waiting.set_shown(true)
	_audio.stop()
	_items.reset()
	_venue.set_start_lamps(0)
	_line_up()
	_park_saucer()
	Game.hud.set_suppressed(false)
	Inp.guard_arm()


func tick(dt: float) -> void:
	if not on:
		return
	_audio.suspend(Game.paused or Game.forge.is_open or (Game.freecam != null and Game.freecam.on) or results)
	if dt <= 0.0 or results:
		return
	var real := Game.frame_real_dt
	if _slow_t > 0.0:
		_slow_t -= real
		if _slow_t <= 0.0:
			Game.time_scale = 1.0
	_player_controls(_driver)
	if _count > 0.0:
		_countdown(dt)
	else:
		_race_time += dt
	if _bog > 0.0:
		_bog -= dt
		if _bog <= 0.0:
			_driver.car.held = false
	for r: Racer in everyone:
		if r.brain != null:
			r.brain.drive(r, self, dt)
		_meter_burn(r, dt)
		r.touching = null
		r.scrape = 0.0
	var steps := maxi(1, ceili(dt / SUB))
	var sub := dt / steps
	for s in steps:
		for r: Racer in everyone:
			r.car.step(sub, r.controls, course)
			r.scrape = maxf(r.scrape, r.car.scrape)
		_collide_cars()
		for r: Racer in everyone:
			_consume_hits(r)
	_props.tick(dt)
	_items.tick(dt)
	_set.tick(dt)
	if racing() and _finish == 0.0 and (Inp.btn(&"crouch").pressed or Inp.btn(&"attack").pressed or (not Inp.using_pad and Inp.btn(&"fire").pressed)):
		_items.use(_driver)
	for r: Racer in everyone:
		_after_frame(r, dt)
	_rank()
	for p: Callout in popups:
		p.age += real
	while not popups.is_empty() and popups[0].age > POP_TIME:
		popups.pop_front()
	flash = move_toward(flash, 0.0, real * 3.0)
	boost = _driver.car.boost_amt
	_update_camera(dt, real)
	_audio.rev(dt, maxf(0.0, _driver.car.speed), _driver.controls.throttle if not _driver.car.wrecked else 0.0, boost)
	_audio.slide(dt, clampf((absf(_driver.car.slip) - 0.12) * 3.0, 0.0, 1.0) if _driver.car.grounded else 0.0, _driver.scrape)
	for r: Racer in everyone:
		_show(r, dt)
	_update_riders(dt)


func race_time() -> float:
	return _race_time


func cue(sound: SkyDriveFx.Cue) -> void:
	_audio.cue(sound)


## A cue for something that happened at a place: only heard when it is near the player.
func cue_near(sound: SkyDriveFx.Cue, at: Vector3) -> void:
	if at.distance_to(_driver.car.pos) < 70.0:
		_audio.cue(sound)


## The player's item: what it is (SkyItems), whether the roulette is still spinning.
func item() -> int:
	return _driver.item


func item_rolling() -> bool:
	return _driver.roulette > 0.0


func overcharged() -> bool:
	return _driver.over > 0.0


func speed_kmh() -> int:
	return roundi(maxf(0.0, _driver.car.vel.length()) * 3.6)


func meter() -> float:
	return _driver.meter


func meter_max() -> float:
	return _driver.meter_max


func boosting() -> bool:
	return _driver.car.boosting


## 0 none, 1 blue, 2 orange, 3 purple: the drift's mini-turbo so far.
func drift_tier() -> int:
	var c := _driver.car
	if not c.drifting:
		return 0
	if c.drift_charge >= 3.0:
		return 3
	if c.drift_charge >= 1.8:
		return 2
	if c.drift_charge >= 0.8:
		return 1
	return 0


func pose_player(animator: Animator) -> void:
	animator.actor.visible = true


func pop(text: String, sub: String = "", hot: bool = false, big: bool = false) -> void:
	for p: Callout in popups:
		if p.text == text and p.age < 0.5:
			p.sub = sub
			p.age = 0.0
			return
	var p := Callout.new()
	p.text = text
	p.sub = sub
	p.hot = hot
	p.big = big
	popups.append(p)
	if popups.size() > 3:
		popups.pop_front()


# ------------------------------------------------------------------ start ----

func _line_up() -> void:
	_lamps = 0
	var m := course.paths[SkyCourse.MAIN]
	for r: Racer in racers:
		var slot := GRID[r.index]
		var s := START_LINE - 11.5 - floorf(slot / 2.0) * 9.6
		var i := clampi(m.metres.bsearch(s), 0, m.size() - 1)
		var across := -3.3 if slot % 2 == 0 else 3.3
		r.car.place(course, SkyCourse.MAIN, i, across, 0.0)
		r.car.held = true
		r.car.boosting = false
		r.progress = m.metres[i] - START_LINE
		r.last_s = m.metres[i]
		r.finished = false
		r.meter = 1.0
		r.meter_max = 2.0
		r.takedowns = 0
		r.ghost = 0.0
		r.wreck_t = 0.0
		r.hit_by = null
		r.pinned = 0.0
		r.flip_t = 0.0
		r.trick = 0.0
		r.tricked = false
		r.ahead_of.clear()
		r.safe_path = SkyCourse.MAIN
		r.safe_i = i
		r.safe_u = across
		r.controls = RaceCar.Controls.new()
		if r.brain != null:
			r.brain.takes.clear()
			for br: SkyCourse.Branch in course.branches:
				r.brain.takes[br.title] = randf() < (0.35 if br.risky else 0.55)
		_show(r, 0.0)


func _countdown(dt: float) -> void:
	_count = maxf(0.0, _count - dt)
	var lamps := 4 - ceili(_count)
	if lamps != _lamps:
		_lamps = lamps
		_venue.set_start_lamps(lamps)
		_audio.cue(SkyDriveFx.Cue.GO if lamps == 4 else SkyDriveFx.Cue.TICK)
	# a rocket start: on the gas just as the last lamp is about to go; too early and the engine bogs
	if not _rocket_tried and _driver.controls.throttle > 0.5:
		_rocket_tried = true
		if _count > 0.0 and _count < 0.5:
			_rocket = true
		elif _count > 1.15:
			_bog = 0.7
	if _count <= 0.0:
		for r: Racer in racers:
			r.car.held = false
		if _rocket:
			_driver.car.turbo = 1.3
			pop("ROCKET START", "", true)
			_audio.cue(SkyDriveFx.Cue.BOOST)
		elif _bog > 0.0:
			_driver.car.held = true
			pop("BOGGED DOWN")
		# (no input guard at GO: boost held through the lamps works off the line; the guard made it dead until pressed again)


func _park_saucer() -> void:
	_driver.model.root.global_transform = Transform3D(Basis(Vector3.UP, PI * 0.08), SkyVenue.PARKED)


# ---------------------------------------------------------------- driving ----

func _player_controls(r: Racer) -> void:
	var c := r.controls
	var pad := Inp.using_pad
	c.throttle = Inp.rt if pad else maxf(0.0, Inp.move.y)
	c.brake = Inp.lt if pad else maxf(0.0, -Inp.move.y)
	# keys are all or nothing: they turn the stick in over about a fifth of a second, and let it back faster
	var want := -Inp.move.x
	if pad:
		_kb_steer = want
	else:
		_kb_steer = move_toward(_kb_steer, want, Game.frame_real_dt * (5.0 if absf(want) > absf(_kb_steer) and signf(want) == signf(_kb_steer) or _kb_steer == 0.0 else 9.0))
	c.steer = _kb_steer
	# the e-brake (pad A, LB, keyboard Space): held, it locks the rear and scrubs speed; held while steering, it kicks into a drift
	c.drift = Inp.btn(&"strafe").held or Inp.btn(&"jump").held
	# boost: held, Shift on the keyboard, L3 on the pad (user, 2026-11-18: hold L3, not a click on and off)
	c.boost = Inp.btn(&"sprint").held or (pad and Inp.btn(&"l3").held)
	c.aftertouch = Vector2(c.steer, c.throttle - c.brake) if r.car.wrecked else Vector2.ZERO
	if _finish > 0.0:
		c.throttle = 0.3
		c.brake = 0.0
		c.boost = false
		c.drift = false
	# a trick off a jump: the drift button in the air
	var trick_btn := Inp.btn(&"strafe").pressed or Inp.btn(&"jump").pressed
	if trick_btn and r.car.air > 0.12 and not r.tricked and not r.car.wrecked:
		r.tricked = true
		r.trick = 0.55
		_audio.cue(SkyDriveFx.Cue.TICK)


func _meter_burn(r: Racer, dt: float) -> void:
	var want := r.controls.boost and r.meter > 0.0 and not r.car.wrecked and not r.car.held and _count <= 0.0
	if want and not r.car.boosting and r.meter < 0.12:
		want = false      # (a sliver is not worth starting on)
	r.car.boosting = want
	if want:
		r.meter = maxf(0.0, r.meter - dt / SEGMENT_TIME)
		if r == _driver and not _was_boosting:
			_audio.cue(SkyDriveFx.Cue.BOOST)
	if r == _driver:
		_was_boosting = want

var _was_boosting := false
var _kb_steer := 0.0


func _collide_cars() -> void:
	var n := everyone.size()
	for ia in n:
		var a := everyone[ia]
		if a.ghost > 0.0 or a.car.held and a.car.vel == Vector3.ZERO and _count > 0.0:
			continue
		for ib in range(ia + 1, n):
			var b := everyone[ib]
			if b.ghost > 0.0:
				continue
			var d := b.car.pos - a.car.pos
			if d.length_squared() > 49.0:
				continue
			var ra := a.car.half.x * 1.02
			var rb := b.car.half.x * 1.02
			var la := a.car.half.z - a.car.half.x
			var lb := b.car.half.z - b.car.half.x
			# closest points of the two body capsules
			var pa := a.car.pos
			var pb := b.car.pos
			var ta := clampf((pb - pa).dot(a.car.basis.z), -la, la)
			var ca := pa + a.car.basis.z * ta
			var tb := clampf((ca - pb).dot(b.car.basis.z), -lb, lb)
			var cb := pb + b.car.basis.z * tb
			ta = clampf((cb - pa).dot(a.car.basis.z), -la, la)
			ca = pa + a.car.basis.z * ta
			var off := cb - ca
			var dist := off.length()
			var pen := ra + rb - dist
			if pen <= 0.0:
				continue
			var nrm := off / maxf(dist, 0.001)
			# craft shove each other along the road, never into it (a knock in the pack pushed one down through the deck)
			var deck_up := a.car.road.basis.y
			var flat := nrm - deck_up * nrm.dot(deck_up)
			if flat.length_squared() > 0.01:
				nrm = flat.normalized()
			var at := ca + nrm * ra
			var ma := a.car.mass
			var mb := b.car.mass
			a.car.pos -= nrm * (pen * mb / (ma + mb))
			b.car.pos += nrm * (pen * ma / (ma + mb))
			var rel := b.car.point_velocity(at) - a.car.point_velocity(at)
			var vn := rel.dot(nrm)
			a.touching = b
			b.touching = a
			a.touch_t = _race_time
			b.touch_t = _race_time
			if vn >= 0.0:
				continue
			var j := -(1.0 + 0.3) * vn / (a.car.give(at, nrm) + b.car.give(at, nrm))
			var tv := rel - nrm * vn
			var jt := Vector3.ZERO
			if tv.length() > 0.01:
				jt = tv.normalized() * minf(0.2 * j, tv.length() / (a.car.give(at, tv.normalized()) + b.car.give(at, tv.normalized())))
			a.car.impulse(-(nrm * j + jt), at)
			b.car.impulse(nrm * j + jt, at)
			_car_hit(a, b, -vn, at, nrm)


## What a knock between two craft means: who hit whom, how hard, and whether that was a takedown.
func _car_hit(a: Racer, b: Racer, closing: float, at: Vector3, nrm: Vector3) -> void:
	if closing > 5.0:
		Game.fx.sparks(at, mini(14, 3 + int(closing * 0.4)), 4.0 + closing * 0.15, null, 0xffb060)
		if a == _driver or b == _driver:
			_cam_shake = maxf(_cam_shake, clampf(closing / 30.0, 0.15, 1.0))
			flash = maxf(flash, clampf(closing / 40.0, 0.0, 0.8))
			Game.sfx.play_at("vehCrash", at.x, at.y, at.z, {"k": clampf(closing / 30.0, 0.15, 1.0), "range": 70.0})
	# a wreck is a weapon: whatever it hits hard goes down too (aftertouch)
	if a.car.wrecked != b.car.wrecked:
		var wreck := a if a.car.wrecked else b
		var live := b if a.car.wrecked else a
		if closing > (10.0 if wreck == _driver else (20.0 * PLAYER_TOUGH * 1.5 if live == _driver else 20.0)):
			_wreck(live, "AFTERTOUCH" if wreck == _driver else "WRECKAGE", wreck)
		return
	if a.car.wrecked or b.car.wrecked:
		return
	# a ram shell: whatever it touches is thrown aside, and anything it meets hard goes down
	var shelled: Racer = null
	if a.shell > 0.0 and b.shell <= 0.0:
		shelled = a
	elif b.shell > 0.0 and a.shell <= 0.0:
		shelled = b
	if shelled != null and closing > 2.5:
		var other := b if shelled == a else a
		var push := other.car.pos - shelled.car.pos
		var up := other.car.road.basis.y
		push -= up * push.dot(up)
		other.car.vel += push.normalized() * (8.0 + closing * 0.4) + up * 2.0
		other.car.stagger = maxf(other.car.stagger, 1.0)
		other.hit_by = shelled
		other.hit_t = _race_time
		other.hit_how = "RAM"
		if closing > 11.0:
			_wreck(other, "RAM", shelled)
		return
	if closing < 7.0:
		return
	# who drove into whom, in the road's own terms: whoever is moving sideways into the other, or running into the back of it
	var road := a.car.road.basis
	var across := (b.car.pos - a.car.pos).dot(road.x)
	var ahead := (b.car.pos - a.car.pos).dot(road.z)
	var side_a := a.car.vel.dot(road.x) * signf(across)
	var side_b := -b.car.vel.dot(road.x) * signf(across)
	var closing_long := (a.car.vel.dot(road.z) - b.car.vel.dot(road.z)) * signf(ahead)
	var lat_share := absf(nrm.dot(road.x))
	var score_a := side_a * lat_share + maxf(0.0, closing_long) * (1.0 - lat_share)
	var score_b := side_b * lat_share + maxf(0.0, -closing_long) * (1.0 - lat_share)
	var push_a := a.car.vel.dot(nrm)
	var push_b := -b.car.vel.dot(nrm)
	var hunter := a if score_a >= score_b else b
	var prey := b if hunter == a else a
	var into := nrm if hunter == a else -nrm      # from the hunter to the prey
	prey.hit_by = hunter
	prey.hit_t = _race_time
	prey.hit_how = "SLAM"
	prey.car.stagger = maxf(prey.car.stagger, clampf(closing / 28.0, 0.3, 0.9))
	# head on: both go
	if push_a > 12.0 and push_b > 12.0 and closing > HEAD_ON:
		_wreck(a, "HEAD-ON", b)
		_wreck(b, "HEAD-ON", a)
		return
	# a shunt: rammed from behind hard enough
	var rear := into.dot(prey.car.basis.z) > 0.55
	if rear and closing > (SHUNT * 1.5 * PLAYER_TOUGH if prey == _driver else SHUNT):
		_wreck(prey, "SHUNT", hunter)
		return
	# a sideswipe kicks the prey's tail round
	var side := absf(into.dot(prey.car.basis.x))
	if side > 0.5:
		var up := prey.car.basis.y
		var yaw := signf(prey.car.basis.z.cross(into).dot(up))
		prey.car.spin += up * (yaw * clampf(closing * 0.05, 0.3, 1.8))


func _consume_hits(r: Racer) -> void:
	for h: RaceCar.Hit in r.car.hits:
		if h.kind == RaceCar.WALL:
			var limit := WALL_WRECK_SHAKEN if r.car.stagger > 0.0 else WALL_WRECK
			if r == _driver:
				limit = PLAYER_WALL_SHAKEN if r.car.stagger > 0.0 else PLAYER_WALL_WRECK
			if r.car.mag:
				limit = 999.0 if r == _driver else maxf(limit, 45.0)      # (glued to a loop or the roll: the player only scrapes there)
			if r == _driver:
				_cam_shake = maxf(_cam_shake, clampf(h.speed / 30.0, 0.1, 1.0))
				flash = maxf(flash, clampf(h.speed / 40.0, 0.0, 0.7))
			if h.speed > limit and not r.car.wrecked and r.shell <= 0.0:
				_wreck(r, "WALL")
			elif h.speed > 7.0:
				Game.fx.sparks(h.at, 6, 6.0, h.normal, 0xffc070)
				if r == _driver or h.speed > 15.0:
					Game.sfx.play_at("vehCrash", h.at.x, h.at.y, h.at.z, {"k": clampf(h.speed / 35.0, 0.1, 0.8), "range": 60.0})
		elif h.kind == RaceCar.FLOOR:
			Game.fx.sparks(h.at, 8, 7.0, h.normal, 0xffb060)
			if h.speed > 10.0:
				Game.sfx.play_at("vehCrash", h.at.x, h.at.y, h.at.z, {"k": clampf(h.speed / 25.0, 0.1, 0.9), "range": 70.0})


func _after_frame(r: Racer, dt: float) -> void:
	var car := r.car
	r.ghost = maxf(0.0, r.ghost - dt)
	if r.trick > 0.0:
		r.trick = maxf(0.0, r.trick - dt)
	# lap progress (the shortcut counts as the stretch of main road it cuts)
	var s := course.paths[car.path].main_s[car.index]
	var d := s - r.last_s
	r.progress += d
	r.last_s = s
	if car.held and _count > 0.0:
		return
	if car.wrecked:
		r.wreck_t += dt
		r.fx_t -= dt
		if r.fx_t <= 0.0:
			r.fx_t = 0.07
			Game.fx.dust(car.pos, 1, 1.2)
		if r.wreck_t > 2.3:
			_respawn(r)
		return
	# wrecks that are not a hit: over the edge, on its roof, pinned against a wall
	if car.local.y < -7.0 or car.pos.y < course.lowest - 60.0:
		_wreck(r, "OFF THE EDGE")
		return
	if car.basis.y.dot(car.road.basis.y) < 0.05 and absf(car.local.y) < 3.0 and car.on_road:
		r.flip_t += dt
		if r.flip_t > (0.9 if r == _driver else 0.45):
			_wreck(r, "FLIPPED")
			return
	else:
		r.flip_t = 0.0
	if r.touching != null and r.scrape > 1.0 and not r.touching.car.wrecked:
		r.pinned += dt
		r.pinned_by = r.touching
		if r.pinned > (1.8 if r == _driver else 0.5):
			_wreck(r, "PINNED", r.pinned_by)
			return
	else:
		r.pinned = maxf(0.0, r.pinned - dt * 2.0)
	if r.brain != null and r.brain.stuck_for() > 3.0:
		_respawn(r)
		return
	# a safe place to come back to
	if car.on_road and car.grounded and car.local.y < 2.0 and car.stagger <= 0.0:
		r.safe_path = car.path
		r.safe_i = car.index
		r.safe_u = car.local.x
	# boost pads
	for pad: SkyCourse.Pad in course.pads:
		if pad.path != car.path:
			continue
		var k := course.paths[pad.path].wrap(car.index - pad.i)
		if k < pad.span and absf(car.local.x - pad.u) < pad.hw + 0.4 and car.local.y < 2.5:
			if car.turbo < 0.6 and r == _driver:
				_audio.cue(SkyDriveFx.Cue.BOOST)
			car.turbo = maxf(car.turbo, 1.1)
	# smashed stacks
	var smashed := _props.hit_by(car)
	if smashed > 0:
		_gain(r, 0.025 * smashed)
		if r == _driver:
			_audio.cue(SkyDriveFx.Cue.SMASH)
			_cam_shake = maxf(_cam_shake, 0.25)
	# the meter fills from driving on the edge
	if car.drifting and absf(car.slip) > 0.18:
		_gain(r, 0.11 * dt)
	if car.air > 0.35:
		_gain(r, 0.14 * dt)
	if r != _driver:
		_gain(r, 0.035 * dt)
	# landings: a trick pays a boost, big air pays the meter
	if car.air == 0.0 and car.last_air > 0.0:
		var flight := car.last_air
		car.last_air = 0.0
		if r.tricked and not car.wrecked:
			car.turbo = maxf(car.turbo, 0.9)
			if r == _driver:
				pop("TRICK", "", true)
				_audio.cue(SkyDriveFx.Cue.BOOST)
		if flight > 1.0 and r == _driver:
			pop("BIG AIR", "%.1f s" % flight)
		r.tricked = false
	if car.air == 0.0:
		r.tricked = false
	if car.landed > 6.0 and r == _driver:
		_cam_shake = maxf(_cam_shake, clampf(car.landed / 20.0, 0.1, 0.8))
		Game.fx.sparks(car.pos - car.basis.y * 0.5, 10, 5.0, car.road.basis.y, 0x9fdcff)
	car.landed = 0.0
	if car.mini > 0:
		if r == _driver:
			pop(["", "MINI-TURBO", "SUPER MINI-TURBO", "ULTRA MINI-TURBO"][car.mini], "", car.mini >= 2)
			_audio.cue(SkyDriveFx.Cue.BOOST)
		car.mini = 0
	# sparks off the back of a drift, in the colour of the turbo it has earned
	if car.drifting and absf(car.slip) > 0.15:
		r.fx_t -= dt
		if r.fx_t <= 0.0:
			r.fx_t = 0.03
			var tier := 0 if car.drift_charge < 0.8 else (1 if car.drift_charge < 1.8 else (2 if car.drift_charge < 3.0 else 3))
			var col: int = [0xfff0c0, 0x55c8ff, 0xffa040, 0xc070ff][tier]
			for side: float in [-1.0, 1.0]:
				Game.fx.sparks(car.pos + car.basis * Vector3(side * car.half.x * 0.8, -0.45, -car.half.z * 0.75), 1, 3.0, car.road.basis.y, col)
	if r == _driver:
		_player_extras(r, dt)
	elif r.brain != null:
		var pl := _driver
		r.brain.rubber = clampf(1.0 + (pl.progress - r.progress) * 0.00025, 0.94, 1.0)      # (a leader eases off in the bends; nobody is pushed past the grip)
		r.car.top = TOP[r.index] * clampf(1.0 + (pl.progress - r.progress) * 0.0005, 0.93, 1.08)
		if r.progress >= course.finish_s - START_LINE and not r.finished:
			r.finished = true
			_finished_n += 1


## The player's own bookkeeping: near misses, the draft, the shortcut, wrong way, laps and the finish.
func _player_extras(r: Racer, dt: float) -> void:
	var car := r.car
	var fwd := car.basis.z
	draft = 0.0
	for o: Racer in everyone:
		if o == r or o.car.wrecked or o.ghost > 0.0:
			continue
		var rel := o.car.pos - car.pos
		var ahead := rel.dot(fwd)
		var side := rel.dot(car.basis.x)
		if absf(side) < 5.0 and absf(ahead) < 40.0:
			var was_ahead: bool = r.ahead_of.get(o, ahead > 0.0)
			if was_ahead and ahead <= 0.0:
				var gap := absf(side) - car.half.x - o.car.half.x
				var closing := car.vel.length() - o.car.vel.length()
				if gap > -0.2 and gap < 1.6 and closing > 6.0 and _race_time - r.touch_t > 0.6:
					_gain(r, 0.08)
					pop("NEAR MISS")
			r.ahead_of[o] = ahead > 0.0
		else:
			r.ahead_of.erase(o)
		if ahead > 4.0 and ahead < 34.0 and absf(side) < 2.4 and car.speed > 30.0:
			draft = maxf(draft, 1.0 - ahead / 34.0)
	if draft > 0.0:
		car.vel += fwd * (6.0 * draft * dt)
		_gain(r, 0.04 * draft * dt)
	if car.path != SkyCourse.MAIN and _last_path == SkyCourse.MAIN:
		var br := course.branch_of(car.path)
		pop(br.title.replace("  ", " ") if br != null else "SHORTCUT", "", true)
	_last_path = car.path
	# wrong way
	if car.vel.dot(car.road.basis.z) < -6.0:
		_wrong_t += dt
	else:
		_wrong_t = 0.0
	wrong_way = _wrong_t > 1.2
	var passed := 0
	for c: float in course.checkpoints:
		if r.progress + START_LINE >= c:
			passed += 1
	if passed > checkpoint:
		checkpoint = passed
		pop("CHECKPOINT", "%d / %d" % [checkpoint, course.checkpoints.size()], false, true)
		_audio.cue(SkyDriveFx.Cue.GO)
	if _finish > 0.0:
		_finish += dt
		results = _finish >= 1.45
		if results:
			_slow(1.0, 0.0)
	elif r.progress >= course.finish_s - START_LINE:
		_finish = dt
		r.finished = true
		_finished_n += 1
		_audio.cue(SkyDriveFx.Cue.GO)
		pop(SkyRaceUi._placing(place), "", place == 1, true)

var _last_path := SkyCourse.MAIN


## Boost earned by driving: none while it is being burned (driving on the edge at boost speed refilled it as fast as it went).
func _gain(r: Racer, amount: float) -> void:
	if r.over > 0.0 or r.car.boosting:
		return
	r.meter = minf(r.meter_max, r.meter + amount)


func _rank() -> void:
	for r: Racer in racers:
		r.rank = 1
		for o: Racer in racers:
			if o != r and o.progress > r.progress:
				r.rank += 1
	if not (_driver.finished and _finish > 0.02):
		place = _driver.rank


# ----------------------------------------------------------------- wrecks ----

## A boost icon taken (sky_items.gd): boost meter segments, up to the craft's full meter.
func boost_icon(r: Racer, amount: float, red: bool) -> void:
	r.meter = minf(r.meter_max + (1.0 if r.over > 0.0 else 0.0), r.meter + amount)
	if r == _driver:
		_audio.cue(SkyDriveFx.Cue.ITEM if red else SkyDriveFx.Cue.TICK)
		if red:
			pop("RED BOOST", "", true)


## A craft wrecked by something of the course (a crusher, the gantry, the column): whoever knocked it there last gets the takedown.
func crash(r: Racer, how: String) -> void:
	_wreck(r, how)


## The player never wrecks (user, 2026-11-19: "the player just gets knocked around"): what would wreck a rival knocks him about instead,
## and a fall over an edge puts him straight back on the road.
func _knock(r: Racer, how: String) -> void:
	if how == "OFF THE EDGE":
		_respawn(r)
		return
	if _race_time - r.knock_t < 0.6:
		return
	r.knock_t = _race_time
	var car := r.car
	var up := car.road.basis.y
	car.vel *= 0.74
	car.vel += up * 3.0
	car.spin += up * randf_range(-2.4, 2.4)
	car.stagger = maxf(car.stagger, 0.7)
	car.drifting = false
	if how == "CRUSHED":
		car.vel += car.road.basis.z * 9.0      # shoved on out from under the press
	elif how == "FLIPPED":
		var f := car.basis.z - up * car.basis.z.dot(up)
		if f.length_squared() < 0.01:
			f = car.road.basis.z
		f = f.normalized()
		car.basis = Basis(up.cross(f), up, f).orthonormalized()
		car.spin = Vector3.ZERO
		r.flip_t = 0.0
	elif how == "PINNED":
		r.pinned = 0.0
		car.vel += car.road.basis.x * (-signf(car.local.x) * 6.0)
	_cam_shake = 1.0
	flash = maxf(flash, 0.9)
	Game.fx.sparks(car.pos, 18, 9.0, up, 0xffb060)
	Game.sfx.play_at("vehCrash", car.pos.x, car.pos.y, car.pos.z, {"k": 1.0, "range": 80.0})


func _wreck(r: Racer, how: String, by: Racer = null) -> void:
	if r.car.wrecked or r.ghost > 0.0:
		return
	if r == _driver:
		wreck_log.append("%.1fs %s KNOCKED (%s) at MAIN#%d" % [_race_time, r.title, how, r.car.index])
		_knock(r, how)
		return
	var car := r.car
	wreck_log.append("%.1fs %s %s at %s#%d (%.1f across, %.1f up) %.0f m/s%s" % [_race_time, r.title, how, "MAIN" if car.path == SkyCourse.MAIN else "BRANCH%d" % car.path, car.index, car.local.x, car.local.y, car.vel.length(), " by " + by.title if by != null else ""])
	car.wrecked = true
	car.boosting = false
	car.turbo = 0.0
	car.drifting = false
	r.wreck_t = 0.0
	r.fx_t = 0.0
	car.spin += Vector3(randf_range(-3.0, 3.0), randf_range(-4.0, 4.0), randf_range(-6.0, 6.0))
	car.vel += car.road.basis.y * randf_range(3.0, 7.0)
	var credit := by
	if credit == null and r.hit_by != null and _race_time - r.hit_t < 3.0:
		credit = r.hit_by
		if r.hit_how != "" and r.hit_how != "SLAM":
			how = r.hit_how
	_items.drop(r)
	if credit == r:
		credit = null
	var near := car.pos.distance_to(_driver.car.pos) < 120.0
	if near:
		Game.fx.explosion(car.pos, 2.4)
		Game.sfx.play_at("vehCrash", car.pos.x, car.pos.y, car.pos.z, {"k": 1.0, "range": 120.0})
	if credit == null:
		return
	credit.takedowns += 1
	credit.meter_max = minf(4.0, credit.meter_max + 1.0)
	credit.meter = minf(credit.meter_max, credit.meter + 1.0)      # (a segment, not a full refill)
	if credit == _driver:
		takedowns = credit.takedowns
		var kind := "TAKEDOWN"
		if how == "SHUNT":
			kind = "SHUNT TAKEDOWN"
		elif how == "AFTERTOUCH":
			kind = "AFTERTOUCH TAKEDOWN"
		elif how == "PINNED":
			kind = "GRIND TAKEDOWN"
		elif how == "OFF THE EDGE":
			kind = "DROP TAKEDOWN"
		elif how in ["MINE", "PULSE", "RAM", "HARPOON", "CRUSHED", "DEBRIS", "COLUMN", "COLLAPSE", "WRECKING BALL"]:
			kind = how + " TAKEDOWN"
		pop(kind, r.title + "   x%d" % takedowns, true, true)
		_audio.cue(SkyDriveFx.Cue.TAKEDOWN)      # (no slow-motion cut to the wreck since 2026-11-19: the user wanted none shown)


func _respawn(r: Racer) -> void:
	var path := r.safe_path
	var i := r.safe_i
	if path != SkyCourse.MAIN:
		# a fall off a branch puts you back before it, not after
		var br := course.branch_of(path)
		path = SkyCourse.MAIN
		i = br.split_i - 8 if br != null else r.car.index
	var p := course.paths[path]
	var guard := 0
	while guard < 400 and (p.mag[i] == 1 or p.deck[i] == 0 or p.deck[p.wrap(i + 30)] == 0 or p.mag[p.wrap(i + 4)] == 1):
		i = p.wrap(i - 1)
		guard += 1
	if path == SkyCourse.MAIN:
		# a little further back, and in a lane the course has not blocked (a column, fallen girders, a crusher)
		i = maxi(2, i - 12)
	var u := clampf(r.safe_u, -(p.wr[i] - 2.6), p.wl[i] - 2.6)
	if path == SkyCourse.MAIN:
		u = _set.free_lat(i, i + 40, u, p.metres[i], 40.0, p.wl[i] - 2.6, p.wr[i] - 2.6, u)
	r.car.place(course, path, i, u, 40.0)
	r.car.held = false
	r.ghost = GHOST_PLAYER if r == _driver else GHOST_RIVAL
	r.wreck_t = 0.0
	r.flip_t = 0.0
	r.pinned = 0.0
	r.hit_by = null
	r.tricked = false
	r.last_s = p.main_s[i]
	if r == _driver:
		_cam_snap = true
		_slow(1.0, 0.0)


func _slow(scale: float, seconds: float) -> void:
	Game.time_scale = scale
	_slow_t = seconds


# ------------------------------------------------------------------ views ----

func _show(r: Racer, dt: float) -> void:
	var root := r.model.root
	root.global_transform = r.car.model_transform()
	var roll := 0.0
	if r.trick > 0.0:
		roll = TAU * (1.0 - r.trick / 0.55)
	r.model.chassis.basis = Basis(Vector3.BACK, roll) * Basis.from_scale(r.size)
	root.visible = r.ghost <= 0.0 or fmod(Game.time * 14.0, 1.0) > 0.35
	if r.jets != null:
		var load := clampf(r.controls.throttle * 0.6 + maxf(0.0, r.car.speed) / RaceCar.V_TOP * 0.4, 0.0, 1.0)
		r.jets.drive(0.0 if r.car.wrecked else load * 0.8 + (0.06 if on else 0.0), r.car.boost_amt * (1.5 if r.over > 0.0 else 1.0), Game.time)


func _update_riders(dt: float) -> void:
	_crew.brace = boost
	_steer_seen = U.damp(_steer_seen, _driver.controls.steer, 8.0, dt)
	_crew.update(Game.time, dt, _steer_seen)


func _update_camera(dt: float, real: float) -> void:
	var me := _driver.car
	_cam_shake = move_toward(_cam_shake, 0.0, real * 2.2)
	var road_up := me.road.basis.y if me.on_road or me.pads_down > 0 else Vector3.UP
	var vdir := me.vel.normalized() if me.vel.length() > 8.0 else me.basis.z
	var heading := me.basis.z * 0.45 + vdir * 0.55
	if _cam_snap:
		_cam_up = road_up
		_cam_fwd = me.basis.z
	_cam_up = _cam_up.lerp(road_up, 1.0 - exp(-5.0 * real)).normalized()
	heading = (heading - _cam_up * heading.dot(_cam_up)).normalized()
	if heading.length_squared() < 0.5:
		heading = _cam_fwd
	_cam_fwd = _cam_fwd.lerp(heading, 1.0 - exp(-7.0 * real)).normalized()
	var pace := clampf(me.vel.length() / RaceCar.V_BOOST, 0.0, 1.15)
	var dist := 6.4 + pace * 1.8 + boost * 1.4
	var height := 2.0 + pace * 0.3
	var want := -_cam_fwd * dist + _cam_up * height
	if _cam_snap:
		_cam_off = want
		_cam_snap = false
	_cam_off = _cam_off.lerp(want, 1.0 - exp(-10.0 * real))
	var hum := (pace * pace * 0.05 + boost * 0.05 + _cam_shake * 0.3) * Config.cam_shake
	var t := Game.time
	var shake := (me.basis.x * sin(t * 61.0) + _cam_up * sin(t * 47.0 + 1.3)) * hum
	camera.pos = me.pos + _cam_off + shake
	camera.look = me.pos + _cam_fwd * 7.5 + _cam_up * 1.1
	camera.up = _cam_up
	var fov_want := 64.0 + pace * 22.0 + boost * 9.0
	camera.fov = fov_want if camera.fov < 1.0 else U.damp(camera.fov, fov_want, 6.0, real)
