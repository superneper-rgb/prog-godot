class_name WarehouseLevel
extends ExportedLevel
## WAREHOUSE ROBBERY (JS levels/warehouse/level.js): the world is exported; this runs the heist on it: ten rooms, waves through the shutters, the machinery that carries you, the Compactor and the Foreman. The moving parts and their looks are in wh_views.gd. Lighting is a plain carry-over on the shared lights on purpose (the user will rework this level).

const INTERIOR_SKY := Color8(0x10, 0x1e, 0x2a)
const NIGHT_SKY := Color8(0x08, 0x0e, 0x18)
const INTERIOR_FOG := Color8(0x18, 0x2a, 0x35)
const NIGHT_FOG := Color8(0x14, 0x20, 0x2f)
const NIGHT_AMBIENT := Color8(0x78, 0x94, 0xbc)
const NIGHT_GROUND := Color8(0x18, 0x20, 0x2d)
const NIGHT_MOON := Color8(0x72, 0x94, 0xc9)
const ALARM_FOG := Color8(0x6a, 0x1c, 0x10)
const ALARM_SKY := Color8(0x3a, 0x14, 0x10)

var K: Dictionary = WhData.TUNING
var director: WhDirector
var setpieces: WhSetPieces
var boss: WhForeman
var nav: WhNav
var views: WhViews
var comms: WhComms
var music: MusicTrack
var _music_build := 0.0
var movers: Array[Dictionary] = []
var lift: World.Solid
var gate: World.Solid
var dock_bridge: World.Solid
var foreman_cam: World.Solid
var slag_cam: World.Solid
var hud_state: Dictionary = {}
var now_ := 0.0
var elapsed := 0.0
var last_clock := 0
var was_dead := false
var rating_shown := false
var transfer_pads: Array[Dictionary] = []
var _look_key := ""
var loadout: Array = ["pistol", "legacy_smg"]      # JS levelKit: WH
var equip := "pistol"


## world.solids[i] is layout.solids[i]: the layout's solids are added first, in order
func solid(i: int) -> World.Solid:
	return world.solids[i] if i >= 0 and i < world.solids.size() else null


func build() -> void:
	super.build()
	for s: World.Solid in world.solids:      # (the exporter keeps a solid's JS id under extra)
		var ex: Variant = s.data.get("extra")
		if ex is Dictionary and (ex as Dictionary).has("id"):
			s.data["id"] = ex["id"]
	lift = solid(WhData.LIFT)
	gate = solid(WhData.GATE)
	dock_bridge = solid(WhData.DOCK_BRIDGE)
	for m: Dictionary in WhData.MOVERS:
		var c := m.duplicate()
		c.s = solid(int(m.solid))
		movers.append(c)
	for p: Dictionary in WhData.TRANSFER_PADS:
		var s := solid(int(p.solid))
		transfer_pads.append({"x": s.cx, "y": s.top, "z": s.cz, "hx": s.hx, "hz": s.hz, "checkpoint": p.get("checkpoint", false), "name": p.name})
	world.fall_reset_y = -40.0
	nav = WhNav.new(world)
	var crates: Array[World.Solid] = []
	for i: int in WhData.BOSS_CRATES:
		crates.append(solid(i))
	boss = WhForeman.new(world, crates, solid(WhData.BOSS_ARM), func(m: String) -> void: dir_message(m.get_slice(" / ", 0)), func(cue: String) -> void: _boss_cue(cue))
	setpieces = WhSetPieces.new(self)
	comms = WhComms.new()
	add_child(comms)
	# Alarm theme: silent on the roof, starts when the alarm trips, swells slowly stage by stage and holds at its peak before the Freight pit, at a low ceiling so weapons, drives and the Foreman always sit above it.
	var theme: AudioStreamMP3 = load("res://assets/sfx/warehouse-alarm-theme.mp3")
	if theme != null:
		theme.loop = true
		music = MusicTrack.new(theme, 0.0)
		add_child(music)
	# The Foreman and the Slag Compactor have no body collider, so the camera boom would swing straight into them. Camera-only blockers follow both; switched off whenever the player is inside the footprint (a boom starting inside a blocker collapses onto the head). Shoulders and missile pods span about +-6.3 m, eye bezel to exhaust about +-4.4 m; tall, so the boom shortens in front of it instead of lifting over its shoulders.
	foreman_cam = world.add_camera_blocker({"cx": 0.0, "cz": 0.0, "hx": 6.3, "hz": 4.4, "bottom": 0.0, "top": 40.0, "off": true})
	slag_cam = world.add_camera_blocker({"cx": 0.0, "cz": 0.0, "hx": 1.0, "hz": 1.0, "bottom": 0.0, "top": 1.0, "off": true})
	var controls: Array = info.get("data", {}).get("director", {}).get("controls", WhData.CONTROLS)      # (the exported ones: the cabinets have moved them to in front of their faces)
	director = WhDirector.new(self, controls)
	views = WhViews.new(self)
	views.roof_door = MinigameDoor.new(self, world, WhData.TUNING.roofDoor)
	add_child(views)
	last_clock = Time.get_ticks_msec()


