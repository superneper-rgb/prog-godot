class_name MarrowWardenView
extends CreatureView
## THE MARROW WARDEN on screen (JS enemies/marrow-warden-view.js): a hunched reliquary-tick. A tall crown of hooked ribs rises over its back and cages a glowing heart, over overlapping bone armour bands, on six long IK-planted legs whose knees ride above the body. A low skull head with an underbite, tusks on the jaw and ember-pinpoint eyes in deep sockets. Heavy and deliberate: feet stay planted in world space and step in a tripod gait; every move winds up visibly, strikes past its pose and settles through springs. Fissures burn hotter as it loses health; at each phase roar it sheds armour bands, phase 3 breaks ribs and a tusk. Death in stages: thrash, the cage bursts and the heart ruptures, the legs buckle one by one, it deflates, twitches and sinks into the pit.
## Every pose is keyed off the AI's own timers, so gameplay timing and the hitbox are untouched.
## ENGINE DIFFERENCE: the fissures' colour stays at the JS's phase 1 value (the JS tints it a little warmer per phase); their brightness is exact.

const L1 := 1.95
const L2 := 2.75
const BODY_Y := 1.6
const CH_EMBER := 0
const CH_WELL := 1
const CH_SMEAR := 2
const SHED := {2: [2, 5], 3: [1, 4]}      # bands shed at the phase-2 / phase-3 roar
const ZS: Array[float] = [0.95, -0.25, -1.45]

static var _model: CreatureModel = null

## JS this.legs
class Leg:
	var hip: int
	var knee: int
	var sx: float
	var i: int
	var grp: int
	var rest: Vector3
	var plant := Vector3.ZERO
	var from := Vector3.ZERO
	var to := Vector3.ZERO
	var cur := Vector3.ZERO
	var step_t := -1.0
	var init := false

var t := 0.0
var age := 0.0
var hold_t := 0.0
var prev_hop := 0.0
var prev_flash := 0.0
var prev_mt := 0.0
var prev_dead := 0.0
var notice_t := 9.0
var prev_state: StringName
var spin := 0.0
var last_pos: Vector3
var vel := Vector3.ZERO
var yaw_prev := 0.0
var yaw_rate := 0.0

var j_body: int
var j_abd: int
var j_head: int
var j_jaw: int
var j_throat: int
var j_heart: int
var j_cage_l: int
var j_cage_r: int
var j_sweep: int
var j_smear: int
var eyes: Array = []       # [joint, r]
var tusks: Array[int] = []
var mands: Array = []      # [joint, sx]
var bands: Array = []      # { j, i, home, out, spin }
var ribs: Array = []       # { j, sx, i }
var spines: Array = []     # [joint, r0]
var sacs: Array = []       # { j, s, ph }
var legs: Array[Leg] = []
var rings: Array[MeshInstance3D] = []
var streak: MeshInstance3D
var rim: MeshInstance3D
var cracks: FxBeam.Cracks

var sp_lift := AnimKit.Spring.new(80.0, 0.55)
var sp_y := AnimKit.Spring.new(140.0, 0.45)
var sp_sq := AnimKit.Spring.new(260.0, 0.28)
var sp_fwd := AnimKit.Spring.new(160.0, 0.4)
var sp_roll := AnimKit.Spring.new(120.0, 0.45)
var sp_twist := AnimKit.Spring.new(150.0, 0.42)
var sp_head_p := AnimKit.Spring.new(150.0, 0.42)
var sp_head_r := AnimKit.Spring.new(130.0, 0.4)
var sp_look := AnimKit.Spring.new(60.0, 0.75)
var sp_jaw := AnimKit.Spring.new(320.0, 0.32)
var sp_cage := AnimKit.Spring.new(110.0, 0.38)
var sp_throat := AnimKit.Spring.new(140.0, 0.45)
var sp_tuck := AnimKit.Spring.new(140.0, 0.6)
var sp_rear := AnimKit.Spring.new(90.0, 0.5)
var sp_splay := AnimKit.Spring.new(90.0, 0.6)
var react := AnimKit.Reaction.new(150.0, 0.3)
var blink: AnimKit.Blink
var fidget: AnimKit.Fidget


static func get_model() -> CreatureModel:
	if _model == null:
		_model = CreatureModel.build("res://assets/objects/enemy_warden.glb", _glow, {"smear": CH_SMEAR}, {"wardenEmber": 1})
		_model.body_mat.set_shader_parameter(&"flash_tint", Vector3(0.6, 0.25, 0.2))
	return _model


static func _glow(s: RobotGfx.SpriteSoup, m: CreatureModel) -> void:
	s.sprite(m.names["block"], CH_EMBER, Vector3(0.0, 0.2, 1.05), 1.4)
	s.sprite(m.names["well"], CH_WELL, Vector3(0.0, 0.5, 0.0), 3.4)


