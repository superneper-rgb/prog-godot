class_name MaktarLevel
extends ExportedLevel
## FOINT ARENA (JS levels/maktar/level.js, level id `maktar`): the world is exported, this adds what the game needs on top of it: a World of simplified colliders that follow the animation (flip drums and exposed fans switch on and off with the flip, bullpen carriages and shutters move with the gates), hazards (exposed fans hurt and fling whoever stands on them, the electrified moat shocks and launches you back to the centre), enemy spawn points inside the six bullpens (they ride with the carriage; `ready` says when the door is open for a wave), and the tournament: director, TV, commentary, crowd, machinery, music.
## Units are metres, Y up. The arena models its floor surface at y = 0.065, so the whole arena is lowered by that much and the floor is y = 0 like in every other level.

const OFF := 0.065
const FLOOR_R := 24.4                  # radius of the floor disc
const MOAT_IN := 24.5                  # radii of the electrified moat: stepping past the floor edge shocks you
const MOAT_OUT := 31.0
const SHOCK_DAMAGE := 15.0
const SHOCK_COOLDOWN := 0.7
const SHOCK_LAUNCH_SPEED := 34.0
const SHOCK_LAUNCH_UP := 15.0
const SHOCK_LAUNCH_TIME := 1.0
const FAN_DAMAGE := 12.0
const FAN_INTERVAL := 0.4
const FAN_FLING := 9.0
const FAN_UP := 6.0


class Fan:
	var drum: World.Solid
	var fan: World.Solid
	var x := 0.0
	var z := 0.0
	var r := 0.0
	var top := 0.0
	var fan_top := 0.0
	var th := 0.0
	var cool := 0.0


class GatePart:
	var s: World.Solid
	var lx := 0.0
	var zc := 0.0
	var bottom := 0.0
	var top := 0.0
	var push := false


class SpawnPoint:
	var id := ""
	var gate := 0
	var lx := 0.0
	var zc := 24.7
	var x := 0.0
	var y := 0.0
	var z := 0.0
	var yaw := 0.0
	var ready := false


class Gate:
	var index := 0
	var a := 0.0
	var sin_ := 0.0
	var cos_ := 0.0
	var ox := 0.0
	var oz := 0.0
	var o := 0.0
	var dy := 0.0
	var parts: Array[GatePart] = []
	var door: World.Solid
	var spawns: Array[SpawnPoint] = []
	var state := ""


var fans: Array[Fan] = []
var gates: Array[Gate] = []
var spawns: Array[SpawnPoint] = []
var motion: ArenaMotion
var director: ArenaChallenges
var tv: TournamentTV
var commentary: ArenaAudio.Commentary
var ambience: ArenaAudio.Ambience
var machinery: ArenaAudio.Machinery
var music: MusicTrack
var actors: Array = []                 # everybody who can ride a bridge / be shoved by a closing door: the player and the robots
var launch_t := 0.0
var launch_ux := 0.0
var launch_uz := 0.0
var shock_cool := 0.0
var _began := false


static func _y(v: float) -> float:
	return v - OFF


