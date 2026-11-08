class_name MsGuests
extends RefCounted
## THE MOTHERSHIP's wedding guests (JS levels/mothership/guests.js): ~120 grays in tuxedos, pinstripes, dinner jackets and gowns, drawn as instanced crowds (one draw per outfit + heads + hats; the meshes come from the export).
## They sit at the tables, dance round the cake, mill about, and line the receiving hall, where every member of the family gives you a long, suspicious look and a TRANSLATED remark as you pass. When the toast goes wrong they scatter: the seated dive under the tablecloths, the rest bolt for the doors.

const FLOOR := 2.0
const OUTFITS := 7
const TABLES := [[-14.0, -14.0], [14.0, -14.0], [-6.5, -18.0], [6.5, -18.0], [-18.5, -4.5], [18.5, -7.0], [-12.0, 4.5], [12.0, 5.0], [-17.0, 11.0], [16.5, 11.5], [-7.0, 11.5], [7.5, 12.0]]
const FAMILY := ["COUSIN VINNY", "AUNT CARMELA", "UNCLE FRANKIE", "NONNO PAULIE", "COUSIN ANGIE", "SMALL SAL", "AUNT ROSA", "JOEY BANANAS", "TERESA", "UNCLE GINO", "LITTLE TONY", "DONNA MARIA", "COUSIN NICKY", "AUNT LUCIA", "FAT RICHIE", "GRANDPA SILVIO"]
const LINE_COMMON := ["Welcome, welcome. ...Huh. Your antenna's bent, cousin.", "Is that... nah. Nah.", "Kiss the ring. ...Close enough.", "Who invited the guy with the price tag?",
	"Your eyes look kinda small tonight, paisan.", "Smells like Earth in here. You smell that?", "Sit with the bride's side. ...Way in the back.", "Nice face. Where'd you get it?",
	"You blink? Grays don't blink. ...Do we blink?", "Ma, look. LOOK at him. ...Ma."]
const LINE_PROG := ["Sal! You got... big. Real big. The food on Zeta that good?", "Since when do grays got belly hair, Sal?", "Somebody get Sal a bigger chair."]
const LINE_TOMMY := ["Little Vito! Look at you! ...Still little.", "Is that thing on your head... spinnin'?", "Vito, you need a booster seat for the toast?"]
const ZERO := Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO)


class Guest:
	var kind := ""
	var variant := 0
	var hat := false
	var phase := 0.0
	var head_yaw := 0.0
	var panic := -1.0
	var delay := 0.0
	var gone := false
	var x := 0.0
	var y := NAN
	var z := 0.0
	var yaw := 0.0
	var hx := 0.0
	var hz := 0.0
	var hyaw := 0.0
	var table := -1
	var orbit := 0.0
	var ang := 0.0
	var nm := ""
	var pitch := 0.58
	var spoke := false
	var dive := false
	var exit_: Variant = null
	var bi := 0
	var hi := 0
	var ti := -1


var L: MothershipLevel
var guests: Array[Guest] = []
var body_mm: Array[MultiMesh] = []
var head_mm: MultiMesh
var hat_mm: MultiMesh
var scattered := false
var clock := 0.0
var last_say := -9.0
var deck: Array = []
var sid := 0
var _s := 99
var _idle := false


func _rnd() -> float:
	_s = (_s * 16807) % 2147483647
	return float(_s) / 2147483647.0


func _add(o: Dictionary) -> Guest:
	var g := Guest.new()
	g.variant = int(_rnd() * OUTFITS)
	g.hat = _rnd() < 0.45
	g.phase = _rnd() * 6.0
	g.kind = o.kind
	g.x = o.get("x", 0.0)
	g.z = o.get("z", 0.0)
	g.y = o.get("y", NAN)
	g.yaw = o.get("yaw", 0.0)
	if o.has("variant"):
		g.variant = o.variant
	if o.has("hat"):
		g.hat = o.hat
	g.table = o.get("table", -1)
	g.orbit = o.get("orbit", 0.0)
	g.ang = o.get("ang", 0.0)
	g.nm = o.get("name", "")
	g.pitch = o.get("pitch", 0.58)
	g.hx = g.x
	g.hz = g.z
	g.hyaw = g.yaw
	guests.append(g)
	return g


func _im(nm: String) -> MultiMesh:
	for n: Variant in L.node_named(nm):
		if n is MultiMeshInstance3D:
			var mi := n as MultiMeshInstance3D
			mi.extra_cull_margin = 200.0
			return mi.multimesh
	push_warning("MOTHERSHIP: no crowd mesh " + nm)
	return null


