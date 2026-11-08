class_name IntroAlley
extends CanvasLayer
## The old opening (JS intro/intro.js, kept in the cutscene list): Tommy walks into an alley, sprays "SHIT HOUSE" on the wall, looks at the viewer and walks off, then it fades to black. Its own world, lights and Tommy (a copy of the model on the game's own Animator), so it never touches the game world. The animation is a pure function of time.

const WALL_Z := -3.0
const TEXT := "SHIT HOUSE"
const WALK_A := 0.5
const WALK_B := 3.6
const TURN_A := 3.6
const TURN_B := 4.3
const SHAKE_A := 4.3
const SPRAY_A := 5.5
const SPRAY_B := 10.0
const LOWER_A := 10.0
const LOWER_B := 10.8
const FACE_A := 10.5
const FACE_B := 11.4
const LOOK_A := 11.4
const LOOK_B := 15.0
const BIRD_A := 12.3
const BIRD_B := 14.7
const BACK_A := 15.0
const BACK_B := 15.7
const LEAVE_A := 15.7
const FADE_A := 18.2
const END_T := 19.5
const X_IN := -3.4
const X_STOP := -0.6
const X_END := 1.45
const X_FACE := 2.25
const GW := 1536
const GH := 384
const NP := 90
const SONG_T0 := 0.3
const CAM_A := Vector3(1.7, 1.1, 3.9)
const CAM_B := Vector3(1.5, 1.08, 3.4)
const CAM_LOOK := Vector3(0.3, 0.9, WALL_Z)

var on_done := Callable()
var t := 0.0
var _done := false
var _skipping := 0.0
var _vp: SubViewport
var _cam: Camera3D
var _an: Animator
var _p: Player
var _fade: ColorRect
var _hint: Label
var _can: Node3D
var _nozzle: Node3D
var _finger: MeshInstance3D
var _knuckles: Array[MeshInstance3D] = []
var _mist: MultiMesh
var _p_pos := PackedVector3Array()
var _p_vel := PackedVector3Array()
var _p_life := PackedFloat32Array()
# pose overrides on top of the walking animation
var _arm := 0.0
var _shake := 0.0
var _look := 0.0
var _spray := 0.0
var _bird := 0.0
var _cur_z := -2.5
var _prev := Vector2(X_IN, -2.5)
var _wall_stand := -2.5
var _hand_dx := 0.3
var _hand_dz := -0.4
var _last_phase := 0
var _rattle_t := 0.0
# the graffiti
var _gvp: SubViewport
var _gclip: Control
var _gpage: Control
var _font: SystemFont
var _fs := 250
var _base_y := roundi(GH * 0.7)
var _drips: Array[Dictionary] = []
var _drip_t0 := PackedFloat32Array()
var _g_w := 2.4
var _g_x := 0.55
var _reveal := -INF
var _reveal_px := 0.0
var _paint_t := 0.0
# sound
var _song: AudioStreamPlayer
var _hiss: AudioStreamPlayer
var _hum: AudioStreamPlayer
var _song_on := false
var _hiss_g := 0.0
var _gain := 0.55
var _step_s: Dictionary
var _rattle_s: Dictionary


class Layer:
	extends Control
	var fn: Callable
	func _draw() -> void:
		fn.call(self)


func _ready() -> void:
	layer = 100
	var rect := TextureRect.new()
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.world_3d = World3D.new()
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.audio_listener_enable_3d = false
	_vp.gui_disable_input = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.size = get_viewport().get_visible_rect().size
	add_child(_vp)
	rect.texture = _vp.get_texture()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(rect)
	_build_scene()
	_build_graffiti()
	_build_sound()
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)
	_hint = CrtTheme.label("PRESS ANY KEY TO SKIP", &"sys", 11, Color("8d97a6"), 2)
	_hint.anchor_left = 1.0
	_hint.anchor_right = 1.0
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_left = -240.0
	_hint.offset_right = -22.0
	_hint.offset_top = -30.0
	_hint.offset_bottom = -16.0
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.modulate.a = 0.0
	add_child(_hint)
	_calibrate()


