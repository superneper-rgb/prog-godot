class_name MsArena
extends RefCounted
## THE GODMOTHER's floor, built solid in code (2026-11-15). The export's sixteen tiles were 0.6 m paper wedges with open seams, the centre disc was a single-sided sheet, and between the pit floor and the foot of the wall you looked straight out into the void.
## Now each tile is a thick platform: a carpet top in a gilt chamfer, lacquered walnut sides, a gunmetal keel, and on its underside a violet anti-grav lens that lights (and throws a faint beam down) while she holds the tile up. The centre disc is a pedestal on eight gold columns round a brass shaft collar, the gifts sit on a fixed ledge round the wall (the outer tiles stop short of it), and the PIT under the tiles is a closed trough of psychic plasma that wakes up when the floor does.
## Out of the pit: its burn bounces you up to grab a ledge (the pedestal's edge, a low tile), or walk in under the pedestal to the Spine Beam, which lifts you back up through the floor (so the pedestal stands on columns, not a solid drum).
## Every non-carpet face shares one trim material (ms_trim.gdshader, the finish in the vertex colour) and nothing here casts a shadow: the penthouse's only shadowed light is a 0.08 sun, and four cascades of these cost draws for nothing you could see.

const PF := MsAct2.PENT_F
const AR := 21.0
const PIT := PF - 2.8
const LEDGE_R := 17.8      # the gift ledge: the gifts and their cover ring never moved with the tiles, so they now stand on something
const DRUM_R := 8.0
const DISC_T := 0.6        # the pedestal's thickness (its underside clears your head in the pit)
const COL_R := 6.6         # its columns' ring
const SHAFT_R := 2.85
const DEPTH := 1.0         # a tile from carpet to keel; MsAct2.Tile.move gives its colliders the same depth
const SEAM := 0.0025       # half the seam between two tiles, rad (the colliders keep their own 0.01 / 0.02 rad gaps)
const R_IN := [8.04, 14.17]
const R_OUT := [14.13, 17.74]
const STRIP_R0 := [8.0, 14.2]
const ARC_N := 14
const CH := 0.07           # the gilt chamfer round a top
const LENS_IN := 1.15      # the anti-grav lens on a keel's underside, inset from the tile's edges
## a tile's cross-section, top to bottom: [inset_a, y_a, inset_b, y_b, finish]
const TILE_BANDS := [[CH, 0.0, 0.0, -CH, &"gold"], [0.0, -CH, 0.0, -0.48, &"walnut"], [0.0, -0.48, 0.0, -0.56, &"gold"], [0.0, -0.56, 0.1, -0.64, &"walnut"], [0.1, -0.64, 0.45, -0.64, &"keel"], [0.45, -0.64, 0.95, -DEPTH, &"keel"], [0.95, -DEPTH, LENS_IN, -DEPTH, &"gold"]]


class Under:
	var tl: MsAct2.Tile
	var body: MeshInstance3D
	var glow: MeshInstance3D
	var beam: MeshInstance3D
	var k := 0.0


var L: MothershipLevel
var A: MsAct2
var zone: Node3D
var trim: ShaderMaterial
var fin: Dictionary = {}      # finish name -> vertex colour for the trim shader (rgb linear albedo, a the finish: 0 wood, 0.5 lens, 1 metal)
var carpet: StandardMaterial3D
var pit_mat: ShaderMaterial
var pit_lights: Array[OmniLight3D] = []
var unders: Array[Under] = []
var heat := 0.0


func _init(level: MothershipLevel, act2: MsAct2) -> void:
	L = level
	A = act2
	zone = A.tiles[0].g.get_parent() as Node3D if not A.tiles.is_empty() else L
	trim = ShaderMaterial.new()
	trim.shader = preload("res://levels/mothership/ms_trim.gdshader")
	for f: Array in [[&"gold", 0xd6a23a, 1.0], [&"brass", 0xb88a3a, 1.0], [&"walnut", 0x7a2a3c, 0.0], [&"keel", 0x3a2440, 0.0], [&"lens", 0x2a1030, 0.5]]:
		var c := MsKit.lin(f[1])
		c.a = f[2]
		fin[f[0]] = c
	for tl: MsAct2.Tile in A.tiles:
		_tile(tl)
	carpet = MsKit.std(0xffd8e2, 0.6)
	for tl: MsAct2.Tile in A.tiles:      # the ledge's carpet: an outer tile's own, without its lift glow
		if tl.ring == 1 and tl.mat != null and tl.mat.albedo_texture != null:
			carpet = tl.mat.duplicate() as StandardMaterial3D
			carpet.emission = Color.BLACK
			break
	_room()
	_colliders()


