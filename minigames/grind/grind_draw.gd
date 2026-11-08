class_name GrindDraw
extends Node2D
## RAILJACK's scene (JS GrindSession's camera, projection and draw* methods): the wireframe void painted far to near into the low-res buffer, with the JS's own hand projection. The city is hashed once per 40 m cell instead of once per frame.

const EDGES: Array[int] = [0, 1, 1, 2, 2, 3, 3, 0, 4, 5, 5, 6, 6, 7, 7, 4, 0, 4, 1, 5, 2, 6, 3, 7]
const CELL := 40.0
const CITY := 640.0

var S: GrindSession = null
var W := 660
var H := 380
var has_eye := false
# the camera
var ex := 0.0
var ey := 0.0
var ez := 0.0
var fx_ := 0.0
var fy_ := 0.0
var fz_ := 0.0
var rx := 0.0
var ry := 0.0
var rz := 0.0
var ux := 0.0
var uy := 0.0
var uz := 0.0
var F := 0.0
var W2 := 0.0
var H2 := 0.0
var shx := 0.0
var shy := 0.0
# project()'s answer
var px := 0.0
var py := 0.0
var ps := 0.0
var pd := 0.0
# eight projected corners
var _pt := PackedVector2Array()
var _s0 := 0.0
var _edge_buf := PackedVector2Array()
var _cells := {}
var _canvas := RID()
var _quad_i := PackedInt32Array([0, 1, 2, 0, 2, 3])
var _fan := {}


class Block:
	var z0 := 0.0
	var z1 := 0.0
	var x0 := 0.0
	var x1 := 0.0
	var y0 := 0.0
	var y1 := 0.0
	var seed_ := 0
	var win := false
	var wob_a := 0.0     # BLACK ICE: the block sways
	var wob_s := 0.0
	var flick := false


func _ready() -> void:
	_pt.resize(8)
	_edge_buf.resize(24)
	_canvas = get_canvas_item()
	for n in range(3, 9):
		var a := PackedInt32Array()
		for i in range(1, n - 1):
			a.append_array([0, i, i + 1])
		_fan[n] = a


func _rgba(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)


# ---- camera + projection (world: x right, y up, z down the line) ----
func setup_camera() -> void:
	var p := S.p
	var c := S.cam
	var q: float = c.intro
	var it := q * q * (3.0 - 2.0 * q)
	var pz := p.z
	var ez0 := pz - 6.4 - it * 10.0
	ex = S.cx(ez0) + c.x
	ey = S.cy(ez0) + 2.5 + c.y + it * 7.0
	ez = ez0
	var tz := pz + 16.0
	var t := Vector3(S.cx(tz) + c.x * 0.9, S.cy(tz) + 0.55 + c.y * 0.6, tz)
	var f := (t - Vector3(ex, ey, ez)).normalized()
	var r := Vector3(f.z, 0.0, -f.x).normalized()      # up x f
	var u := Vector3(f.y * r.z - f.z * r.y, f.z * r.x - f.x * r.z, f.x * r.y - f.y * r.x)      # f x r
	var cr := cos(float(c.roll))
	var sr := sin(float(c.roll))
	rx = r.x * cr + u.x * sr
	ry = r.y * cr + u.y * sr
	rz = r.z * cr + u.z * sr
	ux = u.x * cr - r.x * sr
	uy = u.y * cr - r.y * sr
	uz = u.z * cr - r.z * sr
	fx_ = f.x
	fy_ = f.y
	fz_ = f.z
	F = H * 0.92
	W2 = W / 2.0
	H2 = H * 0.5
	var sh := S.shake * S.shake * 10.0
	shx = (randf() - 0.5) * sh
	shy = (randf() - 0.5) * sh
	has_eye = true


func project(x: float, y: float, z: float) -> bool:
	var dx := x - ex
	var dy := y - ey
	var dz := z - ez
	var d := dx * fx_ + dy * fy_ + dz * fz_
	if d < 0.35:
		return false
	var s := F / d
	px = W2 + (dx * rx + dy * ry + dz * rz) * s + shx
	py = H2 - (dx * ux + dy * uy + dz * uz) * s + shy
	ps = s
	pd = d
	return true


func fog(z: float) -> float:
	return clampf(1.0 - (z - S.p.z - 70.0) / (GrindSession.FAR - 70.0), 0.0, 1.0)


func lane_x(l: int, z: float) -> float:
	return S.cx(z) + l * GrindSession.LANE_W


func _seg(x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, col: Color, w: float) -> void:
	if not project(x0, y0, z0):
		return
	var ax := px
	var ay := py
	if not project(x1, y1, z1):
		return
	draw_line(Vector2(ax, ay), Vector2(px, py), col, w)


## a line whose colour runs from c0 to c1 (createLinearGradient along the stroke)
func _gline(a: Vector2, b: Vector2, c0: Color, c1: Color, w: float) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.01:
		return
	var n := Vector2(-d.y, d.x) / l * w * 0.5
	draw_primitive(PackedVector2Array([a + n, b + n, b - n, a - n]), PackedColorArray([c0, c1, c1, c0]), PackedVector2Array())