func on_enter() -> void:
	Game.music = music
	var E := Game.combat.enemies
	E.slot_free_hook = _slot_free
	E.fire_hook = _fire


func on_exit() -> void:
	var E := Game.combat.enemies
	E.slot_free_hook = Callable()
	E.fire_hook = Callable()
	Game.rig.pull_t = 0.0
	if Game.music == music:
		Game.music = null
	if music != null:
		music.stop()
	views.leave()


# ---- the shared enemies' rules while the warehouse runs ----
func _slot_free(kind: StringName, who: Robot) -> Variant:
	if who != null and who.get(&"warehouse") == true and kind == &"shot":
		var n := 0
		for r: Robot in Game.combat.enemies.robots:
			if not r.dead and r != who and r.slot == &"shot":
				n += 1
		return n < int(K.combat.shotSlots.get(director.stage, 4))
	return null


func _fire(r: Robot, x: float, y: float, z: float, dx: float, dy: float, dz: float, o: Dictionary) -> bool:
	if r.get(&"warehouse") != true or r.drone or not o.is_empty():
		return false
	var fan: Variant = K.combat.fans.get(r.get(&"warehouse_kind"))
	if fan == null:
		return false
	var rays := int(fan.rays)
	for i in rays:
		var a := (i - (rays - 1) / 2.0) * float(fan.spread)
		var c := cos(a)
		var s := sin(a)
		Game.combat.enemies.fire(r, x, y, z, dx * c + dz * s, dy, dz * c - dx * s, {"speed": fan.speed, "dmg": fan.dmg, "r": 0.16})
	return true


func _boss_cue(cue: String) -> void:
	var B: Dictionary = boss.B
	if Game.sfx != null and Game.sfx.enemy_audio != null and Game.sfx.enemy_audio.has_method(&"boss_cue"):
		Game.sfx.enemy_audio.boss_cue(cue, B)


# ---- the director's api ----
## Respawns and checkpoint loads face the next step of the route (a few metres along the walking path, or straight at a cargo jump), not a fixed authored yaw that can leave the camera staring into a wall.
func _route_yaw(p: Dictionary) -> float:
	var o := director.objective()
	var t: Variant = o.target
	if t == null:
		return float(p.get("yaw", 0.0))
	var aim := Vector2(float(t.x), float(t.z))
	if o.kind != "jump":
		var travelled := 0.0
		var lx := float(p.x)
		var lz := float(p.z)
		for q: Vector3 in nav.route(p.x, p.y, p.z, t.x, t.y, t.z):
			travelled += U.hyp(q.x - lx, q.z - lz)
			lx = q.x
			lz = q.z
			if travelled >= 4.0:
				aim = Vector2(q.x, q.z)
				break
	var dx := aim.x - float(p.x)
	var dz := aim.y - float(p.z)
	return atan2(dx, dz) if U.hyp(dx, dz) > 1.0 else float(p.get("yaw", 0.0))


func dir_teleport(p: Dictionary, P: Player) -> void:
	var s: Dictionary = p.duplicate()
	s.yaw = _route_yaw(p)
	world.spawn = s
	P.reset()
	_sync_camera_blockers(P, director.stage, director.flags)
	var rig := Game.rig
	rig.pull_t = 1.0 if director.stage == "finale" and director.flags.get("bossStarted", false) else 0.0
	rig.pull_w = rig.pull_t
	rig.pull_eff = rig.pull_t
	rig.snap_to(P)


func dir_clear_projectiles() -> void:
	var C := Game.combat
	C.enemies.bolts.clear()
	C.projs.clear()
	C.saws.clear()
	C.rocks.clear()
	C.wells.clear()


func dir_remove(r: Robot) -> void:
	Game.despawn_enemy(r)


func dir_boss_reset(phase: int) -> void:
	boss.reset(phase)


func dir_boss_state() -> Dictionary:
	return boss.B


func dir_entry(stage: String, door: int) -> Variant:
	return views.entrance_point(stage, door)


func dir_transfer_pads() -> Array[Dictionary]:
	return transfer_pads


func dir_message(m: String) -> void:
	Game.hud.toast(m)


