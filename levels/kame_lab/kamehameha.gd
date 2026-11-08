class_name Kamehameha
extends Node3D
## KAMEHAMEHA prototype (JS levels/kame-lab/kamehameha.js; KAME LAB, and Tommy's ascension): the two-handed ki beam in the Budokai / Budokai Tenkaichi style, from the wind-up to the explosion on impact.
## Hold fire: the hands meet in front of the chest, then pull back to the right hip, cupped (WIND). A ball of ki grows between the palms (CHARGE, charge_t to full): a white core inside cyan and blue glows, a flickering star of light rays, streaks pulled into it, swoosh rings orbiting it, a blue aura bubble round the body, dust rolling out along the ground and rocks lifting off it. Let go: both arms thrust forward, palms out, wrists together (THRUST), and the beam comes out: three nested energy shells (white core, cyan, a blue outer skin with spiral bands) behind a bulging head. It runs until it hits the world or an enemy, burns whatever it touches and keeps erupting there, can be steered slowly, and when it ends the contact point goes up in an expanding energy dome with a ground shock ring, sparks, smoke and thrown rocks. A bigger charge = a thicker, longer, harder-hitting beam and a bigger dome.
## Sound: three recorded clips in assets/sfx/kame-lab (the charge, the beam firing, the beam head looping while it hits), plus small synth cues (wind-up whoosh, charge-level chimes, the final boom). ENGINE DIFFERENCE: the JS's charge hum and fire noise only stand in until the recorded clips have loaded; here they are always there, so no hum.
##   Kamehameha.new(combat, world_h, aim_dir): combat: anything with targets, cast_ray, damage; world_h: Callable(x, z, y) -> ground height; aim_dir: Callable() -> the heading that aims the beam
##   update(dt, P, fire)    once per frame: input, timeline, particles, beam, damage, sound. fire: a Btn (held, pressed)
##   pose(an, P, dt)        after the animator has posed the body: torso twist, both arms (two-bone IK), hands (cutscenes/hand_pose.gd), and the hand-attached effects placed on this frame's palms
##   busy                   true from the wind-up to the end of the recovery. state, k: phase name and charge 0..1 (HUD)

const WIND_T := 0.42      # s: hands together in front, then back to the hip
const CHARGE_T := 2.4     # s of charging to a full ball
const K_MIN := 0.18       # charge a tap still fires
const THRUST_T := 0.13    # s: arms snap forward before the beam leaves
const BEAM0 := 1.0        # s the beam lasts: tap / full charge
const BEAM1 := 2.6
const FADE_T := 0.35      # s the beam takes to thin out and die
const RECOVER_T := 0.45   # s back to the normal pose
const R0 := 0.2           # beam radius (m)
const R1 := 0.62
const BALL0 := 0.05       # ball radius in the hands (m)
const BALL1 := 0.2
const SPEED := 75.0       # m/s the beam head travels
const RANGE := 120.0      # m
const STEER := 1.4        # rad/s the beam follows the aim
const DPS0 := 70.0        # damage per second along the beam
const DPS1 := 220.0
const BOOM0 := 60.0       # damage at the centre of the final dome
const BOOM1 := 260.0
const DOME_R0 := 2.2      # final dome radius (m)
const DOME_R1 := 7.5
const ROCKS := 40
const LOCK := 0.45
const UP := Vector3.UP
const Z1 := Vector3.BACK
const SAMPLES := {"charge": "kame-charge", "fire": "beam-fire", "head": "beam-head"}

static var _tex := {}

var state := "idle"
var t_ := 0.0
var k := 0.0
var release := false
var stage := 0
var w := 0.0
var fwd := 0.0
var dir := Vector3(0, 0, 1)
var origin := Vector3.ZERO
var len_ := 0.0
var head_d := 0.0
var beam_dur := 1.0
var r := 0.0
var alpha := 0.0
var alpha_aura := 0.0
var hit: Variant = null
var hit_p := Vector3.ZERO
var hit_world := false
var contact := false
var tick_t := 0.0
var crack_t := 0.0
var yaw_ := 0.0
var aim := Vector3.ZERO
var palm_l := Vector3.ZERO
var palm_r := Vector3.ZERO
var have_hands := false
var q_fl := Quaternion.IDENTITY
var q_fr := Quaternion.IDENTITY
var time := 0.0
var busy: bool:
	get:
		return state != "idle"
var rooted: bool:
	get:
		return state != "idle" and state != "recover"

var combat: Variant
var ground_h: Callable
var aim_dir: Callable
var ki: CinePuffs
var dust: CinePuffs
var hands := HandPose.new()
var _ball := {}
var _ball_pos := Vector3.ZERO
var _ball_r := 0.0
var _swoosh: Array[Dictionary] = []
var _aura: MeshInstance3D
var _beam_g: Node3D
var _shells: Array[Dictionary] = []
var _head := {}
var _head_bulb: MeshInstance3D
var _muzzle := {}
var _rays_charge: Rays
var _rays_muzzle: Rays
var _rays_impact: Rays
var _booms: Array[Dictionary] = []
var _free_booms: Array[Dictionary] = []
var _rocks: Array[Dictionary] = []
var _rock_mm: MultiMesh
var _hand_light: OmniLight3D
var _head_light: OmniLight3D
var _boom_light: OmniLight3D
var _hand_i := 0.0
var _head_i := 0.0
var _boom_i := 0.0
var _voices := {}
var _aura_acc := 0.0
var _in_acc := 0.0
var _dust_acc := 0.0
var _dome_mesh: SphereMesh
var _ring_mesh: PlaneMesh
var _noise: ImageTexture


## light rays: thin camera-facing wedges from a centre that flicker in and out (the "speed line" burst)
class Rays:
	var n := 0
	var mesh: ImmediateMesh
	var node: MeshInstance3D
	var R: Array[Dictionary] = []
	var mat: StandardMaterial3D

	func _init(par: Node3D, count: int, order: int) -> void:
		n = count
		mesh = ImmediateMesh.new()
		node = MeshInstance3D.new()
		node.mesh = mesh
		mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.disable_fog = true
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.vertex_color_use_as_albedo = true
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.render_priority = order
		node.material_override = mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.custom_aabb = AABB(Vector3.ONE * -100000.0, Vector3.ONE * 200000.0)
		node.visible = false
		par.add_child(node)
		for i in n:
			R.append({"d": Vector3.ZERO, "t": 1.0, "life": 1.0, "len": 1.0})

	## c centre, len / width in metres, I 0..1 brightness, bias: a direction the rays favour (or null), spread 0..1 around it
	func update(dt: float, c: Vector3, ln: float, width: float, I: float, bias: Variant = null, spread: float = 1.0) -> void:
		node.visible = I > 0.01
		if not node.visible:
			return
		var cam := Game.camera.global_position
		mesh.clear_surfaces()
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for q: Dictionary in R:
			q["t"] += dt
			if float(q["t"]) >= float(q["life"]):
				q["t"] = 0.0
				q["life"] = randf_range(0.06, 0.2)
				q["len"] = randf_range(0.35, 1.0)
				var d := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
				if bias != null:
					d = d.lerp(bias, 1.0 - spread).normalized()
				q["d"] = d
			var f := sin(PI * float(q["t"]) / float(q["life"])) * I
			var L := ln * float(q["len"]) * (0.6 + 0.4 * f)
			var qd: Vector3 = q["d"]
			var sd := qd.cross((cam - c).normalized()).normalized() * (width * (0.5 + 0.5 * float(q["len"])))
			var col := Color(0.75 * f, 0.9 * f, f, 1.0)
			mesh.surface_set_color(col)
			mesh.surface_add_vertex(c + sd)
			mesh.surface_set_color(col)
			mesh.surface_add_vertex(c - sd)
			mesh.surface_set_color(Color(0, 0, 0, 1))
			mesh.surface_add_vertex(c + qd * L)
		mesh.surface_end()


# ---- textures (drawn once) ----
static func _px(im: Image, s: int, fn: Callable) -> void:
	for y in s:
		for x in s:
			im.set_pixel(x, y, fn.call(x, y))


static func _stops(st: Array, u: float) -> Color:
	var i := 0
	while i < st.size() - 1 and u > float(st[i + 1][0]):
		i += 1
	if i >= st.size() - 1:
		return st[st.size() - 1][1]
	var a: float = st[i][0]
	var b: float = st[i + 1][0]
	return (st[i][1] as Color).lerp(st[i + 1][1], clampf((u - a) / maxf(b - a, 1e-5), 0.0, 1.0))


static func _radial(stops: Array, size: int = 64) -> ImageTexture:
	var im := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var h := size / 2.0
	for y in size:
		for x in size:
			var u := Vector2(x + 0.5 - h, y + 0.5 - h).length() / h
			im.set_pixel(x, y, _stops(stops, u))
	return ImageTexture.create_from_image(im)