## lineCap round: the JS strokes overlap by half a width at every joint, and those overlaps are part of how bright the rail reads
func _capped(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.001:
		return
	d *= w * 0.5 / l
	draw_line(a - d, b + d, col, w)


func _poly(pts: PackedVector2Array, col: Color) -> void:
	var n := pts.size()
	if n < 3:
		return
	if not _fan.has(n):
		var a := PackedInt32Array()
		for i in range(1, n - 1):
			a.append_array([0, i, i + 1])
		_fan[n] = a
	RenderingServer.canvas_item_add_triangle_array(_canvas, _fan[n], pts, PackedColorArray([col]))


func _quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, col: Color) -> void:
	draw_primitive(PackedVector2Array([a, b, c, d]), PackedColorArray([col]), PackedVector2Array())


# ---- rendering ----
func _draw() -> void:
	if S == null or S.ph.is_empty():
		return
	setup_camera()
	draw_rect(Rect2(0, 0, W, H), Color8(1, 5, 2))
	draw_sky()
	draw_floor()
	draw_rails()
	# everything standing on the lines, far to near, with the packet slotted in at its depth
	var p := S.p
	var list: Array[Array] = []
	var obs := S.obs
	while S._vis_ob < obs.size() and obs[S._vis_ob].z < p.z - 3.0:
		S._vis_ob += 1
	for i in range(S._vis_ob, obs.size()):
		var o := obs[i]
		if o.z >= p.z + GrindSession.FAR:
			break
		var z := S.runner_z(o) if o.type == &"runner" else o.z
		if z > p.z - 3.0 and z < p.z + GrindSession.FAR:
			list.append([z, 0, o])
	var bits := S.bits
	while S._vis_bit < bits.size() and bits[S._vis_bit].z <= p.z - 1.0:
		S._vis_bit += 1
	for i in range(S._vis_bit, bits.size()):
		var q := bits[i]
		if q.z >= p.z + GrindSession.FAR:
			break
		if not q.got:
			list.append([q.z, 1, q])
	list.append([p.z, 2, null])
	if S.gate_z < p.z + GrindSession.FAR + 40.0:
		list.append([S.gate_z, 3, null])
	list.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for it: Array in list:
		match it[1]:
			0:
				draw_obstacle(it[2], it[0])
			1:
				draw_bit(it[2])
			2:
				draw_packet()
			3:
				draw_gate()
	draw_parts()


func draw_sky() -> void:
	var COL := S.COL
	if not project(ex - 4000.0, ey, ez + 6000.0):
		return
	var q1 := Vector2(px, py)
	if not project(ex + 4000.0, ey, ez + 6000.0):
		return
	var q2 := Vector2(px, py)
	var hy := (q1.y + q2.y) / 2.0
	var ang := atan2(q2.y - q1.y, q2.x - q1.x)
	var fw := float(W)
	var fh := float(H)
	draw_set_transform(Vector2(fw / 2.0, hy), ang)
	var c1 := S.tcol(30, 120, 60, 0.28)
	var c0 := Color(c1.r, c1.g, c1.b, 0.0)      # (the JS's top stop is a black-green at zero alpha: the same fade)
	draw_primitive(PackedVector2Array([Vector2(-fw, -fh * 0.6), Vector2(fw, -fh * 0.6), Vector2(fw, 0), Vector2(-fw, 0)]), PackedColorArray([c0, c0, c1, c1]), PackedVector2Array())
	# the "moon": a phosphor disc cut by scan slots, parked over the far end of the line
	var mr := fh * 0.17
	var my := -fh * 0.2
	var ph0 := fmod(S.ph[0] * 30.0, 40.0)
	var mx := ph0 - 20.0
	for k in 14:
		var y0 := my - mr + k * mr * 2.0 / 14.0
		var gap := maxf(0.0, (k - 6) * 0.9)
		var y1 := y0 + mr * 2.0 / 14.0 - gap
		var w0 := sqrt(maxf(0.0, mr * mr - (y0 - my) * (y0 - my)))
		var w1 := sqrt(maxf(0.0, mr * mr - (y1 - my) * (y1 - my)))
		_quad(Vector2(mx - w0, y0), Vector2(mx + w0, y0), Vector2(mx + w1, y1), Vector2(mx - w1, y1), _rgba(COL.solid, 0.1 + 0.025 * k))
	draw_arc(Vector2(mx, my), mr, PI, TAU, 32, _rgba(COL.solid, 0.35), 1.0)
	draw_set_transform(Vector2.ZERO)
	# far skyline of data monoliths: wireframe outlines that ride with the camera (they only swing as the line bends)
	var body := Color(2 / 255.0, 10 / 255.0, 5 / 255.0, 0.95)
	var edge := _rgba(COL.grid, 0.42)
	var slit := _rgba(COL.dim, 0.25)
	var base := S.cy(ez) - 60.0
	for t: Dictionary in S.towers:
		var z: float = ez + t.z
		var x: float = ex + t.x
		var tw: float = t.w
		var tx: float = t.x
		var y1: float = base + 60.0 + t.h
		if not project(x - tw / 2.0, base, z):
			continue
		var a := Vector2(px, py)
		if not project(x + tw / 2.0, y1, z):
			continue
		var c := Vector2(px, py)
		if not project(x + tw / 2.0, y1, z + t.d):
			continue
		var d2 := Vector2(px, py)
		if not project(x - tw / 2.0, y1, z + t.d):
			continue
		var a2 := Vector2(px, py)
		if a.x > fw or c.x < 0.0:      # (off the sides of the buffer)
			continue
		draw_rect(Rect2(a.x, c.y, c.x - a.x, a.y - c.y), body)
		draw_rect(Rect2(a.x, c.y, c.x - a.x, a.y - c.y), edge, false, 1.0)
		draw_polyline(PackedVector2Array([Vector2(a.x, c.y), a2, d2, c]), edge, 1.0)
		var yy := c.y + 4.0
		while yy < a.y:
			if int(yy * 7.0 + tx) % 3 == 0:
				draw_rect(Rect2(a.x + 2.0, yy, maxf(1.0, (c.x - a.x) * 0.3), 1.0), slit)
			yy += 5.0
	# horizon line
	draw_set_transform(Vector2(fw / 2.0, hy), ang)
	draw_line(Vector2(-fw, 0), Vector2(fw, 0), _rgba(COL.solid, 0.5), 1.0)
	draw_set_transform(Vector2.ZERO)
	draw_city()


