class_name MsAct2
extends RefCounted
## THE MOTHERSHIP, act two: everything after the kitchen (JS levels/mothership/act2.js, greens.js, the handles of upper.js).
##   08 CASINO LA LUNA   the green janitor, two rail beams that CROSS (jump from one to the other where they meet), tommy-gun grays, then THE ROULETTE FLOOR: the wheel turns (you turn with it), its pocket walls are moving cover, a giant ball rolls round the rim. Optional B: the HIGH-ROLLER LOUNGE (stop three slot reels on a 7 each).
##   09 CONSERVATORY     abduction beams roam the crop rows (show: a cow goes up and down). Optional C: the hatch beam up to the ROOF GARDEN.
##   10 PORTRAIT GALLERY the Button Man shoots the Don's portrait as a calling card, then the duel. Optional D: the DON'S STUDY (ride the orange CARRY beam on purpose up to the balcony).
##   11 THE CHAPEL       three Consiglieri pass their shields round the pews; the corridor back to the wrecked reception.
##   12 THE CLIMB        up the reception's dome: lift, ring rail, carry beam, high ring, the oculus, a music box, and the SPINE BEAM up to her.
##   13 THE GODMOTHER    the boss (ms_godmother.gd), then the truce (ms_truce.gd).
##   14 HOME             the petals open, the greens' saucer comes for you (with every captive you freed); ride its beam up.
##   optional E (from the reception): THE WINE CELLAR freezer. The counting room (optional A) keeps its caged bookkeeper; its bagmen and their alarm are gone with the Bagman (the user's cut).
## Five captive greens, one at the end of each optional route: talk to one and you spring it. Freed greens stay freed for the whole run, and the ending counts them.

const CF := 6.0
const CHAPEL_F := 7.5
const PENT_F := 44.0
const FLOOR := 2.0
const ROUL_X := 0.0
const ROUL_Z := 44.5
const ROUL_R := 8.0
const ORDER := ["arrival", "line", "reception", "brawl", "corridor", "laundry", "kitchen", "casino", "conservatory", "gallery", "chapel", "climb", "godmother", "home"]
const RAIL_RATE := 1.45      # the casino rails run their 24 s schedule in ~16.5 s
const R3_E := [22.4, 34.0]
const R3_C := [-2.0, 34.0]
const R3_W := [-22.2, 33.6]
const R4_C := [-2.0, 34.0]
const R4_V := [-2.0, 58.4]
const LANES := [-46.4, -42.2, -38.0, -33.8]
const HATCH_X := -49.4
const HATCH_Z := 27.6
const GARDEN_Y := 32.2
const STUDY_Z0 := -26.0
const STUDY_Z1 := -6.0
const STUDY_EM_Y := 18.4
const STUDY_Y0 := 6.0
const HIGH_Y := 27.2
const OCULUS_Y := 34.8
const L3_Z := 11.3
const LOUNGE_Y := 13.0
const DON_PORTRAIT := [-40.5, 11.6, -29.6]
const GALLERY_SPOTS := [[-32.5, 10.5, -24.0], [-32.5, 10.5, -10.0], [-32.5, 10.5, -3.0], [-47.0, 6.0, -27.0], [-34.0, 6.0, -27.0], [-47.0, 6.0, 1.0]]
const CELLAR := {"y0": -2.0, "x0": 7.6, "x1": 28.0, "z0": -50.0, "z1": -30.0}


## A floor tile of the penthouse: the wedge is cut into thin radial strips; they act as one solid (JS the `s` of U.tiles).
class Tile:
	var g: Node3D
	var strips: Array = []      # [solid, dx, dz]
	var mat: StandardMaterial3D = null
	var home := Vector3.ZERO
	var ring := 0
	var k := 0
	var lift := 0.0
	var want := 0.0
	var off_ := true
	var _e := -1.0

	func set_off(v: bool) -> void:
		off_ = v
		for q: Array in strips:
			(q[0] as World.Solid).set_off(v)

	func move(x: float, z: float, top: float) -> void:
		if off_:
			return
		for q: Array in strips:
			var s: World.Solid = q[0]
			s.place(x + float(q[1]), z + float(q[2]))
			s.set_span(top - MsArena.DEPTH, top, top)      # (the export's 0.6 m slab is a 1 m platform now, keel included: ms_arena.gd)

	func top_at(x: float, z: float) -> Variant:
		for q: Array in strips:
			var h: Variant = (q[0] as World.Solid).top_at(x, z)
			if h != null:
				return h
		return null

	func emission(r: float, g_: float, b: float) -> void:
		if mat != null and r != _e:
			_e = r
			mat.emission = Color(r, g_, b).linear_to_srgb()


class Captive:
	var id := ""
	var kind := ""
	var g: Node3D
	var npc: NpcRig
	var prison: Node3D
	var door: Node3D
	var beam: MeshInstance3D
	var t := 0.0
	var out := 0.0
	var mats: Array = []
	var door0 := Vector3.ONE
	var ry0 := 0.0


class Gate:
	var s: World.Solid
	var g: Node3D
	var open := 0.0
	var want := 0.0


var L: MothershipLevel
var beams: MsBeams
var stage_id := ""
var cur_obj := ""
var captives: Array[Captive] = []
var freed: Dictionary = {}
var gm: MsGodmother = null
var truce: MsTruce = null
var saucer: Node3D = null
var riders: Array[Node3D] = []
var janitor: NpcRig = null
var music_box := 0.0
var escape_t := -1.0
var ending: MsBeams.Lift = null
var ending_on := false
var truce_wait := 0.0
var counting := 0
var lounge := 0
var cellar := 0
var cellar_guards: Array = []
var solved := false
var jump_cue := 0
var opt_foes: Array = []
var gates: Dictionary = {}
var culled: Array = []
var rail_w: MsBeams.Rail
var rail_n: MsBeams.Rail
var tiles: Array[Tile] = []
var tile_floor: World.Solid
var arena: MsArena = null
var petals: Array = []      # [node, open, cur]
var pockets: Array = []      # [solid, a, r, mesh]
var wheel: Node3D
var ball: Node3D
var reels: Array = []
var plates: Array = []
var cow: Node3D
var spine_col: MeshInstance3D
var spine_core: MeshInstance3D
var spine_off := 0.0
var rw_a := 0.0
var rw_ball := 0.0
var rw_hit_cd := 0.0
var lg_stops: Array = [null, null, null]
var lg_t := 0.0
var lg_buzz := 0.0
var _root: Node3D
var complete_t := -1.0


static func after(id: String, ref: String) -> bool:
	return ORDER.find(id) >= ORDER.find(ref)


func _cull_add(o: Node3D, at: Callable = Callable(), y: float = NAN) -> void:
	if o != null:
		culled.append([o, at, y])


func _cull_step(P: Player) -> void:
	if P == null:
		return
	for c: Array in culled:
		var o: Node3D = c[0]
		var p: Vector3 = o.position if not (c[1] as Callable).is_valid() else (c[1] as Callable).call()
		var yy: float = c[2] if not is_nan(c[2]) else p.y
		o.visible = U.hyp(p.x - P.x, p.z - P.z) < 48.0 and absf(yy - P.y) < 26.0


