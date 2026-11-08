class_name Goggles
extends RefCounted
## The night vision goggles' model, fitted to a character's head (JS gear/night-vision.js measureHead, buildProg, buildTommy, fitGoggles). Prog: tri-lens unit on a head harness, hinged at the forehead. Tommy: a wrap-around band with two lenses. The main menu's pair and the in-game pair (gear/night_vision.gd, which moves it) both wear this.

const GLOW_SHADER := "res://ui/menu_scene/menu_glow.gdshader"
const GLOW_TEX := "res://assets/ui/menu_scene/nv_glow.png"

var root: Node3D
var light: OmniLight3D
var glows: Array[MeshInstance3D] = []
var lens_mat: StandardMaterial3D
var glow_mat: ShaderMaterial
var attach: BoneAttachment3D
var pose := Callable()      # on 0 = flipped up on the brow, 1 = over the eyes
var head_w := 0.2      # the measured head's width


class Frame:
	var p: Vector3
	var n: Vector3
	var u: Vector3
	func _init(p_: Vector3, n_: Vector3, u_: Vector3) -> void:
		p = p_
		n = n_
		u = u_


class Measure:
	var f_min := 0.0
	var f_max := 0.0
	var u_min := 0.0
	var u_max := 0.0
	var l_min := 0.0
	var l_max := 0.0
	var W := 0.0
	var H := 0.0
	var D := 0.0
	var lc := 0.0
	var fc := 0.0
	var skull := PackedVector3Array()      # [l, u, f] of the skull itself, no hair: for the straps
	var has_eyes := false
	var eye_l := 0.0
	var eye_gap := 0.0
	var eye_u := 0.0
	var eye_front := 0.0
	var eye_r := 0.0


class Hoop:
	var frames: Array[Frame] = []
	var lc := 0.0
	var fc := 0.0
	var front := 0.0


static func _pct(a: PackedFloat32Array, p: float) -> float:
	return a[int(clampf(p, 0.0, 1.0) * (a.size() - 1))]


