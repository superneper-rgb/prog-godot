class_name OmSecurity
extends RefCounted
## OMNISPHERE security (JS security.js): how FOINT's people get into a fight, and how the player keeps track of them. Blast doors with status lamps, shoot beacons, entrances (enemies never appear out of thin air: through a door, out of a dropship, out of a drone bay), waves, a red marker over every live hostile of the current wave (off screen it slides to the screen edge as an arrow), anything that falls into the magma dies, and Checkpoint Gamma's blast gate (two hydraulic clamps, a manual release lever).

const LAVA_KILL := 1.5
const LAMP := {"green": 0x40ff70, "red": 0xff2a10, "amber": 0xffa020}
const FAR2 := 240.0 * 240.0      # props this small are not drawn beyond 240 m (a door is several draws; the drop sees the whole plant)


class Beacon:
	var g: Node3D
	var sp: MeshInstance3D
	var core: MeshInstance3D
	var ring: MeshInstance3D
	var ticks: MeshInstance3D
	var size := 2.6
	var on := true
	var ph := 0.0

	func set_on(v: bool) -> void:
		on = v
		g.visible = v


class Door:
	var x := 0.0
	var y := 0.0
	var z := 0.0
	var w := 0.0
	var h := 0.0
	var axis := "z"
	var g: Node3D
	var leaves: Array = []      # {leaf, s}
	var s: World.Solid
	var beacon: MeshInstance3D
	var lamp_mat: StandardMaterial3D
	var halos: Array[MeshInstance3D] = []
	var open := 0.0
	var want := false
	var hold := 0.0
	var auto := true
	var locked := false
	var colour := -1
	var gone := false
	var grace := 0.0

	## keep it open for t seconds (an arrival coming through)
	func open_for(t: float) -> void:
		hold = maxf(hold, t)

	## bar the door for good (red lamps, never opens) or free it again
	func lock(v: bool = true) -> void:
		locked = v
		hold = 0.0

	## blown out of its frame (Juniper's breach): no door, no collision; destroy(false) puts it back for a checkpoint load
	func destroy(v: bool = true) -> void:
		gone = v
		g.visible = not v
		s.set_off(v)
		if not v:
			open = 0.0
			colour = -1


class Bay:
	var x := 0.0
	var y := 0.0
	var z := 0.0
	var g: Node3D
	var lid: Node3D
	var light: MeshInstance3D
	var open := 0.0
	var hold := 0.0


class Wave:
	var id := ""
	var list: Array = []
	var goal: Variant = null
	var travel := false
	var started := false
	var spawned: Array = []
	var left := {}
	var pending := 0
	var t := 0.0
	var queue: Array = []
	var gen := 0


class Arrival:
	var r: Robot
	var path: Array = []      # Vector3
	var i := 0
	var speed := 4.2
	var wait := 0.45
	var kind := "walk"
	var v := 0.0
	var block_t := 0.0


class Ship:
	var s: OmCraft.Gunship
	var from: Vector3
	var hover: Vector3
	var leave: Vector3
	var t := 0.0
	var ph := "in"
	var a: Dictionary
	var dropped := 0
	var drop_t := 0.0
	var yaw := 0.0
	var lift := 0.0


class Clamp:
	var s := 1.0
	var cg: Node3D
	var bar: Node3D
	var valve: Node3D
	var beacon: Beacon
	var T: OmProp
	var blown := false
	var u := 0.0


class Gate:
	var x := 0.0
	var y := 0.0
	var zc := 0.0
	var w := 0.0
	var h := 0.0
	var leaves: Array = []      # {leaf, s, solid}
	var clamps: Array[Clamp] = []
	var arm: Node3D
	var lamp: MeshInstance3D
	var lever: Array = []
	var open := 0.0
	var opening := false


## the red marks over the current wave
class Marks:
	extends Control
	var items: Array = []      # [x, y, edge, angle, text]
	var font: Font

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		font = load("res://assets/fonts/VT323-Regular.ttf")

	func _draw() -> void:
		var red := Color("#ff5a3a")
		for q: Array in items:
			var p := Vector2(q[0], q[1])
			if q[2]:      # off screen: an arrow on the edge
				var a: float = q[3]
				draw_set_transform(p, a, Vector2.ONE)
				draw_colored_polygon(PackedVector2Array([Vector2(16.0, 0.0), Vector2(-10.0, -10.0), Vector2(-10.0, 10.0)]), red)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				var pts := PackedVector2Array([p + Vector2(0.0, -12.0), p + Vector2(12.0, 0.0), p + Vector2(0.0, 12.0), p + Vector2(-12.0, 0.0)])
				draw_colored_polygon(pts, Color(1.0, 0.235, 0.118, 0.25))
				pts.append(pts[0])
				draw_polyline(pts, red, 2.0)
				draw_string(font, p + Vector2(-20.0, -18.0), q[4], HORIZONTAL_ALIGNMENT_CENTER, 40.0, 12, Color("#ffb39e"))


