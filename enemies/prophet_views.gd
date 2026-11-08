class_name ProphetViews
extends RefCounted
## FLAYED PROPHET + BROOD on screen (JS enemies/meatball-prophet-view.js): CreatureModels exported from the JS game, the JS views' animation statement for statement.
##   Prophet: a hovering ball of flayed, striated muscle under a torn hood of stitched dead skin. Down its front runs a vertical birth-slit lined with hooked teeth. A cluster of mismatched human eyes sits round the slit, each one looking about on its own, blinking out of step, until it commits to an attack: then every eye snaps onto you at once. A crown of grown rib-bones blooms open when it summons. Two gaunt arms: the right fused into a serrated bone blade, the left an overlong pale hand that wrings the blood globs out of the body.
##   Brood: a skinless lump of meat, a lamprey ring-mouth of hooked teeth, four long human fingers for legs. Before a bite it rears onto its back fingers and the mouth dilates.

const EYES: Array = [[-0.36, 0.36, 0.86], [0.42, 0.3, 0.86], [-0.5, 0.02, 0.86], [0.52, -0.04, 0.85], [-0.24, 0.5, 0.83], [0.24, 0.52, 0.82], [0.0, 0.42, 0.9], [-0.68, 0.08, 0.73], [0.68, 0.05, 0.73], [-0.42, -0.34, 0.84], [0.46, -0.4, 0.79], [0.33, 0.06, 0.94]]
const TATTER_A: Array[float] = [1.7, 2.15, 2.6, 3.05, -2.95, -2.45, -1.95, -1.55]


