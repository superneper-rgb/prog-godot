class_name DebugConsole
extends Control
## DEV CONSOLE (devtools/console.js): a terminal-style box in the middle of the screen, toggled with the ` key (the ` / ~ key left of 1) anywhere in the game.
## This file is only the console itself (window, input line, history, command registry, help pages); the game's commands are in ui/console_commands.gd.
##
## ADDING A COMMAND (from anywhere: a level, an enemy module, a peek eval):
##   Game.ui.console.register({
##     "name": "heal",                    # what you type (case-insensitive, no spaces)
##     "usage": "[amount]",               # argument hint shown in help (optional)
##     "desc": "Restore health",          # one line for the help list (required)
##     "details": "Longer text for help heal (optional, can contain \n)",
##     "aliases": ["hp+"],                # other names that run the same command (optional)
##     "complete": func(args): return [], # Tab completion for its arguments (optional)
##     "run": func(args: Array, con: DebugConsole, raw: String): ...,   # args = words after the name (quotes group words), raw = everything after the name
##   })
## Every registered command shows up in "help" automatically (sorted by name). run() can print with con.print_line(text), con.ok(text), con.warn(text), con.error(text); returning a string prints it; it may await.
## Registering an existing name replaces that command.

const MAX_LINES := 600
const HIST_FILE := "user://console_history.txt"
const C_TEXT := Color("9df5b0")
const C_CMD := Color("e8ffe9")
const C_OK := Color("5dff8f")
const C_WARN := Color("ffd166")
const C_ERR := Color("ff6b6b")
const C_DIM := Color("4f9a64")
const C_HEAD := Color("c8ffd4")

var cmds := {}          # name -> def
var alias := {}         # alias -> name
var history: PackedStringArray = []
var is_open := false
var hooks_on_open := Callable()
var hooks_on_close := Callable()
var _hist_idx := -1
var _draft := ""
var _box: PanelContainer
var _out: RichTextLabel
var _in: LineEdit
var _lines := 0
var _toggle_ms := -1000
var _key_was := false


func _init() -> void:
	name = "DebugConsole"
	CrtTheme.full(self)
	z_index = 400
	visible = false


func _ready() -> void:
	var t := CrtTheme.tools_theme()
	theme = t
	_box = PanelContainer.new()
	var st := CrtTheme.panel(Color(6.0 / 255.0, 10.0 / 255.0, 8.0 / 255.0, 0.94), 6, Color("2f6b3c"))
	st.shadow_color = Color(0, 0, 0, 0.65)
	st.shadow_size = 40
	st.shadow_offset = Vector2(0, 12)
	_box.add_theme_stylebox_override(&"panel", st)
	_box.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 0)
	_box.add_child(col)
	# .dc-bar
	var bar := PanelContainer.new()
	var bs := CrtTheme.panel(Color(30.0 / 255.0, 80.0 / 255.0, 45.0 / 255.0, 0.18), 0, Color(0, 0, 0, 0), 12, 6)
	bs.border_width_bottom = 1
	bs.border_color = Color("1d4026")
	bar.add_theme_stylebox_override(&"panel", bs)
	var row := HBoxContainer.new()
	var tl := CrtTheme.label("DEV CONSOLE", &"monob", 11, Color("5fd17c"), 1)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(tl)
	row.add_child(CrtTheme.label("` / Esc close · Tab complete · ↑↓ history · PgUp/PgDn scroll", &"mono", 11, Color("3f8a55")))
	bar.add_child(row)
	col.add_child(bar)
	# .dc-out
	var om := MarginContainer.new()
	om.add_theme_constant_override(&"margin_left", 12)
	om.add_theme_constant_override(&"margin_right", 6)
	om.add_theme_constant_override(&"margin_top", 8)
	om.add_theme_constant_override(&"margin_bottom", 8)
	om.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(om)
	_out = RichTextLabel.new()
	_out.bbcode_enabled = false
	_out.scroll_following = true
	_out.selection_enabled = true
	_out.context_menu_enabled = false
	_out.focus_mode = Control.FOCUS_CLICK
	_out.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_out.add_theme_font_override(&"normal_font", CrtTheme.font(&"mono"))
	_out.add_theme_font_size_override(&"normal_font_size", 13)
	_out.add_theme_color_override(&"default_color", C_TEXT)
	_out.add_theme_constant_override(&"line_separation", 2)
	om.add_child(_out)
	# .dc-in
	var ip := PanelContainer.new()
	var is_ := CrtTheme.panel(Color(0, 0, 0, 0.35), 0, Color(0, 0, 0, 0), 12, 7)
	is_.border_width_top = 1
	is_.border_color = Color("1d4026")
	ip.add_theme_stylebox_override(&"panel", is_)
	var ir := HBoxContainer.new()
	ir.add_theme_constant_override(&"separation", 8)
	ir.add_child(CrtTheme.label(">", &"monob", 13, C_OK))
	_in = LineEdit.new()
	_in.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_in.flat = true
	_in.context_menu_enabled = false
	_in.caret_blink = true
	_in.add_theme_font_override(&"font", CrtTheme.font(&"mono"))
	_in.add_theme_font_size_override(&"font_size", 13)
	_in.add_theme_color_override(&"font_color", C_CMD)
	_in.add_theme_color_override(&"caret_color", C_OK)
	_in.add_theme_stylebox_override(&"normal", StyleBoxEmpty.new())
	_in.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
	_in.add_theme_constant_override(&"minimum_character_width", 0)
	ir.add_child(_in)
	ip.add_child(ir)
	col.add_child(ip)
	get_viewport().size_changed.connect(_fit)
	_fit()
	_load_history()
	print_line("PROG dev console. Type \"help\" for the command list.", C_DIM)
	register({"name": "help", "usage": "[page|command]", "desc": "List commands (paged) or show one command", "aliases": ["?"],
		"details": "help        first page of commands\nhelp 2      second page (pages fit the console window)\nhelp spawn  usage and details of one command",
		"run": func(a: Array, _c: DebugConsole, _r: String) -> Variant: help(a); return null})
	register({"name": "clear", "desc": "Clear the console output", "aliases": ["cls"], "run": func(_a: Array, _c: DebugConsole, _r: String) -> Variant: clear(); return null})
	register({"name": "echo", "usage": "<text>", "desc": "Print text", "run": func(_a: Array, _c: DebugConsole, r: String) -> Variant: print_line(r); return null})
	register({"name": "history", "desc": "Show the commands typed this session", "run": func(_a: Array, _c: DebugConsole, _r: String) -> Variant:
		if history.is_empty():
			return "No history yet."
		var i := 1
		for h in history:
			print_line(str(i).lpad(3) + "  " + h)
			i += 1
		return null})


