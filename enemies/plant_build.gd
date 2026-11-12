class_name PlantBuild
extends RefCounted
## Organic shapes made in code: tubes along a smooth curve (roots, stems, vines, trunks), lathes (bulbs, pods, flower cups), lumpy blobs, leaves and thorns. Each is a Geo of
## positions, smooth normals, linear vertex colours and indices that can be transformed and merged, then turned into a mesh. Shared by the Briar Dervish and the jungle test level.
## Vertex colours are given as sRGB hex (as a colour picker shows them) and stored linear, which is what the batch and StandardMaterial3D's vertex-colour albedo both multiply by.

static var _noise: FastNoiseLite = null


static func lin(hex: int) -> Color:
	return Color.hex((hex << 8) | 0xff).srgb_to_linear()


static func noise3(p: Vector3) -> float:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_noise.frequency = 1.0
		_noise.seed = 913
	return _noise.get_noise_3dv(p)


class Geo:
	var pos := PackedVector3Array()
	var nor := PackedVector3Array()
	var col := PackedColorArray()
	var idx := PackedInt32Array()

	## add another Geo, moved by xf
	func merge(g: Geo, xf: Transform3D = Transform3D.IDENTITY) -> Geo:
		var base := pos.size()
		var nb := xf.basis.inverse().transposed()
		for i in g.pos.size():
			pos.append(xf * g.pos[i])
			nor.append((nb * g.nor[i]).normalized())
			col.append(g.col[i])
		for i in g.idx:
			idx.append(base + i)
		return self

	func moved(xf: Transform3D) -> Geo:
		return Geo.new().merge(self, xf)

	## smooth normals from the faces (lumpy shapes keep their shading)
	func smooth() -> Geo:
		nor.resize(pos.size())
		for i in nor.size():
			nor[i] = Vector3.ZERO
		var t := 0
		while t < idx.size():
			var a := idx[t]
			var b := idx[t + 1]
			var c := idx[t + 2]
			var n := (pos[c] - pos[a]).cross(pos[b] - pos[a])      # Godot's front face is clockwise
			nor[a] += n
			nor[b] += n
			nor[c] += n
			t += 3
		for i in nor.size():
			nor[i] = nor[i].normalized() if nor[i].length_squared() > 1e-12 else Vector3.UP
		return self

	func arrays() -> Array:
		var a: Array = []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = pos
		a[Mesh.ARRAY_NORMAL] = nor
		a[Mesh.ARRAY_COLOR] = col
		a[Mesh.ARRAY_INDEX] = idx
		return a

	func mesh(mat: Material = null) -> ArrayMesh:
		var m := ArrayMesh.new()
		if pos.is_empty():
			return m
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays())
		if mat != null:
			m.surface_set_material(0, mat)
		return m


## Catmull-Rom through the points, `per` samples per span
static func curve(pts: PackedVector3Array, per: int) -> PackedVector3Array:
	if pts.size() < 3:
		return pts
	var out := PackedVector3Array()
	var n := pts.size()
	for i in n - 1:
		var p0 := pts[maxi(0, i - 1)]
		var p1 := pts[i]
		var p2 := pts[i + 1]
		var p3 := pts[mini(n - 1, i + 2)]
		for s in per:
			var u := float(s) / per
			var u2 := u * u
			var u3 := u2 * u
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u3))
	out.append(pts[n - 1])
	return out


## A tube along `path` (already smooth, see curve()). r0 -> r1 radius (r1 = 0: a point), colour c0 -> c1 along it.
## lump: bark-like bumps (fraction of the radius); twist: how far the bumps wind round; flat: squash across (1 = round).
static func tube(path: PackedVector3Array, r0: float, r1: float, sides: int, c0: int, c1: int, lump: float = 0.0, seed_: float = 0.0, cap: bool = true, flat: float = 1.0) -> Geo:
	var g := Geo.new()
	var n := path.size()
	if n < 2:
		return g
	var lc0 := lin(c0)
	var lc1 := lin(c1)
	var L := 0.0
	var acc := PackedFloat32Array([0.0])
	for i in range(1, n):
		L += path[i].distance_to(path[i - 1])
		acc.append(L)
	var tng := (path[1] - path[0]).normalized()
	var ref := Vector3.UP if absf(tng.y) < 0.9 else Vector3.RIGHT
	var nrm := ref.cross(tng).normalized()
	for i in n:
		var t_new := (path[mini(n - 1, i + 1)] - path[maxi(0, i - 1)]).normalized()
		var axis := tng.cross(t_new)      # parallel transport: turn the frame with the curve
		if axis.length_squared() > 1e-10:
			nrm = nrm.rotated(axis.normalized(), tng.angle_to(t_new))
		tng = t_new
		nrm = (nrm - tng * nrm.dot(tng)).normalized()
		var bin := tng.cross(nrm)
		var u := acc[i] / maxf(L, 1e-5)
		var rad := lerpf(r0, r1, u)
		var c := lc0.lerp(lc1, u)
		for s in sides:
			var a := TAU * s / sides
			var k := 1.0
			if lump > 0.0:
				k += lump * noise3(Vector3(cos(a + u * 2.0) * 1.3, acc[i] * 2.2 + seed_, sin(a) * 1.3))
			g.pos.append(path[i] + (nrm * cos(a) * flat + bin * sin(a)) * rad * k)
			g.col.append(c)
	for i in n - 1:
		for s in sides:
			var a := i * sides + s
			var b := i * sides + (s + 1) % sides
			var c2 := a + sides
			var d := b + sides
			g.idx.append_array([a, c2, b, b, c2, d])
	if cap:
		var e0 := g.pos.size()
		g.pos.append(path[0] - (path[1] - path[0]).normalized() * r0 * 0.3)
		g.col.append(lc0)
		for s in sides:
			g.idx.append_array([e0, s, (s + 1) % sides])
		if r1 > 0.004:
			var e1 := g.pos.size()
			g.pos.append(path[n - 1] + (path[n - 1] - path[n - 2]).normalized() * r1 * 0.5)
			g.col.append(lc1)
			var o := (n - 1) * sides
			for s in sides:
				g.idx.append_array([e1, o + (s + 1) % sides, o + s])
	return g.smooth()


