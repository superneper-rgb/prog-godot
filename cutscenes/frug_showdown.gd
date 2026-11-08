class_name FrugShowdown
extends Cutscene
## FRUG SHOWDOWN CUTSCENE (JS cutscenes/frug-showdown.js): OMNISPHERE, the bridge to Containment. Prog and Tommy in phantom suits walk north toward the drum while the plant blows up behind them; Frug (suit) steps out of the drum's south door. Everybody freezes; he huffs, they aim, "It's over, Frug."; he laughs, flexes, his suit bursts, he roars; they back off, and then he is suddenly charging. Every bullet misses, he leaps into a flying double kick (slow motion) and Tommy explodes. Prog stands there blank, splattered, then screams, throws the rifle and tackles Frug off the bridge: they wrestle all the way down into the magma.
## A test cutscene: nothing in the level plays it (dev console: "cutscene play frug-showdown"). It borrows the live omnisphere world (its bridge, door, lava, alarm paint) and puts back everything it touched. The game is frozen behind it (menu_open() is true while it runs).
## Sound: assets/sfx/frug-showdown/ and the plant's own boom / alarm / ambience files. ENGINE DIFFERENCE: the slow-motion low pass sits on this cutscene's own sounds only; the JS routes the game's sfx through it too, but no game sound plays inside the slow motion.

# the bridge (levels/omnisphere/escape.js): x -204..-196, deck y 18, z -122..-218; the drum's south door at z -218.6
const BX := -200.0
const BY := 18.0
const DOOR_Z := -218.6
const RAIL_X := 3.9
const PROG_X := -201.1
const TOMMY_X := -198.9
const WALK0 := -184.0
const STOP_Z := -199.0
const FRUG_X := -199.1
const FRUG_STOP := -213.0
const FRUG_SCALE := 1.55      # about 2.75 m: a head and a half over Prog
## seconds on the cutscene clock (slow motion stretches the clock, not this list)
const T := {"fadeIn": 0.6, "door": 5.6, "frugOut": 6.1, "walkEnd": 7.6, "frugStop": 8.8, "huff": 9.6, "raise": 12.3, "lineT": 12.9, "lineP": 14.6, "laugh": 16.7, "flex": 19.5, "burst": 21.1, "roar": 21.7,
	"roarEnd": 24.3, "back": 24.8, "backEnd": 27.3, "charge": 27.4, "leap": 28.2, "slowA": 28.4, "impact": 28.75, "land": 29.05, "blank": 31.0, "stare": 34.0, "scream": 36.0, "toss": 36.5, "run": 37.25, "tackle": 37.6}
const SLOW := 0.12      # clock rate inside [slowA, impact]
const VOICES := {"TOMMY": {"color": "#ffd36b", "rate": 14.0, "pitch": 150.0}, "PROG": {"color": "#9fd8ff", "rate": 13.0, "pitch": 102.0}}
const BOOMS := [[0.9, -226.0, 24.0, -96.0, true], [2.3, -184.0, 21.0, -116.0, false], [3.5, -203.0, 20.0, -127.0, true], [4.8, -232.0, 30.0, -70.0, false], [6.4, -176.0, 22.0, -82.0, true], [10.6, -214.0, 26.0, -108.0, false], [14.9, -190.0, 34.0, -66.0, true], [18.6, -238.0, 22.0, -114.0, false], [22.9, -180.0, 24.0, -100.0, true], [25.9, -222.0, 28.0, -84.0, false]]
const DIR := "res://assets/sfx/frug-showdown/"
const OMNI := "res://assets/sfx/omnisphere/"
const FILES := {"huff": DIR + "huff", "laugh": DIR + "laugh", "rip": DIR + "rip", "roar": DIR + "roar", "charge": DIR + "charge", "slowmo": DIR + "slowmo", "gore": DIR + "gore", "scream": DIR + "scream",
	"tackle": DIR + "tackle", "fall": DIR + "fall", "lava": DIR + "lava", "musicA": DIR + "music-standoff", "musicB": DIR + "music-fall",
	"boomBig": OMNI + "boom-big", "boom": OMNI + "boom", "alarm": OMNI + "alarm", "ambience": OMNI + "ambience", "groan": OMNI + "groan"}
const B_LP := &"FrugLp"
const B_AMB := &"FrugAmb"
const B_MUSIC := &"FrugMusic"

var t := -1.0
var hold := false      # (tests: the clock stands still)
var real := 0.0
var _ei := 0
var _shake := 0.0
var _slow_real := 0.0
var _splash_t := -1.0
var _ev: Array = []
var _order := 0
var _root: Node3D = null
var _line: Variant = null
var H: Variant = null
var F: Variant = null
var _saved: Variant = null
var _parts: Array[Dictionary] = []
var _glows: Array[Dictionary] = []
var _knot: Variant = null
var _rifle: Variant = null
var _lights: Array[OmniLight3D] = []
var _wait := 0.0
var _players: Array[AudioStreamPlayer] = []
var _ramps: Array[Dictionary] = []
var _music_a: AudioStreamPlayer = null
var _music_b: AudioStreamPlayer = null
var _ring: AudioStreamPlayer = null
var _mats := {}
var _box_mesh: BoxMesh
var _ico_mesh: SphereMesh
var _blob_mesh: SphereMesh
var _after: Array = []
var _qf := Quaternion.IDENTITY


func _init() -> void:
	name = "FrugShowdown"


func _E(tm: float, fn: Callable) -> void:
	_order += 1
	_ev.append({"t": tm, "fn": fn, "n": _order})
	_ev.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["t"] < b["t"] if a["t"] != b["t"] else a["n"] < b["n"])


static func _win(tm: float, a: float, b: float, fi: float = 0.25, fo: float = 0.25) -> float:      # 0 -> 1 -> 0 envelope over [a, b]
	return Cutscene.ease_((tm - a) / fi) * (1.0 - Cutscene.ease_((tm - b) / fo))


static func rr(a: float, b: float) -> float:
	return a + randf() * (b - a)


# ---- sound: its own buses, the plant's own audio muted under it ----
func _bus(bn: StringName, send: StringName, g: float) -> int:
	var i := AudioServer.get_bus_index(bn)
	if i < 0:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, bn)
		AudioServer.set_bus_send(i, send)
		if bn == B_LP:
			var lp := AudioEffectLowPassFilter.new()
			lp.cutoff_hz = 20000.0
			AudioServer.add_bus_effect(i, lp)
	AudioServer.set_bus_volume_db(i, linear_to_db(g))
	return i


func _audio_on() -> void:
	_bus(B_LP, &"SFX", 1.0)      # slow motion muffles everything but the score
	_bus(B_AMB, B_LP, 1.0)
	_bus(B_MUSIC, &"SFX", 0.85)
	_set_cutoff(20000.0)
	_mute_level(true)


func _mute_level(m: bool) -> void:      # the level's beds fall silent
	for bn: StringName in Game.level_beds():
		var i := AudioServer.get_bus_index(bn)
		if i >= 0:
			AudioServer.set_bus_mute(i, m)


func _audio_off() -> void:
	for p: AudioStreamPlayer in _players:
		if is_instance_valid(p):
			p.queue_free()
	_players.clear()
	_ramps.clear()
	_set_cutoff(20000.0)
	_mute_level(false)


func _set_cutoff(hz: float) -> void:
	var i := AudioServer.get_bus_index(B_LP)
	if i >= 0:
		(AudioServer.get_bus_effect(i, 0) as AudioEffectLowPassFilter).cutoff_hz = hz


func _snd(id: String, o: Dictionary = {}) -> AudioStreamPlayer:
	var st: AudioStream = load(FILES[id] + ".mp3") if ResourceLoader.exists(FILES[id] + ".mp3") else null
	if st == null:
		return null
	if o.get("loop", false):
		st = st.duplicate()
		if st is AudioStreamMP3:
			(st as AudioStreamMP3).loop = true
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.bus = o.get("bus", B_LP)
	p.volume_db = linear_to_db(maxf(float(o.get("gain", 1.0)), 1e-5))
	p.pitch_scale = float(o.get("rate", 1.0))
	add_child(p)
	p.play()
	_players.append(p)
	p.finished.connect(func() -> void:
		_players.erase(p)
		p.queue_free())
	return p


## a voice or a bus eases to a level (JS setTargetAtTime)
func _fade_v(v: Variant, to: float, tau: float = 0.15) -> void:
	if v == null:
		return
	_ramps = _ramps.filter(func(r: Dictionary) -> bool: return not is_same(r["v"], v))
	var from: float = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(v))) if v is StringName else db_to_linear((v as AudioStreamPlayer).volume_db)
	_ramps.append({"v": v, "cur": from, "to": to, "tau": tau})


