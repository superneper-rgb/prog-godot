class_name VhSniper
extends RefCounted
## VISITING HOURS: the sniper on Billboard Hill (JS sniper.js, section 6). Nobody we know: a man in a long black hooded coat, sat in the contact's camp chair on the catwalk Prog left. Only the finale shows him: the drag (the ember lights the inside of the hood, never a face), the bolt worked (a hot casing rings on the grating), the cigarette dropped on the grating (it lies there burning until water puts it out), and then he is gone; from the office he is a point of fire 250 m off (flare_from).

const SH := Vector3(0.2, 1.26, 0.1)
const REST_E := Vector3(0.32, 0.96, 0.2)
const REST_H := Vector3(0.3, 0.74, 0.44)
const DRAG_E := Vector3(0.27, 1.1, 0.36)
const DRAG_H := Vector3(0.05, 1.4, 0.3)
const EJ_AT := Vector3(-0.1, 1.3, 0.38)      # the ejection port and the throw, chair-local
const EJ_V := Vector3(-0.75, 1.35, -0.08)

var lv: ExportedLevel
var g: Node3D
var upper: Node3D
var fore: Node3D
var hand: Node3D
var cig: Node3D
var tip: Node3D
var cherry_m: StandardMaterial3D
var halo: MeshInstance3D
var flare: MeshInstance3D
var glow: Light3D
var rim: Light3D
var fill: Light3D
var casing: Node3D
var brass: StandardMaterial3D
var deck := 0.0
var c_t := -1.0
var c_v := Vector3.ZERO
var c_done := false
var c_bounces := 0
var on_clink := Callable()
var drag := 0.0
var drop_t := -1.0
var drop_v := 0.0
var ember := 1.0
var puff_t := 0.0
var muzzle_t := -1.0
var on_deck := false
var t := 0.0
var douse_t := -1.0
var cig_home: Node3D
# smoke (the cigarette's, the suppressor's): each puff its own size and fade (JS one Points draw; here 28 soft cards)
const NS := 28
var s_nodes: Array[MeshInstance3D] = []
var s_pos := PackedVector3Array()
var s_vel := PackedVector3Array()
var s_age := PackedFloat32Array()
var s_life := PackedFloat32Array()
var s_size := PackedFloat32Array()
var s_i := 0
var s_col := MsKit.lin(0x9a9ca4)


func _init(p_lv: ExportedLevel, p_deck: float) -> void:
	lv = p_lv
	deck = p_deck
	g = VhKit.one(lv, "sniper")
	g.visible = false
	upper = VhKit.one(lv, "vh-sn-upper")
	fore = VhKit.one(lv, "vh-sn-fore")
	hand = VhKit.one(lv, "vh-sn-hand")
	cig = VhKit.one(lv, "vh-sn-cig")
	cig_home = cig.get_parent()
	tip = VhKit.one(lv, "vh-sn-tip")
	cherry_m = VhKit.unlit(0xff6a1c)
	for mi in VhKit.meshes(VhKit.one(lv, "vh-sn-cherry")):
		mi.material_override = cherry_m
	for n: Node3D in lv.node_named("vh-sn-halo"):
		n.visible = false
	for n: Node3D in lv.node_named("vh-sn-flare"):
		n.visible = false
	for n: Node3D in lv.node_named("vh-sn-smoke"):
		n.visible = false
	halo = MsKit.sprite8(tip, 0xff7a30, 1.0, 0.035)
	flare = MsKit.sprite8(lv, 0xff6a28, 1.0, 1.0)
	flare.visible = false
	flare.extra_cull_margin = 500.0
	glow = VhKit.light(lv, "vh-sn-glow")
	rim = VhKit.light(lv, "vh-sn-rim")
	fill = VhKit.light(lv, "vh-sn-fill")
	casing = VhKit.one(lv, "vh-sn-casing")
	casing.visible = false
	brass = MsKit.std(0xc8963c, 0.3, 0.85)
	brass.emission_enabled = true
	brass.emission = MsKit.srgb(0xff5a10)
	brass.emission_energy_multiplier = 0.0
	for mi in VhKit.meshes(casing):
		mi.material_override = brass
	_lights(0.0, 0.0, 0.0)
	var pm := ShaderMaterial.new()
	pm.shader = load("res://levels/visiting_hours/vh_puff.gdshader")
	s_pos.resize(NS)
	s_vel.resize(NS)
	s_age.resize(NS)
	s_age.fill(9.0)
	s_life.resize(NS)
	s_life.fill(1.0)
	s_size.resize(NS)
	for _i in NS:
		var mi := MeshInstance3D.new()
		mi.mesh = MsKit.quad()
		mi.material_override = pm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 4.0
		mi.visible = false
		lv.add_child(mi)
		mi.set_instance_shader_parameter(&"col", Vector3(s_col.r, s_col.g, s_col.b))
		s_nodes.append(mi)