func _fit() -> void:
	var vp := get_viewport_rect().size
	var sz := Vector2(minf(820.0, vp.x - 32.0), minf(480.0, vp.y - 80.0))
	_box.size = sz
	_box.position = (vp - sz) * 0.5


# ---- output ----

func print_line(text: Variant = "", color: Color = C_TEXT, bold: bool = false) -> void:
	for line in String(str(text) if text != null else "").split("\n"):
		_out.push_color(color)
		if bold:
			_out.push_font(CrtTheme.font(&"monob"))
		_out.add_text(line)
		if bold:
			_out.pop()
		_out.pop()
		_out.newline()
		_lines += 1
	while _lines > MAX_LINES:
		_out.remove_paragraph(0)
		_lines -= 1


func ok(t: Variant) -> void:
	print_line(t, C_OK)


func warn(t: Variant) -> void:
	print_line(t, C_WARN)


func error(t: Variant) -> void:
	print_line(t, C_ERR)


func dim(t: Variant) -> void:
	print_line(t, C_DIM)


func head(t: Variant) -> void:
	print_line(t, C_HEAD, true)


func clear() -> void:
	_out.clear()
	_lines = 0


## How many output lines fit in the window without scrolling (help pages are cut to this).
func visible_lines() -> int:
	var h := _out.size.y if _out.size.y > 10.0 else 400.0
	return maxi(6, int(floor(h / 19.0)))


# ---- registry ----

func register(def: Dictionary) -> void:
	if not def.has("name") or not (def.get("run") is Callable):
		push_error("console.register needs {name, desc, run(args, con, raw)}")
		return
	var nm := String(def.name).to_lower()
	if cmds.has(nm):
		unregister(nm)
	var d := {"usage": "", "desc": "", "details": "", "aliases": [], "category": "", "hidden": false}
	d.merge(def, true)
	d.name = nm
	var al: Array = []
	for a: Variant in def.get("aliases", []):
		al.append(String(a).to_lower())
	d.aliases = al
	cmds[nm] = d
	for a: String in al:
		alias[a] = nm


func unregister(nm: String) -> bool:
	var d: Variant = cmds.get(nm.to_lower())
	if d == null:
		return false
	cmds.erase(d.name)
	for a: String in d.aliases:
		if alias.get(a) == d.name:
			alias.erase(a)
	return true


