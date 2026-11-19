class_name OmLab
extends RefCounted
## OMNISPHERE: the containment chamber as a lab and an engine room, and the moving platforms in it. NEW (user, 2026-11-15; not in the JS): the drum was Juniper, his frame, seven banks and a railing. The model is assets/omnisphere/chamber_kit.glb, built by tools/omnisphere/build_chamber_kit.py (the layout and every size are there; the constants below must match it), drawn with the level's own paint. Here: its place, its collision, the capacitor tubes' glass, and the movers.
## THE WAY UP (what the jetpack is for): four mast lifts carry you from the walkway (4.5 m) to the banks' caps (14.4 m); seven carriages circle the commutator ring just inside the caps; two hoist baskets hang off the polar crane and sweep over the caps, winching between 16 m and the crane's deck (40 m); the deck turns over the whole room and passes above the observation gallery (34 m), which a long lift also reaches from the walkway. A jump and a full burn is about 9.5 m up, so walkway to cap is just possible without the lift.
## The room loses it as he is freed: a bank that blows takes its lift down with it; when he stands up the power goes, the ring stops, its west arc comes down out of his way and the crane coasts to a halt with its baskets wound up.

const KIT := "res://assets/omnisphere/chamber_kit.glb"
const LIFT_BANKS: Array[int] = [1, 2, 6, 4]      # OmChamber.BANKS: 75, 115, -30 and -110 degrees
const LIFT_OFF := 7.0                            # a lift stands this many degrees round from its bank
const LIFT_R := 27.75
const WALK_Y := 4.5
const RING_R := 19.5
const RING_Y := 14.4
const RING_W := 0.11                             # rad/s: 2.1 m/s at the ring
const CARS := 7
const WEST := [140.0, 220.0]                     # the ring's arc over his way out
const GAL_LIFT := -122.0
const GAL_LIFT_R := 37.5
const GAL_Y := 34.0
const CRANE_Y := 40.0
const CRANE_W := -0.045                          # rad/s: the other way round, 1.1 m/s at the baskets
const CRANE_L := 42.6
const BASKET_X := 3.1
const BASKET_Z := 24.0
const BASKET_LOW := 16.0
const AWAKE := 80.0                              # the movers run while PROG is this near the drum's centre


class Lift:
	var g: Node3D
	var s: World.Solid
	var y0 := 0.0
	var y1 := 0.0
	var travel := 3.0
	var off := 0.0
	var bank := -1
	var dead := false
	var y := 0.0


class Car:
	var g: Node3D
	var s: World.Solid
	var a0 := 0.0
	var gone := false


class Basket:
	var g: Node3D
	var s: World.Solid
	var cable: MeshInstance3D
	var side := 1.0
	var off := 0.0
	var y := 0.0


var lv: ExportedLevel
var W: World
var sets: OmSets
var chamber: OmChamber
var act2: OmAct2
var audio: OmAudio
var root: Node3D
var C := Vector3.ZERO
var paint: Material
var paint_local: Material
var ring_west: Node3D
var crane_g: Node3D
var girder: World.Solid
var hub: World.Solid
var lifts: Array[Lift] = []
var cars: Array[Car] = []
var baskets: Array[Basket] = []
var clock := 0.0
var ring_a := 0.0
var crane_a := 0.35
var coast := 1.0
var released := false