func _ramp_step(dt: float) -> void:
	for r: Dictionary in _ramps:
		r["cur"] = float(r["to"]) + (float(r["cur"]) - float(r["to"])) * exp(-dt / float(r["tau"]))
		var db := linear_to_db(maxf(float(r["cur"]), 1e-5))
		var v: Variant = r["v"]
		if v == null:      # (the low pass: its cutoff, set by the frame)
			continue
		if v is StringName:
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index(v), db)
		elif is_instance_valid(v):
			(v as AudioStreamPlayer).volume_db = db


func _tinnitus(on_: bool) -> void:
	if on_:
		var w := CineParts.sound("frug.ring", [["t", 0.0, 2.0, 6100.0, 6100.0, {"gain": 1.0, "attack": 0.001}]])
		var st: AudioStreamWAV = (w["s"] as AudioStreamWAV).duplicate()
		st.loop_mode = AudioStreamWAV.LOOP_FORWARD
		st.loop_end = st.data.size() / 2 - 2000
		_ring = AudioStreamPlayer.new()
		_ring.stream = st
		_ring.bus = &"SFX"
		_ring.volume_db = -80.0
		add_child(_ring)
		_ring.play()
		_players.append(_ring)
		_fade_v(_ring, 0.05, 0.05)
	elif _ring != null:
		_fade_v(_ring, 0.0, 0.3)
		_ring = null


# ---- subtitles + voices (the shared box) ----
func _say(who: String, text: String, hold: float = 1.3) -> void:
	_line = {"who": who, "text": text, "t0": t, "shown": 0, "voiced": 0}
	_E(t + text.length() / float(VOICES[who]["rate"]) + hold, func() -> void:
		if _line != null and _line["text"] == text:
			_end_line())
	Game.ui.dialog.show_box(true)
	Game.ui.dialog.set_content("", "", "")


func _end_line() -> void:
	_line = null
	Game.ui.dialog.show_box(false)


func _tick_line() -> void:
	if _line == null:
		return
	var V: Dictionary = VOICES[_line["who"]]
	var text: String = _line["text"]
	var n := mini(text.length(), floori((t - float(_line["t0"])) * float(V["rate"])))
	for i in range(int(_line["voiced"]), n):
		var ch := text[i].to_lower()
		var prev := text[i - 1].to_lower() if i > 0 else " "
		if "aeiou".contains(ch) and not "aeiou".contains(prev):
			PhoneVoice.own_syllable(V["pitch"], 0.92 if _line["who"] == "PROG" else 1.08, 0.55, 0.1, 0.22, 1.04, 0.76, 0.8, ch, i, PhoneVoice.last_syllable(text, i))
	_line["voiced"] = n
	if n != int(_line["shown"]):
		_line["shown"] = n
		Game.ui.dialog.set_content(_line["who"], text.substr(0, n), "")


# ---- small visual pieces ----
## a sprite that grows and fades: fireballs, smoke, steam, blood mist, lava bursts
func _puff(p: Vector3, color: int, s0: float, s1: float, life: float, o: Dictionary = {}) -> void:
	var opa: float = o.get("opacity", 1.0)
	var s := CineParts.glow(_root, color, s0, o.get("add", true), opa)
	s.position = p
	_glows.append({"s": s, "s0": s0, "s1": s1, "life": life, "max": life, "o": opa, "v": o.get("v"), "rise": float(o.get("rise", 0.0))})


func _update_glows(dt: float) -> void:
	for i in range(_glows.size() - 1, -1, -1):
		var g: Dictionary = _glows[i]
		g["life"] -= dt
		var s: MeshInstance3D = g["s"]
		if float(g["life"]) <= 0.0:
			s.queue_free()
			_glows.remove_at(i)
			continue
		var u := 1.0 - float(g["life"]) / float(g["max"])
		s.scale = Vector3.ONE * lerpf(g["s0"], g["s1"], 1.0 - (1.0 - u) * (1.0 - u))
		CineParts.glow_opacity(s, float(g["o"]) * (1.0 - u) * (u / 0.1 if u < 0.1 else 1.0))
		if g["v"] != null:
			s.position += (g["v"] as Vector3) * dt
		s.position.y += float(g["rise"]) * dt


