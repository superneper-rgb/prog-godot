class_name Blockout
extends RefCounted
## BLOCKOUT KIT (JS levels/_kit/blockout.js): the framework kit levels stand on: stages and objectives (reach / hold / kill / custom / choice), checkpoints (F6 and the console's `cp`), the objective HUD, the guide
## ring, beam, label and arrow, death and respawn at the last saved objective, the boss bar, a level's own enemies. Static geometry comes from the export: `box` / `wall` / `ramp` are for pieces a level makes itself at run time.
## Stages and objectives are Dictionaries with the JS's fields in snake_case. Callbacks get the Blockout: on_start(bo, {retry}), on_done(bo), done(bo, P, C), next(bo), text(bo), rate(bo), when(bo), on_enter(bo, {objective, retry}).

const KIND_COLOR := {"reach": 0x39caff, "hold": 0xffc55c, "kill": 0xff5a4a, "custom": 0x39caff}
const TAGS := {"floor": 0x687984, "ramp": 0xd49b48, "cover": 0x93a3ac, "wall": 0x414d59, "plat": 0x839a9e, "hazard": 0xd75e45, "goal": 0x4aa66a}

var level: Level
var world: World
var opts: Dictionary
var id := ""
var display_name := ""
var mode := "blockout"      # blockout = everything on; playtest = no dev tools, guidance + HUD on; release = no dev tools and no guidance or HUD (the level has to guide the player itself)
var dev := true
var guides := true
var stages: Array[Dictionary] = []
var state := {"stage": 0, "obj": 0, "finished": false, "flags": {}, "time": 0.0, "progress": 0.0, "choice": null}
var saved := {"stage": 0, "obj": 0}
var checkpoints: Array[Dictionary] = []
var spawned: Array = []
var minigame_doors: Array = []
var last_p: Player = null
var last_c: Combat = null
var _was_dead := false
var _guide_on := true
var _started := false
var _via_idx := 0
var _via_for: Variant = null
var _mats: Dictionary = {}
var _root: Node3D
var _guide_root: Node3D
var _g_group: Node3D
var _g_ring: MeshInstance3D
var _g_disc: MeshInstance3D
var _g_beam: MeshInstance3D
var _g_label: Label3D
var _g_label_bg: Sprite3D
var _arrow: Node3D
var _hud: BlockoutHud


func _init(p_level: Level, p_opts: Dictionary) -> void:
	level = p_level
	world = p_level.world
	opts = p_opts
	id = String(p_opts.get("id", p_level.id))
	display_name = String(p_opts.get("name", id))
	var m := String(p_opts.get("mode", "blockout"))
	var s: Variant = Game.get("blockout_modes")
	if s is Dictionary and (s as Dictionary).has(id):      # JS: ?mode=, then the console's `mode <name>` (remembered per level)
		m = (s as Dictionary)[id]
	mode = m if m in ["blockout", "playtest", "release"] else "blockout"
	dev = mode == "blockout"
	guides = mode != "release"
	_guide_on = guides
	world.drone_leash = bool(p_opts.get("drone_leash", false))
	if p_opts.has("fall_reset_y"):
		world.fall_reset_y = float(p_opts["fall_reset_y"])
	if p_opts.has("spawn"):
		world.spawn.merge(Blockout.z(p_opts["spawn"]), true)
	_root = Node3D.new()
	_root.name = "Blockout"
	level.add_child(_root)
	_guide_root = Node3D.new()
	_guide_root.name = "Blockout guidance"
	_root.add_child(_guide_root)
	_build_guides()
	for p: Dictionary in p_opts.get("portals", []):
		level.portals.append(p)


## JS Z(): [x, y, z] or a {x, y, z, yaw} dictionary, as a dictionary.
static func z(a: Variant) -> Dictionary:
	if a is Array:
		return {"x": float(a[0]), "y": float(a[1]), "z": float(a[2])}
	if a is Vector3:
		return {"x": a.x, "y": a.y, "z": a.z}
	return a


# ---- pieces a level makes at run time (the static ones are in its export) ------------------------------------------