func _init(p_lv: ExportedLevel, J: Dictionary, p_sets: OmSets, p_chamber: OmChamber, p_act2: OmAct2, p_audio: OmAudio) -> void:
	lv = p_lv
	W = p_lv.world
	sets = p_sets
	chamber = p_chamber
	act2 = p_act2
	audio = p_audio
	C = Vector3(J.x, J.floor, J.z)
	root = Node3D.new()
	root.name = "OmLab"
	root.position = C
	lv.add_child(root)
	# the level's paint, off a piece of the drum that is already there; the movers get a copy that textures in their own space, so nothing crawls over them as they go
	paint = VhKit.meshes(VhKit.one(lv, "om-plinth"))[0].get_active_material(0)
	paint_local = paint.duplicate()
	var meshes := {}
	var kit: Node3D = (load(KIT) as PackedScene).instantiate()
	for n: Node in kit.get_children():
		var mi := n as MeshInstance3D
		if mi != null:
			meshes[String(mi.name)] = mi.mesh
		elif String(n.name).begins_with("SOL"):
			_solid(n as Node3D)
	kit.free()
	for nm: String in ["lab_floor", "lab_mid", "lab_upper", "lab_ring_west"]:
		var m := _part(root, meshes[nm], paint)
		m.name = nm
		if nm == "lab_ring_west":
			ring_west = m
	_tubes()
	var solids: Array = []
	# ---- lifts: beside four banks, and the long one to the gallery
	var where: Array = []
	for i in LIFT_BANKS.size():
		where.append([float(OmChamber.BANKS[LIFT_BANKS[i]]) + LIFT_OFF, LIFT_R, RING_Y, LIFT_BANKS[i], 3.3, i * 2.7])
	where.append([GAL_LIFT, GAL_LIFT_R, GAL_Y, -1, 8.5, 1.0])
	for q: Array in where:
		var L := Lift.new()
		var a := deg_to_rad(float(q[0]))
		var p := Vector3(cos(a) * float(q[1]), 0.0, sin(a) * float(q[1]))
		L.g = _part(root, meshes["lab_lift"], paint_local)
		L.g.position = p
		L.g.rotation.y = PI / 2.0 - a      # its guide shoes (local x) along the tangent, on the masts
		L.y0 = WALK_Y
		L.y1 = q[2]
		L.bank = q[3]
		L.travel = q[4]
		L.off = q[5]
		L.y = L.y0
		L.s = W.add({"kind": "box", "cx": C.x + p.x, "cz": C.z + p.z, "hx": 1.3, "hz": 1.3, "yaw": PI / 2.0 - a, "bottom": C.y + L.y0 - .32, "top": C.y + L.y0, "tag": "plat"})
		lifts.append(L)
		solids.append(L.s)
	# ---- the ring's carriages
	for i in CARS:
		var c := Car.new()
		c.a0 = TAU * i / CARS + .2
		c.g = _part(root, meshes["lab_carriage"], paint_local)
		c.g.position.y = RING_Y
		c.s = W.add({"kind": "box", "cx": C.x, "cz": C.z, "hx": 1.6, "hz": 1.2, "bottom": C.y + RING_Y - .3, "top": C.y + RING_Y, "tag": "plat"})
		cars.append(c)
		solids.append(c.s)
	# ---- the polar crane and its two baskets
	crane_g = _part(root, meshes["lab_crane"], paint_local)
	crane_g.position.y = CRANE_Y
	girder = W.add({"kind": "box", "cx": C.x, "cz": C.z, "hx": 1.6, "hz": CRANE_L, "bottom": C.y + CRANE_Y - 1.5, "top": C.y + CRANE_Y, "tag": "plat"})
	hub = W.add({"kind": "disc", "cx": C.x, "cz": C.z, "r": 3.5, "hx": 3.5, "hz": 3.5, "bottom": C.y + CRANE_Y - .3, "top": C.y + CRANE_Y, "tag": "plat"})
	solids.append(girder)
	solids.append(hub)
	var rope := BoxMesh.new()
	rope.size = Vector3(.06, 1.0, .06)
	var rope_mat := MsKit.std(0x15171a, .6, .5)
	for i in 2:
		var b := Basket.new()
		b.side = 1.0 if i == 0 else -1.0
		b.off = i * 12.0
		b.y = BASKET_LOW
		b.g = _part(root, meshes["lab_basket"], paint_local)
		b.cable = MsKit.part(root, rope, rope_mat, Vector3.ZERO, false)
		b.s = W.add({"kind": "box", "cx": C.x, "cz": C.z, "hx": 1.3, "hz": 1.3, "bottom": C.y + BASKET_LOW - .28, "top": C.y + BASKET_LOW, "tag": "plat"})
		baskets.append(b)
		solids.append(b.s)
	lv.shader_ports.adopt(root)      # the copy gets the paint's shader as the export's own materials did...
	RenderingServer.material_set_param(paint_local.get_rid(), &"uLocal", 1.0)      # ...in the object's space
	sets.mechs.add_custom(solids, true, _step)      # (the Meat Spire's mover glue: whoever stands on one is carried, turning included)
	_pose()


