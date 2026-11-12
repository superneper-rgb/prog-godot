class_name Forge
extends Node
## FORGE, the in-game level editor (new on purpose, not a port; user 2026-11-09). F8 in any level switches between EDIT and PLAY.
## In EDIT the world holds still (Forge is one of Game.menus, so Game.menu_open() is true), you fly the Monitor camera and place, move, turn, copy and delete things:
## new things from the palette, and the original level itself, piece by piece (forge/forge_pieces.gd).
## What you build is the level: it is saved to assets/levels/<id>/edits.json (on leaving EDIT, on Ctrl+S, and when the level is left) and the level's ForgeLayer builds it every time.
## Every change is an op through ForgeLayer.apply (create / update / delete / batch by uid, naming only the fields that change), so undo, redo and a future co-op editor share one path.
## A placed thing's uid is "<author>-<n>"; an original piece's is "o:" + its id in pieces.json, and its record says how far it moved and turned, its tint, and whether it is deleted.
## This node owns one editor's session: EDIT on or off, the camera, the selection, the brush, the undo stack. What is placed belongs to the level (ForgeLayer); the panels are ForgeUi.
##
## Keys: WASD fly, Space / C up / down, Shift fast, Alt slow, right-drag look, wheel = speed. H hover, F focus (orbit the selection), T top-down view.
## Left click: place the brush (hold and sweep to paint a row; B scatters turn and size), or pick and drag (slides over surfaces, Shift+drag lifts, Ctrl+drag camera plane).
## Shift+click adds to the selection; a drag on empty space box-selects placed things (with Alt held, level pieces too). E carry the selection in front of you (wheel = distance). R / Shift+R turn 15 degrees, Alt+R 90.
## Q: the selection becomes the brush (a level piece too: stamp copies of it). Ctrl+D copy, Delete remove (a level piece is hidden, its colliders off), End drop to the floor.
## V collision view (every solid near you, the invisible walls in amber, deleted level pieces in red: click one to bring it back). Ctrl+Z / Ctrl+Y undo / redo, Ctrl+S save,
## G grid snap, P play from the pointer, Esc drop the brush / clear the selection, F1 help, F8 back to play.
## Pad (once in EDIT): sticks fly and look, RT / LT up / down, A place / carry / drop, B cancel, X delete, Y copy, LB / RB turn, D-pad picks from the palette, L3 hover, R3 focus.

const GRID := [0.0, 0.25, 0.5, 1.0]
const TURN := 15.0
const UNDO_MAX := 300
const LOOK := 0.0032
const SOLID_VIEW_R := 30.0        # metres around the camera the collision view draws

var is_open := false              # EDIT mode
var monitor := ForgeMonitor.new()
var ui: ForgeUi
var sel: Array[String] = []
var hover := ""
var brush: Variant = null         # catalogue entry while placing, else null
var brush_cat := "shape"
var brush_rot := Vector3.ZERO     # degrees: pitch, yaw, roll
var grid_i := 2
var scatter := false              # painting turns and sizes each copy a little at random
var show_solids := false          # the collision view
var undo_stack: Array = []        # [{do, undo}]
var redo_stack: Array = []
var drag: Variant = null          # {uids, lead, mode, q0, c0, start, moved}
var carry: Variant = null         # {uids, lead, dist, start, moved}
var marquee: Variant = null       # {a, b}: a box select being dragged (screen points)
var paint: Variant = null         # {last, mark}: the brush held down and swept
var top_view: Variant = null      # [pitch] to go back to from looking straight down
var air_dist := 8.0
var pad_mode := false             # the pointer is the screen centre (a pad is driving)
var pointer: Variant = null       # Vector2: a test puts the pointer here (the peek window sits off screen, where the real mouse cannot reach it)
var message := ""                 # a short line the UI shows ("SAVED")
var message_amber := false
var message_t := 0.0
var place_ok := false
var _ro := Vector3.ZERO
var _rd := Vector3.FORWARD
var _look := Vector2.ZERO
var _pad_prev := {}
var _ghost: MeshInstance3D = null
var _ghost_key := ""
var _ghost_mat: StandardMaterial3D
var _lines: MeshInstance3D = null
var _lines_mesh := ImmediateMesh.new()
var _hidden: Array = []          # the game's and the level's 2D pieces put away while editing (restored on leaving EDIT)
var _rng := RandomNumberGenerator.new()
var _ui_scan: Array[Node] = []
var _ui_scan_n := 0


func _init() -> void:
	name = "Forge"


func _ready() -> void:
	ui = ForgeUi.new(self)
	add_child(ui)
	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.albedo_color = Color(CrtTheme.PH, 0.26)
	_ghost_mat.cull_mode = BaseMaterial3D.CULL_DISABLED


func layer() -> ForgeLayer:
	var lv: Level = Game.level
	return lv.get_node_or_null("ForgeLayer") as ForgeLayer if lv != null else null


func pieces() -> ForgePieces:
	var L := layer()
	return L.get_pieces() if L != null else null


func grid() -> float:
	return GRID[grid_i]


# ---- EDIT on / off ----

func can_open() -> bool:
	return Game.started and Game.level != null and Game.world != null and not Game.paused and layer() != null and Game.overlay == null \
			and not Game.dialogue.on and not Game.doors.travelling and Game.cutscene_on() == null and not Game.ui.console.is_open


func toggle() -> void:
	set_edit(not is_open)


func set_edit(on: bool) -> void:
	if on == is_open:
		return
	if on:
		if not can_open():
			return
		is_open = true
		monitor.enable(Game.rig)
		Inp.capture_blocked = true
		Game.ui.unlock()
		_ensure_helpers()
		ui.set_edit(true)
		var t0 := Time.get_ticks_msec()
		var P := pieces()
		if P != null and Time.get_ticks_msec() - t0 > 300:
			_say("LEVEL PIECES READ IN %.1f S" % ((Time.get_ticks_msec() - t0) / 1000.0))
		return
	_end_drag()
	_end_carry()
	_end_paint()
	marquee = null
	is_open = false
	hover = ""
	Inp.capture_blocked = false
	Inp.guard_arm()
	save(false)
	_show_helpers(false)
	_restore_game_ui()
	ui.set_edit(false)
	if Game.started and not Game.paused:
		Game.ui.lock()