static func _lam(c: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.hex((c << 8) | 0xff)
	m.roughness = 1.0
	m.metallic_specular = 0.0
	return m


## JS's canvas: bricks and speckle (its own seed, so the same wall)
static func _wall_tex() -> ImageTexture:
	var img := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	img.fill(Color("#1d2027"))
	var s := 7
	var rnd := func() -> float:
		s = (s * 16807) % 2147483647
		return float(s) / 2147483647.0
	var hsl := func(h: float, sa: float, l: float) -> Color:
		var c: float = (1.0 - absf(2.0 * l - 1.0)) * sa
		var hp: float = h / 60.0
		var x: float = c * (1.0 - absf(fmod(hp, 2.0) - 1.0))
		var m: float = l - c / 2.0
		var rgb := Vector3(c, x, 0.0)
		if hp >= 4.0 and hp < 5.0:
			rgb = Vector3(x, 0.0, c)
		elif hp >= 3.0 and hp < 4.0:
			rgb = Vector3(0.0, x, c)
		return Color(rgb.x + m, rgb.y + m, rgb.z + m)
	var bw := 64
	var bh := 64
	for r in 8:
		for i in range(-1, 9):
			var x: int = i * bw + (bw / 2 if r % 2 == 1 else 0)
			var y: int = r * bh
			var l: float = 34.0 + rnd.call() * 14.0
			var h: float = 215.0 + rnd.call() * 14.0
			var sa: float = 8.0 + rnd.call() * 8.0
			img.fill_rect(Rect2i(x + 2, y + 2, bw - 4, bh - 4), hsl.call(h, sa / 100.0, l * 0.7 / 100.0))
	for i in 2600:
		var dark: bool = rnd.call() < 0.5
		var a: float = 0.03 + rnd.call() * 0.05
		var x: int = int(rnd.call() * 512.0)
		var y: int = int(rnd.call() * 512.0)
		var w: int = 1 + int(rnd.call() * 2.0)
		var h: int = 1 + int(rnd.call() * 2.0)
		var over := Color(0, 0, 0) if dark else Color(1, 1, 1)
		for yy in range(y, mini(512, y + h)):
			for xx in range(x, mini(512, x + w)):
				img.set_pixel(xx, yy, img.get_pixel(xx, yy).lerp(over, a))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _mesh(par: Node3D, m: Mesh, mat: Material, p: Vector3 = Vector3.ZERO, shadow: bool = true) -> MeshInstance3D:
	var o := MeshInstance3D.new()
	o.mesh = m
	o.material_override = mat
	o.position = p
	o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	par.add_child(o)
	return o


func _build_scene() -> void:
	var root := Node3D.new()
	_vp.add_child(root)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.hex(0x05070cff)
	env.fog_enabled = true      # scene.fog = new Fog(0x05070c, 9, 22)
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color.hex(0x05070cff)
	env.fog_depth_begin = 9.0
	env.fog_depth_end = 22.0
	env.fog_depth_curve = 1.0
	# HemisphereLight(0x7a90c8, 0x1c1a24, 1.5), as the View makes one (View.HEMI_SKY_SHADER says how)
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = View.HEMI_SKY_SHADER
	sm.shader = sh
	var a := Color.hex(0x7a90c8ff).srgb_to_linear()
	var b := Color.hex(0x1c1a24ff).srgb_to_linear()
	var k := 1.0 / (PI * (1.0 - 2.0 * View.HEMI_LEAK) * 1.5)
	var s_ := Vector3(a.r, a.g, a.b)
	var g_ := Vector3(b.r, b.g, b.b)
	sm.set_shader_parameter(&"sky_color", (s_ * (1.0 - View.HEMI_LEAK) - g_ * View.HEMI_LEAK).max(Vector3.ZERO) * k)
	sm.set_shader_parameter(&"ground_color", (g_ * (1.0 - View.HEMI_LEAK) - s_ * View.HEMI_LEAK).max(Vector3.ZERO) * k)
	var sky := Sky.new()
	sky.sky_material = sm
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env.sky = sky
	env.background_energy_multiplier = 1.5
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	_cam = Camera3D.new()
	_cam.near = 0.1
	_cam.far = 60.0
	_cam.fov = 36.0
	_cam.current = true
	root.add_child(_cam)
	_cam.position = CAM_A
	_cam.look_at(CAM_LOOK)
	var key := SpotLight3D.new()      # SpotLight(0xffc27a, 46, 0, 0.95, 0.85, 2)
	key.light_color = Color.hex(0xffc27aff)
	key.light_energy = 46.0 / PI
	key.spot_range = 40.0
	key.spot_attenuation = 2.0
	key.spot_angle = rad_to_deg(0.95)
	key.spot_angle_attenuation = 0.6
	key.shadow_enabled = true
	key.position = Vector3(-1.9, 3.5, 0.6)
	root.add_child(key)
	key.look_at(Vector3(0.4, 0.9, WALL_Z))
	var rim := DirectionalLight3D.new()
	rim.light_color = Color.hex(0x6f9bffff)
	rim.light_energy = 1.4 / PI
	root.add_child(rim)
	rim.look_at_from_position(Vector3(4.0, 2.5, -1.0), Vector3.ZERO)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color.hex(0xffe0b0ff)
	fill.light_energy = 0.45 / PI
	root.add_child(fill)
	fill.look_at_from_position(Vector3(3.0, 1.5, 5.0), Vector3.ZERO)
	# brick wall
	var wm := _lam(0xffffff)
	wm.albedo_texture = _wall_tex()
	wm.uv1_scale = Vector3(4.6, 2.2, 1.0)
	var wq := QuadMesh.new()
	wq.size = Vector2(14.0, 5.6)
	_mesh(root, wq, wm, Vector3(0.5, 2.8, WALL_Z), false)
	var gr := PlaneMesh.new()
	gr.size = Vector2(40.0, 30.0)
	_mesh(root, gr, _lam(0x3a3e49), Vector3.ZERO, false)
	var curb := BoxMesh.new()
	curb.size = Vector3(14.0, 0.12, 0.25)
	_mesh(root, curb, _lam(0x3b3f49), Vector3(0.5, 0.06, WALL_Z + 0.13))
	# a couple of crates against the wall on the left, and a lamp so the light has a source
	for c: Array in [[-2.6, 0.55, 0.5], [-2.0, 0.45, 0.4], [-2.3, 0.4, 0.38]]:
		var bx := BoxMesh.new()
		bx.size = Vector3(c[1], c[2], 0.3)
		_mesh(root, bx, _lam(0x5a4630), Vector3(c[0], float(c[2]) / 2.0 + (0.5 if float(c[0]) == -2.3 else 0.0), WALL_Z + 0.2))
	var lamp := Node3D.new()
	lamp.position = Vector3(-2.55, 0.0, WALL_Z + 0.5)
	root.add_child(lamp)
	_mesh(lamp, Goggles.cyl_mesh(0.04, 0.05, 3.5, 8), _lam(0x15171c), Vector3(0.0, 1.75, 0.0))
	var arm := BoxMesh.new()
	arm.size = Vector3(0.7, 0.05, 0.05)
	_mesh(lamp, arm, _lam(0x15171c), Vector3(0.3, 3.5, 0.0))
	var bulb := SphereMesh.new()
	bulb.radius = 0.11
	bulb.height = 0.22
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.albedo_color = Color.hex(0xffd9a0ff)
	_mesh(lamp, bulb, bm, Vector3(0.62, 3.42, 0.0), false)
	# ---- Tommy ----
	var B := Builds.character_build("tommy")
	_an = Animator.new((load(B.file) as PackedScene).instantiate(), B)
	root.add_child(_an.actor)
	_p = Player.new(null)
	_p.x = X_IN
	_p.y = 0.0
	_p.z = -2.5
	_p.yaw = PI / 2.0
	_p.grounded = true
	_p.flip = -1.0
	_p.mode = &"normal"
	_an.pose_hook = _pose_hook
	# can + overspray
	_can = Node3D.new()
	root.add_child(_can)
	_mesh(_can, Goggles.cyl_mesh(0.03, 0.03, 0.14, 12), _lam(0xb9bec8))
	_mesh(_can, Goggles.cyl_mesh(0.0305, 0.0305, 0.045, 12), _lam(0xe8222a), Vector3(0.0, -0.01, 0.0))
	_mesh(_can, Goggles.cyl_mesh(0.022, 0.03, 0.04, 12), _lam(0x14161b), Vector3(0.0, 0.09, 0.0))
	_nozzle = Node3D.new()
	_nozzle.position.y = 0.115
	_can.add_child(_nozzle)
	_can.visible = false
	# a raised finger on the right fist (his hands are mitts), placed along the forearm -> hand direction each frame
	var skin := Color.hex(0xd4a374ff)
	var sk: Variant = _an.get(&"_skin_mesh")
	if sk != null and _an._skin_surf >= 0:
		var sm2: Material = (sk as MeshInstance3D).get_active_material(_an._skin_surf)
		if sm2 is StandardMaterial3D:
			skin = (sm2 as StandardMaterial3D).albedo_color
	var fm := StandardMaterial3D.new()
	fm.albedo_color = skin
	fm.roughness = 1.0
	fm.metallic_specular = 0.0
	var cap := CapsuleMesh.new()
	cap.radius = 0.017
	cap.height = 0.15 + 0.034
	_finger = _mesh(root, cap, fm)
	_finger.visible = false
	var kn := SphereMesh.new()
	kn.radius = 0.026
	kn.height = 0.052
	for i in 2:
		var o := _mesh(root, kn, fm)
		o.visible = false
		_knuckles.append(o)
	# the mist (JS Points: square, 0.045 m)
	var q := QuadMesh.new()
	q.size = Vector2(0.045, 0.045)
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.albedo_color = Color(Color.hex(0xff3a3aff), 0.6)
	mm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mm.billboard_keep_scale = true
	q.material = mm
	_mist = MultiMesh.new()
	_mist.transform_format = MultiMesh.TRANSFORM_3D
	_mist.mesh = q
	_mist.instance_count = NP
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = _mist
	mi.custom_aabb = AABB(Vector3(-20, -60, -20), Vector3(40, 80, 40))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	_p_pos.resize(NP)
	_p_vel.resize(NP)
	_p_life.resize(NP)
	for i in NP:
		_p_pos[i] = Vector3(0.0, -50.0, 0.0)
		_p_life[i] = 0.0


## pose overrides on top of the walking animation
func _set_k(a: Animator, k: StringName, v: Vector3, m: float) -> void:
	var i := Animator.KEYS.find(k)
	if i >= 0:
		a.pose[i] = (a.pose[i] as Vector3).lerp(v, m)


func _pose_hook(a: Animator) -> void:
	var w := _arm
	var sh := _shake * sin(t * 38.0) * 0.09      # rattling the can
	var sc := _spray * sin(t * 6.5) * 0.1      # the little up-down of the spray arm
	_set_k(a, &"upper_armL", Vector3(-1.38 + sc + sh, 0.0, 0.22), w)
	_set_k(a, &"forearmL", Vector3(-0.5 + sh * 1.4, 0.0, 0.0), w)
	_set_k(a, &"handL", Vector3(-0.1, 0.0, 0.0), w)
	# the finger: right arm up in front of him, fist raised, with a little jab
	var b := _bird
	if b > 0.001:
		var jab := sin((t - BIRD_A) * 7.5) * 0.09 * b
		_set_k(a, &"upper_armR", Vector3(-1.2 + jab, 0.0, -0.1), b)
		_set_k(a, &"forearmR", Vector3(-1.45 - jab * 1.5, 0.0, 0.0), b)
		_set_k(a, &"handR", Vector3(-0.2, 0.0, 0.0), b)
		Cutscene.add_pose(a, &"spine2", -0.05 * b, 0.0, 0.0)
	# lean into the wall a touch while spraying
	Cutscene.add_pose(a, &"spine2", 0.12 * _spray, 0.0, 0.0)
	Cutscene.add_pose(a, &"head", -0.18 * _spray, _look * sin(t * 0.9) * 0.15, _look * 0.12)


# ---- graffiti (drawn on a page that follows the hand). ENGINE DIFFERENCE: canvas shadowBlur is a set of wide outlines.
func _build_graffiti() -> void:
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Permanent Marker", "Segoe Print", "Ink Free", "Marker Felt", "Comic Sans MS", "Chalkboard SE"])
	_font.font_weight = 700
	_fs = 250
	_fs = int(floorf(_fs * minf(1.0, (GW * 0.9) / _font.get_string_size(TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs).x)))
	_gvp = SubViewport.new()
	_gvp.size = Vector2i(GW, GH)
	_gvp.disable_3d = true
	_gvp.transparent_bg = true
	_gvp.gui_disable_input = true
	_gvp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_gvp)
	var page := Layer.new()
	page.size = Vector2(GW, GH)
	page.fn = _draw_drips
	_gvp.add_child(page)
	_gpage = page
	var clip := Layer.new()
	clip.size = Vector2(0.0, GH)
	clip.clip_contents = true
	clip.fn = _draw_text
	page.add_child(clip)
	_gclip = clip
	# drips: start at the lowest painted line of random columns. (The JS reads the rendered text's pixels; here the text is drawn into a throwaway image the moment the page has rendered.)
	var s := 11
	var rnd := func() -> float:
		s = (s * 16807) % 2147483647
		return float(s) / 2147483647.0
	for n in 34:
		var x := int(floorf(30.0 + rnd.call() * (GW - 60)))
		var a: float = rnd.call()
		var b: float = rnd.call()
		_drips.append({"x": x, "y0": float(_base_y) - 6.0, "len": 16.0 + a * b * 130.0, "speed": 18.0 + rnd.call() * 34.0, "w": 3.0 + rnd.call() * 4.0, "delay": 0.5 + rnd.call() * 1.6})
	_drip_t0.resize(_drips.size())
	_drip_t0.fill(-1.0)


