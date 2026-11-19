class_name UfStation
extends RefCounted
## UNDERFOINT's Clock Street station: the block on the north street with the stopped clock, the alley between its two buildings, the stair down under the cavern wall, the concourse, and the track tunnel
## that runs north to the Sigil's chamber with two dead trains in it. The street does not show the alley: a fallen sign and rubble lie across its mouth. What you walk on and into is the same as the greybox was
## (the stair is one ramp, x 68..74, z 84..108; the concourse x 56..86, z 108..132; the tunnel x 66..76, z 133..180), so nothing about the route has moved.

const Y := UnderfointLevel.STATION_Y
const CEIL := 5.0      # the concourse's and the tunnel's height

var lv: UnderfointLevel
var b: UfBuild
var arch: UfArch
var rng: RandomNumberGenerator
var d: UfDistrict


func _init(p_lv: UnderfointLevel, p_b: UfBuild, p_arch: UfArch, p_rng: RandomNumberGenerator) -> void:
	lv = p_lv
	b = p_b
	arch = p_arch
	rng = p_rng
	d = p_lv.district


func build() -> void:
	b.tex("tile_wall", "dirty_tiles", {"tile": 1.3, "tint": Color(0.7, 0.76, 0.68), "growth": 0.8})
	b.tex("ballast", "concrete_debris", {"tile": 2.0, "tint": Color(0.3, 0.28, 0.26), "puddles": 0.6})
	b.glow("tube", Color(0.8, 0.92, 1.0), 2.2)
	b.glow("signal", Color(1.0, 0.16, 0.1), 2.0)
	_block()
	_stair()
	_concourse()
	_tunnel()
	b.commit(lv, "_station")


# ---- up top --------------------------------------------------------------------------------------------------------------------------------------------------------------

