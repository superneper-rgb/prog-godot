class_name CityDriving
extends RefCounted
## FOINT CITY driving (JS levels/hub/city-driving.js): hands the city's own cars (traffic and parked) to the shared vehicle controller and takes them back. E next to a parked car: you get in. E next to a moving car: it pulls over to the kerb and stops; once it stands it is handed to the controller (the vehicle stands exactly where the car stopped, its door can open) and its driver climbs out, then you walk round to the door and get in. Got out: the vehicle stays where you left it, a solid box the traffic drives round; left alone and clear of you it goes back into the street. Crashes: every street car can be knocked (a vehicle hits it, a bullet stops on it, a blast reaches it): it becomes a vehicle on the spot, moving as it was, and its driver stays at the wheel until it stops or burns, then bails out and runs. A wreck stays until you are far away, then the car comes back pristine out of sight. The controller's side knows nothing about the city.

## handling per type, on top of Vehicles.Handling: small cars are quick and light, vans and trucks accelerate slowly and turn wide, the bus most of all; mass (kg) and hp for crashes and damage
const HANDLING := {
	&"hatch": {"top_speed": 33.0, "reverse_speed": 9.0, "accel": 10.6, "accel_curve": 1.3, "accel_at_top": 0.08, "brake": 19.0, "steer_low": 0.66, "steer_high": 0.12, "mu": 1.55, "yaw_inertia": 0.85, "mass": 1100.0, "hp": 700.0},
	&"sedan": {"top_speed": 34.0, "reverse_speed": 9.0, "accel": 10.2, "accel_curve": 1.3, "accel_at_top": 0.08, "brake": 18.0, "steer_low": 0.6, "steer_high": 0.11, "mu": 1.5, "yaw_inertia": 1.0, "mass": 1450.0, "hp": 800.0},
	&"taxi": {"top_speed": 35.0, "reverse_speed": 9.0, "accel": 10.4, "accel_curve": 1.3, "accel_at_top": 0.08, "brake": 18.0, "steer_low": 0.6, "steer_high": 0.11, "mu": 1.5, "yaw_inertia": 1.0, "mass": 1450.0, "hp": 800.0},
	&"van": {"top_speed": 28.0, "reverse_speed": 7.5, "accel": 7.4, "accel_curve": 1.3, "accel_at_top": 0.07, "brake": 15.0, "steer_low": 0.52, "steer_high": 0.09, "mu": 1.35, "yaw_inertia": 1.2, "steer_in": 2.3, "steer_out": 4.6, "mass": 2300.0, "hp": 1100.0},
	&"truck": {"top_speed": 23.0, "reverse_speed": 6.0, "accel": 5.3, "accel_curve": 1.3, "accel_at_top": 0.07, "brake": 12.0, "steer_low": 0.46, "steer_high": 0.08, "mu": 1.2, "yaw_inertia": 1.35, "steer_in": 2.0, "steer_out": 4.0, "rolling": 5.0, "handbrake_decel": 5.0, "mass": 7000.0, "hp": 1900.0, "crash": 3.2},
	&"bus": {"top_speed": 20.0, "reverse_speed": 5.5, "accel": 4.2, "accel_curve": 1.3, "accel_at_top": 0.07, "brake": 11.0, "steer_low": 0.42, "steer_high": 0.07, "mu": 1.1, "yaw_inertia": 1.5, "steer_in": 1.8, "steer_out": 3.6, "rolling": 4.5, "handbrake_decel": 4.0, "mass": 11500.0, "hp": 2800.0, "crash": 2.8},
	&"saucerG": {"top_speed": 36.0, "reverse_speed": 10.0, "accel": 13.0, "accel_curve": 1.2, "accel_at_top": 0.1, "brake": 16.0, "steer_low": 0.72, "steer_high": 0.14, "mu": 1.05, "yaw_inertia": 0.7, "mass": 900.0, "hp": 550.0},      # hovering: it slides
	&"saucerN": {"top_speed": 33.0, "reverse_speed": 9.0, "accel": 14.5, "accel_curve": 1.2, "accel_at_top": 0.1, "brake": 17.0, "steer_low": 0.78, "steer_high": 0.15, "mu": 1.25, "yaw_inertia": 0.8, "mass": 1000.0, "hp": 600.0},
}
const CAM := {&"hatch": {"dist": 6.8, "height": 1.8}, &"sedan": {"dist": 7.2, "height": 1.9}, &"taxi": {"dist": 7.2, "height": 1.9}, &"van": {"dist": 8.8, "height": 2.5}, &"truck": {"dist": 10.8, "height": 3.1}, &"bus": {"dist": 13.5, "height": 3.7}, &"saucerG": {"dist": 7.4, "height": 2.1}, &"saucerN": {"dist": 7.8, "height": 2.2}}
const ENGINE := {&"hatch": {"base": 34.0, "span": 130.0, "type": "sawtooth", "whine": 0.0}, &"sedan": {"base": 30.0, "span": 115.0, "type": "sawtooth", "whine": 0.0}, &"taxi": {"base": 30.0, "span": 115.0, "type": "sawtooth", "whine": 0.0}, &"van": {"base": 26.0, "span": 90.0, "type": "sawtooth", "whine": 0.0}, &"truck": {"base": 20.0, "span": 62.0, "type": "sawtooth", "whine": 0.0}, &"bus": {"base": 18.0, "span": 52.0, "type": "sawtooth", "whine": 0.0}, &"saucerG": {"base": 70.0, "span": 160.0, "type": "sine", "whine": 1.0}, &"saucerN": {"base": 48.0, "span": 110.0, "type": "triangle", "whine": 1.0}}
const ASPHALT := {"grip": 1.0, "rolling": 1.0}
const PAVING := {"grip": 0.8, "rolling": 1.7}
const OWNER := "hub"
const LAMP_SIZE := 0.75      # JS lampMat: PointsMaterial size 1.25, sizeAttenuation: as many pixels across as a quad this wide at the game's 62 degrees (size * tan(fov / 2)), the size the street's lamps draw at (car_lamps.gdshader)

