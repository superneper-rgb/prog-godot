class_name CityTraffic
extends RefCounted
## FOINT CITY traffic (JS levels/hub/city-traffic.js createTraffic): the cars drive the lane graph of city_plan.gd. Drivers keep to the right, obey the signals (stop on red, stop on yellow when they can), slow into turns, yield to oncoming traffic before
## turning left, keep their distance, stop for the player and for pedestrians in front of them (and lean on the horn when you stand there), the bus runs a loop around the dome and pulls in at its four stops, delivery trucks back down Dock Road and unload.
## The per-car colours, the places and the parked cars come from the export (one MultiMesh per part and type, node_named "Cars-sedan" and so on), the state of each car as it was built from life.json. What a car looks like does not any more (2026-11-10): city_cars.gd puts FOINT CITY's own fleet into those MultiMeshes and says where its lamps sit. A car's lamps are a draw per type sharing the car's own transform (shaders/car_lamps): JS: one Points cloud rewritten per lamp in script.
## Not here: taking a car over (vehicles, city-driving.js): car.ctl keeps the JS's branches so that plugs in. Honks go nowhere yet (city-sound.js).

const SAFE := 2.4
const SPEC_HOVER := {&"saucerG": 0.07, &"saucerN": 0.09}
const FACTION := {&"saucerG": 1, &"saucerN": 2}      # the two alien factions' rides: grays and greens can't stand each other (they lean on the horn when they pass)
const LAMPS_PER := 10
const AMBER := Color(0.9, 0.5, 0.08)


class CarType:
	var kind := &""
	var l := 0.0
	var w := 0.0
	var h := 0.0
	var cb_hx := 0.0
	var cb_ox := 0.0
	var cb_hz := 0.0
	var seat: Dictionary = {}
	var rids: Array[RID] = []    # every part's MultiMesh of this type shares the car's transform
	var lamp_mm: MultiMesh = null
	var lamp_buf := PackedFloat32Array()
	var lamp_cars: Array = []


## JS car.queue: what is ahead, a stretch of lane or the turn through a junction.
class Piece:
	var path: CityPlan.Path
	var edge: CityPlan.Edge = null
	var node: CityPlan.Junction = null
	var turn := &""
	var from: CityPlan.Edge = null
	var to: CityPlan.Edge = null


class Car:
	var id := 0
	var kind := &""
	var t: CarType
	var x := 0.0
	var z := 0.0
	var y := 0.0
	var hx := 1.0
	var hz := 0.0
	var v := 0.0
	var lat := 0.0
	var lat_t := 0.0
	var s := 0.0
	var dwell := 0.0
	var blocked := 0.0
	var honk := 0.0
	var brake := 0
	var pitch := 0.0
	var block_t := 0.0
	var pass_car: Car = null    # (JS car.pass)
	var dyaw := 0.0
	var yaw_prev := NAN
	var bob := 0.0
	var vmax := 0.0
	var queue: Array[Piece] = []
	var slot := 0
	var bus := false
	var truck := false
	var served: Dictionary = {}
	var unload := 0.0
	var parked_idx := -1        # JS car.parkedIdx: which bay of the kerb a parked car has (-1: it drives)
	var color := 0
	var glow := 0
	var yaw := 0.0              # a parked car's instance yaw (JS e.yaw)
	var veh: Variant = null     # the vehicle of the controller it has become
	var exit: Variant = null    # its driver getting out (city_drivers.gd)
	var seated_npc := false
	var home0: Variant = null
	var ctl := &""              # JS car.ctl: "" the traffic AI, "stop" pulling over for the player, "drive" a vehicle has it, "static" left where it stands
	var stop_t := 0.0
	var solid: World.Solid = null
	var lamp_slot := 0
	var faction := 0
	var index := 0


var plan: CityPlan
var GY := 0.0
var RY := 0.0
var world: World
var rng := CityPlan.Rng.new(9021)
var types: Dictionary = {}
var cars: Array[Car] = []
var parked: Array[Car] = []
var externals: Array[Car] = []         # parked cars that were driven away, standing wherever they were left
var people: Array = []                 # the walkers standing in the road, filled by the crowd
var player_driving := false
var honks: Array[Car] = []             # (for the street sound, when it comes)
var bus_turn: Dictionary = {}
var stops: Array = []
var _beam_rid: RID
var _bus_edges: Dictionary = {}
var _gap := 0.0                        # JS obstacleAhead returns [gap, what]
var _px := PackedFloat32Array()        # where every car is, for the one loop that asks of every pair
var _pz := PackedFloat32Array()
var _what: Car = null
var _material_keep: Array = []
var kit: CityCars                      # what the cars look like (city_cars.gd)


