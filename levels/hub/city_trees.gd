class_name CityTrees
extends RefCounted
## FOINT CITY's trees, an art pass made in Godot (user, 2026-11-09): they replace the exported ones (faceted hulls merged into the city's static blocks) and stand where those stood.
## Three kinds, each in a few seeded shapes: a broad street tree on forking limbs over its iron grate, a tall columnar tree in each concrete planter, and low shrubs round its foot.
## A tree is bark tubes plus leaf cards in clumps (levels/shaders/tree_leaves.gdshader cuts the leaves out of each card); all the trees of one shape are one MultiMesh, each turned, sized and tinted on its own.
## Wind: levels/shaders/tree_wind.gdshaderinc. Nothing runs per frame in script.
## 2026-11-11 (user: they could look better and match the city better): they were bright green lollipops in a violet night. Now the street tree is a city plane: a taller clear trunk, limbs
## opening into a wide vase, the crown in flat layered pads of small leaves with the limbs and the sky showing between them; and the colours sit in the city's dark mass (blue-black greens,
## a slate-violet cast on some, old gold only at the tips of the planters' trees), so what reads is the lamp on the leaves, not the paint.
## CityTrees.new() with no level makes only the materials: sample() then gives one tree as a node of its own (the dev level's palette).

const STREET_SHAPES := 3
const PLANTER_SHAPES := 2
const SHRUB_SHAPES := 3
const PLANTER_TOP := 0.55      # soil in a planter, over the street (World: the planters' boxes top out at GY + 0.55)

var group: Node3D
var bark_m: ShaderMaterial
var broad_m: ShaderMaterial
var fan_m: ShaderMaterial
var shrub_m: ShaderMaterial


## One surface's arrays while a shape is built.
class Geo:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()
	var idx := PackedInt32Array()

	func add_to(m: ArrayMesh, mat: Material) -> void:
		if v.is_empty():
			return
		var arr: Array = []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_COLOR] = col
		arr[Mesh.ARRAY_INDEX] = idx
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		m.surface_set_material(m.get_surface_count() - 1, mat)


## lv: the hub; obstacles: life.json's (trees are the ones of radius 0.3, planters 2.2); gy: the street down town.
func _init(lv: ExportedLevel = null, obstacles: Array = [], gy: float = 0.0) -> void:
	_materials()
	if lv == null:
		return
	_hide_old(lv)
	group = Node3D.new()
	group.name = "CityTrees"
	var dn: Array = lv.node_named("FointDistrict")
	(dn[0] if not dn.is_empty() else lv).add_child(group)      # (hidden with the district from the hub street)
	var trees: Array[Vector3] = []
	var planters: Array[Vector3] = []
	for o: Array in obstacles:
		var r: float = o[2]
		var x: float = o[0]
		var z: float = o[1]
		if absf(r - 0.3) < 0.01:
			var g := lv.world.ground_pt(x + 0.7, z, gy + 1.0)      # (beside the trunk: the grate)
			trees.append(Vector3(x, gy if g == -INF else g, z))
		elif absf(r - 2.2) < 0.01:
			planters.append(Vector3(x, gy + PLANTER_TOP, z))
	var rng := RandomNumberGenerator.new()
	# street trees
	var street: Array = []
	for s in STREET_SHAPES:
		street.append(_broad_tree(1301 + s * 77))
	var per: Array = []
	per.resize(STREET_SHAPES)
	for s in STREET_SHAPES:
		per[s] = []
	for p in trees:
		var h := _hash(p.x, p.z)
		(per[int(h * STREET_SHAPES) % STREET_SHAPES] as Array).append(p)
	for s in STREET_SHAPES:
		_plant(street[s], per[s], "StreetTrees%d" % s, 0.92, 1.12, true)
	# planters: a columnar tree in the middle, shrubs round it
	var cols: Array = []
	for s in PLANTER_SHAPES:
		cols.append(_column_tree(2203 + s * 51))
	var shrubs: Array = []
	for s in SHRUB_SHAPES:
		shrubs.append(_shrub(3307 + s * 29))
	var pc: Array = [[], []]
	var ps: Array = [[], [], []]
	for p in planters:
		var h := _hash(p.x, p.z)
		(pc[int(h * 7.0) % PLANTER_SHAPES] as Array).append(p)
		rng.seed = int(h * 100000.0)
		var spots: Array[Vector2] = [Vector2(-0.95, -0.95), Vector2(0.95, -0.95), Vector2(-0.95, 0.95), Vector2(0.95, 0.95), Vector2(0.0, -1.05), Vector2(1.05, 0.0)]
		for k in spots.size():
			if k >= 4 and rng.randf() < 0.5:
				continue
			var sp := spots[k] + Vector2(rng.randf_range(-0.15, 0.15), rng.randf_range(-0.15, 0.15))
			(ps[rng.randi() % SHRUB_SHAPES] as Array).append(Vector3(p.x + sp.x, p.y, p.z + sp.y))
	for s in PLANTER_SHAPES:
		_plant(cols[s], pc[s], "PlanterTrees%d" % s, 0.9, 1.08, true)
	for s in SHRUB_SHAPES:
		_plant(shrubs[s], ps[s], "Shrubs%d" % s, 0.8, 1.15, false)


