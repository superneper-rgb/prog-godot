extends Node
## Autoload Peek: dev-only command port into the running game (the Godot twin of tests/lib/peek.cjs). Inert unless the game
## was started with `-- --peek=<port>` (tools/peek.mjs does that). One JSON line in, one JSON line out, per connection.
##   {"cmd":"eval","code":"return Game.player.x"}   GDScript function body; may await; result comes back as text
##   {"cmd":"frames","n":60}                        wait n rendered frames
##   {"cmd":"shot","path":"C:/.../x.png","w":1280}  screenshot (never into the project)
##   {"cmd":"logs"}                                 errors and prints captured since the last call
##   {"cmd":"quit"}

class PeekLogger extends Logger:
	var lines: PackedStringArray = []
	var _m := Mutex.new()
	func _log_message(message: String, error: bool) -> void:
		_m.lock()
		lines.append(("ERR: " if error else "") + message.strip_edges())
		_m.unlock()
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		_m.lock()
		var txt := rationale if rationale != "" else code
		var kind := "WARNING" if error_type == ERROR_TYPE_WARNING else ("SCRIPT" if error_type == ERROR_TYPE_SCRIPT else "ERROR")
		var where := "%s:%d" % [file, line]
		for bt: ScriptBacktrace in script_backtraces:
			if bt.get_frame_count() > 0:
				where = "%s:%d (%s)" % [bt.get_frame_file(0), bt.get_frame_line(0), bt.get_frame_function(0)]
				break
		lines.append("%s: %s @ %s" % [kind, txt, where])
		_m.unlock()
	func take() -> PackedStringArray:
		_m.lock()
		var out := lines
		lines = PackedStringArray()
		_m.unlock()
		return out

var _srv: TCPServer
var _log: PeekLogger
var enabled := false
var _eval_id := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var port := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--peek="):
			port = int(a.substr(7))
		elif a == "--check-scripts":     # tools/check.mjs: compile every script (autoloads are known here, unlike under --script)
			set_process(false)
			_check_scripts()
			return
	if port == 0:
		set_process(false)
		return
	enabled = true
	_log = PeekLogger.new()
	OS.add_logger(_log)
	_srv = TCPServer.new()
	var e := _srv.listen(port, "127.0.0.1")
	if e != OK:
		push_error("peek: cannot listen on %d (%s)" % [port, error_string(e)])
		set_process(false)
		return
	print("PEEK READY %d" % port)
	# keep out of the user's way: no focus, moved past every monitor (a startup --position gets clamped; a runtime move does not)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
		var left := 0
		for i in DisplayServer.get_screen_count():
			left = mini(left, DisplayServer.screen_get_position(i).x)
		DisplayServer.window_set_position(Vector2i(left - DisplayServer.window_get_size().x - 200, 100))


func _check_scripts() -> void:
	var files: PackedStringArray = []
	_walk_scripts("res://", files)
	var bad := 0
	for f in files:
		if load(f) == null:
			print("BAD SCRIPT: ", f)
			bad += 1
	print("scripts checked: %d, bad: %d" % [files.size(), bad])
	get_tree().quit(1 if bad > 0 else 0)


func _walk_scripts(dir: String, out: PackedStringArray) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		if n != "." and n != ".." and not n.begins_with("."):
			var p := dir.path_join(n)
			if d.current_is_dir():
				if n != "assets":
					_walk_scripts(p, out)
			elif n.ends_with(".gd"):
				out.append(p)
		n = d.get_next()


func _process(_dt: float) -> void:
	while _srv.is_connection_available():
		_serve(_srv.take_connection())


func _serve(peer: StreamPeerTCP) -> void:
	var buf := PackedByteArray()
	var t0 := Time.get_ticks_msec()
	while true:
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			return
		var n := peer.get_available_bytes()
		if n > 0:
			var r: Array = peer.get_partial_data(n)
			buf.append_array(r[1])
			if buf.has(10):
				break
		if Time.get_ticks_msec() - t0 > 10000:
			return
		await get_tree().process_frame
	var msg: Variant = JSON.parse_string(buf.get_string_from_utf8())
	var out: Dictionary = await _run(msg if msg is Dictionary else {})
	var logs := _log.take()
	if logs.size() > 0:
		out["logs"] = logs
	peer.put_data((JSON.stringify(out) + "\n").to_utf8_buffer())
	peer.poll()
	await get_tree().process_frame
	peer.disconnect_from_host()
	if out.get("quit", false):
		get_tree().quit()


func _run(m: Dictionary) -> Dictionary:
	match String(m.get("cmd", "")):
		"eval":
			return await _eval(String(m.get("code", "")))
		"frames":
			for i in int(m.get("n", 1)):
				await get_tree().process_frame
			return {"ok": true}
		"shot":
			return await _shot(String(m.get("path", "")), int(m.get("w", 0)))
		"logs":
			return {"ok": true}
		"quit":
			return {"ok": true, "quit": true}
	return {"ok": false, "error": "unknown cmd"}


func _eval(code: String) -> Dictionary:
	var src := "extends RefCounted\nfunc run():\n"
	var lines := code.split("\n")
	var last_nonblank := -1
	for i in lines.size():
		if lines[i].strip_edges() != "":
			last_nonblank = i
	for i in lines.size():
		src += "\t" + lines[i] + "\n"
	if last_nonblank < 0:
		src += "\tpass\n"
	var s := GDScript.new()
	s.source_code = src
	_eval_id += 1
	var e := s.reload()
	if e != OK:
		return {"ok": false, "error": "compile failed: " + error_string(e)}
	var o: Object = s.new()
	var v: Variant = await o.run()
	return {"ok": true, "value": var_to_str(v) if not (v is String) else v}


func _shot(path: String, w: int) -> Dictionary:
	if path == "":
		return {"ok": false, "error": "no path"}
	await RenderingServer.frame_post_draw
	var tex := get_viewport().get_texture()
	if tex == null:
		return {"ok": false, "error": "no viewport texture (headless?)"}
	var img := tex.get_image()
	if w > 0 and img.get_width() > w:
		img.resize(w, int(float(img.get_height()) * w / img.get_width()), Image.INTERPOLATE_LANCZOS)
	var e := img.save_png(path)
	return {"ok": e == OK, "path": path, "error": error_string(e) if e != OK else ""}
