class_name MainMenu
extends Control
## The main menu, ported from index.html (main menu + start screen character select): CONTINUE / NEW GAME / LOAD GAME / LEVEL SELECT / CHARACTER SELECT / QUIT GAME on the left, DEV LEVEL at the bottom,
## panels on the right, in quiet grey over the rainy prison yard backdrop (ui/menu_scene/menu_scene.gd), which holds the list back until its opening has played.

const ITEMS: Array = [["continue", "CONTINUE"], ["new", "NEW GAME"], ["load", "LOAD GAME"], ["levels", "LEVEL SELECT"], ["chars", "CHARACTER SELECT"], ["quit", "QUIT GAME"]]
# the JS level registry's names and blurbs; the level list shows the ones that exist here, and only the ones listed there
const LEVEL_INFO := {
	"hub": ["HUBWORLD", "The noir city street: vendors, gunshop, free roam."],
	"maktar": ["FOINT ARENA", "Televised challenges, escalating rounds and cash prizes."],
	"spire": ["MEAT SPIRE", "Climb a living flesh creature, organ by organ. A warden, a heart, a boss."],
	"worldbackalley": ["BACK ALLEY", "A thunderstorm, a long straight street, gray aliens all the way down it."],
	"mothership": ["THE MOTHERSHIP", "Crash the Godmother's wedding aboard the grays' mansion-shaped UFO."],
	"apartment": ["PROG'S APARTMENT", "Home. Grimy one-bedroom over the city: save, cutscenes, the closet. No door in the hub yet."],
	"omnisphere": ["OMNISPHERE", "FOINT's top-secret plant on the magma."],
	"visiting-hours": ["VISITING HOURS", "Saltmarsh Correctional, a stormy night: get Oswald Fenn out."],
	"arena": ["TEST ARENA", "The movement and camera test floor."],
}
const LEVEL_NAMES := {
	"club": "CLUB 9", "warehouse": "WAREHOUSE ROBBERY", "dev": "DEV LEVEL", "blockout-demo": "BLOCKOUT DEMO", 
	"kame-lab": "KAME LAB", 
}

const C_ITEM := Color("9ea6ad")
const C_FOCUS := Color("ffffff")
const C_OPEN := Color("8ff09a")
const C_ARROW := Color("5fe36a")
const C_DIM := Color("6f7a83")
const C_STATE := Color("6f7a83")
const C_STATE_B := Color("c6cdd2")
const C_BTN := Color("c6cdd2")
const C_SUB := Color("7b858d")
const C_WARN := Color("ffb02e")


class TubeView extends Control:
	var m: MainMenu
	func _draw() -> void:
		if m != null:
			m._draw_tube(self)


var panel := ""
var idx := 0
var slot_mode := "load"
var slot_idx := 0
var confirm := 0
var level_pick := ""
var msg := ""
var _tube: CrtScreen
var _view: TubeView
var _rects := {}
var _lvl_ids: PackedStringArray = []
var _lvl_scroll := 0.0
var _time := 0.0
var _item_k: PackedFloat32Array = []    # the focused arrow's slide
var _panel_in := 1.0
var _fade := 1.0
var _stick_x := 0.0
var _on := false
var _f := 1.0
var _left_x := 0.0
var _panel_rect := Rect2()
var _chars: CharPreviews = null
var enabled := true
var scene: MenuScene = null
var _reveal_a := 1.0


func _init() -> void:
	name = "MainMenu"
	CrtTheme.full(self, false)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	z_index = 20
	_item_k.resize(ITEMS.size() + 1)
	for i in _item_k.size():
		_item_k[i] = 0.0


