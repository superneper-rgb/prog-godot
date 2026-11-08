class_name CityDrivers
extends RefCounted
## FOINT CITY drivers (JS levels/hub/city-drivers.js createDrivers, update, and city-pilots.js update): the townsfolk sitting at the wheel of the cars nearest the camera, seated instances of one species (shader mode 5), placed on the car's own matrix so they follow every turn and brake dip. Only the nearest MAX moving cars get one.
## The saucers are flown by the aliens: the real grey and green models (enemies/gray_alien_npc.gd), standing at the controls under the dome and grumbling at the traffic; taken over, the pilot climbs out on the kerb side and waddles off. JS quirk kept: its view resets the scale it was given, so they stand at full size.

const MAX := 10
const CAP := 12
const THIGH := {&"sedan": 1.45, &"taxi": 1.45, &"hatch": 1.45, &"van": 1.3, &"truck": 1.2, &"bus": 1.15}
const CLOTHES := [0x5a2222, 0x23324a, 0x2e3e2c, 0x8a6a30, 0x3e2a48, 0x1f4646, 0x9a4a22, 0x3a3a3c, 0x6a3a4a, 0x14181f, 0x5e5444, 0x8a8478, 0x2e1e16, 0xb02a6a, 0x2aa8b8, 0xc8b020]
const SPOT := {&"saucerG": {"gray": true, "x": -0.05, "y": 0.55, "s": 0.75}, &"saucerN": {"gray": false, "x": 0.35, "y": 0.62, "s": 0.72}}      # where each faction's pilot stands in its ride (car-local: x forward, feet height above the road) and how big he is drawn
const NEAR := 55.0


class Seat:
	var nm := ""
	var hip_y := 0.0
	var sh_x := 0.0
	var sh_y := 0.0
	var arm_len := 0.0
	var head_top := 0.0
	var mm: MultiMesh
	var mi: MultiMeshInstance3D
	var buf := PackedFloat32Array()
	var n := 0
	var fit: Dictionary = {}


var traffic: CityTraffic
var seats: Array[Seat] = []
var pilots: Array = []        # { "car", "mi", "S" }
var walkers: Array = []       # the ones who got out
var walk_mm := {}             # species index -> {mm, mi, buf, n}
var _folk: CityFolk = null
var _group: Node3D = null


## one getting-out (JS car.exit)
class Exit:
	var t := 0.0
	var walker: Variant = null
	var done := false
	var shut := false
	var side := 1
	var flee := false
	var rate := 1.0
	var fx := 0.0
	var fz := 0.0
	var alien := false
var clothes: Array[Color] = []


func _init(level: ExportedLevel, tr: CityTraffic, J: Dictionary, f: CityFolk, gray: Mesh, green: Mesh) -> void:
	traffic = tr
	_folk = f
	for c: int in CLOTHES:
		clothes.append(Color.hex((c << 8) | 0xff).srgb_to_linear())
	var group := Node3D.new()
	_group = group
	group.name = "Drivers"
	var dn: Array = level.node_named("FointDistrict")
	(dn[0] if not dn.is_empty() else level.scene_root).add_child(group)      # (hidden with the district from the hub street)
	for nm: String in J["driver_species"]:
		var d: Dictionary = J["drivers"][nm]
		var s := Seat.new()
		s.nm = nm
		s.hip_y = d["hipY"]
		s.sh_x = d["shX"]
		s.sh_y = d["shY"]
		s.arm_len = d["armLen"]
		s.head_top = d["headTop"]
		s.mm = MultiMesh.new()
		s.mm.transform_format = MultiMesh.TRANSFORM_3D
		s.mm.use_colors = true
		s.mm.use_custom_data = true
		s.mm.mesh = f.driver_mesh(nm)
		s.mm.instance_count = CAP
		s.mm.visible_instance_count = 0
		s.mm.custom_aabb = AABB(Vector3(-4000, -100, -4000), Vector3(8000, 300, 8000))
		s.buf.resize(CAP * 20)
		s.mi = MultiMeshInstance3D.new()
		s.mi.name = "Driver_" + nm
		s.mi.multimesh = s.mm
		s.mi.material_override = f.material
		s.mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.mi.visible = false
		group.add_child(s.mi)
		seats.append(s)
	for car in traffic.cars:
		if SPOT.has(car.kind):
			var S: Dictionary = SPOT[car.kind]
			var a := GrayAlienNpc.new({"green": not S.gray, "pose": &"idle"})
			a.name = "Pilot"
			group.add_child(a)
			a.set_shown(false)
			pilots.append({"car": car, "a": a, "S": S, "out": -1.0, "talk_t": randf() * 4.0, "talking": false})


