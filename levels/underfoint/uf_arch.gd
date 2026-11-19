class_name UfArch
extends RefCounted
## UNDERFOINT's buildings: the old city's blocks built face by face out of UfBuild pieces. A building is a footprint, a number of floors and a style; each face is cut into bays, and a bay gets a real opening
## (a shopfront with its shutter down, a door up two steps, a window with a sill and what is left behind it), set back in the wall's thickness. Floors are parted by string courses, the top has a cornice and a parapet.
## A ruined building has lost floors toward one corner: the walls end in broken stubs there, the floors behind are open to the cavern, and what fell lies at its foot.
## Material tags it expects in the builder: the wall and trim it is given, and "shutter", "planks", "iron", "rust", "debris", "roof", "inner", "void", "window", "candle", "sign_a".."sign_c".

const GH := 4.2            # the ground floor's height
const FH := 3.3            # every floor above
const BAY := 3.3           # a bay is about this wide
const PIER := 0.9          # the wall left between two openings
const W := 0.38            # how deep an opening is set in the wall
const CORNER := 0.5        # extra wall at each end of a face

var b: UfBuild
var rng: RandomNumberGenerator


## One side of a building, seen from outside: `at(u, y, d)` is u metres along it, d metres out from the wall's face (negative: into the wall)
class Face:
	var ox := 0.0
	var oz := 0.0
	var ux := 0.0
	var uz := 0.0
	var nx := 0.0
	var nz := 0.0
	var length := 0.0
	var n := 1               # bays
	var bw := BAY            # a bay's real width
	var heights := PackedInt32Array()      # floors standing, per bay

	func at(u: float, y: float, d: float) -> Vector3:
		return Vector3(ox + ux * u + nx * d, y, oz + uz * u + nz * d)

	func out() -> Vector3:
		return Vector3(nx, 0.0, nz)

	func along() -> Vector3:
		return Vector3(ux, 0.0, uz)


func _init(p_b: UfBuild, p_rng: RandomNumberGenerator) -> void:
	b = p_b
	rng = p_rng


static func _mk(ox: float, oz: float, ux: float, uz: float, nx: float, nz: float, length: float) -> Face:
	var f := Face.new()
	f.ox = ox
	f.oz = oz
	f.ux = ux
	f.uz = uz
	f.nx = nx
	f.nz = nz
	f.length = length
	f.n = maxi(1, int((length - CORNER * 2.0) / BAY))
	f.bw = (length - CORNER * 2.0) / f.n
	return f


# ---- pieces, in a face's own space ---------------------------------------------------------------------------------------------------------------------------------------

func _q(tag: String, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, want: Vector3) -> void:
	if (p2 - p0).cross(p1 - p0).dot(want) < 0.0:
		b.quad(tag, p0, p3, p2, p1)
	else:
		b.quad(tag, p0, p1, p2, p3)


## a piece of wall facing out, at depth d
func _front(tag: String, f: Face, u0: float, u1: float, y0: float, y1: float, d: float) -> void:
	if u1 - u0 < 0.01 or y1 - y0 < 0.01:
		return
	_q(tag, f.at(u0, y0, d), f.at(u1, y0, d), f.at(u1, y1, d), f.at(u0, y1, d), f.out())


## the side of an opening or a ledge: at u, from depth d0 to d1, facing along (dir 1) or back along (dir -1) the face
func _side(tag: String, f: Face, u: float, y0: float, y1: float, d0: float, d1: float, dir: float) -> void:
	_q(tag, f.at(u, y0, d0), f.at(u, y0, d1), f.at(u, y1, d1), f.at(u, y1, d0), f.along() * dir)


## a level piece: a sill's top, a lintel's underside
func _flat(tag: String, f: Face, u0: float, u1: float, y: float, d0: float, d1: float, up: bool) -> void:
	_q(tag, f.at(u0, y, d0), f.at(u1, y, d0), f.at(u1, y, d1), f.at(u0, y, d1), Vector3.UP if up else Vector3.DOWN)