## Slab: footprint x0..x1 / z0..z1, top surface at `top`, `thick` metres thick (default 0.6). o: {tag, color, id, yaw, thick}
func box(x0: float, x1: float, z0: float, z1: float, top: float, o: Dictionary = {}) -> World.Solid:
	var thick: float = o.get("thick", 0.6)
	var tag: String = o.get("tag", "floor")
	var s := world.add({"kind": "box", "cx": (x0 + x1) / 2.0, "cz": (z0 + z1) / 2.0, "hx": absf(x1 - x0) / 2.0, "hz": absf(z1 - z0) / 2.0, "top": top, "bottom": top - thick, "tag": tag, "yaw": float(o.get("yaw", 0.0))})
	var m := BoxMesh.new()
	m.size = Vector3(absf(x1 - x0), thick, absf(z1 - z0))
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = _mat(tag, o.get("color"))
	mi.position = Vector3(s.cx, top - thick / 2.0, s.cz)
	mi.rotation.y = float(o.get("yaw", 0.0))
	_root.add_child(mi)
	s.mesh = mi
	return s


## Wall / pillar: footprint x0..x1 / z0..z1 from y `y0` up to `y1`.
func wall(x0: float, x1: float, z0: float, z1: float, y0: float, y1: float, o: Dictionary = {}) -> World.Solid:
	var d := {"tag": "wall"}
	d.merge(o, true)
	d["thick"] = y1 - y0
	return box(x0, x1, z0, z1, y1, d)


func _mat(tag: String, color: Variant) -> StandardMaterial3D:
	var c: int = color if color != null else int(TAGS.get(tag, TAGS["floor"]))
	if not _mats.has(c):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color.hex((c << 8) | 0xff)
		m.roughness = 0.9
		_mats[c] = m
	return _mats[c]


## a giant sealed door + SchleedTech terminal: E at the panel runs a minigame, winning opens the door (levels/_kit/minigame_door.gd)
func minigame_door(o: Dictionary) -> MinigameDoor:
	var d := MinigameDoor.new(level, world, o)
	minigame_doors.append(d)
	return d


## open / close a solid: set_solid(s, false) removes its collision AND mesh (a door that opens).
func set_solid(s: World.Solid, on: bool) -> void:
	s.set_off(not on)
	if s.mesh != null:
		(s.mesh as Node3D).visible = on


func flag(k: String, v: Variant = null) -> Variant:
	if v != null:
		state.flags[k] = v
	return state.flags.get(k)


func toast(m: String) -> void:
	Game.hud.toast(m, 2.2)


## teleport the player (and snap the camera)
func teleport(p: Variant, P: Player = last_p) -> void:
	if P == null:
		return
	world.spawn.merge(Blockout.z(p), true)
	P.reset()
	Game.rig.snap_to(P)


func boss_bar(b: Variant) -> void:
	if _hud != null:
		_hud.boss_bar(b)


# ---- enemies ---------------------------------------------------------------------------------------------------------

func spawn(pt: Variant, o: Dictionary = {}) -> Robot:
	var p := Blockout.z(pt)
	var kind: String = o.get("kind", "robot")
	var P := last_p
	var y: float = p["y"] if p.has("y") else world.ground_height(p.x, p.z, 0.6, 200.0)
	var yaw: float = p["yaw"] if p.has("yaw") else (atan2(P.x - p.x, P.z - p.z) if P != null else 0.0)
	var spec := o.duplicate()      # the rest of the spec rides along (a goon's costume / gun / alarm)
	spec["drone"] = kind == "drone"
	spec["no_respawn"] = true
	if kind == "robot" or kind == "drone":
		spec.erase("kind")
	var r: Robot = Game.spawn_enemy({"x": p.x, "y": y, "z": p.z, "yaw": yaw}, spec)
	if r == null:
		return null
	r.blockout = true
	if P != null:
		r._know(P.x, P.z)
		r.seen_t = 0.0
		r.set_(&"alert")
	if o.has("hp"):
		r.hp = float(o["hp"])
		r.max = float(o["hp"])
	spawned.append(r)
	var cb: Callable = opts.get("on_spawn", Callable())
	if not cb.is_null():
		cb.call(r, o, self)
	return r


func clear_enemies() -> void:
	for r: Robot in spawned:
		Game.despawn_enemy(r)
	spawned.clear()


# ---- stages + objectives -----------------------------------------------------------------------------------------------

