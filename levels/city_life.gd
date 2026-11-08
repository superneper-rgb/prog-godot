class_name CityLife
extends RefCounted
## JS CityView.update, the parts that live on the exported city (hub street and Back Alley): the camera's fill light and the sky sphere follow the camera, the rain, the street lamps' hum and the dying lamp, the apartment lights, the burning barrel, the shop door light,
## neon breathing and stutter, wall fixtures, dead signals, the club's spill, the steam, the armour vendor's hologram, the skyline beacon. The sprites all run in one shader per texture (levels/shaders/city_sprites*): one `t` a frame is all they cost here.
## JS _doorTick is not here: it drives city.aptDoors, and no city has any since the apartment became its own level.

var level: ExportedLevel
var t := 0.0
var fill: Light3D = null
var sky: Array = []
var lamps: Array = []       # { "l": Light3D, "base": 74 or 80 (also the hum's phase, as in the JS), "bad": bool }
var apt: Array = []         # { "l": Light3D, "base": intensity, "ph": phase }
var barrel: Light3D = null
var door_light: Light3D = null
var rain: MeshInstance3D = null
var rain_mat: ShaderMaterial = null
var has_shop := false       # the hub's street: the rain stops under its roofs
var S: Dictionary = {}      # JS city.storm: { rain_n, rain_speed, slant, opacity, len }. Storm gusts change slant and opacity through set_rain().
var flick: Array = []       # { "m": material, "base", "rate", "ph", "gate" }: neon, slow breathing with the odd stutter
var blink: Array[BaseMaterial3D] = []
var spills: Array = []      # { "lamp", "pavement", "aperture", "pm", "am", "strength", "phase" }: the light spilling out of CLUB 9
var sw := 0.0
var club9_z := 0.0
var beacon: Array = []
var holos: Array = []       # { "n": Node3D, "hm", "lm" }: the armour vendor's hologram, one suit at a time
var holo_cur := -1
var holo_col: BaseMaterial3D = null
var holo_light: Light3D = null
var bad_k := 1.0
var sprite_rids: Array[RID] = []
var sprite_mats: Array[ShaderMaterial] = []      # (held: the server takes them by RID)


func _init(p_level: ExportedLevel, p_has_shop: bool, p_storm: Dictionary = {}) -> void:
	level = p_level
	has_shop = p_has_shop
	S = p_storm
	for l: Light3D in level.lights:
		var n := String(l.name)
		var js := n.substr(n.find("_") + 1)      # (ExportedLevel names them L<index>_<JS name>)
		if js == "CityFill":
			fill = l
		elif js.begins_with("CityLamp"):
			lamps.append({"l": l, "base": 74.0 if js.begins_with("CityLampWarm") else 80.0, "bad": js.begins_with("CityLampBad")})
		elif js.begins_with("CityApt"):
			apt.append({"l": l, "base": l.light_energy, "ph": int(js.substr(7)) * 1.7})
		elif js == "CityBarrel":
			barrel = l
		elif js == "CityDoorLight":
			door_light = l
	if fill == null:
		push_warning("CityLife: no CityFill light in the export: export this level again")
	sky = level.node_named("HubSky")
	_build_rain()
	_build_life()


