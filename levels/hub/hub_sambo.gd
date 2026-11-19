class_name HubSambo
extends Node3D
## SAMBO FENRIR in FOINT CITY (user, 2026-11-19): the street's half of his mission. He paces the east quay's promenade at the end of Harbor St, the stick up, filming himself and roasting
## whoever walks past (his recorded lines: npcs/sambo/sambo_lines.gd; the species he has a line for get their own). Run into him, or talk to him, and he pitches the stream: he wants Prog as his
## camera guy for a day, reads the sponsor in his fake accent, and wants in to the FOINT Pervert Palace site; he hands over the stream camera (npcs/sambo/stream_cam.gd) and goes to wait at the
## site's gate. There X ("GO IN WITH SAMBO") plays the walk in (WalkIn: the gate swings open, the camera tilts up the tower, black) and the Pervert Palace level loads with no loading card; its own
## arrival shot (levels/palace/palace_cines.gd) takes it from there. After the mission (samboDone) he is back on the quay, streaming as ever.
## Also here: the site itself as the city sees it (levels/palace/palace_site.gd built without its insides: no lights of its own, the hoarding and the shut gate solid), and the quay opened to it:
## the railing along the lot taken out of the district's merged meshes and colliders, as the Pervert Palace level's own quay has it.

const GY := -10.0
const MET := "samboMet"           # (the same flags as levels/palace/palace_level.gd)
const DONE := "samboDone"
const TID := 887001               # his combat target (the crowd's are 880000+, 881000+, 889000+)
const LANE_X := 128.25            # the promenade's middle (the crowd's loop along the quay)
const KEEP := 0.35                # he keeps right of it
const Z_LO := 182.0               # the stretch he paces, round the site's gate
const Z_HI := 246.0
const WALK := 1.05
const HURRY := 1.45
const WAIT := Vector3(129.05, GY, 198.4)      # by the gate, waiting for his camera guy
const GATE_AT := Vector2(130.6, 201.0)        # where X takes you in with him
const CUT := [129.45, 129.95, 176.3, 222.7]   # x0, x1, z0, z1: the railing taken out where the lot meets the quay (its merged pieces run 170.0-222.7)
const ROAM: Array[String] = ["s_roam_01", "s_roam_02", "s_roam_03", "s_roam_04", "s_roam_05", "s_roam_06"]
const INSULTS: Array[String] = ["s_ins_01", "s_ins_02", "s_ins_03", "s_ins_04", "s_ins_05", "s_ins_06", "s_ins_07"]
const SPECIES := {"hotdog": "s_sp_hotdog", "twohead": "s_sp_twohead", "tvbot": "s_sp_tvbot", "fishbowl": "s_sp_fishbowl", "cone": "s_sp_cone", "slime": "s_sp_slime",
	"brainjar": "s_sp_brainjar", "ufo": "s_sp_ufo"}
const DETAIL_RANGE := {"Cables": 110.0, "Rebar": 110.0, "Rigging": 110.0, "Pendants": 110.0, "BasketCable": 110.0, "PalletCable": 110.0, "Cage": 150.0, "Tubes": 170.0,
	"Boards": 170.0, "Blocks": 150.0}
const PITCH: Array[String] = ["s_pitch_01", "p_pitch_01", "s_pitch_02", "p_pitch_02", "s_pitch_03", "p_pitch_03", "s_ad_01", "s_ad_02", "s_pitch_04", "s_pitch_05", "p_pitch_04",
	"s_pitch_06", "s_pitch_07"]

var lv: HubLevel
var site: PalaceSite
var body: SamboBody
var talker: Dictionary = {}
var target: Target
var walk: WalkIn
var cam: StreamCam = null
var pos := Vector3.ZERO
var yaw := 0.0
var state := &"roam"              # roam: pacing the quay; to_gate: off to the gate after the pitch; gate: waiting there; in: the walk in
var _dir := 1.0                   # which way along the quay
var _pause := 0.0                 # standing still this long (the end of his stretch, a roast)
var _line_t := 5.0
var _voice: Sfx.SpatialVoice = null
var _said := {}
var _bump_t := 0.0
var _hit_t := 0.0
var _fit_t := 0.0
var _gest_t := 0.0
var _bumped := false              # the talk opens on his "watch it, grandpa"
var _run := 0.0                   # Prog's recent top speed
var _near := false                # Prog close enough that he stops and faces him
var _rng := RandomNumberGenerator.new()