func stage(def: Dictionary) -> Dictionary:
	var st := {"task": "", "objectives": [], "index": stages.size()}
	st.merge(def, true)
	var objs: Array = []
	var j := 0
	for raw: Dictionary in st["objectives"]:
		var o := raw.duplicate()
		var kind: String = raw.get("kind", "kill" if (raw.has("spawns") and not raw.has("at")) else "reach")
		var at: Variant = Blockout.z(raw["at"]) if raw.has("at") else null
		var d := {"radius": 2.2 if kind == "hold" else 2.5, "hold": 1.8, "save": true, "label": raw.get("id", "step %d" % (j + 1)),
			"text": "Defeat the hostiles." if kind == "kill" else ("Hold E at the marker." if kind == "hold" else "Reach the marker.")}
		d.merge(o, true)
		d["kind"] = kind
		d["at"] = at
		var via: Array = []
		for v: Variant in raw.get("via", []):
			via.append(Blockout.z(v))
		d["via"] = via
		d["spawns"] = raw.get("spawns", [])
		objs.append(d)
		j += 1
	st["objectives"] = objs
	if stages.is_empty() and st.has("spawn"):
		world.spawn.merge(Blockout.z(st["spawn"]), true)
	stages.append(st)
	return st


func cur() -> Dictionary:
	return stages[int(state.stage)] if int(state.stage) < stages.size() else {}


func cur_obj() -> Dictionary:
	var st := cur()
	if st.is_empty():
		return {}
	var objs: Array = st["objectives"]
	return objs[int(state.obj)] if int(state.obj) < objs.size() else {}


func _call(d: Dictionary, k: String, a: Variant = null) -> Variant:
	var c: Variant = d.get(k)
	if c is Callable and not (c as Callable).is_null():
		return (c as Callable).call(self, a) if a != null else (c as Callable).call(self)
	return null


func start_objective(j: int, retry: bool = false) -> void:
	state.obj = j
	state.progress = 0.0
	clear_enemies()
	var o := cur_obj()
	if o.is_empty():
		return
	for s: Dictionary in o["spawns"]:
		spawn(s, s)
	_call(o, "on_start", {"retry": retry})
	_place_guide(o)


func enter_stage(i: int, j: int = 0, o2: Dictionary = {}) -> void:
	state.stage = i
	state.finished = false
	var st := cur()
	if not o2.get("keep_flags", false):
		state.flags = {}
	var cb: Callable = opts.get("on_enter_stage", Callable())
	if not cb.is_null():
		cb.call(self, {"stage": st.get("id", ""), "objective": j, "retry": o2.get("retry", false), "restoring": not o2.get("keep_flags", false)})
	_call(st, "on_enter", {"objective": j, "retry": o2.get("retry", false)})
	start_objective(j, o2.get("retry", false))
	save()


func save() -> void:
	saved = {"stage": state.stage, "obj": state.obj}
	var o := cur_obj()
	var st := cur()
	var objs: Array = st.get("objectives", [])
	var prev: Dictionary = objs[int(state.obj) - 1] if int(state.obj) > 0 else {}
	var p: Variant = null
	if o.has("spawn"):
		p = Blockout.z(o["spawn"])
	elif prev.get("at") != null:
		var a: Dictionary = (prev["at"] as Dictionary).duplicate()
		a["y"] = float(a["y"]) + 0.1
		p = a
	elif st.has("spawn"):
		p = st["spawn"]
	if p != null:
		world.spawn.merge(Blockout.z(p), true)
	if Game.started:
		Game.save_game(true)      # the game autosaves here (CONTINUE resumes at this checkpoint)


func complete_objective() -> void:
	var st := cur()
	var o := cur_obj()
	_call(o, "on_done")
	var next: Variant = null
	var ch: Variant = state.get("choice")
	if ch is Dictionary and (ch as Dictionary).has("next"):
		next = (ch as Dictionary)["next"]
	if next == null and o.has("next"):
		next = _call(o, "next") if o["next"] is Callable else o["next"]
	if next == null and int(state.obj) == (st["objectives"] as Array).size() - 1 and st.has("next"):
		next = _call(st, "next") if st["next"] is Callable else st["next"]
	state.choice = null
	if next != null:
		for i in stages.size():
			if stages[i].get("id") == next:
				enter_stage(i, 0, {"keep_flags": true})
				return
		push_error("Unknown blockout stage: %s" % next)
		return
	if int(state.obj) + 1 < (st["objectives"] as Array).size():
		start_objective(int(state.obj) + 1)
		save()
		Game.sfx.menu_sound("pauseConfirm")
		return
	if int(state.stage) + 1 < stages.size():
		toast(String(st["name"]).to_upper() + " CLEARED")
		enter_stage(int(state.stage) + 1, 0, {"keep_flags": true})
		return
	state.finished = true
	clear_enemies()
	_g_group.visible = false
	_arrow.visible = false
	toast("LEVEL COMPLETE")
	var cb: Callable = opts.get("on_complete", Callable())
	if not cb.is_null():
		cb.call(self)


