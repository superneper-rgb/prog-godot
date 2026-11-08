class_name MeshBuild
extends RefCounted
## Builds the hard-surface enemy models in code, the way the JS game does: three.js BoxGeometry / CylinderGeometry / SphereGeometry / TorusGeometry with the same vertices and
## UVs, transformed and folded into one triangle soup per model. Every vertex carries the joint it hangs from and its material row (UV2), so one model is one draw (RigidBatch).

## One primitive before it is folded in: same attribute order and winding as the three.js class it copies.
class Geo:
	var pos := PackedVector3Array()
	var nor := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()

	func rotate_x(a: float) -> void:
		_apply(Basis(Vector3.RIGHT, a))

	func rotate_y(a: float) -> void:
		_apply(Basis(Vector3.UP, a))

	func rotate_z(a: float) -> void:
		_apply(Basis(Vector3.BACK, a))

	func _apply(b: Basis) -> void:
		for i in pos.size():
			pos[i] = b * pos[i]
			nor[i] = b * nor[i]

	func translate(x: float, y: float, z: float) -> void:
		var d := Vector3(x, y, z)
		for i in pos.size():
			pos[i] += d

	## scale, with the normals carried the way a normal matrix does
	func scale(sx: float, sy: float, sz: float) -> void:
		for i in pos.size():
			var p := pos[i]
			pos[i] = Vector3(p.x * sx, p.y * sy, p.z * sz)
			var n := nor[i]
			nor[i] = Vector3(n.x / sx, n.y / sy, n.z / sz).normalized()

	## rigid move: rotation (Euler XYZ, as three.js) then translation
	func place(x: float, y: float, z: float, rx: float = 0.0, ry: float = 0.0, rz: float = 0.0) -> void:
		if rx != 0.0 or ry != 0.0 or rz != 0.0:
			_apply(Basis.from_euler(Vector3(rx, ry, rz), EULER_ORDER_XYZ))
		translate(x, y, z)


## Triangle soup of one model: no shared vertices (flat parts need per-triangle normals anyway).
class Soup:
	var pos := PackedVector3Array()
	var nor := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var col := PackedColorArray()

	## slot: the joint; mat: the material row. flat: per-triangle normals (JS flatShading: true), else the Geo's own.
	func add(g: Geo, slot: int, mat: int, c: Color = Color.WHITE, flat: bool = true) -> void:
		var tag := Vector2(slot, mat)
		var i := 0
		while i < g.idx.size():
			var ia := g.idx[i]
			var ib := g.idx[i + 1]
			var ic := g.idx[i + 2]
			i += 3
			var a := g.pos[ia]
			var b := g.pos[ib]
			var e := g.pos[ic]
			var fn := Vector3.UP
			if flat:
				var cr := (b - a).cross(e - a)
				if cr.length_squared() < 1e-16:
					continue                     # a cone's collapsed side
				fn = cr.normalized()
			# three.js winds counter-clockwise, Godot's front faces are clockwise: same triangle, swapped order
			pos.append_array([a, e, b])
			if flat:
				nor.append_array([fn, fn, fn])
			else:
				nor.append_array([g.nor[ia], g.nor[ic], g.nor[ib]])
			# Godot reads textures with v = 0 at the top row, three.js (flipY) with v = 1 there
			uv.append_array([_flip(g.uv[ia]), _flip(g.uv[ic]), _flip(g.uv[ib])])
			uv2.append_array([tag, tag, tag])
			col.append_array([c, c, c])

	static func _flip(u: Vector2) -> Vector2:
		return Vector2(u.x, 1.0 - u.y)

	func commit() -> ArrayMesh:
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = pos
		a[Mesh.ARRAY_NORMAL] = nor
		a[Mesh.ARRAY_TEX_UV] = uv
		a[Mesh.ARRAY_TEX_UV2] = uv2
		a[Mesh.ARRAY_COLOR] = col
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		return m


## THREE.BoxGeometry(w, h, d)
static func box(w: float, h: float, d: float) -> Geo:
	var g := Geo.new()
	_plane(g, 2, 1, 0, -1.0, -1.0, d, h, w)    # px
	_plane(g, 2, 1, 0, 1.0, -1.0, d, h, -w)    # nx
	_plane(g, 0, 2, 1, 1.0, 1.0, w, d, h)      # py
	_plane(g, 0, 2, 1, 1.0, -1.0, w, d, -h)    # ny
	_plane(g, 0, 1, 2, 1.0, -1.0, w, h, d)     # pz
	_plane(g, 0, 1, 2, -1.0, -1.0, w, h, -d)   # nz
	return g