## Game.menus: back to the main menu closes it
func close() -> void:
	set_edit(false)


## Game.enter_level / leave_level: a level going away takes its unsaved edits to disk first
func level_left() -> void:
	set_edit(false)
	save(false)
	sel.clear()
	undo_stack.clear()
	redo_stack.clear()
	brush = null
	_ghost = null
	_lines = null
	_ghost_key = ""


func save(say: bool = true) -> void:
	var L := layer()
	if L == null or not L.edits.dirty:
		if say:
			_say("NOTHING NEW TO SAVE")
		return
	if L.edits.save():
		_say("SAVED  ·  " + ForgeEdits.path_for(L.edits.level_id).trim_prefix("res://"))
	else:
		_say("CANNOT SAVE IN A PACKED GAME: CHANGES ARE LIVE ONLY", true)


func _say(m: String, amber: bool = false) -> void:
	message = m
	message_amber = amber
	message_t = 3.0


# ---- the op path ----

## apply and remember for undo
func apply_op(op: Dictionary) -> void:
	var L := layer()
	if L == null:
		return
	var inv := L.apply(op)
	_push(op, inv)


func _push(op: Dictionary, inv: Dictionary) -> void:
	undo_stack.append({"do": op, "undo": inv})
	if undo_stack.size() > UNDO_MAX:
		undo_stack.pop_front()
	redo_stack.clear()


func undo() -> void:
	var L := layer()
	if L == null or undo_stack.is_empty() or drag != null or carry != null or paint != null:
		return
	var e: Dictionary = undo_stack.pop_back()
	L.apply(e.undo)
	redo_stack.append(e)
	_prune_sel()
	_say("UNDO")


func redo() -> void:
	var L := layer()
	if L == null or redo_stack.is_empty() or drag != null or carry != null or paint != null:
		return
	var e: Dictionary = redo_stack.pop_back()
	L.apply(e.do)
	undo_stack.append(e)
	_prune_sel()
	_say("REDO")


func _prune_sel() -> void:
	for uid in sel.duplicate():
		if not exists(uid):
			sel.erase(uid)


## what a thing is now, as an op would write it (null: no record, so a placed thing that is gone or an original piece as exported)
func _state(uid: String) -> Variant:
	var o := obj(uid)
	return o.to_fields() if o != null else null


## the op that takes a thing from one state to another
static func _transition(uid: String, from: Variant, to: Variant) -> Dictionary:
	if from == null and to == null:
		return {"op": "batch", "ops": []}
	if from == null:
		return {"op": "create", "uid": uid, "fields": to}
	if to == null:
		return {"op": "delete", "uid": uid}
	return {"op": "update", "uid": uid, "fields": to}


# ---- one interface over placed things and original pieces ----

func obj(uid: String) -> ForgeEdits.Obj:
	var L := layer()
	return L.edits.objects.get(uid) if L != null else null


static func is_orig(uid: String) -> bool:
	return ForgeLayer.is_orig(uid)


func exists(uid: String) -> bool:
	if is_orig(uid):
		var P := pieces()
		return P != null and P.obj(uid.substr(2)) != null
	return obj(uid) != null


## where a thing is: {pos (its middle), basis, size, yaw (degrees)}
func info(uid: String) -> Dictionary:
	var o := obj(uid)
	if is_orig(uid):
		var P := pieces()
		if P == null or P.obj(uid.substr(2)) == null:
			return {}
		var r := P.oriented(uid.substr(2), o)
		return {"pos": r[0], "basis": r[1], "size": r[2], "yaw": o.rot.y if o != null else 0.0}
	if o == null:
		return {}
	return {"pos": o.pos, "basis": ForgeLayer.obj_basis(o), "size": o.size, "yaw": o.rot.y}


## the op that sets these fields (an original piece gets its record the first time it is edited)
func _upsert(uid: String, fields: Dictionary) -> Dictionary:
	if is_orig(uid) and obj(uid) == null:
		var id := uid.substr(2)
		var po := pieces().obj(id)
		var f := {"type": "inst" if not po.inst.is_empty() else "piece", "id": id, "pos": [0.0, 0.0, 0.0], "rot": [0.0, 0.0, 0.0], "size": ForgeEdits.arr3(po.box.size), "color": "", "collide": true}
		f.merge(fields, true)
		return {"op": "create", "uid": uid, "fields": f}
	return {"op": "update", "uid": uid, "fields": fields}


func _pos_fields(uid: String, centre: Vector3) -> Dictionary:
	if is_orig(uid):
		return {"pos": ForgeEdits.arr3(centre - pieces().obj(uid.substr(2)).box.get_center())}
	return {"pos": ForgeEdits.arr3(centre)}


## an original piece that moves or switches in play is left alone (its level script drives it)
func editable(uid: String, say: bool = true) -> bool:
	if not is_orig(uid):
		return true
	var P := pieces()
	var po := P.obj(uid.substr(2)) if P != null else null
	if po == null:
		return false
	if po.dyn:
		if say:
			_say("THIS PART OF THE LEVEL MOVES IN PLAY: ITS LEVEL SCRIPT DRIVES IT, SO IT CANNOT BE EDITED HERE", true)
		return false
	return true


func _editable_sel() -> Array[String]:
	var out: Array[String] = []
	for u in sel:
		if editable(u):
			out.append(u)
	return out


func entry_for(cat: String, id: String) -> Variant:
	var L := layer()
	if cat == "copy":
		return ForgeCatalogue.copy_entry(L, id) if L != null else null
	return ForgeCatalogue.find(cat, id)