## The JS level makes its own simplified World (colliders.json would hold the same thing, without the handles the animation needs).
func _build_colliders(_dir: String) -> void:
	var W := world
	# ---- floor: one disc with the twelve fan openings left hollow ----
	var holes: Array = []
	for i in 6:
		for lower: bool in [false, true]:
			var a := i * PI / 3.0
			var r := 20.4 if lower else 13.2
			var s := 0.82 if lower else 0.87
			var x := sin(a) * r
			var z := cos(a) * r
			holes.append([x, z, 2.56 * s])
			# the platform face: solid only while the drum lies flat (see sync)
			var top := _y(0.16 + 0.215 * s)
			var drum := W.add({"kind": "disc", "cx": x, "cz": z, "r": 2.44 * s, "top": top, "bottom": top - 0.3, "tag": "platform"})
			# the bottom of the opening; its walls are the edge of the floor disc around the hole
			var pit := _y(0.16 - 3.18 * s)
			W.add({"kind": "disc", "cx": x, "cz": z, "r": 2.56 * s, "top": pit, "bottom": pit - 1.0, "tag": "pit"})
			# the exposed fan (face up): solid and dangerous, it takes the drum's place at the end of the flip
			var fan_top := _y(0.16 + 0.3 * s)
			var fan := W.add({"kind": "disc", "cx": x, "cz": z, "r": 2.44 * s, "top": fan_top, "bottom": fan_top - 0.3, "tag": "fan", "off": true})
			var f := Fan.new()
			f.drum = drum
			f.fan = fan
			f.x = x
			f.z = z
			f.r = 2.56 * s
			f.top = top
			f.fan_top = fan_top
			fans.append(f)
	W.add({"kind": "disc", "cx": 0.0, "cz": 0.0, "r": FLOOR_R, "top": 0.0, "bottom": -4.5, "holes": holes, "tag": "floor"})
	# ---- central dais: three stacked discs (rim, platform, plate) ----
	W.add({"kind": "disc", "cx": 0.0, "cz": 0.0, "r": 8.45, "top": _y(0.41), "bottom": -0.2, "tag": "dais"})
	W.add({"kind": "disc", "cx": 0.0, "cz": 0.0, "r": 7.0, "top": _y(0.68), "bottom": -0.2, "tag": "dais"})
	W.add({"kind": "disc", "cx": 0.0, "cz": 0.0, "r": 6.1, "top": _y(0.73), "bottom": -0.2, "tag": "dais"})
	# no boundary wall: the moat is electrified, not blocked (see hazards)
	# ---- bullpen gates: floor/bridge, threshold, side walls, roof, back wall, sliding door (all in carriage space) ----
	for n in 6:
		var i := 2 + n * 4
		var a := i * PI / 12.0
		var g := Gate.new()
		g.index = n
		g.a = a
		g.sin_ = sin(a)
		g.cos_ = cos(a)
		g.ox = sin(a) * 5.4
		g.oz = cos(a) * 5.4
		_part(g, 0.0, 24.5, 3.05, 2.0, 0.0, 0.2)                     # bullpen floor (the bridge across the moat)
		_part(g, 0.0, 22.4, 3.45, 0.725, 0.08, 0.24)                 # threshold
		_part(g, -3.35, 24.5, 0.4, 1.9, 0.15, 4.65, true)            # side walls
		_part(g, 3.35, 24.5, 0.4, 1.9, 0.15, 4.65, true)
		_part(g, 0.0, 24.5, 3.1, 1.9, 4.0, 4.8)                      # roof
		_part(g, 0.0, 26.4, 3.0, 0.125, 0.1, 3.9, true)              # back wall
		g.door = _part(g, 0.0, 22.9, 3.07, 0.2, 0.03, 3.77, true)    # armoured door, rides up with the shutter
		# enemy spawn points: three spots inside the bullpen, facing the arena centre. x / z / y / yaw are live (the bullpen moves); `ready` is true while the gate is fully out and the door is up, i.e. the wave can walk out.
		for k in 3:
			var sp := SpawnPoint.new()
			sp.id = "G%d-%d" % [n + 1, k + 1]
			sp.gate = n
			sp.lx = (k - 1) * 1.6
			sp.y = _y(0.2)
			sp.yaw = a + PI
			g.spawns.append(sp)
			spawns.append(sp)
		gates.append(g)
	# ---- main screen deck: its four slanted legs reach the floor near the rim (two boxes each) ----
	for x: float in [-7.4, -5.8, 5.8, 7.4]:
		var lx := x * 0.62
		W.add({"kind": "box", "cx": lx, "cz": 22.7, "hx": 0.27, "hz": 0.45, "bottom": -0.2, "top": _y(1.1), "tag": "prop"})
		W.add({"kind": "box", "cx": lx, "cz": 23.3, "hx": 0.27, "hz": 0.45, "bottom": _y(1.1), "top": _y(2.2), "tag": "prop"})
	# ---- hovering monitors: one simplified box each, from the emitter up past the casing and the bob ----
	for i in range(3, 18):
		var a := deg_to_rad(int(i / 3) * 60.0 + (i % 3 - 1) * 12.0)
		W.add({"kind": "box", "cx": sin(a) * 23.1, "cz": cos(a) * 23.1, "hx": 1.05, "hz": 0.3, "yaw": a, "bottom": _y(0.45), "top": _y(2.55), "tag": "prop"})


func _part(g: Gate, lx: float, zc: float, hx: float, hz: float, bottom: float, top: float, push: bool = false) -> World.Solid:
	var s := world.add({"kind": "box", "cx": 0.0, "cz": 0.0, "hx": hx, "hz": hz, "yaw": g.a, "bottom": _y(bottom), "top": _y(top), "tag": "gate"})
	var p := GatePart.new()
	p.s = s
	p.lx = lx
	p.zc = zc
	p.bottom = bottom
	p.top = top
	p.push = push
	g.parts.append(p)
	return s


