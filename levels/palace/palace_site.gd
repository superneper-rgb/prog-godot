class_name PalaceSite
extends RefCounted
## THE FOINT PERVERT PALACE SITE (user, 2026-11-19: "very much under construction no complete structures, wood and metal scaffolding. cranes holding platforms to climb"). FOINT's new tower
## going up on a lot of its own in the bay off FOINT CITY's east quay, at the end of Harbor St (x 131-191, z 176-226 in the hub's own coordinates; nothing to do with the dome, user). A steel
## frame ten floors high round a concrete core, only some floors decked, a scaffold up the west face with its stair flights, a hoist on the north face, two tower cranes (A, the tall one, its jib
## out over the quay; B at the south-east corner, its hook carrying the beam bundle the climb rides), festoon bulbs along the floors, floodlights, the site office and materials, and a hoarding
## round it all with FOINT's lettering and the gate on the quay.
## Built from this one file twice: `full` for its own level (levels/palace/palace_level.gd: the climb's colliders, its lights, everything inside the hoarding), and the city's view of it
## (levels/hub/hub_sambo.gd: what shows over the hoarding, with the hoarding and the shut gate solid, and no lights of its own: the city's light is painted).
## The climb: up the west scaffold's three lifts (A -6, B -2, C 2: stair flights at alternate ends, a gap in the boards on A and on B), into floor 3's decked west bay, along the beam on line
## z 190.8 to the gap where its next beam is not in yet (two hanging tubes to swing across: Config.pole_swing), to the deck patch at the south-east corner, onto crane B's beam bundle, up to
## floor 6's slab (the fight), into the hoist on the north face, up to the top slab (floor 10), and into crane A's man-basket. The top slab is where the mech comes down.

const Y0 := -10.0                  # the lot's deck, level with the quay
const LX0 := 131.3
const LX1 := 191.3
const LZ0 := 176.0
const LZ1 := 226.0
const HOARD_X := 131.9             # the hoarding's line on the quay side
const HOARD_H := 2.6
const GATE_Z := 201.0
const GATE_W := 4.4
const TX: Array[float] = [148.0, 154.0, 160.0, 166.0, 172.0, 178.0]      # the frame's column lines
const TZ: Array[float] = [184.0, 190.8, 197.6, 204.4, 211.2, 218.0]
const FH := 4.0                    # a floor
const NF := 10                     # floors over the ground: the top slab is floor 10
const CORE := [158.6, 167.4, 196.6, 205.4]
const CORE_TOP := 36.0
const SX0 := 144.4                 # the west scaffold, x
const SX1 := 147.6
const BEAM_Z := 190.8              # floor 3's walked beam
const POLE_X: Array[float] = [167.7, 170.3]
const PALLET := [172.6, 177.4, 180.9, 183.3]      # crane B's beam bundle (x0, x1, z0, z1)
const PALLET_LO := 2.0             # its top, waiting at floor 3, and where it takes you
const PALLET_HI := 14.0
const HOIST := [159.4, 163.6, 218.7, 221.9]       # the hoist cage on the north face
const MAST_A := Vector3(184.5, Y0, 201.0)
const TOP_A := 50.0                # crane A's slewing ring
const JIB_Y := 51.6                # its jib's walkway
const JIB_W := 128.0               # how far west the jib reaches (over the quay)
const CJIB_E := 201.0              # the counter-jib's end, east
const BASKET := [179.2, 182.6, 199.4, 202.6]      # crane A's man-basket, waiting at the top slab's east edge
const MAST_B := Vector3(187.6, Y0, 182.1)      # (its jib runs west right over the beam bundle)
const TOP_B := 26.0
const JIB_B_Y := 27.5

var world: World
var full := false
var root: Node3D
var b: UfBuild
var rng := RandomNumberGenerator.new()
# moving parts the level drives (the city's view leaves them parked)
var gate_l: Node3D
var gate_r: Node3D
var gate_solid: World.Solid = null
var pallet: Node3D
var pallet_cable: MeshInstance3D
var hoist_cage: Node3D
var basket: Node3D
var basket_cable: MeshInstance3D
var jib_a: Node3D                  # crane A's slewing part (rotation.y about the mast)
var trolley_a: Node3D
var hook_b: Node3D
var beacons: Array[Node3D] = []
var floods: Array[Light3D] = []
# batches
var _steel: PalaceKit.Batch
var _cols: PalaceKit.Batch
var _tube: PalaceKit.Batch
var _board: PalaceKit.Batch
var _crane: PalaceKit.Batch
var _rebar: PalaceKit.Batch
var _bulb: PalaceKit.Batch
var _cable: PalaceKit.Batch
var _cwt: PalaceKit.Batch
var _mats := {}


static func ly(k: int) -> float:
	return Y0 + FH * k


func build(parent: Node3D, w: World, p_full: bool) -> void:
	world = w
	full = p_full
	rng.seed = 6969
	root = Node3D.new()
	root.name = "PervertPalaceSite"
	parent.add_child(root)
	b = UfBuild.new(world)
	b.base_y = Y0
	b.foot_shade = 0.75
	_materials()
	_lot()
	_hoarding()
	_frame()
	_core()
	_scaffold_west()
	_scaffold_north()
	_crane_a()
	_crane_b()
	_hoist()
	_bulbs()
	_floods()
	if full:
		_props()
		_route_solids()
	b.commit(root, "_site")
	_steel.commit(root, "Steel")
	_cols.commit(root, "Columns")
	_tube.commit(root, "Tubes")
	_board.commit(root, "Boards")
	_crane.commit(root, "CraneSteel")
	_rebar.commit(root, "Rebar")
	_bulb.commit(root, "Bulbs")
	_cable.commit(root, "Cables")
	_cwt.commit(root, "Counterweights")
	_signs()


# ---------------------------------------------------------------------------------------------- materials

