class_name View
extends Node3D
## The picture (JS class View, index.html scene.js): applies the camera each frame (FOV, shake, overrides), owns the sun, the hemisphere light, fog, background, tone mapping and the
## post look (core/post_fx.gd, core/looks.gd), and what a level may change of them. Game.view. Lives for the session; reset_render_state() puts everything back before the next level.
##
## What the JS needed and Godot does not:
##  - LightPool (a constant number of lights so a light switching on never recompiled every shader): Forward+ is clustered, the light count is not part of any shader. Point and spot
##    lights are plain nodes under the level; up to 512 in view, and switching one costs nothing.
##  - singlePassGlow: Godot draws a double-sided transparent in one pass already.
##  - sun-shadow-cache.js: Godot has no static directional shadow cache, and the cascades are redrawn every frame. The JS cache saved ~0.1 ms because its shadow draws were cheap; here the
##    culling and the depth-only draws are native and threaded, and cascades cost GPU, not script time. Numbers in docs/measurements.md.
##  - The sun following the player in texel steps: cascades follow the camera and Godot snaps them to texels itself, so the sun is only a direction. It is the JS's constant one, (30, 50, 20).
##  - Materials patched by material-look.js: soft shadows are light_angular_distance on the sun (contact-hardening PCSS); the sky / ground reflection is core/material_look.gd.

## A camera that is not the rig: what cutscenes, the dialogue, a level's `cine.camera` and `camera_override()` hand to the frame. JS `{ pos, look, fov?, up? }`.
class Shot:
	var pos := Vector3.ZERO
	var look := Vector3.FORWARD
	var fov := 0.0              # 0 = keep the game's FOV logic
	var up := Vector3.ZERO      # zero = world up. A banked view (OMNISPHERE's freefall) sets it
	func _init(p: Vector3 = Vector3.ZERO, l: Vector3 = Vector3.FORWARD, f: float = 0.0) -> void:
		pos = p
		look = l
		fov = f

const MaterialLook := preload("res://core/material_look.gd")
const SUN_POS := Vector3(30.0, 50.0, 20.0)
## Godot's sky ambient reads the last mip of the radiance map, a wide but not exactly cosine blur: a white sky over black ground lights an upward face at 0.965, a sideways face at 0.5 and a
## downward one at 0.035 (measured). Three.js's hemisphere light is exact, so the colours going in are spread by the inverse (set_hemi).
const HEMI_LEAK := 0.035
const TONE_NONE := 0            # three.js NoToneMapping
const TONE_ACES := 1            # three.js ACESFilmicToneMapping
## Which cutscene owns the camera when several are on (the else-if chain at the end of the JS frame). Game.cutscenes[name] = an object with `on` and `camera` (a Shot).
const CUTSCENE_ORDER: Array[StringName] = [&"beatdown", &"balcony_call", &"boss_intro", &"office_shutup", &"shitchan_clap", &"cherub_fart", &"implant_cs", &"frug_showdown", &"tommy_ascension", &"firefight"]

# three.js's ACES output matrix (ACESOutputMat), inverted to find the radiance that lands on a given display colour.
static var _aces_in_inv := Basis(Vector3(0.59719, 0.07600, 0.02840), Vector3(0.35458, 0.90834, 0.13383), Vector3(0.04823, 0.01566, 0.83777)).inverse()
static var _aces_out_inv := Basis(Vector3(1.60475, -0.10208, -0.00327), Vector3(-0.53108, 1.10813, -0.07276), Vector3(-0.07367, -0.00605, 1.07602)).inverse()

const HEMI_SKY_SHADER := """
shader_type sky;
// JS HemisphereLight, as what the sky would have to be for Godot's sky ambient to give the same light: sky colour above, ground colour below. Never drawn: the background is a plain colour.
uniform vec3 sky_color;
uniform vec3 ground_color;
void sky() {
	COLOR = mix(ground_color, sky_color, smoothstep(-0.05, 0.05, EYEDIR.y));
}
"""

var camera: Camera3D = null
var sway := Vector3.ZERO        # the gameplay camera's drunk lurch (pitch, yaw, roll, rad) and drift (camera axes, m): player/drunk.gd sets them every frame
var sway_pos := Vector3.ZERO
var env: Environment = null
var compositor: Compositor = null
var post: PostFx = null
var sun: DirectionalLight3D = null
var sky: Sky = null
var blob: MeshInstance3D = null
var material_look: RefCounted = null   # core/material_look.gd: the sky / ground reflection
var city = null                 # JS view.city: what a city level draws (update(camera_pos, player)), set by that level
var mirror_on := false

