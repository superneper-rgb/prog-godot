class_name OmFieldMast
extends RefCounted
## OMNISPHERE: one emitter mast of the docks' perimeter field (om_field.gd), built once at load and drawn as a MultiMesh: a tapered octagonal shaft bolted to the dock's flank, a deck bracket and a diagonal brace, a conduit up the magma side, hazard collars, an emitter housing every 2.9 m with lenses facing along the field, and a capped head under the beacon. Painted textures are generated at load (gunmetal panels with seams, rivets, rust and wear; chipped hazard stripes), with the light baked into the vertex colours and drawn unshaded, PS2 style (lit, the masts went black: this edge is in shadow, and the level's own art carries its light).
## NEW (user, 2026-11-09): not in the JS. Local frame: x runs along the field, +z points into the dock, y is the world height.

const STEEL := 0
const HAZARD := 1
const LENS := 2
const TILE := 2.0      # metres per texture repeat (the painted panel is 2 m tall)

var sts: Array[SurfaceTool] = []
var foot := 0.0
var floor_y := 0.0
var top := 0.0


## the mast's mesh: surface 0 steel, 1 hazard paint, 2 the emitter lenses (lens_mat, so the field can switch them off)
static func build(p_floor: float, p_top: float, lens_mat: Material) -> ArrayMesh:
	var b := OmFieldMast.new()
	b.floor_y = p_floor
	b.top = p_top
	b.foot = p_floor - 3.0
	for i in 3:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		b.sts.append(st)
	b._shape()
	var steel := StandardMaterial3D.new()
	steel.albedo_texture = _metal_tex()
	steel.vertex_color_use_as_albedo = true
	steel.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	steel.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var haz := StandardMaterial3D.new()
	haz.albedo_texture = _hazard_tex()
	haz.vertex_color_use_as_albedo = true
	haz.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	haz.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var mats: Array[Material] = [steel, haz, lens_mat]
	var mesh := ArrayMesh.new()
	for i in 3:
		b.sts[i].commit(mesh)
		mesh.surface_set_material(i, mats[i])
	return mesh


func _shape() -> void:
	var shaft_top := top + .3
	# shaft: wider and darker at the foot, a slight taper
	prism(STEEL, Vector3.ZERO, 8, .27, .21, foot, shaft_top)
	# the deck bracket: a plate bolted onto the deck, a lug into the flank under it, and the brace
	box(STEEL, Vector3(0, floor_y + .09, .55), Vector3(.9, .18, 1.5), Basis.IDENTITY, .8)
	box(STEEL, Vector3(0, floor_y - .7, .3), Vector3(.55, 1.2, .8), Basis.IDENTITY, .55)
	for sx: float in [-.36, .36]:
		box(STEEL, Vector3(sx, floor_y + .3, .45), Vector3(.06, .42, 1.1), Basis.IDENTITY, .75)      # gussets
	for bx: float in [-.3, .3]:
		for bz: float in [.25, .95]:
			prism(STEEL, Vector3(bx, 0, bz), 6, .055, .055, floor_y + .18, floor_y + .26, .6)      # bolt heads
	beam(STEEL, Vector3(0, floor_y + 4.2, .18), Vector3(0, floor_y + .2, 1.25), .16, .12)
	box(STEEL, Vector3(0, floor_y + 4.2, .1), Vector3(.5, .3, .5), Basis.IDENTITY, .85)      # brace clamp
	# the conduit up the magma side, clamped every 3 m
	prism(STEEL, Vector3(0, 0, -.33), 6, .07, .07, foot + .4, top - .6, .55)
	var y := floor_y + 1.0
	while y < top - 1.0:
		box(STEEL, Vector3(0, y, -.22), Vector3(.2, .12, .26), Basis.IDENTITY, .7)
		y += 3.0
	# hazard collars: just above the deck, under the head
	prism(HAZARD, Vector3.ZERO, 8, .31, .31, floor_y + .35, floor_y + 1.15)
	prism(HAZARD, Vector3.ZERO, 8, .3, .3, top - .9, top - .2)
	# emitter housings: a block round the shaft, a lens either side along the field, fins top and bottom
	y = floor_y + 1.5
	while y < top - .5:
		box(STEEL, Vector3(0, y, 0), Vector3(.62, .4, .5), Basis.IDENTITY, .78)
		for s: float in [-1.0, 1.0]:
			box(STEEL, Vector3(s * .36, y, 0), Vector3(.1, .5, .58), Basis.IDENTITY, .6)      # lens bezel
			box(STEEL, Vector3(s * .41, y, 0), Vector3(.02, .36, .46), Basis.IDENTITY, .25)      # the dark recess behind the grille
			for k in 3:      # a slatted lens
				box(LENS, Vector3(s * .425, y - .1 + k * .1, 0), Vector3(.03, .055, .4), Basis.IDENTITY, 1.0)
		box(STEEL, Vector3(0, y + .24, 0), Vector3(.8, .05, .3), Basis.IDENTITY, .9)      # cooling fins
		box(STEEL, Vector3(0, y - .24, 0), Vector3(.8, .05, .3), Basis.IDENTITY, .65)
		y += 2.9
	# the head: housing, a skirt, a pyramid cap, the beacon's cage posts
	box(STEEL, Vector3(0, top + .55, 0), Vector3(.8, .55, .8), Basis.IDENTITY, .95)
	box(STEEL, Vector3(0, top + .22, 0), Vector3(.95, .12, .95), Basis.IDENTITY, .7)
	prism(STEEL, Vector3(0, 0, 0), 4, .58, .2, top + .82, top + 1.1, 1.0, PI / 4.0)
	for k in 4:
		var a := PI / 4.0 + k * PI / 2.0
		box(STEEL, Vector3(cos(a) * .2, top + 1.42, sin(a) * .2), Vector3(.04, .64, .04), Basis.IDENTITY, .8)
	box(STEEL, Vector3(0, top + 1.76, 0), Vector3(.34, .05, .34), Basis.IDENTITY, .9)
	for s: float in [-1.0, 1.0]:
		box(LENS, Vector3(s * .41, top + .55, 0), Vector3(.03, .22, .5), Basis.IDENTITY, 1.0)