static func build_for(level: HubLevel) -> HubSambo:
	var s := HubSambo.new()
	s.name = "SamboFenrir"
	level.add_child(s)
	s._build(level)
	return s


func _build(level: HubLevel) -> void:
	lv = level
	_rng.seed = 4242
	site = PalaceSite.new()
	site.build(level, level.world, false)
	site.set_gate(0.0)
	_trim_site()
	_open_quay()
	body = SamboBody.new()
	add_child(body)
	body.selfie = 1.0
	if Game.story_get(MET) and not Game.story_get(DONE):
		state = &"gate"
		pos = WAIT
		yaw = -PI / 2.0
	else:
		pos = Vector3(LANE_X - KEEP, GY, 208.0)
		yaw = 0.0
	_place()
	target = Target.new(TID, pos.x, pos.z, GY, {"r": 0.4, "h": 1.9, "max": 400.0, "hp": 400.0, "npc": true, "w": 0.0})
	talker = Game.dialogue.add_talker({"id": "sambo_fenrir", "name": "SAMBO FENRIR", "x": pos.x, "y": GY, "z": pos.z, "yaw": yaw, "radius": 2.4, "color": "#ff7bd5",
		"lines": _talk_lines, "actor": self, "active": func() -> bool: return state == &"roam" and not Game.story_get(MET) and not Game.story_get(DONE),
		"shot": {"cam_dist": 3.4, "cam_y": 1.3, "look_y": 1.0, "look_side": 0.5, "spot_fwd": 1.5, "spot_side": 0.8},
		"on_end": func(_d: Dictionary) -> void: _met()})
	level.actions.append({"x": GATE_AT.x, "z": GATE_AT.y, "label": "GO IN WITH SAMBO",
		"active": func(p: Player) -> bool: return state == &"gate" and absf(p.y - GY) < 1.5 and U.hyp(p.x - GATE_AT.x, p.z - GATE_AT.y) < 2.4,
		"run": func() -> void: _walk_in()})
	walk = WalkIn.new()
	walk.s = self
	add_child(walk)


## The site as the city sees it costs what it shows: its fine stuff (cables, rebar, scaffold tubes and boards, the signs' lettering) goes past a range, and its small loose
## pieces (the gate's leaves, the flood heads, the beacons) stay out of the shadow maps. The frame, the cranes and the festoons carry it from across the city.
func _trim_site() -> void:
	for n: Node in site.root.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		var nm := String(g.name).rstrip("0123456789")
		var far := float(DETAIL_RANGE.get(nm, 0.0))
		if g is Label3D:
			far = 150.0
		if far > 0.0:
			g.visibility_range_end = far
			g.visibility_range_end_margin = 10.0
		if nm == "@MeshInstance3D@":
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The quay where the lot meets it, as the Pervert Palace level's own (levels/palace/palace_city.gd): no railing along the lot. The railing is merged into the district's cell meshes, so its
## triangles are taken out of a copy of each (the cached scene keeps its own), its collider is cut back to either side, the 6 m of rail south of the lot that went with the merged piece is put
## back, and the deck's lip outside the hoarding's corners is closed off.
func _open_quay() -> void:
	var box := AABB(Vector3(CUT[0], GY + 0.01, CUT[2]), Vector3(CUT[1] - CUT[0], 1.49, CUT[3] - CUT[2]))
	var dist: Array = lv.node_named("FointDistrict")
	if not dist.is_empty():
		for n: Node in (dist[0] as Node).find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi.mesh is ArrayMesh and (mi.global_transform * mi.get_aabb()).intersects(box):
				_cut_tris(mi, box)
	var w := lv.world
	for s: World.Solid in w.solids.duplicate():
		if s.kind != "box" or s.yaw != 0.0 or s.hx > 0.6 or s.cx < CUT[0] - 0.15 or s.cx > CUT[1] + 0.15 or s.top < GY + 0.3 or s.bottom > GY + 0.5:
			continue
		var z0 := s.cz - s.hz
		var z1 := s.cz + s.hz
		if z1 <= CUT[2] or z0 >= CUT[3]:
			continue
		for seg: Vector2 in [Vector2(z0, minf(z1, CUT[2])), Vector2(maxf(z0, CUT[3]), z1)]:
			if seg.y - seg.x > 0.05:
				w.add({"kind": "box", "cx": s.cx, "cz": (seg.x + seg.y) * 0.5, "hx": s.hx, "hz": (seg.y - seg.x) * 0.5, "bottom": s.bottom, "top": s.top, "tag": s.tag, "no_cam": s.no_cam})
		w.remove(s)
	var b := UfBuild.new(w)
	b.base_y = GY
	b.mat("quay_rail", Color(0.16, 0.16, 0.19), {"rough": 0.4, "metal": 0.7})
	b.box("quay_rail", 129.66, 129.74, GY + 1.03, GY + 1.1, 170.0, CUT[2], false)      # the top rail put back south of the lot
	b.commit(self, "_quay_rail")
	for z: float in [CUT[2] - 0.12, CUT[3] + 0.12]:      # where the railing stops: the quay's edge outside it and the deck's lip round the hoarding are not a path
		w.add({"kind": "box", "cx": 130.9, "cz": z, "hx": 1.5, "hz": 0.13, "bottom": GY - 0.2, "top": GY + 3.0, "tag": "invisible", "no_cam": true})