func _hs(k: int, n: int) -> float:
	var h := (CrtKit.imul(k, 374761393) + CrtKit.imul(n, 668265263) + S.seed_n) & 0xFFFFFFFF
	h = CrtKit.imul(h ^ (h >> 13), 1274126177)
	return float((h ^ (h >> 16)) & 0xFFFFFFFF) / 4294967296.0


## one 40 m cell of the near city, from its hash: the same blocks are there every pass, nearest last
func _cell(k: int) -> Array[Block]:
	var ti := S.ti
	var items: Array[Block] = []
	var add := func(z0: float, x0: float, x1: float, y0: float, y1: float, z1: float, sd: int, win: bool) -> Block:
		var b := Block.new()
		b.z0 = z0
		b.x0 = x0
		b.x1 = x1
		b.y0 = y0
		b.y1 = y1
		b.z1 = z1
		b.seed_ = sd
		b.win = win
		items.append(b)
		return b
	var ARCH: float = [0.1, 0.3, 0.16, 0.42][ti]
	var PR: Array = [[0.8, 0.45, 0.0], [0.9, 0.85, 0.7], [0.55, 0.8, 0.6], [0.9, 0.8, 0.8]][ti]
	for side: int in [-1, 1]:
		for i in 3:
			var n := (20 if side > 0 else 0) + i * 6
			var r0 := _hs(k, n)
			# CIVILIAN: office blocks. CORPORATE: server-rack canyon. MILITARY: bunkers and needle spires. BLACK: a collapsing nightmare
			if r0 > float(PR[i]):
				continue
			var sd := k * 31 + n
			var h1 := _hs(k, n + 1)
			var h2 := _hs(k, n + 2)
			var h3 := _hs(k, n + 3)
			var h4 := _hs(k, n + 4)
			var h5 := _hs(k, n + 5)
			var o := 0.0
			var w := 0.0
			var d := 0.0
			var ht := 0.0
			var fy := 0.0
			var fl := 0
			if ti == 0:
				o = 12.0 + h1 * (90.0 if i != 0 else 36.0)
				w = 8.0 + h2 * 30.0
				d = 12.0 + h3 * 26.0
				ht = 14.0 + h5 * h5 * 190.0
			elif ti == 1:
				o = 10.0 + i * 9.0 + h1 * 6.0
				w = 3.0 + h2 * 3.0
				d = 10.0 + h3 * 20.0
				ht = 22.0 + h5 * 70.0
			elif ti == 2:
				if i == 1:
					o = 14.0 + h1 * 40.0
					w = 1.2 + h2 * 1.6
					d = 1.6 + h3 * 1.6
					ht = 120.0 + h5 * 260.0
				else:
					o = 13.0 + h1 * 60.0
					w = 20.0 + h2 * 34.0
					d = 16.0 + h3 * 30.0
					ht = 8.0 + h5 * 26.0
			else:
				var kind := h5      # 0..0.4 monolith  0.4..0.7 hanging spike  0.7..1 floating shard
				o = 11.0 + h1 * (120.0 if i != 0 else 44.0)
				w = 3.0 + h2 * 24.0 * (1.0 if kind < 0.4 else 0.5)
				d = 4.0 + h3 * 30.0
				if kind < 0.4:
					ht = 40.0 + h4 * h4 * 320.0
				elif kind < 0.7:
					ht = 40.0 + h4 * 200.0
					fl = 2
				else:
					ht = 3.0 + h4 * 16.0
					fl = 1
					fy = 4.0 + h4 * 70.0
			var z0 := k * CELL + h4 * (CELL - minf(d, CELL - 1.0))
			var zm := z0 + d / 2.0
			var cm := S.cx(zm)
			var a := cm - o - w if side < 0 else cm + o
			var base := S.cy(zm) - 42.0
			var b: Block
			if fl == 2:      # hangs from the ceiling
				b = add.call(z0, a, a + w, base + 190.0 - ht, base + 190.0, z0 + d, sd, true)
			elif fl == 1:      # floats mid-air
				b = add.call(z0, a, a + w, base + 42.0 + fy, base + 42.0 + fy + ht, z0 + d, sd, false)
			else:
				b = add.call(z0, a, a + w, base, base + ht, z0 + d, sd, true)
			if ti == 3:
				b.flick = true
				if h1 > 0.5:
					b.wob_a = 2.0 + h2 * 4.0
				b.wob_s = sd
	if _hs(k, 90) < ARCH:
		var z0 := k * CELL + 18.0
		var cxm := S.cx(z0 + 1.5)
		var fy := S.cy(z0) - 42.0
		var ty := S.cy(z0) + 14.0 + (_hs(k, 91) * 10.0 if ti == 3 else 0.0)
		var sd := k
		add.call(z0, cxm - 17.0, cxm - 14.6, fy, ty + 2.0, z0 + 3.0, sd, false)
		add.call(z0, cxm + 14.6, cxm + 17.0, fy, ty + 2.0, z0 + 3.0, sd + 1, false)
		add.call(z0, cxm - 17.0, cxm + 17.0, ty, ty + 2.0, z0 + 3.0, sd + 2, false)
		if ti >= 2:      # a second beam: a laser fence
			add.call(z0, cxm - 17.0, cxm + 17.0, ty + 7.0, ty + 7.8, z0 + 3.0, sd + 3, false)
		if ti == 3:
			add.call(z0, cxm - 17.0, cxm + 17.0, ty - 0.2 - (_hs(k, 92) * 4.0), ty + 0.2 - (_hs(k, 92) * 4.0) + 0.6, z0 + 3.0, sd + 4, false)
	items.sort_custom(func(p1: Block, p2: Block) -> bool: return p1.z0 > p2.z0)
	return items


