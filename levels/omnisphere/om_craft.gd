class_name OmCraft
extends RefCounted
## OMNISPHERE aircraft (JS craft.js): the FOINT "Repo-Man" gunship, Tug 3 the evac ship, the heavy lifter and the cargo tug. The bodies are the export's (hidden templates made for the exporter, copied here per aircraft); fans, lights and the moving bits run here.

const HB_PARTS := [[7.2, 0.0, 2.4], [-8.6, 0.0, 2.8], [-12.6, 0.0, 1.8], [0.5, 6.8, 2.4], [0.5, -6.8, 2.4]]      # [forward, right, radius] in metres
const BIG := 1e9

var lv: ExportedLevel
var root: Node3D
var tpl := {}
static var hb_id := 9800


func _init(p_lv: ExportedLevel) -> void:
	lv = p_lv
	root = Node3D.new()
	root.name = "OmCraft"
	lv.add_child(root)
	for k: String in ["gunship", "evac", "lifter", "tug"]:
		var n := VhKit.one(lv, "om-tpl-" + k)
		n.visible = false
		tpl[k] = n
	for nm: String in ["FOINT gunship", "Tug 3", "heavy lifter", "cargo tug"]:      # (whatever the export's tour left in the world: every aircraft is made here)
		for q: Node3D in lv.node_named(nm):
			q.visible = false


func _copy(k: String) -> Node3D:
	var g: Node3D = (tpl[k] as Node3D).duplicate()
	g.visible = true
	g.transform = Transform3D.IDENTITY
	root.add_child(g)
	return g


static func parts(g: Node, suffix: String) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var walk: Array[Node] = [g]
	while not walk.is_empty():
		var n: Node = walk.pop_back()
		walk.append_array(n.get_children())
		if String(n.name).ends_with(suffix) and n is Node3D:
			out.append(n as Node3D)
	return out


static func part(g: Node, suffix: String) -> Node3D:
	var a := parts(g, suffix)
	return a[0] if not a.is_empty() else null


static func _sprite(group: Node3D, hex: int, s: float, op: float, pos: Vector3) -> MeshInstance3D:
	var sp := MsKit.sprite8(group, hex, op, s)
	sp.position = pos
	return sp


## how far a gunship at (x, y, z) must rise so its hull (about 9 wide) clears every roof / structure under it; look-ahead along (dx, dz) so it climbs before it arrives
static func hull_lift(W: World, x: float, y: float, z: float, dx: float = 0.0, dz: float = 0.0, clearance: float = 5.0) -> float:
	var top := -1e9
	for o: Array in [[0.0, 0.0], [7.0, 0.0], [-7.0, 0.0], [0.0, 7.0], [0.0, -7.0], [dx, dz], [dx * 2.0, dz * 2.0]]:
		top = maxf(top, W.ground_height(x + float(o[0]), z + float(o[1]), 4.5, y + 6.0))
	return maxf(0.0, top + clearance - y)


class Gunship:
	var group: Node3D
	var fans: Array[Node3D] = []
	var gun: Node3D
	var search: Node3D
	var spot: SpotLight3D
	var lamps: Array[MeshInstance3D] = []
	var t := 0.0

	func update(dt: float) -> void:
		t += dt
		for f in fans:
			f.rotation.y += dt * 38.0
		var b := 0.5 + 0.5 * (1.0 if sin(t * 6.0) > 0.0 else 0.0)
		MsKit.opa(lamps[0], b)
		MsKit.opa(lamps[1], b)
		MsKit.opa(lamps[2], 1.0 if fmod(t * 1.3, 1.0) < 0.08 else 0.05)
		if search != null:
			search.rotation.z = sin(t * 0.7) * 0.5

	func free_model() -> void:
		if is_instance_valid(group):
			group.queue_free()


