class_name JungleFlora
extends RefCounted
## The alien jungle's plants as geometry built in code from PlantBuild shapes: giant trees on buttress roots, tree ferns, ferns, broadleaf, glowing lantern and star flowers, glow
## mushrooms, hanging vines, lianas, mossy rocks and a fallen log. Each comes back in its own frame (or in world space where it says so) for the level to merge or instance.
## Made for the jungle test clearing (jungle_test_level.gd), meant to carry over to the jungle level to come.
## Vertex colours are sRGB hex in, linear out (PlantBuild.lin). Alpha is the breeze's weight where a mesh sways in world space (jungle_wind.gdshaderinc, sway_by 0).

## A tree's parts: bark to merge, fins to collide with, and where its leaves and vines go. All in world space.
class Giant:
	var bark := PlantBuild.Geo.new()
	var hulls: Array[PackedVector3Array] = []     # buttress fins as convex pieces (World.add_convex)
	var clumps: Array[Transform3D] = []           # leaf clumps (one MultiMesh for every tree)
	var hangs := PackedVector3Array()             # vine anchors, under the boughs
	var foot := Vector3.ZERO
	var foot_r := 1.0                             # the trunk a metre up: its collider
	var height := 30.0


## sRGB hex a -> b
static func mix_hex(a: int, b: int, t: float) -> int:
	var c := Color.hex((a << 8) | 0xff).lerp(Color.hex((b << 8) | 0xff), clampf(t, 0.0, 1.0))
	return c.to_rgba32() >> 8


## the trunk's radius at height y: a flared foot, tapering up
static func trunk_r(r0: float, y: float, h: float) -> float:
	var t := clampf(y / h, 0.0, 1.0)
	return r0 * (1.0 - 0.45 * t) * (1.0 + 1.3 * exp(-maxf(y, 0.0) / 1.8))


## A giant: fluted trunk on a flared foot, `fins` buttress roots, boughs (o.boughs: [{yaw, len, y, rise}]) each ending in a fork and leaf clumps, and a crown on top.
## ground(x, z) -> the floor's height there (the fins follow it down).
static func tree(foot: Vector3, h: float, r0: float, rng: RandomNumberGenerator, o: Dictionary, ground: Callable) -> Giant:
	var T := Giant.new()
	T.foot = foot
	T.height = h
	T.foot_r = trunk_r(r0, 1.0, h) * 0.86
	var lean := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized() * h * rng.randf_range(0.02, 0.05)
	# the trunk: a ribbed lathe, leaning a little
	var prof := PackedVector2Array()
	var cols := PackedInt32Array()
	var n := 28
	for i in n + 1:
		var u := float(i) / n
		var y := -1.5 + (h + 1.5) * pow(u, 1.2)
		prof.append(Vector2(trunk_r(r0, y, h), y))
		cols.append(mix_hex(0x2a221f, 0x4b3a33, smoothstep(0.0, 6.0, y)) if u < 0.5 else mix_hex(0x4b3a33, 0x3a4535, (u - 0.5) * 2.0))
	prof.append(Vector2(0.0, h + 0.6))
	cols.append(0x3a4535)
	var trunk := PlantBuild.lathe(prof, cols, 34, 9, 0.17, 0.06, rng.randf() * 50.0, false)
	for i in trunk.pos.size():
		var p := trunk.pos[i]
		var k := pow(clampf(p.y / h, 0.0, 1.0), 2.0)
		trunk.pos[i] = foot + Vector3(p.x + lean.x * k, p.y, p.z + lean.y * k)
	T.bark.merge(trunk)
	# buttress fins: planks of root standing on edge, tall at the trunk, running down into the ground
	var nf: int = o.get("fins", 6)
	var a0 := rng.randf() * TAU
	var sz := r0 / 1.8
	for k in nf:
		var a := a0 + TAU * k / nf + rng.randf_range(-0.22, 0.22)
		_fin(T, foot, a, r0, rng.randf_range(4.0, 6.5) * sz, rng.randf_range(3.6, 6.0) * sz, rng.randf_range(-0.9, 0.9), lerpf(0.75, 1.0, sz), ground)
	# boughs. o.keep_out(point) -> true where nothing may grow (a sun shaft): a bough that would reach in is left off
	var keep_out: Callable = o.get("keep_out", Callable())
	for b: Dictionary in o.get("boughs", []):
		_bough(T, foot, lean, r0, h, float(b["yaw"]), float(b["len"]), float(b.get("y", h * 0.75)), float(b.get("rise", 0.22)), rng, 1.0, keep_out)
	# the crown: short boughs up into the canopy
	for i in o.get("crown", 3):
		var ya := rng.randf() * TAU
		_bough(T, foot, lean, r0, h, ya, rng.randf_range(4.0, 6.5), h * rng.randf_range(0.86, 0.95), 0.55, rng, 1.9, keep_out)
	return T


