class_name OmRocks
extends RefCounted
## OMNISPHERE's basalt masses (JS levels/omnisphere/parts.js rock(), layout.js rockMass()): the same lumpy rings rebuilt from the same seed, so the collider can follow the drawn rock instead of a plain disc.
## ENGINE DIFFERENCE (user asked for the edges of rocks to stop catching and floating): the JS gives a rock a round disc solid (r * 1.03, or `cr`), but the drawn rock is lumpy (radius +-15% round the rim, an overhanging lip, a taper below it), so the disc ended up to a metre outside the visible rim in places (a floating edge you could stand on in the air) and short of it in others (a rock top you fall through). Here the solid is the rock itself: one convex wedge per ring and segment, all in one body. Heights are unchanged: the cap is flat at `top`, as in the JS.

const TAU_ := TAU
const SEG := 28
const RINGS := 9

## [cx, cz, r, y0, top, seed, rough, lip, cr]: layout.js rockMass() calls (r is the rock's radius; cr the JS disc's radius it replaces)
const MASSES: Array = [
	[-8.0, -52.0, 14.0, -3.0, 27.0, 7, 0.1, 0.08, 14.6],      # the inspection rock
	[14.0, -86.0, 7.0, -3.0, 9.0, 11, 0.2, 0.05, 7.21],       # scenery stacks around the island
	[36.0, -36.0, 6.0, -3.0, 5.0, 12, 0.25, 0.08, 6.18],
	[-24.0, -24.0, 5.0, -3.0, 4.0, 13, 0.25, 0.08, 5.15],
	[-46.0, -76.0, 9.6, -3.0, 12.2, 21, 0.14, 0.08, 9.0],     # the crane tower island
	[-143.0, -41.0, 21.0, -3.0, 17.4, 23, 0.1, 0.08, 20.0],   # Checkpoint Gamma
	[-170.0, -41.0, 9.0, -3.0, 17.2, 31, 0.14, 0.08, 8.5],    # the vestibule behind the gate
]


## JS parts.js rng(seed): xorshift32, one closure per rock. State in `s`, call next() for the next number in [0, 1).
class Rng:
	var s := 1

	func _init(seed_: int) -> void:
		s = (seed_ * 2654435761) & 0xFFFFFFFF
		if s == 0:
			s = 1

	func next() -> float:
		s = (s ^ (s << 13)) & 0xFFFFFFFF
		var t := s if s < 0x80000000 else s - 0x100000000      # (JS: `s >> 17` shifts the int32, with its sign)
		var r1 := t ^ (t >> 17)
		s = (r1 ^ (r1 << 5)) & 0xFFFFFFFF
		return float(s) / 4294967296.0


## JS rock(rx, rz, y0, top, seed, { rough, lip }): the rings of vertices (RINGS + 1 rows of SEG points, relative to the rock's centre).
static func rows(rx: float, rz: float, y0: float, top: float, seed_: int, rough: float, lip: float) -> Array[PackedVector3Array]:
	var R := Rng.new(seed_)
	var ph := [R.next() * TAU_, R.next() * TAU_, R.next() * TAU_]
	var h := top - y0
	var out: Array[PackedVector3Array] = []
	for j in RINGS + 1:
		var u := float(j) / RINGS
		var y := y0 + h * u
		var row := PackedVector3Array()
		var prof := (1.0 + lip * pow(u, 6.0) * 3.0) * (1.06 - 0.14 * u + 0.08 * sin(u * 5.0 + float(ph[2])))      # slight taper, overhanging lip at the top
		for i in SEG:
			var a := float(i) / SEG * TAU_
			var flute := 0.06 * absf(sin(a * 7.0 + float(ph[0])))
			var lump := rough * (sin(a * 3.0 + float(ph[0]) + u * 2.0) * 0.5 + sin(a * 5.0 + float(ph[1]) - u * 3.0) * 0.3 + (R.next() - 0.5) * 0.35)
			var r := prof * (1.0 + lump - flute)
			var jy := (R.next() - 0.5) * h * 0.03 * (1.0 if j > 0 and j < RINGS else 0.0)
			row.append(Vector3(cos(a) * rx * r, y + jy, sin(a) * rz * r))
		out.append(row)
	return out


## The convex pieces (world space) that fill the rock: for each ring pair and segment, the hull of the four ring points and the two axis points.
static func hulls(cx: float, cz: float, r: float, y0: float, top: float, seed_: int, rough: float, lip: float) -> Array[PackedVector3Array]:
	var rw := rows(r, r, y0, top, seed_, rough, lip)
	var c := Vector3(cx, 0.0, cz)
	var out: Array[PackedVector3Array] = []
	for j in RINGS:
		var lo := rw[j]
		var hi := rw[j + 1]
		var ylo := y0 + (top - y0) * float(j) / RINGS
		var yhi := top if j + 1 == RINGS else y0 + (top - y0) * float(j + 1) / RINGS
		for i in SEG:
			var k := (i + 1) % SEG
			out.append(PackedVector3Array([c + Vector3(0, ylo, 0), c + Vector3(0, yhi, 0), c + lo[i], c + lo[k], c + hi[k], c + hi[i]]))
	return out


## Swap each rock's disc solid (tag wall, bottom -3, at the rock's centre with the JS radius) for the rock-shaped one. Returns how many were swapped.
static func fit(world: World) -> int:
	var n := 0
	for m: Array in MASSES:
		var disc: World.Solid = null
		for s in world.solids:
			if s.kind == "disc" and s.tag == "wall" and is_equal_approx(s.cx, float(m[0])) and is_equal_approx(s.cz, float(m[1])) and is_equal_approx(s.r, float(m[8])) and is_equal_approx(s.top, float(m[4])):
				disc = s
				break
		if disc == null:
			push_warning("OmRocks: no disc solid for the rock at (%s, %s)" % [m[0], m[1]])
			continue
		world.remove(disc)
		world.add_convex(hulls(float(m[0]), float(m[1]), float(m[2]), float(m[3]), float(m[4]), int(m[5]), float(m[6]), float(m[7])), "wall")
		n += 1
	return n


## The molten-rock ledge round the containment drum (y 8, 10 m under the docks bridge): the JS drew it in the landmarks mesh and never gave it a collider, so you fell through it into the lava. New (user, 2026-11-10): its flat top triangles become one trimesh solid. Only the level-ground faces (y = 8, facing up) are taken, so the drum's walls and the siphon pipes stay as they were.
const LEDGE_Y := 8.0


static func ledge(world: World, lv: ExportedLevel) -> void:
	for n: Node3D in lv.node_named("omnisphere landmarks"):
		for mi in VhKit.meshes(n):
			if mi.mesh == null or mi.mesh.get_surface_count() == 0:
				continue
			var arr := mi.mesh.surface_get_arrays(0)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			var tris := PackedVector3Array()
			for i in range(0, idx.size(), 3):
				var a: Vector3 = mi.global_transform * v[idx[i]]
				var b: Vector3 = mi.global_transform * v[idx[i + 1]]
				var c: Vector3 = mi.global_transform * v[idx[i + 2]]
				if absf(a.y - LEDGE_Y) > 0.05 or absf(b.y - LEDGE_Y) > 0.05 or absf(c.y - LEDGE_Y) > 0.05:
					continue
				if (b - a).cross(c - a).y > 0.0:      # (Godot's front face is clockwise and the trimesh is one-sided: wind every top face clockwise seen from above)
					var t := b
					b = c
					c = t
				tris.append_array(PackedVector3Array([a, b, c]))
			if tris.size() > 0:
				world.add_mesh(tris, "ledge", true)
