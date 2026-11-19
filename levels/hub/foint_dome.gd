class_name FointDomeLife
extends RefCounted
## The FOINT DOME in FOINT CITY: puts the modelled dome in place of the exported one, and runs its animation (the red light breathes, the sign flickers now and then, the lanterns' flames burn, the glows pulse with them, the spire tips' beacons throb and the ring at the gate beats).
## Changed from the port (2026-11-11, user: "far more accurate to the original concept art"): the dome the export carries was flat black sheets with thin amber line-work. The building is now
## its own model, assets/foint_dome/foint_dome.glb, written by tools/dome/build_foint_dome.py to the concept: thick armour plate, recessed red window bands, layered buttresses, a crown of
## leaning fins. Its light is red only, as in the concept. The exported plate, paint, amber, slits, thorn cards, sign card and tip beacons are hidden; the banners, the lantern flames, the four
## glows and the gate ring are still the export's, found by their JS names (DomeBanners, DomeFlames) and their JS colours. The footprint is the old one, so the colliders did not change.

const MODEL := "res://assets/foint_dome/foint_dome.glb"
const PLATE := "res://levels/shaders/foint_dome_plate.gdshader"
const LIGHT := "res://levels/shaders/foint_dome_light.gdshader"
const HIDE: Array[String] = ["DomePlate", "DomePaint", "DomeAmber", "DomeRed", "DomeThorns", "DomeTips"]
const RED_GLOW := Color(0.8, 0.03, 0.08)
const BANNER_TINT := Color(0.5, 0.34, 0.42)      # the exported banner cloth, brought down to the dome's deep crimson (it is unlit, and at full value it outshone the windows)

var plate_m: ShaderMaterial = null
var red_m: ShaderMaterial = null
var sign_m: ShaderMaterial = null
var halo: BaseMaterial3D = null
var crest: BaseMaterial3D = null
var door_glow: BaseMaterial3D = null
var crown_glow: BaseMaterial3D = null
var ring: MeshInstance3D = null
var ring_m: BaseMaterial3D = null
var fire_m: ShaderMaterial = null
var tip_m: ShaderMaterial = null
var _ok := false


## The buttress footings: (angle th, rf, width) as in tools/dome/build_foint_dome.py BUTTRESS_SET (th 0 = +z, PI = the gate), mirrored about the gate, plus the one straight behind.
const FOOTINGS: Array[Vector3] = [Vector3(0.45, 55.0, 5.2), Vector3(0.98, 54.5, 4.4), Vector3(1.5, 55.0, 4.8), Vector3(2.03, 54.5, 4.4), Vector3(2.56, 54.5, 4.4)]
const PLINTH_H := 1.35


## Added 2026-11-16 (user: "foint dome legs lacking proper collision" at 23.8, -10, 212). The export's footing colliders stop at rf, but the model's plinth reaches rf + 0.5 and is a little
## wider, so the player walked into the plinth's front lip and sank into the leg's face. A plinth-sized box under each footing (its own top at the plinth's, so the existing taller
## box over the wedge still does the wedge).
func _footing_plinths(level: ExportedLevel, c: Vector3) -> void:
	if level.world == null:
		return
	var list: Array[Vector2] = []      # (th, rf)
	var widths: Array[float] = []
	for f: Vector3 in FOOTINGS:
		for th: float in [PI - f.x, PI + f.x]:
			list.append(Vector2(th, f.y))
			widths.append(f.z)
	list.append(Vector2(0.0, 55.0))
	widths.append(5.2)
	for i in list.size():
		var th := list[i].x
		var rf := list[i].y
		var rc := rf - 3.15
		var hw := widths[i] / 2.0 + 0.9 + 0.4
		level.world.add({"kind": "box", "cx": c.x + sin(th) * rc, "cz": c.z + cos(th) * rc, "hx": hw, "hz": 3.65, "yaw": th, "bottom": c.y, "top": c.y + PLINTH_H, "tag": "bound"})
	# Added 2026-11-16 (user: no collision at -8.4, -10, 208.9): the gate's two legs (build_gate in the builder) had none. Each gets its blocky foot (|x| 6..11, 2.4 high)
	# and the leg above it (|x| about 6.1..10, up to the sign at 11.3), both centred where the builder extrudes them.
	for s: float in [-1.0, 1.0]:
		level.world.add({"kind": "box", "cx": c.x + s * 8.5, "cz": c.z - 51.4, "hx": 2.5, "hz": 2.15, "bottom": c.y, "top": c.y + 2.4, "tag": "bound"})
		level.world.add({"kind": "box", "cx": c.x + s * 8.05, "cz": c.z - 51.2, "hx": 1.95, "hz": 1.2, "bottom": c.y, "top": c.y + 11.3, "tag": "bound"})


