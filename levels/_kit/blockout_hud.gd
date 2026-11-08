class_name BlockoutHud
extends Control
## The kit's screen pieces (JS blockout.js mountUI, bossBar): objective panel, hold prompt, level clock, F6 checkpoint menu, boss bar. Dialogue and cutscenes have the screen to themselves.

const FONT := &"sys"

var bo: Blockout
var _panel: PanelContainer
var _zone: Label
var _task: Label
var _detail: Label
var _use: PanelContainer
var _use_key: Label
var _use_act: Label
var _use_fill: ColorRect
var _use_track: ColorRect
var _clock: Label
var _menu: PanelContainer
var _select: OptionButton
var _boss: Control
var _boss_name: Label
var _boss_lab: Label
var _boss_fill: ColorRect
var _boss_track: ColorRect


func _init(p_bo: Blockout) -> void:
	bo = p_bo
	name = "BlockoutHud"
	CrtTheme.full(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	# #bo-hud
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.position = Vector2(26, 185)
	_panel.custom_minimum_size = Vector2(345, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(16.0 / 255.0, 35.0 / 255.0, 43.0 / 255.0, 0.8)
	sb.border_width_left = 3
	sb.border_color = Color("d7a75b")
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	_panel.add_theme_stylebox_override(&"panel", sb)
	add_child(_panel)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(col)
	_zone = CrtTheme.label("", FONT, 11, Color("e4b66c"), 2)
	col.add_child(_zone)
	_task = CrtTheme.label("", FONT, 14, Color("e8ede6"))
	_task.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_task.custom_minimum_size = Vector2(310, 0)
	col.add_child(_task)
	_detail = CrtTheme.label("", FONT, 11, Color("b0c2c5"))
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size = Vector2(310, 0)
	col.add_child(_detail)
	# #bo-use
	_use = PanelContainer.new()
	_use.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var su := StyleBoxFlat.new()
	su.bg_color = Color(16.0 / 255.0, 35.0 / 255.0, 43.0 / 255.0, 0.93)
	su.set_border_width_all(1)
	su.border_color = Color("60767a")
	su.content_margin_left = 22
	su.content_margin_right = 22
	su.content_margin_top = 13
	su.content_margin_bottom = 13
	_use.add_theme_stylebox_override(&"panel", su)
	_use.custom_minimum_size = Vector2(280, 0)
	_use.visible = false
	add_child(_use)
	var uc := VBoxContainer.new()
	uc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_use.add_child(uc)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 9)
	uc.add_child(row)
	_use_key = CrtTheme.label("", FONT, 13, Color("ffd28b"))
	row.add_child(_use_key)
	_use_act = CrtTheme.label("", FONT, 13, Color("f3e4c5"))
	row.add_child(_use_act)
	_use_track = ColorRect.new()
	_use_track.color = Color("304b53")
	_use_track.custom_minimum_size = Vector2(0, 3)
	_use_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	uc.add_child(_use_track)
	_use_fill = ColorRect.new()
	_use_fill.color = Color("e7b15e")
	_use_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_use_track.add_child(_use_fill)
	# #bo-time
	_clock = CrtTheme.label("", FONT, 12, Color("becbd0"), 2)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_clock)
	# #bo-boss
	_boss = Control.new()
	_boss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss.visible = false
	add_child(_boss)
	_boss_name = CrtTheme.label("", &"vt323", 18, Color("8dffb4"), 3)
	_boss.add_child(_boss_name)
	_boss_lab = CrtTheme.label("", &"vt323", 18, Color("ffc55c"), 3)
	_boss_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_boss.add_child(_boss_lab)
	_boss_track = ColorRect.new()
	_boss_track.color = Color("031008")
	_boss_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss.add_child(_boss_track)
	_boss_fill = ColorRect.new()
	_boss_fill.color = Color("2fd46a")
	_boss_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_track.add_child(_boss_fill)
	_build_menu()
	_layout()
	resized.connect(_layout)


func _build_menu() -> void:
	_menu = PanelContainer.new()
	_menu.custom_minimum_size = Vector2(340, 0)
	_menu.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("14212c")
	sb.set_border_width_all(1)
	sb.border_color = Color("ffc55c")
	sb.set_content_margin_all(18)
	_menu.add_theme_stylebox_override(&"panel", sb)
	add_child(_menu)
	var c := VBoxContainer.new()
	_menu.add_child(c)
	c.add_child(CrtTheme.label(bo.display_name.to_upper() + " PLAYTEST", &"sysb", 14, Color("eff7fa")))
	var help := CrtTheme.label("Load any stage or objective with full health + ammo and a fresh encounter. F4 copies your x,y,z. F7 hides the guides.", FONT, 12, Color("eff7fa"))
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size = Vector2(300, 0)
	c.add_child(help)
	_select = OptionButton.new()
	c.add_child(_select)
	var go := Button.new()
	go.text = "LOAD CHECKPOINT"
	go.pressed.connect(func() -> void:
		bo.load_cp(_select.selected)
		toggle_menu())
	c.add_child(go)
	var again := Button.new()
	again.text = "RESTART CURRENT AREA"
	again.pressed.connect(func() -> void:
		bo.restart()
		toggle_menu())
	c.add_child(again)
	var close := Button.new()
	close.text = "RESUME"
	close.pressed.connect(toggle_menu)
	c.add_child(close)