func _init(level: ExportedLevel, p: CityPlan, J: Dictionary, p_kit: CityCars) -> void:
	plan = p
	kit = p_kit
	GY = J["GY"]
	RY = J["RY"]
	world = level.world
	for k: String in J["types"]:
		var d: Dictionary = J["types"][k]
		var t := CarType.new()
		t.kind = StringName(k)
		t.l = d["L"]
		t.w = d["W"]
		t.h = d["H"]
		t.cb_hx = d["cb"]["hx"]
		t.cb_ox = d["cb"]["ox"]
		t.cb_hz = d["cb"]["hz"]
		t.seat = CityCars.seat(t.kind, d["seat"])
		for nm: String in ["Cars-", "CarsTrim-", "CarsGlass-", "CarsNeon-", "CarsUnderglow-"]:
			for o: Node in level.node_named(nm + k):
				if o is MultiMeshInstance3D:
					var mi := o as MultiMeshInstance3D
					mi.visible = true
					if not kit.dress(mi, nm, t.kind):      # (the old neon strip: the new car's lights are a surface of its trim)
						continue
					mi.multimesh.custom_aabb = AABB(Vector3(-4000, -100, -4000), Vector3(8000, 300, 8000))      # (JS: frustumCulled off. One box: nothing to recompute when a car moves)
					t.rids.append(mi.multimesh.get_rid())
		types[t.kind] = t
	for b: Array in J["bus_turn"]:
		bus_turn[int(b[0])] = StringName(b[1])
	for d: Dictionary in J["stops"]:
		stops.append({"x": float(d["x"]), "z": float(d["z"]), "edge": plan.edges[int(d["edge"])]})
	for e in plan.edges:      # JS busEdge(e), asked once per turn: answered here once
		var be := bus_turn.has(e.from.id) or bus_turn.has(e.to.id)
		for st: Dictionary in stops:
			if st.edge == e:
				be = true
		_bus_edges[e.id] = be
	for d: Dictionary in J["cars"]:
		var car := Car.new()
		car.id = int(d["id"])
		car.kind = StringName(d["kind"])
		car.t = types[car.kind]
		car.x = d["x"]
		car.z = d["z"]
		car.y = RY
		car.hx = d["hx"]
		car.hz = d["hz"]
		car.s = d["s"]
		car.slot = int(d["slot"])
		car.bus = d["bus"]
		car.truck = d["truck"]
		car.vmax = d["vmax"]
		var e: CityPlan.Edge = plan.edges[int(d["edge"])]
		var pc := Piece.new()
		pc.path = e.path
		pc.edge = e
		car.queue.append(pc)
		var si := int(d["solid"])
		if si >= 0 and si < world.solids.size():
			car.solid = world.solids[si]
		car.faction = int(FACTION.get(car.kind, 0))
		car.index = cars.size()
		_px.append(car.x)
		_pz.append(car.z)
		car.color = int(d.get("color", 0))
		car.glow = int(d.get("glow", 0))
		cars.append(car)
	for d: Dictionary in J.get("parked", []):
		var car := Car.new()
		car.kind = StringName(d["kind"])
		car.t = types[car.kind]
		car.x = d["x"]
		car.z = d["z"]
		car.y = RY
		car.yaw = d["yaw"]
		car.hx = d["hx"]
		car.hz = d["hz"]
		car.slot = int(d["slot"])
		car.parked_idx = int(d["idx"])
		car.color = int(d["color"])
		car.glow = int(d.get("glow", 0))
		car.id = 1000 + car.parked_idx
		var si := int(d["solid"])
		if si >= 0 and si < world.solids.size():
			car.solid = world.solids[si]
		parked.append(car)
	for c in cars:
		_extend(c)
	_build_lamps(level, J)
	for o: Node in level.node_named("HeadlightPools"):
		if o is MultiMeshInstance3D:
			var mi := o as MultiMeshInstance3D
			mi.visible = true
			mi.multimesh.custom_aabb = AABB(Vector3(-4000, -100, -4000), Vector3(8000, 300, 8000))
			_beam_rid = mi.multimesh.get_rid()
	for o: Node in level.node_named("CarLamps"):      # the frozen cloud of the export: the draw per type below takes over
		if o is Node3D:
			(o as Node3D).visible = false
	for c in cars:
		_place_solid(c)