## the near city: wireframe data-blocks standing in the world on both sides of the line (rooted in the data sea, some taller than the track). They sweep past with real parallax and gantry arches span the line now and then, so the packet flies through architecture instead of in front of a painted backdrop.
func draw_city() -> void:
	var k0 := floori((ez + 2.0) / CELL)
	var k1 := floori((ez + CITY) / CELL)
	for k: int in _cells.keys():
		if k < k0:
			_cells.erase(k)
	var t := S.time
	for k in range(k1, k0 - 1, -1):      # (a block's z stays inside its cell: far cell to near is far block to near)
		if not _cells.has(k):
			_cells[k] = _cell(k)
		for b: Block in _cells[k]:
			if b.flick and (int(t * 9.0 + b.seed_) % 23 == 0):      # the odd block drops out for a frame: flicker
				continue
			draw_block(b, sin(t * 1.3 + b.wob_s) * b.wob_a if b.wob_a != 0.0 else 0.0)


func _corners(x0: float, x1: float, y0: float, y1: float, z0: float, z1: float) -> bool:
	if not project(x0, y0, z0):
		return false
	_pt[0] = Vector2(px, py)
	_s0 = ps
	if not project(x1, y0, z0):
		return false
	_pt[1] = Vector2(px, py)
	if not project(x1, y1, z0):
		return false
	_pt[2] = Vector2(px, py)
	if not project(x0, y1, z0):
		return false
	_pt[3] = Vector2(px, py)
	if not project(x0, y0, z1):
		return false
	_pt[4] = Vector2(px, py)
	if not project(x1, y0, z1):
		return false
	_pt[5] = Vector2(px, py)
	if not project(x1, y1, z1):
		return false
	_pt[6] = Vector2(px, py)
	if not project(x0, y1, z1):
		return false
	_pt[7] = Vector2(px, py)
	return true


func draw_block(q: Block, wob: float) -> void:
	var f := clampf(1.0 - (q.z0 - ez) / CITY, 0.0, 1.0)
	if f <= 0.02:
		return
	var x0 := q.x0 + wob
	var x1 := q.x1 + wob
	if not _corners(x0, x1, q.y0, q.y1, q.z0, q.z1):
		return
	var c := _pt
	var stroke := _rgba(S.COL.grid, 0.15 + 0.5 * f)
	var fill := Color(2 / 255.0, 10 / 255.0, 5 / 255.0, 0.97)
	_face(c[0], c[1], c[2], c[3], fill, stroke)
	if ex > x1:
		_face(c[1], c[5], c[6], c[2], fill, stroke)
	elif ex < x0:
		_face(c[0], c[4], c[7], c[3], fill, stroke)
	if ey > q.y1:
		_face(c[3], c[2], c[6], c[7], fill, stroke)
	elif ey < q.y0:
		_face(c[0], c[1], c[5], c[4], fill, stroke)
	if not q.win or f < 0.12:
		return
	# lit window slits (world-spaced rows, a hash picks which are on) on the faces that face the camera
	var rows := mini(36, floori((q.y1 - q.y0) / 4.5))
	var wc := _rgba(S.COL.dim, 0.18 + 0.4 * f)
	for r in range(1, rows):
		var t := float(r) / rows
		var lit := (q.seed_ * 7 + r * 13) % 5
		if lit > 2:
			continue
		var yL := c[0].y + (c[3].y - c[0].y) * t
		var yR := c[1].y + (c[2].y - c[1].y) * t
		var xL := c[0].x + (c[3].x - c[0].x) * t
		var xR := c[1].x + (c[2].x - c[1].x) * t
		if xR - xL < 8.0:
			break
		draw_rect(Rect2(xL + (xR - xL) * 0.12, minf(yL, yR), (xR - xL) * (0.2 + 0.15 * lit), 1.0), wc)


func _face(a: Vector2, b: Vector2, c: Vector2, d: Vector2, fill: Color, stroke: Color) -> void:
	_quad(a, b, c, d, fill)
	draw_polyline(PackedVector2Array([a, b, c, d, a]), stroke, 1.0)