## A copy of the mesh without the triangles whose middle lies in the box (local space: the district's cells are not rotated or scaled)
static func _cut_tris(mi: MeshInstance3D, box: AABB) -> int:
	var src := mi.mesh as ArrayMesh
	var lb := mi.global_transform.affine_inverse() * box
	var out := ArrayMesh.new()
	var cut := 0
	var custom := 0
	for i in 4:
		custom |= Mesh.ARRAY_FORMAT_CUSTOM_MASK << (Mesh.ARRAY_FORMAT_CUSTOM_BASE + i * Mesh.ARRAY_FORMAT_CUSTOM_BITS)
	for si in src.get_surface_count():
		var arr := src.surface_get_arrays(si)
		if arr[Mesh.ARRAY_INDEX] != null and src.surface_get_primitive_type(si) == Mesh.PRIMITIVE_TRIANGLES:
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var keep := PackedInt32Array()
			keep.resize(idx.size())
			var k := 0
			for t in range(0, idx.size(), 3):
				if lb.has_point((v[idx[t]] + v[idx[t + 1]] + v[idx[t + 2]]) / 3.0):
					cut += 1
					continue
				keep[k] = idx[t]
				keep[k + 1] = idx[t + 1]
				keep[k + 2] = idx[t + 2]
				k += 3
			keep.resize(k)
			arr[Mesh.ARRAY_INDEX] = keep
		out.add_surface_from_arrays(src.surface_get_primitive_type(si), arr, [], {}, src.surface_get_format(si) & custom)
		out.surface_set_material(si, src.surface_get_material(si))
		out.surface_set_name(si, src.surface_get_name(si))
	if cut > 0:
		mi.mesh = out
	return cut


## The hub's cutscene getter, its combat targets, its exit
func targets_in() -> void:
	target.hp = target.max
	target.dead = false
	Game.combat.targets.append(target)


func on_exit() -> void:
	if cam != null and is_instance_valid(cam):
		cam.remove()
	cam = null


# ---------------------------------------------------------------------------------------------- the frame

func update(dt: float) -> void:
	if walk.on:
		walk.update(dt)
		if lv.life != null:      # (the crowd keeps out of the shot: a patch of the promenade they step round, or wait at)
			lv.life.crowd.movers = PackedFloat32Array([pos.x, pos.z, 0.45, 127.4, 201.6, 3.0])
		return
	var P := Game.player
	if P == null:
		return
	var talking: bool = Game.dialogue.on and is_same(Game.dialogue.npc, talker)
	var adt := 0.0 if Game.paused else Game.frame_real_dt      # (the talk holds the world still; his lid still flaps)
	_bump_t -= dt
	_hit_t -= dt
	_line_t -= dt
	if _fit_t > 0.0:
		_fit_t -= adt
		if _fit_t <= 0.0 and body.gesture == &"fists":
			body.gesture = &""
	if _gest_t > 0.0:
		_gest_t -= dt
		if _gest_t <= 0.0:
			if body.gesture == &"point":
				body.gesture = &""
			body.look_away()
	if Game.story_get(MET) and not Game.story_get(DONE) and cam == null and Game.animator != null:
		cam = StreamCam.wear(Game.animator)      # (back on the street mid-stream: still wearing it)
	var d := U.hyp(P.x - pos.x, P.z - pos.z)
	if not talking:
		_near = d < (3.2 if _near else 2.6) and absf(P.y - GY) < 1.5 and not Game.vehicles.driving
		_bump(P, d)
		match state:
			&"roam":
				_roam(dt, P)
			&"to_gate":
				_to_gate(dt)
			&"gate":
				_at_gate(dt, P)
	else:
		body.speed = 0.0
	_place()
	talker["x"] = pos.x
	talker["z"] = pos.z
	talker["yaw"] = yaw
	target.bx = pos.x
	target.bz = pos.z
	target.y = pos.y
	if target.dead or target.hp < target.max * 0.5:      # (he can be hit; he cannot be killed)
		target.dead = false
		target.hp = target.max
	if lv.life != null:
		lv.life.crowd.movers = PackedFloat32Array([pos.x, pos.z, 0.45])      # the crowd steps round him
	var c: Vector3 = Game.camera.global_position if Game.camera != null else pos
	body.visible = U.hyp(c.x - pos.x, c.z - pos.z) < 150.0
	if body.visible:
		body.update(adt if talking else dt)