## one tree as a node of its own, its foot at the origin. kind: &"street", &"planter" or &"shrub"; shape: which of its seeded shapes
func sample(kind: StringName, shape: int = 0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	match kind:
		&"street":
			mi.mesh = _broad_tree(1301 + (shape % STREET_SHAPES) * 77)
		&"planter":
			mi.mesh = _column_tree(2203 + (shape % PLANTER_SHAPES) * 51)
		_:
			mi.mesh = _shrub(3307 + (shape % SHRUB_SHAPES) * 29)
	mi.name = "CityTree_" + String(kind)
	mi.extra_cull_margin = 1.0
	return mi


static func _hash(x: float, z: float) -> float:
	return fposmod(sin(x * 12.9898 + z * 78.233) * 43758.5453, 1.0)


## The exported trees: the city furniture material's swaying variant (shader_ports.gd obc_a465045101_a465, variant 1) is only ever on them.
func _hide_old(lv: ExportedLevel) -> void:
	var n_hidden := 0
	var st: Array[Node] = [lv]
	while not st.is_empty():
		var n: Node = st.pop_back()
		st.append_array(n.get_children())
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null or mi.mesh.get_surface_count() == 0:
			continue
		var m := mi.mesh.surface_get_material(0)
		if m == null or not m.has_meta("extras"):
			continue
		var x: Dictionary = m.get_meta("extras")
		if String(x.get("obc", "")) == "obc_a465045101_a465" and int(x.get("obc_var", 0)) == 1:
			mi.visible = false
			n_hidden += 1
	if n_hidden == 0:
		push_warning("CityTrees: found none of the exported trees to replace")


func _materials() -> void:
	bark_m = ShaderMaterial.new()
	bark_m.shader = load("res://levels/shaders/tree_bark.gdshader")
	var leaves: Shader = load("res://levels/shaders/tree_leaves.gdshader")
	broad_m = ShaderMaterial.new()      # the street trees: blue-black green, a muted sage where the lamps catch them, some with a slate-violet cast
	broad_m.shader = leaves
	broad_m.set_shader_parameter(&"leaf_kind", 0)
	broad_m.set_shader_parameter(&"cells", 4.0)
	broad_m.set_shader_parameter(&"col_dark", Color8(8, 20, 25))
	broad_m.set_shader_parameter(&"col_light", Color8(30, 68, 62))
	broad_m.set_shader_parameter(&"col_tip", Color8(88, 136, 112))
	broad_m.set_shader_parameter(&"col_alt", Color8(36, 42, 62))
	broad_m.set_shader_parameter(&"fill", 0.34)      # (lifted from 0.13: there they were black cut-outs away from a lamp)
	fan_m = ShaderMaterial.new()      # the columnar trees: fan leaves, dark olive turning old gold at the tips, some gone dusty mauve
	fan_m.shader = leaves
	fan_m.set_shader_parameter(&"leaf_kind", 1)
	fan_m.set_shader_parameter(&"cells", 4.5)
	fan_m.set_shader_parameter(&"col_dark", Color8(14, 22, 17))
	fan_m.set_shader_parameter(&"col_light", Color8(62, 78, 44))
	fan_m.set_shader_parameter(&"col_tip", Color8(156, 138, 62))
	fan_m.set_shader_parameter(&"col_alt", Color8(74, 52, 62))
	fan_m.set_shader_parameter(&"fill", 0.34)
	shrub_m = ShaderMaterial.new()      # the shrubs: dark glossy green, some of them wine-red
	shrub_m.shader = leaves
	shrub_m.set_shader_parameter(&"leaf_kind", 0)
	shrub_m.set_shader_parameter(&"cells", 5.0)
	shrub_m.set_shader_parameter(&"col_dark", Color8(7, 16, 15))
	shrub_m.set_shader_parameter(&"col_light", Color8(32, 72, 54))
	shrub_m.set_shader_parameter(&"col_tip", Color8(88, 128, 96))
	shrub_m.set_shader_parameter(&"col_alt", Color8(96, 24, 48))
	shrub_m.set_shader_parameter(&"fill", 0.34)
	shrub_m.set_shader_parameter(&"flutter", 0.012)


## All the trees of one shape in one MultiMesh: turned, sized and tinted each on its own.
func _plant(mesh: ArrayMesh, at: Array, nm: String, s0: float, s1: float, shadows: bool) -> void:
	if at.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = at.size()
	for i in at.size():
		var p: Vector3 = at[i]
		var h := _hash(p.x * 1.7, p.z * 0.9)
		var h2 := _hash(p.z * 2.3, p.x * 1.3)
		var s := lerpf(s0, s1, h2)
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, h * TAU).scaled(Vector3(s, s, s)), p))
		mm.set_instance_custom_data(i, Color(_hash(p.x * 3.1, p.z * 0.7), lerpf(0.88, 1.12, _hash(p.x, p.z * 5.3)), 0.0, 0.0))
	var mi := MultiMeshInstance3D.new()
	mi.name = nm
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 1.0      # (the wind leans them a little past their box)
	group.add_child(mi)


