class_name HubLife
extends RefCounted
## What makes FOINT CITY move (JS levels/hub/district-view.js, its per-frame parts): the street clock, the traffic, the crowd, the drivers, the signal lenses, the three roaming lamp lights. Everything comes out of life.json + life.bin, the exporter's picture of the JS city as it was built.

const WARM_L := 3

var level: ExportedLevel
var J: Dictionary = {}
var bin := PackedByteArray()
var plan: CityPlan
var traffic: CityTraffic
var cars: CityCars             # what the city's cars look like (city_cars.gd)
var crowd: CityCrowd
var _water_mat: ShaderMaterial = null
var _water_cand := PackedVector4Array()
var _water_pick := 0
var drivers: CityDrivers
var driving: CityDriving = null
var sound: CitySound = null
var office: HubOffice = null
var folk: CityFolk
var sim_t := 0.0
var signal_mat: ShaderMaterial = null
var _lamp_x := PackedFloat32Array()
var _lamp_z := PackedFloat32Array()
var _lamp_top := PackedFloat32Array()
var _lamps: Array = []
var _warm: Array[OmniLight3D] = []
var _tgt: Array = []
var _pick := 0.0
var _sky_mats: Array[ShaderMaterial] = []
## the flying cars' kinds (tools/cars/sky_cars.py) and where their glows sit on each model: (forward, up), the engines (forward, side, up)
const SKY_KINDS := {
	&"skyLimo": {"head": Vector2(2.72, 0.09), "tail": Vector2(-2.66, 0.2), "strobe": Vector2(-2.66, 0.8), "engine": Vector3(-2.24, 1.1, -0.04)},
	&"skyDart": {"head": Vector2(2.12, 0.04), "tail": Vector2(-2.05, 0.2), "strobe": Vector2(-0.45, 0.72), "engine": Vector3(-2.42, 0.78, 0.02)},
}
const SKY_HIGH := [4, 5, 8]      # the high crossings and the express ring
var _pod_rid: RID
var _pod_pts := PackedVector3Array()
var _pod_cum := PackedFloat32Array()
var _pod_len := 0.0
var _pod_loop := 1.0
var _pods: Array = []          # [s, v]
var _pod_lamps: MultiMesh = null
var dome: FointDomeLife = null
var trees: CityTrees = null       # levels/hub/city_trees.gd
var _beams: Array = []         # [node, sx]: the bridge's two searchlights (JS city-bridge.js)
var _bulb_m: ShaderMaterial = null      # the B-9 alley's door bulb (JS district-view.js)


static func load_for(lv: ExportedLevel) -> HubLife:
	var dir := ExportedLevel.DIR + lv.id + "/"
	if not FileAccess.file_exists(dir + "life.json"):
		push_warning("hub: no life.json: run node tools/export/export.mjs life")
		return null
	var o := HubLife.new()
	o.level = lv
	o.J = ExportedLevel._json(dir + "life.json")
	o.bin = FileAccess.get_file_as_bytes(dir + "life.bin")
	o._build()
	return o


func _build() -> void:
	plan = CityPlan.new(J["plan"])
	folk = CityFolk.new(J, bin)
	cars = CityCars.new()
	traffic = CityTraffic.new(level, plan, J, cars)
	crowd = CityCrowd.new(level, plan, traffic, J, folk)
	crowd.aliens = CityAliens.new(level, crowd.GY)
	crowd.targets.append_array(crowd.aliens.targets)
	var gray: Mesh = null
	var green: Mesh = null
	if J.has("pilots"):
		if (J["pilots"] as Dictionary).has("gray"):
			gray = NpcRig.flat_mesh(J["pilots"]["gray"], bin)
		if (J["pilots"] as Dictionary).has("green"):
			green = NpcRig.flat_mesh(J["pilots"]["green"], bin)
	drivers = CityDrivers.new(level, traffic, J, folk, gray, green)
	if J.has("car_models"):
		var dn: Array = level.node_named("FointDistrict")
		driving = CityDriving.new(traffic, drivers, plan, level.world, level, J)
	sound = CitySound.new()
	sound.name = "CitySound"
	level.add_child(sound)
	sound.setup(traffic, plan, J)
	_hide_frozen()
	_build_signals()
	office = HubOffice.new(level)
	_build_warm_lights()
	_build_sky_traffic()
	_build_pods()
	_build_glints()
	trees = CityTrees.new(level, J["obstacles"], float(J["GY"]))


