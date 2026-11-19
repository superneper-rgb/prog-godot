class_name DialogBox
extends Control
## The box NPC talk and cutscene subtitles share (JS #dlg + .dlgbar): the foint-tech panel (assets/ui/dialog-frame.webp) with a green CRT screen, the name on the top-left plate, the typed text, the hint; and the letterbox bars. Restyle it here only; never make another subtitle box.

const FRAME := preload("res://assets/ui/dialog-frame.webp")
const PH := Color("7dff9c")
const ASPECT := 1972.0 / 383.0

var _bar_t: ColorRect
var _bar_b: ColorRect
var _panel: Control
var _screen: ColorRect
var _name: Label
var _text: Label
var _hint_row: HBoxContainer
var _hint: Label
var _key: Hud.VdKey
var _bars_on := false
var _box_on := false
var _bar_k := 0.0
var _box_k := 0.0
var _cine := false
var _terminal: SigilTerminal = null      # the Sigil's talk is shown on the SchleedTech terminal, close up, in place of the box
var _term_on := false


func _init() -> void:
	name = "DialogBox"
	CrtTheme.full(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_bar_t = _bar()
	_bar_b = _bar()
	_panel = Control.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	# #dlg::before, ::after: the screen's green glow and scan lines
	_screen = ColorRect.new()
	_screen.color = Color(0.02, 0.1, 0.05, 0.62)
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_screen)
	var tex := TextureRect.new()
	tex.texture = FRAME
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(tex)
	_name = CrtTheme.label("", &"raj600", 11, PH, 1)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name.clip_text = true
	_panel.add_child(_name)
	_text = CrtTheme.label("", &"raj600", 16, PH, 1)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.clip_text = true
	_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_panel.add_child(_text)
	_hint_row = HBoxContainer.new()
	_hint_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_row.alignment = BoxContainer.ALIGNMENT_END
	_hint_row.add_theme_constant_override(&"separation", 6)
	_panel.add_child(_hint_row)
	_key = Hud.VdKey.new()
	_hint_row.add_child(_key)
	_hint = CrtTheme.label("", &"raj600", 12, Color(125.0 / 255.0, 1.0, 156.0 / 255.0, 0.65), 2)
	_hint_row.add_child(_hint)
	_panel.visible = false
	_layout()
	resized.connect(_layout)
	set_process(false)


func _bar() -> ColorRect:
	var b := ColorRect.new()
	b.color = Color.BLACK
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(b)
	return b


## CSS sizes are in percent of the panel: width min(900 px, viewport - 24), bottom 9vh + 16 px.
func _layout() -> void:
	if _panel == null:
		return
	var vp := size
	var w := minf(900.0, vp.x - 24.0)
	var h := w / ASPECT
	_panel.size = Vector2(w, h)
	_panel.position = Vector2((vp.x - w) * 0.5, vp.y - vp.y * 0.09 - 16.0 - h + (1.0 - _box_k) * 12.0)
	_screen.position = Vector2(w * 0.077, h * 0.167)
	_screen.size = Vector2(w * (1.0 - 0.077 - 0.072), h * (1.0 - 0.167 - 0.154))
	_name.position = Vector2(w * 0.088, h * 0.05)
	_name.size = Vector2(w * 0.104, h * 0.094)
	_text.position = Vector2(w * 0.102, h * 0.19)
	_text.size = Vector2(w * (1.0 - 0.102 - 0.096), h * (1.0 - 0.19 - 0.22))
	_hint_row.position = Vector2(w * 0.5, h * (1.0 - 0.165) - 18.0)
	_hint_row.size = Vector2(w * (1.0 - 0.5 - 0.096), 18.0)
	_name.add_theme_font_size_override(&"font_size", maxi(8, int(w * 0.0105 * 1.25)))
	_text.add_theme_font_size_override(&"font_size", maxi(11, int(w * 0.013 * 1.5)))
	_hint.add_theme_font_size_override(&"font_size", maxi(9, int(w * 0.0115 * 1.25)))
	var bh := vp.y * (0.125 if _cine else 0.09) * _bar_k
	_bar_t.position = Vector2.ZERO
	_bar_t.size = Vector2(vp.x, bh)
	_bar_b.position = Vector2(0.0, vp.y - bh)
	_bar_b.size = Vector2(vp.x, bh)


## body.dlg: the letterbox slides in. cine: the deeper bars of a cutscene.
func set_bars(on: bool, cine: bool = false) -> void:
	_bars_on = on
	_cine = cine
	set_process(true)


## A talker with `terminal: true` (the Sigil): its lines go to the terminal close-up (ui/sigil_terminal.gd) instead of the box, for as long as this is on
func set_terminal(on: bool) -> void:
	if on == _term_on:
		return
	if on and _terminal == null:
		_terminal = SigilTerminal.new()
		add_child(_terminal)
	_term_on = on
	if _terminal != null:
		_terminal.open(on)


## #dlg.on
func show_box(on: bool) -> void:
	if _term_on and on:
		return
	_box_on = on
	if on:
		_panel.visible = true
	set_process(true)


func set_content(who: String, text: String, hint: String) -> void:
	if _term_on:
		_terminal.set_content(who, text, hint)
		return
	_name.text = who
	_text.text = text
	_hint.text = hint
	_hint_row.visible = hint != ""
	if hint != "":
		_key.set_key("X", Inp.using_pad)


func _process(dt: float) -> void:
	# CSS: bars height .55s cubic-bezier(.2,.7,.2,1), the box opacity .25s and transform .3s
	_bar_k = move_toward(_bar_k, 1.0 if _bars_on else 0.0, dt / 0.35)
	_box_k = move_toward(_box_k, 1.0 if _box_on else 0.0, dt / 0.25)
	_panel.modulate.a = _box_k
	if _box_k <= 0.0 and not _box_on:
		_panel.visible = false
	_layout()
	if is_equal_approx(_bar_k, 1.0 if _bars_on else 0.0) and is_equal_approx(_box_k, 1.0 if _box_on else 0.0):
		set_process(false)