func _init(p_r: MarrowWarden) -> void:
	super._init(p_r, get_model())
	var n: Dictionary = model.names
	j_body = n["body"]
	j_abd = n["abd"]
	j_head = n["head"]
	j_jaw = n["jaw"]
	j_throat = n["throat"]
	j_heart = n["heart"]
	j_cage_l = n["cageL"]
	j_cage_r = n["cageR"]
	j_sweep = n["sweepG"]
	j_smear = n["smear"]
	j_spine = j_body
	j_el_l = j_head
	j_muzzle = n["muzzle"]
	var eye_r: Array[float] = [0.17, 0.17, 0.07, 0.06, 0.055]
	for i in 5:
		eyes.append([n["eye%d" % i], eye_r[i]])
	tusks = [n["tusk0"], n["tusk1"]]
	mands = [[n["mand0"], -1.0], [n["mand1"], 1.0]]
	var rs := RandomNumberGenerator.new()
	rs.seed = 4177
	for i in 7:
		var bj: int = n["band%d" % i]
		bands.append({"j": bj, "i": i, "home": pose.pos[bj], "out": Vector3(rs.randf() - 0.5, 1.0, rs.randf() - 0.5).normalized(), "spin": rs.randf() * 4.0 - 2.0})
	for side in 2:
		for i in 6:
			ribs.append({"j": n["rib%d%d" % [side, i]], "sx": -1.0 if side == 0 else 1.0, "i": i})
	for i in 5:
		spines.append([n["spine%d" % i], -0.6 - i * 0.12])
	var sac_r: Array[float] = [0.36, 0.28, 0.24, 0.2]
	var sac_p: Array[float] = [1.85 * 7.0 - 0.7 * 3.0, 1.9 * 7.0 - 1.2 * 3.0, 1.7 * 7.0 - 1.3 * 3.0, 1.9 * 7.0 - 0.25 * 3.0]
	for i in 4:
		sacs.append({"j": n["sac%d" % i], "s": sac_r[i], "ph": sac_p[i]})
	var li := 0
	for i in 3:
		for sx: float in [-1.0, 1.0]:
			var L := Leg.new()
			L.hip = n["hip%d" % li]
			L.knee = n["knee%d" % li]
			L.sx = sx
			L.i = i
			L.grp = (i + (1 if sx > 0.0 else 0)) % 2
			L.rest = Vector3(sx * (3.2 if i == 0 else 3.6), -BODY_Y, ZS[i] * 1.45 + (0.6 if i == 0 else 0.0))
			legs.append(L)
			li += 1
	prev_state = R.state
	last_pos = Vector3(R.x, R.y, R.z)
	yaw_prev = R.yaw
	blink = AnimKit.Blink.new(2.4, 6.0, 0.16, fmod(R.id * 0.137, 1.0))
	fidget = AnimKit.Fidget.new([2.4, 1.6, 2.6, 2.0], 4.0, 9.0, fmod(R.id * 0.71, 1.0))
	var d := batch.data
	var o := row * batch.stride
	_col(d, o + 16, 0xff5a2a)
	_col(d, o + 20, 0xff4020)
	_col(d, o + 24, 0xff6040)
	d[o + 12 + CH_EMBER] = 1.0
	d[o + 12 + CH_WELL] = 1.0
	for _i in 5:
		rings.append(FxBeam.ring(0xff2840))
	streak = FxBeam.streak(0xff2a3a)
	rim = FxBeam.ring(0xff3040)
	cracks = FxBeam.Cracks.new(5, 4.5)


func dispose() -> void:
	super.dispose()
	for m: MeshInstance3D in rings:
		if is_instance_valid(m):
			m.queue_free()
	if is_instance_valid(streak):
		streak.queue_free()
	if is_instance_valid(rim):
		rim.queue_free()
	cracks.free_all()


func sprite_world(i: int) -> Vector3:
	if i == 0:
		return pose.world[model.names["block"]] * Vector3(0.0, 0.2, 1.05)
	if i == 2:
		return pose.world[model.names["well"]] * Vector3(0.0, 0.5, 0.0)
	return pose.world[j_body].origin


## three.js 'YXZ'
static func _yxz(x: float, y: float, z: float) -> Basis:
	return Basis.from_euler(Vector3(x, y, z), EULER_ORDER_YXZ)


## JS ik: 2-bone IK in the hip's vertical plane: yaw the hip at the foot, raise the femur, bend the knee (knee up)
func _ik(L: Leg, F: Vector3) -> void:
	var H := pose.pos[L.hip]
	var dx := F.x - H.x
	var dy := F.y - H.y
	var dz := F.z - H.z
	var dh := U.hyp(dx, dz)
	var D := maxf(0.6, minf(L1 + L2 - 0.02, U.hyp(dh, dy)))
	var a := atan2(dy, dh)
	var A := acos(clampf((L1 * L1 + D * D - L2 * L2) / (2.0 * L1 * D), -1.0, 1.0))
	var B := acos(clampf((L1 * L1 + L2 * L2 - D * D) / (2.0 * L1 * L2), -1.0, 1.0))
	pose.rot[L.hip] = Basis(Vector3.UP, atan2(-dz, dx)) * Basis(Vector3(0.0, 0.0, 1.0), a + A)
	pose.euler(L.knee, 0.0, 0.0, -(PI - B))