## What the export froze where it stood: the live ones above take over.
func _hide_frozen() -> void:
	for nm: String in folk_names():
		for o: Node in level.node_named(nm):
			(o as Node3D).visible = false
	for o: Node in level.node_named("SignalLenses"):
		(o as Node3D).visible = false



func dispose() -> void:
	if driving != null:
		driving.detach()
	traffic.dispose()
	crowd.dispose()
	plan.dispose()


func release_bin() -> void:
	bin = PackedByteArray()
	folk.release_bin()


func folk_names() -> Array[String]:
	var out: Array[String] = []
	for k: String in J["species"]:
		out.append("Folk-" + k)
	for k: String in J["drivers"]:
		out.append("Driver-" + k)
	return out


## JS city-streets.js lensPts + its per-frame recolouring: one instanced draw, each lens works out its aspect in the shader.
func _build_signals() -> void:
	var lens: Array = J["lens"]
	var quad := ArrayMesh.new()
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-1, -1, 0), Vector3(1, -1, 0), Vector3(1, 1, 0), Vector3(-1, 1, 0)])
	arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	quad.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	signal_mat = ShaderMaterial.new()
	signal_mat.shader = load("res://levels/shaders/signal_lens.gdshader")
	if J.get("glow") != null:
		signal_mat.set_shader_parameter(&"map", load("res://assets/" + String(J["glow"])))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = lens.size()
	var b := PackedFloat32Array()
	b.resize(lens.size() * 16)
	for i in lens.size():
		var q: Array = lens[i]
		var o := i * 16
		b[o] = 1.0
		b[o + 3] = q[0]
		b[o + 5] = 1.0
		b[o + 7] = q[1]
		b[o + 10] = 1.0
		b[o + 11] = q[2]
		b[o + 12] = q[3]
		b[o + 13] = q[4]
		b[o + 14] = q[5]
	mm.buffer = b
	mm.custom_aabb = AABB(Vector3(-4000, -100, -4000), Vector3(8000, 300, 8000))
	var mi := MultiMeshInstance3D.new()
	mi.name = "SignalLenses2"
	mi.multimesh = mm
	mi.material_override = signal_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level.scene_root.add_child(mi)
	var d: Array = level.node_named("FointDistrict")
	if not d.is_empty():      # (hidden with the district when it is not drawn)
		mi.reparent(d[0], false)


