class_name UfRoute
extends Node3D
## UNDERFOINT's last line (user 2026-11-12: "twists and turns", "bumps in the road", "explosions and craziness", Hollywood-chase scale): every metre the last train runs, built once at level load in its
## own space and moved past the train each frame. The train itself never moves (levels/underfoint/uf_chase.gd): this node is set to (the train's frame at rest) * (its frame at s)^-1, so on a bend the
## tunnel swings round the train, on a grade it tips, on a cant it rolls, and everything along the route goes by at the train's speed. Its space is the level's own space at s = 0 (the train standing in the
## tunnel off the north wall of the Sigil's chamber), so until the train moves this is just more of the level.
## Along it, in order: the brick trunk line (a long sweep, a hard right), the twin bores (arches between them: the Sigil runs in the other bore), the broken stretch (holes in the roof, bad track), the
## hairpin, SERN's fuel depot (tanks that go up), the climb and the mouth in the cavern wall; the viaduct over the old city (rooftops beside it, FOINT's piles to the slab, the span that falls); SERN's
## blast door; SERN's own line (steel, strip lights, the spiral down) and the gate at its end. Smoke, fire, dust, rubble and flashes that must be left behind are made in this node's space (blast(), dust()).
## The pieces the fight breaks (lamps, piers, tanks, the buildings it lands on, the falling spans, the door leaves, the plug of rubble at the start) are kept here for the director to break.

const Y := UnderfointLevel.STATION_Y
const DS := 1.0                       # metres between samples of the route
const S0 := -64.0                     # the first sample: in the chamber, behind the north wall
const HOME := Vector3(70.0, Y, 309.0)  # the middle of the flatcar on the track while the train stands: the route's 0
const CHUNK := 48.0
const SEEN_BACK := 200.0
const SEEN_AHEAD := 300.0
const SMOKE := preload("res://levels/shaders/uf_route_smoke.gdshader")
const FIRE := preload("res://levels/shaders/uf_route_fire.gdshader")
const PORTAL := preload("res://levels/shaders/uf_portal.gdshader")
const GAIN := UnderfointLevel.GAIN
## The line, piece by piece: [kind, length m, turn in degrees over it (+ left), climb m over it, name]. A name marks where that piece begins (mark()): s1, s2, s3 begin the three stretches.
const PLAN := [
	["void", 27.0, 0.0, 0.0, ""],
	["trunk", 37.0, 0.0, 0.0, "portal"],
	["trunk", 70.0, 0.0, 0.0, "s1"],
	["trunk", 210.0, 75.0, 0.0, "sweep"],
	["trunk", 60.0, 0.0, -2.0, ""],
	["trunk", 120.0, -60.0, 0.0, "right"],
	["twin", 240.0, 10.0, 0.0, "twin"],
	["broken", 150.0, 30.0, -4.0, "broken"],
	["trunk", 90.0, -70.0, 0.0, "hairpin"],
	["depot", 210.0, 18.0, 0.0, "depot"],
	["trunk", 110.0, -35.0, 5.0, "climb"],
	["mouth", 24.0, 0.0, 1.0, "mouth"],
	["viaduct", 150.0, 18.0, 0.0, "s2"],
	["viaduct", 200.0, -32.0, 0.0, "roofs"],
	["viaduct", 210.0, 28.0, 0.0, "side2"],
	["viaduct", 260.0, 0.0, 0.0, "ahead"],
	["viaduct", 190.0, -24.0, 0.0, "climbback"],
	["blast", 30.0, 0.0, 0.0, "blast"],
	["sern", 150.0, 0.0, -9.0, "s3"],
	["sern", 130.0, 55.0, -3.0, "bend_l"],
	["sern", 130.0, -55.0, -3.0, "bend_r"],
	["sern", 420.0, 300.0, -26.0, "helix"],
	["sern", 220.0, 0.0, 0.0, "straight"],
	["gate", 260.0, 0.0, 0.0, "finale"],
	["gate", 160.0, 0.0, 0.0, "beyond"],
]
const VIA_H := -36.0                  # the old city's streets under the viaduct, from the rail
const SLAB_H := 40.0                  # FOINT CITY's slab over it
const SPAN := 30.0                    # pier to pier on the viaduct
const ROOF_U := 17.0                  # the middle of the roofs the Sigil bounds along, left of the rail
const ROOF_H := -2.0                  # and their tops, from the rail
const FALL0 := 40.0                   # the spans that fall: from this far into the "ahead" piece ...
const FALL1 := 250.0                  # ... to this far
## SERN's line: half its width and its height. (2026-11-15: was 7 and 9.7, sized for the old body. The Sigil's new body is 13 m across its feet with its scythes 12.4 m up, and the user asked that it
## never go through a wall or a roof: SERN's line is now the twin bores' size, and the director keeps it centred, see levels/underfoint/uf_chase.gd _fit.)
const SERN_W := 9.5
const SERN_H := 12.5


## A lamp on a wall: what the Sigil smashes as it scrapes past
class Lamp:
	var sig := 0.0
	var side := 1.0
	var light: OmniLight3D
	var glow: MeshInstance3D
	var alive := true


## Something along the line the fight can break: a pier, a tank, a building, a span, a door leaf. t >= 0: seconds since it went.
class Thing:
	var sig := 0.0
	var u := 0.0
	var h := 0.0
	var node: Node3D
	var alive := true
	var t := -1.0
	var vel := Vector3.ZERO
	var spin := Vector3.ZERO
	var rest := Transform3D.IDENTITY


var rb: UfBuild                      # the route's own builder: its materials lay their stains in the mesh's space, so they ride with the route
var arch: UfArch
var rng := RandomNumberGenerator.new()
var n := 0
var length := 0.0                    # sigma of the route's end
var s := 0.0                          # where the train is on it
var jolt := Transform3D.IDENTITY      # the bumps (the director shakes the world about the train)
var marks := {}
var lamps: Array[Lamp] = []
var piers: Array[Thing] = []
var tanks: Array[Thing] = []
var blds: Array[Thing] = []
var spans: Array[Thing] = []
var gantries: Array[Thing] = []       # the signal frames over the line in the tunnels, in order along it: they go by a metre from the car, and the Sigil goes through them (smash_gantry)
var tv_mat: StandardMaterial3D        # the glass of the old monitors on the tunnel walls: the director gives it the Sigil's face (levels/underfoint/uf_chase.gd)
var towers: Array[Thing] = []         # the water tank on each roof the Sigil bounds across (shoot it and that roof will not hold it: levels/underfoint/uf_chase.gd)
var doors: Array[Thing] = []
var breaches := PackedFloat32Array()
var fires: Array = []                 # [sigma, route-space point, size]: what burns in the city under the viaduct
var plug: Node3D
var gate: MeshInstance3D
var gate_mat: ShaderMaterial
var F0 := Transform3D.IDENTITY

var _p := PackedVector3Array()
var _yaw := PackedFloat32Array()
var _pitch := PackedFloat32Array()
var _roll := PackedFloat32Array()
var _kap := PackedFloat32Array()
var _pieces: Array = []               # [kind, sigma0, sigma1, name]
var _chunks: Array[Node3D] = []
var _chunk_s := PackedFloat32Array()
var _now := 0.0
var _smoke_mm: MultiMesh
var _smoke_mat: ShaderMaterial
var _fire_mm: MultiMesh
var _fire_mat: ShaderMaterial
var _smoke_i := 0
var _fire_i := 0
var _deb: Array[MeshInstance3D] = []
var _deb_v: Array[Vector3] = []
var _deb_w: Array[Vector3] = []
var _deb_t := PackedFloat32Array()
var _deb_i := 0
var _flash: Array[OmniLight3D] = []
var _flash_t := PackedFloat32Array()
var _flash_e := PackedFloat32Array()
var _flash_i := 0
var _shaft_mats: Array[StandardMaterial3D] = []
var _trunk := PackedVector2Array()    # the trunk tunnel's section, foot of the left wall round to the foot of the right
var _sern := PackedVector2Array()
var _lamp_box: BoxMesh
var _gantry_mesh: ArrayMesh
var _tv_quad: QuadMesh


func _init() -> void:
	name = "UfRoute"
	rng.seed = 5150


# ---- the route's shape ------------------------------------------------------------------------------------------------------------------------------------------------------

## Sample the plan every metre: the bends eased in over 24 m, the climbs smoothed, a cant on every curve
func _sample() -> void:
	var total := 0.0
	for q: Array in PLAN:
		total += float(q[1])
	n = int(total / DS) + 2
	length = S0 + total
	var kap := PackedFloat32Array()
	kap.resize(n)
	var yy := PackedFloat32Array()
	yy.resize(n)
	var sig := S0
	var y0 := 0.0
	for q: Array in PLAN:
		var L: float = q[1]
		var turn := deg_to_rad(float(q[2]))
		var climb: float = q[3]
		var nm: String = q[4]
		if nm != "":
			marks[nm] = sig
		_pieces.append([String(q[0]), sig, sig + L, nm])
		var i0 := maxi(0, int(ceilf((sig - S0) / DS)))
		var i1 := mini(n - 1, int(floorf((sig + L - S0) / DS)))
		for i in range(i0, i1 + 1):
			var u := clampf((S0 + i * DS - sig) / L, 0.0, 1.0)
			kap[i] = turn / L
			yy[i] = y0 + climb * u * u * (3.0 - 2.0 * u)
		y0 += climb
		sig += L
	# a bend comes on over 24 m, not at once (a step in curvature is a jerk the whole world would feel)
	_kap.resize(n)
	var W := 12
	for i in n:
		var acc := 0.0
		var cnt := 0
		for j in range(maxi(0, i - W), mini(n, i + W + 1)):
			acc += kap[j]
			cnt += 1
		_kap[i] = acc / cnt
	_p.resize(n)
	_yaw.resize(n)
	_pitch.resize(n)
	_roll.resize(n)
	var yaw := 0.0
	var pos := Vector3(HOME.x, 0.0, HOME.z + S0)
	for i in n:
		var a := maxi(0, i - 1)
		var b := mini(n - 1, i + 1)
		var slope := (yy[b] - yy[a]) / (DS * (b - a))
		_yaw[i] = yaw
		_pitch[i] = -atan(slope)
		_roll[i] = clampf(-_kap[i] * 14.0, -0.085, 0.085)
		_p[i] = Vector3(pos.x, HOME.y + yy[i], pos.z)
		var mid := yaw + _kap[i] * DS * 0.5
		pos += Vector3(sin(mid), 0.0, cos(mid)) * DS
		yaw += _kap[i] * DS
	F0 = frame_at(0.0)


## The route's frame at sigma in its own space: origin on the track's centre at rail level, +Z along it, +X to its left, +Y up off the rails
func frame_at(sig: float) -> Transform3D:
	var f := clampf((sig - S0) / DS, 0.0, float(n - 1) - 0.0001)
	var i := int(f)
	var t := f - i
	var b := Basis.from_euler(Vector3(lerpf(_pitch[i], _pitch[i + 1], t), lerpf(_yaw[i], _yaw[i + 1], t), lerpf(_roll[i], _roll[i + 1], t)))
	return Transform3D(b, _p[i].lerp(_p[i + 1], t))


