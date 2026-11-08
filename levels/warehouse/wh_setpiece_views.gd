class_name WhSetpieceViews
extends Node
## What the building throws at you, on screen (JS levels/warehouse/setpiece-visuals.js): a pure function of WhSetPieces' state: Volt Drums, falling freight and its tug, crew-lift pads, staged loads, the Slag Compactor. Meshes are made per logic object and removed with it. Not yet: the VOLT stencil and scuffs on the drum (a painted band stands in), the signs on the pads and the tug.

var L: WarehouseLevel
var S: WhSetPieces
var K: Dictionary = WhData.TUNING.setpieces
var DX := float(WhData.DEPTH_X)
var slag_box := {"live": false, "x0": 0.0, "x1": 0.0, "cz": 0.0, "hz": 1.0, "bottom": 0.0, "top": 0.0}
var views: Dictionary = {}             # logic dict's id (its instance) -> view
var frame := 0
var M: Dictionary = {}
var G: Dictionary = {}
var hauler: Node3D
var tug_clamps: Array[Node3D] = []
var tug_stage := ""
var tug_camera: World.Solid
var slag: Node3D
var body: MeshInstance3D
var spikes: Array[Node3D] = []
var rollers: Array[Node3D] = []
var strips: Array[Dictionary] = []
var lamp: Node3D
var tracks: Array[Dictionary] = []
var light: OmniLight3D


func _init(level: WarehouseLevel) -> void:
	L = level
	S = level.setpieces