func draw_floor() -> void:
	var COL := S.COL
	# the data sea far below: a grid anchored to the world, so it streams past
	var fy := S.cy(ez) - 42.0
	var z := ceilf((ez + 6.0) / 14.0) * 14.0
	while z < ez + 520.0:
		_seg(ex - 260.0, fy, z, ex + 260.0, fy, z, _rgba(COL.grid, 0.32 * clampf(1.0 - (z - ez) / 520.0, 0.0, 1.0)), 1.0)
		z += 14.0
	var x := floorf((ex - 260.0) / 14.0) * 14.0
	var c0 := _rgba(COL.grid, 0.34)
	var c1 := _rgba(COL.grid, 0.0)
	while x < ex + 260.0:
		if project(x, fy, ez + 8.0):
			var a := Vector2(px, py)
			if project(x, fy, ez + 520.0):
				_gline(a, Vector2(px, py), c0, c1, 1.0)
		x += 14.0
	# data streaks rising out of the void past the line
	var p := S.p
	for s: Dictionary in S.streaks:
		var sx: float = s.x
		if absf(sx) < 6.0:
			continue
		var sz: float = s.z
		var zz := p.z - 8.0 + fposmod(sz - p.z * 0.6, 200.0)
		var xx := S.cx(zz) + sx
		var yy: float = S.cy(zz) + float(s.y)
		_seg(xx, yy, zz, xx, yy, zz + 3.0 + S.v * 0.12, _rgba(COL.dim, 0.35 * fog(zz)), 1.0)


func draw_rails() -> void:
	var p := S.p
	var COL := S.COL
	var zA := p.z - 7.0
	var zB := p.z + GrindSession.FAR
	var t := Time.get_ticks_msec() / 1000.0
	var pts := PackedVector3Array()
	for l in range(-1, 2):
		for s: GrindSession.Rail in S.rails[l + 1]:
			if s.z1 < zA or s.z0 > zB:
				continue
			var a := maxf(zA, s.z0)
			var e := minf(zB, s.z1)
			var on_it := l == p.lane
			# supports dropping into the void every 24 m
			var z := ceilf(a / 24.0) * 24.0
			while z < e:
				var x := lane_x(l, z)
				var y := S.cy(z)
				if project(x, y - 0.1, z):
					var A := Vector2(px, py)
					if project(x, y - 16.0, z):
						_gline(A, Vector2(px, py), _rgba(COL.grid, 0.5 * fog(z)), _rgba(COL.grid, 0.0), 1.0)
				z += 24.0
			# ties every 3 m (world-anchored: they stream past and sell the speed)
			z = ceilf(a / 3.0) * 3.0
			while z < e:
				var x := lane_x(l, z)
				var y := S.cy(z)
				if project(x - 0.45, y - 0.05, z):
					var A := Vector2(px, py)
					var w := maxf(1.0, ps * 0.06)
					if project(x + 0.45, y - 0.05, z):
						draw_line(A, Vector2(px, py), _rgba(COL.gap, 0.9 * fog(z)), w)
				z += 3.0
			# the line itself: sampled finer up close, glow pass then core pass
			pts.clear()
			z = a
			while true:
				var zz := minf(z, e)
				if project(lane_x(l, zz), S.cy(zz), zz):
					pts.append(Vector3(px, py, ps))
					pts.append(Vector3(fog(zz), 0.0, 0.0))
				if zz >= e:
					break
				z += 1.5 if z - p.z < 30.0 else 4.0
			var n := pts.size() / 2
			var core: Color = COL.white if on_it else COL.solid
			for i in range(1, n):      # the glow pass
				var q1 := pts[i * 2]
				var q0 := pts[i * 2 - 2]
				var w := clampf(q1.z * 0.09, 1.0, 3.2)
				_capped(Vector2(q0.x, q0.y), Vector2(q1.x, q1.y), _rgba(COL.solid, 0.22 * pts[i * 2 + 1].x), w * 4.0)
			for i in range(1, n):      # the core pass
				var q1 := pts[i * 2]
				var q0 := pts[i * 2 - 2]
				var w := clampf(q1.z * 0.09, 1.0, 3.2)
				_capped(Vector2(q0.x, q0.y), Vector2(q1.x, q1.y), _rgba(core, 0.95 * pts[i * 2 + 1].x), w)
			# a line being written: a bright head where it starts; an amber EOF terminator where it stops
			if s.z0 > zA and s.z0 > 40.0 and project(lane_x(l, s.z0), S.cy(s.z0), s.z0):
				var r := maxf(1.5, ps * 0.35)
				var c := Vector2(px, py)
				draw_polyline(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0), c + Vector2(0, -r)]), _rgba(COL.white, 0.9 * fog(s.z0)), 1.0)
			if s.z1 < zB and s.z1 < S.gate_z + 100.0:
				var blink := 1.0 if sin(t * 14.0) > 0.0 else 0.45
				var x := lane_x(l, s.z1)
				var y := S.cy(s.z1)
				box(x - 0.35, x + 0.35, y - 0.25, y + 0.35, s.z1 - 0.3, s.z1, COL.fire, 0.35 * blink, 0.95 * blink, fog(s.z1))
				# chevrons on the last stretch of a line that is about to run out
				for k in range(1, 5):
					var zc := s.z1 - k * 2.2
					if zc < s.z0 or zc < zA:
						break
					var lx := lane_x(l, zc)
					var ly := S.cy(zc) + 0.02
					if not project(lx - 0.4, ly, zc - 0.6):
						continue
					var A := Vector2(px, py)
					if not project(lx, ly, zc):
						continue
					var B := Vector2(px, py)
					var w := maxf(1.0, ps * 0.07)
					if not project(lx + 0.4, ly, zc - 0.6):
						continue
					draw_polyline(PackedVector2Array([A, B, Vector2(px, py)]), _rgba(COL.fire, 0.8 * blink * fog(zc)), w)


