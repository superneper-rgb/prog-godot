class_name GrindSession
extends CanvasLayer
## RAILJACK (JS minigames/grind/grind.js): the data-line runner hack, a full-screen overlay. You are a packet riding a data line, camera behind you, through a wireframe void. Up to three lines run side by side and they open and close as you go (like the grind rails in Ratchet & Clank): HOP left / right between them, JUMP the low FIREWALLS and the DEAD SECTORS (gaps), SHRINK under the SCAN GATES. ICE BLOCKS fill a whole line: the only way past is another line. A line that ends (EOF) drops you into the void. TRACERS run at you head-on: jump them or change lines. TRACE is the life bar: it creeps up while you are connected and jumps on every hit or fall; 100% = lockout. Reach the CORE PORT at the end of the run to upload. This file is the simulation and the session; grind_draw.gd paints the scene, grind_hud.gd the HUD, the shaders do the phosphor.

signal done(res: Dictionary)

const LANE_W := 3.0
const CUBE := 0.9
const DUCK_H := 0.36
const GRAV := 30.0
const JUMP_V := 10.0
const HOP_V := 6.2
const HOP_T := 0.24
const FAST_FALL := -17.0
const DUCK_MIN := 0.32
const JUMP_BUF := 0.12
const COYOTE := 0.09
const FAR := 175.0
const STEP := 1.0 / 120.0
const NONE := -1e9        # JS null for a z
const OB := {             # h0..h1 above the rail, w across, d along
	&"low": {"h0": 0.0, "h1": 0.75, "w": 2.0, "d": 0.5, "name": "FIREWALL", "how": "JUMP"},
	&"high": {"h0": 0.55, "h1": 2.9, "w": 2.4, "d": 0.4, "name": "SCAN GATE", "how": "SHRINK"},
	&"wall": {"h0": 0.0, "h1": 3.4, "w": 2.3, "d": 1.8, "name": "ICE BLOCK", "how": "SWITCH LINES"},
	&"runner": {"h0": 0.0, "h1": 0.9, "w": 1.1, "d": 1.0, "name": "TRACER", "how": "JUMP OR SWITCH"},
}
const RAIL_TIERS: Array[Dictionary] = [      # a touch quicker than the first cut: faster lines (v, m/s) and less breathing room between set pieces (rest)
	{"name": "CIVILIAN", "length": 1500.0, "v": [22.0, 31.0], "rest": [0.65, 1.1], "slalom": 0, "runner": false, "combo": false, "passive": 0.3, "hit": 18, "fall": 26},
	{"name": "CORPORATE", "length": 2000.0, "v": [24.0, 35.0], "rest": [0.52, 0.92], "slalom": 2, "runner": true, "combo": true, "passive": 0.35, "hit": 18, "fall": 26},
	{"name": "MILITARY", "length": 2600.0, "v": [27.0, 40.0], "rest": [0.4, 0.75], "slalom": 3, "runner": true, "combo": true, "passive": 0.4, "hit": 20, "fall": 28},
	{"name": "SCHLEEDTECH BLACK", "length": 3200.0, "v": [30.0, 47.0], "rest": [0.3, 0.62], "slalom": 4, "runner": true, "combo": true, "passive": 0.45, "hit": 22, "fall": 30},
]
# Backing tracks are split by difficulty. opts.music can force a track within the current tier's pool.
const EARLY_TRACKS: Array[Dictionary] = [
	{"id": "midnight", "name": "MAINFRAME MIDNIGHT", "file": "res://assets/sfx/grind/mainframe-midnight.mp3"},
	{"id": "intrusion", "name": "MAINFRAME INTRUSION", "file": "res://assets/sfx/grind/mainframe-intrusion.mp3"},
	{"id": "access", "name": "ACCESS GRANTED", "file": "res://assets/sfx/grind/access-granted.mp3"},
]
const HIGH_TRACKS: Array[Dictionary] = [
	{"id": "machine", "name": "MACHINE-LIKE RUSH", "file": "res://assets/sfx/grind/machine-like-rush.mp3"},
	{"id": "gallop", "name": "CHROMATIC GALLOP", "file": "res://assets/sfx/grind/chromatic-gallop.mp3"},
]
const SHIFT: Array[float] = [0.0, 0.34, 0.67, 1.0]
const KEYMAP := {
	&"left": [KEY_LEFT, KEY_A], &"right": [KEY_RIGHT, KEY_D], &"jump": [KEY_UP, KEY_W, KEY_SPACE], &"duck": [KEY_DOWN, KEY_S, KEY_SHIFT, KEY_CTRL],
	&"confirm": [KEY_ENTER, KEY_SPACE, KEY_E, KEY_X], &"abort": [KEY_ESCAPE, KEY_BACKSPACE],
}
const KEYS: Array[StringName] = [&"left", &"right", &"jump", &"duck", &"confirm", &"abort"]


class Rail:
	var z0 := 0.0
	var z1 := 0.0
	var told := false


class Obs:
	var lane := 0
	var z := 0.0
	var type: StringName = &"low"
	var hit := false
	var done_ := false
	var gap := -1.0      # JS o.gap undefined
	var order := 0


class BitQ:
	var lane := 0
	var z := 0.0
	var y := 0.0
	var got := false
	var scrub := false
	var mystery := false
	var order := 0


class Part:
	var x := 0.0
	var y := 0.0
	var z := 0.0
	var vx := 0.0
	var vy := 0.0
	var vz := 0.0
	var g := 0.0
	var t := 0.0
	var life := 0.0
	var col := Color.WHITE


class Packet:
	var z := 0.0
	var lane := 0
	var x := 0.0
	var y := 0.0
	var vy := 0.0
	var ground := true
	var duck_t := 0.0
	var coyote := 0.0
	var jump_buf := 0.0
	var inv := 0.0
	var flip := 0.0
	var flip_v := 0.0
	var lean := 0.0
	var squash := 0.0


## the palette is per run: each ICE class pushes every green toward red (CIVILIAN green -> SCHLEEDTECH BLACK pure red), the alert colours stay readable
class Pal:
	var solid := Color.WHITE
	var fire := Color.WHITE
	var lock := Color.WHITE
	var rim := Color.WHITE
	var gap := Color.WHITE
	var key := Color.WHITE
	var ice := Color.WHITE
	var probe := Color.WHITE
	var white := Color.WHITE
	var red := Color.WHITE
	var dim := Color.WHITE
	var grid := Color.WHITE


