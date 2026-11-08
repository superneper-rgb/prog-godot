class_name DevProps
extends RefCounted
## DEV level shapes + props (JS levels/dev/props.js): definitions, meshes and colliders. A definition: {id, name, note, base [w, h, d] metres, color, col, steps?, parts}. A placed object is scaled by size / base, turned by yaw / pitch / roll (degrees) and, when it is upright and "collide" is on, gets solids in the World. col: box (yaw-turned box), disc (cylinder: spheres and cones use it too), ramp (rising towards local +Z), stairs (N stacked boxes rising towards local +Z), "" (none).

static var SHAPES: Array = [
	{"id": "cube", "name": "CUBE", "note": "box, any X / Y / Z size", "base": [1.0, 1.0, 1.0], "color": "#c9a45c", "col": "box", "kind": "box"},
	{"id": "wall", "name": "WALL", "note": "thin slab", "base": [4.0, 3.0, .25], "color": "#9a8f86", "col": "box", "kind": "box"},
	{"id": "platform", "name": "PLATFORM", "note": "flat slab", "base": [4.0, .3, 4.0], "color": "#6fa38f", "col": "box", "kind": "box"},
	{"id": "sphere", "name": "SPHERE", "note": "collision is a cylinder", "base": [1.0, 1.0, 1.0], "color": "#d0705a", "col": "disc", "kind": "sphere"},
	{"id": "cylinder", "name": "CYLINDER", "note": "round pillar / drum", "base": [1.0, 1.0, 1.0], "color": "#6f9bd0", "col": "disc", "kind": "cylinder"},
	{"id": "cone", "name": "CONE", "note": "collision is a cylinder", "base": [1.0, 1.0, 1.0], "color": "#d09a3e", "col": "disc", "kind": "cone"},
	{"id": "ramp", "name": "RAMP", "note": "rises towards its front (+Z)", "base": [3.0, 2.0, 6.0], "color": "#cf8658", "col": "ramp", "kind": "ramp"},
	{"id": "stairs", "name": "STAIRS", "note": "8 steps, rise towards +Z", "base": [3.0, 2.0, 4.0], "color": "#c2a46f", "col": "stairs", "steps": 8, "kind": "stairs"},
]
static var PROPS: Array = [
	{"id": "crate", "name": "CRATE", "note": "wooden box", "base": [1.0, 1.0, 1.0], "color": "#a9824f", "col": "box", "kind": "crate"},
	{"id": "barrel", "name": "BARREL", "note": "steel drum", "base": [.6, .9, .6], "color": "#2f6fb0", "col": "disc", "kind": "barrel"},
	{"id": "traffic_cone", "name": "TRAFFIC CONE", "note": "orange", "base": [.4, .7, .4], "color": "#ee6a1e", "col": "disc", "kind": "traffic_cone"},
	{"id": "lamp_post", "name": "LAMP POST", "note": "3.4 m, glowing bulb", "base": [.4, 3.4, .4], "color": "#3b4048", "col": "disc", "kind": "lamp_post"},
	{"id": "pillar", "name": "PILLAR", "note": "stone column", "base": [.8, 3.0, .8], "color": "#b9b4aa", "col": "disc", "kind": "pillar"},
	{"id": "barrier", "name": "BARRIER", "note": "concrete jersey barrier", "base": [.6, .8, 2.4], "color": "#9b9a96", "col": "box", "kind": "barrier"},
]
# the arms depot vending machines (props/arms_depot.gd): placed like props (one uniform scale); `vendor` marks them so the level lists them for X-to-shop (Shops.depot_shops).
# The machine is built at its feet-on-the-floor origin and lowered by half its height to sit centred like every other definition.
const VENDOR_SCALE := 1.3      # built 1.3x like the implant machine, so they sit right next to the chunky player models
static var VENDORS: Array = _vendors()
static var _wedge: ArrayMesh = null


static func _vendors() -> Array:
	var out: Array = []
	for d: Dictionary in ArmsDepot.DEPOTS:
		var sz: Array = d.size
		out.append({"id": d.id, "name": d.name, "note": d.note, "base": [float(sz[0]) * VENDOR_SCALE, float(sz[1]) * VENDOR_SCALE, float(sz[2]) * VENDOR_SCALE], "color": "#b5131f" if d.brand == "foint" else "#d8a845", "col": "box", "kind": "vendor", "vendor": true, "size0": sz})
	return out


static func find_def(cat: String, id: String) -> Variant:
	for d: Dictionary in (SHAPES if cat == "shape" else (PROPS if cat == "prop" else (VENDORS if cat == "vendor" else []))):
		if d.id == id:
			return d
	return null


static func _lam(c: Variant) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c)
	m.roughness = 1.0
	m.metallic_specular = 0.0
	return m


