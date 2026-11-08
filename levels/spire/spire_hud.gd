class_name SpireHud
extends CanvasLayer
## MEAT SPIRE's own HUD (JS levels/spire/level.js buildHud, hudUpdate): the giant boss bar (the Mawmother or the Warden), the banner, the room cards and THE CLIMB panel.

var L: SpireLevel
var bar: Control
var nm: Label
var fl: ColorRect
var gh: ColorRect
var sb: Label
var ticks: Array[ColorRect] = []
var track: Panel
var track_style: StyleBoxFlat
var banner_box: VBoxContainer
var ban_h: Label
var ban_s: Label
var room_box: VBoxContainer
var room_h: Label
var room_s: Label
var climb: PanelContainer
var height: Label
var meter: ColorRect
var meter_bg: ColorRect
var save: Label
var objective: Label
var banner_t := 0.0
var room_t := 0.0
var _bar_a := 0.0
var _gh_w := 1.0
var _fl_w := 1.0


func _init(level: SpireLevel) -> void:
	L = level
	layer = 6


func _font(bold: bool) -> Font:
	return load("res://assets/fonts/Rajdhani-Bold.ttf" if bold else "res://assets/fonts/Rajdhani-SemiBold.ttf")


func _label(parent: Node, size: int, col: Color, bold: bool, glow: Color = Color(0, 0, 0, 0)) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override(&"font", _font(bold))
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", col)
	if glow.a > 0.0:
		l.add_theme_color_override(&"font_shadow_color", glow)
		l.add_theme_constant_override(&"shadow_offset_x", 0)
		l.add_theme_constant_override(&"shadow_offset_y", 1)
		l.add_theme_constant_override(&"shadow_outline_size", 8)
	parent.add_child(l)
	return l


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# the boss bar
	bar = Control.new()
	bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.modulate.a = 0.0
	root.add_child(bar)
	nm = _label(bar, 22, Color("#ffd6dc"), true, Color(1.0, 0.16, 0.29, 0.8))
	track = Panel.new()
	track_style = StyleBoxFlat.new()
	track_style.bg_color = Color(18.0 / 255.0, 2.0 / 255.0, 6.0 / 255.0, 0.82)
	track_style.set_border_width_all(2)
	track_style.border_color = Color("#ffb0bc")
	track_style.set_corner_radius_all(4)
	track_style.shadow_color = Color(1.0, 0.157, 0.275, 0.45)
	track_style.shadow_size = 8
	track.add_theme_stylebox_override(&"panel", track_style)
	bar.add_child(track)
	gh = ColorRect.new()
	gh.color = Color(1.0, 1.0, 1.0, 0.27)
	track.add_child(gh)
	fl = ColorRect.new()
	fl.color = Color("#c8102e")
	track.add_child(fl)
	for k: float in [0.66, 0.33]:
		var t := ColorRect.new()
		t.color = Color(0.0, 0.0, 0.0, 0.8)
		t.set_meta("k", k)
		track.add_child(t)
		ticks.append(t)
	sb = _label(bar, 15, Color("#ffb8c2"), false)
	# the banner
	banner_box = VBoxContainer.new()
	banner_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	banner_box.anchor_top = 0.34
	banner_box.anchor_bottom = 0.34
	banner_box.offset_top = -40.0
	banner_box.offset_bottom = 40.0
	banner_box.alignment = BoxContainer.ALIGNMENT_CENTER
	banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_box.modulate.a = 0.0
	root.add_child(banner_box)
	ban_h = _label(banner_box, 44, Color("#ffe9ee"), true, Color(1.0, 0.16, 0.29, 0.85))
	ban_s = _label(banner_box, 18, Color("#ffb8c2"), false)
	# the room card
	room_box = VBoxContainer.new()
	room_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	room_box.anchor_top = 0.84
	room_box.anchor_bottom = 0.84
	room_box.offset_top = -50.0
	room_box.offset_bottom = 10.0
	room_box.alignment = BoxContainer.ALIGNMENT_CENTER
	room_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room_box.modulate.a = 0.0
	root.add_child(room_box)
	room_h = _label(room_box, 30, Color("#ffdce2"), true, Color(1.0, 0.16, 0.29, 0.75))
	room_s = _label(room_box, 14, Color("#ffb0bc"), false)
	# THE CLIMB
	climb = PanelContainer.new()
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color("#16050dcc")
	cs.set_border_width_all(1)
	cs.border_color = Color("#ff9ab03b")
	cs.set_corner_radius_all(8)
	cs.set_content_margin_all(13.0)
	climb.add_theme_stylebox_override(&"panel", cs)
	climb.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	climb.offset_left = -288.0
	climb.offset_right = -18.0
	climb.offset_top = -160.0
	climb.offset_bottom = -28.0
	climb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(climb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 2)
	climb.add_child(v)
	var title := _label(v, 19, Color("#fff0f3"), true)
	title.text = "THE CLIMB"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	height = _label(v, 13, Color("#ffcad4"), false)
	height.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	meter_bg = ColorRect.new()
	meter_bg.color = Color("#ff9ab02b")
	meter_bg.custom_minimum_size = Vector2(0.0, 3.0)
	v.add_child(meter_bg)
	meter = ColorRect.new()
	meter.color = Color("#8dffc8")
	meter_bg.add_child(meter)
	save = _label(v, 13, Color("#ffcad4"), false)
	save.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	objective = _label(v, 12, Color("#f2a9bb"), false)
	objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func banner(h: String, sub: String, secs: float) -> void:
	ban_h.text = h
	ban_s.text = sub
	banner_t = secs