# the render state a level may change: JS renderState(view). Colours are display values, intensities are three.js's, as in the level files.
var background := Color.BLACK
var fog_kind := 0               # 0 none, 1 Fog (near, far), 2 FogExp2 (density)
var fog_color := Color.BLACK
var fog_near := 1.0
var fog_far := 1000.0
var fog_density := 0.0
var tone_mapping := TONE_NONE
var exposure := 1.0
var hemi_color := Color.WHITE
var hemi_ground := Color.WHITE
var hemi_intensity := 1.0
var sun_color := Color.WHITE
var sun_intensity := 1.0
var fov_k := 0.0
var res_scale := 1.0            # dynamic resolution, 0.6 .. 1
var dynamic_res := true

var _sky_mat: ShaderMaterial = null
var _blob_mat: StandardMaterial3D = null
var _blob_alpha := -1.0
var _hemi_dirty := true         # the colours changed: the radiance map is redrawn, once, this frame
var _rt := 0                    # usec of the last render
var _ft := 16.0
var _cpu := 8.0
var _dyn_t := 0.0
var _sf := 0.0                  # the last scope FOV, remembered so the zoom-out after unequipping / releasing ADS eases from the right FOV
var _mirror_vp: SubViewport = null
var _mirror_cam: Camera3D = null
var _mirror_box: Control = null


func setup(cam: Camera3D) -> void:
	camera = cam
	post = PostFx.new()
	compositor = Compositor.new()
	compositor.compositor_effects = [post]
	# Environment and compositor sit on the camera: a camera's environment wins over any WorldEnvironment a level still makes
	camera.compositor = compositor
	_sky_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = HEMI_SKY_SHADER
	_sky_mat.shader = sh
	sky = Sky.new()
	sky.sky_material = _sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED   # (core/material_look.gd says why)
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR   # the tone map is in post_fx.gd (the JS frame judges everything after it)
	env.tonemap_exposure = 1.0
	env.tonemap_white = 1.0
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_density = 1.0
	env.fog_sky_affect = 0.0     # (JS: the background is not fogged)
	env.fog_sun_scatter = 0.0
	env.fog_aerial_perspective = 0.0
	env.fog_height_density = 0.0
	camera.environment = env
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	# the JS keeps one 72 m box at 3.3 cm a texel round the player. Four cascades over the same 72 m in front of the camera: finer near, no coarser far, and measured no dearer than two (docs/measurements.md).
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 72.0
	sun.light_angular_distance = 2.0     # material-look.js's penumbra: grows with the gap to the caster (closest to the JS numbers of 0, 1, 2, 3 degrees)
	add_child(sun)
	sun.look_at_from_position(SUN_POS, Vector3.ZERO)
	_make_blob()
	material_look = MaterialLook.new()
	get_tree().node_added.connect(material_look.adapt_node)   # whatever appears gets the JS's reflection, level or not, whoever made it
	reset_render_state()
	post.set_look({})
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	dynamic_res = not Peek.enabled      # (a test on a machine that is busy with other things must not get a different picture)


## The levels whose sun shadow is the lean one (user, 2026-11-11: every level keeps its sun or moon shadow, the ones where it cost the most get it cut down hard).
## Measured at 1080p on a GTX 1660 Ti, the full shadow cost 3 to 11 ms a frame in these (the back alley and the jungle went under 60 fps with it); lean, about a fifth of that, and it looks the same.
const SUN_LEAN_LEVELS: Array[String] = ["worldbackalley", "apartment", "blockout-demo", "jungle-test", "hub"]


## The sun's shadow, full or lean. Full: soft, contact-hardening edges (2 degrees of penumbra), the project's filter, four cascades over 72 m. Lean: a 1 degree penumbra, the low
## filter, two cascades over 40 m. The soft edge search is most of the cost (on its own it was 9 of the back alley's 10.7 ms); past 40 m a level's own fog and dark take over.
func set_sun_lean(on: bool) -> void:
	sun.light_angular_distance = 1.0 if on else 2.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if on else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 40.0 if on else 72.0
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW if on else int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality", 3)) as RenderingServer.ShadowQuality)


# ---- the render state: JS renderState().restore and what level files set ------------------------------------------------------------------------------------

