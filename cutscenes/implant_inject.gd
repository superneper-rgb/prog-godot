class_name ImplantInject
extends Cutscene
## IMPLANT INJECTION (JS cutscenes/implant-inject.js): plays after an implant is bought at the DORBATELEPHINIUM IMPLANTS vending machine: the vent flap drops open, a claw arm reaches out, takes the player's head and spins him round (back to the machine), holds him there by the head, a second arm brings a syringe to the BACK of his neck and injects it (beads leave the needle, a glow pools under the skin and veins of it spread) while the screen goes red and the veins pulse (heartbeat); the arms let go and retract, he drops forward onto his face, tries to get up twice (failing), then a third time (hands, knees, crouch, standing hunched, upright). Everything is a pure function of the clock t, so X can skip by jumping ahead.
## ENGINE DIFFERENCE: the nape is found from the skinned vertices (core/skin_probe.gd): Godot has no raycast against a skinned mesh.

const VOICE := {"prog": "progdorbhurt.mp3"}      # Tommy's line is still to be recorded: he only gets a synthesised groan
const D := 1.45      # where he stands: metres from the machine's centre, in front of it
# the timeline, seconds
const GLIDE := 0.8
const FLAP0 := 0.9
const FLAP1 := 1.5
const CLAW0 := 1.5
const CLAW1 := 2.5
const GRIP0 := 2.5
const GRIP1 := 2.9
const SPIN0 := 3.1
const SPIN1 := 4.5
const SYR0 := 5.0
const SYR1 := 5.9
const STAB0 := 5.9
const STAB1 := 6.3
const PLUNGE0 := 6.5
const PLUNGE1 := 10.0
const PULL0 := 10.3
const PULL1 := 10.9
const RELEASE0 := 10.9
const RELEASE1 := 11.2
const CLAW_IN0 := 11.2
const CLAW_IN1 := 12.1
const SYR_IN0 := 10.9
const SYR_IN1 := 11.8
const FLAP_CLOSE0 := 12.2
const FLAP_CLOSE1 := 12.7
const FALL0 := 11.15
const FALL1 := 11.95
const STRUGGLE0 := 12.7
const UP0 := 20.6
const UP1 := 24.2
const EFFECT := 24.2
const CAM_BACK0 := 24.2
const END_T := 25.6
const ROOM_FOR_VOICE_AT := STAB1      # the voice starts when the needle is in

# ---- the body after he is let go: [time, tilt (0 upright .. 1.5 flat on his face), pose, "in" = accelerates into it (a fall)]. A pose is additive bone rotations (x, y, z radians) on top of the idle pose; the body turns about his FEET (they stay where they are), so a fall lands him out in front of the machine and a get-up ends where he fell from. ----
const FLAT := {&"head": Vector3(0.35, 0, 0), &"neck": Vector3(0.1, 0, 0)}
const PUSH := {&"upper_armL": Vector3(-1.45, 0, -0.35), &"upper_armR": Vector3(-1.45, 0, 0.35), &"forearmL": Vector3(-0.35, 0, 0), &"forearmR": Vector3(-0.35, 0, 0), &"head": Vector3(-0.55, 0, 0), &"neck": Vector3(-0.25, 0, 0), &"spine1": Vector3(-0.18, 0, 0), &"spine2": Vector3(-0.22, 0, 0), &"thighL": Vector3(0.05, 0, 0.08), &"thighR": Vector3(0.05, 0, -0.08)}
const KNEEL := {&"upper_armL": Vector3(-1.45, 0, -0.35), &"upper_armR": Vector3(-1.45, 0, 0.35), &"forearmL": Vector3(-0.35, 0, 0), &"forearmR": Vector3(-0.35, 0, 0), &"head": Vector3(-0.4, 0, 0), &"neck": Vector3(-0.25, 0, 0), &"spine1": Vector3(-0.18, 0, 0), &"spine2": Vector3(-0.22, 0, 0), &"thighL": Vector3(-1.35, 0, 0.12), &"thighR": Vector3(-1.35, 0, -0.12), &"shinL": Vector3(1.5, 0, 0), &"shinR": Vector3(1.5, 0, 0)}
const CROUCH := {&"upper_armL": Vector3(-0.9, 0, -0.2), &"upper_armR": Vector3(-0.9, 0, 0.2), &"forearmL": Vector3(-0.5, 0, 0), &"forearmR": Vector3(-0.5, 0, 0), &"thighL": Vector3(-1.2, 0, 0.1), &"thighR": Vector3(-0.7, 0, -0.1), &"shinL": Vector3(1.5, 0, 0), &"shinR": Vector3(1.2, 0, 0), &"spine1": Vector3(0.35, 0, 0), &"spine2": Vector3(0.3, 0, 0), &"head": Vector3(0.1, 0, 0)}
const HUNCH := {&"upper_armL": Vector3(-0.25, 0, -0.15), &"upper_armR": Vector3(-0.3, 0, 0.15), &"forearmL": Vector3(-0.35, 0, 0), &"forearmR": Vector3(-0.35, 0, 0), &"thighL": Vector3(-0.4, 0, 0.05), &"thighR": Vector3(-0.3, 0, -0.05), &"shinL": Vector3(0.5, 0, 0), &"shinR": Vector3(0.4, 0, 0), &"spine1": Vector3(0.3, 0, 0), &"spine2": Vector3(0.3, 0, 0), &"head": Vector3(0.35, 0, 0)}
const GU: Array = [
	[FALL0, 0.0, {}, false], [FALL1, 1.5, FLAT, true], [12.9, 1.5, FLAT, false],
	[13.9, 1.3, PUSH, false], [14.3, 1.33, PUSH, false], [14.8, 1.5, FLAT, true], [15.8, 1.5, FLAT, false],
	[16.9, 1.28, PUSH, false], [17.7, 1.42, KNEEL, false], [18.2, 1.4, KNEEL, false], [18.8, 1.5, FLAT, true], [19.8, 1.5, FLAT, false],
	[20.7, 1.3, PUSH, false], [21.5, 1.42, KNEEL, false], [22.1, 1.4, KNEEL, false], [23.0, 0.75, CROUCH, false], [23.7, 0.2, HUNCH, false], [UP1, 0.0, {}, false],
]

