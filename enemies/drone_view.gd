class_name DroneView
extends RefCounted
## Gun Drone on screen, ported from JS class DroneView (index.html) and enhanceDroneView (enemies/robot-visuals.js): sphere chassis with plates, red eye in a bezel, four blade fins, two gun pods,
## belly fans. Provides the same hooks as RobotView (R / T, smoke_t, spark_t, vent_t, spine_world(), el_l_world(), sprite_world(i), muzzle_world()) so FX can smoke, spark and explode it like any robot.

# material rows: the JS materials of DroneView + the palette() of enhanceDroneView
const M_BODY := 0
const M_DARK := 1
const M_FIN := 2
const P_DARK := 3
const P_YELLOW := 4
const P_STEEL := 5
const M_EYE := 6     # colour A of the copy
const P_GLOW := 7    # colour B of the copy

# joints
const J_BODY := 0
const J_FIN0 := 1    # .. J_FIN0 + 3
const J_EYE := 5
const J_FAN0 := 6
const J_FAN1 := 7
const J_RING := 8
const JOINTS := 9

const SPRITE_POS: Array[Vector3] = [Vector3(0.0, 0.02, 0.46), Vector3(0.0, 0.62, 0.0), Vector3(0.0, -0.43, 0.0)]
const MUZZLE := Vector3(0.0, -0.2, 0.58)
const FIN_DEF: Array[Vector3] = [Vector3(0.38, 0.28, -0.9), Vector3(-0.38, 0.28, 0.9), Vector3(0.36, -0.26, PI + 0.9), Vector3(-0.36, -0.26, PI - 0.9)]
const EYE_POS := Vector3(0.0, 0.02, 0.38)
const FAN_POS: Array[Vector3] = [Vector3(-0.25, -0.424, -0.06), Vector3(0.25, -0.424, -0.06)]

const Q_DX := 0
const Q_DY := 1
const Q_DZ := 2
const Q_PX := 3
const Q_PY := 4
const Q_PZ := 5

static var shared_batch: RigidBatch = null

var T: Robot
var R: Drone
var batch: RigidBatch
var row := -1
var q := PackedFloat32Array()
var bar_t := 0.0
var pop := 1.0
var popped := false
var phase := 0.0
var spin := 0.0
var sp := 0.0
var last_state := &"idle"
var last_burst := 0
var flash_t := 0.0
var smoke_t := 0.0
var spark_t := 0.0
var vent_t := 0.0
var body_y := 0.45
var culled := false
var _body_hidden := false
var _fin_rz: Array[float] = [0.0, 0.0, 0.0, 0.0]


static func get_batch() -> RigidBatch:
	if shared_batch == null:
		shared_batch = _build_batch()
	return shared_batch


func _init(p_r: Drone) -> void:
	T = p_r
	R = p_r
	batch = get_batch()
	row = batch.acquire()
	phase = randf() * 6.0
	q.resize(6)
	q.fill(NAN)
	last_state = R.state
	var d := batch.data
	var o := row * batch.stride
	d[o + 1] = 1.0
	d[o + 7] = 1.0                 # the eye's colour is the whole value
	d[o + 14] = 1.0                # belly, muzzle: as built
	d[o + 15] = 1.0
	var eye := RigidBatch.lin(0xff2a24)
	d[o + 16] = eye.r
	d[o + 17] = eye.g
	d[o + 18] = eye.b
	var bc := RigidBatch.lin(0xffcf4a)
	d[o + 20] = bc.r
	d[o + 21] = bc.g
	d[o + 22] = bc.b
	var bl := RigidBatch.lin(0xff6a3a)
	d[o + 24] = bl.r
	d[o + 25] = bl.g
	d[o + 26] = bl.b
	var mz := RigidBatch.lin(0xff5a2a)
	d[o + 28] = mz.r
	d[o + 29] = mz.g
	d[o + 30] = mz.b
	d[o + 32] = bc.r
	d[o + 33] = bc.g
	d[o + 34] = bc.b
	d[o + 43] = -1.0


func dispose() -> void:
	if row < 0:
		return
	batch.release(row)
	row = -1


func spine_world() -> Vector3:
	return batch.slot_point(row, J_BODY, Vector3.ZERO)


func el_l_world() -> Vector3:
	return batch.slot_point(row, J_BODY, Vector3.ZERO)


func sprite_world(i: int) -> Vector3:
	return batch.slot_point(row, J_BODY, SPRITE_POS[i])