## JS city-atmos.js sky traffic: flying cars on five kinds of lane above the avenues and round the island. All of it runs in shaders/sky_traffic_*: one `t` a frame.
## 2026-11-10: the JS's one blocky unlit hull is replaced by two lit models of our own (tools/cars/sky_cars.py), polished where the street's cars are worn, each craft its own paint and engine colour.
func _build_sky_traffic() -> void:
	var src: Array = level.node_named("SkyTraffic")
	if src.is_empty() or not (src[0] is MultiMeshInstance3D):
		return
	var gy: float = J["GY"]
	var lanes := [
		[[Vector2(-170, 120), Vector2(170, 120), Vector2(170, 510), Vector2(-170, 510)], 62.0, 16, 22.0],      # round the island
		[[Vector2(-150, 140), Vector2(-150, 490), Vector2(150, 490), Vector2(150, 140)], 48.0, 14, 18.0],      # the other way, lower
		[[Vector2(72, 60), Vector2(72, 620), Vector2(80, 620), Vector2(80, 60)], 38.0, 11, 16.0],              # up and down Vox Ave and on over the water
		[[Vector2(-72, 620), Vector2(-72, 60), Vector2(-80, 60), Vector2(-80, 620)], 44.0, 11, 17.0],          # Gleeman Ave
		[[Vector2(-260, 330), Vector2(260, 330), Vector2(260, 338), Vector2(-260, 338)], 80.0, 9, 26.0],       # the high crossing over Mutt St
		[[Vector2(-260, 236), Vector2(260, 236), Vector2(260, 243), Vector2(-260, 243)], 88.0, 8, 24.0],       # a second high crossing, over Kelp St and the dome
		[[Vector2(-260, 451), Vector2(260, 451), Vector2(260, 458), Vector2(-260, 458)], 36.0, 8, 18.0],       # low along Dock Road
		[[Vector2(20, -40), Vector2(20, 200), Vector2(28, 200), Vector2(28, -40)], 60.0, 10, 20.0],            # the bridge corridor: over the hub street, along the bridge, round over the landing plaza
		[[Vector2(-230, 90), Vector2(230, 90), Vector2(230, 560), Vector2(-230, 560)], 100.0, 14, 30.0],       # the express ring, high and fast, out over the water
		[[Vector2(-121, 174), Vector2(-121, 373), Vector2(-115, 373), Vector2(-115, 174)], 24.0, 6, 13.0],     # slow local hoppers down Shore Dr W
	]
	var rng := CityPlan.Rng.new(1117)
	var bufs := {}      # kind -> its crafts' instance data
	var counts := {}
	for k: StringName in SKY_KINDS:
		bufs[k] = PackedFloat32Array()
		counts[k] = 0
	var count := 0
	for li in lanes.size():
		var L: Array = lanes[li]
		var P: Array = L[0]
		var ln := 0.0
		for i in 4:
			ln += (P[i] as Vector2).distance_to(P[(i + 1) % 4])
		for i in int(L[2]):
			var s0: float = (float(i) / int(L[2]) + rng.next() * 0.08) * ln
			var v: float = float(L[3]) * (0.85 + rng.next() * 0.3)
			var bob := rng.next() * 6.0
			var y := gy + float(L[1]) + (rng.next() - 0.5) * 6.0
			var kind: StringName = &"skyLimo" if rng.next() < (0.7 if SKY_HIGH.has(li) else 0.35) else &"skyDart"      # (the yachts keep to the high lanes)
			var r := rng.next()
			var paint := 0 if r < 0.3 else (1 if r < 0.5 else (2 if r < 0.7 else (3 if r < 0.82 else (4 if r < 0.92 else 5))))
			var p0: Vector2 = P[0]
			var p1: Vector2 = P[1]
			var p2: Vector2 = P[2]
			var p3: Vector2 = P[3]
			var kb: PackedFloat32Array = bufs[kind]      # (a packed array comes out of a Dictionary as a copy: put it back)
			kb.append_array([p1.x, p2.y, s0, p0.x, p1.y, p3.x, v, y, p2.x, p3.y, bob, p0.y, float(count % 3), float(paint), 0.0, 0.0])
			bufs[kind] = kb
			counts[kind] += 1
			count += 1
	var old: MultiMeshInstance3D = src[0]
	old.visible = false
	for o: Node in level.node_named("SkyTrafficLights"):
		(o as Node3D).visible = false
	var d: Array = level.node_named("FointDistrict")
	var parent: Node = d[0] if not d.is_empty() else level.scene_root
	_sky_mats.clear()
	var lights := ArrayMesh.new()
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	var v3 := PackedVector3Array()
	var ix := PackedInt32Array()
	for li in 5:
		for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			v3.append(Vector3(c.x, c.y, li))
		var b := li * 4
		ix.append_array([b, b + 1, b + 2, b, b + 2, b + 3])
	arr[Mesh.ARRAY_VERTEX] = v3
	arr[Mesh.ARRAY_INDEX] = ix
	lights.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var hull_shader: Shader = load("res://levels/shaders/sky_traffic_hull.gdshader")
	for k: StringName in SKY_KINDS:
		if counts[k] == 0:
			continue
		var K: Dictionary = SKY_KINDS[k]
		var hull := traffic.kit.sky_mesh(k)
		for si in hull.get_surface_count():
			var hm := ShaderMaterial.new()
			hm.shader = hull_shader
			hm.set_shader_parameter(&"part", CityCars.GROUPS.find(StringName(hull.surface_get_name(si))))
			traffic.kit.follow_sky(hm)
			hull.surface_set_material(si, hm)
			_sky_mats.append(hm)
		var lm := ShaderMaterial.new()
		lm.shader = load("res://levels/shaders/sky_traffic_lights.gdshader")
		if J.get("glow") != null:
			lm.set_shader_parameter(&"map", load("res://assets/" + String(J["glow"])))
		for p: StringName in [&"head", &"tail", &"strobe", &"engine"]:
			lm.set_shader_parameter(p, K[p])
		_sky_mats.append(lm)
		for pair: Array in [[hull, null, "SkyTraffic2_" + String(k)], [lights, lm, "SkyTrafficLights2_" + String(k)]]:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_custom_data = true
			mm.mesh = pair[0]
			mm.instance_count = counts[k]
			mm.buffer = bufs[k]
			mm.custom_aabb = AABB(Vector3(-4000, -100, -4000), Vector3(8000, 600, 8000))
			var mi := MultiMeshInstance3D.new()
			mi.name = pair[2]
			mi.multimesh = mm
			mi.material_override = pair[1]
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(mi)