func room_card(r: Dictionary) -> void:
	if not r.has("title"):
		return
	room_h.text = String(r.title)
	room_s.text = String(r.get("sub", ""))
	room_t = 3.2


func update_hud(dt: float) -> void:
	var P := L.last_p
	var B := L.boss
	climb.visible = P != null and not L.cine.on      # the entrance cutscene has the screen to itself
	if P != null:
		var h := clampf(P.y, 0.0, L.TOP_Y)
		height.text = "%d m / %d m" % [floori(h), int(L.TOP_Y)]
		meter.size = Vector2(meter_bg.size.x * h / L.TOP_Y, 3.0)
		save.text = "CHECKPOINT · " + String(L.checkpoints_[L.cp_idx].name).to_upper()
		var active: Dictionary = {}
		for z: Dictionary in L.zones:
			if z.has("lock") and z.lock.state in ["closing", "fight", "between"]:
				active = z
				break
		if B.mode == "dead":
			objective.text = "THE SPIRE IS YOURS"
		elif not active.is_empty():
			var lk: Dictionary = active.lock
			var s := "WAVE %d / %d" % [int(lk.wave) + 1, (lk.waves as Array).size()]
			if lk.state == "between":
				s += " · INCOMING"
			else:
				if L.last_combat != null:
					var n := 0
					for r: Robot in L.last_combat.enemies.robots:
						if not r.dead and r.zone == active:
							n += 1
					s += " · %d LEFT" % n
				var hints: Array = lk.get("hints", [])
				if int(lk.wave) < hints.size():
					s += " · " + String(hints[int(lk.wave)])
			objective.text = s
		elif B.mode == "fight" or B.mode == "intro":
			objective.text = "DEFEAT THE MAWMOTHER"
		else:
			objective.text = String(L.cur_room.get("sub", "CLIMB THE LIVING SPIRE"))
	banner_t = maxf(0.0, banner_t - dt)
	banner_box.modulate.a = move_toward(banner_box.modulate.a, 1.0 if banner_t > 0.0 else 0.0, dt / 0.8)
	room_t = maxf(0.0, room_t - dt)
	room_box.modulate.a = move_toward(room_box.modulate.a, 1.0 if room_t > 0.0 else 0.0, dt / 1.0)
	# which boss bar? the Mawmother while her fight runs, else a living mid-boss robot that is fighting near you
	var name_ := ""
	var f := 0.0
	var label := ""
	var ph2 := false
	var ex := false
	var on := false
	if B.mode == "intro" or B.mode == "fight" or B.mode == "dying":
		on = true
		name_ = SpireBoss.NAME
		f = B.T.hp / B.T.max if B.T != null else 0.0
		label = "IT WAKES" if B.mode == "intro" else ("" if B.mode == "dying" else B.label)
		ph2 = B.phase >= 2
		ex = B.exposed
	elif L.last_combat != null and P != null:
		for r: Robot in L.last_combat.enemies.robots:
			var bb: Variant = r.get("boss_bar")
			if bb != null and bb != "" and not r.dead and r.state != &"idle" and U.hyp(r.x - P.x, r.z - P.z) < 40.0 and absf(r.y - P.y) < 12.0:
				on = true
				name_ = bb
				f = r.hp / r.max
				label = String(r.get("move_label"))
				ph2 = r.get("enraged") == true
				ex = r.get("exposed") == true
				break
	_bar_a = move_toward(_bar_a, 1.0 if on else 0.0, dt / 0.5)
	bar.modulate.a = _bar_a
	bar.visible = _bar_a > 0.0
	if not bar.visible:
		return
	var vw := bar.get_viewport_rect().size.x
	var w := minf(780.0, vw * 0.74)
	bar.position = Vector2(vw * 0.5 - w * 0.5, 12.0)
	nm.position = Vector2.ZERO
	nm.size = Vector2(w, 30.0)
	if name_ != "":
		nm.text = name_
	track.position = Vector2(0.0, 32.0)
	track.size = Vector2(w, 26.0)
	sb.position = Vector2(0.0, 62.0)
	sb.size = Vector2(w, 20.0)
	sb.text = label
	sb.add_theme_color_override(&"font_color", Color("#ffe24a") if ex else Color("#ffb8c2"))
	track_style.border_color = Color("#ffe24a") if ph2 else Color("#ffb0bc")
	var k := clampf(f, 0.0, 1.0)
	_fl_w = move_toward(_fl_w, k, dt / 0.12)
	_gh_w = move_toward(_gh_w, k, dt / 0.9)
	var iw := w - 4.0
	fl.position = Vector2(2.0, 2.0)
	fl.size = Vector2(iw * _fl_w, 22.0)
	gh.position = Vector2(2.0, 2.0)
	gh.size = Vector2(iw * _gh_w, 22.0)
	var hk := B.hit_k if name_ == SpireBoss.NAME else 0.0
	fl.color = (Color("#ffc020") if ex else Color("#c8102e")) * (1.0 + hk * (0.9 if ex else 0.35))
	fl.color.a = 1.0
	for t: ColorRect in ticks:      # the phase lines (66 % / 33 %) are hers only
		t.visible = name_ == SpireBoss.NAME
		t.position = Vector2(2.0 + iw * float(t.get_meta("k")), 2.0)
		t.size = Vector2(3.0, 22.0)