func find(nm: String) -> Variant:
	var n := nm.to_lower()
	if cmds.has(n):
		return cmds[n]
	if alias.has(n):
		return cmds.get(alias[n])
	return null


func list() -> Array:
	var out: Array = []
	for k: String in cmds:
		if not cmds[k].hidden:
			out.append(cmds[k])
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.name).naturalnocasecmp_to(String(b.name)) < 0)
	return out


## Split "spawn alien 3" / 'say "hello there"' into words; quotes group words.
static func parse_args(s: String) -> Array:
	var out: Array = []
	var cur := ""
	var q := ""
	var has := false
	for ch in s:
		if q != "":
			if ch == q:
				q = ""
			else:
				cur += ch
		elif ch == "\"" or ch == "'":
			q = ch
			has = true
		elif ch == " " or ch == "\t":
			if cur != "" or has:
				out.append(cur)
			cur = ""
			has = false
		else:
			cur += ch
	if cur != "" or has:
		out.append(cur)
	return out


# ---- run a line ----

func exec(line: String, echo_it: bool = true) -> void:
	line = line.strip_edges()
	if line == "":
		return
	if echo_it:
		print_line("> " + line, C_CMD)
	for part_raw in line.split(";"):        # "god on; give all" runs both
		var part := part_raw.strip_edges()
		if part == "":
			continue
		var sp := -1
		for i in part.length():
			if part[i] == " " or part[i] == "\t":
				sp = i
				break
		var nm := part if sp < 0 else part.substr(0, sp)
		var raw := "" if sp < 0 else part.substr(sp + 1).strip_edges()
		var d: Variant = find(nm)
		if d == null:
			error("Unknown command \"" + nm + "\". Type \"help\" for the list.")
			var near := suggest(nm)
			if not near.is_empty():
				dim("Did you mean: " + ", ".join(near) + "?")
			continue
		var r: Variant = await (d.run as Callable).call(parse_args(raw), self, raw)
		if r is String:
			print_line(r)


func suggest(nm: String) -> PackedStringArray:
	var n := nm.to_lower()
	var out := PackedStringArray()
	for c: String in cmds.keys() + alias.keys():
		if c.begins_with(n.substr(0, 2)) or c.contains(n):
			out.append(c)
			if out.size() >= 5:
				break
	return out


# ---- help (always built from the registry, paged to the window height) ----

func help(args: Array) -> void:
	var all := list()
	var a: String = args[0] if args.size() > 0 else ""
	if a != "" and not a.is_valid_int():        # help <command>
		var d: Variant = find(a)
		if d == null:
			error("No command \"" + a + "\".")
			return
		head(String(d.name) + ((" " + String(d.usage)) if d.usage != "" else ""))
		print_line("  " + String(d.desc))
		if d.details != "":
			for l in String(d.details).split("\n"):
				dim("  " + l)
		if not (d.aliases as Array).is_empty():
			dim("  aliases: " + ", ".join(PackedStringArray(d.aliases)))
		return
	var per := maxi(3, visible_lines() - 3)
	var pages := maxi(1, ceili(float(all.size()) / per))
	var p := int(a) if a != "" else 1
	if p < 1 or p > pages:
		error(("There is 1 help page" if pages == 1 else "There are %d help pages" % pages) + ". Try \"help 1\"" + ((" to \"help %d\"" % pages) if pages > 1 else "") + ".")
		return
	var w := 0
	for d: Dictionary in all:
		w = maxi(w, (String(d.name) + ((" " + String(d.usage)) if d.usage != "" else "")).length())
	w = mini(28, w)
	clear()
	head("COMMANDS  (page %d of %d, %d total)" % [p, pages, all.size()])
	for i in range((p - 1) * per, mini(p * per, all.size())):
		var d: Dictionary = all[i]
		var sig := String(d.name) + ((" " + String(d.usage)) if d.usage != "" else "")
		print_line((sig.substr(0, w - 1) + "~" if sig.length() > w else sig.rpad(w)) + "  " + String(d.desc))
	dim(("More commands: type \"help %d\".  \"help <command>\" for details." % (p + 1)) if p < pages else "\"help <command>\" for details on one command.")


# ---- open / close ----

func set_open(v: bool) -> void:
	if v == is_open:
		return
	is_open = v
	visible = v
	Inp.set_text_capture(v)
	if v:
		_in.text = ""
		_hist_idx = -1
		if Game.ui != null:
			Game.ui.tools_opened()      # the mouse is needed here; the browser's game gave up its pointer lock the same way
		if hooks_on_open.is_valid():
			hooks_on_open.call()
		_in.grab_focus()
	else:
		_in.release_focus()
		if Game.ui != null:
			Game.ui.tools_closed()
		if hooks_on_close.is_valid():
			hooks_on_close.call()


