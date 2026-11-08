class_name FleshViews
extends RefCounted
## The Spire's smaller creatures on screen, each a CreatureModel exported from the JS game and the JS view's animation, statement for statement: the Sinew Crawler (JS enemies/sinew-crawler-view.js), the Blister Bloat (JS enemies/blister-bloat-view.js).


static func _yaw_root(yaw: float, at: Vector3) -> Transform3D:
	var sn := sin(yaw)
	var cs := cos(yaw)
	return Transform3D(Basis(Vector3(cs, 0.0, -sn), Vector3.UP, Vector3(sn, 0.0, cs)), at)


## JS SinewCrawlerView: a flayed spine-centipede. On a wall its belly faces the wall and its head turns to you; while it winds up a drop it rears back, splays its ribs, and a red ring on the floor marks where it will land.
class CrawlerView:
	extends CreatureView
	const CH_MOUTH := 0
	static var _model: CreatureModel = null
	var phase := randf() * 6.0
	var t := 0.0
	var age := 0.0
	var prev_state: StringName
	var prev_st := 0.0
	var notice_t := 9.0
	var yaw_prev := 0.0
	var yaw_rate := 0.0
	var walk_ph := 0.0
	var lost := 0
	var quat := Quaternion.IDENTITY
	var mouth_op := 0.0
	var j_body: int
	var j_head: int
	var segs: Array = []       # { s, ph, legs: [ { pv, sx, id } ] }
	var mands: Array = []      # [joint, sx]
	var sp_rear := AnimKit.Spring.new(180.0, 0.45)
	var sp_pounce := AnimKit.Spring.new(260.0, 0.4)
	var sp_sq := AnimKit.Spring.new(300.0, 0.3)
	var sp_lunge := AnimKit.Spring.new(320.0, 0.32)
	var sp_mand := AnimKit.Spring.new(420.0, 0.3)
	var sp_flip := AnimKit.Spring.new(60.0, 0.5)
	var sp_bend := AnimKit.Spring.new(90.0, 0.55)
	var seg_lag: Array = []
	var blink: AnimKit.Blink
	var ring: MeshInstance3D

	static func get_model() -> CreatureModel:
		if _model == null:
			_model = CreatureModel.build("res://assets/objects/enemy_crawler.glb", _glow)
			_model.body_mat.set_shader_parameter(&"flash_tint", Vector3(0.8, 0.4, 0.3))
		return _model

	static func _glow(s: RobotGfx.SpriteSoup, m: CreatureModel) -> void:
		s.sprite(m.names["head"], CH_MOUTH, Vector3(0.0, -0.05, 0.3), 0.3)

	func _init(p_r: SinewCrawler) -> void:
		super._init(p_r, get_model())
		var n: Dictionary = model.names
		j_body = n["body"]
		j_head = n["head"]
		j_spine = j_body
		j_el_l = j_head
		j_muzzle = n["muzzle"]
		for i in 6:
			var legs: Array = []
			for side in 2:
				legs.append({"pv": n["p%d%d" % [i, side]], "sx": -1.0 if side == 0 else 1.0, "id": i * 2 + side})
			segs.append({"s": n["s%d" % i], "ph": i * 0.9, "legs": legs})
			seg_lag.append(AnimKit.Spring.new(120.0, 0.5))
		mands = [[n["mand0"], -1.0], [n["mand1"], 1.0]]
		prev_state = R.state
		yaw_prev = R.yaw
		quat = Quaternion(Vector3.UP, R.yaw)
		blink = AnimKit.Blink.new(1.2, 3.5, 0.1, fmod(R.id * 0.23, 1.0))
		var d := batch.data
		var o := row * batch.stride
		_col(d, o + 16, 0xc8ff40)
		d[o + 12 + CH_MOUTH] = 1.0
		ring = FxBeam.ring(0xff2a3a)

	func dispose() -> void:
		super.dispose()
		if is_instance_valid(ring):
			ring.queue_free()

	func update(dt: float, _now: float, fx: Variant) -> void:
		var C := R as SinewCrawler
		var st := C.state
		var dead := st == &"dead"
		var d := batch.data
		var o := row * batch.stride
		d[o] = C.flash
		# orientation: on a wall the belly faces the wall (up = the wall's normal) and the head points at you; on the ground it is a normal yaw
		var on_wall := C.mode == &"wall" or (dead and C.mode != &"ground")
		if on_wall:
			var yv := C.normal.normalized()
			var P: Player = C.E.P if C.E != null else null
			var v := Vector3(P.x - C.x, P.y + 1.0 - C.y, P.z - C.z) if P != null else Vector3.DOWN
			var zv := v - yv * v.dot(yv)
			if zv.length_squared() < 1e-4:
				zv = Vector3.DOWN + yv * yv.y
			zv = zv.normalized()
			var xv := yv.cross(zv).normalized()
			quat = quat.slerp(Basis(xv, yv, zv).get_rotation_quaternion(), 1.0 - exp(-10.0 * dt))
		else:
			quat = quat.slerp(Quaternion(Vector3.UP, C.yaw), 1.0 - exp(-14.0 * dt))
		# ---- poses (sim time; timings are the AI's: drop wind 0.7 s with tracking until 0.5, flight 0.55 s, bite wind 0.35 s / hit at 0.08 s)
		t += dt
		age += dt
		var tt := t + phase
		var s_t := C.state_t
		var atk := C.atk
		var prev_s := prev_st if st == prev_state else -1.0
		var was_idle := prev_state == &"idle" or prev_state == &"return" or prev_state == &"search"
		if was_idle and (st == &"pursue" or st == &"alert"):
			notice_t = 0.0
			AnimKit.cue(fx, C, "inhale", 0.4)
		prev_state = st
		prev_st = s_t
		notice_t += dt
		var yr := C.yaw - yaw_prev
		yr = atan2(sin(yr), cos(yr))
		yaw_rate += (yr / maxf(dt, 1e-4) - yaw_rate) * (1.0 - exp(-8.0 * dt))
		yaw_prev = C.yaw
		var spd := U.hyp(C.lvx, C.lvz) + (4.0 if C.mode == &"air" else 0.0)
		walk_ph += dt * (6.0 + spd * 2.5 if spd > 0.2 else 0.8)
		var rear := 0.0
		var splay := 0.0
		var mand_open := 0.15 + 0.1 * sin(tt * 9.0)
		var curl := 0.0
		var pounce := 0.0
		var sq := 0.0
		var lunge := 0.0
		var shiver := 0.0
		var dizzy := 0.0
		var flip := 0.0
		var glow := 0.0
		if notice_t < 0.8 and not dead:
			var nh := AnimKit.hold(notice_t, 0.08, 0.45, 0.08, 0.3)
			rear = 0.6 * nh
			mand_open = 0.9 * nh
			splay = 0.4 * nh
		if st == &"windup":
			var wnd := SinewCrawler.DROP_WIND if atk == &"drop" else (SinewCrawler.LEAP_WIND if atk == &"leap" else (SinewCrawler.SPIT_WIND if atk == &"spit" else SinewCrawler.BITE_WIND))
			var u := _n(s_t / wnd)
			if atk == &"drop" or atk == &"leap":      # hisses and pulls back, locks and trembles
				rear = AnimKit.out_back(u, 1.4)
				splay = u
				mand_open = 0.3 + 0.7 * u
				shiver = AnimKit.win(u, 0.7, 1.0)
			elif atk == &"spit":                       # the throat glows bile-green
				rear = 0.5 * u
				mand_open = 0.4 + 0.6 * u
				glow = u
			else:                                      # bite: rears, mandibles spread
				rear = 0.45 * AnimKit.out_back(u)
				mand_open = 0.4 + 0.6 * u
				lunge = -0.12 * u
				shiver = AnimKit.win(u, 0.75, 1.0) * 0.5
		elif st == &"attack":
			if atk == &"drop" or atk == &"leap":       # airborne: stretched out, legs reaching forward
				pounce = 1.0
				splay = 1.0
				curl = 0.25
				mand_open = 1.0
			elif atk == &"spit":
				rear = 0.5 - s_t * 2.0
				lunge = 0.25 * (1.0 - s_t / 0.2)
				if AnimKit.crossed(prev_s, s_t, 0.0):
					sp_lunge.kick(4.0)
			else:
				var u := _n(s_t / 0.08)
				lunge = 0.35 * AnimKit.out_cubic(u)
				mand_open = 1.0 if s_t < 0.08 else 0.0
				if AnimKit.crossed(prev_s, s_t, 0.08):
					sp_mand.kick(-12.0)
					sp_sq.kick(3.0)
		elif st == &"recover":
			if atk == &"drop":                         # lands splayed, stunned and dizzy
				var u := _n(s_t / 0.85)
				if AnimKit.crossed(prev_s, s_t, 0.0) or prev_s < 0.0:
					sp_sq.kick(7.0)
					AnimKit.cue(fx, C, "thud")
				splay = 0.7 * (1.0 - u)
				dizzy = AnimKit.hold(u, 0.05, 0.75, 0.05, 0.2)
			elif atk == &"spit":
				rear = 0.2 * (1.0 - s_t / 0.4)
		if st == &"stagger":
			dizzy = 1.0
			splay = 0.4
		if dead:                                       # on the ground it rolls onto its back, legs curling and twitching
			var k := minf(1.0, C.dead_t * 2.0)
			curl = k
			splay = 0.6
			flip = 1.0 if C.mode == &"ground" else 0.0
		rear = sp_rear.step(rear, dt)
		pounce = sp_pounce.step(pounce, dt)
		sq = sp_sq.step(sq, dt)
		lunge = sp_lunge.step(lunge, dt)
		mand_open = sp_mand.step(mand_open, dt)
		flip = sp_flip.step(flip, dt)
		var bend := sp_bend.step(clampf(-yaw_rate * 0.12, -0.6, 0.6), dt)      # the body bows through turns
		var shv := sin(tt * 57.0) * 0.04 * shiver if shiver != 0.0 else 0.0
		pose.euler(j_body, 0.0, 0.0, PI * flip + dizzy * 0.15 * sin(tt * 6.0))
		pose.pos[j_body] = Vector3(shv, flip * 0.35, 0.0)
		pose.scl[j_body] = Vector3(1.0 + sq * 0.12, 1.0 - sq * 0.25, 1.0 + sq * 0.08 + pounce * 0.12)
		var hp_f := C.hp / C.max if C.max != 0.0 else 1.0
		var lose := lost if dead else (6 if hp_f < 0.3 else (3 if hp_f < 0.6 else 0))      # damage: legs are torn off as it weakens
		if lose > lost and not dead:
			AnimKit.cue(fx, C, "crack")
			if fx != null:
				fx._blood_spray(pose.world[j_body].origin, 0.0, 0.0, 6, 2.5)
		lost = lose
		const LOST_ORDER: Array[int] = [3, 8, 10, 1, 6, 11]
		for i in 6:
			var S2: Dictionary = segs[i]
			var un := 1.0 if dead else AnimKit.out_back(AnimKit.win(age, 0.05 + i * 0.07, 0.3 + i * 0.07), 2.0)      # spawn: it unfurls head first, segment by segment, with an overshoot
			var uns := maxf(0.05, un)
			pose.scl[S2.s] = Vector3(uns, uns, uns)
			var lag: float = (seg_lag[i] as AnimKit.Spring).step(bend * i * 0.12, dt)      # each segment trails the one in front
			pose.pos[S2.s] = Vector3(sin(walk_ph * 0.5 - i * 0.9) * 0.025 * minf(1.0, spd / 3.0) + lag * 0.5, 0.28 + sin(walk_ph + float(S2.ph)) * 0.03 + rear * (0.25 - i * 0.1 if i < 2 else 0.0) - pounce * (0.05 if i < 2 else 0.0), 0.75 - i * 0.28)
			pose.euler(S2.s, -rear * (0.35 if i < 3 else 0.0) + curl * 0.5 * (i - 2.5) * 0.4 + pounce * (0.25 if i < 3 else -0.1), lag, 0.0)
			for L: Dictionary in S2.legs:
				var idx := LOST_ORDER.find(int(L.id))
				pose.scl[L.pv] = Vector3.ONE * (0.0001 if idx >= 0 and idx < lost else 1.0)
				var sx: float = L.sx
				var wave := sin(walk_ph * 1.3 + float(S2.ph) + (0.0 if sx > 0.0 else PI))
				var tw := sin(tt * 19.0 + i * 2.0 + sx) * 0.3 * (1.0 - AnimKit.win(C.dead_t, 1.0, 3.0)) if dead else 0.0
				pose.euler(L.pv, wave * 0.5 * (1.0 if spd > 0.2 else 0.2) - pounce * 0.6 + tw, 0.0, sx * (0.15 + 0.5 * splay) - (sx * curl * 1.2 if dead else 0.0))
		var hs := 1.0 if dead else maxf(0.05, AnimKit.out_back(AnimKit.win(age, 0.0, 0.25), 2.0))
		pose.scl[j_head] = Vector3(hs, hs, hs)
		pose.pos[j_head] = Vector3(0.0, 0.3 + rear * 0.12, 1.02 + lunge * 0.6)
		pose.euler(j_head, -rear * 0.4 + lunge * 0.5 + dizzy * 0.2 * sin(tt * 7.0), bend * 0.6, dizzy * 0.25 * sin(tt * 5.0))
		for M: Array in mands:
			pose.euler(M[0], 0.0, -float(M[1]) * maxf(-0.05, mand_open) * 0.75, 0.0)
		var bl := blink.step(dt)
		# dull until it commits, then they burn red (JS eyeMat.emissive, red channel; the export's emissive is pure red)
		d[o + 9] = (0.08 + (0.9 * (0.6 + 0.4 * absf(sin(tt * 20.0))) if st == &"windup" or st == &"attack" else 0.0)) * (maxf(0.0, 1.0 - C.dead_t) if dead else 1.0) * (1.0 - 0.8 * bl)
		if st == &"windup" and atk == &"spit":
			mouth_op = 0.9 * glow
		else:
			mouth_op = maxf(0.0, mouth_op - dt * 4.0)
		d[o + 16 + 3] = mouth_op
		# the drop ring (in world space)
		if st == &"windup" and atk == &"drop" and C.has_drop:
			var u := _n(C.state_t / SinewCrawler.DROP_WIND)
			FxBeam.place_ring(ring, C.drop_target + Vector3(0.0, 0.07, 0.0), SinewCrawler.DROP_R * (1.25 - 0.25 * u), 0.35 + 0.4 * absf(sin((t + phase) * 14.0)))
		else:
			ring.visible = false
		if dead and C.dead_t > 5.0:
			batch.clear_row(row)
			return
		update_bar(dt, 1.4, 0.86 / 0.86, 1.0, true)
		pose.compose(Transform3D(Basis(quat), Vector3(C.x, C.y, C.z)))
		upload()