## what the selection card shows
func card() -> Dictionary:
	if sel.is_empty():
		return {}
	var u := sel[0]
	var o := obj(u)
	var more := "  +%d" % (sel.size() - 1) if sel.size() > 1 else ""
	var at := info(u)
	if at.is_empty():
		return {}
	var p: Vector3 = at.pos
	if is_orig(u):
		var po := pieces().obj(u.substr(2))
		var nm := po.name if po.name != "" else po.id.get_file()
		var state := "DELETED" if (o != null and o.hidden) else ("EDITED" if o != null else "AS BUILT")
		return {"title": nm.to_upper() + more, "info": "LEVEL PIECE  ·  %s  ·  %d COLLIDERS\nAT  %.2f  %.2f  %.2f\nTURN %.0f°   SIZE %.2f × %.2f × %.2f\n%s" % [state, po.solids.size(), p.x, p.y, p.z, at.yaw, po.box.size.x, po.box.size.y, po.box.size.z, "/".join(po.id.split("/").slice(-2))],
				"collide": o == null or o.collide, "orig": true, "edited": o != null, "hidden": o != null and o.hidden, "dyn": po.dyn}
	var e: Variant = entry_for(o.type, o.id)
	return {"title": (String(e.name) if e != null else o.id.to_upper()) + more, "info": "%s  ·  %s\nAT  %.2f  %.2f  %.2f\nTURN %.0f°   SIZE %.2f × %.2f × %.2f" % [ForgeCatalogue.tab_name(o.type), o.uid, p.x, p.y, p.z, o.rot.y, o.size.x, o.size.y, o.size.z],
			"collide": o.collide, "orig": false, "edited": true, "hidden": false, "dyn": false}


# ---- the things tests and the UI call ----

## place a catalogue entry; returns its uid ("" if there is no such entry)
func place(cat: String, id: String, pos: Vector3, rot: Vector3 = Vector3.ZERO, size: Variant = null, record: bool = true) -> String:
	var L := layer()
	var e: Variant = entry_for(cat, id)
	if L == null or e == null:
		return ""
	ForgeMeshes.mesh_for(e, "")       # (a model's exact size before its first copy)
	var sz: Vector3 = size if size is Vector3 else Vector3(e.base[0], e.base[1], e.base[2])
	var uid := L.edits.new_uid()
	var op := {"op": "create", "uid": uid, "fields": {"type": cat, "id": id, "pos": ForgeEdits.arr3(pos), "rot": ForgeEdits.arr3(rot), "size": ForgeEdits.arr3(sz),
			"color": String(e.color) if String(e.kind) != "model" and String(e.kind) != "copy" else "", "collide": true}}
	if record:
		apply_op(op)
	else:
		L.apply(op)
	return uid


func move_to(uid: String, pos: Vector3) -> void:
	if editable(uid):
		apply_op(_upsert(uid, _pos_fields(uid, pos)))


## delete: a placed thing goes, an original piece is hidden (its colliders off)
func remove(uids: Array) -> void:
	var ops: Array = []
	for uid: String in uids:
		if is_orig(uid):
			if editable(uid):
				ops.append(_upsert(uid, {"hidden": true}))
		elif obj(uid) != null:
			ops.append({"op": "delete", "uid": uid})
	if not ops.is_empty():
		apply_op({"op": "batch", "ops": ops})
	for uid: String in uids:
		if not is_orig(uid):
			sel.erase(uid)


## put original pieces back as the level was built
func restore(uids: Array) -> void:
	var ops: Array = []
	for uid: String in uids:
		if is_orig(uid) and obj(uid) != null:
			ops.append({"op": "delete", "uid": uid})
	if not ops.is_empty():
		apply_op({"op": "batch", "ops": ops})
		_say("RESTORED AS BUILT")


func set_collide(on: bool) -> void:
	var ops: Array = []
	for u in _editable_sel():
		ops.append(_upsert(u, {"collide": on}))
	if not ops.is_empty():
		apply_op({"op": "batch", "ops": ops})


func set_color(c: String) -> void:
	var ops: Array = []
	for u in _editable_sel():
		var o := obj(u)
		var want := c
		if c == "" and not is_orig(u):      # (× gives a dev shape its own colour back, a model or a copy its plain one)
			var e: Variant = entry_for(o.type, o.id)
			want = String(e.color) if e != null and String(e.kind) != "model" and String(e.kind) != "copy" else ""
		if o == null or o.color != want:
			ops.append(_upsert(u, {"color": want}))
	if not ops.is_empty():
		apply_op({"op": "batch", "ops": ops})


func select(uids: Array) -> void:
	sel.clear()
	for u: String in uids:
		sel.append(u)


func set_brush(cat: String, id: String) -> void:
	var e: Variant = entry_for(cat, id)
	brush = e
	brush_cat = cat
	if e != null:
		sel.clear()
		ForgeMeshes.mesh_for(e, "")


# ---- the frame (Game calls update through Game.menus while EDIT is on) ----

func update(_dt: float) -> void:
	var L := layer()
	if L == null:
		set_edit(false)
		return
	var dt: float = Game.frame_real_dt
	message_t = maxf(0.0, message_t - dt)
	_hide_game_ui()
	_fly(dt)
	_pad_buttons(L)
	_set_ray()
	if drag != null:
		_drag_step(L, Input.is_key_pressed(KEY_CTRL), Input.is_key_pressed(KEY_SHIFT))
	if carry != null:
		_carry_step(L)
	if paint != null:
		_paint_step(L)
	if marquee != null:
		marquee.b = _pointer()
	hover = "" if (drag != null or carry != null or brush != null or marquee != null) else String(_pick_any(L).get("uid", ""))
	_update_ghost(L)
	_draw_lines(L)
	ui.refresh()


func _typing() -> bool:
	return get_viewport().gui_get_focus_owner() is LineEdit or Game.ui.console.is_open


static func _dz(v: float) -> float:
	return 0.0 if absf(v) < 0.15 else (v - signf(v) * 0.15) / 0.85