func _hurt_p(P: Player, amt: float, x: float, z: float) -> void:
	if Game.combat != null:
		Game.combat.hurt_player(P, amt, x, z, "bolt")


func _init(level: MothershipLevel, p_beams: MsBeams, root: Node3D) -> void:
	L = level
	beams = p_beams
	_root = root
	# the moving pieces the export kept
	wheel = L.one("ms_wheel")
	ball = L.one("ms_ball")
	cow = L.one("ms_cow")
	for n: Node3D in L.node_named("ms_reel"):
		n.set_meta("mats", L.own_mats(n))
		reels.append(n)
	for n: Node3D in L.node_named("ms_plate"):
		n.set_meta("mats", L.own_mats(n))
		n.set_meta("p0", n.global_position)
		plates.append(n)
	for k in 10:
		pockets.append([L.solid_id("ms_pocket_%d" % k), float(k) / 10.0 * TAU, 5.9])
	var ppos := L.node_named("ms_pocket")
	for k in mini(10, ppos.size()):
		var a: float = pockets[k][1]
		var m: Node3D = ppos[k]
		m.position = Vector3(sin(a) * 5.9, 0.4, cos(a) * 5.9)
		m.rotation.y = a + PI / 2.0
	_build_tiles()
	for n: Node3D in L.node_named("ms_petal"):
		petals.append([n, 0.0, 0.0])
	# ---- the gates (locked until their beat): casino west door, the reception's two side doors
	for nm: String in ["casinoWest", "chapelDoor", "cellarDoor"]:
		var G0 := Gate.new()
		G0.s = L.solid_id("ms_gate_" + nm)
		G0.g = L.one("ms_gate_" + nm)
		gates[nm] = G0
		_cull_add(G0.g)
	# ---- the Spine Beam: the golden column from the cake to the sky (the landmark)
	spine_col = MsKit.glow(root, MsKit.cyl(2.4, 2.4, 400.0, 24, true), 5, 0xffd060, 0.45)
	spine_col.position.y = 8.6 + 200.0
	spine_col.extra_cull_margin = 400.0
	spine_core = MsKit.glow(root, MsKit.cyl(0.7, 0.7, 400.0, 12, true), 0, 0xfff4d0, 0.35)
	spine_core.position.y = 8.6 + 200.0
	spine_core.extra_cull_margin = 400.0
	# ---- beams: the casino's crossing rails, the climb, the conservatory, the study, the lounge, the hatch
	rail_w = _rail({"y": 18.4, "ride": 14.05, "r": 1.4, "rate": RAIL_RATE, "keys": [[0.0, R3_E[0], R3_E[1]], [1.8, R3_E[0], R3_E[1]], [5.6, R3_C[0], R3_C[1]], [8.2, R3_C[0], R3_C[1]], [12.0, R3_W[0], R3_W[1]], [13.8, R3_W[0], R3_W[1]], [17.6, R3_C[0], R3_C[1]], [20.2, R3_C[0], R3_C[1]], [24.0, R3_E[0], R3_E[1]]]})
	rail_n = _rail({"y": 19.3, "ride": 14.05, "r": 1.4, "rate": RAIL_RATE, "color": 0x5ae0ff, "keys": [[0.0, R4_V[0], R4_V[1]], [1.8, R4_V[0], R4_V[1]], [5.6, R4_C[0], R4_C[1]], [8.2, R4_C[0], R4_C[1]], [12.0, R4_V[0], R4_V[1]], [13.8, R4_V[0], R4_V[1]], [17.6, R4_C[0], R4_C[1]], [20.2, R4_C[0], R4_C[1]], [24.0, R4_V[0], R4_V[1]]]})
	_lift({"x": 0.0, "z": 24.6, "y0": 7.5, "y1": 18.6, "r": 1.3})
	# the ring rail: stops north (over the gallery lift) and south (the ledge)
	var ring: Array = []
	var RR := 24.6
	var half := 6.5
	var wait := 2.6
	ring.append([0.0, 0.0, RR])
	ring.append([wait, 0.0, RR])
	for i in range(1, 19):
		var a := float(i) / 18.0 * PI
		ring.append([wait + half * i / 18.0, sin(a) * RR, cos(a) * RR])
	ring.append([2.0 * wait + half, 0.0, -RR])
	for i in range(1, 19):
		var a := PI + float(i) / 18.0 * PI
		ring.append([2.0 * wait + half + half * i / 18.0, sin(a) * RR, cos(a) * RR])
	_rail({"y": 23.4, "ride": 18.9, "r": 1.5, "keys": ring, "linear": true, "rate": 1.3})
	beams.lift({"x": 0.0, "z": 0.0, "y0": OCULUS_Y - 0.6, "y1": PENT_F + 0.9, "r": 3.6, "invisible": true, "pull": 2.6, "speed": 6.5, "to": [0.0, 5.2]})
	_lift({"x": 0.0, "z": L3_Z, "y0": HIGH_Y, "y1": 35.4, "r": 1.4, "to": [0.0, 7.0]})      # (its emitter sits in the landing pad off the high ring)
	# the climb's carry beam (south ledge -> high ring) and two red beams patrolling the high ring
	_abduct({"path": func(_t: float) -> Vector2: return Vector2(0.0, -21.2), "y": 31.2, "floor": 18.3, "r": 1.5, "carry": {"to": [0.0, HIGH_Y, -16.0]}})
	for i in 2:
		_abduct({"path": func(t: float) -> Vector2:
			var a := t * 0.16 + i * PI
			return Vector2(sin(a) * 16.0, cos(a) * 16.0), "y": 34.2, "floor": HIGH_Y, "r": 1.4, "dmg": 12.0, "hurt": _hurt_p})
	# the conservatory: one slow beam over the first bed (the try), four roaming the lanes (the test); a cow on a decor beam by the door (the show)
	for i in LANES.size():
		var lx: float = LANES[i]
		_abduct({"path": func(t: float) -> Vector2:
			var u := (sin(t * (0.22 + i * 0.05) + i * 1.7) + 1.0) / 2.0
			return Vector2(lx, 9.0 + u * 33.0), "y": 15.3, "floor": CF, "r": 1.5, "dmg": 12.0, "hurt": _hurt_p})
	_lift({"x": -46.5, "z": 42.5, "y0": CF + 0.35, "y1": CF + 4.0, "r": 1.1, "decor": true, "color": 0xff5a3a})
	# the study: red beams roam its floor; an orange carry beam takes you to the balcony
	for i in 2:
		_abduct({"path": func(t: float) -> Vector2:
			var u := (sin(t * (0.3 + i * 0.1) + i * 2.0) + 1.0) / 2.0
			return Vector2(-56.0 + i * 2.5, STUDY_Z0 + 3.0 + u * (STUDY_Z1 - STUDY_Z0 - 6.0)), "y": STUDY_EM_Y, "floor": STUDY_Y0, "r": 1.4, "dmg": 10.0, "hurt": _hurt_p})
	_abduct({"path": func(t: float) -> Vector2:
		var u := (sin(t * 0.25) + 1.0) / 2.0
		return Vector2(-53.2, STUDY_Z0 + 4.0 + u * 12.0), "y": STUDY_EM_Y, "floor": STUDY_Y0, "r": 1.5, "carry": {"to": [-62.0, 13.0, -9.0]}})
	# the lounge's reward beam (only once the reels pay out) and the roof hatch
	_lift({"x": -20.8, "z": 51.8, "y0": LOUNGE_Y, "y1": 17.9, "r": 1.1, "on": func(_t: float) -> float: return 1.0 if solved else 0.0})
	_lift({"x": HATCH_X, "z": HATCH_Z, "y0": CF, "y1": GARDEN_Y + 0.6, "r": 1.3, "to": [HATCH_X - 2.6, HATCH_Z]})
	# the end saucer
	saucer = L.one("ms_end_saucer")
	L.saucer_prep(saucer)
	for n: Node3D in L.node_named("ms_rider"):
		riders.append(n)
		n.visible = false
	saucer.visible = false


