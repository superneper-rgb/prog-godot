class_name BriarDervishView
extends CreatureView
## THE BRIAR DERVISH on screen: a waxy pitcher-bulb (lime belly, magenta neck, a ribbed blood-red lip round a mouth of glowing nectar, a hooded lid) on a jointed stem, two ribbed
## seed pods on stalks at its sides, over a gnarled plum root knot with five thorned root legs. Built in code from PlantBuild shapes (no glb), one CreatureModel batch.
## It reads the sim (enemies/briar_dervish.gd) and poses from it: roots breathe and ripple as it creeps, pods kick when they spit, the stem coils before a whirl and is wrung round
## when wound up, the roots splay flat while it spins and the bulb lags behind, it wobbles to a stop when dizzy, curls into a ball to fall or burrow, and wilts and sheds its pods and
## bulb when it dies. Gameplay never reads any of this.

const N_LEGS := 5
const BULB_TILT := 0.45
const BULB_SCALE := 1.3            # the bulb and all that hangs off it (the sim's POD_* match it)
const PLANT_SINK := 0.7            # the spin: how far the hub drops onto the floor, and the roots laid flat along it (hip, knee, foot)
const PLANT_LIFT := -0.45
const PLANT_REACH := 0.9
const PLANT_CURL := 0.35
const CH_NECTAR := 0
const CH_POD := 1
const RING_HEX := 0xff2a5a
const SAP_HEX := 0xb8ff40

static var _model: CreatureModel = null

class Leg:
	var a := 0
	var b := 0
	var c := 0
	var ph := 0.0
	var keys: Array[StringName] = []      # its _qq keys

var t := 0.0
var j_crown := 0
var j_stem: Array[int] = []
var j_bulb := 0
var j_lid := 0
var j_pod: Array[int] = [0, 0]
var legs: Array[Leg] = []
var rest_rot: Array[Basis] = []

var crown_a := 0.0          # the root crown's own turn (it settles on a multiple of a fifth of a turn)
var stem_a := 0.0           # the stem's (it settles back on the facing)
var walk_ph := 0.0
var wob := 0.0              # the dizzy wobble
var wob_dir := 0.0
var prev_flash := 0.0
var prev_mv := &""
var prev_under := false
var prev_drop := 0.0
var rise_t := 9.0           # since it came out of the ground or landed
var dust_t := 0.0
var pops: Array[bool] = [false, false]
var bulb_fall: Transform3D
var bulb_v := Vector3.ZERO
var bulb_spin := Vector3.ZERO
var bulb_off := false
var puffed := false

var sp_bend := AnimKit.Spring.new(70.0, 0.45)
var sp_side := AnimKit.Spring.new(60.0, 0.4)
var sp_twist := AnimKit.Spring.new(90.0, 0.35)
var sp_look := AnimKit.Spring.new(50.0, 0.7)
var sp_nod := AnimKit.Spring.new(140.0, 0.4)
var sp_lid := AnimKit.Spring.new(110.0, 0.5)
var sp_crown := AnimKit.Spring.new(40.0, 0.6)
var sp_stem := AnimKit.Spring.new(30.0, 0.55)
var sp_pod: Array = [AnimKit.Spring.new(260.0, 0.3), AnimKit.Spring.new(260.0, 0.3)]
var sp_drop := AnimKit.Spring.new(220.0, 0.35)

var ring: MeshInstance3D
var cracks: FxBeam.Cracks


static func get_model() -> CreatureModel:
	if _model == null:
		_model = CreatureModel.build_from(_make(), "briar_dervish (code)", _glow)
	return _model


static func _glow(s: RobotGfx.SpriteSoup, m: CreatureModel) -> void:
	s.sprite(m.names["bulb"], CH_NECTAR, _mouth(), 2.0)
	for side: float in [1.0, -1.0]:
		s.sprite(m.names["podL" if side > 0.0 else "podR"], CH_POD, Vector3(side * 0.32, 0.0, 0.62), 0.45)


## the mouth's middle in the bulb's frame
static func _mouth() -> Vector3:
	return Basis(Vector3.RIGHT, BULB_TILT) * Vector3(0.0, 1.0, 0.0)


# ---------------------------------------------------------------- the model, in code