func _ready() -> void:
	_tube = CrtScreen.new(Vector2(1280, 720), "res://ui/menu_tube.gdshader")
	CrtTheme.full(_tube)
	# the list over the backdrop, under the menu's own gradient: the shared CRT look is off here (the JS menu is not a tube)
	_tube.param(&"curve", Vector2.ZERO)
	_tube.param(&"bg_center", Color(0, 0, 0, 0))
	_tube.param(&"bg_edge", Color(0, 0, 0, 0))
	_tube.param(&"vig_inner", Color(0, 0, 0, 0))
	_tube.param(&"vig_outer", Color(0, 0, 0, 0))
	_tube.param(&"glow_amount", 0.0)
	_tube.param(&"scan", 0.0)
	_tube.param(&"roll_alpha", 0.0)
	_tube.param(&"grain", 0.0)
	_tube.glitch_sound = ""
	add_child(_tube)
	_view = TubeView.new()
	_view.m = self
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tube.content.add_child(_view)
	_chars = CharPreviews.new()
	_tube.content.add_child(_chars)
	get_viewport().size_changed.connect(_layout)
	set_process(false)


func _layout() -> void:
	var vp := get_viewport_rect().size
	_tube.set_logical(vp)
	_view.size = vp
	_rebuild()


## Show or hide the menu. Coming up: the slot state, the focus, the panels closed.
func show_menu(on: bool, fade_in: bool = false) -> void:
	_on = on
	visible = on
	set_process(on)
	_tube.live = on
	_tube.arm_glitch(false)
	_chars.visible = false
	get_viewport().disable_3d = on      # (the game's world is not drawn while the backdrop is up)
	if on:
		_fade = 0.0 if fade_in else 1.0
		prepare_scene()
		enabled = false      # (the menu ignores input until the opening has played)
		_reveal_a = 0.0
		scene.begin()
		_ready_menu()
	else:
		_chars.set_active(false)
		if scene != null:
			scene.dispose()
			scene = null


## The backdrop, made once per showing: at boot behind the terminal, or behind the fade coming back from a game.
func prepare_scene() -> void:
	if scene != null:
		return
	scene = MenuScene.new()
	scene.on_reveal = func() -> void: enabled = true
	add_child(scene)
	move_child(scene, 0)
	scene.build()


func _ready_menu() -> void:
	# (menu.ready)
	panel = ""
	var ids := []
	for k: String in Game.LEVELS:
		if LEVEL_INFO.has(k):
			ids.append(k)
	_lvl_ids = PackedStringArray(ids)
	var cur := Game.level.id if Game.level != null else ""
	level_pick = cur if _lvl_ids.has(cur) else (_lvl_ids[0] if _lvl_ids.size() > 0 else "")
	var has := false
	for s: Dictionary in Game.save.slots():
		if not s.empty:
			has = true
	idx = 0
	for i in ITEMS.size():
		if not _disabled(i):
			idx = i
			break
	_layout()
	if has:
		pass


func _disabled(i: int) -> bool:
	var a: String = ITEMS[i][0]
	if a == "continue":
		return not Game.save.exists()
	if a == "load":
		for s: Dictionary in Game.save.slots():
			if not s.empty:
				return false
		return true
	return false


# ---- the JS menu object ----

## One save slot as a line of text: level, money, play time, when it was saved.
func slot_line(s: Dictionary) -> String:
	if s.get("empty", true):
		return "EMPTY"
	var m := floori(float(s.get("play_ms", 0.0)) / 60000.0)
	var t := ("%dh %02dm" % [m / 60, m % 60]) if m >= 60 else "%dm" % m
	var when := ""
	var sa: float = s.get("saved_at", 0.0)
	if sa > 0.0:
		var d := Time.get_datetime_dict_from_unix_time(int(sa / 1000.0))
		const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
		when = "%s %d %02d:%02d" % [MONTHS[int(d.month) - 1], d.day, d.hour, d.minute]
	var lv: String = s.get("level", "")
	return level_name(lv) + " · " + CrtTheme.money(float(s.get("money", 0))) + " · " + t + (" · " + when if when != "" else "")


static func level_name(id: String) -> String:
	if LEVEL_INFO.has(id):
		return LEVEL_INFO[id][0]
	if LEVEL_NAMES.has(id):
		return LEVEL_NAMES[id]
	return id.to_upper() if id != "" else "HUBWORLD"