## The head's size and the eye line, in a frame centred on the head bone and aligned with the body (x = his left, y = up, z = forward). ENGINE DIFFERENCE: measured on the rest vertices, not the posed ones: everything dominated by the head bone is rigid with it, so the numbers are the same.
static func measure_head(an: Animator) -> Measure:
	var rec: Variant = an.by_key.get(&"head")
	if rec == null or rec.bone < 0:
		return null
	var sk := an.skel
	var under: Dictionary = {rec.bone: true}
	for i in sk.get_bone_count():
		if under.has(sk.get_bone_parent(i)):
			under[i] = true
	var scale_ := sk.global_basis.get_scale().x
	var c0: Vector3 = sk.get_bone_global_rest(rec.bone).origin
	var F := PackedFloat32Array()
	var Uu := PackedFloat32Array()
	var Lf := PackedFloat32Array()
	var S := PackedVector3Array()
	var eyes := PackedVector3Array()
	var walk: Array[Node] = [an.actor]
	var notskull := RegEx.create_from_string("(?i)hair|eye|iris|pupil|nose|brow|beard|mustache|tooth|teeth")
	while not walk.is_empty():
		var n: Node = walk.pop_back()
		walk.append_array(n.get_children())
		if not n is MeshInstance3D or not (n as MeshInstance3D).is_visible_in_tree():
			continue
		var mi := n as MeshInstance3D
		if mi.mesh == null or mi.skin == null:
			continue
		var bone_of: Dictionary = {}
		for b in mi.skin.get_bind_count():
			bone_of[b] = mi.skin.get_bind_bone(b) if mi.skin.get_bind_bone(b) >= 0 else sk.find_bone(mi.skin.get_bind_name(b))
		for s in mi.mesh.get_surface_count():
			var arr: Array = mi.mesh.surface_get_arrays(s)
			var V: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var BI: Variant = arr[Mesh.ARRAY_BONES]
			var BW: Variant = arr[Mesh.ARRAY_WEIGHTS]
			if BI == null or BW == null or (BI as PackedInt32Array).is_empty():
				continue
			var per: int = (BI as PackedInt32Array).size() / V.size()
			var mat := mi.get_active_material(s)
			var mname := mat.resource_name if mat != null else ""
			var not_skull := notskull.search(mname) != null
			var is_eye := mname.contains("eye_white")
			for i in V.size():
				var v: Vector3 = (V[i] - c0) * scale_
				var best := -1
				var bw := 0.0
				for j in per:
					var w: float = BW[i * per + j]
					if w > bw:
						bw = w
						best = BI[i * per + j]
				var bone: int = bone_of.get(best, -1)
				if is_eye:      # (every eye-white vertex, whichever bone holds it, as the JS)
					eyes.append(v)
				if not under.has(bone):
					continue
				F.append(v.z)
				Uu.append(v.y)
				Lf.append(v.x)
				if not not_skull and not String(sk.get_bone_name(bone)).to_lower().contains("hair"):
					S.append(v)
	if F.size() < 20:
		return null
	F.sort()
	Uu.sort()
	Lf.sort()
	var m := Measure.new()
	m.f_min = _pct(F, 0.03)
	m.f_max = _pct(F, 0.97)
	m.u_min = _pct(Uu, 0.02)
	m.u_max = _pct(Uu, 0.99)
	m.l_min = _pct(Lf, 0.03)
	m.l_max = _pct(Lf, 0.97)
	m.W = m.l_max - m.l_min
	m.H = m.u_max - m.u_min
	m.D = m.f_max - m.f_min
	m.lc = (m.l_min + m.l_max) / 2.0
	m.fc = (m.f_min + m.f_max) / 2.0
	if S.size() > 40:
		m.skull = S
	# the eyes themselves (the eye-white meshes), so the lenses can sit right over them: per side its centre and size
	var eye_a := PackedVector3Array()
	var eye_b := PackedVector3Array()
	for v: Vector3 in eyes:
		(eye_a if v.x > m.lc else eye_b).append(v)
	if not eye_a.is_empty() and not eye_b.is_empty():
		var a := _box(eye_a)
		var b := _box(eye_b)
		m.has_eyes = true
		m.eye_l = (a.c.x + b.c.x) / 2.0
		m.eye_gap = absf(a.c.x - b.c.x)
		m.eye_u = (a.c.y + b.c.y) / 2.0
		m.eye_front = maxf(a.front, b.front)
		m.eye_r = maxf(a.r, b.r)
	return m


static func _box(P: PackedVector3Array) -> Dictionary:
	var ab := AABB(P[0], Vector3.ZERO)
	for p: Vector3 in P:
		ab = ab.expand(p)
	return {"c": ab.get_center(), "r": maxf(ab.size.x, ab.size.y) / 2.0, "front": ab.end.z}


## radial outline of skull points: for n angle bins the farthest point (0 where a bin is empty), the gaps filled from their neighbours, narrow bumps (the ears) taken out with a running median, then smoothed. ang_rad(p) -> Vector2(angle 0..1, radius), or x < 0 to skip.
static func _outline(n: int, pts: PackedVector3Array, ang_rad: Callable, wrap: bool, med: int = 7) -> PackedFloat32Array:
	var r := PackedFloat32Array()
	r.resize(n)
	r.fill(0.0)
	var any := false
	for p: Vector3 in pts:
		var ad: Vector2 = ang_rad.call(p)
		if ad.x < 0.0:
			continue
		var b := roundi(ad.x * n) % n
		if b >= 0 and b < n:
			r[b] = maxf(r[b], ad.y)
			any = any or ad.y > 0.0
	if not any:
		return PackedFloat32Array()
	for i in n:
		if r[i] == 0.0:      # empty bin: between the nearest filled ones
			var a := 1
			var b := 1
			while r[posmod(i - a, n)] == 0.0 and a < n:
				a += 1
			while r[posmod(i + b, n)] == 0.0 and b < n:
				b += 1
			var ra: float = r[posmod(i - a, n)] if (wrap or i - a >= 0) else r[posmod(i + b, n)]
			var rb: float = r[posmod(i + b, n)] if (wrap or i + b < n) else ra
			r[i] = ra + (rb - ra) * a / (a + b)
	var c := r.duplicate()
	var hw := med >> 1
	for i in n:
		var w := PackedFloat32Array()
		for j in range(-hw, hw + 1):
			var k := posmod(i + j, n) if wrap else mini(n - 1, maxi(0, i + j))
			w.append(c[k])
		w.sort()
		r[i] = w[hw]
	for s in 2:
		c = r.duplicate()
		for i in n:
			var p: float = c[posmod(i - 1, n)] if wrap else c[maxi(0, i - 1)]
			var q: float = c[posmod(i + 1, n)] if wrap else c[mini(n - 1, i + 1)]
			r[i] = maxf(c[i], (p + 2.0 * c[i] + q) / 4.0)
	return r