static func _mat(nm: String, rough: float, emit: int = -1, energy: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = nm + "_0"      # (CreatureModel strips the exporter's _<index>)
	m.vertex_color_use_as_albedo = true
	m.roughness = rough
	if emit >= 0:
		m.emission_enabled = true
		m.emission = Color.hex((emit << 8) | 0xff)
		m.emission_energy_multiplier = energy
	return m


static func _joint(parent: Node3D, nm: String, xf: Transform3D) -> Node3D:
	var n := Node3D.new()
	n.name = nm
	n.transform = xf
	n.set_meta("extras", {"js_name": "J_" + nm})
	parent.add_child(n)
	return n


static func _part(parent: Node3D, g: PlantBuild.Geo, mat: Material) -> void:
	if g.pos.is_empty():
		return
	var mi := MeshInstance3D.new()
	mi.mesh = g.mesh(mat)
	parent.add_child(mi)


## a frame at `at` whose -Z runs along dir
static func _along(at: Vector3, dir: Vector3) -> Transform3D:
	var up := Vector3.UP if absf(dir.normalized().y) < 0.95 else Vector3.FORWARD
	return Transform3D(Basis.looking_at(dir, up), at)


static func _make() -> Node3D:
	var bark := _mat("bark", 0.78)
	var skin := _mat("wet_ff3c8c_45_0", 0.3)
	var lip := _mat("wet_ff2a40_70_0", 0.25)
	var thorn := _mat("thorn", 0.35)
	var nectar := _mat("glow_1", 0.15, 0xb6ff3a, 2.6)
	var podglow := _mat("glow_2", 0.2, 0xe0ff5a, 2.2)
	var pods := _mat("wet_ff5aa0_40_0", 0.36)
	var leafm := _mat("leaf", 0.45)
	var root := Node3D.new()
	root.name = "dervish"
	# ---- the root crown: a gnarled knot with five thorned legs ----
	var crown := _joint(root, "crown", Transform3D.IDENTITY)
	var knot := PlantBuild.blob(0.82, Vector3(1.0, 0.72, 1.0), 0.22, 0x1c0c1a, 0x4a1c3c, 3.0, 18, 12).moved(Transform3D(Basis.IDENTITY, Vector3(0.0, 1.0, 0.0)))
	for i in 7:      # nodules and stubs round the knot
		var a := i * TAU / 7.0 + 0.4
		knot.merge(PlantBuild.blob(0.26 + 0.06 * (i % 3), Vector3(1.0, 0.8, 1.0), 0.25, 0x220e20, 0x5a2448, i * 1.7).moved(Transform3D(Basis.IDENTITY, Vector3(sin(a) * 0.62, 0.72 + 0.2 * (i % 2), cos(a) * 0.62))))
	_part(crown, knot, bark)
	var ct := PlantBuild.Geo.new()
	for i in 9:
		var a := i * TAU / 9.0
		var d := Vector3(sin(a), 0.55 + 0.3 * (i % 2), cos(a))
		ct.merge(PlantBuild.thorn(Vector3(sin(a) * 0.62, 1.15, cos(a) * 0.62), d, 0.32, 0.07, 0xd8c8a8, 0x3a0c1c))
	_part(crown, ct, thorn)
	for i in N_LEGS:
		var th := i * TAU / N_LEGS + 0.31
		var out := Vector3(sin(th), 0.0, cos(th))
		var H := out * 0.45 + Vector3(0.0, 1.0, 0.0)
		var K := out * 1.55 + Vector3(0.0, 1.78, 0.0)
		var A := out * 2.55 + Vector3(0.0, 0.78, 0.0)
		var T := out * 2.88 + Vector3(0.0, -0.02, 0.0)
		var xa := _along(H, K - H)
		var xb := _along(K, A - K)
		var xc := _along(A, T - A)
		var ja := _joint(crown, "leg%da" % i, xa)
		var jb := _joint(ja, "leg%db" % i, xa.affine_inverse() * xb)
		var jc := _joint(jb, "leg%dc" % i, xb.affine_inverse() * xc)
		var la := H.distance_to(K)
		var lb := K.distance_to(A)
		var lc := A.distance_to(T)
		var sd := float(i) * 3.1
		# each segment runs along its joint's -Z, bowed a little upward
		_part(ja, PlantBuild.tube(PlantBuild.curve(PackedVector3Array([Vector3.ZERO, Vector3(0.0, 0.1, -la * 0.5), Vector3(0.0, 0.0, -la)]), 5), 0.27, 0.2, 10, 0x200c1c, 0x4c1a3a, 0.16, sd), bark)
		_part(ja, PlantBuild.blob(0.25, Vector3.ONE, 0.2, 0x2a1024, 0x5a2246, sd).moved(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -la))), bark)
		_part(jb, PlantBuild.tube(PlantBuild.curve(PackedVector3Array([Vector3.ZERO, Vector3(0.0, 0.12, -lb * 0.5), Vector3(0.0, 0.0, -lb)]), 6), 0.2, 0.13, 9, 0x4c1a3a, 0x6e2a4c, 0.14, sd + 1.0), bark)
		_part(jb, PlantBuild.blob(0.16, Vector3.ONE, 0.18, 0x3a1430, 0x6e2a4c, sd + 2.0).moved(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -lb))), bark)
		_part(jc, PlantBuild.tube(PlantBuild.curve(PackedVector3Array([Vector3.ZERO, Vector3(0.0, 0.06, -lc * 0.55), Vector3(0.0, -0.05, -lc)]), 5), 0.13, 0.0, 8, 0x6e2a4c, 0xe8d8b8, 0.08, sd + 3.0), bark)
		var tb := PlantBuild.Geo.new()
		for k in 4:      # thorns up the outside of the shin and the foot
			var z := -lb * (0.2 + 0.2 * k)
			tb.merge(PlantBuild.thorn(Vector3(0.0, 0.14, z), Vector3(0.0, 1.0, -0.35), 0.24 - 0.03 * k, 0.05, 0xe2d2b0, 0x30081a))
			tb.merge(PlantBuild.thorn(Vector3(0.13 * (1 if k % 2 == 0 else -1), 0.05, z - 0.12), Vector3(0.9 * (1 if k % 2 == 0 else -1), 0.6, -0.2), 0.18, 0.04, 0xe2d2b0, 0x30081a))
		_part(jb, tb, thorn)
		_part(jc, PlantBuild.thorn(Vector3(0.0, 0.1, -lc * 0.35), Vector3(0.0, 1.0, 0.25), 0.2, 0.045, 0xe2d2b0, 0x30081a), thorn)
		_part(ja, PlantBuild.thorn(Vector3(0.0, 0.2, -la * 0.45), Vector3(0.0, 1.0, 0.3), 0.3, 0.06, 0xe2d2b0, 0x30081a), thorn)
	# ---- the stem: four joints, a node ring at each ----
	var parent := root
	var at := Vector3(0.0, 1.38, 0.0)
	var stems: Array[Node3D] = []
	for i in 4:
		var js := _joint(parent, "stem%d" % i, Transform3D(Basis.IDENTITY, at))
		stems.append(js)
		var c0 := 0x3a1c34 if i == 0 else (0x34502a if i == 1 else 0x3f6a24)
		var c1 := 0x34502a if i == 0 else (0x3f6a24 if i == 1 else 0x5a8a28)
		_part(js, PlantBuild.tube(PlantBuild.curve(PackedVector3Array([Vector3.ZERO, Vector3(0.0, 0.16, 0.02), Vector3(0.0, 0.32, 0.0)]), 4), 0.3 - 0.025 * i, 0.27 - 0.025 * i, 12, c0, c1, 0.06, i * 2.0), bark)
		_part(js, PlantBuild.lathe(PackedVector2Array([Vector2(0.27 - 0.025 * i, -0.04), Vector2(0.36 - 0.025 * i, 0.0), Vector2(0.27 - 0.025 * i, 0.06)]), PackedInt32Array([c0, 0x2a1a20, c0]), 12), bark)
		parent = js
		at = Vector3(0.0, 0.32, 0.0)
	var lv := PlantBuild.Geo.new()      # two drooping leaves off the second node
	for side: float in [1.0, -1.0]:
		lv.merge(PlantBuild.leaf(2.1, 0.85, 1.5, 0.35, 0x2c5a1c, 0x9ad030, 8, 3, 0xd8ff60).moved(Transform3D(Basis(Vector3.UP, side * PI * 0.5 + 0.5) * Basis(Vector3.RIGHT, -0.5), Vector3(0.0, 0.05, 0.0))))
	_part(stems[1], lv, leafm)
	# ---- the pitcher bulb, tipped forward so its mouth faces you ----
	var bulb := _joint(stems[3], "bulb", Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * BULB_SCALE), Vector3(0.0, 0.3, 0.0)))
	var tilt := Transform3D(Basis(Vector3.RIGHT, BULB_TILT), Vector3.ZERO)
	var prof := PackedVector2Array([Vector2(0.2, -0.02), Vector2(0.4, 0.08), Vector2(0.64, 0.26), Vector2(0.8, 0.5), Vector2(0.77, 0.76), Vector2(0.6, 0.96), Vector2(0.45, 1.08), Vector2(0.47, 1.17), Vector2(0.56, 1.24)])
	var cols := PackedInt32Array([0x2e5418, 0x4a8a1e, 0x8cc828, 0xa8dc30, 0xb4c83a, 0xd8507a, 0xc8205a, 0xd02860, 0xe03868])
	_part(bulb, PlantBuild.lathe(prof, cols, 22, 9, 0.07, 0.03, 1.0).moved(tilt), skin)
	# the lip: a fat ribbed rim, and the inside wall going down to the nectar
	var lp := PackedVector3Array()
	for i in 41:
		var a := TAU * i / 40.0
		lp.append(Vector3(sin(a) * 0.6, 1.27 + 0.03 * sin(a * 9.0), cos(a) * 0.6))
	_part(bulb, PlantBuild.tube(lp, 0.1, 0.1, 8, 0xff3048, 0xff3048, 0.25, 4.0, false).moved(tilt), lip)
	var inner := PlantBuild.lathe(PackedVector2Array([Vector2(0.52, 1.26), Vector2(0.44, 1.12), Vector2(0.38, 0.98), Vector2(0.34, 0.86)]), PackedInt32Array([0xff4a70, 0x8a1438, 0x3a0818, 0x200410]), 20, 0, 0.0, 0.0, 0.0, false)      # (top down: it faces in)
	_part(bulb, inner.moved(tilt), lip)
	_part(bulb, PlantBuild.lathe(PackedVector2Array([Vector2(0.35, 0.86), Vector2(0.2, 0.9), Vector2(0.0, 0.91)]), PackedInt32Array([0x9cff30, 0xd8ff70, 0xf0ffb0]), 18).moved(tilt), nectar)
	var teeth := PlantBuild.Geo.new()      # the peristome's inward teeth
	for i in 16:
		var a := TAU * (i + 0.5) / 16.0
		var p := Vector3(sin(a) * 0.55, 1.3, cos(a) * 0.55)
		teeth.merge(PlantBuild.thorn(p, Vector3(-sin(a), -0.45, -cos(a)), 0.2, 0.035, 0xf4e8d0, 0x601020))
	_part(bulb, teeth.moved(tilt), thorn)
	var veins := PlantBuild.Geo.new()      # bioluminescent veins up the belly
	for i in 5:
		var a := TAU * i / 5.0 + 0.3
		var vp := PackedVector3Array()
		for k in 7:
			var u := k / 6.0
			var pr := prof[1].lerp(prof[5], u)
			vp.append(Vector3(sin(a + 0.15 * sin(u * 5.0)) * (pr.x + 0.012), pr.y, cos(a + 0.15 * sin(u * 5.0)) * (pr.x + 0.012)))
		veins.merge(PlantBuild.tube(PlantBuild.curve(vp, 3), 0.028, 0.012, 5, 0xc8ff50, 0xc8ff50, 0.0, 0.0, true))
	_part(bulb, veins.moved(tilt), nectar)
	# the hooded lid, hinged at the back of the rim
	var hinge := tilt * Vector3(0.0, 1.3, -0.58)
	var lid := _joint(bulb, "lid", Transform3D(Basis.IDENTITY, hinge))
	var lg := PlantBuild.leaf(1.3, 1.35, -0.3, -0.3, 0x8a1f4a, 0xd84a7a, 8, 4, 0xff8ab0, true).moved(Transform3D(Basis(Vector3.RIGHT, BULB_TILT), Vector3(0.0, 0.04, 0.0)))      # (closed: lying over the mouth)
	_part(lid, lg, pods)
	# two seed pods on stalks at its sides (L = +X: the sim's side -1)
	for side: float in [1.0, -1.0]:
		var jp := _joint(bulb, "podL" if side > 0.0 else "podR", Transform3D(Basis.IDENTITY, tilt * Vector3(side * 0.58, 0.5, 0.05)))
		var st := PlantBuild.curve(PackedVector3Array([Vector3.ZERO, Vector3(side * 0.18, 0.08, 0.0), Vector3(side * 0.32, 0.0, 0.05)]), 4)
		_part(jp, PlantBuild.tube(st, 0.12, 0.09, 8, 0x3f6a24, 0x6a2a50, 0.1, side * 5.0), bark)
		var pg := PlantBuild.lathe(PackedVector2Array([Vector2(0.06, -0.38), Vector2(0.2, -0.3), Vector2(0.3, -0.12), Vector2(0.32, 0.08), Vector2(0.26, 0.26), Vector2(0.18, 0.34), Vector2(0.15, 0.36)]),
			PackedInt32Array([0x4a1430, 0x6a1c40, 0x9a2a58, 0xb83468, 0xc84a70, 0xe06a80, 0xff8a90]), 14, 6, 0.12, 0.04, side * 3.0)
		_part(jp, pg.moved(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(side * 0.32, 0.0, 0.26))), pods)
		var mouth := PackedVector3Array()
		for i in 17:
			var a := TAU * i / 16.0
			mouth.append(Vector3(side * 0.32 + sin(a) * 0.15, cos(a) * 0.15, 0.62))
		_part(jp, PlantBuild.tube(mouth, 0.045, 0.045, 6, 0xe0ff70, 0xe0ff70, 0.0, 0.0, false), podglow)
		_part(jp, PlantBuild.blob(0.085, Vector3(1.0, 1.0, 0.5), 0.0, 0xc0ff40, 0xf0ffa0).moved(Transform3D(Basis.IDENTITY, Vector3(side * 0.32, 0.0, 0.55))), podglow)
	return root


