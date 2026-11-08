class_name GrindScreen
extends Control
## RAILJACK's CRT composite (JS makeDom, resize, composite, drawAscii): the low-res scene buffer, its bloom and character grid in small viewports, the glass (phosphor, ASCII re-read, glitch) and post (alarm hue, flashes, scan, grain, roll, vignette) in shaders, then the monitor and its lamps. The JS reads pixels back and prints glyphs one by one; here the ASCII overlay is one shader pass.

const RAMP := " .:-=+*#%@"

var S: GrindSession = null
var draw_node: GrindDraw = null
var hud: GrindHud = null
var vp_scene: SubViewport = null
var vp_bloom: SubViewport = null
var vp_asc: SubViewport = null
var vp_glyph: SubViewport = null
var spill: ColorRect = null
var glass_box: Control = null
var glass: ColorRect = null
var post: ColorRect = null
var art: TextureRect = null
var lamps: Control = null
var _glass_mat: ShaderMaterial = null
var _post_mat: ShaderMaterial = null
var _spill_mat: ShaderMaterial = null
var g := Rect2()
var mon := Rect2()
var _slices := PackedVector3Array()
var _core_cache := {}
var _glow: Texture2D = null
var _glyph_ctl: Control = null


func _init(p_s: GrindSession) -> void:
	S = p_s


func _vp(size_: Vector2i, child: Node) -> SubViewport:
	var v := SubViewport.new()
	v.size = size_
	v.disable_3d = true
	v.transparent_bg = false
	v.gui_disable_input = true
	v.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	v.add_child(child)
	add_child(v)
	return v


func _sample_rect(tex: Texture2D) -> ColorRect:
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	var m := ShaderMaterial.new()
	m.shader = load("res://minigames/grind/grind_down.gdshader")
	m.set_shader_parameter(&"src", tex)
	r.material = m
	return r


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	draw_node = GrindDraw.new()
	draw_node.S = S
	vp_scene = _vp(Vector2i(660, 380), draw_node)
	vp_scene.msaa_2d = Viewport.MSAA_4X
	vp_bloom = _vp(Vector2i(96, 55), _sample_rect(vp_scene.get_texture()))
	vp_asc = _vp(Vector2i(198, 60), _sample_rect(vp_scene.get_texture()))
	spill = ColorRect.new()
	spill.set_anchors_preset(Control.PRESET_FULL_RECT)
	spill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spill_mat = ShaderMaterial.new()
	_spill_mat.shader = load("res://minigames/grind/grind_spill.gdshader")
	spill.material = _spill_mat
	add_child(spill)
	glass_box = Control.new()
	glass_box.clip_contents = true
	glass_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glass_box)
	glass = ColorRect.new()
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glass_mat = ShaderMaterial.new()
	_glass_mat.shader = load("res://minigames/grind/grind_glass.gdshader")
	_glass_mat.set_shader_parameter(&"buf", vp_scene.get_texture())
	_glass_mat.set_shader_parameter(&"bloom", vp_bloom.get_texture())
	_glass_mat.set_shader_parameter(&"asc", vp_asc.get_texture())
	var C := S.COL
	var pn: Array[Vector3] = []
	var ac: Array[Color] = []
	var aa: Array[float] = [0.5, 0.56, 0.56, 0.6]
	var cols: Array[Color] = [C.solid, C.fire, C.red, C.white]
	for q in 4:
		var c := cols[q]
		var mx := maxf(maxf(c.r, c.g), c.b)
		pn.append(Vector3(c.r / mx, c.g / mx, c.b / mx))
		ac.append(Color(c.r, c.g, c.b, aa[q]))
	_glass_mat.set_shader_parameter(&"pn", pn)
	_glass_mat.set_shader_parameter(&"acol", ac)
	var bar := S.tcol(150, 255, 190, 1.0)
	_glass_mat.set_shader_parameter(&"bar_col", Vector3(bar.r, bar.g, bar.b))
	glass.material = _glass_mat
	glass_box.add_child(glass)
	hud = GrindHud.new()
	hud.S = S
	glass_box.add_child(hud)
	post = ColorRect.new()
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_post_mat = ShaderMaterial.new()
	_post_mat.shader = load("res://minigames/grind/grind_post.gdshader")
	var rb := S.tcol(110, 255, 170, 1.0)
	_post_mat.set_shader_parameter(&"roll_col", Vector3(rb.r, rb.g, rb.b))
	post.material = _post_mat
	glass_box.add_child(post)
	art = TextureRect.new()
	art.texture = load(CrtKit.ART_PATH)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	var gr := Gradient.new()
	gr.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	gr.colors = PackedColorArray([Color(1, 1, 1, 0.95), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)])
	var gt := GradientTexture2D.new()
	gt.gradient = gr
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	_glow = gt
	lamps = Control.new()
	lamps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lamps.set_anchors_preset(Control.PRESET_FULL_RECT)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	lamps.material = add
	lamps.draw.connect(_draw_lamps)
	add_child(lamps)
	get_viewport().size_changed.connect(resize)
	resize()