# ---------------------------------------------------------------------------------------------- the tiles
func _tile(tl: MsAct2.Tile) -> void:
	# the export's wedge (and its gold rim) goes; the group node stays: the fight moves and turns it. Its carpet (the textured one: MsAct2 had taken the rim's gold for tl.mat, so the lift glow lit the rim) tops the new body and carries the glow.
	var walk: Array[Node] = [tl.g]
	while not walk.is_empty():
		var n: Node = walk.pop_back()
		walk.append_array(n.get_children())
		if n is MeshInstance3D:
			var mi0 := n as MeshInstance3D
			mi0.visible = false
			for s in mi0.mesh.get_surface_count():
				var m := mi0.get_surface_override_material(s) as StandardMaterial3D
				if m != null and m.albedo_texture != null:
					tl.mat = m
					m.emission_enabled = true
					m.emission = Color.BLACK
					m.emission_energy_multiplier = 0.4      # (a tile's lift glow: a blush, not a wash over the carpet)
	var a0 := (tl.k + tl.ring * 0.5) / 8.0 * TAU + SEAM
	var a1 := (tl.k + tl.ring * 0.5 + 1.0) / 8.0 * TAU - SEAM
	var r0: float = R_IN[tl.ring]
	var r1: float = R_OUT[tl.ring]
	var o := Vector2(tl.home.x, tl.home.z)
	var top := SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st := _trim_st()
	for b: Array in TILE_BANDS:
		_band(st, _outline(o, r0, r1, a0, a1, b[0], b[1]), _outline(o, r0, r1, a0, a1, b[2], b[3]), float(b[2]) - float(b[0]), b[1] == b[3], fin[b[4]])
	_cap(top, _outline(o, r0, r1, a0, a1, CH, 0.0), true, o, Color.WHITE)
	_cap(st, _outline(o, r0, r1, a0, a1, LENS_IN, -DEPTH), false, o, fin[&"lens"])
	var mesh := ArrayMesh.new()
	top.commit(mesh)
	mesh.surface_set_material(0, tl.mat if tl.mat != null else MsKit.std(0xffd8e2, 0.6))
	st.commit(mesh)
	mesh.surface_set_material(1, trim)
	# the emitter under the keel: its lens lights, a violet glow and a faint beam fall to the pit (all dark while the tile is home)
	var am := (a0 + a1) / 2.0
	var rm := (r0 + r1) / 2.0
	var c := Vector3(sin(am) * rm - o.x, -DEPTH - 0.03, cos(am) * rm - o.y)
	var U := Under.new()
	U.tl = tl
	U.body = _mi(tl.g, mesh, "tile_body")
	U.glow = MsKit.sprite(tl.g, 0xc070ff, 0.0, 2.6)
	U.glow.position = c + Vector3(0.0, -0.1, 0.0)
	U.glow.visible = false
	U.beam = MsKit.glow(tl.g, MsKit.cyl(0.55, 1.4, 1.0, 16, true), 2, 0xc070ff, 0.0)
	U.beam.position = c
	U.beam.visible = false
	unders.append(U)


## the outline of a tile's top (or any slice of it) at height y, `inset` metres in from its edges: the inner arc a0 -> a1 then the outer arc back, in the tile's own space
func _outline(o: Vector2, r0: float, r1: float, a0: float, a1: float, inset: float, y: float) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var ri := r0 + inset
	var ro := r1 - inset
	var di := inset / ri
	var dd := inset / ro
	for i in ARC_N:
		var a := lerpf(a0 + di, a1 - di, float(i) / (ARC_N - 1))
		pts.append(Vector3(sin(a) * ri - o.x, y, cos(a) * ri - o.y))
	for i in ARC_N:
		var a := lerpf(a1 - dd, a0 + dd, float(i) / (ARC_N - 1))
		pts.append(Vector3(sin(a) * ro - o.x, y, cos(a) * ro - o.y))
	return pts


static func _trim_st() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


func _mi(parent: Node3D, mesh: Mesh, nm: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## one triangle, wound so its front faces along n (Godot draws clockwise faces as the front: (b - a) x (c - a) points away from the viewer)
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3, uv: Callable, col: Color) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0:
		var s := b
		b = c
		c = s
	for p: Vector3 in [a, b, c]:
		st.set_color(col)
		st.set_normal(n)
		st.set_uv(uv.call(p))
		st.add_vertex(p)