func muzzle_world(_kind: String = "") -> Vector3:
	return batch.slot_point(row, J_BODY, MUZZLE)


func set_culled(on: bool) -> void:
	culled = on
	if on:
		_hide_body()


func _hide_body() -> void:
	if _body_hidden:
		return
	_body_hidden = true
	var d := batch.data
	var o := row * batch.stride
	for i in range(o + RigidBatch.PARAMS * 4, o + batch.stride):
		d[i] = 0.0
	d[o + 43] = -1.0


func _c(i: int, target: float, rate: float, dt: float) -> float:
	var v := q[i]
	v = target if is_nan(v) else v + (target - v) * (1.0 - exp(-rate * dt))
	q[i] = v
	return v


func update(dt: float, now: float, fx: Variant) -> void:
	var t := now + phase
	var dead := R.state == &"dead"
	if R.state != last_state:
		if last_state == &"dead":
			popped = false
			pop = 0.0
			spin = 0.0
			q.fill(NAN)
		last_state = R.state
	pop = 0.0 if dead else minf(1.0, pop + dt * 4.0)
	var g_scale := 1.0 if dead else 0.4 + 0.6 * pop
	# ---- pose: tilts into its movement, bobs, spins when staggered / falling ----
	var st := R.state
	var a_u := clampf(R.a_u, 0.0, 1.0)
	var rx := 0.0
	var ry := 0.0
	var rz := 0.0
	if dead:
		if not R.crashed:
			spin += R.spin_v * dt
			rx = 0.4 * sin(spin * 0.7)
			ry = spin
			rz = 0.5
		else:
			rx = _c(Q_DX, 0.35, 8.0, dt)
			ry = spin
			rz = _c(Q_DZ, 0.55, 8.0, dt)
			body_y = _c(Q_DY, 0.3, 8.0, dt)
		if R.crashed and not popped:
			popped = true
			if fx != null:
				fx.robot_pop(self)
	else:
		spin = 0.0
		body_y = 0.45 + sin(t * 2.2) * 0.04
		var spinning := st == &"stagger"
		sp += dt * 16.0 * (1.0 if spinning else 0.0)
		rx = _c(Q_PX, clampf(R.lvz * 0.04, -0.35, 0.35), 8.0, dt) + (-0.12 * R.a_u if st == &"windup" else 0.0)
		ry = sp if spinning else _c(Q_PY, 0.0, 10.0, dt)
		rz = _c(Q_PZ, -clampf(R.lvx * 0.05, -0.35, 0.35), 8.0, dt) + (0.3 if st == &"stagger" else 0.0)
	var k_fin := 0.16 if st == &"windup" or st == &"attack" else 0.05
	for i in 4:
		_fin_rz[i] = FIN_DEF[i].z + sin(t * 9.0 + i * 1.7) * k_fin + (0.5 if dead else 0.0)
	# ---- eye: dim while unaware, bright when hostile, charges through the windup, flares on every shot ----
	if st == &"attack" and R.burst_n != last_burst and R.burst_n > 0:
		flash_t = 1.0
	last_burst = R.burst_n if st == &"attack" else 0
	flash_t = maxf(0.0, flash_t - dt * 7.0)
	var I := 0.45 + 0.1 * sin(t * 2.0)
	if st == &"alert":
		I = 1.15 if sin(t * 30.0) > 0.0 else 0.35
	elif st == &"pursue" or st == &"recover" or st == &"search":
		I = 0.9 + 0.15 * sin(t * 8.0)
	elif st == &"windup":
		var f := 8.0 + 24.0 * a_u
		I = (0.6 + 0.6 * a_u) * (1.0 if sin(t * f * 2.0) > -0.2 else 0.45)
	elif st == &"attack":
		I = 1.2 + flash_t * 0.6
	elif st == &"call":
		I = 1.2 if sin(t * 14.0) > 0.0 else 0.5
	elif st == &"stagger":
		I = 1.1 if sin(t * 83.0) * sin(t * 47.0) > -0.2 else 0.05
	if dead:
		var D := R.dead_t
		if D < 0.15:
			I = 1.6
		elif D < 1.9:
			I = (0.9 if sin(D * 47.0) * sin(D * 19.0) > 0.0 else 0.04) * maxf(0.0, 1.0 - D / 1.9)
		else:
			I = 0.0
	var es := 1.0 + (0.5 * a_u if st == &"windup" else 0.0) + flash_t * 0.4
	# ---- calling reinforcements: amber beacon and an expanding ring ----
	var calling := st == &"call"
	var u := a_u if calling else 0.0
	# ---- the row ----
	var d := batch.data
	var o := row * batch.stride
	d[o] = R.flash
	d[o + 4] = minf(1.0, 0.25 + I * 0.75)                                     # the eye
	d[o + 5] = minf(1.0, 0.04 + flash_t * 0.5 + (a_u * 0.25 if st == &"windup" else 0.0))
	d[o + 6] = 0.04 + flash_t * 0.4
	var gl := RigidBatch.lin(0x17232a) if R.dead else (RigidBatch.lin(0xffad52) if st == &"windup" else RigidBatch.lin(0x75dbe7))     # enhanceDroneView's fan and mast lights
	d[o + 8] = gl.r
	d[o + 9] = gl.g
	d[o + 10] = gl.b
	d[o + 12] = 0.7 + 0.5 * es * I * 0.6                                      # eye glow
	d[o + 13] = 0.5 + 0.35 * sin(t * 16.0)                                    # beacon
	d[o + 19] = minf(0.9, 0.6 * I)
	d[o + 23] = (1.0 if sin(t * 16.0) > 0.0 else 0.35) if calling else 0.0
	d[o + 27] = 0.0 if dead else 0.4 + 0.2 * sin(t * 12.0)                    # belly
	d[o + 31] = 0.0 if dead else flash_t                                      # muzzle
	d[o + 35] = 0.8 * (1.0 - u) if calling else 0.0                           # call ring
	# ---- health bar ----
	if R.flash > 0.5:
		bar_t = 2.5
	elif R.hp < R.max:
		bar_t = maxf(0.0, bar_t - dt * 0.7)
	else:
		bar_t = maxf(0.0, bar_t - dt)
	if not dead and bar_t > 0.0 and R.hp < R.max:
		var f := maxf(0.0, R.hp / R.max)
		var c_b := RobotView.hsl(0.02 + 0.3 * f, 0.85, 0.55)
		d[o + 36] = R.x
		d[o + 37] = R.y + 1.5 * g_scale
		d[o + 38] = R.z
		d[o + 39] = R.yaw
		d[o + 40] = c_b.r
		d[o + 41] = c_b.g
		d[o + 42] = c_b.b
		d[o + 43] = f
		d[o + 3] = g_scale                                                    # (the JS drone's bar keeps the group's scale)
	else:
		d[o + 43] = -1.0
	if R.shattered and dead:
		_hide_body()
		return
	_body_hidden = false
	# ---- the joints ----
	var sn := sin(R.yaw)
	var cs := cos(R.yaw)
	var g_xf := Transform3D(Basis(Vector3(cs * g_scale, 0.0, -sn * g_scale), Vector3(0.0, g_scale, 0.0), Vector3(sn * g_scale, 0.0, cs * g_scale)), Vector3(R.x, R.y, R.z))
	var body := g_xf * Transform3D(Basis.from_euler(Vector3(rx, ry, rz), EULER_ORDER_XYZ), Vector3(0.0, body_y, 0.0))
	batch.set_slot(row, J_BODY, body)
	for i in 4:
		var f := FIN_DEF[i]
		var base := FIN_DEF[i].z
		batch.set_slot(row, J_FIN0 + i, body * Transform3D(Basis(Vector3.BACK, _fin_rz[i]), Vector3(f.x + sin(-base) * 0.2, f.y + cos(base) * 0.2, 0.0)))
	batch.set_slot(row, J_EYE, body * Transform3D(Basis.IDENTITY.scaled(Vector3(es, es, es)), EYE_POS))
	var fan_rot := R.t * (2.0 if R.dead else 34.0)
	batch.set_slot(row, J_FAN0, body * Transform3D(Basis(Vector3.UP, -fan_rot), FAN_POS[0]))
	batch.set_slot(row, J_FAN1, body * Transform3D(Basis(Vector3.UP, fan_rot), FAN_POS[1]))
	if calling:
		var rs := 0.5 + u * 6.0
		batch.set_slot(row, J_RING, g_xf * Transform3D(Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3(rs, rs, rs)), Vector3(0.0, 0.45, 0.0)))
	else:
		batch.hide_slot(row, J_RING)