func _draw_text(g: Control) -> void:
	var x := (GW - _font.get_string_size(TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs).x) / 2.0
	var at := Vector2(x, _base_y)
	var glow := Color("#ff2a2a")
	for o: Array in [[52, 0.05], [34, 0.07], [18, 0.1]]:      # overspray halo
		g.draw_string_outline(_font, at, TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs, o[0], Color(glow, o[1]))
	g.draw_string(_font, at, TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs, Color("#e8222a"))
	g.draw_string_outline(_font, at - Vector2(0.0, 2.0), TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs, 3, Color(1.0, 120.0 / 255.0, 110.0 / 255.0, 0.5))


func _draw_drips(g: Control) -> void:
	var red := Color("#e8222a")
	for i in _drips.size():
		var d: Dictionary = _drips[i]
		if float(d.x) > _reveal_px - 8.0:
			continue
		if _drip_t0[i] < 0.0:
			_drip_t0[i] = _paint_t + float(d.delay)
		var gl := clampf((_paint_t - _drip_t0[i]) * float(d.speed), 0.0, d.len)
		if gl <= 0.0:
			continue
		var p0 := Vector2(d.x, d.y0)
		g.draw_line(p0, p0 + Vector2(0.0, gl), red, d.w, true)
		g.draw_circle(p0 + Vector2(0.0, gl), float(d.w) * 0.7, red)