func refresh() -> void:
	_rebuild()


func open_slots(mode: String) -> void:
	if panel == "slots" and slot_mode == mode:
		set_panel("slots")
		return
	slot_mode = mode
	confirm = 0
	slot_idx = Game.save.active - 1
	if mode == "new":
		for s: Dictionary in Game.save.slots():
			if s.empty:
				slot_idx = int(s.n) - 1
				break
	panel = ""
	set_panel("slots")


func step_slot(d: int) -> void:
	slot_idx = posmod(slot_idx + d, SaveGame.SLOT_COUNT)
	confirm = 0
	refresh()


func pick_slot() -> void:
	var s: Dictionary = Game.save.slots()[slot_idx]
	if slot_mode == "load":
		if s.empty:
			return
		if int(s.n) == Game.save.active:
			set_panel("slots")
			Game.ui.continue_game()
		else:
			Game.ui.play_slot(int(s.n), false)
		return
	if not s.empty and confirm != int(s.n):      # an occupied slot needs a second pick
		confirm = int(s.n)
		CrtTheme.menu_sound("open")
		refresh()
		return
	Game.ui.play_slot(int(s.n), true)


func set_panel(p: String) -> void:
	panel = "" if panel == p else p
	_panel_in = 0.0
	_chars.set_active(panel == "chars")
	refresh()


func act(a: String) -> void:
	if Game.started:
		return
	if panel == "levels" and a == "levels":     # A / Enter with the level list open plays the picked level
		Game.ui.launch_level(level_pick)
		return
	if panel == "slots" and a == slot_mode:
		pick_slot()
		return
	match a:
		"continue":
			if Game.save.exists():
				Game.ui.continue_game()
		"new":
			if not Game.save.exists():          # the slot in use is still empty: just start in it
				Game.ui.continue_game()
			else:
				open_slots("new")
		"load":
			open_slots("load")
		"dev":
			Game.ui.launch_level("dev" if Game.LEVELS.has("dev") else Game.DEFAULT_LEVEL)
		"quit":
			Game.ui.quit_game()
		_:
			set_panel(a)


func move(d: int) -> void:
	var count := ITEMS.size() + 1
	var i := idx
	for k in count:
		i = posmod(i + d, count)
		if i == ITEMS.size() or not _disabled(i):
			break
	idx = i
	refresh()


func _act_idx() -> String:
	return "dev" if idx >= ITEMS.size() else String(ITEMS[idx][0])


func pick_level(id: String) -> void:
	level_pick = id
	refresh()


func step_level(d: int) -> void:
	if _lvl_ids.is_empty():
		return
	var k := maxi(0, _lvl_ids.find(level_pick))
	pick_level(_lvl_ids[posmod(k + d, _lvl_ids.size())])


## The pad and keyboard, every frame while the menu is up (menu.pad + the keydown listener + charSelect.frame).
func pad() -> void:
	if not enabled:
		return
	if Inp.btn(&"d_up").pressed or Inp.key_hit(KEY_UP, true) or Inp.key_hit(KEY_W):
		move(-1)
	elif Inp.btn(&"d_down").pressed or Inp.key_hit(KEY_DOWN, true) or Inp.key_hit(KEY_S):
		move(1)
	var left: bool = Inp.btn(&"d_left").pressed or Inp.key_hit(KEY_LEFT) or (panel == "chars" and Inp.key_hit(KEY_A))
	var right: bool = Inp.btn(&"d_right").pressed or Inp.key_hit(KEY_RIGHT) or (panel == "chars" and Inp.key_hit(KEY_D))
	if panel == "levels":
		if left:
			step_level(-1)
		elif right:
			step_level(1)
	elif panel == "slots":
		if left:
			step_slot(-1)
		elif right:
			step_slot(1)
	elif panel == "chars":
		# controller: D-pad or a flick of the left stick switches
		var sx := Inp.move.x if Inp.pad_connected else 0.0
		if left:
			_chars.step(-1)
		elif right:
			_chars.step(1)
		elif absf(sx) > 0.6 and absf(_stick_x) <= 0.6:
			_chars.step(1 if sx > 0.0 else -1)
		_stick_x = sx
		if Inp.key_hit(KEY_1) or Inp.key_hit(KEY_KP_1):
			_chars.pick("prog")
		elif Inp.key_hit(KEY_2) or Inp.key_hit(KEY_KP_2):
			_chars.pick("tommy")
		if Inp.btn(&"quick").pressed:      # (a keyboard / pad way to the costume, which the browser's <select> had the mouse for)
			_chars.toggle_costume()
		refresh()
	if Inp.btn(&"jump").pressed or Inp.key_hit(KEY_ENTER) or Inp.key_hit(KEY_KP_ENTER):
		act(_act_idx())
	elif panel != "" and (Inp.btn(&"b").pressed or Inp.key_hit(KEY_ESCAPE)):
		set_panel(panel)