## a star of thin light spikes round a hot centre (the lens-flare burst at the hands)
static func _star() -> ImageTexture:
	const S := 256
	var h := S / 2.0
	var buf := PackedColorArray()
	buf.resize(S * S)
	buf.fill(Color(0, 0, 0, 0))
	for i in 22:
		var a := float(i) / 22.0 * TAU + randf_range(-0.08, 0.08)
		var L := h * (randf_range(0.45, 0.7) if i % 2 == 1 else randf_range(0.8, 1.0))
		var wd := (2.2 if i % 2 == 1 else 3.4) * 0.5
		var c := cos(a)
		var n := sin(a)
		for st in int(L * 2.0):
			var d := st * 0.5
			var f := d / L
			var col := Color(1, 1, 1, 0.95).lerp(Color(160.0 / 255.0, 210.0 / 255.0, 1.0, 0.0), f)
			var cx := h + c * d
			var cy := h + n * d
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					var ix := int(cx + ox * wd)
					var iy := int(cy + oy * wd)
					if ix >= 0 and iy >= 0 and ix < S and iy < S:
						var v := buf[iy * S + ix]
						buf[iy * S + ix] = Color(minf(1.0, maxf(v.r, col.r)), minf(1.0, maxf(v.g, col.g)), 1.0, minf(1.0, maxf(v.a, col.a)))
	var im := Image.create(S, S, false, Image.FORMAT_RGBA8)
	for y in S:
		for x in S:
			var u := Vector2(x + 0.5 - h, y + 0.5 - h).length() / (h * 0.35)
			var v := buf[y * S + x]
			if u < 1.0:
				var c2 := Color(1, 1, 1, 1).lerp(Color(120.0 / 255.0, 190.0 / 255.0, 1.0, 0.0), u)
				v = Color(minf(1.0, v.r + c2.r * c2.a), minf(1.0, v.g + c2.g * c2.a), minf(1.0, v.b + c2.b * c2.a), minf(1.0, v.a + c2.a))
			im.set_pixel(x, y, v)
	return ImageTexture.create_from_image(im)


## a comet-tail arc (the blue swooshes orbiting the charging ball)
static func _arc() -> ImageTexture:
	const S := 128
	var h := S / 2.0
	var im := Image.create(S, S, false, Image.FORMAT_RGBA8)
	for y in S:
		for x in S:
			var p := Vector2(x + 0.5 - h, y + 0.5 - h)
			var a := fposmod(atan2(p.y, p.x), TAU)
			if a > PI * 1.5:
				continue
			var f := a / (PI * 1.5)
			var wd := (3.0 + 9.0 * f) * 0.5 * 0.5      # (the 256 canvas's widths, at 128)
			var d := absf(p.length() - h * 0.78)
			if d > wd:
				continue
			im.set_pixel(x, y, Color((170.0 + 85.0 * f) / 255.0, (220.0 + 35.0 * f) / 255.0, 1.0, f * f))
	return ImageTexture.create_from_image(im)


## tileable value noise (beam and dome shaders scroll it)
static func _noise_tex() -> ImageTexture:
	const N := 128
	const G := 16
	var grid := PackedFloat32Array()
	grid.resize(G * G)
	for i in G * G:
		grid[i] = randf()
	var im := Image.create(N, N, false, Image.FORMAT_L8)
	for y in N:
		for x in N:
			var v := 0.0
			var amp := 0.6
			for o: int in [1, 2]:
				var fx := (float(x) / N) * G * o
				var fy := (float(y) / N) * G * o
				var ix := floori(fx)
				var iy := floori(fy)
				var tx := fx - ix
				var ty := fy - iy
				tx = tx * tx * (3.0 - 2.0 * tx)
				ty = ty * ty * (3.0 - 2.0 * ty)
				var a := grid[posmod(iy, G) * G + posmod(ix, G)]
				var b := grid[posmod(iy, G) * G + posmod(ix + 1, G)]
				var c := grid[posmod(iy + 1, G) * G + posmod(ix, G)]
				var d := grid[posmod(iy + 1, G) * G + posmod(ix + 1, G)]
				v += amp * lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)
				amp *= 0.5
			var q := clampf(v / 0.9, 0.0, 1.0)
			im.set_pixel(x, y, Color(q, q, q))
	return ImageTexture.create_from_image(im)


static func _textures() -> Dictionary:
	if not _tex.is_empty():
		return _tex
	_tex = {
		"core": _radial([[0.0, Color(1, 1, 1, 1)], [0.3, Color(240.0 / 255.0, 250.0 / 255.0, 1.0, 1.0)], [0.55, Color(150.0 / 255.0, 215.0 / 255.0, 1.0, 0.7)], [1.0, Color(40.0 / 255.0, 110.0 / 255.0, 1.0, 0.0)]]),
		"halo": _radial([[0.0, Color(130.0 / 255.0, 200.0 / 255.0, 1.0, 0.75)], [0.45, Color(70.0 / 255.0, 130.0 / 255.0, 1.0, 0.3)], [1.0, Color(30.0 / 255.0, 60.0 / 255.0, 1.0, 0.0)]]),
		"ring": _radial([[0.0, Color(1, 1, 1, 0)], [0.62, Color(160.0 / 255.0, 215.0 / 255.0, 1.0, 0.0)], [0.82, Color(220.0 / 255.0, 240.0 / 255.0, 1.0, 0.95)], [0.9, Color(120.0 / 255.0, 180.0 / 255.0, 1.0, 0.5)], [1.0, Color(60.0 / 255.0, 120.0 / 255.0, 1.0, 0.0)]], 128),
		"star": _star(), "arc": _arc(), "noise": _noise_tex(),
	}
	return _tex


func _sprite(map: String, order: int = 9) -> MeshInstance3D:
	var q := QuadMesh.new()
	var m := ShaderMaterial.new()
	m.shader = load("res://levels/kame_lab/kame_sprite.gdshader")
	m.set_shader_parameter(&"map", _textures()[map])
	m.render_priority = order
	var s := MeshInstance3D.new()
	s.mesh = q
	s.material_override = m
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.custom_aabb = AABB(Vector3.ONE * -3.0, Vector3.ONE * 6.0)
	s.visible = false
	add_child(s)
	return s


static func _sp(s: MeshInstance3D, op: float, rot: Variant = null) -> void:
	var m := s.material_override as ShaderMaterial
	m.set_shader_parameter(&"opacity", op)
	if rot != null:
		m.set_shader_parameter(&"rot", rot)


static func _lin(h: int) -> Vector3:
	var c := Color.hex((h << 8) | 0xff).srgb_to_linear()
	return Vector3(c.r, c.g, c.b)


