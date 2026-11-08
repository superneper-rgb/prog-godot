class_name WallWretchView
extends CreatureView
## WALLWRETCH on screen (JS enemies/wall-wretch-view.js): a gaunt, screaming figure with a sculpted skull, a ribbed chest and no arms: tendon bundles fuse its shoulders into the wall. A long fleshy ribbon of a tongue hangs from the mouth; when it attacks it unrolls toward you into a broad spade tip. While it aims, the jaw gapes, the tip glows and a thin drool line shows the aim; when the aim locks the line turns solid red.
## ENGINE DIFFERENCES: the JS rebuilds the tongue's vertices in script every frame; here enemies/wretch_tongue.gdshader computes the same curve on the GPU. Its fixed wall slab (shown only when a wretch is not placed in the Spire's own flesh, which is a dev spawn) is not exported.

const CH_TIP := 0
const TONGUE_SHADER := preload("res://enemies/wretch_tongue.gdshader")
const NT := 30
const RING := 10

static var _model: CreatureModel = null
static var _tongue_mesh: ArrayMesh = null
static var _tongue_mat: ShaderMaterial = null

var phase := randf() * 6.0
var t := 0.0
var age := 0.0
var prev_tg := &"in"
var prev_st: StringName = &""
var has_prev := false
var notice_t := 9.0
var pf := 0.0
var j_torso: int
var j_head: int
var j_jaw: int
var j_mouth: int
var j_tip: int
var j_drips: Array[int] = []
var drip_x: Array[float] = [-0.07, 0.0, 0.07]
var tongue: MeshInstance3D
var aim_line: MeshInstance3D
var sp_rear := AnimKit.Spring.new(160.0, 0.4)
var sp_thrust := AnimKit.Spring.new(260.0, 0.32)
var sp_yank := AnimKit.Spring.new(140.0, 0.45)
var sp_tx := AnimKit.Spring.new(320.0, 0.3)
var sp_tz := AnimKit.Spring.new(320.0, 0.3)
var sp_sag := AnimKit.Spring.new(60.0, 0.7)
var fid: AnimKit.Fidget


static func get_model() -> CreatureModel:
	if _model == null:
		_model = CreatureModel.build("res://assets/objects/enemy_wretch.glb", _glow)
		_model.body_mat.set_shader_parameter(&"flash_tint", Vector3(0.8, 0.3, 0.2))
	return _model


static func _glow(s: RobotGfx.SpriteSoup, m: CreatureModel) -> void:
	s.sprite(m.names["tip"], CH_TIP, Vector3.ZERO, 0.9)


## One ribbon, shared: UV = (position along it 0..1, around it 0..1). The shader bends it.
static func _shared_tongue() -> void:
	if _tongue_mesh != null:
		return
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var ix := PackedInt32Array()
	for i in NT + 1:
		for j in RING + 1:
			v.append(Vector3.ZERO)
			uv.append(Vector2(float(i) / NT, float(j) / RING))
	for i in NT:
		for j in RING:
			var a := i * (RING + 1) + j
			var b := a + RING + 1
			ix.append_array([a, a + 1, b, b, a + 1, b + 1])
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = ix
	_tongue_mesh = ArrayMesh.new()
	_tongue_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_tongue_mat = ShaderMaterial.new()
	_tongue_mat.shader = TONGUE_SHADER
	var tex: Texture2D = get_model().textures.get("fleshTex")
	_tongue_mat.set_shader_parameter(&"skin", tex)


func _init(p_r: WallWretch) -> void:
	super._init(p_r, get_model())
	var n: Dictionary = model.names
	j_torso = n["torso"]
	j_head = n["head"]
	j_jaw = n["jaw"]
	j_mouth = n["mouthPt"]
	j_tip = n["tip"]
	for i in 3:
		j_drips.append(n["drip%d" % i])
	j_spine = j_head
	j_el_l = j_mouth
	j_muzzle = j_mouth
	var d := batch.data
	var o := row * batch.stride
	_col(d, o + 16, 0xff5a8a)
	d[o + 12 + CH_TIP] = 1.0
	fid = AnimKit.Fidget.new([0.5, 0.9, 1.4], 2.5, 6.0, fmod(R.id * 0.47, 1.0))
	_shared_tongue()
	tongue = MeshInstance3D.new()
	tongue.name = "WretchTongue"
	tongue.mesh = _tongue_mesh
	tongue.material_override = _tongue_mat
	tongue.extra_cull_margin = 16384.0
	tongue.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Game.level.add_child(tongue)
	aim_line = FxBeam.tube(0xffb0c8)