func _materials() -> void:
	b.tex("deck", "concrete_floor_worn_001", {"tile": 3.2, "tint": Color(0.36, 0.35, 0.39), "puddles": 1.0, "growth": 0.0})
	b.tex("slab", "concrete_floor_worn_001", {"tile": 3.0, "tint": Color(0.5, 0.49, 0.52), "puddles": 0.8, "growth": 0.0})
	b.tex("core", "cracked_concrete_wall", {"tile": 3.0, "tint": Color(0.46, 0.45, 0.48), "growth": 0.05})
	b.tex("hoard", "oriented_strand_board", {"tile": 2.44, "tint": Color(0.17, 0.12, 0.22), "growth": 0.0})       # painted FOINT violet-black over the chipboard
	b.tex("osb", "oriented_strand_board", {"tile": 2.44, "tint": Color(0.78, 0.68, 0.55), "growth": 0.0})
	b.tex("ply", "plywood", {"tile": 2.44, "tint": Color(0.72, 0.6, 0.48), "growth": 0.0, "puddles": 0.4})
	b.tex("metaldeck", "corrugated_iron_02", {"tile": 1.4, "tint": Color(0.42, 0.42, 0.47), "puddles": 0.5, "growth": 0.0})
	b.tex("plate", "metal_plate_02", {"tile": 1.6, "tint": Color(0.3, 0.3, 0.34), "puddles": 0.3, "growth": 0.0})
	b.mat("pile", Color(0.07, 0.062, 0.09), {"rough": 0.6, "scale": 0.05})
	b.mat("quay", Color(0.2, 0.19, 0.23), {"rough": 0.8})
	b.mat("cabin", Color(0.82, 0.8, 0.74), {"rough": 0.6, "metal": 0.2})
	b.mat("cabin_dark", Color(0.12, 0.12, 0.14), {"rough": 0.5})
	b.mat("brick", Color(0.42, 0.16, 0.1), {"rough": 0.9, "scale": 0.4})
	b.mat("bag", Color(0.62, 0.6, 0.55), {"rough": 0.95})
	b.mat("pallet", Color(0.42, 0.3, 0.18), {"rough": 0.9})
	b.mat("skip", Color(0.55, 0.38, 0.08), {"rough": 0.6, "metal": 0.4})
	b.mat("toilet", Color(0.12, 0.32, 0.55), {"rough": 0.5})
	b.mat("rubber", Color(0.03, 0.03, 0.035), {"rough": 0.8})
	b.mats["window"] = PalaceKit.glow(Color(0.55, 0.78, 1.0), 1.6)
	b.mats["amber"] = PalaceKit.glow(Color(1.0, 0.6, 0.16), 4.0)
	b.mats["redlamp"] = PalaceKit.glow(Color(1.0, 0.07, 0.04), 7.0)
	b.mats["flood"] = PalaceKit.glow(Color(0.92, 0.96, 1.0), 9.0)
	b.mats["stripes"] = PalaceKit.stripes(Color(0.75, 0.06, 0.05), Color(0.92, 0.9, 0.86))
	b.mats["galv"] = PalaceKit.plain(Color(0.46, 0.48, 0.52), 0.32, 0.85)
	var steel := PalaceKit.ph("metal_plate_02", {"tile": 1.5, "tint": Color(0.46, 0.14, 0.1), "metal": 0.25, "rough": 1.0})      # red-oxide primer
	var crane := PalaceKit.ph("metal_plate_02", {"tile": 1.5, "tint": Color(0.17, 0.15, 0.22), "metal": 0.55, "rough": 0.9})    # the cranes in the city's own near-black violet
	_mats["steel"] = steel
	_mats["crane"] = crane
	_steel = PalaceKit.Batch.new(PalaceKit.ibeam_mesh(), steel)
	_cols = PalaceKit.Batch.new(PalaceKit.ibeam_mesh(0.4, 0.4, 0.028, 0.02), steel)
	_tube = PalaceKit.Batch.new(PalaceKit.tube_mesh(6), b.mats["galv"], false)
	_board = PalaceKit.Batch.new(PalaceKit.box_mesh(), PalaceKit.ph_single("res://assets/third-party/polyhaven/old_planks_02.jpg", Color(0.62, 0.5, 0.38), 1.6, 0.85), true)
	_crane = PalaceKit.Batch.new(PalaceKit.tube_mesh(6), crane)
	_rebar = PalaceKit.Batch.new(PalaceKit.tube_mesh(5), PalaceKit.plain(Color(0.22, 0.1, 0.07), 0.75, 0.6), false)
	_bulb = PalaceKit.Batch.new(PalaceKit.ball_mesh(0.07), PalaceKit.glow(Color(0.72, 0.9, 1.0), 7.0), false)
	_cable = PalaceKit.Batch.new(PalaceKit.tube_mesh(4), PalaceKit.plain(Color(0.02, 0.02, 0.025), 0.6, 0.3), false)
	_cwt = PalaceKit.Batch.new(PalaceKit.box_mesh(), PalaceKit.ph("concrete_floor_worn_001", {"tile": 2.0, "tint": Color(0.42, 0.42, 0.44)}))


# ---------------------------------------------------------------------------------------------- the lot and the hoarding

## The pier deck on its piles, level with the quay
func _lot() -> void:
	b.box("deck", LX0, LX1, Y0 - 1.6, Y0, LZ0, LZ1)
	var x := LX0 + 2.0
	while x < LX1:
		for z: float in [LZ0 + 0.6, LZ1 - 0.6]:
			b.box("pile", x - 0.45, x + 0.45, -16.0, Y0 - 1.6, z - 0.45, z + 0.45, false)
		x += 7.5
	var z2 := LZ0 + 6.0
	while z2 < LZ1 - 3.0:
		b.box("pile", LX1 - 1.05, LX1 - 0.15, -16.0, Y0 - 1.6, z2 - 0.45, z2 + 0.45, false)
		z2 += 7.5
	# the deck's lip, a darker band where the concrete meets the water
	b.box("pile", LX0, LX1, Y0 - 1.7, Y0 - 1.5, LZ0 - 0.2, LZ0, false)
	b.box("pile", LX0, LX1, Y0 - 1.7, Y0 - 1.5, LZ1, LZ1 + 0.2, false)
	b.box("pile", LX1, LX1 + 0.2, Y0 - 1.7, Y0 - 1.5, LZ0 - 0.2, LZ1 + 0.2, false)


## OSB panels on steel posts round the lot, painted FOINT's violet-black outside, raw inside; the gate in the quay side
func _hoarding() -> void:
	var t := 0.05
	var runs := [      # [x0, z0, x1, z1]: the four sides, the quay side in two (the gate between)
		[HOARD_X, LZ0 + 0.3, HOARD_X, GATE_Z - GATE_W * 0.5], [HOARD_X, GATE_Z + GATE_W * 0.5, HOARD_X, LZ1 - 0.3],
		[HOARD_X, LZ0 + 0.3, LX1 - 0.4, LZ0 + 0.3], [HOARD_X, LZ1 - 0.3, LX1 - 0.4, LZ1 - 0.3], [LX1 - 0.4, LZ0 + 0.3, LX1 - 0.4, LZ1 - 0.3]]
	for r: Array in runs:
		var x0: float = r[0]
		var z0: float = r[1]
		var x1: float = r[2]
		var z1: float = r[3]
		if absf(x1 - x0) < 0.01:      # along z
			b.box("hoard", x0 - t, x0, Y0, Y0 + HOARD_H, minf(z0, z1), maxf(z0, z1))
			b.box("osb", x0, x0 + t, Y0, Y0 + HOARD_H, minf(z0, z1), maxf(z0, z1), false)
			var z := minf(z0, z1)
			while z <= maxf(z0, z1) + 0.01:
				b.box("galv", x0 + t, x0 + t + 0.08, Y0, Y0 + HOARD_H + 0.1, z - 0.04, z + 0.04, false)
				z += 2.44
		else:
			var inward := 1.0 if z0 < 200.0 else -1.0
			var zo := z0 - (t if inward > 0.0 else 0.0)
			b.box("hoard", minf(x0, x1), maxf(x0, x1), Y0, Y0 + HOARD_H, minf(zo, zo + t), maxf(zo, zo + t))
			b.box("osb", minf(x0, x1), maxf(x0, x1), Y0, Y0 + HOARD_H, z0 + (0.0 if inward > 0.0 else -t), z0 + (t if inward > 0.0 else 0.0), false)
	# the gate: two leaves on the posts either side, shut in the city's view, swung in on the site
	var hinge_s := Vector3(HOARD_X, Y0, GATE_Z - GATE_W * 0.5)
	var hinge_n := Vector3(HOARD_X, Y0, GATE_Z + GATE_W * 0.5)
	gate_l = _gate_leaf(hinge_s, 1.0)
	gate_r = _gate_leaf(hinge_n, -1.0)
	for p: Vector3 in [hinge_s, hinge_n]:
		b.box("plate", p.x - 0.12, p.x + 0.12, Y0, Y0 + 3.1, p.z - 0.12, p.z + 0.12)
		b.box("amber", p.x - 0.1, p.x + 0.1, Y0 + 3.1, Y0 + 3.3, p.z - 0.1, p.z + 0.1, false)      # the warning lamps on the gate posts
	if not full:
		gate_solid = world.add({"kind": "box", "cx": HOARD_X - 0.05, "cz": GATE_Z, "hx": 0.08, "hz": GATE_W * 0.5, "bottom": Y0, "top": Y0 + HOARD_H, "tag": "hoard"})


func _gate_leaf(hinge: Vector3, dir: float) -> Node3D:
	var n := Node3D.new()
	n.name = "GateLeaf"
	root.add_child(n)
	n.position = hinge
	var w := GATE_W * 0.5 - 0.06
	var frame := PalaceKit.plain(Color(0.12, 0.11, 0.14), 0.5, 0.7)
	var leaf := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(0.06, HOARD_H - 0.1, w)
	leaf.mesh = m
	leaf.material_override = b.mats["hoard"]
	leaf.position = Vector3(-0.04, HOARD_H * 0.5, dir * w * 0.5)
	n.add_child(leaf)
	for y: float in [0.25, HOARD_H - 0.25]:
		var rail := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(0.08, 0.08, w)
		rail.mesh = rm
		rail.material_override = frame
		rail.position = Vector3(0.02, y, dir * w * 0.5)
		n.add_child(rail)
	return n


