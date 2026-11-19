class_name SkyCourse
extends Node3D
## The Overcurrent: an illegal one-way run down the inside of the derelict SkySphere (user, 2026-11-18: "an underground illegal race",
## Hydro Thunder mixed with Burnout 3, one long run, branching routes, set pieces). The main road and its branches are each sampled every
## STEP metres into road frames (x left, y road up, z forward) with their own widths, walls, gaps and magnetic stretches. Cars drive on it
## freely (race_car.gd): the course answers where the deck and walls are and how far down the run a point counts as; it also draws the deck
## and keeps the AI's line and the places of the boost icons, item boxes, crushers, the collapsing gantry and the column (sky_set_pieces.gd).
## Built in stretches: stretch one (the Crown down to the Ribs) is in; the finish line closes it until the rest is built.
## History: 2026-11-18 a closed sky circuit (loops, a shortcut) replaced a track the cars were pinned to; the same day it became this run.

const STEP := 1.6
const HALF_WIDTH := 10.8         # (was 9.3: the user found no room to turn, 2026-11-18)
const BRANCH_WIDTH := 4.8        # a branch's half width: one craft and a bit
const WALL_H := 1.2
const MAIN := 0
const START := Vector3(0, 300, -560)
const G_AI := 24.0            # RaceCar.G: the AI's corner speeds come from the same grip sums the craft really has
const MU_AI := 1.72
const DF_AI := 0.0052
const BRAKE_AI := 36.0


## One road: samples with their frames and what is there.
class Path:
	var closed := false
	var pos := PackedVector3Array()
	var ups := PackedVector3Array()     # an explicit road up (loops, roll); zero = level, then banked
	var bank := PackedFloat32Array()    # + tips the road's left side down (a left turn)
	var auto := PackedByteArray()       # bank from the curvature
	var frames: Array[Transform3D] = []
	var metres := PackedFloat32Array()
	var wl := PackedFloat32Array()      # half width to the left (+x)
	var wr := PackedFloat32Array()      # half width to the right (-x)
	var wall_l := PackedByteArray()
	var wall_r := PackedByteArray()
	var deck := PackedByteArray()       # 0: a gap, nothing to drive on
	var mag := PackedByteArray()        # 1: the deck holds a fast craft to it (loops)
	var sector := PackedFloat32Array()  # the look of the deck there (sky_road.gdshader): 0 plate, 1 catwalk grating, 2 painted hazard, 3 tunnel
	var curve := PackedFloat32Array()   # signed curvature in the road's own plane, + left, 1/m
	var line := PackedFloat32Array()    # the AI's lateral target, + left
	var pace := PackedFloat32Array()    # the AI's speed limit, m/s
	var main_s := PackedFloat32Array()  # how far down the run (main metres) a point here counts as
	var length := 0.0

	func size() -> int:
		return pos.size()

	func wrap(i: int) -> int:
		var n := pos.size()
		if closed:
			return posmod(i, n)
		return clampi(i, 0, n - 1)


## A branch off the main road: it leaves one edge at split_i and comes back alongside an edge at merge_i, narrowing until it has merged.
class Branch:
	var title := ""
	var path := 1
	var split_i := 0
	var merge_i := 0
	var side := -1.0          # which edge of the main road it leaves and rejoins: +1 left, -1 right
	var taper_n := 0          # its samples riding the main road's edge at the end
	var risky := true         # a rival takes a risky branch now and then, a safe one often


## A boost pad, an item box row, a stack of props, a boost icon, a crusher: a place on a road.
class Pad:
	var path := MAIN
	var i := 0
	var span := 5
	var u := 0.0
	var hw := 2.6


class PropSpot:
	var path := MAIN
	var i := 0
	var u := 0.0
	var count := 6
	var spread := 3.0


class Icon:
	var path := MAIN
	var i := 0
	var u := 0.0
	var red := false


class Crusher:
	var i := 0
	var u0 := 0.0             # the lane it slams: from u0 to u1 across
	var u1 := 0.0
	var phase := 0.0


var paths: Array[Path] = []
var branches: Array[Branch] = []
var length := 0.0                  # the main road
var lowest := 0.0                  # the deck's lowest point (anything well under it has fallen)
var finish_s := 0.0                # main metres of the finish line
var gate_s := PackedFloat32Array() # main metres of the named arches
var gate_names: Array[String] = []
var checkpoints := PackedFloat32Array()
var pads: Array[Pad] = []
var props: Array[PropSpot] = []
var icons: Array[Icon] = []
var crushers: Array[Crusher] = []
var gantries := PackedInt32Array() # main samples where a gantry spans the road (it comes down when the first craft nears it)
var gantry_style := PackedInt32Array()   # 0 a crane truss, 1 the reactor's shield plates
var wreckers: Array[Crusher] = []  # wrecking balls: i, and phase (u0/u1 unused)
var columns := PackedInt32Array()  # main samples where a column stands in the middle of a widened road
var item_rows: Array[Vector2i] = []   # (path, sample) of each row of item boxes across the deck (sky_items.gd)
# query answers (filled by the calls below, read straight after: no allocation in the hot loops)
var q_i := 0
var q_local := Vector3.ZERO
var q_path := MAIN

# builder state
var _b: Path
var _tip := Vector3.ZERO
var _yaw := 0.0
var _wl := HALF_WIDTH
var _wr := HALF_WIDTH
var _wall_l := true
var _wall_r := true
var _deck := true
var _mag := false
var _auto := false
var _sector := 0.0
var _gate_i: Array[int] = []
var _check_i: Array[int] = []
var _finish_i := 0
var _recipes: Dictionary = {}     # branch title -> Callable that lays its middle


