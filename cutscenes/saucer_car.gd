class_name SaucerCar
extends Node3D
## A purple flying saucer that has wheels, the gray aliens' ride (JS cutscenes/saucer-car.js). Origin = the ground under the car's centre, nose = +z. update(dt, speed, beat): speed in m/s spins the wheels, beat 0..1 bounces the body to the bass. set_dome(0..1): 0 closed, 1 open (the canopy tips up at the back).

const PROF: Array[Vector2] = [Vector2(0.0, 0.34), Vector2(0.8, 0.30), Vector2(1.5, 0.38), Vector2(1.92, 0.55), Vector2(2.02, 0.70), Vector2(1.9, 0.82), Vector2(1.4, 0.96), Vector2(0.8, 1.06), Vector2(0.35, 1.12), Vector2(0.0, 1.13)]
const SEG := 56

static var _glow_tex: GradientTexture2D = null

var body: Node3D
var wheels: Array[Node3D] = []
var dome_pivot: Node3D
var _bulbs: Array[MeshInstance3D] = []
var _bulb_on: StandardMaterial3D
var _bulb_off: StandardMaterial3D
var _beacon: StandardMaterial3D
var _stripe: StandardMaterial3D
var _glow: ShaderMaterial
var _spin := 0.0
var _clock := 0.0


static func _emit(c: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color.hex((c << 8) | 0xff)
	return m


static func _glow_texture() -> GradientTexture2D:
	if _glow_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.4), Color(1, 1, 1, 0)])
		_glow_tex = GradientTexture2D.new()
		_glow_tex.gradient = g
		_glow_tex.width = 64
		_glow_tex.height = 64
		_glow_tex.fill = GradientTexture2D.FILL_RADIAL
		_glow_tex.fill_from = Vector2(0.5, 0.5)
		_glow_tex.fill_to = Vector2(1.0, 0.5)
	return _glow_tex