func _lift(o: Dictionary) -> MsBeams.Lift:
	o["parent"] = _root
	var l := beams.lift(o)
	_cull_add(l.g, Callable(), (float(o.y0) + float(o.y1)) / 2.0)      # (lifts by their base, trolleys and emitters as they move)
	if l.g != null:
		var lx: float = o.x
		var lz: float = o.z
		culled[culled.size() - 1][1] = func() -> Vector3: return Vector3(lx, 0.0, lz)
	return l


func _rail(o: Dictionary) -> MsBeams.Rail:
	o["parent"] = _root
	var r := beams.rail(o)
	_cull_add(r.trolley)
	return r


func _abduct(o: Dictionary) -> MsBeams.Abduct:
	o["parent"] = _root
	var a := beams.abduct(o)
	_cull_add(a.g)
	return a


func _build_tiles() -> void:
	tile_floor = L.solid_id("ms_tile_floor")
	var idx := 0
	for ring in 2:
		for k in 8:
			var r0 := 14.2 if ring == 1 else 8.0
			var r1 := 20.4 if ring == 1 else 14.1
			var a0 := (k + ring * 0.5) / 8.0 * TAU + 0.01
			var a1 := a0 + TAU / 8.0 - 0.02
			var am := (a0 + a1) / 2.0
			var rm := (r0 + r1) / 2.0
			var tl := Tile.new()
			tl.g = L.one("ms_tile_%d" % idx)
			tl.ring = ring
			tl.k = k
			tl.home = Vector3(sin(am) * rm, PENT_F, cos(am) * rm)
			tl.g.position = tl.home
			var wedge := (a1 - a0) / 9.0
			for j in 9:
				var aj := a0 + wedge * (j + 0.5)
				var s := L.solid_id("ms_tile_%d_%d" % [idx, j])
				tl.strips.append([s, sin(aj) * rm - tl.home.x, cos(aj) * rm - tl.home.z])
			var ms: Array = L.own_mats(tl.g)
			if not ms.is_empty():
				tl.mat = ms[0]
				tl.mat.emission_enabled = true
				tl.mat.emission = Color.BLACK
			tl.set_off(true)
			tiles.append(tl)
			idx += 1
	arena = MsArena.new(L, self)      # the tiles' real bodies, the drum, the gift ledge and the pit under them


# ================================================================== the gates
func gate_set(nm: String, open: bool, instant: bool = false) -> void:
	var G0: Gate = gates[nm]
	G0.want = 1.0 if open else 0.0
	G0.s.set_off(open)
	if instant:
		G0.open = G0.want


# ================================================================== the roulette floor + its ball
func _roulette_step(dt: float, P: Player, C: Combat, on: bool) -> void:
	var w := 0.22 if on else 0.05
	rw_a += w * dt
	wheel.rotation.y = rw_a
	for p: Array in pockets:
		var a: float = p[1] + rw_a
		(p[0] as World.Solid).place(ROUL_X + sin(a) * float(p[2]), ROUL_Z + cos(a) * float(p[2]), -a + PI / 2.0)
	# carry whoever stands on the wheel round with it
	if P != null and P.grounded and absf(P.y - (CF + 0.05)) < 0.2:
		var dx := P.x - ROUL_X
		var dz := P.z - ROUL_Z
		var r := U.hyp(dx, dz)
		if r < ROUL_R - 0.2:
			var a := atan2(dx, dz) + w * dt
			var nx := ROUL_X + sin(a) * r
			var nz := ROUL_Z + cos(a) * r
			if not L.world.blocked(nx, nz, P.y, 1.8, 0.36, 0.42):
				P.x = nx
				P.z = nz
				P.yaw += w * dt
	# the ball rolls round the rim track (the other way), speeding up and slowing; it knocks you off your feet
	var ball_v := -(0.65 + 0.25 * sin(rw_a * 3.0) if on else 0.2)
	rw_ball += ball_v * dt
	var br := ROUL_R + 0.95
	var bx := ROUL_X + sin(rw_ball) * br
	var bz := ROUL_Z + cos(rw_ball) * br
	ball.position = Vector3(bx, CF + 0.8, bz)
	ball.rotation.x += dt * 6.0
	rw_hit_cd = maxf(0.0, rw_hit_cd - dt)
	if on and P != null and not P.dead and rw_hit_cd <= 0.0 and U.hyp(P.x - bx, P.z - bz) < 1.25 and P.y < CF + 1.6 and C != null:
		rw_hit_cd = 1.0
		if C.hurt_player(P, 12.0, bx, bz, "melee"):
			var d := U.hyp(P.x - bx, P.z - bz)
			if d == 0.0:
				d = 1.0
			P.ix += (P.x - bx) / d * 9.0
			P.iz += (P.z - bz) / d * 9.0
			P.vy = 6.0
			P.grounded = false
	if on and P != null and U.hyp(P.x - bx, P.z - bz) < 14.0 and randf() < dt * 3.0:
		MsSound.noise(0.12, &"lowpass", 300.0, 300.0, 0.05, 1.0, 0.2)


# ================================================================== the lounge puzzle: three reels, three plates; stop each reel on a 7
func _lounge_step(dt: float, P: Player) -> void:
	lg_t += dt
	lg_buzz = maxf(0.0, lg_buzz - dt)
	for i in mini(reels.size(), plates.size()):
		var sym: int = lg_stops[i] if lg_stops[i] != null else posmod(floori(lg_t / (0.42 + i * 0.07) + i), 4)
		var mats: Array = (reels[i] as Node3D).get_meta("mats")
		for m: StandardMaterial3D in mats:
			m.uv1_scale = Vector3(1.0, 0.25, 1.0)
			m.uv1_offset = Vector3(0.0, sym * 0.25, 0.0)
		var pl: Node3D = plates[i]
		var pos: Vector3 = pl.get_meta("p0")
		var on := U.hyp(P.x - pos.x, P.z - pos.z) < 0.7 and absf(P.y - LOUNGE_Y) < 0.4
		pl.position.y = LOUNGE_Y + (0.0 if on else 0.03)
		var pm: Array = pl.get_meta("mats")
		var hex := 0x402000
		if lg_stops[i] != null:
			hex = 0x40a020 if lg_stops[i] == 3 else 0x601010
		for m: StandardMaterial3D in pm:
			m.emission = MsKit.srgb(hex)
		if on and lg_stops[i] == null and not solved and lg_buzz <= 0.0:
			lg_stops[i] = sym
			MsSound.tone(0.12, 880.0 if sym == 3 else 440.0, 1320.0 if sym == 3 else 330.0, 0.12, &"square", 0.0)
	if not solved and lg_stops[0] != null and lg_stops[1] != null and lg_stops[2] != null:
		if lg_stops[0] == 3 and lg_stops[1] == 3 and lg_stops[2] == 3:
			solved = true
			L.toast("JACKPOT! A beam to the shelf above.")
			for k in 3:
				var rp: Vector3 = (reels[k] as Node3D).global_position
				L.sparks(Vector3(rp.x, LOUNGE_Y + 2.0, rp.z), 30, 6.0, Vector3.UP, 0xffd060)
			var parts: Array = []
			var fs := [660.0, 880.0, 990.0, 1320.0, 1760.0]
			for i in 5:
				parts.append(["tone", i * 0.09, {"type": &"triangle", "f0": fs[i], "f1": fs[i], "gain": 0.08, "dur": 0.12}])
			MsSound.play(parts, 0.0)
		else:
			lg_buzz = 1.6
			lg_stops = [null, null, null]
			MsSound.tone(0.5, 120.0, 90.0, 0.2, &"sawtooth", 0.0)