var lv: ExportedLevel
var bo: Blockout
var W: World
var audio: OmAudio
var craft: OmCraft
var sol: Dictionary
var doors: Array[Door] = []
var arrivals: Array[Arrival] = []
var waves: Dictionary = {}
var bays: Array[Bay] = []
var ships: Array[Ship] = []
var beacons: Array[Beacon] = []
var clock := 0.0
var cur_wave: Wave = null
var gate: Gate = null
var marks: Marks
var layer: CanvasLayer
var top_mat: ShaderMaterial
var lava := 0.0


func _init(p_lv: ExportedLevel, p_bo: Blockout, p_audio: OmAudio, p_craft: OmCraft) -> void:
	lv = p_lv
	bo = p_bo
	W = lv.world
	audio = p_audio
	craft = p_craft
	sol = VhKit.solids(W)
	layer = CanvasLayer.new()
	layer.layer = 3
	lv.add_child(layer)
	marks = Marks.new()
	layer.add_child(marks)
	# beacons draw over everything: visible across the arena (JS depthTest false)
	var base: Shader = load("res://levels/mothership/ms_glow.gdshader")
	var s := Shader.new()
	s.code = base.code.replace("render_mode blend_add,", "render_mode depth_test_disabled, blend_add,")
	top_mat = ShaderMaterial.new()
	top_mat.shader = s
	top_mat.set_shader_parameter(&"mode", 4)


static func key(x: float, z: float) -> String:
	return "%d_%d" % [floori(x * 10.0 + 0.5), floori(z * 10.0 + 0.5)]      # (JS Math.round: halves go up, GDScript round() goes away from zero)


func _solid(id: String) -> World.Solid:
	var a: Array = sol.get(id, [])
	if a.is_empty():
		push_warning("OMNISPHERE: no solid " + id)
		return W.add({"kind": "box", "cx": 0.0, "cz": -5000.0, "hx": 0.1, "hz": 0.1, "top": -500.0, "bottom": -501.0, "tag": "wall"})
	return a[0]


func _top_sprite(parent: Node, hex: int, op: float, size: float) -> MeshInstance3D:
	var mi := MsKit.sprite8(parent, hex, op, size)
	mi.material_override = top_mat
	return mi


# ------------------------------------------------------------------------------------------------ shoot beacons
## a glow + target ring at pos (local to parent): pulses while on
func shoot_beacon(parent: Node, pos: Vector3, size: float = 2.6, color: int = 0xffb040) -> Beacon:
	var b := Beacon.new()
	b.g = Node3D.new()
	b.g.position = pos
	parent.add_child(b.g)
	b.size = size
	b.ph = randf() * 6.0
	b.sp = _top_sprite(b.g, color, 0.9, size)
	b.core = MsKit.sprite8(b.g, 0xffffff, 0.9, size * 0.35)
	b.ring = MsKit.glow(b.g, _ring_mesh(size * 0.32, size * 0.4, 24), 0, color, 0.85)
	b.ticks = MsKit.glow(b.g, _ring_mesh(size * 0.44, size * 0.52, 4), 0, color, 0.7)
	beacons.append(b)
	return b


static func _ring_mesh(a: float, c: float, n: int) -> ArrayMesh:
	var pts := PackedVector3Array()
	for i in n:
		var u := TAU * i / n
		var v := TAU * (i + 1) / n
		var p0 := Vector3(cos(u) * a, sin(u) * a, 0.0)
		var p1 := Vector3(cos(u) * c, sin(u) * c, 0.0)
		var p2 := Vector3(cos(v) * c, sin(v) * c, 0.0)
		var p3 := Vector3(cos(v) * a, sin(v) * a, 0.0)
		pts.append_array(PackedVector3Array([p0, p1, p2, p0, p2, p3]))
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pts
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