func _place() -> void:
	body.global_position = pos
	body.rotation.y = yaw


func _turn_to(a: float, dt: float, rate: float = 7.0) -> void:
	yaw = lerp_angle(yaw, a, 1.0 - exp(-dt * rate))


## Pacing the quay, the stick up; he stops for Prog and for a roast
func _roam(dt: float, P: Player) -> void:
	if _near:
		body.speed = 0.0
		_turn_to(atan2(P.x - pos.x, P.z - pos.z), dt)
		return
	if _pause > 0.0:
		_pause -= dt
		body.speed = 0.0
	else:
		var lane := LANE_X - KEEP * _dir                     # his right: -x going +z
		pos.x = move_toward(pos.x, lane, dt * 0.8)
		pos.z += _dir * WALK * dt
		body.speed = WALK
		_turn_to(atan2(lane - pos.x, _dir * 1.0), dt, 5.0)
		if (_dir > 0.0 and pos.z >= Z_HI) or (_dir < 0.0 and pos.z <= Z_LO):
			_dir = -_dir
			_pause = _rng.randf_range(1.5, 3.0)
	_lines(P)


## After the pitch: up the promenade to the gate, keeping off the benches by the railing
func _to_gate(dt: float) -> void:
	var lane := Vector3(LANE_X + 0.05, GY, WAIT.z + (1.0 if pos.z > WAIT.z else -1.0))
	var goal := WAIT if (absf(pos.z - WAIT.z) < 1.2 or absf(pos.x - lane.x) < 0.05 and absf(pos.z - lane.z) < 0.1) else lane
	var to := goal - pos
	to.y = 0.0
	var L := to.length()
	if L < 0.06 and goal == WAIT:
		state = &"gate"
		body.speed = 0.0
		return
	var step := minf(L, HURRY * dt)
	pos += to / maxf(L, 1e-4) * step
	body.speed = HURRY
	_turn_to(atan2(to.x, to.z), dt, 8.0)


## At the gate, facing the street and filming himself; now and then he hurries his camera guy
func _at_gate(dt: float, P: Player) -> void:
	body.speed = 0.0
	if _near:
		_turn_to(atan2(P.x - pos.x, P.z - pos.z), dt)
	else:
		_turn_to(-PI / 2.0, dt, 3.0)
	if _line_t <= 0.0 and _can_talk(P, 26.0):
		var id := "s_climb_12" if int(_said.get("s_climb_12", 0)) <= int(_said.get("s_pitch_07", 0)) else "s_pitch_07"
		_line_t = say(id) + _rng.randf_range(10.0, 15.0)


func _can_talk(P: Player, reach: float) -> bool:
	if Game.dialogue.on or Game.menu_open() or (lv.cine != null and lv.cine.on):
		return false
	if _voice != null and _voice.player != null and _voice.player.playing:
		return false
	return U.hyp(P.x - pos.x, P.z - pos.z) < reach and absf(P.y - GY) < 6.0


## What he says to the stream as he goes: a roast of whoever is in front of him, or more of his nonsense
func _lines(P: Player) -> void:
	if _line_t > 0.0 or not _can_talk(P, 24.0):
		return
	var who: CityCrowd.Person = _victim() if _rng.randf() < 0.6 else null
	if who != null:
		var id := String(SPECIES.get(who.skin_id, ""))
		if id == "" or int(_said.get(id, 0)) > 0 and _rng.randf() < 0.6:
			id = _least(INSULTS)
		var dur := say(id)
		body.look_at_point(who.x, who.z)
		body.gesture = &"point"
		body.point_at = Vector3(who.x, GY + 1.2, who.z)
		_gest_t = dur
		_pause = maxf(_pause, dur * 0.7)      # he stops to roast them
		_line_t = dur + _rng.randf_range(6.0, 10.0)
	else:
		_line_t = say(_least(ROAM)) + _rng.randf_range(7.0, 12.0)