## something standing proud of the wall from depth d0 out to d1: its front, top, underside and two ends
func _slab(tag: String, f: Face, u0: float, u1: float, y0: float, y1: float, d0: float, d1: float) -> void:
	_front(tag, f, u0, u1, y0, y1, d1)
	_flat(tag, f, u0, u1, y1, d0, d1, true)
	_flat(tag, f, u0, u1, y0, d0, d1, false)
	_side(tag, f, u0, y0, y1, d0, d1, -1.0)
	_side(tag, f, u1, y0, y1, d0, d1, 1.0)


# ---- a building ------------------------------------------------------------------------------------------------------------------------------------------------------------

## o: x0, x1, z0, z1, y (the ground), floors, wall, trim, shops (faces with shopfronts: 0 south (-z), 1 north, 2 west (-x), 3 east), ruin (true: floors lost toward one corner), shade, collide (default true)
func building(o: Dictionary) -> void:
	var x0: float = o.x0
	var x1: float = o.x1
	var z0: float = o.z0
	var z1: float = o.z1
	var y: float = o.get("y", 0.0)
	var floors: int = o.floors
	var was_base := b.base_y
	b.base_y = y
	b.shade = o.get("shade", 1.0)
	b.grow = 0.0
	var faces: Array[Face] = [_mk(x0, z0, 1.0, 0.0, 0.0, -1.0, x1 - x0), _mk(x0, z1, 1.0, 0.0, 0.0, 1.0, x1 - x0), _mk(x0, z0, 0.0, 1.0, -1.0, 0.0, z1 - z0), _mk(x1, z0, 0.0, 1.0, 1.0, 0.0, z1 - z0)]
	var nx := faces[0].n
	var nz := faces[2].n
	# how many floors stand over each cell of the plan
	var grid := PackedInt32Array()
	grid.resize(nx * nz)
	grid.fill(floors)
	var ruined: bool = o.get("ruin", false) and floors > 1
	var rc := Vector2.ZERO
	if ruined:
		rc = Vector2(x0 if rng.randf() < 0.5 else x1, z0 if rng.randf() < 0.5 else z1)
		var reach := maxf(x1 - x0, z1 - z0) * rng.randf_range(0.6, 1.1)
		for i in nx:
			for j in nz:
				var c := Vector2(_cell_mid(faces[0], i), _cell_mid(faces[2], j))
				var lost := int(pow(clampf(1.0 - c.distance_to(rc) / reach, 0.0, 1.0), 0.8) * floors + 0.5)
				grid[i + j * nx] = maxi(1, floors - lost)
	for i in nx:
		faces[0].heights.append(grid[i])
		faces[1].heights.append(grid[i + (nz - 1) * nx])
	for j in nz:
		faces[2].heights.append(grid[j * nx])
		faces[3].heights.append(grid[nx - 1 + j * nx])
	var shops: Array = o.get("shops", [])
	for fi in 4:
		_face(faces[fi], o, floors, shops.has(fi))
	# the tops: a roof where it is whole, the open floor where it is not, and the inner wall where one stands higher than the next
	var lowest := floors
	for i in nx:
		for j in nz:
			var h := grid[i + j * nx]
			lowest = mini(lowest, h)
			var cx0 := _cell_edge(faces[0], i)
			var cx1 := _cell_edge(faces[0], i + 1)
			var cz0 := _cell_edge(faces[2], j)
			var cz1 := _cell_edge(faces[2], j + 1)
			var top := _top(y, h)
			b.base_y = top - 1.2
			b.quad("roof" if h == floors else "debris", Vector3(cx0, top, cz0), Vector3(cx1, top, cz0), Vector3(cx1, top, cz1), Vector3(cx0, top, cz1))
			b.base_y = y
			if i + 1 < nx and grid[i + 1 + j * nx] != h:
				var h2 := grid[i + 1 + j * nx]
				_q("inner", Vector3(cx1, _top(y, mini(h, h2)), cz0), Vector3(cx1, _top(y, mini(h, h2)), cz1), Vector3(cx1, _top(y, maxi(h, h2)), cz1), Vector3(cx1, _top(y, maxi(h, h2)), cz0), Vector3.RIGHT if h > h2 else Vector3.LEFT)
			if j + 1 < nz and grid[i + (j + 1) * nx] != h:
				var h3 := grid[i + (j + 1) * nx]
				_q("inner", Vector3(cx0, _top(y, mini(h, h3)), cz1), Vector3(cx1, _top(y, mini(h, h3)), cz1), Vector3(cx1, _top(y, maxi(h, h3)), cz1), Vector3(cx0, _top(y, maxi(h, h3)), cz1), Vector3.BACK if h > h3 else Vector3.FORWARD)
	if o.get("collide", true):
		b.world.add({"kind": "box", "cx": (x0 + x1) * 0.5, "cz": (z0 + z1) * 0.5, "hx": (x1 - x0) * 0.5, "hz": (z1 - z0) * 0.5, "bottom": y, "top": _top(y, lowest), "tag": "building"})
		if ruined:
			for i in nx:
				for j in nz:
					var h := grid[i + j * nx]
					if h > lowest:
						var cx0 := _cell_edge(faces[0], i)
						var cx1 := _cell_edge(faces[0], i + 1)
						var cz0 := _cell_edge(faces[2], j)
						var cz1 := _cell_edge(faces[2], j + 1)
						b.world.add({"kind": "box", "cx": (cx0 + cx1) * 0.5, "cz": (cz0 + cz1) * 0.5, "hx": (cx1 - cx0) * 0.5, "hz": (cz1 - cz0) * 0.5, "bottom": _top(y, lowest), "top": _top(y, h), "tag": "building"})
	if ruined:
		var inx := 1.0 if rc.x == x0 else -1.0
		var inz := 1.0 if rc.y == z0 else -1.0
		heap(rc.x - inx * 1.2, rc.y - inz * 1.2, 3.2, y, String(o.wall))
	elif rng.randf() < 0.6:
		_roof_things(x0, x1, z0, z1, _top(y, floors))
	b.shade = 1.0
	b.base_y = was_base