static func _fin(T: Giant, foot: Vector3, a: float, r0: float, L: float, H: float, wig: float, wk: float, ground: Callable) -> void:
	var dir := Vector3(sin(a), 0.0, cos(a))
	var perp := Vector3.UP.cross(dir)       # (dir x perp = up: the section goes round as a tube's does, so the faces point out)
	var S := 14
	var rings: Array[PackedVector3Array] = []
	var g := PlantBuild.Geo.new()
	for s in S:
		var t := float(s) / (S - 1)
		var c := foot + dir * (r0 * 0.5 + (L + r0) * t) + perp * (sin(t * PI) * wig)
		var gy: float = ground.call(c.x, c.z)
		var top := gy + 0.08 + H * pow(1.0 - t, 1.6)
		var bot := gy - 0.7
		var w := lerpf(0.5, 0.08, t) * wk
		var sec := [Vector2(w, bot), Vector2(w, top - w), Vector2(w * 0.7, top - w * 0.3), Vector2(0.0, top), Vector2(-w * 0.7, top - w * 0.3), Vector2(-w, top - w), Vector2(-w, bot)]
		var ring := PackedVector3Array()
		for q: Vector2 in sec:
			var lump := 1.0 + 0.3 * PlantBuild.noise3(Vector3(c.x * 0.8, q.y * 1.1, c.z * 0.8))
			var p := Vector3(c.x, q.y, c.z) + perp * q.x * lump
			ring.append(p)
			g.pos.append(p)
			g.col.append(PlantBuild.lin(mix_hex(0x222b19, 0x40322c, (q.y - gy) / maxf(H, 0.5) * 1.6)))
		rings.append(ring)
	var m := 7
	for s in S - 1:
		for j in m:
			var ia := s * m + j
			var ib := s * m + (j + 1) % m
			g.idx.append_array([ia, ia + m, ib, ib, ia + m, ib + m])
	var e := g.pos.size()       # the tip, closed
	var last := rings[S - 1]
	var mid := Vector3.ZERO
	for p in last:
		mid += p
	g.pos.append(mid / m + dir * 0.08)
	g.col.append(PlantBuild.lin(0x222b19))
	var o2 := (S - 1) * m
	for j in m:
		g.idx.append_array([e, o2 + (j + 1) % m, o2 + j])
	T.bark.merge(g.smooth())
	var s2 := 0
	while s2 < S - 1:
		var pts := PackedVector3Array()
		for q in range(s2, mini(s2 + 3, S)):
			pts.append_array(rings[q])
		T.hulls.append(pts)
		s2 += 2