## the nearest townsperson up and about within a few metres in front of him
func _victim() -> CityCrowd.Person:
	if lv.life == null:
		return null
	var fx := sin(yaw)
	var fz := cos(yaw)
	var best: CityCrowd.Person = null
	var bd := 6.0
	for f: CityCrowd.Person in lv.life.crowd.folk:
		if f.down >= 0.0 or f.flee > 0.0:
			continue
		var dx := f.x - pos.x
		var dz := f.z - pos.z
		var dd := sqrt(dx * dx + dz * dz)
		if dd < bd and dd > 0.6 and (dx * fx + dz * fz) > 0.25 * dd:
			bd = dd
			best = f
	return best


func _least(ids: Array[String]) -> String:
	var best := ids[0]
	var n := 1 << 20
	for id: String in ids:
		var k := int(_said.get(id, 0)) * 10 + _rng.randi() % 3
		if k < n:
			n = k
			best = id
	return best


## Prog runs into him: before the pitch it opens the talk (user: "run into him -> talk")
func _bump(P: Player, d: float) -> void:
	_run = maxf(_run * exp(-Game.frame_real_dt * 5.0), Vector2(P.vx, P.vz).length())      # (how fast he came on: the contact itself stops him)
	if _bump_t > 0.0 or d > 1.35 or absf(P.y - GY) > 1.2 or Game.dialogue.on or (lv.cine != null and lv.cine.on):
		return
	if _run < 2.4:
		return
	_bump_t = 5.0
	if state == &"roam" and not Game.story_get(MET) and not Game.story_get(DONE):
		yaw = atan2(P.x - pos.x, P.z - pos.z)
		talker["yaw"] = yaw
		_bumped = true
		Game.dialogue.start(talker)
	else:
		say("s_bump2" if int(_said.get("s_bump", 0)) > 0 else "s_bump")


## This frame's combat events (HubLevel.combat_events): a hit is assault, on stream
func combat_event(e: Dictionary) -> void:
	if int(e.get("tid", -1)) != TID or String(e.get("t", "")) != "hit":
		return
	body.gesture = &"fists"
	_fit_t = 1.4
	if _hit_t <= 0.0:
		_hit_t = 4.0
		say("s_hit")


# ---------------------------------------------------------------------------------------------- the talk

func _talk_lines() -> Array:
	var out: Array = []
	if _bumped:
		out.append(_line("s_bump"))
		_bumped = false
	for id: String in PITCH:
		out.append(_line(id))
	return out


func _line(id: String) -> Dictionary:
	var L := {"text": SamboLines.text(id), "clip": SamboLines.DIR + id + ".wav", "id": id}
	if SamboLines.who(id) == "PROG":
		L["who"] = Dialogue.player_name()
	if id.begins_with("s_ad_"):
		L["wave"] = true      # the sponsor read: the stick swung about
	if id == "s_pitch_01":
		L["point"] = true     # "look at this guy"
	if id == "s_pitch_06":
		L["camera"] = true    # "here, take the camera"
	return L


## Dialogue actor
func look_at_point(x: float, z: float) -> void:
	body.look_at_point(x, z)


func look_away() -> void:
	body.look_away()


func set_talk(v: bool) -> void:
	body.set_talk(v)


func mouth_world() -> Vector3:
	return body.mouth_world()


func on_line(L: Dictionary) -> void:
	if _voice != null and _voice.player != null and _voice.player.playing:      # (the talk's recordings take over from whatever he was saying to the stream)
		_voice.player.stop()
	_said[String(L.get("id", ""))] = int(_said.get(String(L.get("id", "")), 0)) + 1
	body.wave = 1.0 if L.get("wave", false) else 0.0
	if L.get("point", false):
		var P := Game.player
		body.gesture = &"point"
		body.point_at = Vector3(P.x, P.y + 1.3, P.z)
	elif body.gesture == &"point":
		body.gesture = &""
	if L.get("camera", false) and cam == null and Game.animator != null:
		cam = StreamCam.wear(Game.animator)


func _met() -> void:
	Game.story_set(MET)
	body.wave = 0.0
	body.gesture = &""
	body.look_away()
	state = &"to_gate"
	_line_t = 12.0


