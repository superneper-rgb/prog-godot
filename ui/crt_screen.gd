class_name CrtScreen
extends ColorRect
## One phosphor screen: a SubViewport holding the picture (add controls under `content`, laid out in the screen's own logical px), shown through the shared CRT shader, with the
## random glitch of the pause terminal and the shop machines. A screen whose picture rarely changes stays cheap: its viewport only redraws when asked (`refresh()`), the shader
## alone runs every frame. `live = true` redraws every frame.

var viewport: SubViewport
var content: Control
var live := false:
	set(v):
		live = v
		_mode()
var _dirty := true
var logical := Vector2(600, 440)

# the glitch timers (pcGlitchArm)
var glitch_sound := "pauseGlitch"
var _armed := false
var _next := 0.0
var _gt := -1.0
var _tear_a := Vector2(0.4, 10.0)
var _tear_b := Vector2(0.7, 5.0)

# pzGlitch: at, shift x, y (css px), tan(skew), brightness, contrast, saturate, hue rad, clip top, clip bottom. Held, steps(1, end).
const GL_KEYS: Array = [
	[0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0],
	[0.12, -9.0, 0.0, 0.0699, 1.7, 1.4, 1.0, 0.0, 0.10, 0.58],
	[0.24, 12.0, 0.0, 0.0, 1.3, 1.0, 1.0, -0.4189, 0.52, 0.18],
	[0.30, -4.0, 2.0, -0.0524, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0],
	[0.46, 7.0, -2.0, 0.0, 2.1, 1.0, 2.0, 0.0, 0.0, 0.40],
	[0.60, -11.0, 0.0, 0.0, 1.0, 1.6, 1.0, 0.0, 0.30, 0.34],
	[0.74, 3.0, 0.0, 0.0, 1.3, 1.0, 1.0, 0.0, 0.0, 0.0],
]
# pzTear: at, opacity
const TEAR_KEYS: Array = [[0.0, 0.0], [0.14, 1.0], [0.28, 0.0], [0.48, 0.9], [0.62, 0.0], [0.78, 0.6], [0.90, 0.0]]
const GLITCH_DUR := 0.38


func _init(p_logical: Vector2 = Vector2(600, 440), shader_path: String = "res://ui/crt.gdshader") -> void:
	logical = p_logical
	color = Color.WHITE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.disable_3d = true
	viewport.transparent_bg = true
	viewport.gui_disable_input = true
	viewport.handle_input_locally = false
	viewport.audio_listener_enable_2d = false
	viewport.audio_listener_enable_3d = false
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.size_2d_override_stretch = true
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(viewport)
	content = Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.size = logical
	viewport.add_child(content)
	material = CrtTheme.mat(shader_path)
	resized.connect(fit)


func _ready() -> void:
	(material as ShaderMaterial).set_shader_parameter("view", viewport.get_texture())
	fit()
	set_process(false)


## Size the viewport to this screen's real pixels (scale: the page is magnified, the controls page of the pause terminal).
func fit(scale_up: float = 1.0) -> void:
	if not is_inside_tree():
		return
	var f := CrtTheme.px(self)
	var real := Vector2i(maxi(1, roundi(size.x * f * scale_up)), maxi(1, roundi(size.y * f * scale_up)))
	if viewport.size != real:
		viewport.size = real
	var lg := Vector2i(maxi(1, roundi(logical.x)), maxi(1, roundi(logical.y)))
	if viewport.size_2d_override != lg:
		viewport.size_2d_override = lg
	content.size = logical
	var m := material as ShaderMaterial
	m.set_shader_parameter("rect_px", size * f * scale_up)
	m.set_shader_parameter("px_scale", f * scale_up)
	refresh()


## The logical page size changed (the terminal's page is scaled to its glass).
func set_logical(l: Vector2) -> void:
	logical = l
	fit()


## Redraw the picture once.
func refresh() -> void:
	_dirty = true
	_mode()


func _mode() -> void:
	if viewport == null:
		return
	if live:
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	elif _dirty:
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		_dirty = false
	else:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func param(n: StringName, v: Variant) -> void:
	(material as ShaderMaterial).set_shader_parameter(n, v)


## The glitch, as pcGlitchArm: every few seconds while the screen sits there, a short tear, jump and flash.
func arm_glitch(on: bool) -> void:
	_armed = on
	_gt = -1.0
	_apply_key(GL_KEYS[0])
	param(&"tear_a", Vector3(_tear_a.x, _tear_a.y, 0.0))
	param(&"tear_b", Vector3(_tear_b.x, _tear_b.y, 0.0))
	if on:
		_next = 1.5 + randf() * 2.5
	set_process(on)


func glitch_now() -> void:
	_tear_a = Vector2((10.0 + randf() * 70.0) * 0.01, 4.0 + randf() * 14.0)
	_tear_b = Vector2((10.0 + randf() * 80.0) * 0.01, 2.0 + randf() * 8.0)
	_gt = 0.0
	if glitch_sound != "":
		CrtTheme.menu_sound(glitch_sound)


func _process(delta: float) -> void:
	if _gt >= 0.0:
		_gt += delta
		var p := _gt / GLITCH_DUR
		if p >= 1.0:
			_gt = -1.0
			_apply_key(GL_KEYS[0])
			param(&"tear_a", Vector3(_tear_a.x, _tear_a.y, 0.0))
			param(&"tear_b", Vector3(_tear_b.x, _tear_b.y, 0.0))
		else:
			var key: Array = GL_KEYS[0]
			for k: Array in GL_KEYS:
				if p >= k[0]:
					key = k
			_apply_key(key)
			var o := 0.0
			for k: Array in TEAR_KEYS:
				if p >= k[0]:
					o = k[1]
			param(&"tear_a", Vector3(_tear_a.x, _tear_a.y, o))
			param(&"tear_b", Vector3(_tear_b.x, _tear_b.y, o))
	if _armed:
		_next -= delta
		if _next <= 0.0:
			glitch_now()
			_next = 3.0 + randf() * 6.0


func _apply_key(k: Array) -> void:
	param(&"g_shift", Vector2(k[1], k[2]))
	param(&"g_skew", k[3])
	param(&"g_bright", k[4])
	param(&"g_contrast", k[5])
	param(&"g_sat", k[6])
	param(&"g_hue", k[7])
	param(&"g_clip", Vector2(k[8], k[9]))
