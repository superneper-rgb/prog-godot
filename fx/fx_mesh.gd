class_name FxMesh
extends RefCounted
## Small meshes the effects share, built once at boot: rings, the faceted ball, the rocket with baked vertex colours (same sizes as the JS geometries).


static func _commit(verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray = PackedColorArray(), idx: PackedInt32Array = PackedInt32Array()) -> ArrayMesh:
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = verts
	a[Mesh.ARRAY_NORMAL] = norms
	if not cols.is_empty():
		a[Mesh.ARRAY_COLOR] = cols
	if not idx.is_empty():
		a[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	return m


## JS RingGeometry(inner, outer, segs) rotated flat: lies in XZ, faces +Y.
static func ring(inner: float, outer: float, segs: int) -> ArrayMesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	for i in segs:
		var a0 := float(i) / segs * TAU
		var a1 := float(i + 1) / segs * TAU
		var p0 := Vector3(cos(a0) * inner, 0, sin(a0) * inner)
		var p1 := Vector3(cos(a0) * outer, 0, sin(a0) * outer)
		var p2 := Vector3(cos(a1) * outer, 0, sin(a1) * outer)
		var p3 := Vector3(cos(a1) * inner, 0, sin(a1) * inner)
		for p in [p0, p1, p2, p0, p2, p3]:
			v.append(p)
			n.append(Vector3.UP)
	return _commit(v, n)


## JS IcosahedronGeometry(r, detail): each face split into (detail + 1)^2, flat normals.
static func icosahedron(r: float, detail: int) -> ArrayMesh:
	var t := (1.0 + sqrt(5.0)) * 0.5
	var c := [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0), Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t), Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	var f := [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var steps := detail + 1
	for tri: Array in f:
		var a: Vector3 = c[tri[0]]
		var b: Vector3 = c[tri[1]]
		var d: Vector3 = c[tri[2]]
		for i in steps:
			for j in steps - i:
				var p := (a + (b - a) * (float(i) / steps) + (d - a) * (float(j) / steps)).normalized() * r
				var q := (a + (b - a) * (float(i + 1) / steps) + (d - a) * (float(j) / steps)).normalized() * r
				var s := (a + (b - a) * (float(i) / steps) + (d - a) * (float(j + 1) / steps)).normalized() * r
				_tri(v, n, p, s, q)
				if j < steps - i - 1:
					var u := (a + (b - a) * (float(i + 1) / steps) + (d - a) * (float(j + 1) / steps)).normalized() * r
					_tri(v, n, q, s, u)
	return _commit(v, n)


static func _tri(v: PackedVector3Array, n: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3) -> void:
	# Godot's front face winds clockwise; the input triangles wind counter-clockwise seen from outside
	var fn := (b - a).cross(c - a).normalized()
	if fn.dot(a + b + c) < 0.0:
		var t := b
		b = c
		c = t
		fn = -fn
	v.append(a)
	v.append(c)
	v.append(b)
	for i in 3:
		n.append(fn)


## JS OctahedronGeometry(r, 0)
static func octahedron(r: float) -> ArrayMesh:
	var P := [Vector3(r, 0, 0), Vector3(-r, 0, 0), Vector3(0, r, 0), Vector3(0, -r, 0), Vector3(0, 0, r), Vector3(0, 0, -r)]
	var F := [[0, 2, 4], [0, 4, 3], [0, 3, 5], [0, 5, 2], [1, 2, 5], [1, 5, 3], [1, 3, 4], [1, 4, 2]]
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	for tri: Array in F:
		_tri(v, n, P[tri[0]], P[tri[1]], P[tri[2]])
	return _commit(v, n)


## A primitive's triangles, moved and tinted, appended to the arrays of a merged mesh.
static func _append(prim: Mesh, xf: Transform3D, col: Color, v: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray) -> void:
	var a := prim.surface_get_arrays(0)
	var pv: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var pn: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var ix: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	if ix.is_empty():
		for i in pv.size():
			ix.append(i)
	for i in ix:
		v.append(xf * pv[i])
		n.append((xf.basis * pn[i]).normalized())
		c.append(col)


static func _cylinder(top: float, bottom: float, h: float, seg: int, open := false) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = seg
	m.rings = 1
	m.cap_top = not open
	m.cap_bottom = not open
	return m


## JS ConeGeometry(r, h, seg) with its tip along +Z (three.js cones point up +Y; the JS rotates them onto the flight axis).
static func cone_z(r: float, h: float, seg: int, z: float) -> ArrayMesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	_append(_cylinder(0.0, r, h, seg), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, z)), Color.WHITE, v, n, c)
	return _commit(v, n, c)


