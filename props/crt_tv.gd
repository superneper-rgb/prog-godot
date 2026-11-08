class_name CrtTv
extends Node3D
## The old CRT television hanging from the gunshop's ceiling (JS props/crt-tv.js): the set comes with the level export, this is its screen and its life: a NO SIGNAL card when idle, play_once() plays the video with its sound coming out of the set, and every so often a glitch (tear, roll, collapse) with a crackle. ENGINE DIFFERENCE: Godot has no MP4 decoder here: tools/export/render-video.mjs turned the video into JPEG frames and a WAV.

const SCREEN_ASPECT := 0.5 / 0.36
const VIDEO := "res://assets/video/gunshop.frames"
const SOUND := "res://assets/video/gunshop.wav"

var playing := false
var paused := false
var drop := 0.95
var _mat: ShaderMaterial
var _glow: OmniLight3D
var _t := 0.0
var _next := 3.0 + randf() * 5.0
var _kind := &""
var _gt := 0.0
var _gd := 0.0
var _k := 0.0
var _force := &""
var _force_dur := 0.0
var _roll := 0.0
var _crackle: AudioStreamWAV
# NO SIGNAL
var _sig_tex: ImageTexture = null
var _sig_vp: SubViewport
var _sig_view: Control
var _sx := 140.0
var _sy := 150.0
var _svx := 22.0
var _svy := 15.0
var _sacc := 0.0
# the video
var _bytes := PackedByteArray()
var _offs := PackedInt32Array()
var _frames := 0
var _fps := 15.0
var _vw := 320
var _vh := 180
var _vt := 0.0
var _vtex: ImageTexture = null
var _vframe := -1
var _on_end := Callable()
var _audio: AudioStreamPlayer
var _ai := -1