func build() -> void:
	super.build()
	motion = ArenaMotion.new(self)
	for g: Gate in gates:
		g.o = motion.carriage_z
		g.dy = motion.shutter_y
	sync_(null)
	music = MusicTrack.new(load("res://assets/music/death-lessons.ogg"), 0.55)      # FILMMAKER - DEATH LESSONS (EP 1)
	add_child(music)
	director = ArenaChallenges.new(self)
	tv = TournamentTV.new(self)
	add_child(tv)
	commentary = ArenaAudio.Commentary.new(self)
	add_child(commentary)
	machinery = ArenaAudio.Machinery.new(self)
	add_child(machinery)
	ambience = ArenaAudio.Ambience.new(self)
	add_child(ambience)
	Game.arena_tv = tv


## Play has begun, or the player has come through the door (JS: music.play, arenaChallenges.menu)
func start_music() -> void:
	if music != null and not music.playing:
		music.play()
	if not _began:
		_began = true
		director.menu()


func on_enter() -> void:
	Game.music = music


func on_exit() -> void:
	Game.arena_blocked = false
	Game.arena_tv = null
	if Game.music == music:
		Game.music = null
	tv.leave()
	if music != null:
		music.stop()


## JS frame: arenaChallenges.update, arenaTV.update, the arena's audio, LV.update, arenaMachinery.update (the game calls tick where the JS calls LV.update, so they all live here)
func tick(_dt: float) -> void:
	var dt: float = Game.frame_dt
	var real: float = Game.frame_real_dt
	var running: bool = Game.started and not Game.paused
	var open: bool = Game.wheel.is_open or Game.menu_open()
	if running and not open:
		director.update(dt)
	if running:
		tv.update(dt)
	commentary.update(real)
	ambience.update(real)
	var blocked: bool = Game.started and director.blocked
	Game.arena_blocked = blocked
	update_arena(0.0 if Game.started and (Game.paused or open or blocked) else dt, Game.player if Game.started and not blocked else null, dt if running and not open else 0.0)      # gate travel continues during the tournament camera/countdown
	machinery.update()


## JS arenaChallenges.constrain: after combat, every frame the game runs
func combat_events(_events: Array) -> void:
	director.constrain()


func update_arena(dt: float, P: Variant, gate_dt: float) -> void:
	actors.clear()
	if P != null:
		actors.append(P)
	for r: Robot in Game.combat.enemies.robots:
		actors.append(r)
	motion.update(dt, gate_dt)
	sync_(P)
	_hazards(dt, P)


# ---- keep the colliders in step with the animation ----
func _place(g: Gate, p: GatePart) -> void:
	p.s.place(g.ox + p.lx * g.cos_ + (p.zc + g.o) * g.sin_, g.oz - p.lx * g.sin_ + (p.zc + g.o) * g.cos_)


## a moving wall must not close on somebody: shove him out along the shallower axis
func _push_out(P: Variant, s: World.Solid) -> void:
	var feet: float = P.y
	var head: float = P.y + 1.8
	if feet >= s.top - 0.05 or head <= s.bottom + 0.05:
		return
	var sn := sin(s.yaw)
	var cs := cos(s.yaw)
	var dx: float = P.x - s.cx
	var dz: float = P.z - s.cz
	var lx := dx * cs - dz * sn
	var lz := dx * sn + dz * cs
	var r := 0.25
	var ox := s.hx + r - absf(lx)
	var oz := s.hz + r - absf(lz)
	if ox <= 0.0 or oz <= 0.0:
		return
	var mx := 0.0
	var mz := 0.0
	if oz <= ox:
		mz = (1.0 if lz >= 0.0 else -1.0) * oz
	else:
		mx = (1.0 if lx >= 0.0 else -1.0) * ox
	P.x += mx * cs + mz * sn
	P.z += -mx * sn + mz * cs


## a surface comes back up under somebody in the opening: it lifts him
func _lift_if_below(P: Player, f: Fan, top: float) -> void:
	if U.hyp(P.x - f.x, P.z - f.z) < f.r and P.y < top - 0.25:
		P.y = top
		P.vy = 0.0
		P.grounded = true