## the band between two outlines (same point count), closed round; its faces look out of the tile (and down where it steps in, up where it is the top chamfer)
func _band(st: SurfaceTool, top: PackedVector3Array, bot: PackedVector3Array, step_in: float, flat: bool, col: Color) -> void:
	var n := top.size()
	var area := 0.0
	for i in n:
		var p := top[i]
		var q := top[(i + 1) % n]
		area += p.x * q.z - q.x * p.z
	var sg := 1.0 if area > 0.0 else -1.0
	var uv := func(p: Vector3) -> Vector2: return Vector2((p.x + p.z) / 2.4, p.y / 2.4)
	for i in n:
		var j := (i + 1) % n
		var e := top[j] - top[i]
		var out := Vector3(e.z, 0.0, -e.x).normalized() * sg      # (the outline runs counter-clockwise in x / z when area > 0: outward is the edge turned right)
		var ref := Vector3.DOWN if flat else out + Vector3(0.0, -signf(step_in), 0.0)
		var nn := (top[j] - top[i]).cross(bot[i] - top[i])
		if nn.length_squared() < 1e-10:
			nn = (bot[j] - bot[i]).cross(bot[i] - top[j])
		nn = nn.normalized()
		if nn.dot(ref) < 0.0:
			nn = -nn
		_tri(st, top[i], top[j], bot[j], nn, uv, col)
		_tri(st, top[i], bot[j], bot[i], nn, uv, col)


## a flat top (carpet, the room's own uv: world xz / 2.4 as the JS had it) or bottom
func _cap(st: SurfaceTool, pts: PackedVector3Array, up: bool, o: Vector2, col: Color) -> void:
	var n := pts.size() / 2
	var nn := Vector3.UP if up else Vector3.DOWN
	var uv := func(p: Vector3) -> Vector2: return Vector2((p.x + o.x) / 2.4, (p.z + o.y) / 2.4)
	for i in n - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var c := pts[2 * n - 2 - i]
		var d := pts[2 * n - 1 - i]
		_tri(st, a, b, c, nn, uv, col)
		_tri(st, a, c, d, nn, uv, col)


# ---------------------------------------------------------------------------------------------- the room under the floor
## A ring revolved round a vertical axis from a profile: each step [r_a, y_a, r_b, y_b, finish, facing] (finish: a trim finish name, or the carpet material; facing: +1 out from the axis, -1 in towards it, 2 up, -2 down).
## Given st_trim, the trim faces go into it (several lathes gathered into one surface) and the returned mesh is empty; otherwise the mesh has the trim surface and, if any, a carpet one.
func _lathe(steps: Array, seg: int, cx: float = 0.0, cz: float = 0.0, st_trim: SurfaceTool = null) -> ArrayMesh:
	var st_t := st_trim if st_trim != null else _trim_st()
	var st_c: SurfaceTool = null
	var off := Vector3(cx, 0.0, cz)
	for s: Array in steps:
		var is_carpet: bool = s[4] is Material
		if is_carpet and st_c == null:
			st_c = SurfaceTool.new()
			st_c.begin(Mesh.PRIMITIVE_TRIANGLES)
		var st: SurfaceTool = st_c if is_carpet else st_t
		var col: Color = Color.WHITE if is_carpet else fin[s[4]]
		var ra: float = s[0]
		var ya: float = s[1]
		var rb: float = s[2]
		var yb: float = s[3]
		var f: int = s[5]
		var flat := absf(ya - yb) < 1e-4
		var uv := func(p: Vector3) -> Vector2: return Vector2(p.x / 2.4, p.z / 2.4) if flat else Vector2(atan2(p.x, p.z) * 4.0, p.y / 2.4)
		for i in seg:
			var u0 := float(i) / seg * TAU
			var u1 := float(i + 1) / seg * TAU
			var d0 := Vector3(sin(u0), 0.0, cos(u0))
			var d1 := Vector3(sin(u1), 0.0, cos(u1))
			var p0 := d0 * ra + Vector3(0.0, ya, 0.0) + off
			var p1 := d1 * ra + Vector3(0.0, ya, 0.0) + off
			var q0 := d0 * rb + Vector3(0.0, yb, 0.0) + off
			var q1 := d1 * rb + Vector3(0.0, yb, 0.0) + off
			var mid := (d0 + d1).normalized()
			var nn := Vector3.UP if f == 2 else Vector3.DOWN
			if f == 1 or f == -1:      # a wall or a chamfer: its own normal, turned to face the way it looks
				nn = (p1 - p0).cross(q0 - p0)
				if nn.length_squared() < 1e-10:
					nn = (q1 - q0).cross(q0 - p1)
				nn = nn.normalized()
				if nn.dot(mid * float(f)) < 0.0:
					nn = -nn
			_tri(st, p0, p1, q1, nn, uv, col)
			_tri(st, p0, q1, q0, nn, uv, col)
	var mesh := ArrayMesh.new()
	if st_trim != null:
		return mesh
	st_t.commit(mesh)
	mesh.surface_set_material(0, trim)
	if st_c != null:
		st_c.commit(mesh)
		mesh.surface_set_material(1, carpet)
	return mesh