## JS BASE_LOOK.restore(): the look of a fresh View. Every level starts from it (Game.enter_level), the hub's build sets its own.
func reset_render_state() -> void:
	set_clip(0.1, 500.0)
	tone_mapping = TONE_NONE
	exposure = 1.0
	_push_tone()
	set_background(Color.hex(0x86b9efff))
	set_fog(Color.hex(0x9cc6f2ff), 70.0, 230.0)
	set_hemi(Color.hex(0xdcecffff), Color.hex(0x6d6a5cff), 1.15)
	set_sun(Color.hex(0xfff1d6ff), 1.9)
	sun.visible = true
	sun.shadow_enabled = true
	set_sun_lean(false)
	city = null
	camera.fov = Config.fov


## After a level's build (JS enterLevel): its look. Called by Game.enter_level.
func level_built(lv: Level) -> void:
	var own: Variant = lv.get(&"look")
	apply_look(own if own is Dictionary else Looks.get_look(lv.id))
	# The arena still makes the stand-in sun it had before this View existed. In the JS it is lit by view.sun alone: a shadow-casting sun of a level's own is a stray that would double the sun.
	if sun_intensity > 0.0:
		for c: Node in lv.get_children():
			if c is DirectionalLight3D and c.shadow_enabled:
				c.visible = false


## A level's whole render state as data (what its mount sets in the JS): any key not named stays as it is. For the exporter.
## {"background": Color, "fog": null | [Color, near, far] | [Color, density], "tone_mapping": View.TONE_*, "exposure": float, "hemi": [Color, Color, intensity], "sun": [Color, intensity], "sun_cast": bool, "sun_lean": bool, "clip": [near, far]}
func apply_render_state(d: Dictionary) -> void:
	if d.has("tone_mapping") or d.has("exposure"):
		set_tone_mapping(d.get("tone_mapping", tone_mapping), d.get("exposure", exposure))
	if d.has("background"):
		set_background(d.background)
	if d.has("fog"):
		var f: Variant = d.fog
		if f == null:
			clear_fog()
		elif f.size() == 3:
			set_fog(f[0], f[1], f[2])
		else:
			set_fog_exp2(f[0], f[1])
	if d.has("hemi"):
		set_hemi(d.hemi[0], d.hemi[1], d.hemi[2])
	if d.has("sun"):
		set_sun(d.sun[0], d.sun[1])
	if d.has("sun_cast"):
		sun.shadow_enabled = d.sun_cast
	if d.has("sun_lean"):
		set_sun_lean(d.sun_lean)
	if d.has("clip"):
		set_clip(d.clip[0], d.clip[1])


func set_clip(near: float, far: float) -> void:
	camera.near = near
	camera.far = far


## JS renderer.toneMapping / toneMappingExposure. Background and fog are given in display colours (three.js draws them after the tone map), so they follow.
func set_tone_mapping(mode: int, exp_: float = 1.0) -> void:
	tone_mapping = mode
	exposure = exp_
	_push_tone()
	_push_fog()


func _push_tone() -> void:
	RenderingServer.global_shader_parameter_set(&"prog_exposure", exposure)
	RenderingServer.global_shader_parameter_set(&"prog_tone_on", 0.0 if tone_mapping == TONE_NONE else 1.0)
	post.tone_mapping = tone_mapping
	post.exposure = exposure


## JS scene.background = new Color(...)
func set_background(c: Color) -> void:
	background = c
	# BG_COLOR is scaled by background_energy_multiplier (which carries the hemisphere intensity) on the sRGB value. With fog on, Godot draws the clear colour through its sky pass instead: there
	# it goes to linear twice and is scaled again in linear. All measured; undone here so the pixel is what three.js clears to.
	var t := display_to_radiance(c)
	var e := env.background_energy_multiplier
	var v := Color(t.r / e, t.g / e, t.b / e).linear_to_srgb().linear_to_srgb() if fog_kind != 0 else t.linear_to_srgb()
	env.background_color = Color(v.r / e, v.g / e, v.b / e)


## JS scene.fog = new Fog(color, near, far)
func set_fog(c: Color, near: float, far: float) -> void:
	fog_kind = 1
	fog_color = c
	fog_near = near
	fog_far = far
	_push_fog()


## JS scene.fog = new FogExp2(color, density)
func set_fog_exp2(c: Color, density: float) -> void:
	fog_kind = 2
	fog_color = c
	fog_density = density
	_push_fog()


## JS scene.fog = null
func clear_fog() -> void:
	fog_kind = 0
	_push_fog()


