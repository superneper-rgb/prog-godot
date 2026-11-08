class_name SpireBossView
extends RefCounted
## The Mawmother's pose (JS levels/spire/boss.js visual()): every attack winds up then lunges and settles, purely visual, timed off the fight's clock so telegraphs and hits stay exact. The arms get a target pose from the move timelines; a 2D chain solve puts the tip exactly on a slam mark, a clap line or the floor; springs carry them between poses and the strike frames are driven directly.

const ARM_SEGS := 7

var B: SpireBoss
var L: SpireLevel
var body: Node3D
var neck: Node3D
var head: Node3D
var upper: Node3D
var lower: Node3D
var core: Node3D
var core_m: Array
var skin_m: Array
var dark_m: Array
var boss_m: Array
var sac_m: Array
var eyes: Array[Dictionary] = []
var ribs: Array[Dictionary] = []
var feelers: Array[Dictionary] = []
var mands: Array[Dictionary] = []
var tongue: Array[Node3D] = []
var sacs: Array[Dictionary] = []
var spine: Array[Node3D] = []
var tumours: Array[Node3D] = []
var horns: Array[Node3D] = []
var arms: Array[Dictionary] = []
var spikes: Array[Node3D] = []
var marks: Array[Dictionary] = []
var rings: Array[Node3D] = []
var whirl: Array[Dictionary] = []
var strips: Array[Dictionary] = []
var vortex: Array[Dictionary] = []
var chomp_disc: Node3D
var chomp_m: Array
var cracks: Array[Dictionary] = []
var _crack_i := 0
var stomp := 0.0
var an_lift := 0.0
var jw_x := 0.0
var jw_v := 0.0
var dslap := 0
var used: Array[Dictionary] = []
var sol_th := 0.0
var sol_be := 0.0
var chain_phi := 0.0
var arm_y := 0.0
var look := Vector3.ZERO


func _init(boss: SpireBoss) -> void:
	B = boss
	L = boss.L
	body = L.one("SpbBody")
	neck = L.one("SpbNeck")
	head = L.one("SpbHead")
	upper = L.one("SpbUpper")
	lower = L.one("SpbLower")
	core = L.one("SpbCore")
	for n: Node3D in [body, head, upper, lower]:
		n.rotation_order = EULER_ORDER_XYZ
	core_m = L._mat_list("spbCore")
	skin_m = L._mat_list("spbSkin")
	dark_m = L._mat_list("spbDark")
	boss_m = L._mat_list("spBossFlesh")
	sac_m = L._mat_list("spbSac")
	for i in 5:
		var ball := L.one("SpbEyeBall%d" % i)
		eyes.append({"e": L.one("SpbEye%d" % i), "ball": ball, "iris": L.own_mats(ball, "spbIris"), "pup": L.one("SpbEyePup%d" % i), "lid_u": L.one("SpbEyeLidU%d" % i), "lid_d": L.one("SpbEyeLidD%d" % i), "ph": _hash(i, 23, 6) * 9.0})
	var i := 0
	for sx: float in [-1.0, 1.0]:
		for k in 5:
			var p := L.one("SpbRib%d" % i)
			p.rotation_order = EULER_ORDER_YXZ
			ribs.append({"piv": p, "ph": k * 0.7 + sx, "base": 0.05 + k * 0.03})
			i += 1
	for k in 7:
		var p := L.one("SpbFeeler%d" % k)
		p.rotation_order = EULER_ORDER_XYZ
		feelers.append({"piv": p, "ph": k * 0.9})
	i = 0
	for sx: float in [-1.0, 1.0]:
		var p := L.one("SpbMand%d" % i)
		p.rotation_order = EULER_ORDER_XYZ
		mands.append({"piv": p, "sx": sx})
		i += 1
	for k in 7:
		var j := L.one("SpbTongue%d" % k)
		j.rotation_order = EULER_ORDER_XYZ
		tongue.append(j)
	for k in 7:
		var sc: Vector3 = L.one("SpbSac%d" % k).scale
		sacs.append({"piv": L.one("SpbSacPiv%d" % k), "sac": L.one("SpbSac%d" % k), "emb": L.one("SpbEmb%d" % k), "s": sc.x, "ph": k * 1.7})
		(sacs[k].emb as Node3D).rotation_order = EULER_ORDER_XYZ
	for k in 12:
		spine.append(L.one("SpbSpine%d" % k))
	for k in 2:
		tumours.append(L.one("SpbTumour%d" % k))
	for k in 9:
		var h := L.one("SpbHorn%d" % k)
		h.rotation_order = EULER_ORDER_XYZ
		horns.append(h)
	for k in 6:
		var ang := k * TAU / 6.0 + 0.3
		var segs: Array[Node3D] = []
		for s in ARM_SEGS:
			var j := L.one("SpbArm%d_%d" % [k, s])
			j.rotation_order = EULER_ORDER_XYZ
			segs.append(j)
		arms.append({"arm": L.one("SpbArm%d" % k), "segs": segs, "vx": PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]), "vz": PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]), "init": false, "ph": k * 1.1, "base": ang, "yaw": ang, "w": 0.0, "th": 0.0, "be": 0.0, "yaw_t": ang, "direct": 0.0, "tr": 0.0, "soft": 0.0})
	for k in 4:
		spikes.append(L.one("SpbSpike%d" % k))
		marks.append({"n": L.one("SpbMark%d" % k), "m": L.own_mats(L.one("SpbMark%d" % k))})
	for k in 3:
		rings.append(L.one("SpbRing%d" % k))
		var wb := L.one("SpbWhirl%d" % k)
		wb.rotation_order = EULER_ORDER_YXZ
		whirl.append({"n": wb, "m": L.own_mats(wb)})
		vortex.append({"n": L.one("SpbVortex%d" % k), "m": L.own_mats(L.one("SpbVortex%d" % k))})
	for k in 2:
		var sps: Array[Node3D] = []
		for q in 11:
			sps.append(L.one("SpbStripSp%d_%d" % [k, q]))
		strips.append({"g": L.one("SpbStrip%d" % k), "band": L.one("SpbStripBand%d" % k), "m": L.own_mats(L.one("SpbStripBand%d" % k)), "sps": sps})
	chomp_disc = L.one("SpbChomp")
	chomp_m = L.own_mats(chomp_disc)
	for k in 8:      # the arena floor cracks under every slam and clap
		var c := FxBeam.crack()      # (already under the level)
		c.visible = false
		cracks.append({"n": c, "t": 0.0, "life": 5.0})