func _process(delta: float) -> void:
	_time += delta
	_fade = move_toward(_fade, 1.0, delta / 0.9)
	_tube.param(&"opacity", _fade)
	_panel_in = move_toward(_panel_in, 1.0, delta / 0.18)
	for i in _item_k.size():
		_item_k[i] = move_toward(_item_k[i], 1.0 if i == idx else 0.0, delta / 0.15)
	if scene != null:
		scene.frame(delta)
		if enabled:      # (#menuLeft, #menuRight: transition opacity .9s)
			_reveal_a = move_toward(_reveal_a, 1.0, delta / 0.9)
	_view.modulate.a = _reveal_a
	_chars.frame(delta, _time, panel == "chars")
	_view.queue_redraw()


# ---- layout + drawing ----

func _rebuild() -> void:
	_rects.clear()
	var vp := get_viewport_rect().size
	# #start: padding 0 6vw; #menuLeft 0 0 min(420px, 86vw), centred column
	_left_x = vp.x * 0.06
	var fs := roundi(clampf(vp.y * 0.034, 20.0, 32.0))
	var lh := fs * 1.3 + 4.0      # (.mi: padding 2px 0)
	var gap := vp.y * 0.011
	var state_h := 12.0 * 1.7 * 3.0
	var total := (lh + gap) * ITEMS.size() - gap + vp.y * 0.035 + state_h
	var y := (vp.y - total) * 0.5
	for i in ITEMS.size():
		_rects["item%d" % i] = Rect2(_left_x - fs * 1.5, y, 420.0 + fs * 1.5, lh)
		y += lh + gap
	_rects["_state"] = Rect2(_left_x, y - gap + vp.y * 0.035, 420.0, state_h)
	var ds := roundi(clampf(vp.y * 0.021, 14.0, 18.0))
	_rects["item%d" % ITEMS.size()] = Rect2(_left_x - ds * 1.5, vp.y - vp.y * 0.04 - ds * 1.3 - ds * 0.66 * 1.3, 240.0 + ds * 1.5, ds * 1.3 + ds * 0.66 * 1.3)
	# #menuRight: the panels
	var px := _left_x + minf(420.0, vp.x * 0.86) + vp.x * 0.04
	var pw := minf(560.0, vp.x - px - vp.x * 0.06)
	_panel_rect = Rect2()
	var f13 := 13.0
	if panel == "levels":
		var rows := _lvl_ids.size()
		var row_h := 20.0 * 1.1 + 4.0 + 13.0 * 1.3 + 22.0 + 2.0
		var want := 18.0 + f13 + 14.0 + rows * row_h + (rows - 1) * 8.0 + 20.0
		var ph := minf(want, vp.y - 40.0)
		_panel_rect = Rect2(px, (vp.y - ph) * 0.5, pw, ph)
		var list_y := _panel_rect.position.y + 18.0 + f13 + 14.0
		var list_h := ph - (18.0 + f13 + 14.0 + 20.0)
		var content_h := rows * row_h + (rows - 1) * 8.0
		var k := maxi(0, _lvl_ids.find(level_pick))
		var ky := k * (row_h + 8.0)
		if ky < _lvl_scroll:
			_lvl_scroll = ky
		elif ky + row_h > _lvl_scroll + list_h:
			_lvl_scroll = ky + row_h - list_h
		_lvl_scroll = clampf(_lvl_scroll, 0.0, maxf(0.0, content_h - list_h))
		for i in rows:
			_rects["lv:" + _lvl_ids[i]] = Rect2(px + 20.0, list_y + i * (row_h + 8.0) - _lvl_scroll, pw - 40.0, row_h)
		_rects["_list"] = Rect2(px + 20.0, list_y, pw - 40.0, list_h)
	elif panel == "slots":
		var row_h := 20.0 * 1.1 + 4.0 + 13.0 * 1.3 + 22.0 + 2.0
		var n := SaveGame.SLOT_COUNT
		var ph := 18.0 + f13 + 14.0 + n * row_h + (n - 1) * 8.0 + 20.0
		_panel_rect = Rect2(px, (vp.y - ph) * 0.5, pw, ph)
		var ly := _panel_rect.position.y + 18.0 + f13 + 14.0
		for i in n:
			_rects["sl:%d" % i] = Rect2(px + 20.0, ly + i * (row_h + 8.0), pw - 40.0, row_h)
	elif panel == "chars":
		var ph := 18.0 + f13 + 14.0 + 276.0 + 14.0 + 18.0 + 5.0 + 40.0 + 20.0
		_panel_rect = Rect2(px, (vp.y - ph) * 0.5, pw, ph)
		var cy := _panel_rect.position.y + 18.0 + f13 + 14.0
		var cw := (pw - 40.0 - 14.0) * 0.5
		_rects["ch:prog"] = Rect2(px + 20.0, cy, cw, 276.0)
		_rects["ch:tommy"] = Rect2(px + 20.0 + cw + 14.0, cy, cw, 276.0)
		_rects["costume"] = Rect2(px + 20.0, cy + 276.0 + 14.0 + 18.0 + 5.0, pw - 40.0, 40.0)
		_chars.place(_rects["ch:prog"], _rects["ch:tommy"])
	_tube.refresh()