static func _bough(T: Giant, foot: Vector3, lean: Vector2, r0: float, h: float, ya: float, ln: float, hb: float, rise: float, rng: RandomNumberGenerator, clump_k: float = 1.0, keep_out: Callable = Callable()) -> void:
	var d := Vector3(sin(ya), 0.0, cos(ya))
	var side := Vector3.UP.cross(d) * rng.randf_range(-0.12, 0.12)
	var k := pow(hb / h, 2.0)
	var rb := trunk_r(r0, hb, h)
	var root := foot + Vector3(lean.x * k, hb, lean.y * k) + d * rb * 0.3
	var path := PlantBuild.curve(PackedVector3Array([root, root + (d + side) * ln * 0.3 + Vector3.UP * ln * rise, root + (d - side) * ln * 0.66 + Vector3.UP * ln * (rise + 0.07), root + d * ln + Vector3.UP * ln * (rise - 0.06)]), 6)
	var r_b := rb * 0.55
	var n := path.size()
	var fp := path[int(n * 0.6)]
	var fa := ya + rng.randf_range(0.6, 1.1) * (1.0 if rng.randf() < 0.5 else -1.0)
	var fd := Vector3(sin(fa), 0.0, cos(fa))
	var fl := ln * 0.45
	var fpath := PlantBuild.curve(PackedVector3Array([fp, fp + fd * fl * 0.5 + Vector3.UP * fl * 0.35, fp + fd * fl + Vector3.UP * fl * 0.28]), 5)
	if keep_out.is_valid():
		for p: Vector3 in path + fpath:
			if keep_out.call(p):
				return
	T.bark.merge(PlantBuild.tube(path, r_b, 0.16, 10, 0x40332d, 0x3a4535, 0.15, rng.randf() * 40.0))
	T.bark.merge(PlantBuild.tube(fpath, r_b * 0.45, 0.1, 8, 0x40332d, 0x3a4535, 0.12, rng.randf() * 40.0))
	T.clumps.append(clump_xf(path[n - 1], rng, 1.6 * clump_k))
	T.clumps.append(clump_xf(fpath[fpath.size() - 1], rng, 1.3 * clump_k))
	T.clumps.append(clump_xf(path[int(n * 0.82)] + Vector3.UP * 0.3, rng, 1.15 * clump_k))
	if clump_k < 1.5:
		for _q in rng.randi_range(2, 4):
			var p := path[clampi(int(n * rng.randf_range(0.4, 0.97)), 0, n - 1)]
			T.hangs.append(p - Vector3.UP * r_b * 0.5)


static func clump_xf(p: Vector3, rng: RandomNumberGenerator, s: float) -> Transform3D:
	var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.15, 0.15))
	return Transform3D(b.scaled(Vector3.ONE * s * rng.randf_range(0.85, 1.2)), p)


## A clump of big waxy leaves, the first standing up, the outer ones drooping: what hangs off every bough (instanced). Own frame, about 2.5 m across.
static func clump(rng: RandomNumberGenerator) -> PlantBuild.Geo:
	var g := PlantBuild.Geo.new()
	var n := 22
	for i in n:
		var u := float(i) / n
		var ya := i * 2.39996 + rng.randf_range(-0.2, 0.2)
		var pitch := lerpf(-0.55, 1.15, sqrt(u)) + rng.randf_range(-0.15, 0.15)
		var ln := rng.randf_range(1.7, 2.5)
		var lf := PlantBuild.leaf(ln, ln * 0.46, rng.randf_range(0.6, 1.3), 0.28, 0x123f33, mix_hex(0x2f8a5a, 0x5aa86a, rng.randf()), 6, 2, 0x86c98a)
		var b := Basis(Vector3.UP, ya) * Basis(Vector3.RIGHT, pitch)
		g.merge(lf, Transform3D(b, Vector3(0.0, 0.15 * (1.0 - u), 0.0) + b * Vector3(0.0, 0.0, 0.15)))
	return g


