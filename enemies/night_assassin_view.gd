class_name NightAssassinView
extends CreatureView
## NIGHT ASSASSIN on screen (JS enemies/night-assassin-view.js): the model comes from the exporter (assets/objects/enemy_assassin.glb, tools/export/enemy_assassin.expr.js), these are its poses (driven by the AI state): low ready / run (strafing: hips and legs turn toward the run, the spine twists back so the aimed pistol stays on the player; backpedal when going backwards), aimed pistol with per-shot recoil, knife draw + crouch, lunging dash, tucked backflip and side aerial (the whole body turns round its hips), landing crouch, miss stumble, stagger, falls on its back when killed.

const CH_GLOW := 0
const CH_FLASH := 1
const CH_TRAIL := 2

static var _model: CreatureModel = null

var J := {}
var j_sheath_knife: int
var j_hand_knife: int
var tails: Array = []      # [joint, rest z, x]
var ph := 0.0
var fall_t := 0.0
var _tg := {}


static func get_model() -> CreatureModel:
	if _model == null:
		_model = CreatureModel.build("res://assets/objects/enemy_assassin.glb", _glow, {}, {"assassinLens": 1})
		_model.body_mat.set_shader_parameter(&"flash_tint", Vector3(0.45, 0.42, 0.4))
	return _model


static func _glow(s: RobotGfx.SpriteSoup, m: CreatureModel) -> void:
	for sx: float in [-1.0, 1.0]:
		s.sprite(m.names["nv"], CH_GLOW, Vector3(sx * 0.035, 0.0, 0.09), 1.0)
	s.sprite(m.names["muz"], CH_FLASH, Vector3.ZERO, 1.0)
	s.sprite(m.names["handKnife"], CH_TRAIL, Vector3(0.0, -0.15, 0.0), 0.3)


func _init(p_r: NightAssassin) -> void:
	super._init(p_r, get_model())
	var n: Dictionary = model.names
	J = n
	j_sheath_knife = n["sheathKnife"]
	j_hand_knife = n["handKnife"]
	j_spine = n["spine"]
	j_el_l = n["elL"]
	j_muzzle = n["muz"]
	var i := 0
	for sx: float in [-1.0, 1.0]:
		tails.append([n["tail%d" % i], sx * 0.12, sx * 0.025])
		i += 1
	var d := batch.data
	var o := row * batch.stride
	d[o + 12 + CH_TRAIL] = 1.0
	d[o + 16 + 4 * CH_FLASH] = 1.0      # 0xffe0a0
	d[o + 16 + 4 * CH_FLASH + 1] = 0.74
	d[o + 16 + 4 * CH_FLASH + 2] = 0.35
	_col(d, o + 16 + 4 * CH_TRAIL, 0xd8ffe0)


static func _sat(u: float) -> float:
	return clampf(u, 0.0, 1.0)