func dir_level_start() -> void:
	views.mission_card(director.state().plan)
	comms.beat("roof")


func dir_gate_locked() -> bool:
	return views.roof_door_locked()


func dir_gate_target() -> Dictionary:
	return views.roof_door_target()


func dir_stage_entered(stage: String, opts: Dictionary) -> void:
	if not opts.get("retry", false):
		views.mission_card(director.state().plan)
		comms.hush()
		comms.beat(stage)
	if stage == "roof":
		views.roof_door_reset()
	views.reset_for_stage()
	Game.player.factory_interaction = null
	if stage == "racks" and not opts.get("retry", false):
		setpieces.reset_stats()
	setpieces.enter(stage, opts, Game.combat)


func dir_chase_active() -> bool:
	return setpieces.chase.phase == "rise" or setpieces.chase.phase == "run"


func dir_operated(id: String) -> void:
	if id == "foreman":
		comms.beat("foreman")


func dir_beat(nm: String) -> void:
	if nm == "cleared":
		comms.horn()
		Game.hud.toast("CLAMPS CLEAR" if director.stage == "vault" else "WAY OPEN")
	else:
		comms.beat(nm)


func dir_alarm() -> void:
	pass      # (JS ctx.alarm: the armed-alarm sting belongs to the warehouse's music pass)


func dir_checkpoint(p: Dictionary, _P: Player, C: Combat) -> void:
	world.spawn = p.duplicate()
	for i: int in C.owned:
		var w := Weapons.WEAPONS[i]
		C.ammo[i] = w.mag_size
		C.reserve[i] = w.max - w.mag_size
	now_ = 0.0
	_move_machinery(0.0, null, 0.0)


func dir_gate(open: bool) -> void:
	views.gate_request(gate, open)


func dir_dock_bridge(deployed: bool) -> void:
	views.bridge_requested = deployed


func dir_exit_gate(stage: String, open: bool) -> void:
	var g: Variant = WhData.GATES.get(stage)
	if g != null:
		views.gate_request(solid(int(g)), open)


func dir_lift(y: float, x: float = 0.0) -> void:
	lift.set_span(y - 0.6, y)
	lift.place(x, lift.cz)
	views.lift_moved(lift)


func dir_announce(stage: String, i: int) -> void:
	views.announce(stage, i, now_)


func dir_spawn(kind: String, stage: String, door: int, P: Player) -> Robot:
	var passage: Variant = views.request_passage(stage, door, now_, kind, P, Game.combat.enemies.robots)
	if passage == null:
		return null
	var st: Dictionary = passage.start
	var pt := {"x": st.x, "y": float(st.y) + (1.4 if kind == "drone" else 0.0), "z": st.z, "yaw": st.yaw}
	var wk := "wh_drone" if kind == "drone" else ("wh_spider" if kind == "spider" else "wh_robot")
	var r: Variant = Game.spawn_enemy(pt, {"kind": wk, "no_respawn": true})
	r.setup(kind, nav)
	r.mute = true
	r.known = Robot.Known.at(P.x, P.z)
	r.seen_t = 0.0
	r.set_(&"alert")
	if r.drone:
		r.call_cd = 1e9
		r.calls = 999
		if stage == "transfer" or (stage == "freight" and door == 3):
			r.warehouse_hover_floor = float(st.y)
	if kind == "guard" or kind == "mech":
		var bv: Variant = Game.enemy_views.bot_by_id.get(r.id)
		if bv != null and bv.get(&"body_tint") != null:
			bv.body_tint = Color.hex(0xc66f40ff if kind == "mech" else 0xd3b35dff).srgb_to_linear()
	views.dispatch(r, passage)
	return r


func dir_interaction_held() -> bool:
	return Inp.btn(&"b").held


func dir_prepare_interaction(c: Dictionary, P: Player, dt: float) -> bool:
	return views.prepare_control(c, P, dt)


func dir_interaction_label(c: Dictionary) -> String:
	return WhData.CONTROL_NAMES[c.id][1] if WhData.CONTROL_NAMES.has(c.id) else String(c.label)


func dir_hud(s: Dictionary) -> void:
	hud_state = s


## F6 / console: deliberate QA loading; never used for ordinary progression.
func load_checkpoint(which: Variant) -> bool:
	var nm: String = which if which is String else WhDirector.STAGE_ORDER[clampi(int(which), 0, WhDirector.STAGE_ORDER.size() - 1)]
	comms.hush()
	var ok := director.load_checkpoint(nm, Game.player, Game.combat)
	if ok:
		elapsed = 0.0
		last_clock = Time.get_ticks_msec()
		was_dead = false
		rating_shown = false
	return ok