## a band round the skull at height y (lower at the back by `tilt`), following its real outline `pad` out from it; null if the skull was not measured
static func _hoop(m: Measure, y: float, tilt: float, pad: float) -> Hoop:
	if m.skull.is_empty():
		return null
	var h := m.H * 0.035
	var l0 := 1e9
	var l1 := -1e9
	var f0 := 1e9
	var f1 := -1e9
	var count := 0
	for p: Vector3 in m.skull:      # a thin slice: a thick one catches the wider skull below the band and holds it off the head
		if absf(p.y - y) < h * 2.0:
			count += 1
			l0 = minf(l0, p.x)
			l1 = maxf(l1, p.x)
			f0 = minf(f0, p.z)
			f1 = maxf(f1, p.z)
	if count < 12:
		return null
	var lc := (l0 + l1) / 2.0
	var fc := (f0 + f1) / 2.0
	var n := 48
	var r := _outline(n, m.skull, func(p: Vector3) -> Vector2:
		var x := p.x - lc
		var z := p.z - fc
		if absf(p.y - (y - tilt * z)) > h:
			return Vector2(-1.0, 0.0)
		var a := atan2(x, z) / TAU
		if a < 0.0:
			a += 1.0
		return Vector2(a, sqrt(x * x + z * z)), true)
	if r.is_empty():
		return null
	var up := Vector3(0.0, 1.0, tilt).normalized()      # the band's plane is tipped by the tilt
	var o := Hoop.new()
	for i in n:
		var d := r[i]
		var t := float(i) / n * TAU
		var nx := sin(t)
		var nz := cos(t)
		o.frames.append(Frame.new(Vector3(lc + nx * (d + pad), y - tilt * nz * (d + pad), fc + nz * (d + pad)), Vector3(nx, 0.0, nz), up))
	o.lc = lc
	o.fc = fc
	o.front = fc + r[0] + pad
	return o


## a strap over the crown from ear to ear in the plane f = f0, from height y0 up, following the skull's outline `pad` out from it
static func _crown_arc(m: Measure, lc: float, y0: float, f0: float, pad: float) -> Array[Frame]:
	var out: Array[Frame] = []
	if m.skull.is_empty():
		return out
	var h := m.D * 0.05
	var n := 20
	var r := _outline(n + 1, m.skull, func(p: Vector3) -> Vector2:
		if absf(p.z - f0) > h or p.y < y0 - h:
			return Vector2(-1.0, 0.0)
		var a := atan2(maxf(0.0, p.y - y0), p.x - lc) / PI
		return Vector2(a * n / (n + 1), Vector2(p.x - lc, p.y - y0).length()), false, 5)
	if r.is_empty():
		return out
	for i in r.size():
		var a := PI * i / n
		var nx := cos(a)
		var ny := sin(a)
		out.append(Frame.new(Vector3(lc + nx * (r[i] + pad), y0 + ny * (r[i] + pad), f0), Vector3(nx, ny, 0.0), Vector3(0.0, 0.0, 1.0)))
	return out