var t := 0.0
var plasmid: Variant = null
var skipping := false
var lvl := 0.0
var beat_n := -1
var voiced := false
var effect_done := false
var back_set := false
var neck_off: Variant = null
var cue_done: Array[bool] = []
var _cues: Array = []
var _from_pos := Vector3.ZERO
var _from_look := Vector3.ZERO
var _from_fov := 50.0
var _M := Vector3.ZERO
var _fwd := Vector3.ZERO
var _back := Vector3.ZERO
var _side := Vector3.ZERO
var _spot := Vector3.ZERO
var _start := Vector3.ZERO
var _yaw0 := 0.0
var _spin_dir := 1.0
var _char_id := "prog"
var _neck_back := Vector3.ZERO
var _probe: SkinProbe = null
var _fluid: Dictionary = {}
var _vc: VoiceClips
var _overlay: ImplantOverlay
var _snd: Dictionary = {}


func _ready() -> void:
	name = "ImplantInject"
	_vc = VoiceClips.new("res://assets/sfx/vending/", VOICE)
	add_child(_vc)
	_cues = [
		[FLAP0, _mech.bind("mechRelay")], [FLAP0 + 0.2, func() -> void:
			_mech("mechClunk")
			_hiss(0.6)],
		[CLAW0, _servo.bind(1.0, 240.0)], [GRIP0, _clank.bind(380.0, 0.2)], [GRIP0 + 0.2, _clank.bind(300.0, 0.12)],
		[SPIN0, _servo.bind(1.5, 180.0)], [SPIN1, _mech.bind("mechKnock")],
		[SYR0, func() -> void:
			_mech("mechRelay")
			_servo(0.9, 340.0)], [STAB0 + 0.25, _stab],
		[PLUNGE0, _hiss.bind(3.5)], [PULL0, _servo.bind(0.6, 420.0)], [RELEASE0, func() -> void:
			_clank(260.0, 0.2)
			_mech("mechHiss")],
		[CLAW_IN0, _servo.bind(0.9, 200.0)], [SYR_IN0, _servo.bind(0.9, 300.0)], [FLAP_CLOSE0 + 0.35, _mech.bind("mechClunk")],
		[FALL1 - 0.12, _thud], [13.9, _groan.bind(1.2)], [14.6, _thud], [16.9, _groan.bind(1.5)],
		[18.6, _thud], [20.7, _gasp], [21.6, _groan.bind(1.6)], [23.3, _gasp],
	]


# ---- sounds (synthesised as the JS's Sfx helpers; the machine's own mech sounds are reused) ----

func _s(key: String, dur: float, tones: Array, noises: Array, wet: float) -> void:
	if not _snd.has(key):
		_snd[key] = Cutscene.synth(dur, tones, noises)
	Game.sfx.clip(_snd[key], {"wet": wet})


func _mech(id: String) -> void:
	Game.sfx.play(id)


func _servo(len_: float, f: float) -> void:
	_s("servo%d_%d" % [roundi(len_ * 10.0), roundi(f)], len_ + 0.05, [[0.0, len_, f, f * 1.8, &"sawtooth", 0.05, 0.08]], [[0.0, len_, &"bandpass", 1200.0, 2600.0, 4.0, 0.05, 0.1]], 0.2)


func _clank(f: float, g: float) -> void:
	_s("clank%d" % roundi(f), 0.27, [[0.0, 0.22, f, f * 0.42, &"triangle", g, 0.002]], [[0.0, 0.09, &"bandpass", 3200.0, 1400.0, 2.4, g * 0.8, 0.002]], 0.32)