func dispose() -> void:
	for k: StringName in types:
		(types[k] as CarType).lamp_cars.clear()
	for c in cars:
		c.pass_car = null
		c.queue.clear()
	cars.clear()
	externals.clear()
	people.clear()
	honks.clear()


## The car's lamps, one draw per type: every lamp a quad at its place on the car, billboarded in the shader. A car only tells the shader brake and indicators. JS: head, tail, indicators, roof signs in one Points cloud.
func _build_lamps(level: ExportedLevel, J: Dictionary) -> void:
	var group := Node3D.new()
	group.name = "CarLamps2"
	var dn: Array = level.node_named("FointDistrict")
	(dn[0] if not dn.is_empty() else level.scene_root).add_child(group)      # (hidden with the district from the hub street)
	var shader: Shader = load("res://levels/shaders/car_lamps.gdshader")
	var mat := ShaderMaterial.new()
	mat.shader = shader
	if J.get("glow") != null:
		mat.set_shader_parameter(&"map", load("res://assets/" + String(J["glow"])))
	_material_keep.append(mat)
	for k: StringName in types:
		var t: CarType = types[k]
		for c in cars:
			if c.t == t:
				c.lamp_slot = t.lamp_cars.size()
				t.lamp_cars.append(c)
		if t.lamp_cars.is_empty():
			continue
		var d: Dictionary = CityCars.lamps(k, J["types"][String(k)]["lamps"])
		var lamps: Array = []      # [position, colour, channel]
		for p: Array in d["head"]:
			lamps.append([p, Color(1, 0.92, 0.75), 0.0])
		for p: Array in d["tail"]:
			lamps.append([p, Color(1, 0.08, 0.04), 1.0])
		var j := 0
		for p: Array in d["ind"]:
			lamps.append([p, AMBER, 2.0 if j % 2 == 0 else 3.0])
			j += 1
		for p: Array in d.get("roof", []):
			lamps.append([p, (Color(1, 0.6, 0.15) if k == &"bus" else Color(1, 0.85, 0.4)) * 0.8, 0.0])
		var v := PackedVector3Array()
		var uv := PackedVector2Array()
		var col := PackedColorArray()
		var ix := PackedInt32Array()
		var cus := PackedFloat32Array()
		var base := 0
		for q: Array in lamps:
			var p: Array = q[0]
			for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				v.append(Vector3(p[0], p[1], p[2]))
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
		am.surface_set_material(0, mat)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = am
		mm.instance_count = t.lamp_cars.size()
		mm.custom_aabb = AABB(Vector3(-4000, -100, -4000), Vector3(8000, 300, 8000))
		t.lamp_mm = mm
		t.lamp_buf.resize(t.lamp_cars.size() * 16)
		var mi := MultiMeshInstance3D.new()
		mi.name = "lamps_" + String(k)
		mi.multimesh = mm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		group.add_child(mi)


## choose what comes after the edge at the end of the queue and append the turn and the next edge
func _extend(car: Car) -> void:
	var last: Piece = car.queue[car.queue.size() - 1]
	if last.edge == null:
		return
	var e := last.edge
	var opts := plan.next_edges(e, car.truck)
	var eo: CityPlan.Edge
	if car.bus:
		var want: StringName = bus_turn.get(e.to.id, e.d)
		eo = opts[0]
		for o in opts:
			if o.d == want:
				eo = o
				break
	elif car.truck:
		var dead_opt: CityPlan.Edge = null
		for o in opts:
			if o.to.dead:
				dead_opt = o
				break
		eo = dead_opt if dead_opt != null and rng.next() < 0.6 else opts[int(floor(rng.next() * opts.size()))]
	else:
		var w := PackedFloat32Array()
		var sum := 0.0
		for o in opts:
			var q := (2.2 if o.d == e.d else 1.0) * (0.8 if _bus_edges[o.id] else 1.0)
			w.append(q)
			sum += q
		var r := rng.next() * sum
		eo = opts[opts.size() - 1]
		for i in opts.size():
			r -= w[i]
			if r <= 0.0:
				eo = opts[i]
				break
	var tp := plan.turn_path(e, eo)
	var a := Piece.new()
	a.path = tp
	a.node = e.to
	a.turn = tp.kind
	a.from = e
	a.to = eo
	var b := Piece.new()
	b.path = eo.path
	b.edge = eo
	car.queue.append(a)
	car.queue.append(b)