## The station's block (x 42..100, z 66..100): two buildings with the alley between them (x 67..75), and on the east one the tower with the clock the outcasts mean
func _block() -> void:
	b.box("walk", 42.0, 100.0, 0.0, 0.15, 66.0, 84.0)
	b.box("walk", 42.0, 68.0, 0.0, 0.15, 84.0, 100.0)
	b.box("walk", 74.0, 100.0, 0.0, 0.15, 84.0, 100.0)
	arch.building({"x0": 44.5, "x1": 67.0, "z0": 68.5, "z1": 100.0, "y": 0.15, "floors": 6, "wall": "stone", "trim": "trim", "shops": [0, 2], "shade": 0.85})
	arch.building({"x0": 75.0, "x1": 97.5, "z0": 68.5, "z1": 100.0, "y": 0.15, "floors": 4, "wall": "brick", "trim": "trim", "shops": [0, 3], "shade": 0.95})
	# the clock tower: four more storeys of brick on the east building's corner, a face on the two sides the city can see, stopped at seven minutes past four
	var base := UfArch._top(0.15, 4)
	var top := 27.0
	b.base_y = base - 3.0
	var faces: Array[UfArch.Face] = [UfArch._mk(80.0, 70.0, 1.0, 0.0, 0.0, -1.0, 8.0), UfArch._mk(80.0, 78.0, 1.0, 0.0, 0.0, 1.0, 8.0), UfArch._mk(80.0, 70.0, 0.0, 1.0, -1.0, 0.0, 8.0), UfArch._mk(88.0, 70.0, 0.0, 1.0, 1.0, 0.0, 8.0)]
	for fi in 4:
		var f := faces[fi]
		arch._front("brick", f, 0.0, 8.0, base, top, 0.0)
		for u: float in [0.0, 7.3]:      # corner piers
			arch._slab("trim", f, u, u + 0.7, base, top, 0.0, 0.12)
		for y: float in [base + 3.0, top - 0.5]:
			arch._slab("trim", f, 0.0, 8.0, y, y + 0.35, 0.0, 0.2)
		arch._slab("trim", f, 0.0, 8.0, top, top + 0.3, 0.0, 0.42)
		if fi == 0 or fi == 2:
			_clock(f, 4.0, base + 6.4)
		else:
			arch._front("void", f, 3.2, 4.8, base + 4.6, base + 7.6, 0.02)
			arch._slab("trim", f, 3.1, 4.9, base + 4.45, base + 4.6, 0.0, 0.14)
	b.base_y = top - 1.0
	b.box("roof", 80.0, 88.0, top + 0.3, top + 0.4, 70.0, 78.0, false)
	for k in 3:      # a stepped cap
		var s := 3.2 - k * 1.1
		b.box("iron", 84.0 - s, 84.0 + s, top + 0.4 + k * 0.7, top + 1.1 + k * 0.7, 74.0 - s, 74.0 + s, false, false)
	b.base_y = -1000.0
	b.world.add({"kind": "box", "cx": 84.0, "cz": 74.0, "hx": 4.0, "hz": 4.0, "bottom": base, "top": top, "tag": "tower"})
	lv._light(Vector3(84.0, base + 6.4, 67.0), Color("ffd9a0"), 0.5, 12.0)      # the faces still glow a little: it is what you see first from the avenue
	lv._light(Vector3(77.0, base + 6.4, 74.0), Color("ffd9a0"), 0.5, 12.0)
	# the alley's mouth: the station's sign, down across it, and what came down with it. The alley itself: dark, wet, a dead lamp, the city's rubbish blown in
	b.base_y = 0.15
	b.box("castiron", 67.0, 67.2, 0.15, 5.4, 68.6, 68.8, false, false)
	b.box("castiron", 74.8, 75.0, 0.15, 5.4, 68.6, 68.8, false, false)
	b.box("castiron", 67.0, 70.2, 5.2, 5.4, 68.6, 68.8, false)
	b.turned("sign_b", 71.6, 69.6, 2.3, 0.07, 0.15, 1.5, 0.35, Vector2(0.0, 0.9))      # the board, leaning where it fell
	b.turned("castiron", 72.4, 70.4, 1.7, 0.06, 0.15, 0.3, -0.5)
	b.base_y = -1000.0
	b.world.add({"kind": "box", "cx": 71.6, "cz": 69.9, "hx": 2.3, "hz": 0.5, "yaw": 0.35, "bottom": 0.15, "top": 1.2, "tag": "sign"})
	arch.heap(68.4, 71.2, 1.5, 0.15, "stone")
	arch.heap(73.6, 72.6, 1.3, 0.15, "brick")
	d.lamp(67.5, 78.0, PI * 0.5, false)
	d.prop("trashbag", 74.2, 0.15, 76.0, 0.7)
	d.prop("trashbag", 73.8, 0.15, 76.8, 2.2, 0.9)
	d.prop("metal_trash_can", 68.3, 0.15, 80.6, PI * 0.5, 1.0, Vector3.ZERO, 0.0)
	d.prop("old_tyre", 73.6, 0.25, 81.5, 0.3, 1.0, Vector3(1.3, 0.0, 0.0))


## A clock face on wall f, centred at (u, y): a pale dial in a stone ring, twelve marks, two hands
func _clock(f: UfArch.Face, u: float, y: float) -> void:
	var r := 1.7
	arch._slab("trim", f, u - r - 0.3, u + r + 0.3, y - r - 0.3, y + r + 0.3, 0.0, 0.1)
	arch._front("clock", f, u - r, u + r, y - r, y + r, 0.12)
	for k in 12:
		var a := k * TAU / 12.0
		var c := Vector2(sin(a), cos(a)) * (r - 0.25)
		arch._front("castiron", f, u + c.x - 0.05, u + c.x + 0.05, y + c.y - 0.12, y + c.y + 0.12, 0.14)
	for q: Array in [[TAU * (4.0 + 7.0 / 60.0) / 12.0, 0.95, 0.07], [TAU * 7.0 / 60.0, 1.4, 0.045]]:      # the hour hand, the minute hand
		var dir := Vector2(sin(q[0]), cos(q[0]))
		var side := Vector2(dir.y, -dir.x) * float(q[2])
		var tip := dir * float(q[1])
		var back := dir * -0.2
		arch._q("castiron", f.at(u + back.x - side.x, y + back.y - side.y, 0.15), f.at(u + back.x + side.x, y + back.y + side.y, 0.15), f.at(u + tip.x + side.x, y + tip.y + side.y, 0.15), f.at(u + tip.x - side.x, y + tip.y - side.y, 0.15), f.out())


