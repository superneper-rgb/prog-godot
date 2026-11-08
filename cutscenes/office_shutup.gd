class_name OfficeShutup
extends Cutscene
## The B-9 office (JS cutscenes/office-shutup.js). Prog stands at the Boss's desk with Tommy a step behind him, arguing about a failed mission: six recorded lines that get louder and meaner, the two of them talking over each other, the Boss lunging at the desk, until Tommy cuts them both off with a shout and tells them what he thinks of them. Prog and the Boss are the real actors; Tommy is a private Animator whose face is repainted on a copy of his texture (angry brows, a mouth that flaps with his voice level). Cutscene list only, nothing in play triggers it. The game is frozen behind it. X skips.

const DIR := "res://assets/sfx/office-shutup/"
const BOSS_FILES := {"a1": "a1.mp3", "a3": "a3.mp3", "a5": "a5.mp3"}
const PROG_FILES := {"a2": "a2.mp3", "a4": "a4.mp3", "a6": "a6.mp3"}
const TOMMY_FILES := {"t1": "t1.mp3", "t2": "t2.mp3", "t3": "t3.mp3", "t4": "t4.mp3", "t5": "t5.mp3", "t6": "t6.mp3"}
const GAIN := {"boss": 0.8, "prog": 2.6, "tommy": 1.4}      # output gain per speaker: Prog's recordings are far quieter than the Boss's; Tommy ends up about twice as loud as either (peaks just touch full scale)
const FLOOR := -10.0      # office numbers: the Boss stands at (127, 330) behind his desk, Prog in front of it, Tommy behind Prog
const BOSS_AT := Vector2(127.0, 330.0)
const PROG_AT := Vector2(123.75, 329.7)
const TOMMY_AT := Vector2(122.45, 330.45)
const X0 := 116.6
const X1 := 129.4
const Z0 := 326.7
const Z1 := 333.2
const SIDE := Vector3(124.6, FLOOR + 1.55, 332.3)      # south-east of the three of them, past the visitor's chair: the pan shot stands here, Tommy, Prog and the Boss all in front of it
const ARG: Array = [["a1", "boss", 0.0], ["a2", "prog", 0.3], ["a3", "boss", 0.5], ["a4", "prog", 0.8], ["a5", "boss", 0.9], ["a6", "prog", 1.4]]      # the lines of the argument: the clip, who says it, and how many seconds before it ends the next speaker cuts in (they talk over each other more and more)

var actors: HubOfficeActors
var on_end := Callable()
var t := 0.0
var _bi := 0
var _bt := 0.0
var _dt := 0.016
var _heat := 0.0
var _heat_to := 0.0
var _shake := 0.0
var _hit := 0.0
var _stun := 0.0
var _stun_to := 0.0
var _rage := 0.0
var _rage_to := 0.0
var _skipping := false
var _pan := &"tommy"
var _slam_at := -1.0
var _slammed := false
var _lvl := {"boss": 0.0, "prog": 0.0, "tommy": 0.0}
var _beats: Array[Dictionary] = []
var _vcs := {}
var _snd := {}
var _from_pos := Vector3.ZERO
var _from_look := Vector3.ZERO
var _from_fov := 50.0
var _look := Vector3.ZERO
var _boss_face := Vector3.ZERO
var _prog_face := Vector3.ZERO
var _tommy_face := Vector3.ZERO
var _prev_armed := false
var _prev_idx := -1
# Tommy
var _t_an: Animator = null
var _t_p: Player = null
var _t_mats: Array[StandardMaterial3D] = []
var _t_tex := {}
var _t_key := ""