# ================================================================== people: the janitor (quiet beat), the captives, the Godmother, the saucer
func setup_people(rigs: Dictionary) -> void:
	var D: Dialogue = Game.dialogue
	var me := "TOMMY" if L.char_id() == "tommy" else "PROG"
	janitor = rigs.get("ms_janitor")
	if janitor != null:
		L.to_zone(janitor, "casino")
		L.rig_actors.append([janitor, "casino"])
	D.add_talker({"id": "ms_janitor", "name": "GREEN JANITOR", "x": 24.2, "y": 13.0, "z": 36.6, "yaw": -PI / 2.0, "actor": janitor, "voice_pitch": 1.2, "shot": {"spot_fwd": 2.0}, "active": func() -> bool: return stage_id == "casino",
		"lines": ["Psst. Hey. You're the one the boys are talkin' about. Nice work in the kitchen.", "The Godmother's up top, in the dome. The Spine Beam goes straight to her: you climb the reception to get to it.",
			"And listen... five of ours are locked up in this house. Cages, freezers, worse. If you got time... the saucer's got room.", {"who": me, "text": "I'll keep an eye out.", "voice": null}, "You're a good egg. For an Earth guy."]})
	var defs: Array = [
		{"id": "books", "name": "BOOKKEEPER", "kind": "cage", "x": 54.0, "y": -4.0, "z": -27.8, "yaw": 0.0, "lines": ["They got me countin' THEIR money. In MY own currency!", {"who": me, "text": "Hold still. ...There."}, "I'm out! I'll meet you at the saucer. Don't spend it all in one place!"]},
		{"id": "crooner", "name": "LOUNGE CROONER", "kind": "cage", "x": -23.4, "y": 17.3, "z": 52.4, "yaw": PI / 2.0, "lines": ["They made me sing \"That's Amore\" four hundred times. FOUR HUNDRED.", {"who": me, "text": "You're free. No encores."}, "Bless you. I'm outta here."]},
		{"id": "gardener", "name": "GARDENER", "kind": "cage", "x": -63.6, "y": GARDEN_Y, "z": 8.4, "yaw": PI / 2.0, "lines": ["They hung me out here like a birdfeeder. The pigeons, man. THE PIGEONS.", {"who": me, "text": "Let's get you down."}, "Thanks! I'll see you at the saucer. Watch the wind!"]},
		{"id": "accountant", "name": "THE ACCOUNTANT", "kind": "shoes", "x": -62.2, "y": 13.0, "z": -21.0, "yaw": PI / 2.0, "lines": ["Cement shoes. Classic. The ledger's on the shelf: everything they took from our neighborhood.", {"who": me, "text": "Taking it. And you."}, "That book is gonna make the greens VERY happy. Go!"]},
		{"id": "frozen", "name": "FROZEN GREEN", "kind": "ice", "x": 12.0, "y": -2.0, "z": -47.5, "yaw": 0.0, "lines": ["Mmmf. MMMF. ...MMMMF!", {"who": me, "text": "Hang on, I'll chip you out."}, "B-b-brr! Th-thanks! I'll th-thaw out on the saucer!"]},
	]
	for d: Dictionary in defs:
		var cid: String = d.id
		var C := Captive.new()
		C.id = cid
		C.kind = d.kind
		C.g = L.one("ms_cage_" + cid)
		C.prison = L.one("ms_prison_" + cid)
		C.door = L.one("ms_door_" + cid)
		C.door0 = C.door.scale
		C.ry0 = C.door.rotation.y
		C.npc = rigs.get("ms_green_" + cid)
		C.beam = MsKit.glow(C.g, MsKit.cyl(0.7, 0.7, 6.0, 16, true), 0, 0x7affc0, 0.0)
		C.beam.position.y = 3.0
		if C.kind == "ice":
			C.mats = L.own_mats(C.door)
		captives.append(C)
		_cull_add(C.g)
		if C.npc != null:
			C.npc.reparent(C.g, false)
			C.npc.position = Vector3.ZERO
			C.npc.rotation.y = float(d.yaw)
			C.npc.set(&"R_x", float(d.x))
			C.npc.set(&"R_z", float(d.z))
			C.npc.set(&"R_yaw", float(d.yaw))
		D.add_talker({"id": "ms_green_" + cid, "name": d.name, "x": d.x, "y": d.y, "z": d.z, "yaw": d.yaw, "actor": C.npc, "voice_pitch": 1.25, "color": "#7be34a", "shot": {"spot_fwd": 2.0}, "active": func() -> bool: return not freed.has(cid), "lines": d.lines, "on_end": func(_t: Dictionary) -> void: free_green(cid)})
	gm = MsGodmother.new(L, _root)
	# the truce is a cutscene, not a talker: it plays by itself a moment after "Enough."
	truce = MsTruce.new(L, gm, PENT_F)


func free_green(id: String, instant: bool = false) -> void:
	if freed.has(id):
		return
	freed[id] = true
	var C: Captive = null
	for c: Captive in captives:
		if c.id == id:
			C = c
	if C == null:
		return
	C.out = 2.0 if instant else 0.001
	if not instant:
		var n := freed.size()
		L.toast("GREENS FREED %d / 5" % n)
		L.radio("All five! The whole band's goin' home tonight." if n == 5 else "Got another one. The saucer'll pick 'em up.")
		var P := Game.player
		if P != null:
			P.hp = maxf(P.hp, P.max_hp if P.max_hp != 0.0 else 100.0)
		_refill()
		MsSound.play([["tone", 0.0, {"type": &"sine", "f0": 440.0, "f1": 1320.0, "gain": 0.12, "dur": 0.6}], ["tone", 0.15, {"type": &"sine", "f0": 660.0, "f1": 1760.0, "gain": 0.08, "dur": 0.6}]], 0.5)


func _refill() -> void:
	var C2 := Game.combat
	if C2 == null:
		return
	for i: int in C2.owned:
		var w: Variant = Weapons.WEAPONS[i]
		C2.ammo[i] = w.mag_size
		C2.reserve[i] = w.max - w.mag_size