# ---- checkpoints (F6, the console's `cp`): built from the stages and objectives ------------------------------------------

func build_checkpoints() -> void:
	checkpoints.clear()
	var i := 0
	for st: Dictionary in stages:
		var num := "%02d" % (i + 1)
		checkpoints.append({"name": "%s %s" % [num, st["name"]], "key": st.get("id", ""), "stage": i, "obj": 0})
		var j := 0
		for o: Dictionary in st["objectives"]:
			if j > 0 or o.has("spawn"):
				var letters := "abcdefghijklmnopqrstuvwxyz"
				var lt: String = letters[j - 1] if j > 0 and j <= 26 else str(j)
				checkpoints.append({"name": "%s%s %s / %s" % [num, lt, st["name"], o["label"]], "key": "%s.%s" % [st.get("id", ""), o.get("id", j)], "stage": i, "obj": j})
			j += 1
		i += 1
	for e: Dictionary in opts.get("extra_checkpoints", []):
		checkpoints.append(e)


func _refill(C: Combat) -> void:
	for i: int in C.owned:
		var w := Weapons.WEAPONS[i]
		C.ammo[i] = w.mag_size
		C.reserve[i] = w.max - w.mag_size


func _clear_projectiles() -> void:
	if last_c == null:
		return
	last_c.enemies.bolts.clear()
	last_c.projs.clear()
	last_c.saws.clear()
	last_c.rocks.clear()
	last_c.wells.clear()


## Load a checkpoint: by index, name prefix ('03b'), key ('vault.cabinet') or stage id. Full health + ammo, fresh encounter, camera snapped.
func load_cp(which: Variant, obj: int = 0) -> bool:
	if last_p == null or last_c == null or stages.is_empty():
		return false
	var cp: Dictionary = {}
	if which is int:
		if int(which) >= 0 and int(which) < checkpoints.size():
			cp = checkpoints[int(which)]
	else:
		var w := String(which)
		for c: Dictionary in checkpoints:
			if c["key"] == w or c["name"] == w or String(c["name"]).begins_with(w + " "):
				cp = c
				break
		if cp.is_empty():
			for i in stages.size():
				if stages[i].get("id") == w:
					cp = {"stage": i, "obj": obj}
	if cp.is_empty():
		return false
	var st: Dictionary = stages[int(cp["stage"])]
	var objs: Array = st["objectives"]
	var oi := int(cp["obj"])
	var o: Dictionary = objs[oi] if oi < objs.size() else {}
	var prev: Dictionary = objs[oi - 1] if oi > 0 else {}
	var at: Variant = null
	if cp.has("spawn"):
		at = cp["spawn"]
	elif o.has("spawn"):
		at = o["spawn"]
	elif oi == 0 and st.has("spawn"):
		at = st["spawn"]
	elif prev.get("at") != null:
		var a: Dictionary = (prev["at"] as Dictionary).duplicate()
		a["y"] = float(a["y"]) + 0.1
		at = a
	elif st.has("spawn"):
		at = st["spawn"]
	else:
		at = world.spawn
	var A := Blockout.z(at)
	var facing: float = float(A.get("yaw", 0.0))
	if o.get("at") != null:
		var ot: Dictionary = o["at"]
		facing = atan2(float(ot["x"]) - float(A["x"]), float(ot["z"]) - float(A["z"]))
	_clear_projectiles()
	clear_enemies()
	var p := A.duplicate()
	p["yaw"] = facing
	world.spawn.merge(p, true)
	last_p.respawn()
	Game.rig.snap_to(last_p)
	_refill(last_c)
	state.time = 0.0
	state.choice = null
	_was_dead = false
	enter_stage(int(cp["stage"]), oi, {"retry": true})
	world.spawn.merge(p, true)
	return true


func restart() -> bool:
	for i in checkpoints.size():
		if checkpoints[i]["stage"] == saved.stage and checkpoints[i]["obj"] == saved.obj:
			return load_cp(i)
	return load_cp(0)


# ---- guidance visuals (ring, beam, label, one arrow) ----------------------------------------------------------------------