## What the exporter wrote about this city (city_life.json). A level exported before it had that file simply has none of this.
func _build_life() -> void:
	var path := ExportedLevel.DIR + level.id + "/city_life.json"
	if not FileAccess.file_exists(path):
		push_warning("CityLife: no city_life.json for %s: export this level again" % level.id)
		return
	var J: Dictionary = ExportedLevel._json(path)
	var mats := _named_materials()
	sw = float(J.get("sw", 0.0))
	club9_z = float(J.get("club9_z", 0.0))
	for f: Dictionary in J.get("flick", []):
		var m: BaseMaterial3D = mats.get(String(f["name"]))
		if m != null:
			m.emission = Color.WHITE      # (the export caught it mid-flicker; JS: emissive 0xffffff, emissiveIntensity is what moves)
			flick.append({"m": m, "base": float(f["base"]), "rate": float(f["rate"]), "ph": float(f["ph"]), "gate": float(f["gate"])})
	for f: Dictionary in J.get("blink", []):
		var m: BaseMaterial3D = mats.get(String(f["name"]))
		if m != null:
			m.emission = Color.hex(0xffa830ff)      # (likewise: it may have been caught dark)
			blink.append(m)
	var i := 0
	for q: Dictionary in J.get("spill", []):
		var lamp := _light_named("CitySpillLamp%d" % i)
		var pavement: Array = level.node_named("CitySpillPavement%d" % i)
		var aperture: Array = level.node_named("CitySpillAperture%d" % i)
		if lamp != null and not pavement.is_empty() and not aperture.is_empty():
			spills.append({"lamp": lamp, "pavement": pavement[0], "aperture": aperture[0], "pm": mats.get("CitySpillPavementMat%d" % i), "am": mats.get("CitySpillApertureMat%d" % i), "strength": float(q["strength"]), "phase": float(q["phase"])})
		i += 1
	beacon = level.node_named("CityBeacon")
	for k in int(J.get("holos", 0)):
		var a: Array = level.node_named("CityHolo%d" % k)
		if not a.is_empty():
			var n: Node3D = a[0]
			n.rotation_order = EULER_ORDER_XYZ
			n.visible = false
			holos.append({"n": n, "hm": mats.get("CityHoloHm%d" % k), "lm": mats.get("CityHoloLm%d" % k)})
	holo_col = mats.get("CityHoloColumnMat")
	holo_light = _light_named("CityHoloLight")
	_build_sprites(J.get("sprites", []))


## A material the exporter kept apart because it moves, by its JS name (extras.js_name).
func _named_materials() -> Dictionary:
	var out := {}
	var stack: Array[Node] = [level]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		var mesh: Mesh = null
		if n is MeshInstance3D:
			mesh = (n as MeshInstance3D).mesh
		elif n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh != null:
			mesh = (n as MultiMeshInstance3D).multimesh.mesh
		if mesh == null:
			continue
		for s_i in mesh.get_surface_count():
			var m := mesh.surface_get_material(s_i)
			if m is BaseMaterial3D and m.has_meta("extras"):
				var js := String((m.get_meta("extras") as Dictionary).get("js_name", ""))
				if js != "":
					out[js] = m
	return out


## (A named light also leaves an empty node of the same name.)
func _light_named(js: String) -> Light3D:
	for o: Node in level.node_named(js):
		if o is Light3D:
			return o
	return null


