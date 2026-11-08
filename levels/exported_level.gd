class_name ExportedLevel
extends Level
## A level built from what tools/export/export.mjs took out of the three.js game: scene.glb (meshes), colliders.json (the World), level.json (spawn, fog, lights, portals...),
## instances.bin (MultiMesh transforms). Static world only: level logic plugs in on top by subclassing this and finding its moving things by their JS name (node_named, solids_tagged).

const DIR := "res://assets/levels/"

var look: Variant = null                 # a level's own look entry (View.level_built reads it; otherwise core/looks.gd by id)
var info: Dictionary = {}                # level.json
var scene_root: Node3D = null            # the instantiated scene.glb
var by_name: Dictionary = {}             # JS .name -> Array of Node3D (everything that stayed a separate node)
var moving_solids: Array[World.Solid] = []
var lights: Array[Light3D] = []
var city: CityLife = null       # the city's per-frame life, on levels that have a JS CityView
var timing: Dictionary = {}              # ms per build step
var dev_shot: View.Shot = null           # tools/export/level_probe.gd: the view of a reference picture of the three.js build
var shader_ports: ShaderPorts = null     # the hand-ported shaders on this level (levels/shader_ports.gd)
var _nodes: Dictionary = {}              # node name in the GLB -> node


## Something built after the export answers to its JS name too.
func add_named(js_name: String, n: Node3D) -> void:
	_name_node(js_name, n)


func build() -> void:
	var t0 := Time.get_ticks_usec()
	var dir := DIR + id + "/"
	info = _json(dir + "level.json")
	if info.is_empty():
		push_error("exported level '%s': no level.json (run node tools/export/export.mjs level %s)" % [id, id])
		return
	_build_world_fields()
	for d: Dictionary in info.get("portals", []):      # (level.json: a level's own doors)
		portals.append(d)
	_build_colliders(dir)
	var t1 := Time.get_ticks_usec()
	_build_scene(dir)
	var t2 := Time.get_ticks_usec()
	_build_instances(dir)
	shader_ports = ShaderPorts.apply(self, dir)
	_build_lights()
	_apply_render_state()
	var t3 := Time.get_ticks_usec()
	timing = {"colliders_ms": (t1 - t0) / 1000.0, "scene_ms": (t2 - t1) / 1000.0, "rest_ms": (t3 - t2) / 1000.0, "total_ms": (t3 - t0) / 1000.0}


func camera_override(_rig: Variant, _player: Variant, _dt: float) -> View.Shot:
	return dev_shot


## What stayed a separate node under this JS name ([] if nothing did).
func node_named(js_name: String) -> Array:
	return by_name.get(js_name, [])


## All solids with this tag, for level logic that drives doors and lifts.
func solids_tagged(tag: String) -> Array[World.Solid]:
	var out: Array[World.Solid] = []
	for s in world.solids:
		if s.tag == tag:
			out.append(s)
	return out


# ---------------------------------------------------------------- collision ----

func _build_world_fields() -> void:
	var sp: Dictionary = info.get("spawn", {})
	world.spawn = {"x": float(sp.get("x", 0.0)), "y": float(sp.get("y", 0.0)), "z": float(sp.get("z", 0.0)), "yaw": float(sp.get("yaw", 0.0))}
	world.fall_reset_y = float(info.get("fall_reset_y", -25.0))
	world.poles = info.get("poles", [])
	world.camera_room_dist = float(info.get("camera_room_dist", 0.0))
	world.camera_room_lens_max = float(info.get("camera_room_lens_max", 0.0))
	world.camera_no_swing = bool(info.get("camera_no_swing", false))
	# what Combat reads off the world: a JS world without them gets the original range's targets and pods (null), a level that says [] gets none
	var wx: Dictionary = info.get("world_extra", {})
	if wx.has("targetSpots"):
		world.target_spots = wx["targetSpots"]
	if wx.has("pickupSpots"):
		world.pickup_spots = wx["pickupSpots"]
	if wx.has("clerkSpot"):
		world.clerk_spot = wx["clerkSpot"]
	if wx.has("projectileFloorY"):
		world.projectile_floor_y = float(wx["projectileFloorY"])
	if wx.has("droneLeash"):
		world.drone_leash = bool(wx["droneLeash"])
	var w: Variant = info.get("water")
	if w is Dictionary:
		world.water = ExportedGrids.Water.new(w)
	var cz: Variant = info.get("camera_zone")
	if cz is Dictionary and (cz as Dictionary).has("grid"):
		var g := ExportedGrids.Sparse.new((cz as Dictionary)["grid"])
		world.camera_zone_weight = func(p: Variant) -> float: return g.at(p.x, p.z, 0.0)