## Open (1) or shut (0) the gate: the leaves swing in onto the lot
func set_gate(u: float) -> void:
	if gate_l != null:
		gate_l.rotation.y = -u * 1.75
		gate_r.rotation.y = u * 1.75
	if gate_solid != null:
		gate_solid.set_off(u > 0.3)


## FOINT's lettering on the hoarding (lit, the brand's own amber) and the site's safety signs (painted)
func _signs() -> void:
	var amber := Color(1.0, 0.66, 0.2)
	var out := Basis(Vector3.UP, -PI / 2.0)      # facing -X: out to the quay
	PalaceKit.sign_text(root, "FOINT", Transform3D(out, Vector3(HOARD_X - 0.08, Y0 + 1.75, 188.5)), 190, amber, true, true)
	PalaceKit.sign_text(root, "PERVERT PALACE", Transform3D(out, Vector3(HOARD_X - 0.08, Y0 + 0.95, 188.5)), 120, Color(0.95, 0.92, 1.0), true, true)
	PalaceKit.sign_text(root, "COMING SOON  -  EVERYBODY'S WELCOME. NOBODY'S WATCHING.", Transform3D(out, Vector3(HOARD_X - 0.08, Y0 + 0.4, 188.5)), 44, Color(0.85, 0.8, 0.95), false)
	PalaceKit.sign_text(root, "FOINT", Transform3D(out, Vector3(HOARD_X - 0.08, Y0 + 1.75, 213.5)), 190, amber, true, true)
	PalaceKit.sign_text(root, "PERVERT PALACE", Transform3D(out, Vector3(HOARD_X - 0.08, Y0 + 0.95, 213.5)), 120, Color(0.95, 0.92, 1.0), true, true)
	PalaceKit.sign_text(root, "69 FLOORS OF DISCRETION  -  OPENING NEXT SPRING", Transform3D(out, Vector3(HOARD_X - 0.08, Y0 + 0.4, 213.5)), 44, Color(0.85, 0.8, 0.95), false)
	var gs := Transform3D(out, Vector3(HOARD_X - 0.09, Y0 + 2.05, GATE_Z + GATE_W * 0.5 + 1.25))
	PalaceKit.sign_text(root, "DANGER\nCONSTRUCTION SITE\nAUTHORISED PERSONNEL ONLY", gs, 46, Color(0.95, 0.15, 0.1), false, false, Color(0.95, 0.92, 0.85))
	PalaceKit.sign_text(root, "HARD HATS\nMUST BE WORN", Transform3D(out, Vector3(HOARD_X - 0.09, Y0 + 2.0, GATE_Z - GATE_W * 0.5 - 1.25)), 48, Color(0.1, 0.35, 0.85), false, false, Color(0.95, 0.92, 0.85))
	for z: float in [LZ0 + 0.22, LZ1 - 0.22]:      # the long sides, seen from the bridge and the quay
		var face := Basis(Vector3.UP, PI) if z < 200.0 else Basis.IDENTITY
		for x: float in [146.0, 172.0]:
			PalaceKit.sign_text(root, "FOINT PERVERT PALACE", Transform3D(face, Vector3(x, Y0 + 1.5, z + (-0.06 if z < 200.0 else 0.06))), 140, amber, true, true)
	# the crane's counter-jib carries FOINT's name too, lit, high over the bay (it turns with the jib)
	if jib_a != null:
		var l := PalaceKit.sign_text(jib_a, "FOINT", Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(9.0, JIB_Y - TOP_A + 0.2, -1.32)), 520, amber, true, true)
		l.pixel_size = 0.006
		var l2 := PalaceKit.sign_text(jib_a, "FOINT", Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(9.0, JIB_Y - TOP_A + 0.2, 1.32)), 520, amber, true, true)
		l2.pixel_size = 0.006


# ---------------------------------------------------------------------------------------------- the frame

## Columns on the grid, beams at every floor (a few at the top not in yet), decks where they are laid, the two slabs (floors 6 and 10), rebar out of the column stubs on top
func _frame() -> void:
	var top := ly(NF) + 1.3
	for x in TX:
		for z in TZ:
			_cols.add(PalaceKit.span(Vector3(x, Y0, z), Vector3(x, top, z)))
			if full:
				world.add({"kind": "box", "cx": x, "cz": z, "hx": 0.21, "hz": 0.21, "bottom": Y0, "top": top, "tag": "steel", "no_cam": true})
			for k in 6:      # rebar out of the stub, waiting for the next floor
				var a := TAU * k / 6.0
				var p := Vector3(x + cos(a) * 0.16, top, z + sin(a) * 0.16)
				_rebar.add(PalaceKit.span(p, p + Vector3(cos(a) * 0.05, 1.1 + 0.2 * rng.randf(), sin(a) * 0.05), 0.012, 0.012))
	for k in range(1, NF + 1):
		var y := ly(k) - 0.1 - 0.18      # (the beams' middle: their tops 0.1 under the floor)
		for i in TZ.size():
			for j in TX.size() - 1:
				if _beam_missing(k, true, i, j):
					continue
				_steel.add(PalaceKit.span(Vector3(TX[j] + 0.2, y, TZ[i]), Vector3(TX[j + 1] - 0.2, y, TZ[i])))
		for j in TX.size():
			for i in TZ.size() - 1:
				if _beam_missing(k, false, j, i):
					continue
				_steel.add(PalaceKit.span(Vector3(TX[j], y, TZ[i] + 0.2), Vector3(TX[j], y, TZ[i + 1] - 0.2)))
		# secondary joists between the main beams where a floor is decked
		for d: Array in _decks(k):
			var z := float(d[2]) + 1.7
			while z < float(d[3]) - 0.5:
				_steel.add(PalaceKit.span(Vector3(float(d[0]) + 0.2, y + 0.06, z), Vector3(float(d[1]) - 0.2, y + 0.06, z), 0.7, 0.7))
				z += 3.4
	# the decks and slabs
	for k in range(1, NF + 1):
		for d: Array in _decks(k):
			var tag: String = d[4]
			var thick := 0.32 if tag == "slab" else 0.1
			b.box(tag, d[0], d[1], ly(k) - thick, ly(k), d[2], d[3], full)
			if tag == "slab":      # its edge formwork: a plywood band round the poured edge
				b.box("ply", d[0] - 0.03, d[1] + 0.03, ly(k) - thick - 0.05, ly(k) + 0.06, d[2] - 0.03, d[2], false)
				b.box("ply", d[0] - 0.03, d[1] + 0.03, ly(k) - thick - 0.05, ly(k) + 0.06, d[3], d[3] + 0.03, false)
	# the ground floor's slab
	b.box("slab", TX[0] - 0.3, TX[5] + 0.3, Y0, Y0 + 0.2, TZ[0] - 0.3, TZ[5] + 0.3, full)
	# floor 10: rebar mats over the bays still to be poured (a grid of bars on chairs over plywood formwork), on the north-east
	var rx0 := 166.0
	var rx1 := 178.0
	var rz0 := 211.2
	var rz1 := 218.0
	var yr := ly(NF) + 0.06
	var x2 := rx0 + 0.2
	while x2 < rx1:
		_rebar.add(PalaceKit.span(Vector3(x2, yr, rz0 + 0.1), Vector3(x2, yr, rz1 - 0.1), 0.012, 0.012))
		x2 += 0.3
	var z3 := rz0 + 0.2
	while z3 < rz1:
		_rebar.add(PalaceKit.span(Vector3(rx0 + 0.1, yr + 0.025, z3), Vector3(rx1 - 0.1, yr + 0.025, z3), 0.012, 0.012))
		z3 += 0.3


