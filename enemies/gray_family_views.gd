class_name GrayFamilyViews
extends RefCounted
## The gray family on screen (JS enemies/gray-family.js): TommyGunView and ButtonManView are the alien's body with their own export plus a laser; ButlerView and ConsigliereView are small models of their own. Same animation as the JS, statement for statement.
## The Muscle's view is with the Gristle Brute's, whose moves he uses.

## JS TommyGunView
class TommyGunView:
	extends AlienView
	var tube: MeshInstance3D
	var dot: MeshInstance3D

	func _init(p_r: TommyGunGray) -> void:
		super._init(p_r, "gray_tommy", 0xff4a3a)
		tube = FxBeam.tube(0xff2a1a)
		dot = FxBeam.dot(0xff3020)

	func update(dt: float, now: float, fx: Variant) -> void:
		super.update(dt, now, fx)
		var L := R as TommyGunGray
		var on := L.laser_on and not L.dead
		if not on:
			tube.visible = false
			dot.visible = false
			return
		var mz := pose.world[j_muzzle].origin
		var end := mz + L.laser_dir * L.laser_len
		var w := 0.012 if L.laser_fire else 0.02 + 0.008 * sin(now * 40.0)
		FxBeam.place_tube(tube, mz, end, w, 0.45 if L.laser_fire else 0.9)
		FxBeam.place_dot(dot, end, 0.45 + 0.15 * sin(now * 30.0), 0.9)

	func dispose() -> void:
		super.dispose()
		if is_instance_valid(tube):
			tube.queue_free()
			dot.queue_free()


## JS ButtonManView
class ButtonManView:
	extends AlienView
	var tube: MeshInstance3D
	var dot: MeshInstance3D
	var shimmer: MeshInstance3D

	func _init(p_r: ButtonMan) -> void:
		super._init(p_r, "gray_buttonman", 0xff3020)
		tube = FxBeam.tube(0xff2a1a)
		dot = FxBeam.dot(0xff3020)
		shimmer = FxBeam.dot(0x9fd0ff)

	func update(dt: float, now: float, fx: Variant) -> void:
		super.update(dt, now, fx)
		var L := R as ButtonMan
		if L.cloaked:
			batch.clear_row(row)
		if L.cloaked and not L.dead:
			FxBeam.place_dot(shimmer, Vector3(L.x, L.y + 1.0, L.z), 1.8, 0.12 + 0.12 * sin(now * 23.0))
		else:
			shimmer.visible = false
		var on := L.laser_on and not L.dead and not L.cloaked
		if not on:
			tube.visible = false
			dot.visible = false
			return
		var mz := pose.world[j_muzzle].origin
		FxBeam.place_tube(tube, mz, L.laser_at, 0.02 if L.laser_lock else 0.008, 0.95 if L.laser_lock else 0.55 + 0.3 * sin(now * 30.0))
		FxBeam.place_dot(dot, L.laser_at, 0.5 if L.laser_lock else 0.3, 1.0)

	func dispose() -> void:
		super.dispose()
		if is_instance_valid(tube):
			tube.queue_free()
			dot.queue_free()
			shimmer.queue_free()