func _update_beacons(dt: float) -> void:
	var cam: Camera3D = Game.camera
	for b in beacons:
		if not b.on or not b.g.is_visible_in_tree():
			continue
		b.ph += dt
		var p := 0.5 + 0.5 * sin(b.ph * 5.0)
		var q := maxf(0.0, sin(b.ph * 2.2))
		MsKit.opa(b.sp, 0.45 + 0.5 * p)
		b.sp.scale = Vector3.ONE * (b.size * (1.0 + p * 0.35))
		MsKit.opa(b.core, 0.6 + 0.4 * p)
		if cam != null:
			var bs := cam.global_transform.basis
			b.ring.global_basis = bs.rotated(bs.z, b.ph * 1.2).scaled_local(Vector3.ONE * (1.0 + q * 0.15))
			b.ticks.global_basis = bs.rotated(bs.z, -b.ph * 2.0)
		MsKit.opa(b.ring, 0.55 + 0.45 * q)


# ------------------------------------------------------------------------------------------------ blast doors
## door in a wall opening: centre x, z, floor y, width w, height h, axis = the wall runs along 'x' or 'z'. o.auto: opens for the player (default)
func blast_door(x: float, z: float, y: float, w: float, h: float, axis: String = "z", o: Dictionary = {}) -> Door:
	var d := Door.new()
	var k := key(x, z)
	d.x = x
	d.y = y
	d.z = z
	d.w = w
	d.h = h
	d.axis = axis
	d.g = VhKit.one(lv, "om-door-" + k)
	d.leaves = [{"leaf": VhKit.one(lv, "om-door-%s-l0" % k), "s": -1.0}, {"leaf": VhKit.one(lv, "om-door-%s-l1" % k), "s": 1.0}]
	d.s = _solid("door-" + k)
	d.auto = o.get("auto", true)
	d.locked = o.get("locked", false)
	d.beacon = MsKit.sprite8(d.g, 0xffa020, 0.0, 2.2)
	d.beacon.position = Vector3(1.05, h + 0.5, 0.0)      # (in front of the beacon box: a glow sprite cutting through the box speckles)
	d.beacon.visible = not o.get("no_beacon", false)
	d.lamp_mat = VhKit.unlit(LAMP.green)
	for mi in VhKit.meshes(VhKit.one(lv, "om-door-%s-lamp" % k)):
		mi.material_override = d.lamp_mat
	for s: float in [-1.0, 1.0]:
		var sp := MsKit.sprite8(d.g, LAMP.green, 0.55, 1.8)
		sp.position = Vector3(0.0, h * 0.62, s * (w / 2.0 + 0.35))
		d.halos.append(sp)
	doors.append(d)
	return d


func _gap(d: Door, x: float, z: float, y: float) -> bool:
	return absf(x - d.x) < (1.1 if d.axis == "z" else d.w / 2.0 + 0.4) and absf(z - d.z) < (d.w / 2.0 + 0.4 if d.axis == "z" else 1.1) and absf(y - d.y) < 3.0


func _update_doors(dt: float, P: Player) -> void:
	var cam: Vector3 = Game.camera.global_position if Game.camera != null else Vector3.ZERO
	for d in doors:
		if d.gone:
			continue
		d.g.visible = cam.distance_squared_to(Vector3(d.x, d.y, d.z)) < FAR2
		d.hold = maxf(0.0, d.hold - dt)
		var near := not d.locked and d.auto and P != null and not P.dead and U.hyp(P.x - d.x, P.z - d.z) < 5.5 and absf(P.y - d.y) < 3.0
		d.grace = 1.2 if near else maxf(0.0, d.grace - dt)      # stays open a moment after you step away
		var in_gap := P != null and _gap(d, P.x, P.z, P.y)
		if not in_gap and d.open > 0.0 and Game.combat != null:      # never shut on anyone
			for r: Robot in Game.combat.enemies.robots:
				if not r.dead and _gap(d, r.x, r.z, r.y):
					in_gap = true
					break
		d.want = not d.locked and (near or in_gap or d.hold > 0.0 or d.grace > 0.0)
		var to := 1.0 if d.want else 0.0
		if to != d.open:
			var was := d.open
			d.open = minf(1.0, d.open + dt / 0.7) if to > d.open else maxf(0.0, d.open - dt / 0.9)
			if was == 0.0 or was == 1.0:
				audio.play_at("door", Vector3(d.x, d.y, d.z))
		var e := d.open * d.open * (3.0 - 2.0 * d.open)
		for q: Dictionary in d.leaves:
			(q.leaf as Node3D).position.z = float(q.s) * e * (d.w / 2.0 - 0.1)
		d.s.set_off(d.open > 0.55)
		MsKit.opa(d.beacon, 0.5 + 0.5 * sin(clock * 14.0) if d.open > 0.0 and d.open < 1.0 else (0.4 if d.hold > 0.0 else 0.0))
		var moving := d.open > 0.0 and d.open < 1.0
		var col: int = (LAMP.amber if sin(clock * 16.0) > 0.0 else 0x201000) if moving else (LAMP.red if d.locked or not d.auto else LAMP.green)
		if col != d.colour:
			d.colour = col
			d.lamp_mat.albedo_color = MsKit.srgb(col)
			for h: MeshInstance3D in d.halos:
				MsKit.tint(h, MsKit.lin(col), 0.1 if col == 0x201000 else 0.55)