func build() -> void:
	name = "OvercurrentRun"
	paths.append(Path.new())
	_build_main()
	_finish(paths[MAIN])
	var m := paths[MAIN]
	length = m.length
	finish_s = m.metres[_finish_i]
	for i in _gate_i.size():
		gate_s.append(m.metres[_gate_i[i]])
	for i in _check_i:
		checkpoints.append(m.metres[i])
	m.main_s = m.metres.duplicate()
	for b: Branch in branches:
		_build_branch(b)
		var p := paths[b.path]
		_finish(p)
		p.main_s.resize(p.size())
		var a := m.metres[b.split_i]
		var e := m.metres[b.merge_i] + (p.metres[p.size() - 1] - p.metres[p.size() - 1 - b.taper_n])
		for i in p.size():
			p.main_s[i] = lerpf(a, e, p.metres[i] / p.length)
	lowest = INF
	for p: Path in paths:
		_lines(p)
		for o: Vector3 in p.pos:
			lowest = minf(lowest, o.y)
	for k in paths.size():
		_build_deck(paths[k], k)
	for p: Path in paths:
		_build_hoops(p)
	_build_pads()


# ------------------------------------------------------------------ layout ----

## Stretch one: off the start gantry high in the Crown, the Launch dive, a loop, the Omega and its Catwalk, the Crusher gauntlet, the
## collapsing Gantry, the Column, and the Ribs switchbacks down to the (for now) finish over a broken span.
func _build_main() -> void:
	_b = paths[MAIN]
	_tip = START
	_yaw = -PI * 0.5      # heading -x: the sphere's axis is on the left, so left turns follow the shell round
	_add(_tip, 0.0)
	_sector = 2.0
	_run(75.0)            # the grid (the line at 40 m)
	_item_row()
	_sector = 0.0
	_pad(0.0, 3.4)
	# THE LAUNCH: straight off the gantry and down a long steep dive
	_gate("THE  LAUNCH")
	_arc(480.0, 11.0, -20.0, 0.04)
	_icon(0.0, false)
	_arc(480.0, 11.0, -20.0, 0.04)
	_icon(-5.0, false)
	_icon(5.0, false)
	_arc(300.0, 35.0, -4.0, 0.14)
	_run(30.0)
	# a loop, with a booster before it
	_pad(0.0, 3.2)
	_mag = true
	_run(12.0)
	_gate("LOOP")
	_loop(42.0, 30.0)
	_run(12.0)
	_mag = false
	_run(20.0)
	_arc(300.0, 60.0, 0.0, 0.12)
	_item_row()
	_run(20.0)
	# THE OMEGA: the road swings in over the void and back; the Catwalk goes straight on along the shell, narrow, over a broken span
	_split("THE  CATWALK", -1.0, true, _catwalk)
	_arc(40.0, 90.0)
	_run(30.0)
	_width(12.4)
	_arc(34.0, -100.0, 0.0, 0.15)
	_props(1, 7)
	_arc(34.0, -80.0, 0.0, 0.15)
	_width(HALF_WIDTH)
	_run(30.0)
	_arc(40.0, 90.0)
	_merge("THE  CATWALK")
	_run(40.0)
	_check()
	# THE CRUSHERS: a walled straight under hydraulic presses, one lane at a time
	_sector = 2.0
	_gate("THE  CRUSHERS")
	_run(24.0)
	for k in 5:
		_crusher(1.0 if k % 2 == 0 else -1.0, float(k) * 0.42)
		if k == 2:
			_icon(0.0, true)
		_run(28.0)
	_sector = 0.0
	_run(10.0)
	_item_row()
	_arc(300.0, 45.0, -4.0, 0.12)
	# a chicane, then a long sweeper down
	_width(9.4)
	_arc(70.0, 30.0)
	_props(-1, 4, 0.55)
	_arc(70.0, -60.0)
	_props(1, 4, 0.55)
	_arc(70.0, 30.0)
	_width(HALF_WIDTH)
	_arc(300.0, 30.0, -6.0, 0.12)
	# THE GANTRY: a rusted crane gantry over the road comes down as the field arrives
	_run(40.0)
	_gate("THE  GANTRY")
	_run(30.0)
	gantries.append(_b.size() - 1)
	gantry_style.append(0)
	_arc(500.0, 15.0)
	_icon(-6.0, false)
	_icon(6.0, false)
	# THE COLUMN: the road opens round a support column; pick a side
	_width(18.0)
	_run(36.0)
	columns.append(_b.size() - 1)
	_run(44.0)
	_width(HALF_WIDTH)
	_arc(260.0, 60.0, -6.0, 0.14)
	_check()
	# THE RIBS: switchbacks down between the shell's ribs; the second leg runs under the first
	_sector = 3.0
	_width(12.4)
	_arc(36.0, 100.0, -6.0, 0.16)
	_props(-1, 6)
	_arc(36.0, 80.0, -6.0, 0.16)
	_width(HALF_WIDTH)
	_run(110.0, -6.0)
	_item_row()
	_width(12.4)
	_arc(36.0, -100.0, -6.0, 0.16)
	_props(1, 6)
	_arc(36.0, -80.0, -6.0, 0.16)
	_width(HALF_WIDTH)
	_sector = 0.0
	_arc(400.0, 30.0, 0.0, 0.08)
	_icon(0.0, true)
	# the broken span to the finish (the run goes on from here once its next stretch is built)
	_walls(false, false)
	_ramp(30.0, 0.0, 0.12)
	_gate("THE  BREAK")
	_deck = false
	_run(22.0, -1.5, 3)
	_deck = true
	_walls(true, true)
	_width(13.0)
	_ramp(28.0, -0.06, -0.06)
	_ramp(30.0, -0.06, 0.0)
	_width(HALF_WIDTH)
	_run(30.0)
	_check()
	_stretch_two()
	_stretch_three()