func _fly(dt: float) -> void:
	var mv := Vector3.ZERO
	var pace := 1.0
	var keys := not Inp.real_off and not _typing() and not Input.is_key_pressed(KEY_CTRL)      # (Ctrl is for commands: Ctrl+D must not also strafe)
	if keys:
		var k := func(c: int) -> float: return 1.0 if Input.is_physical_key_pressed(c) else 0.0
		mv = Vector3(k.call(KEY_D) - k.call(KEY_A), k.call(KEY_SPACE) - k.call(KEY_C), k.call(KEY_W) - k.call(KEY_S))
		pace = 3.0 if Input.is_key_pressed(KEY_SHIFT) else (0.3 if Input.is_key_pressed(KEY_ALT) else 1.0)
	var pads := Input.get_connected_joypads()
	if pads.size() > 0 and not Inp.real_off:
		var id: int = pads[0]
		var lx := _dz(Input.get_joy_axis(id, JOY_AXIS_LEFT_X))
		var ly := _dz(Input.get_joy_axis(id, JOY_AXIS_LEFT_Y))
		var rx := _dz(Input.get_joy_axis(id, JOY_AXIS_RIGHT_X))
		var ry := _dz(Input.get_joy_axis(id, JOY_AXIS_RIGHT_Y))
		var up := Input.get_joy_axis(id, JOY_AXIS_TRIGGER_RIGHT) - Input.get_joy_axis(id, JOY_AXIS_TRIGGER_LEFT)
		if absf(lx) + absf(ly) + absf(rx) + absf(ry) + absf(up) > 0.05:
			pad_mode = true
		mv += Vector3(lx, up, -ly)
		monitor.look(rx * 2.4 * minf(dt, 0.1), ry * 1.8 * minf(dt, 0.1))
		if Input.is_joy_button_pressed(id, JOY_BUTTON_RIGHT_SHOULDER) and Input.is_joy_button_pressed(id, JOY_BUTTON_LEFT_SHOULDER):
			pace = 3.0
	monitor.look(_look.x * LOOK, _look.y * LOOK)
	_look = Vector2.ZERO
	monitor.update(dt, mv.limit_length(1.0) if mv.length() > 1.0 else mv, pace, Game.world)


func _pointer() -> Vector2:
	var vp := get_viewport()
	return pointer if pointer is Vector2 else (vp.get_visible_rect().size * 0.5 if pad_mode else vp.get_mouse_position())


func _set_ray() -> void:
	var cam: Camera3D = Game.camera
	var mp := _pointer()
	_ro = cam.project_ray_origin(mp)
	_rd = cam.project_ray_normal(mp)


## the nearest thing under the pointer, placed or original: {uid, t, n} or empty
func _pick_any(L: ForgeLayer) -> Dictionary:
	var best := {}
	var h := L.pick(_ro, _rd)
	if not h.is_empty():
		best = {"uid": String(h.uid), "t": float(h.t), "n": h.n}
	var P := pieces()
	if P != null:
		var q := P.pick(_ro, _rd, L.edits)
		if not q.is_empty() and (best.is_empty() or float(q.t) < float(best.t)):
			best = {"uid": "o:" + String(q.id), "t": float(q.t), "n": q.n}
		if show_solids:      # deleted pieces are clickable in the collision view (to bring them back)
			for u: String in L.edits.objects:
				var o: ForgeEdits.Obj = L.edits.objects[u]
				if not is_orig(u) or not o.hidden:
					continue
				var at := info(u)
				var r: Variant = ForgeLayer.box_hit(_ro, _rd, at.pos, at.basis, (at.size as Vector3) / 2.0)
				if r != null and (best.is_empty() or float(r[0]) < float(best.t)):
					best = {"uid": u, "t": float(r[0]), "n": r[1]}
	return best


func _snap(v: Vector3, keep: Vector3 = Vector3.ZERO) -> Vector3:
	var g := grid()
	if g <= 0.0:
		return v
	return Vector3(v.x if keep.x > 0.5 else roundf(v.x / g) * g, v.y if keep.y > 0.5 else roundf(v.y / g) * g, v.z if keep.z > 0.5 else roundf(v.z / g) * g)


## where an object of this size goes for the pointer: resting against the surface it points at (any direction), or in mid-air with Shift (or when it points at nothing)
func _placement(L: ForgeLayer, size: Vector3, yaw: float, skip: Dictionary) -> Variant:
	if Input.is_key_pressed(KEY_SHIFT) and drag == null:
		return _snap(_ro + _rd * air_dist)
	var h := L.surface(_ro, _rd, skip)
	if h.is_empty():
		return null
	var p: Vector3 = h.p
	var n: Vector3 = h.n
	if absf(n.y) < 0.5:      # the pointer caught the top edge of a side (a seam between two floor slabs): that is the floor, not the side
		var q: Vector3 = p - n * 0.03
		var top := Game.world.ground_pt(q.x, q.z, p.y + 0.1)
		if top > -INF and absf(top - p.y) < 0.12:
			p.y = top
			n = Vector3.UP
	p = _snap(p, Vector3(1.0 if absf(n.x) >= 0.5 else 0.0, 1.0 if absf(n.y) >= 0.5 else 0.0, 1.0 if absf(n.z) >= 0.5 else 0.0))
	var c: Vector3 = p + n * DevProps.reach_along(size, yaw, n)
	if absf(n.y) < 0.5:      # against a wall or a side: stand on whatever is below rather than sink into it
		var g := Game.world.ground_pt(c.x, c.z, h.p.y + 0.05)
		if g > -INF:
			c.y = maxf(c.y, g + size.y * 0.5)
	return c


# ---- mouse and keys ----

func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventMouseMotion:
		var m := event as InputEventMouseMotion
		pad_mode = false
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not Inp.real_off:
			_look += m.screen_relative
	elif event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		if b.button_index == MOUSE_BUTTON_LEFT and not b.pressed:
			_release()


func _release() -> void:
	if drag != null:
		_end_drag()
	if paint != null:
		_end_paint()
	if marquee != null:
		_end_marquee()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed or k.echo:
			return
		if k.keycode == KEY_F8:
			get_viewport().set_input_as_handled()
			toggle()
			return
		if is_open and not _typing() and _key(k):
			get_viewport().set_input_as_handled()
		return
	if not is_open or not event is InputEventMouseButton:
		return
	var b := event as InputEventMouseButton
	if not b.pressed:
		return
	var L := layer()
	if L == null:
		return
	get_viewport().set_input_as_handled()
	pad_mode = false
	_set_ray()
	if b.button_index == MOUSE_BUTTON_LEFT:
		_click(L, b.shift_pressed)
	elif b.button_index == MOUSE_BUTTON_WHEEL_UP or b.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_wheel(1.0 if b.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0, b.shift_pressed)


