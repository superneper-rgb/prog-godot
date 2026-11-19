class_name SigilTerminal
extends Control
## The Sigil speaking: the SchleedTech monitor (the pause terminal's, assets/ui/cut/pausecrt.png) pulled up until its glass nearly fills the window, the Sigil's face on it in green phosphor and its words typed
## under the face. It is how the shared dialogue shows a talker that has `terminal: true` (ui/dialog_box.gd set_terminal; core/dialogue.gd): the same lines, typing, skip and close as any other talk, only
## not in the little box. The layout is the pause menu's (ui/pause_menu.gd pc_layout), so the glass sits in the monitor exactly as it does there.

const LOGICAL := Vector2(600, 440)

var _bg: ColorRect
var _stage: Control
var _view: CrtScreen
var _face: SigilFace
var _name: Label
var _text: Label
var _hint: Label
var _art: TextureRect
var _on := false
var _k := 0.0          # 0 away .. 1 up close
var _sw := 0.0
var _sh := 0.0
var _zoom := 1.0
var _t := Vector2.ZERO
var _glass := Rect2()


func _init() -> void:
	name = "SigilTerminal"
	CrtTheme.full(self)
	visible = false


func _ready() -> void:
	_bg = ColorRect.new()
	_bg.color = Color.WHITE
	CrtTheme.full(_bg)
	_bg.material = CrtTheme.mat("res://ui/backdrop.gdshader")
	add_child(_bg)
	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_view = CrtScreen.new(LOGICAL)
	_view.param(&"glow_tint", Vector3(80.0 / 255.0, 1.0, 140.0 / 255.0))
	_view.param(&"glow_amount", 0.62)
	_view.param(&"glow_radius", 7.0)
	_view.live = true
	_stage.add_child(_view)
	_face = SigilFace.new()
	_face.caption = ""
	_face.backdrop = false
	_face.position = Vector2(140.0, 26.0)
	_face.size = Vector2(320.0, 250.0)
	_view.content.add_child(_face)
	_name = CrtTheme.label("THE SIGIL", &"raj600", 13, CrtTheme.PH_HI, 3)
	_name.position = Vector2(34.0, 22.0)
	_view.content.add_child(_name)
	var node := CrtTheme.label("HIVE NODE ACTIVATED", &"raj600", 11, CrtTheme.PH, 2)
	node.position = Vector2(34.0, 42.0)
	_view.content.add_child(node)
	_text = CrtTheme.label("", &"raj600", 21, CrtTheme.PH, 1)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.position = Vector2(46.0, 296.0)
	_text.size = Vector2(508.0, 96.0)
	_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_view.content.add_child(_text)
	_hint = CrtTheme.label("", &"raj600", 12, CrtTheme.PH, 2)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.position = Vector2(400.0, 404.0)
	_hint.size = Vector2(166.0, 18.0)
	_view.content.add_child(_hint)
	_art = TextureRect.new()
	_art.texture = load("res://assets/ui/cut/pausecrt.png")
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_SCALE
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_stage.add_child(_art)
	get_viewport().size_changed.connect(_layout)
	_layout()
	set_process(false)


func open(on: bool) -> void:
	_on = on
	if on:
		visible = true
		_view.arm_glitch(true)
		_view.glitch_now()
	set_process(true)


func set_content(who: String, text: String, hint: String) -> void:
	_name.text = who
	_text.text = text
	_hint.text = "[ X ]  " + hint if hint != "" else ""
	_face.speaking = 1.0 if hint == "SKIP" and who == "THE SIGIL" else 0.0      # (the dialogue's hint is SKIP exactly while a line is still coming out)
	if Game.player != null:
		_face.look = sin(Time.get_ticks_msec() / 1700.0) * 0.25


## Fit the monitor to the window as the pause terminal does, and work out how far to pull it up
func _layout() -> void:
	var vp := get_viewport_rect().size
	var h: Array = UiArt.PAUSE_HOLE
	_sw = minf(vp.x * 0.98, vp.y * 0.98 * UiArt.PAUSE_RATIO)
	_sh = _sw / UiArt.PAUSE_RATIO
	_glass = Rect2(h[0] * _sw, h[1] * _sh, (h[2] - h[0]) * _sw, (h[3] - h[1]) * _sh)
	_zoom = maxf(1.0, minf(vp.x * 0.9 / _glass.size.x, vp.y * 0.9 / _glass.size.y))      # (0.9: a rim of the monitor stays in the picture, so it is still a thing and not a screen)
	_t = Vector2(_sw * 0.5 - (h[0] + h[2]) * 0.5 * _sw, _sh * 0.5 - (h[1] + h[3]) * 0.5 * _sh)
	_stage.size = Vector2(_sw, _sh)
	_stage.pivot_offset = _glass.position + _glass.size * 0.5
	_art.size = Vector2(_sw, _sh)
	_view.position = _glass.position
	_view.size = _glass.size
	_view.set_logical(LOGICAL)
	_place()


func _place() -> void:
	var vp := get_viewport_rect().size
	var e := _k * _k * (3.0 - 2.0 * _k)
	var sc := lerpf(0.72, _zoom, e)
	_stage.scale = Vector2.ONE * sc
	_stage.position = (vp - Vector2(_sw, _sh)) * 0.5 + _t * e
	modulate.a = minf(1.0, _k * 2.5)
	var f := CrtTheme.px(self)
	_view.param(&"rect_px", _glass.size * f * sc)
	_view.param(&"px_scale", f * sc)
	_view.param(&"overlay", lerpf(1.0, 0.45, e))


func _process(dt: float) -> void:
	_k = move_toward(_k, 1.0 if _on else 0.0, dt / (0.55 if _on else 0.3))
	_place()
	if not _on and _k <= 0.0:
		visible = false
		_view.arm_glitch(false)
		set_process(false)