# ------------------------------------------------------------------------------------------------ drone bays (a hatch box the drone rises out of)
func drone_bay(x: float, y: float, z: float) -> Bay:
	var b := Bay.new()
	var k := key(x, z)
	b.x = x
	b.y = y
	b.z = z
	b.g = VhKit.one(lv, "om-bay-" + k)
	b.lid = VhKit.one(lv, "om-bay-%s-lid" % k)
	b.light = MsKit.sprite8(b.g, 0xff3020, 0.0, 3.0)
	b.light.position = Vector3(0.0, 1.6, 0.0)
	bays.append(b)
	return b


func _update_bays(dt: float) -> void:
	var cam: Vector3 = Game.camera.global_position if Game.camera != null else Vector3.ZERO
	for b in bays:
		b.g.visible = cam.distance_squared_to(Vector3(b.x, b.y, b.z)) < FAR2
		b.hold = maxf(0.0, b.hold - dt)
		var to := 1.0 if b.hold > 0.0 else 0.0
		b.open += signf(to - b.open) * minf(absf(to - b.open), dt * 2.5)
		b.lid.rotation.z = b.open * 1.9
		MsKit.opa(b.light, 0.5 + 0.5 * sin(clock * 12.0) if b.hold > 0.0 else 0.0)


# ------------------------------------------------------------------------------------------------ waves
## a wave: id, arrivals = [{at, via: door | ship | bay, ...}]. goal = [x, z] where the player is headed after it; travel = the player is free to run on while it plays, so a bay behind him is never used and a body left far behind him stops counting
func wave(id: String, list: Array, o: Dictionary = {}) -> void:
	var w := Wave.new()
	w.id = id
	w.list = list
	w.goal = o.get("goal")
	w.travel = o.get("travel", false)
	waves[id] = w


func _dist_to(g: Array, x: float, z: float) -> float:
	return U.hyp(x - float(g[0]), z - float(g[1]))


func _pick_bay(c: Variant, w: Wave) -> Bay:
	var list: Array = c if c is Array else [c]
	var P: Player = Game.player
	if w == null or not w.travel or w.goal == null or P == null:
		return list[0]
	var me := _dist_to(w.goal, P.x, P.z)
	for b: Bay in list:
		if _dist_to(w.goal, b.x, b.z) < me - 4.0:
			return b
	return null


func start_wave(id: String) -> void:
	var w: Wave = waves.get(id)
	if w == null:
		return
	cur_wave = w
	w.started = true
	w.gen += 1
	w.t = 0.0
	w.spawned = []
	w.left = {}
	w.pending = w.list.size()
	w.queue = []
	for a: Dictionary in w.list:
		var q := a.duplicate()
		q["done"] = false
		w.queue.append(q)


func wave_done(id: String) -> bool:
	var w: Wave = waves.get(id)
	if w == null or not w.started or w.pending != 0:
		return false
	for r: Robot in w.spawned:
		if not r.dead and not r.gone and not w.left.has(r.id):
			return false
	return true


func _spawn_at(p: Vector3, yaw: float, a: Dictionary) -> Robot:
	var spec := {"kind": a.get("kind", "robot")}
	for k: String in ["heavy", "costume", "gun", "alarm"]:
		if a.has(k):
			spec[k] = a[k]
	var pt := {"x": p.x, "y": p.y, "z": p.z}
	if not is_nan(yaw):
		pt["yaw"] = yaw
	var r := bo.spawn(pt, spec)
	if r == null:
		return null
	if cur_wave != null:
		cur_wave.spawned.append(r)
	return r