## the glass fills most of the window, the bezel runs off the edges
func resize() -> void:
	var sz := get_viewport().get_visible_rect().size
	var W := sz.x
	var H := sz.y
	var o: Dictionary = CrtKit.HOLE
	var gw_f: float = o.x2 - o.x1
	var gh_f: float = o.y2 - o.y1
	var sh := 0.82 * H / gh_f
	var sw := sh * CrtKit.ART_RATIO
	if gw_f * sw > 0.94 * W:
		sw = 0.94 * W / gw_f
		sh = sw / CrtKit.ART_RATIO
	var gw := gw_f * sw
	var gh := gh_f * sh
	g = Rect2((W - gw) / 2.0, (H - gh) / 2.0, gw, gh)
	mon = Rect2(g.position.x - o.x1 * sw, g.position.y - o.y1 * sh, sw, sh)
	var bw := roundi(380.0 * gw / gh)
	vp_scene.size = Vector2i(bw, 380)
	draw_node.W = bw
	draw_node.H = 380
	vp_bloom.size = Vector2i(96, roundi(96.0 * gh / gw))
	# ASCII overlay grid + a tiny bloom canvas (upscaled with smoothing = free blur)
	var rows := 60
	var cols := roundi(rows * (gw / gh) / 0.55)
	vp_asc.size = Vector2i(cols, rows)
	_glass_mat.set_shader_parameter(&"grid", Vector2(cols, rows))
	glass_box.position = g.position
	glass_box.size = g.size
	glass.position = Vector2.ZERO
	glass.size = g.size
	hud.position = Vector2.ZERO
	hud.size = g.size
	post.position = Vector2.ZERO
	post.size = g.size
	_post_mat.set_shader_parameter(&"box", g.size)
	art.position = mon.position.round()
	art.size = mon.size.ceil()
	_make_glyphs(g.size.x / cols, g.size.y / rows)
	_spill_mat.set_shader_parameter(&"win", sz)
	_spill_mat.set_shader_parameter(&"r0", gh * 0.3)
	_spill_mat.set_shader_parameter(&"r1", maxf(W, H) * 0.75)


## the ten glyphs of the brightness ramp, one cell each, drawn once
func _make_glyphs(cw: float, ch: float) -> void:
	var cell := Vector2i(ceili(cw), ceili(ch))
	if vp_glyph == null:
		_glyph_ctl = Control.new()
		_glyph_ctl.draw.connect(_draw_glyphs)
		vp_glyph = _vp(cell * Vector2i(10, 1), _glyph_ctl)
		_glass_mat.set_shader_parameter(&"glyphs", vp_glyph.get_texture())
	vp_glyph.size = cell * Vector2i(10, 1)
	_glyph_ctl.set_meta(&"ch", ch)
	_glyph_ctl.size = Vector2(vp_glyph.size)
	vp_glyph.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	vp_glyph.render_target_update_mode = SubViewport.UPDATE_ONCE
	_glyph_ctl.queue_redraw()


func _draw_glyphs() -> void:
	var ch: float = _glyph_ctl.get_meta(&"ch")
	var cw := _glyph_ctl.size.x / 10.0
	var f := CrtTheme.font(&"vt323")
	var sz := roundi(ch * 1.02)
	_glyph_ctl.draw_rect(Rect2(Vector2.ZERO, _glyph_ctl.size), Color.BLACK)
	for i in RAMP.length():
		var c := RAMP.unicode_at(i)
		var a := f.get_char_size(c, sz).x
		# textBaseline middle at y + .55 ch
		f.draw_char(_glyph_ctl.get_canvas_item(), Vector2((i + 0.5) * cw - a / 2.0, ch * 0.55 + (f.get_ascent(sz) - f.get_descent(sz)) / 2.0), c, sz, Color.WHITE)


