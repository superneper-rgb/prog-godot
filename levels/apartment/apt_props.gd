class_name AptProps
extends RefCounted
## PROG'S APARTMENT: the things that move, glow or pile up (JS levels/apartment/props.js createProps): the plasma TV (static only), the lights and their flicker, the cigarette and its smoke, the sink's drip, the bathroom mirror, the roaches and the city out the window. The clutter itself comes with the level export; the parts that move are found by their JS names.

const GROUND := -95.0
const LANES := [[-20.0, 1.0], [-22.0, -1.0], [-96.0, 1.0], [-98.0, -1.0]]
const CIG := Vector3(-1.05 + 0.075, 0.42 + 0.04, -2.25 + 0.01)      # (JS ax + 0.075, ty + 0.04, az + 0.01; the table's top is at 0.42)
const SPOUT_Y_ABOVE := 0.14
const STATIC_SHADER := """
shader_type spatial;
// JS props.js drawStatic: snow over 160 x 96 cells, redrawn at about 25 fps, a brighter band rolling down it, now and then a brighter row. In a shader: no script loop over the pixels.
render_mode unshaded, shadows_disabled;
uniform float time = 0.0;
uniform float roll = 0.0;
uniform vec3 tint = vec3(0.788, 0.824, 0.91);
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec2 cell = floor(UV * vec2(160.0, 96.0));
	float tick = floor(time * 25.0);
	float v = h(cell + tick * vec2(3.1, 7.7)) * 230.0 / 255.0;
	if (abs(cell.y - roll) < 6.0) { v += 40.0 / 255.0; }
	if (h(vec2(cell.y, tick)) < 0.04) { v += 30.0 / 255.0; }
	ALBEDO = pow(min(v, 1.0), 2.2) * pow(tint, vec3(2.2));
}
"""

var L: ExportedLevel
var tv_on := true
var events := {"drip": false, "scatter": null}
var kitchen: OmniLight3D
var lamp: OmniLight3D
var bath: OmniLight3D
var neon: OmniLight3D
var _tv_light: OmniLight3D
var _screen: MeshInstance3D
var _screen_on: ShaderMaterial
var _screen_off: StandardMaterial3D
var _led: MeshInstance3D
var _led_mat: BaseMaterial3D
var _roll := 0.0
var _ember: Node3D
var _ember_mat: BaseMaterial3D
var _clock: Node3D
var _vcr: Node3D
var _drop: Node3D
var _ripple: Node3D
var _ripple_mat: BaseMaterial3D
var _sign_mat: BaseMaterial3D
var _halo_mat: BaseMaterial3D
var _tube_mat: BaseMaterial3D
var _bulb_mat: BaseMaterial3D
var _cars: Array = []
var _beacons: Array = []
var _puffs: Array = []
var _drip_t := 1.2
var _drop_y := -1.0
var _ripple_t := 1.0
var _wy := 0.0
var _spout := Vector3.ZERO
var _roach: AptRoaches


func _light(nm: String) -> OmniLight3D:
	for o: Node in L.node_named(nm):
		if o is OmniLight3D:
			return o
	return null


func _one(nm: String) -> Node3D:
	var a: Array = L.node_named(nm)
	return a[0] if not a.is_empty() else null


## the material of a node's mesh, its own copy
static func _own_mat(n: Node) -> BaseMaterial3D:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var m: Material = mi.material_override if mi.material_override != null else (mi.mesh.surface_get_material(0) if mi.mesh != null else null)
		if m is BaseMaterial3D:
			var c := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
			mi.material_override = c
			return c
	for c: Node in n.get_children():
		var r := _own_mat(c)
		if r != null:
			return r
	return null


func _init(level: ExportedLevel, mats: Dictionary) -> void:
	L = level
	kitchen = _light("AptKitchen")
	lamp = _light("AptLamp")
	bath = _light("AptBath")
	neon = _light("AptNeon")
	_tv_light = _light("AptTvLight")
	var s := _one("AptTvScreen")
	if s != null:
		_screen = s if s is MeshInstance3D else s.find_children("*", "MeshInstance3D", true, false)[0]
		_screen_on = ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = STATIC_SHADER
		_screen_on.shader = sh
		_screen_off = StandardMaterial3D.new()
		_screen_off.albedo_color = Color.hex(0x07080aff)
		_screen_off.roughness = 0.2
		_screen.material_override = _screen_on
	var ld := _one("AptTvLed")
	if ld != null:
		_led_mat = _own_mat(ld)
	_ember = _one("AptEmber")
	if _ember != null:
		_ember_mat = _own_mat(_ember)
	_clock = _one("AptClock")
	_vcr = _one("AptVcr")
	_drop = _one("AptDrop")
	_ripple = _one("AptRipple")
	if _ripple != null:
		_ripple_mat = _own_mat(_ripple)
		_wy = _ripple.position.y - 0.002
		_spout = Vector3(_ripple.position.x, 0.0, 4.19)
	var sg := _one("AptSign")
	if sg != null:
		_sign_mat = _own_mat(sg)
	var hl := _one("AptHalo")
	if hl != null:
		_halo_mat = _own_mat(hl)
	_tube_mat = mats.get("fluorescent tube")
	_bulb_mat = mats.get("vanity bulb")
	var rng := RandomNumberGenerator.new()
	rng.seed = 93
	var i := 0
	for n: Node3D in L.node_named("AptCar"):
		_cars.append({"n": n, "lane": i % 4, "u": rng.randf(), "v": 0.02 + rng.randf() * 0.03})
		i += 1
	for n: Node3D in L.node_named("AptBeacon"):
		_beacons.append(n)
	i = 0
	for n: Node3D in L.node_named("AptPuff"):
		_puffs.append({"n": n, "m": _own_mat(n), "age": float(i) / 12.0 * 3.2, "life": 3.2})
		i += 1
	var mirror := _one("AptMirror")
	if mirror != null:
		var mi: MeshInstance3D = mirror if mirror is MeshInstance3D else mirror.find_children("*", "MeshInstance3D", true, false)[0]
		MirrorView.attach(mi, 0x8b8a7c, 0.4, 7.0)
	_roach = AptRoaches.new(level)