func _energy(shader: String, color: int, hot: int, order: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(shader)
	m.set_shader_parameter(&"uColor", _lin(color))
	m.set_shader_parameter(&"uHot", _lin(hot))
	m.set_shader_parameter(&"uNoise", _noise)
	m.render_priority = order
	return m


## the beam's shell: an open cylinder along +z, 0..1 long, v along it
static func _shell_mesh() -> ArrayMesh:
	const N := 28
	var v := PackedVector3Array()
	var nm := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	for i in N + 1:
		var a := TAU * i / N
		var n := Vector3(sin(a), cos(a), 0.0)
		for e in 2:
			v.append(n + Vector3(0.0, 0.0, float(e)))
			nm.append(n)
			uv.append(Vector2(float(i) / N, float(e)))
	for i in N:
		var o := i * 2
		idx.append_array([o, o + 1, o + 2, o + 1, o + 3, o + 2])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = nm
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


static func dodeca() -> ArrayMesh:
	var p := 1.618034
	var q := 1.0 / p
	var V: Array[Vector3] = [Vector3(1, 1, 1), Vector3(1, 1, -1), Vector3(1, -1, 1), Vector3(1, -1, -1), Vector3(-1, 1, 1), Vector3(-1, 1, -1), Vector3(-1, -1, 1), Vector3(-1, -1, -1),
		Vector3(0, q, p), Vector3(0, q, -p), Vector3(0, -q, p), Vector3(0, -q, -p), Vector3(q, p, 0), Vector3(q, -p, 0), Vector3(-q, p, 0), Vector3(-q, -p, 0), Vector3(p, 0, q), Vector3(p, 0, -q), Vector3(-p, 0, q), Vector3(-p, 0, -q)]
	var F := [[0, 8, 10, 2, 16], [0, 16, 17, 1, 12], [0, 12, 14, 4, 8], [1, 17, 3, 11, 9], [1, 9, 5, 14, 12], [2, 10, 6, 15, 13], [2, 13, 3, 17, 16], [3, 13, 15, 7, 11], [4, 14, 5, 19, 18], [4, 18, 6, 10, 8], [5, 9, 11, 7, 19], [6, 18, 19, 7, 15]]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f: Array in F:
		var a: Vector3 = V[f[0]].normalized()
		var b: Vector3 = V[f[1]].normalized()
		var c: Vector3 = V[f[2]].normalized()
		var n := (c - a).cross(b - a).normalized()
		if n.dot(a) < 0.0:
			n = -n
		for i in range(1, 4):
			var tri: Array[Vector3] = [V[f[0]].normalized(), V[f[i]].normalized(), V[f[i + 1]].normalized()]
			if (tri[2] - tri[0]).cross(tri[1] - tri[0]).dot(n) < 0.0:
				tri = [tri[0], tri[2], tri[1]]
			for u: Vector3 in tri:
				st.set_normal(n)
				st.add_vertex(u)
	return st.commit()


func _init(p_combat: Variant, p_ground_h: Callable, p_aim_dir: Callable) -> void:
	name = "kamehameha"
	combat = p_combat
	ground_h = p_ground_h
	aim_dir = p_aim_dir


func _ready() -> void:
	_noise = _textures()["noise"]
	ki = CinePuffs.new(self, true, 10, 1600, 1, 0.6, 360.0)
	dust = CinePuffs.new(self, false, 7, 1600, 1, 0.6, 360.0)
	_rays_charge = Rays.new(self, 26, 11)
	_rays_muzzle = Rays.new(self, 34, 11)
	_rays_impact = Rays.new(self, 30, 11)
	_ball = {"core": _sprite("core", 12), "halo": _sprite("halo", 11), "star": _sprite("star", 12)}
	for i in 3:
		var q := QuadMesh.new()
		# (JS a plane in the world, double sided: drawn here as a sprite's material would not turn with it, so its own)
		var sm := StandardMaterial3D.new()
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		sm.disable_fog = true
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.cull_mode = BaseMaterial3D.CULL_DISABLED
		sm.albedo_texture = _textures()["arc"]
		sm.render_priority = 11
		var s := MeshInstance3D.new()
		s.mesh = q
		s.material_override = sm
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.visible = false
		add_child(s)
		_swoosh.append({"m": s, "tilt": Animator.q_xyz(randf_range(0.0, 6.28), randf_range(0.0, 6.28), 0.0), "spin": randf_range(9.0, 15.0) * (-1.0 if randf() < 0.5 else 1.0), "a": randf_range(0.0, 6.28)})
	var sph := SphereMesh.new()
	sph.radial_segments = 32
	sph.rings = 20
	_aura = MeshInstance3D.new()
	_aura.mesh = sph
	var am := _energy("res://levels/kame_lab/kame_dome.gdshader", 0x2f6dff, 0xbfe6ff, 8)
	am.set_shader_parameter(&"uRim", 1.1)
	am.set_shader_parameter(&"uFill", 0.08)
	_aura.material_override = am
	_aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_aura.visible = false
	add_child(_aura)
	# the beam: three open-ended shells along +z, a head, the burst at the hands
	var shell := _shell_mesh()
	_beam_g = Node3D.new()
	_beam_g.visible = false
	add_child(_beam_g)
	for d: Dictionary in [{"s": 0.42, "c": 0xd8f2ff, "h": 0xffffff, "fill": 1.4, "rim": 0.2, "spiral": 0.0}, {"s": 0.72, "c": 0x58b4ff, "h": 0xe8f8ff, "fill": 0.55, "rim": 0.6, "spiral": 0.35}, {"s": 1.0, "c": 0x1f4dff, "h": 0x9fd8ff, "fill": 0.12, "rim": 1.1, "spiral": 0.6}]:
		var m := _energy("res://levels/kame_lab/kame_beam.gdshader", d["c"], d["h"], 9)
		m.set_shader_parameter(&"uFill", d["fill"])
		m.set_shader_parameter(&"uRim", d["rim"])
		m.set_shader_parameter(&"uSpiral", d["spiral"])
		var mi := MeshInstance3D.new()
		mi.mesh = shell
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.custom_aabb = AABB(Vector3(-2, -2, -1), Vector3(4, 4, 3))
		_beam_g.add_child(mi)
		_shells.append({"mesh": mi, "m": m, "s": d["s"]})
	_head = {"core": _sprite("core", 12), "halo": _sprite("halo", 11), "star": _sprite("star", 12)}
	var hs := SphereMesh.new()
	hs.radial_segments = 28
	hs.rings = 18
	_head_bulb = MeshInstance3D.new()
	_head_bulb.mesh = hs
	var hm := _energy("res://levels/kame_lab/kame_dome.gdshader", 0x3c7bff, 0xeaf6ff, 10)
	hm.set_shader_parameter(&"uRim", 1.3)
	hm.set_shader_parameter(&"uFill", 0.9)
	_head_bulb.material_override = hm
	_head_bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_head_bulb.visible = false
	add_child(_head_bulb)
	_muzzle = {"core": _sprite("core", 12), "halo": _sprite("halo", 11), "star": _sprite("star", 12)}
	_dome_mesh = SphereMesh.new()
	_dome_mesh.radial_segments = 40
	_dome_mesh.rings = 24
	_ring_mesh = PlaneMesh.new()
	_ring_mesh.size = Vector2.ONE
	# rocks: torn up while charging (they float), flung by the launch and by the explosions
	_rock_mm = MultiMesh.new()
	_rock_mm.transform_format = MultiMesh.TRANSFORM_3D
	_rock_mm.mesh = dodeca()
	_rock_mm.instance_count = ROCKS
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color.hex(0x6f6458ff)
	rm.roughness = 0.95
	var rn := MultiMeshInstance3D.new()
	rn.multimesh = _rock_mm
	rn.material_override = rm
	rn.custom_aabb = AABB(Vector3.ONE * -100000.0, Vector3.ONE * 200000.0)
	add_child(rn)
	for i in ROCKS:
		_rocks.append({"on": false, "p": Vector3.ZERO, "v": Vector3.ZERO, "q": Quaternion.IDENTITY, "w": Vector3.ZERO, "s": 0.1, "float": false, "life": 0.0, "y0": 0.0})
		_rock_mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO))
	# lights (made now; dark until used)
	_hand_light = CineParts.light(self, 0x7fc0ff, 0.0, 10.0)
	_head_light = CineParts.light(self, 0x8fc8ff, 0.0, 18.0)
	_boom_light = CineParts.light(self, 0xa8d4ff, 0.0, 40.0)


func _make_boom() -> Dictionary:
	var dome := MeshInstance3D.new()
	dome.mesh = _dome_mesh
	dome.material_override = _energy("res://levels/kame_lab/kame_dome.gdshader", 0x3f7dff, 0xffffff, 10)
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dome)
	var ring := MeshInstance3D.new()
	ring.mesh = _ring_mesh
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	rm.disable_fog = true
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.cull_mode = BaseMaterial3D.CULL_DISABLED
	rm.albedo_texture = _textures()["ring"]
	rm.render_priority = 9
	ring.material_override = rm
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	return {"dome": dome, "ring": ring, "flash": _sprite("core", 13), "star": _sprite("star", 13), "rot": 0.0}


# ---- particles (JS spark, streak, auraFlame, puff, smoke; damp and rise by kind) ----
func _spark(x: float, y: float, z: float, vx: float, vy: float, vz: float, life: float = -1.0, s0: float = -1.0, s1: float = 0.01) -> void:
	ki.emit(x, y, z, vx, vy, vz, life if life >= 0.0 else randf_range(0.25, 0.6), s0 if s0 >= 0.0 else randf_range(0.05, 0.12), s1, 3.2, 0.0, Color(0.0, 0, 0, 1))


func _streak(x: float, y: float, z: float, vx: float, vy: float, vz: float, life: float, s: float) -> void:
	ki.emit(x, y, z, vx, vy, vz, life, s, s * 0.3, 0.0, 0.0, Color(0.25, 0, 0, 1))


func _aura_flame(x: float, y: float, z: float) -> void:
	ki.emit(x, y, z, randf_range(-0.2, 0.2), randf_range(1.6, 3.2), randf_range(-0.2, 0.2), randf_range(0.35, 0.7), randf_range(0.18, 0.32), 0.02, 1.5, 0.0, Color(0.5, 0, 0, 1))


func _puff(x: float, y: float, z: float, vx: float, vy: float, vz: float, life: float, s0: float, s1: float) -> void:
	dust.emit(x, y, z, vx, vy, vz, life, s0, s1, 2.6, 0.15, Color(0.75, 0, 0, 1))