## run one arrival
func _arrive(a: Dictionary, guard: bool = false) -> void:
	match String(a.via):
		"door":
			var d: Door = a.door
			var from: Array = a.from
			var path: Array = a.path
			var ln := 0.0
			var prev: Array = from
			for p: Array in path:
				ln += U.hyp(float(p[0]) - float(prev[0]), float(p[2]) - float(prev[2]))
				prev = p
			var speed: float = a.get("speed", 4.2)
			d.open_for(ln / speed + 3.5)      # long enough for the slowest heavy to clear the doorway
			audio.play_at("alarmShort", Vector3(d.x, d.y, d.z))
			var r := _spawn_at(Vector3(from[0], from[1], from[2]), atan2(float(path[0][0]) - float(from[0]), float(path[0][2]) - float(from[2])), a)
			if r != null:
				var A := Arrival.new()
				A.r = r
				for p: Array in path:
					A.path.append(Vector3(p[0], p[1], p[2]))
				A.speed = speed
				arrivals.append(A)
			cur_wave.pending -= 1
		"bay":
			var w := cur_wave
			var bay: Bay = _pick_bay(a.bay, w) if guard else (a.bay[0] if a.bay is Array else a.bay)
			if bay == null:      # every bay is behind him: the drone is not sent
				w.pending -= 1
				return
			bay.hold = 3.5
			audio.play_at("hatch", Vector3(bay.x, bay.y, bay.z))
			var gen := w.gen
			var rise: float = a.get("rise", 6.0)
			lv.get_tree().create_timer(0.7).timeout.connect(func() -> void:      # the drone comes out once the lid is up
				if cur_wave != w or w.gen != gen or not is_instance_valid(lv):      # the wave was reset (checkpoint load) before the lid opened -- also when the SAME wave was restarted: no extra drone, no double pending--
					return
				var r := _spawn_at(Vector3(bay.x, bay.y + 0.4, bay.z), NAN, {"kind": "drone"})
				if r != null:
					var A := Arrival.new()
					A.r = r
					A.path = [Vector3(bay.x, bay.y + rise, bay.z)]
					A.speed = 5.0
					A.wait = 0.0
					A.kind = "fly"
					arrivals.append(A)
				cur_wave.pending -= 1)
		"ship":
			_ship_run(a)


## the gunship drops a squad: flies in along from -> hover, hovers while each passenger jumps out, then climbs away along leave
func _ship_run(a: Dictionary) -> void:
	var sh := Ship.new()
	sh.s = craft.gunship()
	sh.from = Vector3(a.from[0], a.from[1], a.from[2])
	sh.hover = Vector3(a.hover[0], a.hover[1], a.hover[2])
	sh.leave = Vector3(a.leave[0], a.leave[1], a.leave[2])
	sh.s.group.position = sh.from
	audio.play_at("gunshipPass", sh.from)
	sh.a = a
	sh.yaw = atan2(sh.hover.x - sh.from.x, sh.hover.z - sh.from.z)
	ships.append(sh)


## rise over roofs on the way in / out (not while hovering at the designed drop spot): never clip through a building
func _lift(sh: Ship, dt: float, dx: float, dz: float, on: bool) -> void:
	var p := sh.s.group.position
	var d := U.hyp(dx, dz)
	if d == 0.0:
		d = 1.0
	sh.lift += ((OmCraft.hull_lift(W, p.x, p.y, p.z, dx / d * 14.0, dz / d * 14.0) if on else 0.0) - sh.lift) * minf(1.0, dt * 3.0)
	sh.s.group.position.y += sh.lift


static func _turn(a: float, b: float, k: float) -> float:
	return a + atan2(sin(b - a), cos(b - a)) * k