# ---------------------------------------------------------------- the shared model (JS DroneView constructor + enhanceDroneView)
static func _build_batch() -> RigidBatch:
	var mt := ShaderMaterial.new()
	mt.shader = RigidBatch.MATRIX_SHADER
	var maps := Texture2DArray.new()
	maps.create_from_images([_surface()])
	mt.set_shader_parameter(&"maps", maps)
	var albedo := PackedVector4Array()
	var pbr := PackedVector4Array()
	for i in 24:
		albedo.append(Vector4(1, 1, 1, -1))
		pbr.append(Vector4(1, 0, 0, 0))
	_row(albedo, pbr, M_BODY, 0x667783, 0.0, 0.5, 0.45)
	_row(albedo, pbr, M_DARK, 0x2b2738, -1.0, 0.6, 0.4)
	_row(albedo, pbr, M_FIN, 0xb79b62, 0.0, 0.38, 0.7)
	_row(albedo, pbr, P_DARK, 0x202a31, -1.0, 0.65, 0.6)
	_row(albedo, pbr, P_YELLOW, 0xc39845, 0.0, 0.5, 0.55)
	_row(albedo, pbr, P_STEEL, 0xa8b5bc, -1.0, 0.3, 0.85)
	pbr[M_EYE] = Vector4(1, 0, 1, 0)
	pbr[P_GLOW] = Vector4(1, 0, 2, 0)
	mt.set_shader_parameter(&"mat_albedo", albedo)
	mt.set_shader_parameter(&"mat_pbr", pbr)
	var b := RigidBatch.new(JOINTS, 8)
	b.add_layer(_build_body(), mt, true)
	var glow := ShaderMaterial.new()
	glow.shader = RigidBatch.GLOW_SHADER
	b.add_layer(_build_glow(), glow, false)
	var bar := ShaderMaterial.new()
	bar.shader = RigidBatch.BAR_SHADER
	bar.render_priority = 100
	b.add_layer(RobotGfx.build_bar_mesh(), bar, false)
	return b