func _key(k: InputEventKey) -> bool:
	var ctrl := k.ctrl_pressed
	match k.keycode:
		KEY_ESCAPE:
			if ui.help_open():
				ui.toggle_help()
			elif carry != null:
				_end_carry()
			elif brush != null:
				brush = null
			else:
				sel.clear()
		KEY_F1:
			ui.toggle_help()
		KEY_Z:
			if not ctrl:
				return false
			if k.shift_pressed:
				redo()
			else:
				undo()
		KEY_Y:
			if not ctrl:
				return false
			redo()
		KEY_S:
			if not ctrl:
				return false
			save()
		KEY_D:
			if not ctrl:
				return false
			copy_selection()
		KEY_DELETE, KEY_BACKSPACE:
			remove(sel.duplicate())
		KEY_END:
			drop_to_floor()
		KEY_R:
			turn(90.0 if k.alt_pressed else (-TURN if k.shift_pressed else TURN))
		KEY_E:
			if carry != null:
				_end_carry()
			else:
				_begin_carry()
		KEY_G:
			grid_i = (grid_i + 1) % GRID.size()
			_say("GRID " + ("OFF" if grid() <= 0.0 else "%.2f M" % grid()))
		KEY_B:
			scatter = not scatter
			_say("SCATTER ON: PAINTED COPIES TURN AND SIZE A LITTLE" if scatter else "SCATTER OFF")
		KEY_V:
			show_solids = not show_solids
			_say("COLLISION VIEW ON  ·  amber = invisible walls  ·  red = deleted pieces" if show_solids else "COLLISION VIEW OFF")
		KEY_T:
			top_down()
		KEY_H:
			monitor.hover = not monitor.hover
			if monitor.hover:
				var g := Game.world.ground_pt(monitor.pos.x, monitor.pos.z, monitor.pos.y)
				monitor.hover_h = clampf(monitor.pos.y - g, 0.5, 200.0) if g > -INF else 6.0
			_say("HOVER ON" if monitor.hover else "HOVER OFF")
		KEY_F:
			focus()
		KEY_Q:
			brush_from_selection()
		KEY_P:
			play_here()
		KEY_TAB:
			ui.next_tab(-1 if k.shift_pressed else 1)
		_:
			if k.keycode >= KEY_1 and k.keycode <= KEY_9 and not ctrl:
				ui.pick_index(k.keycode - KEY_1)
			else:
				return false
	return true


func _click(L: ForgeLayer, add: bool) -> void:
	if carry != null:
		_end_carry()
		return
	if brush != null:
		var u := _place_brush(L)
		if u != "":
			paint = {"last": obj(u).pos, "mark": undo_stack.size() - 1}
		return
	var h := _pick_any(L)
	if h.is_empty():
		if not add:
			sel.clear()
		marquee = {"a": _pointer(), "b": _pointer(), "add": add, "level": Input.is_key_pressed(KEY_ALT)}
		return
	var uid := String(h.uid)
	if add:
		if sel.has(uid):
			sel.erase(uid)
		else:
			sel.append(uid)
		return
	if not sel.has(uid):
		select([uid])
	if editable(uid):
		_begin_drag(L, uid)


func _wheel(d: float, shift: bool) -> void:
	if carry != null:
		carry.dist = clampf(float(carry.dist) * (1.12 if d > 0.0 else 1.0 / 1.12), 1.0, 150.0)
	elif drag != null:
		turn(TURN * d)
	elif monitor.orbit != null:
		monitor.orbit_d = clampf(monitor.orbit_d * (1.0 / 1.12 if d > 0.0 else 1.12), 1.5, 120.0)
	elif brush != null and shift:
		air_dist = clampf(air_dist * (1.12 if d > 0.0 else 1.0 / 1.12), 1.0, 120.0)
	else:
		monitor.speed = clampf(monitor.speed * (1.15 if d > 0.0 else 1.0 / 1.15), 1.0, 120.0)
		_say("SPEED %.0f M/S" % monitor.speed)


func _brush_size() -> Vector3:
	var e: Dictionary = brush
	return Vector3(e.base[0], e.base[1], e.base[2])


func _place_brush(L: ForgeLayer, at: Variant = null) -> String:
	var e: Dictionary = brush
	var size := _brush_size()
	var p: Variant = at if at != null else _placement(L, size, brush_rot.y, {})
	if p == null:
		_say("POINT AT A SURFACE (OR HOLD SHIFT TO PLACE IN MID-AIR)", true)
		return ""
	var rot := brush_rot
	if scatter:
		rot.y = fposmod(rot.y + _rng.randf_range(-180.0, 180.0), 360.0)
		var k := _rng.randf_range(0.85, 1.15)
		size *= k
		(p as Vector3).y += (k - 1.0) * _brush_size().y * 0.5 if absf(brush_rot.x) < 1.0 else 0.0
	return place(brush_cat, String(e.id), p, rot, size)


## the brush held down and swept: another copy every time the pointer has gone one copy's width (or a grid step) from the last
func _paint_step(L: ForgeLayer) -> void:
	if brush == null:
		_end_paint()
		return
	var size := _brush_size()
	var p: Variant = _placement(L, size, brush_rot.y, {})
	if p == null:
		return
	var step := maxf(maxf(size.x, size.z) * (1.25 if scatter else 1.0), grid())
	if (p as Vector3).distance_to(paint.last) >= step:
		if _place_brush(L, p) != "":
			paint.last = p


## one sweep of the brush is one undo
func _end_paint() -> void:
	if paint == null:
		return
	var mark: int = paint.mark
	paint = null
	if undo_stack.size() - mark <= 1:
		return
	var dos: Array = []
	var undos: Array = []
	while undo_stack.size() > mark:
		var e: Dictionary = undo_stack.pop_back()
		dos.push_front(e.do)
		undos.append(e.undo)
	_push({"op": "batch", "ops": dos}, {"op": "batch", "ops": undos})
	_say("PAINTED %d" % dos.size())