## JS ButlerView
class ButlerView:
	extends CreatureView
	const CH_EYE := 0
	const CH_THRUST := 1
	const CH_PROBE := 2
	static var _model: CreatureModel = null
	var ph := randf() * 6.0
	var spin := 0.0
	var j_body: int
	var j_tray: int
	var j_cloche: int
	var j_probe: int

	static func get_model() -> CreatureModel:
		if _model == null:
			_model = CreatureModel.build("res://assets/objects/gray_butler.glb", _glow, {}, {"butlerEye": 1})
		return _model

	static func _glow(s: RobotGfx.SpriteSoup, m: CreatureModel) -> void:
		s.sprite(m.names["body"], CH_EYE, Vector3(0.0, 0.2, 0.32), 1.0)
		s.sprite(m.names["body"], CH_THRUST, Vector3(0.0, -0.42, 0.0), 1.0)
		s.sprite(m.names["probe"], CH_PROBE, Vector3(0.0, 0.4, 0.0), 1.0)

	func _init(p_r: ProbeButler) -> void:
		super._init(p_r, get_model())
		var n: Dictionary = model.names
		j_body = n["body"]
		j_tray = n["tray"]
		j_cloche = n["cloche"]
		j_probe = n["probe"]
		j_spine = j_body
		j_el_l = j_body
		j_muzzle = n["muz"]
		var d := batch.data
		var o := row * batch.stride
		_col(d, o + 16, 0xff4040)
		_col(d, o + 20, 0x7fd3ff)
		_col(d, o + 24, 0xff5050)
		d[o + 14] = 0.3

	func update(dt: float, now: float, _fx: Variant) -> void:
		var B := R as ProbeButler
		var t := now + ph
		var dead := B.state == &"dead"
		var u := B.probe_u
		if dead and B.dead_t > 10.0:
			batch.clear_row(row)
			return
		var diving := B.state == &"attack" and B.atk == &"dive"
		var d := batch.data
		var o := row * batch.stride
		d[o] = B.flash * 0.5
		var bx := 0.9 if diving else (-0.25 * u if B.state == &"windup" and B.atk == &"dive" else sin(t * 1.3) * 0.05 + B.lvz * 0.04)
		pose.euler(j_body, bx, 0.0, minf(1.4, B.dead_t * 3.0) if dead else sin(t * 0.9) * 0.06)
		pose.pos[j_cloche] = Vector3(0.0, 0.01 + 0.32 * u, 0.0)
		pose.euler(j_cloche, 0.0, 0.0, -0.9 * u)
		var ps := 0.2 + 0.8 * u if u > 0.02 else 0.0001
		pose.scl[j_probe] = Vector3(ps, ps, ps)
		spin += dt * (4.0 + 40.0 * u)
		pose.euler(j_probe, 0.0, spin, 0.0)
		pose.euler(j_tray, -1.4 if diving else -0.6 * u, 0.0, 0.0)
		d[o + 24 + 3] = 0.9 * u
		d[o + 16 + 3] = 0.0 if dead else 0.3 + 0.6 * u + 0.1 * sin(t * 6.0)
		var eye := _hsl(0.0, 1.0, 0.4 + 0.25 * u)
		d[o + 4] = eye.r
		d[o + 5] = eye.g
		d[o + 6] = eye.b
		d[o + 20 + 3] = 0.0 if dead else 0.5 + 0.2 * sin(t * 30.0)
		d[o + 12 + CH_THRUST] = 0.9 if diving else 0.55
		d[o + 12 + CH_EYE] = 0.45
		update_bar(dt, 1.35 - 0.45, 0.66 / 0.86)
		var sn := sin(B.yaw)
		var cs := cos(B.yaw)
		pose.compose(Transform3D(Basis(Vector3(cs, 0.0, -sn), Vector3.UP, Vector3(sn, 0.0, cs)), Vector3(B.x, B.y - 0.45, B.z)))
		upload()