static func _std(hex: int, metal: float = 0.5, rough: float = 0.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.hex((hex << 8) | 0xff)
	m.metallic = metal
	m.roughness = rough
	return m


static func _unlit(hex: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color.hex((hex << 8) | 0xff)
	return m


static func _add(hex: int, opacity: float) -> StandardMaterial3D:
	var m := _unlit(hex)
	m.albedo_color.a = opacity
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.disable_fog = true
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func _ring_mesh(a: float, b: float, n: int) -> ArrayMesh:
	var v := PackedVector3Array()
	var idx := PackedInt32Array()
	for i in n + 1:
		var t := float(i) / n * TAU
		v.append(Vector3(cos(t) * a, 0.0, sin(t) * a))
		v.append(Vector3(cos(t) * b, 0.0, sin(t) * b))
	for i in n:
		var k := i * 2
		idx.append_array(PackedInt32Array([k, k + 1, k + 2, k + 1, k + 3, k + 2]))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


static func _cyl(r1: float, r2: float, h: float, seg: int) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r1
	c.bottom_radius = r2
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c


func _drum_material() -> StandardMaterial3D:
	# Stencilled steel: teal body, amber hazard band, dark edges (JS drumTexture without its lettering)
	var img := Image.create(256, 128, false, Image.FORMAT_RGB8)
	img.fill(Color8(0x3f, 0x6a, 0x70))
	img.fill_rect(Rect2i(0, 46, 256, 36), Color8(0xd6, 0xa3, 0x54))
	for x in range(-40, 300, 18):
		for y in 36:
			var px := x + y
			for w in 9:
				if px + w >= 0 and px + w < 256:
					img.set_pixel(px + w, 81 - y, Color8(0x1b, 0x2a, 0x2f))
	img.fill_rect(Rect2i(0, 44, 256, 2), Color8(0x14, 0x22, 0x2a))
	img.fill_rect(Rect2i(0, 82, 256, 2), Color8(0x14, 0x22, 0x2a))
	var m := _std(0xffffff, 0.55, 0.52)
	m.albedo_texture = ImageTexture.create_from_image(img)
	return m


func _ready() -> void:
	M = {"drum": _drum_material(), "rib": _std(0x56686b, 0.8, 0.38), "lid": _std(0x1b2a2f, 0.7, 0.4), "bung": _std(0xd6a354, 0.5, 0.45), "volt": _unlit(0x7fe6ff), "volt_hot": _unlit(0xff7a3a), "ring_idle": _add(0xff9a4a, 0.05), "ring_hot": _add(0xff5a2a, 0.55), "crate": _std(0xc79545, 0.5, 0.7), "warn": _add(0xff3a2a, 0.28), "warn_hot": _add(0xff3a2a, 0.7), "shock": _add(0xffc27a, 0.5), "pad_ring": _add(0x5fe8ff, 0.85), "pad_glow": _add(0x2fb8ff, 0.22), "chevron": _add(0x8ff2ff, 0.7), "slag": _std(0x2a1f1c, 0.7, 0.45), "slag_glow": _unlit(0xff7a2a), "spike": _std(0x8d8a86, 0.8, 0.35), "dark": _std(0x20262a, 0.6, 0.6), "amber": _std(0xd49b48, 0.55, 0.5), "chrome": _std(0xb8c4cc, 0.9, 0.25), "machine": _std(0x3d5560, 0.6, 0.5), "rubber": _std(0x17191b, 0.0, 0.9)}
	var hot: StandardMaterial3D = (M.drum as StandardMaterial3D).duplicate()
	hot.emission_enabled = true
	hot.emission = Color.hex(0xff5a1aff)
	hot.emission_energy_multiplier = 1.1
	M["hot"] = hot
	var box := BoxMesh.new()
	var disc := _ring_mesh(0.0, 1.0, 40)
	var cone := _cyl(0.0, 0.34, 1.5, 6)
	G = {"box": box, "disc": disc, "ring": _ring_mesh(float(K.drum.radius) - 0.16, K.drum.radius, 56), "drum": _cyl(0.43, 0.42, K.drum.height, 24), "rib": _cyl(0.445, 0.445, 0.044, 24), "bung": _cyl(0.07, 0.08, 0.06, 10), "vent": box, "cone": cone, "roller": _cyl(1.0, 1.0, 1.0, 16), "pad_base": _cyl(1.45, 1.55, 0.14, 28), "pad_ring": _ring_mesh(1.1, 1.32, 36)}
	# A persistent repulsor cargo tug carries each incoming load to its release point. The cyan emitters explicitly explain why this assembly can hover.
	hauler = _group(self)
	_mesh(hauler, G.box, M.machine, Vector3.ZERO, Vector3(3.2, 0.6, 3.2))
	for x: float in [-1.1, 1.1]:
		tug_clamps.append(_mesh(hauler, G.box, M.amber, Vector3(signf(x) * 1.38, -0.7, 0.0), Vector3(0.16, 1.4, 2.8)))
		for z: float in [-1.1, 1.1]:
			_mesh(hauler, G.disc, M.pad_glow, Vector3(x, -0.37, z), Vector3(0.38, 1.0, 0.38))
	hauler.visible = false
	tug_camera = L.world.add_camera_blocker({"cx": 0.0, "cz": 0.0, "hx": 2.3, "hz": 1.7, "bottom": 0.0, "top": 1.0, "off": true})
	# Slag Compactor: built once, positioned from the chase state.
	slag = _group(self)
	slag.visible = false
	var depth := float(K.chase.depth)
	body = _mesh(slag, G.box, M.slag, Vector3.ZERO, Vector3(depth, 9.0, 1.0))
	for _i in 15:
		var s := _mesh(slag, G.cone, M.spike, Vector3(depth / 2.0 + 0.7, 0.0, 0.0), Vector3.ONE)
		s.rotation.z = -PI / 2.0
		spikes.append(s)
	for y: float in [-1.1, 1.1]:
		var r := _mesh(slag, G.roller, M.spike, Vector3(depth / 2.0 + 0.2, -2.2 + y * 1.35, 0.0), Vector3.ONE)
		r.rotation.x = PI / 2.0
		rollers.append(r)
	for f: float in [-0.34, 0.0, 0.34]:
		strips.append({"s": _mesh(slag, G.box, M.slag_glow, Vector3(depth / 2.0 + 0.03, 0.0, 0.0), Vector3(0.1, 6.4, 0.35)), "f": f})
	lamp = _mesh(slag, G.box, M.slag_glow, Vector3(0.0, 4.7, 0.0), Vector3(0.6, 0.35, 2.0))
	# The Compactor is a driven tracked machine, with axles and grounded treads.
	for side: float in [-1.0, 1.0]:
		var t := _group(slag)
		_mesh(t, G.box, M.rubber, Vector3.ZERO, Vector3(3.3, 0.6, 1.1))
		var wheels: Array[Node3D] = []
		for x: float in [-1.0, 0.0, 1.0]:
			var w := _mesh(t, G.roller, M.chrome, Vector3(x, 0.0, 0.0), Vector3(0.5, 0.8, 0.5))
			w.rotation.x = PI / 2.0
			wheels.append(w)
		tracks.append({"t": t, "wheels": wheels, "side": side})
	# Always in the scene (energy 0 when idle) so the escape wing never triggers a rebuild.
	light = OmniLight3D.new()
	light.light_color = Color.hex(0xff7a2aff)
	light.light_energy = 0.0
	light.omni_range = 32.0
	light.omni_attenuation = 1.6
	add_child(light)


func _group(parent: Node) -> Node3D:
	var g := Node3D.new()
	parent.add_child(g)
	return g


func _mesh(parent: Node, mesh: Mesh, mat: Material, at: Vector3, sc: Vector3) -> MeshInstance3D:
	var q := MeshInstance3D.new()
	q.mesh = mesh
	q.material_override = mat
	q.position = at
	q.scale = sc
	parent.add_child(q)
	return q


func _view(obj: Dictionary, build: Callable) -> Dictionary:
	var v: Variant = views.get(_key(obj))
	if v == null:
		v = build.call(obj)
		views[_key(obj)] = v
	v.seen = frame
	return v


static func _key(o: Dictionary) -> int:
	return o.hash_key if o.has("hash_key") else _assign_key(o)


static var _next_key := 1


static func _assign_key(o: Dictionary) -> int:
	o["hash_key"] = _next_key
	_next_key += 1
	return o["hash_key"]


func _build_drum(d: Dictionary) -> Dictionary:
	var g := _group(self)
	var h := float(K.drum.height)
	var b := _mesh(g, G.drum, M.drum, Vector3(0.0, h / 2.0, 0.0), Vector3.ONE)
	for y: float in [0.22, 0.93]:
		_mesh(g, G.rib, M.rib, Vector3(0.0, y, 0.0), Vector3.ONE)
	_mesh(g, G.disc, M.lid, Vector3(0.0, h + 0.003, 0.0), Vector3(0.36, 1.0, 0.36))
	_mesh(g, G.bung, M.bung, Vector3(0.17, h + 0.03, 0.06), Vector3.ONE)
	var ind := _mesh(g, _ring_mesh(0.18, 0.22, 24), M.volt, Vector3(0.0, h + 0.012, 0.0), Vector3.ONE)
	var vents: Array[MeshInstance3D] = []
	for i in 4:
		var a := i * PI / 2.0 + 0.4
		var v := _mesh(g, G.vent, M.volt, Vector3(sin(a) * 0.428, 0.58, cos(a) * 0.428), Vector3(0.05, 0.3, 0.012))
		v.rotation.y = a
		vents.append(v)
	var ring := _mesh(g, G.ring, M.ring_idle, Vector3(0.0, 0.07, 0.0), Vector3.ONE)
	g.rotation.y = (int(d.id) % 11) * 0.6
	g.position = Vector3(d.x, d.y, d.z)
	return {"g": g, "body": b, "ring": ring, "ind": ind, "vents": vents}


func _build_drop(q: Dictionary) -> Dictionary:
	var g := _group(self)
	var outer := _mesh(g, G.ring, M.warn, Vector3(0.0, 0.06, 0.0), Vector3.ONE * (float(q.cfg.radius) / float(K.drum.radius)))
	var inner := _mesh(g, G.disc, M.warn, Vector3(0.0, 0.05, 0.0), Vector3.ONE)
	var load := _mesh(g, G.box, M.slag if q.cfg.get("look", "") == "scrap" else M.crate, Vector3.ZERO, Vector3(2.6, 1.7, 2.6))
	var shock := _mesh(g, G.ring, M.shock, Vector3(0.0, 0.1, 0.0), Vector3.ONE)
	shock.visible = false
	g.position = Vector3(q.x, q.y, q.z)
	return {"g": g, "outer": outer, "inner": inner, "load": load, "shock": shock}


func _build_pad(p: Dictionary) -> Dictionary:
	var g := _group(self)
	_mesh(g, G.pad_base, M.dark, Vector3(0.0, 0.07, 0.0), Vector3.ONE)
	var ring := _mesh(g, G.pad_ring, M.pad_ring, Vector3(0.0, 0.16, 0.0), Vector3.ONE)
	var glow := _mesh(g, G.disc, M.pad_glow, Vector3(0.0, 0.17, 0.0), Vector3(1.3, 1.0, 1.3))
	var chev: Array[MeshInstance3D] = []
	for _i in 3:
		var c := _mesh(g, G.pad_ring, (M.chevron as StandardMaterial3D).duplicate(), Vector3.ZERO, Vector3(0.45, 1.0, 0.45))
		chev.append(c)
	# Edge strip along the perch lip: the light that points at the flank route.
	var pz := float(p.perch.z)
	var edge := pz - 3.0 * signf(pz)
	_mesh(g, G.box, _unlit(0x5fe8ff), Vector3(0.0, float(p.perch.y) - float(p.y) + 0.06, edge - float(p.z)), Vector3(22.0, 0.08, 0.14))
	g.position = Vector3(p.x, p.y, p.z)
	return {"g": g, "ring": ring, "glow": glow, "chevrons": chev}


## Staged load: freight crate on a cradle at the gantry lip, held by an amber release clamp on the pit-facing lip side, with a blinking red tag.
func _build_load(p: Dictionary) -> Dictionary:
	var g := _group(self)
	var side: float = p.side
	_mesh(g, G.box, M.crate, Vector3(0.0, 0.95, 0.0), Vector3(2.2, 1.6, 2.2))
	_mesh(g, G.box, M.dark, Vector3(0.0, 0.075, 0.0), Vector3(2.5, 0.15, 2.5))
	for x: float in [-1.05, 1.05]:
		_mesh(g, G.box, M.amber, Vector3(x, 0.75, -side * 1.15), Vector3(0.14, 1.2, 0.14))
	_mesh(g, G.box, M.amber, Vector3(0.0, 1.3, -side * 1.2), Vector3(2.3, 0.22, 0.3))
	var tag := _mesh(g, G.box, M.volt_hot, Vector3(0.0, 1.55, -side * 1.37), Vector3(0.5, 0.3, 0.05))
	g.position = Vector3(p.x, p.y, p.z)
	return {"g": g, "tag": tag}


static func _smooth(v: float) -> float:
	v = clampf(v, 0.0, 1.0)
	return v * v * (3.0 - 2.0 * v)


## Escape-wing floor height at world X: vault floor, then the 1:6 outbound rise.
func _escape_floor(x: float) -> float:
	var l := x - DX
	return -24.0 if l < 20.0 else minf(0.0, -24.0 + (l - 20.0) / 6.0)


func sync(time: float, dt: float) -> void:
	frame += 1
	var st := S.stage
	hauler.visible = st == "freight" or st == "reclamation"
	# In Freight the tug docks over the north staging gantry, where it collects loads.
	var home := Vector3(0.0 if st == "freight" else DX + 29.0, 11.8 if st == "freight" else -11.1, -20.0 if st == "freight" else 126.0)
	if tug_stage != st:
		tug_stage = st
		hauler.position = home
	if hauler.visible and S.drops.is_empty():
		hauler.position = hauler.position.lerp(home, 1.0 - exp(-dt * 2.0))
	for d: Dictionary in S.drums:
		if d.alive:
			var v := _view(d, _build_drum)
			var burning: bool = float(d.fuse) > 0.0
			var hot: bool = burning and int(floorf(float(d.flash) * 14.0)) % 2 == 0
			(v.body as MeshInstance3D).material_override = M.hot if hot else M.drum
			(v.ring as MeshInstance3D).material_override = M.ring_hot if burning else M.ring_idle
			var m: Material = M.volt_hot if hot else M.volt
			(v.ind as MeshInstance3D).material_override = m
			for x: MeshInstance3D in v.vents:
				x.material_override = m
	for p: Dictionary in S.loads:
		if p.alive:
			var v := _view(p, _build_load)
			(v.tag as Node3D).visible = int(floorf(time * 2.0)) % 2 == 0
	var warn_on: bool = int(floorf(time * 7.0)) % 2 == 1
	for q: Dictionary in S.drops:
		var v := _view(q, _build_drop)
		var cfg: Dictionary = q.cfg
		var warn := float(cfg.warn)
		var qt: float = q.t
		var landed: bool = q.landed
		var mt: Material = M.warn if landed or not warn_on else M.warn_hot
		(v.outer as MeshInstance3D).material_override = mt
		(v.inner as MeshInstance3D).material_override = mt
		var load: Node3D = v.load
		load.visible = not landed or float(q.land_t) < 0.3
		var shock: Node3D = v.shock
		shock.visible = landed
		if landed:
			var ss := 0.2 + float(q.land_t) * float(cfg.radius) * 1.6 / float(K.drum.radius)
			shock.scale = Vector3(ss, 1.0, ss)
		if q.has("gantry"):
			# Released from a gantry: the load tips off the lip and drops to the lane.
			var u := clampf(qt / warn, 0.0, 1.0)
			var si := maxf(0.05, u * float(cfg.radius))
			(v.inner as Node3D).scale = Vector3(si, 1.0, si)
			var gy: float = q.gantry.y
			var gz: float = q.gantry.z
			load.position = Vector3(0.0, 0.85 + (gy - float(q.y)) * (1.0 - u * u), (gz - float(q.z)) * (1.0 - u))
			load.rotation.x = -signf(gz) * u * 1.2
			continue
		var pr := 1.0 if landed else qt / warn
		var fall := _smooth((qt - (warn - 0.35)) / 0.35)
		var si2 := maxf(0.05, pr * float(cfg.radius))
		(v.inner as Node3D).scale = Vector3(si2, 1.0, si2)
		var travel := _smooth(qt / (warn - 0.5))
		hauler.position = Vector3(lerpf(home.x, q.x, travel), float(q.y) + 6.9, lerpf(home.z, q.z, travel))
		for i in tug_clamps.size():
			tug_clamps[i].position.x = (1.0 if i == 1 else -1.0) * (1.38 + fall * 0.8)
		load.position = Vector3(hauler.position.x - float(q.x), 0.85 + 5.0 * (1.0 - fall), hauler.position.z - float(q.z))
	tug_camera.place(hauler.position.x, hauler.position.z)
	tug_camera.set_span(hauler.position.y - 1.45, hauler.position.y + 0.55)
	tug_camera.set_off(not hauler.visible)
	for p: Dictionary in S.pads:
		var v := _view(p, _build_pad)
		var fl: float = p.flash
		var rs := 1.0 + fl * 0.35
		(v.ring as Node3D).scale = Vector3(rs, 1.0, rs)
		var gs := 1.3 + fl * 0.6
		(v.glow as Node3D).scale = Vector3(gs, 1.0, gs)
		var ch: Array = v.chevrons
		for i in ch.size():
			var u := fposmod(time * 1.2 + i / 3.0, 1.0)
			var c: MeshInstance3D = ch[i]
			c.position.y = 0.2 + u * 2.4
			(c.material_override as StandardMaterial3D).albedo_color.a = 0.7 * (1.0 - u)
	for k: int in views.keys():
		var v: Dictionary = views[k]
		if int(v.seen) != frame:
			(v.g as Node3D).queue_free()
			views.erase(k)
	var ch: Dictionary = S.chase
	var live: bool = ch.phase != "idle"
	slag.visible = live
	if not live:
		light.light_energy = 0.0
	slag_box.live = live
	if live:
		var cfg: Dictionary = K.chase
		var x: float = ch.x
		var l := x - DX
		var width := float(cfg.vaultWidth) + (float(cfg.corridorWidth) - float(cfg.vaultWidth)) * _smooth((l - float(cfg.taperFrom)) / (float(cfg.taperTo) - float(cfg.taperFrom)))
		var rise: float = _smooth(float(ch.rise)) if ch.phase == "rise" else 1.0
		slag.position = Vector3(x, _escape_floor(x) + 4.5 - (1.0 - rise) * 10.0, cfg.centerZ)
		body.scale.z = width
		lamp.scale.z = width * 0.8
		# Rear plate to the roller fronts, for the level's camera blocker.
		var depth := float(cfg.depth)
		slag_box.x0 = x - depth / 2.0
		slag_box.x1 = x + depth / 2.0 + 1.3
		slag_box.cz = cfg.centerZ
		slag_box.hz = width / 2.0
		slag_box.bottom = slag.position.y - 4.5
		slag_box.top = slag.position.y + 4.5
		var running: bool = ch.phase != "done"
		for tr: Dictionary in tracks:
			(tr.t as Node3D).position = Vector3(0.0, -4.05, float(tr.side) * (width / 2.0 - 0.8))
			if running:
				for w: Node3D in tr.wheels:
					w.rotate_object_local(Vector3.UP, dt * float(ch.speed) * 2.0)
		for i in spikes.size():
			spikes[i].position.z = (float(i) / (spikes.size() - 1) - 0.5) * (width - 1.2)
		for i in rollers.size():
			rollers[i].scale = Vector3(1.05, width, 1.05)
			if running:
				rollers[i].rotate_object_local(Vector3.UP, dt * (-1.0 if i == 1 else 1.0) * 4.0)
		for s: Dictionary in strips:
			(s.s as Node3D).position.z = float(s.f) * width
		var pulse := 0.5 + 0.5 * sin(time * 8.0)
		lamp.visible = running or int(floorf(time * 3.0)) % 2 == 0
		light.position = Vector3(x + depth / 2.0 + 2.5, slag.position.y, cfg.centerZ)
		light.light_energy = (4.0 if not running else 22.0 + pulse * 18.0) / PI