func _ready() -> void:
	Game.cutscenes[&"office_shutup"] = self
	for who: String in ["boss", "prog", "tommy"]:
		var files: Dictionary = BOSS_FILES if who == "boss" else (PROG_FILES if who == "prog" else TOMMY_FILES)
		var v := VoiceClips.new(DIR, files)
		add_child(v)
		_vcs[who] = v
	_snd["boom"] = CineParts.sound("shutup_boom", [["t", 0.0, 0.7, 90.0, 30.0, {"type": "triangle", "gain": 1.2, "wet": 0.35}], ["n", 0.0, 0.2, {"type": "lowpass", "f0": 2400.0, "f1": 200.0, "gain": 0.8, "wet": 0.3}], ["n", 0.03, 0.9, {"type": "bandpass", "f0": 300.0, "f1": 90.0, "q": 1.2, "gain": 0.4, "wet": 0.5}]])      # Tommy's first shout lands: a sub drop and a crack, then the room goes quiet
	var slam: Array = [["t", 0.0, 0.3, 120.0, 42.0, {"type": "triangle", "gain": 1.0, "wet": 0.25}], ["n", 0.0, 0.12, {"type": "lowpass", "f0": 1600.0, "f1": 200.0, "gain": 0.8, "wet": 0.25}]]
	for i in 5:
		slam.append(["n", 0.05 + i * 0.045 + randf() * 0.02, 0.03, {"type": "highpass", "f0": 2800.0 + randf() * 2000.0, "f1": 600.0, "gain": 0.16, "wet": 0.15}])
	_snd["slam"] = CineParts.sound("shutup_slam", slam)      # the Boss's palms on the desk
	_snd["whoosh"] = CineParts.sound("shutup_whoosh", [["n", 0.0, 0.4, {"type": "bandpass", "f0": 500.0, "f1": 1500.0, "q": 0.8, "gain": 0.1, "attack": 0.16, "wet": 0.2}]])
	_snd["rumble"] = CineParts.sound("shutup_rumble", [["t", 0.0, 6.0, 48.0, 44.0, {"type": "sawtooth", "gain": 0.05, "attack": 1.5, "wet": 0.5}]])      # under "look around you"


func _exit_tree() -> void:
	Game.cutscenes.erase(&"office_shutup")


func _s(k: String, gain: float = 1.0) -> void:
	CineParts.play(_snd[k], gain)


func _dur(k: String) -> float:
	var v: VoiceClips = _vcs["boss"] if BOSS_FILES.has(k) else (_vcs["prog"] if PROG_FILES.has(k) else _vcs["tommy"])
	return v.dur(k)


func _stop_voices() -> void:
	for k: String in _vcs:
		(_vcs[k] as VoiceClips).stop()


func _speak(k: String, who: String) -> void:
	(_vcs[who] as VoiceClips).speak(k, who, 0.12 if who == "tommy" else 0.07, float(GAIN[who]) * 1.15)


# ---- Tommy: a private Animator, a puppet player object, and a face that talks
static func _puppet(x: float, z: float) -> Player:
	var p := Player.new(null)
	p.world = Game.world
	p.x = x
	p.y = FLOOR
	p.z = z
	p.yaw = PI / 2.0
	p.grounded = true
	p.flip = -1.0
	p.mode = &"normal"
	p.hp = 100.0
	p.max_hp = 100.0
	return p


## ENGINE DIFFERENCE: the JS redraws a canvas when his mouth changes. The eight faces are painted once, here, on copies of the texture.
func _face_kit(an: Animator) -> void:
	_t_mats.clear()
	var orig: Texture2D = null
	for mi: Node in an.actor.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for s in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(s)
			if src is StandardMaterial3D and src.resource_name == "tm_body" and (src as StandardMaterial3D).albedo_texture != null:
				var d := (src as StandardMaterial3D).duplicate() as StandardMaterial3D
				m.set_surface_override_material(s, d)      # (not the player's own Tommy: only this one)
				_t_mats.append(d)
				orig = d.albedo_texture
	if orig == null:
		push_warning("office-shutup: no tm_body material, Tommy keeps his stock face")
		return
	var base := orig.get_image()
	if base.is_compressed():
		base.decompress()
	base.convert(Image.FORMAT_RGBA8)
	base.clear_mipmaps()
	base.resize(512, 512, Image.INTERPOLATE_BILINEAR)
	for angry in 2:
		for mouth in 4:
			var img := base.duplicate() as Image
			_paint_face(img, mouth, angry == 1)
			img.generate_mipmaps()
			_t_tex["%d:%d" % [mouth, angry]] = ImageTexture.create_from_image(img)


static func _px(g: Image, x: float, y: float, w: float, h: float, col: Color) -> void:
	g.fill_rect(Rect2i(roundi(x / 4.0) * 4, roundi(y / 4.0) * 4, maxi(4, roundi(w / 4.0) * 4), maxi(4, roundi(h / 4.0) * 4)), col)