func kappa_at(sig: float) -> float:
	var f := clampf((sig - S0) / DS, 0.0, float(n - 1))
	return _kap[int(f)]


## a point beside the route, in its own space: u to the left, h up off the rails
func pt(sig: float, u: float, h: float) -> Vector3:
	return frame_at(sig) * Vector3(u, h, 0.0)


## ...and where that is in the world this frame
func world(sig: float, u: float, h: float) -> Vector3:
	return transform * pt(sig, u, h)


func world_xf(sig: float, u: float, h: float, extra: Basis = Basis.IDENTITY) -> Transform3D:
	return transform * frame_at(sig) * Transform3D(extra, Vector3(u, h, 0.0))


func kind_at(sig: float) -> String:
	for q: Array in _pieces:
		if sig >= float(q[1]) and sig < float(q[2]):
			return q[0]
	return "void"


func mark(nm: String) -> float:
	return float(marks.get(nm, 0.0))


## the name of the last named piece that begins at or before sigma (the train's speed and the fight's beats go by these)
func name_at(sig: float) -> String:
	var out := ""
	for q: Array in _pieces:
		if float(q[1]) > sig:
			break
		if String(q[3]) != "":
			out = q[3]
	return out


## Where the train is: the world swings round it
func place(p_s: float) -> void:
	s = p_s
	transform = jolt * F0 * frame_at(s).affine_inverse()
	for i in _chunks.size():
		var c0 := _chunk_s[i]
		_chunks[i].visible = c0 + CHUNK > s - SEEN_BACK and c0 < s + SEEN_AHEAD


# ---- building it (level load) -----------------------------------------------------------------------------------------------------------------------------------------------

func build(src: UfBuild) -> void:
	_sample()
	rb = UfBuild.new(src.world)
	_materials(src)
	arch = UfArch.new(rb, rng)
	_lamp_box = BoxMesh.new()
	_lamp_box.size = Vector3(0.34, 0.4, 0.34)
	_trunk = _trunk_section()
	_build_dressing()
	_sern = PackedVector2Array([Vector2(SERN_W, -0.3), Vector2(SERN_W, SERN_H - 0.8), Vector2(SERN_W - 0.9, SERN_H), Vector2(-SERN_W + 0.9, SERN_H), Vector2(-SERN_W, SERN_H - 0.8), Vector2(-SERN_W, -0.3)])
	var c := mark("portal")
	var k := c
	while k < length:      # the holes in the broken stretch's roof: one in the middle of each chunk there (so no hole is cut by a chunk's edge)
		var mid := k + CHUNK * 0.5
		if mid > mark("broken") + 10.0 and mid < mark("hairpin") - 10.0:
			breaches.append(mid)
		k += CHUNK
	while c < length:
		var node := Node3D.new()
		node.name = "chunk%d" % _chunks.size()
		add_child(node)
		_build_chunk(c, minf(length, c + CHUNK), node)
		_chunks.append(node)
		_chunk_s.append(c)
		c += CHUNK
	_build_plug()
	_build_fx()
	place(0.0)


## The route's own materials: every one of the level's, copied so its stains ride the mesh (uf_surface's `stick`, or object-space triplanar), and the line's own
func _materials(src: UfBuild) -> void:
	for tag: String in src.mats:
		var m := (src.mats[tag] as Material).duplicate() as Material
		if m is ShaderMaterial and (m as ShaderMaterial).shader == UfBuild.SURFACE:
			(m as ShaderMaterial).set_shader_parameter(&"stick", 1.0)
		elif m is StandardMaterial3D and (m as StandardMaterial3D).uv1_world_triplanar:
			(m as StandardMaterial3D).uv1_world_triplanar = false
		rb.mats[tag] = m
	_stick(rb.tex("r_ground", "concrete_debris", {"tile": 3.0, "tint": Color(0.36, 0.35, 0.33), "puddles": 1.0, "growth": 1.1}))
	_stick(rb.tex("r_brick", "brick_wall_001", {"tile": 2.6, "tint": Color(0.56, 0.45, 0.41), "growth": 1.0}))
	_stick(rb.tex("r_soot", "brick_wall_001", {"tile": 2.6, "tint": Color(0.3, 0.26, 0.24), "growth": 0.6}))
	_stick(rb.tex("r_ballast", "concrete_debris", {"tile": 1.8, "tint": Color(0.27, 0.25, 0.23), "puddles": 0.4, "growth": 0.4}))
	_stick(rb.tex("r_planks", "distressed_painted_planks", {"tile": 1.6, "tint": Color(0.36, 0.3, 0.24), "growth": 0.5}))
	_stick(rb.tex("r_stone", "cracked_concrete_wall", {"tile": 3.2, "tint": Color(0.5, 0.5, 0.48), "growth": 0.8}))
	_stick(rb.tex("r_deck", "cracked_concrete_wall", {"tile": 2.4, "tint": Color(0.42, 0.42, 0.4), "puddles": 0.8, "growth": 0.6}))
	_stick(rb.tex("r_concrete", "cracked_concrete_wall", {"tile": 2.2, "tint": Color(0.46, 0.47, 0.47), "puddles": 0.6, "growth": 0.3}))
	_stick(rb.tex("r_panel", "rusted_shutter", {"tile": 3.0, "tint": Color(0.42, 0.44, 0.46), "growth": 0.15}))
	_stick(rb.tex("r_steel", "corrugated_iron_02", {"tile": 2.2, "tint": Color(0.34, 0.35, 0.37), "growth": 0.1}))
	_stick(rb.tex("r_street", "cobblestone_floor_04", {"tile": 2.4, "tint": Color(0.42, 0.44, 0.42), "puddles": 1.0, "growth": 0.8}))
	var rail := StandardMaterial3D.new()
	rail.albedo_color = Color(0.3, 0.28, 0.26)
	rail.metallic = 0.85
	rail.roughness = 0.32
	rb.mats["r_rail"] = rail
	var rust := StandardMaterial3D.new()
	rust.albedo_color = Color(0.26, 0.13, 0.07)
	rust.metallic = 0.55
	rust.roughness = 0.62
	rb.mats["r_rust"] = rust
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.05, 0.05, 0.055)
	iron.metallic = 0.7
	iron.roughness = 0.45
	rb.mats["r_iron"] = iron
	var tank := StandardMaterial3D.new()
	tank.albedo_color = Color(0.42, 0.1, 0.06)
	tank.metallic = 0.35
	tank.roughness = 0.5
	rb.mats["r_tank"] = tank
	var pile := StandardMaterial3D.new()
	pile.albedo_color = Color(0.075, 0.065, 0.11)
	pile.roughness = 0.6
	rb.mats["r_pile"] = pile
	var slab := StandardMaterial3D.new()
	slab.albedo_color = Color(0.045, 0.04, 0.06)
	slab.roughness = 0.9
	rb.mats["r_slab"] = slab
	var hz := StandardMaterial3D.new()      # yellow and black, SERN's stripes
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			img.set_pixel(x, y, Color(0.75, 0.55, 0.06) if ((x + y) / 16) % 2 == 0 else Color(0.03, 0.03, 0.03))
	img.generate_mipmaps()
	hz.albedo_texture = ImageTexture.create_from_image(img)
	hz.uv1_scale = Vector3(0.5, 0.5, 1.0)
	hz.roughness = 0.6
	rb.mats["r_hazard"] = hz
	rb.glow("r_lamp", Color(1.0, 0.7, 0.4), 3.2)
	rb.glow("r_strip", Color(0.62, 0.92, 1.0), 3.0)
	rb.glow("r_red", Color(1.0, 0.12, 0.06), 2.6)
	rb.glow("r_grate", Color(0.45, 0.65, 1.0), 1.25)      # (was 1.6 and 1.4 magenta: tiles of light floating in the dark; now framed, and the violet one bluer)
	rb.glow("r_grate2", Color(0.6, 0.45, 1.0), 1.0)
	rb.glow("r_window", Color(1.0, 0.72, 0.38), 1.6)
	rb.glow("r_tv", Color(0.55, 0.75, 1.0), 1.2)      # somebody's set on, down there
	rb.glow("r_beacon", Color(0.55, 0.9, 1.0), 2.2)      # the piles' service lamps
	var far := StandardMaterial3D.new()      # the skyline's blocks: no texture to see at that range, only their mass
	far.albedo_color = Color(0.05, 0.055, 0.06)
	far.roughness = 0.95
	rb.mats["r_far"] = far


func _stick(m: ShaderMaterial) -> void:
	m.set_shader_parameter(&"stick", 1.0)


func _build_chunk(c0: float, c1: float, node: Node3D) -> void:
	var later: Array[Callable] = []      # pieces that get their own node (what breaks), made after the chunk's own meshes are committed
	for q: Array in _pieces:
		var a := maxf(c0, float(q[1]))
		var b := minf(c1, float(q[2]))
		if b <= a:
			continue
		var p0: float = q[1]
		var p1: float = q[2]
		match String(q[0]):
			"trunk":
				_trunk_part(a, b, node, false)
				if String(q[3]) == "portal" and a <= p0 + 0.01:
					_portal_frame(p0)
					_cliff(p0, _trunk, -1.0, 9.6, -0.3, 12.4, "cavern")      # the chamber wall's square hole, filled round the arch
			"broken":
				_trunk_part(a, b, node, true)
			"twin":
				_twin(a, b, p0, p1, node, later)
			"depot":
				_depot(a, b, p0, p1, node, later)
			"mouth":
				_trunk_part(a, b, node, false)
				if b >= p1 - 0.01:
					_cliff(p1, _trunk, 1.0)
			"viaduct":
				_viaduct(a, b, String(q[3]), node, later)
			"blast":
				_blast(a, b, p0, p1, node, later)
			"sern":
				_sern_part(a, b, node)
			"gate":
				_gate_part(a, b, p0, p1, String(q[3]), node)
	rb.commit(node)
	for f in later:
		f.call()


func _slices(a: float, b: float) -> PackedFloat32Array:
	var out := PackedFloat32Array([a])
	var x := a
	while x < b - 0.01:
		var k := absf(kappa_at(x))
		x = minf(b, x + clampf(0.045 / maxf(k, 1e-4), 1.5, 6.0))
		out.append(x)
	return out