func _build_colliders(dir: String) -> void:
	var c: Dictionary = _json(dir + "colliders.json")
	var fields := PackedFloat32Array()
	if c.has("fields_file"):
		fields = FileAccess.get_file_as_bytes(dir + String(c["fields_file"])).to_float32_array()
	for d: Dictionary in c.get("solids", []):
		if not _keep_solid(d):
			continue
		var s := world.add(_solid_dict(d, fields))
		if d.has("moves"):
			moving_solids.append(s)
	for d: Dictionary in c.get("cam_solids", []):
		var s := world.add_camera_blocker(_solid_dict(d, fields))
		if d.has("moves"):
			moving_solids.append(s)
	var t: Variant = c.get("tris")
	if t is Dictionary:
		var f := FileAccess.get_file_as_bytes(dir + String((t as Dictionary)["file"])).to_float32_array()
		var v := PackedVector3Array()
		v.resize(f.size() / 3)
		for i in v.size():
			v[i] = Vector3(f[i * 3], f[i * 3 + 1], f[i * 3 + 2])
		world.add_mesh(v, "mesh")


## A level that rebuilds some solids itself leaves them out here.
func _keep_solid(_d: Dictionary) -> bool:
	return true


func _solid_dict(d: Dictionary, fields: PackedFloat32Array) -> Dictionary:
	if d.get("kind", "") == "field":
		var g: Dictionary = d["grid"]
		var n := int(g["n"])
		var off := int(g["off"]) / 4
		var x0: float = g["x0"]
		var z0: float = g["z0"]
		var cell: float = d["cell"]
		d["fn"] = func(x: float, z: float) -> float:
			var fx := clampf((x - x0) / cell, 0.0, n - 1.001)
			var fz := clampf((z - z0) / cell, 0.0, n - 1.001)
			var i := int(fx)
			var j := int(fz)
			fx -= i
			fz -= j
			var a := off + i * n + j
			var h0 := lerpf(fields[a], fields[a + 1], fz)
			var h1 := lerpf(fields[a + n], fields[a + n + 1], fz)
			return lerpf(h0, h1, fx)
		if d.get("floor") == null:
			d.erase("floor")
	return d


# ---------------------------------------------------------------- meshes ----

func _build_scene(dir: String) -> void:
	var ps: PackedScene = load(dir + "scene.glb")
	if ps == null:
		push_error("exported level '%s': scene.glb not imported (node tools/import.mjs)" % id)
		return
	scene_root = ps.instantiate()
	scene_root.name = "Scene"
	add_child(scene_root)
	_index(scene_root)


## One walk over the imported tree: who is who, by the name the exporter gave the node (for instances) and by the JS name (for level logic)
func _index(n: Node) -> void:
	_nodes[n.name] = n
	var x: Dictionary = n.get_meta("extras", {})
	if x.has("js_name"):
		_name_node(String(x["js_name"]), n as Node3D)
	for c in n.get_children():
		_index(c)


func _name_node(nm: String, n: Node3D) -> void:
	if not by_name.has(nm):
		by_name[nm] = []
	by_name[nm].append(n)