# ---- the stair -------------------------------------------------------------------------------------------------------------------------------------------------------------

## Down from the alley's end (z 84) to the concourse (z 108): forty steps between tiled walls, a rail each side, the station's roundel over the place it goes under the rock
func _stair() -> void:
	b.base_y = Y
	b.foot_shade = 0.75
	var n := 40
	for k in n:
		var z0 := 84.0 + k * 0.6
		var top := -(k + 0.5) * (-Y / n)      # (the ramp you really walk on runs through the middle of each tread)
		b.box("tiles", 68.0, 74.0, top - 0.4, top, z0, z0 + 0.6, false, false)
	b.world.add({"kind": "ramp", "cx": 71.0, "cz": 96.0, "hx": 3.0, "hz": 12.0, "yaw": PI, "bottom": Y - 0.6, "top": 0.0, "top_low": Y, "tag": "stair"})
	b.box("tile_wall", 67.0, 68.0, Y - 1.0, 0.0, 84.0, 108.0)
	b.box("tile_wall", 74.0, 75.0, Y - 1.0, 0.0, 84.0, 108.0)
	b.box("trim", 66.9, 68.1, 0.0, 0.2, 84.0, 100.0, false, false)      # a kerb round the well, where it is open to the alley
	b.box("trim", 73.9, 75.1, 0.0, 0.2, 84.0, 100.0, false, false)
	for x: float in [68.18, 73.82]:      # the rails
		b.ramp("castiron", x, 96.0, 0.03, 12.0, Y + 0.95, 0.95, PI, 0.05, false)
		var z := 85.0
		while z < 108.0:
			var fy := -(z - 84.0) / 24.0 * -Y
			b.box("castiron", x - 0.02, x + 0.02, fy, fy + 0.93, z - 0.02, z + 0.02, false, false)
			z += 2.4
	b.box("tile_wall", 68.0, 74.0, -0.9, 0.0, 100.0, 108.0, false)      # the head of the stair, under the cavern's wall
	b.box("castiron", 68.0, 74.0, -1.5, -0.9, 100.0, 100.25, false)
	b.box("sign_a", 70.3, 71.7, -1.45, -0.95, 99.94, 100.0, false)           # the roundel's bar
	b.box("tube", 70.2, 71.8, -1.62, -1.52, 100.3, 100.44, false)
	b.foot_shade = 0.5
	b.base_y = -1000.0
	lv.lamps.append(lv._light(Vector3(71.0, -2.3, 101.0), Color("cfe8ff"), 0.9, 9.0))
	d.prop("trashbag", 68.5, -1.75, 90.2, 1.1)


# ---- the concourse ---------------------------------------------------------------------------------------------------------------------------------------------------------