## JS placeSolid: a car's body stays solid even at contact and far from the player. Only a car handed to a vehicle gives it up.
# ---- hand-overs (city_driving.gd): a car leaves the instanced meshes for the vehicle controller and comes back ----
func _zero_slot(e: Car) -> void:
	var zero := Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO)
	for rid: RID in e.t.rids:
		RenderingServer.multimesh_instance_set_transform(rid, e.slot, zero)


func _hide_lamps(car: Car) -> void:
	var i := cars.find(car)
	if i < 0:
		return
	var lb := car.t.lamp_buf
	var o := car.lamp_slot * 16
	for q in 16:
		lb[o + q] = 0.0
	RenderingServer.multimesh_instance_set_transform(_beam_rid, i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))


## JS setCar: an instance at a spot, with a car-frame yaw
func _set_car(e: Car, x: float, y: float, z: float, yaw: float) -> void:
	var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(x, y, z))
	for rid: RID in e.t.rids:
		RenderingServer.multimesh_instance_set_transform(rid, e.slot, xf)


## a car (moving or parked) goes to the vehicle controller: its instance, lamps and collider are switched off and the AI leaves it alone
func take(e: Car) -> void:
	if e.ctl == &"drive":
		return
	e.ctl = &"drive"
	e.v = 0.0
	e.pass_car = null
	_zero_slot(e)
	_hide_lamps(e)
	if e.solid != null:
		e.solid.set_off(true)
	if e.parked_idx >= 0 and not externals.has(e):
		externals.append(e)


## keep a taken car's place in step with the vehicle (so the others see it, the crowd waits for it, the street sound ignores it)
func sync(e: Car, x: float, z: float, yaw: float, v: float) -> void:
	e.x = x
	e.z = z
	e.hx = sin(yaw)
	e.hz = cos(yaw)
	e.v = v


## the vehicle is left standing: its instance comes back at the spot it was left at and stays (it is an obstacle for the traffic)
func park(e: Car, x: float, z: float, yaw: float, y: float = NAN) -> void:
	e.ctl = &"static"
	e.v = 0.0
	e.x = x
	e.z = z
	e.y = RY if is_nan(y) else y
	e.hx = sin(yaw)
	e.hz = cos(yaw)
	e.yaw = yaw - PI / 2.0
	_set_car(e, x, e.y, z, e.yaw)
	if not externals.has(e) and e.parked_idx >= 0:
		externals.append(e)
	e.bob = 0.0
	_place_solid(e)


## a take-over that did not happen: the car is back as it was
func unhide(e: Car) -> void:
	e.ctl = &""
	_place_solid(e)
	if e.parked_idx >= 0:
		_set_car(e, e.x, e.y, e.z, e.yaw)
		externals.erase(e)


## where a car could pick the lanes up again: the lane edge it lies on, its place along it and its side offset, or {} (on the pavement, across the road, in a junction, wrong way)
func find_lane(x: float, z: float, hx: float, hz: float, tol: float = 1.3) -> Dictionary:
	var best := {}
	for e: CityPlan.Edge in plan.edges:
		if e.to.dead or e.from.dead:
			continue
		var p0: Vector2 = e.path.pts[0]
		var d: Vector2 = CityPlan.DIRS[e.d]
		var r := CityPlan.right_of(e.d)
		var dx := x - p0.x
		var dz := z - p0.y
		var s := dx * d.x + dz * d.y
		var lat := dx * r.x + dz * r.y
		if s < 2.0 or s > e.path.length - 3.0 or absf(lat) > tol or hx * d.x + hz * d.y < 0.9:
			continue
		if best.is_empty() or absf(lat) < absf(float(best.lat)):
			best = {"edge": e, "s": s, "lat": lat}
	return best


## a car goes back to the lanes (the instance returns, the AI drives on from there)
func resume(car: Car, lane: Dictionary, x: float, z: float, yaw: float) -> void:
	car.ctl = &""
	car.stop_t = 0.0
	var pc := Piece.new()
	var ed: CityPlan.Edge = lane.edge
	pc.path = ed.path
	pc.edge = ed
	car.queue.clear()
	car.queue.append(pc)
	car.s = lane.s
	car.lat = lane.lat
	car.lat_t = 0.0
	car.v = 0.0
	car.pass_car = null
	car.block_t = 0.0
	car.x = x
	car.z = z
	car.hx = sin(yaw)
	car.hz = cos(yaw)
	car.yaw_prev = NAN
	car.dyaw = 0.0
	if not cars.has(car):      # (a parked car that took to the road stays a parked car in the JS too: only moving cars find a lane)
		cars.append(car)
	_extend(car)
	_place_solid(car)
	externals.erase(car)