## A surface swept along the route over a..b from a line across it (u, h points), a strip for each pair. It faces to the left of the line's way: walk a tunnel's section from the foot of its left
## wall, up, over and down the right, and it faces in; walk a deck's top from right to left and it faces up.
func _sweep(tag: String, a: float, b: float, prof: PackedVector2Array, wet: float = 1.0, shaded: bool = true) -> void:
	if b - a < 0.01:
		return
	var sl := _slices(a, b)
	var vl := PackedFloat32Array([0.0])
	for j in range(1, prof.size()):
		vl.append(vl[j - 1] + prof[j].distance_to(prof[j - 1]))
	var fr: Array[Transform3D] = []
	for x in sl:
		fr.append(frame_at(x))
	for i in sl.size() - 1:
		var f0 := fr[i]
		var f1 := fr[i + 1]
		for j in prof.size() - 1:
			var p0 := prof[j]
			var p1 := prof[j + 1]
			var hm := (p0.y + p1.y) * 0.5
			var k := clampf((hm + 0.3) / 3.5, 0.0, 1.0)
			var sh := lerpf(0.5, 1.0, k) if shaded else 1.0
			rb.quad_uv(tag, f0 * Vector3(p0.x, p0.y, 0.0), f0 * Vector3(p1.x, p1.y, 0.0), f1 * Vector3(p1.x, p1.y, 0.0), f1 * Vector3(p0.x, p0.y, 0.0),
				Vector2(sl[i], -vl[j]), Vector2(sl[i], -vl[j + 1]), Vector2(sl[i + 1], -vl[j + 1]), Vector2(sl[i + 1], -vl[j]), sh, (1.0 - k) * 0.7 * wet)


## a box beside the route at sigma: u, h its middle, h3 its half size (across, up, along), turned by extra in the route's frame
func _box(tag: String, sig: float, u: float, h: float, h3: Vector3, extra: Basis = Basis.IDENTITY, sh: float = 1.0) -> void:
	rb.obox(tag, frame_at(sig) * Transform3D(extra, Vector3(u, h, 0.0)), h3, sh)


func _poly(cx: float, cy: float, r: float, k: int, clockwise: bool) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in k + 1:
		var a := TAU * i / k * (-1.0 if clockwise else 1.0)
		out.append(Vector2(cx + cos(a) * r, cy + sin(a) * r))
	return out


## A track: ballast, sleepers every 1.25 m, two rails. old: a disused one, rusty and missing sleepers
func _track(a: float, b: float, u: float, old: bool = false) -> void:
	_sweep("r_ballast", a, b, PackedVector2Array([Vector2(u - 2.3, -0.32), Vector2(u - 1.55, 0.02), Vector2(u + 1.55, 0.02), Vector2(u + 2.3, -0.32)]), 0.5)
	for side: float in [-0.72, 0.72]:
		var x := u + side
		_sweep("r_rust" if old else "r_rail", a, b, PackedVector2Array([Vector2(x - 0.04, 0.12), Vector2(x - 0.04, 0.27), Vector2(x + 0.04, 0.27), Vector2(x + 0.04, 0.12)]), 0.0, false)
	var z := ceilf(a / 1.25) * 1.25
	while z < b:
		if not old or fposmod(z * 7.13, 5.0) > 1.6:
			_box("r_planks", z, u + (fposmod(z * 3.7, 0.3) - 0.15 if old else 0.0), 0.07, Vector3(1.22, 0.055, 0.12), Basis(Vector3.UP, (fposmod(z * 5.1, 0.24) - 0.12) if old else 0.0), 0.85)
		z += 1.25


# ---- the trunk line ---------------------------------------------------------------------------------------------------------------------------------------------------------

## The trunk tunnel's section: brick walls 7 m, a segmental vault to 11.8 m, from the left wall's foot round to the right's
func _trunk_section() -> PackedVector2Array:
	var out := PackedVector2Array([Vector2(9.5, -0.3), Vector2(9.5, 6.8)])
	var cy := 0.275
	var R := 11.525
	var a0 := atan2(6.8 - cy, 9.5)
	for i in range(1, 8):
		var a := lerpf(a0, PI - a0, i / 8.0)
		out.append(Vector2(cos(a) * R, cy + sin(a) * R))
	out.append(Vector2(-9.5, 6.8))
	out.append(Vector2(-9.5, -0.3))
	return out


## What stands close to the line in the tunnels (2026-11-15: the ride is watched looking back down the track, where everything only recedes, and a bot ride showed 75 to 105 km/h reading as a
## walk): a signal frame over the line every 24 m, its posts a metre off the car's sides and its beam just over the engine, and an old monitor on the wall every 48 m. One shared mesh each.
func _build_dressing() -> void:
	rb.glow("r_sig", Color(0.72, 0.84, 1.0), 2.6)
	var st := SurfaceTool.new()
	var bm := BoxMesh.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for q: Array in [[Vector3(0.16, 5.9, 0.16), Vector3(2.9, 2.65, 0.0)], [Vector3(0.16, 5.9, 0.16), Vector3(-2.9, 2.65, 0.0)], [Vector3(6.1, 0.22, 0.22), Vector3(0.0, 5.7, 0.0)],
			[Vector3(0.1, 0.1, 1.2), Vector3(2.9, 4.6, -0.5)], [Vector3(0.1, 0.1, 1.2), Vector3(-2.9, 4.6, -0.5)]]:
		bm.size = q[0]
		st.append_from(bm, 0, Transform3D(Basis.IDENTITY, q[1]))
	_gantry_mesh = st.commit()
	_gantry_mesh.surface_set_material(0, rb.mats["r_iron"])
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for u: float in [-1.6, 1.6]:
		bm.size = Vector3(0.5, 0.14, 0.3)
		st.append_from(bm, 0, Transform3D(Basis.IDENTITY, Vector3(u, 5.5, 0.0)))
	st.commit(_gantry_mesh)
	_gantry_mesh.surface_set_material(1, rb.mats["r_sig"])
	_tv_quad = QuadMesh.new()
	_tv_quad.size = Vector2(2.3, 1.7)
	tv_mat = StandardMaterial3D.new()
	tv_mat.albedo_color = Color(0.01, 0.012, 0.01)
	tv_mat.roughness = 0.25
	tv_mat.emission_enabled = true
	tv_mat.emission = Color(0.35, 1.0, 0.45)      # (green: on the Sigil's own set the face is amber, and amber is what the fight asks you to shoot)
	tv_mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	tv_mat.emission_energy_multiplier = 0.0
	tv_mat.cull_mode = BaseMaterial3D.CULL_DISABLED


func _dress(a: float, b: float, node: Node3D, wall_u: float) -> void:
	var z := ceilf(a / 24.0) * 24.0
	while z < b:
		if z > mark("s1") + 20.0:
			var g := MeshInstance3D.new()
			g.mesh = _gantry_mesh
			g.transform = frame_at(z)
			node.add_child(g)
			var t := Thing.new()
			t.sig = z
			t.h = 3.0
			t.node = g
			t.rest = g.transform
			gantries.append(t)
			if int(roundf(z / 24.0)) % 2 == 0:
				var side := 1.0 if int(roundf(z / 48.0)) % 2 == 0 else -1.0
				_box("r_iron", z + 12.0, side * (wall_u - 0.22), 4.4, Vector3(0.2, 1.05, 1.35))
				var q := MeshInstance3D.new()
				q.mesh = _tv_quad
				q.material_override = tv_mat
				q.transform = frame_at(z + 12.0) * Transform3D(Basis(Vector3.UP, -side * PI * 0.5), Vector3(side * (wall_u - 0.45), 4.4, 0.0))
				node.add_child(q)
		z += 24.0


## The Sigil goes through a signal frame: it is thrown on down the line ahead of it, turning over
func smash_gantry(t: Thing) -> void:
	if not t.alive:
		return
	t.alive = false
	t.t = 0.0
	var f := frame_at(t.sig).basis
	t.vel = f.z * rng.randf_range(10.0, 18.0) + f.x * rng.randf_range(-5.0, 5.0) + Vector3(0.0, rng.randf_range(3.0, 8.0), 0.0)
	t.spin = Vector3(rng.randf_range(-5.0, 5.0), rng.randf_range(-3.0, 3.0), rng.randf_range(-5.0, 5.0))
	debris(pt(t.sig, rng.randf_range(-2.5, 2.5), 5.2), 3, 7.0, 0.3, 0.8)


func _trunk_part(a: float, b: float, node: Node3D, broken: bool) -> void:
	_dress(a, b, node, 9.5)
	_sweep("r_ground", a, b, PackedVector2Array([Vector2(-9.5, -0.3), Vector2(9.5, -0.3)]))
	_sweep("r_brick", a, b, _trunk.slice(0, 2))
	_sweep("r_brick", a, b, _trunk.slice(_trunk.size() - 2, _trunk.size()))
	var vault := _trunk.slice(1, _trunk.size() - 1)
	if broken:      # holes in the roof every so often, light coming down through them and what fell under them on the track
		var x := a
		for hb in _breaks_in(a, b):
			_sweep("r_soot", x, hb - 4.0, vault)
			var side := vault.slice(0, 3)
			var side2 := vault.slice(vault.size() - 3, vault.size())
			_sweep("r_soot", hb - 4.0, hb + 4.0, side)
			_sweep("r_soot", hb - 4.0, hb + 4.0, side2)
			x = hb + 4.0
		_sweep("r_soot", x, b, vault)
	else:
		_sweep("r_soot", a, b, vault)
	_track(a, b, 0.0)
	_track(a, b, 5.2, true)
	# a pipe and a cable run along the right wall
	_sweep("r_rust", a, b, _poly(-9.15, 2.55, 0.2, 8, true), 0.3, false)
	_sweep("r_iron", a, b, _poly(-9.2, 3.1, 0.12, 6, true), 0.0, false)
	_sweep("r_iron", a, b, PackedVector2Array([Vector2(9.3, 4.15), Vector2(9.15, 4.15), Vector2(9.15, 4.3), Vector2(9.3, 4.3)]), 0.0, false)
	# iron ribs every 16 m
	var z := ceilf(a / 16.0) * 16.0
	while z < b:
		for j in _trunk.size() - 1:
			var p0 := _trunk[j]
			var p1 := _trunk[j + 1]
			var d := (p1 - p0)
			var L := d.length()
			var dn := d / L
			var inward := Vector2(-dn.y, dn.x)
			var mid := (p0 + p1) * 0.5 + inward * 0.2
			var bs := Basis(Vector3(dn.x, dn.y, 0.0), Vector3(inward.x, inward.y, 0.0), Vector3(0, 0, 1))
			_box("r_rust", z, mid.x, mid.y, Vector3(L * 0.5 + 0.12, 0.2, 0.22), bs)
		z += 16.0
	# lamps on alternate walls every 26 m (the Sigil smashes the ones it scrapes past)
	z = ceilf(a / 26.0) * 26.0
	while z < b:
		var side := 1.0 if int(z / 26.0) % 2 == 0 else -1.0
		_lamp(z, side * 9.0, 5.4, side, node)
		z += 26.0
	if broken:
		for hb in _breaks_in(a, b):
			for k in 9:      # what came down
				var u := rng.randf_range(-6.0, 7.0)
				var w := rng.randf_range(0.4, 1.3)
				_box("r_brick", hb + rng.randf_range(-3.5, 3.5), u, w * 0.5 - 0.2, Vector3(w, w * 0.6, w * rng.randf_range(0.6, 1.2)), Basis(Vector3.UP, rng.randf() * TAU), 0.8)
			var l := OmniLight3D.new()      # the green of the old city through the hole
			l.position = pt(hb, 0.0, 12.5)
			l.light_color = Color("7dffb0")
			l.light_energy = 1.4 * GAIN
			l.omni_range = 16.0
			l.omni_attenuation = 1.2
			node.add_child(l)


