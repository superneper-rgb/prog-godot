class_name FointDomeLife
extends RefCounted
## The FOINT DOME's animation (JS levels/hub/foint-arena.js, its update): the red slits breathe, the sign flickers now and then, the lanterns' flames burn, the glows pulse with them, the spire tips' red lights throb and the ring at the gate beats.
## The dome itself comes with the export. Its moving parts are found by their JS names where they have one (DomeRed, DomeFlames, DomeTips) and by their JS colours where they do not (the sign, the four glows, the gate ring).

var red: BaseMaterial3D = null
var sign: BaseMaterial3D = null
var halo: BaseMaterial3D = null
var crest: BaseMaterial3D = null
var door_glow: BaseMaterial3D = null
var crown_glow: BaseMaterial3D = null
var ring: MeshInstance3D = null
var ring_m: BaseMaterial3D = null
var fire_m: ShaderMaterial = null
var tip_m: ShaderMaterial = null
var _ok := false


func _init(level: ExportedLevel) -> void:
	var a: Array = level.node_named("FointDome")
	if a.is_empty():
		push_warning("FointDomeLife: no FointDome in the export")
		return
	var dome: Node3D = a[0]
	red = _mat_under(level, "DomeRed")
	var f := _mesh_under(level, "DomeFlames")
	if f != null:
		fire_m = GlowPoints.replace(f, 3.4)
		fire_m.set_shader_parameter(&"flicker", 1.0)
	var tp := _mesh_under(level, "DomeTips")
	if tp != null:
		tip_m = GlowPoints.replace(tp, 4.2)
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
		elif _is(m, 0xff7a22):
			halo = m
		elif _is(m, 0xffc24a):
			ring = mi      # (the export's node over it carries the JS ring's place and tilt; this one is identity under it, so scaling it is the JS's scale)
			ring_m = m
		elif m.blend_mode == BaseMaterial3D.BLEND_MODE_MIX and m.albedo_texture != null and _is(m, 0xffffff) and mi.get_parent() == dome:
			sign = m
	_ok = red != null and sign != null and halo != null and crest != null and door_glow != null and crown_glow != null and ring != null
	if not _ok:
		push_warning("FointDomeLife: the export is missing some of the dome's moving parts (red %s sign %s halo %s crest %s door %s crown %s ring %s)" % [red != null, sign != null, halo != null, crest != null, door_glow != null, crown_glow != null, ring != null])


static func _is(m: BaseMaterial3D, hex: int) -> bool:
	var c := Color.hex((hex << 8) | 0xff)
	return absf(m.albedo_color.r - c.r) < 0.004 and absf(m.albedo_color.g - c.g) < 0.004 and absf(m.albedo_color.b - c.b) < 0.004


static func _mesh_under(level: ExportedLevel, js: String) -> MeshInstance3D:
	for o: Node in level.node_named(js):
		for c: Node in o.get_children():
			if c is MeshInstance3D:
				return c
	return null


static func _mat_under(level: ExportedLevel, js: String) -> BaseMaterial3D:
	var mi := _mesh_under(level, js)
	return mi.get_active_material(0) as BaseMaterial3D if mi != null else null


## JS: upd.push((t) => { ... }), t the district's clock.
func update(t: float) -> void:
	var breathe := 0.82 + 0.18 * sin(t * 1.1)
	if red != null:
		var b := Color(breathe, breathe, breathe).linear_to_srgb()      # (JS color.setScalar sets the linear value; a Godot albedo is sRGB)
		red.albedo_color = Color(b.r, b.g, b.b, red.albedo_color.a)
	if fire_m != null:
		fire_m.set_shader_parameter(&"t", t)      # (each flame's dance is in the shader)
		fire_m.set_shader_parameter(&"size", 3.2 + sin(t * 13.0) * 0.35)
	if sign != null:
		sign.albedo_color.a = 0.94 + 0.06 * sin(t * 2.2) - (0.35 if sin(t * 27.0) * sin(t * 3.1) > 0.86 else 0.0)
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