var opts := {}
var ti := 0
var tier := {}
var title := ""
var rng: CrtKit.Rng = null
var au: GrindAudio = null
var COL := Pal.new()
var tk := 0.0
# ---- input: keyboard + standard-mapping gamepad ----
var i_now := {}
var i_prev := {}
var pad := false
var _rest := {}
var _sdir := {}
var press := {}
var bot := false
var bot_press := {}
var bot_held := {}
var bot_target := 99
var test_keys := {}      # the test driver's held keys, by the KEYMAP name (a peek run answers nothing else)
# ---- the run ----
var rails: Array = [[], [], []]
var obs: Array[Obs] = []
var bits: Array[BitQ] = []
var gate_z := 0.0
var ph: Array[float] = []
var towers: Array[Dictionary] = []
var seed_n := 0
var streaks: Array[Dictionary] = []
var p := Packet.new()
var phase := "boot"
var pt := 0.0
var time := 0.0
var trace := 0.0
var contacts := 0
var falls := 0
var nbits := 0
var score := 0
var score_shown := 0.0
var streak := 0
var streak_t := 9.0
var slow := 0.0
var v := 0.0
var shake := 0.0
var glitch := 0.0
var red_flash := 0.0
var white_flash := 0.0
var alarm_t := 0.0
var banner: Dictionary = {}
var popups: Array[Dictionary] = []
var parts: Array[Part] = []
var cam := {"x": 0.0, "y": 0.0, "roll": 0.0, "intro": 1.0}
var acc := 0.0
var seen := {}
var eof_t := 0.0
var eof := NONE
var song: Dictionary = {}
var chain := 0
var best_chain := 0
var oc := 0.0
var freeze_t := 0.0
var crates := 0
var smashed := 0
var result := {}
var dead := false
var leds := {"power": 1.0, "disk": 0.0, "video": 0.0, "sync": 0.0}
var tear_t := 0.0
var _typed := 0
var _beep := -1
var _later: Array[Array] = []      # JS setTimeout: [seconds left, roll]
# (the cursors: every walk over a sorted list starts here instead of at its head, the rest of each list is behind the packet for good)
var _ob_i := 0
var _bit_i := 0
var _vis_ob := 0
var _vis_bit := 0
var _told_i: Array[int] = [0, 0, 0]
var _prev_mouse := Input.MOUSE_MODE_VISIBLE
# ---- the views ----
var view: GrindDraw = null
var hud: GrindHud = null
var fx_nodes: GrindScreen = null


## JS runGrind: await its `done` signal
static func run_grind(p_opts: Dictionary = {}) -> GrindSession:
	var s := GrindSession.new()
	s.opts = p_opts
	Game.add_child(s)
	return s


func _ready() -> void:
	layer = 200
	var tier_index := clampi(roundi(float(opts.get("difficulty", 2))) - 1, 0, RAIL_TIERS.size() - 1)
	ti = tier_index
	_palette_for(tier_index)
	tier = RAIL_TIERS[tier_index].duplicate()
	if float(opts.get("length", 0.0)) > 0.0:
		tier.length = float(opts.length)      # opts.length shortens / lengthens the route
	title = str(opts.get("title", "SECURE MAINFRAME")).to_upper()
	rng = CrtKit.Rng.new(opts.get("seed", title + "/" + String(tier.name)))
	GrindAudio.warm()
	au = GrindAudio.new(self)
	_poll()
	i_prev = i_now.duplicate()
	build()
	v = float(tier.v[0])
	bot = bool(opts.get("bot", false))
	tear_t = 2.0 + randf() * 3.0
	var tracks: Array[Dictionary] = EARLY_TRACKS if tier_index < 2 else HIGH_TRACKS
	song = tracks[randi() % tracks.size()]
	for s: Dictionary in tracks:
		if s.id == opts.get("music", ""):
			song = s
	fx_nodes = GrindScreen.new(self)
	add_child(fx_nodes)
	view = fx_nodes.draw_node
	hud = fx_nodes.hud
	au.play("boot")
	# the world holds still under the overlay and the 3D frame is not drawn at all (the JS sets the time scale to almost nothing and keeps drawing it)
	Game.overlay = self
	get_viewport().disable_3d = true
	_prev_mouse = Input.mouse_mode
	if _prev_mouse == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _shiftc(c: Array) -> Array:
	var m: int = maxi(maxi(c[0], c[1]), c[2])
	var w: float = float(mini(mini(c[0], c[1]), c[2])) / m
	var to: Array = [m, roundi(m * (0.1 + 0.5 * w * w)), roundi(m * (0.08 + 0.55 * w * w))]
	return _mixc(c, to, tk)


func _mixc(a: Array, b: Array, k: float) -> Array:
	return [roundi(a[0] + (b[0] - a[0]) * k), roundi(a[1] + (b[1] - a[1]) * k), roundi(a[2] + (b[2] - a[2]) * k)]


## a literal green from the drawing code, run through the same shift
func tcol(r: int, g: int, b: int, a: float) -> Color:
	return CrtKit.c8(_shiftc([r, g, b]), a)


func _palette_for(i: int) -> void:
	tk = SHIFT[i]
	var C: Dictionary = CrtKit.COL
	for n: String in ["solid", "rim", "gap", "dim", "grid", "lock", "probe", "key", "white"]:
		COL.set(n, CrtKit.c8(_shiftc(C[n])))
	COL.fire = CrtKit.c8(_mixc(C.fire, [255, 228, 140], tk))
	COL.ice = CrtKit.c8(_mixc(C.ice, [255, 255, 255], tk * 0.8))
	COL.red = CrtKit.c8(_mixc(C.red, [255, 120, 150], tk * 0.9))


# ---- input (JS class Input) ----
func _poll() -> void:
	i_prev = i_now
	var n := {}
	for k: StringName in KEYS:
		var on := bool(test_keys.get(k, false))
		for code: int in KEYMAP[k]:
			if Inp.key_down(code):
				on = true
		n[k] = on
	if not Inp.keys_pressed.is_empty():
		pad = false
	if not Inp.real_off:
		for id: int in Input.get_connected_joypads():
			# a drifting stick used to fake hops: take the resting position of each axis as centre (first poll), then use hysteresis (on 0.5, off 0.3)
			if not _rest.has(id):
				var ax := Input.get_joy_axis(id, JOY_AXIS_LEFT_X)
				var ay := Input.get_joy_axis(id, JOY_AXIS_LEFT_Y)
				_rest[id] = Vector2(ax if absf(ax) < 0.9 else 0.0, ay if absf(ay) < 0.9 else 0.0)
			var a0: float = Input.get_joy_axis(id, JOY_AXIS_LEFT_X) - _rest[id].x
			var a1: float = Input.get_joy_axis(id, JOY_AXIS_LEFT_Y) - _rest[id].y
			var was: int = _sdir.get(id, 0)
			var sd := 0
			if was < 0:
				sd = -1 if a0 < -0.3 else 0
			elif was > 0:
				sd = 1 if a0 > 0.3 else 0
			else:
				sd = -1 if a0 < -0.5 else (1 if a0 > 0.5 else 0)
			_sdir[id] = sd
			var a := Input.is_joy_button_pressed(id, JOY_BUTTON_A)
			var b := Input.is_joy_button_pressed(id, JOY_BUTTON_B)
			var x := Input.is_joy_button_pressed(id, JOY_BUTTON_X)
			var dl := Input.is_joy_button_pressed(id, JOY_BUTTON_DPAD_LEFT)
			var dr := Input.is_joy_button_pressed(id, JOY_BUTTON_DPAD_RIGHT)
			if a or b or x or dl or dr or sd != 0:
				pad = true
			if dl or sd < 0:
				n[&"left"] = true
			if dr or sd > 0:
				n[&"right"] = true
			if a or Input.is_joy_button_pressed(id, JOY_BUTTON_DPAD_UP):
				n[&"jump"] = true
			if b or x or Input.is_joy_button_pressed(id, JOY_BUTTON_DPAD_DOWN) or Input.get_joy_axis(id, JOY_AXIS_TRIGGER_LEFT) > 0.5 or a1 > 0.7:
				n[&"duck"] = true
			if a or Input.is_joy_button_pressed(id, JOY_BUTTON_START):
				n[&"confirm"] = true
			if Input.is_joy_button_pressed(id, JOY_BUTTON_BACK):
				n[&"abort"] = true
	i_now = n