## A frond: a leaf with a lobed edge (PlantBuild.leaf's blade, the width cut into `lobes` scallops) and a narrow stem at its foot.
static func frond(ln: float, wd: float, curl: float, lobes: int, c_base: int, c_tip: int, rib: int, segs: int = 12) -> PlantBuild.Geo:
	var g := PlantBuild.Geo.new()
	var cb := PlantBuild.lin(c_base)
	var ct := PlantBuild.lin(c_tip)
	var cr := PlantBuild.lin(rib)
	var across := 2
	for side in 2:
		var base := g.pos.size()
		for i in segs + 1:
			var u := float(i) / segs
			var env := sin(PI * pow(u, 0.6)) * smoothstep(0.0, 0.18, u)
			var half := wd * 0.5 * env * (0.4 + 0.6 * pow(absf(sin(u * lobes * PI)), 0.45))
			var ang := curl * u * u
			var spine := Vector3(0.0, -sin(ang) * ln * u * 0.5, cos(ang * 0.5) * ln * u)
			for j in across * 2 + 1:
				var v := float(j) / (across * 2) * 2.0 - 1.0
				g.pos.append(spine + Vector3(v * half, 0.12 * (v * v) * half - (0.004 if side == 1 else 0.0), 0.0))
				var c := cb.lerp(ct, u)
				if absf(v) < 0.12:
					c = c.lerp(cr, 0.6)
				g.col.append(c)
		var row := across * 2 + 1
		for i in segs:
			for j in row - 1:
				var a := base + i * row + j
				var b := a + 1
				var c2 := a + row
				var d := c2 + 1
				if side == 0:
					g.idx.append_array([a, b, c2, b, d, c2])
				else:
					g.idx.append_array([a, c2, b, b, c2, d])
	return g.smooth()


## A fern: fronds rising round the root and curling over, two fiddleheads unrolling in the middle. Own frame, root at the origin.
static func fern(rng: RandomNumberGenerator, c_base: int = 0x17453a, c_tip: int = 0x4fae86) -> PlantBuild.Geo:
	var g := PlantBuild.Geo.new()
	var n := 9
	for i in n:
		var ya := TAU * i / n + rng.randf_range(-0.25, 0.25)
		var ln := rng.randf_range(1.1, 1.7)
		var f := frond(ln, ln * 0.42, rng.randf_range(1.4, 2.2), 7, c_base, c_tip, 0x9ee0b8)
		g.merge(f, Transform3D(Basis(Vector3.UP, ya) * Basis(Vector3.RIGHT, rng.randf_range(-1.1, -0.75)), Vector3.ZERO))
	for _i in 2:
		var ya := rng.randf() * TAU
		var pts := PackedVector3Array()
		for s in 14:
			var u := float(s) / 13.0
			var r := 0.07 * (1.0 - u * 0.7)
			var a := u * 4.5
			pts.append(Basis(Vector3.UP, ya) * Vector3(0.0, 0.35 * minf(u * 2.0, 1.0) + sin(a) * r, cos(a) * r - r + 0.03))
		g.merge(PlantBuild.tube(pts, 0.022, 0.012, 5, c_base, 0x8fe0a8))
	return g


## Broadleaf: five big heart-shaped leaves on long stalks, the rib pale and the edge going violet. Own frame.
static func broadleaf(rng: RandomNumberGenerator) -> PlantBuild.Geo:
	var g := PlantBuild.Geo.new()
	var n := 5
	for i in n:
		var ya := TAU * i / n + rng.randf_range(-0.3, 0.3)
		var h := rng.randf_range(0.7, 1.25)
		var reach := rng.randf_range(0.2, 0.45)
		var b := Basis(Vector3.UP, ya)
		var tip := b * Vector3(0.0, h, reach)
		g.merge(PlantBuild.tube(PlantBuild.curve(PackedVector3Array([Vector3.ZERO, b * Vector3(0.0, h * 0.6, reach * 0.2), tip]), 4), 0.035, 0.02, 5, 0x1f4a2c, 0x3f7a4a))
		var ln := rng.randf_range(1.1, 1.6)
		var lf := PlantBuild.leaf(ln, ln * 0.78, rng.randf_range(0.7, 1.1), 0.22, 0x0f3326, 0x3a2a5a, 9, 3, 0x7fd0a0, true)
		g.merge(lf, Transform3D(b * Basis(Vector3.RIGHT, rng.randf_range(0.15, 0.5)), tip))
	return g