func _stab() -> void:
	_s("stab", 0.35, [[0.0, 0.3, 90.0, 40.0, &"sine", 0.35, 0.002]], [[0.0, 0.12, &"highpass", 3000.0, 3000.0, 0.7, 0.12, 0.002]], 0.1)


func _hiss(len_: float) -> void:
	_s("hiss%d" % roundi(len_ * 10.0), len_ + 0.05, [], [[0.0, len_, &"bandpass", 2400.0, 900.0, 1.4, 0.05, 0.3]], 0.2)


func _thud() -> void:
	_s("thud", 0.4, [[0.0, 0.35, 85.0, 38.0, &"sine", 0.55, 0.002]], [[0.0, 0.2, &"lowpass", 600.0, 180.0, 0.7, 0.25, 0.002]], 0.1)


func _groan(len_: float) -> void:
	_s("groan%d" % roundi(len_ * 10.0), len_ + 0.05, [[0.0, len_, 150.0, 85.0, &"sawtooth", 0.07, 0.15]], [[0.0, len_, &"bandpass", 700.0, 420.0, 3.0, 0.05, 0.15]], 0.2)


func _gasp() -> void:
	_s("gasp", 0.55, [], [[0.0, 0.5, &"bandpass", 1400.0, 700.0, 1.2, 0.09, 0.06]], 0.15)


func _beat(k: float) -> void:
	if not _snd.has("beat"):
		_snd["beat"] = Cutscene.synth(0.5, [[0.0, 0.2, 66.0, 36.0, &"sine", 0.5, 0.002], [0.27, 0.18, 58.0, 34.0, &"sine", 0.32, 0.002]], [])
	Game.sfx.clip(_snd["beat"], {"gain": k, "wet": 0.05})


# ---- the machine's frame: fwd = from the machine out to the player; back = his back (towards the machine) once he has been turned round ----

func _machine() -> VendingInjector:
	return Game.level.get(&"vending_injector") if Game.level != null else null


func _frame() -> bool:
	var m := _machine()
	if m == null:
		return false
	_M = m.global_position
	var psi := m.global_rotation.y
	_fwd = Vector3(sin(psi), 0.0, cos(psi))
	_side = Vector3(_fwd.z, 0.0, -_fwd.x)
	_back = -_fwd
	_spot = _M + _fwd * D
	return true


# ---- the heart: 0..1, a double thump about once every 0.8 s ----

static func beat_at(tt: float, bpm: float) -> float:
	var ph := fmod(tt * bpm / 60.0, 1.0)
	var a := exp(-pow(ph / 0.07, 2.0))
	var b := 0.6 * exp(-pow((ph - 0.33) / 0.08, 2.0))
	return maxf(a, b)


static func intensity(tt: float) -> float:
	return ease_(seg(tt, STAB1, STAB1 + 1.8)) * (1.0 - 0.5 * ease_(seg(tt, 13.0, 19.0))) * (1.0 - ease_(seg(tt, 23.4, 25.2)))


static func held(tt: float) -> float:
	return ease_(seg(tt, GRIP1, GRIP1 + 0.5)) * (1.0 - ease_(seg(tt, RELEASE0, RELEASE0 + 0.25)))


func _yaw_at(tt: float) -> float:
	var y := _yaw0 + _spin_dir * PI * ease_(seg(tt, SPIN0, SPIN1))
	if tt > 23.2:      # a stagger as he comes up
		y += 0.2 * sin((tt - 23.2) * 3.1) * (1.0 - ease_(seg(tt, 23.6, UP1 + 0.8)))
	return y


func _body_at(tt: float) -> Dictionary:
	var i := 0
	while i < GU.size() - 2 and tt >= float(GU[i + 1][0]):
		i += 1
	var a: Array = GU[i]
	var b: Array = GU[i + 1]
	var raw := seg(tt, a[0], b[0])
	var u := ease_in(raw) if b[3] else ease_(raw)
	var pose := {}
	var pa: Dictionary = a[2]
	var pb: Dictionary = b[2]
	for k: StringName in pa:
		pose[k] = (pa[k] as Vector3).lerp(pb.get(k, Vector3.ZERO), u)
	for k: StringName in pb:
		if not pa.has(k):
			pose[k] = Vector3.ZERO.lerp(pb[k], u)
	var th := 0.0
	if tt > float(GU[0][0]) and tt < float(GU[GU.size() - 1][0]):
		th = lerpf(a[1], b[1], u)
	return {"th": th, "pose": pose}