## Stretch two, the Core: a long span out over the void to the dead reactor, a magnetic banked spiral down round it, the barrel roll, the
## Wreckers (wrecking balls swinging across the road), the reactor's shielding coming down, and the Duct, a branch across an S.
func _stretch_two() -> void:
	const CORE := Vector3(12.0, 0.0, 56.0)      # the reactor's axis (sky_venue.gd)
	const SPIRAL_R := 128.0
	_sector = 0.0
	_item_row()
	# THE SPAN: aim along the line that grazes the spiral's circle with the core on the left, and run out to it
	var to_core := Vector2(CORE.x - _tip.x, CORE.z - _tip.z)
	var d := to_core.length()
	var yaw_core := atan2(to_core.x, to_core.y)
	var yaw_t := yaw_core - asin(clampf(SPIRAL_R / d, 0.0, 0.99))
	var entry := _tip + _fwd(yaw_t) * sqrt(maxf(1.0, d * d - SPIRAL_R * SPIRAL_R))
	entry.y = 205.0
	_gate("THE  SPAN")
	_width(9.6)
	_join(entry, _fwd(yaw_t), 0.42, false)
	_icon(0.0, true)
	_walls(true, true)
	_width(HALF_WIDTH)
	# THE SPIRAL: one and a half turns down round the core, steeply banked and magnetic: glued on, flat out
	_sector = 3.0
	_pad(0.0, 3.4)
	_mag = true
	_width(12.6)
	_gate("THE  SPIRAL")
	_arc(SPIRAL_R, 200.0, -36.0, 0.42)
	_icon(-5.0, false)
	_icon(5.0, false)
	_arc(SPIRAL_R, 200.0, -36.0, 0.42)
	_item_row()
	_arc(SPIRAL_R, 140.0, -20.0, 0.42)
	_mag = false
	_width(HALF_WIDTH)
	_sector = 0.0
	_run(50.0)
	# out under the first stretch, round the sphere's axis, set piece by set piece (waypoints on a ring keep it inside the shell)
	_ring(150.0, 330.0, 104.0)
	_check()
	# the barrel roll
	_mag = true
	_width(7.8)
	_run(10.0)
	_gate("BARREL  ROLL")
	_roll(84.0, 1.0, 0.0)
	_run(10.0)
	_width(HALF_WIDTH)
	_mag = false
	_ring(178.0, 380.0, 96.0)
	# THE WRECKERS: wrecking balls swinging across the road from a line of gantries
	_sector = 2.0
	_gate("THE  WRECKERS")
	_run(26.0)
	for k in 4:
		_wrecker(float(k) * 0.3)
		_run(32.0)
	_sector = 0.0
	_icon(0.0, true)
	_ring(218.0, 390.0, 86.0)
	_item_row()
	# THE SHIELDING: the reactor's shield plates, hung on a gantry over the road, come down as the field arrives
	_run(40.0)
	_gate("THE  SHIELDING")
	_run(30.0)
	gantries.append(_b.size() - 1)
	gantry_style.append(1)
	_run(140.0, -8.0)
	_ring(268.0, 400.0, 72.0)
	# THE DUCT: the road snakes right then left; the Duct goes straight across, magnetic, through a broken pipe
	_split("THE  DUCT", 1.0, false, _duct)
	_arc(40.0, -90.0)
	_run(30.0)
	_width(12.4)
	_arc(34.0, 100.0, -3.0, 0.15)
	_props(-1, 7)
	_arc(34.0, 80.0, -3.0, 0.15)
	_width(HALF_WIDTH)
	_run(30.0)
	_arc(40.0, -90.0)
	_merge("THE  DUCT")
	_run(40.0)
	_check()


## Stretch three, the Sump: the Plunge down into the lower hull, a burning ring along the shell, the Foundry presses, the Column again,
## the Deep (a level lower: the Pit Loop, the Scrapheap branch, the Scaffold coming down, a chicane), and the Last Drop over the pit into
## the Sump, where it finishes.
func _stretch_three() -> void:
	# THE PLUNGE
	_sector = 0.0
	_gate("THE  PLUNGE")
	_pad(0.0, 3.2)
	_ring(335.0, 470.0, -60.0)
	_icon(0.0, false)
	_ring(380.0, 520.0, -150.0)
	_icon(-5.0, false)
	_icon(5.0, false)
	_item_row()
	# the furnace ring: along the lower hull, fires below; a chicane
	_sector = 3.0
	_width(9.4)
	_arc(70.0, -30.0)
	_props(1, 4, 0.55)
	_arc(70.0, 60.0)
	_props(-1, 4, 0.55)
	_arc(70.0, -30.0)
	_width(HALF_WIDTH)
	_ring(422.0, 540.0, -190.0)
	_check()
	# THE FOUNDRY: presses again, faster
	_sector = 2.0
	_gate("THE  FOUNDRY")
	_run(24.0)
	for k in 6:
		_crusher(1.0 if k % 2 == 0 else -1.0, float(k) * 0.33)
		_run(24.0)
	_sector = 0.0
	_item_row()
	_ring(472.0, 540.0, -205.0)
	# the Column, once more
	_width(18.0)
	_run(36.0)
	columns.append(_b.size() - 1)
	_run(44.0)
	_width(HALF_WIDTH)
	_ring(512.0, 520.0, -215.0)
	_check()
	# THE DEEP (2026-11-19, the user wanted the run longer): most of another lap round the bottom of the hull, a level down
	_sector = 3.0
	_ring(556.0, 500.0, -255.0)
	_icon(0.0, false)
	# the Pit Loop, with a booster before it
	_pad(0.0, 3.2)
	_mag = true
	_run(12.0)
	_gate("THE  PIT  LOOP")
	_loop(40.0, 28.0)
	_run(12.0)
	_mag = false
	_sector = 0.0
	_ring(606.0, 490.0, -272.0)
	_item_row()
	# THE SCRAPHEAP: the road swings in and back; the branch goes straight over a heap of scrap, a gap in it
	_run(20.0)
	_split("THE  SCRAPHEAP", -1.0, true, _scrapheap)
	_arc(40.0, 90.0)
	_run(30.0)
	_width(12.4)
	_arc(34.0, -100.0, 0.0, 0.15)
	_props(1, 7)
	_arc(34.0, -80.0, 0.0, 0.15)
	_width(HALF_WIDTH)
	_run(30.0)
	_arc(40.0, 90.0)
	_merge("THE  SCRAPHEAP")
	_run(40.0)
	_ring(668.0, 480.0, -295.0)
	# THE SCAFFOLD: a crane's scaffold over the road comes down as the field arrives
	_run(40.0)
	_gate("THE  SCAFFOLD")
	_run(30.0)
	gantries.append(_b.size() - 1)
	gantry_style.append(0)
	_run(120.0, -6.0)
	_icon(-6.0, false)
	_icon(6.0, false)
	_ring(712.0, 470.0, -318.0)
	_check()
	# a narrow chicane, barrels on the apexes
	_sector = 2.0
	_width(9.0)
	_arc(60.0, 30.0)
	_props(-1, 4, 0.55)
	_arc(60.0, -60.0)
	_props(1, 4, 0.55)
	_arc(60.0, 30.0)
	_width(HALF_WIDTH)
	_sector = 0.0
	_ring(760.0, 460.0, -332.0)
	_icon(0.0, true)
	# THE LAST DROP: off a ledge, over the pit, down onto the Sump's floor and the finish
	_walls(false, false)
	_pad(0.0, 3.0)
	_ramp(34.0, 0.0, 0.14)
	_gate("THE  LAST  DROP")
	_deck = false
	_run(34.0, -6.0, 3)
	_deck = true
	_walls(true, true)
	_width(16.0)
	_ramp(30.0, -0.12, -0.12)
	_ramp(40.0, -0.12, 0.0)
	_run(40.0)
	_width(HALF_WIDTH + 2.0)
	_sector = 2.0
	_run(30.0)
	_finish_i = _b.size() - 1
	_gate("FINISH")
	_run(160.0)