static func _hull(pts: PackedVector2Array) -> PackedVector2Array:
	var q := pts.duplicate()
	q.sort()
	var out := PackedVector2Array()
	out.resize(q.size() * 2)
	var k := 0
	for i in q.size():
		while k >= 2 and (out[k - 1] - out[k - 2]).cross(q[i] - out[k - 2]) <= 0.0:
			k -= 1
		out[k] = q[i]
		k += 1
	var t := k + 1
	for i in range(q.size() - 2, -1, -1):
		while k >= t and (out[k - 1] - out[k - 2]).cross(q[i] - out[k - 2]) <= 0.0:
			k -= 1
		out[k] = q[i]
		k += 1
	out.resize(maxi(k - 1, 0))
	return out


## a wireframe box with an opaque dark body (so it hides what is behind it) and glowing edges; _pt holds the projected corners
func box(x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, col: Color, fill_a: float, edge_a: float, fog_: float) -> bool:
	if not _corners(x0, x1, y0, y1, z0, z1):
		return false
	solid(col, fill_a, edge_a, fog_)
	return true


func solid(col: Color, fill_a: float, edge_a: float, fog_: float) -> void:
	var h := _hull(_pt)
	_poly(h, Color(2 / 255.0, 9 / 255.0, 4 / 255.0, 0.94 * fog_))
	if fill_a > 0.0:
		_poly(h, _rgba(col, fill_a * fog_))
	for i in 24:
		_edge_buf[i] = _pt[EDGES[i]]
	var w := maxf(1.0, _s0 * 0.04)
	draw_multiline(_edge_buf, _rgba(col, 0.25 * edge_a * fog_), w * 3.5)
	draw_multiline(_edge_buf, _rgba(col, edge_a * fog_), w)


## clip a segment to the convex quad a, b, c, d (the JS clips the path to the firewall's face)
static func _clip_quad(s0: Vector2, s1: Vector2, q: Array) -> PackedVector2Array:
	var t0 := 0.0
	var t1 := 1.0
	var d := s1 - s0
	var e0: Vector2 = q[1] - q[0]
	var e1: Vector2 = q[2] - q[0]
	var area := e0.cross(e1)
	var sgn := 1.0 if area >= 0.0 else -1.0
	for i in 4:
		var a: Vector2 = q[i]
		var e: Vector2 = q[(i + 1) % 4] - a
		var num := e.cross(s0 - a) * sgn
		var den := e.cross(d) * sgn
		if absf(den) < 1e-6:
			if num < 0.0:
				return PackedVector2Array()
			continue
		var u := -num / den
		if den > 0.0:
			t0 = maxf(t0, u)
		else:
			t1 = minf(t1, u)
		if t0 > t1:
			return PackedVector2Array()
	return PackedVector2Array([s0 + d * t0, s0 + d * t1])