func _hit(k: StringName) -> bool:
	return i_now[k] and not i_prev.get(k, false)


func held(k: StringName) -> bool:
	return i_now[k] or bot_held.get(k, false)


func _sort_order(a: Variant, b: Variant) -> bool:      # (JS sort is stable, sort_custom is not)
	return a.z < b.z or (a.z == b.z and a.order < b.order)


# ---- the run: rails (per lane, sorted intervals), obstacles, bits ----
func v_at(z: float) -> float:
	return lerpf(tier.v[0], tier.v[1], clampf(z / float(tier.length), 0.0, 1.0))


func build() -> void:
	var T := tier
	var LEN := float(T.length)
	rails = [[], [], []]
	var open: Array = [null, 0.0, null]
	var ol: Array[Obs] = []
	var m := func(z: float, s: float) -> float: return s * v_at(z)
	var pick := func(a: Array) -> Variant: return a[int(rng.next() * a.size())] if not a.is_empty() else (0 if rng.next() >= 0.0 else 0)
	var is_open := func(l: int) -> bool: return open[l + 1] != null
	var open_list := func() -> Array:
		var r: Array = []
		for l: int in [-1, 0, 1]:
			if open[l + 1] != null:
				r.append(l)
		return r
	var open_l := func(l: int, z: float) -> void:
		if open[l + 1] == null:
			open[l + 1] = z
	var close_l := func(l: int, z: float) -> void:
		if open[l + 1] != null:
			if z - float(open[l + 1]) > 2.0:
				var R := Rail.new()
				R.z0 = open[l + 1]
				R.z1 = z
				rails[l + 1].append(R)
			open[l + 1] = null
	var neighbours := func() -> Array:
		var r: Array = []
		for l: int in [-1, 0, 1]:
			# (past the edge counts as open, as in the JS, where open[-1] is undefined and undefined !== null: an outer line can always open)
			var lo: bool = l - 1 < -1 or open[l] != null
			var hi: bool = l + 1 > 1 or open[l + 2] != null
			if open[l + 1] == null and (lo or hi):
				r.append(l)
		return r
	var put := func(lane: int, z: float, type: StringName) -> void:
		var o := Obs.new()
		o.lane = lane
		o.z = z
		o.type = type
		o.order = ol.size()
		ol.append(o)
	var pats: Array = ["low", "low", "high", "high", "wall", "wall", "gap", "merge"]
	if T.combo:
		pats.append_array(["combo", "combo"])
	if int(T.slalom) != 0:
		pats.append_array(["slalom", "slalom"])
	if T.runner:
		pats.append("runner")
	# the first few teach one thing each, in order
	var intro: Array = ["low", "high", "wall", "gap", "merge"]
	var c := 85.0
	var last := ""
	var rest0: float = T.rest[0]
	var rest1: float = T.rest[1]
	while c < LEN - m.call(LEN, 4.0):
		c += m.call(c, lerpf(rest0, rest1, rng.next()))
		var pat: String = intro.pop_front() if not intro.is_empty() else pick.call(pats)
		if pat == last and pat != "low" and pat != "high":
			pat = pick.call(pats)
		last = pat
		var lanes: Array = open_list.call()
		if pat == "low" or pat == "high":
			for l: int in lanes:
				put.call(l, c, StringName(pat))
			c += m.call(c, 0.55)
		elif pat == "combo":
			var a: StringName = &"low" if rng.next() < 0.5 else &"high"
			var b: StringName = &"high" if a == &"low" else &"low"
			for l: int in lanes:
				put.call(l, c, a)
			var z2: float = c + m.call(c, 0.8)
			for l: int in lanes:
				put.call(l, z2, b)
			c = z2 + m.call(c, 0.55)
		elif pat == "gap":
			var gl: float = m.call(c, 0.27)
			for l: int in lanes:
				close_l.call(l, c)
				open[l + 1] = c + gl
			c += gl + m.call(c, 0.5)
		elif pat == "wall":
			if lanes.size() < 2:
				var s: int = pick.call(neighbours.call())
				open_l.call(s, c)
				lanes.append(s)
				c += m.call(c, 1.5)
			elif not is_open.call(0):      # never make the dodge a jump across the void
				open_l.call(0, c)
				lanes.append(0)
				c += m.call(c, 1.2)
			var free: int = pick.call(lanes)
			for l: int in lanes:
				if l != free:
					put.call(l, c, &"wall")
			c += m.call(c, 0.6)
		elif pat == "slalom":
			for l: int in [-1, 0, 1]:
				open_l.call(l, c)
			var z: float = c + m.call(c, 1.4)
			var f: int = pick.call([-1, 0, 1])
			var n: int = int(T.slalom) + int(rng.next() * 2.0)
			for _i in n:
				for l: int in [-1, 0, 1]:
					if l != f:
						put.call(l, z, &"wall")
				if f == 0:
					f = pick.call([-1, 1])
				elif f == -1:
					f = 0 if rng.next() < 0.75 else -1
				else:
					f = 0 if rng.next() < 0.75 else 1
				z += m.call(z, 0.85)
			c = z
		elif pat == "merge":
			# the line(s) you are on run out: the survivor carries on (a fresh one opens beside a lone line)
			var keep: int
			if lanes.size() == 1:
				keep = pick.call(neighbours.call())
				open_l.call(keep, c)
			elif not is_open.call(0):      # two outer lines: they fold into a fresh middle one
				keep = 0
				open_l.call(0, c)
			else:
				keep = pick.call(lanes)
			var end: float = c + m.call(c, 1.5)
			for l: int in lanes:
				if l != keep:
					close_l.call(l, end)
			c = end + m.call(c, 0.4)
		elif pat == "runner":
			if lanes.size() < 2 and rng.next() < 0.6:
				var s: int = pick.call(neighbours.call())
				open_l.call(s, c)
				lanes.append(s)
				c += m.call(c, 1.0)
			put.call(pick.call(lanes), c + m.call(c, 0.5), &"runner")
			c += m.call(c, 1.0)
		# drift: lines open and close between the set pieces too
		if rng.next() < 0.4:
			var now: Array = open_list.call()
			if now.size() < 3 and rng.next() < 0.6:
				open_l.call(pick.call(neighbours.call()), c + m.call(c, 0.2))
			elif now.size() > 1:
				# a line only runs out next to one that carries on (never strand the packet across the void)
				var can: Array = []
				for l: int in now:
					var beside := false
					for k: int in now:
						if absi(k - l) == 1:
							beside = true
					if beside and not (l == 0 and now.size() == 3):
						can.append(l)
				if not can.is_empty():
					close_l.call(pick.call(can), c + m.call(c, 1.2))
					c += m.call(c, 1.2)
	# home stretch: everything merges into the middle line, which runs into the CORE PORT
	c += m.call(c, 0.8)
	open_l.call(0, c)
	var end2: float = c + m.call(c, 1.6)
	for l: int in [-1, 1]:
		close_l.call(l, end2)
	gate_z = end2 + m.call(end2, 1.6)
	for l: int in [-1, 0, 1]:
		close_l.call(l, gate_z + 400.0)
	for r: Array in rails:
		r.sort_custom(func(x: Rail, y: Rail) -> bool: return x.z0 < y.z0)
	ol.sort_custom(_sort_order)
	# obstacles only stand on rails that exist (a gap or an EOF can swallow one: drop it)
	obs.clear()
	for o: Obs in ol:
		if rail_at(o.lane, o.z - 1.0) and rail_at(o.lane, o.z + 1.0):
			obs.append(o)
	# bits: short strings on a line, lifted over firewalls (jump for them) and lowered under scan gates (shrink for them)
	bits.clear()
	var add_bit := func(lane: int, z: float, y: float, scrub: bool, mystery: bool) -> void:
		var q := BitQ.new()
		q.lane = lane
		q.z = z
		q.y = y
		q.scrub = scrub
		q.mystery = mystery
		q.order = bits.size()
		bits.append(q)
	var zb := 110.0
	var lanes3: Array = [-1, 0, 1]
	while zb < gate_z - 40.0:
		var lane: int = pick.call(lanes3)
		var n: int = 6 + int(rng.next() * 5.0)
		for k in n:
			var bz: float = zb + k * 3.2
			if not rail_at(lane, bz):
				continue
			var near: Obs = null
			for o: Obs in obs:
				if o.lane == lane and absf(o.z - bz) < 4.5:
					near = o
					break
			if near != null and (near.type == &"wall" or near.type == &"runner"):
				continue
			var y := 0.55
			if near != null:
				y = 1.55 if near.type == &"low" else 0.2
			add_bit.call(lane, bz, y, false, false)
		zb += 30.0 + rng.next() * 50.0
	var clear_of_obs := func(lane: int, z: float) -> bool:
		for o: Obs in obs:
			if o.lane == lane and absf(o.z - z) < 8.0:
				return false
		return true
	for _k in 2 + (1 if T.name == "CIVILIAN" else 0):      # SCRUB keys knock the trace back
		for _t in 30:
			var z: float = lerpf(0.25, 0.9, rng.next()) * gate_z
			var lane: int = pick.call(lanes3)
			if rail_at(lane, z) and clear_of_obs.call(lane, z):
				add_bit.call(lane, z, 0.7, true, false)
				break
	# MYSTERY crates: rare, gold, and what is inside is rolled when you grab it (jackpot / big scrub / overclock)
	var n_crate: int = 3 + int(rng.next() * 3.0)
	for k in n_crate:
		for _t in 30:
			var z: float = lerpf(0.12 + 0.8 * k / n_crate, 0.2 + 0.8 * (k + 1) / n_crate, rng.next()) * gate_z
			var lane: int = pick.call(lanes3)
			var free := true
			for q: BitQ in bits:
				if q.lane == lane and absf(q.z - z) < 4.0:
					free = false
					break
			if rail_at(lane, z) and clear_of_obs.call(lane, z) and free:
				add_bit.call(lane, z, 0.75, false, true)
				break
	bits.sort_custom(_sort_order)
	# the void's dressing
	ph = [rng.next() * 6.28, rng.next() * 6.28, rng.next() * 6.28, rng.next() * 6.28]
	towers.clear()
	for _i in 46:
		var x := (rng.next() - 0.5) * 2200.0
		var z := 650.0 + rng.next() * 420.0
		var w := 18.0 + rng.next() * 60.0
		var h := 30.0 + pow(rng.next(), 2.0) * 260.0
		var d := 18.0 + rng.next() * 40.0
		towers.append({"x": x, "z": z, "w": w, "h": h, "d": d})
	seed_n = int(rng.next() * 1e9)
	streaks.clear()
	for _i in 40:
		var x := (rng.next() - 0.5) * 70.0
		var y := -2.0 - rng.next() * 26.0
		var z := rng.next() * 200.0
		streaks.append({"x": x, "y": y, "z": z})
	p = Packet.new()