func _pose_hook(a: Animator) -> void:
	var h := held(t)
	var talk := lvl
	var pain := ease_(seg(t, STAB1, STAB1 + 0.4)) * (1.0 - ease_(seg(t, RELEASE0 + 0.2, RELEASE1 + 0.4)))
	var flail := sin(t * 17.0) * h
	add_pose(a, &"head", -0.4 * h + 0.06 * sin(t * 9.0) * talk, 0.05 * sin(t * 31.0) * pain, 0.05 * sin(t * 13.0) * pain)
	add_pose(a, &"neck", -0.15 * h, 0.0, 0.0)
	add_pose(a, &"spine2", 0.12 * h * (1.0 - pain) + 0.06 * sin(t * 11.0) * pain, 0.0, 0.0)
	add_pose(a, &"upper_armL", -0.2 * h + 0.5 * pain * sin(t * 15.0) * h, 0.0, -0.25 * h)
	add_pose(a, &"upper_armR", -0.2 * h - 0.5 * pain * sin(t * 15.0 + 1.0) * h, 0.0, 0.25 * h)
	add_pose(a, &"forearmL", -0.5 * h, 0.0, 0.0)
	add_pose(a, &"forearmR", -0.5 * h, 0.0, 0.0)
	add_pose(a, &"thighL", 0.12 * h + 0.18 * flail, 0.0, 0.0)
	add_pose(a, &"thighR", 0.12 * h - 0.18 * flail, 0.0, 0.0)
	if t > FALL0:      # on the ground: the keyframed pose, arms trembling while they bear weight
		var pose: Dictionary = _body_at(t)["pose"]
		var ua: Variant = pose.get(&"upper_armL")
		var bear := clampf(-(ua as Vector3).x / 1.45, 0.0, 1.0) if ua != null else 0.0
		var tr := sin(t * 36.0) * 0.045 * bear
		var br := 0.025 * sin(t * 4.5)
		for k: StringName in pose:
			var v: Vector3 = pose[k]
			add_pose(a, k, v.x, v.y, v.z)
		add_pose(a, &"upper_armL", tr, 0.0, 0.0)
		add_pose(a, &"upper_armR", -tr, 0.0, 0.0)
		add_pose(a, &"forearmL", tr * 0.8, 0.0, 0.0)
		add_pose(a, &"forearmR", -tr * 0.8, 0.0, 0.0)
		add_pose(a, &"spine1", br, 0.0, 0.0)
		add_pose(a, &"head", -br * 1.4 + 0.06 * sin(t * 2.3), 0.1 * sin(t * 1.7), 0.0)


# ---- fluid under the skin behind the neck: beads leave the needle, a glow pools and veins of it spread as the plunger goes in ----