## JS: MeshBasicMaterial, toneMapped false, so the colour is what reaches the screen.
func _flat(c: int, alpha: float, add: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_fog = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	if add:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_tint(m, c, alpha, add)
	return m


func _tint(m: StandardMaterial3D, c: int, alpha: float, add: bool) -> void:
	var col := Color.hex((c << 8) | 0xff)
	# These JS materials skip the tone map and blend on display values. Godot blends before its tone map, so the radiance that comes out as the JS's colour x alpha over a dark background goes in: for a blended one the blend's alpha then takes it back down. (A radiance of the full colour, as this was, came out far too bright and washed to lavender over the alley's road.)
	var r := Game.view.display_to_radiance(Color(col.r * alpha, col.g * alpha, col.b * alpha))
	if add:
		var a := r.linear_to_srgb()
		m.albedo_color = Color(a.r, a.g, a.b, 1.0)
	else:
		var b := Color(r.r / alpha, r.g / alpha, r.b / alpha).linear_to_srgb()
		m.albedo_color = Color(b.r, b.g, b.b, alpha)


func _build_guides() -> void:
	_g_group = Node3D.new()
	_g_group.name = "Objective marker"
	_g_group.visible = false
	_guide_root.add_child(_g_group)
	var ring := TorusMesh.new()      # JS RingGeometry(.88, 1): flat, squashed to nothing
	ring.inner_radius = 0.88
	ring.outer_radius = 1.0
	ring.rings = 48
	ring.ring_segments = 4
	_g_ring = MeshInstance3D.new()
	_g_ring.mesh = ring
	_g_ring.scale = Vector3(1.0, 0.001, 1.0)
	_g_ring.material_override = _flat(0x39caff, 0.95)
	_g_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_g_group.add_child(_g_ring)
	var disc := CylinderMesh.new()
	disc.top_radius = 0.88
	disc.bottom_radius = 0.88
	disc.height = 0.001
	disc.radial_segments = 48
	disc.rings = 1
	_g_disc = MeshInstance3D.new()
	_g_disc.mesh = disc
	_g_disc.material_override = _flat(0x39caff, 0.12)
	_g_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_g_group.add_child(_g_disc)
	var beam := CylinderMesh.new()
	beam.top_radius = 1.0
	beam.bottom_radius = 1.0
	beam.height = 40.0
	beam.radial_segments = 24
	beam.rings = 1
	beam.cap_top = false
	beam.cap_bottom = false
	_g_beam = MeshInstance3D.new()
	_g_beam.mesh = beam
	_g_beam.position.y = 20.0
	_g_beam.material_override = _flat(0x39caff, 0.1, true)
	_g_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_g_group.add_child(_g_beam)
	# the label: a dark plate with a coloured border and the objective's name, always on top
	var px := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	px.fill(Color.WHITE)
	var white := ImageTexture.create_from_image(px)
	_g_label_bg = Sprite3D.new()
	_g_label_bg.texture = white
	_g_label_bg.modulate = Color(8.0 / 255.0, 16.0 / 255.0, 22.0 / 255.0, 0.78)
	_g_label_bg.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_g_label_bg.no_depth_test = true
	_g_label_bg.shaded = false
	_g_label_bg.pixel_size = 1.0
	_g_label_bg.render_priority = 9
	_g_group.add_child(_g_label_bg)
	_g_label = Label3D.new()
	_g_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_g_label.no_depth_test = true
	_g_label.shaded = false
	_g_label.font = CrtTheme.font(&"sysb")
	_g_label.font_size = 40
	_g_label.outline_size = 0
	_g_label.render_priority = 10
	_g_group.add_child(_g_label)
	# the arrow: JS Shape (0, 1.5) (-.85, .2) (-.3, .2) (-.3, -1) (.3, -1) (.3, .2) (.85, .2), laid flat, pointing along +z
	var p := PackedVector3Array([Vector3(0, 0, 1.5), Vector3(-0.85, 0, 0.2), Vector3(0.85, 0, 0.2), Vector3(-0.3, 0, 0.2), Vector3(-0.3, 0, -1), Vector3(0.3, 0, -1), Vector3(0.3, 0, 0.2)])
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = p
	arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 3, 4, 5, 3, 5, 6])
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var ami := MeshInstance3D.new()
	ami.mesh = am
	var am_mat := _flat(0x39caff, 1.0)
	am_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	ami.material_override = am_mat
	ami.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arrow = Node3D.new()
	_arrow.name = "Next route step"
	_arrow.visible = false
	_arrow.add_child(ami)
	_guide_root.add_child(_arrow)


