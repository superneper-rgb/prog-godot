class_name CityCarLot
extends RefCounted
## FOINT CITY's cars and alien craft as drivable vehicles outside the city (the dev level's CITY tab, the console's `vehicle sedan`): the same models, paint, doors and handling as the hub's
## (city_cars.gd, city_driving.gd), read from the hub's life.json. An alien craft comes with its pilot standing under the dome until you take it. detach() when the level goes.

const LIFE := "res://assets/levels/hub/life.json"
const OWNER := "car_lot"
const COLOURS: Array[int] = [0x8a1a22, 0x1c4a6a, 0x3a3a44, 0x5a2030, 0x26405a, 0x6a5a20, 0x2a2a30, 0x7a7068]      # (the city's own colours are per street slot: here each new car takes the next of these)
const PAINTED: Array[StringName] = [&"sedan", &"hatch", &"van", &"truck"]      # the kinds that come in any colour; a taxi, a bus and the alien craft keep their own

var kit := CityCars.new()
var models: Dictionary = {}
var pilots: Array = []      # [veh, GrayAlienNpc]
var _specs: Dictionary = {}
var _n := 0


func _init() -> void:
	var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(LIFE))
	if not (j is Dictionary) or not (j as Dictionary).has("car_models"):
		push_error("CityCarLot: no car_models in " + LIFE)
		return
	models = j["car_models"]
	for k: StringName in CityDriving.HANDLING:
		var cm: Dictionary = models[String(k)]
		_specs[String(k)] = Vehicles.register_type(String(k), {"label": cm.name, "handling": CityDriving.HANDLING[k], "cam": CityDriving.CAM[k], "engine": CityDriving.ENGINE[k], "nitro": false, "tail_pluck": false,
			"build": func(o: Dictionary = {}) -> Vehicles.VModel: return CityDriving.build_model(kit, cm, k, int(o.get("color", cm.palette0)), 0, int(o.get("seed", 0)))})


## the kinds, for a palette: [{id, name, note}]
func kinds() -> Array:
	var out: Array = []
	for k: StringName in CityDriving.HANDLING:
		if models.has(String(k)):
			var alien := CityDrivers.SPOT.has(k)
			out.append({"id": String(k), "name": String(models[String(k)].name), "note": "alien craft, its pilot under the dome" if alien else ("drivable" + (", driver's door opens" if CityCars.door(k) != null else ""))})
	return out


## one of them parked at a place (E to get in). parent: the level.
func spawn(kind: String, x: float, y: float, z: float, yaw: float, parent: Node3D) -> Vehicles.Veh:
	if not _specs.has(kind) or Game.vehicles == null:
		return null
	_n += 1
	var build := {"seed": _n * 7 + 3}
	if PAINTED.has(StringName(kind)):
		build["color"] = COLOURS[_n % COLOURS.size()]
	var v: Vehicles.Veh = Game.vehicles.spawn(kind, x, z, yaw, y, {"owner": OWNER, "parent": parent, "solid": true, "build": build})
	if v != null and CityDrivers.SPOT.has(StringName(kind)):
		var a := GrayAlienNpc.new({"green": not CityDrivers.SPOT[StringName(kind)].gray, "pose": &"idle"})
		a.name = "Pilot"
		parent.add_child(a)
		pilots.append([v, a])
	return v


## every frame: the pilots stand in their craft (out of sight while you fly it)
func tick(t: float, dt: float) -> void:
	for p: Array in pilots:
		var v: Vehicles.Veh = p[0]
		var a: GrayAlienNpc = p[1]
		var on: bool = not v.driver and Game.vehicles.vehicles.has(v)
		a.set_shown(on)
		if on:
			var S: Dictionary = CityDrivers.SPOT[StringName(v.type)]
			a.place(v.x + sin(v.yaw) * float(S.x), v.y + float(S.y), v.z + cos(v.yaw) * float(S.x), v.yaw)
			a.update(t, dt)


## every car of the lot out of the world
func clear() -> void:
	if Game.vehicles != null:
		Game.vehicles.clear(OWNER)
	for p: Array in pilots:
		if is_instance_valid(p[1]):
			(p[1] as Node).queue_free()
	pilots.clear()


## the level is going: the cars and the car types this lot registered go with it (never what a hub entered since registered)
func detach() -> void:
	clear()
	for k: String in _specs:
		if Vehicles.SPECS.has(k) and is_same(Vehicles.SPECS[k], _specs[k]):
			Vehicles.SPECS.erase(k)
	_specs.clear()