## Which beams are not in yet: high up, here and there (never on the walked lines, round the slabs or the climb)
func _beam_missing(k: int, along_x: bool, line: int, seg: int) -> bool:
	if k == 3 and along_x and line == 1 and seg == 3:      # floor 3's beam on z 190.8 between x 166 and 172: the swing over the gap
		return true
	if k == 6 or k == NF or k <= 3:
		return false
	var h := (k * 131 + line * 17 + seg * 7 + (3 if along_x else 0)) % 11
	return k >= 7 and h < 2


## A floor's laid decks: [x0, x1, z0, z1, material]
func _decks(k: int) -> Array:
	var X0 := TX[0] - 0.25
	var X1 := TX[5] + 0.25
	var Z0 := TZ[0] - 0.25
	var Z1 := TZ[5] + 0.25
	match k:
		2:
			return [[X0, TX[1], Z0, Z1, "metaldeck"]]
		3:
			return [[X0, TX[2], Z0, Z1, "metaldeck"], [TX[4], X1, Z0, TZ[1] + 1.2, "metaldeck"]]
		4, 5:
			return [[TX[4], X1, Z0, TZ[1], "metaldeck"], [X0, TX[1], TZ[3], Z1, "metaldeck"]]
		6:
			return [[X0, X1, Z0, Z1, "slab"]]
		7, 9:
			return [[TX[1], TX[4], TZ[4], Z1, "metaldeck"]]
		8:
			return [[TX[1], TX[4], TZ[4], Z1, "metaldeck"], [TX[4], X1, Z0, TZ[1], "metaldeck"]]
		NF:
			return [[X0, X1, Z0, Z1, "slab"]]
	return []


## The core: four concrete walls from the ground to above the top floor, a dark doorway at each slab, the climbing formwork rig on top
func _core() -> void:
	var c: Array = CORE
	var t := 0.3
	var x0: float = c[0]
	var x1: float = c[1]
	var z0: float = c[2]
	var z1: float = c[3]
	b.box("core", x0, x1, Y0, CORE_TOP, z0, z0 + t, full)
	b.box("core", x0, x1, Y0, CORE_TOP, z1 - t, z1, full)
	b.box("core", x0, x0 + t, Y0, CORE_TOP, z0 + t, z1 - t, full)
	b.box("core", x1 - t, x1, Y0, CORE_TOP, z0 + t, z1 - t, full)
	var void_m := StandardMaterial3D.new()
	void_m.albedo_color = Color(0.01, 0.01, 0.015)
	void_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	b.mats["void"] = void_m
	for k: int in [3, 6, NF]:      # the lift doors to come: dark openings on the west face
		b.box("void", x0 - 0.02, x0, ly(k), ly(k) + 2.4, 199.9, 202.1, false)
	# the climbing formwork on top: a steel deck round the walls, plywood forms standing up, the rig's frame
	var y := CORE_TOP
	b.box("plate", x0 - 1.2, x1 + 1.2, y + 0.6, y + 0.75, z0 - 1.2, z1 + 1.2, false)
	b.box("ply", x0 - 0.15, x1 + 0.15, y, y + 2.2, z0 - 0.15, z0, false)
	b.box("ply", x0 - 0.15, x1 + 0.15, y, y + 2.2, z1, z1 + 0.15, false)
	for p: Vector2 in [Vector2(x0 - 1.2, z0 - 1.2), Vector2(x1 + 1.2, z0 - 1.2), Vector2(x1 + 1.2, z1 + 1.2), Vector2(x0 - 1.2, z1 + 1.2)]:
		_crane.add(PalaceKit.span(Vector3(p.x, y - 3.0, p.y), Vector3(p.x, y + 3.0, p.y), 0.09, 0.09))


# ---------------------------------------------------------------------------------------------- scaffold

## A scaffold standard
func _std(x: float, z: float, y0: float, y1: float) -> void:
	_tube.add(PalaceKit.span(Vector3(x, y0, z), Vector3(x, y1, z), 0.024, 0.024))


func _lift_boards(x0: float, x1: float, z0: float, z1: float, y: float, solid: bool) -> void:
	var n := maxi(1, int(round((x1 - x0) / 0.23)))
	var w := (x1 - x0) / n
	for i in n:
		var cx := x0 + w * (i + 0.5)
		var z := z0
		while z < z1 - 0.05:
			var e := minf(z + 3.9, z1)
			_board.add(Transform3D(Basis().scaled(Vector3(w - 0.012, 0.05, e - z - 0.02)), Vector3(cx, y - 0.025, (z + e) * 0.5)))
			z = e
	if solid and full:
		world.add({"kind": "box", "cx": (x0 + x1) * 0.5, "cz": (z0 + z1) * 0.5, "hx": (x1 - x0) * 0.5, "hz": (z1 - z0) * 0.5, "bottom": y - 0.06, "top": y, "tag": "board", "no_cam": true})


## A guard rail: tubes at 0.5 and 1.0 over a deck, a toe board; solid to waist height so nobody walks off
func _rail(a: Vector3, c: Vector3, solid: bool = true) -> void:
	for h: float in [0.5, 1.0]:
		_tube.add(PalaceKit.span(a + Vector3(0, h, 0), c + Vector3(0, h, 0), 0.024, 0.024))
	var d := c - a
	var L := d.length()
	var n := maxi(1, int(L / 2.4))
	for i in n + 1:
		var p := a + d * (float(i) / n)
		_tube.add(PalaceKit.span(p, p + Vector3(0, 1.05, 0), 0.024, 0.024))
	_board.add(PalaceKit.span(a + Vector3(0, 0.075, 0), c + Vector3(0, 0.075, 0), 0.15, 0.03))
	if solid and full:
		world.add({"kind": "box", "cx": (a.x + c.x) * 0.5, "cz": (a.z + c.z) * 0.5, "hx": maxf(0.05, absf(d.x) * 0.5), "hz": maxf(0.05, absf(d.z) * 0.5), "bottom": a.y, "top": a.y + 1.05, "tag": "rail", "no_cam": true})