func _draw_tube(v: Control) -> void:
	var vp := v.size
	var fw := CrtTheme.font(&"raj600")
	var fs := roundi(clampf(vp.y * 0.034, 20.0, 32.0))
	var sp := fs * 0.17
	for i in ITEMS.size():
		var r: Rect2 = _rects.get("item%d" % i, Rect2())
		var a: String = ITEMS[i][0]
		var dis := _disabled(i)
		var col := C_ITEM
		if i == idx:
			col = C_FOCUS
		elif a == panel or (panel == "slots" and a == slot_mode):
			col = C_OPEN
		if dis:
			col.a = 0.4
		var y := CrtTheme.baseline(fw, fs, r.position.y, r.size.y)
		CrtTheme.draw_text(v, fw, _left_x, y, ITEMS[i][1], fs, col, sp)
		_arrow(v, i, r, fs)
	# #menuState
	var st: Rect2 = _rects.get("_state", Rect2())
	var fr := CrtTheme.font(&"raj600")
	var cur: Dictionary = Game.save.slots()[Game.save.active - 1]
	var lh := 12.0 * 1.7
	var ty := st.position.y
	var ex := CrtTheme.draw_text(v, fr, _left_x, CrtTheme.baseline(fr, 12, ty, lh), "SLOT %d " % Game.save.active, 12, C_STATE, 2.88)
	var line := slot_line(cur).to_upper()
	var wrap_w := 420.0 - (ex - _left_x)
	var lines := CrtTheme.wrap(fr, line, 12, wrap_w, 2.88)
	for l in lines:
		CrtTheme.draw_text(v, fr, ex if l == lines[0] else _left_x, CrtTheme.baseline(fr, 12, ty, lh), l, 12, C_STATE_B, 2.88)
		ty += lh
	var ce := CrtTheme.draw_text(v, fr, _left_x, CrtTheme.baseline(fr, 12, ty, lh), "CHARACTER ", 12, C_STATE, 2.88)
	CrtTheme.draw_text(v, fr, ce, CrtTheme.baseline(fr, 12, ty, lh), Builds.BUILDS[Game.char_pick].name.to_upper(), 12, C_STATE_B, 2.88)
	if msg != "":
		CrtTheme.draw_text(v, fr, _left_x, CrtTheme.baseline(fr, 12, ty + lh, lh), msg, 12, C_OPEN, 2.4)
	# #devWrap
	var di := ITEMS.size()
	var dr: Rect2 = _rects.get("item%d" % di, Rect2())
	var ds := roundi(clampf(vp.y * 0.021, 14.0, 18.0))
	var dcol := C_FOCUS if idx == di else C_DIM
	CrtTheme.draw_text(v, fw, _left_x, CrtTheme.baseline(fw, ds, dr.position.y, ds * 1.3), "DEV LEVEL", ds, dcol, ds * 0.24)
	var ss := roundi(ds * 0.66)
	CrtTheme.draw_text(v, fw, _left_x, CrtTheme.baseline(fw, ss, dr.position.y + ds * 1.3, ss * 1.3), "TESTING TOOLS & SPAWNER", ss, Color("4d565e"), ss * 0.2)
	_arrow(v, di, dr, ds)
	# the panel
	if panel != "":
		_draw_panel(v)