## On to a point on a ring round the sphere's axis, `degrees` round it (0 = +z, as yaw), arriving running round it with the axis on the left.
func _ring(degrees: float, radius: float, y: float) -> void:
	var a := deg_to_rad(degrees)
	var at := Vector3(radius * sin(a), y, radius * cos(a))
	_join(at, _fwd(a + PI * 0.5), 0.36, false)


## The Scrapheap: a narrow grating over a heap of scrap, up a ramp, a gap, and a red boost icon on the far side.
func _scrapheap() -> void:
	_sector = 1.0
	_run(14.0)
	_props(-1, 5, 0.0)
	_ramp(26.0, 0.0, 0.14)
	_run(16.0)
	_deck = false
	_run(16.0, -1.0, 3)
	_deck = true
	_icon(0.0, true)
	_ramp(20.0, -0.06, -0.06)
	_item_row()


## The Duct: a magnetic run straight across the S, into a broken pipe and out over a gap.
func _duct() -> void:
	_sector = 1.0
	_run(16.0)
	_props(1, 5, 0.0)
	_mag = true
	_run(70.0)
	_icon(0.0, true)
	_run(40.0)
	_mag = false
	_item_row()


## The Catwalk: a narrow rusted grating along the shell, up onto scaffolding, a broken span to jump, a red boost icon on the far side.
func _catwalk() -> void:
	_sector = 1.0
	_run(14.0)
	_props(-1, 5, 0.0)
	_ramp(30.0, 0.0, 0.16)
	_run(18.0)
	_deck = false
	_run(16.0, -1.0, 3)
	_deck = true
	_icon(0.0, true)
	_ramp(20.0, -0.08, -0.08)
	_item_row()


# ---------------------------------------------------------------- branches ----

func _split(title: String, side: float, risky: bool, recipe: Callable) -> void:
	var b := Branch.new()
	b.title = title
	b.side = side
	b.risky = risky
	b.split_i = _b.size() - 1
	b.path = paths.size() + branches.size()
	branches.append(b)
	_recipes[title] = recipe


func _merge(title: String) -> void:
	for b: Branch in branches:
		if b.title == title:
			b.merge_i = _b.size() - 1


## A branch: edge to edge with the main road where it splits, its own middle, and back alongside the main road's edge, narrowing.
func _build_branch(br: Branch) -> void:
	var m := paths[MAIN]
	while paths.size() <= br.path:
		paths.append(Path.new())
	_b = paths[br.path]
	_b.closed = false
	var at := m.frames[br.split_i]
	var edge := m.wl[br.split_i] if br.side > 0.0 else m.wr[br.split_i]
	_tip = at.origin + at.basis.x * (br.side * (edge + BRANCH_WIDTH))
	var f := at.basis.z
	_yaw = atan2(f.x, f.z)
	_width(BRANCH_WIDTH)
	_walls(false, false)
	_deck = true
	_mag = false
	_add(_tip, 0.0)
	_gate(br.title)
	(_recipes[br.title] as Callable).call()
	var t0 := m.frames[br.merge_i]
	var edge0 := m.wl[br.merge_i] if br.side > 0.0 else m.wr[br.merge_i]
	_join(t0.origin + t0.basis.x * (br.side * (edge0 + BRANCH_WIDTH)), t0.basis.z, 0.34, false)
	_walls(br.side > 0.0, br.side < 0.0)
	var first := _b.size()
	var k := 1
	while true:
		var i := m.wrap(br.merge_i + k)
		var w := BRANCH_WIDTH * (1.0 - float(k) * STEP / 34.0)
		if w < 0.6 or i >= m.size() - 1:
			break
		_wl = w
		_wr = w
		var fr := m.frames[i]
		var e := m.wl[i] if br.side > 0.0 else m.wr[i]
		_add(fr.origin + fr.basis.x * (br.side * (e + w)), 0.0)
		k += 1
	br.taper_n = _b.size() - first
	# the main road's wall on that side is open where the branch is alongside
	var walls := m.wall_l if br.side > 0.0 else m.wall_r
	for j in range(-1, 14):
		walls[m.wrap(br.split_i + j)] = 0
	for j in range(-6, k):
		walls[m.wrap(br.merge_i + j)] = 0
	if br.side > 0.0:
		m.wall_l = walls
	else:
		m.wall_r = walls
	_b = m