func _smoke(x: float, y: float, z: float, vx: float, vy: float, vz: float, life: float, s0: float, s1: float) -> void:
	dust.emit(x, y, z, vx, vy, vz, life, s0, s1, 1.1, 0.8, Color(1.0, 0, 0, 1))


# ---- sound ----
func _snd_stage(q: float) -> void:
	var b := int(q * 4.0)
	CineParts.play(CineParts.sound("kame.stage%d" % b, [["t", 0.0, 0.35, 900.0 + 700.0 * q, 1400.0 + 900.0 * q, {"type": "sine", "gain": 0.12, "wet": 0.5}], ["n", 0.0, 0.25, {"type": "highpass", "f0": 4000.0, "f1": 2500.0, "gain": 0.12, "wet": 0.4}]]))


func _snd_wind() -> void:
	CineParts.play(CineParts.sound("kame.wind", [["n", 0.0, 0.4, {"type": "bandpass", "f0": 300.0, "f1": 1600.0, "q": 1.2, "gain": 0.22, "attack": 0.05, "wet": 0.3}]]))


func _snd_boom(q: float, p: Vector3) -> void:
	var v := 1.0 / (1.0 + Game.camera.global_position.distance_to(p) * 0.05)
	var b := roundi(q * 4.0) / 4.0
	CineParts.play(CineParts.sound("kame.boom%d" % roundi(q * 4.0), [["n", 0.0, 1.4 + 1.2 * b, {"type": "lowpass", "f0": 2400.0, "f1": 70.0, "gain": 0.9 + 0.7 * b, "attack": 0.003, "wet": 0.6}], ["t", 0.0, 1.1 + 0.6 * b, 80.0, 24.0, {"gain": 0.9 + 0.6 * b, "wet": 0.5}], ["n", 0.08, 1.6, {"type": "bandpass", "f0": 700.0, "f1": 120.0, "q": 0.7, "gain": 0.35, "wet": 0.8}]]), v)


## one voice per sample (a new play cuts the old one); loop_from: once through, then loop from there to the end
func _play(id: String, gain: float, loop_from: float = -1.0) -> AudioStreamPlayer:
	_stop(id)
	var st: AudioStreamMP3 = (load("res://assets/sfx/kame-lab/%s.mp3" % SAMPLES[id]) as AudioStreamMP3).duplicate()
	if loop_from >= 0.0:
		st.loop = true
		st.loop_offset = loop_from
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.bus = &"SFX"
	p.volume_db = linear_to_db(maxf(gain, 1e-5))
	add_child(p)
	p.play()
	_voices[id] = p
	return p


func _stop(id: String) -> void:
	var v: Variant = _voices.get(id)
	if v != null and is_instance_valid(v):
		(v as AudioStreamPlayer).queue_free()
	_voices.erase(id)


func quiet() -> void:
	for id: String in SAMPLES:
		_stop(id)


# ---- state ----
func _set_state(s: String) -> void:
	state = s
	t_ = 0.0


static func _hittable(o: Variant) -> bool:
	return o != null and not o.dead and o.actor_state == null


## where the beam goes (Tenkaichi-style soft lock): the enemy nearest the camera's heading within LOCK rad, else level along the heading, tilted with the camera
func _aim_at(from: Vector3) -> Vector3:
	var cd: Vector3 = aim_dir.call()
	var hy := atan2(cd.x, cd.z)
	var best: Variant = null
	var bo := LOCK
	for O: Variant in combat.targets:
		if not _hittable(O):
			continue
		var dx: float = O.x - from.x
		var dz: float = O.z - from.z
		var d := U.hyp(dx, dz)
		if d < 1.2 or d > RANGE:
			continue
		var off := absf(atan2(sin(atan2(dx, dz) - hy), cos(atan2(dx, dz) - hy)))
		if off < bo:
			bo = off
			best = O
	if best != null:
		return Vector3(best.x, best.y + (best.h if best.h != 0.0 else 1.8) * 0.5, best.z)
	var pitch := clampf(asin(clampf(cd.y, -1.0, 1.0)) + 0.3, -0.6, 0.9)      # the chase camera looks down at you: level that out
	return Vector3(from.x + sin(hy) * cos(pitch) * 60.0, from.y + sin(pitch) * 60.0, from.z + cos(hy) * cos(pitch) * 60.0)


# ---- input + timeline ----
func update(dt: float, P: Player, fire: Variant) -> void:
	time += dt
	var tm_mats: Array = [_aura.material_override, _head_bulb.material_override]
	for s: Dictionary in _shells:
		tm_mats.append(s["m"])
	for m: ShaderMaterial in tm_mats:
		m.set_shader_parameter(&"uTime", time)
	if P == null:
		return
	t_ += dt
	if P.dead and state != "idle":
		_end_beam(false)
		_set_state("idle")
	match state:
		"idle":
			if fire != null and fire.pressed and not P.dead and P.mode == &"normal":
				_set_state("wind")
				k = 0.0
				stage = 0
				release = false
				_snd_wind()
				_play("charge", 0.9, 4.3)
		"wind":
			if fire != null and not fire.held:
				release = true
			if t_ >= WIND_T:
				_set_state("charge")
		"charge":
			if fire != null and not fire.held:
				release = true
			k = minf(1.0, k + dt / CHARGE_T)
			var st := floori(k * 4.0 + 1e-6)
			if st > stage:
				stage = st
				_snd_stage(k)
			if release and k >= K_MIN:
				k = maxf(k, K_MIN)
				_set_state("thrust")
		"thrust":
			if t_ >= THRUST_T:
				_launch(P)
		"beam":
			if t_ >= beam_dur:
				_set_state("fade")
		"fade":
			if t_ >= FADE_T:
				_end_beam(true)
				_set_state("recover")
		"recover":
			if t_ >= RECOVER_T:
				_set_state("idle")
	# facing: the body turns to the aim while charging, and follows the (slowly steered) beam while firing
	var firing := state == "beam" or state == "fade"
	aim = _aim_at(origin if firing else _ball_pos)
	if firing:
		yaw_ = atan2(dir.x, dir.z)
	elif state != "idle":
		yaw_ = atan2(aim.x - P.x, aim.z - P.z)
	# ---- sound levels ----
	if _voices.has("charge") and state != "wind" and state != "charge":
		_stop("charge")
	if _voices.has("fire") and not firing:
		_stop("fire")
	if contact and firing:
		if not _voices.has("head"):
			_play("head", 0.0, 0.0)
		(_voices["head"] as AudioStreamPlayer).volume_db = linear_to_db(maxf((0.7 + 0.3 * k) * alpha, 1e-5))
	elif _voices.has("head"):
		_stop("head")
	_sim_charge(dt, P)
	_sim_beam(dt, P)
	_sim_booms(dt)
	_sim_rocks(dt, P)
	ki.step(dt)
	dust.step(dt)
	_hand_i *= exp(-10.0 * dt)
	_head_i *= exp(-12.0 * dt)
	_boom_i *= exp(-5.0 * dt)
	_hand_light.light_energy = _hand_i / PI
	_head_light.light_energy = _head_i / PI
	_boom_light.light_energy = _boom_i / PI


# ---- charging: the ball, the aura, the ground ----
func _sim_charge(dt: float, P: Player) -> void:
	var charging := state == "wind" or state == "charge" or state == "thrust"
	var q := 0.04 * (t_ / WIND_T) if state == "wind" else k
	# aura bubble: swells in with the charge, gone the moment the beam leaves
	var a_on := clampf((q - 0.08) * 2.2, 0.0, 1.0) if charging and state != "wind" else 0.0
	alpha_aura = lerpf(alpha_aura, a_on, 1.0 - exp(-(6.0 if a_on > alpha_aura else 14.0) * dt))
	_aura.visible = alpha_aura > 0.01
	if _aura.visible:
		_aura.position = Vector3(P.x, P.y + 1.0, P.z)
		_aura.scale = Vector3(1.0, 1.25, 1.0) * (lerpf(1.0, 2.1, q) * (1.0 + 0.03 * sin(time * 31.0)))
		(_aura.material_override as ShaderMaterial).set_shader_parameter(&"uAlpha", alpha_aura * (0.55 + 0.25 * randf()))
	if not charging:
		return
	var b := _ball_pos
	# streaks pulled into the ball
	_in_acc += dt * (20.0 + 110.0 * q)
	while _in_acc >= 1.0:
		_in_acc -= 1.0
		var a := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var R := randf_range(0.7, 1.6) * (0.6 + 0.8 * q)
		var sp := randf_range(5.0, 9.0)
		_streak(b.x + a.x * R, b.y + a.y * R, b.z + a.z * R, -a.x * sp, -a.y * sp, -a.z * sp, R / sp, randf_range(0.04, 0.08) * (0.6 + q))
	if randf() < dt * 40.0 * q:
		_spark(b.x, b.y, b.z, randf_range(-3, 3), randf_range(-2, 3), randf_range(-3, 3))
	# aura flames rising round the body and dust rolling out at the feet
	_aura_acc += dt * 70.0 * clampf(q * 1.5, 0.0, 1.0)
	while _aura_acc >= 1.0:
		_aura_acc -= 1.0
		var a := randf_range(0.0, 6.28)
		var rr := randf_range(0.25, 0.55) * (1.0 + q)
		_aura_flame(P.x + cos(a) * rr, P.y + randf_range(0.0, 1.6), P.z + sin(a) * rr)
	_dust_acc += dt * (4.0 + 40.0 * q)
	while _dust_acc >= 1.0:
		_dust_acc -= 1.0
		var a := randf_range(0.0, 6.28)
		var sp := randf_range(2.0, 5.0) * (0.5 + q)
		_puff(P.x + cos(a) * 0.6, P.y + 0.08, P.z + sin(a) * 0.6, cos(a) * sp, randf_range(0.0, 0.4), sin(a) * sp, randf_range(0.6, 1.2), 0.4, 1.4 + q)
	# rocks lift off the ground once the charge is serious
	if q > 0.3 and randf() < dt * 7.0 * q:
		_lift_rock(P)
	_hand_i = maxf(_hand_i, 3.0 + 26.0 * q)
	Game.fx.shake = maxf(Game.fx.shake, 0.04 + 0.16 * q * q)