func _layout() -> void:
	if _use == null:
		return
	var vp := size
	_use.position = Vector2((vp.x - _use.size.x) * 0.5, vp.y - 105.0 - _use.size.y)
	_clock.position = Vector2(vp.x - 628.0, vp.y - 27.0 - 40.0)
	_clock.size = Vector2(600.0, 40.0)
	_menu.position = Vector2(vp.x - 18.0 - 376.0, 18.0)
	var bw := minf(600.0, vp.x * 0.56)
	_boss.position = Vector2((vp.x - bw) * 0.5, 58.0)
	_boss.size = Vector2(bw, 40.0)
	_boss_name.position = Vector2.ZERO
	_boss_lab.position = Vector2(0.0, 0.0)
	_boss_lab.size = Vector2(bw, 18.0)
	_boss_track.position = Vector2(0.0, 23.0)
	_boss_track.size = Vector2(bw, 16.0)


func toggle_menu() -> void:
	var open := not _menu.visible
	_menu.visible = open
	if open:
		_select.clear()
		for c: Dictionary in bo.checkpoints:
			_select.add_item(String(c["name"]))
		Game.paused = true
		Game.ui.unlock()
	else:
		Game.paused = false
		Game.ui.lock()


## the shared boss bar (top centre, phosphor CRT): {name, f: 0..1, label, hot} shows / updates it, null hides it. A bar can mean anything that fills or drains (the Mothership's Godmother fills a RESPECT bar).
func boss_bar(b: Variant) -> void:
	_boss.visible = b != null
	if b == null:
		return
	var d: Dictionary = b
	_boss_name.text = String(d.get("name", ""))
	_boss_lab.text = String(d.get("label", ""))
	var hot: bool = d.get("hot", false)
	_boss_fill.color = Color("ffb43c") if hot else Color("2fd46a")
	_boss_fill.size = Vector2(_boss_track.size.x * clampf(float(d.get("f", 0.0)), 0.0, 1.0), _boss_track.size.y)


func update_hud(P: Player) -> void:
	var lv_cine: Variant = Game.level.get(&"cine") if Game.level != null else null
	var hidden: bool = Game.dialogue.on or Game.cutscene_on() != null or not Game.started or (lv_cine != null and lv_cine.on and lv_cine.get(&"play") != true)      # dialogue and cutscenes (letterbox bars) have the screen to themselves
	visible = not hidden
	if hidden:
		return
	var st: Dictionary = bo.cur()
	var o: Dictionary = bo.cur_obj()
	var pad := Inp.using_pad
	var finished: bool = bo.state.finished
	_zone.text = (bo.display_name.to_upper() + " / COMPLETE") if finished else "%02d %s / %s" % [int(bo.state.stage) + 1, String(st.get("name", "")).to_upper(), bo.display_name.to_upper()]
	var text: Variant = o.get("text", "")
	if text is Callable:
		text = (text as Callable).call(bo)
	var st_task := String(st.get("task", ""))
	if finished:
		_task.text = String(bo.opts.get("complete_text", "LEVEL COMPLETE"))
	else:
		var t := String(text) if String(text) != "" else st_task
		_task.text = t.replace("Hold E", "Hold B") if pad else t
	var alive := 0
	for r: Robot in bo.spawned:
		if not r.dead:
			alive += 1
	if finished:
		_detail.text = ""
	else:
		var dt := "Objective %d / %d" % [int(bo.state.obj) + 1, (st.get("objectives", []) as Array).size()]
		if alive > 0:
			dt += " · %d hostile%s" % [alive, "s" if alive > 1 else ""]
		if st_task != "" and String(text) != "":
			dt += " · " + st_task
		if o.get("guide") != false:
			dt += " · Follow blue arrows"
		_detail.text = dt
	var near: bool = o.get("kind") == "hold" and P != null and bo.in_range(P, o)
	_use.visible = near and not finished
	if _use.visible:
		_use_key.text = "HOLD B" if pad else "HOLD E"
		_use_act.text = String(o.get("prompt", "USE"))
		_use_fill.size = Vector2(_use_track.size.x * float(bo.state.progress), 3.0)
		_use.position = Vector2((size.x - _use.size.x) * 0.5, size.y - 105.0 - _use.size.y)
	if P != null and bo.guides:
		var s := int(floorf(float(bo.state.time)))
		var c := "LEVEL TIME %02d:%02d" % [s / 60, s % 60]
		if bo.dev:
			c += "\nx %.1f  y %.1f  z %.1f  (F4 copies)" % [P.x, P.y, P.z]
		_clock.text = c
	else:
		_clock.text = ""
	_panel.visible = P != null and bo.guides