func branch_of(path: int) -> Branch:
	for b: Branch in branches:
		if b.path == path:
			return b
	return null


## Near a branch's junction: the matching sample on the other road to search from (q_path names that road); -1 elsewhere.
## side_out: which edge of the car's road the other one is on.
func junction(path: int, i: int) -> int:
	var m := paths[MAIN]
	if path == MAIN:
		for b: Branch in branches:
			var n := paths[b.path].size()
			q_path = b.path
			var from_split := i - b.split_i
			if from_split >= -3 and from_split < 30:
				_q_side = b.side
				return clampi(from_split, 0, n - 1)
			var from_merge := i - b.merge_i
			if from_merge >= -10 and from_merge < b.taper_n + 4:
				_q_side = b.side
				return clampi(n - b.taper_n - 1 + from_merge, 0, n - 1)
		return -1
	var br := branch_of(path)
	if br == null:
		return -1
	var nb := paths[path].size()
	q_path = MAIN
	_q_side = -br.side
	if i < 30:
		return m.wrap(br.split_i + i)
	if i > nb - br.taper_n - 12:
		return m.wrap(br.merge_i + i - (nb - br.taper_n - 1))
	return -1

var _q_side := 1.0


## Which edge of the road the junction found by junction() is on: +1 left, -1 right.
func junction_side() -> float:
	return _q_side


# -------------------------------------------------------------- the pieces ----

static func _fwd(yaw: float) -> Vector3:
	return Vector3(sin(yaw), 0.0, cos(yaw))


static func _left(yaw: float) -> Vector3:
	return Vector3(cos(yaw), 0.0, -sin(yaw))


static func _rise(t: float, shape: int) -> float:
	match shape:
		1:
			return t * t
		2:
			return 1.0 - (1.0 - t) * (1.0 - t)
		3:
			return t
	return t * t * (3.0 - 2.0 * t)


func _path_id() -> int:
	return paths.find(_b)


func _add(p: Vector3, bank: float, up: Vector3 = Vector3.ZERO) -> void:
	_b.pos.append(p)
	_b.ups.append(up)
	_b.bank.append(bank)
	_b.auto.append(1 if _auto else 0)
	_b.wl.append(_wl)
	_b.wr.append(_wr)
	_b.wall_l.append(1 if _wall_l else 0)
	_b.wall_r.append(1 if _wall_r else 0)
	_b.deck.append(1 if _deck else 0)
	_b.mag.append(1 if _mag else 0)
	_b.sector.append(_sector)


func _item_row() -> void:
	item_rows.append(Vector2i(_path_id(), _b.size() - 1))


func _width(w: float) -> void:
	_wl = w
	_wr = w


func _walls(left: bool, right: bool) -> void:
	_wall_l = left
	_wall_r = right


func _gate(label: String) -> void:
	if _b == paths[MAIN]:
		_gate_i.append(_b.size() - 1)
		gate_names.append(label)


func _check() -> void:
	_check_i.append(_b.size() - 1)
	_gate("CHECKPOINT")


func _pad(u: float, hw: float) -> void:
	var p := Pad.new()
	p.path = _path_id()
	p.i = _b.size() - 1
	p.u = u
	p.hw = hw
	pads.append(p)


func _icon(u: float, red: bool) -> void:
	var c := Icon.new()
	c.path = _path_id()
	c.i = _b.size() - 1
	c.u = u
	c.red = red
	icons.append(c)


func _wrecker(phase: float) -> void:
	var c := Crusher.new()
	c.i = _b.size() - 1
	c.phase = phase
	c.u0 = -_wr
	c.u1 = _wl
	wreckers.append(c)


func _crusher(side: float, phase: float) -> void:
	var c := Crusher.new()
	c.i = _b.size() - 1
	c.phase = phase
	if side > 0.0:
		c.u0 = 0.8
		c.u1 = _wl
	else:
		c.u0 = -_wr
		c.u1 = -0.8
	crushers.append(c)


## A stack of props at the last sample: side -1 right edge, +1 left edge, 0 middle; at = how far in from the edge as a share of the half width.
func _props(side: int, count: int, at: float = 0.12) -> void:
	var p := PropSpot.new()
	p.path = _path_id()
	p.i = _b.size() - 1
	var w := _wl if side > 0 else _wr
	p.u = float(side) * w * (1.0 - at)
	p.count = count
	props.append(p)


func _run(length_m: float, climb: float = 0.0, shape: int = 0) -> void:
	var n := maxi(1, ceili(length_m / STEP))
	var f := _fwd(_yaw)
	for i in range(1, n + 1):
		var t := float(i) / n
		_add(_tip + f * (length_m * t) + Vector3.UP * (climb * _rise(t, shape)), 0.0)
	_tip += f * length_m + Vector3.UP * climb


## Straight on with the slope going from s0 to s1 (rise over run): ramps, lips and landings with no kink.
func _ramp(length_m: float, s0: float, s1: float) -> void:
	var n := maxi(1, ceili(length_m / STEP))
	var f := _fwd(_yaw)
	for i in range(1, n + 1):
		var x := length_m * float(i) / n
		_add(_tip + f * x + Vector3.UP * (s0 * x + (s1 - s0) * x * x / (2.0 * length_m)), 0.0)
	_tip += f * length_m + Vector3.UP * ((s0 + s1) * 0.5 * length_m)