func open() -> void:
	set_open(true)


func close() -> void:
	set_open(false)


func toggle() -> void:
	set_open(not is_open)


# ---- tab completion: command names, then the command's own complete(args_so_far) list if it has one ----

func complete() -> void:
	var v := _in.text
	var sp := -1
	for i in v.length():
		if v[i] == " " or v[i] == "\t":
			sp = i
			break
	var pool := PackedStringArray()
	var prefix := ""
	var head_s := ""
	if sp < 0:
		for d: Dictionary in list():
			pool.append(String(d.name))
		prefix = v
	else:
		var d: Variant = find(v.substr(0, sp))
		if d == null or not (d.get("complete") is Callable):
			return
		var rest := v.substr(sp + 1)
		var args := parse_args(rest)
		var last := ""
		if not (rest.ends_with(" ") or rest.ends_with("\t")) and args.size() > 0:
			last = args.pop_back()
		for s: Variant in (d.complete as Callable).call(args):
			pool.append(str(s))
		prefix = last
		head_s = v.substr(0, v.length() - last.length())
	var hits := PackedStringArray()
	for n in pool:
		if n.to_lower().begins_with(prefix.to_lower()):
			hits.append(n)
	hits.sort()
	if hits.is_empty():
		return
	if hits.size() == 1:
		_in.text = head_s + hits[0] + " "
		_in.caret_column = _in.text.length()
		return
	var common := hits[0]
	for h in hits:
		while not h.to_lower().begins_with(common.to_lower()):
			common = common.substr(0, common.length() - 1)
	if common.length() > prefix.length():
		_in.text = head_s + common
		_in.caret_column = _in.text.length()
	else:
		dim("  ".join(hits))


# ---- keys: seen first, so nothing in the game sees a key while the console is open (Inp.text_capture) ----

## One press, one toggle: a press can reach this twice (the key, and its character on its own), and that would open and shut the window in the same breath.
func _press_toggle() -> void:
	var now := Time.get_ticks_msec()
	if now - _toggle_ms < 180:
		return
	_toggle_ms = now
	toggle()


## The key is polled as well as heard, so that nothing that takes key events ahead of this node can lose the console.
func _process(_delta: float) -> void:
	var down := Input.is_physical_key_pressed(KEY_QUOTELEFT)
	if down and not _key_was:
		_press_toggle()
	_key_was = down


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var e := event as InputEventKey
	var toggle_key := e.physical_keycode == KEY_QUOTELEFT or e.keycode == KEY_QUOTELEFT or e.unicode == 96 or e.unicode == 126
	if toggle_key:
		if e.pressed and not e.echo:
			_press_toggle()
		get_viewport().set_input_as_handled()
		return
	if not is_open or not e.pressed:
		return
	var handled := true
	match e.keycode:
		KEY_ESCAPE:
			set_open(false)
		KEY_ENTER, KEY_KP_ENTER:
			var v := _in.text
			_in.text = ""
			_hist_idx = -1
			if v.strip_edges() != "":
				if history.is_empty() or history[0] != v:
					history.insert(0, v)
				if history.size() > 100:
					history.resize(100)
				_save_history()
			exec(v)
		KEY_UP:
			if not history.is_empty():
				if _hist_idx < 0:
					_draft = _in.text
				_hist_idx = mini(history.size() - 1, _hist_idx + 1)
				_in.text = history[_hist_idx]
				_in.caret_column = _in.text.length()
		KEY_DOWN:
			if _hist_idx >= 0:
				_hist_idx -= 1
				_in.text = _draft if _hist_idx < 0 else history[_hist_idx]
				_in.caret_column = _in.text.length()
		KEY_TAB:
			complete()
		KEY_PAGEUP, KEY_PAGEDOWN:
			var sb := _out.get_v_scroll_bar()
			sb.value += (-1.0 if e.keycode == KEY_PAGEUP else 1.0) * (_out.size.y - 30.0)
		KEY_L:
			if e.ctrl_pressed:
				clear()
			else:
				handled = false
		_:
			handled = false
	if handled:
		get_viewport().set_input_as_handled()
	elif not _in.has_focus() and not e.ctrl_pressed:
		_in.grab_focus()


func _load_history() -> void:
	if FileAccess.file_exists(HIST_FILE):
		history = FileAccess.get_file_as_string(HIST_FILE).split("\n", false)


func _save_history() -> void:
	var f := FileAccess.open(HIST_FILE, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(history))
		f.close()