## JS city-deck.js: the freight pods: one instanced draw running the whole U, terminal to terminal. A pod comes out of one terminal gate, climbs a descent, runs the Deck round to the other descent and goes back into the shed through the other gate; inside the shed it is out of sight for as long as the shed is long. Pods keep to the right of their own direction.
func _build_pods() -> void:
	var pp: Variant = J.get("pod_path")
	var src: Array = level.node_named("DeckFreight")
	if pp == null or src.is_empty() or not (src[0] is MultiMeshInstance3D):
		return
	var old: MultiMeshInstance3D = src[0]
	old.visible = true
	old.multimesh.custom_aabb = AABB(Vector3(-4000, -100, -4000), Vector3(8000, 300, 8000))
	_pod_rid = old.multimesh.get_rid()
	var pts: Array = pp["pts"]
	for p: Array in pts:
		_pod_pts.append(Vector3(p[0], p[1], p[2]))
	_pod_cum.resize(_pod_pts.size())
	var c := 0.0
	for i in range(1, _pod_pts.size()):
		c += _pod_pts[i].distance_to(_pod_pts[i - 1])
		_pod_cum[i] = c
	_pod_len = c
	_pod_loop = _pod_len + float(pp["hidden"])
	for i in 14:
		_pods.append([(_pod_loop * i) / 14.0 + (i % 2) * 31.0, (11.0 + (i % 4) * 3.0) * (1.0 if i % 2 else -1.0)])
	for o: Node in level.node_named("DeckFreightLamps"):
		(o as Node3D).visible = false
	# its lamps: a lamp ahead and one behind, head and tail by which way the pod runs (JS: Points without a map, so square)
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()
	var cus := PackedFloat32Array()
	var ix := PackedInt32Array()
	var base := 0
	for q: Array in [[3.4, Color(1, 0.86, 0.6), 2.0], [-3.4, Color(0.9, 0.12, 0.08), 2.0], [3.4, Color(0.9, 0.12, 0.08), 3.0], [-3.4, Color(1, 0.86, 0.6), 3.0]]:
		for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			v.append(Vector3(0.0, 0.35, q[0]))
			uv.append(corner)
			col.append(q[1])
			cus.append_array([q[2], 0.0, 0.0, 0.0])
		ix.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
		base += 4
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_COLOR] = col
	arr[Mesh.ARRAY_CUSTOM0] = cus
	arr[Mesh.ARRAY_INDEX] = ix
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	var m := ShaderMaterial.new()
	m.shader = load("res://levels/shaders/car_lamps.gdshader")
	m.set_shader_parameter(&"SIZE", 2.6)
	_sky_mats.append(m)
	am.surface_set_material(0, m)
	_pod_lamps = MultiMesh.new()
	_pod_lamps.transform_format = MultiMesh.TRANSFORM_3D
	_pod_lamps.use_custom_data = true
	_pod_lamps.mesh = am
	_pod_lamps.instance_count = 14
	_pod_lamps.custom_aabb = AABB(Vector3(-4000, -100, -4000), Vector3(8000, 300, 8000))
	for i in 14:
		_pod_lamps.set_instance_custom_data(i, Color(0.0, 0.0 if i % 2 else 1.0, 1.0 if i % 2 else 0.0, 0.0))
	var mi := MultiMeshInstance3D.new()
	mi.name = "DeckFreightLamps2"
	mi.multimesh = _pod_lamps
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	old.get_parent().add_child(mi)