## does lane `l` have a line at z?
func rail_at(l: int, z: float) -> bool:
	if l < -1 or l > 1:
		return false
	for s: Rail in rails[l + 1]:
		if z < s.z0:
			return false
		if z <= s.z1:
			return true
	return false


## the z where lane l's line ends (an EOF, not just a short gap) within `within` metres, or NONE
func rail_end_ahead(l: int, z: float, within: float) -> float:
	var r: Array = rails[l + 1]
	for i in r.size():
		var s: Rail = r[i]
		if z >= s.z0 - 0.01 and z <= s.z1:
			if s.z1 - z > within:
				return NONE
			for k in range(i + 1, r.size()):
				if (r[k] as Rail).z0 > s.z1:
					return NONE if (r[k] as Rail).z0 - s.z1 < 14.0 else s.z1
			return s.z1
	return NONE


## track centreline: gentle S-bends and swells that grow in after the start
func cx(z: float) -> float:
	var k := clampf((z - 50.0) / 220.0, 0.0, 1.0)
	return k * (10.0 * sin(z / 101.0 + ph[0]) + 5.0 * sin(z / 43.0 + ph[1]))


func cy(z: float) -> float:
	var k := clampf((z - 50.0) / 220.0, 0.0, 1.0)
	return k * (4.0 * sin(z / 77.0 + ph[2]) + 1.6 * sin(z / 31.0 + ph[3]))


