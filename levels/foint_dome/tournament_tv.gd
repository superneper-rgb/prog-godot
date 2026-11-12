class_name TournamentTV
extends Node
## FOINT DOME's giant screen (JS tournament-tv.js): the broadcast picture, the camera flight up to it, and the challenge menu shown on it. ENGINE DIFFERENCE: the JS lays a CSS3D panel over a canvas picture; here both are Controls in one SubViewport drawn on the screen's quad, and the mouse is mapped onto it through the camera.

const SCREEN_W := 10.602
const SCREEN_H := 4.05
const SCREEN_AT := Vector3(0.0, 7.585, 24.515)
const FLY := 1.65

var level: FointDomeLevel
var vp: SubViewport
var picture: MeshInstance3D
var broadcast_root: Control
var menu_root: Control
var scan: ColorRect
var status_box: PanelContainer
var status_lab: Label
var selected := 0
var flight: Variant = null             # {from, gaze, to_pos, to_look, t, duration, done}
var active := false
var settled := false
var signature := ""
var sig := ""
var pad_time := 0.0
var pad_dir := 0
var shot := View.Shot.new(Vector3.ZERO, Vector3.FORWARD, 48.0)
var _rows: Array[Button] = []
var _wallet: Label
var _tag: Label
var _title: Label
var _desc: Label
var _prize: Label
var _record: Label
var _enter: Button
var _message: Label
var _b_name: Label
var _b_line: Label
var _body_font: Font
var _head_font: FontVariation
var _ui_hidden := false


func _init(p_level: FointDomeLevel) -> void:
	level = p_level


func _ready() -> void:
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Trebuchet MS", "Arial", "sans-serif"])
	_body_font = sf
	_head_font = FontVariation.new()
	_head_font.base_font = load("res://assets/fonts/Cinzel-Variable.ttf")
	_head_font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 900}
	_head_font.spacing_glyph = 1
	vp = SubViewport.new()
	vp.size = Vector2i(1100, 420)
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.handle_input_locally = true
	vp.gui_disable_input = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	_build_broadcast()
	_build_menu()
	scan = ColorRect.new()
	scan.size = Vector2(1100, 420)
	scan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = "shader_type canvas_item; void fragment() { COLOR = vec4(0.0, 0.0, 0.0, mod(FRAGCOORD.y, 4.0) >= 3.0 ? 0.033 : 0.0); }"
	sm.shader = sh
	scan.material = sm
	vp.add_child(scan)
	var q := QuadMesh.new()
	q.size = Vector2(SCREEN_W, SCREEN_H)
	picture = MeshInstance3D.new()
	picture.mesh = q
	var pm := ShaderMaterial.new()
	pm.shader = load("res://levels/shaders/arena_screen.gdshader")
	pm.set_shader_parameter(&"screen", vp.get_texture())
	picture.material_override = pm
	picture.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	picture.position = SCREEN_AT
	picture.rotation.y = PI
	level.add_child(picture)
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	status_box = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#140e0fe6")
	sb.set_border_width_all(1)
	sb.border_color = Color("#8a1824")
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	status_box.add_theme_stylebox_override(&"panel", sb)
	status_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	status_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	status_box.position.y = 70.0
	status_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_lab = Label.new()
	status_lab.add_theme_font_override(&"font", _head_font)
	status_lab.add_theme_font_size_override(&"font_size", 13)
	status_lab.add_theme_color_override(&"font_color", Color("#ff8a7a"))
	status_box.add_child(status_lab)
	status_box.visible = false
	layer.add_child(status_box)