# ---- sound
func _build_sound() -> void:
	_song = AudioStreamPlayer.new()
	_song.stream = load("res://assets/intro/intro.mp3")
	_song.volume_db = linear_to_db(0.4 * _gain)
	add_child(_song)
	var R := FartSynth.R
	var noise_loop := func(hz: float, band: bool) -> AudioStreamWAV:
		var n := R * 2
		var b := PackedByteArray()
		b.resize(n * 2)
		var rng := RandomNumberGenerator.new()
		var y1 := 0.0
		var y2 := 0.0
		var x1 := 0.0
		var x2 := 0.0
		var w := TAU * minf(hz, R * 0.45) / R
		var al := sin(w) / (2.0 * 0.7)
		var a0 := 1.0 + al
		var cw := cos(w)
		for i in n:
			var v := rng.randf() * 2.0 - 1.0
			var y: float
			if band:
				y = (al / a0) * v - (al / a0) * x2 + 2.0 * cw / a0 * y1 - (1.0 - al) / a0 * y2
			else:
				y = ((1.0 - cw) * 0.5 * v + (1.0 - cw) * x1 + (1.0 - cw) * 0.5 * x2) / a0 + 2.0 * cw / a0 * y1 - (1.0 - al) / a0 * y2
			x2 = x1
			x1 = v
			y2 = y1
			y1 = y
			b.encode_s16(i * 2, int(clampf(y, -1.0, 1.0) * 32000.0))
		var s := AudioStreamWAV.new()
		s.format = AudioStreamWAV.FORMAT_16_BITS
		s.mix_rate = R
		s.data = b
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_end = n
		return s
	_hiss = AudioStreamPlayer.new()
	_hiss.stream = noise_loop.call(6500.0, true)
	_hiss.volume_db = -80.0
	add_child(_hiss)
	_hiss.play()
	_hum = AudioStreamPlayer.new()      # quiet night-city rumble
	_hum.stream = noise_loop.call(160.0, false)
	_hum.volume_db = linear_to_db(0.06 * _gain)
	add_child(_hum)
	_hum.play()
	_step_s = CineParts.sound("alley_step", [["n", 0.0, 0.09, {"type": "lowpass", "f0": 165.0, "f1": 165.0, "q": 0.7, "gain": 0.5, "wet": 0.0}]])
	_rattle_s = CineParts.sound("alley_rattle", [["n", 0.0, 0.035, {"type": "bandpass", "f0": 3650.0, "f1": 3650.0, "q": 4.0, "gain": 0.28, "wet": 0.0}]])