func _arrow(v: Control, i: int, r: Rect2, fs: int) -> void:
	var k: float = _item_k[i]
	if k <= 0.0:
		return
	# ::before: a right-pointing triangle, sliding in 6 px
	var x := r.position.x + fs * 0.3 + (k - 1.0) * 6.0
	var cy := r.position.y + r.size.y * 0.5
	var h := fs * 0.36
	var w := fs * 0.56
	var c := Color(C_ARROW.r, C_ARROW.g, C_ARROW.b, k)
	v.draw_colored_polygon(PackedVector2Array([Vector2(x, cy - h), Vector2(x + w, cy), Vector2(x, cy + h)]), c)


func _draw_panel(v: Control) -> void:
	var r := _panel_rect
	var off := (1.0 - _panel_in) * -10.0
	var a := _panel_in
	var x := r.position.x + off
	# .mpanel
	v.draw_rect(Rect2(x, r.position.y, r.size.x, r.size.y), Color(3.0 / 255.0, 6.0 / 255.0, 9.0 / 255.0, 0.74 * a))
	v.draw_rect(Rect2(x, r.position.y, r.size.x, r.size.y), Color(143.0 / 255.0, 240.0 / 255.0, 154.0 / 255.0, 0.14 * a), false, 1.0)
	v.draw_rect(Rect2(x, r.position.y, 2.0, r.size.y), Color(95.0 / 255.0, 227.0 / 255.0, 106.0 / 255.0, 0.55 * a))
	var fh := CrtTheme.font(&"raj600")
	var title := "SELECT LEVEL"
	if panel == "slots":
		title = "NEW GAME  /  PICK A SLOT" if slot_mode == "new" else "LOAD GAME"
	elif panel == "chars":
		title = "SELECT CHARACTER"
	CrtTheme.draw_text(v, fh, x + 20.0, CrtTheme.baseline(fh, 13, r.position.y + 18.0, 13.0), title, 13, Color(143.0 / 255.0, 240.0 / 255.0, 154.0 / 255.0, a), 13.0 * 0.34)
	if panel == "levels":
		var clip: Rect2 = _rects.get("_list", Rect2())
		for id in _lvl_ids:
			var b: Rect2 = _rects["lv:" + id]
			if b.end.y < clip.position.y or b.position.y > clip.end.y:
				continue
			var info: Array = LEVEL_INFO.get(id, [id.to_upper(), ""])
			_entry(v, b, info[0], info[1], id == level_pick, false, false, clip)
	elif panel == "slots":
		var ss: Array = Game.save.slots()
		for i in ss.size():
			var s: Dictionary = ss[i]
			var b: Rect2 = _rects["sl:%d" % i]
			var warn := confirm == int(s.n)
			var t := "SLOT %d" % int(s.n) + ("  ◂" if int(s.n) == Game.save.active else "")
			var sub := "OVERWRITE THIS SAVE? PICK IT AGAIN TO START OVER" if warn else slot_line(s)
			_entry(v, b, t, sub, slot_idx == i, warn, slot_mode == "load" and s.empty, Rect2())
	elif panel == "chars":
		_draw_chars(v)