static func _top(y: float, floors: int) -> float:
	return y + GH + (floors - 1) * FH


static func _cell_edge(f: Face, i: int) -> float:
	var u := 0.0 if i <= 0 else (f.length if i >= f.n else CORNER + i * f.bw)
	return f.ox + u if f.ux != 0.0 else f.oz + u


static func _cell_mid(f: Face, i: int) -> float:
	return (_cell_edge(f, i) + _cell_edge(f, i + 1)) * 0.5


func _face(f: Face, o: Dictionary, floors: int, shop: bool) -> void:
	var wall: String = o.wall
	var trim: String = o.trim
	var y: float = o.get("y", 0.0)
	var sign_tag: String = ["sign_a", "sign_b", "sign_c"][rng.randi() % 3]
	for fl in floors:
		var yb := y if fl == 0 else y + GH + (fl - 1) * FH
		var yt := yb + (GH if fl == 0 else FH)
		for j in f.n + 1:      # the piers
			if not ((j > 0 and f.heights[j - 1] > fl) or (j < f.n and f.heights[j] > fl)):
				continue
			var p0 := 0.0 if j == 0 else CORNER + j * f.bw - PIER * 0.5
			var p1 := f.length if j == f.n else CORNER + j * f.bw + PIER * 0.5
			_front(wall, f, p0, p1, yb, yt, 0.0)
			if j < f.n:
				_side(wall, f, p1, yb, yt, -W, 0.0, 1.0)
			if j > 0:
				_side(wall, f, p0, yb, yt, -W, 0.0, -1.0)
		for i in f.n:
			if f.heights[i] <= fl:
				continue
			var a0 := CORNER + i * f.bw + PIER * 0.5
			var a1 := CORNER + (i + 1) * f.bw - PIER * 0.5
			var u0 := 0.0 if i == 0 else CORNER + i * f.bw
			var u1 := f.length if i == f.n - 1 else CORNER + (i + 1) * f.bw
			if fl == 0:
				_ground_bay(f, wall, trim, a0, a1, yb, yt, shop)
				if shop:      # the fascia the shop's name was on
					_slab(sign_tag, f, u0, u1, yb + 3.25, yb + 4.0, 0.0, 0.1)
					if rng.randf() < 0.22:      # a tin canopy still up
						_slab("iron", f, a0 - 0.2, a1 + 0.2, yb + 3.12, yb + 3.2, 0.0, 1.3)
						_slab("rust", f, a0 - 0.1, a0 - 0.04, yb + 3.2, yb + 3.9, 0.1, 1.25)
						_slab("rust", f, a1 + 0.04, a1 + 0.1, yb + 3.2, yb + 3.9, 0.1, 1.25)
					elif rng.randf() < 0.12:    # a sign hung out over the pavement
						_slab(sign_tag, f, a0 - 0.5, a0 - 0.38, yb + 3.3, yb + 4.5, 0.1, 1.0)
				else:
					_slab(trim, f, u0, u1, yt - 0.14, yt + 0.1, 0.0, 0.13)
			else:
				_window_bay(f, wall, trim, a0, a1, yb, yt, yb + 0.95, yb + 2.75)
				if fl < f.heights[i] - 1:
					_slab(trim, f, u0, u1, yt - 0.12, yt + 0.1, 0.0, 0.13)
			if fl == f.heights[i] - 1:      # this bay's top
				if f.heights[i] == floors:
					_slab(trim, f, u0, u1, yt - 0.38, yt, 0.0, 0.2)
					_slab(trim, f, u0, u1, yt, yt + 0.2, 0.0, 0.38)
					_front(wall, f, u0, u1, yt + 0.2, yt + 0.95, 0.0)
					_flat(trim, f, u0, u1, yt + 0.95, -0.3, 0.02, true)
					_q(wall, f.at(u0, yt, -0.3), f.at(u1, yt, -0.3), f.at(u1, yt + 0.95, -0.3), f.at(u0, yt + 0.95, -0.3), -f.out())
				else:      # broken off: stubs of the wall that went
					var parts := 3
					for k in parts:
						var s0 := u0 + (u1 - u0) * k / parts
						var s1 := u0 + (u1 - u0) * (k + 1) / parts
						var hh := rng.randf_range(0.15, 1.7) * (0.4 if rng.randf() < 0.3 else 1.0)
						_front(wall, f, s0, s1, yt, yt + hh, 0.0)
						_q(wall, f.at(s0, yt, -W), f.at(s1, yt, -W), f.at(s1, yt + hh, -W), f.at(s0, yt + hh, -W), -f.out())
						_flat("debris", f, s0, s1, yt + hh, -W, 0.0, true)
						_side(wall, f, s0, yt, yt + hh, -W, 0.0, -1.0)
						_side(wall, f, s1, yt, yt + hh, -W, 0.0, 1.0)
	# what hangs on it: a drainpipe, a fire escape on a tall back wall
	if rng.randf() < 0.55 and f.n >= 2:
		var j := 1 + rng.randi() % (f.n - 1)
		var top := _top(y, mini(f.heights[j - 1], f.heights[j]))
		var u := CORNER + j * f.bw
		_slab("rust", f, u - 0.07, u + 0.07, y, top, 0.0, 0.14)
	if not shop and floors >= 4 and f.n >= 3 and rng.randf() < 0.35:
		_fire_escape(f, y, 1 + rng.randi() % (f.n - 2))