var checkpoints: Array:
	get:
		return WhDirector.STAGE_ORDER


# ---- the machinery ----
## Dwell at both loading stations, then travel smoothly between them.
static func machinery_position(m: Dictionary, time: float) -> float:
	var tt := fposmod(time / float(m.period) + float(m.get("phase", 0.0)), 1.0)
	var dwell := float(m.get("dwell", 0.18))
	var u := 0.0 if tt < dwell else ((tt - dwell) / (0.5 - dwell) if tt < 0.5 else (1.0 if tt < 0.5 + dwell else 1.0 - (tt - 0.5 - dwell) / (0.5 - dwell)))
	u = u * u * (3.0 - 2.0 * u)
	return float(m.from) + (float(m.to) - float(m.from)) * u


## Raise both refuges during the warning and hold them until every wave has passed. The existing mover controller eases the colliders and carries their riders.
func _foreman_deck_height(m: Dictionary, active: bool, time: float) -> float:
	if not active:
		return m.from
	if m.axis != "y":
		return machinery_position(m, time)
	var B: Dictionary = boss.B
	if B.move == "pound" or B.move == "purge" or B.move == "recover":
		return m.to
	if B.move == "drop":
		return m.from
	var q := m.duplicate()
	q.period = 6.0 if int(B.phase) == 3 else 8.0
	return machinery_position(q, time)


func _move_machinery(time: float, P: Variant, dt: float) -> void:
	var fl: Dictionary = director.flags
	var st := director.stage
	var speed := float(K.machinery.controlSpeed)
	for m: Dictionary in movers:
		var s: World.Solid = m.s
		var axis: String = m.axis
		var previous: float = s.top if axis == "y" else (s.cz if axis == "z" else s.cx)
		var riding: bool = not m.get("hazard", false) and P != null and P.grounded and absf(P.y - s.top) < 0.12 and s.top_at(P.x, P.z) != null
		var stage_ok: bool = not m.has("stage") or m.stage == st
		var enabled: bool = not m.has("enabledBy") or fl.get(m.enabledBy, false)
		var not_stopped: bool = not m.has("stoppedBy") or not fl.get(m.stoppedBy, false)
		var boss_ok: bool = not m.has("bossPhase") or (st == "finale" and int(boss.B.phase) >= int(m.bossPhase) and boss.B.mode == "fight")
		var active: bool = stage_ok and enabled and not_stopped and boss_ok
		var next: float
		if m.has("bossPhase"):
			next = _foreman_deck_height(m, active, time)
		else:
			next = machinery_position(m, time) if active else float(m.from)
		# Switching or parking machinery must not teleport a collider through a player. Checkpoint synchronization deliberately uses dt = 0 and no rider.
		if (m.has("enabledBy") or m.has("bossPhase")) and dt > 0.0:
			next = clampf(next, previous - speed * dt, previous + speed * dt)
		var rise: float = (next - previous) * float(m.slope) if m.has("slope") else 0.0
		if axis == "y":
			s.set_span(s.bottom + next - s.top + rise, next + rise)
		else:
			var ncx: float = next if axis == "x" else s.cx
			var ncz: float = next if axis == "z" else s.cz
			if rise != 0.0:
				s.set_span(s.bottom + rise, s.top + rise)
			s.place(ncx, ncz)
		views.solid_moved(s)
		if riding:
			if axis == "y":
				P.y += next - previous
			elif axis == "z":
				P.z += next - previous
			else:
				P.x += next - previous
			P.y += rise
		if m.get("hazard", false) and P != null and not P.dead and st == "transfer" and absf(P.x - s.cx) < s.hx + 0.25 and absf(P.z - s.cz) < s.hz + 0.25 and P.y < s.top and P.y + P.h > s.bottom:
			director.recover_course(P, "PRESS CAUGHT YOU")


func _sync_camera_blockers(P: Variant, stage: String, flags: Dictionary) -> void:
	var B: Dictionary = boss.B
	foreman_cam.place(B.x, B.z, B.yaw)
	var dx: float = P.x - float(B.x) if P != null else 0.0
	var dz: float = P.z - float(B.z) if P != null else 0.0
	var cs := cos(float(B.yaw))
	var sn := sin(float(B.yaw))
	var lx := dx * cs - dz * sn
	var lz := dx * sn + dz * cs
	foreman_cam.set_off(stage != "finale" or B.dead or P == null or (absf(lx) < foreman_cam.hx + 1.0 and absf(lz) < foreman_cam.hz + 1.0))
	var q: Dictionary = views.slag_box
	if q.live:
		slag_cam.place((float(q.x0) + float(q.x1)) / 2.0, q.cz, 0.0, (float(q.x1) - float(q.x0)) / 2.0, q.hz)
		slag_cam.set_span(q.bottom, q.top)
	slag_cam.set_off(not q.live or P == null or P.x < float(q.x1) + 0.6)