func _push_fog() -> void:
	env.fog_enabled = fog_kind != 0
	post.has_fog = fog_kind != 0
	set_background(background)
	if fog_kind == 0:
		return
	post.fog_color = fog_color.srgb_to_linear()
	env.fog_light_color = display_to_radiance(fog_color).linear_to_srgb()
	env.fog_light_energy = 1.0
	env.fog_depth_curve = _fog_curve()
	if fog_kind == 1:
		env.fog_depth_begin = fog_near
		env.fog_depth_end = fog_far
	else:
		# FogExp2 is 1 - exp(-(d * density)^2). Godot's depth fog is a smoothstep(begin, end, d)^curve; end = 1.8 / density stays within 0.05 of it over the whole range.
		env.fog_depth_begin = 0.0
		env.fog_depth_end = 1.8 / maxf(fog_density, 0.000001)


## three.js mixes fog into the finished display value, Godot mixes radiance before the tone map. Same amount of fog, different picture: dark things against a bright fog go pale much sooner here.
## Godot's curve is a pow on the amount, so it is chosen to give the three.js result half way into the fog, for the kind of surface the difference shows on: a dark one against a pale fog, a lit one
## (a sign, a lamp) against a dark fog. What is close to the fog's own colour hardly depends on it.
func _fog_curve() -> float:
	var f := (fog_color.r + fog_color.g + fog_color.b) / 3.0
	var d := 0.7 if f < 0.3 else 0.125
	var t := (f + d) * 0.5
	var rf := display_to_radiance(Color(f, f, f)).g
	var rd := display_to_radiance(Color(d, d, d)).g
	var rt := display_to_radiance(Color(t, t, t)).g
	if absf(rf - rd) < 0.0005:
		return 1.0
	return clampf(log(clampf((rt - rd) / (rf - rd), 0.05, 0.95)) / log(0.5), 0.4, 3.0)


## JS view.hemi: sky colour, ground colour, three.js intensity. An intensity-only change (lightning) costs nothing; a colour change redraws the radiance map once.
func set_hemi(c: Color, ground: Color, intensity: float) -> void:
	if c != hemi_color or ground != hemi_ground:
		_hemi_dirty = true
	hemi_color = c
	hemi_ground = ground
	hemi_intensity = intensity
	env.background_energy_multiplier = maxf(intensity, 0.0001)
	set_background(background)
	var a := c.srgb_to_linear()
	var b := ground.srgb_to_linear()
	material_look.set_hemi(Vector3(a.r, a.g, a.b) * intensity, Vector3(b.r, b.g, b.b) * intensity)


## The radiance map holds the colours at intensity 1 (the energy multiplier is the intensity, and Godot multiplies by it on the way in as well as on the way out: the uniform undoes the first).
## Called at the frame end so a colour and an intensity set in one frame are drawn together.
func _flush_hemi() -> void:
	_hemi_dirty = false
	var a := hemi_color.srgb_to_linear()
	var b := hemi_ground.srgb_to_linear()
	var k := 1.0 / (PI * (1.0 - 2.0 * HEMI_LEAK) * env.background_energy_multiplier)
	var s_ := Vector3(a.r, a.g, a.b)
	var g_ := Vector3(b.r, b.g, b.b)
	_sky_mat.set_shader_parameter(&"sky_color", (s_ * (1.0 - HEMI_LEAK) - g_ * HEMI_LEAK).max(Vector3.ZERO) * k)
	_sky_mat.set_shader_parameter(&"ground_color", (g_ * (1.0 - HEMI_LEAK) - s_ * HEMI_LEAK).max(Vector3.ZERO) * k)


## JS view.sun.color / .intensity (three.js units: Godot's energy 1 is three's pi).
func set_sun(c: Color, intensity: float) -> void:
	sun_color = c
	sun_intensity = intensity
	sun.light_color = c
	sun.light_energy = intensity / PI


## The HDR radiance that the current tone map turns into this display colour (for what three.js draws untouched by the tone map: the background, fog, `toneMapped: false` materials).
## Returned as a linear Color.
func display_to_radiance(c: Color) -> Color:
	var l := c.srgb_to_linear()
	if tone_mapping == TONE_NONE:
		return l
	var v: Vector3 = _aces_out_inv * Vector3(l.r, l.g, l.b)
	v = Vector3(_rrt_inverse(v.x), _rrt_inverse(v.y), _rrt_inverse(v.z))
	v = _aces_in_inv * v
	v *= 0.6 / exposure
	return Color(maxf(v.x, 0.0), maxf(v.y, 0.0), maxf(v.z, 0.0))