## how a species sits in a car type: its scale (never taller than the cabin), and the arm / leg angles that put its hands on the wheel
func _fit(M: Seat, ty: CityTraffic.CarType) -> Dictionary:
	if M.fit.has(ty.kind):
		return M.fit[ty.kind]
	var s: Dictionary = ty.seat["seat"]
	var w: Dictionary = ty.seat["wheel"]
	var sc := minf(float(s["scale"]), (ty.h - 0.1 - float(s["y"])) / (M.head_top - M.hip_y))
	var fwd := (float(w["x"]) - float(s["x"])) / sc
	var upv := (float(w["y"]) - float(s["y"])) / sc - (M.sh_y - M.hip_y)
	var D := U.hyp(fwd, upv)
	var o := {"sc": sc, "dir": atan2(fwd, -upv), "bend": acos(minf(1.0, maxf(0.25, D / (M.arm_len * 0.97)))), "thigh": float(THIGH.get(ty.kind, 1.4)), "x": float(s["x"]), "y": float(s["y"]) - M.hip_y * sc, "z": float(s["z"])}
	M.fit[ty.kind] = o
	return o


func piloted(car: CityTraffic.Car) -> bool:
	return SPOT.has(car.kind)


## the car's driver gets out: car.exit.done turns true once he is clear of the car. opts.flee: a crash or gunfire, not a hand-over: he scrambles out faster and runs off, away from opts.from (the player)
func begin_exit(car: CityTraffic.Car, opts: Dictionary = {}) -> void:
	if car.exit != null:
		return
	var ex := Exit.new()
	if piloted(car):      # JS city-pilots.js beginExit: he climbs out on the kerb side and walks clear
		for p: Dictionary in pilots:
			if p.car == car:
				var rx := -car.hz
				var rz := car.hx
				var x := car.x + rx * (car.t.w + 0.5)
				var z := car.z + rz * (car.t.w + 0.5)
				ex.alien = true
				ex.walker = {}      # (JS car.exit.walker: true: nobody draws him seated)
				car.exit = ex
				var a: GrayAlienNpc = p.a
				a.place(x, car.y, z, atan2(rx, rz))
				a.look_away()
				p.out = 0.0
				a.move_to(x + rx * 3.5 + car.hx * 1.5, z + rz * 3.5 + car.hz * 1.5, 1.4, func() -> void:
					if car.exit != null:
						car.exit.done = true)
		return
	ex.flee = opts.get("flee", false)
	ex.rate = 1.45 if ex.flee else 1.0
	var from: Variant = opts.get("from")
	ex.fx = from.x if from != null else car.x
	ex.fz = from.z if from != null else car.z
	car.exit = ex


func _ss(a: float, b: float, x: float) -> float:
	var k := clampf((x - a) / (b - a), 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)


func _walk_mesh(i: int) -> Dictionary:
	if walk_mm.has(i):
		return walk_mm[i]
	var nm: String = seats[i].nm
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = _folk.species_mesh(nm)
	mm.instance_count = 2
	mm.visible_instance_count = 0
	mm.custom_aabb = AABB(Vector3(-4000, -100, -4000), Vector3(8000, 300, 8000))
	var mi := MultiMeshInstance3D.new()
	mi.name = "DriverOut-" + nm
	mi.multimesh = mm
	mi.material_override = _folk.material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	_group.add_child(mi)
	var buf := PackedFloat32Array()
	buf.resize(40)
	var W := {"mm": mm, "mi": mi, "buf": buf, "n": 0}
	walk_mm[i] = W
	return W