var traffic: CityTraffic
var drivers: CityDrivers
var plan: CityPlan
var world: World
var parent: Node3D
var J: Dictionary
var RY := 0.0
var taken: Array = []
var deck_rects: Array = []
var driven: Variant = null
var clock := 0.0
var player0: Variant = null
var _beam_mesh: Mesh = null
var _beam_mat: Material = null
var _specs: Dictionary = {}      # kind -> the spec this instance registered (detach erases only these: the hub that replaces this one registers its own before this one's deferred free runs)
var _source: Dictionary = {}


func _init(p_traffic: CityTraffic, p_drivers: CityDrivers, p_plan: CityPlan, p_world: World, p_parent: Node3D, p_j: Dictionary) -> void:
	traffic = p_traffic
	drivers = p_drivers
	plan = p_plan
	world = p_world
	parent = p_parent
	J = p_j
	RY = traffic.RY
	deck_rects = J.get("deck_rects", [])
	for k: StringName in HANDLING:
		var cm: Dictionary = J["car_models"][String(k)]
		_specs[String(k)] = Vehicles.register_type(String(k), {"label": cm.name, "handling": HANDLING[k], "cam": CAM[k], "engine": ENGINE[k], "nitro": false, "tail_pluck": false,
			"build": func(o: Dictionary = {}) -> Vehicles.VModel: return make_model(k, int(o.get("color", cm.palette0)), int(o.get("glow", 0)))})
	var V: Vehicles = Game.vehicles
	_source = {"owner": OWNER, "nearest": nearest, "tick": tick, "knockable": knockable}
	V.sources.append(_source)


## take this instance's source and car types out of the controller (safe to call twice; never touches what a newer hub registered)
func detach() -> void:
	var V: Vehicles = Game.vehicles
	if V != null:
		V.sources.erase(_source)
	for k: String in _specs:      # (their build closures hold this object)
		if Vehicles.SPECS.has(k) and is_same(Vehicles.SPECS[k], _specs[k]):
			Vehicles.SPECS.erase(k)
	_specs.clear()