## A lantern flower: a stalk that rises and arches over, three bells hanging off it, glowing inside. [plant, glow], own frame.
static func lantern(rng: RandomNumberGenerator, glow: int = 0x5ff4ff) -> Array[PlantBuild.Geo]:
	var g := PlantBuild.Geo.new()
	var gl := PlantBuild.Geo.new()
	var h := rng.randf_range(1.1, 1.7)
	var arc := rng.randf_range(0.4, 0.7)
	var path := PlantBuild.curve(PackedVector3Array([Vector3.ZERO, Vector3(0.0, h * 0.6, 0.05), Vector3(0.0, h, arc * 0.5), Vector3(0.0, h * 0.85, arc)]), 6)
	g.merge(PlantBuild.tube(path, 0.035, 0.015, 6, 0x1d3f2a, 0x3a5a3a))
	for i in 2:
		var lf := PlantBuild.leaf(0.55, 0.22, 0.9, 0.3, 0x174233, 0x3f8a5a, 6, 2, 0x86c98a)
		g.merge(lf, Transform3D(Basis(Vector3.UP, PI * i + rng.randf_range(-0.4, 0.4)) * Basis(Vector3.RIGHT, -0.4), Vector3(0.0, 0.15 + i * 0.12, 0.0)))
	var n := path.size()
	for i in 3:
		var p := path[clampi(n - 1 - i * 4, 0, n - 1)]
		var s := 1.0 - i * 0.2
		var bell := PlantBuild.lathe(PackedVector2Array([Vector2(0.15, -0.24), Vector2(0.135, -0.13), Vector2(0.1, -0.03), Vector2(0.04, 0.02), Vector2(0.0, 0.03)]), PackedInt32Array([0x8a3ab0, 0x5a2a80, 0x3a1f55, 0x2a3a2a, 0x2a3a2a]), 12, 6, 0.12, 0.0, 0.0, false)
		g.merge(bell, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), p))
		gl.merge(PlantBuild.blob(0.075, Vector3(1.0, 1.2, 1.0), 0.0, glow, 0xeaffff, 0.0, 8, 6), Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), p + Vector3(0.0, -0.13 * s, 0.0)))
		for q in 3:
			var a := TAU * q / 3.0 + rng.randf()
			var st := PackedVector3Array([p + Vector3(0.0, -0.1, 0.0) * s, p + Vector3(sin(a) * 0.05, -0.28, cos(a) * 0.05) * s])
			gl.merge(PlantBuild.tube(st, 0.008, 0.006, 4, glow, glow, 0.0, 0.0, false))
			gl.merge(PlantBuild.blob(0.022, Vector3.ONE, 0.0, glow, 0xffffff, 0.0, 6, 4), Transform3D(Basis.IDENTITY, st[1]))
	return [g, gl]


## A star flower: six pink petals open on a short stalk round a glowing heart. [plant, glow], own frame.
static func star(rng: RandomNumberGenerator, heart: int = 0xffc94a) -> Array[PlantBuild.Geo]:
	var g := PlantBuild.Geo.new()
	var gl := PlantBuild.Geo.new()
	var h := rng.randf_range(0.18, 0.4)
	var top := Vector3(rng.randf_range(-0.05, 0.05), h, rng.randf_range(-0.05, 0.05))
	g.merge(PlantBuild.tube(PackedVector3Array([Vector3.ZERO, top]), 0.02, 0.015, 5, 0x1d3f2a, 0x3a5a3a))
	for i in 6:
		var lf := PlantBuild.leaf(0.24, 0.12, 0.7, 0.35, 0xb02a8a, 0xff8ad8, 5, 2, 0xffd0f0)
		g.merge(lf, Transform3D(Basis(Vector3.UP, TAU * i / 6.0) * Basis(Vector3.RIGHT, -0.35), top))
	gl.merge(PlantBuild.blob(0.05, Vector3(1.0, 0.6, 1.0), 0.2, heart, 0xfff4c0, 0.0, 8, 6), Transform3D(Basis.IDENTITY, top + Vector3(0.0, 0.02, 0.0)))
	return [g, gl]


