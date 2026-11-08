class_name NightVision
extends CanvasLayer
## NIGHT VISION (N, pad: d-pad down; JS gear/night-vision.js): goggles kept in the left hip pocket. Putting them on, the left hand pulls them out of the pocket, lifts them over the head, sets them on it, swings / pulls them down over the eyes and clicks them on (the green, grainy screen + the charge whine). Taking them off runs it backwards: click off, swing them up, lift them off the head and stuff them back in the pocket (out of sight).
## The model is gear/goggles.gd, fitted to each character by measuring the head mesh once. It hangs on the head bone; while it is in the hand only its position is moved (kept upright in the head's frame, so the hand-off to the head is seamless).
## ENGINE DIFFERENCE: the JS raises the ambient for each render and puts it back; here that would redraw the radiance map every frame, so the raised values stay set while it is on and are only rewritten when they change.

# the two moves, in seconds. ON: reach the pocket, out (goggles appear), up over the head, set on the head, onto the eyes, click on, hand down.
const ON := {"pocket": 0.32, "up": 0.78, "place": 1.02, "eyes": 1.42, "click": 1.5, "end": 1.92}
# OFF: hand up to the goggles, click off, off the eyes, lift off the head, down into the pocket (goggles gone), hand back.
const OFF := {"hand": 0.3, "eyes": 0.68, "lift": 0.94, "pocket": 1.42, "end": 1.82}
# LIGHT AMPLIFICATION while the goggles are on: the scene's ambient is raised and evened out (the ground half as bright as the sky, so shadowed floors and walls come up too) and the exposure lifted. Only light values change, so no shader recompiles.
const AMP_HEMI := 2.4
const AMP_SKY := Color8(0xdf, 0xe6, 0xee)
const AMP_GROUND := Color8(0x8c, 0x94, 0x9c)
const AMP_MIX := 0.75
const AMP_EXPOSURE := 1.7

var mode: StringName = &"stored"      # stored (in the pocket) | equip | worn | remove
var t := 0.0      # seconds into the move
var on := false
var fired := false
var k := 0.0      # how far they are down over the eyes
var m := 0.0      # 0 in the hand .. 1 on the head
var vis := false
var fit: Goggles = null
var _fit_for: Animator = null
var _worn := Vector3.ZERO
# this frame's move: where the left hand goes (a blend of named spots) and how hard (w)
var _pw := 0.0
var _pa := &""
var _pb := &""
var _pf := 0.0
var _has_plan := false
var live := true
var flash := 0.0
var _amp := 0.0
var _applied := false
var _base_c := Color.WHITE
var _base_g := Color.WHITE
var _base_i := 1.0
var _base_e := 1.0
var _set_i := 0.0
var _set_e := 0.0
var _overlay := 0.0
var _mat: ShaderMaterial
var _rect: ColorRect
var _label: Label
var _sub: Label
var _whine_on: AudioStreamWAV
var _whine_off: AudioStreamWAV
var _hum: AudioStreamPlayer
var _hum_k := 0.0

var busy: bool:
	get:
		return mode == &"equip" or mode == &"remove"


func _ready() -> void:
	layer = -1      # under the HUD: the JS filter is on the game's canvas only, its overlay under the HUD elements
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://gear/nv_screen.gdshader")
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _mat
	_rect.visible = false
	add_child(_rect)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	box.offset_left = -130.0
	box.offset_right = -22.0
	box.offset_top = -16.0
	box.offset_bottom = 16.0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 0)
	_rect.add_child(box)
	_label = _text(load("res://assets/fonts/Rajdhani-Bold.ttf"), 12, "N  V", 0.8)
	_sub = _text(load("res://assets/fonts/Rajdhani-Medium.ttf"), 10, "", 0.6)
	box.add_child(_label)
	box.add_child(_sub)
	_hum = AudioStreamPlayer.new()
	_hum.bus = &"SFX"
	add_child(_hum)


