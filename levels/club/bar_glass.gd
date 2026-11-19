class_name BarGlass
extends RefCounted
## CLUB 9's glassware: a glass and the drink in it, as one small Node3D (origin at the base), for the bar top, the bartender's hands, the menu's preview stage and Prog's hand.
## Meshes and materials are made once (warm(), at the club's load) and shared; a drink's liquid is its own material per colour, also made at load.

const KINDS := {
	# kind: [top radius, bottom radius, height, liquid height share, stem height]
	"shot": [0.022, 0.018, 0.06, 0.75, 0.0],
	"tumbler": [0.042, 0.036, 0.09, 0.7, 0.0],
	"pint": [0.045, 0.034, 0.16, 0.85, 0.0],
	"coupe": [0.055, 0.012, 0.045, 0.8, 0.08],
	"beaker": [0.038, 0.038, 0.12, 0.6, 0.0],
	"can": [0.033, 0.033, 0.12, 0.0, 0.0],
}

static var _glass_m: StandardMaterial3D = null
static var _stem_m: StandardMaterial3D = null
static var _liquid_m: Dictionary = {}       # colour -> material
static var _meshes: Dictionary = {}
static var _can_m: StandardMaterial3D = null      # the FOINT LITE LAGER label, the same can Prog's apartment is littered with
static var _can_end_m: StandardMaterial3D = null
const CAN_LABEL := "res://assets/levels/_tex/a1fd10e53d114053_256x128.jpg"      # the apartment export's "beer can" texture (JS levels/apartment/props.js canLabel)


## Materials for the glass and every colour the bar pours (called at load, so nothing compiles mid-play).
static func warm(colors: Array) -> void:
	if _glass_m == null:
		_glass_m = StandardMaterial3D.new()
		_glass_m.albedo_color = Color(0.8, 0.86, 0.95, 0.22)
		_glass_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glass_m.roughness = 0.05
		_glass_m.metallic = 0.2
		_glass_m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_glass_m.rim_enabled = true
		_glass_m.rim = 0.6
		_stem_m = StandardMaterial3D.new()
		_stem_m.albedo_color = Color(0.85, 0.9, 1.0, 0.4)
		_stem_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_stem_m.roughness = 0.1
		_can_m = StandardMaterial3D.new()
		_can_m.albedo_texture = load(CAN_LABEL) as Texture2D
		_can_m.roughness = 0.55
		_can_m.metallic = 0.25
		_can_end_m = StandardMaterial3D.new()
		_can_end_m.albedo_color = Color.hex(0xb9c2c8ff)      # the label's own silver
		_can_end_m.roughness = 0.4
		_can_end_m.metallic = 0.6
	for c: int in colors:
		liquid(c)


static func liquid(c: int) -> StandardMaterial3D:
	if _liquid_m.has(c):
		return _liquid_m[c]
	var col := Color.hex((c << 8) | 0xff)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(col.r, col.g, col.b, 0.86)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 0.9      # club drinks glow a little under the black lights
	m.roughness = 0.15
	_liquid_m[c] = m
	return m


static func _mesh(key: String, top: float, bottom: float, h: float, caps: bool) -> CylinderMesh:
	if _meshes.has(key):
		return _meshes[key]
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = 14
	m.rings = 1
	m.cap_top = caps
	m.cap_bottom = true
	_meshes[key] = m
	return m


## The apartment's can: a 12-sided cylinder whose side carries the label once round (u) and top to bottom (v), as three.js mapped it
## (a CylinderMesh squeezes its side into part of the UV square), with plain silver ends.
static func _can_mesh(r: float, h: float) -> ArrayMesh:
	if _meshes.has("can_label"):
		return _meshes["can_label"]
	const SEG := 12
	var side := SurfaceTool.new()
	side.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in SEG + 1:
		var a := TAU * float(i) / SEG
		var n := Vector3(sin(a), 0.0, cos(a))
		for top: int in [1, 0]:
			side.set_normal(n)
			side.set_uv(Vector2(float(i) / SEG, 1.0 - float(top)))
			side.add_vertex(Vector3(n.x * r, (float(top) - 0.5) * h, n.z * r))
	for i in SEG:
		var b := i * 2
		side.add_index(b); side.add_index(b + 2); side.add_index(b + 1)
		side.add_index(b + 1); side.add_index(b + 2); side.add_index(b + 3)
	var m := side.commit()
	m.surface_set_material(0, _can_m)
	var ends := SurfaceTool.new()
	ends.begin(Mesh.PRIMITIVE_TRIANGLES)
	for top: int in [1, 0]:
		var y := (float(top) - 0.5) * h
		var up := Vector3.UP if top == 1 else Vector3.DOWN
		for i in SEG:
			var a0 := TAU * float(i) / SEG
			var a1 := TAU * float(i + 1) / SEG
			var p0 := Vector3(sin(a0) * r, y, cos(a0) * r)
			var p1 := Vector3(sin(a1) * r, y, cos(a1) * r)
			ends.set_normal(up)
			for v: Vector3 in ([Vector3(0.0, y, 0.0), p1, p0] if top == 1 else [Vector3(0.0, y, 0.0), p0, p1]):
				ends.add_vertex(v)
	ends.commit(m)
	m.surface_set_material(1, _can_end_m)
	_meshes["can_label"] = m
	return m


## A glass of kind (KINDS) with a drink of colour c in it, full.
static func make(kind: String, c: int) -> Node3D:
	warm([])
	var k: Array = KINDS.get(kind, KINDS["tumbler"])
	var root := Node3D.new()
	root.name = "Glass_" + kind
	var stem := float(k[4])
	if stem > 0.0:
		var st := MeshInstance3D.new()
		st.mesh = _mesh("stem", 0.005, 0.005, stem, true)
		st.material_override = _stem_m
		st.position.y = stem * 0.5
		root.add_child(st)
		var foot := MeshInstance3D.new()
		foot.mesh = _mesh("foot", 0.03, 0.032, 0.006, true)
		foot.material_override = _stem_m
		foot.position.y = 0.003
		root.add_child(foot)
	var g := MeshInstance3D.new()
	g.name = "glass"
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if kind == "can":      # FOINT LIGHT comes in the apartment's FOINT LITE LAGER can (was a plain amber cylinder in the drink's colour)
		g.mesh = _can_mesh(float(k[0]), float(k[2]))
	else:
		g.mesh = _mesh(kind, k[0], k[1], k[2], false)
		g.material_override = _glass_m
	g.position.y = stem + float(k[2]) * 0.5
	root.add_child(g)
	if float(k[3]) > 0.0:
		var lq := MeshInstance3D.new()
		lq.name = "liquid"
		var lh := float(k[2]) * float(k[3])
		var r_top := lerpf(float(k[1]), float(k[0]), float(k[3])) * 0.92
		lq.mesh = _mesh("%s_liquid" % kind, r_top, float(k[1]) * 0.92, lh, true)
		lq.material_override = liquid(c)
		lq.set_meta(&"h", lh)
		lq.set_meta(&"base", stem + 0.004)
		lq.position.y = stem + 0.004 + lh * 0.5
		root.add_child(lq)
	return root


## How full (0..1): the liquid sinks from the top.
static func set_fill(g: Node3D, f: float) -> void:
	var lq := g.get_node_or_null(^"liquid") as MeshInstance3D
	if lq == null:
		return
	f = clampf(f, 0.0, 1.0)
	lq.visible = f > 0.02
	var h: float = lq.get_meta(&"h")
	lq.scale.y = maxf(f, 0.02)
	lq.position.y = float(lq.get_meta(&"base")) + h * f * 0.5
