class_name PalaceCity
extends RefCounted
## What is round the Pervert Palace site in its own level (levels/palace/palace_level.gd): FOINT CITY as it stands at the east quay. The towers are the hub's own footprints and heights (its
## colliders, assets/levels/hub/colliders.json), drawn as boxes under palace_facade.gdshader so the skyline from the crane is the real one; the quay, the road and its lamps at the
## lot's gate; the bay (palace_water.gdshader) with the site's lights laid on it; the hub's own night sky (its NightSky shader on a dome, the violet end of its drift).

const DIR := "res://assets/levels/"
const SKY := "res://levels/shaders/shader_4a3f88.gdshader"
const FACADE := "res://levels/palace/palace_facade.gdshader"
const WATER := "res://levels/palace/palace_water.gdshader"
const WATER_Y := -12.6
const CENTRE := Vector2(161.0, 201.0)
const REACH := 360.0              # towers further than this from the lot are left to the fog

var root: Node3D
var water_mat: ShaderMaterial
var _lights: Array[Vector4] = []


func build(parent: Node3D, world: World) -> void:
	root = Node3D.new()
	root.name = "City"
	parent.add_child(root)
	_sky()
	_water()
	_towers()
	_quay(world)


## A light for the water to carry (x, y, z, warmth 0 cold .. 1 warm). The level adds the site's.
func add_water_light(p: Vector3, warm: float) -> void:
	if _lights.size() < 24:
		_lights.append(Vector4(p.x, p.y, p.z, warm))
		var u := PackedVector4Array()
		u.resize(24)
		for i in _lights.size():
			u[i] = _lights[i]
		water_mat.set_shader_parameter(&"uL", u)
		water_mat.set_shader_parameter(&"uLN", float(_lights.size()))


func _sky() -> void:
	var m := ShaderMaterial.new()
	m.shader = load(SKY)
	m.set_shader_parameter(&"uCenter", Vector3.ZERO)
	var v: Dictionary = HubLevel.VIOLET
	m.set_shader_parameter(&"uHor", v.horizon)
	m.set_shader_parameter(&"uBand", v.band)
	m.set_shader_parameter(&"uZen", v.zenith)
	m.set_shader_parameter(&"uMoonCol", v.moon)
	m.set_shader_parameter(&"uHalo", v.halo)
	m.set_shader_parameter(&"uMoonR", v.moon_r)
	m.set_shader_parameter(&"uCloud", v.cloud)
	m.set_shader_parameter(&"uMoon", Vector3(0.55, 0.32, -0.77).normalized())      # (low over the bay, east of the crane)
	var s := SphereMesh.new()
	s.radius = 900.0
	s.height = 1800.0
	s.radial_segments = 32
	s.rings = 16
	var mi := MeshInstance3D.new()
	mi.name = "NightSky"
	mi.mesh = s
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-100000, -100000, -100000), Vector3(200000, 200000, 200000))
	root.add_child(mi)


func _water() -> void:
	var fn := FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fn.frequency = 0.04
	fn.fractal_octaves = 3
	var nt := NoiseTexture2D.new()
	nt.width = 256
	nt.height = 256
	nt.seamless = true
	nt.noise = fn
	nt.generate_mipmaps = true
	water_mat = ShaderMaterial.new()
	water_mat.shader = load(WATER)
	water_mat.set_shader_parameter(&"noise_tex", nt)
	var pm := PlaneMesh.new()
	pm.size = Vector2(1600.0, 1600.0)
	pm.subdivide_width = 8
	pm.subdivide_depth = 8
	var mi := MeshInstance3D.new()
	mi.name = "Bay"
	mi.mesh = pm
	mi.material_override = water_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(CENTRE.x, WATER_Y, CENTRE.y)
	root.add_child(mi)