## the walker is outside the arc the car's driver door sweeps (door info is in the controller's axes: x left, z forward)
func _clear_of_door(car: CityTraffic.Car, w: Variant) -> bool:
	var DI: Variant = car.veh.model.door_info
	if DI == null or w == null:
		return DI != null
	var rx := -car.hz
	var rz := car.hx
	var dx: float = w.x - car.x
	var dz: float = w.z - car.z
	var fwd := dx * car.hx + dz * car.hz
	var left := -(dx * rx + dz * rz)
	return fwd > float(DI.z1) + 0.35 or U.hyp(left - float(DI.x), fwd - float(DI.z1)) > float(DI.z1) - float(DI.z0) + 0.45 or float(w.t) > 4.0


## the exits and the ones who got out: the second half of the JS's update
func _exits(dt: float, cam: Vector3) -> void:
	for car: CityTraffic.Car in traffic.cars:
		var ex: Exit = car.exit
		if ex == null:
			continue
		ex.t += dt * ex.rate
		if ex.alien:      # (his walk says when he is clear)
			continue
		if car.veh != null and not ex.shut:      # his door: open as he turns, shut behind him once he is out of its arc (left hanging open when he runs)
			car.veh.door_want = 1.0
			if not ex.flee and ex.t > 1.55 and _clear_of_door(car, ex.walker):
				ex.shut = true
				car.veh.door_want = 0.0
		if ex.walker == null and ex.t > 1.25:      # he is up beside the door: the walking townsperson takes over from the seated one, same spot, same pose
			var si := car.id % seats.size()
			var F := _fit(seats[si], car.t)
			var rx := -car.hz
			var rz := car.hx
			var lx: float = float(F.x) - 0.12
			var lz := -(car.t.w + 0.45)
			var wx := car.x + car.hx * lx + rx * lz
			var wz := car.z + car.hz * lx + rz * lz
			var dx := -rx * 0.75 - car.hx * 0.66
			var dz := -rz * 0.75 - car.hz * 0.66
			if ex.flee:      # (runs off away from whoever hit him, never back across the car)
				var ax := wx - ex.fx
				var az := wz - ex.fz
				var al := U.hyp(ax, az)
				if al == 0.0:
					al = 1.0
				dx = -rx * 0.8 + ax / al * 0.9
				dz = -rz * 0.8 + az / al * 0.9
			ex.walker = {"si": si, "x": wx, "z": wz, "y": car.y, "hx": -rx, "hz": -rz, "dx": dx, "dz": dz, "t": 0.0, "ph": 0.0, "v": 0.0, "vmax": 3.4 if ex.flee else 1.35, "col": clothes[(car.id * 5 + 3) % clothes.size()]}
			walkers.append(ex.walker)
		if ex.walker != null and (ex.shut or ex.flee or car.veh == null) and float(ex.walker.t) > 0.9 and U.hyp(float(ex.walker.x) - car.x, float(ex.walker.z) - car.z) > car.t.w + 0.9:
			ex.done = true
	for W: Dictionary in walk_mm.values():
		W.n = 0
	for i in range(walkers.size() - 1, -1, -1):
		var w: Dictionary = walkers[i]
		w.t += dt
		var far := U.hyp(float(w.x) - cam.x, float(w.z) - cam.z) > 16.0
		if float(w.t) > 9.0 or (float(w.t) > 4.0 and far):      # (gone once he is round the corner of your eye, or after a while)
			walkers.remove_at(i)
			continue
		var l := U.hyp(w.dx, w.dz)
		if l == 0.0:
			l = 1.0
		w.v = minf(w.vmax, float(w.v) + dt * (5.0 if float(w.vmax) > 2.0 else 2.2))
		w.x += float(w.dx) / l * float(w.v) * dt
		w.z += float(w.dz) / l * float(w.v) * dt
		w.ph += dt * float(w.v) * 4.6 / 0.8
		var turn := 1.0 - exp(-5.0 * dt)      # turns from facing the street to where he walks
		w.hx += (float(w.dx) / l - float(w.hx)) * turn
		w.hz += (float(w.dz) / l - float(w.hz)) * turn
		var W := _walk_mesh(w.si)
		if W.n >= 2:
			continue
		var s := minf(1.0, (9.0 - float(w.t)) / 0.5)      # (and if he is still about after 9 s he shrinks away over half a second)
		var k: int = W.n
		var m := Transform3D(Basis(Vector3.UP, atan2(float(w.hx), float(w.hz))).scaled(Vector3(s, s, s)), Vector3(w.x, w.y, w.z))
		var o := k * 20
		var bf: PackedFloat32Array = W.buf
		bf[o] = m.basis.x.x
		bf[o + 1] = m.basis.y.x
		bf[o + 2] = m.basis.z.x
		bf[o + 3] = m.origin.x
		bf[o + 4] = m.basis.x.y
		bf[o + 5] = m.basis.y.y
		bf[o + 6] = m.basis.z.y
		bf[o + 7] = m.origin.y
		bf[o + 8] = m.basis.x.z
		bf[o + 9] = m.basis.y.z
		bf[o + 10] = m.basis.z.z
		bf[o + 11] = m.origin.z
		var col: Color = w.col
		bf[o + 12] = col.r
		bf[o + 13] = col.g
		bf[o + 14] = col.b
		bf[o + 15] = 0.0
		bf[o + 16] = w.ph
		bf[o + 17] = minf(1.0, float(w.v) / 0.6)
		bf[o + 18] = 0.3
		bf[o + 19] = 1.0
		W.buf = bf
		W.n = k + 1
	for W: Dictionary in walk_mm.values():
		(W.mm as MultiMesh).visible_instance_count = W.n
		(W.mi as MultiMeshInstance3D).visible = W.n > 0
		if W.n > 0:
			(W.mm as MultiMesh).buffer = W.buf