## leaving the hub: every car the controller holds is taken out of it. (No JS counterpart: there the hub is resident and enterLevel parks its cars with setOwnerActive('hub', false); here the hub node is freed, and a vehicle left in the controller would point at freed nodes, aborting the pose loop every frame before the next level's own car, which then drives off with the camera while its model stays behind.)
func release_all() -> void:
	var V: Vehicles = Game.vehicles
	if V == null:
		return
	for v: Vehicles.Veh in V.vehicles.duplicate():
		if v.owner_ == OWNER:
			v.on_clear = Callable()      # (the traffic goes with the level: nothing to park or resume)
			V.remove(v)
	taken.clear()
	driven = null
	detach()      # (now, not at the deferred free: a hub entered from the hub (RETURN TO MENU) has registered its own types by then, and the old erase took them away: no car could be driven again)


## a drivable model of a car type for the vehicle controller (+Z forward): shared geometry and trim / glass materials, its own paint material and lamps (JS traffic.kit.makeModel; the parts are exported per type, tools/export/city_car.expr.js)
func make_model(kind: StringName, colour: int, glow: int = 0) -> Vehicles.VModel:
	var cm: Dictionary = J["car_models"][String(kind)]
	var ps: PackedScene = load("res://assets/objects/car_%s.glb" % String(kind))
	var scene: Node3D = ps.instantiate()
	var parts := {}
	var stack: Array[Node] = [scene]
	while not stack.is_empty():
		var c: Node = stack.pop_back()
		stack.append_array(c.get_children())
		var nm := String(c.name)      # (the exporter names a node n<idx>_<js name>)
		if nm.begins_with("n") and nm.find("_") > 1 and nm.substr(1, nm.find("_") - 1).is_valid_int():
			nm = nm.substr(nm.find("_") + 1)
		if not parts.has(nm):
			parts[nm] = c
	var m := Vehicles.VModel.new()
	m.root = scene
	m.chassis = parts.get("C_chassis")
	# JS paintOf: the shared paint with its own colour. The export's material is that paint (vertex colours, shine, grime), so the car does not change colour when it stops being a street car
	var paint: StandardMaterial3D = null
	for nm: String in ["C_paint", "C_door_paint"]:
		if parts.has(nm):
			for mi: MeshInstance3D in _meshes(parts[nm]):
				if paint == null:
					paint = (mi.get_active_material(0) as Material).duplicate() as StandardMaterial3D
					paint.albedo_color = Color.hex((colour << 8) | 0xff).linear_to_srgb()      # (the street's MultiMesh takes the bytes as its linear colour: the same number here, or the car changes colour the moment it is taken)
				mi.material_override = paint
	m.wheel_r = cm.wheel_r
	m.hl = cm.hl
	m.hw = cm.hw
	m.cb = {"hl": cm.cb.hl, "hw": cm.cb.hw, "ox": cm.cb.ox}
	m.wheelbase = cm.wheelbase
	m.axle_f = cm.axle_f
	m.axle_r = cm.axle_r
	m.track = cm.track
	m.height = cm.height
	m.seat = cm.seat
	var wl: Array = cm.wheels
	for i in wl.size():
		var w := Vehicles.VWheel.new()
		w.pivot = parts.get("C_pivot%d" % i)
		w.spin = parts.get("C_spin%d" % i)
		w.front = wl[i].front
		m.wheels.append(w)
	# the driver's door: hinged at its front edge, opens outward (door(0..1))
	var door_p: Node3D = parts.get("C_door")
	if door_p != null and cm.door_info != null:
		m.door_info = cm.door_info
		var open_a: float = cm.door_info.open
		m.door = func(k: float) -> void: door_p.rotation.y = -k * open_a
	var steer_p: Node3D = parts.get("C_steer")
	if steer_p != null:
		var sw: Dictionary = cm.seat.wheel
		var n := Vector3(-cos(float(sw.tilt)), sin(float(sw.tilt)), 0.0).normalized()
		m.steer_wheel = func(steer: float) -> void: steer_p.quaternion = Quaternion(n, steer * 1.9)
	# lamps (head, tail) and the headlight pool on the road ahead
	var fix: Node3D = parts.get("C_fix")
	var heads: Array[MeshInstance3D] = []
	var tails: Array[MeshInstance3D] = []
	var lamps: Dictionary = cm.lamps
	if glow != 0 and not String(kind).begins_with("saucer"):      # (JS: !HOVER[kind]) the underglow it had in the street
		_street_part(fix, "CarsUnderglow-" + String(kind), func(b: StandardMaterial3D) -> void:
			b.vertex_color_use_as_albedo = false
			b.albedo_color = Color((Color.hex((glow << 8) | 0xff).srgb_to_linear() * 0.75).linear_to_srgb(), 1.0)
			Game.view.material_look.patch(b, {"decl": '#include "res://levels/shaders/common.gdshaderinc"', "frag": "ALBEDO = add_display(ALBEDO, ALPHA);
ALPHA = 1.0;"}))      # (the copy needs the additive look shader_ports gives the street's own)
	for q: Array in lamps.head:
		heads.append(_lamp(fix, q, 0xffebbf))
	for q: Array in lamps.tail:
		tails.append(_lamp(fix, q, 0xff140a))
	m.brake = func(b: bool) -> void:
		for t: MeshInstance3D in tails:
			MsKit.opa(t, 1.0 if b else 0.4)
	m.brake.call(false)
	var beam := _street_part(m.root, "HeadlightPools", Callable())      # JS: one headlight pool on the road ahead, the traffic's own quad and material
	if beam != null:
		beam.scale = Vector3(4.6, 1.0, 9.0)
		beam.position = Vector3(0.0, 0.03, float(cm.hl) + 4.6)
	return m


func _lamp(parent_: Node3D, q: Array, hex: int) -> MeshInstance3D:
	var s := MsKit.sprite8(parent_, hex, 1.0, LAMP_SIZE)
	s.position = Vector3(q[0], q[1], q[2])
	return s


## one piece of the street's car drawing as a mesh of its own (the quad and material of its MultiMesh); tune gets a copy of the material
func _street_part(under: Node3D, nm: String, tune: Callable) -> MeshInstance3D:
	for o: Node in Game.level.node_named(nm):
		if o is MultiMeshInstance3D and (o as MultiMeshInstance3D).multimesh.mesh != null:
			var mi := MeshInstance3D.new()
			mi.mesh = (o as MultiMeshInstance3D).multimesh.mesh
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.extra_cull_margin = 8.0
			if tune.is_valid():
				var b := mi.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
				tune.call(b)
				mi.material_override = b
			under.add_child(mi)
			return mi
	return null


static func _meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var stack: Array[Node] = [n]
	while not stack.is_empty():
		var c: Node = stack.pop_back()
		stack.append_array(c.get_children())
		if c is MeshInstance3D:
			out.append(c)
	return out


func _on_deck(x: float, z: float) -> bool:
	for r: Array in deck_rects:
		if x > float(r[0]) and x < float(r[1]) and z > float(r[2]) and z < float(r[3]):
			return true
	return false


## ground-dependent traction: asphalt on the roads, the bridge and the Deck network, slippier and rougher over the pavements and plazas
func surface(x: float, z: float, _y: float = 0.0) -> Dictionary:
	var land: Dictionary = J["land"]
	if z > float(land.z0) - 4.0 and z < float(land.z1) + 2.0 and x > float(land.x0) and x < float(land.x1) and not plan.on_road(x, z) and not _on_deck(x, z):
		return PAVING
	return ASPHALT


func heading(e: CityTraffic.Car) -> float:
	return atan2(e.hx, e.hz)


## how far the player stands from the car's body (0 = touching), or INF when it is on another floor
func reach(e: CityTraffic.Car, p: Variant) -> float:
	var dx: float = p.x - e.x
	var dz: float = p.z - e.z
	var f := absf(dx * e.hx + dz * e.hz)
	var s := absf(-dx * e.hz + dz * e.hx)
	if absf(float(p.y) - e.y) > 3.0:
		return INF
	return U.hyp(maxf(0.0, f - e.t.l), maxf(0.0, s - e.t.w))


## finding a car to drive
func nearest(player: Player) -> Variant:
	var best: CityTraffic.Car = null
	var bd := 2.7
	for c: CityTraffic.Car in traffic.cars:
		if c.ctl != &"" and c.ctl != &"stop" and c.ctl != &"static":
			continue
		var d := reach(c, player)
		if d < bd:
			bd = d
			best = c
	for c: CityTraffic.Car in traffic.parked:
		if c.ctl != &"" and c.ctl != &"stop" and c.ctl != &"static":
			continue
		var d := reach(c, player)
		if d < bd:
			bd = d
			best = c
	for v: Vehicles.Veh in taken:      # (its driver is still getting out)
		if v.data.get("pending", false):
			var d := reach(v.data.entry, player)
			if d < bd:
				bd = d
				best = v.data.entry
	if best == null:
		return null
	var e := best
	var waiting: bool = e.ctl == &"stop" or (e.veh != null and e.veh.data.get("pending", false))
	var nm: String = J["car_models"][String(e.kind)].name
	var label := nm + " - WAITING FOR THE DRIVER" if waiting else ("STOP & DRIVE " if e.parked_idx < 0 and e.ctl == &"" else "DRIVE ") + nm
	return {"d": bd, "label": label, "act": func() -> void:
		if not waiting:
			request(e)}


## E on a car: a parked one is yours at once, a moving one stops first
func request(e: CityTraffic.Car) -> void:
	if e.parked_idx >= 0 or e.ctl == &"static":      # (a parked car, or one that was left standing: nobody is in it)
		complete(e)
		return
	traffic.stop_for(e)
	Game.hud.toast("THE DRIVER IS PULLING OVER")


## the car becomes a vehicle of the controller where it stands (nobody in it yet); null when there is no room
func make_vehicle(e: CityTraffic.Car) -> Vehicles.Veh:
	var yaw := heading(e)
	if e.home0 == null:      # (where a parked car comes back to once its wreck is cleared)
		e.home0 = {"x": e.x, "z": e.z, "yaw": e.yaw, "hx": e.hx, "hz": e.hz, "y": e.y}
	traffic.take(e)
	# Resolve the height HERE, with a ceiling just above the car as it stands: a car handed over under a Deck viaduct would otherwise be placed on the deck 15 m up instead of the street.
	var gy := world.ground_height(e.x, e.z, 0.05, e.y + 1.2)
	var y0 := gy if is_finite(gy) else e.y
	var v: Vehicles.Veh = Game.vehicles.spawn(String(e.kind), e.x, e.z, yaw, y0, {"owner": OWNER, "parent": parent, "world": world, "surface": surface, "build": {"color": e.color, "glow": e.glow}, "solid": true, "data": {"entry": e, "kind": e.kind},
		"on_enter": func(veh: Vehicles.Veh) -> void:
			driven = veh
			traffic.player_driving = true
			veh.data.left = null
			veh.data.occupied = false
			e.seated_npc = false,
		"on_exit": func(veh: Vehicles.Veh, _force: bool) -> void:
			if driven == veh:
				driven = null
			traffic.player_driving = false
			veh.data.left = clock,
		"on_wreck": func(veh: Vehicles.Veh) -> void:
			if veh.data.get("occupied", false):
				veh.data.occupied = false
				e.seated_npc = false
			veh.data.bailed = true
			veh.data.no_enter = true
			if veh.data.get("left") == null and veh.driver == false:
				veh.data.left = clock,
		"on_clear": func(veh: Vehicles.Veh) -> void: release(veh)})
	if v == null:
		traffic.unhide(e)
		return null
	e.veh = v
	taken.append(v)
	v.data.origin = "car" if e.parked_idx < 0 else "parked"
	e.y = v.y
	return v


func complete(e: CityTraffic.Car) -> void:
	var V: Vehicles = Game.vehicles
	if V.driving or e.ctl == &"drive":
		return
	e.exit = null
	var v := make_vehicle(e)
	if v == null:
		Game.hud.toast("NO ROOM TO GET IN")
		return
	V.enter(v)


## a car that pulled over for the player stands still: it is handed over now, so its driver can open the real door and climb out (the player gets in when he is clear)
func hand_over(car: CityTraffic.Car) -> void:
	if Game.vehicles.driving:
		return
	var v := make_vehicle(car)
	if v == null:      # (no room for the vehicle: he gets out of the street's own car instead)
		drivers.begin_exit(car)
		return
	v.data.pending = true
	v.data.wanted = true
	v.data.no_enter = true
	car.exit = null
	drivers.begin_exit(car)


## a vehicle (or a bullet / blast: by = null) hit a street car: it becomes a vehicle of ours where it is, keeping its speed; its driver (a moving car has one) stays in until it stops
func knock(e: CityTraffic.Car, _by: Variant) -> Vehicles.Veh:
	if e.ctl == &"drive" or e.veh != null or (e.exit != null and e.exit.walker != null):
		return null
	var sp: float = 0.0 if e.ctl == &"static" else e.v
	var occupied: bool = e.parked_idx < 0 and e.ctl != &"static" and not drivers.piloted(e)
	var v := make_vehicle(e)
	if v == null:
		return null
	v.vx = sin(v.yaw) * sp
	v.vz = cos(v.yaw) * sp
	v.f = sp
	v.l = 0.0
	v.speed = sp
	v.data.knocked = true
	v.data.occupied = occupied
	v.data.no_enter = occupied
	e.seated_npc = occupied
	e.exit = null
	return v


## the street cars standing within r of a point (for the controller's crashes, shots and blasts), nearest first
func knockable(x: float, y: float, z: float, r: float) -> Array:
	var out: Array = []
	var add := func(e: CityTraffic.Car) -> void:
		if e.ctl == &"drive" or e.veh != null or e.solid == null or e.solid.off or absf(y - e.y) > 3.0 + e.t.h:
			return
		var dx := x - e.x
		var dz := z - e.z
		var f := absf(dx * e.hx + dz * e.hz)
		var s := absf(-dx * e.hz + dz * e.hx)
		var d := U.hyp(maxf(0.0, f - e.t.l), maxf(0.0, s - e.t.w))
		if d <= r:
			out.append({"d": U.hyp(dx, dz), "knock": func(by: Variant) -> Vehicles.Veh: return knock(e, by)})
	for c: CityTraffic.Car in traffic.cars:
		add.call(c)
	for c: CityTraffic.Car in traffic.parked:
		add.call(c)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.d < b.d)
	return out


## a wrecked car is gone for good: the street gets its car back, pristine, where nobody is looking
func respawn(e: CityTraffic.Car) -> void:
	e.veh = null
	e.exit = null
	e.seated_npc = false
	if e.parked_idx >= 0 and e.home0 != null:
		e.x = e.home0.x
		e.z = e.home0.z
		e.yaw = e.home0.yaw
		e.hx = e.home0.hx
		e.hz = e.home0.hz
		e.y = e.home0.y
		traffic.unhide(e)
	elif not traffic.respawn(e, player0):
		traffic.park(e, e.x, e.z, heading(e), e.y)


## a vehicle of ours is gone (cleared / removed): its place in the street is kept, left where it stood
func release(v: Vehicles.Veh) -> void:
	taken.erase(v)
	if driven == v:
		driven = null
		traffic.player_driving = false
	if v.data.get("settled", false):      # (settle() puts the street's side right itself)
		return
	var e: CityTraffic.Car = v.data.get("entry")
	if e != null and e.ctl == &"drive":
		if v.wrecked:
			respawn(e)
		else:
			traffic.park(e, v.x, v.z, v.yaw, v.y)
			e.veh = null


## a vehicle goes back to the street: the lanes if it lies on one (a car that came from the traffic), otherwise parked where it stands
func settle(v: Vehicles.Veh) -> void:
	var e: CityTraffic.Car = v.data.entry
	var sp := sin(v.yaw)
	var cp := cos(v.yaw)
	var lane: Dictionary = traffic.find_lane(v.x, v.z, sp, cp) if v.data.get("origin") == "car" else {}
	var clear := not lane.is_empty()
	if clear:
		for o: CityTraffic.Car in traffic.cars:
			if o != e and o.ctl == &"" and U.hyp(o.x - v.x, o.z - v.z) < 9.0:
				clear = false
				break
	var y := v.y
	v.data.settled = true
	Game.vehicles.remove(v)
	taken.erase(v)
	if clear:
		traffic.resume(e, lane, v.x, v.z, v.yaw)
	else:
		traffic.park(e, v.x, v.z, v.yaw, y)
	e.veh = null


## every frame (called by the vehicle controller before it steps)
func tick(dt: float, driven_now: Variant, player: Player) -> void:
	clock += dt
	player0 = player
	# cars pulling over for the player
	for car: CityTraffic.Car in traffic.cars:
		if car.ctl != &"stop":
			continue
		if driven_now != null or player.dead:
			if car.exit == null:
				traffic.cancel_stop(car)
			continue
		var d := reach(car, player)
		if car.exit == null:
			if d > 12.0 or car.stop_t > 26.0:
				traffic.cancel_stop(car)
				Game.hud.toast("NEVER MIND")
				continue
			if car.v < 0.15 and absf(car.lat - car.lat_t) < 0.2 and car.stop_t > 0.6:
				if drivers.piloted(car):
					drivers.begin_exit(car)
				else:
					hand_over(car)
		elif car.exit.done:
			if d < 4.5:
				complete(car)
			elif car.exit.t > 8.0:      # he got out and you went off: the empty car stays where it stopped
				traffic.park(car, car.x, car.z, heading(car), car.y)
				car.exit = null
	# vehicles of ours: keep the street's picture of them in step, and settle the ones nobody drives
	for i in range(taken.size() - 1, -1, -1):
		var v: Vehicles.Veh = taken[i]
		var e: CityTraffic.Car = v.data.get("entry")
		if e == null:
			continue
		traffic.sync(e, v.x, v.z, v.yaw, v.speed)
		e.y = v.y
		if v.data.get("knocked", false) and not v.data.get("bailed", false) and not v.driver:      # knocked loose: its driver gets out once it stands (at once if it burns), and runs
			if v.speed < 0.4 or (v.fire > 0.0 and v.speed < 4.0):
				v.data.bailed = true
				if v.data.get("occupied", false):
					v.data.occupied = false
					e.seated_npc = false
					v.data.pending = true
					v.data.no_enter = true
					drivers.begin_exit(e, {"flee": true, "from": player})
				else:
					v.data.left = clock
			continue
		if v.data.get("pending", false):      # its driver is climbing out: when he is clear, the seat is yours (if you are still there and asked for it)
			var ex: Variant = e.exit
			if ex != null and not ex.done:
				continue
			v.data.pending = false
			v.data.no_enter = v.wrecked
			e.exit = null
			if v.data.get("wanted", false) and not v.wrecked and driven_now == null and not player.dead and reach(e, player) < 4.5:
				Game.vehicles.enter(v)
			else:      # (you went off: the empty car stays where he left it)
				v.data.origin = "left"
				v.data.left = clock
			continue
		if v.driver or v.data.get("left") == null:
			continue
		var away := U.hyp(player.x - v.x, player.z - v.z)
		var idle: float = clock - float(v.data.left)
		if v.wrecked:
			if (idle > 30.0 and away > 60.0) or (taken.size() > 6 and away > 45.0 and idle > 12.0):
				v.data.settled = true
				Game.vehicles.remove(v)
				taken.erase(v)
				respawn(e)
			continue
		if v.speed > 0.3:
			continue
		var lane: Dictionary = traffic.find_lane(v.x, v.z, sin(v.yaw), cos(v.yaw)) if v.data.get("origin") == "car" else {}
		if (not lane.is_empty() and idle > 6.0 and away > 26.0) or (idle > 24.0 and away > 36.0) or (taken.size() > 6 and away > 45.0 and idle > 4.0):
			settle(v)