## A turn of `degrees` (+ left) on a circle of `radius`, climbing, banked into the turn.
func _arc(radius: float, degrees: float, climb: float = 0.0, bank: float = 0.0) -> void:
	var sg := signf(degrees)
	var sweep := deg_to_rad(absf(degrees))
	var centre := _tip + _left(_yaw) * (radius * sg)
	var n := maxi(2, ceili(radius * sweep / STEP))
	var y0 := _tip.y
	for i in range(1, n + 1):
		var t := float(i) / n
		var yaw := _yaw + sg * sweep * t
		var p := centre - _left(yaw) * (radius * sg)
		p.y = y0 + climb * _rise(t, 0)
		var env := minf(smoothstep(0.0, 0.35, t), 1.0 - smoothstep(0.65, 1.0, t))
		_add(p, sg * bank * env)
	_yaw += sg * sweep
	_tip = centre - _left(_yaw) * (radius * sg)
	_tip.y = y0 + climb


## A full vertical loop that comes out `gap` metres to the side (+ left) of where it went in.
func _loop(radius: float, gap: float) -> void:
	var f := _fwd(_yaw)
	var side := _left(_yaw)
	var n := ceili(TAU * radius / STEP)
	for i in range(1, n + 1):
		var t := float(i) / n
		var a := TAU * t
		var lift := t * t * (3.0 - 2.0 * t)
		var p := _tip + f * (radius * sin(a)) + Vector3.UP * (radius * (1.0 - cos(a))) + side * (gap * lift)
		_add(p, 0.0, Vector3.UP * cos(a) - f * sin(a))
	_tip += side * gap


## A heartline roll: over `length_m` the deck twists once (turn +1: its left side goes up first) round a line HEART metres above it, so a craft
## on it goes straight on and rolls right over; it drops `climb` on the way.
func _roll(length_m: float, turn: float, climb: float = 0.0) -> void:
	const HEART := 0.95      # (the craft's centre of mass rides this high: on the heart line it is turned over without being swung)
	var f := _fwd(_yaw)
	var n := ceili(length_m / STEP)
	var base := _tip
	for i in range(1, n + 1):
		var t := float(i) / n
		var u := t * t * (3.0 - 2.0 * t)
		var up := Vector3.UP.rotated(f, turn * TAU * u)
		var axis := base + f * (length_m * t) + Vector3.UP * (HEART + climb * u)
		_add(axis - up * HEART, 0.0, up)
	_tip = base + f * length_m + Vector3.UP * climb


## A free curve to a point and heading (banked from its own curvature).
func _join(to: Vector3, out_dir: Vector3, handle: float, close: bool) -> void:
	var end := out_dir.normalized()
	var span := _tip.distance_to(to)
	var a := _tip + _fwd(_yaw) * (span * handle)
	var b := to - end * (span * handle)
	var n := ceili(span * 1.2 / STEP)
	_auto = true
	for i in range(1, n if close else n + 1):
		_add(_tip.bezier_interpolate(a, b, to, float(i) / n), 0.0)
	_auto = false
	_tip = to
	_yaw = atan2(end.x, end.z)


# -------------------------------------------------------------- finishing ----

func _finish(p: Path) -> void:
	var n := p.size()
	var fw := PackedVector3Array()
	fw.resize(n)
	for i in n:
		fw[i] = (p.pos[p.wrap(i + 1)] - p.pos[p.wrap(i - 1)]).normalized()
	p.metres.resize(n)
	var m := 0.0
	for i in n:
		if i > 0:
			m += p.pos[i].distance_to(p.pos[i - 1])
		p.metres[i] = m
	p.length = m + (p.pos[n - 1].distance_to(p.pos[0]) if p.closed else 0.0)
	var bend := PackedFloat32Array()
	bend.resize(n)
	for i in n:
		var l := Vector3.UP.cross(fw[i]).normalized()
		var ds := maxf(0.5, p.pos[p.wrap(i + 1)].distance_to(p.pos[p.wrap(i - 1)]))
		bend[i] = (fw[p.wrap(i + 1)] - fw[p.wrap(i - 1)]).dot(l) / ds
	for i in n:
		if p.auto[i] == 1:
			var k := 0.0
			for j in range(-8, 9):
				k += bend[p.wrap(i + j)]
			p.bank[i] = clampf(k / 17.0 * 11.0, -0.3, 0.3)
	_smooth(p, p.wl, 9)
	_smooth(p, p.wr, 9)
	_smooth(p, p.bank, 10)      # (arcs meet with their banks at zero: smoothed, a hairpin made of two arcs stays banked through its middle)
	p.frames.resize(n)
	for i in n:
		var f := fw[i]
		var up := p.ups[i]
		var explicit := up != Vector3.ZERO
		if not explicit:
			up = Vector3.UP
		up = (up - f * f.dot(up)).normalized()
		if not explicit and absf(p.bank[i]) > 0.0001:
			up = up.rotated(f, -p.bank[i])
		var left := up.cross(f).normalized()
		up = f.cross(left)
		p.frames[i] = Transform3D(Basis(left, up, f), p.pos[i])
	p.curve.resize(n)
	for i in n:
		var ds := maxf(0.5, p.pos[p.wrap(i + 1)].distance_to(p.pos[p.wrap(i - 1)]))
		p.curve[i] = (p.frames[p.wrap(i + 1)].basis.z - p.frames[p.wrap(i - 1)].basis.z).dot(p.frames[i].basis.x) / ds


func _smooth(p: Path, values: PackedFloat32Array, half: int) -> void:
	var src := values.duplicate()
	for i in values.size():
		var sum := 0.0
		for j in range(-half, half + 1):
			sum += src[p.wrap(i + j)]
		values[i] = sum / float(half * 2 + 1)


