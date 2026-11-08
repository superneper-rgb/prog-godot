class_name MawViews
extends RefCounted
## The Spire's two mouths on screen: the Maw Ledge (JS enemies/maw-ledge-view.js) and the Maw Nest (JS enemies/maw-nest-view.js), CreatureModels exported from the JS game with the JS views' animation, statement for statement.


## JS MawLedgeView: asleep it is a round fleshy ledge like any other on the spire (a touch too purple), with a lip round its rim, a lidded eye that blinks now and then and a tongue tip that peeks out. When it bites, its back splits along the middle into two jaws that rear up, rows of teeth rise from the lip, and it slams shut. Awake, the eye stays open and red.
class LedgeView:
	extends CreatureView
	const CH_MOUTH := 0
	static var _model: CreatureModel = null
	var phase := randf() * 6.0
	var t := 0.0
	var blink_t := 2.0 + randf() * 4.0
	var blink := 0.0
	var prev_state: StringName
	var prev_st := 0.0
	var sq := AnimKit.Spring.new(260.0, 0.3)
	var hold_t := 0.0
	var j_body: int
	var j_a: int
	var j_b: int
	var j_lid: int
	var j_tongue: int
	var teeth: Array[int] = []

	static func get_model() -> CreatureModel:
		if _model == null:
			_model = CreatureModel.build("res://assets/objects/enemy_mimic.glb", _glow)
			_model.body_mat.set_shader_parameter(&"flash_tint", Vector3(0.8, 0.3, 0.5))
		return _model

	static func _glow(s: RobotGfx.SpriteSoup, m: CreatureModel) -> void:
		s.sprite(m.names["body"], CH_MOUTH, Vector3(0.0, 1.2, 0.0), 1.6)

	func _init(p_r: MawLedge) -> void:
		super._init(p_r, get_model())
		var n: Dictionary = model.names
		j_body = n["body"]
		j_a = n["jawA"]
		j_b = n["jawB"]
		j_lid = n["lid"]
		j_tongue = n["tongue"]
		j_spine = j_body
		j_el_l = n["muzzle"]
		j_muzzle = j_el_l
		for i in 22:
			teeth.append(n["tooth%d" % i])
		prev_state = R.state
		var d := batch.data
		var o := row * batch.stride
		_col(d, o + 16, 0xff3a5a)
		d[o + 12 + CH_MOUTH] = 1.0

	## BITE timeline (the AI's): windup 0.55 s: the lips peel apart and quiver, teeth rise, the whole ledge shudders. attack: the jaws snap wide open (0-0.07 s) and SLAM shut on the 0.11 s damage frame (held contact frame, the ledge squashes, thud + shake). recover 0.9 s: it chews twice and settles.
	func update(dt: float, _now: float, fx: Variant) -> void:
		var M := R as MawLedge
		t += dt
		var tt := t + phase
		var st := M.state
		var dead := st == &"dead"
		var s_t := M.state_t
		var prev_s := prev_st if st == prev_state else -1.0
		prev_state = st
		prev_st = s_t
		var d := batch.data
		var o := row * batch.stride
		d[o] = M.flash
		var root := FleshViews._yaw_root(M.yaw, Vector3(M.x, M.y, M.z))
		var jaw := 0.0
		var tee := 0.0
		var shake := 0.0
		if st == &"windup":
			var u := _n(s_t / MawLedge.WIND)
			jaw = 0.3 * AnimKit.in_out_cubic(u) + 0.04 * sin(tt * 37.0) * u
			tee = u
			shake = u
		elif st == &"attack":
			jaw = 0.3 + 0.95 * AnimKit.out_cubic(s_t / 0.07) if s_t < 0.07 else (1.25 * (1.0 - AnimKit.in_cubic((s_t - 0.07) / 0.04)) if s_t < 0.11 else 0.0)
			tee = 1.0
			if AnimKit.crossed(prev_s, s_t, 0.11):
				sq.kick(7.0)
				hold_t = 0.06
				AnimKit.cue(fx, M, "thud")
				AnimKit.fx_shake(fx, M, 0.4, 10.0)
		elif st == &"recover":
			var u := s_t / 0.9
			tee = maxf(0.0, 1.0 - s_t * 1.5)
			jaw = 0.18 * maxf(0.0, sin(u * PI * 4.0)) * (1.0 - u)      # chews twice
		if dead:
			jaw = 0.5 * minf(1.0, M.dead_t * 2.0)
			tee = 0.3
		pose.euler(j_a, -jaw, 0.0, 0.0)
		pose.euler(j_b, jaw, PI, 0.0)
		for i in teeth.size():
			var tj := teeth[i]
			pose.scl[tj] = Vector3(0.08, maxf(0.001, 0.32 * tee), 0.08)
			var tp := pose.pos[tj]
			tp.y = 1.1 + 0.12 * tee
			pose.pos[tj] = tp
		pose.pos[j_body] = Vector3(sin(tt * 50.0) * 0.04 * shake if shake != 0.0 else 0.0, -minf(0.8, M.dead_t * 0.4) if dead else 0.0, cos(tt * 43.0) * 0.04 * shake if shake != 0.0 else 0.0)
		d[o + 16 + 3] = (0.6 if jaw > 0.05 else 0.0) * (0.0 if dead else 1.0)
		# tells: the eye blinks open now and then (stays open once it is awake), the tongue peeks
		blink_t -= dt
		if blink_t < 0.0:
			blink_t = 4.0 + randf() * 5.0
			blink = 1.0
		blink = maxf(0.0, blink - dt)
		var awake := M.awake or st == &"windup" or st == &"attack"
		var lid_open := 0.0 if dead else (1.0 if awake else (sin(blink * PI) if blink > 0.0 else 0.0))
		var ls := 0.19 * (1.0 - lid_open) + 0.001
		pose.scl[j_lid] = Vector3(ls, ls, ls)
		d[o + 9] = 0.9 if awake else 0.2      # JS irisM.emissive
		var tg := pose.pos[j_tongue]
		tg.z = MawLedge.MIMIC_R * (0.7 + 0.25 * pow(maxf(0.0, sin(tt * 0.7)), 6.0))
		pose.pos[j_tongue] = tg
		pose.scl[j_tongue] = Vector3(0.14, 0.08, 0.25) if not dead else Vector3.ONE * 0.0001
		hold_t = maxf(0.0, hold_t - dt)
		var q_v := sq.step(0.0, 0.0 if hold_t > 0.0 else dt)
		pose.scl[j_body] = Vector3(1.0 + 0.08 * q_v, 1.0 + 0.02 * sin(tt * 1.3) - 0.15 * q_v - (0.3 * minf(1.0, M.dead_t) if dead else 0.0), 1.0 + 0.08 * q_v)
		if dead and M.dead_t > 6.0:
			batch.clear_row(row)
			return
		update_bar(dt, 2.6, 1.26 / 0.86, 1.0, true)
		pose.compose(root)
		upload()


