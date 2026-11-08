class_name FlailView
extends Node3D
## The SCORPION FLAIL's ball and chain in the world (JS weapons/scorpion-flail.js FlailView, flail-impact-fx.js, flail-voice.js): not swinging, a point mass on a rope dragged along the ground; swinging, the ball follows FlailSim's scripted arc.
## The chain is a row of links along a hanging rope between the handle tip and the ball's ring. The slam: a torn ground fire front, rolling dust, white streaks and tumbling fragments, pooled for repeated slams. The head's own cranky voice lives here too.

const TEX_ADD := preload("res://fx/tex_add.gdshader")
const TEX_MIX := preload("res://fx/tex_mix.gdshader")
const GROUND_FIRE := preload("res://fx/flail_ground_fire.gdshader")
const TRAIL := preload("res://fx/flail_trail.gdshader")
const VOICE_LINES: Array = [["pain-1", "pain"], ["pain-2", "pain"], ["pain-3", "pain"], ["pain-4", "pain"], ["pain-5", "pain"], ["teeth", "quip"], ["retired", "quip"], ["shuffleboard", "quip"], ["stick", "quip"], ["pension", "quip"], ["aim", "quip"], ["bill", "quip"], ["mother", "quip"], ["collateral", "collateral"]]
const POINTS := 25

## One pooled impact (JS FlailImpactFX q).
class Impact:
	var t := 9.0
	var s := 1.0
	var radius := 2.8
	var seed_ := 0.0
	var pos := Vector3.ZERO

var fx: FX
var has := false
var p := Vector3.ZERO
var v := Vector3.ZERO
var pos_ := Vector3.ZERO
var q := Quaternion.IDENTITY
var fw := Vector3(0, 0, 1)
var _ball: MeshInstance3D
var _links: FX.InstList
var _pts := PackedVector3Array()
var _cum := PackedFloat32Array()
# impact
var _impacts: Array[Impact] = []
var _serial := 0
var _camera_b := Basis.IDENTITY
var _i_core: FX.InstList
var _i_scorch: FX.InstList
var _i_ring: FX.InstList
var _i_fire: FX.InstList
var _i_dust: FX.InstList
var _i_streak: FX.InstList
var _i_debris: FX.InstList
var _i_live := false
# trail
var _trail: ImmediateMesh
var _trail_mi: MeshInstance3D
var _trail_time := 0.0
var _trail_pts: Array = []       # [Vector3, time]
# voice (JS FlailVoice): one complaint every 4-7 physical strikes; complaints wait for retraction and never stack over one another
var _v_last := {}
var _v_remaining := 0
var _v_pending := false
var _v_pending_kind := "quip"
var _v_quip_t := 0.0
var _v_collateral_t := 0.0
var _v_active: Sfx.SpatialVoice = null
var _v_active_base := 1.0        # the voice's level at 1.0 gain, for the duck
var _v_duck_t := -1.0
var _v_pain: Sfx.SpatialVoice = null


func _init(p_fx: FX) -> void:
	fx = p_fx
	name = "Flail"


