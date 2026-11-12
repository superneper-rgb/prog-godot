class_name DeckUnderside
extends RefCounted
## THE DECK's underside, the face the Underline stands under: longitudinal stringers that turn the ribs into a coffered grid, conduit bundles hung on straps from every rib,
## sagging cable runs, a downpipe and wet streaks on every pier, and the rain running off the slab's edges and through its expansion joints. All of it hangs on the Deck's own
## bays and ribs (levels/hub/deck_look.gd) and the pier colliders, so it lines up with the export. Instanced (one draw per shape) and made at level load.

const Y := DeckLook.Y
const GY := DeckLook.GY
const HW := DeckLook.HW
const RIB_BOT := Y - 2.65          # the transverse ribs' underside (JS: a 0.7 box at Y - 2.3)

var _boxes: Array = []             # [Transform3D, shade]
var _cyls: Array = []
var _cables: Array = []


## A box from its centre and size, along the route (`along` = size along it, `across` = across it)
func _box(r: Dictionary, a: float, off: float, y: float, along: float, across: float, tall: float, shade: float) -> void:
	var p := DeckLook.p_at(r, a, off)
	var s := Vector3(across, tall, along) if r.axis == "z" else Vector3(along, tall, across)
	_boxes.append([Transform3D(Basis.from_scale(s), Vector3(p.x, y, p.y)), shade])


## A cylinder lying along the route from a0 to a1
func _pipe(r: Dictionary, a0: float, a1: float, off: float, y: float, radius: float, shade: float) -> void:
	var p := DeckLook.p_at(r, (a0 + a1) * 0.5, off)
	var b := Basis.from_scale(Vector3(radius * 2.0, a1 - a0, radius * 2.0))
	b = (Basis(Vector3.RIGHT, PI * 0.5) if r.axis == "z" else Basis(Vector3.BACK, PI * 0.5)) * b
	_cyls.append([Transform3D(b, Vector3(p.x, y, p.y)), shade])


func build(look: DeckLook, piers: Array, parent: Node3D) -> void:
	var curtains := SurfaceTool.new()
	curtains.begin(Mesh.PRIMITIVE_TRIANGLES)
	var joints := SurfaceTool.new()
	joints.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stains := SurfaceTool.new()
	stains.begin(Mesh.PRIMITIVE_TRIANGLES)
	var first_bay := {}
	for bay: Array in look.bays:
		var r: Dictionary = bay[0]
		var a0: float = bay[1]
		var a1: float = bay[2]
		var harbor: bool = r.axis == "x"
		# stringers: an I-beam's web and bottom flange either side of centre, under the ribs, so from below the underside is a grid and not a row of bars
		for off: float in [-6.4, -2.1, 2.1, 6.4]:
			_box(r, (a0 + a1) * 0.5, off, RIB_BOT + 0.3, a1 - a0 - 0.2, 0.12, 0.6, 1.0)
			_box(r, (a0 + a1) * 0.5, off, RIB_BOT - 0.05, a1 - a0 - 0.2, 0.46, 0.1, 1.1)
		# the conduit bundle each side, hung on straps from every rib, a coupling at each bay end
		for s: float in [-1.0, 1.0]:
			var bundle := [[3.0, 0.07, -0.42, 0.9], [3.24, 0.1, -0.44, 1.0], [3.5, 0.06, -0.41, 1.15]]
			for c: Array in bundle:
				_pipe(r, a0 + 0.3, a1 - 0.3, s * c[0], RIB_BOT + c[2], c[1], c[3])
			_pipe(r, a0 + 0.1, a0 + 0.45, s * 3.24, RIB_BOT - 0.44, 0.14, 0.8)
			_pipe(r, a1 - 0.45, a1 - 0.1, s * 3.24, RIB_BOT - 0.44, 0.14, 0.8)
		var a := a0 + 2.5
		var prev := -1.0
		while a < a1 - 1.0:
			for s: float in [-1.0, 1.0]:
				_box(r, a, s * 3.24, RIB_BOT - 0.2, 0.05, 0.05, 0.4, 0.9)               # the hanger rod
				_box(r, a, s * 3.24, RIB_BOT - 0.55, 0.08, 0.8, 0.05, 0.9)              # the strap the bundle sits in
				if prev > 0.0:                                                          # a cable sagging from rib to rib
					for off: float in [s * 1.25, s * 4.3]:
						var p0 := DeckLook.p_at(r, prev, off)
						var b := Basis.from_scale(Vector3(1.0, 1.0, a - prev))
						if not r.axis == "z":
							b = Basis(Vector3.UP, PI * 0.5) * b
						_cables.append([Transform3D(b, Vector3(p0.x, RIB_BOT, p0.y)), 1.0 if absf(off) < 2.0 else 0.85])
			prev = a
			a += 5.0
		# the rain off the slab's two edges (not where the Harbor span runs into an avenue: the deck carries on there)
		for s: float in [-1.0, 1.0]:
			var e0 := a0
			var e1 := a1
			if harbor and s > 0.0:
				e0 = maxf(a0, DeckLook.AVENUES[0] + HW)
				e1 = minf(a1, DeckLook.AVENUES[1] - HW)
			if e1 > e0:
				_sheet(curtains, r, e0, e1, s * (HW + 0.04), Y - 0.9, GY)
		# the expansion joint: water through it, across the carriageway (not at a route's first bay: nothing butts on it)
		var key: String = str(r.c) + str(r.axis)
		if first_bay.has(key):
			_sheet_across(joints, r, a0, Y - 2.9, GY)
		first_bay[key] = true
	# the piers: a downpipe on the face toward the road it carries, and the water's streaks down every face
	for pier: Array in piers:
		var px: float = pier[0]
		var pz: float = pier[1]
		var h: float = pier[2]
		var dir: Vector2 = pier[3]
		var top := Y - 2.7
		var o := Vector2(px, pz) + dir * (h + 0.2)
		_cyls.append([Transform3D(Basis.from_scale(Vector3(0.26, top - GY - 0.3, 0.26)), Vector3(o.x, (top + GY + 0.3) * 0.5, o.y)), 1.05])
		_boxes.append([Transform3D(Basis.from_scale(Vector3(0.42, 0.18, 0.42)), Vector3(o.x, GY + 0.2, o.y)), 0.9])      # the shoe it empties from
		var yy := GY + 2.0
		while yy < top - 0.5:
			var bo := Vector2(px, pz) + dir * (h + 0.1)
			var bs := Vector3(0.5 if dir.x == 0.0 else 0.25, 0.08, 0.5 if dir.y == 0.0 else 0.25)
			_boxes.append([Transform3D(Basis.from_scale(bs), Vector3(bo.x, yy, bo.y)), 0.8])
			yy += 3.0
		for f: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			var c := Vector2(px, pz) + f * (h + 0.03)
			var t := Vector2(-f.y, f.x)
			_quad(stains, Vector3(c.x - t.x * h, top, c.y - t.y * h), Vector3(c.x + t.x * h, top, c.y + t.y * h), top - GY, 2.0 * h)

	_add_mm(parent, "DeckSteelBoxes", _box_mesh(), _boxes)
	_add_mm(parent, "DeckSteelPipes", _cyl_mesh(), _cyls)
	_add_mm(parent, "DeckCables", _cable_mesh(), _cables)
	_add_water(parent, "DeckRunoff", curtains, {"columns": 2.2, "density": 0.3, "speed": 7.0, "strength": 0.018, "height": Y - 0.9 - GY})
	_add_water(parent, "DeckJointWater", joints, {"columns": 3.5, "density": 0.25, "speed": 7.5, "strength": 0.03, "height": Y - 2.9 - GY, "tint": Color(0.42, 0.62, 0.95)})
	_add_water(parent, "DeckPierStains", stains, {"columns": 3.0, "density": 0.55, "speed": 0.0, "strength": 0.035, "height": Y - 2.7 - GY})