func _init(level: MothershipLevel) -> void:
	L = level
	# seated round the tables (4 of the 6 chairs), standing groups by the walls, dancers on the floor round the cake, the receiving line
	for i in TABLES.size():
		var T0: Array = TABLES[i]
		for k in 6:
			if (k + i) % 3 == 0:
				continue
			var a := float(k) / 6.0 * TAU + i
			_add({"kind": "seat", "x": T0[0] + sin(a) * 1.55, "z": T0[1] + cos(a) * 1.55, "yaw": a + PI, "table": i})
	for c: Array in [[-20.0, -14.0, 4], [21.0, 4.0, 4], [-8.0, -24.0, 3], [9.0, -24.0, 3], [-22.0, 14.0, 4], [22.0, 15.0, 3], [0.0, 13.5, 4], [-14.0, -21.0, 3]]:
		var n: int = c[2]
		for k in n:
			var a := float(k) / n * TAU
			_add({"kind": "stand", "x": c[0] + sin(a) * 0.9, "z": c[1] + cos(a) * 0.9, "yaw": a + PI})
	for k in 18:
		var a := float(k) / 18.0 * TAU
		_add({"kind": "dance", "orbit": 7.2 + (k % 2) * 1.6, "ang": a, "yaw": 0.0, "variant": (3 + (1 if k % 4 == 1 else 0)) if k % 2 else (k % 3)})
	# the head table and the tommy-gun gray on the gallery are crowd figures too (one draw per outfit, not a model each)
	for s: Array in [[-3.2, FLOOR + 1.2, 21.3, PI, 0, true], [1.4, FLOOR + 1.2, 21.3, PI, 0, false], [3.0, FLOOR + 1.2, 21.3, PI, 5, false]]:
		_add({"kind": "head", "x": s[0], "y": s[1], "z": s[2], "yaw": s[3], "variant": s[4], "hat": s[5]})
	_add({"kind": "gunner", "x": 5.5, "y": 7.5, "z": 25.4, "yaw": -PI / 2.0, "variant": 1, "hat": true})
	for i in FAMILY.size():
		var sx := 1.0 if i % 2 else -1.0
		var z := -55.0 + floori(i / 2.0) * 3.1
		var p := 0.5 + _rnd() * 0.18      # (the JS's object literal rolls this one first)
		_add({"kind": "line", "name": FAMILY[i], "x": sx * 4.1, "z": z, "yaw": -sx * PI / 2.0, "hat": i % 3 != 1, "variant": i % 5, "pitch": p})
	# which row of which instanced mesh (the export kept the JS's order: same seed, same outfits)
	var vi: Array[int] = []
	vi.resize(OUTFITS)
	var hat_i := 0
	var head_i := 0
	for g: Guest in guests:
		g.bi = vi[g.variant]
		vi[g.variant] += 1
		g.hi = head_i
		head_i += 1
		if g.hat:
			g.ti = hat_i
			hat_i += 1
	for v in OUTFITS:
		body_mm.append(_im("ms_guest_body_%d" % v))
	head_mm = _im("ms_guest_head")
	hat_mm = _im("ms_guest_hat")


## a translated line in the gray tongue from a world position (the subtitle names the speaker)
func say(nm: String, text: String, x: float, y: float, z: float, pitch: float = 0.58, kind: String = "alert") -> void:
	var e := {"id": 90000 + (sid % 500), "num": 0, "key": "ms_%d" % sid, "text": text, "dur": minf(3.2, 0.6 + text.length() * 0.055), "kind": kind, "pitch": pitch, "x": x, "y": y, "z": z, "name": nm, "speech": true}
	sid += 1
	if Game.sfx != null:
		Game.sfx.speak(e)
	Game.hud.subtitle(e)


func _next_line() -> String:
	if deck.is_empty():
		deck = LINE_COMMON.duplicate()
		deck.append_array(LINE_TOMMY if L.char_id() == "tommy" else LINE_PROG)
		for i in range(deck.size() - 1, 0, -1):
			var j := int(_rnd() * (i + 1))
			var t: Variant = deck[i]
			deck[i] = deck[j]
			deck[j] = t
	return deck.pop_back()


func _hide(g: Guest) -> void:
	body_mm[g.variant].set_instance_transform(g.bi, ZERO)
	head_mm.set_instance_transform(g.hi, ZERO)
	if g.ti >= 0:
		hat_mm.set_instance_transform(g.ti, ZERO)