## flat webbing along frames { p: centre, n: out from the head, u: across the strap }: `w` wide, `th` thick, a closed loop or an open run
static func _webbing(frames: Array[Frame], w: float, th: float, closed: bool) -> ArrayMesh:
	var P := PackedVector3Array()
	var I := PackedInt32Array()
	var N := frames.size()
	var corners := [[-1.0, -1.0], [1.0, -1.0], [1.0, 1.0], [-1.0, 1.0]]      # (n, u) signs: inner-low, outer-low, outer-high, inner-high
	for f: Frame in frames:
		for c: Array in corners:
			P.append(f.p + f.n * (float(c[0]) * th / 2.0) + f.u * (float(c[1]) * w / 2.0))
	var segs := N if closed else N - 1
	for i in segs:
		var A := i * 4
		var B := ((i + 1) % N) * 4
		for k in 4:
			var k2 := (k + 1) % 4
			I.append_array([A + k, B + k, B + k2, A + k, B + k2, A + k2])
	if not closed:      # end caps
		for e: int in [0, (N - 1) * 4]:
			I.append_array([e, e + 1, e + 2, e, e + 2, e + 3])
	return indexed_mesh(P, I)


## A smooth mesh from JS-wound triangles (computeVertexNormals); Godot's front faces wind the other way.
static func indexed_mesh(P: PackedVector3Array, I: PackedInt32Array, uv := PackedVector2Array()) -> ArrayMesh:
	var Nn := PackedVector3Array()
	Nn.resize(P.size())
	Nn.fill(Vector3.ZERO)
	var J := PackedInt32Array()
	J.resize(I.size())
	for t in range(0, I.size(), 3):
		var a := I[t]
		var b := I[t + 1]
		var c := I[t + 2]
		var fn := (P[b] - P[a]).cross(P[c] - P[a])
		Nn[a] += fn
		Nn[b] += fn
		Nn[c] += fn
		J[t] = a
		J[t + 1] = c
		J[t + 2] = b
	for i in Nn.size():
		Nn[i] = Nn[i].normalized()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = P
	arr[Mesh.ARRAY_NORMAL] = Nn
	arr[Mesh.ARRAY_INDEX] = J
	if not uv.is_empty():
		arr[Mesh.ARRAY_TEX_UV] = uv
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


## Tube along a polyline (JS TubeGeometry; the head's curves are short, so the Catmull-Rom's between-points are not needed at this size).
static func tube(pts: PackedVector3Array, r: float, sides: int, closed: bool) -> ArrayMesh:
	var P := PackedVector3Array()
	var I := PackedInt32Array()
	var N := pts.size()
	for i in N:
		var a := pts[(i + 1) % N if closed else mini(i + 1, N - 1)]
		var b := pts[posmod(i - 1, N) if closed else maxi(i - 1, 0)]
		var t := (a - b).normalized()
		var s := t.cross(Vector3.UP)
		if s.length_squared() < 1e-6:
			s = t.cross(Vector3.RIGHT)
		s = s.normalized()
		var u := s.cross(t).normalized()
		for k in sides:
			var ang := TAU * k / sides
			P.append(pts[i] + (s * cos(ang) + u * sin(ang)) * r)
	for i in (N if closed else N - 1):
		var A := i * sides
		var B := ((i + 1) % N) * sides
		for k in sides:
			var k2 := (k + 1) % sides
			I.append_array([A + k, A + k2, B + k2, A + k, B + k2, B + k])
	return indexed_mesh(P, I)


static func _ring_curve(m: Measure, y: float, grow: float, tilt: float = 0.0) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var a := m.W / 2.0 * grow
	var b := m.D / 2.0 * grow
	for i in 40:
		var t := float(i) / 40.0 * TAU
		var z := m.fc + cos(t) * b
		pts.append(Vector3(m.lc + sin(t) * a, y + tilt * (m.fc - z), z))
	return pts


static func _std(col: int, r: float, me: float, two_sided: bool = false) -> StandardMaterial3D:
	var t := StandardMaterial3D.new()
	t.albedo_color = Color.hex((col << 8) | 0xff)
	t.roughness = r
	t.metallic = me
	if two_sided:
		t.cull_mode = BaseMaterial3D.CULL_DISABLED
	return t


