class_name TuningPanel
extends Control
## The F3 tuning panel (TUNABLES + UI._buildDebug): reads and writes Config by name with sliders, plus the live readout. Built the first time it opens. Enemy modules add their groups with add_group().

# group, then [key, min, max, step]: the JS's TUNABLES, keys in snake_case (a key Config does not have is skipped)
static var TUNABLES: Array = [
	["Input", [
		["deadzone", 0, 0.4, 0.01], ["move_exp", 0.6, 3, 0.05], ["cam_exp", 0.6, 3, 0.05],
		["pad_look_speed", 1, 8, 0.1], ["pad_look_ease", 0, 120, 1], ["mouse_sens", 0.0005, 0.006, 0.0001],
	]],
	["Ground", [
		["run_speed", 3, 16, 0.1], ["ground_accel", 10, 200, 1], ["ground_decel", 10, 300, 1], ["turn_boost", 0, 2, 0.05], ["land_drag", 0, 0.8, 0.01],
		["strafe_speed_mult", 0.3, 1.2, 0.01], ["sprint_speed_mult", 1, 2, 0.01], ["crouch_speed_mult", 0, 1, 0.01],
		["turn_k", 4, 40, 0.5], ["strafe_turn_k", 4, 60, 0.5],
		["start_boost", 1, 3, 0.05], ["strafe_accel_mult", 0.5, 2, 0.05], ["turn_snap", 0, 2, 0.05],
	]],
	["Jump", [
		["jump_vel", 5, 20, 0.1], ["double_jump_mult", 0.4, 1.2, 0.01], ["high_jump_mult", 1, 2.2, 0.01],
		["jump_cut_vel", 1, 10, 0.1], ["gravity_up", 8, 60, 0.5], ["gravity_down", 8, 80, 0.5],
		["air_accel", 5, 150, 1], ["air_drag", 0, 40, 0.5],
		["coyote", 0, 0.4, 0.01], ["jump_buffer", 0, 0.4, 0.01],
		["air_turn_boost", 0, 2, 0.05], ["apex_grav", 0.4, 1, 0.01], ["apex_vel", 0, 6, 0.1],
	]],
	["Reload", [["aim_hold", 0, 1.5, 0.05], ["aim_hold_semi", 0, 1, 0.05], ["aim_hold_max", 0.3, 2, 0.05], ["reload_speed", 0.4, 2.5, 0.05], ["auto_reload", 0, 1, 1], ["reload_tilt", 0, 1.5, 0.05]]],
	["Ledge", [["hang_twist", -3, 3, 0.05], ["hang_time", 0.05, 2, 0.05], ["pull_time", 0.2, 1.5, 0.02]]],
	["Swim", [["swim_speed", 1, 8, 0.1], ["swim_sprint", 1, 10, 0.1], ["swim_accel", 1, 20, 0.5], ["swim_drag", 0.5, 10, 0.1], ["swim_turn_k", 1, 20, 0.5], ["swim_float", 0.8, 1.8, 0.01], ["swim_hop", 0, 8, 0.1], ["swim_climb", 0.5, 4, 0.1]]],
	["Camera", [
		["cam_dist", 2, 12, 0.1], ["cam_height", 0.5, 2.5, 0.05], ["cam_follow_k", 0, 8, 0.1],
		["cam_pos_k", 2, 40, 0.5], ["cam_vert_k", 1, 30, 0.5], ["cam_vert_air_k", 0.2, 12, 0.1], ["fov", 40, 100, 1],
		["cam_dist_aim", 1.5, 8, 0.1], ["cam_shoulder", 0, 2, 0.05], ["aim_fov_cut", 0, 25, 0.5], ["ads_dist", 0.8, 4, 0.05], ["ads_shoulder", 0, 1.5, 0.02], ["ads_fov_cut", 0, 40, 0.5], ["ads_speed_mult", 0.1, 1, 0.02],
	]],
	["Camera follow", [
		["cam_manual_hold", 0, 3, 0.05], ["cam_follow_ramp", 0.1, 3, 0.05], ["cam_follow_delay", 0, 1, 0.01], ["cam_steady_rate", 0.5, 10, 0.1],
		["cam_follow_side", 0, 1, 0.01], ["cam_follow_max", 0.3, 6, 0.1], ["cam_follow_smooth", 2, 20, 0.5], ["cam_follow_air", 0, 1, 0.01],
		["cam_follow_leash", 0, 1, 0.05], ["cam_leash_smooth", 0, 12, 0.5], ["cam_follow_leash_room", 0, 1, 0.05], ["cam_jump_band", 0, 1, 0.01], ["cam_run_at_dist", 0, 3, 0.05], ["cam_lead", 0, 0.3, 0.01], ["cam_lead_k", 1, 12, 0.5], ["cam_land_dip", 0, 0.02, 0.001], ["cam_shake", 0, 1.5, 0.05],
	]],
	["Camera collision", [
		["cam_probe", 0.05, 0.5, 0.01], ["cam_wall_gap", 0.1, 0.6, 0.01], ["cam_clear_in_k", 5, 60, 1], ["cam_clear_out_k", 0.5, 10, 0.1], ["cam_clear_hold", 0, 1, 0.01], ["cam_lift_max", 0, 1.4, 0.02],
	]],
]