# ------------------------------------------------------------------ shapes ----

## A street tree: a clear trunk with a flared foot, four or five limbs opening into a wide vase, each carrying flat pads of leaves at different heights, the limbs showing between them.
func _broad_tree(sd: int) -> ArrayMesh:
	var r := RandomNumberGenerator.new()
	r.seed = sd
	var bark := Geo.new()
	var leaf := Geo.new()
	var th := r.randf_range(3.1, 3.6)
	var lean := Vector3(r.randf_range(-0.16, 0.16), 0.0, r.randf_range(-0.16, 0.16))
	var top := Vector3(0.0, th, 0.0) + lean
	_tube(bark, PackedVector3Array([Vector3.ZERO, Vector3(0, 0.2, 0), Vector3(0, 1.0, 0) + lean * 0.25, Vector3(0, 2.2, 0) + lean * 0.65, top]), PackedFloat32Array([0.40, 0.24, 0.20, 0.18, 0.165]), 9)
	var clumps: Array = []      # [centre, radius]
	var n := r.randi_range(4, 5)
	var a0 := r.randf() * TAU
	for i in n:
		var a := a0 + TAU * float(i) / float(n) + r.randf_range(-0.3, 0.3)
		var dir := Vector3(cos(a), 0.0, sin(a))
		var reach := r.randf_range(1.7, 2.6)
		var rise := r.randf_range(1.2, 3.3)      # (each limb to its own height: a crown in layers, not one flat table)
		var end := top + dir * reach + Vector3(0.0, rise, 0.0)
		var mid := top + dir * reach * 0.3 + Vector3(0.0, rise * 0.62, 0.0)      # (up first, then out: a vase, not a ball)
		var pts := _bezier(top - Vector3(0, 0.2, 0), mid, end, 7)
		_tube(bark, pts, _taper(pts.size(), 0.125, 0.03), 7)
		clumps.append([end + Vector3(0, 0.2, 0), r.randf_range(1.15, 1.5)])
		# two twigs off the limb, one each way round, carrying smaller pads lower down: the layers
		for sg: float in [-1.0, 1.0]:
			var from := pts[2 + (1 if sg > 0.0 else 2)]
			var side := Vector3(cos(a + sg * 0.9), 0.0, sin(a + sg * 0.9))
			var tend := from + side * r.randf_range(0.9, 1.5) + Vector3(0.0, r.randf_range(0.5, 1.2), 0.0)
			var tp := _bezier(from, from + side * 0.35 + Vector3(0, 0.45, 0), tend, 4)
			_tube(bark, tp, _taper(tp.size(), 0.055, 0.018), 5)
			clumps.append([tend + Vector3(0, 0.15, 0), r.randf_range(0.8, 1.05)])
	var lead := _bezier(top, top + Vector3(0, 1.5, 0), Vector3(r.randf_range(-0.4, 0.4), th + 4.0, r.randf_range(-0.4, 0.4)), 5)
	_tube(bark, lead, _taper(lead.size(), 0.11, 0.03), 6)
	clumps.append([lead[lead.size() - 1] + Vector3(0, 0.3, 0), r.randf_range(1.35, 1.65)])
	_crown(leaf, clumps, r, 90.0, 0.5, 0.8, 0.72)
	var m := ArrayMesh.new()
	bark.add_to(m, bark_m)
	leaf.add_to(m, broad_m)
	return m