## three.js BoxGeometry.buildPlane with one segment. u, v, w are axis indices.
static func _plane(g: Geo, u: int, v: int, w: int, udir: float, vdir: float, width: float, height: float, depth: float) -> void:
	var base := g.pos.size()
	var n := Vector3.ZERO
	n[w] = 1.0 if depth > 0.0 else -1.0
	for iy in 2:
		var y := iy * height - height * 0.5
		for ix in 2:
			var x := ix * width - width * 0.5
			var p := Vector3.ZERO
			p[u] = x * udir
			p[v] = y * vdir
			p[w] = depth * 0.5
			g.pos.append(p)
			g.nor.append(n)
			g.uv.append(Vector2(ix, 1 - iy))
	g.idx.append_array([base, base + 2, base + 1, base + 2, base + 3, base + 1])


## THREE.PlaneGeometry(w, h), facing +z
static func plane(w: float, h: float) -> Geo:
	var g := Geo.new()
	for iy in 2:
		for ix in 2:
			g.pos.append(Vector3(ix * w - w * 0.5, h * 0.5 - iy * h, 0.0))
			g.nor.append(Vector3.BACK)
			g.uv.append(Vector2(ix, 1 - iy))
	g.idx.append_array([0, 2, 1, 2, 3, 1])
	return g


## THREE.CylinderGeometry(rt, rb, len, seg, 1) (a cone with rt = 0, as ConeGeometry)
static func cylinder(rt: float, rb: float, len: float, seg: int) -> Geo:
	var g := Geo.new()
	var half := len * 0.5
	var slope := (rb - rt) / len
	for iy in 2:
		var radius := iy * (rb - rt) + rt
		for ix in seg + 1:
			var u := float(ix) / seg
			var th := u * TAU
			var s := sin(th)
			var c := cos(th)
			g.pos.append(Vector3(radius * s, -iy * len + half, radius * c))
			g.nor.append(Vector3(s, slope, c).normalized())
			g.uv.append(Vector2(u, 1 - iy))
	for ix in seg:
		var a := ix
		var b := ix + seg + 1
		var c := ix + seg + 2
		var d := ix + 1
		if rt > 0.0:
			g.idx.append_array([a, b, d])
		if rb > 0.0:
			g.idx.append_array([b, c, d])
	if rt > 0.0:
		_cap(g, rt, half, 1.0, seg)
	if rb > 0.0:
		_cap(g, rb, half, -1.0, seg)
	return g


static func _cap(g: Geo, radius: float, half: float, sign_: float, seg: int) -> void:
	var center := g.pos.size()
	for ix in seg + 1:
		g.pos.append(Vector3(0.0, half * sign_, 0.0))
		g.nor.append(Vector3(0.0, sign_, 0.0))
		g.uv.append(Vector2(0.5, 0.5))
	var ring := g.pos.size()
	for ix in seg + 1:
		var th := float(ix) / seg * TAU
		var c := cos(th)
		var s := sin(th)
		g.pos.append(Vector3(radius * s, half * sign_, radius * c))
		g.nor.append(Vector3(0.0, sign_, 0.0))
		g.uv.append(Vector2(c * 0.5 + 0.5, s * 0.5 * sign_ + 0.5))
	for ix in seg:
		var c := center + ix
		var i := ring + ix
		if sign_ > 0.0:
			g.idx.append_array([i, i + 1, c])
		else:
			g.idx.append_array([i + 1, i, c])