## JS ProphetView
class ProphetView:
	extends CreatureView
	const CH_THROAT := 0
	const CH_CROWN := 1
	const CH_SAUCE := 2
	const CH_SUMMON := 3
	static var _model: CreatureModel = null
	var phase := randf() * 6.0
	var t := 0.0
	var pop := 1.0
	var last_state: StringName
	var pf := 0.0
	var gone := false
	var puddle_t := 0.0
	var sp_sq := AnimKit.Spring.new(140.0, 0.22)
	var sp_lean := AnimKit.Spring3.new(50.0, 0.3)
	var J: Dictionary
	var eyes: Array = []       # { eye, lid, inv: Quaternion, jx, jy, jt, blink, cur: Quaternion }
	var lips: Array[int] = []
	var tatters: Array = []    # { m, sp, ph, a }
	var ribs: Array = []       # [joint, a]
	var fingers: Array = []    # [f1, f2]
	var cords: Array = []      # { links, ph }
	var j_body: int
	var j_cavity: int
	var j_cleaver: int
	var j_thumb: int
	var j_glob: int
	var puddle: MeshInstance3D

	static func get_model() -> CreatureModel:
		if _model == null:
			_model = CreatureModel.build("res://assets/objects/enemy_prophet.glb", _glow)
			_model.body_mat.set_shader_parameter(&"flash_tint", Vector3(0.8, 0.25, 0.15))
		return _model

	static func _glow(s: RobotGfx.SpriteSoup, m: CreatureModel) -> void:
		s.sprite(m.names["mouth"], CH_THROAT, Vector3(0.0, 0.0, 0.02), 1.0)
		s.sprite(m.names["crown"], CH_CROWN, Vector3(0.0, 0.3, 0.0), 1.0)
		s.sprite(m.names["muzzle"], CH_SAUCE, Vector3.ZERO, 1.0)
		s.sprite(m.names["spine"], CH_SUMMON, Vector3(0.0, -0.1, 0.5), 1.0)

	func _init(p_r: Prophet) -> void:
		super._init(p_r, get_model())
		J = model.names
		j_body = J["hips"]
		j_spine = J["spine"]
		j_el_l = J["elL"]
		j_muzzle = J["muzzle"]
		j_cavity = J["cavity"]
		j_cleaver = J["cleaver"]
		j_thumb = J["thumb"]
		j_glob = J["glob"]
		lips = [J["lip0"], J["lip1"]]
		var rs := RandomNumberGenerator.new()
		rs.seed = R.id + 77
		for i in 12:
			var e: Array = ProphetViews.EYES[i]
			var dv := Vector3(e[0], e[1], e[2]).normalized()
			var qz := Quaternion(Vector3(0.0, 0.0, 1.0), dv)
			eyes.append({"eye": J["eye%d" % i], "lid": J["lid%d" % i], "inv": qz.inverse(), "jx": 0.0, "jy": 0.0, "jt": rs.randf() * 2.0, "blink": AnimKit.Blink.new(1.2, 6.0, 0.12, rs.randf()), "cur": Quaternion.IDENTITY})
		for i in 8:
			tatters.append({"m": J["tat%d" % i], "sp": AnimKit.Spring.new(60.0 + rs.randf() * 30.0, 0.25), "ph": rs.randf() * 6.0, "a": ProphetViews.TATTER_A[i]})
		for i in 7:
			ribs.append([J["rib%d" % i], (float(i) / 7.0) * TAU + 0.2])
		for i in 4:
			fingers.append([J["f1_%d" % i], J["f2_%d" % i]])
		for i in 5:
			var links: Array[int] = []
			for k in 3:
				links.append(J["cord%d_%d" % [i, k]])
			cords.append({"links": links, "ph": rs.randf() * 6.0})
		last_state = R.state
		var d := batch.data
		var o := row * batch.stride
		_col(d, o + 16, 0xff2a10)
		_col(d, o + 20, 0xff3018)
		_col(d, o + 24, 0xff2010)
		_col(d, o + 28, 0xff3a20)
		puddle = FxBeam.puddle(0x4a0406)

	func dispose() -> void:
		super.dispose()
		if is_instance_valid(puddle):
			puddle.queue_free()

	func _on_respawn() -> void:
		puddle.visible = false
		q.clear()
		pop = 0.0
		gone = false

	func sprite_world(i: int) -> Vector3:
		if i == 0:
			return pose.world[J["crown"]] * Vector3(0.0, 0.3, 0.0)
		if i == 1:
			return pose.world[j_spine] * Vector3(0.0, -0.1, 0.5)
		return pose.world[j_spine] * Vector3(0.0, 0.3, -0.4)

	func update(dt: float, _now: float, fx: Variant) -> void:
		var C := R as Prophet
		t += dt
		var tt := t + phase
		if C.state != last_state:
			if C.state == &"dead":
				puddle.visible = false
				gone = false
			elif last_state == &"dead":
				_on_respawn()
			if C.state == &"attack" and C.atk != &"summon":
				AnimKit.cue(fx, C, "whoosh")
			last_state = C.state
		var dead := C.state == &"dead"
		var st := C.state_t
		var boomed := dead and C.boomed
		# ---- placement ----
		pop = 1.0 if dead else minf(1.0, pop + dt * 3.0)
		var pop_s := 1.0 if dead else 0.3 + 0.7 * (1.0 - pow(1.0 - pop, 3.0))
		var root := FleshViews._yaw_root(C.yaw, Vector3(C.x, C.y, C.z))
		# ---- death: swell, veins burning brighter, until the burst; then just a blood puddle ----
		var swell := 1.0
		var flash := C.flash
		var vein_glow := 0.12 + 0.08 * pow(maxf(0.0, sin(tt * 3.1)), 8.0)      # a slow heartbeat in the veins
		if dead and not boomed:
			var u := _n(C.dead_t / maxf(0.2, Prophet.BOOM_DELAY))
			swell = 1.0 + 0.42 * u * u + 0.05 * sin(tt * 40.0) * u
			flash = maxf(flash, 0.3 + 0.4 * sin(tt * (14.0 + u * 30.0)) * u + u * 0.2)
			vein_glow = 0.4 + 2.2 * u
		if boomed:
			if not gone:
				gone = true
				batch.clear_row(row)
				puddle_t = 0.0
			puddle_t += dt
			FxBeam.place_puddle(puddle, Vector3(C.x, C.y + 0.014, C.z), minf(1.9, 0.2 + puddle_t * 5.0), maxf(0.0, 0.9 - (C.dead_t - 14.0) * 0.25) if C.dead_t > 14.0 else 0.9)
			return
		var d := batch.data
		var o := row * batch.stride
		d[o] = flash
		if C.flash > pf + 0.2:      # a hit makes the whole mass quiver
			sp_sq.v -= 3.0
		pf = C.flash
		# ---- locomotion: hover bob, lean into the movement ----
		var fwd := C.lvz
		var lat := C.lvx
		var gaze := clampf(U.wrap_angle(atan2(C.known.x - C.x, C.known.z - C.z) - C.yaw), -0.9, 0.9) if C.known != null else 0.0
		var talking := not dead and C.E != null and C.E.barks != null and C.E.barks.is_talking(C)
		var bob := sin(tt * 1.6) * 0.06 + sin(tt * 2.9) * 0.02
		var hips_y := 1.05 + bob + (0.1 if dead else 0.0)
		var lean := fwd * 0.05
		var lean_z := -lat * 0.06
		var sh_lx := -0.08 + sin(tt * 1.1) * 0.05
		var sh_lz := 0.14 + 0.03 * sin(tt * 0.9)
		var el_lx := -0.25
		var sh_rx := -0.06 + sin(tt * 1.0 + 1.0) * 0.05
		var sh_rz := -0.14
		var el_rx := -0.3
		var cleaver := -1.0 + sin(tt * 1.3) * 0.06
		var curl := 0.4 + 0.15 * sin(tt * 2.3)
		var charge := 0.0
		var summon := 0.0
		var rate := 10.0
		var body_p := 0.0
		var lock := 0.0
		match C.state:
			&"alert":
				var u := _n(st / 0.3)
				sh_lx = -0.9 * u
				sh_rx = -0.6 * u
				sh_rz = -0.5 * u
				sh_lz = 0.5 * u
				hips_y += 0.08 * sin(u * PI)
				rate = 16.0
				lock = 1.0
			&"pursue":
				sh_lx = -0.35
				el_lx = -0.45
				sh_rx = -0.25
				cleaver = -0.8 + sin(tt * 3.5) * 0.12
				sh_rz = -0.24
				rate = 8.0
			&"windup":
				lock = 1.0
				if C.atk == &"summon":      # arms thrown wide, the crown blooms, the slit splits open
					var k := _ease(_n(st / maxf(0.1, Prophet.SUMMON_WIND)))
					summon = k
					sh_lx = -1.2 * k
					sh_rx = -1.2 * k
					sh_lz = 1.1 * k + 0.14 * (1.0 - k)
					sh_rz = -1.1 * k - 0.14 * (1.0 - k)
					el_lx = -0.6 * k
					el_rx = -0.6 * k
					cleaver = -1.6 * k - 1.0 * (1.0 - k)
					curl = 0.9
					hips_y += 0.18 * k
					body_p = 0.2 * k
					rate = 12.0
				else:                        # the pale hand reaches back and wrings a glob out of its own side
					var k := _ease(_n(st / maxf(0.1, Prophet.BLAST_WIND)))
					charge = k
					sh_lx = -1.3 * k - 0.1 * (1.0 - k)
					el_lx = -1.6 * k - 0.3 * (1.0 - k)
					sh_lz = 0.25
					sh_rx = -0.5 * k
					sh_rz = -0.4
					cleaver = -0.9
					curl = 0.9 * k
					body_p = -0.18 * k
					rate = 16.0
			&"attack":
				var u := _n(C.a_u)
				var e := _ease(_n(u / 0.5))
				lock = 1.0
				if C.atk == &"summon":
					summon = 1.0 - u * 0.4
					sh_lx = -1.3
					sh_rx = -1.3
					sh_lz = 1.25
					sh_rz = -1.25
					el_lx = -0.5
					el_rx = -0.5
					cleaver = -1.8
					curl = 1.0
					hips_y += 0.2
					body_p = 0.25
				else:
					charge = 1.2
					sh_lx = lerpf(-1.3, -1.55, e)
					el_lx = lerpf(-1.6, -0.05, e)
					sh_lz = 0.12
					curl = 0.0
					sh_rx = -0.5
					sh_rz = -0.4
					body_p = lerpf(-0.18, 0.2, e)
				rate = 34.0
			&"recover":
				var u := _n(C.a_u)
				var e := _ease(u)
				var sm := C.atk == &"summon"
				charge = maxf(0.0, 0.9 * (1.0 - u))
				summon = maxf(0.0, 1.0 - u) if sm else 0.0
				lock = 1.0 - u
				sh_lx = lerpf(-1.3 if sm else -1.55, -0.15, e)
				el_lx = lerpf(-0.05, -0.35, e)
				sh_rx = lerpf(-1.3 if sm else -0.5, -0.1, e)
				sh_lz = lerpf(1.2 if sm else 0.14, 0.14, e)
				sh_rz = lerpf(-1.2 if sm else -0.14, -0.14, e)
				cleaver = lerpf(-1.8, -1.0, e)
				curl = 0.1 + 0.35 * e
				body_p = lerpf(0.1, 0.0, e)
				rate = 12.0
			&"stagger":
				var u := _n(st / 0.6)
				var env := u / 0.12 if u < 0.12 else 1.0 - (u - 0.12) / 0.88
				var s := sin(C.yaw)
				var c := cos(C.yaw)
				var f := C.hit_x * s + C.hit_z * c
				var l := C.hit_x * c - C.hit_z * s
				lean = f * 0.35 * env
				lean_z = l * 0.3 * env
				hips_y += 0.1 * env
				sh_lx = -0.6 * env
				sh_rx = -0.6 * env
				sh_lz = 0.2 + 0.6 * env
				sh_rz = -0.2 - 0.6 * env
				cleaver = -1.0 + 0.6 * env
				rate = 24.0
			&"dead":
				sh_lx = -0.9
				sh_rx = -0.9
				sh_lz = 1.0
				sh_rz = -1.0
				cleaver = -0.6
				curl = 1.0
				rate = 10.0
				summon = 0.6
		if C.flinch_t > 0.0 and not dead:
			var p := C.flinch_t / 0.2
			var k := p * p
			var s := sin(C.yaw)
			var c := cos(C.yaw)
			lean += (C.hit_x * s + C.hit_z * c) * 0.2 * k
			lean_z += (C.hit_x * c - C.hit_z * s) * 0.15 * k
		if C.fire_t > 0.0 and not dead:
			var k := C.fire_t / 0.25
			sh_lx -= 0.25 * k
			body_p += 0.12 * k
		# ---- apply (eased) ----
		pose.pos[j_body] = Vector3(0.0, _qq(&"hipsY", hips_y, 8.0, dt), 0.0)
		pose.euler(j_body, _qq(&"lean", lean + body_p, 8.0, dt), _qq(&"look", gaze * 0.5, 5.0, dt), _qq(&"leanZ", lean_z, 8.0, dt))
		pose.euler(J["shL"], _qq(&"shLx", sh_lx, rate, dt), _qq(&"shLy", 0.0, rate, dt), _qq(&"shLz", sh_lz, rate, dt))
		pose.euler(J["shR"], _qq(&"shRx", sh_rx, rate, dt), _qq(&"shRy", 0.0, rate, dt), _qq(&"shRz", sh_rz, rate, dt))
		pose.euler(J["elL"], _qq(&"elLx", el_lx, rate, dt), 0.0, 0.0)
		pose.euler(J["elR"], _qq(&"elRx", el_rx, rate, dt), 0.0, 0.0)
		pose.euler(j_cleaver, _qq(&"cleaver", cleaver, rate, dt), 0.0, 0.0)
		var cu := _qq(&"curl", curl, rate, dt)
		for f: Array in fingers:
			pose.euler(f[0], -cu * 0.9, 0.0, 0.0)
			pose.euler(f[1], -cu * 1.2, 0.0, 0.0)
		pose.euler(j_thumb, 0.0, 0.0, 0.6 - cu * 0.4)
		# ---- body: breathing heave, hit quiver, scale pop / death swell ----
		var sq := sp_sq.step(1.0 + 0.025 * sin(tt * 1.4) + 0.06 * summon, dt)
		var ps := pop_s * swell
		pose.scl[j_spine] = Vector3(ps / sqrt(sq), ps * sq, ps / sqrt(sq))
		pose.euler(j_spine, 0.0, sin(tt * 0.5) * 0.06, 0.0)
		d[o + 8] = vein_glow + 0.5 * summon + 0.2 * charge      # JS muscleM glow
		# ---- eyes: each wanders on its own (saccades), blinks out of step; while it commits, every eye locks onto the target and opens wide ----
		lock = _qq(&"lock", lock, 20.0 if lock > 0.5 else 4.0, dt)
		for e: Dictionary in eyes:
			e.jt = float(e.jt) - dt
			if float(e.jt) <= 0.0:
				e.jt = 0.25 + randf() * 1.4
				e.jx = (randf() - 0.5) * 1.6
				e.jy = (randf() - 0.5) * 0.9
			var gx: float = gaze * 0.9 + float(e.jx) * (1.0 - lock)
			var gy: float = -0.22 + float(e.jy) * (1.0 - lock)
			var tv: Vector3 = (e.inv as Quaternion) * Vector3(sin(gx) * cos(gy), sin(gy), cos(gx) * cos(gy))
			if tv.z < 0.55:
				tv.z = 0.55
			tv = tv.normalized()
			var tq := Quaternion(Vector3(0.0, 0.0, 1.0), tv)
			e.cur = (e.cur as Quaternion).slerp(tq, 1.0 - exp(-(30.0 if lock > 0.5 else 18.0) * dt))
			pose.rot[e.eye] = Basis(e.cur as Quaternion)
			var bl: float = 1.0 if dead else (e.blink as AnimKit.Blink).step(dt) * (1.0 - lock)
			pose.euler(e.lid, lerpf(-0.55 - 0.4 * lock, 1.65, bl), 0.0, 0.0)
		# ---- the slit: parts while it preaches, gapes when it spits or births ----
		var open := 0.3 + 0.5 * absf(sin(tt * 9.0)) if talking else 0.06 + 0.04 * sin(tt * 1.4)
		var wide := _qq(&"mouthW", maxf(maxf(maxf(maxf(open, charge * 0.6), summon), 0.8 if C.state == &"stagger" else 0.0), 1.0 if dead else 0.0), 14.0, dt)
		for i in 2:
			var s := -1.0 if i == 1 else 1.0
			pose.pos[lips[i]] = Vector3(s * (0.06 + 0.13 * wide), 0.0, 0.0)
			pose.euler(lips[i], 0.0, s * 0.55 * wide, 0.0)
		pose.scl[j_cavity] = Vector3(0.05 + 0.17 * wide, 0.42, 0.12)
		d[o + 16 + 3] = minf(1.0, wide * 1.2) * 0.9
		d[o + 12 + CH_THROAT] = 0.25 + 0.6 * wide
		# ---- crown: the ribs flex open when it summons, and twitch now and then ----
		var bloom := _qq(&"bloom", summon, 10.0, dt)
		for i in ribs.size():
			pose.euler(ribs[i][0], 0.0, float(ribs[i][1]) - PI / 2.0, -(bloom * 0.7 + 0.03 * sin(tt * 2.1 + i * 1.7)))
		d[o + 20 + 3] = 0.12 + 0.7 * bloom + 0.05 * sin(tt * 3.0)
		d[o + 12 + CH_CROWN] = 0.9 + 1.2 * bloom
		d[o + 28 + 3] = 0.6 * summon
		d[o + 12 + CH_SUMMON] = 1.0 + 1.6 * summon
		# ---- secondary motion: skin tatters and umbilical cords drag behind its movement and sway ----
		sp_lean.step(fwd, lat, 0.0, dt)
		var lx := sp_lean.x.x
		var ly := sp_lean.y.x
		for T: Dictionary in tatters:
			var a: float = T.a
			var ph: float = T.ph
			var sw: float = (T.sp as AnimKit.Spring).step(-lx * 0.12 * cos(a) + ly * 0.12 * sin(a), dt)
			pose.euler(T.m, -(0.1 + sw + 0.08 * sin(tt * 1.7 + ph) + 0.3 * summon), 0.0, 0.06 * sin(tt * 1.3 + ph * 2.0))      # rotation.x < 0 flaps the skin outward
		for c: Dictionary in cords:
			var ph: float = c.ph
			for k in 3:
				pose.euler(c.links[k], -lx * 0.12 * (k + 1) * 0.6 + 0.2 * sin(tt * 1.9 + ph + k * 0.9) + (0.3 if dead else 0.0), 0.0, ly * 0.1 + 0.2 * cos(tt * 1.5 + ph * 1.3 + k * 0.8))
		# ---- the blood glob forming in the pale hand ----
		var ch := _n(charge)
		d[o + 24 + 3] = minf(1.0, ch * 1.1)
		d[o + 12 + CH_SAUCE] = 0.1 + 0.5 * charge
		var gl := 0.01 + 0.075 * ch if ch > 0.02 else 0.0001
		pose.scl[j_glob] = Vector3(gl, gl, gl)
		# ---- health bar ----
		update_bar(dt, 2.45, 1.06 / 0.86, 1.0, true)
		if d[o + 43] >= 0.0:
			var bc := _hsl(0.02 + 0.08 * maxf(0.0, C.hp / C.max), 0.9, 0.55)
			d[o + 40] = bc.r
			d[o + 41] = bc.g
			d[o + 42] = bc.b
		pose.compose(root)
		upload()