static func part(par: Node3D, mesh: Mesh, mat: Material, p: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var o := MeshInstance3D.new()
	o.mesh = mesh
	o.material_override = mat
	o.position = p
	o.rotation = rot
	o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	par.add_child(o)
	return o


static func box_mesh(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b


static func cyl_mesh(r_top: float, r_bot: float, h: float, seg: int) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c


## A flat disc facing +Z (JS CircleGeometry).
static func circle_mesh(r: float, seg: int) -> ArrayMesh:
	var P := PackedVector3Array([Vector3.ZERO])
	var I := PackedInt32Array()
	for i in seg:
		var a := TAU * i / seg
		P.append(Vector3(cos(a) * r, sin(a) * r, 0.0))
		I.append_array([0, i + 1, (i + 1) % seg + 1])
	return indexed_mesh(P, I)


## one lens tube pointing forward (+z), front face at z = 0
func _lens_tube(M: Dictionary, r: float, len_: float) -> Node3D:
	var g := Node3D.new()
	part(g, cyl_mesh(r, r * 1.08, len_, 14), M.body, Vector3(0.0, 0.0, -len_ / 2.0), Vector3(PI / 2.0, 0.0, 0.0))
	var tor := TorusMesh.new()
	tor.inner_radius = r * 0.98 - r * 0.16
	tor.outer_radius = r * 0.98 + r * 0.16
	tor.rings = 16
	tor.ring_segments = 6
	part(g, tor, M.trim, Vector3.ZERO, Vector3(PI / 2.0, 0.0, 0.0))
	part(g, circle_mesh(r * 0.82, 16), M.lens, Vector3(0.0, 0.0, 0.002))
	var halo := MeshInstance3D.new()
	var q := QuadMesh.new()
	halo.mesh = q
	halo.material_override = glow_mat
	halo.position.z = 0.01
	halo.scale = Vector3.ONE * (r * 5.0)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.extra_cull_margin = 1.0
	g.add_child(halo)
	glows.append(halo)
	return g


## PROG: harness + forehead mount + hinged tri-lens unit (two lenses over the eyes, the third centred above them)
func _build_prog(m: Measure, M: Dictionary) -> void:
	# over the measured eyes when there are any (else estimated from the head's box)
	root = Node3D.new()
	var k := m.W / 0.2
	var eye_y := m.eye_u if m.has_eyes else m.u_min + m.H * 0.53
	var eye_z := m.eye_front if m.has_eyes else m.f_max - m.D * 0.08
	var brow_y := eye_y + m.H * 0.2
	# band round the brow (lower at the back) and a strap over the crown, both drawn along the skull's real outline (snug, just clear of it);
	# the head's bounding box (nose, cheeks, hair spikes) is only the fallback, and much too big for a band
	# flat webbing pressed onto the skull (sitting right on it, not held off it like a halo): ~2 cm wide, a few mm thick
	var TH := 0.0035 * k
	var WB := 0.014 * k
	var PAD := TH * 0.5 + 0.0006 * k
	var band := _hoop(m, brow_y, 0.25, PAD)
	var crown: Array[Frame] = []
	if band != null:
		crown = _crown_arc(m, band.lc, brow_y, band.fc + m.D * 0.05, PAD)
		part(root, _webbing(band.frames, WB, TH, true), M.strap)
	else:
		part(root, tube(_ring_curve(m, brow_y, 1.05, 0.25), 0.011 * k, 6, true), M.strap)
	if not crown.is_empty():
		part(root, _webbing(crown, WB * 0.85, TH, false), M.strap)
	else:
		var top := PackedVector3Array()
		for i in 17:
			var a := PI * i / 16.0
			top.append(Vector3(m.lc + cos(a) * m.W / 2.0 * 1.05, brow_y + sin(a) * (m.u_max - brow_y) * 1.04, m.fc + m.D * 0.05))
		part(root, tube(top, 0.01 * k, 6, false), M.strap)
	var front_z := band.front - PAD if band != null else m.fc + m.D / 2.0 * 1.05      # the forehead (the mount sits on it)
	part(root, box_mesh(0.07 * k, 0.05 * k, 0.03 * k), M.body, Vector3(m.lc, brow_y + 0.01 * k, front_z + 0.012 * k))
	var hinge_z := front_z + 0.03 * k
	var hinge_y := brow_y + 0.02 * k
	part(root, cyl_mesh(0.011 * k, 0.011 * k, 0.08 * k, 10), M.trim, Vector3(m.lc, hinge_y, hinge_z), Vector3(0.0, 0.0, PI / 2.0))
	var pivot := Node3D.new()
	pivot.position = Vector3(m.lc, hinge_y, hinge_z)
	root.add_child(pivot)
	# measured eyes: lens fronts a little proud of the eyes (clear of the brow and cheeks, close enough that the eyes never show beside them); else the old estimate
	var unit := Node3D.new()
	unit.position = Vector3(m.eye_l - m.lc if m.has_eyes else 0.0, eye_y - hinge_y, eye_z + 0.015 * k - hinge_z if m.has_eyes else maxf(eye_z + 0.035 * k - hinge_z, 0.02 * k))
	pivot.add_child(unit)
	for sx: float in [1.0, -1.0]:
		part(pivot, box_mesh(0.012 * k, absf(unit.position.y) + 0.02 * k, 0.014 * k), M.body, Vector3(sx * 0.045 * k, unit.position.y / 2.0, unit.position.z * 0.5))
	var eye_gap := m.eye_gap if m.has_eyes else minf(m.W * 0.32, 0.068 * k)
	var rl := maxf(0.019, m.eye_r * 1.3 / k) if m.has_eyes else 0.019      # lens radius (design units): wide enough to hide the whole eye
	part(unit, box_mesh(eye_gap + 2.0 * rl * k + 0.022 * k, (rl + 0.002) * 2.0 * k, 0.03 * k), M.body, Vector3(0.0, 0.012 * k, -0.02 * k))
	part(unit, box_mesh(0.035 * k, 0.05 * k, 0.03 * k), M.body, Vector3(0.0, 0.045 * k, -0.02 * k))
	for e: Array in [[eye_gap / 2.0, 0.0, rl, 0.055], [-eye_gap / 2.0, 0.0, rl, 0.055], [0.0, rl * 1.8 if m.has_eyes else 0.05, rl * 0.84, 0.065]]:
		var L := _lens_tube(M, float(e[2]) * k, float(e[3]) * k)
		L.position = Vector3(e[0], float(e[1]) * k, 0.03 * k)
		unit.add_child(L)
	light = OmniLight3D.new()
	light.light_color = Color.hex(0x7dff4aff)
	light.light_energy = 0.0
	light.omni_range = 1.6 * k
	light.position = Vector3(0.0, 0.02 * k, 0.06 * k)
	unit.add_child(light)
	pose = func(on: float) -> void: pivot.rotation.x = -1.85 * (1.0 - on)


## TOMMY: a wrap-around band with two lenses; off, it rides up on his forehead turned to the side; on, it is pulled round and down over his eyes
func _build_tommy(m: Measure, M: Dictionary) -> void:
	root = Node3D.new()
	var k := m.W / 0.2
	var eye_y := m.u_min + m.H * 0.17      # his head bone also carries the beanie + propeller: the eyes sit low in that box
	var eye_z := m.f_max - m.D * 0.08
	var turn := Node3D.new()      # pivots about the head's centre at eye height
	turn.position = Vector3(m.lc, eye_y, m.fc)
	root.add_child(turn)
	# (the open band: an arc from -2.6 to 2.6 rad, open at the back)
	var Pb := PackedVector3Array()
	var Ib := PackedInt32Array()
	for i in 41:
		var a := -2.6 + 5.2 * i / 40.0
		for y: float in [0.025 * k, -0.025 * k]:
			Pb.append(Vector3(sin(a) * m.W / 2.0 * 1.08, y, cos(a) * m.D / 2.0 * 1.08))
		if i < 40:
			var A := i * 2
			Ib.append_array([A, A + 1, A + 3, A, A + 3, A + 2])
	part(turn, indexed_mesh(Pb, Ib), _std(0x1b1e21, 0.7, 0.25, true))
	for y: float in [0.025 * k, -0.025 * k]:      # trim along the band's top / bottom edge (same arc as the band: open at the back)
		var pts := PackedVector3Array()
		for i in 31:
			var a := -2.6 + 5.2 * i / 30.0
			pts.append(Vector3(sin(a) * m.W / 2.0 * 1.09, y, cos(a) * m.D / 2.0 * 1.09))
		part(turn, tube(pts, 0.004 * k, 4, false), M.trim)
	part(turn, box_mesh(minf(m.W * 0.62, 0.12 * k), 0.048 * k, 0.03 * k), M.body, Vector3(0.0, 0.0, eye_z - m.fc + 0.03 * k))
	var eye_gap := minf(m.W * 0.32, 0.066 * k)
	for x: float in [eye_gap / 2.0, -eye_gap / 2.0]:
		var L := _lens_tube(M, 0.02 * k, 0.05 * k)
		L.position = Vector3(x, 0.0, eye_z - m.fc + 0.075 * k)
		turn.add_child(L)
	part(turn, box_mesh(0.06 * k, 0.04 * k, 0.025 * k), M.body, Vector3(0.0, 0.0, -m.D / 2.0 * 1.1 - 0.012 * k))
	light = OmniLight3D.new()
	light.light_color = Color.hex(0x7dff4aff)
	light.light_energy = 0.0
	light.omni_range = 1.6 * k
	light.position = Vector3(0.0, 0.0, eye_z - m.fc + 0.1 * k)
	turn.add_child(light)
	pose = func(on: float) -> void:
		turn.rotation = Vector3(-0.5 * (1.0 - on), 1.35 * (1.0 - on), 0.0)
		turn.position.y = eye_y + m.H * 0.24 * (1.0 - on)


## a pair worn for show (the main-menu scene): fitted to `an` like the in-game pair, hung on its head bone and down over the eyes. set_glow(0..1) lights the lenses. The actor must be in the tree and posed.
static func fit(an: Animator, char_id: String) -> Goggles:
	var m := measure_head(an)
	if m == null:
		return null
	var o := Goggles.new()
	o.head_w = m.W
	o.lens_mat = _std(0x0b1a08, 0.15, 0.2)
	o.lens_mat.emission_enabled = true
	o.lens_mat.emission = Color.hex(0x6bff3aff)
	o.lens_mat.emission_energy_multiplier = 0.0
	o.glow_mat = ShaderMaterial.new()
	o.glow_mat.shader = load(GLOW_SHADER)
	o.glow_mat.set_shader_parameter(&"map", load(GLOW_TEX))
	var c := Color.hex(0x9dff6aff).srgb_to_linear()
	o.glow_mat.set_shader_parameter(&"col", Vector3(c.r, c.g, c.b))
	o.glow_mat.set_shader_parameter(&"opacity", 0.0)
	o.glow_mat.set_shader_parameter(&"billboard", true)
	var M := {"strap": _std(0x15171a, 0.85, 0.1, true), "body": _std(0x23272b, 0.45, 0.55), "trim": _std(0x3c4248, 0.35, 0.7), "lens": o.lens_mat}
	if char_id == "tommy":
		o._build_tommy(m, M)
	else:
		o._build_prog(m, M)
	var rec: Variant = an.by_key.get(&"head")
	o.attach = BoneAttachment3D.new()
	o.attach.bone_idx = rec.bone
	an.skel.add_child(o.attach)
	o.attach.on_skeleton_update()
	o.attach.add_child(o.root)
	o.root.name = "night-vision-goggles"
	# the body's facing frame, turned with the head: the head's world rotation without its rest rotation (with the head turned or tilted the goggles still line up with the face)
	var q: Quaternion = an.bone_world_quat(rec.bone) * (rec.rest_w as Quaternion).inverse()
	o.root.global_transform = Transform3D(Basis(q), an.bone_world_pos(rec.bone))
	o.pose.call(1.0)
	return o


func set_glow(g: float) -> void:
	lens_mat.emission_energy_multiplier = 0.15 + 2.4 * g
	glow_mat.set_shader_parameter(&"opacity", 0.9 * g)
	light.light_energy = 0.7 * g