## The ground floor of one bay
func _ground_bay(f: Face, wall: String, trim: String, a0: float, a1: float, yb: float, yt: float, shop: bool) -> void:
	var r := rng.randf()
	if shop and r > 0.16:      # a shopfront: a stall riser, the window, and what closed it
		var s := yb + 0.4
		var t := yb + 3.1
		_front(wall, f, a0, a1, yb, s, 0.0)
		_flat(trim, f, a0, a1, s, -W, 0.03, true)
		_front(trim, f, a0, a1, s - 0.08, s, 0.03)
		_front(wall, f, a0, a1, t, yt, 0.0)
		_flat(wall, f, a0, a1, t, -W, 0.0, false)
		var k := rng.randf()
		if k < 0.55:
			_front("shutter", f, a0, a1, s, t, -0.2)
		elif k < 0.8:
			_front("void", f, a0, a1, s, t, -W)
			_boards(f, a0, a1, s, t)
		else:
			_front("window", f, a0, a1, s, t, -W + 0.06)
			_slab("planks", f, (a0 + a1) * 0.5 - 0.05, (a0 + a1) * 0.5 + 0.05, s, t, -W + 0.06, -W + 0.14)
	elif r < (0.16 if shop else 0.2):      # a door, up two steps
		var c0 := (a0 + a1) * 0.5 - 0.68
		var c1 := c0 + 1.36
		var s := yb + 0.3
		var t := yb + 2.8
		_front(wall, f, a0, c0, yb, yt, 0.0)
		_front(wall, f, c1, a1, yb, yt, 0.0)
		_side(wall, f, c0, s, t, -W, 0.0, 1.0)
		_side(wall, f, c1, s, t, -W, 0.0, -1.0)
		_front(wall, f, c0, c1, t, yt, 0.0)
		_front(wall, f, c0, c1, yb, s, 0.0)
		_flat(wall, f, c0, c1, t, -W, 0.0, false)
		_slab(trim, f, c0 - 0.14, c1 + 0.14, t, t + 0.2, 0.0, 0.12)
		_front("planks" if rng.randf() < 0.75 else "void", f, c0, c1, s, t, -W + 0.05)
		_slab(trim, f, c0 - 0.2, c1 + 0.2, yb, yb + 0.15, 0.0, 0.66)
		_slab(trim, f, c0 - 0.2, c1 + 0.2, yb + 0.15, yb + 0.3, 0.0, 0.33)
		_flat(trim, f, c0, c1, s, -W, 0.0, true)
	elif shop or r < 0.78:
		_window_bay(f, wall, trim, a0, a1, yb, yt, yb + 1.25, yb + 3.15)
	else:
		_front(wall, f, a0, a1, yb, yt, 0.0)