## A planter's tree: a straight stem, short branches climbing it, a tall narrow crown of stacked clumps.
func _column_tree(sd: int) -> ArrayMesh:
	var r := RandomNumberGenerator.new()
	r.seed = sd
	var bark := Geo.new()
	var leaf := Geo.new()
	var h := r.randf_range(6.2, 6.9)
	var stem := PackedVector3Array()
	for i in 7:
		var y := h * float(i) / 6.0
		stem.append(Vector3(sin(y * 1.3 + sd) * 0.05, y, cos(y * 1.1 + sd) * 0.05))
	_tube(bark, stem, _taper(stem.size(), 0.17, 0.035), 7)
	var clumps: Array = []
	var nb := 8
	for i in nb:
		var y := lerpf(1.7, h - 0.6, float(i) / float(nb - 1))
		var a := float(i) * 2.4 + r.randf_range(-0.3, 0.3)
		var dir := Vector3(cos(a), 0.0, sin(a))
		var ln := lerpf(1.0, 0.45, float(i) / float(nb - 1))
		var base := Vector3(0.0, y, 0.0)
		var end := base + dir * ln + Vector3(0.0, ln * 0.9, 0.0)
		var bp := _bezier(base, base + dir * ln * 0.4 + Vector3(0, 0.15, 0), end, 4)
		_tube(bark, bp, _taper(bp.size(), 0.05, 0.015), 5)
		clumps.append([end, lerpf(1.05, 0.6, float(i) / float(nb - 1)) * r.randf_range(0.9, 1.1)])
	for i in 5:      # the column itself, so the crown is solid down its middle
		var y := lerpf(2.4, h + 0.2, float(i) / 4.0)
		clumps.append([Vector3(0.0, y, 0.0), lerpf(1.2, 0.55, float(i) / 4.0)])
	_crown(leaf, clumps, r, 100.0, 0.42, 0.62, 0.85)
	var m := ArrayMesh.new()
	bark.add_to(m, bark_m)
	leaf.add_to(m, fan_m)
	return m


## A shrub: a few low clumps of leaf cards (no wood shows).
func _shrub(sd: int) -> ArrayMesh:
	var r := RandomNumberGenerator.new()
	r.seed = sd
	var leaf := Geo.new()
	var clumps: Array = []
	var n := r.randi_range(3, 4)
	for i in n:
		var a := TAU * float(i) / float(n) + r.randf_range(-0.4, 0.4)
		clumps.append([Vector3(cos(a) * 0.22, r.randf_range(0.3, 0.5), sin(a) * 0.22), r.randf_range(0.32, 0.42)])
	clumps.append([Vector3(0.0, 0.55, 0.0), 0.38])
	_crown(leaf, clumps, r, 44.0, 0.34, 0.5)
	var m := ArrayMesh.new()
	leaf.add_to(m, shrub_m)
	return m