func _end_marquee() -> void:
	var m: Dictionary = marquee
	marquee = null
	var r := Rect2(m.a, Vector2.ZERO).expand(m.b)
	if r.size.length() < 6.0:
		return
	var cam: Camera3D = Game.camera
	var L := layer()
	var found: Array[String] = []
	var inside := func(p: Vector3) -> bool: return not cam.is_position_behind(p) and cam.global_position.distance_to(p) < 250.0 and r.has_point(cam.unproject_position(p))
	for u: String in L.placed:
		if inside.call(L.edits.objects[u].pos):
			found.append(u)
	var P := pieces() if m.get("level", false) else null      # (level pieces only with Alt held: a box round some crates should not take the floor they stand on)
	if P != null:
		for po in P.objs:
			var u := "o:" + po.id
			var o := obj(u)
			if po.dyn or (o != null and o.hidden) or po.box.size.length() > 60.0:      # (not the giant shells: a box round a corner of the room should not take the room)
				continue
			if inside.call(info(u).pos):
				found.append(u)
	if not m.add:
		sel.clear()
	for u in found:
		if not sel.has(u):
			sel.append(u)
	_say("%d SELECTED" % sel.size())


# ---- moving: drag (mouse) and carry (Halo's grab) ----

func _starts(uids: Array) -> Dictionary:
	var out := {}
	for u: String in uids:
		out[u] = _state(u)
	return out


func _begin_drag(L: ForgeLayer, lead: String) -> void:
	var uids := _editable_sel()
	if not uids.has(lead):
		return
	drag = {"uids": uids, "lead": lead, "mode": "", "q0": null, "c0": info(lead).pos, "start": _starts(uids), "moved": false}
	L.hold(uids, true)


func _move_all(L: ForgeLayer, m: Dictionary, lead_to: Vector3) -> void:
	var d: Vector3 = lead_to - info(m.lead).pos
	if d.length_squared() < 1e-10:
		return
	var ops: Array = []
	for u: String in m.uids:
		ops.append(_upsert(u, _pos_fields(u, info(u).pos + d)))
	L.apply({"op": "batch", "ops": ops})      # (live: the whole move goes on the undo stack once, when it ends)
	m.moved = true


func _drag_step(L: ForgeLayer, ctrl: bool, shift: bool) -> void:
	var m: Dictionary = drag
	var lead := info(m.lead)
	if lead.is_empty():
		drag = null
		return
	var mode := "free" if ctrl else ("vert" if shift else "surf")
	if mode != m.mode:
		m.mode = mode
		m.q0 = null
		m.c0 = lead.pos
	if mode == "surf":
		var skip := {}
		for u: String in m.uids:
			skip[u] = true
		var p: Variant = _placement(L, lead.size, lead.yaw, skip)
		if p != null:
			_move_all(L, m, p)
		return
	var nrm: Vector3 = -Game.camera.global_basis.z
	if mode == "vert":
		nrm.y = 0.0
		if nrm.length_squared() < 1e-4:
			return
		nrm = nrm.normalized()
	var q: Variant = Plane(nrm, m.c0).intersects_ray(_ro, _rd)
	if q == null:
		return
	if m.q0 == null:
		m.q0 = q
	var dl: Vector3 = (q as Vector3) - (m.q0 as Vector3)
	var c: Vector3 = m.c0
	if mode == "vert":
		c.y += dl.y
	else:
		c += dl
	_move_all(L, m, _snap(c))


func _end_move(m: Variant) -> void:
	var L := layer()
	if m == null or L == null:
		return
	L.hold(m.uids, false)
	if not m.moved:
		return
	var fwd: Array = []
	var back: Array = []
	for u: String in m.uids:
		var now: Variant = _state(u)
		fwd.append(_transition(u, m.start[u], now))
		back.push_front(_transition(u, now, m.start[u]))
	_push({"op": "batch", "ops": fwd}, {"op": "batch", "ops": back})


func _end_drag() -> void:
	var m: Variant = drag
	drag = null
	_end_move(m)


func _begin_carry() -> void:
	var L := layer()
	if L == null:
		return
	if sel.is_empty() and hover != "":
		select([hover])
	var uids := _editable_sel()
	if uids.is_empty():
		return
	carry = {"uids": uids, "lead": uids[0], "dist": maxf(2.0, monitor.pos.distance_to(info(uids[0]).pos)), "start": _starts(uids), "moved": false}
	L.hold(carry.uids, true)


func _carry_step(L: ForgeLayer) -> void:
	if not exists(carry.lead):
		carry = null
		return
	_move_all(L, carry, _snap(monitor.pos + _rd * float(carry.dist)))


func _end_carry() -> void:
	var m: Variant = carry
	carry = null
	_end_move(m)


## turn the selection (or the brush) about its middle
func turn(deg: float) -> void:
	if brush != null:
		brush_rot.y = fposmod(brush_rot.y + deg, 360.0)
		return
	var uids := _editable_sel()
	if uids.is_empty():
		return
	var mid := Vector3.ZERO
	for u in uids:
		mid += info(u).pos
	mid /= uids.size()
	var b := Basis(Vector3.UP, deg_to_rad(deg))
	var ops: Array = []
	for u in uids:
		var at := info(u)
		var o := obj(u)
		var r: Vector3 = o.rot if o != null else Vector3.ZERO
		var f := _pos_fields(u, mid + b * (at.pos - mid))
		f["rot"] = ForgeEdits.arr3(Vector3(r.x, fposmod(r.y + deg, 360.0), r.z))
		ops.append(_upsert(u, f))
	if drag != null or carry != null:
		layer().apply({"op": "batch", "ops": ops})      # (inside a move: that move's one undo covers it)
		var m: Dictionary = drag if drag != null else carry
		m.moved = true
	else:
		apply_op({"op": "batch", "ops": ops})


## copy the selection beside itself (to the Monitor's right) and select the copies. A level piece is copied as a new thing made from its mesh.
func copy_selection() -> void:
	var L := layer()
	if L == null or sel.is_empty():
		return
	var w := 0.0
	for u in sel:
		var s: Vector3 = info(u).get("size", Vector3.ONE)
		w = maxf(w, maxf(s.x, s.z))
	var right := Vector3(-cos(monitor.yaw), 0.0, sin(monitor.yaw))
	var off := right * (w + 0.25)
	if grid() > 0.0:
		off = _snap(off)
	var ops: Array = []
	var made: Array[String] = []
	for u in sel:
		var f: Dictionary
		if is_orig(u):
			var id := u.substr(2)
			var e: Variant = ForgeCatalogue.copy_entry(L, id)
			if e == null:
				continue
			var at := info(u)
			var o := obj(u)
			f = {"type": "copy", "id": id, "pos": ForgeEdits.arr3(at.pos + off), "rot": ForgeEdits.arr3(Vector3(0.0, at.yaw, 0.0)), "size": ForgeEdits.arr3(at.size), "color": o.color if o != null else "", "collide": true}
		else:
			f = obj(u).to_fields()
			f.pos = ForgeEdits.arr3(obj(u).pos + off)
			f.erase("held_by")
		var nu := L.edits.new_uid()
		ops.append({"op": "create", "uid": nu, "fields": f})
		made.append(nu)
	if ops.is_empty():
		return
	apply_op({"op": "batch", "ops": ops})
	sel = made


