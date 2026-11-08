class_name VhAdmin
extends RefCounted
## VISITING HOURS: the admin block running (JS admin.js): one floor shown at a time by where the camera is, the doors (a pivot, a collider while shut, a mag-lock lamp), the light fittings (flicker, the lockdown's dimming), how lit a spot is for the guards, the design-to-world mapping of a point. The rooms themselves are the export's.

const K := VhLayout.ADK
const LOW: Array[StringName] = [&"b1", &"f1", &"f2"]


class Door:
	var id := ""
	var pivot: Node3D
	var lamp: MeshInstance3D
	var solid: World.Solid
	var side := 1.0
	var locked := false
	var open := 0.0
	var want := 0.0
	var x := 0.0
	var z := 0.0
	var y := 0.0
	var hold := 0.0
	var held := false
	var base_yaw := 0.0


class Fitting:
	var light: Light3D
	var base := 0.0
	var x := 0.0
	var y := 0.0
	var z := 0.0
	var r := 0.0
	var flicker := 0.0
	var lb := 1.0


var lv: ExportedLevel
var floors: Dictionary = {}      # id -> Node3D
var doors: Dictionary = {}
var door_list: Array[Door] = []
var lights: Array[Fitting] = []
var emergency := 0.0
var t := 0.0
var cur := "?"
var glass: ShaderMaterial
var m_red: StandardMaterial3D
var m_green: StandardMaterial3D
var ad := {}
var saw := PackedFloat64Array()
var sa_top := 0.0
var sbw := PackedFloat64Array()
var wl: Dictionary = {}
var cells3: Dictionary = {}
var live_office: Dictionary = {}
var office_group: Node3D


func _init(p_lv: ExportedLevel, data: Dictionary) -> void:
	lv = p_lv
	var AD: Dictionary = VhLayout.AD_D
	ad = {"x0": VhLayout.ad_x(AD.x0), "x1": VhLayout.ad_x(AD.x1), "z0": VhLayout.ad_z(AD.z0), "z1": VhLayout.ad_z(AD.z1)}
	var A: Dictionary = VhLayout.STAIR_A
	var B: Dictionary = VhLayout.STAIR_B
	saw = PackedFloat64Array(data.SAW) if data.has("SAW") else PackedFloat64Array([VhLayout.ad_x(A.x0), VhLayout.ad_x(A.x1), VhLayout.ad_z(A.z0), VhLayout.ad_z(A.z1)])
	sbw = PackedFloat64Array(data.SBW) if data.has("SBW") else PackedFloat64Array([VhLayout.ad_x(B.x0), VhLayout.ad_x(B.x1), VhLayout.ad_z(B.z0), VhLayout.ad_z(B.z1)])
	sa_top = float(data.get("SA_TOP", float(VhLayout.FLW[&"f4"]) + 5.4))
	wl = data.get("WL", {})
	cells3 = data.get("cells3", {})
	live_office = (data.get("live", {}) as Dictionary).get("office", {})
	for id: StringName in [&"b1", &"f1", &"f2", &"f3", &"f4", &"sb", &"sa"]:
		var g := VhKit.one(lv, "admin-" + String(id))
		g.visible = false
		floors[id] = g
	office_group = VhKit.one(lv, "window-office")
	m_red = VhKit.unlit(0xff2a1a)
	m_green = VhKit.unlit(0x40ff70)
	var sol := VhKit.solids(lv.world)
	for d: Dictionary in data.get("doors", []):
		var o := Door.new()
		o.id = d.id
		o.pivot = VhKit.one(lv, "vh-door-" + o.id)
		o.base_yaw = o.pivot.rotation.y - float(d.side) * float(d.open) * 1.45      # (exported however the tour left it)
		o.side = float(d.side)
		o.locked = bool(d.locked)
		o.x = float(d.x)
		o.z = float(d.z)
		o.y = float(d.y)
		var lamp := VhKit.one(lv, "vh-doorlamp-" + o.id)
		for mi in VhKit.meshes(lamp):
			o.lamp = mi
		var ss: Array = sol.get("door-" + o.id, [])
		if not ss.is_empty():
			o.solid = ss[0]
		doors[o.id] = o
		door_list.append(o)
	var by_n := data.get("lights", []) as Array
	for i in by_n.size():
		var d: Dictionary = by_n[i]
		var f := Fitting.new()
		f.light = VhKit.light(lv, "vh-al-%d" % i)
		f.base = float(d.base)
		f.x = float(d.x)
		f.y = float(d.y)
		f.z = float(d.z)
		f.r = float(d.r)
		f.flicker = float(d.get("flicker", 0.0))
		f.lb = float(d.get("lb", 1.0))
		lights.append(f)
	glass = lv.shader_ports.mats.get("shader_36eaf6#0")


func in_block(p: Vector3) -> bool:
	return p.x > float(ad.x0) - 0.05 and p.x < float(ad.x1) + 0.05 and p.z > float(ad.z0) - 0.05 and p.z < float(ad.z1) + 0.05 and p.y < float(VhLayout.FLW[&"f4"]) + 6.0


func floor_at(y: float) -> StringName:
	var W: Dictionary = VhLayout.FLW
	return &"b1" if y < float(W[&"f1"]) else (&"f1" if y < float(W[&"f2"]) else (&"f2" if y < float(W[&"f3"]) else (&"f3" if y < float(W[&"f4"]) else &"f4")))


func in_stair_b(p: Vector3) -> bool:
	return p.x > sbw[0] - 0.4 and p.x < sbw[1] and p.z > float(ad.z0) and p.z < sbw[3] + 0.4


