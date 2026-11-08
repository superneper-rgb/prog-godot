class_name WhMissionHud
extends CanvasLayer
## The warehouse objective HUD (JS levels/warehouse/mission-hud.js): a phosphor CRT plate with the department, the goal and a checklist of steps, the hold-to-use prompt, the department title card and the Foreman's bar.

const STATUS := {"ram": "FREIGHT RAM", "purge": "DECK PURGE", "salvo": "MISSILE SALVO", "stamp": "HAMMER", "sweep": "LOW SWEEP", "burst": "RIVETS", "pound": "SHOCKWAVES", "drop": "CARGO", "link": "OVERTIME"}
const PH := Color("#7dffa0")
const DIM := Color("#3f9a5f")
const AMB := Color("#ffc25a")
const BRIGHT := Color("#b8ffc9")
const FONT := "res://assets/fonts/VT323-Regular.ttf"

var plate: PanelContainer
var zone: Label
var count: Label
var goal: Label
var list: VBoxContainer
var tip: Label
var prompt: PanelContainer
var key: Label
var action: Label
var fill: ColorRect
var card_box: VBoxContainer
var card_no: Label
var card_name: Label
var card_line: Label
var card_t := 0.0
var boss: PanelContainer
var boss_title: Label
var boss_fill: ColorRect
var last_list := "?"
var font: Font


func _lab(parent: Control, size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override(&"font", font)
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _plate(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_border_width_all(2)
	s.border_color = Color("#4a4d3e")
	s.set_corner_radius_all(7)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 10
	return s


func _ready() -> void:
	layer = 4
	font = load(FONT)
	plate = PanelContainer.new()
	plate.add_theme_stylebox_override(&"panel", _plate(Color("#0a2214f2")))
	plate.position = Vector2(16, 160)
	plate.custom_minimum_size = Vector2(330, 0)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plate)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(col)
	var row := HBoxContainer.new()
	col.add_child(row)
	zone = _lab(row, 18, DIM)
	zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count = _lab(row, 18, DIM)
	goal = _lab(col, 24, BRIGHT)
	goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal.custom_minimum_size.x = 300
	list = VBoxContainer.new()
	col.add_child(list)
	tip = _lab(col, 20, AMB)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size.x = 300
	prompt = PanelContainer.new()
	prompt.add_theme_stylebox_override(&"panel", _plate(Color("#061509f0")))
	prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt.grow_vertical = Control.GROW_DIRECTION_BEGIN
	prompt.position.y = -105.0
	prompt.custom_minimum_size = Vector2(280, 0)
	prompt.visible = false
	add_child(prompt)
	var pc := VBoxContainer.new()
	prompt.add_child(pc)
	var pr := HBoxContainer.new()
	pr.alignment = BoxContainer.ALIGNMENT_CENTER
	pc.add_child(pr)
	key = _lab(pr, 24, PH)
	action = _lab(pr, 24, BRIGHT)
	var tr := ColorRect.new()
	tr.color = Color("#173822")
	tr.custom_minimum_size = Vector2(256, 4)
	pc.add_child(tr)
	fill = ColorRect.new()
	fill.color = PH
	fill.size = Vector2(0, 4)
	tr.add_child(fill)
	card_box = VBoxContainer.new()
	card_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	card_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card_box.position.y = 120.0
	card_box.alignment = BoxContainer.ALIGNMENT_CENTER
	card_box.modulate.a = 0.0
	card_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card_box)
	card_no = _lab(card_box, 16, Color("#5dc982"))
	card_name = _lab(card_box, 52, BRIGHT)
	card_line = _lab(card_box, 21, PH)
	for l: Label in [card_no, card_name, card_line]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss = PanelContainer.new()
	boss.add_theme_stylebox_override(&"panel", _plate(Color("#061509e8")))
	boss.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss.grow_horizontal = Control.GROW_DIRECTION_BOTH
	boss.position.y = 24.0
	boss.custom_minimum_size = Vector2(480, 0)
	boss.visible = false
	add_child(boss)
	var bc := VBoxContainer.new()
	boss.add_child(bc)
	boss_title = _lab(bc, 18, BRIGHT)
	var bt := ColorRect.new()
	bt.color = Color("#173822")
	bt.custom_minimum_size = Vector2(456, 8)
	bc.add_child(bt)
	boss_fill = ColorRect.new()
	boss_fill.color = PH
	boss_fill.size = Vector2(456, 8)
	bt.add_child(boss_fill)


## the department's title across the screen for a few seconds
func card(p: Dictionary) -> void:
	card_no.text = "DEPARTMENT %02d OF %d" % [p.no, p.total]
	card_name.text = p.name
	card_line.text = p.get("card", "")
	card_t = 3.4


func update(state: Dictionary, hud: Dictionary, pad: bool) -> void:
	var dt: float = Game.frame_real_dt
	card_t = maxf(0.0, card_t - dt)
	card_box.modulate.a = move_toward(card_box.modulate.a, 1.0 if card_t > 0.0 else 0.0, dt / 0.35)
	var plan: Variant = state.plan
	zone.text = plan.name if plan != null else ""
	count.text = "%d/%d" % [plan.no, plan.total] if plan != null else ""
	var fin: bool = state.finished
	goal.text = "ROBBERY COMPLETE" if fin else (plan.goal if plan != null else "")
	# A single line (the jump course, the chase) shows what to do now in place of a list.
	var rows: Array = []
	if plan != null:
		if (plan.steps as Array).size() > 0:
			rows = plan.steps
		elif plan.hint != null and not fin:
			rows = [{"text": plan.hint, "now": true, "done": false}]
	var sig := ""
	for r: Dictionary in rows:
		sig += ("x" if r.done else (">" if r.now else "-")) + String(r.text) + "|"
	if sig != last_list:
		last_list = sig
		for c: Node in list.get_children():
			c.queue_free()
		for r: Dictionary in rows:
			var q := _lab(list, 20, DIM if r.done else (PH if r.now else DIM))
			q.text = ("✓ " if r.done else ("▸ " if r.now else "· ")) + String(r.text)
			q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			q.custom_minimum_size.x = 300
	var lesson: Variant = state.lesson
	tip.text = lesson if lesson != null else ""
	tip.visible = lesson != null
	var use: String = hud.get("near_id", "")
	prompt.visible = use != "" and not fin
	if use != "":
		key.text = "HOLD B  " if pad else "HOLD E  "
		action.text = hud.get("use_label", "")
		fill.size.x = 256.0 * float(hud.get("progress", 0.0))
	var b: Variant = state.boss
	var fighting: bool = b != null and state.flags.get("bossStarted", false) and not state.flags.get("finaleClear", false)
	plate.visible = not fighting
	boss.visible = b != null and b.mode != "waiting" and b.mode != "dead" and not fin
	if boss.visible:
		var status: String = "POWERING UP" if b.mode == "intro" else ("RECONFIGURING" if b.mode == "transition" else ("DISABLED" if b.mode == "dying" else ("EYE OPEN: SHOOT IT" if b.exposed else ("SHUTTERS" if b.move == "recover" else STATUS.get(b.move, "HUNTING")))))
		boss_title.text = "THE FOREMAN · PHASE %d · %s" % [b.phase, status]
		boss_fill.size.x = 456.0 * float(b.hp) / float(b.max)
		boss_fill.color = AMB if b.hit_part == "armor" and float(b.flash) > 0.1 else PH