## the selected thing becomes the brush (a level piece: stamp copies of it)
func brush_from_selection() -> void:
	if sel.is_empty():
		return
	var u := sel[0]
	if is_orig(u):
		var id := u.substr(2)
		if ForgeCatalogue.copy_entry(layer(), id) == null:
			_say("THIS PIECE CANNOT BE COPIED", true)
			return
		set_brush("copy", id)
		brush_rot = Vector3(0.0, info(u).get("yaw", 0.0), 0.0) if obj(u) != null else Vector3.ZERO
		_say("BRUSH: A COPY OF THIS LEVEL PIECE")
		return
	var o := obj(u)
	set_brush(o.type, o.id)
	brush_rot = o.rot


## let the selection fall onto whatever is below it
func drop_to_floor() -> void:
	var L := layer()
	var uids := _editable_sel()
	if L == null or uids.is_empty():
		return
	L.hold(uids, true)
	var ops: Array = []
	for u in uids:
		var at := info(u)
		var p: Vector3 = at.pos
		var half: float = (at.size as Vector3).y * 0.5
		var g := Game.world.ground_pt(p.x, p.z, p.y - half + 0.05)
		if g > -INF and absf(g + half - p.y) > 0.001:
			ops.append(_upsert(u, _pos_fields(u, Vector3(p.x, g + half, p.z))))
	L.hold(uids, false)
	if not ops.is_empty():
		apply_op({"op": "batch", "ops": ops})
		_say("DROPPED")


## look straight down at the level (again: back to how it was)
func top_down() -> void:
	if top_view == null:
		top_view = monitor.pitch
		monitor.orbit = null
		monitor.pitch = 1.5
		_say("TOP-DOWN VIEW  ·  T to go back")
	else:
		monitor.pitch = float(top_view)
		top_view = null


## orbit the selection (or what the pointer is on)
func focus() -> void:
	var uids: Array = sel if not sel.is_empty() else ([hover] if hover != "" else [])
	if uids.is_empty():
		monitor.orbit = null
		return
	var mid := Vector3.ZERO
	for u: String in uids:
		mid += info(u).pos
	mid /= uids.size()
	var r := 0.0
	for u: String in uids:
		var at := info(u)
		r = maxf(r, mid.distance_to(at.pos) + (at.size as Vector3).length() * 0.5)
	monitor.orbit_around(mid, maxf(4.0, r * 2.6))


## drop Prog where the pointer is (a floor) and go back to play
func play_here() -> void:
	var L := layer()
	var P: Player = Game.player
	if L == null or P == null:
		return
	var h := L.surface(_ro, _rd)
	if h.is_empty() or (h.n as Vector3).y < 0.5:
		_say("POINT AT A FLOOR TO PLAY FROM THERE", true)
		return
	var p: Vector3 = h.p
	P.x = p.x
	P.y = p.y
	P.z = p.z
	P.vx = 0.0
	P.vy = 0.0
	P.vz = 0.0
	set_edit(false)
	Game.rig.snap_to(P)


# ---- pad buttons (edges) ----

func _pad_hit(id: int, b: JoyButton) -> bool:
	var down := Input.is_joy_button_pressed(id, b)
	var was: bool = _pad_prev.get(b, false)
	_pad_prev[b] = down
	if down and not was:
		pad_mode = true
		return true
	return false


func _pad_buttons(L: ForgeLayer) -> void:
	var pads := Input.get_connected_joypads()
	if pads.is_empty() or Inp.real_off:
		return
	var id: int = pads[0]
	if _pad_hit(id, JOY_BUTTON_A):
		_set_ray()
		if carry != null or brush != null:
			_click(L, false)
			_end_paint()
		else:
			var h := _pick_any(L)
			if not h.is_empty():
				select([String(h.uid)])
				_begin_carry()
	if _pad_hit(id, JOY_BUTTON_B):
		if carry != null:
			_end_carry()
		elif brush != null:
			brush = null
		else:
			sel.clear()
	if _pad_hit(id, JOY_BUTTON_X):
		remove(sel.duplicate())
	if _pad_hit(id, JOY_BUTTON_Y):
		copy_selection()
	if _pad_hit(id, JOY_BUTTON_LEFT_SHOULDER):
		turn(TURN)
	if _pad_hit(id, JOY_BUTTON_RIGHT_SHOULDER):
		turn(-TURN)
	if _pad_hit(id, JOY_BUTTON_DPAD_LEFT):
		ui.step_item(-1)
	if _pad_hit(id, JOY_BUTTON_DPAD_RIGHT):
		ui.step_item(1)
	if _pad_hit(id, JOY_BUTTON_DPAD_UP):
		ui.next_tab(-1)
	if _pad_hit(id, JOY_BUTTON_DPAD_DOWN):
		ui.next_tab(1)
	if _pad_hit(id, JOY_BUTTON_LEFT_STICK):
		monitor.hover = not monitor.hover
	if _pad_hit(id, JOY_BUTTON_RIGHT_STICK):
		focus()
	if _pad_hit(id, JOY_BUTTON_BACK):
		set_edit(false)


# ---- the game's own screen stays out of the way while editing ----