# ---- frame loop (fixed-step sim so a run plays the same every time) ----
func _process(delta: float) -> void:
	if dead:
		return
	var dt := minf(0.05, delta)
	_poll()
	for k: StringName in KEYS:
		if _hit(k):
			press[k] = true
	if freeze_t > 0.0:      # hit-stop: a few frozen frames sell the big moments
		freeze_t -= dt
	else:
		acc += dt
	while acc >= STEP:
		acc -= STEP
		step(STEP)
		press.clear()
		if dead:
			return
	for i in range(_later.size() - 1, -1, -1):
		_later[i][0] -= dt
		if _later[i][0] <= 0.0:
			var roll: float = _later[i][1]
			_later.remove_at(i)
			_mystery_open(roll)
	fx(dt)
	au.update(dt)
	fx_nodes.render(dt)


func step(dt: float) -> void:
	var P := press
	pt += dt
	if P.get(&"abort", false) and phase != "result":
		close({"ok": false, "aborted": true})
		return
	if phase == "boot":
		var typed := floori(pt * 95.0)
		if typed > _typed:
			_typed = typed
			if typed % 2 == 0 and typed < "".join(boot_lines()).length():
				au.type()
		if pt > 2.6 or (pt > 0.25 and (P.get(&"confirm", false) or P.get(&"jump", false))):
			phase = "count"
			pt = 0.0
			_beep = -1
	elif phase == "count":
		var n := floori(pt / 0.55)
		if n != _beep and n < 4:
			_beep = n
			au.beep(n == 3)
		if pt >= 0.55 * 3.0:
			phase = "play"
			pt = 0.0
			au.start_grind()
			shake = 0.3
			white_flash = 0.35
			au.start_song(song.file)
			set_banner("INJECTED", "NOW PLAYING: " + String(song.name), COL.probe, 1.6)
	elif phase == "play":
		time += dt
		trace += dt * float(tier.passive)
		if bot:
			bot_think()
		update_player(dt)
		if phase == "play":
			collide()
		if trace >= 100.0 and phase == "play":
			fail()
		if phase == "play" and p.z >= gate_z:
			win()
	elif phase == "lost":
		p.vy -= GRAV * dt
		p.y += p.vy * dt
		p.flip += dt * 9.0
		if trace >= 100.0:
			fail()
			return
		if pt > 0.95:
			respawn()
	elif phase == "win":
		p.z += v * dt * (1.0 - clampf(pt / 1.6, 0.0, 1.0))
		p.y += dt * 3.0 * pt
		if pt > 1.8:
			phase = "result"
			pt = 0.0
	elif phase == "fail":
		glitch = maxf(glitch, 0.4 * (1.0 - pt / 1.8))
		if pt > 1.8:
			phase = "result"
			pt = 0.0
	elif phase == "result":
		if pt > 0.6 and (P.get(&"confirm", false) or P.get(&"jump", false)):
			close(result)


func update_player(dt: float) -> void:
	var P := press
	var B := bot_press
	# speed: the line gets faster the deeper you are; a hit knocks it down for a second
	slow = maxf(0.0, slow - dt)
	if oc > 0.0:      # OVERCLOCK: faster, untouchable, rainbow trail
		oc -= dt
		p.inv = maxf(p.inv, 0.1)
		var rc: Color = [COL.red, COL.fire, COL.key, COL.solid, COL.probe][randi() % 5]
		_part(p.x + (randf() - 0.5) * 0.8, p.y + 0.2 + randf() * 0.6, p.z - 0.5, (randf() - 0.5) * 2.0, randf() * 2.0, v * 0.2, 2.0, 0.5, rc)
		if oc <= 0.0:
			oc = 0.0
			popup("OVERCLOCK OVER", COL.dim)
	v = v_at(p.z) * (1.0 - 0.4 * slow) * (1.18 if oc > 0.0 else 1.0)
	p.z += v * dt
	p.inv -= dt
	p.coyote -= dt
	p.jump_buf -= dt
	p.duck_t -= dt
	# hop between lines (any time, ground or air: a hop onto nothing is a fall)
	var dir := (1 if P.get(&"right", false) or B.get(&"right", false) else 0) - (1 if P.get(&"left", false) or B.get(&"left", false) else 0)
	if dir != 0 and p.lane + dir >= -1 and p.lane + dir <= 1:
		p.lane += dir
		p.lean = dir
		au.hop(dir)
		if p.ground:
			p.ground = false
			p.vy = HOP_V
	var tx := p.lane * LANE_W
	var sp := LANE_W / HOP_T
	p.x += clampf(tx - p.x, -sp * dt, sp * dt)
	if absf(tx - p.x) < 0.01:
		p.lean *= exp(-dt * 10.0)
	# shrink: hold it, a tap lasts DUCK_MIN; in the air it slams you down
	if P.get(&"duck", false) or B.get(&"duck", false):
		p.duck_t = DUCK_MIN
		au.play("shrink")
		if not p.ground and p.vy > FAST_FALL:
			p.vy = FAST_FALL
	if held(&"duck"):
		p.duck_t = maxf(p.duck_t, 0.02)
	# jump (buffered, with coyote time off the end of a line)
	if P.get(&"jump", false) or B.get(&"jump", false):
		p.jump_buf = JUMP_BUF
	if p.jump_buf > 0.0 and (p.ground or p.coyote > 0.0) and p.duck_t <= 0.02:
		p.ground = false
		p.vy = JUMP_V
		p.coyote = 0.0
		p.jump_buf = 0.0
		p.flip_v = PI * 2.0 / (2.0 * JUMP_V / GRAV)
		au.play("jump")
		leds.disk = 1.0
	if not p.ground:
		p.vy -= GRAV * dt
		p.y += p.vy * dt
		if p.flip_v != 0.0:
			p.flip += p.flip_v * dt
		if p.vy <= 0.0 and p.y <= 0.0 and p.y > -0.75:
			var ln := _round_js(p.x / LANE_W)
			if absf(p.x - ln * LANE_W) < 0.6 and rail_at(ln, p.z):
				p.y = 0.0
				p.vy = 0.0
				p.ground = true
				p.flip = 0.0
				p.flip_v = 0.0
				p.squash = 1.0
				au.play("land")
				shake = maxf(shake, 0.08)
				burst(p.x, 0.05, p.z, COL.fire if chain >= 5 else COL.solid, 10 + mini(chain, 12), 4.0)      # landing sparks, hotter on a chain
		if p.y < -1.6:
			lose()
			return
	elif not rail_at(_round_js(p.x / LANE_W), p.z):      # ran off the end of the line (or into a dead sector)
		p.ground = false
		p.vy = 0.0
		p.coyote = COYOTE
	p.squash = maxf(0.0, p.squash - dt * 5.0)
	au.set_grind(p.ground, v, 1.0 if oc > 0.0 else minf(1.0, chain / 12.0))
	# sparks off the rail
	if p.ground and randf() < 0.7:
		for _k in 2:
			_part(p.x + (randf() - 0.5) * 0.6, 0.02, p.z - 0.4, (randf() - 0.5) * 3.0, 1.0 + randf() * 2.5, v * (0.35 + randf() * 0.3), 14.0, 0.18 + randf() * 0.2, COL.white if randf() < 0.3 else COL.solid)
	# warnings: lines opening up ahead, the line under you running out
	for l in range(-1, 2):
		var r: Array = rails[l + 1]
		while _told_i[l + 1] < r.size() and (r[_told_i[l + 1]] as Rail).z0 <= p.z + 20.0:
			_told_i[l + 1] += 1
		var i := _told_i[l + 1]
		while i < r.size():
			var s: Rail = r[i]
			if s.z0 >= p.z + v * 2.4:
				break
			if not s.told and s.z0 > 60.0:
				s.told = true
				if not rail_at(l, s.z0 - 15.0):
					au.play("link")
					popup("<< LINE OPEN" if l < p.lane else ("LINE OPEN >>" if l > p.lane else "LINE OPEN"), COL.probe)
			i += 1
	var e := rail_end_ahead(p.lane, p.z, v * 1.6) if p.ground else NONE
	eof = e
	if e != NONE:
		eof_t -= dt
		if eof_t <= 0.0:
			au.play("eof")
			eof_t = 0.45
	else:
		eof_t = 0.0
	# first sighting of each hazard type: name it and say how to beat it
	for i in range(_ob_i, obs.size()):
		var o := obs[i]
		if o.z > p.z + v * 2.6:
			break
		if o.z < p.z or seen.has(o.type):
			continue
		seen[o.type] = true
		var d: Dictionary = OB[o.type]
		set_banner(d.name, String(d.how) + "  [" + key_name(o.type) + "]", COL.red if o.type == &"runner" else COL.fire, 2.0)
	if not seen.has(&"gap"):
		var e2 := rail_end_ahead(p.lane, p.z, v * 2.2)
		var r: Array = rails[p.lane + 1]
		var s: Rail = null
		var nx: Rail = null
		for q: Rail in r:
			if s == null and q.z0 <= p.z and q.z1 >= p.z:
				s = q
			elif s != null and q.z0 > s.z1:
				nx = q
				break
		if e2 == NONE and s != null and nx != null and nx.z0 - s.z1 < 14.0 and s.z1 - p.z < v * 2.2:
			seen[&"gap"] = true
			set_banner("DEAD SECTOR", "JUMP THE GAP  [" + key_name(&"low") + "]", COL.fire, 2.0)
	if e != NONE and not seen.has(&"eof"):
		seen[&"eof"] = true
		set_banner("EOF - LINE ENDS", "HOP TO ANOTHER LINE  [" + key_name(&"wall") + "]", COL.fire, 2.0)