## JS ConsigliereView
class ConsigliereView:
	extends CreatureView
	const CH_GLOW := 0
	const CH_FLUID := 1
	static var _model: CreatureModel = null
	var ph := randf() * 6.0
	var j_body: int
	var j_ring: int
	var links: Array = []

	static func get_model() -> CreatureModel:
		if _model == null:
			_model = CreatureModel.build("res://assets/objects/gray_consigliere.glb", _glow, {"liquid": CH_FLUID})
		return _model

	static func _glow(s: RobotGfx.SpriteSoup, m: CreatureModel) -> void:
		s.sprite(m.names["body"], CH_GLOW, Vector3(0.0, 0.05, 0.0), 1.0)

	func _init(p_r: Consigliere) -> void:
		super._init(p_r, get_model())
		var n: Dictionary = model.names
		j_body = n["body"]
		j_ring = n["ring"]
		j_spine = j_body
		j_el_l = j_body
		j_muzzle = j_body
		var d := batch.data
		var o := row * batch.stride
		_col(d, o + 16, 0xc070ff)
		_col(d, o + 20, 0x5cff8a)
		d[o + 20 + 3] = 0.22
		d[o + 12 + CH_GLOW] = 1.0
		for i in 4:
			links.append([FxBeam.tube(0xc070ff), FxBeam.ball(0xb060ff)])

	func update(dt: float, now: float, _fx: Variant) -> void:
		var C := R as Consigliere
		var t := now + ph
		var dead := C.state == &"dead"
		if dead and C.dead_t > 10.0:
			batch.clear_row(row)
			_links(t, true)
			return
		var d := batch.data
		var o := row * batch.stride
		d[o] = C.flash * 0.5
		pose.euler(j_body, 0.0, 0.0, minf(1.5, C.dead_t * 3.0) if dead else sin(t * 1.3) * 0.08)
		pose.pos[j_body] = Vector3(0.0, 0.4 + sin(t * 2.0) * 0.06, 0.0)
		pose.euler(j_ring, 0.0, t * 3.0, 0.0)
		d[o + 16 + 3] = 0.0 if dead else 0.3 + 0.15 * sin(t * 5.0)
		update_bar(dt, 1.5 - 0.4, 0.66 / 0.86)
		var sn := sin(C.yaw)
		var cs := cos(C.yaw)
		pose.compose(Transform3D(Basis(Vector3(cs, 0.0, -sn), Vector3.UP, Vector3(sn, 0.0, cs)), Vector3(C.x, C.y - 0.4, C.z)))
		upload()
		_links(t, dead)

	func _links(t: float, dead: bool) -> void:
		var C := R as Consigliere
		var a := pose.world[j_body].origin
		for i in links.size():
			var L: Array = links[i]
			var tb: MeshInstance3D = L[0]
			var bl: MeshInstance3D = L[1]
			var oo: Robot = C.shielded[i] if not dead and i < C.shielded.size() else null
			if oo == null:
				tb.visible = false
				bl.visible = false
				continue
			var ty := oo.y + (oo.h if oo.h != 0.0 else 1.6) * 0.6
			FxBeam.place_tube(tb, a, Vector3(oo.x, ty, oo.z), 0.03 * (1.0 + 0.4 * sin(t * 20.0 + i)), 0.7)
			FxBeam.place_ball(bl, Vector3(oo.x, oo.y + (oo.h if oo.h != 0.0 else 1.6) * 0.55, oo.z), (2.0 if oo.get(&"muscle") == true else 1.05) * (1.0 + 0.03 * sin(t * 6.0 + i)), 0.16)

	func dispose() -> void:
		super.dispose()
		for L: Array in links:
			if is_instance_valid(L[0]):
				L[0].queue_free()
				L[1].queue_free()