func _update_ships(dt: float) -> void:
	for i in range(ships.size() - 1, -1, -1):
		var sh: Ship = ships[i]
		sh.t += dt
		sh.s.update(dt)
		var g := sh.s.group
		if sh.ph == "in":
			var u := minf(1.0, sh.t / float(sh.a.get("in_t", 5.0)))
			var e := 1.0 - pow(1.0 - u, 3.0)
			g.position = sh.from.lerp(sh.hover, e)
			_lift(sh, dt, sh.hover.x - sh.from.x, sh.hover.z - sh.from.z, u < 1.0)
			sh.yaw = _turn(sh.yaw, atan2(sh.hover.x - sh.from.x, sh.hover.z - sh.from.z), minf(1.0, dt * 2.0))
			g.rotation = Vector3((1.0 - u) * 0.25, sh.yaw, -(1.0 - u) * 0.18)
			if u >= 1.0:
				sh.ph = "drop"
				sh.t = 0.0
		elif sh.ph == "drop":
			sh.lift *= maxf(0.0, 1.0 - dt * 3.0)
			g.position.y = sh.hover.y + sh.lift + sin(sh.t * 2.0) * 0.25
			g.rotation.x *= maxf(0.0, 1.0 - dt * 4.0)
			g.rotation.z = sin(sh.t * 1.3) * 0.03
			sh.drop_t -= dt
			var list: Array = sh.a.squad
			if sh.dropped < list.size() and sh.drop_t <= 0.0:
				var q: Dictionary = list[sh.dropped]
				var dl := Vector3(q.land[0], q.land[1], q.land[2])
				var p := g.position
				var r := _spawn_at(Vector3(dl.x, p.y - 1.6, dl.z), atan2(dl.x - p.x, dl.z - p.z), q)
				if r != null:
					var A := Arrival.new()
					A.r = r
					A.path = [dl]
					A.speed = 4.0
					A.wait = 0.0
					A.kind = "fly" if q.get("kind") == "drone" else "drop"
					A.v = 2.0
					arrivals.append(A)
				sh.dropped += 1
				sh.drop_t = 0.55
				if Game.fx != null:
					Game.fx.dust(dl, 6, 2.0)
			if sh.dropped >= list.size() and sh.t > list.size() * 0.55 + 1.2:
				sh.ph = "out"
				sh.t = 0.0
				if cur_wave != null:
					cur_wave.pending -= 1
		else:
			var u := minf(1.0, sh.t / 6.0)
			g.position = sh.hover.lerp(sh.leave, u * u)
			_lift(sh, dt, sh.leave.x - sh.hover.x, sh.leave.z - sh.hover.z, true)
			sh.yaw = _turn(sh.yaw, atan2(sh.leave.x - sh.hover.x, sh.leave.z - sh.hover.z), minf(1.0, dt * 1.6))
			g.rotation = Vector3(-u * 0.2, sh.yaw, -sin(u * PI) * 0.3)
			if u >= 1.0:
				sh.s.free_model()
				ships.remove_at(i)


func _update_arrivals(dt: float, P: Player) -> void:
	for i in range(arrivals.size() - 1, -1, -1):
		var A: Arrival = arrivals[i]
		var r := A.r
		if r.dead or r.gone:
			arrivals.remove_at(i)
			continue
		r.dev_passive = true
		if A.wait > 0.0:
			A.wait -= dt
			continue
		var T: Vector3 = A.path[A.i]
		if A.kind == "drop":      # out of the ship: real gravity, then a hard landing (the view plays land)
			A.v += 28.0 * dt
			var ny := r.y - A.v * dt
			var g := W.ground_height(r.x, r.z, 0.3, r.y + 0.2)
			if g > -INF and ny <= g:
				r.y = g
				audio.play_at("boom", Vector3(r.x, r.y, r.z))
				if Game.fx != null:
					Game.fx.dust(Vector3(r.x, r.y, r.z), 10, 2.5)
					if P != null and U.hyp(P.x - r.x, P.z - r.z) < 12.0:
						Game.fx.shake = maxf(Game.fx.shake, 0.25)
				_release(A, i, P)
			else:
				r.y = ny
				r.vx = 0.0
				r.vz = 0.0
			continue
		var dx := T.x - r.x
		var dz := T.z - r.z
		var dy := T.y - r.y if A.kind == "fly" else 0.0
		var d := sqrt(dx * dx + dy * dy + dz * dz)
		if d < 0.35:
			A.i += 1
			if A.i >= A.path.size():
				_release(A, i, P)
			continue
		var st := minf(d, A.speed * dt)
		var nx := r.x + dx / d * st
		var nz := r.z + dz / d * st
		if A.kind != "fly" and W.blocked(nx, nz, r.y, 2.0, (r.r if r.r != 0.0 else 0.5) + 0.05, 0.42):      # something in the way (a bollard, a mate): hand him to his own AI
			A.block_t += dt
			if A.block_t > 0.6:
				_release(A, i, P)
				continue
		else:
			A.block_t = 0.0
			r.x = nx
			r.z = nz
			if A.kind == "fly":
				r.y += dy / d * st
		r.vx = dx / d * A.speed
		r.vz = dz / d * A.speed
		r.yaw = atan2(dx, dz)


## the arrival is over: he is in the fight
func _release(A: Arrival, i: int, P: Player) -> void:
	var r := A.r
	r.dev_passive = false
	arrivals.remove_at(i)
	if P != null:
		r._know(P.x, P.z)
		r.seen_t = 0.0
		r.set_(&"alert")