func _place_guide(o: Dictionary) -> void:
	var has_at: bool = o.get("at") != null
	_g_group.visible = has_at and _guide_on and not state.finished and o.get("guide") != false
	if not has_at:
		return
	var col: int = o.get("color", KIND_COLOR.get(o["kind"], KIND_COLOR["reach"]))
	_tint(_g_ring.material_override, col, 0.95, false)
	var area: bool = is_area(o) and not o.get("marker", false)
	var gr: float = area_r(o) if area else float(o["radius"])      # an area step shows only a faint zone + label (the arrow is the guide)
	_g_ring.visible = not area
	_tint(_g_disc.material_override, col, 0.07 if area else 0.12, false)
	_tint(_g_beam.material_override, col, 0.1, true)
	var at: Dictionary = o["at"]
	_g_group.position = Vector3(float(at["x"]), float(at["y"]) + 0.06, float(at["z"]))
	_g_group.scale = Vector3(gr, 1.0, gr)
	_g_beam.scale = Vector3.ONE
	var compact: bool = opts.get("compact_guides", false)
	_g_beam.visible = not compact and not area
	var title := String(o.get("title", o["label"])).to_upper().left(26)
	var y_off := (0.85 if (compact or area) else 3.2)
	var w_m := (2.4 if (compact or area) else 6.0)
	var h_m := (0.45 if (compact or area) else 1.125)
	_g_label.text = title
	_g_label.modulate = Color.hex((col << 8) | 0xff)
	_g_label.pixel_size = h_m / 96.0
	_g_label.position = Vector3(0.0, y_off, 0.0)
	_g_label.scale = Vector3(1.0 / gr, 1.0, 1.0 / gr)
	_g_label_bg.position = Vector3(0.0, y_off, 0.0)
	_g_label_bg.scale = Vector3(w_m / gr, h_m, 1.0 / gr)


func _active_objective(P: Player) -> Dictionary:
	var o := cur_obj()
	if o.get("kind") != "choice" or P == null:
		return o
	var best: Dictionary = {}
	var bd := INF
	for c: Dictionary in o["choices"]:
		if c.has("when") and not (c["when"] as Callable).call(self):
			continue
		var a := Blockout.z(c["at"])
		var d := U.hyp(P.x - float(a["x"]), P.z - float(a["z"]))
		if d < bd:
			bd = d
			best = c
	if best.is_empty():
		return o
	var m := o.duplicate()
	m.merge(best, true)
	m["kind"] = "reach"
	m["choice"] = true
	m["at"] = Blockout.z(best["at"])
	var via: Array = []
	for v: Variant in best.get("via", []):
		via.append(Blockout.z(v))
	m["via"] = via
	m["text"] = o.get("text", "")
	return m


func _update_guide(P: Player) -> void:
	var o := _active_objective(P)
	var hide: Callable = opts.get("hide_guides", Callable())
	var show: bool = _guide_on and not state.finished and o.get("at") != null and o.get("guide") != false and (hide.is_null() or not hide.call())
	if cur_obj().get("kind") == "choice" and o.get("at") != null:
		_place_guide(o)
	_g_group.visible = show
	if not show or P == null:
		_arrow.visible = false
		return
	var pulse: float = 1.0 + 0.04 * sin(float(state.time) * 5.0)
	_g_ring.scale = Vector3(pulse, 0.001, pulse)
	_g_beam.scale = Vector3(0.96, 1.0, 0.96)
	if not is_same(_via_for, o) and _via_for != o:
		_via_for = o
		_via_idx = 0
	var via: Array = o["via"]
	while _via_idx < via.size() and U.hyp(P.x - float(via[_via_idx]["x"]), P.z - float(via[_via_idx]["z"])) < 3.5:
		_via_idx += 1
	var goal: Dictionary = via[_via_idx] if _via_idx < via.size() else o["at"]
	var dx := float(goal["x"]) - P.x
	var dz := float(goal["z"]) - P.z
	var d := U.hyp(dx, dz)
	if d < area_r(o) + 2.0 and _via_idx >= via.size():
		_arrow.visible = false
		return
	var ahead := minf(6.0, d)
	var x := P.x + dx / d * ahead
	var zz := P.z + dz / d * ahead
	var f := world.ground_height(x, zz, 0.15, P.y + 1.0)
	_arrow.position = Vector3(x, (f if is_finite(f) else P.y) + 0.1, zz)
	_arrow.rotation.y = atan2(dx, dz)
	var s: float = 0.7 + 0.05 * sin(float(state.time) * 6.0)
	_arrow.scale = Vector3(s, s, s)
	_arrow.visible = true