func _part(parent: Node3D, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	parent.add_child(m)
	return m


## a static solid the kit carries as an empty: SOL_<tag>_<n> a box (scale = half width, height, half depth), SOLD_<tag>_<n> a disc (scale.x = radius), standing on its position
func _solid(n: Node3D) -> void:
	var nm := String(n.name)
	var p := n.position
	var sc := n.scale
	var o := {"kind": "disc" if nm.begins_with("SOLD") else "box", "cx": C.x + p.x, "cz": C.z + p.z, "hx": sc.x, "hz": sc.z, "yaw": n.rotation.y, "bottom": C.y + p.y, "top": C.y + p.y + sc.y,
		"tag": "plat" if nm.contains("gallery") else "cover"}
	if o.kind == "disc":
		o["r"] = sc.x
	W.add(o)


## the banks' tubes and cores were two flat greens: glass you see the charge through
func _tubes() -> void:
	var glass := ShaderMaterial.new()
	glass.shader = load("res://levels/shaders/om_bank_tube.gdshader")
	var core := ShaderMaterial.new()
	core.shader = load("res://levels/shaders/om_bank_core.gdshader")
	for i in OmChamber.BANKS.size():
		for mi in VhKit.meshes(VhKit.one(lv, "om-bank-%d-tube" % i)):
			mi.material_override = glass
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for mi in VhKit.meshes(VhKit.one(lv, "om-bank-%d-core" % i)):
			mi.material_override = core
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _in_west(a: float) -> bool:
	var d := fposmod(rad_to_deg(a), 360.0)
	return d > float(WEST[0]) - 6.0 and d < float(WEST[1]) + 6.0


## every mover's solid and model to where the state says (the movers' step, and once after a reset)
func _pose() -> void:
	for L in lifts:
		L.s.set_span(C.y + L.y - .32, C.y + L.y)
		L.g.position.y = L.y
	for c in cars:
		var a := c.a0 + ring_a
		var x := cos(a) * RING_R
		var z := sin(a) * RING_R
		c.s.place(C.x + x, C.z + z, PI / 2.0 - a)
		c.g.position = Vector3(x, RING_Y, z)
		c.g.rotation.y = PI / 2.0 - a
	girder.place(C.x, C.z, crane_a)
	hub.place(C.x, C.z, crane_a)
	crane_g.rotation.y = crane_a
	var cs := cos(crane_a)
	var sn := sin(crane_a)
	for b in baskets:
		var lx := BASKET_X * b.side
		var lz := BASKET_Z * b.side
		var x := lx * cs + lz * sn
		var z := -lx * sn + lz * cs
		var yaw := crane_a + (0.0 if b.side > 0.0 else PI)      # its open side to the girder
		b.s.place(C.x + x, C.z + z, yaw)
		b.s.set_span(C.y + b.y - .28, C.y + b.y)
		b.g.position = Vector3(x, b.y, z)
		b.g.rotation.y = yaw
		var top := CRANE_Y + 5.0
		var hook := b.y + 4.6
		b.cable.position = Vector3(x, (top + hook) / 2.0, z)
		b.cable.scale.y = maxf(.05, top - hook)


func _step(_t: float, dt: float, P: Player) -> void:
	if P == null or U.hyp(P.x - C.x, P.z - C.z) > AWAKE:
		return
	clock += dt
	coast = move_toward(coast, 0.0 if released else 1.0, dt * .25)
	if not released:
		ring_a += RING_W * dt
	crane_a += CRANE_W * coast * dt
	for L in lifts:
		if not L.dead and L.bank >= 0 and chamber.banks[L.bank].blown:      # its bank went: the lift lets go
			L.dead = true
			var at := root.to_global(L.g.position + Vector3(0, L.y1 + 2.0, 0))
			Game.fx.sparks(at, 40, 9.0, null, 0xffc060)
			audio.play_at("groan", at)
		if L.dead:
			L.y = move_toward(L.y, L.y0, dt * 11.0)
		else:
			L.y = lerpf(L.y0, L.y1, SpireMechs.pingpong(clock, 2.6, L.travel, L.off))
	for b in baskets:
		if released:
			b.y = move_toward(b.y, CRANE_Y, dt * 3.0)
		else:
			b.y = lerpf(BASKET_LOW, CRANE_Y, SpireMechs.pingpong(clock, 4.5, 8.0, b.off))
	_pose()


## he is up and the plant is dead: the lifts drop, the ring stops and its west arc comes down out of his way (with whatever carriage was on it)
func _release() -> void:
	released = true
	for L in lifts:
		L.dead = true
	ring_west.visible = false
	for k in 5:
		var a := deg_to_rad(lerpf(float(WEST[0]), float(WEST[1]), (k + .5) / 5.0))
		var x := C.x + cos(a) * RING_R
		var z := C.z + sin(a) * RING_R
		sets.after(.15 + k * .12, func() -> void: sets.boom(x, C.y + RING_Y + 4.0, z, 4.0, 0.0, {"harmless": true}))
	for c in cars:
		if _in_west(c.a0 + ring_a):
			c.gone = true
			c.g.visible = false
			c.s.set_off(true)


func reset(stage: String) -> void:
	var late := stage == "escape"
	released = late
	coast = 0.0 if late else 1.0
	ring_west.visible = not late
	for L in lifts:
		L.dead = late
		L.y = L.y0
	for c in cars:
		c.gone = late and _in_west(c.a0 + ring_a)
		c.g.visible = not c.gone
		c.s.set_off(c.gone)
	for b in baskets:
		b.y = CRANE_Y if late else BASKET_LOW
	_pose()


func update(_dt: float) -> void:
	if act2.released and not released:
		_release()