func draw_obstacle(o: GrindSession.Obs, z: float) -> void:
	var COL := S.COL
	var d: Dictionary = GrindSession.OB[o.type]
	var x := lane_x(o.lane, z)
	var y := S.cy(z)
	var f := fog(z)
	var t := Time.get_ticks_msec() / 1000.0
	var col: Color = COL.gap if o.hit else (COL.red if o.type == &"runner" else COL.fire)
	var dw: float = d.w
	var dd: float = d.d
	var h0: float = d.h0
	var h1: float = d.h1
	if o.type == &"low":
		# FIREWALL: a knee-high barrier with hazard slashes
		if not box(x - dw / 2.0, x + dw / 2.0, y, y + h1, z - dd / 2.0, z + dd / 2.0, col, 0.12, 0.95, f):
			return
		var P := _pt
		var q: Array = [P[0], P[1], P[2], P[3]]
		var ws := _rgba(col, 0.55 * f)
		var lw := maxf(1.0, _s0 * 0.08)
		var wpx := P[1].x - P[0].x
		var hpx := P[0].y - P[3].y
		for k in range(-2, 8):
			var sx := P[3].x + (k / 6.0) * wpx
			var c := _clip_quad(Vector2(sx, P[0].y), Vector2(sx + hpx, P[3].y), q)
			if c.size() == 2:
				draw_line(c[0], c[1], ws, lw)
	elif o.type == &"high":
		# SCAN GATE: two posts and a lintel; a curtain of scan lines from shin height up
		var pw := 0.18
		var hw := dw / 2.0
		box(x - hw - pw, x - hw, y, y + h1 + 0.2, z - 0.15, z + 0.15, col, 0.1, 0.9, f)
		box(x + hw, x + hw + pw, y, y + h1 + 0.2, z - 0.15, z + 0.15, col, 0.1, 0.9, f)
		if not box(x - hw - pw, x + hw + pw, y + h1, y + h1 + 0.25, z - 0.15, z + 0.15, col, 0.15, 0.9, f):
			return
		var flick := 0.3 if o.hit else 0.6 + 0.4 * sin(t * 31.0 + o.z)
		var yy := h0
		var lc := _rgba(col, 0.5 * flick * f)
		while yy < h1:
			if project(x - hw, y + yy, z):
				var A := Vector2(px, py)
				var w := maxf(1.0, ps * 0.03)
				if project(x + hw, y + yy, z):
					draw_line(A, Vector2(px, py), lc, w)
			yy += 0.22
		var sy := y + h0 + fposmod(t * 2.2 + o.z, 1.0) * (h1 - h0)      # the sweep
		if project(x - hw, sy, z):
			var A := Vector2(px, py)
			var w := maxf(1.0, ps * 0.06)
			if project(x + hw, sy, z):
				draw_line(A, Vector2(px, py), _rgba(COL.white, 0.8 * f * flick), w)
		if project(x - hw, y + h0, z):
			var A := Vector2(px, py)
			var w := maxf(1.0, ps * 0.05)
			if project(x + hw, y + h0, z):
				draw_line(A, Vector2(px, py), _rgba(col, 0.95 * f), w)
	elif o.type == &"wall":
		# ICE BLOCK: a slab across the whole line, crossed out, with a grid on its face
		if not box(x - dw / 2.0, x + dw / 2.0, y - 0.3, y + h1, z - dd / 2.0, z + dd / 2.0, col, 0.14, 1.0, f):
			return
		var P := _pt
		var w := maxf(1.0, _s0 * 0.05)
		draw_line(P[0], P[2], _rgba(col, 0.85 * f), w)
		draw_line(P[1], P[3], _rgba(col, 0.85 * f), w)
		var g := PackedVector2Array()
		for k in range(1, 4):
			var tt := k / 4.0
			g.append(P[0].lerp(P[1], tt))
			g.append(P[3].lerp(P[2], tt))
			g.append(P[0].lerp(P[3], tt))
			g.append(P[1].lerp(P[2], tt))
		draw_multiline(g, _rgba(col, 0.25 * f), 1.0)
	elif o.type == &"runner":
		# TRACER: a spinning red octahedron running down the line at you, trailing its own wake
		var r := 0.55
		var cyy := y + 0.45
		var spin := t * 7.0
		var cs := cos(spin)
		var sn := sin(spin)
		var pts := PackedVector2Array()
		var s0 := 0.0
		for ax: Array in [[r, 0.0, 0.0], [-r, 0.0, 0.0], [0.0, r, 0.0], [0.0, -r, 0.0], [0.0, 0.0, r], [0.0, 0.0, -r]]:
			if not project(x + ax[0] * cs - ax[2] * sn, cyy + ax[1], z + ax[0] * sn + ax[2] * cs):
				return
			if pts.is_empty():
				s0 = ps
			pts.append(Vector2(px, py))
		_poly(_hull(pts), Color(14 / 255.0, 2 / 255.0, 2 / 255.0, 0.9 * f))
		var seg := PackedVector2Array()
		for fc: Array in [[0, 2, 4], [0, 2, 5], [1, 2, 4], [1, 2, 5], [0, 3, 4], [0, 3, 5], [1, 3, 4], [1, 3, 5]]:
			seg.append(pts[fc[0]])
			seg.append(pts[fc[1]])
			seg.append(pts[fc[1]])
			seg.append(pts[fc[2]])
		draw_multiline(seg, _rgba(col, 0.95 * f), maxf(1.0, s0 * 0.04))
		for k in range(1, 5):
			if project(x, cyy, z + k * 1.4):
				var A := Vector2(px, py)
				var w := maxf(1.0, ps * 0.12)
				if project(x, cyy, z + k * 1.4 + 0.8):
					draw_line(A, Vector2(px, py), _rgba(col, (0.5 - k * 0.1) * f), w)


func draw_bit(q: GrindSession.BitQ) -> void:
	var COL := S.COL
	var x := lane_x(q.lane, q.z)
	var y := S.cy(q.z) + q.y
	var f := fog(q.z)
	var t := Time.get_ticks_msec() / 1000.0
	var r := 0.5 + 0.06 * sin(t * 7.0) if q.mystery else (0.42 if q.scrub else 0.24)
	var sp := t * (2.5 if q.mystery else 4.0) + q.z
	var cs := cos(sp)
	var sn := sin(sp)
	if not project(x, y + r, q.z):
		return
	var s0 := ps
	var a := Vector2(px, py)
	if not project(x + r * cs, y, q.z + r * sn):
		return
	var b := Vector2(px, py)
	if not project(x, y - r, q.z):
		return
	var c := Vector2(px, py)
	if not project(x - r * cs, y, q.z - r * sn):
		return
	var d := Vector2(px, py)
	var col: Color = COL.fire if q.mystery else (COL.white if q.scrub else COL.key)
	if q.mystery and project(x, y, q.z):
		var cc := Vector2(px, py)
		var s := ps
		for k in 2:
			draw_arc(cc, s * (0.9 + 0.5 * k + 0.1 * sin(t * 5.0)), 0.0, TAU, 24, _rgba(COL.fire, (0.6 - k * 0.25) * f * (0.5 + 0.5 * sin(t * 6.0 + k))), 1.0)
	_quad(a, b, c, d, _rgba(col, (0.55 if q.mystery else (0.5 if q.scrub else 0.25)) * f))
	draw_polyline(PackedVector2Array([a, b, c, d, a]), _rgba(col, 0.95 * f), maxf(1.0, s0 * 0.04))
	if q.scrub and project(x, y, q.z):
		draw_arc(Vector2(px, py), ps * 0.8, 0.0, TAU, 20, _rgba(COL.white, 0.5 * f * (0.5 + 0.5 * sin(t * 8.0))), 1.0)