func _captives_update(dt: float, time: float) -> void:
	for C: Captive in captives:
		C.t += dt
		if C.npc != null and C.g.visible:
			C.npc.update(time, dt)
		if C.out == 0.0:
			if C.npc != null:
				C.npc.position.y = absf(sin(C.t * 1.7)) * 0.03
			continue
		C.out += dt
		var u := minf(1.0, C.out / 2.0)
		if C.kind == "ice":
			L.set_alpha(C.mats, 0.55 * (1.0 - u))
			C.door.scale = Vector3(C.door0.x * (1.0 + u * 0.3), C.door0.y * (1.0 - u * 0.5), C.door0.z * (1.0 + u * 0.3))
		elif C.kind == "shoes":
			C.door.scale = C.door0 * maxf(0.01, 1.0 - u)
		else:
			C.door.rotation.y = C.ry0 - 1.8 * minf(1.0, u * 3.0)
		MsKit.opa(C.beam, u * 1.2 if u < 0.5 else (1.0 - u) * 1.2)      # a green beam takes the green out (to the saucer)
		if C.npc != null:
			C.npc.position.y = maxf(0.0, u - 0.4) * 6.0
			C.npc.scale = Vector3.ONE * maxf(0.01, 1.0 - maxf(0.0, u - 0.6) * 2.5)
			C.npc.visible = u < 0.99
		if u >= 1.0:
			C.prison.visible = C.kind != "ice"


# ================================================================== the optional rooms' guards (spawned once, when you walk in)
func _spawn_free(pt: Array, kind: String, passive: bool = false) -> Robot:
	var r: Robot = Game.spawn_enemy({"x": pt[0], "y": pt[1], "z": pt[2], "yaw": 0.0}, {"kind": kind, "no_respawn": true})
	if r != null:
		r.dev_passive = passive
	return r


func _opt_reset() -> void:
	for r: Variant in opt_foes:
		Game.despawn_enemy(r)
	opt_foes = []
	counting = 0
	lounge = 0
	cellar = 0
	cellar_guards = []


## the people in the optional rooms are already there before you can see in: they are put out while you are still outside, passive, and wake when you walk in, shoot one, or one of them sees you. Anyone who arrives later comes in through a door or a hatch.
func _wake(list: Array, P: Player) -> void:
	for r: Variant in list:
		if r != null and not r.dead:
			r.dev_passive = false
			r._know(P.x, P.z)
			r.seen_t = 0.0
			r.set_(&"alert")


func _opt_step(_dt: float, P: Player) -> void:
	if P == null:
		return
	# (optional A: the counting room's bagmen went with the Bagman; the bookkeeper's cage is open to anyone who walks in)
	if lounge == 0 and P.x > -25.0 and P.x < -14.0 and P.z > 38.5 and P.z < 55.0 and P.y > 12.0 and P.y < 18.0:      # down the lounge's service hatches
		lounge = 1
		for i in 2:
			var pt: Array = [[-19.0, 16.0, 44.0], [-19.0, 16.0, 52.0]][i]
			var r := _spawn_free(pt, "butler")
			if r != null:
				L.ent.enter(r, [pt], {"hatch": true, "delay": 0.3 + i * 0.8})
				opt_foes.append(r)
	if cellar == 0 and U.hyp(P.x - 9.0, P.z + 29.0) < 7.0 and P.y > 0.0:      # on guard in the freezer before you reach the stairs
		cellar = 1
		cellar_guards = []
		for pt: Array in [[20.0, -2.0, -40.0], [24.0, -2.0, -46.0]]:
			var r := _spawn_free(pt, "alien", true)
			if r != null:
				r.yaw = PI * 0.75
				opt_foes.append(r)
				cellar_guards.append(r)
	if cellar == 1:      # (only once you are down there, or shoot one: they guard the freezer, they don't come up into the hall)
		var hit := false
		for r: Variant in cellar_guards:
			if r != null and (r.dead or r.hp < r.max):
				hit = true
		var down: bool = P.x > CELLAR.x0 and P.x < CELLAR.x1 and P.z > CELLAR.z0 and P.z < float(CELLAR.z1) - 3.0 and P.y > float(CELLAR.y0) - 1.0 and P.y < float(CELLAR.y0) + 3.0
		if hit or down:
			cellar = 2
			_wake(cellar_guards, P)


# ================================================================== stage state
func state(_bo_: Blockout, id: String, o: Dictionary) -> void:
	stage_id = id
	beams.release()
	gate_set("casinoWest", after(id, "conservatory") or (id == "casino" and L.bo.flag("westOpen") == true), true)
	gate_set("cellarDoor", after(id, "brawl"), true)
	gate_set("chapelDoor", after(id, "climb") or (id == "chapel" and L.bo.flag("backOpen") == true), true)
	L.dome_cap.set_off(after(id, "climb"))
	if gm != null:
		var ph := gm.phase if gm.mode == "fight" else 1
		if id == "home":
			gm.place_tamed()
		elif id == "godmother" and o.get("retry", false) and not o.get("restoring", false) and ph > 1:      # died mid-fight: back to the start of this phase
			gm.resume(ph)
		elif id == "godmother" and int(o.get("objective", 0)) >= 1:      # the truce checkpoint: straight to "Enough." (the cutscene follows)
			gm.force_enough()
		else:
			gm.reset()
			if id == "godmother":
				gm.intro()
	if truce != null and truce.on:
		truce.abort()
	truce_wait = 0.0
	if saucer != null:
		saucer.visible = id == "home"
	for p: Array in petals:
		p[1] = 1.0 if id == "home" else 0.0
	escape_t = 0.0 if id == "home" else -1.0
	ending_on = false      # (the ending's beam is built once and switched on per run)
	_opt_reset()      # the optional rooms' guards come back with any stage (re)start
	lg_stops = [null, null, null]


func truce_done() -> void:
	gm.shake_ = false
	gm.tame()
	L.bo.flag("truce", true)


func open_roof() -> void:
	for p: Array in petals:
		p[1] = 1.0
	MsSound.play([["noise", 0.0, {"type": &"lowpass", "f0": 300.0, "f1": 900.0, "gain": 0.25, "attack": 0.4, "dur": 2.4}], ["tone", 0.0, {"type": &"sine", "f0": 70.0, "f1": 110.0, "gain": 0.3, "dur": 2.4}]], 0.5)