func _breaks_in(a: float, b: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for hb in breaches:
		if hb >= a and hb < b:
			out.append(hb)
	return out


func _lamp(sig: float, u: float, h: float, side: float, node: Node3D) -> void:
	_box("r_iron", sig, u + side * 0.25, h + 0.25, Vector3(0.35, 0.05, 0.05))
	var g := MeshInstance3D.new()
	g.mesh = _lamp_box
	g.material_override = rb.mats["r_lamp"]
	g.transform = frame_at(sig) * Transform3D(Basis.IDENTITY, Vector3(u - side * 0.1, h, 0.0))
	node.add_child(g)
	var l := OmniLight3D.new()
	l.position = pt(sig, u - side * 0.9, h - 0.3)
	l.light_color = Color("ffb872")
	l.light_energy = 1.35 * GAIN
	l.omni_range = 18.0
	l.omni_attenuation = 1.3
	l.distance_fade_enabled = true
	l.distance_fade_begin = 110.0
	l.distance_fade_length = 25.0
	node.add_child(l)
	var lp := Lamp.new()
	lp.sig = sig
	lp.side = side
	lp.light = l
	lp.glow = g
	lamps.append(lp)


## A frame of soot-black brick round the tunnel's mouth where it leaves the chamber (the chamber side of it is the chamber's own wall)
func _portal_frame(sig: float) -> void:
	for j in _trunk.size() - 1:
		var p0 := _trunk[j]
		var p1 := _trunk[j + 1]
		var d := p1 - p0
		var L := d.length()
		var dn := d / L
		var inward := Vector2(-dn.y, dn.x)
		var mid := (p0 + p1) * 0.5 + inward * 0.35
		_box("r_soot", sig + 1.2, mid.x, mid.y, Vector3(L * 0.5 + 0.2, 0.35, 1.2), Basis(Vector3(dn.x, dn.y, 0.0), Vector3(inward.x, inward.y, 0.0), Vector3(0, 0, 1)))


## A wall across the route at sigma with a hole the shape of `hole` (a section whose top is one height for each u): the cavern wall the line comes out of, a bore's end, SERN's wall.
## facing +1: it faces on along the route (you see it looking back), -1: back down it. reach_u: how far it goes out each side; low, high: from and to what height.
func _cliff(sig: float, hole: PackedVector2Array, facing: float, reach_u: float = 230.0, low: float = VIA_H - 1.0, high: float = SLAB_H, tag: String = "rock") -> void:
	var f := frame_at(sig)
	var umin := 1e9
	var umax := -1e9
	for p in hole:
		umin = minf(umin, p.x)
		umax = maxf(umax, p.x)
	var t := tag
	_wall_q(t, f, umax, reach_u, low, high, facing)
	_wall_q(t, f, -reach_u, umin, low, high, facing)
	_wall_q(t, f, umin, umax, low, hole[0].y if hole[0].y < 0.0 else -0.3, facing)
	for j in hole.size() - 1:      # above the hole's top line, up to `high`
		var p0 := hole[j]
		var p1 := hole[j + 1]
		if absf(p1.x - p0.x) < 0.01:
			continue
		var a0 := Vector3(p0.x, p0.y, 0.0)
		var a1 := Vector3(p1.x, p1.y, 0.0)
		var t0 := Vector3(p0.x, high, 0.0)
		var t1 := Vector3(p1.x, high, 0.0)
		if (p1.x < p0.x) == (facing > 0.0):
			rb.quad_uv(t, f * a1, f * t1, f * t0, f * a0, Vector2(p1.x, -p1.y), Vector2(p1.x, -high), Vector2(p0.x, -high), Vector2(p0.x, -p0.y), 0.8, 0.3)
		else:
			rb.quad_uv(t, f * a0, f * t0, f * t1, f * a1, Vector2(p0.x, -p0.y), Vector2(p0.x, -high), Vector2(p1.x, -high), Vector2(p1.x, -p1.y), 0.8, 0.3)


## one flat piece of a wall across the route: u0..u1 (u1 > u0), h0..h1, facing +1 on along the route, -1 back down it
func _wall_q(tag: String, f: Transform3D, u0: float, u1: float, h0: float, h1: float, facing: float) -> void:
	if u1 <= u0 or h1 <= h0:
		return
	var A := f * Vector3(u0, h0, 0.0)
	var B := f * Vector3(u0, h1, 0.0)
	var C := f * Vector3(u1, h1, 0.0)
	var D := f * Vector3(u1, h0, 0.0)
	if facing > 0.0:
		rb.quad_uv(tag, A, B, C, D, Vector2(u0, -h0), Vector2(u0, -h1), Vector2(u1, -h1), Vector2(u1, -h0), 0.85, 0.3)
	else:
		rb.quad_uv(tag, D, C, B, A, Vector2(u1, -h0), Vector2(u1, -h1), Vector2(u0, -h1), Vector2(u0, -h0), 0.85, 0.3)


# ---- the twin bores ---------------------------------------------------------------------------------------------------------------------------------------------------------

## Two bores side by side under one flat roof, a row of brick piers between them: the train in the left, the Sigil in the right (it smashes the piers it passes)
func _twin(a: float, b: float, p0: float, p1: float, node: Node3D, later: Array[Callable]) -> void:
	_sweep("r_ground", a, b, PackedVector2Array([Vector2(-29.5, -0.3), Vector2(9.5, -0.3)]))
	_sweep("r_brick", a, b, PackedVector2Array([Vector2(9.5, -0.3), Vector2(9.5, 12.5)]))
	_sweep("r_soot", a, b, PackedVector2Array([Vector2(9.5, 12.5), Vector2(-29.5, 12.5)]))
	_sweep("r_brick", a, b, PackedVector2Array([Vector2(-29.5, 12.5), Vector2(-29.5, -0.3)]))
	_sweep("r_brick", a, b, PackedVector2Array([Vector2(-9.0, 12.5), Vector2(-9.0, 9.4), Vector2(-11.0, 9.4), Vector2(-11.0, 12.5)]))      # the lintel the piers carry
	_track(a, b, 0.0)
	_track(a, b, -19.5, true)
	var z := ceilf(a / 26.0) * 26.0
	while z < b:
		_lamp(z, 9.0, 5.4, 1.0, node)
		if z + 13.0 < b:
			_lamp(z + 13.0, -29.0, 5.4, -1.0, node)
		z += 26.0
	if a <= p0 + 0.01:
		_cliff(p0, _trunk, 1.0, 29.5, -0.3, 12.5, "r_brick")      # the end of the twin bores where the single one comes in
	if b >= p1 - 0.01:
		_cliff(p1, _trunk, -1.0, 29.5, -0.3, 12.5, "r_brick")
	z = ceilf((a - p0) / 9.0) * 9.0 + p0
	while z < b:
		var zz := z
		if zz > p0 + 3.0 and zz < p1 - 3.0:
			later.append(func() -> void: _pier(zz, node))
		z += 9.0


func _pier(sig: float, node: Node3D) -> void:
	_box("r_brick", sig, -10.0, 4.6, Vector3(0.85, 4.9, 1.5))
	_box("r_soot", sig, -10.0, 0.0, Vector3(1.05, 0.35, 1.7))
	var pn := Node3D.new()
	pn.name = "pier"
	node.add_child(pn)
	rb.commit(pn)
	var t := Thing.new()
	t.sig = sig
	t.u = -10.0
	t.h = 4.6
	t.node = pn
	piers.append(t)


# ---- SERN's depot ----------------------------------------------------------------------------------------------------------------------------------------------------------

## The trunk widens to the right into an old SERN fuel siding: a platform, tanks on cradles, drums, crates, hazard paint. The tanks go up when the Sigil plows through them.
func _depot(a: float, b: float, p0: float, p1: float, node: Node3D, later: Array[Callable]) -> void:
	_sweep("r_ground", a, b, PackedVector2Array([Vector2(-23.0, -0.3), Vector2(9.5, -0.3)]))
	_sweep("r_brick", a, b, PackedVector2Array([Vector2(9.5, -0.3), Vector2(9.5, 12.5)]))
	_sweep("r_soot", a, b, PackedVector2Array([Vector2(9.5, 12.5), Vector2(-23.0, 12.5)]))
	_sweep("r_brick", a, b, PackedVector2Array([Vector2(-23.0, 12.5), Vector2(-23.0, -0.3)]))
	_sweep("r_concrete", a, b, PackedVector2Array([Vector2(-23.0, 1.1), Vector2(-11.5, 1.1), Vector2(-11.5, -0.3)]))      # the platform: its top and its edge
	_sweep("r_hazard", a, b, PackedVector2Array([Vector2(-11.48, 1.1), Vector2(-11.48, 0.4)]), 0.0, false)
	_track(a, b, 0.0)
	_track(a, b, -7.2, true)
	if a <= p0 + 0.01:
		_cliff(p0, _trunk, 1.0, 23.0, -0.3, 12.5, "r_brick")
	if b >= p1 - 0.01:
		_cliff(p1, _trunk, -1.0, 23.0, -0.3, 12.5, "r_brick")
	var z := ceilf(a / 14.0) * 14.0
	while z < b:      # roof girders and hanging lamps
		_box("r_rust", z, -6.75, 12.1, Vector3(16.3, 0.3, 0.25))
		if int(z / 14.0) % 2 == 0:
			_box("r_iron", z, -6.0, 10.6, Vector3(0.03, 1.5, 0.03))
			_lamp_hang(z, -6.0, 9.0, node)
		z += 14.0
	z = ceilf(a / 26.0) * 26.0
	while z < b:
		_lamp(z, 9.0, 5.4, 1.0, node)
		z += 26.0
	z = ceilf((a - p0 - 18.0) / 30.0) * 30.0 + p0 + 18.0
	while z < b:      # a tank every 30 m, drums and crates between
		var zz := z
		if zz < p1 - 12.0:
			later.append(func() -> void: _tank(zz, node))
			for k in 6:
				var dz := rng.randf_range(7.0, 22.0)
				var u := rng.randf_range(-21.5, -13.0)
				if zz + dz < b:
					rb.ocyl("r_tank" if k % 3 != 0 else "r_rust", frame_at(zz + dz) * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(u, 1.55, 0.0)), 0.3, 0.45, 10)
			_box("r_planks", zz + 15.0, -20.0, 1.75, Vector3(0.65, 0.65, 0.65), Basis(Vector3.UP, 0.3))
			_box("r_hazard", zz + 4.0, -22.95, 5.0, Vector3(0.04, 0.6, 1.6))
		z += 30.0