func _mat(color: int, e: bool = false, r: float = -1.0) -> StandardMaterial3D:
	var k := "%d.%s.%.2f" % [color, e, r]
	if _mats.has(k):
		return _mats[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.hex((color << 8) | 0xff)
	m.roughness = r if r >= 0.0 else 0.6
	if e:
		m.emission_enabled = true
		m.emission = m.albedo_color
		m.emission_energy_multiplier = 1.6
	_mats[k] = m
	return m


## a flying chunk: falls, bounces on the bridge deck, sinks into the magma; trail = blood drops / smoke as it flies
func _chunk(p: Vector3, v: Vector3, color: int, size: float, o: Dictionary = {}) -> void:
	var m := MeshInstance3D.new()
	m.mesh = o.get("geo", _box_mesh)
	var emissive: bool = o.get("emissive", false)
	m.material_override = _mat(color, emissive, 0.5 if emissive else 0.45)
	m.position = p
	m.scale = Vector3(size, size * float(o.get("flat", 1.0)), size * rr(0.6, 1.3))
	m.rotation = Vector3(rr(0.0, 6.0), rr(0.0, 6.0), rr(0.0, 6.0))
	_root.add_child(m)
	var sp: float = o.get("spin", 8.0)
	_parts.append({"m": m, "v": v, "w": Vector3(rr(-sp, sp), rr(-sp, sp), rr(-sp, sp)), "life": float(o.get("life", 7.0)), "trail": o.get("trail", ""), "tt": 0.0, "rest": false})


static func _on_deck(x: float, z: float) -> bool:
	return absf(x - BX) < RAIL_X and z < -122.0 and z > DOOR_Z


func _update_parts(dt: float) -> void:
	for i in range(_parts.size() - 1, -1, -1):
		var p: Dictionary = _parts[i]
		var m: MeshInstance3D = p["m"]
		p["life"] -= dt
		if float(p["life"]) <= 0.0 or m.position.y < -0.5:
			m.queue_free()
			_parts.remove_at(i)
			continue
		if p["rest"]:
			continue
		var v: Vector3 = p["v"]
		v.y -= 15.0 * dt
		m.position += v * dt
		m.rotation += (p["w"] as Vector3) * dt
		if p["trail"] != "":
			p["tt"] -= dt
			if float(p["tt"]) <= 0.0:
				p["tt"] = 0.14 if p["trail"] == "smoke" else 0.05
				if p["trail"] == "blood":
					Game.fx._blood_spray(m.position, v.x * 0.05, v.z * 0.05, 2, 1.2)
				else:
					_puff(m.position, 0x2a2420, 0.6, 2.4, 1.4, {"add": false, "opacity": 0.55, "rise": 1.0})
		var fl := BY + m.scale.y * 0.3 if _on_deck(m.position.x, m.position.z) else 0.2
		if m.position.y < fl and v.y < 0.0:
			if fl > 1.0:
				m.position.y = fl
				v.y *= -0.25
				v.x *= 0.5
				v.z *= 0.5
				p["w"] = (p["w"] as Vector3) * 0.4
				if absf(v.y) < 0.8:
					p["rest"] = true
					if p["trail"] == "blood":
						Game.fx._blood_splat(m.position.x, BY, m.position.z, 0.25 + randf() * 0.3, 40.0)
			else:      # into the magma: a flare and gone
				_puff(m.position, 0xff8a30, 0.4, 2.2, 0.5)
				m.queue_free()
				_parts.remove_at(i)
				continue
		p["v"] = v


## glossy blood blobs stuck to a body: at points facing `from`, on the nearest bones so they ride the animation. bones: [skeleton, bone, fat]
func _splatter(skel: Skeleton3D, bones: Array, from: Vector3, n: int, size: float) -> void:
	var att := {}
	for i in n:
		var b: Array = bones[randi() % bones.size()]
		var idx: int = b[0]
		var wx := skel.global_transform * skel.get_bone_global_pose(idx)
		var a := wx.origin
		var d := from - a
		d.y = 0.0
		d = d.normalized()
		a += d * (rr(0.1, 0.2) * float(b[1])) + Vector3(rr(-0.12, 0.12), rr(-0.15, 0.15), rr(-0.12, 0.12))
		if not att.has(idx):
			var ba := BoneAttachment3D.new()
			skel.add_child(ba)
			ba.bone_idx = idx
			att[idx] = ba
		var m := MeshInstance3D.new()
		m.mesh = _blob_mesh
		m.material_override = _mat(0x5e0505 if randf() < 0.5 else 0x8c0a0a, false, 0.18)
		(att[idx] as Node3D).add_child(m)
		var ws := wx.basis.get_scale().x
		var s := size * rr(0.5, 1.4)
		m.position = wx.affine_inverse() * a
		m.scale = Vector3(s / ws, s * 0.45 / ws, s * rr(0.7, 1.3) / ws)
		m.rotation = Vector3(rr(0.0, 6.0), rr(0.0, 6.0), rr(0.0, 6.0))


# ---- Prog and Tommy (fresh Animators in phantom suits; a puppet player object each) ----
static func _puppet(x: float, z: float) -> Player:
	var p := Player.new(null)
	p.world = Game.world
	p.x = x
	p.y = BY
	p.z = z
	p.yaw = PI
	p.grounded = true
	p.armed = true
	p.flip = -1.0
	p.mode = &"normal"
	return p


func _hero_an(id: String) -> Animator:
	var B := Builds.character_build(id)
	var a := Animator.new((load(B.file) as PackedScene).instantiate(), B)
	_root.add_child(a.actor)
	PhantomSuit.set_phantom_suit(a, true)
	return a


func _build_heroes() -> void:
	var a_p := _hero_an("prog")
	var a_t := _hero_an("tommy")
	var prog := {"an": a_p, "p": _puppet(PROG_X, WALK0 + 0.4), "look": 0.0, "scream": 0.0, "blank": 0.0, "next": 0.0}
	var tommy := {"an": a_t, "p": _puppet(TOMMY_X, WALK0 - 0.3), "look": 0.0, "next": 0.0}
	(prog["p"] as Player).weapon_idx = Weapons.index_of("rifle")
	(tommy["p"] as Player).weapon_idx = Weapons.index_of("smg")
	var ihead := Animator.KEYS.find(&"head")
	var ineck := Animator.KEYS.find(&"neck")
	var ichest := Animator.KEYS.find(&"chest")
	a_p.pose_hook = func(a: Animator) -> void:      # head turns, the blank stare (no life at all), the scream (head forward, chest out)
		var k: float = prog["scream"]
		var b: float = prog["blank"]
		a.pose[ihead] += Vector3(0.28 * k - 0.05 * b, 0.5 * float(prog["look"]), 0.0)
		a.pose[ineck] += Vector3(0.22 * k, 0.0, 0.0)
		a.pose[ichest] += Vector3(-0.3 * k, 0.0, 0.0)
		if b > 0.5:      # he does not even blink
			a._bl_next = a.t + 5.0
	a_t.pose_hook = func(a: Animator) -> void: a.pose[ihead] += Vector3(0.0, -0.5 * float(tommy["look"]), 0.0)
	H = {"prog": prog, "tommy": tommy}


func _bone_w(an: Animator, key: StringName) -> Vector3:
	return an.bone_world_pos(an.by_key[key].bone) if an.by_key.has(key) else Vector3.ZERO


# ---- Frug (Meshy model + clips, posed on top by aiming bones in his own body frame) ----
func _build_frug() -> void:
	var model: Node3D = (load("res://assets/npcs/frug/model.glb") as PackedScene).instantiate()
	var yaw_g := Node3D.new()
	var tilt := Node3D.new()
	var body := Node3D.new()
	_root.add_child(yaw_g)
	yaw_g.add_child(tilt)
	tilt.add_child(body)
	body.add_child(model)
	body.scale = Vector3.ONE * FRUG_SCALE
	var mats: Array[StandardMaterial3D] = []
	var walk: Array[Node] = [model]
	while not walk.is_empty():
		var n: Node = walk.pop_back()
		walk.append_array(n.get_children())
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			var m: StandardMaterial3D = (mi.mesh.surface_get_material(0) as StandardMaterial3D).duplicate()
			mi.material_override = m
			mats.append(m)
	var skel: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var B := {}
	for i in skel.get_bone_count():
		var nm := skel.get_bone_name(i)
		for pre: String in ["mixamorig:", "mixamorig_", "mixamorig"]:
			if nm.begins_with(pre):
				nm = nm.substr(pre.length())
				break
		B[nm] = i
	var ap: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
	ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for nm: String in ["Idle", "Walking", "RunFast"]:
		if ap.has_animation(nm):
			ap.get_animation(nm).loop_mode = Animation.LOOP_LINEAR
	F = {"model": model, "skel": skel, "ap": ap, "mats": mats, "yaw_g": yaw_g, "tilt": tilt, "body": body, "B": B, "hip_h": 0.0, "cur": &"Idle", "x": FRUG_X, "y": BY, "z": DOOR_Z - 1.5, "yaw": 0.0, "drop": 0.0, "tilt_x": 0.0, "tilt_z": 0.0, "puff_t": 0.0, "w": {"huff": 0.0, "laugh": 0.0, "flex": 0.0, "strain": 0.0, "roar": 0.0, "run": 0.0, "kick": 0.0, "land": 0.0, "grapple": 0.0}, "mode": &"", "landed": false, "tex_muscle": load("res://assets/npcs/frug/muscle.jpg"), "tex_suit": load("res://assets/npcs/frug/suit.jpg")}
	_frug_costume("suit")
	# which way the model faces: Head -> headfront, measured in the rest pose
	var hf := Vector3(0.0, 0.0, 1.0)
	if B.has("headfront") and B.has("Head"):
		hf = _b_pos(B["headfront"]) - _b_pos(B["Head"])
	body.rotation.y = -atan2(hf.x, hf.z)
	var hip: float = (_b_pos(B["Hips"]).y if B.has("Hips") else 0.88 * FRUG_SCALE)
	F["hip_h"] = hip
	tilt.position.y = hip
	body.position.y = -hip
	ap.play(&"Idle")


func _frug_costume(n: String) -> void:
	for m: StandardMaterial3D in F["mats"]:
		m.albedo_texture = F["tex_suit"] if n == "suit" else F["tex_muscle"]


func _b_pos(i: int) -> Vector3:
	var skel: Skeleton3D = F["skel"]
	return skel.global_transform * skel.get_bone_global_pose(i).origin


func _b_quat(i: int) -> Quaternion:
	var skel: Skeleton3D = F["skel"]
	return (skel.global_basis * skel.get_bone_global_pose(i).basis).get_rotation_quaternion()


func _clip(nm: StringName, fade: float = 0.25, ts: float = 1.0) -> void:
	var ap: AnimationPlayer = F["ap"]
	if not ap.has_animation(nm):
		return
	ap.speed_scale = ts
	if F["cur"] == nm:
		return
	ap.play(nm, fade)
	F["cur"] = nm


## aim a bone's +Y (Mixamo: toward its child) along `dir` in Frug's (tilted) body frame, by weight w
func _aim(nm: String, dx: float, dy: float, dz: float, w: float) -> void:
	var B: Dictionary = F["B"]
	if not B.has(nm) or w <= 0.001:
		return
	var i: int = B[nm]
	var skel: Skeleton3D = F["skel"]
	var d := _qf * Vector3(dx, dy, dz).normalized()
	var qa := _b_quat(i)
	var y := qa * Vector3.UP
	var qb := Quaternion(y, d) * qa
	qa = qa.slerp(qb, minf(1.0, w))
	skel.set_bone_pose_rotation(i, (Animator.q_inv(_b_quat(skel.get_bone_parent(i))) * qa).normalized())


## turn a bone about an axis of the body frame (x = his left, y = up, z = forward); +x leans forward
func _turn(nm: String, ax: float, ay: float, az: float, ang: float) -> void:
	var B: Dictionary = F["B"]
	if not B.has(nm) or ang == 0.0:
		return
	var i: int = B[nm]
	var skel: Skeleton3D = F["skel"]
	var qb := Quaternion((_qf * Vector3(ax, ay, az)).normalized(), ang)
	var qa := qb * _b_quat(i)
	skel.set_bone_pose_rotation(i, (Animator.q_inv(_b_quat(skel.get_bone_parent(i))) * qa).normalized())


func _arms(ux: float, uy: float, uz: float, fx_: float, fy: float, fz: float, w: float) -> void:
	_aim("LeftArm", ux, uy, uz, w)
	_aim("LeftForeArm", fx_, fy, fz, w)
	_aim("RightArm", -ux, uy, uz, w)
	_aim("RightForeArm", -fx_, fy, fz, w)


func _update_frug(dt: float, placed: bool = false) -> void:
	var W: Dictionary = F["w"]
	var yaw_g: Node3D = F["yaw_g"]
	var tilt: Node3D = F["tilt"]
	# ---- where he is (unless the fall placed him) and what his legs do (clip)
	if not placed:
		yaw_g.position = Vector3(F["x"], float(F["y"]) - float(F["drop"]), F["z"])
		yaw_g.quaternion = Quaternion(Vector3.UP, F["yaw"])
		tilt.rotation.x = F["tilt_x"]
		tilt.rotation.z = F["tilt_z"]
	(F["ap"] as AnimationPlayer).advance(dt)
	_qf = tilt.global_basis.get_rotation_quaternion()
	var br := t * 6.2
	# ---- the layers, oldest first (each one slerps the bones toward its pose by its weight)
	if float(W["huff"]) > 0.0:      # fury: chest heaving, shoulders up, head down, fists low
		var k: float = W["huff"]
		var h := 0.5 + 0.5 * sin(br)
		_turn("Spine2", 1.0, 0.0, 0.0, (-0.1 * h + 0.08) * k)
		_turn("Head", 1.0, 0.0, 0.0, 0.22 * k)
		_turn("LeftShoulder", 0.0, 0.0, 1.0, 0.16 * h * k)
		_turn("RightShoulder", 0.0, 0.0, 1.0, -0.16 * h * k)
		_arms(0.38, -0.92, 0.08, 0.22, -0.88, 0.42, 0.85 * k)
	if float(W["laugh"]) > 0.0:      # head thrown back, belly held, the whole torso bouncing
		var k: float = W["laugh"]
		var j := sin(t * 23.0) * 0.5 + 0.5
		_turn("Spine1", 1.0, 0.0, 0.0, (-0.12 - 0.07 * j) * k)
		_turn("Spine2", 1.0, 0.0, 0.0, (-0.16 - 0.06 * j) * k)
		_turn("Head", 1.0, 0.0, 0.0, -0.55 * k + 0.08 * j * k)
		_arms(0.42, -0.78, 0.4, -0.45, -0.15, 0.85, k)
	if float(W["flex"]) > 0.0:      # double biceps: upper arms out level, forearms straight up, chest out
		var k: float = W["flex"]
		var q := sin(t * 40.0) * 0.02 * float(W["strain"])
		_turn("Spine2", 1.0, 0.0, 0.0, -0.16 * k)
		_turn("Head", 1.0, 0.0, 0.0, -0.12 * k)
		_arms(1.0, 0.22 + q, 0.12, 0.08, 1.0, -0.15 + q, k)
	if float(W["roar"]) > 0.0:      # the roar: arms flung down and back, chest up, head forward and up, trembling
		var k: float = W["roar"]
		var q := sin(t * 47.0) * 0.03
		_turn("Spine1", 1.0, 0.0, 0.0, -0.18 * k)
		_turn("Spine2", 1.0, 0.0, 0.0, (-0.24 + q) * k)
		_turn("Neck", 1.0, 0.0, 0.0, 0.3 * k)
		_turn("Head", 1.0, 0.0, 0.0, (-0.32 + q) * k)
		_arms(0.82, -0.42, -0.28, 0.62, -0.55, 0.3 + q, k)
	if float(W["run"]) > 0.0:      # the charge: low, arms pumping (on top of RunFast)
		var k: float = W["run"]
		_turn("Spine", 1.0, 0.0, 0.0, 0.32 * k)
		_turn("Head", 1.0, 0.0, 0.0, -0.22 * k)
	if float(W["kick"]) > 0.0:      # the flying double kick: body laid back (tilt), both legs straight out in line, arms thrown up
		var k: float = W["kick"]
		for sd: String in ["Left", "Right"]:
			var m := 1.0 if sd == "Left" else -1.0
			_aim(sd + "UpLeg", 0.1 * m, -1.0, 0.28, k)
			_aim(sd + "Leg", 0.06 * m, -1.0, 0.3, k)
			_aim(sd + "Foot", 0.0, -0.3, 1.0, k)
		_arms(0.75, 0.55, -0.35, 0.45, 0.85, -0.2, k)
		_turn("Head", 1.0, 0.0, 0.0, 0.6 * k)
	if float(W["land"]) > 0.0:      # three-point landing: right knee down, left knee up, right fist on the deck
		var k: float = W["land"]
		_turn("Spine", 1.0, 0.0, 0.0, 0.45 * k)
		_turn("Spine2", 1.0, 0.0, 0.0, 0.2 * k)
		_turn("Head", 1.0, 0.0, 0.0, -0.55 * k)
		_aim("LeftUpLeg", 0.25, -0.2, 0.95, k)
		_aim("LeftLeg", 0.05, -1.0, -0.12, k)
		_aim("LeftFoot", 0.0, -0.2, 1.0, k)
		_aim("RightUpLeg", -0.15, -1.0, 0.05, k)
		_aim("RightLeg", -0.05, -0.15, -1.0, k)
		_aim("RightArm", -0.25, -0.95, 0.25, k)
		_aim("RightForeArm", -0.05, -1.0, 0.05, k)
		_aim("LeftArm", 0.7, -0.35, -0.5, k)
		_aim("LeftForeArm", 0.4, -0.6, -0.4, k)
	if float(W["grapple"]) > 0.0:      # wrestling in the fall: grabbing at Prog, legs kicking
		var k: float = W["grapple"]
		var a := t * 7.0
		_aim("LeftArm", 0.45, 0.2 + 0.3 * sin(a), 0.9, k)
		_aim("LeftForeArm", -0.4, 0.35 * sin(a + 1.0), 0.85, k)
		_aim("RightArm", -0.45, 0.2 + 0.3 * sin(a + 2.0), 0.9, k)
		_aim("RightForeArm", 0.5, 0.3 * sin(a + 3.0), 0.8, k)
		_aim("LeftUpLeg", 0.2, -0.7, 0.6 * sin(a * 0.9), k)
		_aim("LeftLeg", 0.1, -1.0, -0.4, k)
		_aim("RightUpLeg", -0.2, -0.7, -0.6 * sin(a * 0.9), k)
		_aim("RightLeg", -0.1, -1.0, -0.4, k)
	# nostril steam on each exhale while he is fuming
	if float(W["huff"]) > 0.5 and t < float(T["laugh"]):
		var ph := fmod(br / TAU, 1.0)
		var B: Dictionary = F["B"]
		if ph < 0.5 and float(F["puff_t"]) > 0.5 and B.has("headfront"):
			var a := _b_pos(B["headfront"])
			var b := Vector3(0.0, -0.6, 2.2).rotated(Vector3.UP, F["yaw"])
			for i in 2:
				_puff(a, 0xdfe6ea, 0.12, 0.9, 0.9, {"add": false, "opacity": 0.55, "v": b + Vector3(rr(-0.3, 0.3), 0.0, 0.0)})
		F["puff_t"] = ph


func _frug_chest() -> Vector3:
	var B: Dictionary = F["B"]
	return _b_pos(B["Spine2"]) if B.has("Spine2") else Vector3(F["x"], float(F["y"]) + 1.5, F["z"])


# ---- the suit bursts ----
func _burst_suit() -> void:
	_frug_costume("muscle")
	_snd("rip", {"gain": 1.2})
	_shake = maxf(_shake, 0.6)
	var B: Dictionary = F["B"]
	var bones: Array[int] = []
	for k: String in ["Spine2", "Spine1", "Spine", "LeftArm", "RightArm", "LeftForeArm", "RightForeArm", "LeftUpLeg", "RightUpLeg", "LeftLeg", "RightLeg"]:
		if B.has(k):
			bones.append(B[k])
	for i in 46:
		var a := _b_pos(bones[i % bones.size()])
		var d := Vector3(rr(-1.0, 1.0), rr(-0.2, 1.0), rr(-1.0, 1.0)).normalized()
		var col := 0xe8e4dc if i % 7 == 0 else (0x9a1418 if i % 11 == 0 else 0x15151a)      # black cloth, a few white shirt scraps, the tie
		_chunk(a + d * 0.25, d * rr(4.0, 11.0) + Vector3(0.0, 3.0, 0.0), col, rr(0.12, 0.32), {"flat": 0.12, "spin": 14.0, "life": 6.0})
	for i in 6:      # buttons
		_chunk(_frug_chest(), Vector3(rr(-6.0, 6.0), rr(3.0, 8.0), rr(-6.0, 6.0)), 0xd8d0b0, 0.05, {"geo": _ico_mesh, "spin": 30.0})
	_puff(_frug_chest(), 0x3a3a40, 1.0, 4.5, 0.9, {"add": false, "opacity": 0.4})


# ---- Tommy explodes ----
func _explode_tommy() -> void:
	var tm: Dictionary = H["tommy"]
	var an: Animator = tm["an"]
	var at := _bone_w(an, &"chest")
	if at.length_squared() == 0.0:
		var pp: Player = tm["p"]
		at = Vector3(pp.x, pp.y + 0.8, pp.z)
	an.actor.visible = false
	tm["gone"] = true
	_snd("gore", {"gain": 1.5})
	_shake = 1.4
	Game.fx.shake = maxf(Game.fx.shake, 1.0)
	var pz: float = (H["prog"]["p"] as Player).z
	var to_prog := Vector3(PROG_X - at.x, 0.0, pz - at.z).normalized()
	for i in 70:      # the pieces: suit navy, his white skin, meat
		var r := randf()
		var col := 0x2f3a5e if r < 0.32 else (0xf0efe9 if r < 0.52 else (0x1f1d1e if r < 0.62 else (0x7a0b0b if r < 0.85 else 0xb0201a)))
		var v := Vector3(rr(-1.0, 1.0), rr(0.1, 1.1), rr(0.2, 1.4)).normalized() * rr(5.0, 16.0)
		if i % 4 == 0:
			v += to_prog * 6.0
		_chunk(at + Vector3(rr(-0.2, 0.2), rr(-0.3, 0.3), rr(-0.2, 0.2)), v, col, rr(0.06, 0.26), {"geo": _ico_mesh if i % 3 != 0 else _box_mesh, "trail": "blood" if i % 2 != 0 else "", "life": 9.0})
	Game.fx._blood_spray(at, 0.0, 1.0, 160, 8.0)
	Game.fx._blood_spray(at, to_prog.x, to_prog.z, 120, 6.0)
	for i in 9:
		Game.fx._blood_splat(at.x + rr(-1.6, 1.6), BY, at.z + rr(-0.5, 3.5), rr(0.4, 1.3), 60.0)
	Game.fx._blood_splat(at.x, BY, at.z, 2.2, 60.0)
	for i in 7:
		_puff(at + Vector3(rr(-0.4, 0.4), rr(-0.3, 0.4), rr(0.0, 0.8)), 0x7a0606, 0.4, rr(2.5, 4.0), rr(0.8, 1.4), {"add": false, "opacity": 0.75, "v": Vector3(rr(-1.0, 1.0), rr(-0.2, 0.6), rr(0.5, 2.5))})
	_puff(at, 0xffd0c0, 0.5, 2.5, 0.12)
	# the spatter: Prog (the side facing Tommy) and Frug's front, soaked
	_after.append([0.06, func() -> void:
		if on and H != null:
			var pa: Animator = H["prog"]["an"]
			var pb: Array = []
			for k: StringName in [&"chest", &"spine2", &"head", &"neck", &"upper_armL", &"upper_armR", &"forearmL", &"forearmR", &"thighL", &"thighR", &"pelvis"]:
				if pa.by_key.has(k):
					pb.append([pa.by_key[k].bone, 1.0])
			_splatter(pa.skel, pb, at, 34, 0.09)])
	var B: Dictionary = F["B"]
	var fb: Array = []
	for k: String in ["Spine2", "Spine1", "Spine", "Head", "Neck", "LeftArm", "RightArm", "LeftForeArm", "RightForeArm", "LeftUpLeg", "RightUpLeg", "LeftLeg", "RightLeg", "LeftFoot", "RightFoot"]:
		if B.has(k):
			fb.append([B[k], 1.8 if k == "Spine2" or k == "Spine1" or k == "Hips" else (1.5 if k == "Head" else 1.0)])
	_splatter(F["skel"], fb, at + Vector3(0.0, 0.0, 1.5), 70, 0.13)
	for m: StandardMaterial3D in F["mats"]:      # and darker all over
		m.albedo_color = Color.hex(0xd09090ff)


# ---- the plant coming apart behind them ----
func _boom(x: float, y: float, z: float, big: bool) -> void:
	var p := Vector3(x, y, z)
	Game.fx.explosion(p, 5.0 if big else 3.0)
	_puff(p, 0xfff0b0, 2.0, 16.0 if big else 10.0, 0.55)
	_puff(p, 0xff7a20, 3.0, 22.0 if big else 14.0, 1.0)
	for i in 3:
		_puff(p + Vector3(rr(-3.0, 3.0), rr(0.0, 4.0), rr(-3.0, 3.0)), 0x1e1814, 4.0, 26.0 if big else 16.0, rr(4.0, 6.0), {"add": false, "opacity": 0.7, "rise": rr(2.0, 4.0)})
	for i in (9 if big else 5):
		_chunk(p, Vector3(rr(-9.0, 9.0), rr(6.0, 16.0), rr(-9.0, 9.0)), 0x2a2a2e, rr(0.4, 1.4), {"trail": "smoke", "life": 6.0, "spin": 4.0})
	var d := U.hyp(x - camera.pos.x, z - camera.pos.z)
	_snd("boomBig" if big else "boom", {"gain": clampf(26.0 / maxf(10.0, d), 0.35, 1.3) * (1.3 if big else 1.1), "rate": rr(0.9, 1.05)})
	_shake = maxf(_shake, clampf(30.0 / d, 0.15, 0.7))


# ---- gunfire that never connects ----
func _shoot_at_frug(h: Dictionary, kind: String) -> void:
	var wv: WeaponView = (h["an"] as Animator).wv
	wv.fire(kind, 5.0 if kind == "rifle" else 3.0)
	wv.flash(1.0, kind)
	Game.sfx.play(kind)
	var a := wv.muzzle_world()
	var b := _frug_chest()
	var miss := Vector3(b.x + (-1.0 if randf() < 0.5 else 1.0) * rr(0.7, 1.6), b.y + rr(-0.9, 1.1), b.z)      # wide of him every time
	var far := (miss - a).normalized()
	var hit_z := DOOR_Z + 0.4
	var k := (hit_z - a.z) / (far.z if far.z != 0.0 else -1.0)
	var end := a + far * maxf(2.0, k)
	Game.fx.tracer(a, end, 0.03, 0.06)
	if randf() < 0.6:
		Game.fx.sparks(end, 5, 3.5, Vector3(0.0, 0.2, 1.0), 0xffd27a)


# ---- per frame ----
func _update_heroes(dt: float) -> void:
	var prog: Dictionary = H["prog"]
	var tommy: Dictionary = H["tommy"]
	for h: Dictionary in [prog, tommy]:
		var p: Player = h["p"]
		if h.get("fall", false):
			continue
		# walking up the bridge, the freeze, aim, the slow step back
		if t < float(T["walkEnd"]):
			p.vz = -2.0
			p.z = lerpf(WALK0, STOP_Z, t / float(T["walkEnd"])) + (0.4 if h == prog else -0.3)
			p.vx = 0.0
		elif t > float(T["back"]) and t < float(T["backEnd"]):
			p.vz = 0.55
			p.z += 0.55 * dt
		elif not h.get("running", false):
			p.vz = 0.0
		p.aiming = t > float(T["raise"]) and t < float(T["impact"])      # the shock drops his aim
		p.armed = not (h == prog and t > float(T["toss"]))
		p.y = BY
		p.grounded = true
	var P_: Player = prog["p"]
	# Prog's charge and the tackle
	if prog.get("running", false) and not prog.get("fall", false):
		var dx: float = float(F["x"]) - 0.55 - P_.x
		var dz: float = float(F["z"]) - P_.z
		var d := U.hyp(dx, dz)
		P_.sprinting = true
		P_.yaw = atan2(dx, dz)
		P_.vx = dx / d * 7.5
		P_.vz = dz / d * 7.5
		P_.x += P_.vx * dt
		P_.z += P_.vz * dt
		if d < 0.75:
			_tackle()
	# the knot: the two of them over the rail and down
	if _knot != null:
		var K: Dictionary = _knot
		var v: Vector3 = K["v"]
		v.y -= (7.5 if float(K["x"]) > BX + RAIL_X + 0.2 else 0.0) * dt
		if float(K["x"]) <= BX + RAIL_X + 0.2:
			v.y = maxf(v.y - 6.0 * dt, 0.0)
		K["x"] += v.x * dt
		K["y"] += v.y * dt
		K["z"] += v.z * dt
		v.x *= 1.0 - 0.25 * dt
		K["v"] = v
		K["spin"] += dt * float(K["sv"])
		K["roll"] += dt * 1.6
		if float(K["y"]) < 1.0 and _splash_t < 0.0:
			_splash()
	if not prog.get("running", false):
		P_.yaw = atan2(float(F["x"]) - P_.x, float(F["z"]) - P_.z) if t > float(T["impact"]) else PI      # the kill turns him to face Frug
	(tommy["p"] as Player).yaw = PI
	prog["blank"] = _win(t, float(T["land"]) + 0.3, float(T["scream"]) - 0.1, 0.1, 0.1)
	prog["scream"] = _win(t, T["scream"], float(T["run"]) + 0.2, 0.15, 0.3)
	for h: Dictionary in [prog, tommy]:
		if h.get("gone", false):
			continue
		var an: Animator = h["an"]
		an.update(dt, h["p"])
		if h.get("fall", false) and _knot != null:
			_place_in_knot(an.actor, 0.38, -1.0, PI / 2.0)
			an.actor.position.y += 0.2
	# gunfire: from the first step of the charge to the leap, both of them emptying their guns
	if t > float(T["charge"]) + 0.08 and t < float(T["leap"]) + 0.1:
		for e: Array in [[prog, "rifle", 0.085], [tommy, "smg", 0.07]]:
			var h: Dictionary = e[0]
			if h.get("gone", false):
				continue
			if t > float(h["next"]):
				h["next"] = t + float(e[2]) * rr(0.85, 1.15)
				_shoot_at_frug(h, e[1])
	# Prog's grip on Frug in the tackle and the fall
	if prog.get("fall", false) and not prog.get("gone", false):
		var a := _frug_chest()
		var an: Animator = prog["an"]
		for s: int in [0, 1]:      # 0 = L, 1 = R
			an._ik(s, a + Vector3(0.25 if s == 0 else -0.25, 0.25 + 0.15 * sin(t * 9.0 + (0.0 if s == 0 else 2.0)), 0.0), Vector3(1.0 if s == 0 else -1.0, -1.0, 0.0), 1.0)


## the two of them locked together, tumbling about the fall's axis: each sits `off` to one side of the knot's centre, facing the other
func _place_in_knot(obj: Node3D, off: float, side_sign: float, yaw: float) -> void:
	var K: Dictionary = _knot
	var qb := Quaternion(Vector3.RIGHT, sin(float(K["roll"])) * 0.5) * Quaternion(Vector3.BACK, K["spin"])
	var a := qb * Vector3(off * side_sign, 0.0, 0.0)
	obj.position = Vector3(float(K["x"]) + a.x, float(K["y"]) + a.y, float(K["z"]) + a.z)
	obj.quaternion = qb * Quaternion(Vector3.UP, yaw)


func _tackle() -> void:
	var prog: Dictionary = H["prog"]
	var p: Player = prog["p"]
	prog["running"] = false
	prog["fall"] = true
	p.sprinting = false
	p.grounded = false
	p.vx = 0.0
	p.vz = 0.0
	_snd("tackle", {"gain": 1.4})
	_shake = 1.2
	Game.fx.sparks(Vector3(BX + RAIL_X, BY + 1.0, F["z"]), 14, 5.0, Vector3(1.0, 0.3, 0.0), 0xffd0a0)
	_knot = {"x": (p.x + float(F["x"])) / 2.0, "y": BY + 1.0, "z": (p.z + float(F["z"])) / 2.0, "v": Vector3(4.4, 3.2, -0.2), "spin": 0.0, "sv": 2.4, "roll": 0.0}
	F["mode"] = &"fall"
	(F["ap"] as AnimationPlayer).speed_scale = 0.0
	_E(t + 0.45, func() -> void: _snd("fall", {"gain": 1.1}))


func _splash() -> void:
	_splash_t = t
	var K: Dictionary = _knot
	var p := Vector3(K["x"], 0.4, K["z"])
	(H["prog"]["an"] as Animator).actor.visible = false
	(F["yaw_g"] as Node3D).visible = false
	H["prog"]["gone"] = true
	K["v"] = Vector3.ZERO
	_snd("lava", {"gain": 1.5})
	_fade_v(_music_b, 0.55, 2.5)
	Game.fx.explosion(p, 3.0)
	_puff(p, 0xfff2b0, 1.0, 9.0, 0.5)
	_puff(p, 0xff6a10, 2.0, 14.0, 1.4)
	for i in 40:
		_chunk(p + Vector3(rr(-0.6, 0.6), 0.0, rr(-0.6, 0.6)), Vector3(rr(-4.0, 4.0), rr(6.0, 15.0), rr(-4.0, 4.0)), 0xff7a1a if i % 3 != 0 else 0xffd060, rr(0.12, 0.35), {"geo": _blob_mesh, "emissive": true, "spin": 2.0, "life": 4.0})
	for i in 6:
		_puff(p + Vector3(rr(-1.0, 1.0), rr(0.0, 2.0), rr(-1.0, 1.0)), 0x3a3030, 2.0, rr(10.0, 16.0), rr(3.0, 4.5), {"add": false, "opacity": 0.6, "rise": 3.0})
	Game.fx.sparks(p, 30, 8.0, Vector3.UP, 0xffa040)
	_E(t + 2.6, Game.ui.set_fade.bind(true))
	_E(t + 4.0, _finish.bind(true))


func _update_frug_motion(dt: float) -> void:
	var W: Dictionary = F["w"]
	if F["mode"] == &"fall":      # in the knot: facing Prog, tumbling with him
		var yg: Node3D = F["yaw_g"]
		_place_in_knot(yg, 0.42, 1.0, -PI / 2.0)
		(F["tilt"] as Node3D).rotation = Vector3.ZERO
		F["x"] = yg.position.x
		F["y"] = yg.position.y
		F["z"] = yg.position.z
		W["grapple"] = 1.0
		for k: String in ["huff", "land", "kick", "run", "roar", "flex", "laugh"]:
			W[k] = 0.0
		_update_frug(dt, true)
		return
	# out of the door, the stop
	if t > float(T["frugOut"]) and t < float(T["frugStop"]):
		F["z"] = lerpf(DOOR_Z - 1.5, FRUG_STOP, (t - float(T["frugOut"])) / (float(T["frugStop"]) - float(T["frugOut"])))
		_clip(&"Walking", 0.3, 1.1)
	elif t >= float(T["frugStop"]) and t < float(T["charge"]):
		_clip(&"Idle", 0.4)
	# the charge: from standing to a flat-out sprint in a few steps, weaving
	if t >= float(T["charge"]) and t < float(T["leap"]):
		var u := (t - float(T["charge"])) / (float(T["leap"]) - float(T["charge"]))
		F["z"] = lerpf(FRUG_STOP, -201.6, u * u * 0.3 + u * 0.7)
		F["x"] = FRUG_X + sin(u * 9.0) * 0.45
		_clip(&"RunFast", 0.06, 1.9)
	# the leap: an arc onto Tommy; on past him to the landing
	var tz: float = (H["tommy"]["p"] as Player).z
	var hip: float = F["hip_h"]
	if t >= float(T["leap"]) and t < float(T["impact"]):      # his hips drop to Tommy's chest height: the feet land there
		var u := (t - float(T["leap"])) / (float(T["impact"]) - float(T["leap"]))
		F["z"] = lerpf(-201.6, tz - 0.9, u)
		F["x"] = lerpf(F["x"], TOMMY_X, 0.1)
		F["y"] = BY + lerpf(hip, 1.3, u) + sin(u * PI) * 0.45 - hip
		F["tilt_x"] = -lerpf(0.2, 1.25, Cutscene.ease_(u * 1.6))
	if t >= float(T["impact"]) and t < float(T["land"]):
		var u := (t - float(T["impact"])) / (float(T["land"]) - float(T["impact"]))
		F["z"] = lerpf(tz - 0.9, tz + 0.5, u)
		F["y"] = BY + lerpf(1.3 - hip, 0.0, u)
		F["tilt_x"] = lerpf(-1.25, 0.1, Cutscene.ease_(u))
	if t >= float(T["land"]) and not F["landed"]:
		F["landed"] = true
		F["y"] = BY
		F["tilt_x"] = 0.0
		_shake = maxf(_shake, 0.8)
		Game.fx.dust(Vector3(F["x"], BY + 0.1, F["z"]), 14, 3.0)
		_clip(&"Idle", 0.1)
	F["drop"] = float(W["land"]) * 0.55 * FRUG_SCALE * 0.5
	# layer weights
	W["huff"] = maxf(_win(t, float(T["frugStop"]) - 0.3, float(T["laugh"]) + 0.2, 0.6, 0.3), _win(t, float(T["stare"]) + 0.6, 99.0, 1.2, 0.1))
	W["laugh"] = _win(t, float(T["laugh"]) + 0.5, T["flex"], 0.4, 0.4)
	W["flex"] = _win(t, T["flex"], float(T["roar"]) + 0.1, 0.5, 0.35)
	W["strain"] = Cutscene.ease_((t - float(T["flex"]) - 0.6) / 0.9)
	W["roar"] = _win(t, T["roar"], T["roarEnd"], 0.3, 0.6)
	W["run"] = _win(t, T["charge"], T["leap"], 0.1, 0.1)
	W["kick"] = _win(t, T["leap"], float(T["impact"]) + 0.12, 0.12, 0.15)
	W["land"] = _win(t, float(T["land"]) - 0.08, float(T["stare"]) + 1.2, 0.08, 1.4)
	F["yaw"] = 0.0
	F["tilt_z"] = 0.0
	if t > float(T["land"]):      # after the landing he turns his stare on Prog
		var pp: Player = H["prog"]["p"]
		F["yaw"] = atan2(pp.x - float(F["x"]), pp.z - float(F["z"]))
	_update_frug(dt)


# ---- camera ----
func _frug_head() -> Vector3:
	var B: Dictionary = F["B"]
	return _b_pos(B["Head"]) if B.has("Head") else Vector3(F["x"], float(F["y"]) + 2.5, F["z"])



func _s(px: float, py: float, pz: float, lx: float, ly: float, lz: float, fov: float) -> void:
	camera.pos = Vector3(px, py, pz)
	camera.look = Vector3(lx, ly, lz)
	camera.fov = fov


func _shot_at(tm: float) -> void:
	var P_: Player = H["prog"]["p"]
	var z_p := P_.z
	var z_f: float = F["z"]
	var fx_: float = F["x"]
	var fh := _frug_head()
	var ph := _bone_w(H["prog"]["an"], &"head")
	var fw := Vector3(sin(P_.yaw), 0.0, cos(P_.yaw))
	var sd := Vector3(fw.z, 0.0, -fw.x)
	if tm < float(T["door"]):      # in front of them, low: the plant burning behind
		var u := tm / float(T["door"])
		_s(BX + lerpf(1.8, 1.3, u), BY + lerpf(0.55, 0.8, u), z_p - 6.5, BX - 0.2, BY + 1.5, z_p + 8.0, 48.0)
	elif tm < 8.0:      # over their shoulders: the door opens
		var u := (tm - float(T["door"])) / 2.4
		_s(BX + 0.9, BY + 2.0, z_p + lerpf(3.6, 3.0, u), BX - 0.1, BY + 1.9, DOOR_Z, 46.0)
	elif tm < 9.6:      # the two of them frozen
		var u := (tm - 8.0) / 1.6
		_s(BX + 0.2, BY + 1.3, z_p - lerpf(3.8, 3.3, u), BX, BY + 1.1, z_p, 40.0)
	elif tm < 12.1:      # Frug, fuming, from low
		var u := (tm - 9.6) / 2.5
		_s(BX + 0.8, BY + 1.0, z_f + lerpf(4.4, 3.5, u), fh.x, fh.y - 0.25, fh.z, 38.0)
	elif tm < 16.5:      # they aim; the lines
		var u := (tm - 12.1) / 4.4
		_s(BX + lerpf(3.7, 3.2, u), BY + 1.5, z_p - 2.3, BX, BY + 0.85, z_p - 0.7, 42.0)
	elif tm < 19.4:      # he laughs
		var u := (tm - 16.5) / 2.9
		_s(BX - 1.1, BY + 1.9, z_f + lerpf(4.6, 3.9, u), fh.x, fh.y - 0.4, fh.z, 42.0)
	elif tm < 24.6:      # flex, burst, roar
		var u := (tm - 19.4) / 5.2
		_s(BX + lerpf(2.0, 1.3, u), BY + 0.5, z_f + lerpf(4.9, 4.2, u), fx_, BY + 1.75, z_f, 50.0)
	elif tm < float(T["charge"]):      # pan back to them backing away
		var u := Cutscene.ease_((tm - 24.6) / 2.0)
		_s(BX + 4.0, BY + 1.7, lerpf(z_f + 2.0, z_p - 1.0, u * 0.6), BX, BY + 1.4, lerpf(z_f, z_p, u), 46.0)
	elif tm < float(T["slowA"]):      # SUDDENLY: wide, side on, he is coming
		_s(BX + 7.8, BY + 1.6, -205.5, BX, BY + 1.3, -205.0, 52.0)
	elif tm < float(T["impact"]):      # slow motion: the camera drifts round the kick toward Tommy's face (real time)
		var u := Cutscene.ease_(_slow_real / ((float(T["impact"]) - float(T["slowA"])) / SLOW))
		var a := lerpf(0.15, 0.95, u)
		var tz: float = (H["tommy"]["p"] as Player).z
		var cx := (fx_ + TOMMY_X) / 2.0
		var cz := (z_f + tz) / 2.0
		var cy := (float(F["y"]) + 1.3 + BY + 0.9) / 2.0
		_s(cx + cos(a) * 2.9, cy + 0.15, cz - sin(a) * 2.9 * 0.8 + 0.6, cx, cy, cz, 46.0)      # radius kept inside the rails
	elif tm < float(T["blank"]):      # the burst, the landing
		var tz: float = (H["tommy"]["p"] as Player).z
		_s(BX + 3.6, BY + 1.8, tz + 4.8, BX - 0.6, BY + 1.0, tz - 0.6, 54.0)
	elif tm < float(T["stare"]):      # Prog: nothing on his face (from off his shoulder, clear of Frug)
		var u := (tm - float(T["blank"])) / 3.2
		_s(ph.x + fw.x * lerpf(1.3, 1.1, u) - sd.x * 1.0, ph.y - 0.02, ph.z + fw.z * lerpf(1.3, 1.1, u) - sd.z * 1.0, ph.x, ph.y - 0.05, ph.z, 26.0)
	elif tm < float(T["scream"]):      # over his shoulder: Frug staring back, soaked
		_s(ph.x - fw.x * 1.5 - sd.x * 0.85, ph.y + 0.2, ph.z - fw.z * 1.5 - sd.z * 0.85, fh.x, fh.y - 0.5, fh.z, 40.0)
	elif tm < float(T["run"]):      # the scream
		var u := (tm - float(T["scream"])) / 1.25
		_s(ph.x + fw.x * lerpf(1.3, 1.7, u) + sd.x * 0.3, ph.y - 0.3, ph.z + fw.z * lerpf(1.3, 1.7, u) + sd.z * 0.3, ph.x, ph.y, ph.z, 36.0)
	elif _knot == null or float(_knot["y"]) > BY + 0.3:      # the tackle, over the rail
		_s(BX - 1.2, BY + 1.5, z_f + 2.4, BX + 3.0, BY + 1.0, z_f - 0.3, 52.0)
	elif _splash_t < 0.0:      # falling with them
		_s(float(_knot["x"]) + 2.0, maxf(float(_knot["y"]) + 3.4, 2.6), float(_knot["z"]) + 3.8, _knot["x"], _knot["y"], _knot["z"], 50.0)
	else:
		_s(float(_knot["x"]) + 2.0, 2.6, float(_knot["z"]) + 3.8, _knot["x"], 0.6, _knot["z"], 50.0)
	var k := _shake * 0.06
	camera.pos += Vector3(rr(-k, k), rr(-k, k), rr(-k, k))


# ---- the world we borrow ----
func _borrow() -> void:
	var L: Variant = Game.level
	var sv := {"door": null, "bridge": [], "bots": [], "pa": null}
	var d: OmSecurity.Door = L.act2.door_s if L.get(&"act2") != null else null
	if d != null:
		var zs := []
		for l: Dictionary in d.leaves:
			zs.append((l["leaf"] as Node3D).position.z)
		sv["door"] = {"d": d, "z": zs, "off": d.s.off, "vis": d.g.visible}
	if L.get(&"esc") != null:
		for b: OmEscape.Fall in L.esc.bridge:
			sv["bridge"].append({"b": b, "vis": b.g.visible, "y": b.g.position.y, "r": b.g.rotation})
			b.g.visible = true
			b.g.position.y = BY
			b.g.rotation = Vector3.ZERO
	for b: Variant in Game.enemy_views.bots:
		if not b.culled:
			sv["bots"].append(b)
			b.set_culled(true)
	if Game.animator != null:
		sv["pa"] = Game.animator.actor.visible
		Game.animator.actor.visible = false
	_saved = sv


func _give_back() -> void:
	var sv: Variant = _saved
	if sv == null:
		return
	_saved = null
	if sv["door"] != null:
		var d: OmSecurity.Door = sv["door"]["d"]
		for i in d.leaves.size():
			(d.leaves[i]["leaf"] as Node3D).position.z = sv["door"]["z"][i]
		d.s.set_off(sv["door"]["off"])
	for s: Dictionary in sv["bridge"]:
		var b: OmEscape.Fall = s["b"]
		b.g.visible = s["vis"]
		b.g.position.y = s["y"]
		b.g.rotation = s["r"]
	for b: Variant in sv["bots"]:
		b.set_culled(false)
	if Game.animator != null and sv["pa"] != null:
		Game.animator.actor.visible = sv["pa"]


func _door_open(e: float) -> void:
	if _saved == null or _saved["door"] == null:
		return
	var d: OmSecurity.Door = _saved["door"]["d"]
	e = e * e * (3.0 - 2.0 * e)
	for l: Dictionary in d.leaves:
		(l["leaf"] as Node3D).position.z = float(l["s"]) * e * (d.w / 2.0 - 0.1)


# ---- run ----
func play() -> bool:
	if on:
		return false
	var L: Variant = Game.level
	if L == null or L.get(&"act2") == null:      # Load the omnisphere level first (level omnisphere).
		return false
	on = true
	t = -1.0      # (while the fade goes down and the scene is built)
	real = 0.0
	_ei = 0
	_shake = 0.0
	_slow_real = 0.0
	_splash_t = -1.0
	_ev = []
	_parts = []
	_glows = []
	_knot = null
	_line = null
	_lights = []
	_rifle = null
	_after = []
	_wait = 0.0
	if _box_mesh == null:
		_box_mesh = BoxMesh.new()
		_ico_mesh = SphereMesh.new()      # (JS an icosahedron: as faceted as this gets)
		_ico_mesh.radius = 0.5
		_ico_mesh.height = 1.0
		_ico_mesh.radial_segments = 5
		_ico_mesh.rings = 2
		_blob_mesh = SphereMesh.new()
		_blob_mesh.radius = 0.5
		_blob_mesh.height = 1.0
		_blob_mesh.radial_segments = 7
		_blob_mesh.rings = 5
	_root = Node3D.new()
	_root.name = "FrugShowdown"
	Game.level.add_child(_root)
	camera.pos = Game.camera.global_position
	camera.look = Game.camera.global_position - Game.camera.global_basis.z
	camera.fov = 50.0
	enter_cine(false)
	Game.ui.dialog.set_bars(true)
	Game.ui.set_fade(true)
	return true


func _begin() -> void:
	_build_heroes()
	_build_frug()
	_borrow()
	_audio_on()
	for e: Array in [[BX, DOOR_Z + 2.0], [BX, -170.0]]:
		var l := CineParts.light(_root, 0xff2a10, 0.0, 26.0, e[0], BY + 5.0, e[1], 1.6)
		_lights.append(l)
	# score + beds
	_music_a = _snd("musicA", {"gain": 1.0, "bus": B_MUSIC})
	_snd("ambience", {"gain": 0.5, "loop": true, "bus": B_AMB})
	_snd("alarm", {"gain": 0.38, "loop": true, "bus": B_AMB})
	t = 0.0
	_E(T["fadeIn"], Game.ui.set_fade.bind(false))
	for b: Array in BOOMS:
		_E(b[0], _boom.bind(b[1], b[2], b[3], b[4]))
	_E(float(T["door"]) - 0.2, func() -> void: _snd("groan", {"gain": 0.8}))
	_E(T["huff"], func() -> void: _snd("huff", {"gain": 1.3}))
	_E(float(T["raise"]) + 0.1, func() -> void: Game.sfx.play("equip"))
	_E(T["lineT"], _say.bind("TOMMY", "Don't. Move."))
	_E(T["lineP"], _say.bind("PROG", "It's over, Frug."))
	_E(T["laugh"], func() -> void: _snd("laugh", {"gain": 1.4}))
	_E(T["burst"], _burst_suit)
	_E(T["roar"], func() -> void:
		_snd("roar", {"gain": 1.5})
		_shake = maxf(_shake, 0.9)
		_fade_v(B_AMB, 0.5, 0.3))
	_E(T["roarEnd"], _fade_v.bind(B_AMB, 1.0, 1.0))
	_E(T["charge"], func() -> void:
		if _music_a != null and is_instance_valid(_music_a):
			_music_a.stop()
		_snd("charge", {"gain": 1.5, "rate": 1.15})
		_shake = 0.5)
	_E(T["slowA"], func() -> void:
		_snd("slowmo", {"gain": 1.4, "bus": &"SFX"})
		_ramps.append({"lp": true, "v": null, "cur": 20000.0, "to": 500.0, "tau": 0.08}))
	_E(T["impact"], func() -> void:
		_ramps = _ramps.filter(func(r: Dictionary) -> bool: return not r.has("lp"))
		_set_cutoff(20000.0)
		_explode_tommy())
	_E(float(T["impact"]) + 0.35, func() -> void:
		_fade_v(B_AMB, 0.08, 0.6)
		_tinnitus(true))
	_E(T["scream"], func() -> void:
		_tinnitus(false)
		_fade_v(B_AMB, 1.0, 0.3)
		_snd("scream", {"gain": 1.6})
		_music_b = _snd("musicB", {"gain": 1.0, "bus": B_MUSIC})
		_shake = 0.7)
	_E(T["toss"], _toss_rifle)
	_E(T["run"], func() -> void: H["prog"]["running"] = true)


func _toss_rifle() -> void:
	var h: Dictionary = H["prog"]
	(h["p"] as Player).armed = false
	var g: Node3D = (load("res://assets/weapons/rifle.glb") as PackedScene).instantiate()
	_root.add_child(g)
	var a := _bone_w(h["an"], &"handR")
	var pp: Player = h["p"]
	g.position = a if a.length_squared() > 0.0 else Vector3(pp.x, pp.y + 1.2, pp.z)
	_rifle = {"g": g, "v": Vector3(-5.5, 4.5, 1.5), "w": Vector3(rr(-10.0, -6.0), rr(-3.0, 3.0), rr(4.0, 9.0))}
	Game.sfx.play("whoosh")


func _finish(_ok: bool) -> void:
	if not on:
		return
	on = false
	_end_line()
	_ring = null
	_audio_off()
	_give_back()
	if H != null:
		(H["prog"]["an"] as Animator).pose_hook = Callable()
		(H["tommy"]["an"] as Animator).pose_hook = Callable()
	if _root != null:
		_root.queue_free()
		_root = null
	H = null
	F = null
	_knot = null
	_rifle = null
	_parts = []
	_glows = []
	leave_cine()
	Game.rig.snap_to(Game.player)
	Game.get_tree().create_timer(0.15).timeout.connect(Game.ui.set_fade.bind(false))


## X: the only way out besides the tackle landing (not while the scene is still building)
func skip() -> void:
	if on and t >= 0.0:
		_finish(true)


## skip to a moment on the clock (testing): events before it fire in order
func seek(s: float) -> void:
	var h := hold
	hold = false
	while on and t < s:
		update(1.0 / 30.0)
	hold = h


func update(dt: float) -> void:
	if not on:
		return
	if _root != null and not is_instance_valid(_root):      # (the level went from under it: console level change)
		_root = null
		_finish(false)
		return
	if t < 0.0:
		_wait += dt
		if _wait > 0.5:
			_begin()
		return
	if H == null or F == null:
		return
	if hold:
		dt = 0.0
	dt = minf(dt, 0.05)
	real += dt
	for i in range(_after.size() - 1, -1, -1):
		_after[i][0] -= dt
		if float(_after[i][0]) <= 0.0:
			(_after[i][1] as Callable).call()
			_after.remove_at(i)
	_ramp_step(dt)
	for r: Dictionary in _ramps:
		if r.has("lp"):
			_set_cutoff(r["cur"])
	var slow := t >= float(T["slowA"]) and t < float(T["impact"])
	var sdt := dt * SLOW if slow else dt
	if slow:
		_slow_real += dt
	t += sdt
	while _ei < _ev.size() and float(_ev[_ei]["t"]) <= t:
		var e: Dictionary = _ev[_ei]
		_ei += 1
		(e["fn"] as Callable).call()
		if not on:
			return
	RenderingServer.global_shader_parameter_set(&"omni_alarm", 1.0)      # (the level's tick has just put its own value back)
	_door_open(clampf((t - float(T["door"])) / 0.8, 0.0, 1.0))
	for l: OmniLight3D in _lights:
		l.light_energy = (14.0 if t < float(T["impact"]) + 0.3 else 6.0) * (1.0 if sin(real * 2.2 * TAU) > 0.0 else 0.15) / PI
	_update_frug_motion(sdt)
	_update_heroes(sdt)
	if _rifle != null:
		var g: Node3D = _rifle["g"]
		var v: Vector3 = _rifle["v"]
		v.y -= 15.0 * sdt
		_rifle["v"] = v
		g.position += v * sdt
		g.rotation += (_rifle["w"] as Vector3) * sdt
		if g.position.y < 0.0:
			g.queue_free()
			_rifle = null
	_update_parts(sdt)
	_update_glows(sdt)
	_tick_line()
	Game.fx.update(sdt)
	Game.enemy_views.flush()
	_shot_at(t)
	_shake = maxf(0.0, _shake - dt * 2.2)


## the level is being left under it
func dispose() -> void:
	if on:
		_finish(false)