## One instanced draw per texture and blending (JS sprite-field.js), animated in its shader. The frozen field of the export and the loose sprites it left in the scene go.
func _build_sprites(sets: Array) -> void:
	for o: Node3D in level.node_named("sprite field"):
		o.visible = false
	for o: Node3D in level.node_named("CityLifeSprite"):
		o.visible = false
	if sets.is_empty():
		return
	var quad := ArrayMesh.new()
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-0.5, -0.5, 0), Vector3(0.5, -0.5, 0), Vector3(0.5, 0.5, 0), Vector3(-0.5, 0.5, 0)])
	arr[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
	arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	quad.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var group := Node3D.new()
	group.name = "CitySprites"
	level.add_child(group)
	for e: Dictionary in sets:
		var list: Array = e["list"]
		var mat := ShaderMaterial.new()
		mat.shader = load("res://levels/shaders/city_sprites_add.gdshader" if String(e["blend"]) == "add" else "res://levels/shaders/city_sprites_mix.gdshader")
		mat.set_shader_parameter(&"map", load("res://assets/" + String(e["tex"])))
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = quad
		mm.instance_count = list.size()
		var b := PackedFloat32Array()
		b.resize(list.size() * 20)
		for k in list.size():
			var q: Array = list[k]      # kind, x, y, z, sx, sy, r, g, b, a, p0, p1, p2, p3, p4
			var o := k * 20
			b[o] = q[11]            # the basis carries p1 p2 p3 and p4 (see the shader)
			b[o + 4] = q[12]
			b[o + 8] = q[13]
			b[o + 1] = q[14]
			b[o + 3] = q[1]
			b[o + 7] = q[2]
			b[o + 11] = q[3]
			b[o + 12] = q[6]
			b[o + 13] = q[7]
			b[o + 14] = q[8]
			b[o + 15] = q[9]
			b[o + 16] = q[4]
			b[o + 17] = q[5]
			b[o + 18] = q[0]
			b[o + 19] = q[10]
		mm.buffer = b
		mm.custom_aabb = AABB(Vector3(-4000, -4000, -4000), Vector3(8000, 8000, 8000))      # (they move in the shader; JS: frustumCulled off)
		var mi := MultiMeshInstance3D.new()
		mi.name = "sprites"
		mi.multimesh = mm
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		group.add_child(mi)
		sprite_mats.append(mat)
		sprite_rids.append(mat.get_rid())


## JS CityView._rain: drops wrap in a 40 x 28 x 40 box around the camera. All of it happens in the shader, so nothing runs per frame in script. Between the JS's 0 and 28 m: it never reaches the city's roofs from above, as in the JS.
func _build_rain() -> void:
	var n: int = S.get("rain_n", 1300)
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	v.resize(n * 2)
	uv.resize(n * 2)
	var r := RandomNumberGenerator.new()
	r.seed = 7677
	for i in n:
		var b := Vector3(r.randf() * 40.0, r.randf() * 28.0, r.randf() * 40.0)
		v[i * 2] = b
		v[i * 2 + 1] = b
		uv[i * 2] = Vector2(0.0, 0.0)
		uv[i * 2 + 1] = Vector2(1.0, 0.0)
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_TEX_UV] = uv
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
	rain_mat = ShaderMaterial.new()
	rain_mat.shader = load("res://levels/shaders/rain.gdshader")
	m.surface_set_material(0, rain_mat)
	rain = MeshInstance3D.new()
	rain.name = "Rain"
	rain.mesh = m
	rain.extra_cull_margin = 16384.0
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level.add_child(rain)
	for o: Node3D in level.node_named("CityRain"):      # the frame of it the export caught
		o.visible = false
	if not S.is_empty():
		rain_mat.set_shader_parameter(&"speed", float(S.rain_speed))
		rain_mat.set_shader_parameter(&"len", float(S.get("len", 0.95)))
		set_rain(S.slant, S.opacity)


## The gusts (levels/worldbackalley/storm.gd). JS: sl = -S.slant * len and the drops drift with fall * S.slant, so a gust sweeps the rain across as well as leaning it.
func set_rain(slant: float, opacity: float) -> void:
	rain_mat.set_shader_parameter(&"slant", -slant * float(S.get("len", 0.95)))
	rain_mat.set_shader_parameter(&"drift", slant)
	rain_mat.set_shader_parameter(&"opacity", opacity)


