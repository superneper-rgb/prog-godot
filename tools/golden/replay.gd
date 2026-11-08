extends RefCounted
## Replays tools/golden/scenarios.json through the Godot Player and CameraRig on the arena's collision and compares every frame with what the three.js game
## recorded (tools/golden/golden.json). Run inside the game at the arena level: node tools/peek.mjs eval 'return (load("res://tools/golden/replay.gd").new()).run()'

const NAMES := ["x", "y", "z", "yaw", "vx", "vy", "vz", "grounded", "mode", "flip", "cam_x", "cam_y", "cam_z", "cam_yaw", "cam_pitch", "look_x", "look_y", "look_z"]


## One scenario, frame by frame over a range: Godot vs JS camera and body.
func detail(name: String, f0: int, f1: int) -> String:
	var scenarios: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tools/golden/scenarios.json"))
	var golden: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/golden/golden.json"))
	var w: World = Game.world
	var keep := w.spawn
	var dt := 1.0 / 60.0
	var lines: PackedStringArray = []
	for sc: Dictionary in scenarios:
		if sc.name != name:
			continue
		var rows: Array = golden[sc.name]
		w.spawn = {"x": float(sc.start[0]), "y": float(sc.start[1]), "z": float(sc.start[2]), "yaw": float(sc.start[3])}
		var p := Player.new(w)
		var rig := CameraRig.new(w)
		p.reset()
		rig.snap_to(p)
		Inp.bot_on = true
		Inp.bot_held = {}
		Inp.bot_move = Vector2.ZERO
		Inp.bot_look = Vector2.ZERO
		Inp.step(dt)
		var f := 0
		for st: Array in sc.steps:
			var n := roundi(float(st[0]) * 60.0)
			var o: Dictionary = st[1]
			var mv: Array = o.get("move", [0, 0])
			var lk: Array = o.get("look", [0, 0])
			var hold: Array = o.get("hold", [])
			Inp.bot_held = {}
			for b: String in hold:
				Inp.bot_held[StringName(b)] = true
			Inp.bot_move = Vector2(float(mv[0]), float(mv[1]))
			Inp.bot_look = Vector2(float(lk[0]), float(lk[1]))
			for i in n:
				Inp.step(dt)
				p.update(dt, rig.yaw)
				rig.update(dt, p)
				p.events.clear()
				if f >= f0 and f <= f1:
					var g: Array = rows[f]
					lines.append("f%d body gd [%.3f %.3f %.3f] js [%.3f %.3f %.3f] | cam gd [%.3f %.3f %.3f] js [%.3f %.3f %.3f] | yaw %.3f/%.3f pitch %.3f/%.3f | fy %.3f dist %.3f clear %.3f lift %.3f free %.3f" % [f, p.x, p.y, p.z, g[0], g[1], g[2], rig.pos.x, rig.pos.y, rig.pos.z, g[10], g[11], g[12], rig.yaw, g[13], rig.pitch, g[14], rig.fy, rig.dist, rig.clear_dist, rig.lift, rig.boom.free])
				f += 1
	Inp.bot_on = false
	Inp.bot_held = {}
	Inp.bot_move = Vector2.ZERO
	Inp.bot_look = Vector2.ZERO
	w.spawn = keep
	return "\n".join(lines)


func run() -> String:
	var scenarios: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tools/golden/scenarios.json"))
	var golden: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/golden/golden.json"))
	var w: World = Game.world
	var keep := w.spawn
	var dt := 1.0 / 60.0
	var lines: PackedStringArray = []
	var worst_body := 0.0
	var worst_cam := 0.0
	for sc: Dictionary in scenarios:
		var rows: Array = golden[sc.name]
		w.spawn = {"x": float(sc.start[0]), "y": float(sc.start[1]), "z": float(sc.start[2]), "yaw": float(sc.start[3])}
		Config.jet_fuel = 0.0
		var p := Player.new(w)
		var rig := CameraRig.new(w)
		p.reset()
		rig.snap_to(p)
		Inp.bot_on = true
		Inp.bot_held = {}
		Inp.bot_move = Vector2.ZERO
		Inp.bot_look = Vector2.ZERO
		Inp.step(dt)     # clear edges
		var f := 0
		var max_pos := 0.0
		var max_pos_f := -1
		var max_v := 0.0
		var max_cam := 0.0
		var max_cam_f := -1
		var max_yaw := 0.0
		var mode_bad := -1
		var ground_bad := -1
		for st: Array in sc.steps:
			var n := roundi(float(st[0]) * 60.0)
			var o: Dictionary = st[1]
			var mv: Array = o.get("move", [0, 0])
			var lk: Array = o.get("look", [0, 0])
			var hold: Array = o.get("hold", [])
			Inp.bot_held = {}
			for b: String in hold:
				Inp.bot_held[StringName(b)] = true
			Inp.bot_move = Vector2(float(mv[0]), float(mv[1]))
			Inp.bot_look = Vector2(float(lk[0]), float(lk[1]))
			for i in n:
				Inp.step(dt)
				p.update(dt, rig.yaw)
				rig.update(dt, p)
				p.events.clear()
				var g: Array = rows[f]
				var dp := Vector3(p.x, p.y, p.z).distance_to(Vector3(g[0], g[1], g[2]))
				if dp > max_pos:
					max_pos = dp
					max_pos_f = f
				max_v = maxf(max_v, Vector3(p.vx, p.vy, p.vz).distance_to(Vector3(g[4], g[5], g[6])))
				max_yaw = maxf(max_yaw, absf(U.wrap_angle(p.yaw - float(g[3]))))
				var dc := rig.pos.distance_to(Vector3(g[10], g[11], g[12]))
				if dc > max_cam:
					max_cam = dc
					max_cam_f = f
				if mode_bad < 0 and String(p.mode) != String(g[8]):
					mode_bad = f
				if ground_bad < 0 and (1 if p.grounded else 0) != int(g[7]):
					ground_bad = f
				f += 1
		worst_body = maxf(worst_body, max_pos)
		worst_cam = maxf(worst_cam, max_cam)
		lines.append("%-22s body %.3f m (f%d)  vel %.2f  yaw %.3f  cam %.3f m (f%d)%s%s  end [%.3f %.3f %.3f] js [%.3f %.3f %.3f]" % [sc.name, max_pos, max_pos_f, max_v, max_yaw, max_cam, max_cam_f,
			("  MODE@f%d" % mode_bad) if mode_bad >= 0 else "", ("  GROUND@f%d" % ground_bad) if ground_bad >= 0 else "",
			p.x, p.y, p.z, rows[f - 1][0], rows[f - 1][1], rows[f - 1][2]])
	Inp.bot_on = false
	Inp.bot_held = {}
	Inp.bot_move = Vector2.ZERO
	Inp.bot_look = Vector2.ZERO
	w.spawn = keep
	lines.append("WORST body %.3f m, camera %.3f m" % [worst_body, worst_cam])
	return "\n".join(lines)