static func _rrt_inverse(y: float) -> float:
	y = clampf(y, 0.0, 1.0)
	var a := 1.0 - 0.983729 * y
	var b := 0.0245786 - 0.4329510 * y
	var d := 0.000090537 + 0.238081 * y
	return (-b + sqrt(b * b + 4.0 * a * d)) / (2.0 * a)


# ---- the look -----------------------------------------------------------------------------------------------------------------------------------------------

## Replace the look (Looks.get_look(id), or a level's own): anything not named falls back to LOOK_BASE. JS view.post.setLook. Free at any moment, so a level may call it for a zone.
func apply_look(l: Dictionary) -> void:
	post.set_look(l)


## (the name the JS console and levels know it by)
func set_look(l: Dictionary) -> void:
	apply_look(l)


## `look set <key> <value...>`: a number, or an Array for a colour.
func look_set(key: String, value: Variant) -> String:
	if not Looks.LOOK_BASE.has(key):
		return "No such value. Try: " + ", ".join(PackedStringArray(Looks.LOOK_BASE.keys()))
	post.tweak({key: value})
	return "%s = %s" % [key, str(post.look[key])]


## `look off` / `look on`: the bare frame the materials drew, and back.
func look_enable(on: bool) -> String:
	post.look_enabled = on
	post.apply()
	return "Look " + ("ON" if on else "OFF")


func look_off() -> String:
	return look_enable(false)


func look_on() -> String:
	return look_enable(true)


## `look <level id>`: wear another level's look.
func look_wear(id: String) -> String:
	if not Looks.LOOKS.has(id):
		return "Unknown look. Try: " + ", ".join(PackedStringArray(Looks.LOOKS.keys()))
	post.set_look(Looks.LOOKS[id])
	return "Wearing the look of " + id


## `look debug ao|bloom|depth|off`
func look_debug(what: String) -> String:
	post.debug = {"ao": 1, "bloom": 2, "depth": 3}.get(what, 0)
	post.apply()
	return "Debug view: " + what


## `look dump`: what differs from the base, to paste into core/looks.gd.
func look_dump() -> String:
	var d := {}
	for k: String in post.look:
		if not is_same(post.look[k], Looks.LOOK_BASE[k]) and str(post.look[k]) != str(Looks.LOOK_BASE[k]):
			d[k] = post.look[k]
	var s := var_to_str(d)
	print(s)
	return s


func look_status() -> String:
	var sz := Vector2i(get_viewport().get_visible_rect().size)
	return "look %s%s, %dx%d, %.1f MB of targets" % ["on" if post.look_enabled else "off", " (contact shadows shed: GPU limited)" if post.ao_shed else "", sz.x, sz.y, post.memory_mb(sz)]


## The console command in one function: args as typed after `look`. JS devtools/commands.js.
func look_command(a: PackedStringArray) -> String:
	if a.is_empty():
		return look_status()
	var cmd := a[0]
	match cmd:
		"on":
			return look_on()
		"off":
			return look_off()
		"debug":
			return look_debug(a[1] if a.size() > 1 else "off")
		"dump":
			return look_dump()
		"set":
			if a.size() < 3:
				return "usage: look set <key> <number...>"
			var v: Array = []
			for i in range(2, a.size()):
				if not a[i].is_valid_float():
					return "usage: look set <key> <number...>"
				v.append(a[i].to_float())
			var base: Variant = Looks.LOOK_BASE.get(a[1], 0.0)
			return look_set(a[1], v if (base is Array or base == null) else v[0])
	return look_wear(cmd)


# ---- the frame end: which camera, then the draw ------------------------------------------------------------------------------------------------------------