# ---------------------------------------------------------------- the view

func _init(p_r: BriarDervish) -> void:
	super._init(p_r, get_model())
	var n: Dictionary = model.names
	j_crown = n["crown"]
	for i in 4:
		j_stem.append(n["stem%d" % i])
	j_bulb = n["bulb"]
	j_lid = n["lid"]
	j_pod = [n["podL"], n["podR"]]
	for i in N_LEGS:
		var L := Leg.new()
		L.a = n["leg%da" % i]
		L.b = n["leg%db" % i]
		L.c = n["leg%dc" % i]
		L.ph = i * TAU / N_LEGS
		L.keys = [StringName("la%d" % i), StringName("lb%d" % i), StringName("lc%d" % i)]
		legs.append(L)
	for i in model.rest.size():
		rest_rot.append(model.rest[i].basis.orthonormalized())
	j_spine = j_stem[2]
	j_el_l = j_bulb
	j_muzzle = j_bulb
	var d := batch.data
	var o := row * batch.stride
	d[o + 12 + CH_NECTAR] = 1.0
	d[o + 12 + CH_POD] = 1.0
	_col(d, o + 16, 0xc8ff50)
	_col(d, o + 20, 0xe8ff70)
	crown_a = 0.0
	ring = FxBeam.ring(RING_HEX)
	ring.visible = false
	cracks = FxBeam.Cracks.new(4, 4.0)
	prev_drop = (R as BriarDervish).drop_h