## The west face's scaffold: three working lifts (A at -6, B at -2, C at 2, level with floor 3), stair flights at alternate ends, a gap in the boards on A and on B; tubes all the way up past floor 3
func _scaffold_west() -> void:
	var top := ly(3) + 2.2
	var z := TZ[0]
	while z <= TZ[5] + 0.01:
		_std(SX0, z, Y0, top)
		_std(SX1, z, Y0, top)
		z += 2.4
	var y := Y0 + 2.0
	while y <= top:      # ledgers along the face at every lift, transoms across
		_tube.add(PalaceKit.span(Vector3(SX0, y, TZ[0]), Vector3(SX0, y, TZ[5]), 0.024, 0.024))
		_tube.add(PalaceKit.span(Vector3(SX1, y, TZ[0]), Vector3(SX1, y, TZ[5]), 0.024, 0.024))
		var zz := TZ[0]
		while zz <= TZ[5] + 0.01:
			_tube.add(PalaceKit.span(Vector3(SX0 - 0.1, y + 0.05, zz), Vector3(SX1 + 0.3, y + 0.05, zz), 0.024, 0.024))
			zz += 2.4
		y += 2.0
	var zb := TZ[0]
	while zb < TZ[5] - 2.0:      # the face's bracing: diagonals up each bay of the outside line
		_tube.add(PalaceKit.span(Vector3(SX0 - 0.03, Y0 + 0.2, zb), Vector3(SX0 - 0.03, Y0 + 4.0, zb + 2.4), 0.022, 0.022))
		_tube.add(PalaceKit.span(Vector3(SX0 - 0.03, Y0 + 4.0, zb + 2.4), Vector3(SX0 - 0.03, Y0 + 8.0, zb), 0.022, 0.022))
		_tube.add(PalaceKit.span(Vector3(SX0 - 0.03, Y0 + 8.0, zb), Vector3(SX0 - 0.03, Y0 + 12.0, zb + 2.4), 0.022, 0.022))
		zb += 4.8
	var mid := SX0 + 1.45      # the flights take the outer half of the scaffold
	# lift A (-6): its flight from the ground is outside, on the south end; a flight up to B at the north end takes its outer half there; a gap at z 199.6-202
	_lift_boards(SX0, SX1, TZ[0], 199.6, ly(1), true)
	_lift_boards(SX0, SX1, 202.0, 207.6, ly(1), true)
	_lift_boards(mid, SX1, 207.6, TZ[5], ly(1), true)
	_lift_boards(SX0, mid, 216.6, TZ[5], ly(1), true)
	# lift B (-2): the flight from A comes up its outer half at the north end; the flight on to C leaves from its outer half at the south end; a gap at z 194-196.2
	_lift_boards(mid, SX1, TZ[0], 194.0, ly(2), true)
	_lift_boards(SX0, SX1, 196.2, 207.6, ly(2), true)
	_lift_boards(mid, SX1, 207.6, TZ[5], ly(2), true)
	_lift_boards(SX0, mid, TZ[0], 186.0, ly(2), true)
	# lift C (2), level with floor 3: boards on to the frame
	_lift_boards(mid, SX1, TZ[0], 195.0, ly(3), true)
	_lift_boards(SX0, SX1, 195.0, TZ[5], ly(3), true)
	_lift_boards(SX1, TX[0] - 0.25, 186.0, TZ[5], ly(3), true)      # (the boards bridging to floor 3's deck)
	# the flights: ramps of boards on bearers
	_flight(Vector2(SX0 - 2.8, SX0), 184.6, 193.0, Y0, ly(1))              # ground -> A, outside the south end, rising north
	_lift_boards(SX0 - 2.8, SX0, 193.0, 195.0, ly(1), true)                  # (its landing)
	_flight(Vector2(SX0, mid), 216.6, 207.6, ly(1), ly(2))                   # A -> B, rising south
	_flight(Vector2(SX0, mid), 186.0, 195.0, ly(2), ly(3))                   # B -> C, rising north
	# the outside guard rails of each lift (the flights' open sides keep theirs)
	for k: int in [1, 2, 3]:
		_rail(Vector3(SX0 - 0.02, ly(k), 195.2 if k == 1 else TZ[0]), Vector3(SX0 - 0.02, ly(k), TZ[5]))
	_rail(Vector3(SX0 - 2.8, ly(1), 195.0), Vector3(SX0, ly(1), 195.0))
	_rail(Vector3(SX0 - 2.8, ly(1), 193.0), Vector3(SX0 - 2.8, ly(1), 195.0))


## A stair flight of boards: x0..x1 wide, from z_lo at y_lo to z_hi at y_hi (either way along z)
func _flight(xs: Vector2, z_lo: float, z_hi: float, y_lo: float, y_hi: float) -> void:
	var cz := (z_lo + z_hi) * 0.5
	var hz := absf(z_hi - z_lo) * 0.5
	var yaw := 0.0 if z_hi > z_lo else PI      # (a ramp at yaw 0 rises toward +z)
	b.ramp("ply", (xs.x + xs.y) * 0.5, cz, (xs.y - xs.x) * 0.5, hz, y_lo, y_hi, yaw, 0.08, full)
	var n := int(hz * 2.0 / 0.28)      # treads: cleats across the boards
	for i in n:
		var u := (i + 0.5) / n
		var z := lerpf(z_lo, z_hi, u)
		var y := lerpf(y_lo, y_hi, u)
		_board.add(Transform3D(Basis().scaled(Vector3(xs.y - xs.x - 0.04, 0.04, 0.05)), Vector3((xs.x + xs.y) * 0.5, y + 0.03, z)))
	for x: float in [xs.x, xs.y]:      # the hand rails
		_tube.add(PalaceKit.span(Vector3(x, y_lo + 1.0, z_lo), Vector3(x, y_hi + 1.0, z_hi), 0.024, 0.024))


## The north face's scaffold round the hoist, from floor 6 to the top: lifts at each floor on the hoist's sides (what the hoist's riders are shot from)
func _scaffold_north() -> void:
	var zf := TZ[5] + 0.3
	var zo := TZ[5] + 3.4
	for x: float in [152.0, 154.4, 156.8, 166.2, 168.6, 171.0]:
		_std(x, zf, Y0, ly(NF) + 1.2)
		_std(x, zo, Y0, ly(NF) + 1.2)
	for k: int in [6, 7, 8, 9, 10]:
		var y := ly(k)
		for side: Vector2 in [Vector2(152.0, 156.8), Vector2(166.2, 171.0)]:
			_lift_boards(side.x, side.y, zf, zo, y, k != 6 and k != NF)
			_tube.add(PalaceKit.span(Vector3(side.x, y + 1.0, zo), Vector3(side.y, y + 1.0, zo), 0.024, 0.024))
			_tube.add(PalaceKit.span(Vector3(side.x, y + 0.5, zo), Vector3(side.y, y + 0.5, zo), 0.024, 0.024))


# ---------------------------------------------------------------------------------------------- cranes and the hoist

## A square lattice mast from y0 to y1: four chords, a horizontal and a diagonal on each face every section
func _mast(c: Vector3, half: float, y0: float, y1: float, sec: float, bt: PalaceKit.Batch, chord: float = 0.08, lace: float = 0.045) -> void:
	var corners := [Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)]
	for q: Vector2 in corners:
		bt.add(PalaceKit.span(Vector3(c.x + q.x, y0, c.z + q.y), Vector3(c.x + q.x, y1, c.z + q.y), chord, chord))
	var y := y0
	var flip := false
	while y < y1 - 0.01:
		var y2 := minf(y + sec, y1)
		for i in 4:
			var a: Vector2 = corners[i]
			var d: Vector2 = corners[(i + 1) % 4]
			bt.add(PalaceKit.span(Vector3(c.x + a.x, y, c.z + a.y), Vector3(c.x + d.x, y, c.z + d.y), lace, lace))
			if flip:
				bt.add(PalaceKit.span(Vector3(c.x + a.x, y, c.z + a.y), Vector3(c.x + d.x, y2, c.z + d.y), lace, lace))
			else:
				bt.add(PalaceKit.span(Vector3(c.x + d.x, y, c.z + d.y), Vector3(c.x + a.x, y2, c.z + a.y), lace, lace))
		flip = not flip
		y = y2


## A triangular lattice boom along a line (two bottom chords and one top chord)
func _boom(a: Vector3, c: Vector3, width: float, height: float, sec: float, bt: PalaceKit.Batch) -> void:
	var d := (c - a)
	var L := d.length()
	var f := d / L
	var s := f.cross(Vector3.UP).normalized() * width * 0.5
	var up := Vector3.UP * height
	var b1 := a - s
	var b2 := a + s
	var t := a + up
	bt.add(PalaceKit.span(b1, b1 + d, 0.07, 0.07))
	bt.add(PalaceKit.span(b2, b2 + d, 0.07, 0.07))
	bt.add(PalaceKit.span(t, t + d * 0.97, 0.07, 0.07))
	var n := int(L / sec)
	for i in n:
		var p0 := f * (L * i / n)
		var p1 := f * (L * (i + 1) / n)
		bt.add(PalaceKit.span(b1 + p0, b2 + p0, 0.04, 0.04))
		bt.add(PalaceKit.span(b1 + p0, t + p1, 0.04, 0.04))
		bt.add(PalaceKit.span(b2 + p0, t + p1, 0.04, 0.04))
		bt.add(PalaceKit.span(t + p0, b1 + p1, 0.035, 0.035))
		bt.add(PalaceKit.span(t + p0, b2 + p1, 0.035, 0.035))