## JS TorusGeometry(r, tube, radial, tubular): in the XY plane, around Z.
static func torus_z(r: float, tube: float, radial: int, tubular: int) -> ArrayMesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var t := TorusMesh.new()
	t.inner_radius = r - tube
	t.outer_radius = r + tube
	t.rings = tubular
	t.ring_segments = radial
	_append(t, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), Color.WHITE, v, n, c)
	return _commit(v, n, c)


## JS sawDisc(r, teeth): ceramic disc, copper hub and teeth.
static func saw_disc(r: float, teeth: int, ceramic: Color, copper: Color) -> ArrayMesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var k := r / 0.12
	_append(_cylinder(r, r, 0.012 * k, 22), Transform3D.IDENTITY, ceramic, v, n, c)
	_append(_cylinder(r * 0.28, r * 0.28, 0.02 * k, 10), Transform3D.IDENTITY, copper, v, n, c)
	var box := BoxMesh.new()
	box.size = Vector3(0.032 * k, 0.013 * k, 0.02 * k)
	for i in teeth:
		var a := float(i) / teeth * TAU
		_append(box, Transform3D(Basis(Vector3.UP, -a + 0.55), Vector3(cos(a) * r * 1.02, 0, sin(a) * r * 1.02)), copper, v, n, c)
	return _commit(v, n, c)


## JS _rocket: white body, red nose, four blue fins, flying along +Z.
static func rocket_body(body: Color, nose: Color, fin: Color) -> ArrayMesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var x := Basis(Vector3.RIGHT, PI * 0.5)
	_append(_cylinder(0.06, 0.06, 0.42, 10), Transform3D(x, Vector3.ZERO), body, v, n, c)
	_append(_cylinder(0.0, 0.06, 0.17, 10), Transform3D(x, Vector3(0, 0, 0.295)), nose, v, n, c)
	var box := BoxMesh.new()
	box.size = Vector3(0.012, 0.1, 0.14)
	for k in 4:
		var a := k * PI * 0.5
		_append(box, Transform3D(Basis(Vector3.BACK, a), Vector3(cos(a) * 0.08, sin(a) * 0.08, -0.16)), fin, v, n, c)
	return _commit(v, n, c)


## JS _rocket's flame and core, pointing backwards, additive.
static func rocket_flame(flame: Color, core: Color, op: float) -> ArrayMesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var back := Basis(Vector3.RIGHT, -PI * 0.5)
	_append(_cylinder(0.0, 0.07, 0.6, 8), Transform3D(back, Vector3(0, 0, -0.5)), Color(flame, op), v, n, c)
	_append(_cylinder(0.0, 0.035, 0.34, 8), Transform3D(back, Vector3(0, 0, -0.38)), Color(core, op), v, n, c)
	return _commit(v, n, c)


## Flat triangles from a primitive, moved and coloured by colour_of(position, smooth normal) -> Color.
static func _flat(prim: Mesh, xf: Transform3D, colour_of: Callable, v: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray) -> void:
	var a := prim.surface_get_arrays(0)
	var pv: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var pn: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var ix: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if ix.is_empty():
		for i in pv.size():
			ix.append(i)
	var nb := xf.basis.inverse().transposed()
	var k := 0
	while k + 2 < ix.size():
		var p0 := xf * pv[ix[k]]
		var p1 := xf * pv[ix[k + 1]]
		var p2 := xf * pv[ix[k + 2]]
		var fn := (p2 - p0).cross(p1 - p0).normalized()   # (Godot winds front faces clockwise)
		for q: int in [k, k + 1, k + 2]:
			v.append(xf * pv[ix[q]])
			n.append(fn)
			c.append(colour_of.call(pv[ix[q]], (nb * pn[ix[q]]).normalized()))
		k += 3