static func _sprite_mat(c: int, op: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://cutscenes/saucer_glow.gdshader")
	m.set_shader_parameter(&"map", _glow_texture())
	var k := Color.hex((c << 8) | 0xff)
	m.set_shader_parameter(&"col", Vector3(k.r, k.g, k.b))
	m.set_shader_parameter(&"op", op)
	return m


static func _sprite(par: Node3D, mat: Material, p: Vector3, s: float) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(s, s)
	var o := Goggles.part(par, q, mat, p)
	o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return o


static func _torus(r: float, t: float, rings: int, seg: int) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = r - t
	m.outer_radius = r + t
	m.rings = rings
	m.ring_segments = seg
	return m


static func _ball(r: float, a: int, b: int) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = a
	m.rings = b
	return m


## The lathed hull: flat belly, sharp rim, shallow top. (The JS's seam shares its normals: here the last column wraps to the first.)
static func _hull_mesh() -> ArrayMesh:
	var P := PackedVector3Array()
	var I := PackedInt32Array()
	var n := PROF.size()
	for i in SEG:
		var a := float(i) / float(SEG) * TAU
		for p: Vector2 in PROF:
			P.append(Vector3(p.x * sin(a), p.y, p.x * cos(a)))
	for i in SEG:
		var i2 := (i + 1) % SEG
		for j in n - 1:
			var A := i * n + j
			var B := i2 * n + j
			var C := i2 * n + j + 1
			var D := i * n + j + 1
			I.append_array(PackedInt32Array([A, B, D, C, D, B]))
	return Goggles.indexed_mesh(P, I)


func _init() -> void:
	name = "Saucer car"
	body = Node3D.new()
	add_child(body)
	var paint := Goggles._std(0x6a35a8, 0.28, 0.75, true)
	var chrome := Goggles._std(0xcfd6e0, 0.18, 0.95)
	var dark := Goggles._std(0x15131a, 0.85, 0.1)
	var glass := Goggles._std(0x7fe9ff, 0.05, 0.2, true)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color.a = 0.38
	# ---- the saucer: a lathed hull, chrome rim band, neon stripe
	Goggles.part(body, _hull_mesh(), paint)
	Goggles.part(body, _torus(1.99, 0.055, 64, 8), chrome, Vector3(0.0, 0.70, 0.0))
	_stripe = _emit(0xb455ff)
	Goggles.part(body, _torus(1.5, 0.03, 64, 6), _stripe, Vector3(0.0, 0.97, 0.0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Goggles.part(body, _torus(1.15, 0.045, 48, 6), _emit(0x5dff9a), Vector3(0.0, 0.3, 0.0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# chase lights around the rim
	_bulb_on = _emit(0xfff2a8)
	_bulb_off = _emit(0xff9a2a)
	var bulb := _ball(0.045, 8, 6)
	for i in 20:
		var a := float(i) / 20.0 * TAU
		var b := Goggles.part(body, bulb, _bulb_off, Vector3(sin(a) * 2.01, 0.70, cos(a) * 2.01))
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_bulbs.append(b)
	# ---- canopy: a glass bubble hinged at the back, so it can tip open
	dome_pivot = Node3D.new()
	dome_pivot.name = "saucer_dome"
	dome_pivot.position = Vector3(0.0, 1.08, -1.05)
	body.add_child(dome_pivot)
	var dm := SphereMesh.new()
	dm.radius = 1.05
	dm.height = 1.05
	dm.is_hemisphere = true
	dm.radial_segments = 32
	dm.rings = 16
	var dome := Goggles.part(dome_pivot, dm, glass, Vector3(0.0, 0.0, 1.05))      # roomy enough for two full-size gray aliens sitting in tandem
	dome.scale = Vector3(1.0, 1.05, 1.0)
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Goggles.part(dome_pivot, _torus(1.05, 0.04, 40, 6), chrome, Vector3(0.0, 0.0, 1.05))
	Goggles.part(body, Goggles.cyl_mesh(0.012, 0.012, 0.7, 6), chrome, Vector3(0.5, 0.35, -0.2), Vector3(0.0, 0.0, -0.25))
	_beacon = _emit(0xff3b6b)
	Goggles.part(body, _ball(0.05, 8, 6), _beacon, Vector3(0.58, 0.7, -0.2)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# ---- wheels poking out below the rim: fat tyres, chrome hubs with spokes
	var tyre_m := Goggles.cyl_mesh(0.4, 0.4, 0.34, 20)
	var hub_m := Goggles.cyl_mesh(0.24, 0.24, 0.36, 14)
	var spoke_m := Goggles.box_mesh(0.38, 0.05, 0.4)
	for w_at: Vector2 in [Vector2(-1.5, 0.95), Vector2(1.5, 0.95), Vector2(-1.5, -0.95), Vector2(1.5, -0.95)]:
		var w := Node3D.new()
		w.position = Vector3(w_at.x, 0.4, w_at.y)
		add_child(w)
		Goggles.part(w, tyre_m, dark, Vector3.ZERO, Vector3(0.0, 0.0, PI / 2.0))
		Goggles.part(w, hub_m, chrome, Vector3.ZERO, Vector3(0.0, 0.0, PI / 2.0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i in 3:
			Goggles.part(w, spoke_m, dark, Vector3.ZERO, Vector3(float(i) * PI / 3.0, 0.0, 0.0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wheels.append(w)
	# ---- head / tail lights and an underglow pool on the road
	_lamp(-0.62, 1.9, 0xfff3c8, true)
	_lamp(0.62, 1.9, 0xfff3c8, true)
	_lamp(-0.7, -1.9, 0xff2a2a, false)
	_lamp(0.7, -1.9, 0xff2a2a, false)
	_glow = _sprite_mat(0x6dff9a, 0.55)
	_sprite(self, _glow, Vector3(0.0, 0.05, 0.0), 6.4)


func _lamp(x: float, z: float, c: int, big: bool) -> void:
	var r := 0.1 if big else 0.08
	Goggles.part(body, _ball(r, 10, 8), _emit(c), Vector3(x, 0.66, z)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sprite(body, _sprite_mat(c, 0.8), Vector3(x, 0.66, z), 0.7)


func set_dome(k: float) -> void:
	dome_pivot.rotation.x = -k * 1.0


static func _hsl(h: float, s: float, l: float) -> Color:
	var q := l * (1.0 + s) if l <= 0.5 else l + s - l * s
	var p := 2.0 * l - q
	var ch := func(t: float) -> float:
		t = fposmod(t, 1.0)
		if t < 1.0 / 6.0:
			return p + (q - p) * 6.0 * t
		if t < 0.5:
			return q
		if t < 2.0 / 3.0:
			return p + (q - p) * 6.0 * (2.0 / 3.0 - t)
		return p
	return Color(ch.call(h + 1.0 / 3.0), ch.call(h), ch.call(h - 1.0 / 3.0))


func tick(dt: float, speed: float = 0.0, beat: float = 0.0) -> void:
	_clock += dt
	_spin += speed * dt / 0.4
	for w: Node3D in wheels:
		w.rotation.x = _spin
	body.position.y = 0.03 * beat + 0.012 * sin(_clock * 3.0)      # idle hover wobble + the bass thump
	body.scale.y = 1.0 + 0.025 * beat
	var i := 0
	var f := int(floor(_clock * 14.0))
	for b: MeshInstance3D in _bulbs:
		b.material_override = _bulb_on if (f + i) % 4 == 0 else _bulb_off
		i += 1
	_beacon.albedo_color = Color.hex(0xff3b6bff) if sin(_clock * 9.0) > 0.0 else Color.hex(0x401018ff)
	_glow.set_shader_parameter(&"op", 0.42 + 0.2 * beat + 0.05 * sin(_clock * 11.0))
	_stripe.albedo_color = _hsl(fmod(_clock * 0.25, 1.0), 0.9, 0.6)