## Crane A: the tall tower crane east of the frame, tied to it, its jib out west over the frame and the quay, the counter-jib east over the bay with its blocks, the cab, the
## apex and its pendants, the trolley and the hook (the man-basket the climb ends in hangs from it), red lamps on the tips and the apex
func _crane_a() -> void:
	var c := MAST_A
	_mast(c, 1.1, Y0, TOP_A, 2.4, _crane)
	b.box("plate", c.x - 2.2, c.x + 2.2, Y0, Y0 + 1.2, c.z - 2.2, c.z + 2.2, full)      # its footing
	for k: int in [3, 6, 9]:      # ties to the frame
		_crane.add(PalaceKit.span(Vector3(c.x - 1.1, ly(k) - 0.3, c.z - 1.1), Vector3(TX[5], ly(k) - 0.3, TZ[2]), 0.09, 0.09))
		_crane.add(PalaceKit.span(Vector3(c.x - 1.1, ly(k) - 0.3, c.z + 1.1), Vector3(TX[5], ly(k) - 0.3, TZ[3]), 0.09, 0.09))
	jib_a = Node3D.new()
	jib_a.name = "CraneA_Slew"
	root.add_child(jib_a)
	jib_a.position = Vector3(c.x, TOP_A, c.z)
	var jb := PalaceKit.Batch.new(PalaceKit.tube_mesh(6), _mats["crane"])
	var jy := JIB_Y - TOP_A
	var west := Vector3(JIB_W - c.x, jy, 0.0)      # (the slewing frame: x along the jib, west negative)
	_boom(Vector3(-1.0, jy, 0.0), west, 2.0, 2.3, 2.6, jb)
	_boom(Vector3(1.0, jy, 0.0), Vector3(CJIB_E - c.x, jy, 0.0), 2.4, 1.0, 2.6, jb)
	_mast(Vector3(0.0, 0.0, 0.0), 1.1, jy, jy + 9.0, 2.4, jb, 0.08, 0.04)      # the apex
	var apex := Vector3(0.0, jy + 9.0, 0.0)
	var cs := PalaceKit.Batch.new(PalaceKit.tube_mesh(4), PalaceKit.plain(Color(0.05, 0.05, 0.06), 0.5, 0.6), false)
	cs.add(PalaceKit.span(apex, Vector3(-30.0, jy + 2.3, 0.0), 0.03, 0.03))      # the pendants
	cs.add(PalaceKit.span(apex, Vector3(-52.0, jy + 2.3, 0.0), 0.03, 0.03))
	cs.add(PalaceKit.span(apex, Vector3(14.0, jy + 1.0, 0.0), 0.03, 0.03))
	jb.commit(jib_a, "Jib")
	cs.commit(jib_a, "Pendants")
	# the walkway along the jib's bottom chords: the man-basket's riders get off onto it
	var walk := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(absf(west.x) - 1.0, 0.04, 0.8)
	walk.mesh = wm
	walk.material_override = b.mats["plate"]
	walk.position = Vector3((west.x - 1.0) * 0.5, jy - 0.04, 0.0)
	jib_a.add_child(walk)
	# the counterweight blocks, the machinery house
	var cb := PalaceKit.Batch.new(PalaceKit.box_mesh(), _cwt.mat)
	for i in 4:
		cb.add(Transform3D(Basis().scaled(Vector3(1.2, 3.2, 2.6)), Vector3(CJIB_E - c.x - 0.8 - i * 1.25, jy - 1.4, 0.0)))
	cb.commit(jib_a, "Blocks")
	var house := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(4.0, 2.2, 2.2)
	house.mesh = hm
	house.material_override = b.mats["plate"]
	house.position = Vector3(8.5, jy + 1.1, 0.0)
	jib_a.add_child(house)
	# the cab, on the jib's root, its windows lit
	var cab := Node3D.new()
	cab.name = "Cab"
	jib_a.add_child(cab)
	cab.position = Vector3(-1.6, jy - 1.6, 1.6)
	var cm := BoxMesh.new()
	cm.size = Vector3(2.0, 2.4, 1.8)
	var cmi := MeshInstance3D.new()
	cmi.mesh = cm
	cmi.material_override = b.mats["plate"]
	cab.add_child(cmi)
	var gm := BoxMesh.new()
	gm.size = Vector3(1.6, 1.2, 1.82)
	var gmi := MeshInstance3D.new()
	gmi.mesh = gm
	gmi.material_override = b.mats["window"]
	gmi.position = Vector3(-0.25, 0.35, 0.0)
	cab.add_child(gmi)
	# hazard stripes at the jib's end, red lamps on the tips and the apex
	var tip := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(1.6, 2.4, 2.1)
	tip.mesh = tm
	tip.material_override = b.mats["stripes"]
	tip.position = west + Vector3(0.8, 1.1, 0.0)
	jib_a.add_child(tip)
	for p: Vector3 in [west + Vector3(0.0, 2.5, 0.0), Vector3(CJIB_E - c.x, jy + 1.2, 0.0), apex + Vector3(0.0, 0.3, 0.0)]:
		beacons.append(_beacon(jib_a, p))
	# the trolley and the hook (the level moves them; the cable is stretched between)
	trolley_a = Node3D.new()
	trolley_a.name = "TrolleyA"
	jib_a.add_child(trolley_a)
	trolley_a.position = Vector3((BASKET[0] + BASKET[1]) * 0.5 - c.x, jy - 0.3, 0.0)
	var trm := BoxMesh.new()
	trm.size = Vector3(1.4, 0.5, 2.0)
	var tri := MeshInstance3D.new()
	tri.mesh = trm
	tri.material_override = b.mats["plate"]
	trolley_a.add_child(tri)
	basket = _basket()
	basket_cable = _cable_node("BasketCable")


func _beacon(parent: Node3D, at: Vector3) -> Node3D:
	var m := MeshInstance3D.new()
	m.mesh = PalaceKit.ball_mesh(0.22)
	m.material_override = b.mats["redlamp"]
	m.position = at
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	return m


func _cable_node(nm: String) -> MeshInstance3D:
	var c := MeshInstance3D.new()
	c.name = nm
	c.mesh = PalaceKit.tube_mesh(4)
	c.material_override = PalaceKit.plain(Color(0.03, 0.03, 0.035), 0.5, 0.6)
	c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	c.top_level = true
	root.add_child(c)
	return c


## Stretch a cable between two world points
static func stretch(c: MeshInstance3D, a: Vector3, d: Vector3, r: float = 0.025) -> void:
	c.global_transform = PalaceKit.span(a, d, r, r)


## The man-basket: a steel cage with a plate floor and rails, four slings up to the hook block
func _basket() -> Node3D:
	var n := Node3D.new()
	n.name = "ManBasket"
	root.add_child(n)
	var w: float = BASKET[1] - BASKET[0]
	var d: float = BASKET[3] - BASKET[2]
	n.position = Vector3((BASKET[0] + BASKET[1]) * 0.5, ly(NF), (BASKET[2] + BASKET[3]) * 0.5)
	var fl := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(w, 0.1, d)
	fl.mesh = fm
	fl.material_override = b.mats["plate"]
	fl.position = Vector3(0.0, -0.05, 0.0)
	n.add_child(fl)
	var bt := PalaceKit.Batch.new(PalaceKit.tube_mesh(6), b.mats["stripes"], false)
	var hw := w * 0.5
	var hd := d * 0.5
	var cs := [Vector3(-hw, 0, -hd), Vector3(hw, 0, -hd), Vector3(hw, 0, hd), Vector3(-hw, 0, hd)]
	for i in 4:
		var a: Vector3 = cs[i]
		var e: Vector3 = cs[(i + 1) % 4]
		bt.add(PalaceKit.span(a, a + Vector3(0, 1.1, 0), 0.035, 0.035))
		bt.add(PalaceKit.span(a + Vector3(0, 1.1, 0), e + Vector3(0, 1.1, 0), 0.035, 0.035))
		bt.add(PalaceKit.span(a + Vector3(0, 0.55, 0), e + Vector3(0, 0.55, 0), 0.025, 0.025))
		bt.add(PalaceKit.span(a + Vector3(0, 1.1, 0), Vector3(0, 3.4, 0), 0.012, 0.012))      # its slings
	bt.commit(n, "Cage")
	var hook := MeshInstance3D.new()
	var hk := BoxMesh.new()
	hk.size = Vector3(0.5, 0.7, 0.35)
	hook.mesh = hk
	hook.material_override = b.mats["stripes"]
	hook.position = Vector3(0.0, 3.7, 0.0)
	n.add_child(hook)
	return n