func _tank(sig: float, node: Node3D) -> void:
	var f := frame_at(sig)
	rb.ocyl("r_tank", f * Transform3D(Basis.IDENTITY, Vector3(-17.0, 2.85, 0.0)), 1.6, 4.4, 16)
	for dz: float in [-2.8, 2.8]:      # cradles, and a band of stripes round each end
		rb.obox("r_iron", f * Transform3D(Basis.IDENTITY, Vector3(-17.0, 1.55, dz)), Vector3(1.5, 0.45, 0.25))
		rb.ocyl("r_hazard", f * Transform3D(Basis.IDENTITY, Vector3(-17.0, 2.85, dz * 1.3)), 1.63, 0.18, 16, false)
	rb.ocyl("r_iron", f * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-17.0, 4.6, 0.0)), 0.3, 0.3, 8)      # the filler
	var tn := Node3D.new()
	tn.name = "tank"
	node.add_child(tn)
	rb.commit(tn)
	var t := Thing.new()
	t.sig = sig
	t.u = -17.0
	t.h = 2.85
	t.node = tn
	tanks.append(t)


func _lamp_hang(sig: float, u: float, h: float, node: Node3D) -> void:
	var g := MeshInstance3D.new()
	g.mesh = _lamp_box
	g.material_override = rb.mats["r_lamp"]
	g.transform = frame_at(sig) * Transform3D(Basis.IDENTITY, Vector3(u, h, 0.0))
	node.add_child(g)
	var l := OmniLight3D.new()
	l.position = pt(sig, u, h - 0.6)
	l.light_color = Color("ffb06a")
	l.light_energy = 1.6 * GAIN
	l.omni_range = 20.0
	l.omni_attenuation = 1.3
	l.distance_fade_enabled = true
	l.distance_fade_begin = 110.0
	l.distance_fade_length = 25.0
	node.add_child(l)
	var lp := Lamp.new()
	lp.sig = sig
	lp.side = -1.0
	lp.light = l
	lp.glow = g
	lamps.append(lp)


# ---- the viaduct ------------------------------------------------------------------------------------------------------------------------------------------------------------

## Out of the cavern wall onto the old viaduct: a deck and parapets on stone piers 34 m over the old city's streets, the dead city all round, FOINT's piles going up into the slab and the new city's
## light coming down through its grates. The spans between FALL0 and FALL1 into the "ahead" piece are their own nodes: they fall behind the train.
func _viaduct(a: float, b: float, nm: String, node: Node3D, later: Array[Callable]) -> void:
	var fa := mark("ahead") + FALL0
	var fb := mark("ahead") + FALL1
	var ranges: Array[Vector2] = []
	if b <= fa or a >= fb:
		ranges.append(Vector2(a, b))
	else:
		if a < fa:
			ranges.append(Vector2(a, fa))
		if b > fb:
			ranges.append(Vector2(fb, b))
		var z := fa
		while z < fb:      # each falling span on its own
			var z0 := z
			var z1 := minf(fb, z + SPAN)
			if z1 > a and z0 < b and z0 >= a - 0.01:
				later.append(func() -> void: _span(z0, z1, node))
			z += SPAN
	for r in ranges:
		_deck(r.x, r.y)
	# the street far under it, and the slab far over it
	_sweep("r_street", a, b, PackedVector2Array([Vector2(-170.0, VIA_H), Vector2(170.0, VIA_H)]), 1.0, false)
	_sweep("r_slab", a, b, PackedVector2Array([Vector2(170.0, SLAB_H), Vector2(-170.0, SLAB_H)]), 0.0, false)
	var z := ceilf(a / SPAN) * SPAN
	while z < b:      # a pier every span; a lamp standard on the left parapet every other
		_box("r_stone", z, 0.0, (VIA_H - 1.8) * 0.5, Vector3(3.8, (-VIA_H - 1.8) * 0.5, 1.4), Basis.IDENTITY, 0.8)
		_box("r_stone", z, 0.0, -2.2, Vector3(5.6, 0.45, 1.8))
		if int(z / SPAN) % 2 == 0:
			_box("r_iron", z, 4.75, 3.2, Vector3(0.08, 2.4, 0.08))
			_box("r_iron", z, 4.2, 5.6, Vector3(0.6, 0.06, 0.06))
			if int(z / SPAN) % 6 == 0:
				var g := MeshInstance3D.new()
				g.mesh = _lamp_box
				g.material_override = rb.mats["r_lamp"]
				g.transform = frame_at(z) * Transform3D(Basis.IDENTITY, Vector3(3.7, 5.35, 0.0))
				node.add_child(g)
				var l := OmniLight3D.new()
				l.position = pt(z, 3.7, 4.6)
				l.light_color = Color("ffb872")
				l.light_energy = 1.4 * GAIN
				l.omni_range = 20.0
				l.omni_attenuation = 1.3
				l.distance_fade_enabled = true
				l.distance_fade_begin = 140.0
				l.distance_fade_length = 30.0
				node.add_child(l)
		z += SPAN
	# FOINT's piles, the slab's beams and its grates with the new city's light coming through, the dead city's streets and its skyline.
	# (2026-11-15, audit: it read as "white ladder lines on grey boxes, and magenta rectangles floating with nothing holding them up". The piles were plain boxes with two full-height cyan strips and a
	# band every 9 m, which bloomed to white ladders; the grates were glowing tiles on a black slab nobody could see; and the city itself was unlit, black on black, so only those shapes read. Now the
	# piles are columns with a footing and a capital spread into the slab and a few service lamps, the slab has its beams with the grates framed between them, the streets under the bridge have
	# their old lamps (most still burning), and the dead blocks go on out to a skyline in the haze with somebody's window lit here and there.)
	z = ceilf(a / 44.0) * 44.0
	while z < b:
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		var u := side * rng.randf_range(34.0, 140.0)
		_pile(z, u, Basis(Vector3.UP, rng.randf() * 0.6))
		for k in 3:
			var gu := rng.randf_range(-150.0, 150.0)
			var gz := z + rng.randf_range(-20.0, 20.0)
			if gz > a and gz < b:
				var gw := rng.randf_range(1.5, 3.5)
				var gl := rng.randf_range(1.5, 3.5)
				_box("r_grate" if k % 2 == 0 else "r_grate2", gz, gu, SLAB_H - 0.9, Vector3(gw, 0.05, gl))
				for e: float in [-1.0, 1.0]:      # its frame: the grate is set in the slab, down between the beams
					_box("r_iron", gz, gu + e * (gw + 0.35), SLAB_H - 0.45, Vector3(0.35, 0.5, gl + 0.7))
					_box("r_iron", gz + e * (gl + 0.35), gu, SLAB_H - 0.45, Vector3(gw, 0.5, 0.35))
				if k != 1:      # its light coming down through the haze
					_shaft(gz, gu, gw * 1.6, k == 0, node)
		z += 44.0
	# the slab's beams: across the line every 30 m, and along it here and there (dark, but they put the grates and the lamps in something)
	z = ceilf(a / 30.0) * 30.0
	while z < b:
		_box("r_pile", z, 0.0, SLAB_H - 1.6, Vector3(170.0, 1.6, 1.1), Basis.IDENTITY, 0.7)
		if int(z / 30.0) % 3 == 0:
			for bu: float in [-120.0, -64.0, 64.0, 120.0]:      # a sodium lamp under the beam, still burning
				_box("r_lamp", z, bu, SLAB_H - 3.35, Vector3(0.35, 0.12, 0.35))
		z += 30.0
	for bu: float in [-150.0, -95.0, -45.0, 45.0, 95.0, 150.0]:
		_sweep("r_pile", a, b, PackedVector2Array([Vector2(bu + 1.0, SLAB_H), Vector2(bu + 1.0, SLAB_H - 2.6), Vector2(bu - 1.0, SLAB_H - 2.6), Vector2(bu - 1.0, SLAB_H)]), 0.0, false)
	# the old streets under the bridge: one each side running with the line, a lamp post every 16 m (a few out), and the cross street at every other pier
	for side: float in [-1.0, 1.0]:
		z = ceilf(a / 16.0) * 16.0
		while z < b:
			var su := side * (26.0 + 9.0 * sin(z * 0.004 + side))      # (a street that wanders, the same either side of a chunk's edge)
			_box("r_iron", z, su, VIA_H + 2.6, Vector3(0.09, 2.6, 0.09))
			if fposmod(z * 0.37 + side * 3.1, 7.0) > 1.3:
				_box("r_lamp", z, su - side * 0.6, VIA_H + 5.2, Vector3(0.32, 0.1, 0.22))
				_box("r_iron", z, su - side * 0.3, VIA_H + 5.35, Vector3(0.45, 0.05, 0.05))
			z += 16.0
	z = ceilf(a / (SPAN * 2.0)) * SPAN * 2.0 + SPAN * 0.5
	while z < b:
		var cu := -60.0
		while cu < 60.0:
			if absf(cu) > 8.0:
				_box("r_lamp", z, cu, VIA_H + 5.2, Vector3(0.22, 0.1, 0.32))
				_box("r_iron", z + 0.4, cu, VIA_H + 2.6, Vector3(0.09, 2.6, 0.09))
			cu += 17.0
		z += SPAN * 2.0
	# the skyline: the dead blocks further out, plain masses in the haze with a window lit here and there
	z = ceilf(a / 13.0) * 13.0
	while z < b:
		for side: float in [-1.0, 1.0]:
			if rng.randf() < 0.35:
				continue
			var fu := side * rng.randf_range(105.0, 168.0)
			var fh := rng.randf_range(22.0, 62.0)      # (the old city's towers: up past the bridge's deck, so from the car it is a skyline, not fog)
			var fw := rng.randf_range(7.0, 13.0)
			var turn := Basis(Vector3.UP, rng.randf_range(-0.2, 0.2))
			_box("r_far", z, fu, VIA_H + fh * 0.5, Vector3(fw, fh * 0.5, fw * rng.randf_range(0.7, 1.2)), turn, 0.8)
			if rng.randf() < 0.5:      # a stub on its roof: a tank, a stair head
				_box("r_far", z + rng.randf_range(-3.0, 3.0), fu + rng.randf_range(-3.0, 3.0), VIA_H + fh + 1.4, Vector3(1.6, 1.4, 1.6), turn, 0.8)
			for k in rng.randi_range(1, 6):
				var wy := VIA_H + rng.randf_range(3.0, fh - 2.0)
				_box("r_window" if rng.randf() < 0.8 else "r_tv", z + rng.randf_range(-fw * 0.6, fw * 0.6), fu - side * (fw + 0.05), wy, Vector3(0.05, 0.6, 0.45), turn)
		z += 13.0
	var roofs := nm == "roofs"
	z = ceilf(a / 21.0) * 21.0
	while z < b:
		for side: float in [-1.0, 1.0]:
			if rng.randf() < 0.45:
				continue
			if roofs and side > 0.0 and z > mark("roofs") + 10.0 and z < mark("roofs") + 190.0:
				continue      # the left side of the rooftop run is the beast's buildings (below)
			var near := rng.randf_range(20.0, 95.0)
			var w := rng.randf_range(12.0, 20.0)
			var c := pt(z, side * (near + w * 0.5), VIA_H)
			var floors := rng.randi_range(3, 12)      # (was 3..9: every roof was under the deck, out of sight from the car)
			arch.building({"x0": c.x - w * 0.5, "x1": c.x + w * 0.5, "z0": c.z - w * 0.5, "z1": c.z + w * 0.5, "y": c.y + 0.1, "floors": floors,
				"wall": ["brick", "brick2", "plaster", "stone"][rng.randi() % 4], "trim": "trim", "ruin": rng.randf() < 0.45, "shade": rng.randf_range(0.6, 0.95), "collide": false})
			_windows_lit(c, w, floors)
			if rng.randf() < 0.22:      # something still burning down there, and its light on the streets
				var fp := c + Vector3(rng.randf_range(-4.0, 4.0), rng.randf_range(4.0, 12.0), rng.randf_range(-4.0, 4.0))
				fires.append([z, fp, rng.randf_range(1.2, 2.6)])
				var l := OmniLight3D.new()
				l.position = fp + Vector3(0.0, 2.0, 0.0)
				l.light_color = Color("ff7a2e")
				l.light_energy = 3.0 * GAIN
				l.omni_range = 28.0
				l.omni_attenuation = 1.1
				l.distance_fade_enabled = true
				l.distance_fade_begin = 220.0
				l.distance_fade_length = 40.0
				node.add_child(l)
		z += 21.0
	if roofs:
		z = ceilf((a - mark("roofs") - 30.0) / 45.0) * 45.0 + mark("roofs") + 30.0
		while z < b:
			var zz := z
			if zz < mark("roofs") + 190.0:
				later.append(func() -> void: _roof(zz, node))
			z += 45.0