## TUNABLES.push: an enemy module's group of sliders.
static func add_group(group: String, items: Array) -> void:
	TUNABLES.append([group, items])


class Row:
	var key := ""
	var slider: HSlider
	var val: Label
	var def := 0.0


var debug_open := false
var _built := 0              # how many groups are built
var _box: PanelContainer
var _list: VBoxContainer
var _readout: Label
var _rows: Array[Row] = []
var _invert: CheckBox
var _read_t := 0.0
var _x := 0.0                # 0 hidden .. 1 out (transition: transform .18s)
var _sync_lock := false


func _init() -> void:
	name = "Tuning"
	CrtTheme.full(self)
	z_index = 10
	visible = false


func _ready() -> void:
	theme = CrtTheme.tools_theme()
	get_viewport().size_changed.connect(_fit)
	set_process(false)


func _build_debug() -> void:
	if _box != null:
		_build_groups()
		return
	_box = PanelContainer.new()
	var st := CrtTheme.panel(Color(6.0 / 255.0, 10.0 / 255.0, 8.0 / 255.0, 0.92), 0, Color(0, 0, 0, 0), 12, 10)
	st.border_width_left = 1
	st.border_color = Color("2f6b3c")
	_box.add_theme_stylebox_override(&"panel", st)
	_box.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_box)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_box.add_child(sc)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override(&"separation", 1)
	sc.add_child(_list)
	var title := HBoxContainer.new()
	title.add_child(CrtTheme.label("Debug / tuning ", &"monob", 14, Color("c8ffd4")))
	title.add_child(CrtTheme.label("(View/Back or F3)", &"mono", 12, Color("4f9a64")))
	_list.add_child(title)
	_readout = CrtTheme.label("", &"mono", 11, Color("9df5b0"))
	_readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_readout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_child(_readout)
	_build_groups()
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override(&"separation", 8)
	var reset := Button.new()
	reset.text = "Reset values"
	reset.pressed.connect(_reset)
	btns.add_child(reset)
	var copy := Button.new()
	copy.text = "Copy Config"
	copy.pressed.connect(_copy)
	btns.add_child(copy)
	_list.add_child(btns)
	_fit()


func _build_groups() -> void:
	while _built < TUNABLES.size():
		var g: Array = TUNABLES[_built]
		_built += 1
		var h := CrtTheme.label(String(g[0]).to_upper(), &"monob", 12, Color("5fd17c"), 1)
		_list.add_child(h)
		for it: Array in g[1]:
			var key: String = it[0]
			if Config.get(key) == null:
				continue
			var r := Row.new()
			r.key = key
			r.def = float(Config.get(key))
			var row := HBoxContainer.new()
			row.add_theme_constant_override(&"separation", 6)
			var nm := CrtTheme.label(key, &"mono", 12, Color("9df5b0"))
			nm.custom_minimum_size = Vector2(136, 0)
			nm.clip_text = true
			row.add_child(nm)
			r.slider = HSlider.new()
			r.slider.min_value = float(it[1])
			r.slider.max_value = float(it[2])
			r.slider.step = float(it[3])
			r.slider.value = float(Config.get(key))
			r.slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			r.slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			r.slider.focus_mode = Control.FOCUS_NONE
			r.slider.value_changed.connect(_on_slider.bind(r))
			row.add_child(r.slider)
			r.val = CrtTheme.label(_fmt(float(Config.get(key))), &"mono", 12, Color("c8ffd4"))
			r.val.custom_minimum_size = Vector2(52, 0)
			r.val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			row.add_child(r.val)
			_list.add_child(row)
			_rows.append(r)
	if _invert == null:
		_invert = CheckBox.new()
		_invert.text = "invert_y (right stick / mouse)"
		_invert.button_pressed = Config.invert_y
		_invert.focus_mode = Control.FOCUS_NONE
		_invert.toggled.connect(func(on: bool) -> void: Config.invert_y = on)
		_list.add_child(_invert)