func _ready() -> void:
	var lam := StandardMaterial3D.new()
	lam.vertex_color_use_as_albedo = true
	lam.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	lam.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	lam.roughness = 1.0
	_ball = MeshInstance3D.new()
	_ball.mesh = FxMesh.flail_ball()
	_ball.material_override = lam
	_ball.visible = false
	add_child(_ball)
	_links = FX.InstList.new(self, FxMesh.flail_link(fx._c(0x5a5c63)), lam, 56, "flail links")
	_pts.resize(POINTS)
	_cum.resize(POINTS)
	# impact pools, shared by the three pooled impacts
	var floor_plane := PlaneMesh.new()
	floor_plane.size = Vector2.ONE
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	_i_core = FX.InstList.new(self, floor_plane, _tex_mat(TEX_ADD, "flail_flash"), 3, "flail core")
	_i_scorch = FX.InstList.new(self, floor_plane, _tex_mat(TEX_MIX, "flail_scorch"), 3, "flail scorch")
	var ring_mat := ShaderMaterial.new()
	ring_mat.shader = GROUND_FIRE
	_i_ring = FX.InstList.new(self, floor_plane, ring_mat, 3, "flail ground fire", true)
	_i_fire = FX.InstList.new(self, quad, _tex_mat(TEX_ADD, "flail_flame"), 144, "flail flames")
	_i_dust = FX.InstList.new(self, quad, _tex_mat(TEX_MIX, "flail_dust"), 156, "flail dust")
	var add_mat := ShaderMaterial.new()
	add_mat.shader = FX.PLAIN_ADD
	_i_streak = FX.InstList.new(self, box, add_mat, 96, "flail streaks")
	var shard := StandardMaterial3D.new()
	shard.vertex_color_use_as_albedo = true
	shard.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	shard.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	shard.roughness = 1.0
	shard.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_i_debris = FX.InstList.new(self, FxMesh.tetrahedron(1.0), shard, 60, "flail shards")
	for i in 3:
		_impacts.append(Impact.new())
	_trail = ImmediateMesh.new()
	_trail_mi = MeshInstance3D.new()
	_trail_mi.mesh = _trail
	var tm := ShaderMaterial.new()
	tm.shader = TRAIL
	_trail_mi.material_override = tm
	_trail_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_trail_mi.custom_aabb = AABB(Vector3(-20000, -20000, -20000), Vector3(40000, 40000, 40000))
	_trail_mi.visible = false
	add_child(_trail_mi)
	_v_clear()