## The hub's towers and podiums: every tall box among its colliders near the lot, as a box of lit floors; a red lamp on each tall one's roof
func _towers() -> void:
	var J: Dictionary = ExportedLevel._json(DIR + "hub/colliders.json")
	var boxes: Array = []
	for s: Dictionary in J.get("solids", []):
		if String(s.get("kind", "")) != "box" or String(s.get("tag", "")) != "bound":
			continue
		var top := float(s["top"])
		var bot := float(s["bottom"])
		var hx := float(s["hx"])
		var hz := float(s["hz"])
		if top - bot < 6.0 or hx < 2.0 or hz < 2.0 or top < -2.0:
			continue
		var c := Vector2(float(s["cx"]), float(s["cz"]))
		if c.distance_to(CENTRE) > REACH or c.y < 150.0:      # (the district only: the hub street is far behind the bridge)
			continue
		boxes.append(s)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = PalaceKit.box_mesh()
	mm.instance_count = boxes.size()
	var tops := []
	for i in boxes.size():
		var s: Dictionary = boxes[i]
		var bot := maxf(float(s["bottom"]), -10.2)
		var top := float(s["top"])
		var xf := Transform3D(Basis(Vector3.UP, float(s.get("yaw", 0.0))).scaled(Vector3(float(s["hx"]) * 2.0, top - bot, float(s["hz"]) * 2.0)), Vector3(float(s["cx"]), (bot + top) * 0.5, float(s["cz"])))
		mm.set_instance_transform(i, xf)
		mm.set_instance_custom_data(i, Color(fposmod(float(s["cx"]) * 0.137 + float(s["cz"]) * 0.071, 1.0), 0, 0, 0))
		if top > 30.0:
			tops.append(Vector3(float(s["cx"]), top + 0.4, float(s["cz"])))
	var fm := ShaderMaterial.new()
	fm.shader = load(FACADE)
	var mi := MultiMeshInstance3D.new()
	mi.name = "Towers"
	mi.multimesh = mm
	mi.material_override = fm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	if not tops.is_empty():
		var bm := MultiMesh.new()
		bm.transform_format = MultiMesh.TRANSFORM_3D
		bm.mesh = PalaceKit.ball_mesh(0.35)
		bm.instance_count = tops.size()
		for i in tops.size():
			bm.set_instance_transform(i, Transform3D(Basis(), tops[i]))
		var bi := MultiMeshInstance3D.new()
		bi.name = "RoofBeacons"
		bi.multimesh = bm
		bi.material_override = PalaceKit.glow(Color(1.0, 0.08, 0.05), 9.0)
		bi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(bi)


## The east quay at the lot: its pavement and railing (open at the gate), the road behind, two lamps; walls keep the player to the pavement by the gate
func _quay(world: World) -> void:
	var b := UfBuild.new(world)
	b.base_y = -10.0
	b.tex("pave", "concrete_floor_worn_001", {"tile": 2.5, "tint": Color(0.28, 0.27, 0.31), "puddles": 1.0, "growth": 0.0})
	b.tex("road", "concrete_floor_worn_001", {"tile": 4.0, "tint": Color(0.12, 0.115, 0.14), "puddles": 1.0, "growth": 0.0})
	b.mat("rail", Color(0.16, 0.16, 0.19), {"rough": 0.4, "metal": 0.7})
	b.mat("kerb", Color(0.3, 0.29, 0.33), {"rough": 0.8})
	b.mats["lamp"] = PalaceKit.glow(Color(0.82, 0.7, 1.0), 6.0)
	b.box("pave", 127.0, PalaceSite.LX0, -11.0, -10.0, 150.0, 252.0)
	b.box("road", 112.0, 127.0, -11.15, -10.15, 150.0, 252.0)
	b.box("pave", 100.0, 112.0, -11.0, -10.0, 150.0, 252.0)
	b.box("kerb", 126.85, 127.0, -10.15, -10.0, 150.0, 252.0)
	var gz0 := PalaceSite.GATE_Z - PalaceSite.GATE_W * 0.5
	var gz1 := PalaceSite.GATE_Z + PalaceSite.GATE_W * 0.5
	for seg: Vector2 in [Vector2(150.0, PalaceSite.LZ0), Vector2(PalaceSite.LZ1, 252.0)]:      # the railing where the lot does not meet the quay
		b.box("rail", 129.4, 129.5, -10.0, -8.95, seg.x, seg.y)
		b.box("rail", 129.35, 129.55, -9.05, -8.95, seg.x, seg.y, false)
	for seg: Vector2 in [Vector2(PalaceSite.LZ0, gz0), Vector2(gz1, PalaceSite.LZ1)]:          # along the lot the hoarding is the edge; a low kerb between
		b.box("kerb", 129.4, 129.6, -10.0, -9.8, seg.x, seg.y, false)
	for z: float in [184.0, 218.0]:
		b.box("rail", 125.6, 125.8, -10.0, -4.0, z - 0.1, z + 0.1, false)
		b.box("lamp", 125.2, 126.4, -4.1, -3.85, z - 0.25, z + 0.25, false)
		add_water_light(Vector3(125.8, -4.0, z), 0.15)
	b.commit(root, "_quay")
	# keep him on the pavement by the gate (the road and the far end are scenery here)
	world.add({"kind": "box", "cx": 126.6, "cz": 201.0, "hx": 0.2, "hz": 40.0, "bottom": -10.2, "top": 0.0, "tag": "invisible", "no_cam": true})
	world.add({"kind": "box", "cx": 129.0, "cz": 183.5, "hx": 2.5, "hz": 0.2, "bottom": -10.2, "top": 0.0, "tag": "invisible", "no_cam": true})
	world.add({"kind": "box", "cx": 129.0, "cz": 218.5, "hx": 2.5, "hz": 0.2, "bottom": -10.2, "top": 0.0, "tag": "invisible", "no_cam": true})