func gunship() -> Gunship:
	var s := Gunship.new()
	s.group = _copy("gunship")
	s.fans = parts(s.group, "om_fan")
	s.gun = part(s.group, "om_gun")
	s.search = part(s.group, "om_search")
	s.lamps = [_sprite(s.group, 0xff2a10, 1.6, 0.8, Vector3(-8.6, 0.3, 0.4)), _sprite(s.group, 0x30ff60, 1.6, 0.8, Vector3(8.6, 0.3, 0.4)), _sprite(s.group, 0xffffff, 1.6, 0.8, Vector3(0.0, 2.1, -10.8)), _sprite(s.group, 0xff4020, 1.6, 0.8, Vector3(0.0, -1.2, 6.2))]
	s.spot = SpotLight3D.new()
	s.spot.light_color = MsKit.srgb(0xfff2d0)
	s.spot.light_energy = 60.0 / PI
	s.spot.spot_range = 70.0
	s.spot.spot_angle = rad_to_deg(0.35)
	s.spot.spot_attenuation = 1.4
	s.spot.spot_angle_attenuation = ExportedLevel.spot_k(0.5)
	s.spot.position = Vector3(0.0, -1.8, 5.8)
	s.group.add_child(s.spot)
	s.spot.basis = Basis.looking_at(Vector3(0.0, -20.0, 18.0) - Vector3(0.0, -1.8, 5.8), Vector3.UP)
	return s


## Tug 3 and the heavy lifter: a bay with a ramp, lift fans, cruise engines
class Cargo:
	var group: Node3D
	var fans: Array[Node3D] = []
	var ramp: Node3D
	var harpoon: Node3D
	var muzzle: Node3D
	var seat: Node3D
	var bay := {}
	var jets: Array[MeshInstance3D] = []
	var burners: Array[MeshInstance3D] = []
	var strobes: Array[MeshInstance3D] = []
	var bay_light: OmniLight3D
	var t := 0.0
	var thrust := 0.0
	var cruise := 0.0
	var ramp_open := 0.0
	var big := false

	func update(dt: float) -> void:
		t += dt
		for f in fans:
			f.rotation.y += dt * ((6.0 + 34.0 * thrust) if big else (8.0 + 40.0 * thrust))
		for j in jets:
			MsKit.opa(j, thrust * (0.55 + 0.3 * sin(t * 37.0)) if big else thrust * (0.6 + 0.3 * sin(t * 40.0)))
			j.scale = Vector3.ONE * ((4.0 + thrust * 4.0) if big else (2.5 + thrust * 2.5))
		for b in burners:
			MsKit.opa(b, cruise * (0.7 + 0.3 * sin(t * 50.0)))
			b.scale = Vector3.ONE * ((3.0 + cruise * 6.0) if big else (2.0 + cruise * 4.0))
		if big:
			MsKit.opa(strobes[0], 1.0 if fmod(t, 1.2) < 0.08 else 0.0)
			MsKit.opa(strobes[1], 0.9 if fmod(t + 0.6, 1.2) < 0.08 else 0.0)
			ramp.rotation.x = PI / 2.0 - ramp_open * (PI / 2.0 + 0.22)
			bay_light.light_energy = (9.0 + sin(t * 6.0) * 3.0) / PI
		else:
			ramp.rotation.x = PI / 2.0 - ramp_open * (PI / 2.0 + 0.3)
			bay_light.light_energy = (6.0 + sin(t * 6.0) * 2.0) / PI

	func free_model() -> void:
		if is_instance_valid(group):
			group.queue_free()


## TUG 3, the evac ship. Local frame: faces +z, bay deck at y 0 from z -5.4 to 2.4 (x +-2.5), ramp hinged at the rear edge (z -5.6). ramp_open 0..1 lowers it
func evac_tug() -> Cargo:
	var c := Cargo.new()
	c.group = _copy("evac")
	c.fans = parts(c.group, "om_fan")
	c.ramp = part(c.group, "om_ramp")
	c.bay = {"y": 0.0, "x0": -2.5, "x1": 2.5, "z0": -5.4, "z1": 2.3}
	for p: Vector3 in [Vector3(-5.6, 2.1, 3.7), Vector3(5.6, 2.1, 3.7), Vector3(-5.6, 2.1, -5.1), Vector3(5.6, 2.1, -5.1)]:
		c.jets.append(_sprite(c.group, 0x7af3ff, 3.8, 0.0, p))
	for s: float in [-1.0, 1.0]:
		c.burners.append(_sprite(c.group, 0x9fe8ff, 3.0, 0.0, Vector3(s * 2.2, 4.4, -6.5)))
	c.bay_light = MsKit.light(c.group, 0xff4a2a, 6.0, 14.0, Vector3(0.0, 2.8, -1.5))
	return c