## After the camera has its place for this frame (JS CityView.update(camPos, player)).
func update(dt: float, cam: Vector3) -> void:
	t += dt
	var in_shop := has_shop and cam.x > 8.0 and cam.x < 21.0 and cam.z > 4.0 and cam.z < 18.0 and cam.y < 4.1
	var in_apt := has_shop and cam.x < -7.6 and cam.x > -18.2 and cam.z > 6.0 and cam.z < 23.9 and cam.y > 3.4 and cam.y < 6.6
	var in_office := has_shop and cam.x > 116.0 and cam.x < 130.0 and cam.z > 326.2 and cam.z < 333.8 and cam.y < -5.4
	rain.visible = not in_shop and not in_apt and not in_office
	# the club's spill (JS: prefers-reduced-motion holds the pulse at 0.45; Godot has no such setting to ask, so it pulses)
	if not spills.is_empty():
		var near := U.hyp(cam.x + sw, cam.z - club9_z) < 32.0
		for q: Dictionary in spills:
			var pulse := pow(0.5 + 0.5 * cos(t * PI * 2.0 * 2.4 + float(q.phase)), 3.0)
			(q.lamp as Light3D).visible = near
			(q.pavement as Node3D).visible = near
			(q.aperture as Node3D).visible = near
			if near:
				(q.lamp as Light3D).light_energy = float(q.strength) * (0.35 + 0.65 * pulse) / PI
				if q.pm != null:
					(q.pm as BaseMaterial3D).albedo_color.a = 0.1 + 0.2 * pulse
				if q.am != null:
					(q.am as BaseMaterial3D).albedo_color.a = 0.055 + 0.14 * pulse
	# apartment lights only exist for the shader while the camera is near the building (fewer lights per pixel everywhere else)
	var near_apt := cam.x < 4.0 and cam.x > -34.0 and cam.z > -4.0 and cam.z < 34.0
	for q: Dictionary in apt:
		var l: Light3D = q.l
		if l.visible != near_apt:
			l.visible = near_apt
		if near_apt:
			l.light_energy = float(q.base) * (0.95 + 0.05 * sin(t * 2.3 + float(q.ph)))
	for o: Node3D in sky:
		o.global_position = cam
	if fill != null:
		fill.global_position = Vector3(cam.x, cam.y + 1.2, cam.z)
	# lamps: one is dying, the rest hum
	for q: Dictionary in lamps:
		var base: float = q.base
		var k: float
		if q.bad:
			var burst := sin(t * 0.83 + base) * sin(t * 0.31) > 0.72      # the dying lamp only sputters in short bursts, then holds steady
			k = (0.15 if burst and sin(t * 31.0) * sin(t * 7.3) > 0.55 else 1.0) * (0.3 if burst and randf() > 0.97 else 1.0)
			bad_k = k
		else:
			k = 1.0 + sin(t * 3.0 + base) * 0.015
		(q.l as Light3D).light_energy = base * k / PI      # (l.hs.material.opacity: city_sprites, kind 5)
	# neon: slow breathing with the odd stutter (the sprites beside them: city_sprites, kind 1)
	for f: Dictionary in flick:
		var ph: float = f.ph
		var gate: float = f.gate
		var k := 0.9 + 0.1 * sin(t * float(f.rate) * 6.0 + ph)
		if gate > 0.0 and sin(t * 13.0 + ph) * sin(t * 3.1 + ph * 2.0) > gate:
			k = 0.25
		(f.m as BaseMaterial3D).emission_energy_multiplier = float(f.base) * k
	if barrel != null:
		barrel.light_energy = (16.0 + sin(t * 17.0) * 4.0 + sin(t * 41.3) * 3.0 + sin(t * 5.1) * 3.0) / PI
	if door_light != null:
		door_light.light_energy = 30.0 * (0.92 + 0.08 * sin(t * 2.2)) / PI
	_armor_tick()
	if not beacon.is_empty():
		var bv := fmod(t, 2.0) < 0.9
		for o: Node3D in beacon:
			o.visible = bv
	var flash := fmod(t, 1.3) < 0.75      # dead signals flash amber (wall fixtures and the signals' sprites: city_sprites, kinds 2 and 3)
	for m: BaseMaterial3D in blink:
		m.emission_energy_multiplier = 1.7 if flash else 0.05
	for rid: RID in sprite_rids:
		RenderingServer.material_set_param(rid, &"t", t)
		RenderingServer.material_set_param(rid, &"bad_k", bad_k)


## JS _armorTick: the holographic pedestal cycles the catalogue, one suit at a time.
func _armor_tick() -> void:
	if holos.is_empty():
		return
	var per := 4.5
	var k := int(floor(t / per)) % holos.size()
	var ph := fmod(t, per) / per
	if k != holo_cur:
		if holo_cur >= 0:
			(holos[holo_cur].n as Node3D).visible = false
		(holos[k].n as Node3D).visible = true
		holo_cur = k
	var h: Node3D = holos[k].n
	var sw_ := ph / 0.07 if ph < 0.07 else ((1.0 - ph) / 0.05 if ph > 0.95 else 1.0)
	var fl := 0.86 + 0.14 * sin(t * 23.0) * sin(t * 3.7)
	h.rotation = Vector3(0.0, t * 0.7, 0.0)
	h.scale = Vector3(0.74, 0.74 * maxf(0.02, sw_), 0.74)
	if holos[k].hm != null:
		(holos[k].hm as BaseMaterial3D).albedo_color.a = 0.16 * 1.5 * fl      # (three.js adds its layers on the display value, this frame before the tone map, where layers add up to far less: the shell is mostly three layers deep. 1.5 keeps it as bright)
	if holos[k].lm != null:
		(holos[k].lm as BaseMaterial3D).albedo_color.a = 0.55 * fl
	if holo_col != null:
		holo_col.albedo_color.a = 0.06 + 0.02 * sin(t * 2.1)
	if holo_light != null:
		holo_light.light_energy = 26.0 * (0.94 + 0.06 * sin(t * 1.7)) / PI
