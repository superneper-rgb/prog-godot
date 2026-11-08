class_name PhoniwormView
extends CreatureView
## DIRGEWORM on screen (JS enemies/phoniworm-view.js; the id stays "worm"): a long, bruised, intestine-like body pinched into ringed segments that follows the head's trail on the ground; a blind, ridged leech-head whose nose cone peels open into four toothed petals round a throat of hooks; two vocal sacs that balloon and glow before it HOWLS; it rears and hammers the petals down for the slam. The model comes from the exporter (assets/objects/enemy_worm.glb, tools/export/enemy_worm.expr.js). The group follows the head's ground position and is never rotated (segments live in world axes); the head carries R.yaw.
## ENGINE DIFFERENCE: the JS's instanced body shares its materials across every worm, so a hit flashes them all; here each worm flashes on its own, its bone plates too.

const MAXSEG := 24
const SP := 0.6
const NECK := 4
const CH_SAC := 0
const CH_THROAT := 1
const CH_SONIC := 2      # 2, 3, 4: one per ring

static var _model: CreatureModel = null

var seg: Array = []      # { r, p, s }
var tail: int
var head_root: int
var head_pit: int
var petals: Array[int] = []
var sacs: Array[int] = []
var sonic: Array[int] = []
var mid: int
var trail: Array[Vector3] = []
var hx0 := 0.0
var hz0 := 0.0
var t := 0.0
var phase := randf() * 6.0
var walk_ph := 0.0
var pop := 0.0
var sink := 0.0
var squash := 0.0
var slammed := false
var last_state := &""
var _pos: PackedVector3Array
var _tap: PackedFloat32Array
var _sc_rest := Vector3.ONE


static func get_model() -> CreatureModel:
	if _model == null:
		var glow_rings := {"sonic0": CH_SONIC, "sonic1": CH_SONIC + 1, "sonic2": CH_SONIC + 2}
		_model = CreatureModel.build("res://assets/objects/enemy_worm.glb", _glow, glow_rings)
		_model.body_mat.set_shader_parameter(&"flash_tint", Vector3(0.8, 0.25, 0.15))
	return _model


static func _glow(s: RobotGfx.SpriteSoup, m: CreatureModel) -> void:
	s.sprite(m.names["headPit"], CH_SAC, Vector3(0.5, -0.18, -0.3), 1.0)
	s.sprite(m.names["headPit"], CH_SAC, Vector3(-0.5, -0.18, -0.3), 1.0)
	s.sprite(m.names["throat"], CH_THROAT, Vector3(0.0, 0.0, -0.05), 1.0)


func _init(p_r: Phoniworm) -> void:
	super._init(p_r, get_model())
	var n: Dictionary = model.names
	for i in MAXSEG:
		seg.append({"r": n["r%d" % i], "p": n["p%d" % i], "s": 0.0})
	tail = n["tail"]
	head_root = n["headRoot"]
	head_pit = n["headPit"]
	for k in 4:
		petals.append(n["pet%d" % k])
	for k in 2:
		sacs.append(n["sac%d" % k])
	for k in 3:
		sonic.append(n["sonic%d" % k])
	mid = n["mid"]
	j_spine = head_root
	j_el_l = mid
	j_muzzle = n["mouth"]
	_pos.resize(MAXSEG + 1)
	_tap.resize(MAXSEG + 1)
	var d := batch.data
	var o := row * batch.stride
	_col(d, o + 16 + 4 * CH_SAC, 0xff3020)
	_col(d, o + 16 + 4 * CH_THROAT, 0xff2010)
	for k in 3:
		_col(d, o + 16 + 4 * (CH_SONIC + k), 0xff5040)
	last_state = R.state
	_seed()


## (re)start the trail straight behind the head
func _seed() -> void:
	trail.clear()
	for i in 160:
		trail.append(Vector3(R.x - sin(R.yaw) * i * 0.1, R.y, R.z - cos(R.yaw) * i * 0.1))
	hx0 = R.x
	hz0 = R.z


func on_respawn() -> void:
	q.clear()
	pop = 0.0
	sink = 0.0
	_seed()
	for S: Dictionary in seg:
		S.s = 0.0


## point on the trail d metres behind the head
func _at(d: float) -> Vector3:
	var acc := 0.0
	for i in trail.size() - 1:
		var a := trail[i]
		var b := trail[i + 1]
		var l := Vector2(b.x - a.x, b.z - a.z).length()
		if acc + l >= d:
			var u := (d - acc) / l if l > 1e-6 else 0.0
			return a.lerp(b, u)
		acc += l
	return trail[trail.size() - 1]


static func _num(u: float) -> float:
	return clampf(u, 0.0, 1.0)