## JS MuscleView
class MuscleView:
	extends CreatureView
	const CH_CORE := 0
	const CH_STACK := 1
	static var _model: CreatureModel = null
	var walk_ph := 0.0
	var fall_t := 0.0
	var J: Dictionary

	static func get_model() -> CreatureModel:
		if _model == null:
			_model = CreatureModel.build("res://assets/objects/gray_muscle.glb", _glow, {}, {"muscleCore": 1})
		return _model

	static func _glow(s: RobotGfx.SpriteSoup, m: CreatureModel) -> void:
		s.sprite(m.names["spine"], CH_CORE, Vector3(0.0, 0.5, 0.6), 1.0)
		for sx: float in [-1.0, 1.0]:
			s.sprite(m.names["spine"], CH_STACK, Vector3(sx * 0.36, 1.5, -0.5), 1.0)

	func _init(p_r: Muscle) -> void:
		super._init(p_r, get_model())
		J = model.names
		j_spine = J["spine"]
		j_el_l = J["elL"]
		j_muzzle = J["core"]
		var d := batch.data
		var o := row * batch.stride
		_col(d, o + 16, 0x6cff6a)
		_col(d, o + 20, 0x8c8c8c)

	func sprite_world(_i: int) -> Vector3:
		return pose.world[j_spine] * Vector3(0.0, 0.5, 0.6)

	func update(dt: float, now: float, _fx: Variant) -> void:
		var M := R as Muscle
		var t := now
		var dead := M.state == &"dead"
		var d := batch.data
		var o := row * batch.stride
		d[o] = M.flash * 0.55
		var spd := absf(M.lvz)
		walk_ph += dt * (1.2 + spd * 1.6) * (1.0 if spd > 0.2 else 0.0)
		var s := sin(walk_ph * 2.0)
		var amp := minf(1.0, spd / 2.4) * 0.45
		var hips_y := 1.15 - 0.05 * absf(s) * amp * 2.0
		var sp_p := 0.05 * amp
		var sp_r := 0.0
		var th_l := -amp * s
		var th_r := amp * s
		var kn_l := 0.15 + maxf(0.0, s) * amp
		var kn_r := 0.15 + maxf(0.0, -s) * amp
		var sh_lx := 0.3 * amp * -s
		var sh_rx := 0.3 * amp * s
		var el_lx := -0.3
		var el_rx := -0.3
		var sh_lz := 0.12
		var sh_rz := -0.12
		var plate := 0.0
		var hd_y := 0.0
		var lean := 0.0
		var u := _n(M.a_u)
		var st := M.state
		var slam := M.atk == &"melee"
		var charge := M.atk == &"charge"
		if st == &"windup" and slam:
			var e := _ease(_n(M.state_t / maxf(0.1, GristleBrute.SLAM_WIND)))
			sh_lx = -2.7 * e
			sh_rx = sh_lx
			el_lx = -0.4 * e
			el_rx = el_lx
			sp_p = -0.25 * e
			hips_y = 1.15 + 0.06 * e
		elif st == &"attack" and slam:
			var e := _ease(_n(M.state_t / 0.15))
			sh_lx = lerpf(-2.7, -0.6, e)
			sh_rx = sh_lx
			el_lx = lerpf(-0.4, -0.1, e)
			el_rx = el_lx
			sp_p = lerpf(-0.25, 0.45, e)
			hips_y = 1.15 - 0.15 * e
		elif st == &"recover" and slam:
			var e := _ease(u)
			sh_lx = lerpf(-0.6, 0.0, e)
			sh_rx = sh_lx
			sp_p = lerpf(0.45, 0.05, e)
			hips_y = 1.0 + 0.15 * e
		elif st == &"windup" and charge:
			var e := _ease(_n(M.state_t / maxf(0.1, GristleBrute.CHARGE_WIND)))
			sp_p = 0.35 * e
			hips_y = 1.15 - 0.12 * e
			sh_lx = -1.3 * e
			sh_rx = sh_lx
			el_lx = -0.2
			el_rx = -0.2
			kn_l = 0.5 * e
			kn_r = kn_l
			lean = sin(t * 50.0) * 0.01 * e
		elif st == &"attack" and charge:
			sp_p = 0.45
			sh_lx = -1.4
			sh_rx = -1.4
			th_l = -0.6 * sin(t * 16.0)
			th_r = 0.6 * sin(t * 16.0)
		elif st == &"recover" and charge and M.ch != null and M.ch.missed:
			sp_p = 0.15
			sp_r = sin(t * 5.0) * 0.15
			hd_y = sin(t * 7.0) * 0.6
		elif st == &"stagger":
			sp_p = -0.2 + sin(t * 25.0) * 0.05
			sh_lz = 0.6
			sh_rz = -0.6
		if M.exposed_t > 0.0:
			plate = 1.25 + sin(t * 9.0) * 0.05
		if M.block_t > 0.0:
			plate = -0.15 * (M.block_t / 0.25)
		var fall: int = J["fall"]
		if dead:
			fall_t += dt
			var e := _ease(_n(fall_t / 0.9))
			pose.euler(fall, e * 1.45, 0.0, 0.0)
			pose.pos[fall] = Vector3(0.0, 0.25 * sin(e * 1.4), 0.0)
			plate = 1.5
			hips_y = 1.0
		else:
			fall_t = 0.0
			pose.euler(fall, 0.0, 0.0, 0.0)
			pose.pos[fall] = Vector3.ZERO
		pose.pos[J["hips"]] = Vector3(0.0, _qq(&"hy", hips_y, 12.0, dt), 0.0)
		pose.euler(j_spine, _qq(&"sp", sp_p, 10.0, dt), _qq(&"hdY0", 0.0, 10.0, dt), _qq(&"spR", sp_r, 10.0, dt) + lean)
		var tl := _qq(&"thL", th_l, 10.0, dt)
		var tr := _qq(&"thR", th_r, 10.0, dt)
		var kl := _qq(&"knL", kn_l, 10.0, dt)
		var kr := _qq(&"knR", kn_r, 10.0, dt)
		pose.euler(J["thL"], tl, 0.0, 0.0)
		pose.euler(J["thR"], tr, 0.0, 0.0)
		pose.euler(J["knL"], kl, 0.0, 0.0)
		pose.euler(J["knR"], kr, 0.0, 0.0)
		pose.euler(J["ankL"], -(tl + kl) * 0.8, 0.0, 0.0)
		pose.euler(J["ankR"], -(tr + kr) * 0.8, 0.0, 0.0)
		var ra := 40.0 if st == &"attack" and slam else 10.0
		pose.euler(J["shL"], _qq(&"shLx", sh_lx, ra, dt), 0.0, _qq(&"shLz", sh_lz, 10.0, dt))
		pose.euler(J["shR"], _qq(&"shRx", sh_rx, ra, dt), 0.0, _qq(&"shRz", sh_rz, 10.0, dt))
		pose.euler(J["elL"], _qq(&"elLx", el_lx, 10.0, dt), 0.0, 0.0)
		pose.euler(J["elR"], _qq(&"elRx", el_rx, 10.0, dt), 0.0, 0.0)
		var hinge := _qq(&"plate", plate, 9.0 if M.exposed_t > 0.0 else 14.0, dt)
		pose.euler(J["plate"], hinge, 0.0, 0.0)
		pose.euler(J["head"], 0.0, _qq(&"hdY", hd_y, 6.0, dt), 0.0)
		var open := _n(hinge / 1.2)
		var core := _hsl(0.33, 1.0, 0.45 + 0.2 * open + 0.1 * sin(t * 6.0))
		d[o + 4] = core.r
		d[o + 5] = core.g
		d[o + 6] = core.b
		d[o + 16 + 3] = (0.15 + 0.75 * open) * (0.2 if dead else 1.0)
		d[o + 12 + CH_CORE] = 0.8 + 0.6 * open
		d[o + 20 + 3] = 0.15 + 0.15 * sin(t * 8.0)      # (the JS's two stacks differ only in phase)
		d[o + 12 + CH_STACK] = 0.3 + 0.1 * sin(t * 5.0)
		update_bar(dt, 3.2, 1.26 / 0.86)
		if dead and M.dead_t > 12.0:
			batch.clear_row(row)
			return
		var sn := sin(M.yaw)
		var cs := cos(M.yaw)
		pose.compose(Transform3D(Basis(Vector3(cs, 0.0, -sn), Vector3.UP, Vector3(sn, 0.0, cs)), Vector3(M.x, M.y, M.z)))
		upload()
