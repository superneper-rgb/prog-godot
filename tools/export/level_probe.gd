extends RefCounted
## Proof of an exported level, run inside the game through peek (node tools/export/export.mjs check <id>): the World's answers against the three.js World's on the probes.json
## points the exporter recorded, a bot walk along the level's route, and what the frame costs.

const TOL := 0.03


func run(walk: bool = true) -> String:
	var out := PackedStringArray()
	var lv: Level = Game.level
	if not lv is ExportedLevel:
		return "not an exported level: " + str(lv)
	var id := lv.id
	out.append("level %s: load %s" % [id, str((lv as ExportedLevel).timing)])
	out.append(ground_report(id))
	out.append(await perf_report())
	if walk:
		out.append(await walk_report(lv as ExportedLevel))
	return "\n".join(out)


## ground_height at every probe point (at least 2000 per level), then blocked and ceiling, against what the JS World said
func ground_report(id: String) -> String:
	var txt := FileAccess.get_file_as_string("res://assets/levels/%s/probes.json" % id)
	var p: Variant = JSON.parse_string(txt)
	if not p is Dictionary:
		return "no probes.json"
	var w: World = Game.world
	var r: float = p.get("r", 0.36)
	var bad := 0
	var n := 0
	var worst := []
	for g: Array in p["ground"]:
		var x: float = g[0]
		var z: float = g[1]
		var max_y: float = g[2]
		var js: float = g[3] if g[3] != null else -INF
		var h := w.ground_height(x, z, r, max_y)
		n += 1
		var diff := absf(h - js) if is_finite(h) and is_finite(js) else (0.0 if is_inf(h) == is_inf(js) else INF)
		if diff > TOL:
			bad += 1
			if worst.size() < 400:
				worst.append([diff, x, z, max_y, js, h])
	worst.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var s := "ground: %d points, %d mismatches (> %.2f m)" % [n, bad, TOL]
	for i in mini(8, worst.size()):
		var q: Array = worst[i]
		s += "\n  at %.2f, %.2f from %.2f: JS %.3f, Godot %.3f" % [q[1], q[2], q[3], q[4], q[5]]
	var bl_bad := 0
	var ce_bad := 0
	var m := 0
	var bl_ex := ""
	var ce_ex := ""
	for o: Array in p.get("other", []):
		m += 1
		var x: float = o[0]
		var z: float = o[1]
		var feet: float = o[2]
		var b := w.blocked(x, z, feet + 0.05, 1.1, r, 0.42)
		if b != (o[3] == 1.0):
			bl_bad += 1
			if bl_ex == "":
				bl_ex = " e.g. at %.2f, %.2f feet %.2f: JS %s, Godot %s" % [x, z, feet, str(o[3] == 1.0), str(b)]
		var c := w.ceiling(x, z, r, feet + 1.0, feet + 3.0)
		var jc: Variant = o[4]
		if (jc == null) != is_nan(c) or (jc != null and absf(float(jc) - c) > TOL):
			ce_bad += 1
			if ce_ex == "":
				ce_ex = " e.g. at %.2f, %.2f feet %.2f: JS %s, Godot %.3f" % [x, z, feet, str(jc), c]
	s += "\nblocked: %d of %d differ%s\nceiling: %d of %d differ%s" % [bl_bad, m, bl_ex, ce_bad, m, ce_ex]
	return s


## The route is what the level's data knows: F6 checkpoints where the kit has them, else the doors and actions. The bot walks from point to point with the real controller and input.
## A leg it cannot finish (a jump, a door that needs its logic) is reported, and the body is put at the next point. Stays under peek's two minute limit.
func walk_report(lv: ExportedLevel, budget_s: float = 90.0) -> String:
	var route: Array[Vector3] = []
	var pl: Player = Game.player
	var start := Vector3(pl.x, pl.y, pl.z)
	route.append(start)
	for r: Dictionary in lv.info.get("route", []):
		route.append(Vector3(r["x"], r["y"], r["z"]))
	if route.size() < 2:
		for key in ["portals", "actions"]:
			for a: Dictionary in lv.info.get(key, []):
				if a.has("x") and a.has("z") and a["x"] != null and a["z"] != null:
					route.append(Vector3(a["x"], pl.y, a["z"]))
	var marked := route.size() > 1
	if route.size() < 3:     # little marked: out and back along the four axes, with no teleports (walls in the way are fine: this only shows the body walks and stands)
		for d: Vector3 in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
			route.append(start + d * 4.0)
			route.append(start)
	# keep every leg if they fit; a long level samples its route evenly
	var legs := route.size() - 1
	var per := clampf(budget_s / legs, 3.0, 12.0)
	var step := maxi(1, int(ceil(legs * per / budget_s)))
	Inp.bot_on = true
	var res := PackedStringArray()
	var reached := 0
	var total := 0
	var dropped := 0
	var i := step
	while i <= legs:
		var tgt := route[i]
		if marked and i > step:     # each leg starts from the previous point of the route, wherever the last leg ended
			_place(pl, route[i - step])
		total += 1
		var t0 := Time.get_ticks_msec()
		var ok := false
		var closest := 1e9
		var stuck := 0.0
		var last := Vector2(pl.x, pl.z)
		while Time.get_ticks_msec() - t0 < per * 1000.0:
			var dx := tgt.x - pl.x
			var dz := tgt.z - pl.z
			var dist := sqrt(dx * dx + dz * dz)
			closest = minf(closest, dist)
			if dist < 1.5:
				ok = true
				break
			_steer(Game.rig.yaw, dx / dist, dz / dist)
			await Game.get_tree().process_frame
			if Vector2(pl.x, pl.z).distance_to(last) < 0.002:
				stuck += get_dt()
				if stuck > 0.4:    # against something: a hop, as a player would
					Inp.bot_held[&"jump"] = true
					await Game.get_tree().process_frame
					await Game.get_tree().process_frame
					Inp.bot_held.erase(&"jump")
					stuck = 0.0
			else:
				stuck = 0.0
			last = Vector2(pl.x, pl.z)
			if pl.y < Game.world.fall_reset_y + 2.0:
				dropped += 1
				break
		Inp.bot_move = Vector2.ZERO
		if ok:
			reached += 1
		else:
			res.append("  leg %d: closest %.1f m to %.1f, %.1f, %.1f (ended at %.1f, %.1f, %.1f)" % [i, closest, tgt.x, tgt.y, tgt.z, pl.x, pl.y, pl.z])
		i += step
	Inp.bot_on = false
	_place(pl, start)
	return "walk: %d of %d route legs reached, fell out %d times\n%s" % [reached, total, dropped, "\n".join(res)]