## yaw: +x is PI/2, the wall is PI, the viewer is 0
func _pose(tt: float) -> Array:
	var yaw := PI / 2.0
	var x := X_IN
	var strafe := false
	if tt < TURN_A:
		var u := Cutscene.seg(tt, WALK_A, WALK_B)
		x = lerpf(X_IN, X_STOP, 1.0 - pow(1.0 - u, 1.6))
	elif tt < SPRAY_A:
		yaw = lerpf(PI / 2.0, PI, smoothstep(TURN_A, TURN_B, tt))
		x = X_STOP
	elif tt < LOWER_A:
		yaw = PI
		x = lerpf(X_STOP, X_END, Cutscene.seg(tt, SPRAY_A + 0.15, SPRAY_B - 0.1))
		strafe = true
	elif tt < FACE_A:
		yaw = PI
		x = lerpf(X_END, X_FACE, smoothstep(LOWER_A, FACE_B, tt))
	elif tt < BACK_A:
		yaw = lerpf(PI, 0.0, smoothstep(FACE_A, FACE_B, tt))
		x = lerpf(X_END, X_FACE, smoothstep(LOWER_A, FACE_B, tt))
	elif tt < LEAVE_A:
		yaw = lerpf(0.0, PI / 2.0, smoothstep(BACK_A, BACK_B, tt))
		x = X_FACE
	else:
		var u := tt - LEAVE_A
		x = X_FACE + 1.05 * (u - 0.3 * (1.0 - exp(-u / 0.3)))
	return [x, yaw, strafe]