## JS enemies/flesh-sculpt.js hash: the same seeded numbers the model was built with
static func _hash(a: int, b: int, c: int) -> float:
	var n := sin(a * 127.1 + b * 311.7 + c * 74.7) * 43758.5453
	return n - floorf(n)


static func _win(t: float, a: float, b: float) -> float:
	return SpireMechs.sstep((t - a) / (b - a))


static func _pulse(t: float, at: float, w: float) -> float:
	var u := clampf(1.0 - absf(t - at) / w, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


static func _hold(t: float, a: float, b: float, up: float, down: float) -> float:
	return SpireMechs.sstep((t - a) / up) * (1.0 - SpireMechs.sstep((t - b) / down))


func crack_place(x: float, y: float, z: float, r: float) -> void:
	var c: Dictionary = cracks[_crack_i]
	_crack_i = (_crack_i + 1) % cracks.size()
	var n: MeshInstance3D = c.n
	n.position = Vector3(x, y + 0.05, z)
	n.scale = Vector3(r, 1.0, r)
	n.rotation.y = randf() * TAU
	n.visible = true
	c.t = 0.0


func _crack_update(dt: float) -> void:
	for c: Dictionary in cracks:
		var n: MeshInstance3D = c.n
		if not n.visible:
			continue
		c.t = float(c.t) + dt
		var u: float = float(c.t) / float(c.life)
		n.visible = u < 1.0
		n.set_instance_shader_parameter(&"opacity", 1.0 - u)


func _emission(list: Array, c: Color, energy: float = -1.0) -> void:
	for m: StandardMaterial3D in list:      # (emission_enabled is set before the material is patched: changing it here would rebuild its shader)
		m.emission = c.linear_to_srgb()
		if energy >= 0.0:
			m.emission_energy_multiplier = energy


func _chain_len(be: float) -> float:
	var x := 0.0
	var y := 0.0
	for s in ARM_SEGS:
		x += 1.5 * sin(s * be)
		y += 1.5 * cos(s * be)
	chain_phi = atan2(x, y)
	return U.hyp(x, y)


## 2D chain solve for an arm (7 joints x 1.5 m): find the uniform bend whose chain length matches the distance to the target, then the root angle that points that chain at it. D = outward distance from the arm root, H = height of the target above it.
func _solve_arm(D: float, H: float) -> void:
	var dist := U.hyp(D, H)
	var psi := atan2(D, H)
	var lo := 0.0
	var hi := 0.5
	if dist >= 10.45:
		sol_th = psi
		sol_be = 0.0
		return
	for _it in 14:
		var m := (lo + hi) * 0.5
		if _chain_len(m) > dist:
			lo = m
		else:
			hi = m
	_chain_len((lo + hi) * 0.5)
	sol_be = (lo + hi) * 0.5
	sol_th = psi - chain_phi


func _want(a: Dictionary, w: float, th: float, be: float, yaw_t: float, direct: float = 0.0, tr: float = 0.0, soft: float = 0.0) -> void:
	if a.is_empty() or w <= float(a.w):
		return
	a.w = w
	a.th = th
	a.be = be
	a.yaw_t = yaw_t
	a.direct = direct
	a.tr = tr
	a.soft = soft


func _near(ang: float, strk: bool, p2: bool) -> Dictionary:
	var best: Dictionary = {}
	var bd := 9.0
	for ai in arms.size():
		var a: Dictionary = arms[ai]
		if used.has(a) or (strk and p2 and ai >= 4):
			continue
		var d := absf(atan2(sin(ang - float(a.base)), cos(ang - float(a.base))))
		if d < bd:
			bd = d
			best = a
	if not best.is_empty():
		used.append(best)
	return best


func _aim(x: float, y: float, z: float) -> float:
	_solve_arm(U.hyp(x, z) - 4.1, y - arm_y)
	return atan2(x, z)


## coil -> strike -> hold -> retract around a hit time at; coil pose (cth, cbe); the strike takes sw s and lands exactly at at
func _strike(a: Dictionary, age: float, at: float, x: float, y: float, z: float, cth: float, cbe: float, sw: float = 0.13, hold_t: float = 0.3, back: float = 0.6) -> void:
	if a.is_empty():
		return
	var ang := _aim(x, y, z)
	var rth := sol_th
	var rbe := sol_be
	if age < at - sw:
		_want(a, _win(age, 0.0, minf(0.4, at - sw)), cth, cbe, ang, 0.0, _win(age, at - sw - 0.4, at - sw))
	elif age < at:
		var u := clampf((age - (at - sw)) / sw, 0.0, 1.0)
		u = u * u * u
		_want(a, 1.0, lerpf(cth, rth, u), lerpf(cbe, rbe, u), ang, 1.0)
	elif age < at + hold_t:
		_want(a, 1.0, rth, rbe + 0.03 * sin((age - at) * 40.0) * (1.0 - (age - at) / hold_t), ang, 1.0)
	else:
		_want(a, 1.0 - _win(age, at + hold_t, at + hold_t + back), rth, rbe, ang)


func visual(dt: float, t: float, P: Player) -> void:
	var tg := B.T
	var root := B.boss_root
	if tg == null or not root.visible:
		return
	var f := tg.flash
	var dyk := clampf(B.dying_t / 4.2, 0.0, 1.0) if B.mode == "dying" else 0.0
	var ph := B.phase
	var exposed := B.exposed
	var ek := 0.12 if exposed else 0.0
	_emission(boss_m, Color(0.06 + f * 0.8 + ek, 0.02 + f * 0.15, 0.05 + f * 0.1))
	var skin_c := Color(0.04 * ph + f * 0.8 + ek, 0.01 + f * 0.25, 0.01 + f * 0.2)      # each phase she bleeds a little more light
	_emission(skin_m, skin_c)
	_emission(dark_m, skin_c)
	var dT := B.dying_t if B.mode == "dying" else 0.0
	var sink_k := _win(dT, 3.0, 4.2)
	var defl := _win(dT, 2.4, 4.2)      # death stages: thrash, arms fall one by one, eyes die, deflate, sink
	root.position.y = B.floor_y() - sink_k * 3.5 + B.lift * 1.3
	root.scale = Vector3(1.0 + defl * 0.1, 1.0 - defl * 0.35, 1.0 + defl * 0.1)
	var mv := B.move_
	var mt := B.mt
	var sdt := minf(dt, 1.0 / 30.0)
	var p2 := ph >= 2
	var p3 := ph >= 3
	# anticipation / strike envelopes per move, on the same clock as the AI's own hit times
	var slam_lead: float = SpireBoss.SLAM_LEAD[ph - 1]
	var clap_lead := SpireBoss.CLAP_LEAD * (0.85 if p3 else 1.0)
	var spit_wind := 0.95 + SpireBoss.TILE_WARN * 0.5
	var spit_gap := SpireBoss.SPIT_GAP * (0.8 if p2 else 1.0) * (0.92 if p3 else 1.0)
	var shock_gap := SpireBoss.SHOCK_GAP * (0.85 if p2 else 1.0) * (0.9 if p3 else 1.0)
	var spit_v := SpireBoss.SPIT_V + (1 if p2 else 0)
	var antic := 0.0
	var thrust := 0.0
	match mv:
		"slam":
			antic = _win(mt, 0.05, slam_lead - 0.15) * (1.0 - _win(mt, slam_lead - 0.15, slam_lead))
			thrust = _pulse(mt, slam_lead + 0.1, 0.35)
		"grasp":
			antic = _win(mt, 0.1, clap_lead - 0.2) * (1.0 - _win(mt, clap_lead - 0.15, clap_lead))
			thrust = _pulse(mt, clap_lead + 0.12, 0.4)
		"shock":
			antic = _win(mt, 0.0, 0.6) * (1.0 - _win(mt, 0.95, 1.15))
			thrust = _pulse(mt, 1.25, 0.3)
		"spit":
			antic = _win(mt, 0.2, spit_wind - 0.1) * (1.0 - _win(mt, spit_wind - 0.1, spit_wind))
		"birth":
			antic = _win(mt, 0.1, 1.3) * (1.0 - _win(mt, 1.3, 1.45))
			thrust = _pulse(mt, 1.55, 0.4)
		"rain", "skyfall":
			antic = _win(mt, 0.0, 0.3) * (1.0 - _win(mt, 0.3, 0.5))
			thrust = _pulse(mt, 0.7, 0.4)
		"whirl":
			antic = _win(mt, 0.0, SpireBoss.WHIRL_WIND - 0.1) * (1.0 - _win(mt, SpireBoss.WHIRL_WIND - 0.1, SpireBoss.WHIRL_WIND + 0.1))
	var roar := sin(PI * clampf(mt / 1.6, 0.0, 1.0)) if mv == "roar" else (B.cine_roar if B.mode == "cine" else 0.0)
	var beat := sin(t * (2.3 + 0.5 * ph)) * 0.012 + B.lift * 0.04
	var bs := Vector3(1.0 + beat + antic * 0.035, 1.0 + beat - antic * 0.06 + thrust * 0.04, 1.0 + beat + antic * 0.035)
	body.position = Vector3(sin(t * 47.0) * f * 0.18, 4.4 - antic * 0.25, sin(t * 39.0) * f * 0.12)
	var body_rz := sin(t * 13.0) * 0.012 if ph >= 3 else 0.0      # phase 3: she trembles constantly
	head.position.y = 10.0 + sin(t * 1.6) * 0.12 + B.raise * 0.5 - antic * 0.3
	var head_rx := -antic * 0.3 + thrust * 0.22 - roar * 0.35 + dyk * 0.55
	var head_rz := sin(t * 31.0) * f * 0.16 + dyk * 0.4 + sin(t * 0.7) * 0.03
	var flare := (ph - 1) * 0.16 + antic * 0.22 + roar * 0.55 + f * 0.15
	for r: Dictionary in ribs:
		var rp: float = r.ph
		(r.piv as Node3D).rotation.x = lerpf(float(r.base) + flare + sin(t * 1.3 + rp) * 0.04, -0.45 + sin(t * 19.0 + rp) * 0.08 * (1.0 - dyk), dyk)
	for fl: Dictionary in feelers:
		var fp: float = fl.ph
		var pv: Node3D = fl.piv
		pv.rotation.x = sin(t * 2.1 + fp) * 0.14 - B.jaw * 0.55 - roar * 0.3 + thrust * 0.25
		pv.rotation.z = sin(t * 1.7 + fp * 1.3) * 0.12 + sin(t * 29.0 + fp) * f * 0.35
	# ---- per-move poses for the anatomy (visual only, keyed off move / mt so gameplay timing is untouched)
	if an_lift - B.lift > 0.015:
		stomp = 1.0
	an_lift = B.lift
	stomp = maxf(0.0, stomp - sdt * 3.0)
	var hb := SpireMechs.beat_at(t, 0.8 if ph >= 3 else (0.95 if ph == 2 else 1.15))
	var spit := mv == "spit"
	var grasp := mv == "grasp"
	var birth := mv == "birth"
	var rain := mv == "rain" or mv == "skyfall"
	bs += Vector3(stomp * 0.05, -stomp * 0.09, stomp * 0.05)      # shock: the stomp squashes her flat for a beat
	body.scale = bs
	var body_ry := B.whirl_u * sin(B.whirl_ang) * 0.25      # whirl: the torso twists with the lashing arms
	var gulp := 0.0
	if spit:      # spit: a swallow bulges the neck before each volley, the head jerks on it
		var k := clampi(roundi((mt - spit_wind) / spit_gap), 0, spit_v - 1)
		var tk := spit_wind + k * spit_gap
		gulp = _win(mt, tk - 0.45, tk - 0.05) * (1.0 - _win(mt, tk, tk + 0.3)) + 0.6 * _pulse(mt, tk + 0.04, 0.1)
	neck.scale = Vector3(1.0 + gulp * 0.2 + hb * 0.03, 1.0, 1.0 + gulp * 0.2 + hb * 0.03)
	head_rx += gulp * 0.12 - (0.45 * minf(1.0, mt * 2.0) if rain else 0.0) + (0.18 if exposed else 0.0)      # rain: she bays at the ceiling
	# attack-specific body language. slam / rain: she rears back, then the head and front arms lunge at the marks. clap: the head snaps forward with the arms. brood: she curls over her belly. shock: the head is thrown back while she rears.
	var slam_p := thrust - antic * 0.6 if (mv == "slam" or rain) else 0.0
	var clap_l := B.slap if grasp else 0.0
	var birth_h := sin(minf(1.0, mt / 1.4) * PI) if birth else 0.0
	var shock_c := B.lift if mv == "shock" else 0.0
	var lunge := thrust * 0.8 + slam_p * 1.1 + clap_l * 0.9 + gulp * 0.4 - antic * 0.5
	var y_s := sin(B.yaw)
	var y_c := cos(B.yaw)
	head.position.x = y_s * (0.4 + lunge * 1.3)
	head.position.z = y_c * (0.4 + lunge * 1.3)
	head_rx += slam_p * 0.25 + clap_l * 0.2 + birth_h * 0.35 - shock_c * 0.2
	head_rz += B.whirl_u * sin(B.whirl_ang * 2.0) * 0.15
	head.rotation = Vector3(head_rx, B.yaw, head_rz)
	body.rotation = Vector3((lunge * 0.06 + birth_h * 0.05) * y_c, body_ry, body_rz - (lunge * 0.06 + birth_h * 0.05) * y_s)
	var spread := clampf(antic * 0.9 + roar + (0.8 - B.slap * 1.6 if grasp else 0.0) + B.jaw * 0.35 + f * 0.3, -0.4, 1.2)
	for md: Dictionary in mands:
		var sx: float = md.sx
		var pv: Node3D = md.piv
		pv.rotation.y = sx * (0.15 + spread * 0.55 + sin(t * 2.6 + sx) * 0.05)
		pv.rotation.x = 0.1 * sin(t * 1.9 + sx * 2.0) + (0.4 if exposed else 0.0) + dyk * 0.7 + sin(t * 33.0 + sx) * f * 0.12
	var out := clampf(maxf(maxf(0.6 if spit else 0.0, roar), maxf(maxf(1.0 if exposed else 0.0, dyk), 0.35 if B.jaw > 0.6 else 0.0)), 0.0, 1.0)
	for s in tongue.size():
		var j := tongue[s]
		var lash := sin(t * 11.0 - s * 0.9) * 0.28 if (spit or roar > 0.0) else sin(t * 2.3 - s * 0.7) * 0.08
		j.rotation.x = lerpf(-0.45, 0.22 if (exposed or dyk > 0.0) else 0.06, out) + lash * (0.4 + out)
		j.rotation.y = sin(t * 1.7 - s * 0.6) * 0.12 * (0.3 + out)
	var swell := (SpireMechs.sstep(mt / 1.4) if mt < 1.4 else maxf(0.0, 1.0 - (mt - 1.4) * 2.0)) if birth else 0.0      # brood: the sacs swell, then empty at the birth
	for i in sacs.size():
		var q: Dictionary = sacs[i]
		(q.piv as Node3D).visible = not (dyk > 0.15 + i * 0.08)      # dying: they burst one by one
		var qp: float = q.ph
		var qs: float = q.s
		var w := 1.0 + hb * 0.06 + swell * 0.35 + sin(t * 17.0 + qp) * f * 0.08
		(q.sac as Node3D).scale = Vector3(qs * w, qs * 1.25 * w, qs * 0.85 * w)
		(q.emb as Node3D).rotation.z = t * 0.7 + qp + sin(t * 3.0 + qp) * 0.4
	_emission(sac_m, Color(0.14 + hb * 0.2 + swell * 0.5 + f * 0.4, 0.03 + swell * 0.08, 0.05))
	for i in spine.size():
		spine[i].rotation.x = sin(t * 2.0 - i * 0.5) * 0.06 + antic * 0.08 + dyk * 0.2
	L._flesh.set_skin(0.95 + 0.3 * (ph - 1) + f * 1.6 + (0.4 if exposed else 0.0), maxf(0.0, (0.5 + 0.25 * (ph - 1)) * (0.4 + hb) + f * 0.8 + swell * 0.3 + (0.3 if exposed else 0.0) - dyk * 0.5))      # the back-lit rim burns hotter each phase and flares on every hit
	var jaw_t := B.jaw + roar * sin(t * 38.0) * 0.06 + gulp * 0.35 - (0.1 if (grasp and B.slap > 0.5) else 0.0)
	jw_v += ((jaw_t - jw_x) * 220.0 - jw_v * 2.0 * sqrt(220.0) * 0.32) * sdt      # under-damped: the jaws clack shut and bounce
	jw_x += jw_v * sdt
	upper.rotation.x = -jw_x * 0.55
	lower.rotation.x = jw_x * 0.38
	var glow := 1.0 if exposed else B.core
	core.scale = Vector3.ONE * (0.8 + glow * 0.45 + sin(t * 9.0) * 0.05 * glow)
	for m: StandardMaterial3D in core_m:
		m.albedo_color = Color(1.0, 0.35 + glow * 0.5, 0.15 + glow * 0.2).linear_to_srgb()
	B.core_glow = glow
	core.visible = glow > 0.02 or B.jaw > 0.3
	# ---- the arms
	var clap := mv == "grasp"
	arm_y = root.position.y + 3.0 * root.scale.y
	var fyv := B.floor_y()
	used.clear()
	for a: Dictionary in arms:
		a.w = 0.0
		a.direct = 0.0
		a.yaw_t = a.base
		a.tr = 0.0
		a.soft = 0.0
	if B.mode == "fight":
		if mv == "slam":
			for m: Dictionary in B.marks:
				var age: float = mt - float(m.t0)
				if age < slam_lead + 1.0:
					_strike(_near(atan2(m.x, m.z), true, p2), age, slam_lead, m.x, m.y, m.z, 0.15, -0.13)
		elif clap:
			for q: Dictionary in B.strips:
				var age: float = mt - float(q.t0)
				for sg: float in [1.0, -1.0]:
					var x := sin(float(q.a)) * 9.0 * sg
					var z := cos(float(q.a)) * 9.0 * sg
					_strike(_near(atan2(x, z), true, p2), age, clap_lead, x, fyv, z, -0.2, -0.06, 0.15, 0.45, 0.5)
		elif mv == "shock":
			var N := SpireBoss.SHOCK_N + (1 if p2 else 0)
			for ai in arms.size():
				var a: Dictionary = arms[ai]
				var base: float = a.base
				if mt < 1.15 - 0.12:
					_want(a, _win(mt, 0.05, 0.6), 0.25, -0.12, base, 0.0, _win(mt, 0.6, 1.0))
					continue
				var k := clampi(roundi((mt - 1.15) / shock_gap), 0, N - 1)
				var tk := 1.15 + k * shock_gap
				if (ai + k) % 2 != 0 and k > 0:      # later rings: alternate arms pound
					k = -1
				var x := sin(base) * 7.2
				var z := cos(base) * 7.2
				if k >= 0:
					_strike(a, mt, tk, x, fyv, z, 0.25, -0.12, 0.12, 0.25, 0.5)
				else:
					_want(a, 0.8, 0.25, -0.12, base)
		elif rain:
			var dur := 5.2 if mv == "rain" else 0.5 + (SpireBoss.SKY_N[ph - 1] - 1) * SpireBoss.SKY_PER[ph - 1] + SpireBoss.SKY_LEAD + 0.9
			for ai in arms.size():
				_want(arms[ai], _win(mt, 0.0, 0.4) * (1.0 - _win(mt, dur - 0.7, dur)), 0.2 + 0.25 * sin(t * 5.0 + ai * 1.7), -0.06 + 0.06 * sin(t * 7.0 + ai), arms[ai].base)
		elif mv == "swallow" and not exposed:      # arms thrown wide while she inhales
			for a: Dictionary in arms:
				_want(a, _win(mt, 0.0, 0.7), 0.95, -0.05, a.base, 0.0, 0.6)
		elif birth:      # she cradles the swelling sacs, then lets go
			for a: Dictionary in arms:
				_want(a, _hold(mt, 0.4, 1.35, 0.4, 0.25), 2.25, 0.32, a.base, 0.0, 0.0, 1.0)
		elif mv == "roar":
			for a: Dictionary in arms:
				_want(a, roar, 0.55, -0.1, a.base, 0.0, roar)
		elif exposed:      # dazed: arms flop onto the floor
			for ai in arms.size():
				var a: Dictionary = arms[ai]
				var base: float = a.base
				var r := 8.5 + (ai % 2) * 2.5
				_aim(sin(base) * r, fyv, cos(base) * r)
				_want(a, 0.95, sol_th, sol_be + 0.03 * sin(t * 1.3 + ai), base, 0.0, 0.0, 1.0)
	elif B.mode == "cine":
		# entrance cutscene: one tendril whips across the floor through the player (sw), then every arm is flung skywards in the scream (cine_roar)
		var rz := B.cine_roar
		if rz > 0.01:
			for ai in arms.size():
				_want(arms[ai], rz, 0.2 + 0.12 * sin(t * 5.0 + ai * 1.7), -0.03 + 0.04 * sin(t * 7.0 + ai), float(arms[ai].base) + 0.25 * sin(ai * 2.1) * rz, 0.0, rz)
		var sw: Variant = (B.cine as Dictionary).get("sw") if B.cine != null else null
		if sw != null:
			var a: Dictionary = arms[sw.arm]
			var age: float = sw.age
			var W := 0.5
			var F := 0.28
			var Hh := 0.2
			if age < W:      # rears back and coils, trembling
				_want(a, _win(age, 0.0, W * 0.9), 0.55, -0.1, sw.a0, 0.0, _win(age, 0.15, W))
			else:
				var u := clampf((age - W) / F, 0.0, 1.0)
				_solve_arm(float(sw.r) - 4.1, float(sw.y) - arm_y)
				if age < W + F + Hh:      # the lash: exact frames, the claw ploughs through him
					_want(a, 1.0, sol_th, sol_be, lerpf(sw.a0, sw.a1, u), 1.0)
				else:      # and drags back
					_want(a, 1.0 - _win(age, W + F + Hh, W + F + Hh + 0.8), sol_th, sol_be, sw.a1)
	elif B.mode == "intro":      # wrapped round her body, then they unfurl (springs overshoot)
		for ai in arms.size():
			_want(arms[ai], 1.0 - _win(B.t_, 0.5 + ai * 0.08, 1.4 + ai * 0.08), 2.5, 0.3, arms[ai].base, 0.0, 0.0, 1.0)
	elif B.mode == "dying":
		for ai in arms.size():
			var a: Dictionary = arms[ai]
			var base: float = a.base
			var tc := 0.9 + ai * 0.22
			if dT < tc - 0.15:      # thrashing
				_want(a, 1.0, 0.35 + 0.5 * sin(t * 9.0 + ai * 1.3), -0.1 + 0.15 * sin(t * 13.0 + ai * 2.0), base, 0.0, 1.0)
			else:
				var r := 7.0 + (ai % 3)
				_strike(a, dT, tc, sin(base) * r, fyv, cos(base) * r, 0.35, -0.1, 0.15, 9.0, 0.5)
			if (dslap & (1 << ai)) == 0 and dT >= tc:
				dslap |= 1 << ai
				L.event({"t": &"wormSlam", "x": sin(base) * 8.0, "y": fyv, "z": cos(base) * 8.0, "r": 1.8})
	if B.mode != "dying":
		dslap = 0
	var wl := B.whirl_u
	for ai in arms.size():
		var a: Dictionary = arms[ai]
		var segs: Array[Node3D] = []
		segs.assign(a.segs)
		var sev := p2 and ai >= 4
		var tearing := sev and mv == "roar" and ph == 2 and mt < 0.6      # phase 2+: two arms have lost their tips (torn off in the phase-2 roar)
		var tip_s := 1.0 - _win(mt, 0.25, 0.5) if tearing else (0.0 if sev else 1.0)
		segs[5].visible = tip_s > 0.01
		segs[5].scale = Vector3.ONE * maxf(0.01, tip_s)
		if tearing and mt - dt < 0.3 and mt >= 0.3:
			var q := segs[5].global_position
			L.event({"t": &"summon", "x": q.x, "y": q.y, "z": q.z})
			L.event({"t": &"boltHit", "x": q.x, "y": q.y, "z": q.z, "kind": "world", "bk": "sauce", "nx": 0.0, "ny": 1.0, "nz": 0.0})
		var a_yaw: float = a.yaw
		var direct: float = a.direct
		a_yaw += atan2(sin(float(a.yaw_t) - a_yaw), cos(float(a.yaw_t) - a_yaw)) * (1.0 - exp(-(30.0 if direct != 0.0 else 7.0) * sdt))
		a.yaw = a_yaw
		var ang := a_yaw
		if wl > 0.0:
			var w0: float = (B.whirl as Dictionary).a0 if B.whirl != null else 0.0
			var tgt := w0 + ai * TAU / 6.0 + B.whirl_ang
			ang = a_yaw + atan2(sin(tgt - a_yaw), cos(tgt - a_yaw)) * wl
		var arm: Node3D = a.arm
		arm.rotation.y = ang
		arm.position = Vector3(sin(ang) * 4.1, 3.0, cos(ang) * 4.1)
		var aw: float = a.w
		var ap: float = a.ph
		var vx: PackedFloat32Array = a.vx
		var vz: PackedFloat32Array = a.vz
		var soft: float = a.soft
		var ath: float = a.th
		var abe: float = a.be
		var atr: float = a.tr
		var raise := B.raise * 0.5 if clap else B.raise
		for s in ARM_SEGS:
			var j := segs[s]
			var idle := 1.15 if s == 0 else 0.2 + sin(t * (1.2 + 0.25 * ph) + ap + s * 0.6) * (0.18 + 0.05 * ph)
			var up := 0.25 if s == 0 else 0.04
			var tx := lerpf(idle, up, raise * (1.0 - aw)) + stomp * (0.55 if s == 0 else -0.06) * (1.0 - aw)
			var tz := sin(t * 0.9 + ap + s * 0.5) * 0.12 * (1.0 - raise) * (1.0 - aw)
			tx = lerpf(tx, ath if s == 0 else abe, aw) + sin(t * 41.0 + s * 1.7 + ai) * 0.035 * atr
			if wl > 0.0:
				tx = lerpf(tx, 1.5 if s == 0 else 0.04, wl)
				tz *= 1.0 - wl
			tz += sin(t * 37.0 + s + ai) * f * 0.1
			if not a.init:
				j.rotation.x = tx
				j.rotation.z = tz
			if direct != 0.0 and aw >= 0.999:      # strike / contact frames: exact
				j.rotation.x = tx
				j.rotation.z = tz
				vx[s] = 0.0
				vz[s] = 0.0
				continue
			var k := (140.0 - s * 14.0) * (0.45 if soft != 0.0 else 1.0)
			var c := 2.0 * sqrt(k) * 0.55      # slightly under-damped: tips overshoot and settle
			vx[s] += ((tx - j.rotation.x) * k - vx[s] * c) * sdt
			vz[s] += ((tz - j.rotation.z) * k - vz[s] * c) * sdt
			j.rotation.x += vx[s] * sdt
			j.rotation.z += vz[s] * sdt
		a.init = true
		# the arena floor is solid for her arms: walking down the chain, any segment that would end below the floor is bent flat onto it instead (the claws at the tip count as part of the last segment). While she sinks into the floor at the end the clamp sinks with her.
		if not (B.mode == "dying" and sink_k > 0.0):
			var fl := fyv + 0.12
			var phi := 0.0
			var yy := arm_y
			for s in ARM_SEGS:
				var j := segs[s]
				var len_ := 2.05 if s == 6 else 1.5
				var prev := phi
				phi += j.rotation.x
				var max_cos := (fl - yy) / len_
				if phi > 0.0 and phi < PI and cos(phi) < max_cos:
					phi = acos(clampf(max_cos, -1.0, 1.0))
					j.rotation.x = phi - prev
					vx[s] = minf(vx[s], 0.0)
				yy += 1.5 * cos(phi)
		a.vx = vx
		a.vz = vz
	# phase 3: the great horn snaps off in the roar and tumbles away; the big shoulder tumour bursts and weeps light
	var hn := horns[1]
	var flying := mv == "roar" and ph == 3 and mt > 0.35 and mt < 1.6
	var hu := mt - 0.35 if flying else 0.0
	hn.visible = not p3 or flying
	hn.position = Vector3(hu * 2.5, hu * 3.0 - 4.5 * hu * hu, -hu * 1.5)
	hn.rotation = Vector3(hu * 3.0, 0.0, -hu * 4.0)
	var burst := (_win(mt, 0.3, 0.5) if (mv == "roar" and ph == 3) else 1.0) if p3 else 0.0
	tumours[0].scale = Vector3(1.0 - 0.35 * burst, 0.85 - 0.4 * burst, 1.1 - 0.3 * burst)
	for m: Dictionary in B.marks:
		if m.hit and not m.cracked and mv == "slam":
			m.cracked = true
			crack_place(m.x, m.y, m.z, 4.0)
	for q: Dictionary in B.strips:
		if q.hit and not q.cracked:
			q.cracked = true
			for sg: float in [-1.0, 1.0]:
				crack_place(sin(float(q.a)) * 9.0 * sg, B.floor_y(), cos(float(q.a)) * 9.0 * sg, 4.5)
	_crack_update(dt)
	if P != null:
		look = Vector3(P.x, P.y + 1.2, P.z)
	for ei in eyes.size():
		var E: Dictionary = eyes[ei]
		var ball: Node3D = E.ball
		if P != null and dyk < 0.5:
			var bp := ball.global_position
			if bp.distance_squared_to(look) > 1e-3:
				ball.look_at(look, Vector3.UP, true)
		var eph: float = E.ph
		var bl := maxf(0.0, 1.0 - absf(fmod(t + eph, 4.5) - 0.12) / 0.12)      # a blink every few seconds
		var squint := clampf(antic * 0.6 + roar * 0.2 + f * 0.8, 0.0, 1.0)
		var wide := clampf(roar + (0.6 if exposed else 0.0), 0.0, 1.0)
		var d_close := 1.0 - (1.0 - _win(dT, 1.9 + ei * 0.22, 2.3 + ei * 0.22) if B.mode == "dying" else 1.0)
		var i_close := 1.0 - _win(B.t_, 0.3 + ei * 0.14, 0.5 + ei * 0.14) if B.mode == "intro" else 0.0
		var close := clampf(maxf(maxf(bl, squint * 0.55), maxf(d_close, i_close)) - wide * 0.3, 0.0, 1.0)
		(E.lid_u as Node3D).rotation.x = lerpf(-1.35, -0.05, close)
		(E.lid_d as Node3D).rotation.x = lerpf(1.25, 0.05, close * 0.8)
		var o_ := 1.0 - _win(dT, 1.9 + ei * 0.22, 2.15 + ei * 0.22) if B.mode == "dying" else 1.0      # dying: they go out one by one; waking: they open one by one
		var open := _win(B.t_, 0.3 + ei * 0.14, 0.45 + ei * 0.14) if B.mode == "intro" else 1.0
		var hot := (0.55 + 0.2 * ph + 0.25 * sin(t * 6.0 + eph)) * o_ * open * (0.4 if (dyk > 0.0 and sin(t * 41.0 + eph * 7.0) > 0.6) else 1.0)
		for m: StandardMaterial3D in E.iris:
			m.albedo_color = Color(hot, hot * 0.25 + f * 0.3, hot * 0.08).linear_to_srgb()
		var dil := clampf(1.0 - antic * 0.6 + wide * 0.6 + (0.8 if exposed else 0.0), 0.3, 2.0)
		(E.pup as Node3D).scale = Vector3(0.35 * dil, 1.25, 0.3)
	if dyk > 0.0:
		core.visible = sin(t * 27.0) + sin(t * 11.3) > 1.4 * dyk - 0.6
	var lead: float = SpireBoss.SLAM_LEAD[B.phase - 1]
	var lock_at := lead * SpireBoss.SLAM_LOCK
	var slam_like := mv == "slam" or mv == "rain"
	for i in 4:
		var sp := spikes[i]
		var mk: Node3D = marks[i].n
		var m: Dictionary = {}
		for k in range(B.marks.size() - 1, -1, -1):
			var q: Dictionary = B.marks[k]
			if int(q.slot) == i and mt - float(q.t0) < 2.6:
				m = q
				break
		if m.is_empty() or not slam_like:
			sp.visible = false
			mk.visible = false
			continue
		var age: float = mt - float(m.t0)
		# while it hunts you the ring breathes softly; once it locks it goes solid and shrinks onto the point of impact (so "it stopped following me, move now" reads at a glance)
		var lk := age >= lock_at and age < lead
		var u := (age - lock_at) / maxf(0.01, lead - lock_at) if lk else 0.0
		mk.visible = age < lead + 0.2
		mk.position = Vector3(m.x, float(m.y) + 0.06, m.z)
		var op := 0.6 + 0.3 * absf(sin(age * 30.0)) if lk else (0.4 + 0.25 * absf(sin(age * 9.0)) if age < lead else 0.5)
		L.set_color(marks[i].m, Color8(0xff, 0xd0, 0x40) if lk else Color8(0xff, 0x2a, 0x3a), op)
		mk.scale = Vector3.ONE * (1.15 if age < lock_at else (1.15 - 0.15 * u if age < lead else 1.1))
		var rise := 0.0 if age < lead else ((age - lead) / 0.12 if age < lead + 0.12 else (1.0 if age < lead + 0.65 else maxf(0.0, 1.0 - (age - lead - 0.65) / 0.4)))
		sp.visible = rise > 0.01
		sp.position = Vector3(m.x, float(m.y) + 3.0 * rise - 3.0, m.z)
		sp.scale = Vector3(1.0, maxf(0.01, rise), 1.0)
	for i in 3:
		var rg := rings[i]
		rg.visible = i < B.rings.size()
		if rg.visible:
			var r: float = B.rings[i].r
			rg.position = Vector3(0.0, B.floor_y() + 0.35, 0.0)
			rg.basis = Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(r, r, 1.0))
	for k in 3:
		var band: Node3D = whirl[k].n
		var w: Variant = B.whirl if mv == "whirl" else null
		band.visible = w != null and k < int(w.n)
		if not band.visible:
			continue
		var a := float(w.a0) + k * TAU / float(w.n) + B.whirl_ang
		var len_ := B.ARENA_R - 4.5
		band.position = Vector3(sin(a) * (4.5 + len_ * 0.5), B.floor_y() + 0.08, cos(a) * (4.5 + len_ * 0.5))
		band.basis = Basis.from_euler(Vector3(-PI * 0.5, a + PI, 0.0), EULER_ORDER_YXZ) * Basis.from_scale(Vector3(1.6, len_, 1.0))
		L.set_alpha(whirl[k].m, 0.15 + 0.35 * absf(sin(mt * 16.0)) if mt < SpireBoss.WHIRL_WIND else 0.45)
	# ---- set-piece fx: HEARTSTORM cells (next beat glows, the erupting half flashes and spikes), SWALLOW vortex + chomp zone
	var fy2 := B.TOP_Y
	var hv := mv == "heart"
	var h_n: int = SpireBoss.HT_BEATS[ph - 1]
	var h_gap: float = SpireBoss.HT_GAP[ph - 1]
	var tele := clampf(1.0 - (SpireBoss.HT_FIRST + B.step * h_gap - mt) / (SpireBoss.HT_FIRST - 0.1 if B.step == 0 else h_gap), 0.0, 1.0) if (hv and B.step < h_n) else 0.0
	for c: Dictionary in B.cells:
		var hot: float = maxf(0.0, float(c.hot) - sdt * 2.0)
		c.hot = hot
		var tl := tele if (tele > 0.0 and B.cell_active(c, B.step)) else 0.0
		var vis := tl > 0.01 or hot > 0.01
		var cm: Node3D = c.mesh
		if cm.visible != vis:
			cm.visible = vis
		if vis:
			cm.position.y = fy2 + 0.3
			L.set_color(c.mats, Color(1.0, 0.42 + hot * 0.5, 0.06 + hot * 0.45).linear_to_srgb(), minf(0.9, 0.12 + 0.5 * tl * (0.7 + 0.3 * sin(t * 22.0)) + 0.8 * hot))
		var rise := clampf(minf((1.0 - hot) / 0.1, hot / 0.45), 0.0, 1.0) if hot > 0.0 else 0.0
		for sp: Node3D in c.sp:
			var on := rise > 0.01
			if sp.visible != on:
				sp.visible = on
			if on:
				sp.position.y = fy2 - 1.7 + 3.4 * rise
	var sw_on := mv == "swallow"
	var sw_t: float = SpireBoss.SW_T[ph - 1] if sw_on else 1.0
	var ramp := SpireMechs.sstep((mt - 0.7) / 1.4) * (1.0 - _win(mt, sw_t, sw_t + 0.3)) if sw_on else 0.0
	for k in 3:
		var v: Node3D = vortex[k].n
		v.visible = ramp > 0.01
		if v.visible:
			var fr := fmod(mt * 0.55 + k / 3.0, 1.0)
			var r := lerpf(B.ARENA_R - 1.5, 5.5, fr)
			v.position = Vector3(0.0, fy2 + 0.35, 0.0)
			v.scale = Vector3(r, 1.0, r)
			L.set_alpha(vortex[k].m, ramp * (1.0 - fr) * 0.6)
	chomp_disc.visible = sw_on and B.warn
	if chomp_disc.visible:
		chomp_disc.position = Vector3(0.0, fy2 + 0.32, 0.0)
		L.set_alpha(chomp_m, 0.26 + 0.3 * absf(sin(mt * 14.0)))
	var slen := B.ARENA_R - 1.2
	for i in 2:
		var vs: Dictionary = strips[i]
		var g: Node3D = vs.g
		var q: Dictionary = B.strips[i] if (mv == "grasp" and i < B.strips.size()) else {}
		g.visible = not q.is_empty()
		if q.is_empty():
			continue
		var age: float = mt - float(q.t0)
		g.position = Vector3(0.0, B.floor_y() + 0.07, 0.0)
		g.rotation.y = q.a
		var band: Node3D = vs.band
		band.basis = Basis(Vector3.RIGHT, -PI * 0.5) * Basis.from_scale(Vector3(SpireBoss.CLAP_W * 2.0, slen * 2.0, 1.0))
		L.set_alpha(vs.m, maxf(0.0, 0.5 - (age - clap_lead) * 0.8) if q.hit else (0.55 + 0.25 * sin(age * 22.0) if q.locked else 0.3 + 0.15 * sin(age * 12.0)))
		var rise := 0.0 if not q.hit else ((age - clap_lead) / 0.14 if age < clap_lead + 0.14 else (1.0 if age < clap_lead + 0.7 else maxf(0.0, 1.0 - (age - clap_lead - 0.7) / 0.4)))
		var sps: Array = vs.sps
		for k in sps.size():
			var sp: Node3D = sps[k]
			sp.visible = rise > 0.01
			sp.position = Vector3(0.0, 2.5 * rise - 2.5, (k - 5) * (slen / 5.2))
			sp.scale = Vector3(1.0, maxf(0.01, rise), 1.0)