func _update_marks(P: Player) -> void:
	marks.items.clear()
	var cam: Camera3D = Game.camera
	if cam != null and P != null and cur_wave != null:
		var vs := marks.size
		for r: Robot in cur_wave.spawned:
			if r.dead or r.gone or cur_wave.left.has(r.id):
				continue
			var p3 := Vector3(r.x, r.y + (r.h if r.h != 0.0 else 1.8) + 0.7, r.z)
			var behind := cam.is_position_behind(p3)
			var d := U.hyp(r.x - P.x, r.z - P.z)
			var sp := cam.unproject_position(p3)
			if behind:
				sp = vs - sp
			var off := behind or sp.x < 24.0 or sp.x > vs.x - 24.0 or sp.y < 24.0 or sp.y > vs.y - 24.0
			if not off and d < 9.0:      # close and in view: no clutter
				continue
			if off:
				var c := vs / 2.0
				var a := sp - c
				var k := minf((vs.x / 2.0 - 34.0) / maxf(absf(a.x), 1e-3), (vs.y / 2.0 - 34.0) / maxf(absf(a.y), 1e-3))
				marks.items.append([c.x + a.x * k, c.y + a.y * k, true, atan2(a.y, a.x), ""])
			else:
				marks.items.append([sp.x, sp.y, false, 0.0, "%dm" % roundi(d)])
	marks.visible = not (Game.dialogue != null and Game.dialogue.on)
	marks.queue_redraw()


# ------------------------------------------------------------------------------------------------ the gate: two hydraulic clamps + a manual release lever
func build_gate(x: float, y: float, z0: float, z1: float, h: float) -> Gate:
	var zc := (z0 + z1) / 2.0
	var w := z1 - z0
	gate = Gate.new()
	gate.x = x
	gate.y = y
	gate.zc = zc
	gate.w = w
	gate.h = h
	for i in 2:
		var leaf: Node3D = VhKit.one(lv, "om-gate-l%d" % i)
		gate.leaves.append({"leaf": leaf, "z0": leaf.position.z, "s": -1.0 if i == 0 else 1.0, "solid": _solid("gate-l%d" % i)})      # (z0: the export keeps the JS parent's place in the leaf's own position, so the JS's local z = 0 is z0 here. Written as 0 it threw the closed gate 41 m out of its doorway.)
	for i in 2:
		var c := Clamp.new()
		c.s = -1.0 if i == 0 else 1.0
		var cz := zc + c.s * (w / 2.0 + 1.3)
		c.cg = VhKit.one(lv, "om-clamp-%d" % i)
		c.bar = VhKit.one(lv, "om-clamp-%d-bar" % i)
		c.valve = VhKit.one(lv, "om-clamp-%d-valve" % i)
		c.beacon = shoot_beacon(c.cg, Vector3(1.9, -0.6, 0.0), 2.4)
		c.T = OmProp.make(9500 + i, x + 2.1, z0 + 0.0 + (cz - z0), y + 4.4, 0.6, 1.4, 30.0)
		c.T.dead = false
		gate.clamps.append(c)
	gate.arm = VhKit.one(lv, "om-lever-arm")
	var lg := VhKit.one(lv, "om-lever")
	gate.lamp = MsKit.sprite8(lg, 0xff3020, 0.8, 1.2)
	gate.lamp.position = Vector3(0.5, 1.3, 0.3)
	gate.lever = [x + 5.0, y, zc + w / 2.0 + 4.0]
	return gate


func arm_gate() -> void:
	if gate == null:
		return
	gate.open = 0.0
	gate.opening = false
	gate.arm.rotation.x = 0.0
	for L: Dictionary in gate.leaves:
		(L.leaf as Node3D).position.z = float(L.z0)
		(L.solid as World.Solid).set_off(false)
	for c in gate.clamps:
		c.blown = false
		c.u = 0.0
		c.T.dead = false
		c.T.hp = c.T.max
		c.bar.position.z = 0.0
		c.valve.visible = true
		c.beacon.set_on(true)
		OmProp.arm(c.T)