## One button of the level / slot lists.
func _entry(v: Control, b: Rect2, title: String, sub: String, on: bool, warn: bool, dis: bool, clip: Rect2) -> void:
	var a := 0.35 if dis else 1.0
	var bd := Color(200.0 / 255.0, 210.0 / 255.0, 220.0 / 255.0, 0.12)
	var col := C_BTN
	var sc := C_SUB
	if on:
		bd = Color(95.0 / 255.0, 227.0 / 255.0, 106.0 / 255.0)
		col = C_OPEN
	if warn:
		bd = C_WARN
		col = C_WARN
		sc = C_WARN
	bd.a *= a
	col.a *= a
	sc.a *= a
	var rect := b
	if clip.size.y > 0.0:
		# scrolled lists: the row is cut at the panel's edge
		var top := maxf(b.position.y, clip.position.y)
		var bot := minf(b.end.y, clip.end.y)
		rect = Rect2(b.position.x, top, b.size.x, bot - top)
	v.draw_rect(rect, Color(10.0 / 255.0, 14.0 / 255.0, 18.0 / 255.0, 0.6 * a))
	if on:
		CrtTheme.glow_box(v, rect, Color(95.0 / 255.0, 227.0 / 255.0, 106.0 / 255.0, 0.14), 2.0)
	v.draw_rect(rect, bd, false, 1.0)
	if clip.size.y > 0.0 and (b.position.y < clip.position.y or b.end.y > clip.end.y):
		return     # a part row keeps its box but not its text
	var fb := CrtTheme.font(&"raj600")
	var fs := CrtTheme.font(&"raj500")
	var x := b.position.x + 16.0
	var y := b.position.y + 11.0
	CrtTheme.draw_text(v, fb, x, CrtTheme.baseline(fb, 20, y, 22.0), title, 20, col, 3.6)
	var sy := y + 22.0 + 4.0
	var room := b.size.x - 32.0
	var line := sub
	if CrtTheme.text_w(fs, line, 13, 0.78) > room:
		while line.length() > 1 and CrtTheme.text_w(fs, line + "…", 13, 0.78) > room:
			line = line.substr(0, line.length() - 1)
		line += "…"
	CrtTheme.draw_text(v, fs, x, CrtTheme.baseline(fs, 13, sy, 13.0 * 1.3), line, 13, sc, 0.78)