## JS FollowerView. A brood scuttles on its finger-legs in diagonal pairs, body low and twitching. The bite: it rears back on its rear fingers with the front pair raised and the ring-mouth dilating (0.38 s), lunges, the mouth snapping shut at 0.10 s, settles. It claws its way out of the floor when it is born, twitches its head about between runs, and dies on its back with the fingers curling in.
class FollowerView:
	extends CreatureView
	static var _model: CreatureModel = null
	const LEG_YAW: Array[float] = [0.9, -0.9, 2.3, -2.3]
	var phase := randf() * 6.0
	var t := 0.0
	var age := 0.0
	var walk_ph := 0.0
	var pf := 0.0
	var sp_lean := AnimKit.Spring.new(220.0, 0.35)
	var sp_hy := AnimKit.Spring.new(260.0, 0.4)
	var sp_mouth := AnimKit.Spring.new(400.0, 0.3)
	var sp_rear := AnimKit.Spring.new(200.0, 0.4)
	var sp_roll := AnimKit.Spring.new(160.0, 0.3)
	var fid: AnimKit.Fidget
	var j_hips: int
	var j_maw: int
	var j_teeth: Array[int] = []
	var legs: Array = []       # { hip, up, lo, k2, yaw, ph, front, sx }
	var cord: Array[int] = []
	var puddle: MeshInstance3D

	static func get_model() -> CreatureModel:
		if _model == null:
			_model = CreatureModel.build("res://assets/objects/enemy_follower.glb")
			_model.body_mat.set_shader_parameter(&"flash_tint", Vector3(0.8, 0.25, 0.15))
		return _model

	func _init(p_r: Follower) -> void:
		super._init(p_r, get_model())
		var n: Dictionary = model.names
		j_hips = n["hips"]
		j_spine = n["spine"]
		j_maw = n["maw"]
		j_muzzle = j_maw
		j_teeth = [n["ring0"], n["ring1"]]
		for i in 4:
			legs.append({"hip": n["hip%d" % i], "up": n["up%d" % i], "lo": n["lo%d" % i], "k2": n["k2%d" % i], "yaw": LEG_YAW[i], "ph": 0.0 if i == 0 or i == 3 else PI, "front": i < 2, "sx": 1.0 if i % 2 == 0 else -1.0})
		j_el_l = n["hip0"]
		for k in 3:
			cord.append(n["cord%d" % k])
		fid = AnimKit.Fidget.new([0.4, 0.9], 1.2, 3.5, fmod(R.id * 0.61, 1.0))
		puddle = FxBeam.puddle(0x4a0406)

	func dispose() -> void:
		super.dispose()
		if is_instance_valid(puddle):
			puddle.queue_free()

	func update(dt: float, _now: float, _fx: Variant) -> void:
		var F := R as Follower
		var dead := F.state == &"dead"
		var st := F.state
		var s_t := F.state_t
		t += dt
		var tt := t + phase
		age += dt
		var root := FleshViews._yaw_root(F.yaw, Vector3(F.x, F.y, F.z))
		var d := batch.data
		var o := row * batch.stride
		d[o] = F.flash
		if F.flash > pf + 0.2:
			sp_roll.v += (-1.0 if randf() < 0.5 else 1.0) * 6.0
			sp_lean.v -= 5.0
		pf = F.flash
		if dead:      # flips onto its back, fingers curling in, then sinks into its own puddle
			var D := F.dead_t
			var k := AnimKit.out_cubic(_n(D / 0.35))
			var curl := _n((D - 0.15) / 0.5)
			if D > 0.1:
				FxBeam.place_puddle(puddle, Vector3(F.x, F.y + 0.012, F.z), minf(0.55, D * 1.2), maxf(0.0, 0.9 - (D - 2.0) * 0.9) if D > 2.0 else 0.9)
			else:
				puddle.visible = false
			if D >= 3.0:
				batch.clear_row(row)
				return
			pose.euler(j_hips, 0.0, 0.0, PI * 0.92 * k)
			pose.pos[j_hips] = Vector3(0.0, 0.3 - 0.12 * k - ((D - 1.5) * 0.12 if D > 1.5 else 0.0), 0.0)
			for L: Dictionary in legs:
				pose.euler(L.up, -0.6 - 0.9 * curl + 0.15 * sin(D * 30.0) * (1.0 - curl), 0.0, 0.0)
				pose.euler(L.lo, 1.2 * curl, 0.0, 0.0)
				pose.euler(L.k2, 1.3 * curl, 0.0, 0.0)
			pose.scl[j_maw] = Vector3.ONE * 1.15
			pose.compose(root)
			upload()
			return
		puddle.visible = false
		# born: claws its way up out of the floor
		var pop_u := minf(1.0, age / 0.5)
		var pop := 0.15 + 0.85 * AnimKit.out_back(pop_u)
		var rise := -0.25 * (1.0 - AnimKit.out_cubic(pop_u)) if age < 0.5 else 0.0
		var fwd := F.lvz
		var lat := F.lvx
		var spd := U.hyp(fwd, lat)
		walk_ph += dt * (9.0 + spd * 2.6 if spd > 0.2 else 0.0)
		var run_k := minf(1.0, spd / 2.0)
		var hy := 0.24 + rise + 0.015 * absf(sin(walk_ph * 2.0)) * run_k
		var lean := spd * 0.04
		var rear := 0.0
		var mouth := 0.55 + 0.08 * sin(tt * 5.0)
		var roll := 0.0
		fid.step(dt, st == &"pursue" and spd < 0.3)
		var f0 := fid.env(0, 0.2)
		var f1 := fid.env(1)                      # a twitch, a look about
		var head := 0.6 * sin(fid.u * PI * 2.0) * f1 + 0.25 * sin(tt * 23.0) * f0
		if st == &"windup":
			var u := _n(s_t / 0.38)
			rear = AnimKit.out_cubic(u)
			lean = -0.38 * rear
			hy += 0.07 * rear
			mouth = 0.55 + 0.6 * u
		elif st == &"attack":
			var u := _n(s_t / 0.10)
			var v := _n((s_t - 0.10) / 0.16)
			rear = 1.0 - AnimKit.out_cubic(u)
			lean = lerpf(-0.38, 0.45, AnimKit.out_cubic(u)) - 0.25 * v
			hy += 0.06 * sin(_n(s_t / 0.26) * PI)
			mouth = 1.15 if s_t < 0.1 else 0.35
			if AnimKit.crossed(s_t - dt, s_t, 0.10):
				sp_mouth.v -= 8.0
		elif st == &"recover":
			var u := _n(s_t / 0.8)
			lean = 0.2 * (1.0 - u)
			mouth = 0.45
		elif st == &"stagger":
			lean = -0.35
			rear = 0.4
			mouth = 1.1
			roll = 0.3 * sin(tt * 18.0)
		lean = sp_lean.step(lean, dt)
		hy = sp_hy.step(hy, dt)
		mouth = sp_mouth.step(mouth, dt)
		rear = sp_rear.step(rear, dt)
		roll = sp_roll.step(roll, dt)
		pose.pos[j_hips] = Vector3(0.0, hy, 0.0)
		pose.scl[j_hips] = Vector3(pop, pop, pop)
		pose.euler(j_hips, lean, 0.0, roll + 0.05 * sin(walk_ph) * run_k)
		pose.euler(j_spine, 0.06 * sin(tt * 2.2), head, 0.0)
		# finger-legs: lift and swing in diagonal pairs; while rearing the front pair rises and claws at the air
		for L: Dictionary in legs:
			var ph: float = L.ph
			var front: bool = L.front
			var p := walk_ph + ph
			var lift := maxf(0.0, sin(p)) * run_k
			var swing := cos(p) * 0.35 * run_k * (1.0 if front else -1.0)
			var claw := rear if front else 0.0
			var brace := 0.0 if front else rear
			pose.euler(L.hip, 0.0, float(L.yaw) + swing * float(L.sx), 0.0)
			pose.euler(L.up, -0.75 - 0.5 * lift - 1.0 * claw + 0.35 * brace + 0.04 * sin(tt * 7.0 + ph), 0.0, 0.0)
			pose.euler(L.lo, 0.55 + 0.3 * lift + 0.6 * claw * (0.8 + 0.2 * sin(tt * 16.0 + ph)) - 0.25 * brace, 0.0, 0.0)      # feet planted at rest (checked: nail tips ~0.01 m)
			pose.euler(L.k2, 0.3 + 0.5 * claw, 0.0, 0.0)
		# the mouth: dilates, the inner tooth ring counter-turns
		var m := maxf(0.45, mouth)
		pose.scl[j_maw] = Vector3(m, m, 1.0)
		pose.euler(j_teeth[0], 0.0, 0.0, 0.15 * (mouth - 0.55))
		pose.euler(j_teeth[1], 0.0, 0.0, -0.3 * (mouth - 0.55))
		for k in cord.size():
			pose.euler(cord[k], 0.2 + 0.1 * sin(tt * 2.3 + k), 0.35 * sin(tt * 3.0 - k * 0.9) * (0.4 + run_k), 0.0)
		pose.compose(root)
		upload()