class Card:
	extends Control
	var o: CrtTv
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 512, 384), Color("#182fb5"))
		var f := CrtTheme.font(&"vt323")
		draw_string(f, Vector2(28, 44), "AV-1", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)
		var w := f.get_string_size("NO SIGNAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 50).x + 40.0
		draw_rect(Rect2(o._sx + 5.0, o._sy + 5.0, w, 64), Color(0, 0, 0, 0.35))
		draw_rect(Rect2(o._sx, o._sy, w, 64), Color("#f4f6ff"))
		draw_string(f, Vector2(o._sx + 20.0, o._sy + 48.0), "NO SIGNAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 50, Color("#1b3bc4"))


## screen: the JS's CrtScreen mesh, in the set the export made
func setup(screen: MeshInstance3D) -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://props/crt_tv.gdshader")
	screen.material_override = _mat
	_sig_vp = SubViewport.new()
	_sig_vp.size = Vector2i(512, 384)
	_sig_vp.disable_3d = true
	_sig_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_sig_vp)
	var c := Card.new()
	c.o = self
	c.size = Vector2(512, 384)
	_sig_vp.add_child(c)
	_sig_view = c
	_mat.set_shader_parameter(&"src", _sig_vp.get_texture())
	_glow = OmniLight3D.new()
	_glow.light_color = Color.hex(0x7fa0ffff)
	_glow.omni_range = 3.2
	_glow.omni_attenuation = 2.0
	screen.add_child(_glow)
	_glow.position = Vector3(0.0, 0.0, 0.38)
	_crackle = Cutscene.synth(0.4, [], [[0.0, 0.35, &"bandpass", 2400.0, 900.0, 0.7, 0.22, 0.002]])
	_audio = AudioStreamPlayer.new()
	_audio.bus = &"SFX"
	add_child(_audio)


func _sig_step(dt: float) -> void:
	_sacc += dt
	if _sacc < 1.0 / 15.0:
		return
	_sx += _svx * _sacc
	_sy += _svy * _sacc
	_sacc = 0.0
	if _sx < 20.0 or _sx + 280.0 > 492.0:
		_svx = -_svx
		_sx = clampf(_sx, 20.0, 492.0 - 280.0)
	if _sy < 70.0 or _sy > 300.0:
		_svy = -_svy
		_sy = clampf(_sy, 70.0, 300.0)
	_sig_view.queue_redraw()
	_sig_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


## glitch now (kind: tear | roll | collapse, random if omitted; dur in seconds, optional)
func glitch(kind: StringName = &"", dur: float = 0.0) -> void:
	if _kind != &"":
		return
	_force = kind
	_force_dur = dur
	_next = 0.0


func update(dt: float, listener: Vector3) -> void:
	if _mat == null:
		return
	_t += dt
	_mat.set_shader_parameter(&"time", _t)
	if not playing:
		_sig_step(dt)
	_next -= dt
	if _next <= 0.0 and _kind == &"":
		var r := randf()
		_kind = _force if _force != &"" else (&"tear" if r < 0.55 else (&"roll" if r < 0.85 else &"collapse"))
		_gt = 0.0
		_gd = _force_dur if _force_dur > 0.0 else ((0.12 + randf() * 0.45) if _kind == &"tear" else ((0.5 + randf() * 0.4) if _kind == &"roll" else 0.35))
		_k = 0.5 + randf() * 0.5
		_force = &""
		_force_dur = 0.0
		_mat.set_shader_parameter(&"seed", randf() * 100.0)
		var v := 1.0 / (1.0 + global_position.distance_to(listener) * 0.6)
		if v >= 0.04:
			Game.sfx.clip(_crackle, {"gain": v * _k, "wet": 0.15})
	var gl := 0.0
	var sq := 1.0
	if _kind != &"":
		_gt += dt
		var u := minf(1.0, _gt / _gd)
		if _kind == &"tear":
			gl = _k * (u / 0.15 if u < 0.15 else 1.0 - (u - 0.15) / 0.85) * (0.6 + 0.4 * randf())
		elif _kind == &"roll":
			_roll = (u * u * (3.0 - 2.0 * u)) * (2.0 if _k > 0.75 else 1.0)
			gl = 0.25 * sin(PI * u)
		else:      # squeeze to a line and spring back
			sq = (1.0 - u / 0.4 * 0.995) if u < 0.4 else (0.005 if u < 0.6 else (u - 0.6) / 0.4)
			gl = 0.4 * (1.0 - u)
		if u >= 1.0:
			_kind = &""
			_roll = 0.0
			_next = 4.0 + randf() * 9.0
	elif randf() < dt * 0.25:      # the odd single-frame hiccup between real glitches
		gl = 0.12 + randf() * 0.12
	_mat.set_shader_parameter(&"glitch", gl)
	_mat.set_shader_parameter(&"roll", fmod(_roll, 1.0))
	_mat.set_shader_parameter(&"squash", sq)
	_glow.light_energy = (0.75 + 0.15 * sin(_t * 9.0) + 0.6 * gl) * maxf(0.15, sq) / PI
	if playing and not paused:
		_vt += dt
		var f := int(_vt * _fps)
		if f >= _frames:
			var cb := _on_end
			stop()
			if cb.is_valid():
				cb.call()
		elif f != _vframe:
			_vframe = f
			_show_frame(f)
	# the set's sound follows the listener: quieter with distance, panned
	if _audio.playing and _ai >= 0:
		var p := global_position - Vector3(0.0, drop, 0.0)
		var d := p.distance_to(listener)
		_audio.volume_db = linear_to_db(maxf(0.9 / (1.0 + maxf(0.0, d - 1.5) * 0.45), 1e-5)) if not paused else -80.0


func _load_video() -> void:
	if not _bytes.is_empty():
		return
	_bytes = FileAccess.get_file_as_bytes(VIDEO)
	if _bytes.size() < 16:
		return
	_frames = _bytes.decode_u32(0)
	_fps = _bytes.decode_u32(4) / 1000.0
	_vw = _bytes.decode_u32(8)
	_vh = _bytes.decode_u32(12)
	_offs.resize(_frames + 1)
	var o := 16
	for i in _frames:
		_offs[i] = o
		o += 4 + _bytes.decode_u32(o)
	_offs[_frames] = o


func _show_frame(f: int) -> void:
	var o := _offs[f]
	var len_ := _bytes.decode_u32(o)
	var im := Image.new()
	if im.load_jpg_from_buffer(_bytes.slice(o + 4, o + 4 + len_)) != OK:
		return
	if _vtex == null:
		_vtex = ImageTexture.create_from_image(im)
		var a := float(_vw) / float(_vh) / SCREEN_ASPECT
		_mat.set_shader_parameter(&"fit", Vector2(a if a < 1.0 else 1.0, 1.0 / a if a > 1.0 else 1.0))
		_mat.set_shader_parameter(&"src", _vtex)
	else:
		_vtex.update(im)


## play the video once with sound, then go back to NO SIGNAL (on_end is called then)
func play_once(on_end: Callable = Callable()) -> void:
	_load_video()
	if _frames == 0:
		if on_end.is_valid():
			on_end.call()
		return
	_on_end = on_end
	_vt = 0.0
	_vframe = -1
	playing = true
	paused = false
	glitch(&"collapse", 0.3)      # the picture snaps in like a channel change
	if ResourceLoader.exists(SOUND):
		_audio.stream = load(SOUND)
		_audio.play()
		_ai = 0
	_show_frame(0)
	_mat.set_shader_parameter(&"src", _vtex)


func stop() -> void:
	playing = false
	_audio.stop()
	_ai = -1
	_vtex = null
	_mat.set_shader_parameter(&"src", _sig_vp.get_texture())
	_mat.set_shader_parameter(&"fit", Vector2.ONE)


## freeze / resume the video with the game (pause menu, shop terminals)
func set_paused(p: bool) -> void:
	if not playing or p == paused:
		return
	paused = p
	_audio.stream_paused = p