func _build_instances(dir: String) -> void:
	var list: Array = info.get("instances", [])
	if list.is_empty() or scene_root == null:
		return
	var bytes := FileAccess.get_file_as_bytes(dir + String(info["instances_file"]))
	var tpl_root := scene_root.get_node_or_null("instancing_templates")
	if tpl_root == null:
		push_error("exported level '%s': no instancing templates in scene.glb" % id)
		return
	var group := Node3D.new()
	group.name = "Instances"
	add_child(group)
	var i := 0
	for e: Dictionary in list:
		var tpl := tpl_root.get_node_or_null(String(e["tpl"])) as MeshInstance3D
		if tpl == null:
			continue
		var count := int(e["count"])
		var stride := 16 if e["colors"] else 12
		var off := int(e["off"])
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = e["colors"]
		mm.mesh = tpl.mesh
		mm.instance_count = count
		mm.buffer = bytes.slice(off, off + count * stride * 4).to_float32_array()
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.name = "mm%d_%s" % [i, String(e["tpl"])]
		mi.cast_shadow = tpl.cast_shadow
		mi.visible = not e.get("hidden", false)
		var parent: Node = group
		var pn := String(e.get("parent", ""))
		if pn != "":
			parent = _nodes.get(StringName(pn), group)
		parent.add_child(mi)
		if String(e.get("name", "")) != "":
			_name_node(String(e["name"]), mi)
		i += 1
	tpl_root.free()


# ---------------------------------------------------------------- lights ----

## three.js r160 lights: radiance = colour * intensity, and the BRDF divides by PI. Godot multiplies a light's energy by PI first, so energy = intensity / PI, for every light type,
## and with the same decay exponent and range window (omni_attenuation = decay) the falloff is the same curve. Hemisphere and ambient lights go into the environment.
func camera_placed(cam: Vector3, real_dt: float) -> void:
	if city != null:
		city.update(real_dt, cam)


func _build_lights() -> void:
	var group := Node3D.new()
	group.name = "Lights"
	add_child(group)
	for j: Dictionary in info.get("lights", []):
		var t := String(j.get("type", ""))
		var l: Light3D = null
		match t:
			"point":
				var o := OmniLight3D.new()
				o.omni_range = _light_range(j)
				o.omni_attenuation = float(j.get("decay", 2.0))
				l = o
			"spot":
				var s := SpotLight3D.new()
				s.spot_range = _light_range(j)
				s.spot_attenuation = float(j.get("decay", 2.0))
				s.spot_angle = rad_to_deg(float(j.get("angle", 0.5)))
				s.spot_angle_attenuation = ExportedLevel.spot_k(float(j.get("penumbra", 0.0)))
				l = s
			"dir":
				l = DirectionalLight3D.new()
			_:
				continue
		l.name = "L%d_%s" % [lights.size(), String(j.get("name", t)).validate_node_name()]
		var col: Array = j["color"]
		l.light_color = Color(col[0], col[1], col[2]).linear_to_srgb()
		l.light_energy = float(j.get("intensity", 1.0)) / PI
		l.shadow_enabled = bool(j.get("cast", false)) and bool(info.get("shadows", true))
		var p: Array = j["pos"]
		var pos := Vector3(p[0], p[1], p[2])
		if j.has("target"):
			var q: Array = j["target"]
			var aim := Vector3(q[0], q[1], q[2]) - pos
			if aim.length_squared() > 1e-6:
				l.transform = Transform3D(Basis.looking_at(aim, Vector3.RIGHT if absf(aim.normalized().y) > 0.99 else Vector3.UP), pos)
			else:
				l.position = pos
		else:
			l.position = pos
		l.visible = not j.get("hidden", false)
		var d: Variant = j.get("dyn")
		if d != null:
			l.set_meta("dyn", d)
		if t != "dir" and lights.size() >= 24:
			# the three.js LightPool draws the 32 nearest in view: far ones fade out here too, so a level full of lamps stays cheap
			l.distance_fade_enabled = true
			l.distance_fade_begin = maxf(50.0, _light_range(j) * 2.5)
			l.distance_fade_length = 20.0
		group.add_child(l)
		lights.append(l)
		if String(j.get("name", "")) != "":
			_name_node(String(j["name"]), l)


## three.js penumbra as Godot's spot_angle_attenuation. three.js: a smoothstep between the cone and the penumbra cone. Godot: (1 - rim)^k with rim = (1 - cos) / (1 - cos cone), so a LARGE k is a small hot core and a small k a flat beam with a sharp edge. This k puts Godot's half brightness where the smoothstep has it. (Measured against the JS on a grey board in the rental's beam: 91, 83, 69 here against 94, 82, 66.)
static func spot_k(penumbra: float) -> float:
	return maxf(0.05, log(0.5) / log(1.0 - pow(1.0 - clampf(penumbra, 0.0, 1.0) * 0.5, 2.0))) if penumbra > 0.0 else 0.05


