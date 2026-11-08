class_name GlowText
extends Control
## Big text with a soft CSS text-shadow glow (YOU DIED, VITAL SIGNS CRITICAL): sharp text drawn as usual, over a glow baked once from the text and kept as a mip chain, so the frame pays
## for one quad. Bakes again when its text or size changes.

var text := ""
var font_key: StringName = &"raj700"
var font_size := 44
var spacing := 0.0
var color := Color.WHITE
var margin := 120.0                # room for the glow around the text
var glow_mat: ShaderMaterial
var _glow_rect: ColorRect
var _baked_key := ""


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow_rect = ColorRect.new()
	_glow_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow_rect.color = Color.WHITE
	_glow_rect.show_behind_parent = true
	glow_mat = CrtTheme.mat("res://ui/glow_text.gdshader")
	_glow_rect.material = glow_mat
	_glow_rect.visible = false
	add_child(_glow_rect)


func set_text_style(t: String, key: StringName, sz: int, sp: float, col: Color) -> void:
	text = t
	font_key = key
	font_size = sz
	spacing = sp
	color = col
	queue_redraw()
	_rebake()


func _text_size() -> Vector2:
	var f := CrtTheme.font(font_key)
	return Vector2(CrtTheme.text_w(f, text, font_size, spacing), f.get_height(font_size))


func _draw() -> void:
	if text == "":
		return
	var f := CrtTheme.font(font_key)
	var ts := _text_size()
	var x := (size.x - ts.x) * 0.5
	var y := CrtTheme.baseline(f, font_size, (size.y - ts.y) * 0.5, ts.y)
	CrtTheme.draw_text(self, f, x, y, text, font_size, color, spacing)


func _rebake() -> void:
	if not is_inside_tree() or text == "":
		return
	var key := "%s|%s|%d|%f" % [text, font_key, font_size, spacing]
	if key == _baked_key:
		return
	_baked_key = key
	_bake.call_deferred(key)


## Rasterise the text into a throwaway viewport, read it back once, keep its mips.
func _bake(key: String) -> void:
	if key != _baked_key or DisplayServer.get_name() == "headless":
		return
	var ts := _text_size()
	var box := Vector2i(ceili(ts.x + margin * 2.0), ceili(ts.y + margin * 2.0))
	var vp := SubViewport.new()
	vp.size = box
	vp.disable_3d = true
	vp.transparent_bg = true
	vp.gui_disable_input = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var painter := _Painter.new()
	painter.owner_text = self
	painter.at = Vector2(margin, margin)
	vp.add_child(painter)
	add_child(vp)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if key != _baked_key:
		vp.queue_free()
		return
	var img := vp.get_texture().get_image()
	vp.queue_free()
	img.convert(Image.FORMAT_RGBA8)
	img.generate_mipmaps()
	glow_mat.set_shader_parameter("glow", ImageTexture.create_from_image(img))
	_glow_rect.size = Vector2(box)
	_glow_rect.position = (size - Vector2(box)) * 0.5
	_glow_rect.visible = true


## CSS blur radius (px) to the mip level whose texels are about that wide.
static func lod_of(radius: float) -> float:
	return maxf(0.0, log(maxf(radius, 1.0) * 0.9) / log(2.0))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _glow_rect != null:
		_glow_rect.position = (size - _glow_rect.size) * 0.5
		queue_redraw()


class _Painter extends Node2D:
	var owner_text: GlowText
	var at := Vector2.ZERO
	func _draw() -> void:
		var o := owner_text
		var f := CrtTheme.font(o.font_key)
		var ts := o._text_size()
		var y := CrtTheme.baseline(f, o.font_size, at.y, ts.y)
		CrtTheme.draw_text(self, f, at.x, y, o.text, o.font_size, Color.WHITE, o.spacing)