func dispose() -> void:
	super.dispose()
	if is_instance_valid(ring):
		ring.queue_free()
	cracks.free_all()


func sprite_world(_i: int) -> Vector3:
	return pose.world[j_bulb] * _mouth()


func muzzle_world(_kind: String = "") -> Vector3:
	var W := R as BriarDervish
	return W.pod_mouth(-1.0 if W.pod == 1 else 1.0)


## a leg's pose: lift (the hip up), reach (the knee straightened out), curl (the foot)
func _leg(L: Leg, lift: float, reach: float, curl: float) -> void:
	pose.rot[L.a] = rest_rot[L.a] * Basis(Vector3.RIGHT, lift)
	pose.rot[L.b] = rest_rot[L.b] * Basis(Vector3.RIGHT, reach)
	pose.rot[L.c] = rest_rot[L.c] * Basis(Vector3.RIGHT, curl)


func update(dt: float, _now: float, fx: Variant) -> void:
	var W := R as BriarDervish
	var dead := W.state == &"dead"
	var mv := &"" if dead else W.mv
	var mt := W.mt
	var d_t := W.dead_t if dead else 0.0
	t += dt
	rise_t += dt
	cracks.update(dt)
	# ---- one-shot reactions ----
	if W.flash > prev_flash + 0.2 and not dead:      # a hit: the bulb nods away, the stem sways
		var k0 := minf(1.0, (W.last_dmg if W.last_dmg != 0.0 else 20.0) / 50.0)
		sp_nod.kick(-5.0 * k0)
		sp_side.kick((W.hit_x * cos(W.yaw) - W.hit_z * sin(W.yaw)) * 4.0 * k0)
	prev_flash = W.flash
	if prev_drop > 0.05 and W.drop_h <= 0.05 and not dead:      # landed
		rise_t = 0.0
		sp_drop.kick(-9.0)
		cracks.place(W.x, W.gy, W.z, 5.5)
		if fx != null:
			fx.dust(Vector3(W.x, W.gy + 0.1, W.z), 18, 3.5)
		AnimKit.cue(fx, W, "thud", 0.4)
	prev_drop = W.drop_h
	if prev_under and not W.under and not dead:      # erupted
		rise_t = 0.0
		sp_drop.kick(6.0)
		cracks.place(W.x, W.gy, W.z, 5.0)
		if fx != null:
			fx.dust(Vector3(W.x, W.gy + 0.2, W.z), 22, 3.0)
			fx.sparks(Vector3(W.x, W.gy + 1.0, W.z), 18, 5.0, null, SAP_HEX)
		AnimKit.cue(fx, W, "roar", 0.9)
	prev_under = W.under
	if mv != prev_mv:
		if mv == &"wind":
			AnimKit.cue(fx, W, "wind", 0.8)
		elif mv == &"wound":
			AnimKit.cue(fx, W, "pain")
		elif mv == &"dizzy":
			wob = 1.0
			wob_dir = randf() * TAU
		elif mv == &"burrow":
			AnimKit.cue(fx, W, "inhale", 0.6)
		prev_mv = mv
	if W.fired_pod >= 0:      # a pod spat: it kicks back, sap sprays at the mouth
		var i := W.fired_pod
		(sp_pod[i] as AnimKit.Spring).kick(-7.0)
		sp_nod.kick(-1.5)
		if fx != null:
			fx.sparks(W.pod_mouth(-1.0 if i == 0 else 1.0), 6, 3.0, null, SAP_HEX)
		AnimKit.cue(fx, W, "squelch", 0.25)
	# ---- where the body is ----
	var base_y := W.gy
	var scl := 1.0
	var sink := 0.0
	var ball := 0.0             # curled into a root ball
	if mv == &"drop":
		base_y = W.gy + W.drop_h
		ball = 1.0 if W.drop_h > 0.0 else 1.0 - AnimKit.out_back(AnimKit.clamp01((mt - BriarDervish.DROP_WARN - BriarDervish.DROP_FALL) / BriarDervish.ROOT_OUT), 1.2)
	elif mv == &"burrow":
		ball = AnimKit.smooth(AnimKit.clamp01(mt / (BriarDervish.SINK_T * 0.6)))
		sink = AnimKit.in_cubic(AnimKit.clamp01((mt - BriarDervish.SINK_T * 0.35) / (BriarDervish.SINK_T * 0.65))) * 3.2
	elif W.under:
		ball = 1.0
		sink = 2.15 + 0.08 * sin(t * 30.0)       # only the top of the ball shows: the bulge
		if mv == &"erupt":
			sink = 2.15 - 0.25 * AnimKit.clamp01(mt / BriarDervish.ERUPT_WARN) + 0.12 * sin(t * 47.0)
	elif mv == &"erupt":
		var u := AnimKit.clamp01(rise_t / 0.5)
		sink = 2.4 * (1.0 - AnimKit.out_back(u, 1.6))
		ball = 1.0 - AnimKit.smooth(AnimKit.clamp01(rise_t / BriarDervish.RISE_T))
	if dead:
		scl = 1.0 - 0.5 * AnimKit.smooth(AnimKit.win(d_t, 0.3, 3.2))
		if d_t > 6.0:
			sink = (d_t - 6.0) * 0.9
			scl *= maxf(0.001, 1.0 - (d_t - 6.0) / 3.0)
	base_y -= sink
	base_y += sp_drop.step(0.0, dt) * 0.06
	# the spin is planted: the hub drops onto the floor and the roots sweep flat along it (it used to stand up on its roots and spin a metre in the air)
	var plant := 0.0
	match mv:
		&"wind":
			plant = 0.35 * AnimKit.smooth(AnimKit.clamp01(mt / BriarDervish.WHIRL_WIND))
		&"whirl":
			plant = lerpf(0.35, 1.0, AnimKit.smooth(AnimKit.clamp01(mt / 0.25)))
		&"burst":
			plant = 1.0
		&"dizzy":
			plant = 1.0 - AnimKit.smooth(AnimKit.clamp01(mt / (BriarDervish.DIZZY_T * 0.7)))
	base_y -= PLANT_SINK * plant + 0.03 * plant * sin(t * 40.0)      # (the judder of roots dragged over the ground)
	# dust and cracks along the tunnel, and under a whirl
	dust_t -= dt
	if fx != null and dust_t <= 0.0:
		if W.under:
			fx.dust(Vector3(W.x, W.gy + 0.1, W.z), 3, 1.0)
			dust_t = 0.07
		elif mv == &"whirl" or mv == &"burst":
			fx.dust(Vector3(W.x, W.gy + 0.1, W.z), 3, 2.6)
			dust_t = 0.09
	# ---- turning: the crown spins with the sim, then settles on a fifth of a turn; the stem follows it and settles on the facing ----
	var spinning := W.spin_v > 2.5 and not dead
	if spinning or (W.under and not dead):
		var v := W.spin_v if not W.under else 2.5
		crown_a += v * dt
		stem_a += v * dt * (0.82 if mv != &"burst" else 0.9)      # the bulb lags
		sp_crown.x = crown_a
		sp_crown.v = v
		sp_stem.x = stem_a
		sp_stem.v = v * 0.85
	else:
		var fifth := TAU / N_LEGS
		crown_a = sp_crown.step(roundf(crown_a / fifth) * fifth if absf(sp_crown.v) < 6.0 else crown_a + sp_crown.v * dt, dt)
		stem_a = sp_stem.step(roundf(stem_a / TAU) * TAU if absf(sp_stem.v) < 4.0 else stem_a + sp_stem.v * dt, dt)
	# ---- the wobble while dizzy ----
	wob = maxf(0.0, wob - dt / BriarDervish.DIZZY_T) if mv == &"dizzy" else maxf(0.0, wob - dt * 2.0)
	wob_dir += dt * (7.0 + 6.0 * wob)
	var tilt_amt := 0.22 * wob * wob
	var tilt := Basis(Vector3(cos(wob_dir), 0.0, sin(wob_dir)), tilt_amt)
	var root_xf := Transform3D((tilt * Basis(Vector3.UP, W.yaw)).scaled(Vector3.ONE * scl), Vector3(W.x, base_y, W.z))
	# ---- the legs ----
	var spd := absf(W.lvz) if mv == &"stance" else 0.0
	walk_ph += spd * dt * 2.4
	var splay := 0.0
	var flutter := 0.0
	var fling := 0.0            # the spin throws the roots out flat, a blade at knee height (the wind-up holds them up in a crown: two different shapes)
	match mv:
		&"wind":
			splay = AnimKit.smooth(AnimKit.clamp01(mt / BriarDervish.WHIRL_WIND))
		&"whirl", &"burst":
			splay = 1.0
			fling = AnimKit.smooth(AnimKit.clamp01(mt / 0.25)) if mv == &"whirl" else 1.0
			flutter = 1.0 if mv == &"burst" else 0.6
		&"dizzy":
			splay = 1.0 - AnimKit.smooth(AnimKit.clamp01(mt / (BriarDervish.DIZZY_T * 0.7)))
			fling = 1.0
	var stomp := 0.0
	if mv == &"stomp":
		stomp = AnimKit.smooth(AnimKit.clamp01(mt / BriarDervish.STOMP_WIND))
	var brace := 1.0 if mv == &"wound" else 0.0
	var wilt := AnimKit.smooth(AnimKit.win(d_t, 0.2, 2.2)) if dead else 0.0
	for i in legs.size():
		var L := legs[i]
		var breathe := sin(t * 1.4 + L.ph) * 0.04
		var step := maxf(0.0, sin(walk_ph + L.ph)) * minf(1.0, spd)
		var lift := breathe + 0.32 * step
		var reach := breathe * 0.6 - 0.18 * step
		var curl := 0.0
		lift = lerpf(lift, lerpf(0.42, PLANT_LIFT, fling), splay)
		reach = lerpf(reach, lerpf(0.95, PLANT_REACH, fling), splay)
		curl = lerpf(curl, lerpf(0.75, PLANT_CURL, fling) + 0.12 * sin(t * 31.0 + L.ph) * flutter, splay)
		lift += 0.55 * stomp * (1.0 if i % 2 == 0 else 0.7)
		lift -= 0.1 * brace
		reach -= 0.25 * brace
		lift = lerpf(lift, 1.05, ball)          # the root ball: hips up, knees folded down and in
		reach = lerpf(reach, -2.15, ball)
		curl = lerpf(curl, -1.35, ball)
		lift = lerpf(lift, -0.38, wilt)
		reach = lerpf(reach, -0.3, wilt)
		curl = lerpf(curl, 0.3, wilt)
		_leg(L, _qq(L.keys[0], lift, 22.0, dt), _qq(L.keys[1], reach, 22.0, dt), _qq(L.keys[2], curl, 22.0, dt))
	pose.rot[j_crown] = rest_rot[j_crown] * Basis(Vector3.UP, crown_a)
	# ---- the stem: bends, coils and sways ----
	var P: Variant = Game.player if Game.player != null else null
	var look := 0.0
	if P != null and not dead and mv in [&"stance", &"stomp", &"erupt", &"drop"]:
		look = clampf(U.wrap_angle(atan2(float(P.x) - W.x, float(P.z) - W.z) - W.yaw), -0.55, 0.55)
	var bend := 0.05 + 0.03 * sin(t * 1.1)
	bend += -0.35 * splay                                   # leaning back as it whirls
	bend += 0.5 * ball                                      # tucked down into the ball
	bend += 0.18 * brace
	bend += 1.5 * wilt                                      # dying: it droops
	if mv == &"stance" and W.vol_left > 0:
		bend += 0.12
	var side := sin(t * 0.9 + 1.0) * 0.04 + sin(wob_dir) * 0.25 * wob
	var tw := sp_twist.step(W.twist + (-0.25 * minf(1.0, W.spin_v / 8.0) if spinning else 0.0), dt)
	var b0 := sp_bend.step(bend, dt)
	var s0 := sp_side.step(side, dt)
	for i in 4:
		var w := 0.15 + 0.1 * i
		var sy := Vector3(1.0, 1.0 - 0.35 * ball, 1.0)
		pose.scl[j_stem[i]] = sy
		var ex := Basis(Vector3.UP, tw * 0.25 + (stem_a if i == 0 else 0.0)) * Basis(Vector3.RIGHT, b0 * w) * Basis(Vector3.BACK, s0 * w)
		pose.rot[j_stem[i]] = rest_rot[j_stem[i]] * ex
	# ---- the bulb: tracks you, nods on hits and shots ----
	var nod := sp_nod.step(0.0, dt)
	var lk := sp_look.step(look, dt)
	var bulb_b := Basis(Vector3.UP, lk) * Basis(Vector3.RIGHT, nod * 0.08 + 0.2 * wilt)
	pose.rot[j_bulb] = rest_rot[j_bulb] * bulb_b
	var lid_open := 0.75 + 0.08 * sin(t * 2.2)      # (a hood, stood up over the mouth)
	if mv == &"stance" and W.vol_left > 0:
		lid_open = 1.05
	elif mv in [&"wind", &"whirl", &"burst"] or ball > 0.5:
		lid_open = -0.05
	elif mv == &"wound":
		lid_open = 0.7 + 0.35 * sin(t * 13.0)
	elif mv == &"dizzy":
		lid_open = 0.8 + 0.2 * sin(t * 5.0)
	if dead:
		lid_open = lerpf(0.75, 1.5, wilt)
	pose.rot[j_lid] = rest_rot[j_lid] * Basis(Vector3.RIGHT, -1.6 * sp_lid.step(lid_open, dt))
	for i in 2:
		var kick: float = (sp_pod[i] as AnimKit.Spring).step(0.0, dt)
		var sd := 1.0 if i == 0 else -1.0
		var jp := j_pod[i]
		pose.pos[jp] = model.rest[jp].origin + Vector3(0.0, 0.0, kick * 0.3)
		pose.rot[jp] = rest_rot[jp] * Basis(Vector3.UP, sd * (0.08 * sin(t * 1.7 + sd) - kick * 0.1))
		var sq := clampf(1.0 + kick * 0.25, 0.6, 1.3)      # it squashes back, then stretches as it spits
		var gone := dead and pops[i]
		pose.scl[jp] = Vector3.ONE * 0.0001 if gone else Vector3(1.0 / sqrt(sq), 1.0 / sqrt(sq), sq)
	# ---- dying: pods pop, the bulb drops off and rolls, a last puff of spores ----
	if dead:
		for i in 2:
			if not pops[i] and d_t >= 0.7 + 0.5 * i:
				pops[i] = true
				var at := pose.world[j_pod[i]].origin if pose.world.size() > j_pod[i] else Vector3(W.x, W.gy + 3.0, W.z)
				if fx != null:
					fx.sparks(at, 24, 5.0, null, SAP_HEX)
					fx.dust(at, 6, 1.0)
				AnimKit.cue(fx, W, "squelch", 0.3)
		if not puffed and d_t >= 3.0:
			puffed = true
			if fx != null:
				fx.dust(Vector3(W.x, W.gy + 1.0, W.z), 24, 2.5)
				fx.sparks(Vector3(W.x, W.gy + 1.5, W.z), 30, 3.0, null, 0xd8ff80)
			AnimKit.cue(fx, W, "wheeze", 0.9)
	pose.compose(root_xf)
	if dead and d_t >= 1.9:      # the bulb has come off: it falls, bounces and rolls on its own
		if not bulb_off:
			bulb_off = true
			bulb_fall = pose.world[j_bulb]
			var aw := W.yaw + randf_range(-1.0, 1.0)
			bulb_v = Vector3(sin(aw) * 2.2, 1.5, cos(aw) * 2.2)
			bulb_spin = Vector3(randf_range(-4.0, 4.0), randf_range(-2.0, 2.0), randf_range(-4.0, 4.0))
			AnimKit.cue(fx, W, "crack")
		bulb_v.y -= 18.0 * dt
		var o2 := bulb_fall.origin + bulb_v * dt
		var floor_y := W.gy + 0.55 * scl
		if o2.y < floor_y:
			o2.y = floor_y
			if bulb_v.y < -2.0 and fx != null:
				fx.dust(o2, 5, 0.8)
			bulb_v.y = -bulb_v.y * 0.3
			bulb_v.x *= 0.82
			bulb_v.z *= 0.82
			bulb_spin *= 0.8
		bulb_fall = Transform3D(Basis.from_euler(bulb_spin * dt) * bulb_fall.basis, o2)
		if d_t > 6.0:
			bulb_fall = Transform3D(bulb_fall.basis.orthonormalized().scaled(Vector3.ONE * maxf(0.001, 1.0 - (d_t - 6.0) / 3.0)), bulb_fall.origin - Vector3(0.0, dt * 0.3, 0.0))
		_place_subtree(j_bulb, bulb_fall)
	# ---- glow, flash, the ground ring ----
	var d := batch.data
	var o := row * batch.stride
	var fade := 1.0 - AnimKit.win(d_t, 0.5, 2.5) if dead else 1.0
	var burst_k := 1.0 if mv == &"burst" else 0.0
	d[o] = 0.18 * W.flash * W.flash * W.flash      # a short, partial pop per hit: under automatic fire the plain flash (refreshed ~10 times a second) kept the whole plant white and hid the wound-up stem
	d[o + 8] = fade * (1.0 + 0.35 * sin(t * 3.1) + (0.6 if W.vol_left > 0 else 0.0) + 0.5 * burst_k + 0.6 * float(mv == &"wound"))
	d[o + 9] = fade * (0.8 + 0.4 * sin(t * 4.0))
	d[o + 16 + 3] = fade * (0.35 + 0.15 * sin(t * 3.1) + (0.3 if W.vol_left > 0 else 0.0)) * (1.0 - ball)
	d[o + 20 + 3] = 0.0 if dead else 0.4 + 0.2 * sin(t * 4.0)
	if W.mark_on and not dead:
		var u := mt / (BriarDervish.DROP_WARN if mv == &"drop" else BriarDervish.ERUPT_WARN)
		var rr := BriarDervish.LAND_R if mv == &"drop" else BriarDervish.ERUPT_R
		FxBeam.place_ring(ring, W.mark + Vector3(0.0, 0.06, 0.0), rr * (1.25 - 0.25 * AnimKit.clamp01(u)), 0.55 + 0.4 * absf(sin(t * 9.0)))
	else:
		ring.visible = false
	upload()


## the bulb (and what hangs off it) placed by hand once it has come off the stem
func _place_subtree(j: int, xf: Transform3D) -> void:
	pose.world[j] = xf
	var par := model.parent
	for i in range(j + 1, pose.pos.size()):
		var p := par[i]
		if p < j:
			continue
		var anc := p
		while anc > j:
			anc = par[anc]
		if anc != j:
			continue
		pose.world[i] = pose.world[p] * Transform3D(pose.rot[i].scaled_local(pose.scl[i]), pose.pos[i])
