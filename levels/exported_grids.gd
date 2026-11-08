class_name ExportedGrids
extends RefCounted
## Small lookups behind an exported level's sampled data: the three.js game's water.at(x, z) and cameraZoneWeight(p) came out as sparse grids (see tools/export/page.js).


## cells: flat [index, value, index, value...]; index = i * nz + j
class Sparse:
	var step := 1.0
	var x0 := 0.0
	var z0 := 0.0
	var nx := 0
	var nz := 0
	var cells: Dictionary = {}

	func _init(g: Dictionary) -> void:
		step = g["step"]
		x0 = g["x0"]
		z0 = g["z0"]
		nx = int(g["nx"])
		nz = int(g["nz"])
		var a: Array = g["cells"]
		for k in range(0, a.size(), 2):
			cells[int(a[k])] = float(a[k + 1])

	func at(x: float, z: float, fallback: Variant) -> Variant:
		var i := int(round((x - x0) / step))
		var j := int(round((z - z0) / step))
		if i < 0 or j < 0 or i >= nx or j >= nz:
			return fallback
		return cells.get(i * nz + j, fallback)


## Same fields as the JS world.water object: at(x, z) -> surface height or null, level, ladders.
class Water:
	var level: Variant = null
	var ladders: Array = []
	var grid: Sparse = null

	func _init(w: Dictionary) -> void:
		level = w.get("level")
		ladders = w.get("ladders", [])
		if w.has("grid"):
			grid = Sparse.new(w["grid"])

	func at(x: float, z: float) -> Variant:
		if grid != null:
			return grid.at(x, z, null)
		return level