func _hand(key: StringName) -> Vector3:
	return _an.bone_world_pos(_an.by_key[key].bone)


## measure how far the hand reaches from the body, so the text and the stand-off distance match the model
func _calibrate() -> void:
	_p.x = 0.0
	_p.z = -2.5
	_p.yaw = PI
	_p.vx = 0.0
	_p.vz = 0.0
	_p.strafing = false
	_arm = 1.0
	_spray = 0.0
	_shake = 0.0
	for i in 40:
		_an.update(0.016, _p)
	var v := _hand(&"handL")
	_hand_dx = v.x - _p.x
	_hand_dz = v.z - _p.z
	var hand_y := v.y
	# z so the hand sits just off the wall; the painted strip is centred on the hand's sweep
	_wall_stand = WALL_Z + 0.16 - _hand_dz
	_g_x = (X_STOP + X_END) / 2.0 + _hand_dx
	_g_w = maxf(2.2, (X_END - X_STOP) + 0.9)
	var g_y := hand_y - 0.02
	var q := QuadMesh.new()
	q.size = Vector2(_g_w, _g_w * GH / GW)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = _gvp.get_texture()
	_mesh(_cam.get_parent(), q, m, Vector3(_g_x, g_y + 0.02, WALL_Z + 0.012), false)
	_arm = 0.0
	_p.x = X_IN
	_p.z = -2.5
	_p.yaw = PI / 2.0
	_an.phase = 0.0
	_an.cyc = 0.0
	_an.run = 0.0
	for i in 20:
		_an.update(0.016, _p)
	_prev = Vector2(_p.x, _p.z)
	_cur_z = _p.z


