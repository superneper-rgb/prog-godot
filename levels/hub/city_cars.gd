class_name CityCars
extends RefCounted
## FOINT CITY's fleet (2026-11-10, replaces the cars the export brought from the JS): the models of assets/vehicles/city (built by tools/cars/build_cars.py), their four shared materials, the mesh the street's MultiMeshes draw and the model you drive. The traffic (city_traffic.gd) and the driving (city_driving.gd) keep their own logic and sizes: only what a car looks like comes from here.
## 2026-11-11 (user: too sleek, toy cars, and the doors no longer opened): the models got hard body lines, pillars and a roof over the glass, grilles, handles and mirrors, and a driver's door cut out of the body over a cabin with a seat and a steering wheel (the model's "Door" and "Steer" meshes, their origins the hinge and the wheel's centre).

const DIR := "res://assets/vehicles/city/"
## where each kind's lamp sprites sit, in the street's car frame (x forward, y up, z side). The export's own (life.json) were measured on the old bodies.
const LAMPS := {
	&"sedan": {"head": [[2.28, 0.48, -0.5], [2.28, 0.48, 0.5]], "tail": [[-2.26, 0.72, -0.62], [-2.26, 0.72, 0.62]], "ind": [[2.15, 0.48, -0.74], [2.15, 0.48, 0.74], [-2.2, 0.72, -0.8], [-2.2, 0.72, 0.8]]},
	&"hatch": {"head": [[1.92, 0.62, -0.45], [1.92, 0.62, 0.45]], "tail": [[-1.93, 0.72, -0.4], [-1.93, 0.72, 0.4]], "ind": [[1.8, 0.62, -0.66], [1.8, 0.62, 0.66], [-1.9, 0.72, -0.62], [-1.9, 0.72, 0.62]]},
	&"taxi": {"head": [[2.28, 0.51, -0.5], [2.28, 0.51, 0.5]], "tail": [[-2.27, 0.765, -0.62], [-2.27, 0.765, 0.62]], "ind": [[2.15, 0.51, -0.74], [2.15, 0.51, 0.74], [-2.2, 0.765, -0.8], [-2.2, 0.765, 0.8]], "roof": [[-0.23, 1.5, 0.0]]},
	&"van": {"head": [[2.44, 0.7, -0.55], [2.44, 0.7, 0.55]], "tail": [[-2.47, 1.25, -0.75], [-2.47, 1.25, 0.75]], "ind": [[2.3, 0.7, -0.78], [2.3, 0.7, 0.78], [-2.46, 1.6, -0.76], [-2.46, 1.6, 0.76]]},
	&"truck": {"head": [[3.58, 0.98, -0.6], [3.58, 0.98, 0.6]], "tail": [[-3.62, 2.1, -0.98], [-3.62, 2.1, 0.98]], "ind": [[3.45, 0.98, -0.9], [3.45, 0.98, 0.9], [-3.62, 2.8, -0.98], [-3.62, 2.8, 0.98]]},
	&"bus": {"head": [[5.72, 1.02, -0.6], [5.72, 1.02, 0.6]], "tail": [[-5.74, 1.65, -1.0], [-5.74, 1.65, 1.0]], "ind": [[5.55, 1.02, -0.95], [5.55, 1.02, 0.95], [-5.74, 2.3, -1.0], [-5.74, 2.3, 1.0]], "roof": [[5.4, 2.52, -0.4], [5.4, 2.52, 0.4]]},
	&"saucerG": {"head": [[1.88, 0.6, -0.3], [1.88, 0.6, 0.3]], "tail": [[-1.88, 0.6, -0.3], [-1.88, 0.6, 0.3]], "ind": [[1.7, 0.6, -0.6], [1.7, 0.6, 0.6], [-1.7, 0.6, -0.6], [-1.7, 0.6, 0.6]]},
	&"saucerN": {"head": [[1.85, 0.66, -0.3], [1.85, 0.66, 0.3]], "tail": [[-2.1, 0.76, -0.2], [-2.1, 0.76, 0.2]], "ind": [[1.6, 0.66, -0.5], [1.6, 0.66, 0.5], [-1.9, 0.62, -1.03], [-1.9, 0.62, 1.03]]},
}
## each kind's seat fitted to its new body (the export's were measured on the old, taller ones, and its roof fell back on the old body height: Prog's head came up through the sedan's canopy and his feet out under the floor). y: the hips; roof: the inside of the roof / canopy over the head (ray-cast on these models); recline: a low seat he leans back in (rad); scale: the smallest he is drawn, which still fits; dz: the seat and wheel moved forward. The wheel moves with the seat (build_cars.py SEAT puts the model's steering wheel and seat there: keep the two in step).
const SEATS := {
	&"sedan": {"y": 0.43, "roof": 1.16, "recline": 0.3, "scale": 0.68},
	&"hatch": {"y": 0.53, "roof": 1.36, "recline": 0.2, "scale": 0.7},
	&"taxi": {"y": 0.46, "roof": 1.29, "recline": 0.2, "scale": 0.7},
	&"van": {"roof": 1.97, "dz": -0.3},
	&"truck": {"roof": 2.43},
	&"bus": {"roof": 2.85},
	&"saucerG": {"y": 1.13, "roof": 2.2, "recline": 0.3, "scale": 0.74},      # (2026-11-11: the domes grew to fit the aliens, so Prog is no longer shrunk to half size in them)
	&"saucerN": {"y": 1.2, "roof": 2.36, "recline": 0.3, "scale": 0.72, "dz": -0.3},
}
## the driver's door of the kinds that have one, in the controller's axes (x left, z forward): it spans z0..z1 along the car, hinged at z1, its outer face at x, and swings open by `open` rad (build_cars.py DOOR cuts it there: keep the two in step)
const DOORS := {
	&"sedan": {"z0": -0.58, "z1": 0.60, "x": 0.95, "open": 1.18},
	&"hatch": {"z0": -0.44, "z1": 0.62, "x": 0.87, "open": 1.18},
	&"taxi": {"z0": -0.36, "z1": 0.70, "x": 0.95, "open": 1.18},
	&"van": {"z0": -0.20, "z1": 0.82, "x": 0.98, "open": 1.18},
	&"truck": {"z0": 2.05, "z1": 3.00, "x": 1.16, "open": 1.18},
}
## the surfaces build_cars.py writes -> which of the street's MultiMeshes draws them ("CarsTrim-" takes the parts and the lights as two surfaces; the old "CarsNeon-" is not drawn)
const GROUPS: Array[StringName] = [&"CarPaint", &"CarParts", &"CarGlass", &"CarLights", &"CarDome"]      # (the order is the sky traffic's `part`, hub_life.gd: new ones go last)