## mouth: 0 shut, 1..3 opening wider; angry: glare brows pulled in and down, a flat mouth
static func _paint_face(g: Image, mouth: int, angry: bool) -> void:
	var CREAM := Color("#ede6d6")
	var INK := Color("#1a1618")
	var INSIDE := Color("#4a0e10")
	if angry:      # wipe the stock brows, draw slanted ones thick, pulled in toward the nose
		_px(g, 128, 132, 88, 52, CREAM)
		_px(g, 300, 132, 88, 52, CREAM)
		for i in 9:
			_px(g, 136 + i * 8, 150 + i * 3, 12, 12, INK)
			_px(g, 376 - i * 8 - 12, 150 + i * 3, 12, 12, INK)
	_px(g, 168, 328, 176, 84, CREAM)      # wipe the stock smile
	if mouth == 0:      # a flat bar (a frown when angry)
		if angry:
			_px(g, 204, 372, 104, 8, INK)
			_px(g, 196, 380, 12, 8, INK)
			_px(g, 304, 380, 12, 8, INK)
		else:
			_px(g, 200, 372, 112, 8, INK)
			_px(g, 188, 364, 12, 8, INK)
			_px(g, 312, 364, 12, 8, INK)
	else:
		var w := 76.0 + mouth * 28.0
		var h := 8.0 + mouth * 20.0
		var x := 256.0 - w / 2.0
		var y := 356.0 + (0.0 if mouth > 1 else 8.0)
		_px(g, x - 4.0, y - 4.0, w + 8.0, h + 8.0, INK)
		_px(g, x, y, w, h, INSIDE)
		if mouth >= 2:      # top teeth
			_px(g, x + 8.0, y, w - 16.0, 8, Color("#f4efe2"))
		if mouth >= 3:      # a tongue
			_px(g, x + 24.0, y + h - 12.0, w - 48.0, 8, Color("#a02a2a"))


func _set_face(mouth: int, angry: int) -> void:
	var k := "%d:%d" % [mouth, angry]
	if k == _t_key or not _t_tex.has(k):
		return
	_t_key = k
	for m: StandardMaterial3D in _t_mats:
		m.albedo_texture = _t_tex[k]


func _build_tommy() -> void:
	var B := Builds.character_build("tommy")
	var an := Animator.new((load(B.file) as PackedScene).instantiate(), B)
	add_child(an.actor)
	_t_an = an
	_t_p = _puppet(TOMMY_AT.x, TOMMY_AT.y)
	_face_kit(an)
	an.pose_hook = _tommy_pose


## brooding, head a little down and still; then chest out, fists tight, shaking with every shout
func _tommy_pose(a: Animator) -> void:
	var r := _rage
	var l: float = _lvl["tommy"]
	var sh := (0.02 + 0.05 * r) * l
	add_pose(a, &"head", 0.3 * (1.0 - r) - 0.18 * r + 0.1 * l * sin(t * 15.0), 0.04 * sin(t * 31.0) * l, 0.0)
	add_pose(a, &"spine1", -0.1 * r, 0.0, 0.0)
	add_pose(a, &"chest", -0.12 * r + 0.05 * l * sin(t * 15.0), 0.0, sh * sin(t * 47.0))
	add_pose(a, &"upper_armL", 0.0, 0.0, 0.32 * r + sh * 2.0 * sin(t * 53.0))
	add_pose(a, &"upper_armR", 0.0, 0.0, -0.32 * r + sh * 2.0 * sin(t * 59.0))
	add_pose(a, &"forearmL", -0.9 * r, 0.0, 0.0)
	add_pose(a, &"forearmR", -0.9 * r, 0.0, 0.0)


# ---- the three of them
func _update_faces() -> void:
	var b := actors.boss
	_boss_face = b.root.global_transform * Vector3(0.0, 1.66, 0.08) if b != null else Vector3(BOSS_AT.x, FLOOR + 1.66, BOSS_AT.y)
	_prog_face = face_of_player()
	if _t_an != null and _t_an.by_key.has(&"head"):
		_tommy_face = _t_an.bone_world_pos(_t_an.by_key[&"head"].bone) + Vector3(0.0, 0.05, 0.0)
	else:
		_tommy_face = Vector3(TOMMY_AT.x, FLOOR + 1.3, TOMMY_AT.y)