## The end of the JS frame (index.html ~14425): cutscene cameras, level.cine.camera, a level's camera override and the dialogue's, in that game's order. Called last every frame.
##  - level.cine: an object with `on`, `camera` (Shot), `play`
##  - level.camera_override(rig, player, real_dt) -> Shot or null: a level's own view while it is played normally (VISITING HOURS' tunnel camera). The rig keeps running underneath.
##  - Game.dialogue: `on`, `camera()` -> Shot. Game.cutscenes[name]: `on`, `camera`. Game.freecam: `on`, `update(dt)`, `camera`. Game.forge: `is_open`, `monitor.camera` (it updates as one of Game.menus). Game.arena_tv: `camera`, `render()`.
##  - Game.menu_cam: Callable(now_ms) -> Shot while the game has not started. Game.night_vision: `amplify(view, dt)` -> bool, `restore(view)`.
func apply_camera(real_dt: float) -> void:
	if _hemi_dirty:
		_flush_hemi()
	var G := Game
	var started: bool = G.started
	var player: Player = G.player
	var rig: CameraRig = G.rig
	if player == null or rig == null:
		return
	var cam_v: RefCounted = rig
	if not started:
		if G.menu_cam.is_valid():
			cam_v = G.menu_cam.call(Time.get_ticks_msec())
	elif G.arena_tv != null and G.arena_tv.camera != null:
		cam_v = G.arena_tv.camera
	var cine_on := _cine_on()
	var lv: Level = G.level
	var lv_cine: Variant = lv.get(&"cine") if lv != null else null
	var level_cine: bool = lv_cine != null and lv_cine.on
	var dlg_on: bool = G.dialogue != null and G.dialogue.on
	# a level's own view while it is played normally: the rig keeps running underneath (aim, movement direction); the level may steer rig.yaw to keep them in step with the view
	var lv_cam: RefCounted = null
	if not level_cine and started and not dlg_on and lv != null and lv.has_method(&"camera_override"):
		lv_cam = lv.call(&"camera_override", rig, player, real_dt)
	if level_cine:
		cam_v = lv_cine.camera
	elif lv_cam != null:
		cam_v = lv_cam
	elif dlg_on:
		cam_v = G.dialogue.camera()
	elif cine_on:
		for k: StringName in CUTSCENE_ORDER:
			var cs: Variant = G.cutscenes.get(k)
			if cs != null and cs.on:
				cam_v = cs.camera
				break
	if G.freecam != null and G.freecam.on and started:     # dev console "freecam": the fly camera owns the view, the game is held still
		G.freecam.update(real_dt)
		cam_v = G.freecam.camera
	if G.forge != null and G.forge.is_open and started:     # FORGE (the level editor): the Monitor camera owns the view while it edits
		cam_v = G.forge.monitor.camera
	var nv_amp: bool = G.night_vision != null and started and G.night_vision.amplify(self, real_dt)   # light amplification for this frame's render, undone right after
	var quiet: bool = dlg_on or cine_on or (level_cine and not lv_cine.play)
	var fx: Variant = G.fx
	var shake: float = 0.0 if (quiet or fx == null) else fx.shake
	var vshake: float = 0.0 if (quiet or fx == null) else fx.vertical_shake_y
	# (JS: the world is not redrawn behind an opaque menu. Godot draws 3D and 2D into one viewport, so it stays drawn; the wobble stops as it would on the held frame.)
	if G.menu_open():
		shake = 0.0
		vshake = 0.0
	render(cam_v, player, shake, vshake)
	if lv != null:
		lv.camera_placed(camera.global_position, real_dt)
	if nv_amp:
		G.night_vision.restore(self)
	if G.arena_tv != null:
		G.arena_tv.render()


func _cine_on() -> bool:
	if Game.cutscenes.is_empty():
		return false
	for k: StringName in CUTSCENE_ORDER:
		var cs: Variant = Game.cutscenes.get(k)
		if cs != null and cs.on:
			return true
	return false