static func _row(albedo: PackedVector4Array, pbr: PackedVector4Array, m: int, hex: int, layer: float, rough: float, metal: float) -> void:
	var c := RigidBatch.lin(hex)
	albedo[m] = Vector4(c.r, c.g, c.b, layer)
	pbr[m] = Vector4(rough, metal, 0, 0)


## JS mesh(parent, geometry, material, x, y, z, sx, sy, sz): a palette primitive on a joint. The palette materials are not flat shaded.
static func _pal(o: MeshBuild.Soup, g: MeshBuild.Geo, m: int, slot: int, x: float, y: float, z: float, sx: float, sy: float, sz: float, rx: float = 0.0, ry: float = 0.0, rz: float = 0.0) -> void:
	g.scale(sx, sy, sz)
	g.place(x, y, z, rx, ry, rz)
	o.add(g, slot, m, Color.WHITE, false)


static func _build_body() -> ArrayMesh:
	var o := MeshBuild.Soup.new()
	var add := func(g: MeshBuild.Geo, m: int, slot: int, x: float, y: float, z: float, rx: float = 0.0, ry: float = 0.0, rz: float = 0.0) -> void:
		g.place(x, y, z, rx, ry, rz)
		o.add(g, slot, m)                                  # (flat shaded, as the JS std() materials)
	add.call(MeshBuild.sphere(0.42, 14, 10), M_BODY, J_BODY, 0.0, 0.0, 0.0)
	add.call(MeshBuild.torus(0.425, 0.025, 6, 22), M_DARK, J_BODY, 0.0, 0.0, 0.0, PI * 0.5)
	add.call(MeshBuild.torus(0.17, 0.045, 6, 14), M_DARK, J_BODY, 0.0, 0.02, 0.37)
	add.call(MeshBuild.sphere(0.115, 10, 8), M_EYE, J_EYE, 0.0, 0.0, 0.0)     # scaled in place by its joint
	for i in 4:
		var cone := MeshBuild.cylinder(0.0, 0.085, 0.62, 5)
		cone.scale(1.0, 1.0, 0.55)
		o.add(cone, J_FIN0 + i, M_FIN)
	for s: float in [-1.0, 1.0]:
		add.call(MeshBuild.cylinder(0.035, 0.04, 0.3, 6), M_DARK, J_BODY, s * 0.17, -0.2, 0.36, PI * 0.5)
	# ---- enhanceDroneView ----
	var box := func() -> MeshBuild.Geo: return MeshBuild.box(1.0, 1.0, 1.0)
	var ball := func() -> MeshBuild.Geo: return MeshBuild.sphere(1.0, 10, 7)
	var rod := func() -> MeshBuild.Geo: return MeshBuild.cylinder(1.0, 1.0, 1.0, 7)
	var fan_slot := J_FAN0
	for side_: float in [-1.0, 1.0]:
		_pal(o, box.call(), P_YELLOW, J_BODY, side_ * 0.35, 0.09, -0.06, 0.075, 0.22, 0.32, 0.0, 0.0, side_ * -0.35)
		for i in 4:
			_pal(o, box.call(), P_DARK, J_BODY, side_ * 0.397, 0.04, -0.18 + i * 0.07, 0.025, 0.09, 0.025)
		_pal(o, rod.call(), P_DARK, J_BODY, side_ * 0.25, -0.32, -0.06, 0.13, 0.16, 0.13)
		_pal(o, rod.call(), P_STEEL, J_BODY, side_ * 0.25, -0.405, -0.06, 0.14, 0.025, 0.14)
		for i in 3:
			_pal(o, box.call(), P_STEEL, fan_slot, 0.0, 0.0, 0.0, 0.21, 0.015, 0.025, 0.0, i * PI / 3.0, 0.0)
		fan_slot += 1
		_pal(o, ball.call(), P_GLOW, J_BODY, side_ * 0.25, -0.435, -0.06, 0.07, 0.02, 0.07)
		for p: Vector3 in [Vector3(side_ * 0.39, 0.16, -0.15), Vector3(side_ * 0.39, -0.02, 0.08)]:      # boltBatch
			_pal(o, ball.call(), P_STEEL, J_BODY, p.x, p.y, p.z, 0.018, 0.018, 0.018)
	_pal(o, box.call(), P_DARK, J_BODY, 0.0, 0.37, -0.06, 0.19, 0.07, 0.28)
	for i in 4:
		_pal(o, box.call(), P_STEEL, J_BODY, 0.0, 0.412, -0.16 + i * 0.065, 0.14, 0.012, 0.018)
	_pal(o, rod.call(), P_STEEL, J_BODY, 0.16, 0.43, -0.12, 0.012, 0.22, 0.012)
	_pal(o, ball.call(), P_GLOW, J_BODY, 0.16, 0.55, -0.12, 0.03, 0.03, 0.03)
	var collar := MeshBuild.torus(0.205, 0.022, 7, 24)
	collar.translate(0.0, 0.02, 0.365)
	o.add(collar, J_BODY, P_STEEL, Color.WHITE, false)
	return o.commit()