## One of FOINT's piles, from the old city's street to the new city's slab: a footing, the shaft with its corners cut, a capital spread out under the slab, a service lamp up two corners every
## 11 m and red lamps near the top. (Was a plain box with two full-height strip lights and a band every 9 m: from the bridge, glowing white ladders.)
func _pile(z: float, u: float, turn: Basis) -> void:
	var mid := (VIA_H + SLAB_H) * 0.5
	var half := (SLAB_H - VIA_H) * 0.5
	_box("r_pile", z, u, mid, Vector3(2.6, half, 2.6), turn)
	_box("r_pile", z, u, mid, Vector3(3.05, half, 1.9), turn)      # (the two crossed make the cut corners)
	_box("r_pile", z, u, mid, Vector3(1.9, half, 3.05), turn)
	_box("r_concrete", z, u, VIA_H + 1.6, Vector3(4.4, 1.6, 4.4), turn, 0.7)      # the footing
	_box("r_pile", z, u, SLAB_H - 3.0, Vector3(4.0, 1.4, 4.0), turn)      # the capital, stepped out to the slab
	_box("r_pile", z, u, SLAB_H - 1.0, Vector3(5.6, 1.0, 5.6), turn)
	var f := frame_at(z) * Transform3D(turn, Vector3(u, 0.0, 0.0))
	var hb := VIA_H + 8.0
	var k := 0
	while hb < SLAB_H - 6.0:
		var cx := 2.75 if k % 2 == 0 else -2.75
		rb.obox("r_beacon", f * Transform3D(Basis.IDENTITY, Vector3(cx, hb, 2.75)), Vector3(0.14, 0.22, 0.14))
		rb.obox("r_beacon", f * Transform3D(Basis.IDENTITY, Vector3(-cx, hb + 5.5, -2.75)), Vector3(0.14, 0.22, 0.14))
		hb += 11.0
		k += 1
	for hh: float in [SLAB_H - 7.0]:
		rb.obox("r_red", f * Transform3D(Basis.IDENTITY, Vector3(3.08, hh, 0.0)), Vector3(0.05, 0.3, 0.3))
		rb.obox("r_red", f * Transform3D(Basis.IDENTITY, Vector3(-3.08, hh, 0.0)), Vector3(0.05, 0.3, 0.3))


## A few windows still lit in a dead building (somebody lives down there): on its four faces, here and there up it
func _windows_lit(c: Vector3, w: float, floors: int) -> void:
	for k in rng.randi_range(2, 8):
		var face := rng.randi() % 4
		var along := rng.randf_range(-w * 0.38, w * 0.38)
		var y := c.y + 2.6 + rng.randi_range(0, maxi(0, floors - 1)) * 3.4
		var off := w * 0.5 + 0.06
		var at := c + (Vector3(along, 0.0, off) if face == 0 else (Vector3(along, 0.0, -off) if face == 1 else (Vector3(off, 0.0, along) if face == 2 else Vector3(-off, 0.0, along))))
		at.y = y
		var h := Vector3(0.55, 0.75, 0.04) if face < 2 else Vector3(0.04, 0.75, 0.55)
		rb.obox("r_window", Transform3D(Basis.IDENTITY, at), h)


## A shaft of FOINT CITY's light down through a grate in the slab: a tall soft billboard turned to the eye about its upright
func _shaft(sig: float, u: float, w: float, cyan: bool, node: Node3D) -> void:
	if _shaft_mats.is_empty():
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 0.0))
		g.add_point(0.25, Color(1, 1, 1, 0.55))
		g.set_color(1, Color(1, 1, 1, 0.0))
		g.add_point(0.97, Color(1, 1, 1, 0.9))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill_from = Vector2(0.5, 1.0)
		gt.fill_to = Vector2(0.5, 0.0)
		gt.width = 8
		gt.height = 128
		for col: Color in [Color(0.35, 0.7, 1.0), Color(0.7, 0.4, 1.0)]:
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.no_depth_test = false
			m.albedo_texture = gt
			m.albedo_color = Color(col.r, col.g, col.b, 0.32)
			_shaft_mats.append(m)
	var q := QuadMesh.new()
	q.size = Vector2(w, SLAB_H - VIA_H - 6.0)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = _shaft_mats[0 if cyan else 1]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pt(sig, u, (SLAB_H + VIA_H) * 0.5 + 3.0)
	node.add_child(mi)


func _deck(a: float, b: float) -> void:
	_sweep("r_deck", a, b, PackedVector2Array([Vector2(-5.2, -0.3), Vector2(5.2, -0.3), Vector2(5.2, -1.8), Vector2(-5.2, -1.8), Vector2(-5.2, -0.3)]))
	for side: float in [-1.0, 1.0]:      # parapets, broken here and there
		var u0 := side * 4.7
		var u1 := side * 5.25
		var x := a
		while x < b:
			var run := rng.randf_range(10.0, 26.0)
			var e := minf(b, x + run)
			var p := PackedVector2Array([Vector2(minf(u0, u1), -0.3), Vector2(minf(u0, u1), 0.9), Vector2(maxf(u0, u1), 0.9), Vector2(maxf(u0, u1), -0.3)])
			_sweep("r_brick", x, e, p)
			x = e + (rng.randf_range(2.0, 5.0) if rng.randf() < 0.35 else 0.0)
	_track(a, b, 0.0)


func _span(z0: float, z1: float, node: Node3D) -> void:
	_deck(z0, z1)
	var sn := Node3D.new()
	sn.name = "span"
	node.add_child(sn)
	rb.commit(sn)
	var t := Thing.new()
	t.sig = (z0 + z1) * 0.5
	t.node = sn
	t.rest = sn.transform
	spans.append(t)


## One of the buildings by the viaduct that the Sigil bounds across: a flat roof level with the deck, hard against the bridge's left side.
## (They stood 27 m off and 5 m under the deck: from the car it was a dim shape in the haze behind the parapet, and its attack from there landed across 26 m of air. User 2026-11-13.)
func _roof(sig: float, node: Node3D) -> void:
	var u := ROOF_U + rng.randf_range(-1.0, 1.5)
	var w := rng.randf_range(15.0, 19.0)
	var c := pt(sig, u, VIA_H)
	var floors := 10
	arch.building({"x0": c.x - w * 0.5, "x1": c.x + w * 0.5, "z0": c.z - w * 0.5, "z1": c.z + w * 0.5, "y": c.y + 0.1, "floors": floors, "wall": ["brick", "plaster", "stone"][rng.randi() % 3],
		"trim": "trim", "ruin": false, "shade": 0.8, "collide": false})
	var bn := Node3D.new()
	bn.name = "roof"
	node.add_child(bn)
	rb.commit(bn)
	var t := Thing.new()
	t.sig = sig
	t.u = u
	t.h = ROOF_H
	t.node = bn
	t.rest = bn.transform
	blds.append(t)
	# its water tank: a wooden tank on an iron stand at the roof's edge nearest the line (2026-11-15: the roofs were only to watch; this is the player's way to bring one down under it)
	var f := frame_at(sig)
	var tu := u - w * 0.5 + 3.2
	var up := Basis(Vector3.RIGHT, -PI * 0.5)
	for q: Vector2 in [Vector2(-1.0, -1.0), Vector2(1.0, -1.0), Vector2(-1.0, 1.0), Vector2(1.0, 1.0)]:
		rb.obox("r_rust", f * Transform3D(Basis.IDENTITY, Vector3(tu + q.x * 1.05, ROOF_H + 1.5, q.y * 1.05)), Vector3(0.09, 1.5, 0.09))
	rb.obox("r_iron", f * Transform3D(Basis.IDENTITY, Vector3(tu, ROOF_H + 3.05, 0.0)), Vector3(1.3, 0.08, 1.3))
	rb.ocyl("r_planks", f * Transform3D(up, Vector3(tu, ROOF_H + 4.3, 0.0)), 1.45, 1.2, 14)
	for hb: float in [3.6, 4.4, 5.2]:
		rb.ocyl("r_iron", f * Transform3D(up, Vector3(tu, ROOF_H + hb, 0.0)), 1.48, 0.07, 14, false)
	rb.ocyl("r_iron", f * Transform3D(up, Vector3(tu, ROOF_H + 5.85, 0.0)), 1.55, 0.35, 14, true, 1.0, 0.1, 0.0)
	var tn := Node3D.new()
	tn.name = "tower"
	node.add_child(tn)
	rb.commit(tn)
	var tw := Thing.new()
	tw.sig = sig
	tw.u = tu
	tw.h = ROOF_H + 4.3
	tw.node = tn
	tw.rest = tn.transform
	towers.append(tw)


# ---- SERN ------------------------------------------------------------------------------------------------------------------------------------------------------------------

