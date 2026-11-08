class_name ArmorFigure
extends RefCounted
## The fitting bay's procedural figure (JS buildArmorFigure), about 1.8 m tall, facing +Z, feet at y = 0. Only the STANDARD OUTFIT reaches this in the menus, since every other suit is shown on the real Prog and Tommy; the pedestal's holograms in the hub come through the level export. So the body and the standard gear are here, and the other suits' gear blocks are not.


static func _m(col: int, r: float, m: float, e: int = 0, ei: float = 1.0) -> StandardMaterial3D:
	var t := StandardMaterial3D.new()
	t.albedo_color = VendorStage._hex(col)
	t.roughness = r
	t.metallic = m
	t.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX if false else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	if e != 0:
		t.emission_enabled = true
		t.emission = VendorStage._hex(e)
		t.emission_energy_multiplier = ei
	return t


static func _add(par: Node3D, mesh: Mesh, mat: Material, p: Vector3, rot: Vector3 = Vector3.ZERO, sc: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var o := MeshInstance3D.new()
	o.mesh = mesh
	o.material_override = mat
	o.position = p
	o.rotation = rot
	o.scale = sc
	par.add_child(o)
	return o


static func _grp(par: Node3D, p: Vector3, rot: Vector3 = Vector3.ZERO) -> Node3D:
	var g := Node3D.new()
	g.position = p
	g.rotation = rot
	par.add_child(g)
	return g


static func _cap(r: float, l: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = l + r * 2.0
	c.radial_segments = 8
	c.rings = 2
	return c


static func build(id: String) -> Node3D:
	var root := Node3D.new()
	root.name = "armor-figure:" + id
	# LOOK.standard
	var suit := _m(0x3b4553, 0.8, 0.05)
	var dark := _m(0x1d2229, 0.7, 0.2)
	var trim := _m(0x8d99a8, 0.4, 0.6)
	var lit := _m(0x7fd6ff, 0.3, 0.1, 0x7fd6ff, 1.6)
	var K := 1.0
	var Cy := func(a: float, b: float, h: float, s: int = 8) -> CylinderMesh: return MsKit.cyl(a, b, h, s)
	var S := func(r: float, w: int = 10, h: int = 7) -> SphereMesh: return MsKit.sphere(r, w, h)
	# ---- body (A-pose) ----
	_add(root, Cy.call(0.15, 0.17, 0.17), suit, Vector3(0, 0.95, 0), Vector3.ZERO, Vector3(1, 1, 0.75))      # pelvis
	_add(root, Cy.call(0.135, 0.15, 0.18), suit, Vector3(0, 1.09, 0), Vector3.ZERO, Vector3(1, 1, 0.7))      # abdomen
	_add(root, Cy.call(0.2 * K, 0.155, 0.32), suit, Vector3(0, 1.31, 0), Vector3(0, PI / 8.0, 0), Vector3(1, 1, 0.66))
	_add(root, Cy.call(0.05, 0.058, 0.1), dark, Vector3(0, 1.51, 0))      # neck
	_add(root, S.call(0.108, 12, 9), suit, Vector3(0, 1.635, 0.005), Vector3.ZERO, Vector3(1, 1.1, 1.05))
	var fas: Array[Node3D] = []
	for s: float in [1.0, -1.0]:
		var sh := _grp(root, Vector3(s * 0.235 * K, 1.43, 0), Vector3(0, 0, s * 0.2))
		_add(sh, S.call(0.068, 8, 6), suit, Vector3.ZERO)
		_add(sh, _cap(0.054, 0.2), suit, Vector3(0, -0.15, 0))
		var fa := _grp(sh, Vector3(0, -0.29, 0), Vector3(-0.16, 0, s * 0.05))
		_add(fa, S.call(0.052, 8, 6), dark, Vector3.ZERO)      # elbow
		_add(fa, _cap(0.05, 0.2), suit, Vector3(0, -0.13, 0))
		_add(fa, MsKit.box(0.075, 0.09, 0.1), dark, Vector3(0, -0.3, 0.005))      # glove
		fas.append(fa)
		var lg := _grp(root, Vector3(s * 0.098, 0.92, 0), Vector3(0, 0, s * 0.035))
		_add(lg, _cap(0.074, 0.25), suit, Vector3(0, -0.2, 0))
		var sn := _grp(lg, Vector3(0, -0.41, 0), Vector3(0.02, 0, -s * 0.03))
		_add(sn, S.call(0.066, 8, 6), dark, Vector3(0, 0, 0.005))      # knee
		_add(sn, _cap(0.06, 0.27), suit, Vector3(0, -0.2, 0))
		_add(sn, MsKit.box(0.11, 0.075, 0.23), dark, Vector3(0, -0.45, 0.04))      # boot
	# ---- standard gear ----
	_add(root, Cy.call(0.165, 0.165, 0.05, 10), trim, Vector3(0, 1.01, 0), Vector3.ZERO, Vector3(1, 1, 0.76))      # belt
	for s: float in [1.0, -1.0]:
		_add(root, MsKit.box(0.035, 0.36, 0.012), trim, Vector3(s * 0.07, 1.3, 0.125), Vector3(0, 0, s * 0.32))      # chest straps
	_add(root, MsKit.box(0.1, 0.07, 0.03), dark, Vector3(0.06, 1.0, 0.13))      # belt pouch
	_add(root, Cy.call(0.07, 0.075, 0.035), trim, Vector3(0, 1.475, 0))      # collar
	_add(root, MsKit.box(0.17, 0.035, 0.03), lit, Vector3(0, 1.655, 0.1))      # eye band
	for fa: Node3D in fas:
		_add(fa, Cy.call(0.058, 0.058, 0.04), trim, Vector3(0, -0.22, 0))      # cuffs
	return root