func tick(dt: float) -> void:
	var P := Game.player
	var C := Game.combat
	var clock := Time.get_ticks_msec()
	# Wall clock (not the clamped sim dt), but a hidden tab or a hitch is not run time.
	if dt > 0.0 and not director.finished:
		elapsed += minf(0.25, (clock - last_clock) / 1000.0)
	last_clock = clock
	now_ += dt
	if dt > 0.0:
		_move_machinery(now_, P, dt)
	if was_dead and not P.dead:
		director.restore(P, C)
	was_dead = P.dead
	boss.update(dt, P, C)
	director.tick(dt, P, C)
	var state := director.state()
	var flags: Dictionary = state.flags
	var stage: String = state.stage
	if music != null:
		var build: float = {"roof": 0.0, "racks": 0.45}.get(stage, 1.0)
		_music_build = move_toward(_music_build, build, Game.frame_real_dt / (3.0 if stage == "racks" else 4.0))
		music.volume = 0.13 * _music_build
		if _music_build > 0.0 and not music.playing:
			music.play()
	views.lockdown_update(dt, boss.B if stage == "finale" else {"mode": "waiting"}, P)
	setpieces.update(dt, P, C, state.alive, state.lifting)
	if state.finished and not rating_shown:
		rating_shown = true
		var r := setpieces.rating(elapsed)
		comms.beat("finished")
		Game.hud.toast("HEIST RATING %s / %d · %d BLAST KILLS · %d RETRIES" % [r.grade, r.score, r.blast_kills, r.retries], 4.0)
	var rig := Game.rig
	rig.pull_t = 1.0 if stage == "finale" and flags.get("bossStarted", false) and not flags.get("finaleClear", false) else 0.0
	rig.pull_dist = K.boss.camera.distance
	rig.pull_fov = K.boss.camera.fov
	views.update(dt, now_, P, state)
	views.roof_door_update(dt, P)
	_sync_camera_blockers(P, stage, flags)
	_exposure(P, stage, setpieces.chase)
	if dt > 0.0:
		comms.update()


## Position-based exposure keeps checkpoint loads consistent with traversal.
func _exposure(P: Player, stage: String, chase: Dictionary) -> void:
	var DX := float(WhData.DEPTH_X)
	var exposure := 1.0 if stage == "roof" else (smoothstep(DX + 85.0, DX + 164.0, P.x) if stage == "escape" or stage == "finale" else 0.0)
	var heat := 0.4 if chase.phase == "rise" else (clampf(1.0 - float(chase.dist) / float(K.setpieces.chase.warnAt), 0.0, 1.0) if chase.phase == "run" else 0.0)
	var key := "%s/%.2f/%.1f" % [stage, exposure, heat]
	var view: View = Game.view
	if key != _look_key:
		_look_key = key
		var mood := 0xc7b9e1 if stage == "vault" else (0xb3c3d2 if stage == "security" else (0xe2b98b if stage == "reclamation" else 0xe2d5b4))
		view.set_hemi(Color.hex((mood << 8) | 0xff).lerp(NIGHT_AMBIENT, exposure), Color.hex(0x354952ff).lerp(NIGHT_GROUND, exposure), 0.74 + exposure * 0.24)
		view.set_sun(Color.hex(0xffddb0ff).lerp(NIGHT_MOON, exposure), 0.46 + exposure * 0.16)
		views.exterior_visible(exposure > 0.0)
	var sky := INTERIOR_SKY.lerp(NIGHT_SKY, exposure)
	var fog := INTERIOR_FOG.lerp(NIGHT_FOG, exposure)
	# Compactor alarm: the room flushes red as it closes in, never so far that readability drops.
	if heat > 0.0:
		var pulse := 0.55 + 0.45 * sin(now_ * 7.0)
		fog = fog.lerp(ALARM_FOG, heat * pulse * 0.6)
		sky = sky.lerp(ALARM_SKY, heat * 0.35)
	view.set_background(sky)
	view.set_fog_exp2(fog, 0.0035 - exposure * 0.0013)
	# Interior rooms end well before 110 m. The previous 1200 m frustum submitted the waterfront, distant security bays and even the Foreman through several opaque walls on every Sorting frame.
	view.set_clip(view.camera.near, 110.0 + 1090.0 * exposure)