func _lights(gl: float, r: float, f: float) -> void:
	if glow != null:
		glow.light_energy = gl / PI
	if rim != null:
		rim.light_energy = r / PI
	if fill != null:
		fill.light_energy = f / PI


## billboard-chair-local -> world (the finale's cameras are placed round him)
func local(x: float, y: float, z: float) -> Vector3:
	return g.global_transform * Vector3(x, y, z)


func show(on: bool) -> void:
	g.visible = on


## the shot's smoke off the suppressor
func muzzle() -> void:
	muzzle_t = 0.0


## where the casing will first hit the grating (the macro shot is set up there before it lands)
func casing_land() -> Vector3:
	var p := local(EJ_AT.x, EJ_AT.y, EJ_AT.z)
	var v := g.global_transform.basis * EJ_V
	var d := p.y - deck - 0.006
	var tt := (v.y + sqrt(v.y * v.y + 2.0 * 9.8 * d)) / 9.8
	var h := Vector3(v.x, 0.0, v.z)
	var o := p + h * tt
	o.y = deck + 0.006
	return o


## the bolt worked: the spent casing leaps out, rings on the grating a few times and lies there smoking; on_clink(vol) fires on each bounce
func eject() -> void:
	casing.global_position = local(EJ_AT.x, EJ_AT.y, EJ_AT.z)
	c_v = g.global_transform.basis * EJ_V
	c_t = 0.0
	c_done = false
	c_bounces = 0
	casing.rotation = Vector3.ZERO
	casing.visible = true


## he opens his fingers: the cigarette falls
func drop() -> void:
	if drop_t >= 0.0:
		return
	drop_t = 0.0
	drop_v = 0.0
	cig.reparent(lv, true)


func cig_at() -> Vector3:
	return tip.global_position


## a drop of water on the cherry: a hiss of steam and it goes out
func douse() -> void:
	if douse_t < 0.0:
		douse_t = 0.0


## the far flare: seen from world point from with a vertical fov of fov_deg, about px pixels wide on an h px tall picture (null: off)
func flare_from(from: Variant, fov_deg: float = 50.0, px: float = 7.0, h: float = 720.0) -> void:
	if from == null:
		flare.visible = false
		return
	var w := tip.global_position
	var d := (from as Vector3).distance_to(w)
	flare.global_position = w
	flare.scale = Vector3.ONE * (maxf(0.03, 2.0 * d * tan(fov_deg * PI / 360.0) * px / h) * (0.7 + 0.5 * minf(1.6, ember)))
	MsKit.opa(flare, minf(1.0, 0.45 + ember * 0.4))
	flare.visible = douse_t < 0.0


func reset() -> void:
	c_t = -1.0
	casing.visible = false
	brass.emission_energy_multiplier = 0.0
	drag = 0.0
	drop_t = -1.0
	on_deck = false
	muzzle_t = -1.0
	douse_t = -1.0
	flare.visible = false
	halo.visible = true
	if cig.get_parent() != cig_home:
		cig.reparent(cig_home, false)
	g.visible = false
	s_age.fill(9.0)
	for mi in s_nodes:
		mi.visible = false
	_lights(0.0, 0.0, 0.0)


func _puff(p: Vector3, size: float, life: float, vy: float, spread: float = 0.05) -> void:
	s_i = (s_i + 1) % NS
	s_pos[s_i] = p
	s_vel[s_i] = Vector3((randf() - 0.5) * spread, vy, (randf() - 0.5) * spread)
	s_age[s_i] = 0.0
	s_life[s_i] = life
	s_size[s_i] = size


