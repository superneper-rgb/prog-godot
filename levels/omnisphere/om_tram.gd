class_name OmTram
extends RefCounted
## OMNISPHERE: THE RUNAWAY TRAM (JS tram.js, the Dead Cableway, after pylon 4 goes). A freight tram sits at the siding beside pylon 3; step onto its bed and the brakes let go. It runs the whole loop flat out: drone bays on the rail pylons launch as it passes, two goons fire down from the signal gantry, a heavy steps onto the rail and gets rammed off it, the tram jumps the section where the girder has sagged into the magma, comes in through Gamma's north railing, derails across the deck and buries itself in the old cable-wheel frame. Get off before it does. The bed is a moving Solid on the shared mover glue (it carries PROG with the tram's turns). The track and art are exported; the path is the exporter's.

var bo: Blockout
var sets: OmSets
var sec: OmSecurity
var audio: OmAudio
var alarm: Callable
var path: OmPath
var LEN := 0.0
var S_GAP0 := 0.0
var S_GAP1 := 0.0
var S_DECK := 0.0
var S_END := 0.0
var S_RAM := 0.0
var S_GANTRY := 0.0
var GY := 0.0
var RY := 0.0
var gq: Vector3
var gs: Vector3
var gt: Vector3
var rq: Vector3
var rt: Vector3
var bays: Array = []
var tram: Node3D
var beacon: MeshInstance3D
var bed: World.Solid
var crate_s: Array = []
var cab_s: World.Solid
var brk: Node3D
var brk_home := Vector3(-142, 18, -61.82)
var brk_v := Vector3.ZERO
var brk_fly := false
var armed := false
var s := 0.0
var v := 0.0
var ph := "parked"
var t := 0.0
var gantry_done := false
var ram_done := false
var heavy: Robot = null
var derail := 0.0
var warned := false
var took := false
var landed := false
var on_deck := false
var spots := {}
const CRATES := [[-1.4, -3.6], [1.3, -2.0]]


func _init(lv: ExportedLevel, p_bo: Blockout, p_sets: OmSets, p_sec: OmSecurity, p_audio: OmAudio, p_alarm: Callable) -> void:
	bo = p_bo
	sets = p_sets
	sec = p_sec
	audio = p_audio
	alarm = p_alarm
	var d: Dictionary = lv.info.data.omni_data.tram
	path = OmPath.new(d.pts, d.len)
	LEN = path.length
	S_GAP0 = d.gap0
	S_GAP1 = S_GAP0 + 11.0
	S_DECK = d.deck
	S_END = LEN - 1.5
	S_RAM = d.ram
	S_GANTRY = d.gantry
	const RAIL := 1.7
	gq = path.at(S_GANTRY)
	gt = path.tan(S_GANTRY)
	gs = Vector3(-gt.z, 0.0, gt.x).normalized()
	GY = gq.y + 5.2
	rq = path.at(S_RAM)
	rt = path.tan(S_RAM)
	RY = rq.y - RAIL
	# drone bays on the rail pylons
	for i in (d.bays as Array).size():
		var q: Array = d.bay_pos[i]
		bays.append({"d": d.bays[i], "bay": sec.drone_bay(q[0], q[1], q[2]), "used": false})
	tram = VhKit.one(lv, "om-tram")
	beacon = MsKit.sprite8(tram, 0xffa020, .9, 1.6)
	beacon.position = Vector3(0, 3.5, 4.2)
	var sol := VhKit.solids(lv.world)
	bed = (sol["tram-bed"] as Array)[0]
	crate_s = sol["tram-crate"]
	cab_s = (sol["tram-cab"] as Array)[0]
	brk = VhKit.one(lv, "om-tram-rail")
	sets.mechs.add_custom([bed, crate_s[0], crate_s[1], cab_s], true, func(_tt: float, dt: float, P: Player) -> void: _step(dt, P))
	var board := path.at(3.0)
	var after := path.at(S_GAP1 + 6.0)
	spots = {"board": [board.x, board.y + .1, board.z], "after_jump": [after.x, after.y + .1, after.z]}


static func _loc(lx: float, lz: float, yaw: float, cx: float, cz: float) -> Vector2:
	return Vector2(cx + sin(yaw) * lz + cos(yaw) * lx, cz + cos(yaw) * lz - sin(yaw) * lx)


