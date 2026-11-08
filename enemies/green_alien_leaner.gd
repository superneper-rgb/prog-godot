class_name GreenAlienLeaner
extends GrayAlienNpc
## The green alien leaning on the wall outside Club 9 (JS enemies/green-alien-view.js createGreenAlienLeaner): back flat on the brick, one foot up on it, a cigarette in the right hand. Every so often the hand goes up for a drag and a puff comes out; while he talks the cigarette stays down.

const PERIOD := 10.0      # seconds per smoking cycle

var _cig: Node3D
var _tip: Node3D
var _ember_mat: StandardMaterial3D
var _ember_glow: Sprite3D
var _puffs: Array[Dictionary] = []
var _wisp_t := 0.0
var _puffed := -1
var _arm := 0.0
var _lean_look := 0.0


func _init(_opt: Dictionary = {}) -> void:
	super._init({"green": true, "outfit": "punk", "pose": &"idle"})
	name = "Green alien (Club 9)"
	R.state = &"lean"
	view.gun_hidden = true      # no plasma pistol: both hands are for leaning and smoking


static func _stick(r: float, h: float, col: int) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 8
	c.rings = 1
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.hex((col << 8) | 0xff)
	m.roughness = 0.8
	var o := MeshInstance3D.new()
	o.mesh = c
	o.material_override = m
	o.rotation.x = PI / 2.0
	o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return o


func _ready() -> void:
	super._ready()
	# ---- cigarette in the right hand (axis along the hand's z, lit end forward)
	_cig = Node3D.new()
	_cig.top_level = true
	add_child(_cig)
	_cig.add_child(_stick(0.0065, 0.085, 0xf2efe6))
	var filter := _stick(0.0068, 0.026, 0xc98a3c)
	filter.position.z = -0.03
	_cig.add_child(filter)
	_tip = Node3D.new()
	_tip.position.z = 0.044
	_cig.add_child(_tip)
	var s := SphereMesh.new()
	s.radius = 0.0072
	s.height = 0.0144
	s.radial_segments = 8
	s.rings = 6
	_ember_mat = StandardMaterial3D.new()
	_ember_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ember_mat.albedo_color = Color.hex(0xff5a1fff)
	var em := MeshInstance3D.new()
	em.mesh = s
	em.material_override = _ember_mat
	em.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tip.add_child(em)
	var glow: Texture2D = load("res://assets/ui/menu_scene/glow.png")
	_ember_glow = _sprite(glow, Color.hex(0xff7a2aff), true)
	_ember_glow.pixel_size = 0.07 / 64.0
	_ember_glow.modulate.a = 0.6
	_tip.add_child(_ember_glow)
	# ---- smoke: a small pool of soft grey sprites that rise, spread and fade
	for i in 28:
		var q := _sprite(glow, Color.hex(0xaeb4baff), false)
		q.top_level = true
		q.visible = false
		add_child(q)
		_puffs.append({"s": q, "life": 0.0, "max": 1.0, "vx": 0.0, "vy": 0.0, "vz": 0.0, "r0": 0.05, "r1": 0.3, "a": 0.3})


static func _sprite(tex: Texture2D, col: Color, additive: bool) -> Sprite3D:
	var q := Sprite3D.new()
	q.texture = tex
	q.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	q.shaded = false
	q.transparent = true
	q.modulate = col
	q.pixel_size = 1.0 / 64.0
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if additive:
		q.material_override = null
	return q


func _emit(p: Vector3, r0: float, r1: float, a: float, life: float, vy: float, spread: float) -> void:
	for q: Dictionary in _puffs:
		if float(q.life) <= 0.0:
			q.life = life
			q.max = life
			q.r0 = r0
			q.r1 = r1
			q.a = a
			q.vy = vy
			q.vx = (randf() - 0.5) * spread
			q.vz = (randf() - 0.5) * spread
			(q.s as Sprite3D).global_position = p
			(q.s as Sprite3D).visible = true
			return


func look_at_point(x: float, z: float) -> void:
	_lean_look = _wrap(atan2(x - R.x, z - R.z) - R.yaw)


func look_away() -> void:
	_lean_look = 0.0


func update(time: float, dt: float) -> void:
	var c := fmod(time, PERIOD)
	var want := 0.0
	if not view.talk:
		if c > 3.2 and c < 4.0:
			want = (c - 3.2) / 0.8
		elif c >= 4.0 and c <= 5.3:
			want = 1.0
		elif c > 5.3 and c < 6.1:
			want = 1.0 - (c - 5.3) / 0.8
	_arm += (want - _arm) * minf(1.0, dt * 10.0)
	view.arm = _arm
	view.look_yaw = _lean_look
	R.state_t += dt
	position = Vector3(R.x, R.y, R.z)
	view.update(dt, time, null)
	_cig.global_transform = view.pose.world[view.j_hd_r] * Transform3D(Basis.IDENTITY, Vector3(0.0, -0.07, 0.03))
	var tip := _tip.global_position
	# exhale as the hand comes down; thin wisps from the lit end while it rests
	var cyc := floori(time / PERIOD)
	if not view.talk and c > 5.4 and _puffed != cyc:
		_puffed = cyc
		var m := mouth_world()
		for i in 6:
			_emit(m, 0.05, 0.4, 0.34, 2.6 + randf(), 0.28 + randf() * 0.12, 0.28)
	_wisp_t -= dt
	if _wisp_t <= 0.0 and dt > 0.0:
		_wisp_t = 0.3 + randf() * 0.15
		_emit(tip, 0.025, 0.22, 0.2, 2.2 + randf(), 0.2, 0.05)
	var lit := 0.55 + 0.45 * _arm + 0.15 * sin(time * 9.0)
	_ember_glow.modulate.a = minf(1.0, lit)
	_ember_mat.albedo_color = Color(1.0, 0.25 + 0.3 * _arm, 0.08)
	for q: Dictionary in _puffs:
		if float(q.life) <= 0.0:
			continue
		q.life = float(q.life) - dt
		var sp: Sprite3D = q.s
		if float(q.life) <= 0.0:
			sp.visible = false
			continue
		var u := 1.0 - float(q.life) / float(q.max)
		sp.global_position += Vector3(float(q.vx) * dt, float(q.vy) * dt * (1.0 - 0.5 * u), float(q.vz) * dt)
		sp.pixel_size = (float(q.r0) + (float(q.r1) - float(q.r0)) * sqrt(u)) / 64.0
		sp.modulate.a = float(q.a) * sin(minf(1.0, u * 5.0) * PI / 2.0) * (1.0 - u)