static func _fmt(v: float) -> String:
	return String.num(v, 4)


func _on_slider(v: float, r: Row) -> void:
	if _sync_lock:
		return
	var old: Variant = Config.get(r.key)
	Config.set(r.key, int(v) if old is int else v)
	r.val.text = _fmt(v)


func _reset() -> void:
	for r in _rows:
		var old: Variant = Config.get(r.key)
		Config.set(r.key, int(r.def) if old is int else r.def)
	sync_values()


func _copy() -> void:
	var d := {}
	for k: Variant in ConsoleCommands._config_keys():
		d[k] = Config.get(k)
	DisplayServer.clipboard_set(JSON.stringify(d, "  "))
	if Game.hud != null:
		Game.hud.toast("CONFIG copied")


## Config changed elsewhere (the console's set, a level): show it.
func sync_values() -> void:
	_sync_lock = true
	for r in _rows:
		var v := float(Config.get(r.key))
		r.slider.value = v
		r.val.text = _fmt(v)
	if _invert != null:
		_invert.button_pressed = Config.invert_y
	_sync_lock = false


func toggle_debug(force: Variant = null) -> void:
	debug_open = (not debug_open) if force == null else bool(force)
	if debug_open:
		_build_debug()
		sync_values()
		visible = true
	set_process(true)
	_read_t = 0.0


func _fit() -> void:
	if _box == null:
		return
	var vp := get_viewport_rect().size
	var w := minf(340.0, vp.x * 0.92)
	_box.size = Vector2(w, vp.y)
	_box.position = Vector2(vp.x - w * _x - (1.0 - _x) * 0.05 * w, 0.0)


func _process(delta: float) -> void:
	_x = move_toward(_x, 1.0 if debug_open else 0.0, delta / 0.18)
	_fit()
	if _x <= 0.0 and not debug_open:
		visible = false
		set_process(false)


## The live numbers, ten times a second.
func readout_update(dt: float) -> void:
	_read_t -= dt
	if _read_t > 0.0 or _readout == null:
		return
	_read_t = 0.1
	var P := Game.player
	var cam := Game.rig
	if P == null or cam == null:
		return
	var f := func(v: float) -> String: return ("%s%.2f" % [" " if v >= 0.0 else "", v])
	var held := ""
	for n: StringName in Inp.BUTTONS:
		if Inp.btn(n).held:
			held += String(n).to_upper() + " "
	var t := "FPS %d   pad: %s  using %s\n" % [roundi(Engine.get_frames_per_second()), "standard" if Inp.pad_connected else "none", "pad" if Inp.using_pad else "kb/mouse"]
	t += "LS raw %s %s -> move %s %s  mag %.2f\n" % [f.call(Inp.raw_lx), f.call(Inp.raw_ly), f.call(Inp.move.x), f.call(Inp.move.y), Inp.move.mag]
	t += "RS look mag %.2f   LT %.2f RT %.2f\n" % [Inp.look.mag, Inp.lt, Inp.rt]
	t += "held: %s\n" % held
	t += "pos %s %s %s  speed %.1f  vy %s\n" % [f.call(P.x), f.call(P.y), f.call(P.z), Vector2(P.vx, P.vz).length(), f.call(P.vy)]
	t += "%s %s%s%s%s  last jump: %s\n" % ["GROUND" if P.grounded else "AIR", "CROUCH " if P.crouching else "", "STRAFE " if P.strafing else "", "FLIP " if P.flip >= 0.0 else "", String(P.mode).to_upper() if P.mode != &"normal" else "", String(P.last_jump) if String(P.last_jump) != "" else "-"]
	t += "cam yaw %s pitch %s dist %.2f %s\n" % [f.call(cam.yaw), f.call(cam.pitch), cam.dist, "AUTO" if cam.auto_following else ""]
	t += "HP %d%s" % [roundi(P.hp), " DEAD" if P.dead else ""]
	var en: Variant = Game.combat.enemies if Game.combat != null else null
	if en != null and en.has_method(&"table"):
		for r: Dictionary in en.table():
			t += "\n#%02d %s %s hp%4d d%5.1f %s%s" % [int(r.id) + 1, String(r.state).rpad(8), String(r.get("light", "")).rpad(5), int(r.hp), float(r.dist), r.get("slot", ""), (" (%s)" % r.why) if r.get("why", "") != "" else ""]
	_readout.text = t
