class_name MsBand
extends RefCounted
## THE MOTHERSHIP's wedding band (JS levels/mothership/band.js): 0002pxr (a purple box with a man's face on eight spider legs) sings "Do You Have the Right of Way" on the stage, two little copies of him on keyboard and drums. Everything they do comes from the song's beat map
## (assets/sfx/right-of-way.beats.json) read at the song's playback position, so the band follows the record: it freezes when the record scratches and plays fast when the song plays fast.
##   singer   sways side to side every two beats and dips on each beat; the mic (front-right foot) comes up to his mouth while he sings, drops to his side in the instrumental breaks, and on the loudest lines he pulls it away and throws the other front foot up
##   keys     presses on each keys hit, alternating feet (both feet on loud stabs that land on a beat), moving along the keyboard
##   drums    left stick on the snare hits, right stick on the hi-hat hits (the crash on section downbeats), kick foot on the kick drum
## The poses are one-frame pose_* clips in assets/npcs/pxr/model.glb; this file blends them per bone. The instruments are the export's (ms_band_* and ms_kit_*); the bodies are built here.

const MODEL := "res://assets/npcs/pxr/model.glb"
const BEATS := "res://assets/sfx/right-of-way.beats.json"
const LEGS := ["L1", "L2", "L3", "L4", "R1", "R2", "R3", "R4"]


class Hit:
	var t := 0.0
	var x := 0.0
	var crash := false
	func _init(p_t: float, p_x: float = 0.0, p_crash: bool = false) -> void:
		t = p_t
		x = p_x
		crash = p_crash


class Member:
	var role := ""
	var g: Node3D
	var sk: Skeleton3D
	var bones: Dictionary = {}      # name -> index
	var rest_q: Dictionary = {}
	var rest_p: Dictionary = {}
	var base_yaw := PI / 2.0
	var snare := 0.0
	var hat := 0.0
	var crash := 0.0
	var kick := 0.0
	var last_snare: Hit = null
	var last_kick: Hit = null
	var last_r: Hit = null
	var k_snare: Node3D = null
	var k_hat: Node3D = null
	var k_hat_y := 0.0
	var k_crash: Node3D = null
	var k_crash_tilt := 0.0
	var k_head: Node3D = null
	var k_snare_s := Vector3.ONE


var members: Array[Member] = []
var poses: Dictionary = {}      # pose -> bone -> {q, p}
var ready := false
var feel := {"t": 0.0, "beat": 0.0, "bar": 0, "kick": 0.0, "snare": 0.0, "crash": 0.0, "low": 0.0, "sing": 0.0, "keys": 0.0, "vocal": 0.0}
var bpm := 120.0
var beat0 := 0.0
var duration := 1.0
var spb := 0.5
var env: Dictionary = {}
var env_fps := 30.0
var keys_l: Array[Hit] = []
var keys_r: Array[Hit] = []
var right: Array[Hit] = []
var crashes: Array[Hit] = []
var snare: Array[Hit] = []
var kick: Array[Hit] = []
var _all: Array[String] = ["body"]
var _h := 7


