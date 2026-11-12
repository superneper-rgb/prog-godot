class_name ForgeUi
extends CanvasLayer
## FORGE's panels in the phosphor CRT look (ui/crt_theme.gd): the status line (top left), the selection card (right), the hint bar and the palette strip (bottom), and a short message line.
## Shown only in EDIT. Reads Forge every frame and changes a label only when its text changes. Sizes are css px (CrtTheme.fit_window).

const BG := Color(6.0 / 255.0, 12.0 / 255.0, 9.0 / 255.0, 0.88)
const LINE := Color("2f6b3c")
const HELP := """FLY        WASD  ·  SPACE / C up, down  ·  SHIFT fast  ·  ALT slow  ·  RIGHT-DRAG look  ·  WHEEL speed
           H hover over the ground  ·  F orbit the selection  ·  T look straight down

PLACE      pick from the palette (1-9, TAB next tab, or type to search)  ·  CLICK place
           hold CLICK and sweep to paint a row  ·  B scatter (each copy turned and sized a little)
           SHIFT place in mid-air (SHIFT+WHEEL distance)  ·  R turn  ·  Esc put the brush down

PICK       CLICK anything: a new thing or a piece of the level itself
           SHIFT+CLICK add to the selection  ·  drag on empty space to box-select (ALT: level pieces too)

MOVE       DRAG slides over surfaces  ·  SHIFT+DRAG up / down  ·  CTRL+DRAG in the camera's plane
           E carry it in front of you (WHEEL nearer / further)  ·  R / SHIFT+R turn 15°  ·  ALT+R 90°
           END drop onto whatever is below  ·  G grid snap

EDIT       CTRL+D copy (a level piece copies into a new thing)  ·  Q the selection becomes the brush
           DEL delete (a level piece is hidden, its collision off)  ·  RESTORE AS BUILT on the card
           CTRL+Z / CTRL+Y undo / redo  ·  V collision view (amber: invisible walls, red: deleted pieces)

PLAY       P drop Prog at the pointer and play  ·  F8 play / edit  ·  CTRL+S save (also on leaving EDIT)"""
const SWATCHES := ["", "#a9824f", "#9b9a96", "#5a5f66", "#8a4b2a", "#b5131f", "#d8a845", "#3f8f86", "#e8e4dc", "#22262b"]      # "" = the thing's own colour

var forge: Forge
var thumbs: ForgeThumbs
var root: Control
var tab := "shape"
var search := ""
var _status: Label
var _meter: Label
var _hint: Label
var _msg: Label
var _card: PanelContainer
var _card_title: Label
var _card_info: Label
var _card_collide: CheckBox
var _restore: Button
var _delete: Button
var _marquee: Panel
var _help: PanelContainer
var _tabs: HBoxContainer
var _items: HBoxContainer
var _scroll: ScrollContainer
var _search_box: LineEdit
var _reticle: Label
var _shown_items: Array = []      # entries on the strip, in order
var _item_btns: Array[Button] = []
var _last := {}


func _init(f: Forge) -> void:
	forge = f
	layer = 60
	name = "ForgeUi"


