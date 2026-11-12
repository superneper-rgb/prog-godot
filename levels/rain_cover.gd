class_name RainCover
extends RefCounted
## What the rain lands on (new in the Godot port, asked for by the user 2026-11-09): the height of the topmost solid every half metre in a 48 x 48 m square round the camera, in a wrapping texture the rain and splash shaders read.
## Drops stop at roofs, awnings and the bridge deck, and the splashes sit on whatever is on top. Only cells that come into range are cast (a column of 96 rays when the camera crosses half a metre),
## plus a slow sweep that casts the whole square again every few seconds, for solids that move or switch off.

const N := 96                 # cells a side (the rain's box is 40 m, so 48 m leaves a margin)
const CELL := 0.5             # metres
const NONE := -1.0e6          # open sky down to the end of the world
const SWEEP := 24             # cells re-cast a frame

var world: World
var img: Image
var tex: ImageTexture
var cx := 0                   # the window's low corner, in cells
var cz := 0
var _top := 0.0               # rays start here: far over the camera, so a tall roof is still a roof
var _valid := false
var _sweep := 0


func _init(p_world: World) -> void:
	world = p_world
	img = Image.create_empty(N, N, false, Image.FORMAT_RF)
	img.fill(Color(NONE, 0.0, 0.0))
	tex = ImageTexture.create_from_image(img)


func update(cam: Vector3) -> void:
	var nx := floori(cam.x / CELL) - N / 2
	var nz := floori(cam.z / CELL) - N / 2
	_top = cam.y + 200.0
	if not _valid or absi(nx - cx) >= N or absi(nz - cz) >= N:
		cx = nx
		cz = nz
		_valid = true
		for i in N:
			_column(cx + i)
	else:
		# new columns along x over the old z range, then new rows along z over the new x range: between them every cell that came into the square
		while cx < nx:
			_column(cx + N)
			cx += 1
		while cx > nx:
			cx -= 1
			_column(cx)
		while cz < nz:
			_row(cz + N)
			cz += 1
		while cz > nz:
			cz -= 1
			_row(cz)
	for k in SWEEP:
		var c := _sweep % (N * N)
		_cell(cx + c / N, cz + c % N)
		_sweep += 1
	tex.update(img)      # (36 KB a frame: the sweep changes some of it every frame anyway)


func _column(i: int) -> void:
	for j in range(cz, cz + N):
		_cell(i, j)


func _row(j: int) -> void:
	for i in range(cx, cx + N):
		_cell(i, j)


func _cell(i: int, j: int) -> void:
	var h := world.ground_pt((float(i) + 0.5) * CELL, (float(j) + 0.5) * CELL, _top)
	img.set_pixel(posmod(i, N), posmod(j, N), Color(maxf(h, NONE), 0.0, 0.0))