static func _mesh(g: Node3D, mesh: Mesh, mat: Material, x: float = 0.0, y: float = 0.0, z: float = 0.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = Vector3(x, y, z)
	g.add_child(m)
	return m


static func _wedge_mesh() -> ArrayMesh:      # unit ramp: low edge at z = -0.5, high edge (full height) at z = +0.5
	if _wedge != null:
		return _wedge
	var a := Vector3(-.5, -.5, -.5)
	var b := Vector3(.5, -.5, -.5)
	var c := Vector3(.5, -.5, .5)
	var d := Vector3(-.5, -.5, .5)
	var e := Vector3(-.5, .5, .5)
	var f := Vector3(.5, .5, .5)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for t: Array in [[a, c, b], [a, d, c], [d, f, c], [d, e, f], [a, b, f], [a, f, e], [b, c, f], [a, e, d]]:      # (Godot winds the other way round)
		st.add_vertex(t[0])
		st.add_vertex(t[1])
		st.add_vertex(t[2])
	st.generate_normals()
	_wedge = st.commit()
	return _wedge


## a placed object's visual: built at base size, scaled to size
static func build_object(def: Dictionary, color: String, size: Vector3) -> Node3D:
	var root := Node3D.new()
	var g := Node3D.new()
	root.add_child(g)
	var cm := _lam(color)
	match String(def.kind):
		"box":
			_mesh(g, MsKit.box(1, 1, 1), cm)
		"sphere":
			_mesh(g, MsKit.sphere(.5, 28, 18), cm)
		"cylinder":
			_mesh(g, MsKit.cyl(.5, .5, 1.0, 28), cm)
		"cone":
			_mesh(g, MsKit.cyl(0.0, .5, 1.0, 28), cm)
		"ramp":
			var rm := _lam(color)
			rm.cull_mode = BaseMaterial3D.CULL_DISABLED
			_mesh(g, _wedge_mesh(), rm)
		"stairs":
			for i in 8:
				var h := (i + 1) / 8.0
				_mesh(g, MsKit.box(1, h, 1.0 / 8.0), cm, 0, -.5 + h / 2.0, -.5 + (i + .5) / 8.0)
		"crate":
			_mesh(g, MsKit.box(1, 1, 1), cm)
			var d := _lam("#6e5230")
			for q: Array in [[-.46, -.46], [.46, -.46], [-.46, .46], [.46, .46]]:
				_mesh(g, MsKit.box(.1, 1.02, .1), d, q[0], 0, q[1])
		"barrel":
			_mesh(g, MsKit.cyl(.3, .3, .9, 20), cm)
			var d := _lam("#1a2a3c")
			for y: float in [-.27, .27]:
				_mesh(g, MsKit.torus(.3, .02, 24, 6), d, 0, y, 0)
		"traffic_cone":
			_mesh(g, MsKit.box(.4, .05, .4), _lam("#22262b"), 0, -.325, 0)
			_mesh(g, MsKit.cyl(0.0, .17, .6, 18), cm)
			_mesh(g, MsKit.cyl(.1, .12, .07, 18), _lam("#f2f2f2"), 0, .03, 0)
		"lamp_post":
			_mesh(g, MsKit.cyl(.2, .22, .12, 14), cm, 0, -1.64, 0)
			_mesh(g, MsKit.cyl(.06, .08, 3.2, 12), cm, 0, -.04, 0)
			_mesh(g, MsKit.sphere(.17, 14, 10), VhKit.unlit(0xffe9a8, 1.0), 0, 1.52, 0)
		"pillar":
			_mesh(g, MsKit.cyl(.34, .36, 3.0, 20), cm)
			_mesh(g, MsKit.box(.8, .2, .8), cm, 0, -1.4, 0)
			_mesh(g, MsKit.box(.8, .2, .8), cm, 0, 1.4, 0)
		"barrier":
			_mesh(g, MsKit.box(.6, .35, 2.4), cm, 0, -.225, 0)
			_mesh(g, MsKit.box(.32, .45, 2.4), cm, 0, .175, 0)
		"vendor":
			var m := ArmsDepot.build(def.id)
			m.scale = Vector3.ONE * VENDOR_SCALE
			m.position.y = -float(def.size0[1]) * VENDOR_SCALE / 2.0
			g.add_child(m)
	root.scale = Vector3(size.x / float(def.base[0]), size.y / float(def.base[1]), size.z / float(def.base[2]))
	return root


## collider specs (World.add arguments) for an upright object centred at (x, y, z)
static func colliders(def: Dictionary, x: float, y: float, z: float, yaw_deg: float, size: Vector3) -> Array:
	var yaw := deg_to_rad(yaw_deg)
	var y0 := y - size.y / 2.0
	var c := cos(yaw)
	var s := sin(yaw)
	match String(def.col):
		"box":
			return [{"kind": "box", "cx": x, "cz": z, "hx": size.x / 2.0, "hz": size.z / 2.0, "yaw": yaw, "bottom": y0, "top": y0 + size.y, "tag": "dev"}]
		"disc":
			return [{"kind": "disc", "cx": x, "cz": z, "r": maxf(size.x, size.z) / 2.0, "bottom": y0, "top": y0 + size.y, "tag": "dev"}]
		"ramp":
			return [{"kind": "ramp", "cx": x, "cz": z, "hx": size.x / 2.0, "hz": size.z / 2.0, "yaw": yaw, "bottom": y0, "top_low": y0, "top": y0 + size.y, "tag": "dev"}]
		"stairs":
			var n: int = def.steps
			var dz := size.z / n
			var out: Array = []
			for i in n:
				var b := -size.z / 2.0 + dz * (i + .5)
				out.append({"kind": "box", "cx": x + b * s, "cz": z + b * c, "hx": size.x / 2.0, "hz": dz / 2.0, "yaw": yaw, "bottom": y0, "top": y0 + (i + 1) * size.y / n, "tag": "dev"})
			return out
	return []


## how far the object reaches from its centre along a world direction n (unit), for resting it against a surface
static func reach_along(size: Vector3, yaw_deg: float, n: Vector3) -> float:
	var yaw := deg_to_rad(yaw_deg)
	var c := absf(cos(yaw))
	var s := absf(sin(yaw))
	var ex := c * size.x / 2.0 + s * size.z / 2.0
	var ez := s * size.x / 2.0 + c * size.z / 2.0
	return absf(n.x) * ex + absf(n.y) * size.y / 2.0 + absf(n.z) * ez