## One window: the wall under and over it, the sill, and what is left in the hole
func _window_bay(f: Face, wall: String, trim: String, a0: float, a1: float, yb: float, yt: float, s: float, t: float) -> void:
	if rng.randf() < 0.07:      # never had one, or bricked up long ago
		_front(wall, f, a0, a1, yb, yt, 0.0)
		return
	var c := (a0 + a1) * 0.5
	var hw := minf(0.72, (a1 - a0) * 0.5)
	if a1 - a0 > hw * 2.0 + 0.02:
		_front(wall, f, a0, c - hw, yb, yt, 0.0)
		_front(wall, f, c + hw, a1, yb, yt, 0.0)
		_side(wall, f, c - hw, s, t, -W, 0.0, 1.0)
		_side(wall, f, c + hw, s, t, -W, 0.0, -1.0)
	a0 = c - hw
	a1 = c + hw
	_front(wall, f, a0, a1, yb, s, 0.0)
	_front(wall, f, a0, a1, t, yt, 0.0)
	_flat(wall, f, a0, a1, t, -W, 0.0, false)
	_slab(trim, f, a0 - 0.1, a1 + 0.1, s - 0.14, s, 0.0, 0.13)
	_flat(trim, f, a0, a1, s, -W, 0.0, true)
	_slab(trim, f, a0 - 0.1, a1 + 0.1, t, t + 0.16, 0.0, 0.09)
	var k := rng.randf()
	if k < 0.5:
		_front("void", f, a0, a1, s, t, -W)
	elif k < 0.72:
		_front("void", f, a0, a1, s, t, -W)
		_boards(f, a0, a1, s, t)
	elif k < 0.9:
		_front("window", f, a0, a1, s, t, -W + 0.08)
		_slab(trim, f, c - 0.03, c + 0.03, s, t, -W + 0.08, -W + 0.13)      # the glazing bars
		_slab(trim, f, a0, a1, (s + t) * 0.5 - 0.03, (s + t) * 0.5 + 0.03, -W + 0.08, -W + 0.13)
	elif k < 0.985:
		_front("planks", f, a0, a1, s, t, -W + 0.1)      # shutters, closed for good
		_slab("planks", f, c - 0.02, c + 0.02, s, t, -W + 0.1, -W + 0.13)
	else:
		_front("candle", f, a0, a1, s, t, -W)            # someone is in


## planks nailed across a hole, none of them level
func _boards(f: Face, a0: float, a1: float, s: float, t: float) -> void:
	var n := 2 + rng.randi() % 3
	for k in n:
		var yy := s + (t - s) * (k + 0.5 + rng.randf_range(-0.25, 0.25)) / n
		var tilt := rng.randf_range(-0.14, 0.14)
		var hh := rng.randf_range(0.09, 0.14)
		var p0 := f.at(a0 - 0.12, yy - hh - tilt, -0.1)
		var p1 := f.at(a1 + 0.12, yy - hh + tilt, -0.1)
		var p2 := f.at(a1 + 0.12, yy + hh + tilt, -0.1)
		var p3 := f.at(a0 - 0.12, yy + hh - tilt, -0.1)
		_q("planks", p0, p1, p2, p3, f.out())