## JS TorusGeometry(r, tube, radial, tubular, arc): in the XY plane, around Z.
static func _torus_arc(r: float, tube: float, radial: int, tubular: int, arc: float) -> ArrayMesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var idx := PackedInt32Array()
	for j in radial + 1:
		for i in tubular + 1:
			var u := float(i) / tubular * arc
			var w := float(j) / radial * TAU
			var cx := cos(u) * r
			var cy := sin(u) * r
			var p := Vector3((r + tube * cos(w)) * cos(u), (r + tube * cos(w)) * sin(u), tube * sin(w))
			v.append(p)
			n.append((p - Vector3(cx, cy, 0.0)).normalized())
	for j in range(1, radial + 1):
		for i in range(1, tubular + 1):
			var a := (tubular + 1) * j + i - 1
			var b := (tubular + 1) * (j - 1) + i - 1
			var cc := (tubular + 1) * (j - 1) + i
			var d := (tubular + 1) * j + i
			for q: int in [a, cc, b, a, d, cc]:     # (clockwise seen from outside)
				idx.append(q)
	return _commit(v, n, PackedColorArray(), idx)


## JS makeBall: the spiked, grumpy ball (see the design sheet): face on +Z, chain ring on +Y, one merged mesh with baked vertex colours, flat shaded.
static func flail_ball() -> ArrayMesh:
	var R := 0.21
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var lin := func(hex: int) -> Color: return Color8((hex >> 16) & 255, (hex >> 8) & 255, hex & 255).srgb_to_linear()
	var part := func(prim: Mesh, hex: int, xf: Transform3D, shade: float = 1.0) -> void:
		var col: Color = lin.call(hex)
		var tint := func(_pos: Vector3, nn: Vector3) -> Color:
			var sh := (0.62 + 0.38 * (nn.y * 0.5 + 0.5)) * shade
			return Color(col.r * sh, col.g * sh, col.b * sh)
		_flat(prim, xf, tint, v, n, c)
	var S := func(r: float, x: float, y: float, z: float, hex: int, sx: float = 1.0, sy: float = 1.0, sz: float = 1.0) -> void:
		var m := SphereMesh.new()
		m.radius = r
		m.height = r * 2.0
		m.radial_segments = 9
		m.rings = 7
		part.call(m, hex, Transform3D(Basis.from_scale(Vector3(sx, sy, sz)), Vector3(x, y, z)))
	var B := func(w: float, h: float, d: float, x: float, y: float, z: float, hex: int, rx: float, ry: float, rz: float) -> void:
		var m := BoxMesh.new()
		m.size = Vector3(w, h, d)
		part.call(m, hex, Transform3D(Basis.from_euler(Vector3(rx, ry, rz), EULER_ORDER_XYZ), Vector3(x, y, z)))
	# body: gunmetal shell, the front a clay-brown face (vertex colours, so one mesh)
	var metal: Color = lin.call(0x6a6a6c)
	var face: Color = lin.call(0x9a7850)
	var body := icosahedron(R, 3)
	var body_tint := func(pos: Vector3, _nn: Vector3) -> Color:
		var nx := pos.x / R
		var ny := pos.y / R
		var nz := pos.z / R
		var f := FlailSim.sm((nz - 0.1) / 0.38)
		var h := sin(nx * 41.0 + ny * 23.0 + nz * 57.0) * 0.04
		var tc := metal.lerp(face, f)
		var sh := (0.62 + 0.38 * (ny * 0.5 + 0.5)) * (1.0 + h)
		return Color(tc.r * sh, tc.g * sh, tc.b * sh)
	_flat(body, Transform3D.IDENTITY, body_tint, v, n, c)
	for s: float in [-1.0, 1.0]:
		B.call(0.088, 0.03, 0.05, s * 0.074, 0.084, 0.176, 0xbcb49c, -0.42, 0.0, s * 0.42)       # brows: grey-white tufts, slanting down to the nose (angry)
		B.call(0.06, 0.026, 0.044, s * 0.042, 0.1, 0.182, 0xd8d0b8, -0.42, 0.0, s * 0.3)
		B.call(0.05, 0.022, 0.04, s * 0.108, 0.07, 0.15, 0x9d9680, -0.3, s * 0.5, s * 0.5)
		S.call(0.034, s * 0.07, 0.03, 0.184, 0xe8d98c, 1.0, 0.85, 0.6)                           # eyes: yellowed whites, small dark pupils, heavy lids over the top
		S.call(0.012, s * 0.066, 0.026, 0.208, 0x1a1006)
		S.call(0.038, s * 0.07, 0.048, 0.186, 0x8a6a46, 1.0, 0.55, 0.7)
		part.call(_torus_arc(0.037, 0.008, 5, 12, TAU), 0x3b352f, Transform3D(Basis.IDENTITY, Vector3(s * 0.07, 0.03, 0.178)))    # dark socket ring
		S.call(0.058, s * 0.088, -0.052, 0.148, 0xa07c52, 1.0, 0.9, 0.9)                         # cheeks
		S.call(0.012, s * 0.016, -0.04, 0.236, 0x7a3a2c)                                         # nostrils
	S.call(0.05, 0.0, -0.01, 0.2, 0xd9826a, 1.0, 1.15, 1.1)                                      # the big salmon nose
	S.call(0.075, 0.0, -0.108, 0.13, 0x93704a, 1.5, 0.65, 0.9)                                   # jowls
	part.call(_torus_arc(0.058, 0.008, 5, 12, PI), 0x2a1c12, Transform3D(Basis.IDENTITY, Vector3(0, -0.108, 0.172)))             # the frown (arc over its corners)
	var dirs: Array[Vector3] = [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, -1), Vector3(0, -1, 0), Vector3(0.7, 0.55, -0.45), Vector3(-0.7, 0.55, -0.45), Vector3(0.7, -0.55, -0.45), Vector3(-0.7, -0.55, -0.45), Vector3(0.8, 0.2, 0.5), Vector3(-0.8, 0.2, 0.5), Vector3(0.6, -0.65, 0.45), Vector3(-0.6, -0.65, 0.45), Vector3(0.5, 0.78, 0.2), Vector3(-0.5, 0.78, 0.2)]
	for d in dirs:
		var dv := d.normalized()
		var q := Quaternion(Vector3.RIGHT, PI) if dv.y < -0.9999 else Quaternion(Vector3.UP, dv)
		part.call(_cylinder(0.046, 0.052, 0.028, 8), 0x2c2c2e, Transform3D(Basis(q), dv * (R - 0.002)))                         # dark collar
		part.call(_cylinder(0.0, 0.04, 0.14, 7), 0xb07a28, Transform3D(Basis(q), dv * (R + 0.05)), 1.05)                        # bronze spike
	part.call(_cylinder(0.04, 0.046, 0.03, 8), 0x2c2c2e, Transform3D(Basis.IDENTITY, Vector3(0, R, 0)))                         # the chain ring on top
	part.call(_torus_arc(0.03, 0.011, 5, 10, TAU), 0x3c3d42, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, R + 0.03, 0)))
	return _commit(v, n, c)


## JS linkGeometry: one chain link, flat shaded.
static func flail_link(col: Color) -> ArrayMesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var same := func(_p: Vector3, _nn: Vector3) -> Color: return col
	_flat(_torus_arc(0.043, 0.016, 5, 8, TAU), Transform3D(Basis.from_scale(Vector3(1, 1.5, 1)), Vector3.ZERO), same, v, n, c)
	return _commit(v, n, c)


## JS TetrahedronGeometry(r, 0), white vertex colours (tinted per instance).
static func tetrahedron(r: float) -> ArrayMesh:
	var k := r / sqrt(3.0)
	var P := [Vector3(k, k, k), Vector3(-k, -k, k), Vector3(-k, k, -k), Vector3(k, -k, -k)]
	var F := [[2, 1, 0], [0, 3, 2], [1, 3, 0], [2, 3, 1]]
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	for tri: Array in F:
		_tri(v, n, P[tri[0]], P[tri[1]], P[tri[2]])
		for i in 3:
			c.append(Color.WHITE)
	return _commit(v, n, c)