static func _bezier(a: Vector3, b: Vector3, c: Vector3, n: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in n:
		var t := float(i) / float(n - 1)
		out.append(a.lerp(b, t).lerp(b.lerp(c, t), t))
	return out


static func _taper(n: int, r0: float, r1: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in n:
		out.append(lerpf(r0, r1, pow(float(i) / float(n - 1), 0.8)))
	return out


## A limb: rings along the points (frames carried along, so it does not twist), capped to a point at the end.
static func _tube(g: Geo, pts: PackedVector3Array, rad: PackedFloat32Array, sides: int) -> void:
	var base := g.v.size()
	var t0 := (pts[1] - pts[0]).normalized()
	var ref := Vector3.RIGHT if absf(t0.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var n1 := t0.cross(ref).normalized()
	var along := 0.0
	var rings := pts.size()
	for i in rings:
		var t: Vector3
		if i == 0:
			t = (pts[1] - pts[0]).normalized()
		elif i == rings - 1:
			t = (pts[i] - pts[i - 1]).normalized()
		else:
			t = (pts[i + 1] - pts[i - 1]).normalized()
		n1 = (n1 - t * n1.dot(t)).normalized()
		var n2 := t.cross(n1)
		if i > 0:
			along += pts[i].distance_to(pts[i - 1])
		for j in sides + 1:
			var a := TAU * float(j) / float(sides)
			var d := n1 * cos(a) + n2 * sin(a)
			g.v.append(pts[i] + d * rad[i])
			g.n.append(d)
			g.uv.append(Vector2(float(j) / float(sides), along))
			g.col.append(Color(1, 1, 1, 1))
	for i in rings - 1:
		for j in sides:
			var a := base + i * (sides + 1) + j
			var b := a + sides + 1
			g.idx.append_array(PackedInt32Array([a, b, a + 1, a + 1, b, b + 1]))
	# the tip
	var tip := g.v.size()
	var tdir := (pts[rings - 1] - pts[rings - 2]).normalized()
	g.v.append(pts[rings - 1] + tdir * rad[rings - 1] * 2.0)
	g.n.append(tdir)
	g.uv.append(Vector2(0.5, along + rad[rings - 1] * 2.0))
	g.col.append(Color(1, 1, 1, 1))
	var last := base + (rings - 1) * (sides + 1)
	for j in sides:
		g.idx.append_array(PackedInt32Array([last + j, tip, last + j + 1]))


## Leaf cards over clumps [centre, radius]: mostly in each clump's outer shell, facing out, their normals bent round the whole crown so it shades as one soft mass.
## density: cards per square metre of clump surface / (4 pi); s0..s1: card size; flat: a clump's height over its width (under 1: a pad, not a ball).
static func _crown(g: Geo, clumps: Array, r: RandomNumberGenerator, density: float, s0: float, s1: float, flat: float = 1.0) -> void:
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for c: Array in clumps:
		var p: Vector3 = c[0]
		var rr: float = c[1]
		lo = lo.min(p - Vector3(rr, rr * flat, rr))
		hi = hi.max(p + Vector3(rr, rr * flat, rr))
	var ctr := (lo + hi) * 0.5
	var half := (hi - lo) * 0.5
	for c: Array in clumps:
		var cp: Vector3 = c[0]
		var cr: float = c[1]
		var count := int(density * cr * cr)
		for k in count:
			var d := Vector3(r.randfn(), r.randfn() + 0.25, r.randfn()).normalized()
			var dist := cr * (0.35 + 0.65 * sqrt(r.randf()))
			var p := cp + Vector3(d.x, d.y * flat, d.z) * dist
			var outward := ((p - ctr) / half)
			var shell := clampf(outward.length(), 0.0, 1.0)
			# how lit: out in the shell and high up; the core and the underside stay dark
			var shade := clampf(-0.25 + 0.85 * shell * shell + 0.45 * clampf(outward.y * 0.5 + 0.5, 0.0, 1.0), 0.0, 1.0)
			var face := (d * 0.75 + Vector3(r.randfn(), r.randfn(), r.randfn()).normalized() * 0.3).normalized()
			var ref := Vector3.UP if absf(face.y) < 0.9 else Vector3.RIGHT
			var u := face.cross(ref).normalized()
			var w := face.cross(u)
			var rot := r.randf() * TAU
			var uu := u * cos(rot) + w * sin(rot)
			var ww := face.cross(uu)
			var s := r.randf_range(s0, s1) * 0.5
			var cseed := r.randf()
			var flut := r.randf()
			var b := g.v.size()
			var corners := [p - uu * s - ww * s, p + uu * s - ww * s, p + uu * s + ww * s, p - uu * s + ww * s]
			var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
			for q in 4:
				var cv: Vector3 = corners[q]
				g.v.append(cv)
				g.n.append(((cv - ctr) / half).normalized().lerp(d, 0.3).normalized())
				g.uv.append(uvs[q])
				g.col.append(Color(shade, cseed, flut, 1.0))
			g.idx.append_array(PackedInt32Array([b, b + 1, b + 2, b, b + 2, b + 3]))