func update(dt: float, _now: float, fx: Variant) -> void:
	var W := R as MarrowWarden
	var st := W.state
	var dead := st == &"dead"
	var mv := &"" if dead else W.mv
	var mt := W.mt
	var ph := W.phase
	t += dt
	age += dt
	var hp_f := _n(W.hp / W.max)
	# ---- events -> one-shot reactions ----
	if W.flash > prev_flash + 0.2 and not dead:      # a new hit: directional flinch, scaled by damage
		var c0 := cos(W.yaw)
		var s0 := sin(W.yaw)
		var k0 := minf(1.0, (W.last_dmg if W.last_dmg != 0.0 else 20.0) / 60.0) * (0.9 if W.exposed else 0.4)
		react.hit(W.hit_x * c0 - W.hit_z * s0, W.hit_x * s0 + W.hit_z * c0, k0)
		sp_jaw.kick(-6.0 * k0)
	prev_flash = W.flash
	var was_idle := prev_state == &"idle" or prev_state == &"return" or prev_state == &"search"
	if was_idle and (st == &"pursue" or st == &"alert"):
		notice_t = 0.0
		AnimKit.cue(fx, W, "roar", 0.8)
	prev_state = st
	notice_t += dt
	if prev_dead != 0.0 and not dead:      # revived (arena reset): play the emergence again
		age = 0.0
		for L: Leg in legs:
			L.init = false
	var spawn_u := age                     # emergence: claws out of the pit floor over ~2 s
	var emerging := not dead and spawn_u < 2.2
	if emerging and AnimKit.crossed(spawn_u - dt, spawn_u, 0.05):
		if fx != null:
			fx.dust(Vector3(W.x, W.y + 0.1, W.z), 14, 3.5)
		AnimKit.cue(fx, W, "crack")
	if emerging and AnimKit.crossed(spawn_u - dt, spawn_u, 1.3):
		AnimKit.cue(fx, W, "roar", 1.0)
	var hop_now := W.hop
	if prev_hop > 0.05 and hop_now <= 0.05 and not dead:      # landing: squash, drop, and a held contact frame
		sp_sq.kick(7.0)
		sp_y.kick(-4.0)
		sp_tuck.snap(0.0)
		sp_splay.snap(0.7)
		hold_t = 0.07
		cracks.place(W.x, W.y, W.z, 5.0)
	prev_hop = hop_now
	hold_t = maxf(0.0, hold_t - dt)
	var sdt := 0.0 if hold_t > 0.0 else dt
	# world velocity (for gait lead and lean) and turn rate
	var vv := Vector3(W.x - last_pos.x, 0.0, W.z - last_pos.z) / maxf(dt, 1e-4)
	if vv.length_squared() > 900.0:
		vv = Vector3.ZERO
	vel = vel.lerp(vv, 1.0 - exp(-8.0 * dt))
	last_pos = Vector3(W.x, W.y, W.z)
	var yr := W.yaw - yaw_prev
	yr = atan2(sin(yr), cos(yr))
	yaw_rate += (yr / maxf(dt, 1e-4) - yaw_rate) * (1.0 - exp(-6.0 * dt))
	yaw_prev = W.yaw
	var speed := U.hyp(vel.x, vel.z)
	var cs := cos(W.yaw)
	var sn := sin(W.yaw)
	var fwd_v := vel.x * sn + vel.z * cs
	# ---- target pose for this frame ----
	var lift := 0.0
	var y := 0.05 * sin(t * 1.3)
	var sq := 0.0
	var fwd := 0.0
	var roll := 0.0
	var twist := 0.0
	var head_p := 0.06 * sin(t * 1.1)
	var head_r := 0.0
	var look := 1.0
	var jaw := 0.12 + 0.05 * sin(t * 2.3)
	var cage := 0.0
	var throat := 0.12 + 0.04 * sin(t * 1.7)
	var tuck := 0.0
	var rear := 0.0
	var splay := 0.0
	var squint := 0.0
	var wide := 0.0
	var bristle := 0.0
	var flare := 0.0
	var shiver := 0.0
	var heave := 0.0
	var brace := 0.0
	var dizzy := 0.0
	# locomotion: lean into turns and acceleration, a heavier bob comes from the stepping legs below
	roll += -yaw_rate * 0.12
	lift += -_n(fwd_v / 3.0) * 0.06
	head_p += _n(speed / 3.0) * 0.08
	# idle fidgets: look around, shiver the spines, scrape the floor with a front leg, lower the head and click the jaw
	fidget.step(dt, mv == &"" and not dead and not emerging and speed < 0.4 and notice_t > 1.2)
	var f0 := fidget.env(0)
	var f1 := fidget.env(1)
	var f2 := fidget.env(2)
	var f3 := fidget.env(3)
	var fu := fidget.u
	var look_around := f0 * sin(fu * PI * 2.0) * 0.7
	shiver += f1
	bristle += f1
	head_p += f3 * 0.35 - f2 * 0.1
	jaw += f3 * 0.35 * absf(sin(fu * PI * 6.0))
	# notice: head snaps round, a short rear and roar, spines up
	if notice_t < 1.1 and not dead:
		var nh := AnimKit.hold(notice_t, 0.12, 0.7, 0.12, 0.35)
		lift += 0.25 * nh
		jaw += 0.75 * nh
		wide += nh
		bristle += nh
		head_p -= 0.3 * nh
		flare += 0.5 * nh
	# the moves (timings mirror marrow_warden.gd)
	if mv == &"leap":
		var lead := MarrowWarden.LEAP_LEAD * (0.9 if ph >= 2 else 1.0)
		var air := MarrowWarden.LEAP_AIR
		var m: MarrowWarden.Mark = null
		for k: MarrowWarden.Mark in W.marks:
			if not k.hit:
				m = k
				break
		if hop_now > 0.05:
			var u := _n(1.0 - ((lead - (mt - m.t0)) / air if m != null else 0.0))
			sq -= 0.16 * (1.0 - AnimKit.win(u, 0.0, 0.35))
			tuck = 0.75
			head_p += lerpf(-0.45, 0.35, u)
			lift += lerpf(0.25, -0.3, u)
			bristle = 1.0
		elif m != null:
			var a2 := mt - m.t0
			var cr := AnimKit.win(a2, lead - air - 0.4, lead - air - 0.04)
			y -= 0.45 * cr
			lift -= 0.15 * cr
			head_p += 0.3 * cr
			squint = cr
			splay = 0.35 * cr
			shiver += cr * 0.4
		var last := -9.0      # recovery after each landing: a slow rise out of the squash
		for k: MarrowWarden.Mark in W.marks:
			if k.hit:
				last = maxf(last, k.t0 + lead)
		var rec := mt - last
		if rec >= 0.0 and rec < 0.45 and hop_now <= 0.05:
			y -= 0.25 * (1.0 - AnimKit.win(rec, 0.05, 0.45))
			head_p += 0.2 * (1.0 - AnimKit.win(rec, 0.0, 0.45))
			splay = 0.5 * (1.0 - AnimKit.win(rec, 0.1, 0.45))
	elif mv == &"spray":
		var v0 := MarrowWarden.SPRAY_V + (1 if ph >= 3 else 0)
		var gap := MarrowWarden.SPRAY_GAP * (0.85 if ph >= 2 else 1.0)
		var wind := MarrowWarden.SPRAY_WIND
		var fire_n := int(floorf((mt - wind) / gap))
		var k := mini(v0 - 1, fire_n)
		var u := mt - (wind + k * gap)
		var inh := AnimKit.win(mt, 0.05, wind - 0.05)
		if mt < wind:
			lift += 0.55 * inh
			head_p -= 0.55 * inh
			throat = 0.15 + 0.9 * inh
			jaw = 0.12 + 0.3 * inh
			squint = inh
			brace = inh
			shiver += 0.3 * AnimKit.win(mt, wind - 0.3, wind)
		elif fire_n < v0:
			var thrust := AnimKit.out_cubic(u / 0.07) if u < 0.07 else 1.0 - AnimKit.win(u, 0.07, 0.5)
			lift += 0.55 - 0.35 * thrust
			head_p += -0.55 + 0.95 * thrust
			fwd += 0.35 * thrust
			jaw = 0.4 + 0.6 * thrust
			throat = 1.0 - 0.8 * AnimKit.win(u, 0.0, 0.12) + 0.8 * AnimKit.win(u, 0.35, gap)
			squint = 0.6
			brace = 1.0
		else:
			var r := AnimKit.win(mt - (wind + (v0 - 1) * gap), 0.2, 0.8)
			lift += 0.2 * (1.0 - r)
			head_r += 0.25 * sin(t * 16.0) * (1.0 - r)
			jaw = 0.4 * (1.0 - r) + 0.12
		if AnimKit.crossed(prev_mt, mt, wind + (v0 - 1) * gap + 0.25):
			AnimKit.cue(fx, W, "wheeze")
	elif mv == &"brood":
		var h2 := AnimKit.win(mt, 0.05, 1.15)
		var heave_w := sin(mt * 11.0) * h2      # heave, heave, heave... retch
		if mt < 1.2:
			heave = 0.6 * h2 + 0.25 * heave_w
			y -= 0.2 * h2
			head_p += 0.35 * h2 + 0.12 * heave_w
			jaw = 0.15 + 0.35 * h2 * (0.5 + 0.5 * sin(mt * 22.0))
			squint = h2
			lift -= 0.1 * h2
		elif mt < 1.7:
			var u := (mt - 1.2) / 0.5
			var s := 1.0 - AnimKit.out_cubic(u)
			head_p += 0.6 - 0.2 * u
			fwd += 0.4 * s
			jaw = 1.0
			heave = -0.4 * s
			y -= 0.15
			throat = 0.2
		else:
			var r := AnimKit.win(mt, 1.7, 2.8)
			head_r += 0.3 * sin(t * 13.0) * (1.0 - r)
			head_p += 0.3 * (1.0 - r)
			jaw = 0.35 * (1.0 - r) + 0.12
		if AnimKit.crossed(prev_mt, mt, 1.2):
			AnimKit.cue(fx, W, "squelch")
	elif mv == &"roll":
		var wind := MarrowWarden.ROLL_WIND
		var lk := MarrowWarden.ROLL_LOCK
		var cyc := wind + MarrowWarden.ROLL_DIST / MarrowWarden.ROLL_SPEED + 0.6
		var k := int(floorf(mt / cyc))
		var m := mt - k * cyc
		var roll_n := MarrowWarden.ROLLS + (1 if ph >= 3 else 0)
		var ro := W.roll
		var rolling := ro != null and m >= wind and ro.d < ro.path - 0.05
		if k < roll_n:
			var pre := AnimKit.win(m, 0.0, 0.18) * (1.0 - AnimKit.win(m, 0.18, 0.35))
			var cu := AnimKit.win(m, 0.12, 0.5)      # a dip (anticipation), then the curl
			y -= 0.3 * pre
			tuck = maxf(tuck, cu)
			lift -= 0.5 * cu
			head_p += 0.8 * cu
			bristle = cu
			squint = cu
			if m >= wind - lk and m < wind:
				shiver += 1.0                        # locked: it rattles in place
			if rolling:
				spin += dt * MarrowWarden.ROLL_SPEED / 1.6
				sq -= 0.08
			if not rolling and m >= wind:
				var uc := AnimKit.win(m, cyc - 0.6, cyc - 0.15)
				tuck = maxf(0.0, tuck - uc)
				dizzy = (1.0 - AnimKit.win(m, cyc - 0.15, cyc + 0.2)) * AnimKit.win(m, cyc - 0.6, cyc - 0.4)
			if AnimKit.crossed(prev_mt - k * cyc, m, wind - lk):
				AnimKit.cue(fx, W, "crack")
		else:
			dizzy = 1.0 - AnimKit.win(m, 0.0, 0.6)
		if not rolling:      # settle upright between rolls
			spin += (roundf(spin / TAU) * TAU - spin) * (1.0 - exp(-6.0 * dt))
	elif mv == &"sweep":
		var sw := W.sweep
		if sw != null:
			if sw.state == &"wind":
				var u := _n(sw.u)
				twist = -0.55 * AnimKit.in_out_cubic(u)
				y -= 0.25 * u
				brace = u
				squint = u
				bristle = u
				shiver += 0.4 * AnimKit.win(u, 0.7, 1.0)
				head_p += 0.15 * u
			elif sw.state == &"go":
				var u := _n(sw.u)
				twist = lerpf(0.65, 0.25, AnimKit.win(u, 0.1, 1.0)) * sw.dir
				fwd += 0.2
				brace = 1.0
				jaw = 0.7
			else:
				twist = 0.1 * sin(t * 8.0)
			if AnimKit.crossed(prev_mt, mt, MarrowWarden.SWEEP_WIND * (0.9 if ph >= 2 else 1.0)):
				AnimKit.cue(fx, W, "whoosh")
	elif mv == &"expose":
		var t0 := MarrowWarden.EXPOSE_T * (0.8 if ph >= 3 else 1.0)
		var opening := AnimKit.win(mt, 0.15, 0.55)
		var closing := AnimKit.win(mt, t0 + 0.35, t0 + 0.6)
		shiver += AnimKit.pulse(mt, 0.15, 0.2) * 2.0      # the cage rattles, then splits
		cage = opening * (1.0 - closing)
		splay = 0.6 * cage
		y -= 0.55 * cage
		lift -= 0.15 * cage
		head_p += 0.45 * cage
		head_r += 0.25 * sin(t * 1.6) * cage
		squint = 0.75 * cage
		jaw = 0.12 + 0.35 * cage
		look = 1.0 - cage
		if closing > 0.0:      # snaps shut and rears, furious
			lift += 0.35 * AnimKit.pulse(mt, t0 + 0.6, 0.3)
			jaw += 0.6 * AnimKit.pulse(mt, t0 + 0.6, 0.3)
		if AnimKit.crossed(prev_mt, mt, 0.3):
			AnimKit.cue(fx, W, "crack")
		if AnimKit.crossed(prev_mt, mt, 1.8):
			AnimKit.cue(fx, W, "wheeze")
		if AnimKit.crossed(prev_mt, mt, t0 + 0.4):
			AnimKit.cue(fx, W, "crack")
	elif mv == &"roar":
		var cr := AnimKit.win(mt, 0.0, 0.25) * (1.0 - AnimKit.win(mt, 0.25, 0.45))
		var up := AnimKit.hold(mt, 0.45, 1.25, 0.25, 0.15)
		y -= 0.3 * cr
		rear = up
		lift += 0.75 * up
		jaw = 0.12 + 0.95 * up
		wide = up
		bristle = up
		flare = up
		cage = 0.25 * up
		head_p -= 0.45 * up
		head_r += 0.12 * sin(t * 17.0) * up
		if AnimKit.crossed(prev_mt, mt, 0.4):
			AnimKit.cue(fx, W, "roar", 1.0)
			AnimKit.cue(fx, W, "crack")
		if AnimKit.crossed(prev_mt, mt, 1.38):
			AnimKit.cue(fx, W, "thud")
			AnimKit.fx_shake(fx, W, 0.7, 20.0)
			cracks.place(W.x + sn * 2.6, W.y, W.z + cs * 2.6, 3.5)
			if fx != null:
				fx.dust(Vector3(W.x + sn * 2.8, W.y, W.z + cs * 2.8), 10, 2.5)
	# the death, in stages
	var d_t := W.dead_t if dead else 0.0
	var thrash := 0.0
	var burst := 0.0
	var buckle := 0.0
	var deflate := 0.0
	var sink := 0.0
	if dead:
		thrash = 1.0 - AnimKit.win(d_t, 0.6, 0.9)
		burst = AnimKit.win(d_t, 0.78, 0.95)
		buckle = AnimKit.win(d_t, 0.9, 2.1)
		deflate = AnimKit.win(d_t, 2.0, 3.6)
		sink = AnimKit.win(d_t, 3.8, 6.0)
		lift += 0.45 * thrash * sin(d_t * 9.0) + 0.3 * thrash
		roll += 0.35 * thrash * sin(d_t * 13.0)
		head_p += -0.6 * thrash + 0.5 * buckle
		jaw = 1.0 * thrash + 0.6 * buckle
		head_r += 0.5 * buckle
		cage = 1.4 * burst
		y -= 0.45 * burst + 0.6 * buckle + 0.2 * deflate
		splay = maxf(splay, 0.45 * burst + 0.55 * buckle)
		roll += 0.25 * buckle
		squint = buckle
		if AnimKit.crossed(prev_dead, d_t, 0.02):
			AnimKit.cue(fx, W, "roar", 0.9)
		if AnimKit.crossed(prev_dead, d_t, 0.8):
			AnimKit.cue(fx, W, "crack")
			AnimKit.cue(fx, W, "squelch")
		if AnimKit.crossed(prev_dead, d_t, 2.3):
			AnimKit.cue(fx, W, "wheeze")
	prev_dead = d_t
	prev_mt = mt
	# emergence overrides: rising out of the floor with the legs unfolding, a shake-off at the top
	var rise := 0.0
	if emerging:
		var u := spawn_u
		rise = 1.0 - AnimKit.out_back(_n((u - 0.15) / 1.35), 0.9)
		lift += 0.5 * (1.0 - AnimKit.win(u, 0.6, 1.3))
		head_p -= 0.4 * (1.0 - AnimKit.win(u, 0.5, 1.2))
		lift += 0.3 * AnimKit.hold(u, 1.2, 1.7, 0.2, 0.4)      # claws grip the rim, it hauls itself up head first
		jaw = maxf(jaw, AnimKit.hold(u, 1.25, 1.75, 0.15, 0.3))
		bristle = maxf(bristle, AnimKit.hold(u, 1.2, 1.8, 0.1, 0.3))
		head_r += 0.25 * sin(u * 30.0) * AnimKit.hold(u, 1.8, 2.0, 0.1, 0.2)
	# ---- springs: every channel eases toward its target with overshoot and settle ----
	lift = sp_lift.step(lift, sdt)
	y = sp_y.step(y, sdt)
	sq = sp_sq.step(sq, sdt)
	fwd = sp_fwd.step(fwd, sdt)
	roll = sp_roll.step(roll, sdt)
	twist = sp_twist.step(twist, sdt)
	head_p = sp_head_p.step(head_p, sdt)
	head_r = sp_head_r.step(head_r, sdt)
	jaw = sp_jaw.step(jaw, sdt)
	cage = sp_cage.step(cage, sdt)
	throat = sp_throat.step(throat, sdt)
	tuck = sp_tuck.step(tuck, sdt)
	rear = sp_rear.step(rear, sdt)
	splay = sp_splay.step(splay, sdt)
	react.step(dt)
	var rp := react.pitch.x
	var rr := react.roll.x
	# ---- body ----
	var sh := sin(t * 47.0) * 0.03 * shiver if shiver > 0.0 else 0.0
	var root := FleshViews._yaw_root(W.yaw, Vector3(W.x, W.y + hop_now - rise * 3.8 - sink * 3.2, W.z))
	# gait bob: the body dips a little whenever a tripod is in the air
	var lifting := 0.0
	for L: Leg in legs:
		if L.step_t >= 0.0:
			lifting += sin(PI * L.step_t) / 3.0
	var body_pos := Vector3(sh, BODY_Y + y - 0.07 * lifting + heave * 0.1, fwd)
	var body_rx := -lift + rp * 0.5 + dizzy * 0.1 * sin(t * 5.0)
	if spin != 0.0:
		body_rx += spin      # BONE ROLL: the whole tucked body tumbles
	var body_b := _yxz(body_rx, twist + sh * 0.5, roll + rr * 0.5 + dizzy * 0.15 * sin(t * 4.0) + 0.04 * (lifting - 0.5) * sin(t * 2.4))
	var ball := _n(tuck) * (1.0 if mv == &"roll" else 0.4)      # tucked into a ball: shorter, rounder, spun about the belly's centre
	var body_s := Vector3(1.0 + 0.6 * sq * 0.5 + 0.05 * ball, 1.0 - sq * 0.6 + 0.05 * ball, 1.0 + 0.3 * sq - 0.28 * ball)
	if ball > 0.01:
		var v2 := Vector3(0.0, 0.4, -0.6)
		var vr := body_b * (v2 * body_s)
		body_pos += v2 * ball
		body_pos -= vr * ball
		body_pos.y += 0.15 * ball
	pose.pos[j_body] = body_pos
	pose.rot[j_body] = body_b
	pose.scl[j_body] = body_s
	pose.scl[j_abd] = Vector3(1.0 + 0.02 * sin(t * 1.3) + 0.08 * heave + 0.1 * deflate, 1.0 + 0.03 * sin(t * 1.3) + 0.06 * heave - 0.4 * deflate, 1.0 + 0.02 * sin(t * 1.3) - 0.1 * deflate)
	# ---- head, face ----
	var look_t := look_around
	var P: Variant = fx.last_player if fx != null else null
	if P != null and not dead:
		var da := atan2(float(P.x) - W.x, float(P.z) - W.z) - W.yaw
		da = atan2(sin(da), cos(da))
		look_t += clampf(da, -0.6, 0.6) * look * (1.0 - tuck)
	if AnimKit.crossed(notice_t - dt, notice_t, 0.08):      # the snap of noticing you
		sp_look.kick((look_t - sp_look.x) * 14.0)
	pose.rot[j_head] = _yxz(head_p - rp * 0.6, sp_look.step(look_t, dt) - twist * 0.6, head_r + rr * 0.8 + sh * 2.0)
	pose.euler(j_jaw, maxf(-0.05, jaw) * 0.6, 0.0, 0.0)
	for M: Array in mands:
		var sx: float = M[1]
		pose.euler(M[0], sin(t * 2.3 + sx) * 0.08 + buckle * 0.4, sx * (_n(jaw * 1.2) * 0.75 - 0.1 + sin(t * 9.0 + sx) * 0.05 * (1.0 - squint)), 0.0)
	var th := 0.35 + 0.6 * _n(throat)
	pose.scl[j_throat] = Vector3(th, th * 0.85, th * 0.9) if not (dead and burst > 0.5) else Vector3.ONE * 0.0001
	var d := batch.data
	var o := row * batch.stride
	d[o + 11] = 0.15 + 1.6 * _n(throat - 0.3)      # JS bileM.emissiveIntensity
	var bl := blink.step(dt)
	var eye_y := maxf(0.05, 1.0 - buckle) if dead else maxf(0.1, 1.0 - bl - 0.55 * squint + 0.35 * wide)
	for e: Array in eyes:
		var er: float = e[1]
		pose.scl[e[0]] = Vector3(er * 0.36 * (1.0 + 0.3 * wide), er * 0.36 * eye_y, er * 0.25)
	var ember := 1.0 - AnimKit.win(d_t, 1.0, 2.6) if dead else 1.0
	d[o + 4] = ember * (1.0 + flare * 0.5)
	d[o + 5] = ember * (0.45 + 0.25 * ph * 0.3 + 0.3 * flare)
	d[o + 6] = ember * 0.15
	d[o + 16 + 3] = 0.0 if dead else 0.18 + 0.1 * ph + 0.5 * flare + (0.3 * throat if mv == &"spray" else 0.0)
	# ---- heart and cage ----
	var bpm := 2.6 + ph * 0.8 + cage * 2.0
	var beat := pow(0.5 + 0.5 * sin(t * bpm * PI), 6.0)
	var open := _n(cage)
	var hs := (1.0 + 0.5 * burst if burst < 1.0 else maxf(0.01, 1.0 - AnimKit.win(d_t, 0.95, 1.1))) if dead else 1.0 + (0.07 + 0.12 * open) * beat
	pose.scl[j_heart] = Vector3(hs, hs, hs) if hs > 0.02 else Vector3.ONE * 0.0001
	d[o + 10] = 0.5 + 1.6 * open + 0.9 * beat + flare * 0.6      # JS heartM.emissiveIntensity
	pose.euler(j_cage_l, 0.0, 0.0, cage * 0.95 + rp * 0.1 + shiver * 0.02 * sin(t * 61.0))
	pose.euler(j_cage_r, 0.0, 0.0, -cage * 0.95 - rp * 0.1 - shiver * 0.02 * sin(t * 59.0))
	d[o + 20 + 3] = 0.8 * (1.0 - AnimKit.win(d_t, 0.9, 1.6)) * burst if dead else 0.15 * ph + open * (0.6 + 0.3 * beat) + 0.2 * beat
	# ---- damage states: fissures burn hotter as it weakens; bands shed at phase roars; ribs and a tusk break in phase 3 ----
	var hot := (1.0 - hp_f) * 1.4 + (ph - 1) * 0.35 + 0.6 * flare + 0.8 * open + 0.6 * W.flash
	d[o + 9] = maxf(0.0, 1.5 * (1.0 - AnimKit.win(d_t, 0.9, 3.0))) if dead else 0.15 + hot * (0.75 + 0.25 * beat)
	d[o + 8] = 0.6 * (1.0 - AnimKit.win(d_t, 0.9, 2.8)) if dead else (0.15 + 0.18 * (ph - 1)) * (0.5 + beat) + W.flash * 0.8 + open * 0.5 + flare * 0.4
	d[o] = W.flash
	for b: Dictionary in bands:
		var i: int = b.i
		var shed_at := 2 if SHED[2].has(i) else (3 if SHED[3].has(i) else 9)
		var gone := ph >= shed_at
		var flying := mv == &"roar" and ph == shed_at and mt > 0.4 and mt < 1.6
		var u := mt - 0.4 if flying else 0.0
		var home: Vector3 = b.home
		if flying:
			var bs: float = b.spin
			pose.pos[b.j] = home + (b.out as Vector3) * u * 5.0 + Vector3(0.0, -6.0 * u * u, 0.0)
			pose.euler(b.j, -0.12 + bs * u * 3.0, bs * u * 2.0, 0.0)
		else:
			var dead_burst := burst if dead else 0.0
			pose.pos[b.j] = home + Vector3(0.0, 0.3 * dead_burst * fmod(float(i) * 0.37, 1.0), 0.0)
			pose.euler(b.j, -0.12 + 0.3 * dead_burst * sin(i * 2.1), 0.0, 0.2 * dead_burst * cos(i * 1.7))
		pose.scl[b.j] = Vector3.ONE if not gone or flying else Vector3.ONE * 0.0001
	for rb: Dictionary in ribs:
		var broken: bool = ph >= 3 and ((float(rb.sx) < 0.0 and int(rb.i) == 2) or (float(rb.sx) > 0.0 and int(rb.i) == 4))
		pose.scl[rb.j] = Vector3(1.0, 0.45 if broken else 1.0, 1.0)
	var tk := 0.55 if ph >= 3 else 1.0
	pose.scl[tusks[1]] = Vector3(tk, tk, tk)
	# ---- spines, blister sacs ----
	for i in spines.size():
		pose.euler(spines[i][0], float(spines[i][1]) - 0.55 * _n(bristle) - 0.1 * (ph - 1) + sin(t * 2.0 + i * 0.7) * 0.05 + shiver * 0.08 * sin(t * 40.0 + i) + buckle * 0.5, 0.0, 0.0)
	for q2: Dictionary in sacs:
		var s2: float = q2.s
		var k := s2 * (1.0 + 0.08 * beat + (0.3 * maxf(0.0, heave) + 0.12 * sin(t * 9.0 + float(q2.ph)) if mv == &"brood" else 0.0) + W.flash * 0.1)
		pose.scl[q2.j] = Vector3(k, k * 1.1, k) if not (dead and d_t > 0.85 + s2 * 2.0) else Vector3.ONE * 0.0001
	# ---- legs: tripod gait with world-planted feet, solved by IK; poses (tuck, rear, splay, brace, death) blend over the planted feet ----
	pose.compose(root)
	var inv := pose.world[j_body].affine_inverse()
	var airborne := hop_now > 0.05 or tuck > 0.4 or dead or emerging
	var step_dur := 0.24 if speed > 2.5 else 0.32
	var grp_busy: Array[bool] = [false, false]
	for L: Leg in legs:
		if L.step_t >= 0.0:
			grp_busy[L.grp] = true
	var want_grp := -1
	var want_err := 0.0
	for L: Leg in legs:
		# the spot under the hip where this foot wants to be (in world space), led a little along the velocity
		var v := L.rest
		v.y += BODY_Y
		v.x *= 1.0 + 0.05 * brace
		v = root * v
		v.y = W.y
		v += vel * 0.28
		if not L.init or airborne:
			L.plant = v
			L.cur = v
			L.step_t = -1.0
			L.init = true
		elif L.step_t >= 0.0:
			L.step_t += sdt / step_dur
			L.to = v
			var u := AnimKit.in_out_sine(minf(1.0, L.step_t))
			L.cur = L.from.lerp(L.to, u)
			L.cur.y += sin(PI * minf(1.0, L.step_t)) * (0.45 + 0.1 * speed)
			if L.step_t >= 1.0:
				L.step_t = -1.0
				L.plant = L.to
				L.cur = L.to
				if L.i == 0 and speed > 0.6:
					AnimKit.cue(fx, W, "step")
		else:
			L.cur = L.plant
			var err := U.hyp(v.x - L.plant.x, v.z - L.plant.z)
			if err > 0.75 and not grp_busy[1 - L.grp] and err > want_err:
				want_err = err
				want_grp = L.grp
	if want_grp >= 0:
		for L: Leg in legs:
			if L.grp == want_grp and L.step_t < 0.0:
				L.step_t = 0.0
				L.from = L.plant
	for L: Leg in legs:
		var v := inv * L.cur      # foot in body space
		# pose overrides in body space, strongest wins
		var ow := 0.0
		var ov := Vector3.ZERO
		var front := L.i == 0
		var zs := L.rest.z
		if tuck > 0.01:
			ov = Vector3(L.sx * 1.5, -0.35, zs * 0.75)
			ow = tuck
		if rear > 0.01 and front:
			ov = Vector3(L.sx * 2.6, 1.0 + 0.25 * sin(t * 9.0 + L.sx), 2.4)
			ow = maxf(ow, rear)
		if splay > 0.01 and tuck == 0.0:
			var tw := sin(d_t * 18.0 + L.i * 2.0 + L.sx) * 0.25 * (1.0 - AnimKit.win(d_t, 2.4, 3.6)) * (AnimKit.pulse(fmod(d_t, 0.9), 0.2, 0.2) if d_t > 2.5 else 1.0) if dead else 0.0
			ov = Vector3(L.sx * 4.1, -BODY_Y - y + 0.15 + tw, zs * 1.6)
			var li := L.i * 2 + (1 if L.sx > 0.0 else 0)
			var bw := 0.45 * burst + 0.55 * AnimKit.win(d_t, 0.95 + li * 0.19, 1.12 + li * 0.19) if dead else splay
			ow = maxf(ow, bw)
		if dead and thrash > 0.0:
			ov = Vector3(L.sx * (3.0 + sin(d_t * 14.0 + L.i) * 0.8), -0.5 + sin(d_t * 11.0 + L.i * 1.7 + L.sx) * 0.9, zs * 1.3 + cos(d_t * 12.0 + L.i) * 0.6)
			ow = maxf(ow, thrash)
		if f2 > 0.0 and front and L.sx < 0.0:      # paw-scrape
			ov = Vector3(-3.0, -BODY_Y + 0.2 + 0.25 * absf(sin(fu * PI * 4.0)), zs * 1.45 + 0.6 + 0.5 * sin(fu * PI * 4.0))
			ow = maxf(ow, f2)
		if ow > 0.0:
			v = v.lerp(ov, _n(ow))
		_ik(L, v)
	# ---- the scourge: lies under the floor, lifts through the wind-up, whips round the pit with a hot smear trailing it ----
	var sw2 := W.sweep
	d[o + 24 + 3] = 0.0
	if sw2 != null and not dead:
		var lifted := AnimKit.out_back(_n(sw2.u), 1.2) if sw2.state == &"wind" else (1.0 if sw2.state == &"go" else 1.0 - AnimKit.win(sw2.u, 0.0, 1.0))
		pose.euler(j_sweep, 0.0, sw2.ang - W.yaw, sin(t * 22.0) * 0.06 if sw2.state == &"go" else (sin(t * 30.0) * 0.04 * sw2.u if sw2.state == &"wind" else 0.0))
		var sp2 := Vector3(0.0, -hop_now + 0.3 - (1.0 - lifted) * 0.6 + rise * 3.8, 0.0)
		pose.pos[j_sweep] = sp2
		pose.scl[j_sweep] = Vector3(2.2, (0.4 + 0.6 * lifted) * 2.2, 1.0)
		if sw2.state == &"go":
			pose.pos[j_smear] = sp2
			pose.euler(j_smear, 0.0, sw2.ang - W.yaw - sw2.dir * 0.22, 0.0)
			pose.scl[j_smear] = Vector3(3.2, 1.6, 1.0)
			d[o + 24 + 3] = 0.3
		else:
			pose.scl[j_smear] = Vector3.ONE * 0.0001
	else:
		pose.scl[j_sweep] = Vector3.ONE * 0.0001
		pose.scl[j_smear] = Vector3.ONE * 0.0001
	# ---- telegraphs in world space ----
	var marks := W.marks
	for i in rings.size():
		var m2: MeshInstance3D = rings[i]
		var k2: MarrowWarden.Mark = marks[i] if i < marks.size() else null
		if k2 == null or k2.hit or dead:
			m2.visible = false
			continue
		var a3 := mt - k2.t0
		FxBeam.place_ring(m2, Vector3(k2.x, k2.y + 0.08, k2.z), MarrowWarden.LEAP_R * (1.0 if k2.locked else 1.12 - 0.12 * sin(a3 * 10.0)), 0.95 if k2.locked else 0.5 + 0.3 * sin(a3 * 14.0))
	var ro2 := W.roll
	if ro2 != null and ro2.has_dir and ro2.path > 0.0 and not dead:
		var ln := ro2.path - ro2.d
		if ln > 0.2:
			FxBeam.place_streak(streak, Vector3(W.x + ro2.dir.x * (ln / 2.0), W.y + 0.07, W.z + ro2.dir.y * (ln / 2.0)), 4.0, ln, atan2(ro2.dir.x, ro2.dir.y), 0.35 + 0.25 * sin(t * 14.0))
		else:
			streak.visible = false
	else:
		streak.visible = false
	if sw2 != null and not dead and sw2.state == &"wind":
		FxBeam.place_ring(rim, Vector3(W.x, W.y + 0.06, W.z), MarrowWarden.SWEEP_LEN, 0.35 + 0.4 * absf(sin(t * 12.0)))
	else:
		rim.visible = false
	cracks.update(dt)
	if dead and d_t > 6.0:
		batch.clear_row(row)
		return
	update_bar(dt, 5.6, 1.76 / 0.86, 1.0, true)
	pose.compose(root)
	upload()