## Prog: hands going while he shouts, leaning into the desk as it heats up, a flinch when Tommy goes off
func _pose_hook(a: Animator) -> void:
	var g: float = float(_lvl["prog"]) * (1.0 - _stun)
	var h := _heat
	var s1 := 0.5 + 0.5 * sin(t * 6.1)
	var s2 := 0.5 + 0.5 * sin(t * 4.7 + 1.7)
	add_pose(a, &"upper_armR", -0.9 * g * s1, 0.0, -0.4 * g * s2)
	add_pose(a, &"forearmR", -1.0 * g * s1, 0.0, 0.0)
	add_pose(a, &"upper_armL", -0.7 * g * s2, 0.0, 0.4 * g * s1)
	add_pose(a, &"forearmL", -0.9 * g * s2, 0.0, 0.0)
	add_pose(a, &"head", 0.06 * sin(t * 8.0) * g - 0.05 * h - 0.2 * _hit, 0.35 * g * sin(t * 1.9), 0.0)
	add_pose(a, &"spine1", 0.1 * h * (1.0 - _stun) - 0.15 * _hit, 0.0, 0.0)
	add_pose(a, &"spine2", 0.05 * h, 0.0, 0.0)


func _drive_boss(dt: float) -> void:
	var b := actors.boss
	if b == null:
		return
	b.cine_hold = on
	b.cine = {"attend": 1.0, "talk": _lvl["boss"], "anger": _heat * (1.0 - _stun), "hit": _hit * 0.6, "t": t}
	var want := atan2(PROG_AT.x - b.root.position.x, PROG_AT.y - b.root.position.z)
	b.root.rotation.y += _wrap(want - b.root.rotation.y) * minf(1.0, dt * 3.0)


# ---- shots
static func _in_room(v: Vector3) -> Vector3:
	return Vector3(clampf(v.x, X0, X1), v.y, clampf(v.z, Z0, Z1))


## a camera standing `back` metres from `face` on the side away from `toward`, `side` to the left of the line, `up` above eye level
static func _over(face: Vector3, toward: Vector3, back: float, side: float, up: float) -> Vector3:
	var dx := toward.x - face.x
	var dz := toward.z - face.z
	var d := U.hyp(dx, dz)
	if d == 0.0:
		d = 1.0
	var fx := dx / d
	var fz := dz / d
	return _in_room(Vector3(face.x - fx * back - fz * side, face.y + up, face.z - fz * back + fx * side))