func _tex_mat(shader: Shader, tex: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter(&"tex", load("res://assets/fx/%s.png" % tex))
	return m


## JS hide()
func hide_view() -> void:
	_ball.visible = false
	_links.finish()
	has = false
	_v_stop()
	_trail_clear()


## JS clear()
func clear() -> void:
	hide_view()
	_v_clear()
	for i: Impact in _impacts:
		i.t = 9.0
	_impact_flush()
	_i_live = false


func _gy_at(W: World, player: Player, x: float, z: float, y: float) -> float:
	return W.ground_height(x, z, 0.25, maxf(y, player.y) + 0.6)        # never look for the floor below the player's own feet level: a ball hung low would find none


## JS update(dt, combat, camera, player, wv, sfx)
func update_view(dt: float, combat: Variant, camera: Camera3D, player: Player, wv: Variant, sfx: Sfx) -> void:
	var F := FlailSim.FLAIL
	var w = combat.weapon
	_impact_update(dt, camera)
	var on: bool = F.on and F.hand_ok and w != null and w.special == "flail" and wv != null and (wv.group as Node3D).visible and not player.dead
	F.hand_ok = false
	if not on:
		if _ball.visible or has:
			hide_view()
		return
	_ball.visible = true
	dt = minf(dt, 0.05)
	var W: World = combat.world
	var s: float = F.s
	var retract := FlailSim.sm((F.elapsed - 0.5) / F.rec)
	var L: float = (F.chain + (0.45 * (1.0 - retract) if (F.st == "impact" or F.st == "rec") else 0.0)) * s
	var R: float = F.ball_r * s
	# Read the final posed tip here so the chain starts exactly at the visible handle.
	var tip: Vector3 = (wv.group as Node3D).global_transform * Vector3(0, 0, 0.24)
	F.hand = tip
	if not has or p.distance_to(tip) > L + 5.0:
		p = tip
		p.y -= L * 0.95
		p.y = maxf(p.y, _gy_at(W, player, p.x, p.z, p.y) + R)
		v = Vector3.ZERO
		has = true
		pos_ = p
	var scripted: bool = F.st != "idle"
	for i in 2:                                      # the dragged ball: gravity, air drag, floor with friction, rope
		var h := dt / 2.0
		v.y -= 24.0 * h
		v *= exp(-0.5 * h)
		if not scripted and p.y < tip.y - 0.1:       # a lazy drift forward until the chain is taut: it lies ahead of him, not at his heel
			var l := Vector2(sin(player.yaw), cos(player.yaw)).length()
			v.x += sin(player.yaw) / l * 5.0 * h
			v.z += cos(player.yaw) / l * 5.0 * h
		p += v * h
		var fl := _gy_at(W, player, p.x, p.z, p.y) + R
		if p.y < fl:
			p.y = fl
			if v.y < 0.0:
				v.y *= -0.22
			if absf(v.y) < 0.8:
				v.y = 0.0
			var f := exp(-6.0 * h)
			v.x *= f
			v.z *= f
		var d := p - tip
		var len_ := d.length()
		if len_ > L:
			d /= len_
			p = tip + d * L
			var vr := v.dot(d)
			if vr > 0.0:
				v -= d * vr
	if scripted:
		pos_ = F.ball
		p = pos_
		v = Vector3.ZERO
	else:
		pos_ = p
		F.ball = pos_
		F.ball_ok = true
	# the ball hangs from its ring: the ring points at the hand; the face looks the way he faces (the way it is flying while swinging)
	var up := (tip - pos_).normalized()
	if not scripted:                                 # lying on the floor the ring tilts toward the hand but stays mostly on top, so the face looks forward, not at the sky
		up *= 0.4
		up.y += 0.6
		up = up.normalized()
	fw = Vector3(F.dx, 0.0, F.dz) if scripted else Vector3(sin(player.yaw), 0.0, cos(player.yaw))
	var za := fw - up * fw.dot(up)
	if za.length_squared() < 1e-4:
		za = Vector3(0, 0, 1)
	za = za.normalized()
	var xa := up.cross(za)
	var qt := Basis(xa, up, za).get_rotation_quaternion()
	q = qt if scripted else q.slerp(qt, 1.0 - exp(-dt * 14.0))
	var ball_s: float = s * F.ball_r / 0.21
	_ball.transform = Transform3D(Basis(q).scaled_local(Vector3(ball_s, ball_s, ball_s)), pos_)
	# chain: a hanging rope (parabola, sag from the slack) between the tip and the ring, clamped above the floor, links laid along it
	var a := pos_ + up * (R * 1.1)
	var dist := a.distance_to(tip)
	var slack := maxf(0.0, L - R * 0.4 - dist)
	var taut := FlailSim.sm((F.elapsed - 0.32) / 0.06) if F.st == "accel" else (1.0 if F.st == "impact" and F.elapsed < F.hit_at else 0.0)
	var sag := minf(1.2, sqrt(3.0 * dist * slack / 8.0)) * (1.0 - taut)
	var curl := minf(0.65 * s, slack * 0.8) * (1.0 - taut)
	var gy := _gy_at(W, player, pos_.x, pos_.z, pos_.y)
	var M := POINTS - 1
	for i in POINTS:
		var t := float(i) / M
		var pt := tip.lerp(a, t)
		pt.y -= sag * 4.0 * t * (1.0 - t)
		pt.x += F.dz * curl * sin(PI * t)
		pt.z -= F.dx * curl * sin(PI * t)
		if t > 0.3:
			pt.y = maxf(pt.y, gy + 0.05 * s)
		_pts[i] = pt
		_cum[i] = _cum[i - 1] + pt.distance_to(_pts[i - 1]) if i > 0 else 0.0
	var total: float = _cum[M]
	var pitch := 0.092 * s
	var N := clampi(roundi(total / pitch), 2, 56)
	var j := 0
	for i in N:
		var dd := (i + 0.5) / N * total
		while j < M - 1 and _cum[j + 1] < dd:
			j += 1
		var seg: float = _cum[j + 1] - _cum[j]
		if seg == 0.0:
			seg = 1.0
		var f := clampf((dd - _cum[j]) / seg, 0.0, 1.0)
		var d3 := (_pts[j + 1] - _pts[j]).normalized()
		var sc := _pts[j].lerp(_pts[j + 1], f)
		var b := Basis(_from_up(d3)) * Basis(Vector3.UP, (i % 2) * PI * 0.5)
		_links.add(Transform3D(b.scaled_local(Vector3(s, s, s)), sc), Color.WHITE)
	_links.finish()
	_trail_update(dt, F, pos_, camera)
	if sfx != null:
		_v_update(dt, F, pos_, sfx)


func _from_up(d: Vector3) -> Quaternion:
	var c := Vector3.UP.dot(d)
	if c < -0.9999:
		return Quaternion(Vector3.RIGHT, PI)
	if c > 0.9999:
		return Quaternion.IDENTITY
	return Quaternion(Vector3.UP, d)


## JS event: swing and impact: sounds, dust, sparks, a ground ring, camera shake, and a kick of the weapon / torso springs.
func event(e: Dictionary, sfx: Sfx, wv: Variant) -> void:
	if str(e.t) == "flail_swing":
		sfx.play("flailWhoosh")
		return
	if str(e.t) != "flail_impact":
		return
	var pp := Vector3(e.x, e.y, e.z)
	var hits: int = e.get("hits", 0)
	sfx.play_at("flailSlam", pp.x, pp.y, pp.z, {"range": 80.0, "k": 1.0 if hits > 0 else 0.8})
	_v_impact(e, sfx)
	_impact_spawn(e)
	fx.light.position = pp + Vector3(0, 0.25, 0)
	fx.light_t = 0.13
	fx.vertical_shake_t = 0.1
	fx.vertical_shake = 0.15 if hits > 0 else 0.12
	if wv != null:
		wv.fire("flail", 1.0)


# ---------------------------------------------------------------- the slam (JS FlailImpactFX) ----------------------------------------------------------------

static func _noise(n: float) -> float:
	var x := sin(n * 127.1 + 311.7) * 43758.5453
	return x - floorf(x)


func _impact_spawn(e: Dictionary) -> void:
	if e.get("ground_y") == null:
		return
	var it: Impact = null
	for i: Impact in _impacts:
		if i.t > 4.0:
			it = i
			break
	if it == null:
		it = _impacts[0]
		for i: Impact in _impacts:
			if i.t > it.t:
				it = i
	it.t = 0.0
	var es: float = e.get("s", 1.0)
	it.s = es if es != 0.0 else 1.0
	var er: float = e.get("radius", 2.25)
	it.radius = (er if er != 0.0 else 2.25) * 1.25
	_serial += 1
	it.seed_ = _serial * 2.39996
	it.pos = Vector3(e.x, e.ground_y, e.z)
	_i_live = true


func _impact_update(dt: float, camera: Camera3D) -> void:
	if not _i_live:
		return
	if camera != null:
		_camera_b = camera.global_transform.basis.orthonormalized()
	var any := false
	for it: Impact in _impacts:
		if it.t > 4.0:
			continue
		it.t += dt
		any = true
		_impact_draw(it)
	_impact_flush()
	_i_live = any


func _impact_flush() -> void:
	_i_core.finish()
	_i_scorch.finish()
	_i_ring.finish()
	_i_fire.finish()
	_i_dust.finish()
	_i_streak.finish()
	_i_debris.finish()


func _floor_xf(it: Impact, y: float, sc: float) -> Transform3D:
	return Transform3D(Basis.from_scale(Vector3(sc, 1.0, sc)), it.pos + Vector3(0, y, 0))


func _impact_draw(it: Impact) -> void:
	var t := it.t
	var s := it.s
	var u := clampf(t / 0.52, 0.0, 1.0)
	var radius := s * (0.30 + it.radius * (1.0 - (1.0 - u) * (1.0 - u)))
	if t < 0.075:
		_i_core.add(_floor_xf(it, 0.045, s * (1.0 + t * 10.0)), Color(1, 1, 1, maxf(0.0, 1.0 - t / 0.075)))
	if t < 0.52:
		_i_ring.add_custom(_floor_xf(it, 0.025, radius * 2.54), Color.WHITE, Color(t, 1.05 * pow(1.0 - u, 0.72), it.seed_, 0.0))
	if t < 4.0:
		_i_scorch.add(_floor_xf(it, 0.018, 2.0 * s), Color(1, 1, 1, 0.48 * (1.0 - clampf((t - 1.5) / 2.5, 0.0, 1.0))))
	var pos := it.pos
	if t < 0.52:
		var fire_col := fx._c(0xffb878)
		for i in 48:
			var a := float(i) / 48.0 * TAU + it.seed_
			var lobe := 1.0 + 0.045 * sin(a * 11.0 + it.seed_) + 0.025 * sin(a * 23.0 - it.seed_)
			var r := radius * lobe * (0.97 + _noise(i + 9.0) * 0.06)
			var size := s * (0.45 + _noise(i + 3.0) * 0.55) * (0.78 + 0.22 * sin(u * PI))
			var fl := sin(t * 32.0 + i * 7.0)
			var flicker := 0.65 + 0.35 * fl * fl
			var b := _camera_b * Basis(Vector3(0, 0, 1), (_noise(i + 201.0) - 0.5) * 0.7)
			_i_fire.add(Transform3D(b.scaled_local(Vector3(size * 1.65, size * 0.66, 1.0)), pos + Vector3(cos(a) * r, size * 0.23 + 0.025 * s, sin(a) * r)), Color(fire_col, pow(1.0 - u, 0.65) * flicker * 0.85))
	if t < 0.95:
		var du := clampf(t / 0.95, 0.0, 1.0)
		var dust_r := radius + s * du * 0.48
		for i in 52:
			var outer := i < 36
			var a := float(i) / (36.0 if outer else 16.0) * TAU + it.seed_ + _noise(i + 40.0) * 0.14
			var r := dust_r * (0.94 + _noise(i + 49.0) * 0.12) if outer else dust_r * sqrt(_noise(i + 71.0)) * 0.74
			var size := s * (0.8 + _noise(i + 60.0) * 0.8) * (0.65 + du * 0.75)
			var lift := 0.23 if outer else 0.43
			var b := _camera_b * Basis(Vector3(0, 0, 1), (_noise(i + 260.0) - 0.5) * 0.55 + t * (_noise(i + 261.0) - 0.5))
			_i_dust.add(Transform3D(b.scaled_local(Vector3(size * 1.45, size * (0.70 if outer else 0.95), 1.0)), pos + Vector3(cos(a) * r, s * (0.13 + sin(du * PI) * lift), sin(a) * r)), Color(1, 1, 1, (0.88 if outer else 0.60) * pow(1.0 - du, 1.15)))
	if t < 0.65:
		var hot_c := fx._c(0xfff5d9) * fx._c(0xfff3c8)
		var cool_c := fx._c(0xff701b) * fx._c(0xfff3c8)
		for i in 32:
			var hot := i < 20
			var life := 0.17 + _noise(i + 81.0) * 0.1 if hot else 0.65
			var fade := maxf(0.0, 1.0 - t / life)
			var a := float(i) / 32.0 * TAU + it.seed_
			var speed := 6.0 + _noise(i + 90.0) * 8.0 if hot else 1.4 + _noise(i + 90.0) * 3.5
			var r := s * (0.15 + speed * t)
			var dir := Vector3(cos(a), 0.12 + _noise(i + 100.0) * 0.4, sin(a)).normalized()
			var side := Vector3.UP.cross(dir).normalized()
			var b := Basis(side, dir.cross(side), dir)
			var sz: float = s * (0.3 + _noise(i + 80.0) * 0.6 if hot else 0.05) * fade
			_i_streak.add(Transform3D(b.scaled_local(Vector3(0.018 * s, 0.018 * s, maxf(sz, 0.0001))), pos + Vector3(cos(a) * r, s * maxf(0.05, 0.1 + dir.y * speed * t - 8.0 * t * t), sin(a) * r)), Color(hot_c if hot else cool_c, fade))
	if t < 1.1:
		var shard_c := fx._c(0x655a48)
		for i in 20:
			var a := float(i) / 20.0 * TAU + _noise(i + 120.0) + it.seed_
			var speed := 1.8 + _noise(i + 130.0) * 3.2
			var vy := 2.2 + _noise(i + 150.0) * 3.4
			var land := vy / 10.0
			var after := maxf(0.0, t - land)
			var travel := minf(t, land) + (1.0 - exp(-after * 6.0)) * 0.22 / 6.0
			var r := s * (0.15 + speed * travel)
			var height := s * (0.04 + maxf(0.0, vy * 0.24 * after - 10.0 * after * after if after > 0.0 else vy * t - 10.0 * t * t))
			var size := s * (0.025 + _noise(i + 170.0) * 0.065)
			var b := Basis.from_euler(Vector3(t * (5.0 + i), t * (9.0 - i), i + t * 6.0), EULER_ORDER_XYZ)
			_i_debris.add(Transform3D(b.scaled_local(Vector3(size, size * 0.7, size * 1.5)), pos + Vector3(cos(a) * r, height, sin(a) * r)), Color(shard_c, 1.0 - clampf((t - 0.7) / 0.4, 0.0, 1.0)))


# ---------------------------------------------------------------- the ribbon behind the head (JS FlailSwingTrail) ----------------------------------------------------------------

func _trail_clear() -> void:
	_trail_pts.clear()
	_trail.clear_surfaces()
	_trail_mi.visible = false


func _trail_update(dt: float, F: FlailSim.State, head: Vector3, camera: Camera3D) -> void:
	_trail_time += dt
	const LIFE := 0.22
	while not _trail_pts.is_empty() and _trail_time - float(_trail_pts[0][1]) > LIFE:
		_trail_pts.pop_front()
	var moving: bool = (F.st == "accel" and F.elapsed > 0.31) or (F.st == "impact" and F.elapsed <= 0.45)
	if moving and dt > 0.0 and (_trail_pts.is_empty() or (_trail_pts[-1][0] as Vector3).distance_squared_to(head) > 0.001):
		_trail_pts.append([head, _trail_time])
		if _trail_pts.size() > 24:
			_trail_pts.pop_front()
	_trail_mi.visible = _trail_pts.size() > 1
	if not _trail_mi.visible:
		return
	_trail.clear_surfaces()
	var eye := camera.global_position
	_trail.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var n := _trail_pts.size()
	for i in n:
		var ap: Vector3 = _trail_pts[i][0]
		var prev: Vector3 = _trail_pts[maxi(0, i - 1)][0]
		var next_: Vector3 = _trail_pts[mini(n - 1, i + 1)][0]
		var side := (eye - ap).cross(next_ - prev).normalized() * (0.18 * F.s)
		var al := maxf(0.0, 1.0 - (_trail_time - float(_trail_pts[i][1])) / LIFE)
		var u := float(i) / 23.0
		_trail.surface_set_color(Color(1, 1, 1, al))
		_trail.surface_set_uv(Vector2(u, 0.0))
		_trail.surface_add_vertex(ap - side)
		_trail.surface_set_color(Color(1, 1, 1, al))
		_trail.surface_set_uv(Vector2(u, 1.0))
		_trail.surface_add_vertex(ap + side)
	_trail.surface_end()


# ---------------------------------------------------------------- the head's voice (JS FlailVoice) ----------------------------------------------------------------

func _v_gap() -> int:
	return 4 + randi() % 4


func _v_clear() -> void:
	_v_stop()
	_v_remaining = _v_gap()
	_v_pending = false
	_v_quip_t = 0.0
	_v_collateral_t = 0.0


func _v_stop() -> void:
	if _v_active != null:
		_v_active.stop_now()
	if _v_pain != null:
		_v_pain.stop_now()
	_v_active = null
	_v_pain = null
	_v_pending = false
	_v_quip_t = 0.0
	_v_pending_kind = "quip"
	_v_duck_t = -1.0


func _v_pick(kind: String, sfx: Sfx) -> AudioStream:
	var available: Array[String] = []
	for line: Array in VOICE_LINES:
		if line[1] == kind and sfx.voice_clip("flailVoice_" + str(line[0])) != null:
			available.append(line[0])
	var pool: Array[String] = []
	for id in available:
		if id != _v_last.get(kind, ""):
			pool.append(id)
	if pool.is_empty():
		pool = available
	if pool.is_empty():
		return null
	var line: String = pool[randi() % pool.size()]
	_v_last[kind] = line
	return sfx.voice_clip("flailVoice_" + line)


func _v_impact(e: Dictionary, sfx: Sfx) -> void:
	if str(e.get("kind", "")) == "air":
		return
	_v_remaining -= 1
	if _v_remaining <= 0:
		_v_pending = true
	# One blast must kill five enemies. A 35% chance and a 15-second cooldown keep the celebration occasional.
	if int(e.get("kills", 0)) >= 5 and _v_collateral_t <= 0.0 and _v_quip_t <= 0.0 and randf() < 0.35 and sfx.voice_clip("flailVoice_collateral") != null:
		_v_pending = true
		_v_pending_kind = "collateral"
	var bark := _v_pick("pain", sfx)
	if bark != null:
		# A quick bark rides above the explosion; an ongoing complaint briefly ducks beneath it.
		if _v_pain != null:
			_v_pain.stop_now()
		_v_pain = sfx.clip_at(bark, e.x, e.y, e.z, {"gain": 0.96, "wet": 0.045, "range": 30.0, "ref": 6.0, "duration": 0.24 if _v_pending else minf(bark.get_length(), 0.50), "fade": 0.055, "voice": true})
		if _v_active != null and _v_active.player.playing:
			_v_duck_t = 0.0


func _v_update(dt: float, F: FlailSim.State, pp: Vector3, sfx: Sfx) -> void:
	_v_quip_t = maxf(0.0, _v_quip_t - dt)
	_v_collateral_t = maxf(0.0, _v_collateral_t - dt)
	if _v_duck_t >= 0.0 and _v_active != null:      # (JS: 0.20 for 0.38 s, back to 0.72 by 0.48 s)
		_v_duck_t += dt
		var g := 0.20 if _v_duck_t < 0.38 else lerpf(0.20, 0.72, clampf((_v_duck_t - 0.38) / 0.1, 0.0, 1.0))
		_v_active.player.volume_db = linear_to_db(maxf(_v_active_base * g, 1e-5))
		if _v_duck_t >= 0.48:
			_v_duck_t = -1.0
	if not _v_pending or _v_quip_t > 0.0 or F.elapsed < 0.67 or F.elapsed > 0.70:
		return
	var kind := _v_pending_kind
	var clip := _v_pick(kind, sfx)
	if clip == null:
		return
	_v_active = sfx.clip_at(clip, pp.x, pp.y, pp.z, {"gain": 0.72, "wet": 0.08, "range": 30.0, "ref": 6.0, "voice": true})
	if _v_active != null:
		_v_active_base = _v_active.level / 0.72
	if kind == "collateral":
		_v_collateral_t = 15.0
	_v_quip_t = clip.get_length() + 0.2
	_v_pending = false
	_v_pending_kind = "quip"
	_v_remaining = _v_gap()