## a zigzag of iron landings and ladders up one bay
func _fire_escape(f: Face, y: float, bay: int) -> void:
	var a0 := CORNER + bay * f.bw + 0.2
	var a1 := a0 + f.bw - 0.4
	for fl in range(1, f.heights[bay]):
		var yy := y + GH + (fl - 1) * FH + 0.75
		_slab("rust", f, a0, a1, yy - 0.06, yy, 0.0, 1.15)
		_slab("rust", f, a0, a1, yy + 0.95, yy + 1.0, 1.1, 1.15)
		_slab("rust", f, a0, a1, yy + 0.5, yy + 0.53, 1.1, 1.15)
		for u: float in [a0, a1 - 0.05]:
			_slab("rust", f, u, u + 0.05, yy, yy + 1.0, 1.1, 1.15)
			_slab("rust", f, u, u + 0.05, yy + 0.95, yy + 1.0, 0.0, 1.15)
		var lu := a0 + 0.3 if fl % 2 == 0 else a1 - 0.75      # the ladder down to the landing below
		var low := yy - FH if fl > 1 else y + 2.6             # (the last one stops short of the street, as they do)
		for u: float in [lu, lu + 0.42]:
			_slab("rust", f, u, u + 0.04, low, yy, 0.55, 0.59)
		var ry := low + 0.2
		while ry < yy - 0.1:
			_slab("rust", f, lu, lu + 0.46, ry, ry + 0.03, 0.55, 0.59)
			ry += 0.33


## what stands on a roof: a water tank on legs, a stair head, chimney stacks
func _roof_things(x0: float, x1: float, z0: float, z1: float, top: float) -> void:
	var was_base := b.base_y
	b.base_y = top - 2.0
	var k := rng.randi() % 3
	var cx := rng.randf_range(x0 + 2.5, x1 - 2.5)
	var cz := rng.randf_range(z0 + 2.5, z1 - 2.5)
	if k == 0:
		for sx: float in [-0.9, 0.9]:
			for sz: float in [-0.9, 0.9]:
				b.box("rust", cx + sx - 0.07, cx + sx + 0.07, top, top + 1.6, cz + sz - 0.07, cz + sz + 0.07, false, false)
		b.box("planks", cx - 1.15, cx + 1.15, top + 1.6, top + 3.6, cz - 1.15, cz + 1.15, false)
		b.box("iron", cx - 1.3, cx + 1.3, top + 3.6, top + 3.72, cz - 1.3, cz + 1.3, false)
	elif k == 1:
		b.box("inner", cx - 1.6, cx + 1.6, top, top + 2.6, cz - 1.3, cz + 1.3, false, false)
		b.box("roof", cx - 1.75, cx + 1.75, top + 2.6, top + 2.75, cz - 1.45, cz + 1.45, false)
	else:
		for n in 2 + rng.randi() % 2:
			var px := cx + n * 0.9
			b.box("inner", px - 0.3, px + 0.3, top, top + rng.randf_range(1.2, 2.2), cz - 0.3, cz + 0.3, false, false)
	b.base_y = was_base


## What came down: a heap of broken masonry `r` across, with a few pieces big enough to stand in the way
func heap(cx: float, cz: float, r: float, y: float, wall: String = "debris") -> void:
	var was_base := b.base_y
	b.base_y = y
	b.grow = 0.25
	for k in 16:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * r
		var hx := rng.randf_range(0.25, 0.95) * (1.0 - 0.4 * d / r)
		var hz := rng.randf_range(0.2, 0.7)
		var hh := rng.randf_range(0.2, 1.0) * (1.0 - 0.6 * d / r)
		b.turned("debris" if rng.randf() < 0.65 else wall, cx + cos(a) * d, cz + sin(a) * d, hx, hz, y - 0.05, y + hh, rng.randf() * TAU, Vector2(rng.randf_range(-0.25, 0.25), rng.randf_range(-0.2, 0.2)))
	b.world.add({"kind": "disc", "cx": cx, "cz": cz, "r": r * 0.5, "bottom": y, "top": y + 0.55, "tag": "rubble"})
	b.grow = 0.0
	b.base_y = was_base