func _ready() -> void:
	visible = false
	thumbs = ForgeThumbs.new()
	add_child(thumbs)
	root = CrtTheme.full(Control.new())
	root.theme = CrtTheme.tools_theme()
	add_child(root)
	# ---- status (top left)
	var st := _panel(Vector2(18, 16))
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override(&"separation", 2)
	st.add_child(sv)
	_status = CrtTheme.label("", &"vt323", 26, CrtTheme.PH_HI, 1)
	sv.add_child(_status)
	_meter = CrtTheme.label("", &"mono", 12, CrtTheme.PH_LOW)
	sv.add_child(_meter)
	# ---- message (top middle)
	_msg = CrtTheme.label("", &"vt323", 24, CrtTheme.PH)
	_msg.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.offset_top = 20
	_msg.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(_msg)
	# ---- the pad's pointer (screen centre)
	_reticle = CrtTheme.label("+", &"vt323", 34, CrtTheme.PH)
	_reticle.set_anchors_preset(Control.PRESET_CENTER)
	_reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reticle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_reticle.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_reticle.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(_reticle)
	# ---- selection card (right)
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override(&"panel", CrtTheme.panel(BG, 6, LINE, 14, 10))
	_card.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_card.offset_left = -300
	_card.offset_right = -18
	_card.offset_top = 16
	_card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_card)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override(&"separation", 6)
	_card.add_child(cv)
	_card_title = CrtTheme.label("", &"vt323", 24, CrtTheme.PH_HI, 1)
	_card_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_title.custom_minimum_size = Vector2(250, 0)
	cv.add_child(_card_title)
	_card_info = CrtTheme.label("", &"mono", 12, CrtTheme.PH_LOW)
	_card_info.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY      # (a level piece's path is long: it wraps inside the card)
	_card_info.custom_minimum_size = Vector2(250, 0)
	cv.add_child(_card_info)
	_card_collide = CheckBox.new()
	_card_collide.text = "SOLID (Prog can stand on it)"
	_card_collide.focus_mode = Control.FOCUS_NONE
	_card_collide.toggled.connect(_on_collide)
	cv.add_child(_card_collide)
	var sw := HBoxContainer.new()
	sw.add_theme_constant_override(&"separation", 4)
	cv.add_child(sw)
	for c: String in SWATCHES:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(20, 20)
		b.tooltip_text = "own colour" if c == "" else c
		for sn: StringName in [&"normal", &"hover", &"pressed"]:
			b.add_theme_stylebox_override(sn, CrtTheme.panel(Color(c) if c != "" else Color(0, 0, 0, 0), 3, CrtTheme.PH if sn == &"hover" else LINE))
		if c == "":
			b.text = "×"
		b.pressed.connect(_on_color.bind(c))
		sw.add_child(b)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	cv.add_child(row)
	row.add_child(_button("COPY", forge.copy_selection))
	row.add_child(_button("TURN", func() -> void: forge.turn(Forge.TURN)))
	row.add_child(_button("FOCUS", forge.focus))
	_delete = _button("DELETE", func() -> void: forge.remove(forge.sel.duplicate()))
	_delete.add_theme_color_override(&"font_color", CrtTheme.AMBER)
	row.add_child(_delete)
	_restore = _button("RESTORE AS BUILT", func() -> void: forge.restore(forge.sel.duplicate()))
	cv.add_child(_restore)
	# ---- the box select (drawn while dragging on empty space)
	_marquee = Panel.new()
	_marquee.add_theme_stylebox_override(&"panel", CrtTheme.panel(Color(CrtTheme.PH, 0.08), 0, CrtTheme.PH))
	_marquee.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marquee.visible = false
	root.add_child(_marquee)
	# ---- help (F1)
	_help = PanelContainer.new()
	_help.add_theme_stylebox_override(&"panel", CrtTheme.panel(Color(BG, 0.96), 8, CrtTheme.PH_DIM, 22, 16))
	_help.set_anchors_preset(Control.PRESET_CENTER)
	_help.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_help.grow_vertical = Control.GROW_DIRECTION_BOTH
	_help.mouse_filter = Control.MOUSE_FILTER_STOP
	_help.visible = false
	root.add_child(_help)
	var hv := VBoxContainer.new()
	_help.add_child(hv)
	hv.add_child(CrtTheme.label("FORGE  ·  KEYS  ·  F1 or Esc to close", &"vt323", 30, CrtTheme.PH_HI, 2))
	hv.add_child(CrtTheme.label(HELP, &"mono", 13, CrtTheme.PH))
	# ---- palette (bottom)
	var pal := PanelContainer.new()
	pal.add_theme_stylebox_override(&"panel", CrtTheme.panel(BG, 6, LINE, 12, 8))
	pal.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	pal.offset_left = 18
	pal.offset_right = -18
	pal.offset_bottom = -14
	pal.offset_top = -14 - 168
	pal.grow_vertical = Control.GROW_DIRECTION_BEGIN
	pal.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(pal)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override(&"separation", 6)
	pal.add_child(pv)
	var top := HBoxContainer.new()
	top.add_theme_constant_override(&"separation", 6)
	pv.add_child(top)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override(&"separation", 6)
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_tabs)
	for t: Array in ForgeCatalogue.TABS:
		var b := _button(String(t[1]), _set_tab.bind(String(t[0])))
		b.toggle_mode = true
		b.set_meta(&"cat", t[0])
		_tabs.add_child(b)
	_search_box = LineEdit.new()
	_search_box.placeholder_text = "search..."
	_search_box.custom_minimum_size = Vector2(220, 0)
	_search_box.text_changed.connect(func(s: String) -> void:
		search = s.strip_edges().to_lower()
		_fill())
	_search_box.text_submitted.connect(func(_s: String) -> void: _search_box.release_focus())
	top.add_child(_search_box)
	_scroll = ScrollContainer.new()
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pv.add_child(_scroll)
	_items = HBoxContainer.new()
	_items.add_theme_constant_override(&"separation", 6)
	_scroll.add_child(_items)
	# ---- hint bar (just above the palette)
	_hint = CrtTheme.label("", &"mono", 12, CrtTheme.PH_DIM)
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.offset_bottom = -14 - 168 - 6
	_hint.offset_top = _hint.offset_bottom - 18
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(_hint)