## The concourse (x 56..86, z 108..132): tiled, four columns, the booth, the turnstiles, and beyond them the opening onto the tracks
func _concourse() -> void:
	b.base_y = Y
	b.foot_shade = 0.7
	b.box("tiles", 55.0, 87.0, Y - 1.0, Y, 108.0, 133.0)
	b.box("inner", 55.0, 87.0, Y + CEIL, Y + CEIL + 1.0, 108.0, 133.0)
	b.box("tile_wall", 55.0, 56.0, Y, Y + CEIL, 108.0, 133.0)
	b.box("tile_wall", 86.0, 87.0, Y, Y + CEIL, 108.0, 133.0)
	b.box("tile_wall", 56.0, 66.0, Y, Y + CEIL, 132.0, 133.0)
	b.box("tile_wall", 76.0, 86.0, Y, Y + CEIL, 132.0, 133.0)
	b.box("tile_wall", 56.0, 67.0, Y, Y + CEIL, 107.0, 108.0)      # the south wall, either side of the stair's foot
	b.box("tile_wall", 75.0, 86.0, Y, Y + CEIL, 107.0, 108.0)
	for q: Array in [[55.99, 56.06, 108.0, 132.0], [85.94, 86.01, 108.0, 132.0]]:      # a band of dark tile at hand height, as stations have
		b.box("sign_b", q[0], q[1], Y + 1.3, Y + 1.55, q[2], q[3], false)
	for z: float in [112.0, 118.0, 124.0, 130.0]:      # beams
		b.box("trim", 56.0, 86.0, Y + CEIL - 0.35, Y + CEIL, z - 0.25, z + 0.25, false)
	for q: Array in [[63.0, 114.0], [79.0, 114.0], [63.0, 126.0], [79.0, 126.0]]:
		b.box("tile_wall", q[0] - 0.4, q[0] + 0.4, Y, Y + CEIL, q[1] - 0.4, q[1] + 0.4)
		b.box("trim", q[0] - 0.5, q[0] + 0.5, Y, Y + 0.3, q[1] - 0.5, q[1] + 0.5, false, false)
		b.box("trim", q[0] - 0.5, q[0] + 0.5, Y + CEIL - 0.7, Y + CEIL - 0.35, q[1] - 0.5, q[1] + 0.5, false)
	# the booth: boards to the waist, glass above with a grille, its roof, the hatch tickets came through
	b.box("planks", 59.0, 62.6, Y, Y + 1.1, 116.0, 118.4)
	b.box("window", 59.06, 62.54, Y + 1.1, Y + 2.2, 116.06, 118.34, false, false)
	b.box("castiron", 58.9, 62.7, Y + 2.2, Y + 2.4, 115.9, 118.5, false)
	for x: float in [59.0, 60.2, 61.4, 62.54]:
		b.box("castiron", x, x + 0.06, Y + 1.1, Y + 2.2, 115.98, 116.04, false)
		b.box("castiron", x, x + 0.06, Y + 1.1, Y + 2.2, 118.36, 118.42, false)
	b.box("sign_c", 60.0, 61.6, Y + 2.4, Y + 2.85, 115.92, 115.98, false)
	b.world.add({"kind": "box", "cx": 60.8, "cz": 117.2, "hx": 1.8, "hz": 1.2, "bottom": Y + 1.1, "top": Y + 2.4, "tag": "booth"})
	# the turnstiles: a post, three arms, every 1.6 m, and a rail from the last one to each wall
	var x := 66.0
	while x < 76.0:
		b.box("castiron", x, x + 0.4, Y, Y + 1.0, 127.6, 128.6)
		b.box("iron", x + 0.02, x + 0.38, Y + 1.0, Y + 1.04, 127.58, 128.62, false)
		if x + 1.6 < 76.5:
			for k in 3:
				b.box("castiron", x + 0.4, x + 0.4 + 0.5 - k * 0.12, Y + 0.85 - k * 0.2, Y + 0.89 - k * 0.2, 128.05 + k * 0.05, 128.09 + k * 0.05, false)
		x += 1.6
	for q: Array in [[56.0, 66.0], [76.4, 86.0]]:
		b.box("castiron", q[0], q[1], Y + 0.95, Y + 1.0, 128.05, 128.1, false)
		b.box("castiron", q[0], q[1], Y + 0.5, Y + 0.54, 128.05, 128.1, false)
		b.world.add({"kind": "box", "cx": (q[0] + q[1]) * 0.5, "cz": 128.08, "hx": (q[1] - q[0]) * 0.5, "hz": 0.08, "bottom": Y, "top": Y + 1.0, "tag": "rail", "no_cam": true})
	# what is on the walls and the floor: posters gone to rags, the line's map, benches, a fall of ceiling, the lights
	for q: Array in [[56.07, 110.5, "sign_a"], [56.07, 113.0, "sign_c"], [56.07, 121.5, "sign_b"], [85.93, 111.0, "sign_c"], [85.93, 116.5, "sign_a"], [85.93, 124.0, "sign_c"]]:
		var px: float = q[0]
		b.box(q[2], px - 0.02, px + 0.02, Y + 1.7, Y + 3.1, q[1], q[1] + 1.0, false)
	b.box("castiron", 76.6, 79.4, Y + 1.5, Y + 3.3, 131.9, 131.98, false)      # the map of the line
	b.box("sign_c", 76.75, 79.25, Y + 1.65, Y + 3.15, 131.86, 131.9, false)
	for q: Array in [[57.0, 111.5], [57.0, 123.0], [85.0, 113.5], [85.0, 121.0]]:
		_bench(q[0], q[1])
	b.base_y = -1000.0
	b.foot_shade = 0.5
	arch.heap(82.0, 129.5, 1.6, Y, "tile_wall")
	arch.heap(67.5, 110.5, 1.1, Y, "tile_wall")
	d.prop("trashbag", 57.2, Y, 118.6, 0.4)
	d.prop("metal_trash_can", 84.6, Y, 109.4, 0.0, 1.0, Vector3.ZERO, 0.0)
	d.prop("old_military_crate", 61.0, Y, 119.6, 0.2, 0.8)
	var k := 0
	for q: Array in [[64.0, 119.0], [78.0, 123.0], [71.0, 111.0], [64.0, 129.0], [78.0, 112.0], [71.0, 130.5]]:      # tube lights: two still on
		var lit := k < 2
		b.box("castiron", q[0] - 0.9, q[0] + 0.9, Y + CEIL - 0.1, Y + CEIL, q[1] - 0.12, q[1] + 0.12, false)
		b.box("tube" if lit else "window", q[0] - 0.8, q[0] + 0.8, Y + CEIL - 0.17, Y + CEIL - 0.1, q[1] - 0.05, q[1] + 0.05, false)
		if lit:
			lv.lamps.append(lv._light(Vector3(q[0], Y + 4.3, q[1]), Color("cfe8ff"), 1.3 if k == 0 else 0.9, 13.0))
		k += 1