static func smooth(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


static func _leg(n: String) -> Array[String]:
	return ["leg_" + n + "_coxa", "leg_" + n + "_tibia", "leg_" + n + "_foot"]


func _rnd() -> float:
	_h = (_h * 16807) % 2147483647
	return float(_h) / 2147483647.0


func _init(L: ExportedLevel, spots: Dictionary, parent: Node3D) -> void:
	for n: String in LEGS:
		_all.append_array(_leg(n))
	var beats: Variant = JSON.parse_string(FileAccess.get_file_as_string(BEATS))
	if not beats is Dictionary:
		push_warning("MOTHERSHIP band: no beat map")
		return
	_prep_song(beats)
	var ps: PackedScene = load(MODEL)
	var tpl: Node = ps.instantiate()
	var ap := tpl.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap != null:
		for nm: StringName in ap.get_animation_list():
			if not String(nm).begins_with("pose_"):
				continue
			var a := ap.get_animation(nm)
			var p: Dictionary = {}
			poses[String(nm).substr(5)] = p
			for i in a.get_track_count():
				var bone := String(a.track_get_path(i).get_concatenated_subnames())
				if not p.has(bone):
					p[bone] = {}
				if a.track_get_type(i) == Animation.TYPE_ROTATION_3D:
					p[bone]["q"] = a.track_get_key_value(i, 0)
				elif a.track_get_type(i) == Animation.TYPE_POSITION_3D:
					p[bone]["p"] = a.track_get_key_value(i, 0)
	tpl.free()
	for role: String in ["singer", "keys", "drums"]:
		_make(L, ps, role, spots[role], 1.0 if role == "singer" else 0.6, parent)
	ready = true


func _make(L: ExportedLevel, ps: PackedScene, role: String, at: Array, scale_: float, parent: Node3D) -> void:
	var m := Member.new()
	m.role = role
	var g: Node3D = null
	for n: Node3D in L.node_named("ms_band_" + role):      # (the export's: the keyboard or the drum kit in it)
		g = n
	if g == null:
		g = Node3D.new()
		parent.add_child(g)
		g.position = Vector3(at[0], at[1], at[2])
		g.rotation.y = m.base_yaw
		g.scale = Vector3.ONE * scale_
	m.g = g
	var model: Node3D = ps.instantiate()
	g.add_child(model)
	m.sk = model.find_child("Skeleton3D", true, false) as Skeleton3D
	var ap := model.find_child("AnimationPlayer", true, false)
	if ap != null:
		ap.free()
	for i in m.sk.get_bone_count():
		var b := m.sk.get_bone_name(i)
		m.bones[b] = i
		m.rest_q[b] = m.sk.get_bone_pose_rotation(i)
		m.rest_p[b] = m.sk.get_bone_pose_position(i)
	var walk: Array[Node] = [model]
	while not walk.is_empty():
		var n: Node = walk.pop_back()
		walk.append_array(n.get_children())
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			mi.extra_cull_margin = 8.0
			if String(n.name).begins_with("mic"):
				mi.visible = role == "singer"
			if String(n.name).begins_with("stick"):
				mi.visible = role == "drums"
	if role == "drums":
		for n: Node3D in L.node_named("ms_kit_snare"):
			m.k_snare = n
			m.k_snare_s = n.scale
		for n: Node3D in L.node_named("ms_kit_hattop"):
			m.k_hat = n
			m.k_hat_y = n.position.y
		for n: Node3D in L.node_named("ms_kit_crash"):
			m.k_crash = n
			m.k_crash_tilt = n.rotation.x
		for n: Node3D in L.node_named("ms_kit_kickhead"):
			m.k_head = n
	members.append(m)


## per bone: weighted blend of poses ("rest" = the bind pose); weights need not sum to 1
func _blend(m: Member, names: Array[String], list: Array) -> void:
	for b: String in names:
		var ix: int = m.bones.get(b, -1)
		if ix < 0:
			continue
		var qx := 0.0
		var qy := 0.0
		var qz := 0.0
		var qw := 0.0
		var pp := Vector3.ZERO
		var wsum := 0.0
		var has_ref := false
		var ref := Quaternion.IDENTITY
		var rq: Quaternion = m.rest_q[b]
		var rp: Vector3 = m.rest_p[b]
		for e: Array in list:
			var w: float = e[1]
			if w <= 1e-4:
				continue
			var q := rq
			var p := rp
			if e[0] != "rest":
				var pe: Dictionary = poses.get(e[0], {})
				if pe.has(b):
					q = pe[b].get("q", rq)
					p = pe[b].get("p", rp)
			if not has_ref:
				ref = q
				has_ref = true
			var s := -w if ref.dot(q) < 0.0 else w
			qx += q.x * s
			qy += q.y * s
			qz += q.z * s
			qw += q.w * s
			pp += p * w
			wsum += w
		if wsum == 0.0:
			continue
		m.sk.set_bone_pose_rotation(ix, Quaternion(qx, qy, qz, qw).normalized())
		m.sk.set_bone_pose_position(ix, pp / wsum)


# ---- the song: onset lists with what each hit is for (hand, place on the keyboard, crash or hat)
func beat_of(t: float) -> float:
	return (t - beat0) / spb


func env_at(nm: String, t: float) -> float:
	var a: Array = env[nm]
	var f := clampf(t * env_fps, 0.0, a.size() - 1.001)
	var i := int(f)
	var k := f - i
	return (float(a[i]) * (1.0 - k) + float(a[i + 1]) * k) / 99.0


func _on_beat(t: float) -> bool:
	var ph := fmod(beat_of(t), 1.0)
	return minf(ph, 1.0 - ph) * spb < 0.06


func _prep_song(b: Dictionary) -> void:
	bpm = b.bpm
	beat0 = b.beat0
	duration = b.duration
	spb = 60.0 / bpm
	env = b.env
	env_fps = env.fps
	var hand := 0
	var ks: Array = b["keys"]
	for i in ks.size():
		var t: float = ks[i]
		var both := env_at("keys", t) > 0.72 and _on_beat(t)
		var gap: float = t - float(ks[i - 1]) if i > 0 else 9.0
		if gap > 0.45:
			hand = 0 if _rnd() < 0.5 else 1
		else:
			hand ^= 1
		if both or hand == 0:
			keys_l.append(Hit.new(t, _rnd()))
		if both or hand == 1:
			keys_r.append(Hit.new(t, _rnd()))
	# crash: on a bar's downbeat where a kick lands and the band gets louder (the low end over the next two seconds beats the last two) or every eighth bar
	var cr: Array[float] = []
	var kicks: Array = b["kick"]
	var k := 1
	while beat0 + k * spb < duration:
		var t := beat0 + k * spb
		var found := NAN
		for x: float in kicks:
			if absf(x - t) < 0.07:
				found = x
				break
		if not is_nan(found):
			var up := 0.0
			var s := 0.25
			while s <= 2.0:
				up += env_at("low", t + s) - env_at("low", t - s)
				s += 0.25
			if up / 8.0 > 0.12 or ((k - 1) / 4) % 8 == 0:
				cr.append(found)
		k += 4
	for t: float in b["hat"]:
		var hit := false
		for c: float in cr:
			if absf(c - t) < 0.1:
				hit = true
				break
		if not hit:
			right.append(Hit.new(t))
	for t: float in cr:
		right.append(Hit.new(t, 0.0, true))
		crashes.append(Hit.new(t))
	right.sort_custom(func(a: Hit, c: Hit) -> bool: return a.t < c.t)
	for t: float in b["snare"]:
		snare.append(Hit.new(t))
	for t: float in kicks:
		kick.append(Hit.new(t))


## onset list helpers: the index of the last hit at or before t (-1 if none); the next one is index + 1
func _around(list: Array[Hit], t: float) -> int:
	var lo := 0
	var hi := list.size()
	while lo < hi:
		var m := (lo + hi) >> 1
		if list[m].t <= t:
			lo = m + 1
		else:
			hi = m
	return lo - 1


## a stick / key: 1 at the hit, rebounding over `rel` s; drops in over `pre` s before the next hit
func _strike(list: Array[Hit], i: int, t: float, pre: float, rel: float, hold: float = 0.0) -> float:
	var d := 0.0
	if i >= 0:
		var s := t - list[i].t
		d = 1.0 if s < hold else 1.0 - smooth((s - hold) / rel)
	if i + 1 < list.size():
		d = maxf(d, smooth(1.0 - (list[i + 1].t - t) / pre))
	return d


# ---- the members' moves
func _singer(m: Member, t: float) -> void:
	var b := beat_of(t)
	var v := maxf(env_at("sing", t), env_at("sing", t + 0.3))      # a breath early: the mic comes up before the line
	var phrase := 0.0
	var s := -0.6
	while s <= 1.2 + 1e-6:
		phrase += env_at("sing", t + s)
		s += 0.3
	phrase /= 7.0
	var low := 1.0 - smooth((phrase - 0.12) / 0.15)
	var hi := smooth((v - 0.62) / 0.22) * (1.0 - low)
	var energy := 0.45 + 0.55 * env_at("low", t)
	var w_l := smooth(0.5 + 0.5 * cos(PI * (b - 1.0)))
	var dip := pow(0.5 + 0.5 * cos(TAU * b), 2.0) * energy
	_blend(m, _all, [["sway_L", w_l * (1.0 - dip)], ["sway_R", (1.0 - w_l) * (1.0 - dip)], ["sway_L_dn", w_l * dip], ["sway_R_dn", (1.0 - w_l) * dip]])
	_blend(m, _leg("R1"), [["mic_low", low], ["mic", (1.0 - low) * (1.0 - hi)], ["mic_hi", hi]])
	if hi > 0.01:      # the free foot goes up
		_blend(m, _leg("L1"), [["sway_L", w_l * (1.0 - hi)], ["sway_R", (1.0 - w_l) * (1.0 - hi)], ["mic_hi", hi]])
	m.g.rotation.y = m.base_yaw + sin(PI * b / 4.0) * 0.12      # turns to work the room, one side per bar


func _nod(m: Member, t: float, extra: float = 0.0) -> void:
	var b := beat_of(t)
	var dip := minf(1.0, pow(0.5 + 0.5 * cos(TAU * b), 3.0) * 0.8 + extra)
	_blend(m, _all, [["band_up", 1.0 - dip], ["band_dn", dip]])


func _keys(m: Member, t: float) -> void:
	_nod(m, t)
	for side: String in ["L", "R"]:
		var list: Array[Hit] = keys_l if side == "L" else keys_r
		var i := _around(list, t)
		var d := _strike(list, i, t, 0.07, 0.12, 0.06)
		var has_p := i >= 0
		var has_n := i + 1 < list.size()
		var x := list[i].x if has_p else (list[i + 1].x if has_n else 0.5)
		if has_p and has_n:
			x += (list[i + 1].x - list[i].x) * smooth((t - list[i].t - 0.1) / maxf(0.05, list[i + 1].t - list[i].t - 0.17))
		_blend(m, _leg(side + "1"), [["k%s_in_up" % side, (1.0 - x) * (1.0 - d)], ["k%s_in_dn" % side, (1.0 - x) * d], ["k%s_out_up" % side, x * (1.0 - d)], ["k%s_out_dn" % side, x * d]])


func _drums(m: Member, t: float, dt: float) -> void:
	var ki := _around(kick, t)
	var since := t - kick[ki].t if ki >= 0 else 9.0
	_nod(m, t, exp(-since * 12.0) * 0.6)
	# left stick: snare
	var si := _around(snare, t)
	var sd := _strike(snare, si, t, 0.09, 0.11)
	_blend(m, _leg("L1"), [["dL_up", 1.0 - sd], ["dL_hit", sd]])
	# right stick: hi-hat, or the crash (reaches over for it a beat early)
	var ri := _around(right, t)
	var rd := _strike(right, ri, t, 0.08, 0.1)
	var c0 := smooth(1.0 - (right[ri + 1].t - t - 0.25) / 0.3) if ri + 1 < right.size() and right[ri + 1].crash else 0.0
	var c1 := 1.0 - smooth((t - right[ri].t - 0.15) / 0.3) if ri >= 0 and right[ri].crash else 0.0
	var crash_mix := maxf(c0, c1)
	_blend(m, _leg("R1"), [["dR_up", (1.0 - rd) * (1.0 - crash_mix)], ["dR_hit", rd * (1.0 - crash_mix)], ["dR_crash_up", (1.0 - rd) * crash_mix], ["dR_crash", rd * crash_mix]])
	# kick foot: up just before the hit, stamps on it
	var until := kick[ki + 1].t - t if ki + 1 < kick.size() else 9.0
	var lift := until / 0.04 if until < 0.04 else (smooth((0.16 - until) / 0.12) if until < 0.16 else 0.0)
	_blend(m, _leg("R2"), [["band_up", 1.0 - lift], ["kick_up", lift]])
	# the kit answers: snare jumps, hat closes, crash swings, kick head thumps
	if si >= 0 and snare[si] != m.last_snare:
		m.last_snare = snare[si]
		m.snare = 1.0
	m.snare = maxf(0.0, m.snare - dt * 7.0)
	if ki >= 0 and kick[ki] != m.last_kick:
		m.last_kick = kick[ki]
		m.kick = 1.0
	m.kick = maxf(0.0, m.kick - dt * 7.0)
	if ri >= 0 and right[ri] != m.last_r:
		m.last_r = right[ri]
		if right[ri].crash:
			m.crash = 1.0
		else:
			m.hat = 1.0
	m.hat = maxf(0.0, m.hat - dt * 9.0)
	m.crash = maxf(0.0, m.crash - dt * 1.6)
	if m.k_snare != null:
		m.k_snare.scale.y = m.k_snare_s.y * (1.0 - 0.18 * m.snare)
	if m.k_hat != null:
		m.k_hat.position.y = m.k_hat_y - 0.025 * m.hat
	if m.k_crash != null:
		m.k_crash.rotation.x = m.k_crash_tilt + sin(m.crash * 14.0) * 0.35 * m.crash
	if m.k_head != null:
		m.k_head.scale = Vector3.ONE * (1.0 + 0.05 * m.kick)


func _pulse(list: Array[Hit], tt: float, k: float) -> float:
	var i := _around(list, tt)
	return exp(-(tt - list[i].t) * k) if i >= 0 else 0.0


func update(t: float, dt: float) -> void:
	if not ready:
		return
	var tt := fposmod(t, duration)
	for m: Member in members:
		match m.role:
			"singer":
				_singer(m, tt)
			"keys":
				_keys(m, tt)
			_:
				_drums(m, tt, dt)
	# what the music is doing right now, for the hall's lights: pulses are 1 on the hit and fade
	var F := feel
	F.t = tt
	F.beat = beat_of(tt)
	F.bar = floori((float(F.beat) - 1.0) / 4.0)
	F.kick = _pulse(kick, tt, 9.0)
	F.snare = _pulse(snare, tt, 10.0)
	F.crash = _pulse(crashes, tt, 2.5)
	F.low = env_at("low", tt)
	F.sing = env_at("sing", tt)
	F.keys = env_at("keys", tt)
	F.vocal = env_at("vocal", tt)