func _update_gate(dt: float) -> void:
	if gate == null:
		return
	var free := true
	for c in gate.clamps:
		if not c.blown and (c.T.dead or c.T.hp <= 0.0):
			c.blown = true
			c.T.dead = true
			c.valve.visible = false
			c.beacon.set_on(false)
			var p := Vector3(c.T.x, c.T.y + 0.6, c.T.z)
			if Game.fx != null:
				Game.fx.explosion(p, 1.6)
				Game.fx.sparks(p, 40, 8.0, null, 0xffd080)
			audio.play_at("boom", p)
			audio.play_at("steam", p)
		if c.blown:
			c.u = minf(1.0, c.u + dt * 0.8)
			c.bar.position.z = c.s * c.u * 2.6
		else:
			free = false
	MsKit.tint(gate.lamp, MsKit.lin(0x40ff70 if free else 0xff3020))
	# (user, 2026-11-07: the handle comes over as you hold it, and Prog turns to it. The JS only threw it at the end.)
	if not gate.opening and bo.cur_obj().get("id", "") == "lever":
		lever(float(bo.state.progress))
		var P: Player = bo.last_p
		if P != null and free and Inp.btn(&"b").held and bo.in_range(P, bo.cur_obj()):
			P.yaw = lerp_angle(P.yaw, atan2(float(gate.lever[0]) - P.x, float(gate.lever[2]) - P.z), minf(1.0, dt * 8.0))
	if gate.opening:
		gate.open = minf(1.0, gate.open + dt / 5.0)
		var e := gate.open * gate.open * (3.0 - 2.0 * gate.open)
		for L: Dictionary in gate.leaves:
			(L.leaf as Node3D).position.z = float(L.z0) + float(L.s) * e * (gate.w / 2.0 - 0.4) + (randf() - 0.5) * 0.03 * (1.0 - gate.open)
			(L.solid as World.Solid).set_off(gate.open > 0.35)
		if randf() < dt * 10.0 and gate.open < 1.0 and Game.fx != null:
			Game.fx.sparks(Vector3(gate.x + 0.6, gate.y + randf() * gate.h, gate.zc + (randf() - 0.5) * gate.w * e), 6, 4.0, null, 0xffc060)


func gate_free() -> bool:
	if gate == null:
		return false
	for c in gate.clamps:
		if not c.blown:
			return false
	return true


## both locks gone at once (an F6 load past the valves)
func blow_clamps() -> void:
	if gate != null:
		for c in gate.clamps:
			c.T.hp = 0.0
			c.T.dead = true


## lever progress 0..1 from the hold objective
func lever(u: float) -> void:
	if gate != null:
		gate.arm.rotation.x = -u * 1.5


func open_gate() -> void:
	if gate == null or gate.opening:
		return
	gate.opening = true
	audio.play_at("groan", Vector3(gate.x, gate.y + 4.0, gate.zc))
	audio.play_at("alarmShort", Vector3(gate.x, gate.y + 4.0, gate.zc))
	if Game.fx != null:
		Game.fx.shake = 1.4


## one more arrival into the running wave (the finale's endless reinforcements)
func inject(a: Dictionary) -> void:
	if cur_wave == null:
		open_wave("adhoc")
	cur_wave.pending += 1
	_arrive(a)


## start an empty wave (arrivals come later through inject)
func open_wave(id: String) -> void:
	var w := Wave.new()
	w.id = id
	w.started = true
	cur_wave = w


## puts the security state back for a stage (re)start
func reset() -> void:
	for A in arrivals:
		A.r.dev_passive = false
	arrivals.clear()
	for sh in ships:
		sh.s.free_model()
	ships.clear()
	for k: String in waves:
		(waves[k] as Wave).started = false
	cur_wave = null
	for d in doors:
		d.hold = 0.0
	for b in bays:
		b.hold = 0.0


func update(dt: float, P: Player, C: Combat) -> void:
	clock += dt
	if cur_wave != null:
		cur_wave.t += dt
		for a: Dictionary in cur_wave.queue:
			if not a.done and cur_wave.t >= float(a.get("at", 0.0)):
				a.done = true
				_arrive(a, true)
		# a travel wave: whoever is left far behind the player no longer holds up the objective
		if cur_wave.travel and cur_wave.goal != null and cur_wave.pending == 0 and P != null and not P.dead:
			var me := _dist_to(cur_wave.goal, P.x, P.z)
			for r: Robot in cur_wave.spawned:
				if not r.dead and not r.gone and not cur_wave.left.has(r.id) and U.hyp(r.x - P.x, r.z - P.z) > 30.0 and _dist_to(cur_wave.goal, r.x, r.z) > me + 20.0:
					cur_wave.left[r.id] = true
	_update_arrivals(dt, P)
	_update_ships(dt)
	_update_bays(dt)
	_update_doors(dt, P)
	_update_gate(dt)
	_update_marks(P)
	_update_beacons(dt)
	# safety net: whatever ends up in the magma is dead
	if C != null:
		for r: Robot in C.enemies.robots:
			if not r.dead and r.y < lava + LAVA_KILL and not r.drone:
				C.damage(r, 1e4, {"x": r.x, "z": r.z}, 0.0)