## The AI's line (inside through the bends) and the fastest it can take each sample and still slow for what comes next.
func _lines(p: Path) -> void:
	var n := p.size()
	p.line.resize(n)
	p.pace.resize(n)
	var reach := 14
	for i in n:
		var k := 0.0
		for j in range(-reach, reach + 1):
			k += p.curve[p.wrap(i + j)]
		k /= float(reach * 2 + 1)
		var room := minf(p.wl[i], p.wr[i]) - 2.6
		p.line[i] = clampf(k * 160.0, -1.0, 1.0) * maxf(0.0, room)
		var bend := absf(p.curve[i])
		var grip := MU_AI * G_AI
		var limit := 92.0
		if bend > MU_AI * DF_AI + 0.0005:
			limit = minf(limit, sqrt(grip / (bend - MU_AI * DF_AI)))
		if p.mag[i] == 1:
			limit = maxf(limit, 50.0)
		p.pace[i] = limit
	for _lap in (2 if p.closed else 1):
		for j in range(n - 1, -1, -1):
			var i := j
			var nxt := p.wrap(i + 1)
			if not p.closed and i == n - 1:
				continue
			var ds := p.pos[i].distance_to(p.pos[nxt])
			p.pace[i] = minf(p.pace[i], sqrt(p.pace[nxt] * p.pace[nxt] + 2.0 * BRAKE_AI * ds))
	for i in n:
		if p.deck[p.wrap(i + 8)] == 0 or p.deck[p.wrap(i + 20)] == 0:
			p.pace[i] = maxf(p.pace[i], 66.0)


# ---------------------------------------------------------------- queries ----

## The nearest sample to a point, searching from `hint` back `back` and on `ahead` samples. Leaves the point in that frame in q_local.
func locate(path: int, hint: int, point: Vector3, back: int = 4, ahead: int = 10) -> int:
	var p := paths[path]
	var best := hint
	var best_d := INF
	for j in range(-back, ahead + 1):
		var i := p.wrap(hint + j)
		var d := p.pos[i].distance_squared_to(point)
		if d < best_d:
			best_d = d
			best = i
	q_i = best
	var fr := p.frames[best]
	var off := point - fr.origin
	q_local = Vector3(off.dot(fr.basis.x), off.dot(fr.basis.y), off.dot(fr.basis.z))
	return best


## Is there deck under a point in this frame (q_local from locate)?
func on_deck(path: int, i: int, local: Vector3) -> bool:
	var p := paths[path]
	if p.deck[i] == 0:
		return false
	if local.x >= 0.0:
		return local.x <= p.wl[i]
	return -local.x <= p.wr[i]


func frame(path: int, i: int) -> Transform3D:
	return paths[path].frames[i]


## The main road's frame `distance` metres down it, interpolated.
func sample(distance: float) -> Transform3D:
	var p := paths[MAIN]
	var at := clampf(distance, 0.0, p.metres[p.size() - 1])
	var i := clampi(p.metres.bsearch(at), 1, p.size() - 1)
	return p.frames[i - 1].interpolate_with(p.frames[i], inverse_lerp(p.metres[i - 1], p.metres[i], at))


## The main sample nearest `distance` metres down it.
func index_at(distance: float) -> int:
	var p := paths[MAIN]
	return clampi(p.metres.bsearch(clampf(distance, 0.0, p.metres[p.size() - 1])), 0, p.size() - 1)


## The run seen from above, fitted into the unit square, for the ticket terminal's map: main road first, then each branch.
func route_map() -> Array[PackedVector2Array]:
	var lo := Vector2(INF, INF)
	var hi := -lo
	for o: Vector3 in paths[MAIN].pos:
		lo = lo.min(Vector2(o.x, -o.z))
		hi = hi.max(Vector2(o.x, -o.z))
	var span := maxf(hi.x - lo.x, hi.y - lo.y) * 1.06
	var mid := (lo + hi) * 0.5
	var out: Array[PackedVector2Array] = []
	for p: Path in paths:
		var points := PackedVector2Array()
		for i in range(0, p.size(), 6):
			var o := p.pos[i]
			points.append((Vector2(o.x, -o.z) - mid) / span + Vector2(0.5, 0.5))
		out.append(points)
	return out


# ------------------------------------------------------------------ looks ----

func _build_deck(p: Path, path_id: int) -> void:
	var material := ShaderMaterial.new()
	material.shader = preload("res://levels/sky_sphere/sky_road.gdshader")
	SkyLook.road_textures(material)
	const CHUNK := 60
	var last := p.size() - (0 if p.closed else 1)
	for first in range(0, last, CHUNK):
		var mesh := SurfaceTool.new()
		mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
		var any := false
		for i in range(first, mini(first + CHUNK, last)):
			var j := p.wrap(i + 1)
			if p.deck[i] == 0 or p.deck[j] == 0:
				continue
			any = true
			var hot := float(p.mag[i]) * 0.5 + (0.25 if path_id != MAIN else 0.0)
			_strip(p, mesh, i, j, [-1.0, 0.0, 0.0], [1.0, 0.0, 0.0], Vector3.UP, 0.0, hot)
			for side: float in [1.0, -1.0]:
				var walled := (p.wall_l[i] if side > 0.0 else p.wall_r[i]) == 1
				if walled:
					_strip(p, mesh, i, j, [side, -0.3, 0.06], [side, -0.24, WALL_H], Vector3.LEFT * side, 1.0, hot)
					_strip(p, mesh, i, j, [side, -0.24, WALL_H], [side, 0.42, WALL_H], Vector3.UP, 2.0, hot)
					_strip(p, mesh, i, j, [side, 0.42, WALL_H], [side, -1.0, -1.58], Vector3.LEFT * -side, 3.0, hot)
				else:
					_strip(p, mesh, i, j, [side, -0.05, 0.0], [side, 0.0, 0.16], Vector3.LEFT * side, 5.0, hot)
					_strip(p, mesh, i, j, [side, 0.0, 0.16], [side, 0.18, 0.16], Vector3.UP, 5.0, hot)
					_strip(p, mesh, i, j, [side, 0.18, 0.16], [side, -1.0, -1.58], Vector3.LEFT * -side, 3.0, hot)
			_strip(p, mesh, i, j, [1.0, -1.0, -1.58], [-1.0, -1.0, -1.58], Vector3.DOWN, 4.0, hot)
		if any:
			mesh.index()
			mesh.generate_tangents()
			SkyGeometry.part(self, mesh.commit(), material)