static func _ease_out3(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return 1.0 - (1.0 - u) * (1.0 - u) * (1.0 - u)


func _build_beats() -> void:
	_beats = []
	var n := ARG.size()
	for i in n:
		var clip: String = ARG[i][0]
		var who: String = ARG[i][1]
		var last := i == n - 1
		_beats.append({"id": StringName(clip), "clip": clip, "who": who,
			"len": func() -> float: return minf(_dur(clip) * 0.7, 2.0) if last else maxf(0.9, _dur(clip) - float(ARG[i + 1][2])),
			"enter": func() -> void:
				_heat_to = float(i + 1) / float(n)
				if i > 0:
					_s("whoosh", 0.3 + 0.1 * i)
				if i == n - 2:
					_slam_at = t + 0.3,
			"cam": func(u: float) -> void: _arg_cam(i, u)})
	var stun_len := 0.55
	_beats.append({"id": &"shout", "clip": "t1", "who": "tommy", "len": func() -> float: return _dur("t1") + 0.1 + stun_len,
		"enter": func() -> void:
			_stop_voices()
			_heat_to = 0.0
			_stun_to = 1.0
			_rage_to = 1.0
			_hit = 1.0
			_shake = 1.0
			_s("boom"),
		"cam": func(u: float) -> void: _shout_cam(u, _dur("t1"))})
	_beats.append({"id": &"can", "clip": "t2", "who": "tommy", "len": func() -> float: return _dur("t2") + 0.3, "enter": func() -> void: _shake = 0.7, "cam": _can_cam})
	_beats.append({"id": &"listen", "clip": "t3", "who": "tommy", "len": func() -> float: return _dur("t3") + 0.35, "enter": func() -> void: _pan = &"tommy", "cam": _pan_cam})
	_beats.append({"id": &"hate1", "clip": "t4", "who": "tommy", "len": func() -> float: return _dur("t4") + 0.35,
		"enter": func() -> void:
			_pan = &"prog"
			_s("whoosh", 0.5),
		"cam": _pan_cam})
	_beats.append({"id": &"hate2", "clip": "t5", "who": "tommy", "len": func() -> float: return _dur("t5") + 0.25,
		"enter": func() -> void:
			_pan = &"boss"
			_shake = 0.5
			_s("whoosh", 0.7),
		"cam": _pan_cam})
	_beats.append({"id": &"world", "clip": "t6", "who": "tommy", "len": func() -> float: return _dur("t6") + 1.1,
		"enter": func() -> void:
			_shake = 0.5
			_s("rumble"),
		"cam": func(u: float) -> void: _world_cam(u, _dur("t6"))})
	_beats.append({"id": &"out", "len": func() -> float: return 1.5,
		"enter": func() -> void:
			leave_cine()
			_heat_to = 0.0
			_rage_to = 0.0
			_stun_to = 0.0
			Game.player.yaw = PI / 2.0
			Game.rig.snap_to(Game.player)
			_from_pos = camera.pos
			_from_look = camera.look
			_from_fov = camera.fov,
		"cam": func(u: float) -> void:
			var k := ease_(u / 1.4)
			shot(_from_pos.lerp(Game.rig.pos, k), _from_look.lerp(Game.rig.look, k), lerpf(_from_fov, Config.fov, k))})


## the argument: wide from behind Tommy and Prog (so Tommy is seen standing there), then tighter and shakier cuts as it heats up
func _arg_cam(i: int, u: float) -> void:
	_update_faces()
	var h := _heat
	var k := ease_(u / 3.0)
	match i:
		0:      # behind them both, the Boss across the desk
			shot(Vector3(120.6, FLOOR + 1.75, 331.0) + Vector3(0.5 * k, -0.05 * k, -0.2 * k), _boss_face.lerp(_prog_face, 0.35), lerpf(52.0, 46.0, k))
		1:      # Prog's face, over the Boss's shoulder
			shot(_over(_prog_face, _boss_face, -0.85, -0.45, 0.08), _prog_face, lerpf(34.0, 30.0, k))
		2:      # the Boss, over Prog's shoulder
			shot(_over(_boss_face, _prog_face, -1.0, 0.5, 0.05), _boss_face, lerpf(34.0, 28.0, k))
		3:      # side-on across the desk
			shot(Vector3(125.3, FLOOR + 2.2, 327.1) + Vector3(0.25 * k, -0.1 * k, 0.1 * k), _prog_face.lerp(_boss_face, 0.5), lerpf(52.0, 44.0, k))
		4:      # the Boss lunges: crash zoom
			var z := _ease_out3(u / 0.4)
			shot(_over(_boss_face, _prog_face, -0.7, 0.45, 0.1), _boss_face - Vector3(0.0, 0.12 * (1.0 - z), 0.0), lerpf(34.0, 18.0, z))
		_:      # Prog, going red, closing in
			shot(_over(_prog_face, _boss_face, -0.6, -0.4, 0.05), _prog_face, lerpf(30.0, 15.0, _ease_out3(u / 0.9)))
	var sh := 0.004 + 0.012 * h * h
	camera.pos.x += (sin(t * 47.0) + sin(t * 31.0)) * sh
	camera.pos.y += (sin(t * 53.0) + sin(t * 29.0)) * sh


## Tommy's first shout: a low crash-in on his face, then a cut to the two of them frozen
func _shout_cam(u: float, d: float) -> void:
	_update_faces()
	if u < d + 0.12:
		var z := _ease_out3(u / 0.3)
		shot(Vector3(_tommy_face.x + 1.1 - 0.3 * z, _tommy_face.y - 0.18, _tommy_face.z + 0.85 - 0.2 * z), _tommy_face, lerpf(40.0, 26.0, z))
	else:      # the half second of stunned silence
		shot(Vector3(125.3, FLOOR + 2.2, 327.1), _prog_face.lerp(_boss_face, 0.5), 44.0)


func _can_cam(u: float) -> void:
	_update_faces()
	var z := ease_(u / 1.2)
	shot(Vector3(_tommy_face.x + 1.35 - 0.3 * z, _tommy_face.y - 0.1, _tommy_face.z + 0.7 - 0.1 * z), _tommy_face, lerpf(34.0, 22.0, z))


## "now listen", "I hate you", "but most of all": the camera stands south-east of them and swings its look from Tommy to Prog to the Boss
func _pan_cam(_u: float) -> void:
	_update_faces()
	var to := _prog_face if _pan == &"prog" else (_boss_face if _pan == &"boss" else _tommy_face)
	_look = _look.lerp(to, 1.0 - exp(-7.0 * _dt))
	shot(SIDE + Vector3(0.15 * sin(t * 0.5), 0.05 * sin(t * 0.4), 0.0), _look, 38.0 if _pan == &"tommy" else (30.0 if _pan == &"prog" else 26.0))
	camera.pos.x += (sin(t * 41.0) + sin(t * 27.0)) * 0.004 * _shake
	camera.pos.y += (sin(t * 45.0) + sin(t * 23.0)) * 0.004 * _shake


## "look around you": a close low shot of his face that opens out into a slow orbit through the room (the television wall behind them), ending wide on the three of them
func _world_cam(u: float, d: float) -> void:
	_update_faces()
	var k := clampf(u / d, 0.0, 1.2)
	if k < 0.18:
		var z := ease_(k / 0.18)
		shot(Vector3(_tommy_face.x + 1.0 + 0.5 * z, _tommy_face.y - 0.22, _tommy_face.z + 0.8 + 0.3 * z), _tommy_face, lerpf(30.0, 40.0, z))
	elif k < 0.78:      # orbit round the three of them, looking outward at the room, then back in
		var a := lerpf(-0.5, 3.4, ease_((k - 0.18) / 0.6))
		var r := lerpf(2.6, 4.4, sin(PI * (k - 0.18) / 0.6))
		var cx := 124.9
		var cz := 329.9
		shot(_in_room(Vector3(cx + cos(a) * r, FLOOR + lerpf(1.2, 2.5, sin(PI * (k - 0.18) / 0.6)), cz + sin(a) * r * 0.8)), Vector3(cx + cos(a + PI) * 1.2, FLOOR + lerpf(1.6, 2.4, (k - 0.18) / 0.6), cz + sin(a + PI) * 1.2), 62.0)
	else:      # wide from the door end
		var z := ease_((k - 0.78) / 0.42)
		var l := _tommy_face.lerp(_boss_face, 0.45)
		l.y = FLOOR + 1.2
		shot(Vector3(lerpf(119.2, 118.2, z), FLOOR + lerpf(1.9, 2.3, z), lerpf(331.6, 332.2, z)), l, lerpf(56.0, 50.0, z))
	camera.pos.x += (sin(t * 41.0) + sin(t * 27.0)) * 0.005 * _shake
	camera.pos.y += (sin(t * 45.0) + sin(t * 23.0)) * 0.005 * _shake


# ---- run
func play() -> void:
	if on:
		return
	var an: Animator = Game.animator
	if an == null:
		if on_end.is_valid():
			on_end.call(false)
		return
	if _t_an == null:
		_build_tommy()
	on = true
	t = 0.0
	_bi = 0
	_bt = 0.0
	_heat = 0.0
	_heat_to = 0.0
	_shake = 0.0
	_hit = 0.0
	_stun = 0.0
	_stun_to = 0.0
	_rage = 0.0
	_rage_to = 0.0
	_skipping = false
	_pan = &"tommy"
	_dt = 0.016
	_slam_at = -1.0
	_slammed = false
	_lvl = {"boss": 0.0, "prog": 0.0, "tommy": 0.0}
	_t_an.actor.visible = true
	_t_p.x = TOMMY_AT.x
	_t_p.z = TOMMY_AT.y
	_t_p.y = FLOOR
	_t_p.yaw = PI / 2.0
	_t_key = ""
	_set_face(0, 0)
	var pl := Game.player
	_prev_armed = pl.armed
	_prev_idx = pl.weapon_idx
	pl.armed = false
	pl.aiming = false
	pl.sprinting = false
	pl.crouching = false
	pl.x = PROG_AT.x
	pl.z = PROG_AT.y
	pl.y = FLOOR
	pl.vx = 0.0
	pl.vz = 0.0
	pl.vy = 0.0
	pl.yaw = PI / 2.0
	Game.rig.snap_to(pl)
	_from_pos = Game.rig.pos
	_from_look = Game.rig.look
	_update_faces()
	_look = _tommy_face
	shot(_from_pos, _from_look, Config.fov)
	enter_cine()
	an.pose_hook = _pose_hook
	_build_beats()
	(_beats[0].enter as Callable).call()


func skip() -> void:
	if not on or _skipping or _beats[_bi].id == &"out":
		return
	_skipping = true
	_stop_voices()
	_heat = 0.0
	_heat_to = 0.0
	_stun = 0.0
	_stun_to = 0.0
	_rage = 0.0
	_rage_to = 0.0
	_hit = 0.0
	_bi = _beats.size() - 1
	_bt = 0.0
	(_beats[_bi].enter as Callable).call()


func _finish() -> void:
	if not on:
		return
	on = false
	_stop_voices()
	_t_an.actor.visible = false
	var an: Animator = Game.animator
	if an != null:
		an.pose_hook = Callable()
	var b := actors.boss
	if b != null:
		b.cine_hold = false
		b.cine = null
	var pl := Game.player
	pl.armed = _prev_armed
	pl.weapon_idx = _prev_idx
	leave_cine()
	pl.vx = 0.0
	pl.vz = 0.0
	Game.rig.snap_to(pl)
	if on_end.is_valid():
		on_end.call(true)


func _fire(beat: Dictionary) -> void:
	if beat.has("clip") and not beat.get("fired", false):
		beat["fired"] = true
		_speak(beat.clip, beat.who)


func update(dt: float) -> void:
	if not on:
		return
	dt = minf(dt, 0.05)
	t += dt
	_bt += dt
	_dt = dt
	var beat: Dictionary = _beats[_bi]
	_fire(beat)
	if _bt >= float((beat.len as Callable).call()):
		if _bi == _beats.size() - 1:
			_finish()
			return
		_bi += 1
		_bt = 0.0
		beat = _beats[_bi]
		(beat.enter as Callable).call()
		_fire(beat)
	# heat (how loud and close the argument has got), the stun, Tommy's rage: each eases toward its target
	_heat += (_heat_to - _heat) * minf(1.0, dt * 3.0)
	_stun += (_stun_to - _stun) * minf(1.0, dt * 14.0)
	_rage += (_rage_to - _rage) * minf(1.0, dt * 6.0)
	_hit = maxf(0.0, _hit - dt * (1.2 if beat.id == &"shout" else 2.5))
	_shake = maxf(0.0, _shake - dt * 1.1)
	if _slam_at >= 0.0 and not _slammed and t >= _slam_at:
		_slammed = true
		_s("slam")
		_shake = maxf(_shake, 0.6)
	for who: String in _lvl:
		var v: VoiceClips = _vcs[who]
		var l := v.level() if v.who != null else 0.0
		_lvl[who] = float(_lvl[who]) + (l - float(_lvl[who])) * minf(1.0, dt * 18.0)
	# Prog: eyes front on the Boss, then round to Tommy when he goes off
	var pl := Game.player
	var want_yaw := PI / 2.0
	if beat.id != &"out":
		want_yaw = atan2(TOMMY_AT.x - pl.x, TOMMY_AT.y - pl.z) if (_rage > 0.5 and beat.id != &"shout") else atan2(BOSS_AT.x - pl.x, BOSS_AT.y - pl.z)
	pl.yaw += _wrap(want_yaw - pl.yaw) * minf(1.0, dt * (9.0 if _rage > 0.5 else 5.0))
	player_step(dt, 0.0, pl.yaw)
	# Tommy: faces Prog's back, then the Boss; his mouth follows his voice level
	var tp := _t_p
	var t_yaw := atan2(pl.x - tp.x, pl.z - tp.z) if beat.id == &"hate1" else atan2(BOSS_AT.x - tp.x, BOSS_AT.y - tp.z)
	tp.yaw += _wrap(t_yaw - tp.yaw) * minf(1.0, dt * 8.0)
	tp.y = FLOOR
	_t_an.update(dt, tp)
	var lv: float = _lvl["tommy"]
	var mouth := 0 if lv < 0.06 else (1 if lv < 0.22 else (2 if lv < 0.45 else 3))
	_set_face(mouth if (_vcs["tommy"] as VoiceClips).who != null else 0, 1 if _rage > 0.3 else 0)
	_drive_boss(dt)
	var pa: Animator = Game.animator
	if pa != null:
		pa.update(dt, pl)
	(beat.cam as Callable).call(_bt)