func draw_packet() -> void:
	var COL := S.COL
	var p := S.p
	var z := p.z
	var duck := p.duck_t > 0.0
	var t := Time.get_ticks_msec() / 1000.0
	if p.inv > 0.0 and sin(t * 40.0) < 0.0 and S.phase == "play":
		return
	if S.phase == "boot":
		return
	# squash on landing, flatten + widen when shrunk, flip over on a jump, lean into a hop
	var CUBE := GrindSession.CUBE
	var sq := p.squash * 0.25
	var hy: float = GrindSession.DUCK_H / 2.0 if duck else CUBE / 2.0 * (1.0 - sq)
	var hx: float = 0.62 if duck else CUBE / 2.0 * (1.0 + sq * 0.6)
	var hz: float = 0.6 if duck else CUBE / 2.0
	var ox := S.cx(z) + p.x
	var oy := S.cy(z) + p.y + hy
	var cf := cos(p.flip)
	var sf := sin(p.flip)
	var lean := -p.lean * 0.35
	var cl := cos(lean)
	var sl := sin(lean)
	var i := 0
	for q: Array in [[-1, -1, -1], [1, -1, -1], [1, 1, -1], [-1, 1, -1], [-1, -1, 1], [1, -1, 1], [1, 1, 1], [-1, 1, 1]]:
		var x: float = q[0] * hx
		var y: float = q[1] * hy
		var zz: float = q[2] * hz
		var y2 := y * cf - zz * sf      # flip (about x)
		var z2 := y * sf + zz * cf
		y = y2
		zz = z2
		var x3 := x * cl - y * sl      # lean (about z)
		var y3 := x * sl + y * cl
		if not project(ox + x3, oy + y3, z + zz):
			return
		if i == 0:
			_s0 = ps
		_pt[i] = Vector2(px, py)
		i += 1
	solid(COL.red if S.phase == "fail" else COL.white, 0.12, 1.0, 1.0)
	# the core: a smaller glowing cube inside, pulsing with the beat
	var pulse := 0.5 + 0.5 * sin(t * 9.0)
	if project(ox, oy, z):
		var r := ps * (0.12 if duck else 0.18)
		draw_texture_rect(S.fx_nodes.core_tex(COL.white, COL.solid, 0.5 * pulse + 0.2), Rect2(px - r * 3.0, py - r * 3.0, r * 6.0, r * 6.0), false)
	# drop shadow on the line (a ring) so height reads while you jump
	if not p.ground and S.phase == "play":
		var ln := floori(p.x / GrindSession.LANE_W + 0.5)
		var has := S.rail_at(ln, z)
		if project(S.cx(z) + p.x, S.cy(z), z):
			draw_set_transform(Vector2(px, py), 0.0, Vector2(1.0, 0.24))
			draw_arc(Vector2.ZERO, ps * 0.5, 0.0, TAU, 24, _rgba(COL.solid if has else COL.red, 0.7), 1.0)
			draw_set_transform(Vector2.ZERO)


func draw_gate() -> void:
	var COL := S.COL
	var z := S.gate_z
	var x := S.cx(z)
	var y := S.cy(z)
	var f := fog(z)
	var t := Time.get_ticks_msec() / 1000.0
	# CORE PORT: nested octagonal frames you fly through
	for k in 4:
		var rz := z + k * 3.0
		var rr := 4.6 - k * 0.6
		var pts := PackedVector2Array()
		var s := 0.0
		for i in 8:
			var a := i / 8.0 * PI * 2.0 + PI / 8.0 + t * (0.4 if k % 2 != 0 else -0.4)
			if not project(x + cos(a) * rr, y + 1.4 + sin(a) * rr, rz):
				return
			pts.append(Vector2(px, py))
			s = ps
		pts.append(pts[0])
		draw_polyline(pts, _rgba(COL.white, (0.9 - k * 0.15) * f), maxf(1.0, s * 0.1))
	if project(x, y + 6.8, z):
		var sz := maxi(8, roundi(ps * 1.1))
		var fnt := CrtTheme.font(&"vt323")
		var w := fnt.get_string_size("CORE PORT", HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		draw_string(fnt, Vector2(px - w / 2.0, py), "CORE PORT", HORIZONTAL_ALIGNMENT_LEFT, -1, sz, _rgba(COL.white, 0.9 * f))


func draw_parts() -> void:
	for q: GrindSession.Part in S.parts:
		var z := q.z
		var x := S.cx(z) + q.x
		var y := S.cy(z) + q.y
		if not project(x, y, z):
			continue
		var A := Vector2(px, py)
		var w := maxf(1.0, ps * 0.03)
		if not project(x - q.vx * 0.02, y - q.vy * 0.02, z - (q.vz - S.v) * 0.02 - 0.05):
			continue
		draw_line(A, Vector2(px, py), _rgba(q.col, 0.9 * (1.0 - q.t / q.life)), w)