func _round_js(x: float) -> int:      # Math.round: halves go up, also on the negative side
	return floori(x + 0.5)


func key_name(type: StringName) -> String:
	if type == &"low" or type == &"runner":
		return "A" if pad else "SPACE"
	if type == &"high":
		return "B" if pad else "S / SHIFT"
	return "D-PAD" if pad else "A / D"


func collide() -> void:
	var h := DUCK_H if p.duck_t > 0.0 else CUBE
	while _ob_i < obs.size():      # (behind the packet and settled: never looked at again)
		var o0 := obs[_ob_i]
		if (o0.hit or o0.done_) and o0.z + float(OB[o0.type].d) / 2.0 < p.z - 0.45:
			_ob_i += 1
		else:
			break
	for i in range(_ob_i, obs.size()):
		var o := obs[i]
		var d: Dictionary = OB[o.type]
		var dd: float = d.d
		var dw: float = d.w
		if o.z - dd / 2.0 > p.z + 0.45:
			break
		if o.z + dd / 2.0 < p.z - 0.45:      # behind us: if we went through its lane untouched, that is a clean pass
			if not o.hit and not o.done_:
				o.done_ = true
				if absf(p.x - o.lane * LANE_W) <= dw / 2.0 + 0.3:
					cleared(o.gap >= 0.0 and o.gap < 0.22)
			continue
		if o.hit:
			continue
		if absf(p.x - o.lane * LANE_W) > dw / 2.0 + 0.3:
			continue
		var h0: float = d.h0
		var h1: float = d.h1
		if o.type != &"wall":      # how narrowly are we squeezing past? (smallest gap seen while overlapping it)
			var gap: float = h0 - (p.y + h - 0.06) if o.type == &"high" else p.y + 0.06 - h1
			if gap >= 0.0:
				o.gap = gap if o.gap < 0.0 else minf(o.gap, gap)
		if p.y + h - 0.06 <= h0 or p.y + 0.06 >= h1:
			continue
		o.hit = true
		if p.inv > 0.0:
			if oc > 0.0:
				smash(o)
			continue
		hit(o)
	while _bit_i < bits.size() and (bits[_bit_i].got or bits[_bit_i].z < p.z - 1.0):
		_bit_i += 1
	for i in range(_bit_i, bits.size()):
		var q := bits[i]
		if q.z > p.z + 1.0:
			break
		if q.got or q.z < p.z - 1.0:
			continue
		if absf(p.x - q.lane * LANE_W) < 1.0 and absf(q.y - (p.y + h / 2.0)) < 0.95:
			grab(q)
	streak_t += STEP
	if streak_t > 0.7:
		streak = 0


## a hazard passed without a scratch: the chain climbs, the bell climbs, every 5th is a burst of reward
func cleared(shave_: bool = false) -> void:
	chain += 1
	best_chain = maxi(best_chain, chain)
	var pts := 50 * mini(chain, 10)
	score += pts
	au.clear(chain)
	leds.disk = 1.0
	if shave_:      # squeezed by with almost no room to spare
		score += 150
		au.play("shave")
		white_flash = maxf(white_flash, 0.12)
		popup("CLOSE SHAVE +150", COL.red)
		burst(p.x, p.y + 0.5, p.z + 0.5, COL.white, 14, 5.0)
	elif chain >= 3:
		popup("CLEAN x%d  +%d" % [chain, pts], COL.fire if chain >= 10 else COL.probe)
	if chain % 5 == 0:
		trace = maxf(0.0, trace - 4.0)
		score += 250
		au.play("overdrive")
		white_flash = 0.35
		shake = 0.3
		freeze_t = 0.07
		set_banner("UNTRACEABLE" if chain >= 15 else ("GHOST PROTOCOL" if chain >= 10 else "OVERDRIVE"), "CHAIN x%d   -4%% TRACE   +250" % chain, COL.fire, 1.1)
		burst(p.x, p.y + 0.6, p.z + 1.0, COL.fire, 40, 9.0)


func smash(o: Obs) -> void:      # overclock plough-through
	smashed += 1
	score += 300
	au.play("smash")
	shake = 0.35
	freeze_t = 0.04
	cleared()
	burst(p.x, p.y + 0.5, p.z + 0.8, COL.red if o.type == &"runner" else COL.fire, 34, 8.0)