# ---- what counts as being there ------------------------------------------------------------------------------------------

## A plain reach step is a general AREA, not a spot: the arrow leads the way and anywhere in the zone counts (`area:` sets its radius; `strict: true` = the exact `radius`).
## The ring + beam are for things you must work at (hold / kill / custom, levers), or a reach step with `marker: true`.
func is_area(o: Dictionary) -> bool:
	return o.get("kind") == "reach" and not o.get("choice", false) and not o.get("strict", false)


func area_r(o: Dictionary) -> float:
	var r: float = o["radius"]
	return float(o.get("area", maxf(r * 2.2, r + 5.0))) if is_area(o) else r


func in_range(P: Player, o: Dictionary) -> bool:
	var at: Variant = o.get("at")
	if at == null:
		return false
	var dy: float = o.get("dy", 4.5 if is_area(o) else 3.0)
	return U.hyp(P.x - float(at["x"]), P.z - float(at["z"])) < area_r(o) + (0.6 if o.get("kind") == "hold" else 0.0) and absf(P.y - float(at["y"])) < dy


func _can_expire(o: Dictionary) -> bool:
	return o.get("kind") == "reach" and not o.get("strict", false) and not o.get("choice", false) and not o.has("next")


## Route markers expire once the player is beyond them, even beside the route or beyond the NEXT marker. Distance-to-next alone strands players after an overshoot.
## The incoming leg also handles the final marker, where there is no next target.
func _passed_by(P: Player, o: Dictionary) -> bool:
	if not _can_expire(o) or o.get("at") == null:
		return false
	var st := cur()
	var objs: Array = st["objectives"]
	var si := int(state.stage)
	var oi := int(state.obj)
	var n: Dictionary = {}
	if oi + 1 < objs.size():
		n = objs[oi + 1]
	elif si + 1 < stages.size() and not (stages[si + 1]["objectives"] as Array).is_empty():
		n = stages[si + 1]["objectives"][0]
	# Arriving at the next interaction is sufficient evidence of route progress; the interaction itself still has to be performed.
	if n.get("at") != null and in_range(P, n):
		return true
	var at: Dictionary = o["at"]
	if P.y < float(at["y"]) - float(o.get("dy", 4.5)):
		return false
	var previous: Variant = null
	if oi > 0 and (objs[oi - 1] as Dictionary).get("at") != null:
		previous = objs[oi - 1]["at"]
	elif st.has("spawn"):
		previous = Blockout.z(st["spawn"])
	elif si > 0 and not (stages[si - 1]["objectives"] as Array).is_empty() and (stages[si - 1]["objectives"].back() as Dictionary).get("at") != null:
		previous = stages[si - 1]["objectives"].back()["at"]
	elif opts.has("spawn"):
		previous = Blockout.z(opts["spawn"])
	var via: Array = o["via"]
	var approach: Variant = via.back() if not via.is_empty() else previous
	var radius: float = o["radius"]
	var beyond := func(from: Variant, to: Variant) -> bool:
		if from == null or to == null:
			return false
		var dx := float(to["x"]) - float(from["x"])
		var dz := float(to["z"]) - float(from["z"])
		var span := U.hyp(dx, dz)
		if span < 0.01:
			return false
		var px := P.x - float(at["x"])
		var pz := P.z - float(at["z"])
		var forward := (px * dx + pz * dz) / span
		var sideways := absf(px * dz - pz * dx) / span
		return forward > radius and sideways <= maxf(span, area_r(o) * 2.0)
	# On a bend, being on the next leg's side while still BEFORE this marker is not an overshoot. Get near the incoming leg's end before using that exit.
	var ax := float(at["x"]) - (float(approach["x"]) if approach != null else float(at["x"]))
	var az := float(at["z"]) - (float(approach["z"]) if approach != null else float(at["z"]))
	var length := U.hyp(ax, az)
	var approached := length < 0.01 or ((P.x - float(at["x"])) * ax + (P.z - float(at["z"])) * az) / length >= -area_r(o)
	var nat: Variant = n.get("at")
	return beyond.call(approach, at) or (approached and beyond.call(at, nat))