## A cluster of glow mushrooms: pale stems, caps that light from underneath. [stems, caps], own frame.
static func mushrooms(rng: RandomNumberGenerator, cap: int = 0x5cffb0) -> Array[PlantBuild.Geo]:
	var g := PlantBuild.Geo.new()
	var gl := PlantBuild.Geo.new()
	for _i in rng.randi_range(3, 6):
		var p := Vector3(rng.randf_range(-0.25, 0.25), 0.0, rng.randf_range(-0.25, 0.25))
		var h := rng.randf_range(0.08, 0.3)
		var top := p + Vector3(rng.randf_range(-0.04, 0.04), h, rng.randf_range(-0.04, 0.04))
		g.merge(PlantBuild.tube(PackedVector3Array([p - Vector3.UP * 0.05, top]), 0.025, 0.018, 5, 0xc8d6c0, 0xe8f0e0, 0.0, 0.0, false))
		var r := rng.randf_range(0.05, 0.12)
		var c := PlantBuild.lathe(PackedVector2Array([Vector2(r * 1.05, -0.01), Vector2(r, 0.02), Vector2(r * 0.7, r * 0.5), Vector2(0.0, r * 0.65)]), PackedInt32Array([mix_hex(cap, 0xffffff, 0.4), cap, cap, mix_hex(cap, 0x103020, 0.4)]), 10)
		gl.merge(c, Transform3D(Basis.IDENTITY, top))
	return [g, gl]


## A tree fern's parts: the trunk in its own frame, the crown in a frame at the trunk's top (`top`), so the crown sways from there
class TreeFern:
	var trunk: PlantBuild.Geo
	var crown := PlantBuild.Geo.new()
	var top := Vector3.ZERO


## A tree fern: a thin shaggy trunk and a crown of long arching fronds.
static func tree_fern(rng: RandomNumberGenerator, h: float) -> TreeFern:
	var F := TreeFern.new()
	var lean := Vector3(rng.randf_range(-0.6, 0.6), 0.0, rng.randf_range(-0.6, 0.6))
	var path := PlantBuild.curve(PackedVector3Array([Vector3(0.0, -0.4, 0.0), Vector3(0.0, h * 0.4, 0.0) + lean * 0.3, Vector3(0.0, h, 0.0) + lean]), 6)
	F.trunk = PlantBuild.tube(path, 0.32, 0.2, 9, 0x2a221c, 0x3a3328, 0.35, rng.randf() * 30.0)
	F.top = path[path.size() - 1]
	var n := 11
	for i in n:
		var ln := rng.randf_range(2.4, 3.2)
		var f := frond(ln, ln * 0.36, rng.randf_range(1.6, 2.4), 11, 0x1a4a36, 0x5ab88a, 0xa8e8c0, 14)
		F.crown.merge(f, Transform3D(Basis(Vector3.UP, TAU * i / n + rng.randf_range(-0.2, 0.2)) * Basis(Vector3.RIGHT, rng.randf_range(-0.7, -0.25)), Vector3.ZERO))
	F.crown.merge(PlantBuild.blob(0.3, Vector3(1.0, 0.7, 1.0), 0.3, 0x2a3a22, 0x3a4a2a))
	return F