func _pods_tick(dt: float) -> void:
	if _pods.is_empty():
		return
	var i := 0
	for p: Array in _pods:
		p[0] = fposmod(float(p[0]) + float(p[1]) * dt, _pod_loop)
		var s: float = p[0]
		var xf: Transform3D
		if s > _pod_len:      # inside the shed
			xf = Transform3D(Basis.IDENTITY, Vector3(0.0, -9999.0, 0.0))
		else:
			var lo := 0
			var hi := _pod_cum.size() - 1
			while hi - lo > 1:
				var m := (lo + hi) >> 1
				if _pod_cum[m] <= s:
					lo = m
				else:
					hi = m
			var a := _pod_pts[lo]
			var b := _pod_pts[hi]
			var l := _pod_cum[hi] - _pod_cum[lo]
			if l == 0.0:
				l = 1.0
			var at := a.lerp(b, (s - _pod_cum[lo]) / l)
			var dir := (b - a) / l
			var sg := signf(float(p[1]))
			var fx := dir.x * sg
			var fz := dir.z * sg
			var fh := U.hyp(fx, fz)
			if fh == 0.0:
				fh = 1.0
			# the right-hand lane; heading, then nose up or down the descent
			var basis := Basis(Vector3.UP, atan2(fx, fz)) * Basis(Vector3.RIGHT, -atan2(dir.y * sg, fh))
			xf = Transform3D(basis, Vector3(at.x - (fz / fh) * 3.2, at.y + 0.95, at.z + (fx / fh) * 3.2))
		RenderingServer.multimesh_instance_set_transform(_pod_rid, i, xf)
		if _pod_lamps != null:
			_pod_lamps.set_instance_transform(i, xf)
		i += 1


## The district's small lights that move on their own clock: the FOINT DOME (levels/hub/foint_dome.gd), the bridge's searchlights and the alley's door bulb. The export has them where they stood; these find them by their JS colours.
func _build_glints() -> void:
	dome = FointDomeLife.new(level)
	var dn: Array = level.node_named("FointDistrict")
	if dn.is_empty():
		return
	var st: Array[Node] = [dn[0]]
	while not st.is_empty():
		var n: Node = st.pop_back()
		st.append_array(n.get_children())
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var m := mi.get_active_material(0) as BaseMaterial3D
		if m == null:
			continue
		if FointDomeLife._is(m, 0xffd9a8) and m.blend_mode == BaseMaterial3D.BLEND_MODE_ADD:
			var piv := mi.get_parent() as Node3D      # (the export folded the JS pivot and the beam into this one node)
			piv.rotation_order = EULER_ORDER_YXZ
			_beams.append([piv, signf(piv.position.x)])
		elif FointDomeLife._is(m, 0xff8a4a) and mi.mesh.surface_get_primitive_type(0) == Mesh.PRIMITIVE_POINTS:
			_bulb_m = GlowPoints.replace(mi, 6.5)
	if _beams.size() != 2 or _bulb_m == null:
		push_warning("HubLife: expected two bridge searchlights and the alley bulb, found %d and %s" % [_beams.size(), _bulb_m != null])