## A surface of revolution round +Y. prof: (radius, height), bottom to top faces out (top to bottom faces in: the inside of a cup); cols: one sRGB hex per profile point.
## ribs > 0: that many vertical ribs, rib_amp deep. close: a disc over the first point's ring.
static func lathe(prof: PackedVector2Array, cols: PackedInt32Array, seg: int, ribs: int = 0, rib_amp: float = 0.0, lump: float = 0.0, seed_: float = 0.0, close: bool = true) -> Geo:
	var g := Geo.new()
	var n := prof.size()
	for i in n:
		var c := lin(cols[mini(i, cols.size() - 1)])
		for s in seg:
			var a := TAU * s / seg
			var k := 1.0
			if ribs > 0:
				k -= rib_amp * (1.0 - pow(absf(cos(a * ribs * 0.5)), 0.6))
			if lump > 0.0:
				k += lump * noise3(Vector3(cos(a) * 1.7, prof[i].y * 2.0 + seed_, sin(a) * 1.7))
			var r := prof[i].x * k
			g.pos.append(Vector3(sin(a) * r, prof[i].y, cos(a) * r))
			var shade := 1.0 - 0.35 * clampf((1.0 - k) / rib_amp, 0.0, 1.0) if ribs > 0 and rib_amp > 0.0 else 1.0      # the grooves a shade darker
			g.col.append(Color(c.r * shade, c.g * shade, c.b * shade))
	for i in n - 1:
		for s in seg:
			var a := i * seg + s
			var b := i * seg + (s + 1) % seg
			g.idx.append_array([a, a + seg, b, b, a + seg, b + seg])
	if close and prof[0].x > 0.001:      # close the first ring
		var e := g.pos.size()
		g.pos.append(Vector3(0.0, prof[0].y, 0.0))
		g.col.append(lin(cols[0]))
		for s in seg:
			g.idx.append_array([e, s, (s + 1) % seg])
	return g.smooth()


## A lumpy ball
static func blob(r: float, scl: Vector3, lump: float, c_low: int, c_high: int, seed_: float = 0.0, w: int = 14, h: int = 10) -> Geo:
	var prof := PackedVector2Array()
	var cols := PackedInt32Array()
	for i in h + 1:
		var a := PI * i / h
		prof.append(Vector2(sin(a) * r, -cos(a) * r))
		cols.append(c_low if i < h / 2 else c_high)
	var g := lathe(prof, cols, w, 0, 0.0, lump, seed_)
	var lo := lin(c_low)
	var hi := lin(c_high)
	for i in g.pos.size():
		g.col[i] = lo.lerp(hi, clampf(g.pos[i].y / (2.0 * r) + 0.5, 0.0, 1.0))
		g.pos[i] *= scl
	return g.smooth()


## A thorn from `at` along `dir`
static func thorn(at: Vector3, dir: Vector3, ln: float, r: float, c_base: int, c_tip: int) -> Geo:
	var g := lathe(PackedVector2Array([Vector2(r, 0.0), Vector2(r * 0.55, ln * 0.4), Vector2(r * 0.18, ln * 0.82), Vector2(0.0, ln)]), PackedInt32Array([c_base, c_base, c_tip, c_tip]), 6)
	var d := dir.normalized()
	var ref := Vector3.FORWARD if absf(d.y) > 0.9 else Vector3.UP
	var x := ref.cross(d).normalized()
	var z := x.cross(d)
	return g.moved(Transform3D(Basis(x, d, z), at))


## A leaf blade lying along +Z from the origin, its face up (+Y): curls down along its length, cups across. Two-sided (each side its own faces). blunt: a round-ended flap.
static func leaf(ln: float, wd: float, curl: float, cup: float, c_base: int, c_tip: int, segs: int = 8, across: int = 4, rib: int = -1, blunt: bool = false) -> Geo:
	var g := Geo.new()
	var cb := lin(c_base)
	var ct := lin(c_tip)
	var cr := lin(rib) if rib >= 0 else cb
	for side in 2:
		var base := g.pos.size()
		for i in segs + 1:
			var u := float(i) / segs
			var half := wd * 0.5 * (sqrt(sin(PI * pow(u, 0.6))) if blunt else sin(PI * pow(u, 0.75))) * (1.0 - 0.15 * u)
			var ang := curl * u * u
			var spine := Vector3(0.0, -sin(ang) * ln * u * 0.5, cos(ang * 0.5) * ln * u)
			for j in across * 2 + 1:
				var v := float(j) / (across * 2) * 2.0 - 1.0
				var p := spine + Vector3(v * half, cup * (v * v) * half - (0.004 if side == 1 else 0.0), 0.0)
				g.pos.append(p)
				var c := cb.lerp(ct, u)
				if absf(v) < 0.12:
					c = c.lerp(cr, 0.7)
				g.col.append(c)
		var row := across * 2 + 1
		for i in segs:
			for j in row - 1:
				var a := base + i * row + j
				var b := a + 1
				var c := a + row
				var d := c + 1
				if side == 0:
					g.idx.append_array([a, b, c, b, d, c])
				else:
					g.idx.append_array([a, c, b, b, c, d])
	return g.smooth()