## one wheel of a model to drive: the pivot steers, the mesh under it spins
class CarWheel:
	var pivot: Node3D
	var spin: Node3D
	var front := false


## a model to drive: +Z forward, +X left, origin on the ground under the middle
class CarModel:
	var root: Node3D
	var chassis: Node3D
	var wheels: Array[CarWheel] = []
	var door: Node3D = null       # the driver's door: a pivot at its hinge (its front edge), turn it about Y
	var steer: Node3D = null      # the steering wheel: a pivot at its centre


var mats: Dictionary = {}       # group -> ShaderMaterial, shared by every car
var _street: Dictionary = {}    # kind -> {group -> ArrayMesh}, in the street's frame (x forward)
var _own: Array[WeakRef] = []   # the paint, parts and glass of the cars being driven, and the flying cars: they follow the sky too


func _init() -> void:
	for g: StringName in GROUPS:
		var m := ShaderMaterial.new()
		m.shader = load("res://levels/shaders/car_%s.gdshader" % ("glass" if g == &"CarDome" else String(g).trim_prefix("Car").to_lower()))
		mats[g] = m
	(mats[&"CarDome"] as ShaderMaterial).set_shader_parameter(&"alpha", 0.34)
	(mats[&"CarDome"] as ShaderMaterial).set_shader_parameter(&"rim", 0.8)      # the alien craft's bubbles: the same glass, clear enough to see the pilot standing under it


## the level's sky in every car's paint and glass (hub_level.gd calls this as the sky drifts)
func set_sky(hor: Vector3, band: Vector3, zen: Vector3) -> void:
	var list: Array[ShaderMaterial] = [mats[&"CarPaint"], mats[&"CarParts"], mats[&"CarGlass"], mats[&"CarDome"]]
	_own = _own.filter(func(w: WeakRef) -> bool: return w.get_ref() != null)      # (a car that was freed has let its paint go)
	for w in _own:
		list.append(w.get_ref())
	for m in list:
		m.set_shader_parameter(&"sky_hor", hor)
		m.set_shader_parameter(&"sky_band", band)
		m.set_shader_parameter(&"sky_zen", zen)