func _place(m: Node3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var ln := d.length()
	var xf := g.global_transform * Transform3D(Basis(Quaternion(Vector3.UP, d / ln)).scaled_local(Vector3(1.0, ln, 1.0)), a + d * 0.5)
	m.global_transform = xf


func update(dt: float) -> void:
	t += dt
	if c_t >= 0.0:
		c_t += dt
		brass.emission_energy_multiplier = maxf(0.0, 0.55 - c_t * 0.2)
		if not c_done:
			c_v.y -= 9.8 * dt
			casing.global_position += c_v * dt
			casing.rotation.x += dt * (5.0 if c_bounces > 0 else 16.0)
			casing.rotation.z += dt * (3.0 if c_bounces > 0 else 11.0)
			if casing.global_position.y <= deck + 0.006:
				casing.global_position.y = deck + 0.006
				c_bounces += 1
				if on_clink.is_valid():
					on_clink.call(maxf(0.15, 0.75 - c_bounces * 0.18))
				if c_bounces >= 3 or absf(c_v.y) < 0.7:
					c_done = true
					casing.rotation = Vector3(0.0, casing.rotation.y + 0.6, PI / 2.0)
				else:
					c_v.y = -c_v.y * 0.4
					c_v.x *= 0.45
					c_v.z *= 0.45
		elif c_t < 9.0 and randf() < dt * 7.0:      # (the hot brass smokes in the rain)
			_puff(casing.global_position, 0.025, 1.5, 0.2, 0.015)
	if not g.visible and drop_t < 0.0 and c_t < 0.0:      # (gone: the cigarette still falls, lands, burns)
		return
	var u := clampf(drag, 0.0, 1.0)
	var k := u * u * (3.0 - 2.0 * u)
	var e := REST_E.lerp(DRAG_E, k)
	var h := REST_H.lerp(DRAG_H, k)
	_place(upper, SH, e)
	_place(fore, e, h)
	var hp := h + (h - e).normalized() * 0.07      # (the glove out past the cuff)
	var fb := Basis(Quaternion(Vector3.UP, (h - e).normalized())).scaled_local(Vector3(1.0, 0.8, 1.3))
	hand.global_transform = g.global_transform * Transform3D(fb, hp)
	var fl := maxf(0.0, 1.0 - absf(k - 0.95) / 0.15)      # the drag: the ember burns up at the top
	ember = 0.55 + 0.3 * sin(t * 2.3) * sin(t * 0.7) + fl * 1.4
	if douse_t >= 0.0:      # (the hiss: a burst of steam, then nothing)
		douse_t += dt
		ember *= maxf(0.0, 1.0 - douse_t / 0.45)
		if douse_t < 0.5 and randf() < dt * 30.0:
			_puff(tip.global_position, 0.05, 1.4, 0.35, 0.04)
	if drop_t < 0.0:
		var cb := Basis.from_euler(Vector3(-0.2 - k * 0.9, 0.3, 0.0), EULER_ORDER_XYZ)
		cig.global_transform = g.global_transform * Transform3D(cb, hp + Vector3(0.01, -0.01, 0.03))
	elif not on_deck:
		drop_t += dt
		drop_v -= 9.8 * dt
		cig.global_position.y += drop_v * dt
		cig.rotation.x += dt * 9.0
		cig.rotation.z += dt * 4.0
		if cig.global_position.y <= deck + 0.005:
			cig.global_position.y = deck + 0.005
			if absf(drop_v) > 1.2:
				drop_v = -drop_v * 0.25
			else:
				on_deck = true
				cig.rotation = Vector3(0.0, cig.rotation.y, 0.0)
	var e1 := minf(1.6, ember)
	cherry_m.albedo_color = Color(0.1 + 2.6 * e1, 0.08 + 0.75 * e1, 0.06 + 0.08 * e1)
	halo.visible = douse_t < 0.45
	MsKit.opa(halo, minf(1.0, e1 * 0.9))
	var hs := 0.045 + e1 * 0.025
	var tp_s := tip.global_transform.basis.get_scale().x
	halo.scale = Vector3.ONE * (hs / maxf(tp_s, 0.001))
	if glow != null:
		glow.global_position = tip.global_position
	var gl := (0.22 + ember * 0.35) * (1.0 if douse_t < 0.0 else maxf(0.0, 1.0 - douse_t / 0.4)) * (1.9 * (0.82 + 0.18 * sin(t * 5.1) * sin(t * 1.7 + 1.0)) if on_deck else 1.0) if g.visible or on_deck else 0.0      # (the glow at the ember itself: not inside the sleeve)
	_lights(gl, 1.5 if g.visible else 0.0, 1.4 if g.visible else 0.0)
	# smoke: the cigarette's thread (thicker breathed out after the drag), the suppressor's after the shot
	puff_t -= dt
	if puff_t <= 0.0 and douse_t < 0.0:
		puff_t = 0.22 if on_deck else 0.16
		_puff(tip.global_position, 0.05 + randf() * 0.03, 2.4, 0.22, 0.03)
	if fl > 0.6 and randf() < dt * 8.0:
		_puff(local(0.0, 1.5, 0.25), 0.14, 2.6, 0.3, 0.2)
	if muzzle_t >= 0.0 and muzzle_t < 2.4:
		muzzle_t += dt
		if randf() < dt * 9.0:
			_puff(local(-0.13, 1.28, 1.68), 0.1 + muzzle_t * 0.05, 2.2, 0.18, 0.08)
	for i in NS:
		var mi: MeshInstance3D = s_nodes[i]
		if s_age[i] > s_life[i]:
			mi.visible = false
			continue
		s_age[i] += dt
		var su := s_age[i] / s_life[i]
		var q := s_pos[i] + s_vel[i] * dt
		q.x += sin(t * 0.9 + i) * dt * 0.05
		s_pos[i] = q
		s_size[i] += dt * 0.09
		mi.global_position = q
		mi.scale = Vector3.ONE * (s_size[i] * 0.7)      # (JS gl_PointSize = aS * 700 / distance, at 1080p and the scene's lens)
		mi.set_instance_shader_parameter(&"opacity", 0.32 * sin(PI * minf(1.0, su * 1.2)) * (1.0 - su))
		mi.visible = true