## baked light: dark at the foot (down the dock's flank and in the deck's shadow), full up top; warm magma bounce low down
func _ao(y: float, k: float) -> Color:
	var v := lerpf(.42, .82, smoothstep(foot, floor_y + 2.0, y)) * k
	var warm := 1.0 - smoothstep(floor_y, floor_y + 8.0, y)
	return Color(v * (1.0 + .12 * warm), v * (.96 - .02 * warm), v * (.9 - .1 * warm))


const KEY := Vector3(.45, .78, .43)      # the baked key light: high, from the magma sea's side


func _lit(n: Vector3) -> float:
	return .62 + .5 * maxf(0.0, n.dot(KEY.normalized()))


func _tri(sf: int, p: Array[Vector3], n: Vector3, uv: Array[Vector2], c: Array[Color]) -> void:
	var st := sts[sf]
	for i in 3:
		st.set_normal(n)
		st.set_uv(uv[i])
		st.set_color(c[i])
		st.add_vertex(p[i])


## a quad seen from outside: a bottom-left, b top-left, c top-right, d bottom-right; normal n
func _quad(sf: int, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2, k: float) -> void:
	var kl := k * _lit(n)
	var ca := _ao(a.y, kl)
	var cb := _ao(b.y, kl)
	var cc := _ao(c.y, kl)
	var cd := _ao(d.y, kl)
	# (front faces wind counter-clockwise as they reach the GPU through SurfaceTool: checked in the game)
	_tri(sf, [a, c, b], n, [ua, uc, ub], [ca, cc, cb])
	_tri(sf, [a, d, c], n, [ua, ud, uc], [ca, cd, cc])


## an n-sided prism round the y axis at `at`, radius r0 at y0 to r1 at y1, uv: u round it, v by height
func prism(sf: int, at: Vector3, n: int, r0: float, r1: float, y0: float, y1: float, k: float = 1.0, off: float = -1.0) -> void:
	var o := PI / n if off < 0.0 else off
	for i in n:
		var a0 := TAU * i / n + o
		var a1 := TAU * (i + 1) / n + o
		var am := (a0 + a1) / 2.0
		var nrm := Vector3(cos(am), (r0 - r1) / maxf(.01, y1 - y0), sin(am)).normalized()
		var p00 := at + Vector3(cos(a0) * r0, y0, sin(a0) * r0)
		var p10 := at + Vector3(cos(a1) * r0, y0, sin(a1) * r0)
		var p11 := at + Vector3(cos(a1) * r1, y1, sin(a1) * r1)
		var p01 := at + Vector3(cos(a0) * r1, y1, sin(a0) * r1)
		var u0 := float(i) / n
		var u1 := float(i + 1) / n
		_quad(sf, p10, p11, p01, p00, nrm, Vector2(u0, -y0 / TILE), Vector2(u0, -y1 / TILE), Vector2(u1, -y1 / TILE), Vector2(u1, -y0 / TILE), k)      # (seen from outside, the angle grows to the left)
	if r1 > .001:      # the lid
		for i in n:
			var a0 := TAU * i / n + o
			var a1 := TAU * (i + 1) / n + o
			var c := at + Vector3(0, y1, 0)
			var pa := at + Vector3(cos(a0) * r1, y1, sin(a0) * r1)
			var pb := at + Vector3(cos(a1) * r1, y1, sin(a1) * r1)
			var col := _ao(y1, k * 1.05)
			_tri(sf, [c, pb, pa], Vector3.UP, [Vector2(.5, .5), Vector2(.5 + cos(a1) * .1, .5 + sin(a1) * .1), Vector2(.5 + cos(a0) * .1, .5 + sin(a0) * .1)], [col, col, col])