func update(dt: float, now: float, _fx: Variant) -> void:
	var A := R as NightAssassin
	var d := batch.data
	var o := row * batch.stride
	var t := now
	var st := A.state
	var dead := st == &"dead"
	var dash := A.atk == &"dash"
	var shot := A.atk == &"shot"
	var D: NightAssassin.Dash = A.dash
	var u := _sat(A.a_u)
	d[o] = A.flash
	# locomotion: the legs run the way he actually moves. Strafing, the hips turn toward the run (up to ~70 degrees) and the spine twists back, so the chest, head and pistol stay on the player while the legs sprint sideways; mostly backwards, he backpedals face-on.
	var spd := Vector2(A.lvx, A.lvz).length()
	var run := _sat(spd / 5.0)
	var m_a := atan2(A.lvx, A.lvz) if spd > 0.4 else 0.0
	var back := 1.0
	if absf(m_a) > 2.0:
		m_a -= signf(m_a) * PI
		back = -1.0
	var loco := not dead and (st == &"idle" or st == &"alert" or st == &"pursue" or st == &"search" or st == &"return")
	var hip_yaw := clampf(m_a, -1.25, 1.25) * _sat(spd / 1.2) if loco else 0.0
	var side := sin(hip_yaw)
	if spd > 0.25:
		ph += dt * (3.2 + spd * 1.45)
	var s := sin(ph)
	var sc := cos(ph)
	var hostile := not dead and st != &"idle" and st != &"return"
	var hips_y := 0.98 - 0.06 * run - 0.04 * absf(sc) * run
	var sp_p := (0.2 * back + 0.05 * absf(side)) * run
	var sp_y := 0.0
	var hd_p := 0.0
	var hip_z := -side * 0.08 * run
	var th_l := 0.8 * run * s * back
	var th_r := -0.8 * run * s * back
	var kn_l := 0.12 + maxf(0.0, -sc) * 1.2 * run
	var kn_r := 0.12 + maxf(0.0, sc) * 1.2 * run
	var th_lz := 0.0
	var th_rz := 0.0
	var sh_lx := -0.6 * run * s * back
	var sh_lz := 0.1
	var el_lx := -0.35 - 0.6 * run
	var sh_rx := -0.45
	var sh_rz := -0.12
	var el_rx := -0.55
	var flip_x := 0.0
	var flip_z := 0.0
	var flip_y := 0.0
	var tuck := 0.0
	# the pistol: aimed whenever he is in the fight, unless he is sprinting straight at / away from you; low ready otherwise
	var aim_y := -A.aim
	if hostile and (spd < 3.6 or absf(hip_yaw) > 0.5 or (shot and (st == &"windup" or st == &"attack"))):
		sh_rx = -1.5 + aim_y
		el_rx = -0.08
		sh_rz = -0.05
		sp_y = -0.18
		hd_p = aim_y * 0.5
	if shot and st == &"windup":
		hips_y -= 0.05 * _ease(u)
	if shot and st == &"attack":
		var k := _sat(A.recoil_t / 0.12)
		sh_rx += 0.32 * k
		el_rx -= 0.25 * k
		hips_y -= 0.05
	if dash and st == &"windup":
		var e := _ease(_sat(u / 0.6))
		if u < 0.45:      # up to the chest sheath
			var rr := _ease(_sat(u / 0.45))
			sh_lx = lerpf(0.0, -0.6, rr)
			sh_lz = lerpf(0.1, -0.3, rr)
			el_lx = lerpf(-0.35, -1.75, rr)
		else:      # knife out, cocked low behind the hip
			var rr := _ease(_sat((u - 0.45) / 0.55))
			sh_lx = lerpf(-0.6, 0.45, rr)
			sh_lz = lerpf(-0.3, 0.25, rr)
			el_lx = lerpf(-1.75, -1.3, rr)
		hips_y = 0.98 - 0.3 * e
		sp_p = 0.45 * e
		th_l = -0.5 * e
		th_r = 0.35 * e
		kn_l = 1.0 * e + 0.1
		kn_r = 1.35 * e + 0.1
		sh_rx = lerpf(sh_rx, 0.35, e)
		el_rx = lerpf(el_rx, -0.9, e)
		sp_y = 0.25 * e
		hd_p = -0.35 * e
	elif dash and st == &"attack" and D != null and D.ph == &"dash":
		var k := sin(t * 24.0)
		hips_y = 0.78
		sp_p = 0.7
		hd_p = -0.55
		sp_y = 0.3
		th_l = -0.9 * k
		th_r = 0.9 * k
		kn_l = 0.4 + maxf(0.0, k) * 1.2
		kn_r = 0.4 + maxf(0.0, -k) * 1.2
		sh_lx = -1.65
		sh_lz = -0.15
		el_lx = -0.05
		sh_rx = 0.7
		el_rx = -0.6
	elif st == &"attack" and A.flip_kind != &"":      # backflip (off the knife hit / backing off) or side aerial (repositioning)
		var f := _sat(A.flip_u)
		var arc := sin(PI * f)
		var sd := 1.0 if A.flip_kind == &"sideL" else (-1.0 if A.flip_kind == &"sideR" else 0.0)
		if sd != 0.0:      # turns over his own forward axis, head first toward where he is going
			flip_z = -sd * 2.0 * PI * _ease(f)
			flip_y = arc * NightAssassin.ASSASSIN_FLIP_HEIGHT * 0.8
			tuck = arc
			th_l = -1.2 * arc
			th_r = th_l
			kn_l = 0.1 + 1.6 * arc
			kn_r = kn_l
			th_lz = 0.45 * arc
			th_rz = -0.45 * arc
			sh_lx = -0.3
			sh_rx = -0.3
			sh_lz = 0.3 + 1.1 * arc
			sh_rz = -0.3 - 1.1 * arc
			el_lx = -0.3
			el_rx = -0.3
			sp_p = 0.15 * arc
			hips_y = 0.98
		else:
			flip_x = -2.0 * PI * _ease(f)
			flip_y = arc * NightAssassin.ASSASSIN_FLIP_HEIGHT
			tuck = arc
			th_l = -1.7 * arc
			th_r = th_l
			kn_l = 0.1 + 2.1 * arc
			kn_r = kn_l
			sh_lx = -0.4 - 0.8 * arc
			sh_rx = -0.4 - 0.8 * arc
			sh_lz = 0.5
			sh_rz = -0.5
			el_lx = -0.6
			el_rx = -0.6
			sp_p = 0.3 * arc
			hips_y = 0.98
	elif A.atk == &"evade" and st == &"recover":      # lands in a crouch, pistol already coming back up
		var e := 1.0 - _ease(u)
		hips_y = 0.98 - 0.26 * e
		th_l = -0.6 * e
		th_r = -0.3 * e
		kn_l = 0.1 + 1.2 * e
		kn_r = kn_l
		sp_p = 0.25 * e
		sh_lz = 0.1 + 0.6 * e
	elif dash and st == &"recover" and D != null and not D.missed:
		var e := 1.0 - _ease(u)
		hips_y = 0.98 - 0.32 * e
		th_l = -0.7 * e
		th_r = -0.4 * e
		kn_l = 0.1 + 1.4 * e
		kn_r = kn_l
		sp_p = 0.3 * e
		sh_lx = -0.6
		sh_lz = 0.5 * e
		el_lx = -0.8
	elif dash and st == &"recover":      # missed: stumbles on, arms out, catching his balance
		var e := 1.0 - _ease(u)
		var w := sin(t * 11.0) * e
		sp_p = 0.6 * e
		hips_y = 0.98 - 0.2 * e
		sh_lx = -0.9 * e
		sh_lz = 0.9 * e + 0.2 * w
		sh_rz = -0.9 * e
		sh_rx = -0.3
		th_l = -0.6 * e
		kn_l = 0.8 * e
		hd_p = 0.2 * w
	if st == &"stagger":
		sp_p = -0.35 + sin(t * 22.0) * 0.04
		hd_p = 0.3
		sh_rx = -0.3
		sh_lx = 0.2
		sh_lz = 0.5
		hips_y = 0.92
	if st == &"idle" or st == &"return":
		hd_p = 0.05 * sin(t * 0.7)
	# dead: drops to the knees, then falls onto his back
	var pose_ := pose
	if dead:
		fall_t += dt
		var e := _ease(_sat(fall_t / 0.9))
		pose_.euler(J["fall"], -1.48 * e, 0.0, 0.0)
		pose_.pos[J["fall"]].y = 0.12 * sin(e * PI) - 0.06 * e
		sh_lz = 1.1
		sh_rz = -1.1
		sh_lx = -0.3
		sh_rx = -0.3
		el_lx = -0.3
		el_rx = -0.3
		th_l = -0.25
		th_r = 0.1
		kn_l = 0.5
		kn_r = 0.2
		hd_p = 0.3
	else:
		fall_t = 0.0
		pose_.euler(J["fall"], 0.0, 0.0, 0.0)
		pose_.pos[J["fall"]].y = 0.0
	# apply (fast poses snap, the rest ease)
	var snap := 30.0 if (dash or A.atk == &"evade") and (st == &"attack" or st == &"windup") else 13.0
	var q_hy := _qq(&"hy", hips_y, snap, dt)
	var q_hip_y := _qq(&"hipY", hip_yaw, 9.0, dt)
	pose_.pos[J["hips"]].y = q_hy
	pose_.euler(J["hips"], 0.0, q_hip_y, _qq(&"hipZ", hip_z, 8.0, dt))
	pose_.euler(J["spine"], _qq(&"sp", sp_p, snap, dt), _qq(&"spY", sp_y, 10.0, dt) - q_hip_y, 0.0)      # the spine undoes the hips' turn
	pose_.euler(J["chest"], 0.0, _qq(&"chY", sp_y * 0.6, 10.0, dt), 0.0)
	pose_.euler(J["head"], _qq(&"hd", hd_p, 10.0, dt), 0.0, 0.0)
	var q_th_l := _qq(&"thL", th_l, snap, dt)
	var q_th_r := _qq(&"thR", th_r, snap, dt)
	var q_kn_l := _qq(&"knL", kn_l, snap, dt)
	var q_kn_r := _qq(&"knR", kn_r, snap, dt)
	pose_.euler(J["thL"], q_th_l, 0.0, _qq(&"thLz", th_lz, snap, dt))
	pose_.euler(J["thR"], q_th_r, 0.0, _qq(&"thRz", th_rz, snap, dt))
	pose_.euler(J["knL"], q_kn_l, 0.0, 0.0)
	pose_.euler(J["knR"], q_kn_r, 0.0, 0.0)
	pose_.euler(J["ankL"], -(q_th_l + q_kn_l) * 0.55 * (1.0 - tuck), 0.0, 0.0)
	pose_.euler(J["ankR"], -(q_th_r + q_kn_r) * 0.55 * (1.0 - tuck), 0.0, 0.0)
	var ra := 40.0 if shot and st == &"attack" else snap
	pose_.euler(J["shL"], _qq(&"shLx", sh_lx, snap, dt), 0.0, _qq(&"shLz", sh_lz, snap, dt))
	pose_.euler(J["shR"], _qq(&"shRx", sh_rx, ra, dt), 0.0, _qq(&"shRz", sh_rz, snap, dt))
	pose_.euler(J["elL"], _qq(&"elLx", el_lx, snap, dt), 0.0, 0.0)
	pose_.euler(J["elR"], _qq(&"elRx", el_rx, ra, dt), 0.0, 0.0)
	pose_.euler(J["flip"], flip_x, 0.0, flip_z)      # the flip is exact (no easing: it must land on its feet)
	pose_.pos[J["flip"]].y = 1.0 + flip_y
	for tl: Array in tails:
		pose_.euler(tl[0], 0.25 + run * 0.6 + sin(t * 7.0 + float(tl[2]) * 40.0) * 0.08 + (0.8 if (dash or A.atk == &"evade") and st == &"attack" else 0.0), 0.0, tl[1])
	# knife: drawn from the sheath at 45 % of the dash windup, sheathed again after the recovery
	var out := not dead and dash and (st == &"attack" or st == &"recover" or (st == &"windup" and u >= 0.45))
	pose_.scl[j_hand_knife] = Vector3.ONE if out else Vector3.ZERO
	pose_.scl[j_sheath_knife] = Vector3.ZERO if out else Vector3.ONE
	d[o + 16 + 4 * CH_TRAIL + 3] = 0.7 if out and dash and st == &"attack" and D != null and D.ph == &"dash" else 0.0
	# goggles: steady green, brighter while aiming, a white-green flare as the knife comes out
	var gl := 0.0 if dead else 0.55 + 0.08 * sin(t * 3.0)
	if not dead and shot and st == &"windup":
		gl = 0.7 + 0.5 * u
	if not dead and dash and st == &"windup":
		gl = 0.8 + 0.9 * u + 0.25 * sin(t * 40.0) * u
	var fl := _sat(gl - 1.0)
	var lk := 0.15 if dead else minf(1.0, 0.6 + gl * 0.4)
	d[o + 4] = (0.42 + 0.58 * fl) * lk
	d[o + 5] = lk
	d[o + 6] = (0.35 + 0.6 * fl) * lk
	d[o + 16 + 4 * CH_GLOW] = 0.42 + 0.58 * fl
	d[o + 16 + 4 * CH_GLOW + 1] = 1.0
	d[o + 16 + 4 * CH_GLOW + 2] = 0.35 + 0.6 * fl
	d[o + 16 + 4 * CH_GLOW + 3] = minf(1.0, gl * 0.85)
	d[o + 12 + CH_GLOW] = 0.12 + 0.12 * gl
	# muzzle flash: a small, quick puff (it is suppressed)
	d[o + 16 + 4 * CH_FLASH + 3] = 0.8 if A.recoil_t > 0.07 else 0.0
	d[o + 12 + CH_FLASH] = 0.12 + randf() * 0.06
	update_bar(dt, 2.15, 0.9)
	if dead and A.dead_t > 12.0:
		set_culled(true)
		return
	pose_.compose(Transform3D(Basis(Vector3.UP, A.yaw), Vector3(A.x, A.y, A.z)))
	upload()