## Say a line (assets/sfx/sambo/<id>.wav) from his mouth, with its subtitle when Prog can hear it
func say(id: String, gain: float = 1.3) -> float:
	var st := SamboLines.clip(id)
	if st == null:
		return 0.0
	if _voice != null and _voice.player != null and _voice.player.playing:
		_voice.player.stop()
	var m := body.mouth_world()
	_voice = Game.sfx.clip_at(st, m.x, m.y, m.z, {"range": 40.0, "ref": 5.0, "gain": gain, "voice": true})
	var dur := st.get_length()
	var P := Game.player
	if Game.hud != null and P != null and m.distance_to(Vector3(P.x, P.y, P.z)) < 30.0:
		Game.hud.subtitle({"name": "SAMBO", "text": SamboLines.text(id), "dur": dur})
	_said[id] = int(_said.get(id, 0)) + 1
	body.talking = true
	get_tree().create_timer(dur, false).timeout.connect(func() -> void:
		if is_instance_valid(body):
			body.talking = false)
	return dur


# ---------------------------------------------------------------------------------------------- in through the gate

func _walk_in() -> void:
	if walk.on or Game.doors.travelling:
		return
	state = &"in"
	walk.begin()


## The street's half of the arrival (levels/palace/palace_cines.gd is the site's): Sambo turns from his phone to the gate and leads Prog in as it swings open; the camera, low on the
## promenade, tilts up the lit floors toward the cranes; black; the Pervert Palace loads with no card. X skips to the black.
class WalkIn:
	extends Cutscene
	const DUR := 6.2
	const BLACK := 5.0

	var s: HubSambo
	var play := false      # (core/view.gd: not a playable cutscene)
	var t := 0.0
	var _black := false
	var _gone := false
	var _from := Vector3.ZERO

	func begin() -> void:
		on = true
		t = 0.0
		_black = false
		_gone = false
		_from = s.pos
		var P := Game.player
		P.vx = 0.0
		P.vz = 0.0
		enter_cine(true)
		s.body.look_away()
		s.body.gesture = &""
		s.say("s_gate_01")
		update(0.0)

	func skip() -> void:
		if on and t < BLACK - 0.4:
			t = BLACK - 0.4

	func update(dt: float) -> void:
		if not on:
			return
		t += dt
		var P := Game.player
		# Prog walks to the gate and through it behind him
		if t > 1.1 and t < BLACK + 0.4:
			var aim := Vector2(133.2, 201.6)
			if U.hyp(aim.x - P.x, aim.y - P.z) > 0.4:
				player_step(dt, 0.55, atan2(aim.x - P.x, aim.y - P.z))
		# Sambo: a beat to the stream, then in at the gate ahead of him
		var a := s.pos
		var u := ease_(seg(t, 1.0, 5.4))
		var path: Vector3 = _from.lerp(Vector3(130.9, HubSambo.GY, 200.2), ease_(seg(t, 1.0, 2.8))).lerp(Vector3(135.4, HubSambo.GY, 200.4), ease_in(seg(t, 2.6, 5.4)))
		s.pos = path
		var mv := s.pos - a
		mv.y = 0.0
		s.body.speed = mv.length() / maxf(dt, 1e-4) if dt > 0.0 else 0.0
		if mv.length() > 1e-4:
			s.yaw = lerp_angle(s.yaw, atan2(mv.x, mv.z), 1.0 - exp(-dt * 8.0))
		s._place()
		s.body.update(dt)
		s.site.set_gate(ease_(seg(t, 1.4, 2.8)))
		# the camera: on the promenade behind the two of them, then up through the open gate, up the lit floors toward the cranes (this close the frame hides crane A's
		# mast: the site's half opens on it, coming down out of the dark)
		var tilt := ease_(seg(t, 2.0, BLACK + 0.6))
		var pos := Vector3(125.4, HubSambo.GY + 1.0, 197.2).lerp(Vector3(125.0, HubSambo.GY + 0.75, 196.8), u)      # (south of the gate: the bench and whoever waits on it stay behind them)
		var look := Vector3(131.4, HubSambo.GY + 1.5, 200.6).lerp(Vector3(158.0, 20.0, 201.0), tilt)
		shot(pos, look, lerpf(50.0, 44.0, u))
		if t >= BLACK and not _black:
			_black = true
			Game.ui.set_fade(true)
		if t >= DUR and not _gone:
			_gone = true
			Game.doors.travel({"id": "palace_in", "label": "", "to": "palace", "card": false, "before": func() -> void: pass})

	## (Prog walks; the rig stays where the shot leaves it)
	func pose_player(_an: Animator) -> void:
		pass