## a car whose wreck was cleared comes back on the lanes, out of the player's sight: a random edge at least 70 m away with room on it. False when none was found
func respawn(car: Car, player: Variant) -> bool:
	for _k in 60:
		var e: CityPlan.Edge = plan.edges[randi() % plan.edges.size()]
		if e.to.dead or e.from.dead or (car.bus and not _bus_edges.get(e.id, false)):
			continue
		var s := 3.0 + randf() * maxf(1.0, e.path.length - 6.0)
		var q: Vector4 = e.path.at(s)
		if player != null and U.hyp(q.x - player.x, q.y - player.z) < 70.0:
			continue
		var busy := false
		for o: Car in cars:
			if o != car and U.hyp(o.x - q.x, o.z - q.y) < 11.0:
				busy = true
				break
		if not busy:
			for o: Car in externals:
				if U.hyp(o.x - q.x, o.z - q.y) < 8.0:
					busy = true
					break
		if busy:
			continue
		car.y = RY
		car.bob = 0.0
		resume(car, {"edge": e, "s": s, "lat": 0.0}, q.x, q.y, atan2(q.z, q.w))
		car.v = car.vmax * 0.6
		return true
	return false


## the player wants this car: it pulls over and stops (cancel_stop lets it go on)
func stop_for(car: Car) -> void:
	if car.ctl != &"":
		return
	car.ctl = &"stop"
	car.stop_t = 0.0
	car.lat_t = 1.0


func cancel_stop(car: Car) -> void:
	if car.ctl != &"stop":
		return
	car.ctl = &""
	if not car.bus:
		car.lat_t = 0.0


func _place_solid(car: Car) -> void:
	var sol := car.solid
	if sol == null:
		return
	sol.set_off(car.ctl == &"drive")
	if sol.off:
		return
	var y := car.y + car.bob
	var cb_ox := car.t.cb_ox
	sol.bottom = y - 0.1
	sol.top = y + car.t.h
	sol.place(car.x + car.hx * cb_ox, car.z + car.hz * cb_ox, atan2(-car.hz, car.hx), car.t.cb_hx, car.t.cb_hz)


## nearest gap ahead in my lane: cars, the cars left standing, the vehicle the player drives. Gives _gap and _what.
func _obstacle_ahead(car: Car) -> void:
	var best := 60.0
	var what: Car = null
	var hx := car.hx
	var hz := car.hz
	var nx := -hz
	var nz := hx
	var in_j := car.queue[0].edge == null
	var cw := car.t.w
	var cl := car.t.l
	var cx := car.x
	var cz := car.z
	var pass_car := car.pass_car
	var px := _px
	var pz := _pz
	for i in px.size():
		# (most of the fleet is far away, and this is asked of every pair every frame: past 50 m a car is either over 40 ahead or more than 30 to the side, which every test below refuses)
		var dx := px[i] - cx
		var dz := pz[i] - cz
		if dx * dx + dz * dz > 2500.0:
			continue
		var f := dx * hx + dz * hz
		if f <= 0.0 or f > 40.0:
			continue
		var o: Car = cars[i]
		if o == car or o == pass_car:
			continue
		var g := _gap_to(o, dx, dz, f, nx, nz, hx, hz, cw, cl, in_j)
		if g < best:
			best = g
			what = o
	for o in externals:
		if o == pass_car:
			continue
		var dx := o.x - cx
		var dz := o.z - cz
		var f := dx * hx + dz * hz
		if f <= 0.0 or f > 40.0:
			continue
		var g := _gap_to(o, dx, dz, f, nx, nz, hx, hz, cw, cl, in_j)
		if g < best:
			best = g
			what = o
	_gap = best
	_what = what


func _gap_to(o: Car, dx: float, dz: float, f: float, nx: float, nz: float, hx: float, hz: float, cw: float, cl: float, in_j: bool) -> float:
	var l := absf(dx * nx + dz * nz)
	var same := o.hx * hx + o.hz * hz
	var cr := absf(o.hx * hz - o.hz * hx)
	var as_ := absf(same)
	var ow := o.t.w * as_ + o.t.l * cr      # its half width / length across and along my heading
	var ol := o.t.l * as_ + o.t.w * cr
	if l > cw + ow + 0.35:
		return INF
	if o.ctl == &"" or o.ctl == &"stop":
		if in_j and same < 0.5:             # inside a junction only the cars going my way count
			return INF
		if not in_j and same < -0.3 and l > 1.2:      # oncoming traffic in its own lane
			return INF
	return f - cl - ol