## The end of the viaduct: a wall of SERN concrete across the line with a blast door in it, stripes round it. The door leaves are their own nodes: the train goes through them.
func _blast(a: float, b: float, p0: float, p1: float, node: Node3D, later: Array[Callable]) -> void:
	var wz := p0 + 8.0
	if a < wz:
		_deck(a, minf(b, wz))
		_sweep("r_street", a, minf(b, wz), PackedVector2Array([Vector2(-170.0, VIA_H), Vector2(170.0, VIA_H)]), 1.0, false)
		_sweep("r_slab", a, minf(b, wz), PackedVector2Array([Vector2(170.0, SLAB_H), Vector2(-170.0, SLAB_H)]), 0.0, false)
	if a <= wz and b > wz:
		_cliff(wz, _sern, -1.0, 230.0, VIA_H - 1.0, SLAB_H, "r_concrete")
		for side: float in [-1.0, 1.0]:      # the frame: posts and a lintel striped yellow and black
			_box("r_hazard", wz - 0.6, side * 7.6, 4.8, Vector3(0.6, 5.1, 0.6))
			_box("r_concrete", wz - 0.15, side * (7.0 + SERN_W) * 0.5, SERN_H * 0.5, Vector3((SERN_W - 7.0) * 0.5 + 0.05, SERN_H * 0.5, 0.3))      # (the line is wider and higher than the door: the wall fills round it)
		_box("r_hazard", wz - 0.6, 0.0, 10.4, Vector3(8.2, 0.7, 0.6))
		_box("r_concrete", wz - 0.15, 0.0, (10.1 + SERN_H) * 0.5, Vector3(7.05, (SERN_H - 10.1) * 0.5, 0.3))
		for k in 2:
			var side := 1.0 if k == 0 else -1.0
			later.append(func() -> void: _door(wz - 0.2, side, node))
	if b > wz:
		_sern_part(maxf(a, wz), b, node)


func _door(sig: float, side: float, node: Node3D) -> void:
	_box("r_steel", sig, side * 3.5, 4.75, Vector3(3.5, 5.05, 0.35))
	_box("r_hazard", sig - 0.36, side * 3.5, 4.75, Vector3(3.4, 0.5, 0.02), Basis.IDENTITY)
	var dn := Node3D.new()
	dn.name = "door"
	node.add_child(dn)
	rb.commit(dn)
	var t := Thing.new()
	t.sig = sig
	t.u = side * 3.5
	t.h = 4.75
	t.node = dn
	t.rest = dn.transform
	doors.append(t)


## SERN's own line: a box of steel panels with the corners cut, stripes along its foot, strip lights in the upper corners, red lamps that strobe when it goes wrong
func _sern_part(a: float, b: float, node: Node3D) -> void:
	_dress(a, b, node, SERN_W)
	_sweep("r_concrete", a, b, PackedVector2Array([Vector2(-7.0, -0.3), Vector2(7.0, -0.3)]))
	_sweep("r_panel", a, b, _sern.slice(0, 2))
	_sweep("r_steel", a, b, _sern.slice(1, _sern.size() - 1))
	_sweep("r_panel", a, b, _sern.slice(_sern.size() - 2, _sern.size()))
	var W := SERN_W
	_sweep("r_hazard", a, b, PackedVector2Array([Vector2(W - 0.03, -0.3), Vector2(W - 0.03, 0.7)]), 0.0, false)
	_sweep("r_hazard", a, b, PackedVector2Array([Vector2(-W + 0.03, 0.7), Vector2(-W + 0.03, -0.3)]), 0.0, false)
	_sweep("r_strip", a, b, PackedVector2Array([Vector2(W - 0.9, SERN_H - 0.45), Vector2(W - 1.4, SERN_H - 0.45)]), 0.0, false)
	_sweep("r_strip", a, b, PackedVector2Array([Vector2(-W + 1.4, SERN_H - 0.45), Vector2(-W + 0.9, SERN_H - 0.45)]), 0.0, false)
	_sweep("r_rust", a, b, _poly(-W + 0.4, 3.4, 0.22, 8, true), 0.2, false)
	_sweep("r_rust", a, b, _poly(-W + 0.35, 4.0, 0.14, 6, true), 0.2, false)
	_track(a, b, 0.0)
	var z := ceilf(a / 24.0) * 24.0
	while z < b:
		var l := OmniLight3D.new()
		l.position = pt(z, 0.0, SERN_H - 1.1)
		l.light_color = Color("bfe8ff")
		l.light_energy = 1.1 * GAIN
		l.omni_range = 22.0      # (the line is wider now)
		l.omni_attenuation = 1.4
		l.distance_fade_enabled = true
		l.distance_fade_begin = 110.0
		l.distance_fade_length = 25.0
		node.add_child(l)
		if int(z / 24.0) % 2 == 0:      # a red alarm lamp on the wall
			var side := 1.0 if int(z / 48.0) % 2 == 0 else -1.0
			var g := MeshInstance3D.new()
			g.mesh = _lamp_box
			g.material_override = rb.mats["r_red"]
			g.transform = frame_at(z) * Transform3D(Basis.IDENTITY, Vector3(side * (SERN_W - 0.2), 6.0, 0.0))
			node.add_child(g)
			var r := OmniLight3D.new()
			r.position = pt(z, side * (SERN_W - 1.4), 6.0)
			r.light_color = Color("ff3020")
			r.light_energy = 0.0
			r.omni_range = 14.0
			r.omni_attenuation = 1.2
			r.add_to_group(&"uf_alarm")
			node.add_child(r)
		z += 24.0


## The last stretch: SERN's portal hall, wider and higher, and the ring with the gate in it
func _gate_part(a: float, b: float, p0: float, _p1: float, nm: String, node: Node3D) -> void:
	var hall := PackedVector2Array([Vector2(16.0, -0.3), Vector2(16.0, 15.0), Vector2(-16.0, 15.0), Vector2(-16.0, -0.3)])
	_sweep("r_concrete", a, b, PackedVector2Array([Vector2(-16.0, -0.3), Vector2(16.0, -0.3)]))
	_sweep("r_panel", a, b, hall)
	_sweep("r_hazard", a, b, PackedVector2Array([Vector2(15.97, -0.3), Vector2(15.97, 0.9)]), 0.0, false)
	_sweep("r_hazard", a, b, PackedVector2Array([Vector2(-15.97, 0.9), Vector2(-15.97, -0.3)]), 0.0, false)
	_track(a, b, 0.0)
	if nm == "finale" and a <= p0 + 0.01:
		_cliff(p0, _sern, 1.0, 16.0, -0.3, 15.0, "r_panel")
	var z := ceilf(a / 20.0) * 20.0
	while z < b:
		_box("r_iron", z, 0.0, 14.6, Vector3(16.0, 0.4, 0.4))
		for side: float in [-1.0, 1.0]:
			_box("r_iron", z, side * 15.6, 7.3, Vector3(0.4, 7.4, 0.4))
			var g := MeshInstance3D.new()
			g.mesh = _lamp_box
			g.material_override = rb.mats["r_strip"]
			g.transform = frame_at(z) * Transform3D(Basis.IDENTITY, Vector3(side * 15.3, 12.0, 0.0))
			node.add_child(g)
		var l := OmniLight3D.new()
		l.position = pt(z, 0.0, 12.0)
		l.light_color = Color("c8b8ff")
		l.light_energy = 1.4 * GAIN
		l.omni_range = 26.0
		l.omni_attenuation = 1.3
		node.add_child(l)
		z += 20.0
	var gz := mark("finale") + 230.0
	if nm == "finale" and a <= gz and b > gz:      # SERN's ring, and the gate it holds open
		for k in 16:
			var ang := TAU * k / 16.0
			var c := Vector2(cos(ang) * 10.5, 7.2 + sin(ang) * 7.6)
			_box("r_steel", gz, c.x, c.y, Vector3(2.4, 0.9, 1.2), Basis(Vector3(0, 0, 1), ang + PI * 0.5))
			_box("r_hazard", gz - 1.25, c.x, c.y, Vector3(2.0, 0.5, 0.05), Basis(Vector3(0, 0, 1), ang + PI * 0.5))
		gate_mat = ShaderMaterial.new()
		gate_mat.shader = PORTAL
		gate_mat.set_shader_parameter(&"seed", 9.1)
		gate_mat.set_shader_parameter(&"open", 0.0)
		var q := QuadMesh.new()
		q.size = Vector2(1.0, 1.0)
		gate = MeshInstance3D.new()
		gate.name = "gate"
		gate.mesh = q
		gate.material_override = gate_mat
		gate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gate.transform = frame_at(gz) * Transform3D(Basis(Vector3.UP, PI).scaled(Vector3(21.0, 15.2, 1.0)), Vector3(0.0, 7.2, 0.0))
		node.add_child(gate)


# ---- the plug -------------------------------------------------------------------------------------------------------------------------------------------------------------

## What comes down across the tunnel when the Sigil hits its mouth: a heap of brick filling it from wall to roof just inside the chamber wall. Hidden until then.
func _build_plug() -> void:
	var z0 := mark("portal")
	for k in 70:
		var u := rng.randf_range(-9.0, 9.0)
		var top := 11.6 * sqrt(maxf(0.0, 1.0 - pow(u / 9.6, 2.0)))
		var h := rng.randf_range(0.0, top)
		var w := rng.randf_range(0.8, 2.2)
		_box("r_brick" if k % 3 != 0 else "r_soot", z0 + rng.randf_range(0.6, 4.0), u, h, Vector3(w, w * 0.7, w), Basis.from_euler(Vector3(rng.randf() * 0.6, rng.randf() * TAU, rng.randf() * 0.6)), 0.75)
	_wall_q("r_soot", frame_at(z0 + 3.0), -9.5, 9.5, -0.3, 12.0, 1.0)
	plug = Node3D.new()
	plug.name = "plug"
	add_child(plug)
	rb.commit(plug)
	plug.visible = false


# ---- what is left behind: smoke, fire, dust, rubble, flashes -----------------------------------------------------------------------------------------------------------------

func _build_fx() -> void:
	var made := []
	for k in 2:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = MsKit.quad()
		mm.instance_count = 1100 if k == 0 else 800
		var mat := ShaderMaterial.new()
		mat.shader = SMOKE if k == 0 else FIRE
		mat.set_shader_parameter(&"drag", 1.3 if k == 0 else 2.6)
		mat.set_shader_parameter(&"fade", 0.08 if k == 0 else 0.03)
		mat.set_shader_parameter(&"rise", 0.6 if k == 0 else 0.0)
		mat.render_priority = 5 if k == 0 else 6
		var node := MultiMeshInstance3D.new()
		node.name = "smoke" if k == 0 else "fire"
		node.multimesh = mm
		node.material_override = mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.custom_aabb = AABB(Vector3.ONE * -100000.0, Vector3.ONE * 200000.0)
		add_child(node)
		for i in mm.instance_count:
			mm.set_instance_custom_data(i, Color(0.0, 0.0, 1.0, -100.0))
		made.append([mm, mat])
	_smoke_mm = made[0][0]
	_smoke_mat = made[0][1]
	_fire_mm = made[1][0]
	_fire_mat = made[1][1]
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	for i in 44:
		var d := MeshInstance3D.new()
		d.mesh = cube
		d.material_override = rb.mats["r_brick" if i % 3 != 0 else "r_rust"]
		d.visible = false
		d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(d)
		_deb.append(d)
		_deb_v.append(Vector3.ZERO)
		_deb_w.append(Vector3.ZERO)
		_deb_t.append(-1.0)
	for i in 5:
		var l := OmniLight3D.new()
		l.light_color = Color("ff9a40")
		l.omni_attenuation = 1.5
		l.light_energy = 0.0
		l.visible = false
		add_child(l)
		_flash.append(l)
		_flash_t.append(0.0)
		_flash_e.append(0.0)