# ================================================================== per frame
func update(dt: float, P: Player, C2: Combat, t: float) -> void:
	_cull_step(P)
	var cam: Vector3 = Game.view.camera.global_position if Game.view != null else Vector3.ZERO
	for A: MsBeams.Abduct in beams.abducts:      # never let the camera sit inside an emitter
		if A.g.visible and A.g.position.distance_to(cam) < 2.2:
			A.g.visible = false
	_captives_update(dt, t)
	# gates swing open / shut
	for g0: Gate in gates.values():
		g0.open += (g0.want - g0.open) * minf(1.0, dt * 3.0)
		g0.g.scale.y = maxf(0.02, 1.0 - g0.open)
		if g0.g.visible and g0.open >= 0.97:
			g0.g.visible = false
	spine_off -= dt * 0.35
	MsKit.scroll(spine_col, spine_off)
	# ENGINE DIFFERENCE: the JS adds after its tone map, this frame before: with the camera inside the column, two walls of it would burn the picture out through the curve
	MsKit.opa(spine_col, 0.25 if U.hyp(cam.x, cam.z) < 2.4 else 0.45)
	MsKit.opa(spine_core, (0.3 + 0.1 * sin(t * 3.0)) * 0.5)      # (the JS core is one-sided; this shader draws both its walls)
	_roulette_step(dt, P, C2, stage_id == "casino" and (cur_obj == "roulette" or cur_obj == "roulette2"))
	# the crossing: riding one casino rail while the other waits under you -> both cones flash and a JUMP! cue (once per meeting)
	if stage_id == "casino":
		var rd := beams.riding
		var other: MsBeams.Rail = rail_n if rd == rail_w else (rail_w if rd == rail_n else null)
		var meet := other != null and U.hyp(rd.x - other.x, rd.z - other.z) < 1.2
		if meet:
			other.flash = maxf(other.flash, 0.6 + 0.4 * sin(t * 14.0))
			if jump_cue == 0:
				jump_cue = 1
				L.toast("JUMP! Switch beams")
				MsSound.tone(0.18, 1200.0, 1600.0, 0.1)
		elif other == null or U.hyp(rd.x - other.x, rd.z - other.z) > 4.0:
			jump_cue = 0
	if P != null and P.x < -13.0 and P.z > 38.0 and P.y > 12.0:
		_lounge_step(dt, P)
	var u := (sin(t * 0.7) + 1.0) / 2.0
	cow.position.y = CF + 0.35 + u * 3.2
	cow.rotation.y = 0.6 + t * 0.8
	cow.rotation.z = sin(t * 1.3) * 0.3
	_opt_step(dt, P)
	# the roof garden's wind: gusts push you toward the edge (the banners snap first)
	if P != null and P.y > GARDEN_Y - 0.5 and P.x < -50.0 and P.z < 31.0 and P.z > 5.0:
		if fmod(t, 7.0) > 5.0:
			P.ix -= 3.2 * dt * 9.0 * 0.1
		if fmod(t, 7.0) > 4.4 and fmod(t, 7.0) < 4.4 + dt:
			MsSound.noise(2.2, &"bandpass", 500.0, 1400.0, 0.25, 0.8, 0.6, 0.6)
	# the quiet landing: a music box on the oculus ring
	if P != null and stage_id == "climb" and P.y > OCULUS_Y - 0.5 and P.y < OCULUS_Y + 3.0:
		music_box -= dt
		if music_box <= 0.0:
			music_box = 0.36
			var notes := [1047.0, 1319.0, 1568.0, 1319.0, 1175.0, 1397.0, 1760.0, 1397.0]
			var nt: float = notes[floori(t / 0.36) % notes.size()]
			MsSound.tone(0.5, nt, nt, 0.035, &"triangle", 0.6)
	# the boss
	if gm != null and truce != null and stage_id == "godmother" and gm.is_done() and L.bo.flag("truce") != true and not truce.on and P != null and not P.dead:      # let "ENOUGH." land, then the truce
		truce_wait += dt
		if truce_wait > 2.4:
			truce.start(P)
	if truce != null and truce.on:
		truce.update(dt, P)
	if arena != null and P != null and P.y > PENT_F - 14.0:
		arena.update(dt, t)
	if gm != null:
		gm.update(dt, P, C2, t)
		L.bo.boss_bar(gm.get_bar() if stage_id == "godmother" and P != null and P.y > PENT_F - 3.0 else null)
		if stage_id == "godmother" and gm.mode == "off" and P != null and P.y > PENT_F - 1.0:
			gm.intro()
	# the ending: petals open, the saucer comes down with whoever you freed, its beam takes you up
	for p: Array in petals:
		p[2] = float(p[2]) + (float(p[1]) - float(p[2])) * minf(1.0, dt * 0.8)
		(p[0] as Node3D).rotation.x = float(p[2]) * 1.9
	if saucer != null and escape_t >= 0.0:
		escape_t += dt
		var su := minf(1.0, escape_t / 6.0)
		saucer.position = Vector3(0.0, PENT_F + 18.0 + (1.0 - su) * 40.0, -6.0)
		saucer.rotation.y = t * 0.3
		L.set_saucer_lights(saucer, t)
		var n := freed.size()
		for i in riders.size():
			riders[i].visible = i < n
			riders[i].position.y = 1.75 + absf(sin(t * 6.0 + i)) * 0.06
		if escape_t > 1.2 and escape_t - dt <= 1.2:
			L.radio("...Did you just shake hands with the Godmother?")
		if escape_t > 3.9 and escape_t - dt <= 3.9:
			Game.hud.subtitle({"id": 0, "num": 0, "text": "A finger. I shook a finger.", "dur": 2.6, "name": "TOMMY" if L.char_id() == "tommy" else "PROG", "speech": false})
		if escape_t > 6.0 and not ending_on:
			ending_on = true
			if ending == null:
				ending = beams.lift({"parent": _root, "x": 0.0, "z": -6.0, "y0": PENT_F, "y1": PENT_F + 15.5, "r": 1.8, "color": 0x7affc0, "on": func(_t: float) -> float: return 1.0 if ending_on else 0.0})
			L.radio("Get in! The band's playin' us home!" if n == 5 else "Your ride's here. Step into the beam!")
	if complete_t >= 0.0:
		complete_t += dt
		if complete_t > 5.2:
			complete_t = -1.0
			Game.doors.travel({"id": "mothership-home", "to": "hub", "label": "HOME"})


func on_complete() -> void:
	L.toast("THE MOTHERSHIP -- GREENS FREED %d / 5" % freed.size())
	complete_t = 0.0


# ================================================================== stages (after the kitchen)
func _hatch(delay: float) -> Dictionary:      # the casino's SERVICE HATCHES (an iris in the ceiling, a tractor beam lowers them)
	return {"hatch": true, "delay": delay}


func _soldier(x: float, y: float, z: float, more: Dictionary = {}) -> Dictionary:
	var d := {"x": x, "y": y, "z": z, "kind": "alien"}
	d.merge(more)
	return d


func _kind(x: float, y: float, z: float, k: String, more: Dictionary) -> Dictionary:
	var d := {"x": x, "y": y, "z": z, "kind": k}
	d.merge(more)
	return d


func _from_gallery(x: float, delay: float) -> Dictionary:
	return {"from": [[x, CF, -6.0], [x, CF, 3.5]], "delay": delay}


func _from_chapel(x: float, delay: float) -> Dictionary:
	return {"from": [[x, CHAPEL_F, -36.0], [x, CHAPEL_F, -31.6], [x, CF, -28.6]], "delay": delay}


func _from_corridor(dy: float, delay: float) -> Dictionary:
	return {"from": [[-10.0, FLOOR + dy, -34.0], [-10.0, FLOOR + dy, -43.0], [-15.0, FLOOR + 1.5 + dy, -43.0], [-23.5, CHAPEL_F + dy, -43.0]], "delay": delay}


func _from_hall(delay: float, speed: float = 8.0) -> Dictionary:
	return {"from": [[0.0, FLOOR + 2.5, -36.0], [0.0, FLOOR + 2.5, -25.0], [0.0, 14.0, -8.0]], "delay": delay, "speed": speed}


func _mark(id: String) -> Callable:
	return func(_b: Variant = null, _o: Variant = null) -> void: cur_obj = id