func mystery(_q: BitQ) -> void:
	crates += 1
	au.play("mystery")
	freeze_t = 0.1
	white_flash = 0.4
	_later.append([0.14, randf()])      # rolled live: not seeded, so it is a genuine surprise


func _mystery_open(roll: float) -> void:
	if dead or (phase != "play" and phase != "lost"):      # (a crate rolled after win/fail would change a frozen result)
		return
	if roll < 0.34:
		var pts := 1000 + 500 * randi_range(0, 2)
		score += pts
		au.play("jackpot")
		shake = 0.4
		set_banner("JACKPOT", "+%d CREDITS" % pts, COL.fire, 1.6)
		for _i in 70:
			_part(p.x + (randf() - 0.5) * 2.0, p.y + 1.0, p.z + 1.0 + randf() * 2.0, (randf() - 0.5) * 7.0, 4.0 + randf() * 8.0, v * 0.5, 18.0, 0.9 + randf() * 0.6, COL.fire if randf() < 0.5 else COL.key)
	elif roll < 0.62:
		trace = maxf(0.0, trace - 30.0)
		score += 800
		au.play("scrub")
		au.play("overdrive")
		set_banner("DEEP SCRUB", "-30% TRACE", COL.white, 1.6)
		burst(p.x, p.y + 0.6, p.z + 1.0, COL.white, 50, 9.0)
	else:
		oc = 6.0
		au.play("powerup")
		shake = 0.5
		set_banner("OVERCLOCK", "6 SEC  UNTOUCHABLE  SMASH EVERYTHING", COL.fire, 1.8)
	white_flash = 0.5


func hit(o: Obs) -> void:
	chain = 0
	trace += int(tier.hit)
	contacts += 1
	p.inv = 1.1
	slow = 1.0
	shake = 0.7
	glitch = 0.45
	red_flash = 1.0
	leds.video = 1.0
	streak = 0
	au.play("hit")
	popup("+%d%% TRACE" % int(tier.hit), COL.red)
	burst(p.x, p.y + 0.5, p.z + 0.5, COL.red if o.type == &"runner" else COL.fire, 26, 6.0)


func grab(q: BitQ) -> void:
	q.got = true
	leds.disk = 1.0
	if q.mystery:
		mystery(q)
		return
	if q.scrub:
		trace = maxf(0.0, trace - 12.0)
		score += 500
		au.play("scrub")
		white_flash = 0.25
		popup("SCRUB -12% TRACE", COL.white)
		return
	streak += 1
	streak_t = 0.0
	nbits += 1
	var pts := 25 * mini(streak, 8)
	score += pts
	au.bit(streak - 1)
	if nbits % 25 == 0:      # every 25 bits: a BYTE, a small payout and a sparkle
		trace = maxf(0.0, trace - 3.0)
		score += 200
		au.play("overdrive")
		white_flash = 0.2
		popup("BYTE COMPLETE  -3% TRACE", COL.white)
		burst(p.x, p.y + 0.6, p.z + 1.0, COL.key, 24, 6.0)
	if streak >= 4 and streak % 4 == 0:
		popup("x%d  +%d" % [mini(streak, 8), pts], COL.probe)


func lose() -> void:
	phase = "lost"
	pt = 0.0
	falls += 1
	chain = 0
	oc = 0.0
	trace += int(tier.fall)
	au.play("fall")
	au.set_grind(false, 0.0)
	glitch = 0.6
	red_flash = 0.8
	shake = 0.4
	streak = 0
	set_banner("PACKET LOST", "+%d%% TRACE // RESENDING" % int(tier.fall), COL.red, 1.2)


func respawn() -> void:
	# put the packet back on the nearest live line a little ahead, dropping in from above
	var z := p.z
	for _t in 400:
		var found := false
		for l: int in [p.lane, p.lane - 1, p.lane + 1, p.lane - 2, p.lane + 2]:
			if l >= -1 and l <= 1 and rail_at(l, z) and rail_at(l, z + 12.0):
				p.lane = l
				found = true
				break
		if found:
			break
		z += 1.0
	p.z = z
	p.x = p.lane * LANE_W
	p.y = 2.2
	p.vy = 0.0
	p.ground = false
	p.flip = 0.0
	p.flip_v = 0.0
	p.inv = 1.6
	phase = "play"
	pt = 0.0
	white_flash = 0.3


func win() -> void:
	phase = "win"
	pt = 0.0
	au.play("win")
	au.stop_grind()
	au.stop_song(1.5)
	white_flash = 1.0
	shake = 0.4
	var clean := contacts + falls
	var tr := _round_js(clampf(trace, 0.0, 100.0))
	var bonus := (100 - tr) * 30
	score += bonus
	var rating := "S" if clean == 0 and tr < 45 else ("A" if clean <= 1 else ("B" if clean <= 3 else ("C" if clean <= 5 else "D")))
	result = {"ok": true, "aborted": false, "time": time, "trace": tr, "trace_bonus": bonus, "contacts": contacts, "falls": falls, "bits": nbits, "score": score, "rating": rating, "best_chain": best_chain, "crates": crates}


func fail() -> void:
	phase = "fail"
	pt = 0.0
	trace = 100.0
	au.play("fail")
	au.stop_grind()
	au.stop_song(1.0)
	glitch = 1.0
	red_flash = 1.0
	result = {"ok": false, "aborted": false, "time": time, "trace": 100, "trace_bonus": 0, "contacts": contacts, "falls": falls, "bits": nbits, "score": score, "rating": "-", "best_chain": best_chain, "crates": crates}


# ---- debug autopilot (opts.bot): reads the track like a player would; proves every run can be cleared ----
func _live(l: int, d0: float) -> float:      # how far lane l stays usable from z + d0: a wall or an EOF kills it, a short dead sector does not
	var z := p.z
	var jumpable := v * 0.33
	var i0 := _ob_i
	for i in range(i0, obs.size()):
		var o := obs[i]
		if o.z >= z + d0 + 1.3:
			break
		if o.lane == l and o.type == &"wall" and o.z > z - 1.3:
			return 0.0      # walled while you hop across
	var d := d0
	while d < v * 4.0:
		var zz := z + d
		if not rail_at(l, zz):
			var k := 0.0
			while k < jumpable and not rail_at(l, zz + k):
				k += 1.0
			if k >= jumpable:
				return d
			d += k
			d += 1.0
			continue
		for i in range(i0, obs.size()):
			var o := obs[i]
			if o.z - zz >= 1.3:
				break
			if o.lane == l and o.type == &"wall" and absf(o.z - zz) < 1.3:
				return d
		d += 1.0
	return v * 4.0