## a vertical sheet along the route at `off`, from y0 down to y1 (UV in metres: x along, y down)
func _sheet(st: SurfaceTool, r: Dictionary, a0: float, a1: float, off: float, y0: float, y1: float) -> void:
	var p0 := DeckLook.p_at(r, a0, off)
	var p1 := DeckLook.p_at(r, a1, off)
	_quad(st, Vector3(p0.x, y0, p0.y), Vector3(p1.x, y0, p1.y), y0 - y1, a1 - a0, a0)


## a vertical sheet across the route at `a`
func _sheet_across(st: SurfaceTool, r: Dictionary, a: float, y0: float, y1: float) -> void:
	var p0 := DeckLook.p_at(r, a, -(HW - 0.6))
	var p1 := DeckLook.p_at(r, a, HW - 0.6)
	_quad(st, Vector3(p0.x, y0, p0.y), Vector3(p1.x, y0, p1.y), y0 - y1, 2.0 * (HW - 0.6))


## a vertical quad hanging from the top edge a -> b, `tall` down; UV x runs u0 .. u0 + `length`
func _quad(st: SurfaceTool, a: Vector3, b: Vector3, tall: float, length: float, u0 := 0.0) -> void:
	var d := Vector3(0.0, -tall, 0.0)
	var uv := [Vector2(u0, 0.0), Vector2(u0 + length, 0.0), Vector2(u0 + length, tall), Vector2(u0, tall)]
	var v := [a, b, b + d, a + d]
	for i: int in [0, 1, 2, 0, 2, 3]:
		st.set_uv(uv[i])
		st.add_vertex(v[i])


func _box_mesh() -> Mesh:
	var m := BoxMesh.new()
	m.size = Vector3.ONE
	return m


func _cyl_mesh() -> Mesh:
	var m := CylinderMesh.new()
	m.top_radius = 0.5
	m.bottom_radius = 0.5
	m.height = 1.0
	m.radial_segments = 10
	m.rings = 1
	return m


## one cable span: a round tube 1 m long on +Z, hung from its two ends at the origin's height, sagging 0.4 m in the middle
func _cable_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SEGS := 10
	const SIDES := 5
	const R := 0.035
	var rings: Array = []
	for i in SEGS + 1:
		var t := float(i) / SEGS
		var c := Vector3(0.0, -0.4 * 4.0 * t * (1.0 - t), t)
		var ring: Array = []
		for k in SIDES:
			var ang := TAU * k / SIDES
			var n := Vector3(cos(ang), sin(ang), 0.0)
			ring.append([c + n * R, n])
		rings.append(ring)
	for i in SEGS:
		for k in SIDES:
			var k2 := (k + 1) % SIDES
			for q: Array in [rings[i][k], rings[i + 1][k], rings[i + 1][k2], rings[i][k], rings[i + 1][k2], rings[i][k2]]:
				st.set_normal(q[1])
				st.add_vertex(q[0])
	return st.commit()


func _add_mm(parent: Node3D, nm: String, mesh: Mesh, items: Array) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = items.size()
	for i in items.size():
		mm.set_instance_transform(i, items[i][0])
		var s: float = items[i][1]
		mm.set_instance_color(i, Color(s, s, s))
	var mat := ShaderMaterial.new()
	mat.shader = load("res://levels/shaders/deck_steel.gdshader")
	var mi := MultiMeshInstance3D.new()
	mi.name = nm
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


func _add_water(parent: Node3D, nm: String, st: SurfaceTool, params: Dictionary) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://levels/shaders/deck_water.gdshader")
	for k: String in params:
		mat.set_shader_parameter(k, params[k])
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