func _lab(parent: Control, text: String, size: int, col: Color, at: Vector2, w: float = 0.0, head: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.position = at
	if w > 0.0:
		l.size = Vector2(w, 0.0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override(&"font", _head_font if head else _body_font)
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _rect(parent: Control, r: Rect2, col: Color) -> ColorRect:
	var c := ColorRect.new()
	c.position = r.position
	c.size = r.size
	c.color = col
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	return c


## The canvas picture: 1024 x 390 in the JS
func _build_broadcast() -> void:
	broadcast_root = Control.new()
	broadcast_root.size = Vector2(1100, 420)
	vp.add_child(broadcast_root)
	var k := 1100.0 / 1024.0
	_rect(broadcast_root, Rect2(0, 0, 1100, 420), Color("#120809"))
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Consolas", "Courier New", "monospace"])
	mono.font_weight = 700
	var a := _lab(broadcast_root, "FOINT DOME / LIVE", int(35 * k), Color("#ff4a44"), Vector2(55, 34) * k)
	a.add_theme_font_override(&"font", mono)
	_b_name = _lab(broadcast_root, "", int(58 * k), Color("#f0e4de"), Vector2(55, 112) * k)
	_b_name.add_theme_font_override(&"font", mono)
	_b_line = _lab(broadcast_root, "", int(27 * k), Color("#f0e4de"), Vector2(55, 218) * k)
	_b_line.add_theme_font_override(&"font", mono)
	_rect(broadcast_root, Rect2(Vector2(55, 305) * k, Vector2(910, 3) * k), Color("#a01a24"))


func _btn_style(bg: Color, border: Color, bw: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	return s


func _button(parent: Control, r: Rect2, text: String, size: int, bg: Color, border: Color, col: Color, on: Callable) -> Button:
	var b := Button.new()
	b.position = r.position
	b.size = r.size
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override(&"font", _body_font)
	b.add_theme_font_size_override(&"font_size", size)
	for c: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
		b.add_theme_color_override(c, col)
	var st := _btn_style(bg, border)
	for s: StringName in [&"normal", &"hover", &"pressed", &"focus"]:
		b.add_theme_stylebox_override(s, st)
	b.pressed.connect(on)
	b.focus_mode = Control.FOCUS_NONE
	parent.add_child(b)
	return b


func _build_menu() -> void:
	menu_root = Control.new()
	menu_root.size = Vector2(1100, 420)
	menu_root.visible = false
	vp.add_child(menu_root)
	var R := menu_root
	_rect(R, Rect2(0, 0, 1100, 420), Color("#8a1824"))
	_rect(R, Rect2(5, 5, 1090, 410), Color("#100c0d"))
	# header
	_rect(R, Rect2(5, 5, 1090, 73), Color("#1c1718"))
	_rect(R, Rect2(5, 77, 1090, 1), Color("#8a1824"))
	_rect(R, Rect2(5, 81, 1090, 1), Color("#8a1824"))
	_lab(R, "HELIX ENTERTAINMENT PRESENTS", 12, Color("#a89a9a"), Vector2(30, 12))
	var h := _lab(R, "FOINT DOME", 32, Color("#ece2dc"), Vector2(30, 28), 0.0, true)
	var h1 := _head_font.duplicate() as FontVariation
	h1.spacing_glyph = 5
	h.add_theme_font_override(&"font", h1)
	var live := _rect(R, Rect2(355, 41, 46, 22), Color("#b0141e"))
	_lab(live, "LIVE", 13, Color("#ece2dc"), Vector2(7, 2))
	var wl := _lab(R, "AVAILABLE CASH", 12, Color("#a89a9a"), Vector2(860, 14), 205.0)
	wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_wallet = _lab(R, "", 29, Color("#ff5a4a"), Vector2(860, 28), 205.0)
	_wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# the list
	_rect(R, Rect2(517, 82, 1, 257), Color("#3a2a2c"))
	for i in ArenaChallenges.CHALLENGES.size():
		var q: Dictionary = ArenaChallenges.CHALLENGES[i]
		var b := _button(R, Rect2(17, 89 + i * 39, 488, 39), "", 16, Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color("#ece2dc"), _pick.bind(i))
		_lab(b, "%02d" % (i + 1), 16, Color("#a08a8a"), Vector2(10, 9))
		var nm := _lab(b, q.name, 16, Color("#ece2dc"), Vector2(44, 2))
		nm.name = "name"
		var sm := _lab(b, "%d ROUNDS · %s" % [q.rounds, q.tag], 10, Color("#a89a9a"), Vector2(44, 23))
		sm.name = "sub"
		var em := _lab(b, "›", 23, Color("#ff6a5a"), Vector2(455, 3))
		em.name = "em"
		_rows.append(b)
	# the event
	_tag = _lab(R, "", 12, Color("#a89a9a"), Vector2(542, 95))
	_title = _lab(R, "", 25, Color("#ece2dc"), Vector2(542, 112), 530.0, true)
	_desc = _lab(R, "", 15, Color("#c8bcb8"), Vector2(542, 150), 530.0)
	_rect(R, Rect2(542, 212, 530, 1), Color("#4a2a2e"))
	_lab(R, "COMPLETION PRIZE", 12, Color("#ff6a5a"), Vector2(542, 228))
	_prize = _lab(R, "", 29, Color("#ff6a5a"), Vector2(872, 214), 200.0)
	_prize.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_record = _lab(R, "", 10, Color("#9a8a8a"), Vector2(542, 256), 530.0)
	_enter = _button(R, Rect2(542, 276, 530, 40), "ENTER CHALLENGE", 19, Color("#a8141e"), Color("#ff5a4a"), Color("#f6e8e2"), begin)
	var e1 := _lab(_enter, "↵ / A", 12, Color(0.96, 0.91, 0.89, 0.75), Vector2(430, 11), 90.0)
	e1.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# footer
	_rect(R, Rect2(5, 339, 1090, 76), Color("#1c1718"))
	_rect(R, Rect2(5, 339, 1090, 1), Color("#8a1824"))
	_rect(R, Rect2(5, 343, 1090, 1), Color("#8a1824"))
	_message = _lab(R, "", 13, Color("#ff7a6a"), Vector2(25, 350), 1050.0)
	var fb := Color("#5a2a2e")
	var g1 := _button(R, Rect2(25, 374, 517, 34), "GUNS & AMMO", 16, Color(0, 0, 0, 0), fb, Color("#ece2dc"), guns)
	var gl := _lab(g1, "G / X", 12, Color(0.93, 0.89, 0.86, 0.75), Vector2(417, 9), 90.0)
	gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var g2 := _button(R, Rect2(557, 374, 517, 34), "EXIT STAGE", 16, Color(0, 0, 0, 0), fb, Color("#ece2dc"), exit_stage)
	var xl := _lab(g2, "ESC / B", 12, Color(0.93, 0.89, 0.86, 0.75), Vector2(417, 9), 90.0)
	xl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _pick(i: int) -> void:
	if settled:
		_choose(i)


static func _money(n: float) -> String:
	var s := str(roundi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(-3)
	return "$" + s + out


func _target_pos() -> Vector3:
	var vs := get_viewport().get_visible_rect().size
	var aspect := vs.x / maxf(vs.y, 1.0)
	var distance := maxf(SCREEN_H / 2.0, SCREEN_W / (2.0 * aspect)) / tan(deg_to_rad(48.0) / 2.0) * 1.2
	return Vector3(0.0, 7.585, 24.515 - distance)


func _fly(to_pos: Vector3, to_look: Vector3, done: Callable) -> void:
	var cam := Game.camera
	var at := cam.global_position
	var look := at - cam.global_transform.basis.z * 8.0
	flight = {"from": at, "gaze": look, "to_pos": to_pos, "to_look": to_look, "t": 0.0, "duration": FLY, "done": done}
	shot.pos = at
	shot.look = look
	active = true
	settled = false


func refresh() -> void:
	var D := level.director
	var c: Dictionary = ArenaChallenges.CHALLENGES[selected]
	var wins := int(D.wins.get(c.id, 0))
	var unlocked := D.unlocked(c)
	var key := "%d|%s|%s|%s|%s" % [selected, Game.money, D.wins, D.result.reason if D.result != null else "", settled]
	if signature == key:
		return
	signature = key
	_wallet.text = _money(Game.money)
	for i in _rows.size():
		var q: Dictionary = ArenaChallenges.CHALLENGES[i]
		var b := _rows[i]
		var sel := i == selected
		var un := D.unlocked(q)
		var st := _btn_style(Color("#3a1418") if sel else Color(0, 0, 0, 0), Color("#c8202c") if sel else Color(0, 0, 0, 0))
		if sel:
			st.border_width_left = 5
			st.border_color = Color("#c8202c")
		for s: StringName in [&"normal", &"hover", &"pressed", &"focus"]:
			b.add_theme_stylebox_override(s, st)
		(b.get_node("name") as Label).add_theme_color_override(&"font_color", Color("#ece2dc") if un else Color("#6a6062"))
		(b.get_node("em") as Label).text = "✓" if int(D.wins.get(q.id, 0)) > 0 else ("›" if un else "—")
	_tag.text = String(c.tag) + (" · %d SECONDS" % c.time if c.has("time") else "")
	_title.text = c.name
	_desc.text = c.desc
	_prize.text = _money(D.prize(c))
	if unlocked:
		_record.text = ("%d WIN%s · REPLAY PRIZE SHOWN" % [wins, "" if wins == 1 else "S"]) if wins > 0 else "FIRST WIN · FULL PRIZE"
	else:
		_record.text = "WIN %s EVENT%s TO QUALIFY" % ["ONE" if int(c.tier) == 1 else "THREE DIFFERENT", "" if int(c.tier) == 1 else "S"]
	_enter.disabled = not unlocked or not settled
	_enter.modulate.a = 1.0 if unlocked and settled else 0.4
	if D.result != null:
		_message.text = "%s%s" % [D.result.reason, (" · +" + _money(D.result.prize)) if D.result.won else " · NO ENTRY FEE. TRY AGAIN."]
	else:
		_message.text = "CHOOSE YOUR BATTLE · ↑ ↓ / D-PAD TO BROWSE"


func _choose(index: int) -> void:
	selected = posmod(index, ArenaChallenges.CHALLENGES.size())
	refresh()
	if Game.sfx != null:
		Game.sfx.play("vendNav")


func begin() -> void:
	if not active or not settled:
		return
	level.director.start(ArenaChallenges.CHALLENGES[selected].id)


func guns() -> void:
	if active and settled and not Game.shops.shop.is_open:
		Game.shops.shop.open()
		signature = ""


func exit_stage() -> void:
	if not active or not settled:
		return
	Game.save_game()
	Game.doors.travel({"to": "hub", "spawn_at": "foint"})


## Keyboard: only while the menu holds the screen, and it eats these keys (JS the capture listener)
func _input(event: InputEvent) -> void:
	if not active or Game.paused or not Game.started:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		var code := k.physical_keycode
		if not (code == KEY_UP or code == KEY_DOWN or code == KEY_W or code == KEY_S or code == KEY_ENTER or code == KEY_KP_ENTER or code == KEY_SPACE or code == KEY_G or code == KEY_ESCAPE or code == KEY_TAB):
			return
		get_viewport().set_input_as_handled()
		if not settled or not k.pressed or k.echo:
			return
		if code == KEY_UP or code == KEY_W:
			_choose(selected - 1)
		elif code == KEY_DOWN or code == KEY_S:
			_choose(selected + 1)
		elif code == KEY_G:
			guns()
		elif code == KEY_ESCAPE:
			exit_stage()
		elif code != KEY_TAB:
			begin()
	elif settled and (event is InputEventMouseButton or event is InputEventMouseMotion):
		var cam := Game.camera
		var m: Vector2 = (event as InputEventMouse).position
		var o := cam.project_ray_origin(m)
		var d := cam.project_ray_normal(m)
		if absf(d.z) < 1e-5:
			return
		var hit := o + d * ((SCREEN_AT.z - o.z) / d.z)
		var u := 0.5 - hit.x / SCREEN_W      # the screen faces -Z: its right is world -X
		var v := 0.5 - (hit.y - SCREEN_AT.y) / SCREEN_H
		if u >= 0.0 and u <= 1.0 and v >= 0.0 and v <= 1.0:
			var ev: InputEventMouse = event.duplicate()
			ev.position = Vector2(u * 1100.0, v * 420.0)
			ev.global_position = ev.position
			vp.push_input(ev, true)
		get_viewport().set_input_as_handled()


func _broadcast() -> void:
	var D := level.director
	var nm: String = D.challenge.name if D.challenge != null else "CHOOSE YOUR BATTLE"
	var s := "%s/%d/%s/%d" % [D.state, D.round_, nm, ceili(D.elapsed)]
	if sig == s:
		return
	sig = s
	_b_name.text = nm
	_b_line.text = ("ROUND %d / %d    %s" % [D.round_, D.challenge.rounds, "ROUND CLEAR" if D.state == &"between" else "ON AIR"]) if D.playable else "CHALLENGES  /  ARMORY  /  EXIT"
	if not active:
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE


func _hud(hidden_: bool) -> void:
	if hidden_ == _ui_hidden:
		return
	_ui_hidden = hidden_
	Game.hud.arena_tv(hidden_)


func menu(_reason: String = "") -> void:
	Game.ui.unlock()
	_hud(true)
	_fly(_target_pos(), SCREEN_AT, func() -> void:
		settled = true
		refresh())
	refresh()


func start() -> void:
	Inp.guard_arm()
	menu_root.visible = false
	broadcast_root.visible = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	sig = ""
	_hud(false)
	var rig := Game.rig
	_fly(rig.pos, rig.look, func() -> void:
		active = false
		level.director.ready()
		Inp.guard_arm()
		Game.ui.lock())


func update(dt: float) -> void:
	_broadcast()
	if flight != null:
		var F: Dictionary = flight
		F.t = float(F.t) + dt
		var u := minf(1.0, float(F.t) / float(F.duration))
		var k := u * u * u * (u * (u * 6.0 - 15.0) + 10.0)
		shot.pos = (F.from as Vector3).lerp(F.to_pos, k)
		shot.pos.y += sin(u * PI) * 2.1
		shot.look = (F.gaze as Vector3).lerp(F.to_look, k)
		if u == 1.0:
			flight = null
			(F.done as Callable).call()
	elif active:
		shot.pos = _target_pos()
		shot.look = SCREEN_AT
	if active:
		refresh()
		if settled and Inp.using_pad:
			var ly: float = Inp.raw_ly
			var dir := -1 if Inp.btn(&"d_up").held or ly < -0.55 else (1 if Inp.btn(&"d_down").held or ly > 0.55 else 0)
			pad_time -= dt
			if dir != 0 and (dir != pad_dir or pad_time <= 0.0):
				_choose(selected + dir)
				pad_time = 0.14 if dir == pad_dir else 0.35
			pad_dir = dir
			if Inp.btn(&"jump").pressed:
				begin()
			elif Inp.btn(&"attack").pressed:
				guns()
			elif Inp.btn(&"b").pressed:
				exit_stage()
	var D := level.director
	var running: bool = Game.started and not Game.paused
	status_box.visible = running and D.state != &"menu" and D.state != &"launch" and D.state != &"inactive"
	if status_box.visible:
		var was := status_lab.text
		if D.state == &"countdown":
			status_lab.text = "%d · GET READY" % maxi(1, 3 - int(floorf(D.t)))
		elif D.challenge != null:
			var left := D.queue.size()
			for r: Robot in Game.combat.enemies.robots:
				if not r.dead:
					left += 1
			status_lab.text = "%s   /   ROUND %d OF %d   /   %s%s" % [D.challenge.name, D.round_, D.challenge.rounds, "ROUND CLEAR · RELOAD" if D.state == &"between" else "%d REMAIN" % left, ("   /   %ds" % maxi(0, ceili(float(D.challenge.time) - D.elapsed))) if D.challenge.has("time") else ""]
		else:
			status_lab.text = ""
		if status_lab.text != was:      # (CSS: fits its text, centred on the screen. A container only ever grows, which walked the text about as the count changed.)
			var m := status_box.get_combined_minimum_size()
			status_box.offset_left = -m.x * 0.5
			status_box.offset_right = m.x * 0.5
			status_box.offset_top = 70.0
			status_box.offset_bottom = 70.0 + m.y


## View's contract: the camera while this owns it
var camera: Variant:
	get:
		return shot if active else null


func render() -> void:
	var shown := active and settled and Game.started and not Game.paused
	if menu_root.visible != shown:
		menu_root.visible = shown
		broadcast_root.visible = not shown
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if shown else SubViewport.UPDATE_ONCE
	if shown:
		Inp.set_pointer_lock(false)


func leave() -> void:
	_hud(false)
	active = false
	flight = null
	if is_instance_valid(picture):
		picture.queue_free()