func _pose() -> void:
	var p := path.at(s)
	var tn := path.tan(s)
	var yaw := atan2(tn.x, tn.z) + derail * .9
	var pitch := -asin(clampf(tn.y, -1.0, 1.0))
	var y := p.y
	if s > S_GAP0 - 2.0 and s < S_GAP1 + 2.0:      # the jump
		var u := (s - (S_GAP0 - 2.0)) / (S_GAP1 - S_GAP0 + 4.0)
		y += sin(u * PI) * 3.2
	if s > S_DECK:
		y = maxf(18.6, y)
	tram.position = Vector3(p.x, y + sin(t * 31.0) * .03 * minf(1.0, v / 6.0), p.z)
	tram.rotation = Vector3(pitch, yaw, sin(t * 1.7) * .02 * minf(1.0, v / 8.0) + derail * .12)
	bed.place(p.x, p.z, yaw)
	bed.set_span(y - .6, y)
	for i in 2:
		var q := _loc(CRATES[i][0], CRATES[i][1], yaw, p.x, p.z)
		var c: World.Solid = crate_s[i]
		c.place(q.x, q.y, yaw)
		c.set_span(y, y + 1.1)
	var q := _loc(0.0, 4.2, yaw, p.x, p.z)
	cab_s.place(q.x, q.y, yaw)
	cab_s.set_span(y, y + 3.0)


func _on_bed(P: Player) -> bool:
	return P != null and not P.dead and absf(P.y - bed.top) < .4 and bed.top_at(P.x, P.z) != null


func _step(dt: float, P: Player) -> void:
	t += dt
	var C: Combat = Game.combat
	var fx: Variant = Game.fx
	if ph == "parked":
		if _on_bed(P):
			ph = "release"
			t = 0.0
			audio.play_at("groan", tram.position)
			audio.play_at("sparks", tram.position)
			Game.hud.toast("THE BRAKES ARE GONE  -  HOLD ON", 2.4)
			alarm.call(6.0)
		_pose()
		return
	if ph == "release":
		if randf() < .6:
			fx.sparks(tram.position + Vector3(0, -1.3, 0), 6, 6.0, null, 0xffc060)
		if t > .9:
			ph = "run"
			t = 0.0
		_pose()
		return
	if ph == "run":
		var want := 13.0 if s > S_DECK - 30.0 else (14.0 if s > S_GAP0 - 25.0 and s < S_GAP0 else 11.5)      # it builds speed into the jump and into the station
		v += (want - v) * minf(1.0, dt * .55)
		s += v * dt
		if randf() < dt * 18.0:
			fx.sparks(tram.position + Vector3((randf() - .5) * 2.0, -1.4, 0.0), 3, 5.0, null, 0xffc060)
		# drone bays launch as it closes on them
		for b: Dictionary in bays:
			if not b.used and s > float(b.d) - 34.0:
				b.used = true
				sec.inject({"via": "bay", "bay": b.bay, "rise": 4.0})
		# the far-off stations are manned from the moment it lets go: two goons on the signal gantry, a heavy planted on the rail at the hut (all far away, in plain view)
		if not gantry_done and armed:
			gantry_done = true
			for q: Array in [[0, 2.0], [1, -2.5]]:
				bo.spawn({"x": gq.x + gs.x * float(q[1]), "y": GY + .35, "z": gq.z + gs.z * float(q[1]), "yaw": atan2(-gt.x, -gt.z)}, {"kind": "goon", "costume": "security", "gun": "smg" if int(q[0]) != 0 else "pistol"})
			var r: Robot = bo.spawn({"x": rq.x, "y": RY + .1, "z": rq.z, "yaw": atan2(-rt.x, -rt.z)}, {"kind": "robot", "heavy": "assault"})
			if r != null:
				heavy = r
		if heavy != null and not warned and s > S_RAM - 70.0:
			warned = true
			Game.hud.toast("HEAVY ON THE TRACK  -  BRACE", 1.8)
		if heavy != null and not ram_done and s > S_RAM - 3.0:
			ram_done = true
			if not heavy.dead:
				C.damage(heavy, 9999.0, {"x": tram.position.x, "z": tram.position.z}, 30.0)
			sets.boom(rq.x, RY + 1.5, rq.z, 6.0, 0.0, {"harmless": true})
			fx.shake = 2.0
			audio.play_at("boomBig", Vector3(rq.x, RY, rq.z))
			Game.hud.toast("RAMMED", 1.4)
		# the jump: a big jolt on take-off and landing
		if s > S_GAP0 - 2.0 and not took:
			took = true
			audio.play_at("groan", tram.position)
			for k in 2:
				fx.explosion(path.at(S_GAP0 + k * 11.0) + Vector3(0, -1.7, 0), 2.5)
		if s > S_GAP1 + 2.0 and not landed:
			landed = true
			fx.shake = 1.8
			audio.play_at("boom", tram.position)
			fx.sparks(tram.position, 40, 8.0, null, 0xffc060)
		# onto Gamma: it smashes the railing, derails and skids into the cable-wheel frame
		if s > S_DECK and not on_deck:
			on_deck = true
			var dk := path.at(S_DECK)
			sets.boom(dk.x, 19.0, dk.z, 4.0, 0.0, {"harmless": true})
			Game.hud.toast("GET OFF IT!", 1.6)
			brk_v = Vector3((randf() - .5) * 4.0, 7.0, 9.0)
			brk_fly = true
			fx.sparks(brk_home + Vector3(0, .6, 0), 40, 9.0, null, 0xffc060)
			audio.play_at("groan", brk_home)
		if brk_fly:      # lands flat on the deck in front of it
			brk_v.y -= 18.0 * dt
			brk.position += brk_v * dt
			brk.rotation.x += dt * 5.0
			brk.rotation.z += dt * 2.5
			if brk.position.y < 17.4 and brk_v.y < 0.0:
				brk_fly = false
				brk.position.y = 17.4
				brk.rotation = Vector3(PI / 2.0 - .2, 0.0, .3)
		if s > S_DECK:
			derail = minf(1.0, derail + dt * .8)
			if randf() < .7:
				fx.sparks(tram.position + Vector3(0, -.5, 0), 8, 7.0, null, 0xffc060)
		if s >= S_END:
			s = S_END
			v = 0.0
			ph = "crashed"
			sets.boom(tram.position.x, 20.0, tram.position.z, 8.0, 45.0)
			fx.shake = 2.6
			audio.play_at("boomBig", tram.position)
			beacon.visible = false
	if ph == "crashed" and randf() < dt * 6.0:
		fx.explosion(tram.position + Vector3((randf() - .5) * 4.0, 1.0 + randf() * 2.0, (randf() - .5) * 6.0), 1.4)
	_pose()
	MsKit.opa(beacon, (1.0 if sin(t * 12.0) > 0.0 else .2) if ph == "run" else .9)