## THE HEAVY LIFTER, PROG's ride out. Local frame: faces +z, bay deck at y 0 from z -11 to 2 (x +-3.2), ramp hinged at z -11.2
func lifter() -> Cargo:
	var c := Cargo.new()
	c.big = true
	c.group = _copy("lifter")
	c.fans = parts(c.group, "om_fan")
	c.ramp = part(c.group, "om_ramp")
	c.harpoon = part(c.group, "om_harpoon")
	c.muzzle = part(c.group, "om_muzzle")
	c.seat = part(c.group, "om_seat")
	c.bay = {"y": 0.0, "x0": -3.2, "x1": 3.2, "z0": -11.0, "z1": 2.0}
	for p: Vector3 in [Vector3(-10.0, 2.7, 6.0), Vector3(10.0, 2.7, 6.0), Vector3(-10.0, 2.7, -10.0), Vector3(10.0, 2.7, -10.0)]:
		c.jets.append(_sprite(c.group, 0x7af3ff, 6.0, 0.0, p))
	for s: float in [-1.0, 1.0]:
		c.burners.append(_sprite(c.group, 0x9fe8ff, 4.0, 0.0, Vector3(s * 2.7, 6.2, -16.2)))
	c.strobes = [_sprite(c.group, 0xffffff, 3.0, 0.0, Vector3(0.0, 7.3, -1.0)), _sprite(c.group, 0xff3020, 2.6, 0.0, Vector3(0.0, -1.3, 4.0))]
	c.bay_light = MsKit.light(c.group, 0xff4a2a, 9.0, 20.0, Vector3(0.0, 4.0, -4.5))
	MsKit.light(c.group, 0xffd8a0, 7.0, 9.0, Vector3(0.0, 5.0, 7.2))
	return c


## Hit volumes for a gunship at scale 1.25. The game's targets are upright cylinders, so one cannot cover an 11 m hull with wings and a tail boom: the ship's own target T becomes the fat body and a few small cylinders (nose, tail, fin, wing tips) follow the hull's yaw. Damage taken by a small one is moved onto T; hits landing on several in the same frame (a rocket's splash) count once, at the biggest.
class Hitboxes:
	var T: Target
	var parts_: Array[Target] = []
	var last := 0.0

	func _init(p_t: Target) -> void:
		T = p_t
		T.r = 5.2
		T.h = 6.4
		last = T.hp
		for _p: Array in HB_PARTS:
			var p := Target.new(OmCraft.hb_id, 0.0, 0.0, 0.0, {"r": 1.0, "h": 5.0, "max": BIG, "hp": BIG, "w": 0.0})
			OmCraft.hb_id += 1
			parts_.append(p)
			if Game.combat != null:
				Game.combat.targets.append(p)

	func sync(x: float, y: float, z: float, yaw: float) -> void:
		var loss := maxf(0.0, last - T.hp)
		var fl := T.flash
		for p in parts_:
			loss = maxf(loss, BIG - p.hp)
			fl = maxf(fl, p.flash)
			p.hp = BIG
			p.flash = 0.0
		T.hp = last - loss
		T.flash = fl
		last = T.hp
		var sn := sin(yaw)
		var cs := cos(yaw)
		T.x = x
		T.bx = x
		T.z = z
		T.bz = z
		T.y = y - 2.4
		T.kx = 0.0
		T.kz = 0.0
		for i in parts_.size():
			var q: Array = HB_PARTS[i]
			var p := parts_[i]
			p.x = x + sn * float(q[0]) + cs * float(q[1])
			p.bx = p.x
			p.z = z + cs * float(q[0]) - sn * float(q[1])
			p.bz = p.z
			p.y = y - 2.2
			p.r = q[2]
			p.kx = 0.0
			p.kz = 0.0
			p.dead = T.dead

	func drop() -> void:
		for p in parts_:
			p.dead = true
			if Game.combat != null:
				Game.combat.targets.erase(p)