func dispose() -> void:
	super.dispose()
	if is_instance_valid(tongue):
		tongue.queue_free()
		aim_line.queue_free()


func set_culled(on: bool) -> void:
	super.set_culled(on)
	if is_instance_valid(tongue):
		tongue.visible = not on
		if on:
			aim_line.visible = false


func update(dt: float, _now: float, fx: Variant) -> void:
	var W := R as WallWretch
	t += dt
	age += dt
	var tt := t + phase
	var st := W.state
	var dead := st == &"dead"
	var root := FleshViews._yaw_root(W.yaw, Vector3(W.x, W.y, W.z))
	var d := batch.data
	var o := row * batch.stride
	d[o] = W.flash                      # (a faint warm self-glow is the material's own emissive, from the export)
	var wind := _n(W.state_t / WallWretch.WIND) if st == &"windup" else 0.0
	var tst := W.tg_st
	var out := tst != &"in"
	var lock := st == &"windup" and W.state_t >= WallWretch.WIND - WallWretch.LOCK
	# poses: the wind-up rears the head back and arches the chest (shudders once the aim locks); the shot thrusts the head forward and recoils; a latch yanks it back as it hauls you in; a severed tongue makes it thrash and shriek; idle, the head jerks and tilts (creepy fidgets); it tears itself forward out of the wall when it spawns, and slumps back into the flesh when it dies.
	var fired := prev_tg == &"in" and tst == &"out"
	var sev := W.sever > 0.0
	if prev_st != st and (prev_st == &"idle" or not has_prev) and (st == &"pursue" or st == &"alert") and age > 0.3:
		notice_t = 0.0
		sp_rear.kick(5.0)
		AnimKit.cue(fx, W, "roar", 0.6)
	has_prev = true
	prev_st = st
	notice_t += dt
	var shriek := sin(notice_t / 0.9 * PI) if notice_t < 0.9 else 0.0
	if fired:
		sp_thrust.kick(9.0 * dt * 60.0)      # (per frame while the tongue flies, see below: scaled so the lunge does not depend on the frame rate)
		AnimKit.cue(fx, W, "whoosh")
	if W.flash > pf + 0.2:                # hit: the head snaps back and twists
		sp_tx.kick(-6.0)
		sp_tz.kick((randf() - 0.5) * 10.0)
		sp_yank.kick(-2.0)
	pf = W.flash
	# (in the JS a stray comment swallows the rest of that line: prevTg stays "in" for good, so "fired" holds the whole time the tongue is out and a latch never kicks. That is the lunge players know, so it stays.)
	fid.step(dt, st != &"windup" and not out and not dead and not sev)
	if fid.which >= 0 and fid.u < dt * 3.0:
		sp_tx.kick((fid.which - 1) * 5.0)
		sp_tz.kick((1.0 if fid.which % 2 == 1 else -1.0) * 6.0)
	var rear := sp_rear.step(0.0 if dead else (AnimKit.in_out_cubic(wind) if st == &"windup" else 0.0) + (0.6 if tst == &"latch" else (0.2 if tst == &"back" else 0.0)), dt)
	var thrust := sp_thrust.step(0.0, dt)
	var yank := sp_yank.step(-1.0 if tst == &"latch" else 0.0, dt)
	var tx0 := sp_tx.step(0.0, dt)
	var tz0 := sp_tz.step(0.0, dt)
	var emerge := 0.0 if dead else 1.0 - AnimKit.out_back(AnimKit.win(age, 0.05, 0.9), 1.6)
	var sink := AnimKit.win(W.dead_t, 0.4, 3.0) if dead else 0.0
	var slump := sp_sag.step(1.0 if dead else 0.0, dt)
	var shake := (0.025 if lock else 0.0) + (0.06 if sev else 0.0)
	var sh := sin(tt * 61.0) * shake if shake != 0.0 else 0.0
	pose.euler(j_jaw, 0.4 + 0.5 * shriek + wind * 0.55 + (0.35 if out else 0.0) + 0.3 * slump + (0.35 + 0.2 * sin(tt * 23.0) if sev else 0.0) + 0.05 * sin(tt * 3.0) - 0.3 * maxf(0.0, -yank) * 0.5, 0.0, 0.0)      # a permanent scream, wider as it aims
	pose.euler(j_torso, sin(tt * 1.3) * 0.02 - rear * 0.12 + thrust * 0.04 + 0.2 * slump, 0.0, cos(tt * 1.1) * 0.015 + sh)
	pose.pos[j_torso] = Vector3(0.0, 0.0, -0.6 * emerge - 0.45 * sink + 0.06 * thrust)
	var breathe := 1.0 + 0.025 * sin(tt * 1.9) * (1.0 - slump)
	pose.scl[j_torso] = Vector3(breathe, 1.0, 1.0 - 0.3 * sink)
	pose.pos[j_head] = Vector3(sh, 2.3 - 0.25 * slump - 0.2 * sink, 0.33 - 0.25 * rear + 0.18 * thrust + 0.15 * yank - 0.8 * emerge - 0.5 * sink)
	pose.euler(j_head, -0.35 * rear + 0.25 * thrust + 0.45 * slump + tx0 * 0.1 + (sin(tt * 30.0) * 0.25 if sev else 0.0) + (sin(tt * 30.0) * 0.2 if st == &"stagger" else 0.0) + sin(tt * 0.9) * 0.02, sin(tt * 17.0) * 0.3 if sev else 0.0, tz0 * 0.12 + 0.25 * slump * sin(phase * 3.0))
	for i in 3:
		var u := fmod(tt * 0.6 + drip_x[i] * 5.0 + 5.0, 1.0)
		pose.pos[j_drips[i]] = Vector3(drip_x[i], -0.2 - u * 0.5, 0.3)
		pose.scl[j_drips[i]] = Vector3(0.02, 0.05, 0.02) if not dead else Vector3.ONE * 0.0001
	pose.compose(root)
	# tongue centre line: outstretched when attacking, otherwise hanging from the mouth
	var m := pose.world[j_mouth].origin
	var s0 := sin(W.yaw)
	var c0 := cos(W.yaw)
	var tp: Vector3
	var sag: float
	var bulge := 0.0
	if out:
		tp = W.tg_at
		sag = minf(1.2, (tp - m).length() * 0.08) * (0.4 if tst == &"latch" else 1.0)
	else:
		var fw := 0.3 + 0.9 * wind
		var dn := 1.8 if dead else 1.5 * (1.0 - 0.9 * wind) + 0.05 * sin(tt * 1.7)
		tp = Vector3(m.x + s0 * fw + c0 * 0.05 * sin(tt * 1.2), m.y - dn, m.z + c0 * fw - s0 * 0.05 * sin(tt * 1.2))
		sag = 0.1 * wind
		bulge = 0.25 * (1.0 - wind)
	tongue.visible = not (dead and W.dead_t > 5.0)
	tongue.set_instance_shader_parameter(&"from_pt", m)
	tongue.set_instance_shader_parameter(&"to_pt", tp)
	tongue.set_instance_shader_parameter(&"side", Vector3(s0, 0.0, c0))
	tongue.set_instance_shader_parameter(&"shape", Vector4(sag, 0.035 if out else 0.006, bulge, tt))
	tongue.set_instance_shader_parameter(&"flash", W.flash)
	pose.pos[j_tip] = root.affine_inverse() * tp
	d[o + 16 + 3] = (1.0 if tst == &"latch" else 0.6) if out else wind
	# the aim line while it winds up (pale = still tracking, red = locked)
	if st == &"windup" and W.has_aim:
		var c := RigidBatch.lin(0xff2a3a if lock else 0xffb0c8)
		aim_line.set_instance_shader_parameter(&"tint", Vector4(c.r, c.g, c.b, 1.0))
		FxBeam.place_tube(aim_line, m, W.aim_pt, 0.025 if lock else 0.012, 0.85 if lock else 0.25 + 0.25 * wind)
	else:
		aim_line.visible = false
	if dead and W.dead_t > 5.0:
		batch.clear_row(row)
		return
	update_bar(dt, 3.3, 0.86 / 0.86, 1.0, true)
	pose.compose(root)
	upload()