func _draw_lamps() -> void:
	var flick := 0.94 + 0.06 * sin(_t * 61.0) * sin(_t * 7.3)
	_lamp("power", Color8(140, 255, 120), 0.8 + 0.2 * flick)
	_lamp("disk", Color8(255, 190, 60), S.leds.disk)
	_lamp("video", Color8(140, 255, 120), maxf(S.leds.video, 0.7 if S.glitch > 0.0 else 0.0))
	_lamp("sync", Color8(255, 60, 40), S.leds.sync)


func _lamp(k: String, col: Color, on: float) -> void:
	if on <= 0.05:
		return
	var L: Array = CrtKit.LEDS[k]
	var c := mon.position + Vector2(L[0] * mon.size.x, L[1] * mon.size.y)
	var r := mon.size.x * 0.006 * 4.0
	lamps.draw_texture_rect(_glow, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(col.r, col.g, col.b, on))


## the packet's core: a radial gradient (white, phosphor, nothing), kept per brightness step
func core_tex(white: Color, solid: Color, mid: float) -> Texture2D:
	var q := roundi(mid * 8.0)
	if _core_cache.has(q):
		return _core_cache[q]
	var gr := Gradient.new()
	gr.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	gr.colors = PackedColorArray([Color(white.r, white.g, white.b, 0.9), Color(solid.r, solid.g, solid.b, q / 8.0), Color(solid.r, solid.g, solid.b, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = gr
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 48
	gt.height = 48
	_core_cache[q] = gt
	return gt


var _t := 0.0


func render(_dt: float) -> void:
	_t = Time.get_ticks_msec() / 1000.0
	var u := g.size.y / 520.0
	var kick := S.shake * S.shake * 14.0 * u
	glass_box.position = g.position + Vector2((randf() - 0.5) * kick, (randf() - 0.5) * kick)
	var flick := 0.94 + 0.06 * sin(_t * 61.0) * sin(_t * 7.3)
	var red := S.alarm_mix()
	draw_node.queue_redraw()
	hud.queue_redraw()
	lamps.queue_redraw()
	var m := _glass_mat
	m.set_shader_parameter(&"flick", flick)
	m.set_shader_parameter(&"fringe", 1.6 * u / g.size.x)
	var gl := minf(1.0, S.glitch)
	m.set_shader_parameter(&"glitch", S.glitch)
	m.set_shader_parameter(&"seed", randf() * 100.0)
	if S.glitch > 0.0:
		var n := 2 + int(gl * 14.0)
		_slices.resize(16)
		var bh := 380.0
		for i in 16:
			if i < n:
				var yy := randf() * bh
				var hh := 2.0 + randf() * 14.0
				var off := (randf() - 0.5) * 50.0 * gl * u
				_slices[i] = Vector3(yy / bh, hh / bh, off / g.size.x)
			else:
				_slices[i] = Vector3(-1.0, 0.0, 0.0)
		m.set_shader_parameter(&"slices", _slices)
		m.set_shader_parameter(&"gl_off", Vector2(7.0 * u / g.size.x, -5.0 * u / g.size.x))
		var by := randf()
		m.set_shader_parameter(&"bar", Vector2(by, (3.0 * u + randf() * 10.0 * u) / g.size.y))
	var pm := _post_mat
	pm.set_shader_parameter(&"red", red)
	pm.set_shader_parameter(&"red_flash", S.red_flash)
	pm.set_shader_parameter(&"white_flash", S.white_flash)
	pm.set_shader_parameter(&"grain_off", Vector2(randf() * 160.0, randf() * 160.0))
	pm.set_shader_parameter(&"roll", fmod(_t * 0.16, 1.3) - 0.2)
	var C := S.tcol(20, 80, 40, 0.35)
	_spill_mat.set_shader_parameter(&"col", Color8(90, 10, 6, 89) if red > 0.3 else C)