func _simulate(dt: float) -> void:
	t += dt
	var o := _pose(t)
	var standoff := _wall_stand if (t > TURN_A - 0.4 and t < FACE_A + 0.2) else -2.5
	_cur_z = lerpf(_cur_z, standoff, 1.0 - exp(-6.0 * dt))
	_p.vx = (float(o[0]) - _prev.x) / dt
	_p.vz = (_cur_z - _prev.y) / dt
	_prev = Vector2(o[0], _cur_z)
	_p.x = o[0]
	_p.z = _cur_z
	_p.yaw = o[1]
	_p.strafing = o[2]
	# can / arm weights
	_arm = smoothstep(SHAKE_A, SHAKE_A + 0.5, t) * (1.0 - smoothstep(LOWER_A, LOWER_B, t))
	_shake = 1.0 if t >= SHAKE_A and t < SPRAY_A else 0.0
	_spray = 1.0 if t >= SPRAY_A and t < LOWER_A else 0.0
	_bird = smoothstep(BIRD_A, BIRD_A + 0.45, t) * (1.0 - smoothstep(BIRD_B - 0.3, BIRD_B, t))
	_look = smoothstep(LOOK_A, LOOK_A + 0.4, t) * (1.0 - smoothstep(LOOK_B - 0.3, LOOK_B, t))
	_an.update(dt, _p)
	# hand -> can, paint, mist
	var hv := _hand(&"handL")
	_can.visible = t >= SHAKE_A - 0.25
	_can.position = hv + Vector3(0.0, lerpf(0.04, 0.0, _arm), lerpf(0.0, -0.05, _arm))
	_can.rotation = Vector3(lerpf(0.0, -PI / 2.0, _arm), 0.0, 0.0)
	var show_f := _bird > 0.5
	_finger.visible = show_f
	for k: MeshInstance3D in _knuckles:
		k.visible = show_f
	if show_f:
		var fp := _hand(&"handR")
		var fd := (fp - _hand(&"forearmR")).normalized().lerp(Vector3.UP, 0.6).normalized()
		_finger.position = fp + fd * 0.12
		_finger.quaternion = Quaternion(Vector3.UP, fd)
		var cx := _cam.global_basis.x
		_knuckles[0].position = fp + fd * 0.035 - cx * 0.034
		_knuckles[1].position = fp + fd * 0.035 + cx * 0.034
	if _spray > 0.0:
		_paint_t += dt
		_reveal = maxf(_reveal, hv.x + 0.05)
		_reveal_px = clampf(((_reveal - (_g_x - _g_w / 2.0)) / _g_w) * GW, 0.0, GW)
		_hiss_g += ((0.16 + 0.05 * randf()) - _hiss_g) * (1.0 - exp(-dt / 0.02))
		_hiss.pitch_scale = (6000.0 + randf() * 1500.0) / 6500.0
	else:
		_hiss_g += (0.0 - _hiss_g) * (1.0 - exp(-dt / 0.04))
	if t > SPRAY_B:
		_reveal_px = GW
		_paint_t += dt
	_gclip.size.x = _reveal_px
	if _reveal_px > 2.0:
		_gclip.queue_redraw()
		_gpage.queue_redraw()
		_gvp.render_target_update_mode = SubViewport.UPDATE_ONCE
	# mist emitter
	var nz := _nozzle.global_position
	for i in NP:
		if _p_life[i] <= 0.0:
			if _spray > 0.0 and randf() < 0.7:
				_p_life[i] = 0.16 + randf() * 0.14
				_p_pos[i] = Vector3(nz.x + (randf() - 0.5) * 0.02, nz.y + (randf() - 0.5) * 0.02, nz.z)
				_p_vel[i] = Vector3((randf() - 0.5) * 0.35, (randf() - 0.5) * 0.35, -(0.8 + randf() * 0.8))
			else:
				_p_pos[i] = Vector3(0.0, -50.0, 0.0)
		else:
			_p_life[i] -= dt
			var p := _p_pos[i] + _p_vel[i] * dt
			p.z = maxf(WALL_Z + 0.02, p.z)
			_p_pos[i] = p
		_mist.set_instance_transform(i, Transform3D(Basis.IDENTITY, _p_pos[i]))
	# sound: footsteps off the gait phase, can rattle
	var ph := int(floorf(_an.phase / PI))
	if ph != _last_phase:
		_last_phase = ph
		if U.hyp(_p.vx, _p.vz) > 0.15:
			Game.sfx.clip(_step_s["s"], {"gain": _gain, "wet": 0.0, "rate": (140.0 + randf() * 50.0) / 165.0})
	if not _song_on and t >= SONG_T0:
		_song_on = true
		_song.play(maxf(0.0, t - SONG_T0))
	if _shake > 0.0:
		_rattle_t -= dt
		if _rattle_t <= 0.0:
			Game.sfx.clip(_rattle_s["s"], {"gain": _gain, "wet": 0.0, "rate": (3200.0 + randf() * 900.0) / 3650.0})
			_rattle_t = 0.045 + randf() * 0.05
	# camera: slow push-in
	_cam.position = CAM_A.lerp(CAM_B, smoothstep(0.0, END_T, t))
	_cam.look_at(CAM_LOOK)
	# fade
	var f := 1.0 - smoothstep(0.0, 1.0, t) + smoothstep(FADE_A, END_T, t)
	if _skipping > 0.0:
		_skipping += dt
		f = maxf(f, clampf(_skipping / 0.35, 0.0, 1.0))
	f = clampf(f, 0.0, 1.0)
	_fade.color.a = f
	_gain = 0.55 * (1.0 - f * 0.9)
	_song.volume_db = linear_to_db(maxf(0.4 * _gain, 1e-5))
	_hum.volume_db = linear_to_db(maxf(0.06 * _gain, 1e-5))
	_hiss.volume_db = linear_to_db(maxf(_hiss_g * _gain, 1e-5))
	_hint.modulate.a = clampf((t - 1.2) / 0.6, 0.0, 1.0)
	if t > END_T or (_skipping > 0.0 and _skipping > 0.4):
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	queue_free()
	if on_done.is_valid():
		on_done.call()


func _process(delta: float) -> void:
	if not _done:
		_simulate(clampf(delta, 0.001, 0.05))


func _input(e: InputEvent) -> void:
	if ((e is InputEventKey and e.pressed and not e.echo) or (e is InputEventMouseButton and e.pressed) or (e is InputEventJoypadButton and e.pressed)) and _skipping == 0.0:
		get_viewport().set_input_as_handled()
		_skipping = 0.0001