const ORDER: Array[int] = [0, 1, 2, 1, 3, 2]
const ORDER_FLIP: Array[int] = [0, 2, 1, 1, 2, 3]


## One quad between samples i and j. Ends are [side, inset past the edge, height]: side +1 the left edge, -1 the right, 0 the centre line.
## UV: x the metres across from the right edge, y the metres along; UV2: x the kind of surface, y the sector; COLOR.r magnetic / branch.
func _strip(p: Path, out: SurfaceTool, i: int, j: int, a: Array, b: Array, normal: Vector3, kind: float, hot: float) -> void:
	var a_i := _edge_point(p, i, a)
	var b_i := _edge_point(p, i, b)
	var a_j := _edge_point(p, j, a)
	var b_j := _edge_point(p, j, b)
	var n_i: Vector3 = p.frames[i].basis * normal
	var n_j: Vector3 = p.frames[j].basis * normal
	var m_j := p.metres[j] if j > i else p.metres[i] + p.pos[i].distance_to(p.pos[j])
	var w_i := a_i.distance_to(b_i)
	var w_j := a_j.distance_to(b_j)
	var face := (b_i - a_i).cross(a_j - a_i)
	var flip := face.dot(n_i) < 0.0
	var quad: Array = [[a_i, n_i, 0.0, p.metres[i], i, w_i], [b_i, n_i, 1.0, p.metres[i], i, w_i], [a_j, n_j, 0.0, m_j, j, w_j], [b_j, n_j, 1.0, m_j, j, w_j]]
	for k: int in (ORDER_FLIP if flip else ORDER):
		var v: Array = quad[k]
		out.set_normal(v[1])
		out.set_uv(Vector2(float(v[2]) * float(v[5]), v[3]))
		out.set_uv2(Vector2(kind, p.sector[v[4]]))
		out.set_color(Color(hot, float(v[2]), float(v[5]) * 0.05, 1.0))
		out.add_vertex(v[0])


func _edge_point(p: Path, i: int, e: Array) -> Vector3:
	var side: float = e[0]
	var x := 0.0
	if side > 0.0:
		x = p.wl[i] + float(e[1])
	elif side < 0.0:
		x = -(p.wr[i] + float(e[1]))
	return p.frames[i] * Vector3(x, float(e[2]), 0.0)


## Rusted girder hoops round the loop, every few metres, a sodium lamp on some and a red beacon on others.
func _build_hoops(p: Path) -> void:
	var frame_parts: Array[Transform3D] = []
	var lamps: Array[Transform3D] = []
	var beacons: Array[Transform3D] = []
	var k := 0
	for i in p.size():
		if p.mag[i] == 0:
			continue
		k += 1
		if k % 6 != 0:
			continue
		var fr := p.frames[i]
		var l := p.wl[i] + 0.4
		var r := -(p.wr[i] + 0.4)
		var corners: Array[Vector3] = [Vector3(l, WALL_H + 0.1, 0.0), Vector3(l + 1.4, -1.0, 0.0), Vector3(l * 0.55, -2.9, 0.0),
			Vector3(r * 0.55, -2.9, 0.0), Vector3(r - 1.4, -1.0, 0.0), Vector3(r, WALL_H + 0.1, 0.0)]
		for c in corners.size() - 1:
			frame_parts.append(SkyGeometry.beam(fr * corners[c], fr * corners[c + 1], 0.6, 0.75))
		if (k / 6) % 2 == 0:
			lamps.append(SkyGeometry.box_at(fr * Vector3(l + 0.3, WALL_H + 0.3, 0.0), Vector3(0.5, 0.22, 0.9), fr.basis))
		else:
			beacons.append(SkyGeometry.box_at(fr * Vector3(r - 0.3, WALL_H + 0.3, 0.0), Vector3(0.3, 0.3, 0.3), fr.basis))
	if frame_parts.is_empty():
		return
	SkyGeometry.boxes(self, SkyLook.rust(), frame_parts)
	SkyGeometry.boxes(self, SkyGeometry.light(SkyLook.SODIUM, 1.7), lamps)
	SkyGeometry.boxes(self, SkyGeometry.light(SkyLook.BEACON, 1.6), beacons)


func _build_pads() -> void:
	var material := ShaderMaterial.new()
	material.shader = preload("res://levels/sky_sphere/sky_pad.gdshader")
	material.set_shader_parameter(&"glow", SkyLook.BOOST_PAD)
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for pad: Pad in pads:
		var p := paths[pad.path]
		for k in pad.span:
			var i := p.wrap(pad.i + k)
			var j := p.wrap(i + 1)
			var corners: Array[Vector3] = [
				p.frames[i] * Vector3(pad.u - pad.hw, 0.035, 0.0), p.frames[i] * Vector3(pad.u + pad.hw, 0.035, 0.0),
				p.frames[j] * Vector3(pad.u - pad.hw, 0.035, 0.0), p.frames[j] * Vector3(pad.u + pad.hw, 0.035, 0.0)]
			var uv: Array[Vector2] = [Vector2(0, k), Vector2(1, k), Vector2(0, k + 1), Vector2(1, k + 1)]
			for q: int in [0, 2, 1, 1, 2, 3]:
				mesh.set_normal(p.frames[i].basis.y)
				mesh.set_uv(uv[q] * Vector2(1.0, 1.0 / float(pad.span)))
				mesh.add_vertex(corners[q])
	SkyGeometry.part(self, mesh.commit(), material)