## a box at c with size s, rotated by bs; uv in metres / TILE on every face; k darkens it (baked)
func box(sf: int, c: Vector3, s: Vector3, bs: Basis, k: float = 1.0) -> void:
	var h := s / 2.0
	var X := bs.x * h.x
	var Y := bs.y * h.y
	var Z := bs.z * h.z
	var faces := [[bs.x, -Z, Y, X, s.z, s.y], [-bs.x, Z, Y, -X, s.z, s.y], [bs.z, X, Y, Z, s.x, s.y], [-bs.z, -X, Y, -Z, s.x, s.y], [bs.y, X, -Z, Y, s.x, s.z], [-bs.y, X, Z, -Y, s.x, s.z]]      # [normal, right, up, centre, width, height]: right x up = normal
	for f: Array in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var cc: Vector3 = c + (f[3] as Vector3)
		var uw: float = f[4] / TILE
		var vh: float = f[5] / TILE
		var u0 := (cc.x + cc.z) / TILE
		var v0 := -cc.y / TILE
		var kk := k * (1.08 if n.y > .5 else (.7 if n.y < -.5 else 1.0))      # lit from above
		_quad(sf, cc - u - v, cc - u + v, cc + u + v, cc + u - v, n, Vector2(u0, v0 + vh / 2.0), Vector2(u0, v0 - vh / 2.0), Vector2(u0 + uw, v0 - vh / 2.0), Vector2(u0 + uw, v0 + vh / 2.0), kk)


## a square beam from a to b, w wide (x) and d deep
func beam(sf: int, a: Vector3, b: Vector3, w: float, d: float) -> void:
	var dir := (b - a).normalized()
	var x := Vector3.RIGHT
	var z := x.cross(dir).normalized()
	box(sf, (a + b) / 2.0, Vector3(w, a.distance_to(b), d), Basis(x, dir, z), .8)


# ---- painted textures (made once, at load)

static func _metal_tex() -> ImageTexture:
	const N := 256
	var big := FastNoiseLite.new()
	big.seed = 41
	big.frequency = .018
	big.fractal_octaves = 4
	var fine := FastNoiseLite.new()
	fine.seed = 7
	fine.frequency = .11
	fine.fractal_octaves = 2
	var drip := FastNoiseLite.new()
	drip.seed = 3
	drip.frequency = .05
	var px := PackedByteArray()
	px.resize(N * N * 3)
	var paint := Color(.52, .49, .45)      # (a warm grey: the docks' tanks and gantries are lit by the magma)
	var rust := Color(.40, .22, .12)
	var bare := Color(.64, .64, .62)
	for y in N:
		for x in N:
			var g := big.get_noise_2d(x, y) * .5 + .5
			var f := fine.get_noise_2d(x, y) * .5 + .5
			var dr := drip.get_noise_2d(x * 1.6, y * .07) * .5 + .5      # grime runs down the paint
			var col := paint.lerp(rust, smoothstep(.6, .82, g) * .75)
			col = col * (.82 + .3 * f) * lerpf(1.0, .72, smoothstep(.55, .85, dr))
			if f > .8 and g > .45:      # chipped to the metal
				col = col.lerp(bare, .55)
			var row := y % 128
			var colm := x % 128
			if row < 2 or colm < 2:      # panel seams: a dark groove, a lit lip under it
				col *= .42
			elif row < 4 or colm < 4:
				col *= 1.28
			if (row == 7 or row == 120) and x % 16 >= 7 and x % 16 <= 9:      # rivets along the seams
				col = Color(.55, .56, .58) if row == 7 else col * .6
			var i := (y * N + x) * 3
			px[i] = clampi(int(col.r * 255.0), 0, 255)
			px[i + 1] = clampi(int(col.g * 255.0), 0, 255)
			px[i + 2] = clampi(int(col.b * 255.0), 0, 255)
	var img := Image.create_from_data(N, N, false, Image.FORMAT_RGB8, px)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _hazard_tex() -> ImageTexture:
	const N := 128
	var nz := FastNoiseLite.new()
	nz.seed = 19
	nz.frequency = .09
	nz.fractal_octaves = 3
	var px := PackedByteArray()
	px.resize(N * N * 3)
	var yel := Color(.88, .62, .09)
	var blk := Color(.07, .07, .07)
	for y in N:
		for x in N:
			var g := nz.get_noise_2d(x, y) * .5 + .5
			var col := yel if ((x + y) / 32) % 2 == 0 else blk
			if g > .74:      # chips: the grey under the paint
				col = Color(.42, .42, .42)
			col *= lerpf(1.08, .62, smoothstep(.2, .7, g * .6 + float(y) / N * .4))      # grime, heavier low down
			var i := (y * N + x) * 3
			px[i] = clampi(int(col.r * 255.0), 0, 255)
			px[i + 1] = clampi(int(col.g * 255.0), 0, 255)
			px[i + 2] = clampi(int(col.b * 255.0), 0, 255)
	var img := Image.create_from_data(N, N, false, Image.FORMAT_RGB8, px)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