func _init(level: ExportedLevel) -> void:
	var a: Array = level.node_named("FointDome")
	if a.is_empty():
		push_warning("FointDomeLife: no FointDome in the export")
		return
	var dome: Node3D = a[0]
	for nm: String in HIDE:
		for o: Node in level.node_named(nm):
			(o as Node3D).visible = false
	var f := _mesh_under(level, "DomeFlames")
	if f != null:
		fire_m = GlowPoints.replace(f, 3.4)
		fire_m.set_shader_parameter(&"flicker", 1.0)
	for o: Node in level.node_named("DomeBanners"):
		(o as Node3D).position.z -= 1.75      # out to the model's banner arms (the JS hung them 0.4 m off a thinner wall)
	var bn := _mesh_under(level, "DomeBanners")
	if bn != null and bn.get_active_material(0) is BaseMaterial3D:
		(bn.get_active_material(0) as BaseMaterial3D).albedo_color = BANNER_TINT
	# the unnamed ones, by their JS colours (straight children of the dome; the ring sits in a node of its own)
	for c: Node in dome.get_children():
		var mi: MeshInstance3D = c as MeshInstance3D
		if c.get_child_count() == 1 and c.get_child(0) is MeshInstance3D and String(c.name).find("_") < 0:
			mi = c.get_child(0) as MeshInstance3D
		if mi == null:
			continue
		var m := mi.get_active_material(0) as BaseMaterial3D
		if m == null:
			continue
		if _is(m, 0xd41810):
			crown_glow = m
		elif _is(m, 0xff2414):
			door_glow = m
		elif _is(m, 0xff1a12):
			crest = m
			mi.position.z = -4.2      # in front of the model's gable and blades (the JS card stood behind a lower sign block)
		elif _is(m, 0xff7a22):
			halo = m      # the sign's glow: amber in the JS, red here, and in front of the sign
			m.albedo_color = Color(RED_GLOW.r, RED_GLOW.g, RED_GLOW.b, m.albedo_color.a)
			mi.position.z = -4.6
		elif _is(m, 0xffc24a):
			ring = mi      # (the export's node over it carries the JS ring's place and tilt; this one is identity under it, so scaling it is the JS's scale)
			ring_m = m
		elif m.albedo_texture != null and _is(m, 0xffffff) and mi.get_parent() == dome:
			mi.visible = false      # the JS sign card and the thorn crest card: the model has both as armour
	_footing_plinths(level, dome.global_position)
	_build(dome)
	_ok =plate_m != null and red_m != null and sign_m != null and halo != null and crest != null and door_glow != null and crown_glow != null and ring != null
	if not _ok:
		push_warning("FointDomeLife: some of the dome's parts are missing (model %s red %s sign %s halo %s crest %s door %s crown %s ring %s)" % [plate_m != null, red_m != null, sign_m != null, halo != null, crest != null, door_glow != null, crown_glow != null, ring != null])