func in_stair_a(p: Vector3) -> bool:
	return p.x > saw[0] - 0.05 and p.x < saw[1] + 0.05 and p.z > saw[2] - 0.05 and p.z < saw[3] + 0.05 and p.y > float(VhLayout.FLW[&"f1"]) - 0.5 and p.y < sa_top


func near_stair_a(p: Vector3) -> bool:      # (in it, or where its doors can be seen from)
	return p.x < saw[1] + 9.0 and p.z > saw[2] - 9.0


## a design point -> world: [x, y, z]. What stands within 1.4 m of a wall keeps its distance from the wall's face (a locker, a sign, a camera on its bracket); the rest moves with the room. fid: the floor whose walls count (default: the design height's)
func pt(x: float, y: float, z: float, fid: StringName = &"") -> Array:
	if fid == &"":
		fid = VhLayout.floor_of_d(y)
	var ax: Variant = null
	var dx := 1.4
	var az: Variant = null
	var dz := 1.4
	for w: Array in wl.get(String(fid), []):
		var at: float = w[1]
		var a: float = w[2]
		var b: float = w[3]
		if w[0] == "z":
			var d := absf(x - at)
			if z > a - 0.3 and z < b + 0.3 and d < dx:
				dx = d
				ax = [at, w[4]]
		else:
			var d := absf(z - at)
			if x > a - 0.3 and x < b + 0.3 and d < dz:
				dz = d
				az = [at, w[4]]
	return [_keep_x(x, ax), VhLayout.ad_y(y), _keep_z(z, az)]


static func _keep_x(v: float, w: Variant) -> float:
	if w == null:
		return VhLayout.ad_x(v)
	var at: float = w[0]
	var th: float = w[1]
	var d := v - at
	var s := signf(d) if d != 0.0 else 1.0
	return VhLayout.ad_x(at) + s * (maxf(0.0, absf(d) - th / 2.0) + th * K / 2.0)


static func _keep_z(v: float, w: Variant) -> float:
	if w == null:
		return VhLayout.ad_z(v)
	var at: float = w[0]
	var th: float = w[1]
	var d := v - at
	var s := signf(d) if d != 0.0 else 1.0
	return VhLayout.ad_z(at) + s * (maxf(0.0, absf(d) - th / 2.0) + th * K / 2.0)


func show_floors(cam: Vector3, force: StringName = &"") -> void:
	var inside := true if force != &"" else in_block(cam)
	var fl: StringName = force if force != &"" else (floor_at(cam.y) if inside else &"")
	var stair := inside and in_stair_b(cam)
	var near_a := inside and fl != &"b1" and near_stair_a(cam)
	var key := "%s|%s|%s" % [fl, stair, near_a]
	if key == cur:
		return
	cur = key
	for id: StringName in floors:
		var low := fl in LOW
		(floors[id] as Node3D).visible = fl != &"" and (id == fl or (id == &"sb" and low) or (stair and id in LOW) or (id == &"sa" and (near_a or fl == &"f3")))


func update(dt: float, cam: Vector3, flash: float) -> void:
	t += dt
	if glass != null:
		glass.set_shader_parameter(&"uT", t)
		glass.set_shader_parameter(&"uF", flash)
	show_floors(cam)
	# flicker, the lockdown's dimming, doors
	for l in lights:
		var k := 1.0
		if l.flicker != 0.0:
			var s := sin(t * (7.0 + l.flicker * 3.0)) + sin(t * 23.1 + l.flicker)
			k = 0.05 if s > 1.55 else (0.3 if s < -1.7 else 1.0)
		if l.light != null and l.light.is_visible_in_tree():
			l.light.light_energy = l.base * k * (1.0 - emergency * 0.45) / PI      # (the lockdown dims, it does not black out: section 5 is fought in it)
	var P: Player = Game.player
	for d in door_list:
		if P != null and not d.locked and absf(P.y - d.y) < 2.6:
			d.want = 1.0 if U.hyp(P.x - d.x, P.z - d.z) < 2.8 or d.hold > 0.0 else 0.0
		elif d.locked:
			d.want = 0.0
		elif d.hold > 0.0:      # (held for someone coming through on another floor)
			d.want = 1.0
		elif d.hold == 0.0 and d.held:
			d.want = 0.0
		d.held = d.hold > 0.0
		d.hold = maxf(0.0, d.hold - dt)
		d.open += signf(d.want - d.open) * minf(absf(d.want - d.open), dt * 2.6)
		d.pivot.rotation.y = d.base_yaw + d.side * d.open * 1.45
		if d.solid != null:
			d.solid.set_off(d.open > 0.35)
		if d.lamp != null:
			d.lamp.material_override = m_red if d.locked else m_green


## how lit a spot is for the guards (1 = an ordinary lit room): the light fittings that are on, near, on the same floor
func lit_at(x: float, y: float, z: float) -> float:
	var k := 0.35
	var fl := floor_at(y + 0.1)
	for l in lights:
		if floor_at(l.y) != fl:
			continue
		var dy := y - l.y
		if dy > 1.0 or dy < -6.0:
			continue
		var d := sqrt((x - l.x) * (x - l.x) + (z - l.z) * (z - l.z) + dy * dy * 0.25)
		if d < l.r:
			var on := (l.light.light_energy * PI / l.base) if l.light != null and l.base > 0.0 else 0.0
			k += on * (l.base / 7.0 / l.lb) * pow(1.0 - d / l.r, 2.0) * 1.6
	return k


func door(id: String) -> Door:
	return doors.get(id)


func unlock(id: String, on: bool = true) -> void:
	var d: Door = doors.get(id)
	if d != null:
		d.locked = not on
		if on:
			d.hold = 0.0


## hold a door open for a few seconds (a guard walking through)
func hold(id: String, s: float = 3.0) -> void:
	var d: Door = doors.get(id)
	if d != null and not d.locked:
		d.hold = s