func update(dt: float, P: Player, disguised: bool) -> void:
	clock += dt
	var t := clock
	if _idle:      # (everyone gone: nothing left to write)
		return
	var any := false
	for g: Guest in guests:
		if g.gone:
			_hide(g)
			continue
		any = true
		var x := g.x
		var z := g.z
		var y := g.y if not is_nan(g.y) else FLOOR
		var yaw := g.yaw
		var s := 1.0
		var bob := 0.0
		var lean := 0.0
		match g.kind:
			"dance":
				g.ang += dt * 0.22
				x = sin(g.ang) * g.orbit
				z = cos(g.ang) * g.orbit
				yaw = g.ang + PI / 2.0 + sin(t * 2.0 + g.phase) * 0.6
				bob = absf(sin(t * 4.2 + g.phase)) * 0.09
				g.x = x
				g.z = z
			"seat":
				y = FLOOR - 0.3
				bob = sin(t * 1.3 + g.phase) * 0.01
				lean = sin(t * 0.7 + g.phase) * 0.06
			"gunner":
				lean = -0.08
			_:
				bob = sin(t * 1.1 + g.phase) * 0.012
				lean = sin(t * 0.5 + g.phase) * 0.04
		# who are they looking at? the player, if he is close and in front of them (the line always looks; the rest glance)
		var want_head := sin(t * 0.4 + g.phase) * 0.5
		if P != null and not scattered:
			var dx := P.x - x
			var dz := P.z - z
			var d := U.hyp(dx, dz)
			var rel := atan2(sin(atan2(dx, dz) - yaw), cos(atan2(dx, dz) - yaw))
			var rng := 8.0 if g.kind == "line" else 6.0
			if d < rng and absf(rel) < 2.2 and absf(P.y - y) < 3.0:
				want_head = clampf(rel, -1.3, 1.3)
			if g.kind == "gunner":
				want_head = 0.0
			if g.kind == "line" and disguised and not g.spoke and d < 3.0 and t - last_say > 1.4:
				g.spoke = true
				last_say = t
				say(g.nm, _next_line(), x, y + 1.4, z, g.pitch)
		g.head_yaw += (want_head - g.head_yaw) * minf(1.0, dt * 5.0)
		# panic: dive under the nearest table, or run for the south doors, then vanish
		if g.panic >= 0.0:
			g.panic += dt
			var u := maxf(0.0, g.panic - g.delay)
			if g.kind == "head":
				var k := minf(1.0, u / 0.5)
				s = 1.0 - k
				y -= 0.6 * k
			elif g.kind == "seat" or g.dive:
				var tx: Array = TABLES[g.table if g.table >= 0 else 0]
				var k := minf(1.0, u / 0.45)
				x = x + (float(tx[0]) - x) * k * 0.6
				z = z + (float(tx[1]) - z) * k * 0.6
				s = 1.0 - k
				yaw = atan2(float(tx[0]) - x, float(tx[1]) - z)
			elif g.exit_ != null and u > 0.0:
				var ex: float = g.exit_[0]
				var ez: float = g.exit_[1]
				var dx := ex - g.x
				var dz := ez - g.z
				var d := U.hyp(dx, dz)
				if d > 0.5:
					g.x += dx / d * 6.5 * dt
					g.z += dz / d * 6.5 * dt
				x = g.x
				z = g.z
				yaw = atan2(dx, dz)
				bob = absf(sin(t * 14.0 + g.phase)) * 0.12
				s = maxf(0.0, 1.0 - (u - 3.2)) if d < 1.5 or u > 4.0 else 1.0
			if s <= 0.0:
				g.gone = true
		if g.gone or s <= 0.0:
			_hide(g)
			continue
		var b := Basis(Vector3.UP, yaw).scaled(Vector3(s, s, s)) if s != 1.0 else Basis(Vector3.UP, yaw)
		if lean != 0.0:
			b = b * Basis(Vector3.RIGHT, lean)
		var M := Transform3D(b, Vector3(x, y + bob, z))
		body_mm[g.variant].set_instance_transform(g.bi, M)
		var H := M * Transform3D(Basis(Vector3.UP, g.head_yaw), Vector3(0.0, 1.16, 0.0))
		head_mm.set_instance_transform(g.hi, H)
		if g.ti >= 0:
			hat_mm.set_instance_transform(g.ti, H)
	if not any:
		_idle = true


## the cover is blown: everyone in the hall scatters (the receiving line is out of sight and simply leaves)
func scatter() -> void:
	scattered = true
	for g: Guest in guests:
		g.panic = 0.0
		g.delay = 0.15 + _rnd() * 0.7
		if g.kind == "line" or g.kind == "gunner":
			g.gone = true
			continue
		if g.kind == "head":
			continue
		if g.kind != "seat":
			var best := -1
			var bd := 1e9
			for i in TABLES.size():
				var d := U.hyp(float(TABLES[i][0]) - g.x, float(TABLES[i][1]) - g.z)
				if d < bd:
					bd = d
					best = i
			if bd < 4.5 and _rnd() < 0.6:
				g.dive = true
				g.table = best
			elif g.x < -10.0:
				g.exit_ = [-6.0, -27.0]
			elif g.x > 10.0:
				g.exit_ = [6.0, -27.0]
			else:
				g.exit_ = [-2.0 if g.x < 0.0 else 2.0, -27.0]


## back to before the toast (a checkpoint from earlier)
func reset() -> void:
	scattered = false
	_idle = false
	deck = []
	for g: Guest in guests:
		g.panic = -1.0
		g.gone = false
		g.dive = false
		g.x = g.hx
		g.z = g.hz
		g.yaw = g.hyaw
		g.head_yaw = 0.0
		g.exit_ = null
		if g.kind == "line":
			g.spoke = false
		if g.kind == "stand":
			g.table = -1


func all_gone() -> void:
	for g: Guest in guests:
		g.gone = true