## can this car move out round a vehicle standing in its lane? Only where nothing comes the other way
func _try_pass(car: Car, o: Car) -> bool:
	var rx := -car.hz
	var rz := car.hx
	for pass_i in 2:
		var list: Array[Car] = cars if pass_i == 0 else externals
		for q in list:
			if q == car or q == o or q.ctl == &"static" or (q.ctl == &"drive" and q.v < 0.5):
				continue
			var dx := q.x - car.x
			var dz := q.z - car.z
			var f := dx * car.hx + dz * car.hz
			var l := dx * rx + dz * rz
			if f > -9.0 and f < 48.0 and l < 0.5 and l > -7.0 and q.hx * car.hx + q.hz * car.hz < 0.3:
				return false
	var lo := (o.x - car.x) * rx + (o.z - car.z) * rz + car.lat
	var same := absf(o.hx * car.hx + o.hz * car.hz)
	var cr := absf(o.hx * car.hz - o.hz * car.hx)
	var ow := o.t.w * same + o.t.l * cr
	var want := lo - (ow + car.t.w + 0.7)
	if want < -4.6:
		return false
	car.pass_car = o
	car.lat_t = want
	return true


## JS update(t, dt, player). The bodies of the cars move here too; the crowd reads people_on_road after it.
func update(t: float, dt: float, player: Player) -> void:
	dt = minf(dt, 0.05)
	honks.clear()      # (JS returns them, and starts a new list)
	var px := player.x
	var pz := player.z
	var p_on := not player_driving and player.y < GY + 2.5 and player.y > GY - 2.0
	for car in cars:
		if car.ctl == &"drive" or car.ctl == &"static":
			continue
		var piece := car.queue[0]
		var e := piece.edge
		var target := car.vmax
		# the road ahead: a turn to slow for, a signal to stop at, a left turn to yield, a bus stop, the dead end
		var to_end := piece.path.length - car.s
		if e != null:
			var nxt := car.queue[1]
			var kind := nxt.turn
			var n := e.to
			var turn_v := 4.6 if kind == &"right" else (6.0 if kind == &"left" else (2.6 if kind == &"uturn" else car.vmax))
			target = minf(target, sqrt(turn_v * turn_v + 2.0 * 2.4 * maxf(0.0, to_end - 1.0)))
			var stop_at := NAN
			if n.signal_on:
				var a := CityPlan.signal_at(n, e.axis, t)
				var need := (car.v * car.v) / (2.0 * 4.5)
				if a == CityPlan.R or (a == CityPlan.Y and to_end > need + 1.5):
					stop_at = to_end - 0.6
				elif kind == &"left":                   # yield: oncoming cars still to come through
					var opp: CityPlan.Edge = n.in_edges.get(CityPlan.REV[e.d])
					if opp != null:
						for o in cars:
							if o == car or o.ctl != &"":
								continue
							var o0 := o.queue[0]
							if (o0.edge == opp and opp.path.length - o.s < 26.0 and o.queue.size() > 1 and o.queue[1].turn != &"left") or (o0.node == n and o0.from == opp and o0.turn != &"left"):
								stop_at = to_end - 0.6
								break
					if CityPlan.green_left(n, e.axis, t) < 1.5 and a == CityPlan.G and to_end > 3.0:
						stop_at = to_end - 0.6
			if n.dead and car.truck and not (car.unload < 0.0):      # backed down to the warehouse dock: unload, then turn round
				stop_at = to_end - 0.2
				if to_end < 0.8 and car.v < 0.2:
					car.unload += dt
					if car.unload > 9.0:
						stop_at = NAN
						car.unload = -25.0
			if car.unload < 0.0:
				car.unload = minf(0.0, car.unload + dt)
			if car.bus:
				var st: Dictionary = {}
				for q: Dictionary in stops:
					if q.edge == e:
						st = q
						break
				if not st.is_empty() and car.served != st:
					var along: float = ((st.x as float) - e.a0 if e.axis == &"x" else (st.z as float) - e.a0) * e.sg
					var d := along - car.s
					if d > -1.0:
						stop_at = d
						if d < 12.0:
							car.lat_t = CityPlan.PARK - CityPlan.LANE
						if absf(d) < 0.8 and car.v < 0.3:
							car.dwell += dt
							if car.dwell > 6.5:
								car.served = st
								car.dwell = 0.0
								car.lat_t = 0.0
			if not is_nan(stop_at):
				target = minf(target, 0.0 if stop_at <= 0.2 else sqrt(2.0 * 4.0 * maxf(0.0, stop_at - 0.2)))
		else:
			target = minf(target, 4.6 if piece.turn == &"right" else (6.0 if piece.turn == &"left" else (2.6 if piece.turn == &"uturn" else car.vmax)))
		# the player wants this car: it stops (not in the middle of a junction) at the side of the road
		if car.ctl == &"stop":
			car.stop_t += dt
			if e != null or car.stop_t > 14.0:
				target = 0.0
		# traffic in front
		_obstacle_ahead(car)
		var gap := _gap
		var what := _what
		if gap < 40.0:
			target = minf(target, maxf(0.0, (gap - SAFE) * 1.1))
		# something left standing in the lane: wait a moment, then go round it when nothing comes
		if what != null and what.ctl != &"" and what.v < 0.4 and gap < 14.0 and car.v < 0.4 and e != null and car.pass_car == null and car.ctl == &"":
			car.block_t += dt
			if car.block_t > 2.2 and to_end > 14.0:
				_try_pass(car, what)
		elif what == null or what.ctl == &"":
			car.block_t = 0.0
		if car.pass_car != null:
			var o := car.pass_car
			var f := (o.x - car.x) * car.hx + (o.z - car.z) * car.hz
			if f < -(car.t.l + o.t.l + 1.5) or e == null or o.ctl == &"":
				car.pass_car = null
				car.lat_t = 0.0
				car.block_t = 0.0
		# the player and pedestrians in front of the bumper
		var person_gap := 99.0
		var is_player := false
		if p_on:
			var dx := px - car.x
			var dz := pz - car.z
			var f := dx * car.hx + dz * car.hz
			if f > 0.0 and f < 18.0 and absf(-dx * car.hz + dz * car.hx) < car.t.w + 0.45 + 0.5:
				var g := f - car.t.l - 0.45
				if g < person_gap:
					person_gap = g
					is_player = true
		for p: Variant in people:
			var dx: float = p.x - car.x
			var dz: float = p.z - car.z
			var f := dx * car.hx + dz * car.hz
			if f > 0.0 and f < 18.0 and absf(-dx * car.hz + dz * car.hx) < car.t.w + 0.4 + 0.5:
				var g := f - car.t.l - 0.4
				if g < person_gap:
					person_gap = g
					is_player = false
		if person_gap < 99.0:
			target = minf(target, maxf(0.0, (person_gap - 1.6) * 1.3))
		# speed
		var prev := car.v
		if car.v < target:
			car.v = minf(target, car.v + 2.8 * dt)
		else:
			car.v = maxf(target, car.v - 7.5 * dt)
		car.brake = 1 if car.v < prev - 0.01 or (car.v < 0.1 and target < 0.1) else 0
		car.pitch += ((prev - car.v) / maxf(dt, 1e-3) * 0.004 - car.pitch) * minf(1.0, dt * 6.0)
		if car.v < 0.15 and ((is_player and person_gap < 4.0) or (what != null and what.ctl == &"drive" and gap < 5.0 and car.ctl == &"")):
			car.blocked += dt
			if car.blocked > 1.4 and car.honk <= 0.0:
				honks.append(car)
				car.honk = 3.0 + rng.next() * 3.0
		else:
			car.blocked = 0.0
		if car.faction != 0 and car.honk <= 0.0 and car.v > 2.0:      # rivals passing
			for o in cars:
				if o.faction != 0 and o.faction != car.faction and absf(o.x - car.x) < 9.0 and absf(o.z - car.z) < 9.0:
					honks.append(car)
					car.honk = 6.0 + rng.next() * 4.0
					break
		car.honk -= dt
		# Check the full next body pose: pulling over and turning must not sweep a solid sideways into the player.
		var ds := car.v * dt
		var next_lat := car.lat + (car.lat_t - car.lat) * minf(1.0, dt * (1.6 if car.pass_car != null else 0.8))
		if p_on and player.y < car.y + car.t.h - 0.05:
			var next_s := car.s + ds
			var next_piece := 0
			while next_piece + 1 < car.queue.size() and next_s > car.queue[next_piece].path.length:
				next_s -= car.queue[next_piece].path.length
				next_piece += 1
			var q2 := car.queue[next_piece].path.at(minf(car.queue[next_piece].path.length, next_s))
			var k := minf(1.0, dt * 10.0)
			var hx2 := car.hx + (q2.z - car.hx) * k
			var hz2 := car.hz + (q2.w - car.hz) * k
			var ln := U.hyp(hx2, hz2)
			if ln == 0.0:
				ln = 1.0
			var dx := px - (q2.x - q2.w * next_lat)
			var dz := pz - (q2.y + q2.z * next_lat)
			if absf(dx * hx2 + dz * hz2) / ln < car.t.l + 0.5 and absf(-dx * hz2 + dz * hx2) / ln < car.t.w + 0.5:
				car.v = 0.0
				car.brake = 1
				continue
		car.s += ds
		while car.s > car.queue[0].path.length:
			car.s -= car.queue[0].path.length
			car.queue.pop_front()
			if car.queue.size() < 3:
				_extend(car)
		var q := car.queue[0].path.at(car.s)
		car.lat = next_lat
		car.x = q.x - q.w * car.lat
		car.z = q.y + q.z * car.lat
		_px[car.index] = car.x
		_pz[car.index] = car.z
		var k2 := minf(1.0, dt * 10.0)
		car.hx += (q.z - car.hx) * k2
		car.hz += (q.w - car.hz) * k2
		var hl := U.hyp(car.hx, car.hz)
		if hl == 0.0:
			hl = 1.0
		car.hx /= hl
		car.hz /= hl
	# instances, lamps, pools
	var blink := fmod(t * 1.6, 1.0) < 0.5
	var bi := 0
	for car in cars:
		var yaw := atan2(-car.hz, car.hx)
		if car.ctl != &"drive":
			var dy := fposmod(yaw - (yaw if is_nan(car.yaw_prev) else car.yaw_prev) + PI * 3.0, TAU) - PI
			car.yaw_prev = yaw
			car.dyaw += (dy / maxf(dt, 1e-3) - car.dyaw) * minf(1.0, dt * 8.0)
			car.bob = float(SPEC_HOVER[car.kind]) * sin(t * 2.2 + car.id) if SPEC_HOVER.has(car.kind) else 0.0
			var cy := car.y + car.bob
			# (JS: Y rotation by yaw, then Z rotation by -pitch)
			var c := cos(yaw)
			var s := sin(yaw)
			var cb := cos(-car.pitch)
			var sb := sin(-car.pitch)
			var xf := Transform3D(Vector3(c * cb, sb, -s * cb), Vector3(-c * sb, cb, s * sb), Vector3(s, 0.0, c), Vector3(car.x, cy, car.z))
			for rid: RID in car.t.rids:
				RenderingServer.multimesh_instance_set_transform(rid, car.slot, xf)
			# the pool of its headlights on the road: a quarter turn about Y, 4.6 wide and 9 long
			var fw := car.t.l + 4.6
			RenderingServer.multimesh_instance_set_transform(_beam_rid, bi, Transform3D(Vector3(-s * 4.6, 0.0, -c * 4.6), Vector3(0.0, 1.0, 0.0), Vector3(c * 9.0, 0.0, -s * 9.0), Vector3(car.x + car.hx * fw, cy + 0.03, car.z + car.hz * fw)))
			# lamps: all the shader needs from the car
			var nxt: Piece = car.queue[1] if car.queue[0].edge != null else car.queue[0]
			var turning := car.ctl != &"static" and (nxt.turn == &"left" or nxt.turn == &"right") and (car.queue[0].path.length - car.s < 30.0 if car.queue[0].edge != null else true)
			var side := 0 if nxt.turn == &"left" else 1
			var lb := car.t.lamp_buf
			var o := car.lamp_slot * 16
			lb[o] = xf.basis.x.x
			lb[o + 1] = xf.basis.y.x
			lb[o + 2] = xf.basis.z.x
			lb[o + 3] = xf.origin.x
			lb[o + 4] = xf.basis.x.y
			lb[o + 5] = xf.basis.y.y
			lb[o + 6] = xf.basis.z.y
			lb[o + 7] = xf.origin.y
			lb[o + 8] = xf.basis.x.z
			lb[o + 9] = xf.basis.y.z
			lb[o + 10] = xf.basis.z.z
			lb[o + 11] = xf.origin.z
			lb[o + 12] = 1.0 if car.brake != 0 else 0.4
			lb[o + 13] = 1.0 if turning and blink and side == 0 else 0.0
			lb[o + 14] = 1.0 if turning and blink and side == 1 else 0.0
			lb[o + 15] = 1.0
		bi += 1
	for k: StringName in types:
		var ty: CarType = types[k]
		if ty.lamp_mm != null:
			ty.lamp_mm.buffer = ty.lamp_buf
	# A car only gives up its body while the vehicle controller owns it; proximity never disables collision.
	for car in cars:
		_place_solid(car)