## JS BlisterBloatView: a jelly sac: hits make it wobble (an under-damped squash spring), it leans and lags behind its drift, its tendrils trail the motion. FUSE (0.7 s): it sucks in first (anticipation), then swells hard, shuddering, blisters bulging. BURST: a stretched pop frame, then gone in a green spray (the AI leaves the cloud). It inflates from nothing with an elastic overshoot when it appears.
class BloatView:
	extends CreatureView
	const CH_CORE := 0
	static var _model: CreatureModel = null
	var phase := randf() * 6.0
	var t := 0.0
	var age := 0.0
	var prev_flash := 0.0
	var prev_state: StringName
	var popped := false
	var last_pos: Vector3
	var jelly := AnimKit.Spring.new(170.0, 0.18)
	var drift := AnimKit.Spring3.new(30.0, 0.35)
	var tail_lag := AnimKit.Spring3.new(20.0, 0.4)
	var j_sac: int
	var j_core: int
	var notes: Array = []      # { n, ph, s }
	var tails: Array = []      # { segs, ph }
	var cloud: MeshInstance3D

	static func get_model() -> CreatureModel:
		if _model == null:
			_model = CreatureModel.build("res://assets/objects/enemy_bloat.glb", _glow)
			_model.clear_mat.set_shader_parameter(&"base_emit", Vector3(0.16, 0.2, 0.02))
			_model.clear_mat.set_shader_parameter(&"flash_tint", Vector3(0.8, 0.5, 0.0))
		return _model

	static func _glow(s: RobotGfx.SpriteSoup, m: CreatureModel) -> void:
		s.sprite(m.names["sac"], CH_CORE, Vector3.ZERO, 1.4)

	func _init(p_r: BlisterBloat) -> void:
		super._init(p_r, get_model())
		var n: Dictionary = model.names
		j_sac = n["sac"]
		j_core = n["core"]
		j_spine = j_sac
		j_el_l = j_sac
		j_muzzle = j_core
		var r := RandomNumberGenerator.new()
		r.seed = R.id + 7
		for i in 9:
			notes.append({"n": n["note%d" % i], "ph": r.randf() * 6.0})
		for i in 4:
			var segs: Array = []
			for k in 4:
				segs.append(n["t%d%d" % [i, k]])
			tails.append({"segs": segs, "ph": float(i)})
		prev_state = R.state
		last_pos = Vector3(R.x, R.y, R.z)
		var d := batch.data
		var o := row * batch.stride
		_col(d, o + 16, 0xd0ff50)
		d[o + 12 + CH_CORE] = 1.0
		cloud = FxBeam.cloud(0x9ad040)

	func dispose() -> void:
		super.dispose()
		if is_instance_valid(cloud):
			cloud.queue_free()

	func update(dt: float, _now: float, fx: Variant) -> void:
		var B := R as BlisterBloat
		t += dt
		age += dt
		var tt := t + phase
		var st := B.state
		var dead := st == &"dead"
		var d := batch.data
		var o := row * batch.stride
		d[o] = B.flash
		if B.flash > prev_flash + 0.2:
			jelly.kick(-6.0)
		prev_flash = B.flash
		var v := Vector3(B.x - last_pos.x, B.y - last_pos.y, B.z - last_pos.z) / maxf(dt, 1e-4)
		if v.length_squared() > 400.0:
			v = Vector3.ZERO
		last_pos = Vector3(B.x, B.y, B.z)
		drift.step(v.x, v.y, v.z, dt)
		tail_lag.step(-v.x * 0.12, 0.0, -v.z * 0.12, dt)
		var root_b := Basis.from_euler(Vector3(clampf(drift.z.x * 0.08, -0.4, 0.4), B.yaw + sin(tt * 0.6) * 0.3, clampf(-drift.x.x * 0.08, -0.4, 0.4)), EULER_ORDER_YXZ)
		var root := Transform3D(root_b, Vector3(B.x, B.y + sin(tt * 1.7) * 0.08, B.z))
		if (prev_state == &"idle" or prev_state == &"return") and (st == &"pursue" or st == &"alert"):      # notice: it puffs up
			jelly.kick(5.0)
			AnimKit.cue(fx, B, "inhale", 0.4)
		var fu := _n(B.state_t / BlisterBloat.FUSE) if st == &"windup" else 0.0
		var suck := AnimKit.pulse(fu, 0.1, 0.12)
		var fuse := AnimKit.win(fu, 0.18, 1.0)
		if st == &"windup" and prev_state != &"windup":
			AnimKit.cue(fx, B, "inhale", BlisterBloat.FUSE)
		if dead and not popped:
			popped = true
			AnimKit.cue(fx, B, "squelch")
			if fx != null:
				fx._blood_spray(pose.world[j_core].origin, 0.0, 0.0, 14, 4.0, true)
		if not dead:
			popped = false
		prev_state = st
		var inflate := 1.0 if dead else 0.15 + 0.85 * AnimKit.out_elastic(minf(1.0, age / 0.7))
		var j := jelly.step(0.0, dt)
		var pop_u := B.dead_t / 0.08 if dead else 0.0
		var has_fuse := fuse != 0.0
		var sw := (1.0 + 0.45 * fuse - 0.12 * suck + sin(tt * (40.0 if has_fuse else 2.4)) * (0.05 if has_fuse else 0.03)) * inflate * (1.0 + 0.35 * minf(1.0, pop_u) if dead else 1.0)
		var visible := not dead or pop_u < 1.0
		pose.scl[j_sac] = Vector3(sw * (1.0 - 0.15 * j), sw * (1.0 - 0.06 * sin(tt * 2.4)) * (1.0 + 0.25 * j), sw * (1.0 - 0.15 * j)) if visible else Vector3.ONE * 0.0001
		d[o + 16 + 3] = (0.4 + 0.6 * fuse) if visible else 0.0
		var cs := 0.2 + 0.08 * fuse + 0.02 * sin(tt * 6.0)
		pose.scl[j_core] = Vector3(cs, cs, cs)
		for N: Dictionary in notes:
			var ph: float = N.ph
			var ns := (0.12 + 0.05 * sin(ph * 3.0)) * (1.0 + (0.9 if has_fuse else 0.15) * (0.5 + 0.5 * sin(tt * (30.0 if has_fuse else 3.0) + ph)))
			pose.scl[N.n] = Vector3(ns, ns, ns)
		for T: Dictionary in tails:
			var k := 0
			for jn: int in T.segs:
				var tp: float = T.ph
				pose.euler(jn, sin(tt * 2.0 + tp + k * 0.7) * 0.3 + tail_lag.z.x * (k + 1) * 0.3, 0.0, cos(tt * 1.6 + tp + k) * 0.25 - tail_lag.x.x * (k + 1) * 0.3 + (sin(tt * 35.0 + k) * 0.1 * fuse if has_fuse else 0.0))
				k += 1
		# the spore cloud lives in world space where it popped
		if B.has_cloud:
			var life := _n(B.cloud_t / BlisterBloat.CLOUD_T)
			var grow := 1.0 - life
			FxBeam.place_cloud(cloud, B.cloud, 0.9 + 0.6 * minf(1.0, grow * 4.0), 0.28 * minf(1.0, life * 3.0))
		else:
			cloud.visible = false
		update_bar(dt, 1.7, 0.66 / 0.86, 1.0, true)
		if not visible:
			batch.clear_row(row)
			return
		pose.compose(root)
		upload()
