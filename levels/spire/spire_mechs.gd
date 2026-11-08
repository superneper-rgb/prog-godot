class_name SpireMechs
extends RefCounted
## MEAT SPIRE: living, moving geometry (JS levels/spire/mechs.js). Every moving thing is a mover: a few Solids plus exported nodes, both driven by the same function of time, so what you see is what you stand on. The glue here does what the Player does not know about:
##   carry: whoever stands on a moving solid is carried with it (translation and rotation, ramps included), unless that would push him into a wall
##   hang: a ledge-grab on a moving solid follows it; if the hold retracts under the hands, he drops
##   push-out: a solid that closes on somebody shoves him out sideways; one that rises under his feet scoops him up; if there is nowhere to go he is crushed
##   forces: updrafts, wind and pools (bile) act on the player inside a volume
## Movers are built from the numbers the JS kept for them (level.json data.movers[i].spec), in the same order, because the JS layout comes from a seeded random sequence that mesh building also draws on. The solids are added here; the export's copies (id 'mech') are skipped.

const PR := 0.36      # player radius (CONFIG.radius)
const PH := 1.8


static func sstep(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## the heartbeat: a lub-dub every `per` seconds, 0..1
static func beat_at(t: float, per: float = 1.15) -> float:
	var m := fposmod(t, per)
	return minf(1.0, exp(-pow(m - 0.06, 2.0) / 0.0035) + 0.6 * exp(-pow(m - 0.3, 2.0) / 0.004))


## the breath: -1 (inhaled, sunk) .. 1 (exhaled, swollen), period `per`
static func breath_at(t: float, per: float = 6.0) -> float:
	return sin(t * TAU / per)


## 0 -> 1 -> 0 with waits at both ends
static func pingpong(t: float, wait: float, travel: float, off: float = 0.0) -> float:
	var m := fposmod(t + off, 2.0 * (wait + travel))
	if m < wait:
		return 0.0
	if m < wait + travel:
		return sstep((m - wait) / travel)
	if m < 2.0 * wait + travel:
		return 1.0
	return 1.0 - sstep((m - 2.0 * wait - travel) / travel)


## openness 0..1 of a valve: closed c s, opening r s, open o s, closing r s, and the warning (0..1) in the last warn s before it opens
static func valve(t: float, c: float, o: float, r: float = 0.35, off: float = 0.0, warn: float = 0.7) -> Vector2:
	var m := fposmod(t + off, c + o + 2.0 * r)
	if m < c:
		return Vector2(0.0, (m - (c - warn)) / warn if m > c - warn else 0.0)
	if m < c + r:
		return Vector2(sstep((m - c) / r), 1.0)
	if m < c + r + o:
		return Vector2(1.0, 0.0)
	return Vector2(1.0 - sstep((m - c - r - o) / r), 0.0)


class Mover:
	var kind := ""
	var y0 := -1e9
	var y1 := 1e9
	var solids: Array[World.Solid] = []
	var active := true
	var always := false
	var bounce := false
	var o: Dictionary = {}
	var M: SpireMechs
	var idx := 0
	func step(_t: float, _dt: float, _P: Player) -> void:
		pass
	func bounce_hit(_P: Player) -> void:
		pass
	func node(part: String) -> Node3D:
		return M.node_of(idx, part)
	func f(k: String, d: float = 0.0) -> float:
		return float(o.get(k, d))


## a mover whose step is the level's own (JS mechs.custom)
class Custom extends Mover:
	var fn := Callable()
	func step(t: float, dt: float, P: Player) -> void:
		fn.call(t, dt, P)


## BREATHING LEDGE: a pad that rises and falls with the spire's breath (and dips on every heartbeat when beat > 0)
class Breather extends Mover:
	var s: World.Solid
	var g: Node3D
	var body: Node3D
	var th := 1.0
	var per := 6.0
	var amp := 0.55
	var beat := 0.0
	func setup() -> void:
		th = f("th", 1.0)
		per = f("per", 6.0)
		amp = f("amp", 0.55)
		beat = f("beat", 0.0)
		s = M.add({"kind": "disc", "cx": o.x, "cz": o.z, "r": o.r, "top": o.y, "bottom": float(o.y) - th, "tag": "breath"})
		solids = [s]
		g = node("g")
		body = node("body")
		y0 = float(o.y) - 3.0
		y1 = float(o.y) + 3.0
	func top_fn(t: float) -> float:
		return float(o.y) + amp * SpireMechs.breath_at(t + f("phase"), per) - beat * SpireMechs.beat_at(t, f("beatPer", 1.15))
	func step(t: float, _dt: float, _P: Player) -> void:
		var y := top_fn(t)
		s.set_span(y - th, y)
		g.position.y = y
		var b := SpireMechs.beat_at(t, f("beatPer", 1.15)) if beat != 0.0 else 0.0
		body.scale = Vector3(1.0 + 0.02 * b, 1.0 + 0.04 * b, 1.0 + 0.02 * b)
		if beat != 0.0:
			g.position.x = float(o.x) + sin(t * 61.0) * 0.03 * b


## TENDRIL PLATFORM: a pad on a writhing tendril; rests near p0 and p1 (waits), swings between on a curved path with a Lissajous wobble mid-flight
class TendrilPad extends Mover:
	const N := 8
	var s: World.Solid
	var g: Node3D
	var segs: Array[Node3D] = []
	var knots: Array[Node3D] = []
	var arm: Array[World.Solid] = []
	var ax := 0.0
	var ay := 0.0
	var az := 0.0
	var p0: Vector3
	var p1: Vector3
	var c: Vector3
	var wait := 2.0
	var travel := 3.2
	var wob := 0.5
	func setup() -> void:
		var an: Array = o.anchor
		var al0 := U.hyp(an[0], an[2])
		ax = float(an[0]) - float(an[0]) / al0 * 0.9 if al0 > 2.0 else float(an[0])      # the root is sunk into the column so there is no gap where it joins
		ay = an[1]
		az = float(an[2]) - float(an[2]) / al0 * 0.9 if al0 > 2.0 else float(an[2])
		p0 = Vector3(o.p0[0], o.p0[1], o.p0[2])
		p1 = Vector3(o.p1[0], o.p1[1], o.p1[2])
		wait = f("wait", 2.0)
		travel = f("travel", 3.2)
		wob = f("wob", 0.5)
		var bow: Variant = o.get("bow")
		c = (p0 + p1) * 0.5 + (Vector3(bow[0], bow[1], bow[2]) if bow != null else Vector3(0.0, 1.2, 0.0))
		s = M.add({"kind": "disc", "cx": p0.x, "cz": p0.z, "r": o.r, "top": p0.y, "bottom": p0.y - 0.8, "tag": "tendril"})
		g = node("g")
		solids = [s]
		for i in N:
			segs.append(node("seg%d" % i))
			knots.append(node("knot%d" % i))
			var a := M.add({"kind": "disc", "cx": ax, "cz": az, "r": 0.4, "top": ay, "bottom": ay - 0.8, "tag": "tendrilarm", "no_cam": true})      # the arm itself is solid too
			arm.append(a)
			solids.append(a)
		y0 = minf(p0.y, p1.y) - 4.0
		y1 = maxf(p0.y, p1.y) + 4.0
	func pos(t: float) -> Vector3:
		var u := SpireMechs.pingpong(t, wait, travel, f("phase"))
		var w := sin(PI * u)
		var k := 1.0 - u
		return Vector3(k * k * p0.x + 2.0 * k * u * c.x + u * u * p1.x + wob * w * sin(t * 2.3 + ax), k * k * p0.y + 2.0 * k * u * c.y + u * u * p1.y + wob * 0.6 * w * sin(t * 3.1 + az), k * k * p0.z + 2.0 * k * u * c.z + u * u * p1.z + wob * w * cos(t * 1.9 + ax))
	func step(t: float, _dt: float, _P: Player) -> void:
		var p := pos(t)
		s.place(p.x, p.z)
		s.set_span(p.y - 0.8, p.y)
		g.position = p
		g.rotation.y = t * 0.2
		# bezier from anchor (pointing outward) to the pad belly; it sags and writhes
		var bx := p.x
		var by := p.y - 0.9
		var bz := p.z
		var mx := (ax + bx) * 0.5 + sin(t * 1.7 + ax) * 0.6
		var my := minf(ay, by) - 1.5 + sin(t * 2.1) * 0.4
		var mz := (az + bz) * 0.5 + cos(t * 1.3 + az) * 0.6
		var a0 := Vector3(ax, ay, az)
		var prev := a0
		for i in range(1, N + 1):
			var k := float(i) / N
			var q := 1.0 - k
			var n := Vector3(q * q * ax + 2.0 * q * k * mx + k * k * bx, q * q * ay + 2.0 * q * k * my + k * k * by, q * q * az + 2.0 * q * k * mz + k * k * bz)
			var r := lerpf(f("rr", 0.55), 0.28, k) * (1.0 + 0.12 * sin(t * 6.0 - i))
			SpireMechs.place_between(segs[i - 1], prev, n, r)
			knots[i - 1].position = n
			knots[i - 1].scale = Vector3.ONE * (r * 1.05)
			var a := arm[i - 1]
			var rr2 := r * 0.9
			a.r = rr2
			a.place((prev.x + n.x) * 0.5, (prev.z + n.z) * 0.5)
			a.set_span((prev.y + n.y) * 0.5 - rr2, (prev.y + n.y) * 0.5 + rr2 * 0.6)
			a.world._rebuild_shape(a)
			prev = n


## PERISTALSIS: ridges of flesh that ride up a helical track. Each ridge emerges from the wall at the bottom, climbs, runs flat along the top, then sinks back in.
class Peristalsis extends Mover:
	var ridges: Array[Dictionary] = []
	var dense_a := PackedFloat32Array()
	var dense_y := PackedFloat32Array()
	var L := PackedFloat32Array()
	var LEN := 0.0
	var CYC := 0.0
	var EM := 1.6
	var R := 0.0
	var cx := 0.0
	var cz := 0.0
	var hx := 1.25
	var th := 0.7
	func setup() -> void:
		R = o.R
		cx = f("cx")
		cz = f("cz")
		var track: Array = o.track
		for i in track.size() - 1:      # arc length table (polyline, densified)
			for k in 12:
				var u := k / 12.0
				dense_a.append(lerpf(track[i][0], track[i + 1][0], u))
				dense_y.append(lerpf(track[i][1], track[i + 1][1], u))
		dense_a.append(track[track.size() - 1][0])
		dense_y.append(track[track.size() - 1][1])
		L.append(0.0)
		for i in range(1, dense_a.size()):
			L.append(L[i - 1] + U.hyp(R * (dense_a[i] - dense_a[i - 1]), dense_y[i] - dense_y[i - 1]))
		LEN = L[L.size() - 1]
		EM = f("emerge", 1.6)
		CYC = LEN + 2.0 * EM + f("hidden")
		var n := maxi(1, roundi(CYC / float(o.spacing)))
		var hz := f("len", 1.2)
		hx = f("w", 1.25)
		th = f("th", 0.7)
		for i in n:
			var s := M.add({"kind": "box", "cx": cx, "cz": cz, "hx": hx, "hz": hz, "yaw": 0.0, "top": 0.0, "bottom": -th, "tag": "ridge"})
			solids.append(s)
			ridges.append({"s": s, "g": node("g%d" % i), "body": node("body%d" % i), "off": i * CYC / n})
		y0 = float(track[0][1]) - 3.0
		y1 = float(track[track.size() - 1][1]) + 3.0
	func at(d: float) -> Vector2:
		d = clampf(d, 0.0, LEN)
		var i := 1
		while i < L.size() - 1 and L[i] < d:
			i += 1
		var span := L[i] - L[i - 1]
		var k := (d - L[i - 1]) / (span if span != 0.0 else 1.0)
		return Vector2(lerpf(dense_a[i - 1], dense_a[i], k), lerpf(dense_y[i - 1], dense_y[i], k))
	func step(t: float, _dt: float, _P: Player) -> void:
		var speed: float = o.speed
		for rd: Dictionary in ridges:
			var d := fposmod(t * speed + float(rd.off), CYC) - EM      # -EM..LEN+EM(+hidden)
			var emerge := 1.0
			var dd := d
			if d < 0.0:
				emerge = 1.0 + d / EM
				dd = 0.0
			elif d > LEN:
				emerge = maxf(0.0, 1.0 - (d - LEN) / EM)
				dd = LEN
			var p := at(dd)
			var a2 := at(minf(LEN, dd + 0.5))
			var tang := atan2(sin(a2.x) - sin(p.x), cos(a2.x) - cos(p.x))
			var rr := R - (1.0 - emerge) * (hx * 2.0 + 0.6)
			var x := cx + sin(p.x) * rr
			var z := cz + cos(p.x) * rr
			var y := p.y - (1.0 - emerge) * 0.5
			var s: World.Solid = rd.s
			s.place(x, z, tang)
			s.set_span(y - th, y)
			s.set_off(emerge < 0.15)
			var g: Node3D = rd.g
			g.position = Vector3(x, y, z)
			g.rotation.y = tang
			g.visible = emerge > 0.02
			(rd.body as Node3D).scale.y = 1.0 + 0.08 * sin(t * 5.0 + float(rd.off))


## SPHINCTER / IRIS: petals (boxes) that slide apart to open a hole and meet to close it. Closed it is a floor; open, a gap.
class Iris extends Mover:
	var petals: Array[Dictionary] = []
	var lip: Node3D
	var u := 0.0
	var warn := 0.0
	var gate := true      # (the heart's valves stay shut-off, no collider, until the split)
	var hz0 := 0.0
	func setup() -> void:
		var K := int(o.get("k", 6))
		var th := f("th", 0.7)
		hz0 = o.hz
		for i in K:
			var a := i * TAU / K + f("rot")
			var s := M.add({"kind": "box", "cx": o.x, "cz": o.z, "hx": o.hx, "hz": o.hz, "yaw": a, "top": o.y, "bottom": float(o.y) - th, "tag": "iris"})
			solids.append(s)
			petals.append({"a": a, "s": s, "g": node("g%d" % i), "m": node("m%d" % i)})
		lip = node("lip")
		y0 = float(o.y) - 3.0
		y1 = float(o.y) + 3.0
	func step(t: float, _dt: float, _P: Player) -> void:
		var st := SpireMechs.valve(t, f("closed", 2.4), f("open", 1.6), f("ramp", 0.35), f("phase"), f("warn", 0.7))
		var quiver := sin(t * 40.0) * 0.05 * st.y if st.y > 0.0 else 0.0
		# shrink: the petals pull back into the rim (outer edge fixed) instead of sliding outwards: never sweeps over neighbours
		var shrink: bool = o.get("shrink", false)
		var hz_u := lerpf(hz0, f("hzOpen", 0.28), st.x) if shrink else hz0
		var d := float(o.dIn) + hz0 - hz_u if shrink else lerpf(o.dIn, o.dOut, st.x)
		for p: Dictionary in petals:
			var a: float = p.a
			var cx := float(o.x) + sin(a) * d
			var cz := float(o.z) + cos(a) * d
			var s: World.Solid = p.s
			if shrink:
				(p.m as Node3D).scale.z = hz_u / hz0
				s.place(cx, cz, NAN, NAN, hz_u)
			else:
				s.place(cx, cz)
			(p.g as Node3D).position = Vector3(cx + sin(a) * quiver, float(o.y) + quiver * 0.5, cz + cos(a) * quiver)
			s.set_off((bool(o.get("offWhenOpen", false)) and st.x > 0.98) or not gate)
		lip.scale = Vector3.ONE * (1.0 + 0.05 * st.x + 0.03 * st.y * sin(t * 30.0))
		u = st.x
		warn = st.y


## SLIDER: a box that moves between two poses (eyelid doors, arena lock walls, retracting lids). target(t) -> 0..1 (or set want and it eases at rate)
class SliderM extends Mover:
	var s: World.Solid
	var g: Node3D
	var body: Node3D
	var u := 0.0
	var want := 0.0
	var rate := 1.5
	var target := Callable()
	var vis := Callable()
	var h := 1.0
	func setup() -> void:
		h = o.h
		s = M.add({"kind": "box", "cx": o.a.x, "cz": o.a.z, "hx": o.hx, "hz": o.hz, "yaw": f("yaw"), "top": o.a.top, "bottom": float(o.a.top) - h, "tag": o.get("tag", "slider")})
		s.data["crush"] = f("crush", 12.0)
		solids = [s]
		g = node("g")
		g.rotation.y = f("yaw")
		body = node("body")
		body.rotation_order = EULER_ORDER_XYZ
		u = f("u0")
		want = u
		rate = f("rate", 1.5)
		y0 = minf(o.a.top, o.b.top) - h - 3.0
		y1 = maxf(o.a.top, o.b.top) + 3.0
	func step(t: float, dt: float, _P: Player) -> void:
		if target.is_valid():
			u = target.call(t)
		else:
			u += clampf(want - u, -rate * dt, rate * dt)
		var e := u if o.get("ease", true) == false else SpireMechs.sstep(u)
		var x := lerpf(o.a.x, o.b.x, e)
		var z := lerpf(o.a.z, o.b.z, e)
		var top := lerpf(o.a.top, o.b.top, e)
		s.place(x, z)
		s.set_span(top - h, top)
		s.set_off((o.has("offAt") and e >= float(o.offAt)) or (o.has("offBelow") and e <= float(o.offBelow)))
		g.position = Vector3(x, top, z)
		g.visible = (not o.has("hideAt") or e < float(o.hideAt)) and (not o.has("showAbove") or e > float(o.showAbove))
		if vis.is_valid():
			vis.call(self, t)


## TEETH: a row of lower teeth (stand on them) under upper teeth that chomp down in a travelling wave. A chomp shoves you off the tooth and hurts.
class Teeth extends Mover:
	var teeth: Array[Dictionary] = []
	var per := 4.2
	var gap := 0.55
	var open := 3.8
	func setup() -> void:
		var pts: Array = o.pts
		per = f("per", 4.2)
		gap = f("gap", 0.55)
		open = f("open", 3.8)
		var r: float = o.r
		var dmg := f("dmg", 16.0)
		y0 = 1e9
		y1 = -1e9
		for i in pts.size():
			var x: float = pts[i][0]
			var z: float = pts[i][1]
			var top: float = pts[i][2]
			y0 = minf(y0, top - 3.0)
			y1 = maxf(y1, top + 6.0)
			var low := M.add({"kind": "disc", "cx": x, "cz": z, "r": r, "top": top, "bottom": top - 2.6, "tag": "tooth"})
			var up := M.add({"kind": "disc", "cx": x, "cz": z, "r": r * 0.95, "top": top + 6.0, "bottom": top + 3.0, "tag": "fang", "no_cam": true})      # noCam: a chomping fang shoves you, it never slams the camera into your head
			up.data["crush"] = dmg
			var l := U.hyp(x, z)
			up.data["push_dir"] = [x / l, z / l]
			up.data["hazard"] = func(P: Player) -> void:
				M.hurt(P, dmg, x, z, "melee")
				M.push({"t": &"tongueLash", "x": x, "y": top + 1.0, "z": z, "hit": true})
			solids.append(up)
			teeth.append({"x": x, "z": z, "top": top, "up": up, "um": node("um%d" % i), "i": i, "low": low})
	func bite(t: float, i: int) -> float:      # 0 = open, 1 = shut; a 0.6 s raise (the tell) before every chomp
		var m := fposmod(t - i * gap + f("phase"), per)
		if m < 0.6:
			return -0.25 * SpireMechs.sstep(m / 0.6)      # rears up
		if m < 0.75:
			return -0.25 + 1.25 * SpireMechs.sstep((m - 0.6) / 0.15)      # CHOMP
		if m < 1.35:
			return 1.0      # held shut
		if m < 2.0:
			return 1.0 - SpireMechs.sstep((m - 1.35) / 0.65)
		return 0.0
	func step(t: float, _dt: float, _P: Player) -> void:
		for q: Dictionary in teeth:
			var i: int = q.i
			var b := bite(t, i)
			var bot := float(q.top) + 0.05 + open * (1.0 - b)
			(q.up as World.Solid).set_span(bot, bot + 3.2)
			# visual only (the collider above is authoritative): it trembles while it rears, then the chomp overshoots and squashes on impact
			var m := fposmod(t - i * gap + f("phase"), per)
			var rear := SpireMechs.sstep(m / 0.6) if m < 0.6 else 0.0
			var hit := sin((m - 0.75) / 0.3 * PI) if (m > 0.75 and m < 1.05) else 0.0
			var um: Node3D = q.um
			um.position = Vector3(float(q.x) + sin(t * 43.0 + i) * 0.05 * rear, bot + 1.7 - 0.12 * hit, float(q.z) + cos(t * 37.0 + i) * 0.05 * rear)
			um.scale = Vector3(1.0 + 0.08 * hit, 1.0 - 0.1 * hit, 1.0 + 0.08 * hit)


## PUSTULE: a bulbous pad. Stand on it and it swells (0.9 s), bursts (you drop), and regrows a few seconds later.
class Pustule extends Mover:
	var s: World.Solid
	var sac: Node3D
	var state := "grown"
	var st := 0.0
	var RS := 1.0
	func setup() -> void:
		s = M.add({"kind": "disc", "cx": o.x, "cz": o.z, "r": o.r, "top": o.y, "bottom": float(o.y) - 1.2, "tag": "pustule"})
		solids = [s]
		sac = node("sac")
		RS = float(o.r) * 1.05
		y0 = float(o.y) - 4.0
		y1 = float(o.y) + 4.0
	func scale_sac(sx: float, sy: float) -> void:
		sac.scale = Vector3(sx, sy * 0.5, sx)
		sac.position.y = -RS * sy * 0.5
	func step(t: float, dt: float, P: Player) -> void:
		st += dt
		var ox: float = o.x
		var oy: float = o.y
		var oz: float = o.z
		var on_it: bool = P != null and not P.dead and P.mode == &"normal" and absf(P.y - s.top) < 0.15 and s.top_at(P.x, P.z) != null
		if state == "grown":
			scale_sac(1.0, 1.0 + 0.04 * sin(t * 3.0 + ox))
			if on_it:
				state = "swell"
				st = 0.0
				M.sfx_at("meatSwell", ox, oy, oz, {"range": 30.0})
		elif state == "swell":
			var k := st / f("fuse", 0.9)
			var throb := pow(maxf(0.0, sin(st * (9.0 + 30.0 * k))), 3.0) * 0.08 * (0.4 + k)      # throbs faster and harder until it pops
			scale_sac(1.0 + 0.25 * k + throb + sin(t * 50.0) * 0.04 * k, 1.0 + 0.35 * k + throb * 1.4)
			if k >= 1.0:
				state = "gone"
				st = 0.0
				s.set_off(true)
				sac.visible = false
				M.push({"t": &"meatBoom", "id": -1, "x": ox, "y": oy + 0.2, "z": oz, "r": 1.0, "big": false})
		elif state == "gone":
			if st > f("regrow", 3.6):
				state = "regrow"
				st = 0.0
				sac.visible = true
		elif state == "regrow":
			var k := minf(1.0, st / 1.0)
			var el := 1.0 if k >= 1.0 else pow(2.0, -10.0 * k) * sin((k * 10.0 - 0.75) * 2.0944) + 1.0      # regrows with an elastic wobble
			scale_sac(maxf(0.05, el), maxf(0.05, el))
			var inside: bool = P != null and not P.dead and U.hyp(P.x - ox, P.z - oz) < float(o.r) + PR and P.y < oy + 0.1 and P.y + PH > oy - 1.2
			if k >= 1.0 and not inside:
				state = "grown"
				st = 0.0
				s.set_off(false)
				scale_sac(1.0, 1.0)


## COLLAPSER: frayed planks / rotten caps that give way. Stand on one for grace s and it shudders (the tell, warn s, with a creak) and drops away; with chain > 0 the neighbours start to shudder chain s after it (a domino). A dropped piece regrows after regrow s once nobody is inside it.
class Collapser extends Mover:
	var items: Array[Dictionary] = []
	var warn := 0.6
	var grace := 0.2
	var regrow := 4.5
	var chain := 0.0
	var th := 0.5
	func setup() -> void:
		th = f("th", 0.5)
		warn = f("warn", 0.6)
		grace = f("grace", 0.2)
		regrow = f("regrow", 4.5)
		chain = f("chain")
		var pieces: Array = o.pieces
		y0 = 1e9
		y1 = -1e9
		for i in pieces.size():
			var p: Dictionary = pieces[i]
			y0 = minf(y0, float(p.y) - 6.0)
			y1 = maxf(y1, float(p.y) + 4.0)
			var s: World.Solid
			if p.has("r"):
				s = M.add({"kind": "disc", "cx": p.x, "cz": p.z, "r": p.r, "top": p.y, "bottom": float(p.y) - th, "tag": "crumble"})
			else:
				s = M.add({"kind": "box", "cx": p.x, "cz": p.z, "hx": p.hx, "hz": p.hz, "yaw": float(p.get("yaw", 0.0)), "top": p.y, "bottom": float(p.y) - th, "tag": "crumble"})
			solids.append(s)
			var g := node("g%d" % i)
			g.rotation_order = EULER_ORDER_XYZ
			items.append({"p": p, "s": s, "g": g, "i": i, "state": "solid", "st": 0.0, "on": 0.0, "trig": false, "trig_at": -1.0, "vy": 0.0, "spin": (1.0 if i % 2 != 0 else -1.0) * (0.4 + 0.3 * (i % 3))})
	func step(t: float, dt: float, P: Player) -> void:
		for q: Dictionary in items:
			var s: World.Solid = q.s
			var p: Dictionary = q.p
			var g: Node3D = q.g
			var i: int = q.i
			var px: float = p.x
			var py: float = p.y
			var pz: float = p.z
			q.st = float(q.st) + dt
			var qst: float = q.st
			if q.state == "solid":
				var standing: bool = P != null and not P.dead and P.mode == &"normal" and (P.grounded or P.vy <= 0.01) and absf(P.y - s.top) < 0.16 and s.top_at(P.x, P.z) != null
				q.on = float(q.on) + dt if standing else maxf(0.0, float(q.on) - dt * 0.5)
				if float(q.on) >= grace or q.trig:
					q.state = "shake"
					q.st = 0.0
					M.sfx_at("meatSwell", px, py, pz, {"range": 26.0})
					if chain > 0.0:
						for j: int in [i - 1, i + 1]:
							if j >= 0 and j < items.size() and items[j].state == "solid":
								items[j]["trig_at"] = t + chain
				elif float(q.trig_at) >= 0.0 and t >= float(q.trig_at):
					q.trig_at = -1.0
					q.trig = true
				g.position = Vector3(px, py, pz)
				g.scale = Vector3.ONE
			elif q.state == "shake":
				var k := qst / warn
				g.position = Vector3(px + sin(t * 53.0 + i) * 0.04 * k, py - 0.06 * k, pz + cos(t * 47.0 + i) * 0.04 * k)
				g.scale = Vector3(1.0 + 0.04 * sin(t * 40.0), 1.0, 1.0 + 0.04 * sin(t * 36.0))
				if k >= 1.0:
					q.state = "fall"
					q.st = 0.0
					q.vy = 0.0
					s.set_off(true)
					q.trig = false
					q.on = 0.0
					M.push({"t": &"meatBoom", "id": -1, "x": px, "y": py, "z": pz, "r": 0.7, "big": false})
			elif q.state == "fall":
				q.vy = float(q.vy) - 22.0 * dt
				g.position.y += float(q.vy) * dt
				g.rotation.x += float(q.spin) * dt
				g.rotation.z += float(q.spin) * 0.5 * dt
				if qst > 1.4:
					q.state = "gone"
					q.st = 0.0
					g.visible = false
			elif q.state == "gone":
				if qst > regrow:
					q.state = "regrow"
					q.st = 0.0
					g.visible = true
					g.rotation = Vector3(0.0, float(p.get("yaw", 0.0)), 0.0)
			elif q.state == "regrow":
				var k := minf(1.0, qst / 1.0)
				g.position = Vector3(px, py - (1.0 - k) * 0.8, pz)
				g.scale = Vector3.ONE * maxf(0.05, k)
				var inside := false
				if P != null and not P.dead and P.y < py + 0.1 and P.y + PH > py - th:
					inside = M.foot_overlap(s, P.x, P.z, PR, true)
				if k >= 1.0 and not inside:
					q.state = "solid"
					q.st = 0.0
					s.set_off(false)
					g.scale = Vector3.ONE
					g.position = Vector3(px, py, pz)


## RIB WHEEL / VERTEBRA RING: K boxes on a pivot spinning about a vertical axis: radial ribs (spokes) or tangential plates (a ring).
class WheelM extends Mover:
	var ribs: Array[Dictionary] = []
	var th := 0.55
	var ring := false
	func setup() -> void:
		var K := int(o.get("k", 5))
		th = f("th", 0.55)
		ring = o.get("ring", false)
		for i in K:
			var s := M.add({"kind": "box", "cx": o.x, "cz": o.z, "hx": float(o.len) * 0.5 if ring else float(o.w) * 0.5, "hz": float(o.w) * 0.5 if ring else float(o.len) * 0.5, "yaw": 0.0, "top": o.y, "bottom": float(o.y) - th, "tag": "rib"})
			solids.append(s)
			ribs.append({"s": s, "g": node("g%d" % i), "a0": i * TAU / K})
		y0 = float(o.y) - 4.0
		y1 = float(o.y) + 4.0
	func step(t: float, _dt: float, _P: Player) -> void:
		var ang := f("phase") + f("omega", 0.4) * t
		for i in ribs.size():
			var r: Dictionary = ribs[i]
			var a := ang + float(r.a0)
			var d: float = o.rIn if ring else float(o.rIn) + float(o.len) * 0.5
			var x := float(o.x) + sin(a) * d
			var z := float(o.z) + cos(a) * d
			var y := float(o.y) + (f("bob") * sin(t * 1.3 + i * 1.7) if o.has("bob") else 0.0)
			var s: World.Solid = r.s
			s.place(x, z, a)
			s.set_span(y - th, y)
			var g: Node3D = r.g
			g.position = Vector3(x, y, z)
			g.rotation.y = a


## HANDHOLDS: shelves that extend from a cylindrical wall and retract into it on a cascade timer (ledge-grab climb).
class Handholds extends Mover:
	var list: Array[Dictionary] = []
	var D := 1.6
	var sgn := 1.0
	var cyc := 0.0
	func setup() -> void:
		D = f("depth", 1.6)
		var W := f("w", 1.9)
		var th := 0.6
		sgn = -1.0 if o.get("inward", false) else 1.0
		var holds: Array = o.holds
		y0 = 1e9
		y1 = -1e9
		for i in holds.size():
			var a: float = holds[i][0]
			var top: float = holds[i][1]
			y0 = minf(y0, top - 4.0)
			y1 = maxf(y1, top + 4.0)
			var s := M.add({"kind": "box", "cx": 0.0, "cz": 0.0, "hx": W * 0.5, "hz": D * 0.5, "yaw": a, "top": top, "bottom": top - th, "tag": "hold"})
			solids.append(s)
			var g := node("g%d" % i)
			g.rotation.y = a
			list.append({"a": a, "top": top, "s": s, "g": g, "i": i, "knob": node("knob%d" % i), "R": float(holds[i][2]) if (holds[i] as Array).size() > 2 else float(o.R)})
		cyc = f("out", 3.6) + f("gone", 1.4) + 0.6
	func ext(t: float, i: int) -> Vector2:
		var m := fposmod(t - i * f("stagger", 0.9) + f("phase"), cyc)
		var O := f("out", 3.6)
		if m < O:
			return Vector2(1.0, (m - O + 0.6) / 0.6 if m > O - 0.6 else 0.0)
		if m < O + 0.3:
			return Vector2(1.0 - SpireMechs.sstep((m - O) / 0.3), 1.0)
		if m < cyc - 0.3:
			return Vector2.ZERO
		return Vector2(SpireMechs.sstep((m - cyc + 0.3) / 0.3), 0.0)
	func step(t: float, _dt: float, _P: Player) -> void:
		for h: Dictionary in list:
			var e := Vector2(1.0, 0.0) if o.get("always", false) else ext(t, h.i)
			var r := float(h.R) + sgn * (D * 0.5 - (1.0 - e.x) * (D + 0.2))
			var sh := sin(t * 45.0) * 0.04 * e.y if e.y != 0.0 else 0.0
			var s: World.Solid = h.s
			var a: float = h.a
			s.place(f("cx") + sin(a) * r, f("cz") + cos(a) * r)
			s.set_off(e.x < 0.25)
			var g: Node3D = h.g
			g.position = Vector3(s.cx + sh, float(h.top), s.cz)
			g.visible = e.x > 0.02
			(h.knob as Node3D).scale = Vector3.ONE * (1.0 + 0.6 * e.y)


## PARASITE CARRIER: the creature's offspring, a stepped many-legged tick that crawls along the spire carrying whoever stands on it: shuttle, elevator (straight up/down a wall), loop (round the spire, stopping at stations), tilt (through three stops, its back tilting as it goes: a ramp collider).
class Parasite extends Mover:
	const TH := 0.8
	var s: World.Solid
	var g: Node3D
	var body: Node3D
	var head: Node3D
	var legs: Array[Dictionary] = []
	var route: Array[Dictionary] = []
	var st: Array = []
	var cyc := 0.0
	var tilt := false
	var hl := 1.7
	var loop := false
	func setup() -> void:
		st = o.stops
		var hw := f("hw", 1.5)
		hl = f("hl", 1.7)
		tilt = o.get("variant") == "tilt"
		loop = o.get("variant") == "loop"
		var s0: Dictionary = st[0]
		if tilt:
			s = M.add({"kind": "ramp", "cx": s0.x, "cz": s0.z, "hx": hw, "hz": hl, "yaw": 0.0, "top": s0.y, "top_low": s0.y, "bottom": float(s0.y) - TH, "tag": "parasite"})
		else:
			s = M.add({"kind": "box", "cx": s0.x, "cz": s0.z, "hx": hw, "hz": hl, "yaw": 0.0, "top": s0.y, "bottom": float(s0.y) - TH, "tag": "parasite"})
		solids = [s]
		g = node("g")
		body = node("body")
		head = node("head")
		for i in 8:
			var pv := node("leg%d" % i)
			pv.rotation_order = EULER_ORDER_XYZ
			var row := i / 2
			var sx := -1.0 if i % 2 == 0 else 1.0
			legs.append({"pv": pv, "sx": sx, "ph": row * 1.3 + (0.0 if sx > 0.0 else PI)})
		# the path: stops 0..N-1. shuttle / elevator / tilt ping-pong 0 -> N-1 -> 0; loop goes 0 -> 1 -> ... -> N-1 -> 0. Every stop may carry its own wait (0 = a waypoint it crawls through) and the travel time of the leg that leaves it.
		var N := st.size()
		var wait := f("wait", 2.4)
		var travel := f("travel", 5.0)
		var order: Array = []
		if loop:
			for i in N:
				order.append([i, (i + 1) % N])
		else:
			for i in N - 1:
				order.append([i, i + 1])
			for i in range(N - 1, 0, -1):
				order.append([i, i - 1])
		y0 = 1e9
		y1 = -1e9
		for q: Dictionary in st:
			y0 = minf(y0, float(q.y) - 4.0)
			y1 = maxf(y1, float(q.y) + 4.0)
		for e: Array in order:
			var a: Dictionary = st[e[0]]
			var w := float(a.get("wait", wait))
			var tr := float(a.get("travel", travel))
			route.append({"i0": e[0], "i1": e[1], "w": w, "tr": tr})
			cyc += w + tr
	func step(t: float, _dt: float, _P: Player) -> void:
		var m := fposmod(t + f("phase"), cyc)
		var L: Dictionary = route[0]
		for l: Dictionary in route:
			var d := float(l.w) + float(l.tr)
			if m < d:
				L = l
				break
			m -= d
		var w: float = L.w
		var tr: float = L.tr
		var smooth := w > 0.0 or not loop
		var u := 0.0 if m < w else (SpireMechs.sstep((m - w) / tr) if smooth else (m - w) / tr)
		var A: Dictionary = st[L.i0]
		var B: Dictionary = st[L.i1]
		var tl := lerpf(float(A.get("tilt", 0.0)), float(B.get("tilt", 0.0)), u)
		var x: float
		var z: float
		var y: float
		var yaw: float
		if loop:      # round its centre: interpolate angle (always the forward way) and radius
			var a0: float = A.a
			var a1: float = B.a
			var dir := f("dir", 1.0)
			if dir > 0.0:
				while a1 <= a0:
					a1 += TAU
			else:
				while a1 >= a0:
					a1 -= TAU
			var a := lerpf(a0, a1, u)
			var R := lerpf(A.R, B.R, u)
			x = f("cx") + sin(a) * R
			z = f("cz") + cos(a) * R
			y = lerpf(A.y, B.y, u)
			yaw = a + dir * PI * 0.5
		else:
			x = lerpf(A.x, B.x, u)
			z = lerpf(A.z, B.z, u)
			y = lerpf(A.y, B.y, u)
			var ay := float(A.get("yaw", 0.0))
			var dy := float(B.get("yaw", 0.0)) - ay
			dy = atan2(sin(dy), cos(dy))
			yaw = ay + dy * u
		s.place(x, z, yaw)
		if tilt:
			s.set_span(y - absf(tl) * 0.5 - TH, y + tl * 0.5, y - tl * 0.5)
		else:
			s.set_span(y - TH, y)
		g.position = Vector3(x, y, z)
		g.rotation.y = yaw
		body.rotation.x = -atan2(tl, hl * 2.0) if tilt else 0.0
		var sp := 1.0 if m >= w else 0.12
		for l: Dictionary in legs:
			var ph: float = l.ph
			var pv: Node3D = l.pv
			pv.rotation.x = sin(t * 9.0 + ph) * 0.55 * sp
			pv.rotation.z = float(l.sx) * (0.5 + 0.12 * sin(t * 4.0 + ph))
		head.rotation.x = sin(t * 2.0 + float(st[0].get("x", 0.0))) * 0.08


## CATCH-NET: a membrane that throws you back up when you land on it hard.
class Trampoline extends Mover:
	var s: World.Solid
	var m: Node3D
	var dip := 0.0
	func setup() -> void:
		var d := {"kind": "disc", "cx": o.x, "cz": o.z, "r": o.r, "top": o.y, "bottom": float(o.y) - 0.4, "tag": "net"}
		if o.has("holes"):
			d["holes"] = o.holes
		s = M.add(d)
		solids = [s]
		m = node("m")
		bounce = true
		y0 = float(o.y) - 3.0
		y1 = float(o.y) + 3.0
	func bounce_hit(P: Player) -> void:
		P.vy = clampf(P.land_impact * 0.75 + 5.0, f("min", 11.0), f("max", 16.5))
		P.grounded = false
		P.air_jump = true
		P.jumping = false
		P.land_t = 0.0
		P.y += 0.03
		P.coyote_t = 0.0
		dip = 1.0
		M.push({"t": &"summon", "x": P.x, "y": P.y + 0.1, "z": P.z})
		M.sfx_at("slap", P.x, P.y, P.z, {"range": 40.0, "k": 1.0})
	func step(_t: float, dt: float, _P: Player) -> void:
		dip = maxf(0.0, dip - dt * 2.5)
		m.position.y = float(o.y) + 0.02 - 0.35 * dip * sin((1.0 - dip) * 9.0)


## TRUNK: a tall column section that can slide radially (the spire splits). Children solids are carried with it.
class Trunk extends Mover:
	var s: World.Solid
	var g: Node3D
	var u := 0.0
	var want := 0.0
	var kids: Array[Dictionary] = []
	func setup() -> void:
		var a: float = o.a
		s = M.add({"kind": "disc", "cx": sin(a) * float(o.dIn), "cz": cos(a) * float(o.dIn), "r": o.r, "top": o.y1, "bottom": o.y0, "tag": "trunk", "no_cam": true})
		solids = [s]
		g = node("g")
		always = true
		y0 = float(o.y0) - 3.0
		y1 = float(o.y1) + 3.0
	## attach a solid (+ its group) at an offset in the trunk's frame: along = outward from the axis, side = tangential
	func attach(sol: World.Solid, grp: Node3D, along: float, side: float) -> void:
		kids.append({"sol": sol, "grp": grp, "along": along, "side": side})
		solids.append(sol)
	func step(t: float, dt: float, _P: Player) -> void:
		var dur := f("dur", 5.0)
		u += clampf(want - u, -dt / dur, dt / dur)
		var k := SpireMechs.sstep(u)
		var d := lerpf(o.dIn, o.dOut, k)
		var shake := sin(t * 37.0) * 0.06 if (u > 0.0 and u < 1.0) else 0.0
		var a: float = o.a
		var ux := sin(a)
		var uz := cos(a)
		var cx := ux * d
		var cz := uz * d
		s.place(cx, cz)
		g.position = Vector3(cx + shake, float(o.y0), cz)
		var tx := uz
		var tz := -ux
		for q: Dictionary in kids:
			var sol: World.Solid = q.sol
			sol.place(cx + ux * float(q.along) + tx * float(q.side), cz + uz * float(q.along) + tz * float(q.side))
			if q.grp != null:
				(q.grp as Node3D).position.x = sol.cx + shake
				(q.grp as Node3D).position.z = sol.cz


var level: ExportedLevel
var world: World
var movers: Array[Mover] = []
var forces: Array[Dictionary] = []
var specs: Array = []
var _sfx := Callable()
var _events := Callable()
var _hurt := Callable()
var _was_air := true
var _tram_t := 0.0
var _crush_cd := 0.0
var _hazard_cd := 0.0
var _dummy: Node3D = null


func _init(p_level: ExportedLevel, p_events: Callable, p_sfx: Callable, p_hurt: Callable) -> void:
	level = p_level
	world = p_level.world
	_events = p_events
	_sfx = p_sfx
	_hurt = p_hurt
	specs = p_level.info.data.get("movers", [])
	for i in specs.size():
		var d: Dictionary = specs[i]
		var m: Mover
		match String(d.get("specKind", "")):
			"breather":
				m = Breather.new()
			"tendrilPad":
				m = TendrilPad.new()
			"peristalsis":
				m = Peristalsis.new()
			"iris":
				m = Iris.new()
			"slider":
				m = SliderM.new()
			"teeth":
				m = Teeth.new()
			"pustule":
				m = Pustule.new()
			"collapser":
				m = Collapser.new()
			"wheel":
				m = WheelM.new()
			"handholds":
				m = Handholds.new()
			"parasite":
				m = Parasite.new()
			"trampoline":
				m = Trampoline.new()
			"trunk":
				m = Trunk.new()
			_:      # the level's own (the lung's alveoli, the boss's): SpireLevel fills in fn and solids
				m = Custom.new()
				m.kind = String(d.get("kind", "custom"))
				m.y0 = float(d.get("y0", -1e9))
				m.y1 = float(d.get("y1", 1e9))
				m.M = self
				m.idx = i
				movers.append(m)
				continue
		m.kind = String(d.get("specKind"))
		m.o = d.spec
		m.M = self
		m.idx = i
		m.call(&"setup")
		movers.append(m)


## a mover the level runs itself, not named in the export's movers (JS mechs.custom)
func add_custom(p_solids: Array, p_always: bool, fn: Callable) -> Custom:
	var m := Custom.new()
	m.kind = "custom"
	for s: World.Solid in p_solids:
		m.solids.append(s)
	m.always = p_always
	m.fn = fn
	m.M = self
	movers.append(m)
	return m


func add(d: Dictionary) -> World.Solid:
	var s: World.Solid = world.add(d)
	return s


func node_of(i: int, part: String) -> Node3D:
	var nm := "Spm%d_%s" % [i, part]
	var a := level.node_named(nm)
	if a.is_empty():
		push_warning("SPIRE: nothing exported as " + nm)
		if _dummy == null:
			_dummy = Node3D.new()
			level.add_child(_dummy)
		return _dummy
	return a[0]


func sfx_at(id: String, x: float, y: float, z: float, o: Dictionary = {}) -> void:
	if _sfx.is_valid():
		_sfx.call(id, x, y, z, o)


func push(e: Dictionary) -> void:
	if _events.is_valid():
		_events.call(e)


func hurt(P: Player, amt: float, sx: float, sz: float, kind: String = "bolt") -> bool:
	return _hurt.is_valid() and bool(_hurt.call(P, amt, sx, sz, kind))


## JS placeBetween: a stretched unit cylinder between two points
static func place_between(m: Node3D, a: Vector3, b: Vector3, r: float) -> void:
	var d := b - a
	var l := d.length()
	if l == 0.0:
		l = 1e-4
	m.position = (a + b) * 0.5
	m.basis = Basis(Quaternion(Vector3.UP, d / l)) * Basis.from_scale(Vector3(r, l, r))


# ---------------------------------------------------------------------------------------------------------------- the glue
func foot_overlap(s: World.Solid, x: float, z: float, rad: float, ignore_off: bool = false) -> bool:
	if s.off and not ignore_off:
		return false
	var dx := x - s.cx
	var dz := z - s.cz
	if s.kind == "disc":
		if U.hyp(dx, dz) >= s.r + rad:
			return false
		for h: Array in s.holes:
			if U.hyp(x - float(h[0]), z - float(h[1])) < float(h[2]) - rad:
				return false
		return true
	var c := cos(s.yaw)
	var sn := sin(s.yaw)
	var lx := dx * c - dz * sn
	var lz := dx * sn + dz * c
	return absf(lx) < s.hx + rad and absf(lz) < s.hz + rad


## minimal sideways move that takes a circle of radius rad out of solid s
func _push_out(s: World.Solid, x: float, z: float, rad: float) -> Vector2:
	var dx := x - s.cx
	var dz := z - s.cz
	if s.kind == "disc":
		var d := U.hyp(dx, dz)
		var ux := dx / (d if d != 0.0 else 1.0)
		var uz := dz / (d if d != 0.0 else 1.0)
		if d < 0.05:
			var pd: Variant = s.data.get("push_dir")
			ux = float(pd[0]) if pd != null else 1.0
			uz = float(pd[1]) if pd != null else 0.0
		var need := s.r + rad + 0.02 - d
		return Vector2(ux * need, uz * need)
	var c := cos(s.yaw)
	var sn := sin(s.yaw)
	var lx := dx * c - dz * sn
	var lz := dx * sn + dz * c
	var ox := s.hx + rad + 0.02 - absf(lx)
	var oz := s.hz + rad + 0.02 - absf(lz)
	var mx := 0.0
	var mz := 0.0
	if oz <= ox:
		mz = (1.0 if lz >= 0.0 else -1.0) * oz
	else:
		mx = (1.0 if lx >= 0.0 else -1.0) * ox
	return Vector2(mx * c + mz * sn, -mx * sn + mz * c)


func _snapshot(s: World.Solid) -> void:
	s.p_cx = s.cx
	s.p_cz = s.cz
	s.p_top = s.top
	s.p_bottom = s.bottom
	s.p_yaw = s.yaw
	s.p_low = s.top_low
	s.p_off = s.off
	s.p_r = s.r
	s.p_hx = s.hx
	s.p_hz = s.hz


func _moved(s: World.Solid) -> bool:
	return s.p_cx != s.cx or s.p_cz != s.cz or s.p_top != s.top or s.p_bottom != s.bottom or s.p_yaw != s.yaw or s.p_low != s.top_low or s.p_off != s.off or s.p_r != s.r or s.p_hx != s.hx or s.p_hz != s.hz


## carry a point from a solid's previous frame to its current frame
func _carry_pt(s: World.Solid, x: float, z: float) -> Vector2:
	var c0 := cos(s.p_yaw)
	var s0 := sin(s.p_yaw)
	var dx := x - s.p_cx
	var dz := z - s.p_cz
	var lx := dx * c0 - dz * s0
	var lz := dx * s0 + dz * c0
	var c := cos(s.yaw)
	var sn := sin(s.yaw)
	return Vector2(s.cx + lx * c + lz * sn, s.cz - lx * sn + lz * c)


func _top_near(s: World.Solid, x: float, z: float) -> Variant:
	var q := PR * 0.55
	var t: Variant = s.top_at(x, z)
	for e: Vector2 in [Vector2(q, 0.0), Vector2(-q, 0.0), Vector2(0.0, q), Vector2(0.0, -q)]:
		var u: Variant = s.top_at(x + e.x, z + e.y)
		if u != null and (t == null or float(u) > float(t)):
			t = u
	return t


## per frame. t = level clock. P may be null (menu).
func update(t: float, dt: float, P: Player) -> void:
	var py := P.y if P != null else 0.0
	var act: Array[Mover] = []
	for m: Mover in movers:
		m.active = P == null or (m.y1 > py - 42.0 and m.y0 < py + 42.0) or m.always
		if m.active:
			act.append(m)
	var alive := P != null and not P.dead
	# ---- 1. what is he standing on / hanging from?
	var sup: World.Solid = null
	var sup_top := -1e9
	var hang: World.Solid = null
	if alive and P.mode == &"normal" and (P.grounded or P.vy <= 0.01):
		for m: Mover in act:
			for s: World.Solid in m.solids:
				if s.off or (s.kind != "ramp" and absf(P.y - s.top) >= 0.14):      # (a disc or box answers its top or nothing: the five probes below cannot change this)
					continue
				var tp: Variant = _top_near(s, P.x, P.z)
				if tp != null and absf(P.y - float(tp)) < 0.14 and float(tp) > sup_top:
					sup = s
					sup_top = tp
	if alive and (P.mode == &"hang" or P.mode == &"pull") and P.ledge != null:
		var L: Player.Ledge = P.ledge
		var hx: float = L.x0 + L.fx * (PR + 0.3)
		var hz: float = L.z0 + L.fz * (PR + 0.3)
		for m: Mover in act:
			for s: World.Solid in m.solids:
				if s.off:
					continue
				var tp: Variant = s.top_at(hx, hz)
				if tp != null and absf(float(tp) - L.t) < 0.12:
					hang = s
					break
			if hang != null:
				break
	for m: Mover in act:
		for s: World.Solid in m.solids:
			_snapshot(s)
	# ---- 2. move everything
	for m: Mover in act:
		m.step(t, dt, P)
	if not alive:
		_was_air = true
		return
	var ph := P.h if P.h != 0.0 else PH
	# ---- 3. carry the rider
	if sup != null and not sup.off:
		var n := _carry_pt(sup, P.x, P.z)
		var nt: Variant = _top_near(sup, n.x, n.y)
		if nt != null:
			if not world.blocked(n.x, n.y, nt, ph, PR, 0.42):
				P.yaw += sup.yaw - sup.p_yaw
				P.x = n.x
				P.z = n.y
				P.y = nt
			else:
				# the carry would push him into a wall (a ring sweeping him along the spire's own flesh): slide him out along the wall instead of leaving him standing still while the platform runs out from under him: the carried point is nudged towards the platform's centre until it is clear
				var ax := sup.cx - n.x
				var az := sup.cz - n.y
				var al := U.hyp(ax, az)
				if al == 0.0:
					al = 1.0
				var done := false
				for k: float in [0.12, 0.25, 0.4, 0.6]:
					var px := n.x + ax / al * k
					var pz := n.y + az / al * k
					var pt: Variant = _top_near(sup, px, pz)
					if pt != null and not world.blocked(px, pz, pt, ph, PR, 0.42):
						P.yaw += sup.yaw - sup.p_yaw
						P.x = px
						P.z = pz
						P.y = pt
						done = true
						break
				if not done:
					var ht: Variant = _top_near(sup, P.x, P.z)
					if ht != null:
						P.y = ht
			if P.vy < 0.0:
				P.vy = 0.0
	if hang != null and P.ledge != null:
		var L: Player.Ledge = P.ledge
		var hx: float = L.x0 + L.fx * (PR + 0.3)
		var hz: float = L.z0 + L.fz * (PR + 0.3)
		var nh := _carry_pt(hang, hx, hz)
		var top: Variant = hang.top_at(nh.x, nh.y)
		if hang.off or top == null:
			P.mode = &"normal"
			P.ledge = null
			P.grounded = false
			P.vy = 0.0
			P.mode_t = 0.0
		else:
			var lp := _carry_pt(hang, L.x0, L.z0)
			var pp := _carry_pt(hang, P.x, P.z)
			var da := hang.yaw - hang.p_yaw
			var c := cos(da)
			var sn := sin(da)
			var fx: float = L.fx
			var fz: float = L.fz
			var dy := float(top) - L.t
			L.x0 = lp.x
			L.z0 = lp.y
			L.fx = fx * c + fz * sn
			L.fz = -fx * sn + fz * c
			L.y0 += dy
			L.t = top
			P.x = pp.x
			P.z = pp.y
			P.y += dy
			P.yaw += da
	# ---- 4. push-out / scoop / crush
	_crush_cd = maxf(0.0, _crush_cd - dt)
	_hazard_cd = maxf(0.0, _hazard_cd - dt)
	for m: Mover in act:
		for s: World.Solid in m.solids:
			if s == sup or s.off or not _moved(s):
				continue
			var feet := P.y
			var head := P.y + ph
			if feet >= s.top - 0.03 or head <= s.bottom + 0.03:
				continue
			if not foot_overlap(s, P.x, P.z, PR - 0.02):
				continue
			if s.top - feet <= 0.6 and P.vy < 2.5 and P.mode == &"normal":      # rose under his feet: scooped up
				P.y = s.top
				P.vy = maxf(0.0, P.vy)
				P.grounded = true
				P.air_jump = false
				continue
			var mv := _push_out(s, P.x, P.z, PR)
			if not world.blocked(P.x + mv.x, P.z + mv.y, P.y, ph, PR, 0.42):
				P.x += mv.x
				P.z += mv.y
			elif _crush_cd <= 0.0:
				_crush_cd = 0.8
				hurt(P, float(s.data.get("crush", 12.0)), P.x - mv.x, P.z - mv.y, "melee")
				P.y = s.top + 0.02
				P.vy = 3.0
				P.grounded = false
				push({"t": &"summon", "x": P.x, "y": P.y, "z": P.z})
			var hz_fn: Variant = s.data.get("hazard")
			if hz_fn != null and _hazard_cd <= 0.0:
				_hazard_cd = 0.9
				(hz_fn as Callable).call(P)
	# ---- 5. trampolines (land hard on a membrane: it throws you back up)
	_tram_t = maxf(0.0, _tram_t - dt)
	if P.grounded and _was_air and P.land_impact > 4.0 and _tram_t <= 0.0:
		for m: Mover in act:
			if m.bounce:
				for s: World.Solid in m.solids:
					if not s.off and s.top_at(P.x, P.z) != null and absf(P.y - s.top) < 0.08:
						m.bounce_hit(P)
						_tram_t = 0.25
						break
	_was_air = not P.grounded
	# ---- 6. forces
	for f: Dictionary in forces:
		if not f.has("y0") or (float(f.y1) > py - 30.0 and float(f.y0) < py + 30.0):
			(f.apply as Callable).call(t, dt, P)


# ---------------------------------------------------------------------------------------------------------------- force volumes
## UPDRAFT: a column of breath. Inside it, while on(t) > 0, you are lifted (double jump refreshed) up to y1
func updraft(x: float, z: float, r: float, y0: float, y1: float, on: Callable, vmax: float = 6.5) -> void:
	forces.append({"y0": y0, "y1": y1, "apply": func(t: float, dt: float, P: Player) -> void:
		if P.dead or P.mode != &"normal":
			return
		var k: float = on.call(t)
		if k < 0.05 or U.hyp(P.x - x, P.z - z) > r or P.y < y0 - 0.2 or P.y > y1:
			return
		var cap := vmax * k * clampf((y1 - P.y) / 1.6, 0.0, 1.0)
		if P.vy < cap:
			P.vy = minf(cap, P.vy + 58.0 * k * dt)
			P.grounded = false
			P.jumping = false
			P.air_jump = true
			P.coyote_t = 0.0})


## WIND: inside a region you are shoved at dir(t) = Vector2(wx, wz) m/s
func wind(y0: float, y1: float, inside: Callable, dir: Callable) -> void:
	forces.append({"y0": y0, "y1": y1, "apply": func(t: float, dt: float, P: Player) -> void:
		if P.dead or P.mode != &"normal" or not inside.call(P.x, P.y, P.z):
			return
		var w: Vector2 = dir.call(t)
		P.ix += w.x * 9.0 * dt
		P.iz += w.y * 9.0 * dt})


## POOL: a liquid with a moving surface level(t). Below it you burn and wade slowly.
func pool(y0: float, y1: float, inside: Callable, level_fn: Callable, dps: float = 9.0, slow: float = 0.55) -> void:
	var tick := [0.0]
	forces.append({"y0": y0, "y1": y1, "apply": func(t: float, dt: float, P: Player) -> void:
		if P.dead or P.y < y0 or P.y > y1 or not inside.call(P.x, P.z):
			return
		var lv: float = level_fn.call(t)
		if P.y > lv - 0.05:
			return
		P.slow_t = maxf(P.slow_t, 0.25)
		P.slow_mul = minf(P.slow_mul if P.slow_mul != 0.0 else 1.0, slow)
		tick[0] = float(tick[0]) - dt
		if float(tick[0]) <= 0.0:
			tick[0] = 0.3
			hurt(P, dps * 0.3, P.x, P.z, "bolt")
			push({"t": &"boltHit", "x": P.x, "y": lv, "z": P.z, "kind": "world", "bk": "bile", "nx": 0.0, "ny": 1.0, "nz": 0.0})})