## JS View.render: FOV, camera, shake, blob, and what was per-draw work. cam is the rig or a Shot.
func render(cam: RefCounted, player: Player, shake: float = 0.0, vertical_shake: float = 0.0) -> void:
	var c := camera
	var now_t := Time.get_ticks_usec()
	var rdt := clampf(float(now_t - _rt) / 1000000.0, 0.0, 0.1) if _rt != 0 else 0.0
	_rt = now_t
	_dynamic_resolution(rdt)
	var rig_v := cam as CameraRig
	var shot := cam as Shot
	var pull_w := rig_v.pull_w if rig_v != null else 0.0
	var pull_eff := rig_v.pull_eff if rig_v != null else 0.0
	var pull_fov := rig_v.pull_fov if rig_v != null else 0.0
	var scw := rig_v.scope_w if rig_v != null else 0.0
	var tgt := 0.0
	if player.sprinting:
		tgt = Config.sprint_fov
	elif player.ads:
		tgt = -Config.ads_fov_cut * (1.0 - 0.55 * pull_w)
	elif player.aiming and not (pull_eff > 0.02):
		tgt = -Config.aim_fov_cut * (1.0 - 0.55 * pull_w)
	fov_k = U.damp(fov_k, tgt, 6.5, rdt)
	if player.scope_fov != 0.0:
		_sf = player.scope_fov          # remembered so the zoom-out after unequipping / releasing ADS eases from the right FOV
	var fov: float = shot.fov if (shot != null and shot.fov != 0.0) else lerpf(Config.fov + fov_k + pull_eff * pull_fov + pull_w * (1.0 - pull_eff) * pull_fov * 0.5, _sf if _sf != 0.0 else Config.fov, clampf(scw, 0.0, 1.0))   # scope zoom
	if shot == null and rig_v != null and rig_v.fov != 0.0:      # the driving camera (vehicles/vehicles.gd)
		fov += rig_v.fov - Config.fov
	if shot == null and rig_v != null:
		fov += rig_v.fov_add
	if absf(c.fov - fov) > 0.01:
		c.fov = fov
	var p: Vector3 = rig_v.pos if rig_v != null else shot.pos
	var look: Vector3 = rig_v.look if rig_v != null else shot.look
	if shake > 0.001:                   # smooth, low-frequency wobble (not per-frame white noise), scaled by Config.cam_shake
		var t := float(now_t) * 0.000001
		var a := shake * Config.cam_shake * 0.2
		p.x += (sin(t * 47.3) + sin(t * 31.7 + 1.3)) * 0.5 * a
		p.y += (sin(t * 53.1 + 0.7) + sin(t * 27.9 + 2.9)) * 0.5 * a
		p.z += (sin(t * 41.9 + 2.1) + sin(t * 33.3 + 0.4)) * 0.5 * a
	var xf: Transform3D
	if Config.first_person and rig_v != null:      # dev-menu first-person: eye at the head, look along yaw / pitch
		var cp := cos(rig_v.pitch)
		var fx := -sin(rig_v.yaw) * cp
		var fz := -cos(rig_v.yaw) * cp
		var fy := sin(rig_v.pitch)
		p = Vector3(player.x - fx * 0.3, player.y + 1.6, player.z - fz * 0.3)
		xf = _look_at(p, Vector3(p.x - fx, p.y - fy, p.z - fz), Vector3.UP)
	else:
		xf = _look_at(p, look, shot.up if (shot != null and shot.up != Vector3.ZERO) else Vector3.UP)   # shot.up: a banked view (OMNISPHERE's freefall)
	xf.origin.y += vertical_shake * Config.cam_shake
	if rig_v != null and (sway != Vector3.ZERO or sway_pos != Vector3.ZERO):      # Prog drunk (player/drunk.gd): the view lurches with him, in the camera's own axes
		xf.origin += xf.basis * sway_pos
		xf.basis = xf.basis * Basis.from_euler(sway, EULER_ORDER_YXZ)
	c.global_transform = xf
	# (the sun follows the player in the JS only to keep its one shadow box around them: Godot's cascades follow the camera)
	_update_blob(player)
	if city != null:
		city.update(xf.origin, player)
	if mirror_on:
		_render_mirror(player)


## three.js Matrix4.lookAt, with its fallbacks (eye on the target, up along the view): a camera never fails to aim.
static func _look_at(eye: Vector3, target: Vector3, up: Vector3) -> Transform3D:
	var z := eye - target
	if z.length_squared() == 0.0:
		z.z = 1.0
	z = z.normalized()
	var x := up.cross(z)
	if x.length_squared() == 0.0:
		if absf(up.z) == 1.0:
			z.x += 0.0001
		else:
			z.z += 0.0001
		z = z.normalized()
		x = up.cross(z)
	x = x.normalized()
	return Transform3D(Basis(x, z.cross(x), z), eye)


func _make_blob() -> void:
	# blob shadow stays readable even outside the shadow frustum
	var v := PackedVector3Array()
	var n := 20
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		v.append(Vector3.ZERO)
		v.append(Vector3(cos(a1) * 0.62, 0.0, sin(a1) * 0.62))
		v.append(Vector3(cos(a0) * 0.62, 0.0, sin(a0) * 0.62))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_blob_mat = StandardMaterial3D.new()
	_blob_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_blob_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_blob_mat.albedo_color = Color(0.0, 0.0, 0.0, 0.35)
	_blob_mat.render_priority = 2      # JS renderOrder 2
	_blob_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	blob = MeshInstance3D.new()
	blob.name = "Blob"
	blob.mesh = mesh
	blob.material_override = _blob_mat
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blob.visible = false
	add_child(blob)