func _free_rock() -> Variant:
	for r_: Dictionary in _rocks:
		if not r_["on"]:
			return r_
	return null


func _lift_rock(P: Player) -> void:
	var rk: Variant = _free_rock()
	if rk == null:
		return
	var a := randf_range(0.0, 6.28)
	var d := randf_range(1.2, 4.5)
	rk["on"] = true
	rk["float"] = true
	rk["life"] = 0.0
	rk["s"] = randf_range(0.035, 0.11)
	rk["p"] = Vector3(P.x + cos(a) * d, P.y + float(rk["s"]) * 0.4, P.z + sin(a) * d)
	rk["y0"] = P.y + randf_range(0.4, 1.8)      # the height it hovers at
	rk["v"] = Vector3(randf_range(-0.1, 0.1), randf_range(0.6, 1.4), randf_range(-0.1, 0.1))
	rk["w"] = Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2))
	rk["q"] = Quaternion.IDENTITY
	var rp: Vector3 = rk["p"]
	_puff(rp.x, rp.y, rp.z, 0.0, 0.3, 0.0, 0.8, 0.2, 0.6)


func _fling_rock(p: Vector3, out: Vector3, sp: float) -> void:
	var rk: Variant = _free_rock()
	if rk == null:
		return
	rk["on"] = true
	rk["float"] = false
	rk["life"] = 0.0
	rk["s"] = randf_range(0.06, 0.22)
	rk["p"] = p
	rk["y0"] = -1e9
	rk["v"] = out * (sp * randf_range(0.5, 1.0)) + Vector3(randf_range(-2, 2), randf_range(2, 6), randf_range(-2, 2))
	rk["w"] = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))


func _sim_rocks(dt: float, P: Player) -> void:
	var beam_out := state == "thrust" or state == "beam"
	for i in ROCKS:
		var q: Dictionary = _rocks[i]
		if not q["on"]:
			continue
		q["life"] += dt
		var v: Vector3 = q["v"]
		var p: Vector3 = q["p"]
		if q["float"]:
			if beam_out and P != null:
				q["float"] = false
				var a := Vector3(p.x - P.x, 0.0, p.z - P.z).normalized()
				v = Vector3(a.x * randf_range(6, 12), randf_range(2, 5), a.z * randf_range(6, 12))
				q["w"] = (q["w"] as Vector3) * 4.0
			elif state == "idle" or state == "recover":
				q["float"] = false
			else:
				v.y = lerpf(v.y, clampf((float(q["y0"]) - p.y) * 1.5, -0.4, 1.2) + 0.12 * sin(time * 3.0 + i), 1.0 - exp(-3.0 * dt))
				v.x = (v.x + randf_range(-1, 1) * dt) * exp(-dt)
				v.z = (v.z + randf_range(-1, 1) * dt) * exp(-dt)
		if not q["float"]:
			v.y -= 16.0 * dt
		p += v * dt
		var fl: float = float(ground_h.call(p.x, p.z, p.y + 1.0)) + float(q["s"]) * 0.5
		if not q["float"] and p.y < fl:
			p.y = fl
			v.y *= -0.3
			v.x *= 0.6
			v.z *= 0.6
			q["w"] = (q["w"] as Vector3) * 0.6
			if absf(v.y) < 0.6 and float(q["life"]) > 0.5:
				q["on"] = false
		if float(q["life"]) > 9.0:
			q["on"] = false
		var w_: Vector3 = q["w"]
		q["q"] = ((q["q"] as Quaternion) * Animator.q_xyz(w_.x * dt, w_.y * dt, w_.z * dt)).normalized()
		q["v"] = v
		q["p"] = p
		if q["on"]:
			_rock_mm.set_instance_transform(i, Transform3D(Basis(q["q"] as Quaternion).scaled(Vector3.ONE * float(q["s"])), p))
		else:
			_rock_mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO))


# ---- the beam ----
func _launch(P: Player) -> void:
	_set_state("beam")
	beam_dur = lerpf(BEAM0, BEAM1, k)
	r = lerpf(R0, R1, k)
	head_d = 0.0
	len_ = 0.0
	alpha = 1.0
	contact = false
	hit = null
	tick_t = 0.0
	crack_t = 0.0
	origin = _ball_pos
	aim = _aim_at(origin)
	dir = (aim - origin).normalized()
	_beam_g.visible = true
	_play("fire", 0.75 + 0.25 * k)
	Game.fx.shake = maxf(Game.fx.shake, 0.35 + 0.4 * k)
	# the launch kicks a ring of dust out from the feet and a burst of sparks from the hands
	for i in int(40.0 + 50.0 * k):
		var a := randf_range(0.0, 6.28)
		var sp := randf_range(6.0, 12.0)
		_puff(P.x, P.y + 0.1, P.z, cos(a) * sp, randf_range(0.0, 0.6), sin(a) * sp, randf_range(0.7, 1.4), 0.5, 2.2)
	for i in 60:
		var a := dir * randf_range(4.0, 12.0) + Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4))
		_spark(origin.x, origin.y, origin.z, a.x, a.y, a.z, randf_range(0.2, 0.5), randf_range(0.08, 0.16))


func _end_beam(boom: bool) -> void:
	_beam_g.visible = false
	_head_bulb.visible = false
	for g: Dictionary in [_head, _muzzle]:
		for s: MeshInstance3D in g.values():
			s.visible = false
	_rays_muzzle.node.visible = false
	_rays_impact.node.visible = false
	if boom:      # always ends in the dome where the beam ends (on what it hit, or wherever its head got to after the target died)
		_explode(hit_p, k, true)


static func _seg_dist(px: float, py: float, pz: float, o: Vector3, d: Vector3, L: float) -> float:
	var tt := clampf((px - o.x) * d.x + (py - o.y) * d.y + (pz - o.z) * d.z, 0.0, L)
	return (o + d * tt).distance_to(Vector3(px, py, pz))