## The model, under the export's FointDome node (same space: the dome's centre on the street, -z the gate), one material per kind of surface, and the beacons on its spire tips.
func _build(dome: Node3D) -> void:
	var ps := load(MODEL) as PackedScene
	if ps == null:
		push_warning("FointDomeLife: %s is missing (blender --background --python tools/dome/build_foint_dome.py, then node tools/import.mjs)" % MODEL)
		return
	var model: Node3D = ps.instantiate()
	model.name = "Dome_Model"
	plate_m = _mat(PLATE, {})
	var hazard_m := _mat(PLATE, {&"hazard": 1.0})
	red_m = _mat(LIGHT, {})
	sign_m = _mat(LIGHT, {&"gain": 0.55})      # (its own material: it flickers; a little over the windows so the name reads)
	var amber_m := _mat(LIGHT, {&"tint": Color(1.0, 0.5, 0.12), &"hot": Color(1.0, 0.7, 0.36), &"gain": 0.9})
	var by_name := {"dome_plate": plate_m, "dome_hazard": hazard_m, "dome_red": red_m, "dome_sign": sign_m, "dome_amber": amber_m}
	var tips := PackedVector3Array()
	for n: Node in model.find_children("*", "Node3D", true, false):
		var mi := n as MeshInstance3D
		if mi != null:
			var key := String(mi.name).to_lower()
			if by_name.has(key):
				mi.material_override = by_name[key]
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif String(n.name).begins_with("Tip_"):
			tips.append((n as Node3D).position)
	dome.add_child(model)
	if tips.size() > 0:      # the red beacons, as the JS DomeTips points were: one glow a tip
		var arr: Array = []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = tips
		var pm := ArrayMesh.new()
		pm.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arr)
		var pts := MeshInstance3D.new()
		pts.name = "Dome_ModelTips"
		pts.mesh = pm
		var bm := StandardMaterial3D.new()
		bm.albedo_color = Color(1.0, 0.165, 0.118, 0.66)      # JS tipM: 0xff2a1e
		pts.material_override = bm
		model.add_child(pts)
		tip_m = GlowPoints.replace(pts, 4.2)


static func _mat(shader: String, params: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(shader)
	for k: StringName in params:
		m.set_shader_parameter(k, params[k])
	return m


static func _is(m: BaseMaterial3D, hex: int) -> bool:
	var c := Color.hex((hex << 8) | 0xff)
	return absf(m.albedo_color.r - c.r) < 0.004 and absf(m.albedo_color.g - c.g) < 0.004 and absf(m.albedo_color.b - c.b) < 0.004


static func _mesh_under(level: ExportedLevel, js: String) -> MeshInstance3D:
	for o: Node in level.node_named(js):
		for c: Node in o.get_children():
			if c is MeshInstance3D:
				return c
	return null


## JS: upd.push((t) => { ... }), t the district's clock.
func update(t: float) -> void:
	var breathe := 0.82 + 0.18 * sin(t * 1.1)
	if red_m != null:
		red_m.set_shader_parameter(&"level", breathe)
		plate_m.set_shader_parameter(&"level", breathe)      # the red on the plate breathes with the windows that throw it
	if fire_m != null:
		fire_m.set_shader_parameter(&"t", t)      # (each flame's dance is in the shader)
		fire_m.set_shader_parameter(&"size", 3.2 + sin(t * 13.0) * 0.35)
	if sign_m != null:
		sign_m.set_shader_parameter(&"level", 0.94 + 0.06 * sin(t * 2.2) - (0.35 if sin(t * 27.0) * sin(t * 3.1) > 0.86 else 0.0))
	if halo != null:
		halo.albedo_color.a = 0.24 + 0.08 * sin(t * 2.2)
	if crest != null:
		crest.albedo_color.a = 0.28 + 0.1 * breathe
	if door_glow != null:
		door_glow.albedo_color.a = 0.42 + 0.14 * breathe
	if crown_glow != null:
		crown_glow.albedo_color.a = 0.2 + 0.08 * sin(t * 0.7)
	if tip_m != null:
		tip_m.set_shader_parameter(&"opacity", 0.75 + 0.25 * sin(t * 1.6))
	if ring != null:
		ring_m.albedo_color.a = 0.55 + 0.35 * sin(t * 4.0)
		var s := 1.0 + 0.06 * sin(t * 4.0)
		ring.scale = Vector3(s, s, s)