func _room() -> void:
	# one mesh: the centre pedestal (a gilt lip under the export's carpet disc, r 3..8, a sheet with nothing under it; a walnut skirt, a gilt lower lip, a gunmetal underside, a brass collar round the Spine Beam's hole), its eight columns, and the room's underside (seen from the climb below)
	var st := _trim_st()
	_lathe([[DRUM_R - CH, PF + 0.015, DRUM_R, PF - 0.06, &"gold", 1], [DRUM_R, PF - 0.06, DRUM_R, PF - DISC_T + 0.1, &"walnut", 1], [DRUM_R, PF - DISC_T + 0.1, DRUM_R - 0.12, PF - DISC_T, &"gold", 1], [DRUM_R - 0.12, PF - DISC_T, SHAFT_R, PF - DISC_T, &"keel", -2], [SHAFT_R, PF + 0.012, 3.02, PF + 0.012, &"brass", 2], [SHAFT_R, PF + 0.012, SHAFT_R, PF - DISC_T, &"brass", -1]], 72, 0.0, 0.0, st)
	var ct := PF - DISC_T
	for i in 8:      # plinth, shaft, capital
		var a := (float(i) + 0.5) / 8.0 * TAU
		_lathe([[0.42, PIT + 0.2, 0.42, PIT + 0.01, &"walnut", 1], [0.3, PIT + 0.2, 0.42, PIT + 0.2, &"walnut", 2], [0.3, PIT + 0.2, 0.26, ct - 0.22, &"gold", 1], [0.26, ct - 0.22, 0.46, ct - 0.02, &"gold", 1]], 14, sin(a) * COL_R, cos(a) * COL_R, st)
	_lathe([[2.7, PIT - 0.8, AR + 0.5, PIT - 0.8, &"keel", -2], [AR + 0.5, PIT - 0.8, AR + 0.5, PF - 0.2, &"walnut", 1], [2.7, PIT + 0.02, 2.7, PIT - 0.8, &"brass", -1]], 72, 0.0, 0.0, st)
	var mesh := ArrayMesh.new()
	st.commit(mesh)
	mesh.surface_set_material(0, trim)
	_mi(zone, mesh, "pedestal")
	# the gift ledge: carpet from the wall in to r 17.8, a gilt chamfer, walnut down into the pit, a gilt skirting board
	_mi(zone, _lathe([[AR + 0.3, PF, LEDGE_R + CH, PF, carpet, 2], [LEDGE_R + CH, PF, LEDGE_R, PF - CH, &"gold", -1], [LEDGE_R, PF - CH, LEDGE_R, PIT + 0.4, &"walnut", -1], [LEDGE_R, PIT + 0.4, LEDGE_R - 0.14, PIT + 0.28, &"gold", -1], [LEDGE_R - 0.14, PIT + 0.28, LEDGE_R - 0.14, PIT + 0.01, &"gold", -1]], 96), "ledge")
	# the pit: psychic plasma that wakes when the floor goes up, and the light it throws on the walls and the tiles' keels
	pit_mat = ShaderMaterial.new()
	pit_mat.shader = preload("res://levels/mothership/ms_pit.gdshader")
	var pit := _mi(zone, MsKit.ring(2.75, LEDGE_R + 0.05, 72), "pit")
	pit.material_override = pit_mat
	pit.position.y = PIT + 0.1      # (clear of the export's unlit pit sheet: 1 cm apart they z-fought)
	for i in 3:      # three round the trough
		var a := float(i) / 3.0 * TAU + 0.5
		var l := MsKit.light(zone, 0xff4ab0, 0.0, 13.0, Vector3(sin(a) * 13.0, PIT + 1.0, cos(a) * 13.0))
		l.omni_attenuation = 0.8
		l.visible = false
		pit_lights.append(l)