func _sim_beam(dt: float, _P: Player) -> void:
	var on_ := state == "beam" or state == "fade"
	if not on_:
		return
	var fade_k := 1.0 - t_ / FADE_T if state == "fade" else 1.0
	# steer slowly toward the aim
	var a := (aim - origin).normalized()
	var ang := dir.angle_to(a)
	if ang > 1e-4:
		var q := Quaternion(dir, a)
		dir = (Quaternion.IDENTITY.slerp(q, minf(1.0, STEER * dt / ang)) * dir).normalized()
	# how far the beam can go: the head runs out at SPEED until something stops it
	head_d = minf(RANGE, head_d + SPEED * dt)
	var rr: Variant = combat.cast_ray(origin.x, origin.y, origin.z, dir.x, dir.y, dir.z, RANGE)
	var stop_: float = rr.d if rr.target != null or rr.hit_world else RANGE
	var was_contact := contact
	len_ = minf(head_d, stop_)
	contact = head_d >= stop_ and (rr.target != null or rr.hit_world)
	hit = rr.target if contact else null
	hit_world = contact and rr.target == null
	hit_p = origin + dir * len_
	if contact and not was_contact and fade_k > 0.5:
		_explode(hit_p, k * 0.45, false)
	# damage along the beam, ten times a second
	tick_t -= dt
	if tick_t <= 0.0 and fade_k > 0.3:
		tick_t = 0.1
		var dmg := lerpf(DPS0, DPS1, k) * 0.1
		for O: Variant in combat.targets.duplicate():
			if not _hittable(O):
				continue
			var h: float = O.h if O.h != 0.0 else 1.8
			var d := _seg_dist(O.x, O.y + h * 0.5, O.z, origin, dir, len_ + r)
			if d < r * 1.4 + (O.r if O.r != 0.0 else 0.5) + h * 0.25:
				combat.damage(O, dmg, origin, 2.5 + 3.0 * k, {"x": hit_p.x, "y": hit_p.y, "z": hit_p.z, "kind": "target", "nx": -dir.x, "ny": -dir.y, "nz": -dir.z} if O == hit else null)
	# the contact point keeps erupting
	if contact:
		crack_t -= dt
		if crack_t <= 0.0:
			crack_t = randf_range(0.07, 0.14)
			for i in 14:
				var v := (Vector3(randf_range(-1, 1), randf_range(-0.2, 1), randf_range(-1, 1)).normalized() + dir * -0.8).normalized()
				var sp := randf_range(5.0, 14.0)
				_spark(hit_p.x, hit_p.y, hit_p.z, v.x * sp, v.y * sp, v.z * sp, randf_range(0.2, 0.5), randf_range(0.1, 0.22))
		if randf() < dt * 30.0:
			_smoke(hit_p.x, hit_p.y, hit_p.z, randf_range(-1.5, 1.5), randf_range(0.5, 2.0), randf_range(-1.5, 1.5), randf_range(1.0, 2.0), 0.6, 2.4 + 2.0 * k)
		if randf() < dt * 25.0:
			_puff(hit_p.x, hit_p.y, hit_p.z, randf_range(-4, 4), randf_range(0, 3), randf_range(-4, 4), randf_range(0.6, 1.2), 0.5, 1.8)
		if hit_world and randf() < dt * 10.0:
			_fling_rock(hit_p, Vector3(randf_range(-1, 1), 0.8, randf_range(-1, 1)).normalized(), randf_range(4.0, 9.0))
		_head_i = maxf(_head_i, 30.0 + 40.0 * k)
		Game.fx.shake = maxf(Game.fx.shake, 0.12 + 0.18 * k)
	# sparks peeling off the beam body
	for i in int(3.0 + 6.0 * k):
		var pt := origin + dir * randf_range(0.0, len_)
		var b := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
		_spark(pt.x + b.x * r, pt.y + b.y * r, pt.z + b.z * r, b.x * 2.0 - dir.x * 3.0, b.y * 2.0 - dir.y * 3.0, b.z * 2.0 - dir.z * 3.0, randf_range(0.15, 0.35), randf_range(0.05, 0.1))
	alpha = fade_k
	Game.fx.shake = maxf(Game.fx.shake, 0.1 * fade_k)
	_hand_i = maxf(_hand_i, (20.0 + 30.0 * k) * fade_k)


## an energy dome (final = the big one the beam ends with; else the burst on first contact)
func _explode(p: Vector3, q: float, final: bool) -> void:
	var B: Dictionary = _free_booms.pop_back() if not _free_booms.is_empty() else _make_boom()
	var R := lerpf(DOME_R0, DOME_R1, q) if final else lerpf(0.8, 2.6, q)
	B["p"] = p
	B["R"] = R
	B["t"] = 0.0
	B["dur"] = 1.25 + 0.5 * q if final else 0.55
	B["final"] = final
	B["k"] = q
	var gy: float = ground_h.call(p.x, p.z, p.y + 0.5)
	B["gy"] = gy if is_finite(gy) else p.y
	var ground := p.y - float(B["gy"]) < R * 0.8
	B["ground"] = ground
	for n: String in ["dome", "ring", "flash", "star"]:
		var o: Node3D = B[n]
		o.visible = true
		o.position = p
	(B["ring"] as Node3D).visible = ground
	(B["ring"] as Node3D).position.y = float(B["gy"]) + 0.05
	_booms.append(B)
	var n_ := int(160.0 + 220.0 * q if final else 40.0 + 60.0 * q)
	for i in n_:
		var a := Vector3(randf_range(-1, 1), randf_range(-0.3, 1), randf_range(-1, 1)).normalized()
		var sp := randf_range(0.4, 1.0) * R * 4.0
		_spark(p.x, p.y, p.z, a.x * sp, a.y * sp, a.z * sp, randf_range(0.3, 0.9), randf_range(0.1, 0.3) * (1.5 if final else 1.0))
	for i in int(30.0 + 30.0 * q if final else 8.0):
		var a := randf_range(0.0, 6.28)
		var sp := randf_range(1.0, 3.0) * R * 0.5
		_smoke(p.x + cos(a) * R * 0.3, maxf(B["gy"], p.y - R * 0.3), p.z + sin(a) * R * 0.3, cos(a) * sp, randf_range(0.6, 2.4), sin(a) * sp, randf_range(1.6, 3.2), R * 0.4, R * 1.3)
	if ground:
		for i in int(40.0 + 50.0 * q if final else 10.0):
			var a := randf_range(0.0, 6.28)
			var sp := randf_range(4.0, 10.0) * (0.5 + q)
			_puff(p.x, float(B["gy"]) + 0.1, p.z, cos(a) * sp, randf_range(0.0, 1.0), sin(a) * sp, randf_range(0.8, 1.6), 0.6, 2.6 + R * 0.4)
	if final and ground:
		for i in int(8.0 + 10.0 * q):
			_fling_rock(Vector3(p.x, float(B["gy"]) + 0.2, p.z), Vector3(randf_range(-1, 1), randf_range(0.6, 1.4), randf_range(-1, 1)).normalized(), randf_range(6.0, 14.0))
	_boom_light.position = p + Vector3(0.0, 0.5, 0.0)
	_boom_i = 120.0 + 160.0 * q if final else 40.0
	_boom_light.omni_range = R * 7.0
	var d := Game.camera.global_position.distance_to(p)
	Game.fx.shake = maxf(Game.fx.shake, (0.6 + 0.6 * q if final else 0.25) * clampf(1.3 - d / 60.0, 0.2, 1.0))
	if final:
		_snd_boom(q, p)
		var dmg := lerpf(BOOM0, BOOM1, q)
		for O: Variant in combat.targets.duplicate():
			if not _hittable(O):
				continue
			var dd := Vector3(O.x, O.y + (O.h if O.h != 0.0 else 1.8) * 0.5, O.z).distance_to(p)
			if dd < R + (O.r if O.r != 0.0 else 0.5):
				combat.damage(O, dmg * (1.0 - 0.6 * clampf(dd / R, 0.0, 1.0)), p, 6.0 + 8.0 * q, null)


func _sim_booms(dt: float) -> void:
	var imp: Variant = null
	var imp_i := 0.0
	for i in range(_booms.size() - 1, -1, -1):
		var B: Dictionary = _booms[i]
		B["t"] += dt
		var u: float = float(B["t"]) / float(B["dur"])
		if u >= 1.0:
			for n: String in ["dome", "ring", "flash", "star"]:
				(B[n] as Node3D).visible = false
			_free_booms.append(B)
			_booms.remove_at(i)
			continue
		var R: float = B["R"]
		var grow := 1.0 - pow(1.0 - minf(1.0, u / 0.45), 3.0)
		var fade := 1.0 if u < 0.4 else 1.0 - (u - 0.4) / 0.6
		var dome: MeshInstance3D = B["dome"]
		dome.scale = Vector3.ONE * (R * (0.15 + 0.85 * grow))
		if B["ground"]:
			dome.position.y = maxf((B["p"] as Vector3).y, B["gy"]) - R * 0.15 * grow
		var U_ := dome.material_override as ShaderMaterial
		U_.set_shader_parameter(&"uAlpha", fade * (0.9 + 0.2 * randf()))
		U_.set_shader_parameter(&"uFill", lerpf(1.6, 0.15, minf(1.0, u * 2.2)))
		U_.set_shader_parameter(&"uRim", 1.4)
		U_.set_shader_parameter(&"uTime", time)
		U_.set_shader_parameter(&"uHot", Vector3.ONE)
		U_.set_shader_parameter(&"uColor", Vector3(lerpf(0.75, 0.2, u), lerpf(0.88, 0.45, u), 1.0))
		var ru := 1.0 - pow(1.0 - minf(1.0, u / 0.7), 3.0)
		(B["ring"] as Node3D).scale = Vector3.ONE * (R * (0.6 + 2.6 * ru))
		((B["ring"] as MeshInstance3D).material_override as StandardMaterial3D).albedo_color.a = (1.0 - u) * 0.9
		(B["flash"] as Node3D).scale = Vector3.ONE * (R * (1.4 + 2.0 * grow))
		_sp(B["flash"], maxf(0.0, 1.0 - u * 2.5))
		(B["star"] as Node3D).scale = Vector3.ONE * (R * (2.5 + 3.0 * grow))
		B["rot"] += dt * 0.6
		_sp(B["star"], maxf(0.0, 1.0 - u * 3.0), B["rot"])
		if u < 0.35 and (imp == null or R > float(imp["R"])):
			imp = B
			imp_i = 1.0 - u / 0.35
	if imp != null:
		_rays_impact.update(dt, imp["p"], float(imp["R"]) * 3.0, float(imp["R"]) * 0.06, imp_i)
	elif contact and (state == "beam" or state == "fade"):
		_rays_impact.update(dt, hit_p, r * 7.0, r * 0.12, 0.7 * alpha)
	else:
		_rays_impact.update(dt, Vector3.ZERO, 0.0, 0.0, 0.0)