## PROG is aboard (the board objective)
func riding(P: Player) -> bool:
	return ph != "parked" and _on_bed(P)


func past_jump() -> bool:
	return s > S_GAP1 + 4.0


## the stage is live, for its spawns (the gantry goons, the heavy)
func arm() -> void:
	armed = true


## put the tram back for a stage / checkpoint: parked at the siding, or running from the jump (with PROG on it)
func reset(stage: String, obj: int) -> void:
	s = 0.0
	v = 0.0
	ph = "parked"
	t = 0.0
	gantry_done = false
	ram_done = false
	heavy = null
	derail = 0.0
	took = false
	landed = false
	on_deck = false
	warned = false
	beacon.visible = true
	brk_fly = false
	brk.position = brk_home
	brk.rotation = Vector3.ZERO
	for b: Dictionary in bays:
		b.used = false
	var vis := stage == "cableway"
	tram.visible = vis
	for q: World.Solid in [bed, crate_s[0], crate_s[1], cab_s]:
		q.set_off(not vis)
	if stage == "cableway" and obj >= 5:
		s = S_GAP1 + 6.0
		v = 9.0
		ph = "run"
		gantry_done = true
		ram_done = true
		took = true
		landed = true
	if stage == "gamma":
		tram.visible = true
		for q: World.Solid in [bed, crate_s[0], crate_s[1], cab_s]:
			q.set_off(false)
		s = S_END
		ph = "crashed"
		derail = 1.0
		beacon.visible = false
		brk.position = Vector3(brk_home.x, 17.4, brk_home.z + 10.0)
		brk.rotation = Vector3(PI / 2.0 - .2, 0.0, .3)
	_pose()