func update(t: float, cam: Vector3, dt: float = 0.0) -> void:
	_exits(dt, cam)
	for M in seats:
		M.n = 0
	for p: Dictionary in pilots:
		var car: CityTraffic.Car = p.car
		var a: GrayAlienNpc = p.a
		if float(p.out) >= 0.0:      # he got out: walks clear, mutters, then is gone (until the saucer takes to the lanes again)
			p.out = float(p.out) + dt
			var vis: bool = float(p.out) < 9.0
			a.set_shown(vis)
			if vis:
				a.update(t, dt)
			if car.exit == null and car.ctl != &"drive" and car.ctl != &"static":      # back on the lanes: back at the controls
				p.out = -1.0
			continue
		var seated: bool = car.ctl == &"" or car.ctl == &"stop"
		if not seated or U.hyp(car.x - cam.x, car.z - cam.z) > NEAR:
			a.set_shown(false)
			continue
		a.set_shown(true)
		var S: Dictionary = p.S
		var yaw := atan2(car.hx, car.hz)
		var k: float = S.x
		a.place(car.x + car.hx * k, car.y + float(S.y) + car.bob, car.z + car.hz * k, yaw)
		p.talk_t = float(p.talk_t) - dt
		if float(p.talk_t) < 0.0:      # grumbling at the traffic
			p.talking = not p.talking
			p.talk_t = 1.0 + randf() * 1.5 if p.talking else 3.0 + randf() * 6.0
			a.set_talk(p.talking)
		a.update(t, dt)
	var list: Array = []
	for car in traffic.cars:
		if SPOT.has(car.kind) or (car.exit != null and car.exit.walker != null) or (car.ctl != &"" and car.ctl != &"stop" and car.exit == null and not car.seated_npc):
			continue
		var d := U.hyp(car.x - cam.x, car.z - cam.z)
		if d < 42.0 or car.exit != null:
			list.append([-1.0 if car.exit != null else d, car])
	list.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for li in mini(list.size(), MAX):
		var car: CityTraffic.Car = list[li][1]
		var M := seats[car.id % seats.size()]
		if M.n >= CAP:
			continue
		var F := _fit(M, car.t)
		var yaw := atan2(-car.hz, car.hx)
		var ex: Exit = car.exit
		var steer := 0.0 if ex != null else clampf(car.dyaw * 0.35, -1.0, 1.0)
		var look := steer * 0.35 + 0.18 * sin(t * 0.4 + car.id * 2.1)
		var lx: float = F.x
		var ly: float = F.y
		var lz: float = F.z
		var fsc: float = F.sc
		var yo := 0.0
		var thigh: float = F.thigh
		var fdir: float = F.dir
		var fbend: float = F.bend
		if ex != null:      # getting out (car-local: x forward, z right; he sits on the left, -z)
			var e := ex.t
			var off := _ss(0.0, 0.3, e)
			var kk := _ss(0.25, 0.75, e)
			var uu := _ss(0.75, 1.25, e)
			fdir = lerpf(lerpf(fdir, 0.35, off), 0.0, uu)
			fbend = lerpf(lerpf(fbend, 0.2, off), 0.0, uu)
			thigh = lerpf(thigh, 0.0, uu)
			look = 0.8 * off * (1.0 - kk)
			yo = kk * PI / 2.0
			lz = lerpf(lerpf(lz, -(car.t.w - 0.28), kk), -(car.t.w + 0.45), uu)
			lx = lerpf(lx, lx - 0.12, uu)
			ly = lerpf(ly, 0.0, uu) + sin(uu * PI) * 0.06
			fsc = lerpf(fsc, 1.0, _ss(0.05, 1.25, e))
		# (JS: Y rotation by yaw, then Z rotation by -pitch, as the car; then its place on the seat, a quarter turn, its scale)
		var c := cos(yaw)
		var s := sin(yaw)
		var cb := cos(-car.pitch)
		var sb := sin(-car.pitch)
		var body := Transform3D(Vector3(c * cb, sb, -s * cb), Vector3(-c * sb, cb, s * sb), Vector3(s, 0.0, c), Vector3(car.x, car.y, car.z))
		if car.veh != null:      # (handed to the controller: ride its body, lean and dents and all)
			var fx_n: Node3D = car.veh.model.chassis.get_child(0)
			body = fx_n.global_transform
		var m := body * Transform3D(Basis(Vector3.UP, PI * 0.5 + yo).scaled(Vector3(fsc, fsc, fsc)), Vector3(lx, ly, lz))
		var col := clothes[(car.id * 5 + 3) % clothes.size()]
		var o := M.n * 20
		var bf := M.buf
		bf[o] = m.basis.x.x
		bf[o + 1] = m.basis.y.x
		bf[o + 2] = m.basis.z.x
		bf[o + 3] = m.origin.x
		bf[o + 4] = m.basis.x.y
		bf[o + 5] = m.basis.y.y
		bf[o + 6] = m.basis.z.y
		bf[o + 7] = m.origin.y
		bf[o + 8] = m.basis.x.z
		bf[o + 9] = m.basis.y.z
		bf[o + 10] = m.basis.z.z
		bf[o + 11] = m.origin.z
		bf[o + 12] = col.r
		bf[o + 13] = col.g
		bf[o + 14] = col.b
		bf[o + 15] = look                  # looks where he is going, glances about
		bf[o + 16] = steer
		bf[o + 17] = fdir
		bf[o + 18] = fbend
		bf[o + 19] = thigh
		M.n += 1
	for M in seats:
		M.mm.visible_instance_count = M.n
		M.mi.visible = M.n > 0
		if M.n > 0:
			M.mm.buffer = M.buf