func update(dt: float, _now: float, _fx: Variant) -> void:
	var W := R as Phoniworm
	t += dt
	var tt := t + phase
	var d_ := batch.data
	var o := row * batch.stride
	if W.state != last_state:
		if last_state == &"dead" and W.state != &"dead":
			on_respawn()
		last_state = W.state
	var dead := W.state == &"dead"
	var st := W.state_t
	var n_seg := clampi(W.segs if W.segs != 0 else Phoniworm.WORM_SEG_START, 1, MAXSEG)
	# ---- trail: record the head's ground path (teleports re-seed it)
	if Vector2(W.x - hx0, W.z - hz0).length() > 3.0:
		_seed()
	if Vector2(W.x - trail[0].x, W.z - trail[0].z).length() > 0.1:
		if trail.size() >= 260:
			trail.pop_back()
		trail.push_front(Vector3(W.x, W.y, W.z))
	hx0 = W.x
	hz0 = W.z
	sink = (W.dead_t - 9.0) * 0.35 if dead and W.dead_t > 9.0 else 0.0
	if sink >= 1.2:
		set_culled(true)
		return
	pop = 1.0 if dead else minf(1.0, pop + dt * 2.5)
	d_[o] = W.flash
	var spd := Vector2(W.lvx, W.lvz).length()
	var run := _num(spd / maxf(0.1, Phoniworm.WORM_SPEED))
	walk_ph += dt * (2.0 + spd * 1.9)
	var talking := false
	if not dead and W.E != null and W.E.barks != null:
		for a in W.E.barks.active:
			talking = talking or a.r == W
	# ---- head pose per state: height, forward offset, pitch (+ = nose down), mouth (petals), howl (sacs + rings), charge glow
	var head_h := 1.4 + 0.08 * sin(tt * 1.9)
	var head_z := 0.0
	var pitch := 0.1
	var mouth := 0.15
	var ring := 0.0
	var tremble := 0.0
	var glow := 0.0
	var rate := 7.0
	var extend := 0.0
	var sac_k := 0.0
	var slam_d := W.slam_dist()
	match W.state:
		&"alert":
			var u := _num(st / 0.3)
			head_h = 1.4 + 0.5 * sin(u * PI)
			pitch = -0.3 * sin(u * PI)
			mouth = 0.8
			rate = 14.0
		&"pursue":      # the petals twitch apart, tasting the air
			head_h = 1.15 + 0.15 * sin(walk_ph * 0.5)
			pitch = 0.18
			mouth = 0.18 + 0.12 * pow(maxf(0.0, sin(tt * 1.3)), 4.0)
		&"windup":
			var e := _ease(_num(W.a_u))
			if W.atk == &"slam":
				head_h = lerpf(1.4, 2.9, e)
				head_z = -0.9 * e
				pitch = -0.55 * e
				mouth = 1.0
				tremble = 0.02
				rate = 12.0
			elif W.atk == &"extend":
				head_h = lerpf(1.4, 3.0, e)
				head_z = -0.3 * e
				pitch = -0.7 * e
				mouth = 0.8
				tremble = 0.05 * e
				glow = e
				extend = e
				rate = 12.0
			else:
				head_h = lerpf(1.4, 1.9, e)
				head_z = -0.3 * e
				pitch = -0.45 * e
				mouth = 0.4 + 0.6 * e
				sac_k = e
				tremble = 0.04 * e
				glow = e
				rate = 14.0
		&"attack":
			var u := _num(W.a_u)
			if W.atk == &"slam":      # accelerates down and hits the floor on the 0.1 s damage frame, petals snapping shut
				var k := pow(_num(u / 0.2), 2.2)
				head_h = lerpf(2.9, 0.55, k)
				head_z = lerpf(-0.9, slam_d * 0.8, k)
				pitch = lerpf(-0.55, 0.95, k)
				mouth = lerpf(1.0, 0.15, k)
				rate = 120.0
				if st >= 0.1 and not slammed:
					slammed = true
					squash = 1.0
			elif W.atk == &"extend":
				head_h = lerpf(3.0, 2.3, u)
				head_z = 0.0
				pitch = -0.5
				mouth = 1.0
				glow = 1.0 - u * 0.5
				extend = 1.0 - u
				tremble = 0.03
				rate = 20.0
			else:
				head_h = 1.9
				head_z = 0.3 * (1.0 - u)
				pitch = -0.2
				mouth = 1.15
				ring = 1.0
				sac_k = 1.0 - u * 0.8
				glow = 1.0
				tremble = 0.05
				rate = 30.0
		&"recover":
			var e := _ease(_num(W.a_u))
			if W.atk == &"slam":
				head_h = lerpf(0.55, 1.4, e)
				head_z = lerpf(slam_d * 0.8, 0.0, e)
				pitch = lerpf(0.95, 0.1, e)
				mouth = lerpf(0.15, 0.3, e)
				rate = 8.0
			else:
				head_h = lerpf(2.3 if W.atk == &"extend" else 1.9, 1.4, e)
				pitch = lerpf(-0.3, 0.1, e)
				mouth = lerpf(0.8, 0.2, e)
				ring = 1.0 - e if W.atk == &"ring" else 0.0
				glow = 0.6 * (1.0 - e)
				rate = 8.0
		&"stagger":
			var u := _num(st / 0.6)
			var env := u / 0.12 if u < 0.12 else 1.0 - (u - 0.12) / 0.88
			head_h = 1.4 + 0.5 * env
			pitch = -0.4 * env
			head_z = -0.5 * env
			mouth = 1.0
			tremble = 0.05 * env
			rate = 22.0
		&"search":
			head_h = 1.3
			pitch = 0.1 + 0.1 * sin(tt)
			mouth = 0.25
		&"dead":
			var k := _ease(_num(W.dead_t / 0.9))
			head_h = lerpf(1.4, 0.42, k)
			head_z = 0.25 * k
			pitch = 0.55 * k
			mouth = 0.6 * k
			rate = 9.0
	if W.flinch_t > 0.0 and not dead:
		var p := W.flinch_t / 0.2
		head_h += 0.2 * p
		pitch -= 0.2 * p
		mouth = maxf(mouth, 0.6 * p)
	if W.fire_t > 0.0 and not dead:
		ring = maxf(ring, W.fire_t / 0.3)
	if W.state != &"attack":
		slammed = false
	squash = maxf(0.0, squash - dt * 4.0)
	head_h = _qq(&"hh", head_h, rate, dt)
	head_z = _qq(&"hz", head_z, rate, dt)
	pitch = _qq(&"pt", pitch, rate, dt)
	mouth = _qq(&"mo", mouth, 40.0 if W.state == &"attack" and W.atk == &"slam" else 14.0, dt)
	sac_k = _qq(&"sac", sac_k, 9.0, dt)
	var trem := sin(tt * 70.0) * tremble if tremble != 0.0 else 0.0
	# ---- head placement (g-local; world axes): forward offset along yaw
	var sy := sin(W.yaw)
	var cy := cos(W.yaw)
	var hx := sy * head_z
	var hz := cy * head_z
	var hy := head_h
	var sq := squash * squash * cos((1.0 - squash) * 12.0)      # impact squash, wobbling back
	var P := pose
	P.scl[head_root] = Vector3(1.0 + 0.15 * sq, 1.0 - 0.25 * sq, 1.0 + 0.15 * sq)
	P.pos[head_root] = Vector3(hx + trem, hy, hz)
	P.euler(head_root, 0.0, W.yaw, 0.0)
	P.euler(head_pit, pitch + (0.0 if dead else 0.03 * sin(tt * 2.3)), 0.0, 0.0)
	# ---- the nose cone peels open: four petals, each a little out of step
	var talk := 0.25 * absf(sin(tt * 12.0)) if talking else 0.0
	var open := clampf(mouth + talk, 0.0, 1.2)
	for k in 4:
		P.euler(petals[k], -(0.02 + 1.25 * open + (0.06 * sin(tt * 9.0 + k * 1.9) if open > 0.1 else 0.0)), 0.0, 0.0)
	d_[o + 16 + 4 * CH_THROAT + 3] = minf(1.0, open) * (0.4 + 0.6 * glow)
	d_[o + 12 + CH_THROAT] = 0.4 + 0.5 * glow
	# ---- vocal sacs swell and quiver before the howl, glowing through
	for i in 2:
		var k := 1.0 + 1.1 * sac_k + 0.04 * sin(tt * 2.0 + i) + (0.06 * sin(tt * 55.0 + i * 2.0) * sac_k if sac_k > 0.05 else 0.0)
		P.scl[sacs[i]] = Vector3(k, k * 0.9, k)
	d_[o + 9] = 0.08 + 0.6 * sac_k      # (the sac's glow source)
	d_[o + 8] = 0.05 + 0.5 * glow       # (the head's)
	d_[o + 16 + 4 * CH_SAC + 3] = 0.0 if dead else 0.45 * sac_k
	d_[o + 12 + CH_SAC] = 0.1 + 0.9 * sac_k
	# ---- pressure rings rolling out of the throat during the howl
	for i in 3:
		var u := fmod(tt * 2.6 + i / 3.0, 1.0) if ring > 0.0 else 0.0
		var on := ring > 0.05
		P.scl[sonic[i]] = Vector3.ONE * (0.25 + u * 2.4 * ring) if on else Vector3.ZERO
		d_[o + 16 + 4 * (CH_SONIC + i) + 3] = (1.0 - u) * 0.7 * minf(1.0, ring * 1.3) if on else 0.0
		P.pos[sonic[i]].z = u * 0.5
	# ---- body: segments follow the trail. The neck blends the segment heights / offsets toward the head's.
	var wob := (0.02 if dead else 0.12 + 0.12 * run) * (0.5 if extend != 0.0 else 1.0)
	_pos[0] = Vector3(hx, hy, hz)      # pos[0] = head, pos[i+1] = segment i
	_tap[0] = 1.0
	for i in MAXSEG:
		var S: Dictionary = seg[i]
		var want := 1.0 if i < n_seg else 0.0
		S.s += (want - float(S.s)) * (1.0 - exp(-5.0 * dt))
		var dist_ := (i + 1) * SP + 0.12
		var P0 := _at(dist_)
		var Pa := _at(maxf(0.0, dist_ - 0.32))
		var Pb := _at(dist_ + 0.32)
		var w := maxf(0.0, 1.0 - float(i) / NECK)
		var wn := w * w * (3.0 - 2.0 * w)
		var tap := lerpf(1.0, 0.56, float(i) / maxf(8.0, n_seg - 1.0))
		var tx := Pa.x - Pb.x
		var tz := Pa.z - Pb.z
		var tl := Vector2(tx, tz).length()
		if tl == 0.0:
			tl = 1.0
		tx /= tl
		tz /= tl
		var lat := sin(walk_ph - i * 0.75) * wob * clampf(i / 5.0, 0.0, 1.0) * (1.0 - wn * 0.8)      # slither, bigger toward the tail
		var px := P0.x - W.x + hx * wn - tz * lat
		var pz := P0.z - W.z + hz * wn + tx * lat
		var peri := 0.0 if dead else 0.05 * sin(walk_ph * 1.6 - i * 1.1)      # a peristaltic wave rolling down the body
		var base := 0.44 * tap
		var gy := (P0.y - W.y) + base + (hy - 0.44) * wn * 0.85 + (0.0 if dead else 0.05 * sin(walk_ph * 0.9 - i * 0.9) * (1.0 - wn))
		_pos[i + 1] = Vector3(px, maxf(0.2 * tap, gy) - (0.1 if dead else 0.0), pz)
		_tap[i + 1] = tap * (1.0 + peri)
	for i in MAXSEG:
		var S: Dictionary = seg[i]
		var jr: int = S.r
		var jp: int = S.p
		if float(S.s) <= 0.03:
			P.scl[jr] = Vector3.ZERO
			continue
		var cur := _pos[i + 1]
		var nx := _pos[i]      # toward the head / toward the tail
		var pv := _pos[i + 2] if i + 2 <= MAXSEG else cur
		var dx := nx.x - pv.x
		var dy := nx.y - pv.y
		var dz := nx.z - pv.z
		P.pos[jr] = cur
		P.scl[jr] = Vector3.ONE * (_tap[i + 1] * (0.35 + 0.65 * float(S.s)))
		P.euler(jr, 0.0, atan2(dx, dz), 0.0)
		P.euler(jp, -atan2(dy, Vector2(dx, dz).length()) + (0.0 if dead else 0.04 * sin(walk_ph * 0.9 - i * 0.9)), 0.0, 0.0)
		if i == 3:
			P.pos[mid] = cur
	# tail stinger after the last visible segment, curling up when it rears
	var dt_ := (n_seg + 1) * SP + 0.05
	var T0 := _at(dt_)
	var Ta := _at(dt_ - 0.3)
	var Tb := _at(dt_ + 0.3)
	P.pos[tail] = Vector3(T0.x - W.x, (T0.y - W.y) + 0.24, T0.z - W.z)
	P.euler(tail, -0.2 * glow + 0.08 * sin(tt * 2.4), atan2(Ta.x - Tb.x, Ta.z - Tb.z), 0.0)
	P.scl[tail] = Vector3.ONE * (0.75 * minf(1.0, pop))
	# ---- health bar above the head, facing the camera
	update_bar(dt, hy + 0.95, 1.2, 1.0, true)
	if d_[o + 43] >= 0.0:
		var f := maxf(0.0, W.hp / W.max)
		var bc := _hsl(0.02 + 0.1 * f, 0.9, 0.55)
		d_[o + 36] = W.x + hx
		d_[o + 38] = W.z + hz
		d_[o + 40] = bc.r
		d_[o + 41] = bc.g
		d_[o + 42] = bc.b
	P.compose(Transform3D(Basis.IDENTITY, Vector3(W.x, W.y - sink, W.z)))
	upload()