func _place(pl: Player, p: Vector3) -> void:
	pl.x = p.x
	pl.y = p.y + 0.05
	pl.z = p.z
	pl.vx = 0.0
	pl.vy = 0.0
	pl.vz = 0.0
	Game.rig.snap_to(pl)


## Look from anywhere (null pos: back to the rig), for checking what stands where.
func look(pos: Variant, at: Vector3 = Vector3.ZERO) -> void:
	(Game.level as ExportedLevel).dev_shot = View.Shot.new(pos, at) if pos != null else null
	for i in 10:
		await Game.get_tree().process_frame


## Stand where the exporter took its reference picture of the three.js build (F:/prog-godot-cache/tmp/export/ref-<id>-<k>.jpg); peek `shot` then shows the same view.
func view(k: int = 0) -> String:
	var id: String = Game.level.id
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string("F:/prog-godot-cache/tmp/export/views-%s.json" % id))
	if not v is Array or k >= (v as Array).size():
		return "no view %d" % k
	var d: Dictionary = v[k]
	var pl: Player = Game.player
	pl.x = d["x"]
	pl.y = d["y"]
	pl.z = d["z"]
	pl.yaw = d["yaw"]
	pl.vx = 0.0
	pl.vy = 0.0
	pl.vz = 0.0
	Game.rig.yaw = d["rig_yaw"]
	Game.rig.pitch = d["rig_pitch"]
	Game.rig.snap_to(pl)
	Game.rig.yaw = d["rig_yaw"]
	Game.rig.pitch = d["rig_pitch"]
	var lv := Game.level as ExportedLevel
	lv.dev_shot = null
	if d.has("cam"):     # the three.js camera itself (a level's intro may hold it somewhere the rig would not be)
		var c: Array = d["cam"]
		var l: Array = d["look"]
		lv.dev_shot = View.Shot.new(Vector3(c[0], c[1], c[2]), Vector3(l[0], l[1], l[2]))
	for i in 12:
		await Game.get_tree().process_frame
	return "view %d: %s at %.1f, %.1f, %.1f" % [k, d["name"], pl.x, pl.y, pl.z]


func get_dt() -> float:
	return Game.get_process_delta_time()


## world direction -> bot stick, in the player's camera-relative input
func _steer(yaw: float, wx: float, wz: float) -> void:
	var sy := sin(yaw)
	var cy := cos(yaw)
	Inp.bot_move = Vector2(-cy * wx + sy * wz, sy * wx + cy * wz)   # (player.gd: dx = sy * m.y - cy * m.x, dz = cy * m.y + sy * m.x)


func perf_report() -> String:
	var tree := Game.get_tree()
	var vp := Game.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	for i in 30:
		await tree.process_frame
	var t0 := Time.get_ticks_usec()
	var gpu := 0.0
	var cpu := 0.0
	var n := 120
	for i in n:
		await tree.process_frame
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
	var frame := (Time.get_ticks_usec() - t0) / 1000.0 / n
	var M := Performance
	return "perf: %d draw calls, %s primitives, %d objects, VRAM %.0f MB (textures %.0f, buffers %.0f), frame %.2f ms (render cpu %.2f, gpu %.2f), script process %.2f ms" % [
		M.get_monitor(M.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), String.num_int64(int(M.get_monitor(M.RENDER_TOTAL_PRIMITIVES_IN_FRAME))), M.get_monitor(M.RENDER_TOTAL_OBJECTS_IN_FRAME),
		M.get_monitor(M.RENDER_VIDEO_MEM_USED) / 1048576.0, M.get_monitor(M.RENDER_TEXTURE_MEM_USED) / 1048576.0, M.get_monitor(M.RENDER_BUFFER_MEM_USED) / 1048576.0,
		frame, cpu / n, gpu / n, M.get_monitor(M.TIME_PROCESS) * 1000.0]