## JS city-bridge.js (the searchlights sweep), district-view.js (the bulb sputters), foint-arena.js (the dome), all on the district's clock t.
func _glints_tick(t: float) -> void:
	if dome != null:
		dome.update(t)
	for b: Array in _beams:
		var sx: float = b[1]
		(b[0] as Node3D).rotation = Vector3(0.62 + 0.1 * sin(t * 0.37 + sx * 2.0), sx * 0.6 + 0.3 * sin(t * 0.26 + sx), sx * 0.22)
	if _bulb_m != null:
		var f := sin(t * 37.0) * sin(t * 5.3) * sin(t * 2.1)
		_bulb_m.set_shader_parameter(&"opacity", 0.15 if f > 0.62 else 0.85 + 0.15 * sin(t * 11.0))


## JS district-view.js warmL: three roaming lamp lights: the nearest lamps get them, so lit things (cars, people, the player) read under the baked street light.
func _build_warm_lights() -> void:
	_lamps = J["lamp_pts"]
	var n := _lamps.size()
	_lamp_x.resize(n)
	_lamp_z.resize(n)
	_lamp_top.resize(n)
	for i in n:
		var l: Dictionary = _lamps[i]
		_lamp_x[i] = l["hx"]
		_lamp_z[i] = l["hz"]
		_lamp_top[i] = l["top"]
	for l: Light3D in level.lights:      # (the export has them where the JS parks them, 60 m under the street)
		if l is OmniLight3D and l.position.y < -50.0 and _warm.size() < WARM_L:
			_warm.append(l)
			_tgt.append({"x": 0.0, "y": -60.0, "z": 0.0, "i": -1, "warm": false, "intensity": 26.0, "distance": 17.0, "color": -1, "office": false})


func _warm_tick(dt: float, t: float, cam: Vector3) -> void:
	_pick -= dt
	if _pick <= 0.0:
		_pick = 0.25
		var n := _lamps.size()
		var used := {}
		var office_room := cam.x > 114.0 and cam.x < 131.0 and absf(cam.z - 330.0) < 5.0 and cam.y < -5.0
		var best: Array = []
		for k in WARM_L:
			var bd := 38.0 * 38.0
			var bi := -1
			for i in n:
				if used.has(i):
					continue
				var dx := _lamp_x[i] - cam.x
				var dz := _lamp_z[i] - cam.z
				var dy := _lamp_top[i] - cam.y
				var d := dx * dx + dz * dz + dy * dy * 0.3
				if office_room and (_lamps[i] as Dictionary).get("office", false):
					d *= 0.04
				if d < bd:
					bd = d
					bi = i
			if bi >= 0:
				used[bi] = true
			best.append(bi)
		for k in WARM_L:
			var T: Dictionary = _tgt[k]
			var bi: int = best[k]
			if bi < 0:
				T.i = -1
				continue
			if T.i != bi:
				var l: Dictionary = _lamps[bi]
				T.i = bi
				T.x = float(l["hx"])
				T.y = float(l["top"]) - 0.6
				T.z = float(l["hz"])
				T.warm = l["warm"]
				T.intensity = float(l.get("intensity", 26.0))
				T.distance = float(l.get("distance", 17.0))
				T.color = int(l.get("color", -1))
				T.office = l.get("office", false)
	for k in WARM_L:
		var T: Dictionary = _tgt[k]
		var L2: OmniLight3D = _warm[k]
		var on: bool = T.i >= 0
		var q := minf(1.0, dt * 5.0)
		var p := L2.position
		p.x += (float(T.x) - p.x) * q
		p.y += ((float(T.y) if on else -60.0) - p.y) * q
		p.z += (float(T.z) - p.z) * q
		L2.position = p
		var pulse := 0.94 + 0.06 * sin(t * 8.1) if T.office and not T.warm else 1.0
		L2.light_energy += ((float(T.intensity) * pulse / PI if on else 0.0) - L2.light_energy) * q
		L2.omni_range = float(T.distance) if float(T.distance) > 0.0 else 17.0
		if on:
			var hx: int = T.color if int(T.color) >= 0 else (0xffb06a if T.warm else 0x9cc8ff)
			L2.light_color = Color.hex((hx << 8) | 0xff)