static func _group_of(mesh: Mesh, surface: int) -> StringName:
	var m := mesh.surface_get_material(surface)
	return StringName(m.resource_name) if m != null else &""


static func _to_root(n: Node3D, root: Node) -> Transform3D:
	var x := Transform3D.IDENTITY
	var c: Node = n
	while c != root and c is Node3D:
		x = (c as Node3D).transform * x
		c = c.get_parent()
	return x


## the whole car of one kind as one mesh per surface group, turned into the street's frame (the MultiMeshes' x is the car's heading, the models' z is)
func _street_of(kind: StringName) -> Dictionary:
	if _street.has(kind):
		return _street[kind]
	var out := {}
	var ps: PackedScene = load(DIR + String(kind) + "_street.glb")
	var scene: Node3D = ps.instantiate()
	var tools := {}
	var turn := Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3.ZERO)
	for mi: MeshInstance3D in _meshes(scene):
		var x := turn * _to_root(mi, scene)
		for i in mi.mesh.get_surface_count():
			var g := _group_of(mi.mesh, i)
			if not GROUPS.has(g):
				continue
			if not tools.has(g):
				tools[g] = SurfaceTool.new()
			(tools[g] as SurfaceTool).append_from(mi.mesh, i, x)
	for g: StringName in tools:
		var am: ArrayMesh = (tools[g] as SurfaceTool).commit()
		am.surface_set_material(0, mats[g])
		out[g] = am
	scene.free()
	_street[kind] = out
	return out


## one of the street's car MultiMeshes ("Cars-", "CarsTrim-", "CarsGlass-", "CarsNeon-", "CarsUnderglow-" + kind) takes the new car. False: this one is no longer drawn.
func dress(mi: MultiMeshInstance3D, part: String, kind: StringName) -> bool:
	var S := _street_of(kind)
	var mesh: ArrayMesh = null
	match part:
		"Cars-":
			mesh = S.get(&"CarPaint")
		"CarsGlass-":
			mesh = S.get(&"CarGlass", S.get(&"CarDome"))
		"CarsTrim-":
			var st := SurfaceTool.new()
			mesh = ArrayMesh.new()
			for g: StringName in [&"CarParts", &"CarLights"]:
				if S.has(g):
					st.clear()
					st.append_from(S[g], 0, Transform3D.IDENTITY)
					st.commit(mesh)
					mesh.surface_set_material(mesh.get_surface_count() - 1, mats[g])
		"CarsUnderglow-":
			return true
	if mesh == null:
		mi.visible = false
		return false
	mi.multimesh.mesh = mesh
	mi.material_override = null
	return true


## a flying car's model (tools/cars/sky_cars.py) as one mesh, a surface per group named for it, in its own frame (+Z forward): the sky traffic sets its materials (hub_life.gd)
func sky_mesh(kind: StringName) -> ArrayMesh:
	var ps: PackedScene = load(DIR + String(kind) + "_street.glb")
	var scene: Node3D = ps.instantiate()
	var tools := {}
	for mi: MeshInstance3D in _meshes(scene):
		var x := _to_root(mi, scene)
		for i in mi.mesh.get_surface_count():
			var g := _group_of(mi.mesh, i)
			if not GROUPS.has(g):
				continue
			if not tools.has(g):
				tools[g] = SurfaceTool.new()
			(tools[g] as SurfaceTool).append_from(mi.mesh, i, x)
	var out := ArrayMesh.new()
	for g: StringName in GROUPS:
		if tools.has(g):
			(tools[g] as SurfaceTool).commit(out)
			out.surface_set_name(out.get_surface_count() - 1, String(g))
	scene.free()
	return out


## a material that takes the level's sky as the cars' do (set_sky)
func follow_sky(m: ShaderMaterial) -> void:
	for k: StringName in [&"sky_hor", &"sky_band", &"sky_zen"]:
		m.set_shader_parameter(k, (mats[&"CarPaint"] as ShaderMaterial).get_shader_parameter(k))
	_own.append(weakref(m))