## The HUD, the level's objective panels and prompts: every Control under the game UI but the dev console, and every CanvasLayer the level made.
## Done every frame, since some of them show themselves again from their own updates.
func _hide_game_ui() -> void:
	_ui_scan_n -= 1
	if _ui_scan_n <= 0 or _ui_scan.is_empty():      # (the level's tree is big: who to hide is looked up every 15 frames, hidden every frame)
		_ui_scan_n = 15
		_ui_scan.clear()
		for c: Node in Game.ui.get_children():
			if c is Control and c != Game.ui.console:
				_ui_scan.append(c)
		if Game.level != null:
			_ui_scan.append_array(Game.level.find_children("*", "CanvasLayer", true, false))
	for n: Node in _ui_scan:
		if not is_instance_valid(n):
			continue
		if n.get(&"visible") == true:
			n.set(&"visible", false)
			if not _hidden.has(n):
				_hidden.append(n)


func _restore_game_ui() -> void:
	for n: Variant in _hidden:
		if is_instance_valid(n):
			(n as Node).set(&"visible", true)
	_hidden.clear()
	_ui_scan.clear()


# ---- what is drawn in the world while editing (under the level's ForgeLayer, so it goes with the level) ----

func _ensure_helpers() -> void:
	var L := layer()
	if L == null:
		return
	if _lines == null or not is_instance_valid(_lines):
		_lines = MeshInstance3D.new()
		_lines.name = "ForgeLines"
		_lines.mesh = _lines_mesh
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.no_depth_test = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_lines.material_override = m
		_lines.extra_cull_margin = 16384.0
		_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		L.add_child(_lines)
	if _ghost == null or not is_instance_valid(_ghost):
		_ghost = MeshInstance3D.new()
		_ghost.name = "ForgeGhost"
		_ghost.material_override = _ghost_mat
		_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ghost.visible = false
		_ghost_key = ""
		L.add_child(_ghost)
	_show_helpers(true)


func _show_helpers(on: bool) -> void:
	if _lines != null and is_instance_valid(_lines):
		_lines.visible = on
	if _ghost != null and is_instance_valid(_ghost):
		_ghost.visible = on and brush != null


func _update_ghost(L: ForgeLayer) -> void:
	if _ghost == null or not is_instance_valid(_ghost):
		_ensure_helpers()
	place_ok = false
	if brush == null:
		_ghost.visible = false
		return
	var e: Dictionary = brush
	var key := ForgeMeshes.key_for(e, "")
	if key != _ghost_key:
		_ghost_key = key
		_ghost.mesh = ForgeMeshes.mesh_for(e, "")
	var size := _brush_size()
	var p: Variant = _placement(L, size, brush_rot.y, {})
	place_ok = p != null
	_ghost.visible = place_ok
	if place_ok:
		var b := Basis.from_euler(Vector3(deg_to_rad(brush_rot.x), deg_to_rad(brush_rot.y), deg_to_rad(brush_rot.z)))
		_ghost.transform = Transform3D(b * Basis.from_scale(ForgeMeshes.scale_for(e, "", size)), p)


func _box(c: Vector3, b: Basis, h: Vector3, col: Color) -> void:
	var cs: Array[Vector3] = []
	for k in 8:
		cs.append(c + b * Vector3(h.x * (1.0 if k & 1 else -1.0), h.y * (1.0 if k & 2 else -1.0), h.z * (1.0 if k & 4 else -1.0)))
	for e: Array in [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]:
		_lines_mesh.surface_set_color(col)
		_lines_mesh.surface_add_vertex(cs[e[0]])
		_lines_mesh.surface_set_color(col)
		_lines_mesh.surface_add_vertex(cs[e[1]])


func _thing_box(uid: String, col: Color) -> bool:
	var at := info(uid)
	if at.is_empty():
		return false
	_box(at.pos, at.basis, (at.size as Vector3) / 2.0 + Vector3.ONE * 0.02, col)
	return true


func _draw_lines(L: ForgeLayer) -> void:
	if _lines == null or not is_instance_valid(_lines):
		return
	_lines_mesh.clear_surfaces()
	_lines_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var n := 0
	for u in sel:
		var dead := is_orig(u) and obj(u) != null and obj(u).hidden
		if _thing_box(u, Color(CrtTheme.RED, 1.0) if dead else Color(CrtTheme.PH, 1.0)):
			n += 1
	if hover != "" and not sel.has(hover) and _thing_box(hover, Color(CrtTheme.PH_DIM, 0.55)):
		n += 1
	if brush != null and _ghost.visible:
		var bs := _brush_size()
		_box(_ghost.position, Basis.from_euler(Vector3(deg_to_rad(brush_rot.x), deg_to_rad(brush_rot.y), deg_to_rad(brush_rot.z))), bs / 2.0, Color(CrtTheme.PH, 0.8))
		n += 1
	if show_solids:
		n += _draw_solids(L)
	if n == 0:
		_lines_mesh.surface_add_vertex(Vector3.ZERO)      # (an ImmediateMesh surface cannot be empty)
		_lines_mesh.surface_add_vertex(Vector3.ZERO)
	_lines_mesh.surface_end()


## the collision view: every solid near the camera (the invisible walls in amber), and every deleted level piece in red
func _draw_solids(L: ForgeLayer) -> int:
	var n := 0
	var c := monitor.pos
	for s in Game.world.solids:
		if s.off or s.kind == "mesh" or s.kind == "field":
			continue
		if absf(s.cx - c.x) > SOLID_VIEW_R + s.hx + s.hz or absf(s.cz - c.z) > SOLID_VIEW_R + s.hx + s.hz:
			continue
		var inv := s.tag == "bound" or s.tag == "guard"
		var col := Color(CrtTheme.AMBER, 0.7) if inv else (Color(CrtTheme.PH, 0.9) if s.tag == "forge" else Color(CrtTheme.PH_DIM, 0.3))
		var hx := s.r if s.kind == "disc" else s.hx
		var hz := s.r if s.kind == "disc" else s.hz
		var mid := Vector3(s.cx, (s.bottom + s.top) * 0.5, s.cz)
		_box(mid, Basis(Vector3.UP, s.yaw), Vector3(hx, maxf(0.01, (s.top - s.bottom) * 0.5), hz), col)
		n += 1
	for u: String in L.edits.objects:
		if is_orig(u) and (L.edits.objects[u] as ForgeEdits.Obj).hidden and _thing_box(u, Color(CrtTheme.RED, 0.85)):
			n += 1
	return n