## Crane B: a smaller tower crane at the lot's south-east corner, its jib west along the south face; its hook carries the beam bundle the climb rides from floor 3 to floor 6
func _crane_b() -> void:
	var c := MAST_B
	_mast(c, 0.8, Y0, TOP_B, 2.0, _crane, 0.07, 0.04)
	b.box("plate", c.x - 1.6, c.x + 1.6, Y0, Y0 + 1.0, c.z - 1.6, c.z + 1.6, full)
	var jy := JIB_B_Y
	var a := Vector3(c.x - 0.8, jy, c.z)
	_boom(a, Vector3(158.0, jy, c.z), 1.4, 1.5, 2.2, _crane)
	_boom(Vector3(c.x + 0.8, jy, c.z), Vector3(c.x + 9.0, jy, c.z), 1.6, 0.8, 2.2, _crane)
	_mast(Vector3(c.x, 0.0, c.z), 0.8, TOP_B, jy + 6.0, 2.0, _crane, 0.07, 0.035)
	for i in 3:
		_cwt.add(Transform3D(Basis().scaled(Vector3(1.0, 2.4, 1.8)), Vector3(c.x + 8.4 - i * 1.05, jy - 1.1, c.z)))
	beacons.append(_beacon(root, Vector3(158.0, jy + 1.6, c.z)))
	beacons.append(_beacon(root, Vector3(c.x, jy + 6.3, c.z)))
	# the beam bundle: six beams strapped side by side, a spreader bar, four slings, the hook (the level moves it)
	pallet = Node3D.new()
	pallet.name = "BeamBundle"
	root.add_child(pallet)
	var w: float = PALLET[1] - PALLET[0]
	var d: float = PALLET[3] - PALLET[2]
	pallet.position = Vector3((PALLET[0] + PALLET[1]) * 0.5, PALLET_LO, (PALLET[2] + PALLET[3]) * 0.5)
	var bt := PalaceKit.Batch.new(PalaceKit.ibeam_mesh(), _mats["steel"])
	for i in 6:
		var z := -d * 0.5 + d * (i + 0.5) / 6.0
		bt.add(PalaceKit.span(Vector3(-w * 0.5, -0.18, z), Vector3(w * 0.5, -0.18, z), 1.0, 1.0))
	bt.commit(pallet, "Beams")
	var st := PalaceKit.Batch.new(PalaceKit.tube_mesh(4), b.mats["stripes"], false)
	for sx: float in [-w * 0.35, w * 0.35]:
		st.add(PalaceKit.span(Vector3(sx, 0.0, -d * 0.5 - 0.02), Vector3(sx, 0.0, d * 0.5 + 0.02), 0.03, 0.03))      # the straps
		st.add(PalaceKit.span(Vector3(sx, 0.02, 0.0), Vector3(0.0, 3.0, 0.0), 0.014, 0.014))      # the slings
	st.add(PalaceKit.span(Vector3(-0.8, 3.0, 0.0), Vector3(0.8, 3.0, 0.0), 0.05, 0.05))
	st.commit(pallet, "Rigging")
	var hk := MeshInstance3D.new()
	hk.mesh = PalaceKit.box_mesh()
	hk.material_override = b.mats["stripes"]
	hk.scale = Vector3(0.4, 0.55, 0.3)
	hk.position = Vector3(0.0, 3.35, 0.0)
	pallet.add_child(hk)
	hook_b = hk
	pallet_cable = _cable_node("PalletCable")


## The hoist on the north face: its mast tied to the frame and the cage that rides it (the level moves the cage)
func _hoist() -> void:
	var cx: float = (HOIST[0] + HOIST[1]) * 0.5
	_mast(Vector3(cx, 0.0, HOIST[3] + 0.6), 0.45, Y0, ly(NF) + 3.0, 1.5, _crane, 0.06, 0.03)
	hoist_cage = Node3D.new()
	hoist_cage.name = "HoistCage"
	root.add_child(hoist_cage)
	var w: float = HOIST[1] - HOIST[0]
	var d: float = HOIST[3] - HOIST[2]
	hoist_cage.position = Vector3(cx, ly(6), (HOIST[2] + HOIST[3]) * 0.5)
	var fm := BoxMesh.new()
	fm.size = Vector3(w, 0.12, d)
	var fl := MeshInstance3D.new()
	fl.mesh = fm
	fl.material_override = b.mats["plate"]
	fl.position = Vector3(0.0, -0.06, 0.0)
	hoist_cage.add_child(fl)
	var rf := MeshInstance3D.new()
	rf.mesh = fm
	rf.material_override = b.mats["plate"]
	rf.position = Vector3(0.0, 2.45, 0.0)
	hoist_cage.add_child(rf)
	var bt := PalaceKit.Batch.new(PalaceKit.tube_mesh(6), b.mats["galv"], false)
	var hw := w * 0.5
	var hd := d * 0.5
	for p: Vector2 in [Vector2(-hw, -hd), Vector2(hw, -hd), Vector2(hw, hd), Vector2(-hw, hd)]:
		bt.add(PalaceKit.span(Vector3(p.x, 0.0, p.y), Vector3(p.x, 2.4, p.y), 0.04, 0.04))
	var gy := 0.15
	while gy < 2.4:      # bar walls on the three sides that are not the door
		bt.add(PalaceKit.span(Vector3(-hw, gy, hd), Vector3(hw, gy, hd), 0.012, 0.012))
		bt.add(PalaceKit.span(Vector3(-hw, gy, -hd), Vector3(-hw, gy, hd), 0.012, 0.012))
		bt.add(PalaceKit.span(Vector3(hw, gy, -hd), Vector3(hw, gy, hd), 0.012, 0.012))
		gy += 0.15
	bt.commit(hoist_cage, "Cage")
	var lamp := MeshInstance3D.new()
	lamp.mesh = PalaceKit.ball_mesh(0.12)
	lamp.material_override = b.mats["amber"]
	lamp.position = Vector3(hw - 0.2, 2.6, -hd + 0.2)
	hoist_cage.add_child(lamp)


# ---------------------------------------------------------------------------------------------- light

## Festoon strings of bulbs along the floors' edges (the site's own light: cold blue-white, the city's), sagging between the columns
func _bulbs() -> void:
	for k in range(1, NF + 1):
		var y := ly(k) + (2.4 if k == NF else 2.6)
		var runs := [[Vector3(TX[0], y, TZ[0]), Vector3(TX[5], y, TZ[0])], [Vector3(TX[0], y, TZ[5]), Vector3(TX[5], y, TZ[5])], [Vector3(TX[0], y, TZ[0]), Vector3(TX[0], y, TZ[5])], [Vector3(TX[5], y, TZ[0]), Vector3(TX[5], y, TZ[5])]]
		for r: Array in runs:
			if (k % 2 == 1) and rng.randf() < 0.35:      # (some floors' strings are not up on every side)
				continue
			var a: Vector3 = r[0]
			var c: Vector3 = r[1]
			var L := a.distance_to(c)
			var spans := int(L / 6.0)
			for s in spans:
				var p0 := a.lerp(c, float(s) / spans)
				var p1 := a.lerp(c, float(s + 1) / spans)
				var prev := p0
				for i in range(1, 9):
					var u := i / 8.0
					var p := p0.lerp(p1, u) + Vector3(0, -0.45 * 4.0 * u * (1.0 - u), 0)
					_cable.add(PalaceKit.span(prev, p, 0.008, 0.008))
					prev = p
					if i % 2 == 0 and i < 8:
						_bulb.add(Transform3D(Basis(), p + Vector3(0, -0.06, 0)))