# ---- the pose (after the animator) + everything that rides on the hands ----
## turn a bone about a world axis (its children follow)
func _world_turn(an: Animator, key: StringName, axis: Vector3, ang: float) -> void:
	var rec: Animator.BoneRec = an.by_key.get(key)
	if rec == null or ang == 0.0:
		return
	var wq := Quaternion(axis.normalized(), ang) * an.bone_world_quat(rec.bone)
	var pi_ := an.skel.get_bone_parent(rec.bone)
	an.skel.set_bone_pose_rotation(rec.bone, (Animator.q_inv(an.bone_world_quat(pi_)) * wq).normalized())


## two-bone IK (the same solve as the animator's arm _ik, for any chain): A -> B -> end reaches target Tg, the middle joint bends toward pole
func _limb_ik(an: Animator, A: int, B: int, end: int, Tg: Vector3, pole: Vector3, wt: float) -> void:
	if wt < 0.002:
		return
	var s := an.bone_world_pos(A)
	var e := an.bone_world_pos(B)
	var h := an.bone_world_pos(end)
	var l1 := s.distance_to(e)
	var l2 := e.distance_to(h)
	var u := Tg - s
	var d := u.length()
	u /= d if d != 0.0 else 1.0
	d = clampf(d, absf(l1 - l2) + 0.02, l1 + l2 - 0.005)
	var a := (l1 * l1 + d * d - l2 * l2) / (2.0 * d)
	var hh := sqrt(maxf(0.0, l1 * l1 - a * a))
	var pd := (pole - u * pole.dot(u)).normalized()
	var e2 := s + u * a + pd * hh
	_limb_turn(an, A, (e - s).normalized(), (e2 - s).normalized(), wt)
	e = an.bone_world_pos(B)
	h = an.bone_world_pos(end)
	_limb_turn(an, B, (h - e).normalized(), (Tg - e).normalized(), wt)


func _limb_turn(an: Animator, bone: int, from: Vector3, to: Vector3, wt: float) -> void:
	var wq := Quaternion(from, to) * an.bone_world_quat(bone)
	var pq := Animator.q_inv(an.bone_world_quat(an.skel.get_bone_parent(bone)))
	an.skel.set_bone_pose_rotation(bone, an.skel.get_bone_pose_rotation(bone).normalized().slerp((pq * wq).normalized(), wt))


## put a foot back to its standing world orientation (flat), turned about the vertical by yaw
func _plant(an: Animator, foot: int, q_stand: Quaternion, yaw: float, wt: float) -> void:
	var wq := Quaternion(UP, yaw) * q_stand
	var pq := Animator.q_inv(an.bone_world_quat(an.skel.get_bone_parent(foot)))
	an.skel.set_bone_pose_rotation(foot, an.skel.get_bone_pose_rotation(foot).normalized().slerp((pq * wq).normalized(), wt))


func pose(an: Animator, P: Player, dt: float) -> void:
	var st := state
	var active := st != "idle" and not P.dead
	var w_goal := 0.0 if st == "idle" or st == "recover" else 1.0
	w = lerpf(w, w_goal, 1.0 - exp(-(14.0 if w_goal > 0.0 else 7.0) * dt))
	var f_goal := 1.0 if st == "thrust" or st == "beam" or st == "fade" else 0.0
	fwd = lerpf(fwd, f_goal, 1.0 - exp(-(34.0 if f_goal > 0.0 else 8.0) * dt))
	have_hands = false
	if w < 0.003 and not active:
		_place_followers(P, dt)
		return
	var K := an.by_key
	var fw := Cutscene.ease_(clampf(fwd, 0.0, 1.0))
	if not K.has(&"upper_armL") or not K.has(&"upper_armR") or not K.has(&"pelvis"):
		return
	var yaw := P.yaw
	var F := Vector3(sin(yaw), 0.0, cos(yaw))
	var Rt := Vector3(-cos(yaw), 0.0, sin(yaw))
	var wind_k := Cutscene.ease_(clampf((t_ / WIND_T - 0.35) / 0.65, 0.0, 1.0)) if st == "wind" else 1.0
	# ---- Goku's stance: a wide split (left foot forward, knee bent; right leg back and straighter, foot turned out), hips sunk and turned side-on.
	#      Charging, the torso winds further right with the hands behind the right hip; on the push it squares up to the target and the weight drives forward.
	var stance := w * (Cutscene.ease_(clampf(t_ / (WIND_T * 0.6), 0.0, 1.0)) if st == "wind" else 1.0)
	var has_ft: bool = K.has(&"footL") and K.has(&"footR")
	var ft_l: int = K[&"footL"].bone if has_ft else -1
	var ft_r: int = K[&"footR"].bone if has_ft else -1
	var ankle := an.bone_world_pos(ft_l).y - P.y if has_ft else 0.08      # standing ankle height (the animator's idle pose)
	if has_ft:
		q_fl = an.bone_world_quat(ft_l)
		q_fr = an.bone_world_quat(ft_r)
	an.actor.position.y -= lerpf(0.17, 0.22, fw) * stance      # sink into the stance (the animator puts the actor back each frame)
	an.actor.position += F * (lerpf(0.0, 0.1, fw) * stance)      # the push carries the hips forward over the front foot
	var hip_yaw := lerpf(-0.38, -0.3, fw) * stance      # side-on: left shoulder to the target
	_world_turn(an, &"pelvis", UP, hip_yaw)
	if has_ft and K.has(&"thighL") and K.has(&"shinL") and K.has(&"thighR") and K.has(&"shinR"):
		var base := Vector3(P.x, P.y + ankle, P.z)
		var f_l := base + F * lerpf(0.42, 0.5, fw) + Rt * -0.2
		var f_r := base + F * lerpf(-0.5, -0.58, fw) + Rt * 0.26
		_limb_ik(an, K[&"thighL"].bone, K[&"shinL"].bone, ft_l, f_l, F + Rt * -0.25 + UP * 0.1, stance)
		_limb_ik(an, K[&"thighR"].bone, K[&"shinR"].bone, ft_r, f_r, F + Rt * 0.5, stance)
		# feet flat on the ground: the front one points at the target, the back one turned out
		_plant(an, ft_l, q_fl, 0.15 * stance, stance)
		_plant(an, ft_r, q_fr, -0.75 * stance, stance)
	# torso: wound further right while charging, squared up on the push; leaning forward into it; the head stays on the target
	var twist := lerpf(-0.22 * wind_k, 0.42, fw) * w
	var lean := lerpf(0.4 * wind_k, 0.42, fw) * w
	var ax_r := Rt.rotated(UP, hip_yaw)
	_world_turn(an, &"spine1", UP, twist * 0.35)
	_world_turn(an, &"spine2", UP, twist * 0.35)
	_world_turn(an, &"chest", UP, twist * 0.3)
	_world_turn(an, &"spine1", ax_r, -lean * 0.45)
	_world_turn(an, &"spine2", ax_r, -lean * 0.3)
	_world_turn(an, &"chest", ax_r, -lean * 0.25)
	_world_turn(an, &"head", UP, -(twist + hip_yaw) * 0.9)
	_world_turn(an, &"head", ax_r, lean * 0.6)
	# targets: palms cupped round the ball at the right hip / palms out at arm's length along the aim
	var sh_l := an.bone_world_pos(K[&"upper_armL"].bone)
	var sh_r := an.bone_world_pos(K[&"upper_armR"].bone)
	var fa := an.bone_world_pos(K[&"forearmR"].bone)
	var reach := sh_r.distance_to(fa) + fa.distance_to(an.bone_world_pos(K[&"handR"].bone))
	var pel := an.bone_world_pos(K[&"pelvis"].bone)
	var mid := (sh_l + sh_r) * 0.5
	var hip := pel + Rt * 0.27 + F * 0.14 + UP * 0.22      # at the right hip, a little in front (the left arm crosses the front of the belly to get there)
	var front := mid + F * (reach * 0.55) + UP * -0.18
	var cup_c: Vector3 = front.lerp(hip, wind_k) if st == "wind" else hip
	var aim_d: Vector3 = dir if st == "beam" or st == "fade" else (aim - mid).normalized()
	var out_c := mid + aim_d * (reach * 0.93) + UP * -0.06
	var C := cup_c.lerp(out_c, fw)
	var gap := lerpf(0.05 + 0.05 * k, 0.04, fw)      # half the space between the palms (the ball sits in it)
	# hand aims (world): cupped = top hand (L) palm down, bottom hand (R) palm up, fingers forward and a little out; out = both palms along the aim, the top hand's fingers up and the bottom hand's down, heels of the palms together
	var fingers_cup := (F + Rt * 0.2).normalized()
	var side := aim_d.cross(UP)
	if side.length_squared() < 1e-4:
		side = Rt
	side = side.normalized()
	var up_a := side.cross(aim_d).normalized()
	var aim_l := HandPose.Aim.new((-UP).lerp(aim_d, fw).normalized(), null, fingers_cup.lerp(up_a, fw).normalized())
	var aim_r := HandPose.Aim.new(UP.lerp(aim_d, fw).normalized(), null, fingers_cup.lerp(-up_a, fw).normalized())
	hands.goal("L", "open" if fw > 0.5 else "phone", aim_l)
	hands.goal("R", "open" if fw > 0.5 else "phone", aim_r)
	var q_l := HandPose.hand_quat("L", aim_l)
	var q_r := HandPose.hand_quat("R", aim_r)
	# palm centres: cupped, one above the other; out, side by side at the heels -> wrist targets
	var sep := 0.025 * fw
	var off := UP * (gap * (1.0 - fw)) + up_a * (0.035 * fw)
	var p_l := C + off + side * -sep
	var p_r := C - off + side * sep
	var w_l := p_l - HandPose.palm_point("L", q_l)
	var w_r := p_r - HandPose.palm_point("R", q_r)
	an._ik(0, w_l, F * lerpf(1.0, 0.2, fw) + UP * -0.7 + Rt * lerpf(-0.15, -0.8, fw), w)      # crossing: elbow forward and down, in front of the belly (not through it); out: elbow down and out
	an._ik(1, w_r, Rt * 0.8 + F * -0.7 + UP * -0.5, w)
	hands.apply(an, dt, time)
	# where the palms really are this frame (the ball and the beam leave from between them)
	var hl: int = K[&"handL"].bone
	var hr: int = K[&"handR"].bone
	palm_l = an.bone_world_pos(hl) + HandPose.palm_point("L", an.bone_world_quat(hl))
	palm_r = an.bone_world_pos(hr) + HandPose.palm_point("R", an.bone_world_quat(hr))
	have_hands = true
	_place_followers(P, dt)