## THREE.SphereGeometry(r, w, h)
static func sphere(r: float, w: int, h: int) -> Geo:
	var g := Geo.new()
	var grid: Array[PackedInt32Array] = []
	var index := 0
	for iy in h + 1:
		var row := PackedInt32Array()
		var v := float(iy) / h
		var u_off := 0.0
		if iy == 0:
			u_off = 0.5 / w
		elif iy == h:
			u_off = -0.5 / w
		for ix in w + 1:
			var u := float(ix) / w
			var p := Vector3(-r * cos(u * TAU) * sin(v * PI), r * cos(v * PI), r * sin(u * TAU) * sin(v * PI))
			g.pos.append(p)
			g.nor.append(p.normalized() if p.length_squared() > 0.0 else Vector3.UP)
			g.uv.append(Vector2(u + u_off, 1.0 - v))
			row.append(index)
			index += 1
		grid.append(row)
	for iy in h:
		for ix in w:
			var a := grid[iy][ix + 1]
			var b := grid[iy][ix]
			var c := grid[iy + 1][ix]
			var d := grid[iy + 1][ix + 1]
			if iy != 0:
				g.idx.append_array([a, b, d])
			if iy != h - 1:
				g.idx.append_array([b, c, d])
	return g


## THREE.TorusGeometry(radius, tube, radial, tubular)
static func torus(radius: float, tube: float, radial: int, tubular: int) -> Geo:
	var g := Geo.new()
	for j in radial + 1:
		for i in tubular + 1:
			var u := float(i) / tubular * TAU
			var v := float(j) / radial * TAU
			var p := Vector3((radius + tube * cos(v)) * cos(u), (radius + tube * cos(v)) * sin(u), tube * sin(v))
			var ctr := Vector3(radius * cos(u), radius * sin(u), 0.0)
			g.pos.append(p)
			g.nor.append((p - ctr).normalized())
			g.uv.append(Vector2(float(i) / tubular, float(j) / radial))
	for j in range(1, radial + 1):
		for i in range(1, tubular + 1):
			var a := (tubular + 1) * j + i - 1
			var b := (tubular + 1) * (j - 1) + i - 1
			var c := (tubular + 1) * (j - 1) + i
			var d := (tubular + 1) * j + i
			g.idx.append_array([a, b, d, b, c, d])
	return g


## JS PartBuilder: collects primitive geometry per material with the worn-paint UV scale. One builder per part (the UV offsets count from 0 per part, as in the JS).
class PartBuilder:
	const ROBOT_TEX_SCALE := 1.7
	var k := 0
	var out: Soup
	var slot := 0

	func _init(p_out: Soup, p_slot: int) -> void:
		out = p_out
		slot = p_slot

	func _push(g: Geo, m: int, x: float, y: float, z: float, o: Dictionary) -> void:
		g.rotate_x(o.get("rx", 0.0))
		g.rotate_y(o.get("ry", 0.0))
		g.rotate_z(o.get("rz", 0.0))
		g.translate(x, y, z)
		out.add(g, slot, m, o.get("col", Color.WHITE))

	func box(m: int, w: float, h: float, d: float, x: float, y: float, z: float, o: Dictionary = {}) -> PartBuilder:
		var g := MeshBuild.box(w, h, d)
		var s := ROBOT_TEX_SCALE
		var ox := fposmod(k * 0.37, 1.0)
		var oy := fposmod(k * 0.61, 1.0)
		k += 1
		var taper := o.has("top") or o.has("bot")
		for i in g.pos.size():
			var f := i / 4
			var u := d if f < 2 else w
			var v := h if f < 2 else (d if f < 4 else h)
			g.uv[i] = Vector2(g.uv[i].x * u * s + ox, g.uv[i].y * v * s + oy)
			if taper:                                 # taper: scale x/z of the top / bottom ring
				var p := g.pos[i]
				var kk: float = o.get("top", 1.0) if p.y > 0.0 else o.get("bot", 1.0)
				var kz: float = o.get("top_z", kk) if p.y > 0.0 else kk
				g.pos[i] = Vector3(p.x * kk, p.y, p.z * kz)
		_push(g, m, x, y, z, o)
		return self

	func cyl(m: int, rt: float, rb: float, len: float, x: float, y: float, z: float, o: Dictionary = {}) -> PartBuilder:
		var g := MeshBuild.cylinder(rt, rb, len, o.get("seg", 8))
		var s := ROBOT_TEX_SCALE
		var ox := fposmod(k * 0.37, 1.0)
		for i in g.uv.size():
			g.uv[i] = Vector2(g.uv[i].x * 6.28 * maxf(rt, rb) * s + ox, g.uv[i].y * len * s)
		var axis: String = o.get("axis", "")
		if axis == "x":
			g.rotate_z(PI * 0.5)
		elif axis == "z":
			g.rotate_x(PI * 0.5)
		k += 1
		_push(g, m, x, y, z, o)
		return self