## A vine hanging from `anchor`, `ln` metres, with small leaves along it and a glowing bulb at its end. World space, added to `plant` and `glow`; alpha is the sway (0 at the anchor).
static func vine(anchor: Vector3, ln: float, rng: RandomNumberGenerator, plant: PlantBuild.Geo, glow: PlantBuild.Geo, bulb: int) -> void:
	var drift := Vector3(rng.randf_range(-0.5, 0.5), 0.0, rng.randf_range(-0.5, 0.5))
	var pts := PackedVector3Array([anchor, anchor + Vector3(0.0, -ln * 0.33, 0.0) + drift * 0.6, anchor + Vector3(0.0, -ln * 0.7, 0.0) + drift, anchor + Vector3(0.0, -ln, 0.0) + drift * 0.8])
	var path := PlantBuild.curve(pts, 6)
	var t := PlantBuild.tube(path, 0.05, 0.03, 5, 0x2a4a2a, 0x3a6a3a, 0.2, rng.randf() * 20.0)
	_weigh(t, anchor.y, ln)
	plant.merge(t)
	var n := path.size()
	var i := 2
	while i < n - 1:
		var p := path[i]
		var lf := PlantBuild.leaf(0.3, 0.18, 0.8, 0.3, 0x1f5a3a, 0x4fa070, 4, 1, 0x86c98a, true)
		var ya := rng.randf() * TAU
		var xf := Transform3D(Basis(Vector3.UP, ya) * Basis(Vector3.RIGHT, rng.randf_range(0.2, 0.7)), p)
		var w := lf.moved(xf)
		_weigh(w, anchor.y, ln)
		plant.merge(w)
		i += rng.randi_range(1, 3)
	var b := PlantBuild.blob(0.09, Vector3(1.0, 1.4, 1.0), 0.15, bulb, 0xffffff, rng.randf() * 9.0, 8, 6).moved(Transform3D(Basis.IDENTITY, path[n - 1] + Vector3(0.0, -0.06, 0.0)))
	_weigh(b, anchor.y, ln)
	glow.merge(b)


static func _weigh(g: PlantBuild.Geo, top: float, ln: float) -> void:
	for i in g.col.size():
		var c := g.col[i]
		c.a = clampf((top - g.pos[i].y) / maxf(ln, 1.0) * 2.2, 0.0, 2.2)
		g.col[i] = c


## A liana slung between two trunks, sagging. World space.
static func liana(a: Vector3, b: Vector3, sag: float, rng: RandomNumberGenerator) -> PlantBuild.Geo:
	var pts := PackedVector3Array()
	for i in 9:
		var u := i / 8.0
		pts.append(a.lerp(b, u) + Vector3(0.0, -sag * 4.0 * u * (1.0 - u), 0.0) + Vector3(rng.randf_range(-0.2, 0.2), 0.0, rng.randf_range(-0.2, 0.2)) * sin(u * PI))
	return PlantBuild.tube(PlantBuild.curve(pts, 5), rng.randf_range(0.12, 0.2), 0.1, 8, 0x3a3128, 0x34402e, 0.3, rng.randf() * 30.0)


## A mossy rock. Own frame (its base a little under the origin).
static func rock(r: float, rng: RandomNumberGenerator) -> PlantBuild.Geo:
	var g := PlantBuild.blob(r, Vector3(rng.randf_range(1.0, 1.4), rng.randf_range(0.55, 0.8), rng.randf_range(0.9, 1.2)), 0.28, 0x22261f, 0x4a4e44, rng.randf() * 40.0, 18, 12)
	return g.moved(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(0.0, r * 0.25, 0.0)))


## A fallen log along `path` (world space), and its colliders as convex pieces into `hulls`.
static func fallen_log(path: PackedVector3Array, r: float, rng: RandomNumberGenerator, hulls: Array[PackedVector3Array]) -> PlantBuild.Geo:
	var p := PlantBuild.curve(path, 6)
	var sides := 14
	var g := PlantBuild.tube(p, r, r * 0.8, sides, 0x3a2e28, 0x463830, 0.14, rng.randf() * 30.0)
	var n := p.size()
	var s := 0
	while s < n - 1:
		var pts := PackedVector3Array()
		for q in range(s, mini(s + 3, n)):
			for j in sides:
				pts.append(g.pos[q * sides + j])
		hulls.append(pts)
		s += 2
	return g