func _panel(at: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override(&"panel", CrtTheme.panel(BG, 6, LINE, 14, 8))
	p.position = at
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(p)
	return p


func _button(text: String, fn: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(fn)
	return b


func set_edit(on: bool) -> void:
	visible = on
	if on and _shown_items.is_empty() and search == "":
		_set_tab(tab)      # (the palette and its pictures are made the first time FORGE opens, not at boot)
	if not on and _search_box != null:
		_search_box.release_focus()


# ---- the palette ----

func _set_tab(cat: String) -> void:
	tab = cat
	for b: Node in _tabs.get_children():
		(b as Button).set_pressed_no_signal(String(b.get_meta(&"cat")) == cat)
	_fill()


func next_tab(d: int) -> void:
	var i := 0
	for k in ForgeCatalogue.TABS.size():
		if ForgeCatalogue.TABS[k][0] == tab:
			i = k
	_set_tab(String(ForgeCatalogue.TABS[posmod(i + d, ForgeCatalogue.TABS.size())][0]))


func _fill() -> void:
	for c: Node in _items.get_children():
		c.queue_free()
	_item_btns.clear()
	_shown_items.clear()
	for e: Dictionary in ForgeCatalogue.items(tab):
		if search != "" and not (String(e.name).to_lower().contains(search) or String(e.id).contains(search)):
			continue
		_shown_items.append(e)
		var b := Button.new()
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(104, 118)
		b.tooltip_text = "%s\n%s" % [e.name, e.note]
		b.pressed.connect(_pick.bind(e))
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		CrtTheme.full(v)
		v.offset_left = 4
		v.offset_right = -4
		v.offset_top = 4
		v.offset_bottom = -2
		b.add_child(v)
		var pic := TextureRect.new()
		pic.custom_minimum_size = Vector2(88, 84)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(pic)
		var l := CrtTheme.label(String(e.name), &"mono", 10, CrtTheme.PH)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.custom_minimum_size = Vector2(92, 0)
		v.add_child(l)
		_items.add_child(b)
		_item_btns.append(b)
		thumbs.request(e, pic)
	_mark_brush()


func _pick(e: Dictionary) -> void:
	if forge.brush != null and forge.brush == e:
		forge.brush = null      # (clicking the picked one again puts it down)
	else:
		forge.set_brush(tab, String(e.id))
	_mark_brush()


func pick_index(i: int) -> void:
	if i >= 0 and i < _shown_items.size():
		_pick(_shown_items[i])


func step_item(d: int) -> void:
	if _shown_items.is_empty():
		return
	var i := _shown_items.find(forge.brush) if forge.brush != null else -1
	i = posmod(i + d, _shown_items.size()) if i >= 0 else (0 if d > 0 else _shown_items.size() - 1)
	forge.set_brush(tab, String(_shown_items[i].id))
	_mark_brush()
	_scroll.ensure_control_visible(_item_btns[i])


func _mark_brush() -> void:
	for i in _item_btns.size():
		_item_btns[i].set_pressed_no_signal(forge.brush != null and _shown_items[i] == forge.brush)


# ---- the selection card ----

func _on_collide(on: bool) -> void:
	forge.set_collide(on)


func _on_color(c: String) -> void:
	forge.set_color(c)


func help_open() -> bool:
	return _help.visible


func toggle_help() -> void:
	_help.visible = not _help.visible


func _set_text(l: Label, t: String) -> void:
	if l.text != t:
		l.text = t


# ---- every frame in EDIT ----

func refresh() -> void:
	var L := forge.layer()
	if L == null:
		return
	var lv: Level = Game.level
	var c := L.counts()
	_set_text(_status, "FORGE  ·  EDIT  ·  %s%s" % [String(lv.id).to_upper(), "  *" if L.edits.dirty else ""])
	_set_text(_meter, "%d PLACED  ·  %d DRAW GROUPS  ·  %d LEVEL EDITS  ·  GRID %s  ·  %s%s%s%s" % [c.x, c.y, c.z, "OFF" if forge.grid() <= 0.0 else "%.2f M" % forge.grid(),
			"HOVER %.1f M" % forge.monitor.hover_h if forge.monitor.hover else "FLY %.0f M/S" % forge.monitor.speed, "  ·  ORBIT" if forge.monitor.orbit != null else "",
			"  ·  SCATTER" if forge.scatter else "", "  ·  COLLISION VIEW" if forge.show_solids else ""])
	_meter.label_settings.font_color = CrtTheme.AMBER if c.y > 120 else CrtTheme.PH_LOW      # (the load meter: amber past 120 draw groups)
	_set_text(_hint, _hint_text())
	_set_text(_msg, forge.message if forge.message_t > 0.0 else "")
	_msg.label_settings.font_color = CrtTheme.AMBER if forge.message_amber else CrtTheme.PH
	_msg.modulate.a = clampf(forge.message_t * 2.0, 0.0, 1.0)
	_reticle.visible = forge.pad_mode
	var cd := forge.card()
	_card.visible = not cd.is_empty()
	if _card.visible:
		_set_text(_card_title, cd.title)
		_set_text(_card_info, cd.info)
		_card_collide.set_pressed_no_signal(cd.collide)
		_card_collide.disabled = cd.dyn
		_restore.visible = cd.orig and cd.edited
		_delete.text = "DELETED" if cd.hidden else "DELETE"
		_delete.disabled = cd.hidden or cd.dyn
	_marquee.visible = forge.marquee != null
	if _marquee.visible:
		var r := Rect2(forge.marquee.a, Vector2.ZERO).expand(forge.marquee.b)
		var k := CrtTheme.px(root)
		_marquee.position = r.position / k
		_marquee.size = r.size / k
	if forge.brush != null and _last.get("brush") != forge.brush:
		_mark_brush()
	_last["brush"] = forge.brush


func _hint_text() -> String:
	if forge.carry != null:
		return "CARRYING  ·  move the camera to move it  ·  WHEEL nearer / further  ·  R turn  ·  E or CLICK drop  ·  Esc drop"
	if forge.drag != null:
		return "DRAGGING  ·  slides over surfaces  ·  SHIFT lift  ·  CTRL camera plane  ·  WHEEL turn  ·  G grid"
	if forge.brush != null:
		return "PLACING %s  ·  CLICK place  ·  R turn  ·  SHIFT mid-air (SHIFT+WHEEL distance)  ·  Esc put down the brush" % String(forge.brush.name)
	if forge.paint != null:
		return "PAINTING  ·  sweep to lay a row  ·  let go to stop (one undo for the whole row)  ·  B scatter"
	if forge.marquee != null:
		return "BOX SELECT  ·  let go to pick everything inside  ·  SHIFT keeps what was picked"
	if not forge.sel.is_empty():
		return "DRAG move  ·  E carry  ·  R turn  ·  CTRL+D copy  ·  DEL delete  ·  Q use as brush  ·  F focus  ·  CTRL+Z undo  ·  Esc deselect"
	return "WASD fly  ·  RIGHT-DRAG look  ·  CLICK pick anything  ·  1-9 palette  ·  V collision view  ·  T top-down  ·  P play here  ·  F1 all keys  ·  F8 play"