func _update_blob(player: Player) -> void:
	var w: World = Game.world
	if w == null:
		blob.visible = false
		return
	var g := w.ground_height(player.x, player.z, 0.2, player.y + 0.3)
	var on := g > -INF and player.mode == &"normal"
	if blob.visible != on:
		blob.visible = on
	if on:
		var k := maxf(0.4, 1.0 - (player.y - g) * 0.08)
		blob.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3(k, k, k)), Vector3(player.x, g + 0.03, player.z))
		var alpha := 0.35 * k
		if alpha != _blob_alpha:
			_blob_alpha = alpha
			_blob_mat.albedo_color = Color(0.0, 0.0, 0.0, alpha)


func _dynamic_resolution(rdt: float) -> void:
	# dynamic resolution: when frames get long because of the GPU (big fights: effects, overdraw) the render scale eases down, and back up once it is cheap again.
	# Only when the main thread is NOT the bottleneck (its own time per frame, cpu, is short): a CPU-bound frame (many objects) gets no faster at a lower resolution,
	# and every scale change reallocates the framebuffer (a hitch of its own).
	var vp := get_viewport()
	var cpu_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0 + RenderingServer.viewport_get_measured_render_time_cpu(vp.get_viewport_rid()) + RenderingServer.get_frame_setup_time_cpu()
	_ft = _ft * 0.92 + rdt * 1000.0 * 0.08
	_cpu = _cpu * 0.92 + cpu_ms * 0.08
	_dyn_t += rdt
	if _dyn_t > 0.7:
		_dyn_t = 0.0
		if not dynamic_res:
			return
		var rs := res_scale
		if _ft > 22.0 and _cpu < 14.0 and not post.ao_shed:
			post.ao_shed = true          # the first thing to go when the GPU is the limit: contact shadows, the priciest pass, until the next level; a pixel count drop only after that
		elif _ft > 22.0 and _cpu < 14.0 and rs > 0.6:
			rs = maxf(0.6, rs - 0.1)
		elif (_ft < 15.0 or _cpu > 18.0) and rs < 1.0:
			rs = minf(1.0, rs + 0.05)
		if rs != res_scale:
			res_scale = rs
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR     # (FSR 1 instead of the browser's bilinear stretch; off at scale 1)
			vp.scaling_3d_scale = rs


# ---- dev console "mirror": a second camera in front of the player, in a window at the top (shows the model, its items and its animations from the front) -------------

func set_mirror(on: bool) -> void:
	mirror_on = on
	if _mirror_box == null:
		var w := 260
		var h := 340
		var box := SubViewportContainer.new()
		box.name = "Mirror"
		box.size = Vector2(w, h)
		box.position = Vector2(get_viewport().get_visible_rect().size.x * 0.5 - w * 0.5, 12.0)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.stretch = true
		_mirror_vp = SubViewport.new()
		_mirror_vp.size = Vector2i(w, h)
		_mirror_vp.world_3d = get_viewport().world_3d
		_mirror_vp.msaa_3d = Viewport.MSAA_4X
		box.add_child(_mirror_vp)
		_mirror_cam = Camera3D.new()
		_mirror_cam.fov = 40.0
		_mirror_cam.near = 0.1
		_mirror_cam.far = 100.0
		_mirror_cam.environment = env
		_mirror_cam.compositor = compositor
		_mirror_vp.add_child(_mirror_cam)
		var label := Label.new()
		label.text = "FRONT VIEW"
		label.add_theme_color_override(&"font_color", Color.hex(0x7be34aff))
		label.add_theme_font_size_override(&"font_size", 11)
		box.add_child(label)
		var border := ReferenceRect.new()
		border.editor_only = false
		border.border_color = Color.hex(0x7be34aff)
		border.border_width = 2.0
		border.size = Vector2(w, h)
		box.add_child(border)
		_mirror_box = box
		Game.ui_root.add_child(box)
	_mirror_box.visible = on
	_mirror_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED


func _render_mirror(p: Player) -> void:
	var fx := sin(p.yaw)
	var fz := cos(p.yaw)
	var d := 4.2
	_mirror_cam.global_transform = _look_at(Vector3(p.x + fx * d, p.y + 1.25, p.z + fz * d), Vector3(p.x, p.y + 0.95, p.z), Vector3.UP)