func bot_think() -> void:
	var z := p.z
	bot_press = {}
	bot_held = {}
	var here := _live(p.lane, 0.0)
	if here < v * 1.3:
		var best := p.lane
		var bs := here
		for l: int in [-1, 0, 1]:
			if l == p.lane or (absi(l - p.lane) == 2 and _live(0, 0.0) < v * 0.6):      # don't cut through a walled middle line
				continue
			var s := _live(l, v * 0.3 * absi(l - p.lane)) - absi(l - p.lane)
			if s > bs + 2.0:
				bs = s
				best = l
		bot_target = best
	elif bot_target == 99 or absi(bot_target - p.lane) == 0:
		bot_target = p.lane
	if bot_target != p.lane:
		bot_press[&"left" if bot_target < p.lane else &"right"] = true
	for i in range(_ob_i, obs.size()):
		var o := obs[i]
		if o.z > z + v * 0.5:
			break
		if o.z < z - 1.3 or o.lane != p.lane or o.hit:
			continue
		var lead := (o.z - z) / v
		if (o.type == &"low" or o.type == &"runner") and lead > 0.0 and lead < 0.2 and p.ground:
			bot_press[&"jump"] = true
		if o.type == &"high" and lead < 0.25:
			bot_held[&"duck"] = true
			if not p.ground and p.duck_t <= 0.0:
				bot_press[&"duck"] = true
	if p.ground and not rail_at(p.lane, z + v * 0.12):
		bot_press[&"jump"] = true


# ---- effects (per rendered frame) ----
func fx(dt: float) -> void:
	var k := 1.0 - exp(-dt * 6.0)
	cam.x = lerpf(cam.x, p.x * 0.82, k)
	cam.y = lerpf(cam.y, maxf(-1.4, p.y) * 0.45 + (-0.35 if p.duck_t > 0.0 else 0.0), k)
	var curv := (cx(p.z + 30.0) - 2.0 * cx(p.z + 15.0) + cx(p.z)) / 225.0
	cam.roll = lerpf(cam.roll, clampf(-curv * 45.0, -0.18, 0.18) - p.lean * 0.05, 1.0 - exp(-dt * 3.0))
	cam.intro = 1.0 if phase == "boot" else (maxf(0.0, 1.0 - pt / 1.6) if phase == "count" else maxf(0.0, float(cam.intro) - dt))
	for kk: String in leds:
		if kk != "power":
			leds[kk] = maxf(0.0, float(leds[kk]) - dt * 4.0)
	if trace > 65.0 and phase == "play":
		leds.sync = 1.0 if sin(time * 18.0) > 0.0 else 0.0
	if trace > 70.0 and phase == "play":
		alarm_t -= dt
		if alarm_t <= 0.0:
			au.play("alarm")
			alarm_t = lerpf(0.9, 0.2, (trace - 70.0) / 30.0)
	tear_t -= dt
	if tear_t <= 0.0:
		tear_t = (1.2 + randf() * 3.0) * (1.0 - 0.55 * tk)
		glitch = maxf(glitch, 0.1 + randf() * 0.14 + 0.1 * tk)
		leds.video = 1.0
	shake = maxf(0.0, shake - dt * 1.8)
	glitch = maxf(0.0, glitch - dt)
	red_flash = maxf(0.0, red_flash - dt * 1.6)
	white_flash = maxf(0.0, white_flash - dt * 1.4)
	score_shown += (score - score_shown) * (1.0 - exp(-dt * 10.0))
	if not banner.is_empty():
		banner.t += dt
		if banner.t > banner.dur:
			banner = {}
	for i in range(popups.size() - 1, -1, -1):
		popups[i].t += dt
		if popups[i].t > 1.1:
			popups.remove_at(i)
	var w := 0
	for i in parts.size():
		var q := parts[i]
		q.t += dt
		q.x += q.vx * dt
		q.y += q.vy * dt
		q.z += q.vz * dt
		q.vy -= q.g * dt
		if q.t <= q.life:
			parts[w] = q
			w += 1
	parts.resize(w)
	if parts.size() > 400:
		parts = parts.slice(parts.size() - 400)


func _part(x: float, y: float, z: float, vx: float, vy: float, vz: float, g: float, life: float, col: Color) -> void:
	var q := Part.new()
	q.x = x
	q.y = y
	q.z = z
	q.vx = vx
	q.vy = vy
	q.vz = vz
	q.g = g
	q.life = life
	q.col = col
	parts.append(q)


func set_banner(text: String, sub: String, col: Color, dur: float) -> void:
	banner = {"text": text, "sub": sub, "col": col, "dur": dur, "t": 0.0}


func popup(text: String, col: Color) -> void:
	var has := view != null and view.has_eye and view.project(cx(p.z) + p.x, cy(p.z) + p.y + 1.2, p.z)
	popups.append({"text": text, "col": col, "t": 0.0, "x": view.px if has else float(view.W) / 2.0, "y": view.py if has else float(view.H) * 0.6})


func burst(x: float, y: float, z: float, col: Color, n: int, sp: float) -> void:
	for _i in n:
		_part(x, y, z, (randf() - 0.5) * sp, randf() * sp * 0.8, v * 0.6 + (randf() - 0.5) * sp, 10.0, 0.4 + randf() * 0.4, col)


func close(res: Dictionary) -> void:
	if dead:
		return
	dead = true
	au.stop_grind()
	if au.song != null:
		au.song.stop()
	for a: AudioStreamPlayer in au.players:      # (a sound still ringing dies with the overlay's fade in the JS; here with the node)
		a.reparent(Game)
		a.finished.connect(a.queue_free)
		if not a.playing:
			a.queue_free()
	Game.overlay = null
	get_viewport().disable_3d = false
	if _prev_mouse == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = _prev_mouse
	Inp.guard_arm()      # the overlay swallowed these keys: whatever is still held does nothing until it is let go
	done.emit(res)
	queue_free()


func boot_lines() -> Array[String]:
	return [
		"SCHLEEDTECH LINK 09 - TERMINAL SERVICES",
		"(C) 2091 SCHLEEDTECH ORBITAL HOLDINGS",
		"",
		"C:\\> DIAL \"" + title + "\"",
		"CARRIER ................ 28800 BPS",
		"ICE CLASS .............. " + String(tier.name),
		"DATA LINES ............. 3 (UNSTABLE)",
		"ROUTE LENGTH ........... %d KB" % roundi(gate_z),
		"C:\\> RUN RAILJACK.EXE /PACKET",
	]


## a tracer waits up the line, then runs at you at 11 m/s and meets you exactly at o.z
func runner_z(o: Obs) -> float:
	return o.z + minf(o.z - p.z, 120.0) * 11.0 / v_at(o.z)


func alarm_mix() -> float:
	if phase == "fail" or (phase == "result" and not result.ok):
		return 0.85
	if phase != "play" or trace < 75.0:
		return 0.0
	return clampf((trace - 75.0) / 25.0, 0.0, 1.0) * (0.35 + 0.25 * sin(Time.get_ticks_msec() / 120.0))