func _text(f: Font, size: int, s: String, a: float) -> Label:
	var l := Label.new()
	l.text = s
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.add_theme_font_override(&"font", f)
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", Color(170.0 / 255.0, 1.0, 140.0 / 255.0, a))
	l.add_theme_color_override(&"font_shadow_color", Color(120.0 / 255.0, 1.0, 90.0 / 255.0, 0.5))
	l.add_theme_constant_override(&"shadow_offset_x", 0)
	l.add_theme_constant_override(&"shadow_offset_y", 0)
	return l


func toggle() -> bool:
	if mode == &"stored":
		mode = &"equip"
		t = 0.0
		fired = false
		return true
	if mode == &"worn":
		mode = &"remove"
		t = 0.0
		fired = false
		return true
	return false      # mid-move


static func _span(u: float, a: float, b: float) -> float:
	var x := clampf((u - a) / (b - a), 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _mv(w: float, a: StringName, b: StringName, f: float) -> void:
	_pw = w
	_pa = a
	_pb = b
	_pf = f
	_has_plan = true


## this frame's move: goggle state (vis, m, k), where the left hand goes (a blend of named spots) and how hard (w)
func _plan(dt: float) -> void:
	_has_plan = false
	if mode == &"equip":
		t = minf(ON.end, t + dt)
		vis = t >= float(ON.pocket)
		m = _span(t, ON.up, ON.place)
		k = _span(t, ON.place, ON.eyes)
		if not fired and t >= float(ON.click):
			fired = true
			on = true
			flash = 1.0
			_sound_on()
		if t >= float(ON.end):
			mode = &"worn"
		var w := minf(_span(t, 0.0, 0.2), 1.0 - _span(t, float(ON.click) + 0.05, ON.end))
		if t < float(ON.pocket):
			_mv(w, &"pocket", &"pocket", 0.0)
		elif t < float(ON.up):
			_mv(w, &"pocket", &"over", _span(t, ON.pocket, ON.up))
		elif t < float(ON.place):
			_mv(w, &"over", &"lens", _span(t, ON.up, ON.place))
		else:
			_mv(w, &"lens", &"lens", 0.0)
		return
	if mode == &"remove":
		t = minf(OFF.end, t + dt)
		if not fired and t >= float(OFF.hand):
			fired = true
			on = false
			_sound_off()
		k = 1.0 - _span(t, OFF.hand, OFF.eyes)
		m = 1.0 - _span(t, OFF.eyes, OFF.lift)
		vis = t < float(OFF.pocket)
		if t >= float(OFF.end):
			mode = &"stored"
		var w := minf(_span(t, 0.0, 0.22), 1.0 - _span(t, float(OFF.pocket) + 0.02, OFF.end))
		if t < float(OFF.eyes):
			_mv(w, &"lens", &"lens", 0.0)
		elif t < float(OFF.lift):
			_mv(w, &"lens", &"over", _span(t, OFF.eyes, OFF.lift))
		else:
			_mv(w, &"over", &"pocket", _span(t, OFF.lift, OFF.pocket))
		return
	vis = mode == &"worn"
	m = 1.0
	k = 1.0 if mode == &"worn" else 0.0


## fit the goggles to this character (once per animator: a character swap builds new ones)
func _fit_to(an: Animator) -> void:
	_fit_for = an
	for c: Node in an.skel.get_children():      # a pair an earlier animator of the same model left
		if c is BoneAttachment3D and c.get_node_or_null(^"night-vision-goggles") != null:
			c.queue_free()
	fit = Goggles.fit(an, Game.char_pick)
	if fit != null:
		_worn = fit.root.position
		fit.light.omni_attenuation = 2.0      # (JS PointLight decay 2: it lights the face a little)


## the pair on the head and its arm: left hand to the pocket, over the head, onto the lenses
func _pose_kit(an: Animator) -> void:
	var root := fit.root
	var s := fit.head_w / 0.2
	fit.pose.call(k)
	root.visible = vis
	if not vis and not _has_plan:
		return      # in the pocket: nothing to pose
	# on the head: where it sits and where its lens is (the grip) -- the hand-held goggles keep that offset from the hand
	root.position = _worn
	fit.attach.on_skeleton_update()      # (the attachment follows the skeleton at the end of the frame; this frame's head is wanted now)
	var worn_p := root.global_position
	var lens_w := fit.glows[0].global_position
	var aq := an.actor.global_basis.get_rotation_quaternion()
	var fw := aq * Vector3(0.0, 0.0, 1.0)
	if _has_plan and _pw > 0.001:
		var up := aq * Vector3(0.0, 1.0, 0.0)
		var lf := aq * Vector3(1.0, 0.0, 0.0)
		var th: Variant = an.by_key.get(&"thighL")      # the left hip pocket: just below and outside the hip joint
		var pocket: Vector3 = an.bone_world_pos(th.bone) if th != null else worn_p + up * (-0.8 * s)
		pocket += lf * (0.07 * s) + up * (-0.1 * s) + fw * (0.04 * s)
		var over := lens_w + up * (0.13 * s) + fw * (0.07 * s)      # held up over the head before it goes on
		var lens := lens_w + lf * (0.03 * s) + up * (-0.05 * s) + fw * (0.06 * s)      # fingers on the front of the lenses
		var spot := {&"pocket": pocket, &"over": over, &"lens": lens}
		var tgt: Vector3 = (spot[_pa] as Vector3).lerp(spot[_pb], _pf)
		an._ik(0, tgt, aq * Vector3(1.0, -0.3, -0.15), _pw)      # elbow out to the side
	# in the hand: carried with the hand (same offset the grip has on the head), blending onto the head as m -> 1
	if vis and m < 1.0:
		var hand: Vector3 = an.bone_world_pos(an.by_key[&"handL"].bone) + (worn_p - lens_w) + fw * (0.03 * s)
		root.global_position = hand.lerp(worn_p, m)
	# lens glow + face light (only once it is clicked on)
	var g := 1.0 if on else 0.0
	var flick := 0.92 + 0.08 * randf()
	fit.lens_mat.emission_energy_multiplier = 0.15 + 2.4 * g
	fit.glow_mat.set_shader_parameter(&"opacity", 0.9 * g * flick)
	fit.light.light_energy = 0.7 * g / PI if vis else 0.0


## Every frame after the animator has posed the body. dt 0 while the game is frozen; p_live false while paused / in menus (no screen effect).
func update(dt: float, p_live: bool) -> void:
	var an: Animator = Game.animator
	if an != null and _fit_for != an:
		_fit_to(an)
	_plan(dt)
	if an != null and fit != null:
		_pose_kit(an)
	live = p_live
	var real := Game.frame_real_dt
	var show := on and live
	_overlay = move_toward(_overlay, 1.0 if show else 0.0, real / 0.12)
	if show != _rect.visible:
		_rect.visible = show
		if show:
			_sub.text = "BINOCULAR" if Game.char_pick == "tommy" else "TRIFOCAL"
	if show:
		if flash > 0.0:
			flash = maxf(0.0, flash - dt * 2.6)
		_mat.set_shader_parameter(&"flash", flash * flash)
		_mat.set_shader_parameter(&"overlay", _overlay)
	if _hum.playing:
		_hum_k = move_toward(_hum_k, 1.0 if on else 0.0, real / (1.2 if on else 0.15))
		_hum.volume_db = linear_to_db(maxf(0.0045 * _hum_k, 1e-5))
		if not on and _hum_k <= 0.0:
			_hum.stop()


## See the header: returns false, the values stay set. Called by the view just before the world renders.
func amplify(view: View, dt: float) -> bool:
	_amp += ((1.0 if (on and live) else 0.0) - _amp) * minf(1.0, dt * (6.0 if on else 10.0))
	if _amp < 0.002:
		if _applied:
			_applied = false
			view.set_hemi(_base_c, _base_g, _base_i)
			view.set_tone_mapping(view.tone_mapping, _base_e)
		return false
	if not _applied or view.hemi_intensity != _set_i or view.exposure != _set_e:      # first frame, or the level set its own look underneath
		if not _applied or view.hemi_intensity != _set_i:
			_base_c = view.hemi_color
			_base_g = view.hemi_ground
			_base_i = view.hemi_intensity
		if not _applied or view.exposure != _set_e:
			_base_e = view.exposure
		_applied = true
		_set_i = -1.0
	var i := _base_i + AMP_HEMI * _amp
	var e := _base_e * (1.0 + (AMP_EXPOSURE - 1.0) * _amp)
	if absf(i - _set_i) > 0.002:
		view.set_hemi(_base_c.lerp(AMP_SKY, AMP_MIX * _amp), _base_g.lerp(AMP_GROUND, AMP_MIX * _amp), i)
		view.set_tone_mapping(view.tone_mapping, e)
		_set_i = view.hemi_intensity
		_set_e = view.exposure
	return false


func restore(_view: View) -> void:
	pass


# ---- sound: switch click, the rising charge whine, a faint high hum while on; a falling chirp when it goes off ----
func _click(b: PackedFloat32Array, rate: int) -> void:
	OfflineSynth.noise(b, rate, 0.0, {"type": &"highpass", "f0": 3500.0, "f1": 3500.0, "q": 0.0, "gain": 0.25, "dur": 0.025})
	OfflineSynth.tone(b, rate, 0.0, {"type": &"square", "f0": 1800.0, "f1": 900.0, "gain": 0.03, "dur": 0.03})


func _sound_on() -> void:
	if _whine_on == null:      # (rendered the first time: about 30 ms, under the click)
		var rate := 44100
		var b := OfflineSynth.make(1.4, rate)
		_click(b, rate)
		for r: Array in [[&"sine", 1.0, 0.075], [&"triangle", 1.5, 0.025], [&"sine", 2.01, 0.012]]:
			_whine_part(b, rate, r[0], r[1], r[2])
		_whine_on = OfflineSynth.wav(b, rate)
		var h := OfflineSynth.make(1.0, rate)
		for i in h.size():
			h[i] = sin(TAU * 11800.0 * i / rate)
		_hum.stream = OfflineSynth.wav(h, rate, true)
	Game.sfx.clip(_whine_on, {"wet": 0.0})
	_hum_k = 0.0
	_hum.volume_db = -100.0
	_hum.play()


## frequency 1400 -> 7800 by .75 s -> 8600 by 1.3 s, gain up to g0 by .12 s, held to .7 s, down to nothing by 1.35 s
func _whine_part(b: PackedFloat32Array, rate: int, type: StringName, mul: float, g0: float) -> void:
	var ph := 0.0
	for i in mini(roundi(1.35 * rate), b.size()):
		var u := float(i) / rate
		var f := 1400.0 * pow(7800.0 / 1400.0, u / 0.75) if u < 0.75 else 7800.0 * pow(8600.0 / 7800.0, (u - 0.75) / 0.55)
		var g := 0.0001 * pow(g0 / 0.0001, u / 0.12) if u < 0.12 else (g0 if u < 0.7 else g0 * pow(0.0001 / g0, (u - 0.7) / 0.65))
		ph = fposmod(ph + f * mul / rate, 1.0)
		b[i] += OfflineSynth._wave(type, ph) * g


func _sound_off() -> void:
	if _whine_off == null:
		var rate := 44100
		var b := OfflineSynth.make(0.4, rate)
		_click(b, rate)
		OfflineSynth.tone(b, rate, 0.0, {"type": &"sine", "f0": 6500.0, "f1": 900.0, "gain": 0.05, "dur": 0.35, "attack": 0.001})
		_whine_off = OfflineSynth.wav(b, rate)
	Game.sfx.clip(_whine_off, {"wet": 0.0})