## JS city-water.js update: the water's glitter paths, under the lamps nearest the camera. Re-picked every 10 frames.
func _water_lamps(cam: Vector3) -> void:
	_water_pick -= 1
	if _water_pick > 0:
		return
	_water_pick = 10
	if _water_mat == null:
		if level.shader_ports == null:
			return
		_water_mat = level.shader_ports.mats.get("shader_9ae872#0")
		if _water_mat == null:
			_water_pick = 1000000
			return
		# lamps whose glitter path can show on the water: on the bridge, the piers or within a street of the quay (the quay wall hides the rest)
		var ld: Dictionary = J["land"]
		var x0: float = ld["x0"]
		var x1: float = ld["x1"]
		var z0: float = ld["z0"]
		var z1: float = ld["z1"]
		for l: Dictionary in J["lamp_pts"]:
			var hx: float = l["hx"]
			var hz: float = l["hz"]
			var edge := minf(minf(absf(hx - x0), absf(hx - x1)), minf(absf(hz - z0), absf(hz - z1)))
			if hx < x0 or hx > x1 or hz < z0 or hz > z1 or edge < 16.0:
				_water_cand.append(Vector4(hx, float(l["top"]) - 0.15, hz, 1.0 if l.get("warm", false) else 0.0))
	var near: Array = []
	for i in _water_cand.size():
		var v := _water_cand[i]
		near.append([(v.x - cam.x) * (v.x - cam.x) + (v.z - cam.z) * (v.z - cam.z), i])
	near.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var n := mini(40, near.size())
	var u := PackedVector4Array()
	u.resize(40)
	for i in n:
		u[i] = _water_cand[near[i][1]]
	_water_mat.set_shader_parameter(&"uL", u)
	_water_mat.set_shader_parameter(&"uLN", float(n))


## the street simulation runs on its own clock, frozen while the game is paused or the district is out of sight (JS: run = active(), sdt = run && root.visible ? dt : 0)
func update(dt: float, t: float, cam: Vector3, district_visible: bool) -> void:
	_warm_tick(dt, t, cam)
	_water_lamps(cam)
	if not district_visible:
		return
	var run: bool = Game.started and not Game.paused and not Game.menu_open()
	var sdt := dt if run else 0.0
	sim_t += sdt
	var P := Game.player
	traffic.update(sim_t, sdt, P)
	crowd.update(sim_t, sdt, P)
	drivers.update(sim_t, cam, sdt)
	sound.update(sim_t, sdt if sdt > 0.0 else dt, run)
	office.update(sim_t, sdt, P, cam, run)
	_pods_tick(dt)      # (JS deck.update(t, dt): not on the street clock)
	RenderingServer.material_set_param(signal_mat.get_rid(), &"sim_t", sim_t)
	RenderingServer.material_set_param(folk.material.get_rid(), &"uTime", sim_t)
	for m: ShaderMaterial in _sky_mats:
		RenderingServer.material_set_param(m.get_rid(), &"t", t)
	_glints_tick(t)