## smoke or dust (dark: soot; light: masonry dust), in the route's space: it stays where it was made and the train leaves it behind
func smoke(at: Vector3, v: Vector3, size: float, grow: float, life: float, col: Color) -> void:
	_smoke_mm.set_instance_transform(_smoke_i, Transform3D(Basis(v, Vector3.UP, Vector3.BACK), at))
	_smoke_mm.set_instance_color(_smoke_i, col)
	_smoke_mm.set_instance_custom_data(_smoke_i, Color(size, grow, life, _now))
	_smoke_i = (_smoke_i + 1) % _smoke_mm.instance_count


func fire(at: Vector3, v: Vector3, size: float, grow: float, life: float, col: Color) -> void:
	_fire_mm.set_instance_transform(_fire_i, Transform3D(Basis(v, Vector3.UP, Vector3.BACK), at))
	_fire_mm.set_instance_color(_fire_i, col)
	_fire_mm.set_instance_custom_data(_fire_i, Color(size, grow, life, _now))
	_fire_i = (_fire_i + 1) % _fire_mm.instance_count


## rubble thrown from a point: n pieces, speed out, w their size
func debris(at: Vector3, n_: int, speed: float, w: float = 0.6, up: float = 1.0) -> void:
	for k in n_:
		var d := _deb[_deb_i]
		_deb_i = (_deb_i + 1) % _deb.size()
		var dir := Vector3(randf_range(-1.0, 1.0), randf_range(0.2, 1.0) * up, randf_range(-1.0, 1.0)).normalized()
		d.position = at
		d.scale = Vector3(randf_range(0.5, 1.2), randf_range(0.4, 0.9), randf_range(0.5, 1.2)) * w
		d.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		d.visible = true
		var i := _deb.find(d)
		_deb_v[i] = dir * speed * randf_range(0.5, 1.2)
		_deb_w[i] = Vector3(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0), randf_range(-8.0, 8.0))
		_deb_t[i] = 0.0


func flash(at: Vector3, energy: float, reach: float, dur: float, col: Color = Color("ff9a40")) -> void:
	var i := _flash_i
	_flash_i = (_flash_i + 1) % _flash.size()
	var l := _flash[i]
	l.position = at
	l.light_color = col
	l.omni_range = reach
	l.visible = true
	_flash_t[i] = dur
	_flash_e[i] = energy
	l.set_meta(&"dur", dur)


## A blast in the route's space: r its size. burn: a fuel blast (flash, fireball, black smoke, burning bits); else masonry (a wall of dust and rubble)
func blast(at: Vector3, r: float, burn: bool, bits: int = 10) -> void:
	if burn:
		fire(at, Vector3.ZERO, r * 5.0, 0.6, 0.28, Color(1.8, 1.45, 1.0))
		for k in 34:      # the fireball: rolling out and up, yellow at its heart, red at its edge
			var d := Vector3(randf_range(-1.0, 1.0), randf_range(-0.2, 1.2), randf_range(-1.0, 1.0)).normalized()
			fire(at + d * r * 0.3, d * r * randf_range(2.5, 6.5) + Vector3(0.0, r * 1.2, 0.0), r * randf_range(1.2, 2.3), 1.5, randf_range(0.6, 1.5), [Color(1.0, 0.55, 0.15), Color(1.0, 0.78, 0.35), Color(0.9, 0.3, 0.08)][k % 3] * 1.5)
		for k in 22:      # and the black smoke boiling up out of it
			var d := Vector3(randf_range(-1.0, 1.0), randf_range(0.0, 1.0), randf_range(-1.0, 1.0)).normalized()
			smoke(at + d * r * 0.5, d * r * randf_range(1.0, 3.0) + Vector3(0.0, r * 1.4, 0.0), r * randf_range(1.6, 2.8), 1.9, randf_range(3.0, 5.5), Color(0.05, 0.04, 0.035, 0.88))
		for k in 24:
			var d := Vector3(randf_range(-1.0, 1.0), randf_range(0.0, 1.0), randf_range(-1.0, 1.0)).normalized()
			fire(at, d * randf_range(10.0, 26.0), 0.22, 0.0, randf_range(0.4, 0.9), Color(1.0, 0.7, 0.3) * 1.6)
		flash(at + Vector3(0.0, 1.0, 0.0), 22.0 * GAIN, r * 9.0, 0.7)
	else:
		for k in 22:
			var d := Vector3(randf_range(-1.0, 1.0), randf_range(-0.2, 0.8), randf_range(-1.0, 1.0)).normalized()
			smoke(at + d * r * 0.4, d * r * randf_range(1.0, 2.5), r * randf_range(1.2, 2.2), 1.5, randf_range(2.2, 4.0), Color(0.3, 0.28, 0.24, 0.8))
		flash(at, 6.0 * GAIN, r * 6.0, 0.25, Color("ffd8a0"))
	debris(at, bits, r * 3.0, clampf(r * 0.35, 0.3, 1.4))


## dust and grit down a wall or out of a roof: masonry scraped by the Sigil going past
func scrape(at: Vector3, n_: int) -> void:
	for k in n_:
		smoke(at + Vector3(randf_range(-0.8, 0.8), randf_range(-0.8, 0.8), randf_range(-0.8, 0.8)), Vector3(randf_range(-1.5, 1.5), randf_range(-1.0, 1.5), randf_range(-1.5, 1.5)), randf_range(0.8, 1.8), 1.6, randf_range(1.0, 2.0), Color(0.28, 0.26, 0.22, 0.6))
		fire(at, Vector3(randf_range(-6.0, 6.0), randf_range(-2.0, 6.0), randf_range(-6.0, 6.0)), 0.12, 0.0, randf_range(0.25, 0.5), Color(1.0, 0.7, 0.3) * 1.8)


func update(dt: float) -> void:
	_now += dt
	_smoke_mat.set_shader_parameter(&"now", _now)
	_fire_mat.set_shader_parameter(&"now", _now)
	for i in _deb.size():
		if _deb_t[i] < 0.0:
			continue
		_deb_t[i] += dt
		var d := _deb[i]
		_deb_v[i].y -= 15.0 * dt
		d.position += _deb_v[i] * dt
		d.rotation += _deb_w[i] * dt
		if _deb_t[i] > 3.2:
			_deb_t[i] = -1.0
			d.visible = false
	for i in _flash.size():
		if _flash_t[i] <= 0.0:
			continue
		_flash_t[i] -= dt
		var l := _flash[i]
		var dur: float = l.get_meta(&"dur", 0.5)
		l.light_energy = _flash_e[i] * maxf(0.0, _flash_t[i] / dur)
		if _flash_t[i] <= 0.0:
			l.visible = false
	# the moving parts: falling spans, flying door leaves, sinking buildings, broken piers
	for t in spans:
		_fall(t, dt)
	for t in doors:
		_fly(t, dt)
	for t in gantries:
		_fly(t, dt)
	for t in blds:
		if t.t >= 0.0:
			t.t += dt
			t.node.transform = t.rest.translated(Vector3(0.0, -minf(30.0, 9.0 * t.t * t.t), 0.0))
			t.node.visible = t.t < 3.5
	# what burns in the city under the viaduct, while it is near
	for f: Array in fires:
		if absf(float(f[0]) - s) < 260.0 and randf() < dt * 9.0:
			var at: Vector3 = f[1]
			var r: float = f[2]
			fire(at + Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * r, Vector3(0.0, randf_range(2.0, 4.0), 0.0), r * randf_range(0.8, 1.4), 0.6, randf_range(0.5, 0.9), Color(1.0, 0.45, 0.12) * 1.3)
			if randf() < 0.5:
				smoke(at + Vector3(0.0, r, 0.0), Vector3(randf_range(-0.5, 0.5), randf_range(2.5, 4.0), randf_range(-0.5, 0.5)), r * 1.6, 2.2, randf_range(3.0, 5.0), Color(0.05, 0.045, 0.04, 0.6))


func _fall(t: Thing, dt: float) -> void:
	if t.t < 0.0:
		return
	t.t += dt
	var u := t.t
	t.node.transform = t.rest * Transform3D(Basis.IDENTITY, pt(t.sig, 0.0, 0.0)) * Transform3D(Basis.from_euler(t.spin * u), Vector3(0.0, -6.0 * u * u, 0.0)) * Transform3D(Basis.IDENTITY, -pt(t.sig, 0.0, 0.0))
	if u > 4.0:
		t.node.visible = false


func _fly(t: Thing, dt: float) -> void:
	if t.t < 0.0:
		return
	t.t += dt
	var u := t.t
	var c := pt(t.sig, t.u, t.h)
	t.node.transform = t.rest * Transform3D(Basis.IDENTITY, c + t.vel * u + Vector3(0.0, -7.0 * u * u, 0.0)) * Transform3D(Basis.from_euler(t.spin * u), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -c)
	if u > 3.0:
		t.node.visible = false


# ---- what the director breaks -----------------------------------------------------------------------------------------------------------------------------------------------

## The lamps within reach of sigma on one side (+1 left, -1 right, 0 either) go out with a pop. Returns how many.
func smash_lamps(sig: float, reach: float, side: float) -> int:
	var k := 0
	for lp in lamps:
		if lp.alive and absf(lp.sig - sig) < reach and (side == 0.0 or lp.side == side):
			lp.alive = false
			lp.light.visible = false
			lp.glow.visible = false
			var at := lp.glow.position
			fire(at, Vector3.ZERO, 1.6, 0.4, 0.15, Color(1.6, 1.3, 0.9))
			for j in 10:
				fire(at, Vector3(randf_range(-5.0, 5.0), randf_range(-3.0, 4.0), randf_range(-5.0, 5.0)), 0.1, 0.0, randf_range(0.3, 0.6), Color(1.0, 0.8, 0.4) * 2.0)
			k += 1
	return k


func break_thing(t: Thing, burn: bool, r: float) -> void:
	if not t.alive:
		return
	t.alive = false
	t.node.visible = false
	blast(pt(t.sig, t.u, t.h), r, burn, 12)


## Every lamp back on, every pier, tank, building, span and door back where it was, no smoke in the air (a stretch begins again)
func reset() -> void:
	for lp in lamps:
		lp.alive = true
		lp.light.visible = true
		lp.glow.visible = true
	for arr: Array[Thing] in [piers, tanks, blds, spans, doors, towers, gantries]:
		for t in arr:
			t.alive = true
			t.t = -1.0
			t.node.visible = true
			t.node.transform = t.rest
	for i in _smoke_mm.instance_count:
		_smoke_mm.set_instance_custom_data(i, Color(0.0, 0.0, 1.0, -100.0))
	for i in _fire_mm.instance_count:
		_fire_mm.set_instance_custom_data(i, Color(0.0, 0.0, 1.0, -100.0))
	for i in _deb.size():
		_deb_t[i] = -1.0
		_deb[i].visible = false
	if gate_mat != null:
		gate_mat.set_shader_parameter(&"open", 0.0)