func _draw_chars(v: Control) -> void:
	var fb := CrtTheme.font(&"raj700")
	var fs := CrtTheme.font(&"raj500")
	var fh := CrtTheme.font(&"raj600")
	for id: String in ["prog", "tommy"]:
		var r: Rect2 = _rects["ch:" + id]
		var sel := Game.char_pick == id
		v.draw_rect(r, Color(10.0 / 255.0, 14.0 / 255.0, 18.0 / 255.0, 0.45))
		if sel:
			CrtTheme.glow_box(v, r, Color(95.0 / 255.0, 227.0 / 255.0, 106.0 / 255.0, 0.16), 2.0)
		v.draw_rect(r, Color("5fe36a") if sel else Color(143.0 / 255.0, 240.0 / 255.0, 154.0 / 255.0, 0.14), false, 1.0)
		if sel:
			CrtTheme.draw_text(v, fh, r.position.x + 10.0, r.position.y + 19.0, "▶ SELECTED", 11, Color("8ff09a"), 2.0)
		var cy := r.position.y + 8.0 + 190.0 + 6.0
		CrtTheme.draw_center(v, fb, r.position.x + r.size.x * 0.5, CrtTheme.baseline(fb, 18, cy, 22.0), Builds.BUILDS[id].name.to_upper(), 18, Color("8ff09a") if sel else Color("ffffff"), 18.0 * 0.24)
		const BLURB := {"prog": "Peak performance. The PERFECT weapon. #1 Fat Fuck.", "tommy": "Aura"}
		var yy := cy + 24.0
		for l in CrtTheme.wrap(fs, BLURB[id], 13, r.size.x - 20.0):
			CrtTheme.draw_center(v, fs, r.position.x + r.size.x * 0.5, CrtTheme.baseline(fs, 13, yy, 16.0), l, 13, C_SUB)
			yy += 16.0
	var c: Rect2 = _rects["costume"]
	CrtTheme.draw_text(v, fh, c.position.x, c.position.y - 6.0, "PROG COSTUME", 13, C_STATE_B, 2.0)
	v.draw_rect(c, Color(10.0 / 255.0, 14.0 / 255.0, 18.0 / 255.0, 0.8))
	v.draw_rect(c, Color(143.0 / 255.0, 240.0 / 255.0, 154.0 / 255.0, 0.4), false, 1.0)
	var cn := "Prog V2" if Builds.prog_costume == "prog_v2" else ("Prog V3" if Builds.prog_costume == "prog_v3" else "Prog V1")
	CrtTheme.draw_text(v, fs, c.position.x + 12.0, CrtTheme.baseline(fs, 16, c.position.y, c.size.y), cn, 16, C_FOCUS)
	CrtTheme.draw_right(v, fh, c.end.x - 12.0, CrtTheme.baseline(fh, 12, c.position.y, c.size.y), "Y / Q  CHANGE  ▾", 12, C_SUB, 1.0)


# ---- the mouse ----

func _gui_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseMotion:
		var p: Vector2 = (event as InputEventMouseMotion).position
		for i in ITEMS.size() + 1:
			if i < ITEMS.size() and _disabled(i):
				continue
			if (_rects.get("item%d" % i, Rect2()) as Rect2).has_point(p):
				if idx != i:
					idx = i
					refresh()
				return
		if panel == "slots":
			for i in SaveGame.SLOT_COUNT:
				if (_rects.get("sl:%d" % i, Rect2()) as Rect2).has_point(p) and slot_idx != i:
					slot_idx = i
					refresh()
	elif event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		if panel == "levels" and b.pressed and (b.button_index == MOUSE_BUTTON_WHEEL_DOWN or b.button_index == MOUSE_BUTTON_WHEEL_UP):
			step_level(1 if b.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1)
			return
		if b.button_index != MOUSE_BUTTON_LEFT or not b.pressed:
			return
		var p := b.position
		for i in ITEMS.size() + 1:
			if i < ITEMS.size() and _disabled(i):
				continue
			if (_rects.get("item%d" % i, Rect2()) as Rect2).has_point(p):
				idx = i
				act(_act_idx())
				return
		if panel == "levels":
			var clip: Rect2 = _rects.get("_list", Rect2())
			for id in _lvl_ids:
				var r: Rect2 = _rects["lv:" + id]
				if r.has_point(p) and clip.has_point(p):      # a level button plays it, with this slot's gear
					pick_level(id)
					Game.ui.launch_level(id)
					return
		elif panel == "slots":
			for i in SaveGame.SLOT_COUNT:
				if (_rects.get("sl:%d" % i, Rect2()) as Rect2).has_point(p):
					slot_idx = i
					pick_slot()
					return
		elif panel == "chars":
			for id: String in ["prog", "tommy"]:
				if (_rects["ch:" + id] as Rect2).has_point(p):
					_chars.pick(id)
					refresh()
					return
			if (_rects["costume"] as Rect2).has_point(p):
				_chars.toggle_costume()
				refresh()