func _fluid_mat(color: Color, op: float, priority: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://cutscenes/implant_fluid.gdshader")
	var c := color.srgb_to_linear()
	m.set_shader_parameter(&"col", Vector3(c.r, c.g, c.b))
	m.set_shader_parameter(&"opacity", op)
	m.render_priority = priority
	return m


static func _catmull(pts: Array, u: float) -> Vector3:
	var n := pts.size()
	var f := u * (n - 1)
	var i := mini(floori(f), n - 2)
	var w := f - i
	var p0: Vector3 = pts[maxi(i - 1, 0)] if i > 0 else (pts[0] as Vector3) * 2.0 - (pts[1] as Vector3)
	var p1: Vector3 = pts[i]
	var p2: Vector3 = pts[i + 1]
	var p3: Vector3 = pts[i + 2] if i + 2 < n else (pts[n - 1] as Vector3) * 2.0 - (pts[n - 2] as Vector3)
	return p1.cubic_interpolate(p2, p0, p3, w)


func _tube_mesh(pts: Array, r: float) -> ArrayMesh:
	var P := PackedVector3Array()
	var uv := PackedVector2Array()
	var I := PackedInt32Array()
	var seg_n := 28
	var sides := 6
	for s in seg_n + 1:
		var u := float(s) / seg_n
		var c := _catmull(pts, u)
		var a := _catmull(pts, minf(u + 0.02, 1.0))
		var b := _catmull(pts, maxf(u - 0.02, 0.0))
		var tg := (a - b).normalized()
		var sd := tg.cross(Vector3.UP)
		if sd.length_squared() < 1e-5:
			sd = tg.cross(Vector3.RIGHT)
		sd = sd.normalized()
		var up := sd.cross(tg).normalized()
		for k in sides:
			var ang := TAU * k / sides
			P.append(c + (sd * cos(ang) + up * sin(ang)) * r)
			uv.append(Vector2(u, 0.0))
	for s in seg_n:
		for k in sides:
			var a := s * sides + k
			var b := s * sides + (k + 1) % sides
			var c := (s + 1) * sides + (k + 1) % sides
			var d := (s + 1) * sides + k
			I.append_array([a, b, c, a, c, d])
	return Goggles.indexed_mesh(P, I, uv)


func _build_fluid(an: Animator, color: Color) -> void:
	var rec: Variant = an.by_key.get(&"neck")
	if rec == null:
		return
	var sc: float = an.B.scale
	var att := BoneAttachment3D.new()
	att.bone_idx = rec.bone
	an.skel.add_child(att)
	att.on_skeleton_update()
	var root := Node3D.new()
	att.add_child(root)
	var tubes: Array = []
	var curves: Array = []
	var beads: Array = []
	var drops: Array = []
	var mats: Array[ShaderMaterial] = []
	var mk := func(pts: Array, r: float) -> void:      # axes of root: x = his right, y up, z = forward (the back of his neck faces -z); the veins wrap round the neck and shoulders
		var scaled := []
		for p: Vector3 in pts:
			scaled.append(p * sc)
		curves.append(scaled)
		var m := _fluid_mat(color, 1.0, 50)
		mats.append(m)
		var o := MeshInstance3D.new()
		o.mesh = _tube_mesh(scaled, r * sc)
		o.material_override = m
		o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(o)
		tubes.append([o, m, 0.0])
	mk.call([Vector3(0, 0, 0.03), Vector3(0.01, 0.06, 0.05), Vector3(-0.02, 0.12, 0.08), Vector3(0.01, 0.2, 0.1)], 0.011)      # up the nape under the skull
	mk.call([Vector3(0, 0, 0.03), Vector3(0.05, 0.03, 0.05), Vector3(0.1, 0.06, 0.09), Vector3(0.15, 0.07, 0.13)], 0.009)      # round the right of the neck
	mk.call([Vector3(0, 0, 0.03), Vector3(-0.05, 0.03, 0.05), Vector3(-0.1, 0.06, 0.09), Vector3(-0.15, 0.07, 0.13)], 0.009)      # round the left
	mk.call([Vector3(0, 0, 0.03), Vector3(0.01, -0.07, 0.03), Vector3(-0.01, -0.15, 0.02), Vector3(0.01, -0.26, 0.01)], 0.012)      # down the spine
	mk.call([Vector3(0, 0, 0.03), Vector3(0.06, -0.04, 0.04), Vector3(0.13, -0.05, 0.05), Vector3(0.22, -0.09, 0.06)], 0.009)      # along the right shoulder
	mk.call([Vector3(0, 0, 0.03), Vector3(-0.06, -0.04, 0.04), Vector3(-0.12, -0.06, 0.05), Vector3(-0.21, -0.1, 0.06)], 0.009)      # along the left shoulder
	mk.call([Vector3(0.01, 0.12, 0.08), Vector3(0.06, 0.16, 0.09), Vector3(0.1, 0.22, 0.09)], 0.006)
	mk.call([Vector3(-0.02, 0.12, 0.08), Vector3(-0.07, 0.17, 0.09), Vector3(-0.1, 0.23, 0.09)], 0.006)
	mk.call([Vector3(0.01, -0.15, 0.02), Vector3(0.07, -0.2, 0.02), Vector3(0.1, -0.28, 0.02)], 0.006)
	mk.call([Vector3(-0.01, -0.15, 0.02), Vector3(-0.06, -0.21, 0.02), Vector3(-0.09, -0.3, 0.02)], 0.006)
	var bead := func(r: float, op: float, priority: int) -> Array:
		var s := SphereMesh.new()
		s.radius = r * sc
		s.height = r * sc * 2.0
		s.radial_segments = 10
		s.rings = 6
		var m := _fluid_mat(color, op, priority)
		mats.append(m)
		var o := MeshInstance3D.new()
		o.mesh = s
		o.material_override = m
		o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(o)
		return [o, m]
	for i in 6:      # heads of the flow running down the first six veins
		beads.append((bead.call(0.014, 1.0, 52) as Array)[0])
	for i in 7:      # droplets leaving the needle tip into the skin
		drops.append([(bead.call(0.008, 1.0, 52) as Array)[0], float(i) / 7.0])
	var pl: Array = bead.call(0.03, 0.9, 51)
	(pl[0] as Node3D).position.z = 0.035 * sc
	var hl: Array = bead.call(0.06, 0.22, 49)
	(hl[0] as Node3D).position.z = 0.035 * sc
	# follows the neck; placed so its axes match the standing, back-turned body
	root.global_transform = Transform3D(an.actor.global_basis.orthonormalized(), _neck_back)
	_fluid = {"att": att, "root": root, "tubes": tubes, "curves": curves, "beads": beads, "drops": drops, "pool": pl[0], "pool_m": pl[1], "halo": hl[0], "halo_m": hl[1], "mats": mats, "sc": sc}


func _update_fluid(inject: float) -> void:
	if _fluid.is_empty():
		return
	var grow := ease_(seg(inject, 0.04, 1.0))
	var sc: float = _fluid["sc"]
	var b := 0.65 + 0.35 * beat_at(t, 80.0)
	var fade := 1.0 - ease_(seg(t, FALL1 + 1.0, 15.2))
	var i := 0
	for e: Array in _fluid["tubes"]:
		var k := clampf(grow * 1.5 - (0.55 if i >= 6 else (0.15 if i > 0 else 0.0)), 0.0, 1.0)
		e[2] = k
		(e[1] as ShaderMaterial).set_shader_parameter(&"grow", k)
		i += 1
	i = 0
	for bd: MeshInstance3D in _fluid["beads"]:      # the head of each vein's flow
		var k: float = _fluid["tubes"][i][2]
		bd.visible = k > 0.01 and k < 0.995 and inject < 0.999
		if bd.visible:
			bd.position = _catmull(_fluid["curves"][i], k)
		i += 1
	for d: Array in _fluid["drops"]:
		var o: MeshInstance3D = d[0]
		var u := fmod(float(d[1]) + t * 1.7, 1.0)
		var vis := inject > 0.01 and inject < 0.995
		o.visible = vis
		if vis:
			o.position = Vector3(sin(float(d[1]) * 40.0) * 0.006 * sc, 0.0, (0.004 + u * 0.05) * sc)
			o.scale = Vector3.ONE * (1.0 - u * 0.6)
	var pl: Node3D = _fluid["pool"]
	var hl: Node3D = _fluid["halo"]
	pl.scale = Vector3.ONE * ((0.3 + 1.7 * minf(1.0, inject * 1.3)) * (0.9 + 0.2 * b))
	pl.visible = inject > 0.005
	hl.scale = Vector3.ONE * ((0.5 + 2.2 * minf(1.0, inject * 1.3)) * (0.9 + 0.2 * b))
	hl.visible = inject > 0.005
	for m: ShaderMaterial in _fluid["mats"]:
		var op := fade * (0.55 + 0.45 * b)
		if m == _fluid["halo_m"]:
			op = 0.22 * fade * b
		elif m == _fluid["pool_m"]:
			op = 0.9 * fade * b
		m.set_shader_parameter(&"opacity", minf(1.0, op))


# ---- the machine's arms and the camera, placed after the body is posed ----

func _post(an: Animator) -> void:
	var P := Game.player
	var B := an.B
	var a := an.actor
	var sc: float = B.scale
	var inj := _machine()
	var body := _body_at(t)
	var th: float = body["th"]
	var pose: Dictionary = body["pose"]
	var lift := 0.1 * held(t)
	var yaw := _yaw_at(t)
	var shin: Variant = pose.get(&"shinL")
	var fold := clampf((shin as Vector3).x / 1.7, 0.0, 1.0) if shin != null else 0.0
	var L_ := B.pivot * sc * (1.0 - 0.5 * fold)      # knees folded under him: he is shorter
	# he turns about his feet: they stay on the spot while the body tips over (a fall lands him out in front of the machine, a get-up ends where he fell from)
	a.rotation = Vector3(th, yaw, 0.0)
	a.position = Vector3(P.x + _fwd.x * L_ * sin(th), P.y + L_ * cos(th) + lift, P.z + _fwd.z * L_ * sin(th))
	if th > 0.03:      # tilted over: sink / lift him until the lowest part of him rests on the floor
		if _probe == null:
			_probe = SkinProbe.new(an)
		an.skel.force_update_all_bone_transforms()
		var low := _probe.lowest()
		if low < INF:
			a.position.y += (P.y - low) * clampf(th / 0.4, 0.0, 1.0)
	var hb: Variant = an.by_key.get(&"head")
	var nb: Variant = an.by_key.get(&"neck")
	var head_w: Vector3 = an.bone_world_pos(hb.bone) if hb != null else Vector3(P.x, P.y + B.cam_height, P.z)
	var neck_w: Vector3 = an.bone_world_pos(nb.bone) if nb != null else head_w - Vector3(0.0, 0.1 * sc, 0.0)
	var upright := th < 0.2
	if neck_off == null and t >= SPIN1 and upright:      # where the back of his neck really is (a ray from behind, once)
		if _probe == null:
			_probe = SkinProbe.new(an)
		an.skel.force_update_all_bone_transforms()
		var o := neck_w + _back * (1.0 * sc) + Vector3(0.0, 0.02 * sc, 0.0)
		var hit := _probe.ray_hit(o, _fwd, 2.0 * sc)      # from the machine's side towards the street: the first thing it meets is the nape
		neck_off = hit - neck_w if not is_nan(hit.x) else _back * (0.12 * sc)
	_neck_back = neck_w + (neck_off as Vector3 if neck_off != null else _back * (0.12 * sc))
	var plunge := ease_(seg(t, PLUNGE0, PLUNGE1))
	if inj != null:
		inj.set_liquid(int(plasmid["color"]) if plasmid != null else 0xff3b30)
		inj.flap(ease_(seg(t, FLAP0, FLAP1)) * (1.0 - ease_(seg(t, FLAP_CLOSE0, FLAP_CLOSE1))))
		# the claw takes the head from above while he is held
		var head_top := Vector3(P.x, P.y + B.cam_height + 0.2 * sc + lift, P.z)
		var wrist := head_top + _fwd * 0.04 + Vector3(0.0, 0.14 + 0.14 * (1.0 - ease_(seg(t, GRIP0, GRIP1))), 0.0)
		var cdir := (Vector3.DOWN - _fwd * 0.18).normalized()
		inj.claw_place(wrist, cdir, ease_(seg(t, CLAW0, CLAW1)) * (1.0 - ease_(seg(t, CLAW_IN0, CLAW_IN1))), -(yaw - _yaw0), ease_(seg(t, GRIP0, GRIP1)) * (1.0 - ease_(seg(t, RELEASE0, RELEASE1))), 0.9 + sc)
		# the syringe comes from the machine, which is behind him: out to a hover just behind the neck, in through the skin, the plunger, out again
		var hover := ease_(seg(t, SYR0, SYR1))
		var stab := ease_(seg(t, STAB0, STAB1)) * (1.0 - ease_(seg(t, PULL0, PULL1)))
		var sdir := -_back      # the way the needle points: forward into the nape (a little downhill: the arm comes up from below)
		sdir.y -= 0.1
		sdir = sdir.normalized()
		var tip := _neck_back + _back * (0.3 * (1.0 - stab) - 0.015 * stab)      # 0.3 m behind the skin while hovering, 1.5 cm inside when stabbed
		var swrist := tip - sdir * inj.needle()
		swrist.y += 0.1 * (1.0 - hover)
		inj.syringe_place(swrist, sdir, hover * (1.0 - ease_(seg(t, SYR_IN0, SYR_IN1))), plunge)
	if _fluid.is_empty() and t >= STAB1 - 0.1 and upright:
		_build_fluid(an, Color.hex((int(plasmid["color"]) << 8) | 0xff) if plasmid != null else Color.hex(0xff3b30ff))
	_update_fluid(plunge)
	_update_overlay()
	# ---- camera (stays on the pavement's line and above the street furniture) ----
	var mid := _M.lerp(_spot, 0.5)
	var look_head := Vector3(_spot.x, P.y + B.cam_height * 0.85, _spot.z)
	var ly := _spot + _fwd * 0.8
	var pos: Vector3
	var look: Vector3
	var fov := 45.0
	var gy := P.y      # (the JS's camera heights are for its street at y = 0)
	if t < CLAW0 + 0.9:      # wide, three-quarter from the front
		pos = mid + _side * 5.0 + _fwd * 2.2
		pos.y = gy + 1.7
		look = mid + _fwd * 0.1
		look.y = gy + 1.25
		fov = 50.0
	elif t < SYR0 - 0.2:
		var u := seg(t, CLAW0 + 0.9, SYR0)
		pos = mid + _side * lerpf(4.4, 3.4, u) + _fwd * lerpf(1.8, 1.2, u)
		pos.y = gy + 1.7
		look = look_head
		look.y += 0.15
		fov = lerpf(50.0, 42.0, u)
	elif t < PLUNGE0 + 2.0:      # the needle going into the back of his neck, in profile (from the side the claw arm is not on: it would cover the neck)
		var u := seg(t, SYR0, PLUNGE0 + 2.0)
		pos = _neck_back - _side * lerpf(1.9, 1.5, u) + _fwd * 0.3
		pos.y = _neck_back.y + 0.1
		look = _neck_back + _fwd * 0.02
		fov = lerpf(34.0, 28.0, u)
	elif t < PULL0:      # higher and closer: the glow spreading over his neck and shoulders
		var u := seg(t, PLUNGE0 + 2.0, PULL0)
		pos = _neck_back - _side * lerpf(1.0, 0.8, u) + _fwd * 0.35
		pos.y = _neck_back.y + lerpf(0.6, 0.45, u)
		look = _neck_back
		look.y -= 0.1
		fov = 32.0
	elif t < STRUGGLE0:      # he drops
		pos = ly + _side * 4.6
		pos.y = gy + 1.3
		look = ly
		look.y = gy + 0.45
		fov = 50.0
	elif t < UP0:      # the struggle, low
		var u := seg(t, STRUGGLE0, UP0)
		pos = ly + _side * lerpf(4.4, 3.5, u) + _fwd * 0.4
		pos.y = gy + lerpf(1.0, 0.85, u)
		look = ly
		look.y = gy + 0.3
		fov = 48.0
	else:
		var u := seg(t, UP0, UP1)
		pos = ly + _side * lerpf(3.5, 4.4, u) + _fwd * lerpf(0.4, 1.4, u)
		pos.y = gy + lerpf(0.85, 1.6, u)
		look = _spot + _fwd * lerpf(0.8, 0.1, u)
		look.y = gy + lerpf(0.3, B.cam_height * 0.7, u)
		fov = 48.0
	var k0 := ease_(t / GLIDE)      # eases in from the gameplay camera
	if k0 < 1.0:
		pos = pos.lerp(_from_pos, 1.0 - k0)
		look = look.lerp(_from_look, 1.0 - k0)
		fov = lerpf(_from_fov, fov, k0)
	if t >= CAM_BACK0:      # and back out to it
		if not back_set:
			back_set = true
			Game.rig.snap_to(P)
			_from_pos = camera.pos
			_from_look = camera.look
			_from_fov = camera.fov
		var k := ease_(seg(t, CAM_BACK0, END_T - 0.1))
		pos = _from_pos.lerp(Game.rig.pos, k)
		look = _from_look.lerp(Game.rig.look, k)
		fov = lerpf(_from_fov, Config.fov, k)
	var jolt := ease_(seg(t, STAB0 + 0.2, STAB0 + 0.3)) * (1.0 - ease_(seg(t, STAB0 + 0.3, STAB0 + 0.8))) * 0.03
	pos.y += jolt * sin(t * 70.0)
	shot(pos, look, fov)


func _update_overlay() -> void:
	if _overlay == null:
		return
	var I := intensity(t)
	var b := beat_at(t, 74.0 + 22.0 * I)
	_overlay.modulate.a = I * (0.5 + 0.5 * b)
	# the veins creep in from the screen edges as the injection goes on (thick ones first, branches after), hold, then shrink back out to the edges at the end
	_overlay.G = ease_(seg(t, STAB1, PLUNGE1 + 1.5)) * (1.0 - ease_(seg(t, 20.8, 24.2)))
	_overlay.pulse = 0.8 + 0.9 * b * I
	_overlay.tint = 0.3 * I * (0.6 + 0.4 * b)
	_overlay.flash = 0.55 * maxf(0.0, 1.0 - (t - STAB0 - 0.3) / 0.35) * (1.0 if t > STAB0 + 0.3 else 0.0)
	_overlay.queue_redraw()
	var n := floori(t * (74.0 + 22.0 * I) / 60.0)
	if n != beat_n:
		beat_n = n
		if I > 0.15 and not skipping:
			_beat(I)


# ---- control ----

func play(p: Variant) -> bool:
	if on:
		return false
	var an := Game.animator
	if an == null:
		push_warning("Implant cutscene: no player model")
		return false
	if not _frame():
		push_warning("Implant cutscene: no vending machine in this level")
		return false
	_probe = null
	_fluid = {}
	_char_id = Game.char_pick
	on = true
	t = 0.0
	plasmid = p
	skipping = false
	lvl = 0.0
	beat_n = -1
	voiced = false
	effect_done = false
	back_set = false
	neck_off = null
	cue_done.resize(_cues.size())
	cue_done.fill(false)
	var P := Game.player
	P.sprinting = false
	P.crouching = false
	_start = Vector3(P.x, P.y, P.z)
	_yaw0 = atan2(-_fwd.x, -_fwd.z)      # facing the machine
	_spin_dir = -1.0 if sin(P.yaw - _yaw0) > 0.0 else 1.0      # he turns the short way round
	_from_pos = Game.rig.pos
	_from_look = Game.rig.look
	_from_fov = Config.fov
	shot(_from_pos, _from_look, _from_fov)
	enter_cine()
	_overlay = ImplantOverlay.new()
	Game.ui.add_child(_overlay)
	an.pose_hook = _pose_hook
	return true


func skip() -> void:
	if not on or skipping or t >= UP1:
		return
	skipping = true
	_vc.stop()
	t = UP1 - 0.05


func _finish() -> void:
	if not on:
		return
	on = false
	_vc.stop()
	var an := Game.animator
	var P := Game.player
	if an != null:
		an.pose_hook = Callable()
		an.actor.rotation = Vector3(0.0, P.yaw, 0.0)
	if not _fluid.is_empty():
		(_fluid["att"] as Node).queue_free()
		_fluid = {}
	var m := _machine()
	if m != null:
		m.hide_all()
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
	leave_cine()
	P.vx = 0.0
	P.vz = 0.0
	Game.rig.snap_to(P)


func update(dt: float) -> void:
	dt = minf(dt, 0.05)
	if not _frame():
		_finish()
		return
	t += dt
	var i := 0
	for c: Array in _cues:
		if not cue_done[i] and t >= float(c[0]):
			cue_done[i] = true
			if not skipping and t - float(c[0]) < 0.5:
				(c[1] as Callable).call()
		i += 1
	if not voiced and t >= ROOM_FOR_VOICE_AT:
		voiced = true
		if not skipping:
			if VOICE.has(_char_id):
				_vc.speak(_char_id, _char_id, 0.05)
			else:
				_groan(1.6)
	if not effect_done and t >= EFFECT:
		effect_done = true
		if plasmid != null:
			Game.hud.toast(String(plasmid["name"]) + " IMPLANTED - PRESS Z FOR POWER MODE")      # the implant's own effect goes here, once each implant has one
	if t >= END_T:
		_finish()
		return
	# the player stays where the scene puts him (position and facing), no input
	var P := Game.player
	P.vx = 0.0
	P.vz = 0.0
	P.update(dt, Game.rig.yaw, true)
	var g := ease_(seg(t, 0.0, GLIDE))
	P.x = lerpf(_start.x, _spot.x, g)
	P.z = lerpf(_start.z, _spot.z, g)
	P.yaw = _yaw0 + (fposmod(P.yaw - _yaw0 + PI * 3.0, TAU) - PI) * (1.0 - g) if t < GLIDE else _yaw_at(t)
	P.vx = 0.0
	P.vz = 0.0
	lvl += (_vc.level() - lvl) * minf(1.0, dt * 18.0)
	var an := Game.animator
	if an != null:
		an.update(dt, P)
		_post(an)