## the ball, the muzzle burst and the beam's start ride on the palms; called from pose() so they match this frame's hands
func _place_followers(P: Player, dt: float) -> void:
	var st := state
	var charging := st == "wind" or st == "charge" or st == "thrust"
	var firing := st == "beam" or st == "fade"
	if have_hands:
		_ball_pos = (palm_l + palm_r) * 0.5
	else:
		_ball_pos = Vector3(P.x + sin(P.yaw) * 0.4, P.y + 1.1, P.z + cos(P.yaw) * 0.4)
	_hand_light.position = _ball_pos
	# ---- the charging ball ----
	var q := 0.03 * clampf(t_ / WIND_T, 0.0, 1.0) if st == "wind" else k
	var vis := charging and (st != "wind" or t_ > WIND_T * 0.5)
	for s: MeshInstance3D in _ball.values():
		s.visible = vis
	for m: Dictionary in _swoosh:
		(m["m"] as Node3D).visible = vis and q > 0.15
	if vis:
		var rb := lerpf(BALL0, BALL1, q) * (1.0 + 0.1 * sin(time * 37.0) + 0.06 * randf()) * (1.25 if st == "thrust" else 1.0)
		var full := 1.0 + 0.12 * sin(time * 24.0) if k >= 1.0 else 1.0
		_ball_r = rb
		for s: MeshInstance3D in _ball.values():
			s.position = _ball_pos
		var bc: MeshInstance3D = _ball["core"]
		var bh: MeshInstance3D = _ball["halo"]
		var bs: MeshInstance3D = _ball["star"]
		bc.scale = Vector3.ONE * (rb * 3.2 * full)
		bh.scale = Vector3.ONE * (rb * (7.0 + 4.0 * q) * full)
		bs.scale = Vector3.ONE * (rb * (10.0 + 14.0 * q) * full)
		_sp(bh, 0.6 + 0.4 * q)
		_sp(bs, clampf(q * 1.6, 0.0, 1.0) * (0.7 + 0.3 * randf()), time * 2.4)      # (JS += .04 a frame)
		_sp(bc, 1.0, -time * 4.2)
		_rays_charge.update(dt, _ball_pos, 0.4 + 2.4 * q, 0.01 + 0.025 * q, clampf(q * 1.4, 0.0, 1.0))
		for m: Dictionary in _swoosh:
			m["a"] += float(m["spin"]) * dt
			var n: MeshInstance3D = m["m"]
			n.position = _ball_pos
			n.basis = Basis((m["tilt"] as Quaternion) * Quaternion(Z1, m["a"])).scaled(Vector3.ONE * (rb * 6.0 + 0.25 * q))
			(n.material_override as StandardMaterial3D).albedo_color.a = clampf((q - 0.15) * 2.0, 0.0, 1.0) * (0.6 + 0.4 * randf())
	else:
		_rays_charge.update(0.0, _ball_pos, 0.0, 0.0, 0.0)
	# ---- the beam leaves from the palms ----
	for s: MeshInstance3D in _muzzle.values():
		s.visible = firing
	if not firing:
		_rays_muzzle.update(0.0, _ball_pos, 0.0, 0.0, 0.0)
		_head_bulb.visible = false
		for s: MeshInstance3D in _head.values():
			s.visible = false
		return
	var a := alpha
	var rn := r * (1.0 + 0.07 * sin(time * 41.0) + 0.04 * randf()) * lerpf(0.35, 1.0, a)
	origin = _ball_pos + dir * 0.05
	_beam_g.position = origin
	var bq := Quaternion(Z1, dir)
	_beam_g.quaternion = bq
	var L := maxf(0.01, len_)
	for sh: Dictionary in _shells:
		(sh["mesh"] as Node3D).scale = Vector3(rn * float(sh["s"]), rn * float(sh["s"]), L)
		(sh["m"] as ShaderMaterial).set_shader_parameter(&"uLen", L)
		(sh["m"] as ShaderMaterial).set_shader_parameter(&"uAlpha", a)
	for s: MeshInstance3D in _muzzle.values():
		s.position = origin
	(_muzzle["core"] as Node3D).scale = Vector3.ONE * (rn * 3.4)
	(_muzzle["halo"] as Node3D).scale = Vector3.ONE * (rn * 6.0)
	(_muzzle["star"] as Node3D).scale = Vector3.ONE * (rn * (8.0 + 3.0 * randf()))
	_sp(_muzzle["core"], a)
	_sp(_muzzle["halo"], a)
	_sp(_muzzle["star"], a * (0.75 + 0.25 * randf()), time * 3.0)
	_rays_muzzle.update(dt, origin, 0.9 + 1.8 * k, 0.015 + 0.025 * k, 0.7 * a)
	# the head: a bulging ball of energy at the front
	var hp := origin + dir * L
	var hr := rn * (1.9 if contact else 1.55) * (1.0 + 0.1 * sin(time * 29.0))
	_head_bulb.visible = true
	_head_bulb.position = hp
	_head_bulb.quaternion = bq
	_head_bulb.scale = Vector3(hr, hr, hr * 1.25)
	(_head_bulb.material_override as ShaderMaterial).set_shader_parameter(&"uAlpha", a)
	for s: MeshInstance3D in _head.values():
		s.visible = true
		s.position = hp
	(_head["core"] as Node3D).scale = Vector3.ONE * (hr * 2.6)
	(_head["halo"] as Node3D).scale = Vector3.ONE * (hr * 5.0)
	(_head["star"] as Node3D).scale = Vector3.ONE * (hr * (9.0 if contact else 6.0))
	_sp(_head["core"], a)
	_sp(_head["halo"], a)
	_sp(_head["star"], a * (0.6 + 0.4 * randf()), -time * 3.6)
	_head_light.position = hp
	_head_i = maxf(_head_i, (15.0 + 25.0 * k) * a)