## progress is monotonic: standing in a LATER reach circle of this stage means every plain reach step before it was passed, whatever line the player took.
## Returns the index of the furthest such objective (or -1). Stops at anything that is not a plain reach step.
func _skip_target(P: Player) -> int:
	var objs: Array = cur()["objectives"]
	var target := -1
	for k in range(int(state.obj) + 1, objs.size()):
		if not _can_expire(objs[k - 1]):
			break
		if objs[k].get("kind") == "reach" and not objs[k].get("strict", false) and in_range(P, objs[k]):
			target = k
	return target


# ---- per frame -------------------------------------------------------------------------------------------------------------

func on_level_entered() -> void:
	build_checkpoints()
	_hud = BlockoutHud.new(self)
	Game.ui.add_child(_hud)


func dispose() -> void:
	if _hud != null:
		_hud.queue_free()
		_hud = null


func update(dt: float, P: Player, C: Combat) -> void:
	if C != null:
		last_c = C
	if P != null:
		last_p = P
	for d: Variant in minigame_doors:
		d.update(dt, P)
	if stages.is_empty():
		return
	if P != null and not _started:
		_started = true
		enter_stage(0, 0)      # first frame with a player: enemies need the combat system
	if P != null and dt > 0.0:
		if not state.finished:
			state.time = float(state.time) + dt
		if _was_dead and not P.dead:
			_clear_projectiles()
			_refill(C)
			enter_stage(int(saved.stage), int(saved.obj), {"retry": true, "keep_flags": true})
		_was_dead = P.dead
		var o := cur_obj()
		if not o.is_empty() and not state.finished and not P.dead:
			var done := false
			var kind: String = o["kind"]
			if kind == "reach":
				var k := -1 if o.get("strict", false) else _skip_target(P)
				if k > int(state.obj):      # went on to a later circle: finish the skipped steps in order, ending ON that circle (it then completes itself)
					var stage0: int = state.stage
					for n in 32:
						if int(state.stage) != stage0 or int(state.obj) >= k or state.finished:
							break
						var before: int = state.obj
						complete_objective()
						if int(state.obj) == before:
							break
				else:
					done = in_range(P, o) or _passed_by(P, o)
			elif kind == "hold":
				var held := Inp.btn(&"b").held
				var rate: float = float(_call(o, "rate")) if o.has("rate") else 1.0
				var step: float = (dt / float(o["hold"]) * rate) if (in_range(P, o) and held) else (0.0 if o.get("keep", false) else -dt * 2.0)
				state.progress = clampf(float(state.progress) + step, 0.0, 1.0)
				done = float(state.progress) >= 1.0
			elif kind == "choice":
				for c: Dictionary in o["choices"]:
					if c.has("when") and not (c["when"] as Callable).call(self):
						continue
					var m := o.duplicate()
					m.merge(c, true)
					m["at"] = Blockout.z(c["at"])
					if in_range(P, m):
						state.choice = c
						_call(c, "on_done")
						done = true
						break
			elif kind == "kill":
				if not spawned.is_empty():
					done = true
					for r: Robot in spawned:
						if not r.dead and not r.gone:
							done = false
							break
				else:
					done = (o["spawns"] as Array).is_empty()
			elif kind == "custom":
				var cb: Variant = o.get("done")
				done = cb is Callable and bool((cb as Callable).call(self, P, C))
			if done:
				complete_objective()
	var up: Callable = opts.get("on_update", Callable())
	if not up.is_null():
		up.call(dt, P, C, self)
	_update_guide(P)
	if _hud != null:
		_hud.update_hud(P)
	# dev keys (JS: F4 / F6 / F7 only exist in blockout mode)
	if dev and P != null:
		if Inp.key_hit(KEY_F4):
			var s := "[%.1f, %.1f, %.1f]" % [P.x, P.y, P.z]
			DisplayServer.clipboard_set(s)
			toast("POSITION " + s)
		if Inp.key_hit(KEY_F7):
			_guide_on = not _guide_on
			_guide_root.visible = _guide_on
			toast("GUIDES " + ("ON" if _guide_on else "OFF"))
		if Inp.key_hit(KEY_F6) and _hud != null:
			_hud.toggle_menu()