## JS MawNestView: a bloated, ribbed, veined sac of living flesh dragged along on eight spindly fleshy spider legs with bone claws; its front is split into a gaping toothed maw with a lolling lower lip and a whole nest of pink, slimy tongues pouring out, a pulsing throat bladder on its back, dripping slime.
## ENGINE DIFFERENCE: the JS rewrites the tongue tube's vertices in script and draws the legs with InstancedMeshes; here every ring of a tongue and every leg part is a joint of the batch, so one model is one draw and the vertices move on the GPU.
class NestView:
	extends CreatureView
	const CH_MOUTH := 0
	const NLEG := 8
	const NT := 9
	const TS := 7
	const RAD := 6
	const L1 := 1.25
	const L2 := 1.65
	const BODY_Y := 1.75
	const K := 1.3
	const HIPS: Array[Vector3] = [Vector3(0.42, -0.5, 0.62), Vector3(-0.42, -0.5, 0.62), Vector3(0.42, -0.5, 0.2), Vector3(-0.42, -0.5, 0.2), Vector3(0.42, -0.5, -0.2), Vector3(-0.42, -0.5, -0.2), Vector3(0.42, -0.5, -0.6), Vector3(-0.42, -0.5, -0.6)]
	const TORN: Array[int] = [2, 6, 0, 8]
	static var _model: CreatureModel = null
	static var _tongue_data: Array = []

	## JS this.legs
	class Leg:
		var up: int
		var lo: int
		var kn: int
		var hp: int
		var claw: int
		var ball: int
		var knee_out := 1.0
		var grp := 0
		var plant := Vector3.ZERO
		var from := Vector3.ZERO
		var cur := Vector3.ZERO
		var step_t := -1.0
		var init := false

	var phase := randf() * 6.0
	var t := 0.0
	var age := 0.0
	var last_pos: Vector3
	var vel := Vector3.ZERO
	var pop := 0.0
	var last_state: StringName
	var walk_ph := 0.0
	var sink := 0.0
	var step_acc := 0.0
	var legs: Array[Leg] = []
	var feet: Array[Vector3] = []
	var rings: Array = []       # per tongue: the 8 joints
	var pts: Array = []         # per tongue: 8 points
	var j_box: int
	var j_door: int
	var j_flag: int
	var j_bladder: int
	var j_spit: int
	var j_drips: Array[int] = []

	static func _feet_rest() -> Array[Vector3]:
		var out: Array[Vector3] = []
		for h: Vector3 in HIPS:
			out.append(Vector3(h.x * 3.7 + signf(h.x) * 0.08 * absf(h.z), 0.03, h.z * 2.1))
		return out

	## mulberry32, for the same nine tongues as the JS
	static func _mulberry(state: Array) -> float:
		var a: int = (int(state[0]) + 0x6d2b79f5) & 0xffffffff
		state[0] = a
		var t2: int = _imul(a ^ (a >> 15), 1 | a)
		t2 = ((t2 + _imul(t2 ^ (t2 >> 7), 61 | t2)) & 0xffffffff) ^ t2
		return float((t2 ^ (t2 >> 14)) & 0xffffffff) / 4294967296.0

	static func _imul(a: int, b: int) -> int:
		return (a * b) & 0xffffffff

	static func _tongues() -> Array:
		if _tongue_data.is_empty():
			var s := [99]
			for _i in NT:
				var d := {"rx": (_mulberry(s) - 0.5) * 0.7, "ry": (_mulberry(s) - 0.5) * 0.5 - 0.05, "len": 1.5 + _mulberry(s) * 1.1, "r0": 0.065 + _mulberry(s) * 0.03, "ph": _mulberry(s) * 6.28, "fx": 1.6 + _mulberry(s) * 1.6, "fy": 1.2 + _mulberry(s) * 1.4}
				d["sx"] = float(d["rx"]) * 1.5 + (_mulberry(s) - 0.5) * 0.7
				d["sy"] = float(d["ry"]) * 0.9 + 0.12
				_tongue_data.append(d)
		return _tongue_data

	static func get_model() -> CreatureModel:
		if _model == null:
			_model = CreatureModel.build("res://assets/objects/enemy_nest.glb", _glow, {}, {}, _extra)
			_model.body_mat.set_shader_parameter(&"flash_tint", Vector3(0.8, 0.45, 0.3))
		return _model

	static func _glow(s: RobotGfx.SpriteSoup, m: CreatureModel) -> void:
		s.sprite(m.names["mouthG"], CH_MOUTH, Vector3(0.0, 0.0, -0.05), 1.0)

	## The parts the JS moves by hand: rings of the tongues, leg bones. Each gets a joint.
	static func _extra(cm: CreatureModel, P: CreatureModel.Parts) -> void:
		var box: int = cm.names["box"]
		var tongue_row := P.row_named("nestTongue")
		var data := _tongues()
		for i in NT:
			var d: Dictionary = data[i]
			var base := P.v.size()
			var r0: float = d["r0"]
			var slots: Array[int] = []
			for k in TS + 1:
				var slot := cm.add_joint("r%d_%d" % [i, k], box)
				slots.append(slot)
				var dk := float(k) / TS
				var c := Color(lerpf(0.85, 0.64, dk), lerpf(0.35, 0.18, dk), lerpf(0.49, 0.33, dk))
				for j in RAD:
					var an := float(j) / RAD * TAU
					P.v.append(Vector3(cos(an), sin(an), 0.0))
					P.nor.append(Vector3(cos(an), sin(an), 0.0))
					P.uv.append(Vector2.ZERO)
					P.uv2.append(Vector2(slot, tongue_row))
					P.col.append(c)
			var tip := P.v.size()
			P.v.append(Vector3(0.0, 0.0, r0 * lerpf(1.0, 0.38, 1.0) * 0.9))
			P.nor.append(Vector3(0.0, 0.0, 1.0))
			P.uv.append(Vector2.ZERO)
			P.uv2.append(Vector2(slots[TS], tongue_row))
			P.col.append(Color(0.6, 0.16, 0.3))
			for k in TS:
				for j in RAD:
					var a0 := base + k * RAD + j
					var a1 := base + k * RAD + (j + 1) % RAD
					var c0 := a0 + RAD
					var c1 := a1 + RAD
					P.ix.append_array([a0, c0, a1, a1, c0, c1])
			for j in RAD:
				P.ix.append_array([base + TS * RAD + j, tip, base + TS * RAD + (j + 1) % RAD])
		var flesh := P.row_named("nestFlesh")
		var dark := P.row_named("nestDark")
		var bone := P.row_named("nestBone")
		var cyl := MeshBuild.cylinder(1.0, 1.0, 1.0, 8)
		var lo := MeshBuild.sphere(1.0, 9, 6)
		var cone := MeshBuild.cylinder(0.0, 1.0, 1.0, 6)
		for i in NLEG:
			_part(P, cm.add_joint("up%d" % i, -1), cyl, flesh)
			_part(P, cm.add_joint("lo%d" % i, -1), cyl, flesh)
			_part(P, cm.add_joint("kn%d" % i, -1), lo, dark)
			_part(P, cm.add_joint("hp%d" % i, -1), lo, dark)
			_part(P, cm.add_joint("ball%d" % i, -1), lo, dark)
			_part(P, cm.add_joint("claw%d" % i, -1), cone, bone)

	static func _part(P: CreatureModel.Parts, slot: int, g: MeshBuild.Geo, row: int) -> void:
		var base := P.v.size()
		for i in g.pos.size():
			P.v.append(g.pos[i])
			P.nor.append(g.nor[i])
			P.uv.append(Vector2.ZERO)
			P.uv2.append(Vector2(slot, row))
			P.col.append(Color.WHITE)
		var i := 0
		while i < g.idx.size():      # three.js winds counter-clockwise, Godot's front faces are clockwise
			P.ix.append_array([base + g.idx[i], base + g.idx[i + 2], base + g.idx[i + 1]])
			i += 3

	func _init(p_r: MawNest) -> void:
		super._init(p_r, get_model())
		var n: Dictionary = model.names
		j_box = n["box"]
		j_door = n["door"]
		j_flag = n["flag"]
		j_bladder = n["bladder"]
		j_spit = n["spit"]
		j_spine = j_box
		j_el_l = n["mouthG"]
		j_muzzle = n["muzzle"]
		for i in 9:
			j_drips.append(n["drip%d" % i])
		for i in NT:
			var rs: Array[int] = []
			var ps: Array[Vector3] = []
			for k in TS + 1:
				rs.append(n["r%d_%d" % [i, k]])
				ps.append(Vector3.ZERO)
			rings.append(rs)
			pts.append(ps)
		for i in NLEG:
			var L := Leg.new()
			L.up = n["up%d" % i]
			L.lo = n["lo%d" % i]
			L.kn = n["kn%d" % i]
			L.hp = n["hp%d" % i]
			L.ball = n["ball%d" % i]
			L.claw = n["claw%d" % i]
			L.knee_out = 1.0 if HIPS[i].x > 0.0 else -1.0
			L.grp = (i & 1) ^ ((i >> 1) & 1)
			pose.scl[L.kn] = Vector3.ONE * 0.1
			pose.scl[L.hp] = Vector3(0.13, 0.12, 0.13)
			pose.scl[L.claw] = Vector3(0.06, 0.22, 0.06)
			pose.scl[L.ball] = Vector3.ONE * 0.075
			legs.append(L)
			feet.append(Vector3.ZERO)
		last_pos = Vector3(R.x, R.y, R.z)
		last_state = R.state
		var d := batch.data
		var o := row * batch.stride
		_col(d, o + 16, 0xff3a5a)

	func _on_respawn() -> void:
		q.clear()
		pop = 0.0
		sink = 0.0
		age = 0.0
		for L: Leg in legs:
			L.init = false

	## stretch a unit cylinder between two points
	func _place(j: int, a: Vector3, b: Vector3, rd: float) -> void:
		var dv := b - a
		var l := dv.length()
		if l == 0.0:
			l = 1e-4
		pose.pos[j] = (a + b) * 0.5
		pose.scl[j] = Vector3(rd, l, rd)
		pose.rot[j] = _from_up(dv / l)

	static func _from_up(v: Vector3) -> Basis:
		if v.dot(Vector3.UP) < -0.99999:
			return Basis(Vector3.RIGHT, PI)
		return Basis(Quaternion(Vector3.UP, v))

	func update(dt: float, now: float, fx: Variant) -> void:
		var N := R as MawNest
		t += dt
		age += dt
		var tt := t + phase
		var wv := Vector3(N.x - last_pos.x, 0.0, N.z - last_pos.z) / maxf(dt, 1e-4)
		if wv.length_squared() > 900.0:
			wv = Vector3.ZERO
		vel = vel.lerp(wv, 1.0 - exp(-10.0 * dt))
		last_pos = Vector3(N.x, N.y, N.z)
		if N.state != last_state:
			if last_state == &"dead" and N.state != &"dead":
				_on_respawn()
			if N.state == &"attack" and N.atk == &"whip":
				AnimKit.cue(fx, N, "whoosh")
			if N.state == &"windup" and N.atk == &"call":
				AnimKit.cue(fx, N, "inhale", 1.0)
			last_state = N.state
		var dead := N.state == &"dead"
		var st := N.state_t
		sink = (N.dead_t - 9.0) * 0.35 if dead and N.dead_t > 9.0 else 0.0
		if sink >= 1.4:
			batch.clear_row(row)
			return
		pop = 1.0 if dead else minf(1.0, pop + dt * 2.2)
		var gs := 1.0 if dead else 0.55 + 0.45 * AnimKit.out_back(pop, 2.0)
		var sn := sin(N.yaw)
		var cs := cos(N.yaw)
		var root := Transform3D(Basis(Vector3(cs * gs, 0.0, -sn * gs), Vector3(0.0, gs, 0.0), Vector3(sn * gs, 0.0, cs * gs)), Vector3(N.x, N.y - sink, N.z))
		var unfold := 1.0 if dead else AnimKit.win(age, 0.15, 0.7)
		var curl := AnimKit.win(N.dead_t, 0.5, 1.4) if dead else 1.0 - unfold      # legs fold up under it: unfolding on spawn, curling up dead like a spider
		var d := batch.data
		var o := row * batch.stride
		d[o] = N.flash
		var fwd := N.lvz
		var lat := N.lvx
		var spd := U.hyp(fwd, lat)
		var run := _n(spd / maxf(0.1, MawNest.SPEED))
		walk_ph += dt * (2.2 + spd * 1.6 if spd > 0.2 else 0.0)
		var talking := not dead and N.E != null and N.E.barks != null and N.E.barks.is_talking(N)
		# ---- pose per state ----
		var body_y := BODY_Y + 0.04 * sin(tt * 2.1)
		var body_z := 0.0
		var pitch := 0.0
		var roll := 0.0
		var door := 0.9
		var t_stretch := 1.0
		var t_grav := 1.3
		var t_amp := 0.45
		var t_spread := 1.0
		var flag := -1.5
		var shake := 0.0
		var spit := 0.0
		var mouth_open := 0.3
		var rate := 8.0
		match N.state:
			&"alert":
				var u := _n(st / 0.3)
				body_y += 0.15 * sin(u * PI)
				pitch = -0.1 * sin(u * PI)
				door = 1.2
				t_grav = 0.3
				t_amp = 0.7
				flag = -0.8
				rate = 14.0
			&"pursue":
				body_y -= 0.12 * run
				pitch = 0.06 * run
				roll = -lat * 0.025
				door = 1.0
				t_grav = 0.45
				t_amp = 0.5 + 0.4 * run
				t_spread = 1.25
				flag = -1.0
			&"windup":
				var u := _n(N.a_u)
				var e := _ease(u)
				if N.atk == &"whip":
					body_y -= 0.25 * e
					body_z = -0.3 * e
					pitch = -0.12 * e
					door = 1.3
					t_stretch = lerpf(1.0, 0.45, e)
					t_grav = lerpf(1.3, -0.7, e)
					t_amp = 0.5
					t_spread = 1.4
					mouth_open = 0.7 + 0.3 * e
					rate = 16.0
				elif N.atk == &"call":
					body_y += 0.35 * e
					pitch = -0.28 * e
					door = 1.5
					t_stretch = 1.15
					t_grav = lerpf(1.3, -0.7, e)
					t_amp = 1.0
					t_spread = 1.8
					flag = lerpf(-1.5, 0.15, e)
					shake = 0.025 * e
					mouth_open = 1.0
					rate = 12.0
				else:
					body_y += 0.1 * e
					body_z = -0.25 * e
					pitch = -0.3 * e
					door = 1.45
					t_stretch = 0.65
					t_grav = 0.6
					t_amp = 0.5
					t_spread = 2.3 - 0.4 * e
					spit = e
					mouth_open = 0.8 + 0.2 * e
					shake = 0.012 * e
					rate = 14.0
			&"attack":
				var u := _n(N.a_u)
				if N.atk == &"whip":
					var k := _ease(_n(u / 0.25))
					body_y -= 0.3 * k
					body_z = lerpf(-0.3, 0.7, k)
					pitch = lerpf(-0.12, 0.2, k)
					door = 1.35
					t_stretch = lerpf(0.45, 2.2, k)
					t_grav = lerpf(-0.7, 0.05, k)
					t_amp = lerpf(0.8, 0.12, k)
					t_spread = 0.8
					mouth_open = 1.0
					rate = 40.0
				elif N.atk == &"call":
					body_y += 0.35
					pitch = -0.28
					door = 1.5
					t_stretch = 1.15
					t_grav = -0.7
					t_amp = 1.1
					t_spread = 1.8
					flag = 0.1 + 0.2 * sin(tt * 40.0)
					shake = 0.03
					mouth_open = 1.0
				else:
					body_y += 0.1
					body_z = 0.15 * (1.0 - u)
					pitch = -0.1
					door = 1.45
					t_stretch = 0.7
					t_grav = 0.6
					t_spread = 2.2
					spit = 1.0 - u * 1.5
					mouth_open = 1.0
					rate = 30.0
			&"recover":
				var u := _n(N.a_u)
				var e := _ease(u)
				if N.atk == &"whip":
					body_z = lerpf(0.7, 0.0, e)
					body_y -= 0.3 * (1.0 - e)
					pitch = lerpf(0.2, 0.0, e)
					t_stretch = lerpf(2.0, 1.0, e)
					t_grav = lerpf(0.1, 1.3, e)
					t_amp = lerpf(0.2, 0.35, e)
					door = 1.2
				elif N.atk == &"call":
					body_y += 0.35 * (1.0 - e)
					pitch = -0.28 * (1.0 - e)
					flag = lerpf(0.1, -1.5, e)
					t_grav = lerpf(-0.4, 1.3, e)
					t_amp = lerpf(1.0, 0.35, e)
					door = lerpf(1.5, 0.9, e)
					mouth_open = 1.0 - 0.7 * e
				else:
					body_y += 0.1 * (1.0 - e)
					pitch = -0.1 * (1.0 - e)
					t_stretch = lerpf(0.7, 1.0, e)
					t_spread = lerpf(2.2, 1.0, e)
					door = lerpf(1.45, 0.9, e)
					mouth_open = 1.0 - 0.7 * e
				rate = 8.0
			&"stagger":
				var u := _n(st / 0.55)
				var env := u / 0.12 if u < 0.12 else 1.0 - (u - 0.12) / 0.88
				body_y += 0.1 * env
				pitch = -0.2 * env
				roll = 0.15 * env
				t_amp = 1.3
				t_grav = 0.2
				t_stretch = 1.2
				door = 1.5
				mouth_open = 1.0
				rate = 22.0
			&"search":
				t_grav = 0.7
				t_amp = 0.4
			&"dead":
				var k := _ease(_n(N.dead_t / 0.8))
				body_y = lerpf(BODY_Y, 0.55, k)
				pitch = 0.12 * k
				roll = 0.45 * k
				door = lerpf(0.9, 1.6, k)
				t_grav = 1.5
				t_amp = 0.05
				t_stretch = 0.85
				flag = -1.5
				mouth_open = 1.0
				rate = 9.0
		if N.flinch_t > 0.0 and not dead:
			var p := N.flinch_t / 0.18
			body_y += 0.08 * p
			pitch -= 0.12 * p
		body_y = _qq(&"by", body_y, rate, dt)
		body_z = _qq(&"bz", body_z, rate, dt)
		pitch = _qq(&"pt", pitch, rate, dt)
		roll = _qq(&"rl", roll, 8.0, dt)
		door = _qq(&"dr", door, 14.0, dt)
		t_stretch = _qq(&"ts", t_stretch, rate + 6.0, dt)
		t_grav = _qq(&"tg", t_grav, rate, dt)
		t_amp = _qq(&"ta", t_amp, 8.0, dt)
		t_spread = _qq(&"tsp", t_spread, 10.0, dt)
		flag = _qq(&"fl", flag, 10.0, dt)
		var shk := sin(tt * 80.0) * shake if shake != 0.0 else 0.0
		var talk := 0.2 * absf(sin(tt * 11.0)) if talking else 0.0
		var open := clampf(mouth_open + talk, 0.0, 1.0)
		# ---- body ----
		pose.pos[j_box] = Vector3(shk, body_y + (0.05 * sin(walk_ph * 2.0) if spd > 0.5 else 0.0), body_z)
		pose.euler(j_box, pitch, 0.0, roll + (0.03 * sin(walk_ph) if spd > 0.5 else 0.0))
		pose.euler(j_door, 1.25 + door * 0.8, 0.0, 0.0)
		pose.euler(j_flag, 0.0, 0.0, flag + (0.15 * sin(tt * 18.0) if flag > -0.5 else 0.0))
		var calling := N.atk == &"call" and (N.state == &"windup" or N.state == &"attack")
		pose.scl[j_bladder] = Vector3(0.26 * (1.0 + 0.5 * spit + (0.4 if calling else 0.0)), 0.22 * (1.0 + 0.6 * spit) + 0.02 * sin(tt * 3.0), 0.34)
		d[o + 16 + 3] = 0.0 if dead else 0.25 + 0.5 * open + 0.3 * spit
		d[o + 12 + CH_MOUTH] = 0.5 + 0.7 * open
		# ---- the dart forming in the mouth ----
		var sp_s := 0.3 + 0.9 * _n(spit) if spit > 0.05 else 0.0001
		pose.scl[j_spit] = Vector3(sp_s, sp_s, sp_s)
		pose.pos[j_spit] = Vector3(0.0, 0.0, 0.1 + 0.5 * _n(1.0 - spit))
		pose.euler(j_spit, 0.0, 0.0, tt * 10.0)
		# ---- legs: world-planted feet stepping in two alternating groups, IK from hips that ride the (tilted) belly ----
		var inv := root.affine_inverse()
		var feet_rest := _feet_rest()
		var speed_w := U.hyp(vel.x, vel.z)
		var step_dur := 0.17 if speed_w > 3.0 else 0.24
		var airborne := dead or unfold < 1.0
		var busy: Array[bool] = [false, false]
		var want := -1
		var want_err := 0.0
		for L: Leg in legs:
			if L.step_t >= 0.0:
				busy[L.grp] = true
		for i in NLEG:
			var L := legs[i]
			var f := feet_rest[i]
			var v := root * Vector3(f.x, 0.0, f.z)
			v.y = N.y
			v += vel * 0.2
			if not L.init or airborne:
				L.plant = v
				L.cur = v
				L.step_t = -1.0
				L.init = true
			elif L.step_t >= 0.0:
				L.step_t += dt / step_dur
				var u := AnimKit.in_out_sine(minf(1.0, L.step_t))
				L.cur = L.from.lerp(v, u)
				L.cur.y += sin(PI * minf(1.0, L.step_t)) * 0.35
				if L.step_t >= 1.0:
					L.step_t = -1.0
					L.plant = v
					L.cur = v
			else:
				L.cur = L.plant
				var e := U.hyp(v.x - L.plant.x, v.z - L.plant.z)
				if e > 0.55 and not busy[1 - L.grp] and e > want_err:
					want_err = e
					want = L.grp
		if want >= 0:
			for L: Leg in legs:
				if L.grp == want and L.step_t < 0.0:
					L.step_t = 0.0
					L.from = L.plant
		for i in NLEG:
			var v := inv * legs[i].cur
			feet[i] = Vector3(v.x, maxf(0.03, v.y + 0.03), v.z)
		var acc0 := step_acc
		step_acc += speed_w * dt
		if AnimKit.crossed(acc0, step_acc, floorf(step_acc / 1.1) * 1.1) and speed_w > 1.0 and not dead and fx != null and fx.has_method(&"scream_step"):
			fx.scream_step(self, speed_w)
		var cp := cos(pitch)
		var sp := sin(pitch)
		var cr := cos(roll)
		var sr := sin(roll)
		var by := pose.pos[j_box].y
		var bz := pose.pos[j_box].z
		for i in NLEG:
			var L := legs[i]
			var h0 := HIPS[i]
			var hx := h0.x * K
			var hy := h0.y * K
			var hz := h0.z * K
			var y1 := hy * cp - hz * sp      # pitch then roll
			var z1 := hy * sp + hz * cp
			hy = y1
			hz = z1
			var x2 := hx * cr - hy * sr
			var y2 := hx * sr + hy * cr
			hx = x2
			hy = y2
			var hip := Vector3(hx, hy + by, hz + bz)
			# planted feet: each foot stays where it landed (world space) until it trails its rest spot by > 0.55 m, then steps (two alternating groups)
			var foot := feet[i]
			if curl > 0.001:
				var tw := 0.12 * sin(tt * 17.0 + i * 1.7) * (1.0 - AnimKit.win(N.dead_t, 1.6, 3.5)) if dead else 0.0
				foot = foot.lerp(Vector3(hip.x * 1.15, hip.y + 0.45 + tw, hip.z * 0.6 + 0.1), curl)
			# two-bone IK (knee pushed up and outward)
			var dv := foot - hip
			var dist := dv.length()
			if dist == 0.0:
				dist = 1e-4
			dv /= dist
			dist = clampf(dist, absf(L1 - L2) + 0.02, L1 + L2 - 0.02)
			var a := (L1 * L1 - L2 * L2 + dist * dist) / (2.0 * dist)
			var hh := sqrt(maxf(0.0, L1 * L1 - a * a))
			var px0 := L.knee_out * 0.35
			var py0 := 1.7
			var pd := px0 * dv.x + py0 * dv.y
			var qv := Vector3(px0 - dv.x * pd, py0 - dv.y * pd, -dv.z * pd)
			var ql := qv.length()
			qv /= ql if ql != 0.0 else 1.0
			var knee := hip + dv * a + qv * hh
			var end := hip + dv * dist
			_place(L.up, hip, knee, 0.075)
			_place(L.lo, knee, end, 0.055)
			pose.pos[L.kn] = knee
			pose.pos[L.hp] = hip
			pose.pos[L.ball] = end
			pose.pos[L.claw] = Vector3(end.x, end.y - 0.1, end.z)
			pose.rot[L.claw] = Basis(Vector3.RIGHT, PI)      # bone claw pointing down
		# ---- tongues ----
		var data := _tongues()
		var hp_f := N.hp / N.max if N.max != 0.0 else 1.0
		var n_t := 4 if hp_f < 0.3 else (2 if hp_f < 0.6 else 0)      # damage: tongues are shot down to stumps
		for i in NT:
			var tn: Dictionary = data[i]
			var p: Array[Vector3] = pts[i]
			var seg: float = float(tn.len) * t_stretch / TS
			p[0] = Vector3(float(tn.rx) * 0.8, -0.02 + float(tn.ry) * 0.7, 0.9 - 0.1)
			var hd := Vector3(float(tn.sx) * t_spread, float(tn.sy) * t_spread, 1.0 - (1.1 if t_stretch < 0.6 else 0.0)).normalized()
			for k in range(1, TS + 1):
				var sk := float(k) / TS
				var wx := sin(tt * float(tn.fx) + k * 0.75 + float(tn.ph)) * t_amp * sk
				var wy := cos(tt * float(tn.fy) + k * 0.6 + float(tn.ph) * 1.3) * t_amp * 0.6 * sk
				var dv := Vector3(hd.x + wx, hd.y - t_grav * sk * 1.5 + wy, hd.z).normalized()
				p[k] = p[k - 1] + dv * seg
				hd = (hd * 0.5 + dv * 0.5).normalized()
			var torn := TORN.find(i)
			if torn >= 0 and torn < n_t:
				var at := p[1] + (p[2] - p[1]) * 0.4
				for k in range(2, TS + 1):
					p[k] = Vector3(at.x, at.y - (k - 2) * 0.002, at.z + (k - 2) * 0.002)
			var rs: Array[int] = rings[i]
			var r0: float = tn.r0
			for k in TS + 1:
				var a := p[maxi(0, k - 1)]
				var c := p[mini(TS, k + 1)]
				var tv := (c - a).normalized()
				var nv := Vector3(tv.y * 0.0 - tv.z * 1.0, tv.z * 0.0 - tv.x * 0.0, tv.x * 1.0 - tv.y * 0.0)      # N = T x up
				var nl := nv.length()
				if nl < 1e-4:
					nv = Vector3.RIGHT
				else:
					nv /= nl
				var bv := nv.cross(tv)
				var rk := r0 * lerpf(1.0, 0.38, float(k) / TS)
				pose.rot[rs[k]] = Basis(nv, -bv, tv)      # (right-handed, the ring is symmetrical)
				pose.scl[rs[k]] = Vector3(rk, rk * 0.7, 1.0)      # slightly flattened, like a tongue
				pose.pos[rs[k]] = p[k]
		# ---- slime drips falling off the rim and belly ----
		for i in 9:
			var ph := i * 0.37
			var u := fmod(tt * 0.45 + ph, 1.0)
			var dj := j_drips[i]
			pose.pos[dj] = Vector3((float(i) / 8.0 - 0.5) * 1.0, -0.4 - (i % 3) * 0.1 - u * 0.8 + 0.05, 0.86 - (i % 3) * 0.5)
			pose.scl[dj] = Vector3(0.03, 0.04 + 0.06 * sin(u * PI), 0.03) if not dead or N.dead_t < 4.0 else Vector3.ONE * 0.0001
		update_bar(dt, 3.0 * gs, 1.06 / 0.86, 1.0, true)
		if d[o + 43] >= 0.0:      # (the JS's own hue for this bar)
			var f := maxf(0.0, N.hp / N.max)
			var bc := _hsl(0.95 - 0.05 * (1.0 - f), 0.85, 0.6)
			d[o + 40] = bc.r
			d[o + 41] = bc.g
			d[o + 42] = bc.b
		pose.compose(root)
		upload()