func set_tv(on: bool) -> void:
	tv_on = on
	if _screen != null:
		_screen.material_override = _screen_on if on else _screen_off
	if _tv_light != null:
		_tv_light.visible = on
	if _led_mat != null:
		var c := Color.hex(0x3aff6aff if on else 0xff2a1aff)
		_led_mat.albedo_color = c


func toggle_tv() -> bool:
	set_tv(not tv_on)
	return tv_on


func update(dt: float, time: float, P: Player) -> void:
	events["drip"] = false
	events["scatter"] = null
	# TV static and the light it throws
	if tv_on and _screen_on != null:
		_roll = fmod(_roll + dt * 22.0, 96.0)
		_screen_on.set_shader_parameter(&"time", time)
		_screen_on.set_shader_parameter(&"roll", _roll)
		if _tv_light != null:
			_tv_light.light_energy = (1.4 + 0.45 * 2.6 + sin(time * 31.0) * 0.15 + (randf() - 0.5) * 0.06) / PI
	# fluorescent tube: mostly on, stutters every few seconds
	var stutter := (0.08 if randf() < 0.5 else 1.0) if (sin(time * 0.7) > 0.93 or sin(time * 1.9 + 1.0) > 0.985) else 1.0
	if kitchen != null:
		kitchen.light_energy = 3.2 * stutter / PI
	if _tube_mat != null:
		_tube_mat.albedo_color = Color.hex(0x3a4a3cff if stutter < 0.5 else 0xd8f0dcff)
	var bz := 0.25 if randf() < 0.012 else 1.0
	if bath != null:
		bath.light_energy = 2.0 * bz * (0.92 + sin(time * 47.0) * 0.04) / PI
	if _bulb_mat != null:
		_bulb_mat.albedo_color = Color.hex(0x5a6048ff if bz < 1.0 else 0xe8f0c8ff)
	if lamp != null:
		lamp.light_energy = (2.4 + sin(time * 2.1) * 0.05) / PI
	# the sign: a buzz, sometimes a dropout
	var nf := (0.1 if randf() < 0.6 else 1.0) if sin(time * 0.43) > 0.96 else 1.0
	if neon != null:
		neon.light_energy = 3.5 * nf / PI
	if _sign_mat != null:
		_sign_mat.albedo_color = Color.WHITE * (0.25 if nf < 1.0 else 1.0)
	if _halo_mat != null:
		_halo_mat.albedo_color.a = 0.35 * nf
	# cigarette: ember breathing, smoke curling up
	if _ember != null:
		_ember_mat.albedo_color = Color(1.0, 0.25 + sin(time * 3.1) * 0.08, 0.05)
		_ember.scale = Vector3.ONE * (0.9 + sin(time * 3.1) * 0.15)
	for p: Dictionary in _puffs:
		p.age = float(p.age) + dt
		if float(p.age) > float(p.life):
			p.age = float(p.age) - float(p.life)
		var k: float = float(p.age) / float(p.life)
		var y := CIG.y + 0.02 + k * 0.7
		var sway := sin(time * 1.3 + k * 7.0) * 0.05 * k
		var n: Node3D = p.n
		n.position = Vector3(CIG.x + 0.03 + sway, y, CIG.z + cos(time * 0.9 + k * 5.0) * 0.04 * k)
		n.scale = Vector3.ONE * (0.03 + k * 0.2)
		var m: BaseMaterial3D = p.m
		if m != null:
			m.albedo_color.a = 0.32 * sin(PI * k) * (1.0 - k * 0.5)
	# the tap drips into the brown water
	_drip_t -= dt
	if _drip_t <= 0.0 and _drop_y < 0.0:
		_drop_y = _wy + 0.11 + SPOUT_Y_ABOVE
		_drip_t = 2.1 + randf() * 1.4
	if _drop != null:
		if _drop_y >= 0.0:
			_drop_y -= dt * 2.2
			_drop.position = Vector3(_spout.x, _drop_y, _spout.z)
			_drop.visible = true
			if _drop_y <= _wy:
				_drop_y = -1.0
				_drop.visible = false
				_ripple_t = 0.0
				events["drip"] = true
		else:
			_drop.visible = false
	_ripple_t += dt
	if _ripple != null:
		_ripple.scale = Vector3.ONE * (1.0 + _ripple_t * 9.0)
		if _ripple_mat != null:
			_ripple_mat.albedo_color.a = maxf(0.0, 0.5 - _ripple_t * 0.6)
	# the city
	for c: Dictionary in _cars:
		var ln: Array = LANES[c.lane]
		c.u = fmod(float(c.u) + dt * float(c.v), 1.0)
		(c.n as Node3D).position = Vector3(float(ln[1]) * (float(c.u) * 360.0 - 180.0), GROUND + 0.6, ln[0])
	var blink := fmod(time, 1.6) < 0.25
	for b: Node3D in _beacons:
		b.visible = blink
	var clk := fmod(time, 1.2) < 0.7
	if _clock != null:
		_clock.visible = clk
	if _vcr != null:
		_vcr.visible = clk
	# roaches
	events["scatter"] = _roach.update(dt, P)