func _bench(x: float, z: float) -> void:
	b.box("planks", x - 0.25, x + 0.25, Y + 0.4, Y + 0.47, z - 1.0, z + 1.0, false)
	for s: float in [-0.85, 0.85]:
		b.box("castiron", x - 0.24, x + 0.24, Y, Y + 0.4, z + s - 0.03, z + s + 0.03, false, false)
	b.world.add({"kind": "box", "cx": x, "cz": z, "hx": 0.25, "hz": 1.0, "bottom": Y, "top": Y + 0.47, "tag": "bench"})


# ---- the tunnel ------------------------------------------------------------------------------------------------------------------------------------------------------------

## The track tunnel (x 66..76, z 133..180): brick, two tracks on ballast, the two trains that were in it when everything stopped, signals stuck at red
func _tunnel() -> void:
	b.base_y = Y
	b.box("ballast", 65.0, 77.0, Y - 1.0, Y, 133.0, 180.0)
	b.box("sewer", 65.0, 77.0, Y + CEIL, Y + CEIL + 1.0, 133.0, 180.0)
	b.box("sewer", 65.0, 66.0, Y, Y + CEIL, 133.0, 180.0)
	b.box("sewer", 76.0, 77.0, Y, Y + CEIL, 133.0, 180.0)
	arch._q("sewer", Vector3(66.0, Y + 3.2, 133.0), Vector3(66.0, Y + 3.2, 180.0), Vector3(67.8, Y + CEIL, 180.0), Vector3(67.8, Y + CEIL, 133.0), Vector3(1.0, -1.0, 0.0))      # the roof coved down to the walls
	arch._q("sewer", Vector3(76.0, Y + 3.2, 133.0), Vector3(76.0, Y + 3.2, 180.0), Vector3(74.2, Y + CEIL, 180.0), Vector3(74.2, Y + CEIL, 133.0), Vector3(-1.0, -1.0, 0.0))
	var z := 137.0
	while z < 180.0:      # ribs
		b.box("sewer_trim", 66.0, 66.35, Y, Y + 3.2, z - 0.3, z + 0.3, false, false)
		b.box("sewer_trim", 75.65, 76.0, Y, Y + 3.2, z - 0.3, z + 0.3, false, false)
		b.box("sewer_trim", 67.6, 74.4, Y + CEIL - 0.3, Y + CEIL, z - 0.3, z + 0.3, false)
		arch._q("sewer_trim", Vector3(66.35, Y + 3.2, z - 0.3), Vector3(66.35, Y + 3.2, z + 0.3), Vector3(67.9, Y + CEIL - 0.3, z + 0.3), Vector3(67.9, Y + CEIL - 0.3, z - 0.3), Vector3(1.0, -1.0, 0.0))
		arch._q("sewer_trim", Vector3(75.65, Y + 3.2, z - 0.3), Vector3(75.65, Y + 3.2, z + 0.3), Vector3(74.1, Y + CEIL - 0.3, z + 0.3), Vector3(74.1, Y + CEIL - 0.3, z - 0.3), Vector3(-1.0, -1.0, 0.0))
		z += 8.0
	for cx: float in [68.5, 73.1]:      # a track: two rails, a sleeper every 0.75 m
		for rx: float in [cx - 0.72, cx + 0.72]:
			b.box("castiron", rx - 0.035, rx + 0.035, Y + 0.08, Y + 0.2, 133.0, 180.0, false, false)
		z = 133.4
		while z < 180.0:
			b.box("planks", cx - 1.15, cx + 1.15, Y, Y + 0.09, z - 0.12, z + 0.12, false, false)
			z += 0.75
	b.box("pipe", 66.05, 66.3, Y + 2.2, Y + 2.45, 133.0, 180.0, false)      # the cable trough along the west wall
	for q: Array in [[75.7, 135.5], [66.3, 156.0], [75.7, 176.5]]:        # signals
		b.box("castiron", q[0] - 0.05, q[0] + 0.05, Y, Y + 2.6, q[1] - 0.05, q[1] + 0.05, false, false)
		b.box("castiron", q[0] - 0.16, q[0] + 0.16, Y + 2.6, Y + 3.3, q[1] - 0.12, q[1] + 0.12, false)
		b.box("signal", q[0] - 0.08, q[0] + 0.08, Y + 3.0, Y + 3.16, q[1] - 0.14, q[1] - 0.12, false)
		b.box("window", q[0] - 0.08, q[0] + 0.08, Y + 2.72, Y + 2.88, q[1] - 0.14, q[1] - 0.12, false)
		lv._light(Vector3(q[0], Y + 3.1, q[1] - 0.8), Color("ff3a2a"), 0.8, 9.0)
	b.base_y = -1000.0
	d.car(68.5, 146.0, 1.5, 8.0, Y, false)
	d.car(73.1, 166.0, 1.5, 8.0, Y, false)
	lv._light(Vector3(71.2, Y + 2.0, 150.0), Color("58ff7a"), 0.5, 9.0)      # a set is on somewhere inside the first train
	arch.heap(74.0, 141.0, 1.4, Y, "sewer")
	d.prop("old_tyre", 71.0, Y + 0.1, 159.0, 0.0, 1.0, Vector3(PI * 0.5, 0.0, 0.0))