## The sprites: eye glow (channel 0), beacon (1), belly (2), muzzle (3), and the call ring (channel 4, real geometry).
static func _build_glow() -> ArrayMesh:
	var s := RobotGfx.SpriteSoup.new()
	s.sprite(J_BODY, 0, SPRITE_POS[0], 1.0)
	s.sprite(J_BODY, 1, SPRITE_POS[1], 1.0)
	s.sprite(J_BODY, 2, SPRITE_POS[2], 0.5)
	s.sprite(J_BODY, 3, MUZZLE, 0.5)
	s.solid(MeshBuild.torus(1.0, 0.025, 6, 40), J_RING, 4)
	return s.commit()


## JS surface(): the pale brushed metal of enemies/robot-visuals.js.
static func _surface() -> Image:
	var c := RobotGfx.Canvas.new(256, 51)
	c.clear(0xc2c6c8)
	c.alpha = 0.12
	for i in 2800:
		var v := 150 + int(c.rnd() * 80.0)
		c.style((v << 16) | (v << 8) | v)
		var x := c.rnd() * 256.0
		var y := c.rnd() * 256.0
		c.rect(x, y, 1.0 + c.rnd() * 3.0, 1.0)
	c.alpha = 1.0
	c.style(0x68737b)
	for y: float in [5.0, 126.0, 250.0]:
		c.rect(0.0, y - 1.0, 256.0, 2.0)
	for x: float in [5.0, 250.0]:
		c.rect(x - 1.0, 0.0, 2.0, 256.0)
	for i in 75:
		var light := c.rnd() > 0.5
		c.style(0xdce0df if light else 0x48535a)
		c.alpha = float(0x55 if light else 0x44) / 255.0
		var x := c.rnd() * 256.0
		var y := c.rnd() * 256.0
		var ex := x + 2.0 + c.rnd() * 14.0
		var ey := y + c.rnd() * 2.0
		c.line(x, y, ex, ey, 1.0)
		c.line(x, y + 1.0, ex, ey + 1.0, 1.0)              # (lineWidth stays 2 from the seams above)
	return c.image()