func _colliders() -> void:
	var W := L.world
	W.add({"kind": "disc", "cx": 0.0, "cz": 0.0, "r": AR + 0.5, "top": PF, "bottom": PIT, "tag": "floor", "holes": [[0.0, 0.0, LEDGE_R]]})      # the gift ledge's top
	# the ledge's wall down into the pit (a disc solid is only a top): a ring of thin boxes
	var n := 72
	for i in n:
		var a := (float(i) + 0.5) / n * TAU
		var r := LEDGE_R + 0.2
		W.add({"kind": "box", "cx": sin(a) * r, "cz": cos(a) * r, "hx": 0.2, "hz": r * sin(PI / n) + 0.05, "top": PF, "bottom": PIT, "tag": "wall", "yaw": atan2(-cos(a), sin(a))})
	# the pedestal's columns
	for i in 8:
		var a := (float(i) + 0.5) / 8.0 * TAU
		W.add({"kind": "box", "cx": sin(a) * COL_R, "cz": cos(a) * COL_R, "hx": 0.32, "hz": 0.32, "top": PF - DISC_T, "bottom": PIT, "tag": "wall"})
	# the pedestal itself, as a volume (the export's disc is only its top: from the pit you could ledge-grab it from underneath and climb up through it)
	var pieces: Array[PackedVector3Array] = []
	for i in 24:
		var a0 := float(i) / 24.0 * TAU
		var a1 := float(i + 1) / 24.0 * TAU
		var pts := PackedVector3Array()
		for a: float in [a0, a1]:
			for r: float in [SHAFT_R, DRUM_R]:
				pts.append(Vector3(sin(a) * r, PF, cos(a) * r))
				pts.append(Vector3(sin(a) * r, PF - DISC_T, cos(a) * r))
		pieces.append(pts)
	W.add_convex(pieces, "floor")
	# the outer tiles' collider strips stop at the ledge with their meshes (they ran out to r 20.4, under the gifts)
	for tl: MsAct2.Tile in A.tiles:
		if tl.ring != 1:
			continue
		var a0 := (tl.k + 0.5) / 8.0 * TAU + 0.01
		var a1 := a0 + TAU / 8.0 - 0.02
		var wedge := (a1 - a0) / tl.strips.size()
		var r0: float = STRIP_R0[1]
		var r1: float = R_OUT[1]
		var rm := (r0 + r1) / 2.0
		for j in tl.strips.size():
			var q: Array = tl.strips[j]
			var aj := a0 + wedge * (j + 0.5)
			q[1] = sin(aj) * rm - tl.home.x
			q[2] = cos(aj) * rm - tl.home.z
			(q[0] as World.Solid).place(tl.home.x + float(q[1]), tl.home.z + float(q[2]), NAN, (r1 - r0) / 2.0, rm * sin(wedge / 2.0) + 0.02)


# ---------------------------------------------------------------------------------------------- per frame
func update(dt: float, t: float) -> void:
	var up := 0.0
	for U: Under in unders:
		var lift := U.tl.lift
		U.k += (clampf((lift - 0.15) / 0.5, 0.0, 1.0) - U.k) * minf(1.0, dt * 4.0)
		up = maxf(up, U.k)
		var on := U.k > 0.01
		U.beam.visible = on
		U.glow.visible = on
		var fl := 0.85 + 0.15 * sin(t * 9.0 + U.tl.k * 1.3 + U.tl.ring)
		U.body.set_instance_shader_parameter(&"glow", U.k * fl)
		if not on:
			continue
		MsKit.opa(U.glow, 0.85 * U.k * fl)
		var h := maxf(0.2, lift - DEPTH + 2.8)      # keel to pit floor
		U.beam.scale = Vector3(1.0, h, 1.0)
		U.beam.position.y = -DEPTH - h / 2.0
		MsKit.opa(U.beam, 0.22 * U.k * fl)
	heat += (up - heat) * minf(1.0, dt * 1.5)
	pit_mat.set_shader_parameter(&"heat", heat)
	for l: OmniLight3D in pit_lights:
		l.visible = heat > 0.01
		l.light_energy = heat * 1.6