func sync_(P: Variant) -> void:
	var th := motion.th      # 0 = platform face up, PI = fan face up
	for f: Fan in fans:
		f.th = th
		var drum_was := f.drum.off
		var fan_was := f.fan.off
		f.drum.set_off(th > 0.1)               # flat platform: walkable
		f.fan.set_off(th < PI - 0.1)           # exposed fan: solid (and dangerous, see hazards); between the two the opening is hollow
		if P != null:
			if drum_was and not f.drum.off:
				_lift_if_below(P, f, f.top)
			if fan_was and not f.fan.off:
				_lift_if_below(P, f, f.fan_top)
	var o := motion.carriage_z
	var dy := motion.shutter_y
	for g: Gate in gates:
		var d_o := o - g.o
		var moved := absf(d_o) > 1e-6 or absf(dy - g.dy) > 1e-6
		if moved or g.state == "":
			if absf(d_o) > 1e-6:
				for A: Variant in actors:      # standing on the bridge: ride with it (the player and every robot)
					var gr: Variant = A.get(&"grounded")
					if gr != false and not A.dead and A.y > 0.08 and A.y < 0.35:
						var rx: float = A.x - g.ox
						var rz: float = A.z - g.oz
						var lat := rx * g.cos_ - rz * g.sin_
						var zl := rx * g.sin_ + rz * g.cos_ - g.o
						if absf(lat) < 3.0 and zl > 21.7 and zl < 26.3:
							A.x += d_o * g.sin_
							A.z += d_o * g.cos_
			g.o = o
			g.dy = dy
			for p: GatePart in g.parts:
				_place(g, p)
				if p.s == g.door:
					p.s.set_span(_y(p.bottom + dy), _y(p.top + dy))
			g.state = "retracted" if o > 1.9 and dy < 0.05 else ("open" if o < -5.5 and dy >= 2.4 else "moving")
			for sp: SpawnPoint in g.spawns:
				var zc := sp.zc + o
				sp.x = g.ox + sp.lx * g.cos_ + zc * g.sin_
				sp.z = g.oz - sp.lx * g.sin_ + zc * g.cos_
				sp.ready = g.state == "open"
		if moved:
			for A: Variant in actors:
				if not A.dead:
					for p: GatePart in g.parts:
						if p.push:
							_push_out(A, p.s)


# ---- hazards: exposed fans and the electrified moat ----
func _hazards(dt: float, Pv: Variant) -> void:
	if Pv == null or Pv.dead:
		launch_t = 0.0
		return
	var P: Player = Pv
	var combat := Game.combat
	# exposed fans: standing in / on one hurts, every blade strike also flings you off it
	for f: Fan in fans:
		f.cool -= dt
		if f.th < 2.0 or f.cool > 0.0:
			continue
		if U.hyp(P.x - f.x, P.z - f.z) < f.r and P.y < f.fan_top + 0.8 and P.y > f.fan_top - 1.5:
			f.cool = FAN_INTERVAL
			var dx := P.x - f.x
			var dz := P.z - f.z
			var l := U.hyp(dx, dz)
			if l == 0.0:
				l = 1.0
			combat.hurt_player(P, FAN_DAMAGE, f.x, f.z, "fan")
			P.ix += dx / l * FAN_FLING
			P.iz += dz / l * FAN_FLING
			P.vy = maxf(P.vy, FAN_UP)
			P.grounded = false
			P.mode = &"normal"
	# electrified moat: past the floor edge (and not standing on a bullpen bridge) you are shocked and thrown back to the middle
	shock_cool -= dt
	var r := U.hyp(P.x, P.z)
	if shock_cool <= 0.0 and r > MOAT_IN and r < MOAT_OUT and not (P.grounded and P.y > 0.08):
		shock_cool = SHOCK_COOLDOWN
		var l := r if r != 0.0 else 1.0
		launch_ux = -P.x / l
		launch_uz = -P.z / l
		launch_t = 0.0001
		combat.hurt_player(P, SHOCK_DAMAGE, P.x / l * (r + 2.0), P.z / l * (r + 2.0), "shock")
		P.vy = SHOCK_LAUNCH_UP
		P.grounded = false
		P.mode = &"normal"
		P.jumping = false
		P.slamming = false
	if launch_t > 0.0:      # the launch: a steady push toward the centre that player input can't cancel
		launch_t += dt
		var k := 1.0 if launch_t < SHOCK_LAUNCH_TIME * 0.6 else maxf(0.0, 1.0 - (launch_t - SHOCK_LAUNCH_TIME * 0.6) / (SHOCK_LAUNCH_TIME * 0.4))
		P.ix = launch_ux * SHOCK_LAUNCH_SPEED * k
		P.iz = launch_uz * SHOCK_LAUNCH_SPEED * k
		if launch_t > SHOCK_LAUNCH_TIME or (launch_t > 0.3 and P.grounded):
			launch_t = 0.0