## three.js distance 0 means no limit; a Godot light always has a range: out to where it would add about 1/400 of white
func _light_range(j: Dictionary) -> float:
	var d := float(j.get("distance", 0.0))
	if d > 0.0:
		return d
	var decay := maxf(0.1, float(j.get("decay", 2.0)))
	return clampf(pow(float(j.get("intensity", 1.0)) * 400.0 / PI, 1.0 / decay), 10.0, 4000.0)


# ---------------------------------------------------------------- render state ----

## Everything the level's mount did to the scene and renderer goes through the View (core/view.gd owns sun, sky, fog, tone mapping and the post look). Colours are display colours there.
func _apply_render_state() -> void:
	var d := {}
	var bg: Dictionary = info.get("background", {})
	if bg.get("type") == "color":
		d["background"] = Color.html(String(bg["hex"]))
	d["tone_mapping"] = View.TONE_ACES if info.get("tone_mapping") == "aces" else View.TONE_NONE
	d["exposure"] = float(info.get("exposure", 1.0))
	var f: Variant = info.get("fog")
	if f is Dictionary:
		var fd := f as Dictionary
		var c := Color.html(String(fd["hex"]))
		d["fog"] = [c, float(fd["density"])] if fd.get("type") == "exp2" else [c, float(fd["near"]), float(fd["far"])]
	else:
		d["fog"] = null
	# the View has one hemisphere: the JS one plus any hemisphere and ambient lights the level added
	var sky_c := Vector3.ZERO
	var gnd_c := Vector3.ZERO
	var h: Dictionary = info.get("hemi", {})
	var extra := false
	for j: Dictionary in info.get("lights", []):
		if j.get("hidden", false):
			continue
		if j.get("type") == "hemi":
			sky_c += _v3(j["color"]) * float(j["intensity"])
			gnd_c += _v3(j["ground"]) * float(j["intensity"])
			extra = true
		elif j.get("type") == "ambient":
			sky_c += _v3(j["color"]) * float(j["intensity"])
			gnd_c += _v3(j["color"]) * float(j["intensity"])
			extra = true
	var hi := float(h.get("intensity", 0.0)) if bool(h.get("visible", false)) else 0.0
	if extra:
		sky_c += _v3(h["color"]) * hi
		gnd_c += _v3(h["ground"]) * hi
		var top := maxf(sky_c.x, maxf(sky_c.y, maxf(sky_c.z, maxf(gnd_c.x, maxf(gnd_c.y, gnd_c.z)))))
		var k := maxf(top, 1.0)
		d["hemi"] = [Color(sky_c.x / k, sky_c.y / k, sky_c.z / k).linear_to_srgb(), Color(gnd_c.x / k, gnd_c.y / k, gnd_c.z / k).linear_to_srgb(), k]
	else:
		d["hemi"] = [_srgb(h["color"]), _srgb(h["ground"]), hi]
	var s: Dictionary = info.get("sun", {})
	d["sun"] = [_srgb(s["color"]), float(s.get("intensity", 0.0)) if bool(s.get("visible", false)) else 0.0]
	d["sun_cast"] = bool(s.get("cast", false)) and bool(info.get("shadows", true))
	var cam: Dictionary = info.get("camera", {})
	d["clip"] = [float(cam.get("near", 0.1)), float(cam.get("far", 500.0))]
	Game.view.apply_render_state(d)
	if info.get("look") is Dictionary:
		look = info["look"]


static func _srgb(a: Array) -> Color:
	return Color(a[0], a[1], a[2]).linear_to_srgb()


static func _v3(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])


static func _json(path: String) -> Dictionary:
	var txt := FileAccess.get_file_as_string(path)
	if txt == "":
		return {}
	var v: Variant = JSON.parse_string(txt)
	return v if v is Dictionary else {}