## a car of this kind to drive, in this colour. seed: the slot it had in the street, so it keeps that car's grime (car_look.gdshaderinc car_grime)
func model(kind: StringName, colour: Color, seed: int = 0) -> CarModel:
	var ps: PackedScene = load(DIR + String(kind) + ".glb")
	var m := CarModel.new()
	m.root = ps.instantiate()
	m.chassis = Node3D.new()
	m.chassis.name = "Chassis"
	m.root.add_child(m.chassis)
	var own := {}      # group -> this car's own copy (its paint, and its seed in every surface the grime is on)
	for g: StringName in [&"CarPaint", &"CarParts", &"CarGlass", &"CarDome"]:
		var c := (mats[g] as ShaderMaterial).duplicate() as ShaderMaterial
		c.set_shader_parameter(&"own_seed", float(maxi(seed, 0)))
		for k: StringName in [&"sky_hor", &"sky_band", &"sky_zen"]:
			c.set_shader_parameter(k, (mats[g] as ShaderMaterial).get_shader_parameter(k))
		_own.append(weakref(c))
		own[g] = c
	(own[&"CarPaint"] as ShaderMaterial).set_shader_parameter(&"own_paint", Color(colour, 1.0))
	for mi: MeshInstance3D in _meshes(m.root):
		for i in mi.mesh.get_surface_count():
			var g := _group_of(mi.mesh, i)
			if mats.has(g):
				mi.set_surface_override_material(i, own.get(g, mats[g]))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF      # (as the street's cars: the city's light is baked)
		var x := _to_root(mi, m.root)
		if String(mi.name).begins_with("Wheel"):
			var w := CarWheel.new()
			w.pivot = Node3D.new()
			w.pivot.name = "Pivot_" + String(mi.name)
			m.root.add_child(w.pivot)
			w.pivot.position = x.origin
			mi.owner = null
			mi.get_parent().remove_child(mi)
			w.pivot.add_child(mi)
			mi.transform = Transform3D.IDENTITY
			w.spin = mi
			w.front = x.origin.z > 0.0
			m.wheels.append(w)
		elif String(mi.name).begins_with("Door") or String(mi.name).begins_with("Steer"):      # on a pivot at its own origin (the hinge, the wheel's centre)
			var pv := Node3D.new()
			pv.name = "Pivot_" + String(mi.name)
			m.chassis.add_child(pv)
			pv.position = x.origin
			mi.owner = null
			mi.get_parent().remove_child(mi)
			pv.add_child(mi)
			mi.transform = Transform3D(x.basis, Vector3.ZERO)
			if String(mi.name).begins_with("Door"):
				m.door = pv
			else:
				m.steer = pv
		else:
			mi.owner = null
			mi.get_parent().remove_child(mi)
			m.chassis.add_child(mi)
			mi.transform = x
	return m


## a kind's driver's door (DOORS), or null
static func door(kind: StringName) -> Variant:
	return DOORS.get(kind)


## the lamp places of a kind (the export's own where this has none)
static func lamps(kind: StringName, exported: Dictionary) -> Dictionary:
	return LAMPS.get(kind, exported)


## a kind's seat as the export gives it ({x, y, z, scale, wheel: {..}} for the car you drive, {seat: {..}, wheel: {..}} for the street's drivers) fitted to the new body (SEATS)
static func seat(kind: StringName, exported: Dictionary) -> Dictionary:
	var fit: Dictionary = SEATS.get(kind, {})
	var out := exported.duplicate(true)
	var s: Dictionary = out.get("seat", out)
	var dy: float = float(fit.get("y", s.y)) - float(s.y)
	var dz: float = fit.get("dz", 0.0)
	s.y = float(s.y) + dy
	s.z = float(s.z) + dz
	for k: String in ["roof", "recline", "scale"]:
		if fit.has(k) and (is_same(s, out) or k == "roof"):      # (the street's drivers have their own scale and pose: they take the place and the roof)
			s[k] = fit[k]
	var w: Variant = out.get("wheel")
	if w is Dictionary:
		w.y = float(w.y) + dy
		w.z = float(w.z) + dz
	return out


static func _meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var stack: Array[Node] = [n]
	while not stack.is_empty():
		var c: Node = stack.pop_back()
		stack.append_array(c.get_children())
		if c is MeshInstance3D:
			out.append(c)
	return out