## Floodlight towers on the lot: a lamp head on a lattice mast; in the level they are real lights
func _floods() -> void:
	var spots := [[Vector3(136.0, Y0, 180.0), Vector3(150.0, Y0, 200.0)], [Vector3(136.0, Y0, 222.0), Vector3(148.0, Y0 + 4.0, 205.0)], [Vector3(189.0, Y0, 222.0), Vector3(176.0, ly(6), 205.0)]]
	for s: Array in spots:
		var p: Vector3 = s[0]
		var aim: Vector3 = s[1]
		var top := p + Vector3(0, 9.0, 0)
		_mast(p, 0.25, Y0, top.y, 1.5, _crane, 0.05, 0.025)
		var head := MeshInstance3D.new()
		var hm := BoxMesh.new()
		hm.size = Vector3(1.4, 0.8, 0.25)
		head.mesh = hm
		head.material_override = b.mats["flood"]
		root.add_child(head)
		head.position = top + Vector3(0, 0.4, 0)
		head.look_at(aim, Vector3.UP)
		if full:
			var l := SpotLight3D.new()
			l.light_color = Color(0.88, 0.94, 1.0)
			l.light_energy = 6.0
			l.spot_range = 46.0
			l.spot_angle = 38.0
			l.spot_attenuation = 1.1
			l.shadow_enabled = false
			l.distance_fade_enabled = true
			l.distance_fade_begin = 120.0
			l.distance_fade_length = 30.0
			root.add_child(l)
			l.position = top + Vector3(0, 0.3, 0)
			l.look_at(aim, Vector3.UP)
			floods.append(l)


# ---------------------------------------------------------------------------------------------- the yard and the floors' clutter (the level only)

func _props() -> void:
	# the site office: two cabins stacked in the yard's north-west corner, lit windows
	b.box("cabin", 133.0, 142.6, Y0, Y0 + 2.7, 219.0, 222.4)
	b.box("cabin", 133.0, 142.6, Y0 + 2.75, Y0 + 5.45, 219.0, 222.4)
	for y: float in [Y0 + 1.1, Y0 + 3.85]:
		for x: float in [134.2, 137.4, 140.6]:
			b.box("window", x, x + 1.6, y, y + 0.9, 218.96, 219.0, false)
	b.box("cabin_dark", 141.6, 142.4, Y0, Y0 + 2.1, 218.9, 219.0, false)
	# the gate hut by the gate, the foreman's
	b.box("cabin", 133.0, 136.0, Y0, Y0 + 2.6, 204.6, 207.0)
	b.box("window", 135.98, 136.02, Y0 + 1.2, Y0 + 2.0, 205.2, 206.4, false)
	# a skip, pallets of bricks, cement bags, rebar bundles, toilets
	b.box("skip", 134.0, 139.6, Y0, Y0 + 1.6, 178.6, 181.4)
	for q: Vector3 in [Vector3(139.0, Y0, 190.0), Vector3(141.2, Y0, 190.0), Vector3(139.0, Y0, 210.6)]:
		_brick_pallet(q)
	for q: Vector3 in [Vector3(152.0, ly(6), 194.0), Vector3(170.0, ly(6), 214.0), Vector3(150.4, ly(6), 208.0), Vector3(175.2, ly(6), 199.0), Vector3(156.0, ly(NF), 188.0), Vector3(171.0, ly(NF), 190.0), Vector3(152.0, ly(NF), 213.0)]:
		_brick_pallet(q)
	for q: Vector3 in [Vector3(162.0, ly(6), 188.5), Vector3(150.0, ly(6), 199.5), Vector3(174.0, ly(6), 208.0), Vector3(162.0, ly(NF), 214.0), Vector3(150.0, ly(NF), 198.0)]:
		_rebar_bundle(q)
	b.box("toilet", 175.8, 177.2, ly(6), ly(6) + 2.3, 214.8, 216.2)
	b.box("toilet", 133.4, 134.8, Y0, Y0 + 2.3, 223.0, 224.4)
	b.box("bag", 168.0, 170.0, ly(6), ly(6) + 0.75, 186.0, 187.4)
	b.box("bag", 155.0, 157.0, ly(NF), ly(NF) + 0.75, 207.6, 209.0)
	b.box("rubber", 137.18, 137.82, Y0, Y0 + 0.9, 195.68, 196.32)      # a drum (the level lights a fire in it)


func _brick_pallet(q: Vector3) -> void:
	b.box("pallet", q.x - 0.6, q.x + 0.6, q.y, q.y + 0.14, q.z - 0.5, q.z + 0.5)
	b.box("brick", q.x - 0.55, q.x + 0.55, q.y + 0.14, q.y + 1.0, q.z - 0.45, q.z + 0.45)


func _rebar_bundle(q: Vector3) -> void:
	for i in 14:
		var a := Vector3(q.x - 2.0, q.y + 0.05 + (i % 3) * 0.03, q.z - 0.15 + (i % 5) * 0.06)
		_rebar.add(PalaceKit.span(a, a + Vector3(4.0, 0.0, 0.0), 0.014, 0.014))
	if full:
		world.add({"kind": "box", "cx": q.x, "cz": q.z, "hx": 2.0, "hz": 0.2, "bottom": q.y, "top": q.y + 0.18, "tag": "rebar", "no_cam": true})
	for x: float in [q.x - 1.4, q.x + 1.4]:      # its timber bearers
		b.box("pallet", x - 0.06, x + 0.06, q.y, q.y + 0.05, q.z - 0.3, q.z + 0.3, false)


## What the climb walks on that is not drawn as a box (the walked beam on floor 3, the edge rails of the two slabs), and the swing's two tubes
func _route_solids() -> void:
	var y3 := ly(3) - 0.1
	for seg: Vector2 in [Vector2(TX[2] - 0.2, TX[3]), Vector2(TX[4], TX[5] + 0.2)]:
		world.add({"kind": "box", "cx": (seg.x + seg.y) * 0.5, "cz": BEAM_Z, "hx": (seg.y - seg.x) * 0.5, "hz": 0.1, "bottom": y3 - 0.36, "top": y3, "tag": "steel", "no_cam": true})
	# the swing: two scaffold tubes hung across the gap from floor 4's beams, at hand height over the beam
	for px in POLE_X:
		world.poles.append({"x": px, "y": ly(3) + 2.25, "z": BEAM_Z, "axis": "z", "half": 1.3, "r": 0.04})
		_tube.add(PalaceKit.span(Vector3(px, ly(3) + 2.25, BEAM_Z - 1.4), Vector3(px, ly(3) + 2.25, BEAM_Z + 1.4), 0.04, 0.04))
		for dz: float in [-1.35, 1.35]:
			_tube.add(PalaceKit.span(Vector3(px, ly(3) + 2.25, BEAM_Z + dz), Vector3(px, ly(4) - 0.3, BEAM_Z + dz), 0.024, 0.024))
	# the slabs' edges: tube rails all round (the fights' edges), leaving the hoist's landing, the beam bundle's on floor 6 and the man-basket's on the top
	for k: int in [6, NF]:
		var y := ly(k)
		var X0 := TX[0] - 0.25
		var X1 := TX[5] + 0.25
		var Z0 := TZ[0] - 0.25
		var Z1 := TZ[5] + 0.25
		if k == 6:
			_rail(Vector3(X0, y, Z0), Vector3(PALLET[0], y, Z0))
			_rail(Vector3(PALLET[1], y, Z0), Vector3(X1, y, Z0))
		else:
			_rail(Vector3(X0, y, Z0), Vector3(X1, y, Z0))
		_rail(Vector3(X0, y, Z0), Vector3(X0, y, Z1))
		_rail(Vector3(X0, y, Z1), Vector3(HOIST[0], y, Z1))
		_rail(Vector3(HOIST[1], y, Z1), Vector3(X1, y, Z1))
		if k == 6:
			_rail(Vector3(X1, y, Z0), Vector3(X1, y, Z1))
		else:
			_rail(Vector3(X1, y, Z0), Vector3(X1, y, BASKET[2]))
			_rail(Vector3(X1, y, BASKET[3]), Vector3(X1, y, Z1))