func stages() -> void:
	var bo := L.bo
	bo.stage({"id": "casino", "name": "Casino La Luna", "spawn": {"x": 23.0, "y": 13.0, "z": 32.0, "yaw": -PI / 2.0}, "task": "The house always wins. Tonight, the house is you.",
		"on_enter": func(_a: Variant, o: Dictionary) -> void:
			if not o.get("retry", false):
				L.radio("A casino? In a house? ...Course they got a casino."),
		"objectives": [
			{"id": "balcony", "label": "La Luna", "text": "Casino La Luna. (A green janitor is mopping the balcony: X to talk.)", "at": [21.0, 13.0, 33.2], "radius": 2.2, "on_start": _mark("balcony")},
			{"id": "cross", "label": "The crossing", "text": "Ride the rail beam WEST. Where it crosses the other rail it stops: JUMP across onto the blue one and ride it NORTH to the VIP box.", "at": [-2.0, 13.0, 58.6], "radius": 3.0,
				"spawns": [_kind(12.0, CF, 50.0, "tommygun", _hatch(0.6)), _kind(-12.0, CF, 38.0, "tommygun", _hatch(2.2)), _soldier(8.0, CF, 36.0, _hatch(1.3)), _soldier(-9.0, CF, 54.0, _hatch(3.0))], "on_start": _mark("cross")},
			{"id": "roulette", "label": "The roulette floor", "kind": "kill", "spawn": {"x": 3.0, "y": 13.0, "z": 59.4, "yaw": PI}, "text": "Down to the ROULETTE FLOOR. The Consigliere SHIELDS his family (the purple bubbles): pop the brain jar first. Mind the ball.",
				"spawns": [_kind(0.0, CF, 39.0, "muscle", _hatch(0.4)), _kind(0.0, CF + 3.0, 51.0, "consigliere", _hatch(1.4)), _soldier(6.0, CF, 48.0, _hatch(2.0)), _soldier(-6.0, CF, 38.0, _hatch(2.6))], "on_start": _mark("roulette")},
			{"id": "roulette2", "label": "House rules", "kind": "kill", "text": "They're not done. Tommy-guns on the balconies!", "spawn": {"x": 0.0, "y": CF, "z": 55.5, "yaw": PI},
				"spawns": [_kind(22.0, 13.0, 34.0, "tommygun", {"from": [[33.0, 13.0, 30.0], [26.6, 13.0, 30.4], [23.0, 13.0, 31.5]], "delay": 0.3}), _kind(-22.0, 13.0, 33.0, "tommygun", _hatch(1.2)), _kind(0.0, CF + 3.0, 38.0, "consigliere", _hatch(0.6)), _kind(-6.0, CF + 2.5, 46.0, "butler", _hatch(1.8)), _kind(6.0, CF + 2.5, 46.0, "butler", _hatch(2.4))], "on_start": _mark("roulette2")},
			{"id": "west", "label": "West door", "spawn": [-19.0, CF, 40.0], "text": "The west gate's open: on to the conservatory.", "at": [-27.5, CF, 38.0], "radius": 2.0, "on_start": func(_b: Variant, _o: Variant = null) -> void:
				cur_obj = "west"
				bo.flag("westOpen", true)
				gate_set("casinoWest", true)
				L.radio("Through the west door. Keep goin' up.")},
		]})
	bo.stage({"id": "conservatory", "name": "The Conservatory", "spawn": {"x": -27.5, "y": CF, "z": 38.0, "yaw": -PI / 2.0}, "task": "The family grows its own. Under a fake moon.",
		"objectives": [
			{"id": "enter", "label": "The grow-house", "text": "See the cow? Those red beams ABDUCT. Caught in one, JUMP three times to struggle free -- or get probed.", "at": [-33.0, CF, 37.0], "radius": 2.4, "on_start": _mark("enter")},
			{"id": "rows", "label": "Through the rows", "text": "Cross the crop rows to the south door. Time the beams. (A lift beam in the far corner goes up through the roof...)", "at": [-40.5, CF, 5.4], "radius": 2.2, "via": [[-36.0, CF, 30.0], [-40.0, CF, 16.0]],
				"spawns": [_soldier(-36.0, CF, 14.0, _from_gallery(-40.0, 0.2)), _soldier(-45.0, CF, 20.0, _from_gallery(-41.2, 1.0)), _kind(-40.0, CF + 3.0, 24.0, "butler", {"from": [[-40.5, CF + 2.5, -6.0], [-40.5, CF + 2.5, 4.0]], "delay": 1.8})], "on_start": _mark("rows")},
		]})
	bo.stage({"id": "gallery", "name": "The Portrait Gallery", "spawn": {"x": -40.5, "y": CF, "z": 2.0, "yaw": PI}, "task": "Four hundred years of grays, all looking at you.",
		"objectives": [
			{"id": "enter", "label": "The family portraits", "text": "The family portraits. Somebody's up on the mezzanine...", "at": [-40.5, CF, -6.0], "radius": 2.6, "on_start": _mark("enter"),
				"on_done": func(_b: Variant = null) -> void:
					L.sparks(Vector3(DON_PORTRAIT[0], DON_PORTRAIT[1], DON_PORTRAIT[2]), 40, 7.0, null, 0xffd060)
					MsSound.tone(0.3, 1800.0, 200.0, 0.3, &"sawtooth", 0.0)
					L.guests.say("THE BUTTON MAN", "That was the Don. You're next.", -33.0, 12.0, -10.0, 0.46, "alert")},
			{"id": "button", "label": "The Button Man", "kind": "kill", "spawn": {"x": -40.5, "y": CF, "z": -6.0, "yaw": PI}, "text": "THE BUTTON MAN. Watch for his red laser: it LOCKS just before he fires -- step aside. Hit him while he aims and the shot's spoiled.",
				"spawns": [_kind(-32.5, 10.5, -12.0, "buttonman", {"from": [[-32.5, 10.5, -3.2]], "cloak": true, "speed": 3.2}), _soldier(-45.0, CF, -20.0, _from_chapel(-41.0, 0.6)), _soldier(-36.0, CF, -24.0, _from_chapel(-39.0, 1.4))], "on_start": func(_b: Variant, _o: Variant = null) -> void:
					cur_obj = "button"
					_set_spots(GALLERY_SPOTS)},
			{"id": "south", "label": "To the chapel", "spawn": [-40.5, CF, -14.0], "text": "South, to the family chapel. (The west door is the Don's study...)", "at": [-40.0, CF, -28.6], "radius": 2.0, "on_start": _mark("south")},
		]})
	bo.stage({"id": "chapel", "name": "The Family Chapel", "spawn": {"x": -40.0, "y": CF, "z": -29.0, "yaw": PI}, "task": "Pray for them.",
		"objectives": [
			{"id": "enter", "label": "The chapel", "text": "The family chapel. The Godmother, as a saint. Of course.", "at": [-32.6, CHAPEL_F, -36.5], "radius": 2.4, "via": [[-40.0, CF, -29.4], [-40.0, CHAPEL_F, -33.2]], "on_start": _mark("enter")},
			{"id": "mass", "label": "Mass", "kind": "kill", "spawn": {"x": -32.6, "y": CHAPEL_F, "z": -36.5, "yaw": PI}, "text": "Three Consiglieri, passing their shields round the pews. Pop the jars, then the family.",
				# the family files in from the corridor (up from the reception) through the chapel's east door
				"spawns": [_kind(-28.0, CHAPEL_F + 3.0, -46.0, "consigliere", _from_corridor(3.0, 0.0)), _soldier(-27.0, CHAPEL_F, -43.1, _from_corridor(0.0, 0.5)), _kind(-33.0, CHAPEL_F, -46.0, "muscle", _from_corridor(0.0, 1.2)),
					_kind(-36.0, CHAPEL_F + 3.0, -49.0, "consigliere", _from_corridor(3.0, 1.9)), _soldier(-38.0, CHAPEL_F, -43.1, _from_corridor(0.0, 2.5)), _kind(-31.0, CHAPEL_F + 3.0, -40.0, "consigliere", _from_corridor(3.0, 3.1)), _soldier(-32.6, CHAPEL_F, -50.0, _from_corridor(0.0, 3.7))], "on_start": _mark("mass")},
			{"id": "back", "label": "Back to the reception", "text": "The way up is the reception's dome. Down the corridor and back into the hall.", "at": [-9.0, FLOOR, -29.8], "radius": 2.0, "via": [[-24.6, CHAPEL_F, -43.0], [-14.0, FLOOR, -43.0], [-9.0, FLOOR, -40.0]], "on_start": func(_b: Variant, _o: Variant = null) -> void:
				cur_obj = "back"
				bo.flag("backOpen", true)
				gate_set("chapelDoor", true)},
		]})
	bo.stage({"id": "climb", "name": "The Climb", "spawn": {"x": -9.0, "y": FLOOR, "z": -26.0, "yaw": 0.0}, "task": "All the way up. She's at the top.",
		"on_enter": func(_a: Variant, o: Dictionary) -> void:
			if not o.get("retry", false):
				L.radio("The hall's trashed. ...Up the dome. Ride everything."),
		"objectives": [
			{"id": "gallery", "label": "The north gallery", "text": "Up the stairs to the north gallery.", "at": [0.0, 7.5, 24.8], "radius": 2.2, "via": [[-25.2, FLOOR, 8.2], [-21.5, 3.4, 13.6], [-14.0, 6.4, 21.2], [-9.6, 7.5, 25.0]], "on_start": _mark("gallery")},
			{"id": "ring", "label": "The ring rail", "text": "Into the lift beam, up to the RING RAIL round the dome. Ride it to the south and jump off onto the ledge.", "at": [0.0, 18.3, -22.1], "radius": 2.4, "kind": "custom",      # landing anywhere on the (12 m wide) ledge counts
				"done": func(_a: Variant, P: Player, _c: Variant = null) -> bool: return P != null and P.grounded and absf(P.y - 18.3) < 0.35 and absf(P.x) < 6.2 and P.z < -20.4 and P.z > -26.8,
				"spawns": [_kind(10.0, 22.0, 0.0, "butler", _from_hall(0.0)), _kind(-10.0, 22.0, 0.0, "butler", _from_hall(1.0))], "on_start": _mark("ring")},
			{"id": "carry", "label": "The carry beam", "text": "That ORANGE beam is a carry beam: step in and let it take you up to the high ring.", "at": [0.0, HIGH_Y, -16.0], "radius": 2.2, "on_start": _mark("carry")},
			{"id": "oculus", "label": "The oculus", "text": "Round the high ring to the north (red beams patrol it), then walk out onto the landing pad: its lift takes you up to the oculus.", "at": [0.0, OCULUS_Y, 7.0], "radius": 2.2,
				"via": [[8.2, HIGH_Y, -13.7], [12.9, HIGH_Y, -9.4], [16.0, HIGH_Y, -3.0], [16.0, HIGH_Y, 4.0], [12.4, HIGH_Y, 10.4], [6.0, HIGH_Y, 15.0], [0.0, HIGH_Y, 15.0], [0.0, HIGH_Y, 11.3]],      # round the ring (never across its hole), then out along the jetty to the pad
				"spawns": [_kind(14.0, HIGH_Y, 6.0, "buttonman", {"from": [[0.0, 35.4, L3_Z, "air"], [0.0, HIGH_Y, L3_Z, "air"], [0.0, HIGH_Y, 15.2], [9.0, HIGH_Y, 12.6]], "cloak": true, "speed": 3.6}), _kind(-12.0, HIGH_Y + 2.5, 4.0, "butler", _from_hall(0.8))],
				"on_start": func(_b: Variant, _o: Variant = null) -> void:
					cur_obj = "oculus"
					_set_spots([[16.0, HIGH_Y, 0.0], [-16.0, HIGH_Y, 0.0], [0.0, HIGH_Y, 16.0], [11.0, HIGH_Y, -11.0], [-11.0, HIGH_Y, -11.0]])},
			{"id": "spine", "label": "The Spine Beam", "text": "Quiet up here. ...The Spine Beam goes straight to her. Step in.", "at": [0.0, PENT_F, 5.2], "radius": 2.4, "dy": 3.0, "on_start": _mark("spine")},
		]})
	bo.stage({"id": "godmother", "name": "The Godmother", "spawn": {"x": 0.0, "y": PENT_F, "z": 5.2, "yaw": 0.0}, "task": "You can't beat her. Make her RESPECT you.",
		"on_enter": func(_a: Variant, o: Dictionary) -> void:
			if not o.get("retry", false):
				L.radio("...That's her. Careful. She's a lot of lady."),
		"objectives": [
			{"id": "respect", "label": "Respect", "kind": "custom", "text": func(_b: Variant = null) -> String:
				if gm != null and gm.phase == 1:
					return "Shoot out the THREE glowing emitters under her chair to bring her down, then hit her while she's DOWN."
				if gm != null and gm.phase == 2:
					return "When the red beam sweeps, get up on a HIGH tile and shoot her glowing head: break her focus and she's DIZZY."
				return "Jump the shockwave rings; hit her while she's DIZZY.",
				"done": func(_a: Variant = null, _P: Variant = null, _c: Variant = null) -> bool: return gm != null and gm.is_done(), "on_start": _mark("respect")},
			{"id": "truce", "label": "The truce", "kind": "custom", "text": "She raised her hand. \"Enough.\"", "guide": false, "done": func(_a: Variant = null, _P: Variant = null, _c: Variant = null) -> bool: return bo.flag("truce") == true, "on_start": _mark("truce")},
		]})
	bo.stage({"id": "home", "name": "Home", "spawn": {"x": 0.0, "y": PENT_F, "z": 6.0, "yaw": PI}, "task": "A truce. For now.",
		"objectives": [{"id": "board", "label": "Your ride", "text": func(_b: Variant = null) -> String:
			return "The greens' saucer is here" + (" (with %d of the five aboard)" % freed.size() if not freed.is_empty() else "") + ". Step into its beam.",
			"at": [0.0, PENT_F + 14.5, -6.0], "radius": 2.4, "dy": 3.0, "on_start": _mark("board")}]})


func _set_spots(spots: Array) -> void:
	if Game.combat == null:
		return
	for r: Robot in Game.combat.enemies.robots:
		if r is ButtonMan:
			(r as ButtonMan).spots = spots
