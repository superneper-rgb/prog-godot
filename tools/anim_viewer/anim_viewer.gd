class_name AnimViewer
extends Node3D
## Animation viewer (dev tool, never part of the game): one playable character on a lit stage, posed by the game's own animators from a stand-in player state, holding any weapon.
## Pick a character, a move and a gun; orbit the camera or jump to a set view; pause, step, slow down, scrub a move on the timeline; fire and reload over any move.
## Start it with anim_viewer.bat (or `-- --anim-viewer`; `node tools/peek.mjs start anim-viewer` for the peek, then `AnimViewer.current` in an eval). Game stays idle while it runs.
## Besides Prog and Tommy it shows every enemy (the game's own Robot class and AI, run against a stand-in target) and the NPCs (tools/anim_viewer/anim_cast.gd): `subject` is &"player", &"enemy" or &"npc".
## For those two the viewer lends Game what the views reach for (root3d, level, world, player) and gives them back on exit.

static var current: AnimViewer = null

# the playable characters, by Builds.BUILDS id. One Prog (user, 2026-11-15): V2 and V3 went, and V3's authored-clip player with them, so every move here is the game's own Animator.
const CHARS: Array = [["prog", "Prog"], ["tommy", "Tommy"]]
const SUITS: Array = [["standard", "Standard outfit"], ["phantom_suit", "Phantom Suit"], ["goint_gear_xl", "GOINT GEAR XL"], ["schleedtech_combat", "SchleedTech Combat"], ["omen", "O.M.E.N."]]
# id, label, loop period in seconds (0: the move holds). An empty id is a heading.
const ACTIONS: Array = [
	["", "GROUND", 0.0],
	["idle", "Idle", 0.0],
	["tired_idle", "Idle, hurt (20 % health)", 0.0],
	["walk", "Walk", 0.0],
	["run", "Run", 0.0],
	["sprint", "Sprint", 0.0],
	["strafe_l", "Strafe left", 0.0],
	["strafe_r", "Strafe right", 0.0],
	["backpedal", "Walk backwards", 0.0],
	["tired_walk", "Walk, hurt", 0.0],
	["crouch", "Crouch", 0.0],
	["crouch_walk", "Crouch walk", 0.0],
	["", "AIR", 0.0],
	["jump_cycle", "Jump and land (loop)", 1.5],
	["jump_rise", "Jump, rising (held)", 0.0],
	["fall", "Falling (held)", 0.0],
	["hard_land", "Hard landing (loop)", 1.1],
	["flip_front", "Double-jump flip", 1.0],
	["flip_back", "Back flip", 1.0],
	["flip_side_l", "Side flip left", 1.0],
	["flip_side_r", "Side flip right", 1.0],
	["", "FIGHT", 0.0],
	["punch", "Punch combo", 1.3],
	["slam", "Hammer fist (air slam)", 1.6],
	["flail", "Flail swing (pick the flail)", 1.1],
	["", "CLIMB, SWIM", 0.0],
	["hang", "Ledge hang (held)", 0.0],
	["climb", "Ledge hang and pull up", 1.9],
	["pole", "Pole swing", 0.0],
	["ladder", "Ladder climb", 0.0],
	["wall_r", "Wall run, wall on his right", 0.0],
	["wall_l", "Wall run, wall on his left", 0.0],
	["swim_tread", "Swim, treading water", 0.0],
	["swim", "Swim, crawl", 0.0],
	["", "DEATH", 0.0],
	["death_back", "Death, shot from the front", 4.0],
	["death_front", "Death, shot from behind", 4.0],
]
# id, button, camera yaw (0: in front of him), pitch, distance, look height (fraction of his height)
const CAMS: Array = [
	["front", "Front", 0.0, 0.08, 5.0, 0.52],
	["three_q", "3/4", 0.7, 0.16, 5.0, 0.52],
	["right", "Right", -PI / 2.0, 0.04, 5.0, 0.52],
	["left", "Left", PI / 2.0, 0.04, 5.0, 0.52],
	["back", "Back", PI, 0.1, 5.0, 0.52],
	["game", "Game cam", PI, 0.22, 4.4, 0.85],
	["top", "Top", 0.4, 1.35, 6.0, 0.35],
	["low", "Low", 0.6, -0.14, 3.6, 0.3],
	["face", "Face", 0.3, 0.04, 1.1, 0.93],
	["hands", "Hands / gun", 0.55, 0.25, 1.9, 0.62],
	["feet", "Feet", 0.7, 0.14, 1.9, 0.07],
]
const LEDGE_T := 2.4         # the lip of the ledge prop
const POLE_Y := 2.75         # the pole prop's bar
const RUNG := 0.3            # ladder rung spacing (Player._ladder_step)

var subject := &"player"      # who is on the stage: the player's own animator (an), an enemy (foe) or an NPC (npc)
var foe: AnimFoe = null
var npc: AnimNpc = null
var foe_id := "robot"
var npc_id := "shit-chan"
var world: World
var P: Player
var combat: Combat           # only its reload clock runs (start_reload / _reload_step), so a reload is timed exactly as in play
var an: Animator
var char_id := "prog"
var suit_id := "standard"
var weapon := -1
var action := "idle"
var act_t := 0.0
var rate := 1.0
var paused := false
var aim := false
var speed_ovr := 0.0
var aim_pitch := 0.0
var aim_yaw := 0.0
var hp_ovr := 100.0
var auto_fire := false
var loop_reload := false
var show_bones := false
var show_props := true
var body_h := 1.7
var _step := false
var _fire_cd := 0.0
var _rl_wait := 0.0
var _act_period := 0.0

# camera
var cam: Camera3D
var cam_yaw := 0.7
var cam_pitch := 0.16
var cam_dist := 5.0
var cam_h := 0.52
var turntable := false
var follow := true
var _goal: Array = []        # [yaw, pitch, dist, h] being eased to
var _look_y := 0.9
var _clock := 0.0            # the enemies' and NPCs' time: runs with the playback (pause, step and the speed rate)
var _drag := 0               # 1 orbit, 2 raise / lower the look point

# stage
var _props: Node3D
var _prop_solids: Array[World.Solid] = []
var _prop_kind := ""
var _bones_mesh := ImmediateMesh.new()
var _bones_mi: MeshInstance3D
var _floor_mi: MeshInstance3D
var _material_look: RefCounted = null      # (declares the global shader values the enemies' materials read: the game's View does that, and it is not running here)
var _lent: Level = null          # the bare Level node Game.level points at while the viewer runs (the views add their effects under it)
var _cam_scale := 1.0            # the camera presets are for a 1.7 m body: bigger ones pull back
var _focus := Vector3.ZERO       # what the camera looks at, on the floor

# interface
var _ui: Control
var _panel: PanelContainer
var _opt_char: OptionButton
var _opt_suit: OptionButton
var _opt_weapon: OptionButton
var _lst_actions: ItemList
var _timeline: HSlider
var _lbl_time: Label
var _lbl_info: Label
var _lbl_help: Label
var _chk: Dictionary = {}    # name -> CheckBox
var _sliders: Dictionary = {}     # name -> HSlider
var _tl_drag := false
var _tl_panel: PanelContainer
var _player_only: Array[Control] = []      # suit, weapon, the modifiers over a move: nothing for an enemy or an NPC
var _foe_box: Control


func _ready() -> void:
	current = self
	world = World.new(get_world_3d().space)
	world.target_spots = []      # (Combat would put its practice robots on the spots)
	world.box(0.0, 0.0, 600.0, 600.0, 0.0, {"bottom": -1.0})      # (big: an enemy that chases walks on, and the floor and the camera follow it)
	P = Player.new(world)
	combat = Combat.new(world)
	# what the enemy and NPC views reach for in Game, which is idle here: their batches' nodes go under Game.root3d, their effects under Game.level
	Game.root3d = self
	Game.world = world
	Game.player = P
	_material_look = preload("res://core/material_look.gd").new()
	_lent = Level.new()
	_lent.name = "ViewerLevel"
	add_child(_lent)
	Game.level = _lent
	_stage()
	_build_ui()
	await get_tree().physics_frame      # the floor joins the broadphase before the feet look for it
	await get_tree().physics_frame
	set_character(char_id)
	set_action("idle")
	cam_preset("three_q", true)


func _exit_tree() -> void:
	if current == self:
		current = null
	_clear_other()
	if Game.root3d == self:
		Game.root3d = null
		Game.world = null
		Game.player = null
		Game.level = null
	if combat != null:
		combat.enemies.shutdown()
		combat.enemies = null
		combat.flail = null
	if world != null:
		world.dispose()


# ================= the stage =================
func _stage() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.075, 0.08, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("dfe9ff").lerp(Color("3a3020"), 0.35)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var key := DirectionalLight3D.new()
	key.light_energy = 1.6
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 25.0
	key.rotation = Vector3(-0.95, 0.55, 0.0)
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color("7fb4ff")
	rim.light_energy = 1.0
	rim.rotation = Vector3(-0.5, PI + 0.6, 0.0)
	add_child(rim)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40.0, 40.0)
	floor_mi.mesh = pm
	var fm := ShaderMaterial.new()
	fm.shader = load("res://tools/anim_viewer/anim_floor.gdshader")
	floor_mi.material_override = fm
	add_child(floor_mi)
	_floor_mi = floor_mi
	cam = Camera3D.new()
	cam.fov = 32.0
	cam.near = 0.05
	cam.far = 200.0
	add_child(cam)
	cam.current = true
	_props = Node3D.new()
	add_child(_props)
	_bones_mi = MeshInstance3D.new()
	_bones_mi.mesh = _bones_mesh
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.vertex_color_use_as_albedo = true
	bm.no_depth_test = true
	bm.render_priority = 10
	_bones_mi.material_override = bm
	_bones_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_bones_mi)


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _prop_box(size: Vector3, pos: Vector3, c: Color, solid: bool) -> void:
	var mi := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = size
	mi.mesh = bx
	mi.material_override = _mat(c)
	mi.position = pos
	_props.add_child(mi)
	if solid:
		_prop_solids.append(world.box(pos.x, pos.z, size.x, size.z, pos.y + size.y * 0.5, {"bottom": pos.y - size.y * 0.5}))


## The thing a move needs to be seen against (a ledge, a pole, a ladder, a wall, water). Solid ones join the World too, so the feet find the top of the ledge.
func _set_props(kind: String) -> void:
	if not show_props:
		kind = ""
	if kind == _prop_kind:
		return
	_prop_kind = kind
	for c in _props.get_children():
		c.queue_free()
	for s in _prop_solids:
		world.remove(s)
	_prop_solids.clear()
	var stone := Color(0.42, 0.4, 0.37)
	var steel := Color(0.55, 0.58, 0.62)
	match kind:
		"ledge":
			_prop_box(Vector3(3.0, LEDGE_T, 2.0), Vector3(0.0, LEDGE_T * 0.5, Config.radius + 0.04 + 1.0), stone, true)
		"pole":
			var mi := MeshInstance3D.new()
			var cy := CylinderMesh.new()
			cy.top_radius = 0.035
			cy.bottom_radius = 0.035
			cy.height = 4.0
			mi.mesh = cy
			mi.material_override = _mat(steel)
			mi.position = Vector3(0.0, POLE_Y, 0.0)
			mi.rotation.z = PI / 2.0
			_props.add_child(mi)
			for sx: float in [-2.0, 2.0]:
				_prop_box(Vector3(0.12, POLE_Y + 0.1, 0.12), Vector3(sx, (POLE_Y + 0.1) * 0.5, 0.0), stone, false)
		"ladder":
			for sx: float in [-0.25, 0.25]:
				_prop_box(Vector3(0.05, 5.0, 0.05), Vector3(sx, 2.5, 0.45), steel, false)
			for i in range(1, 16):
				_prop_box(Vector3(0.5, 0.03, 0.03), Vector3(0.0, i * RUNG, 0.45), steel, false)
		"wall_r", "wall_l":
			var sx := -1.0 if kind == "wall_r" else 1.0      # (yaw 0: +X is his left)
			_prop_box(Vector3(0.3, 3.5, 12.0), Vector3(sx * (Config.radius + 0.2), 1.75, 0.0), stone, false)
		"backwall":
			_prop_box(Vector3(12.0, 5.0, 0.5), Vector3(0.0, 2.5, -1.4), stone, true)
		"water":
			_prop_box(Vector3(8.0, 0.02, 8.0), Vector3(0.0, Config.swim_float, 0.0), Color(0.2, 0.45, 0.6, 0.45), false)


# ================= what is shown =================
static func build_of(id: String) -> Builds.Build:
	return Builds.BUILDS.get(id, Builds.BUILDS["prog"])


## Swap the character: always a fresh model and a fresh animator, as Game.spawn_character does.
func set_character(id: String) -> void:
	_clear_other()
	if subject != &"player":
		action = "idle"      # (the list of moves was somebody else's)
		subject = &"player"
		_fill_actions()
	_cam_scale = 1.0
	if an != null:
		an.actor.queue_free()
		an = null
	char_id = id
	var B := build_of(id)
	an = Animator.create(B)
	add_child(an.actor)
	# his height, from an idle frame, frames the camera views
	var keep := action
	action = "idle"
	_drive(0.016)
	an.update(0.016, P)
	action = keep
	var head: Animator.BoneRec = an.by_key.get(&"head")
	body_h = (an.bone_world_pos(head.bone).y + 0.14 * B.scale) if head != null else B.cam_height + 0.25
	PhantomSuit.wear_suit_by_id(an, suit_id)
	_sync_ui()


## Anyone on the stage: kind is &"player" (Prog or Tommy), &"enemy" (a Game.spawn_enemy kind) or &"npc" (an AnimCast.NPC_IDS id)
func set_subject(kind: StringName, id: String) -> void:
	match kind:
		&"enemy":
			set_enemy(id)
		&"npc":
			set_npc(id)
		_:
			set_character(id)


func set_enemy(id: String) -> void:
	_leave_player()
	foe_id = id
	subject = &"enemy"
	if id == "tongue":      # (the Wallwretch is part of a wall: it looks for the one behind it when it is made, so the wall is there, and in the broadphase, first)
		_set_props("backwall")
		await get_tree().physics_frame
		await get_tree().physics_frame
		if subject != &"enemy" or foe_id != id or foe != null:
			return
	foe = AnimFoe.new(self, id)
	_arrive(foe.body_h)


func set_npc(id: String) -> void:
	_leave_player()
	npc_id = id
	subject = &"npc"
	npc = AnimNpc.new(self, id)
	_arrive(npc.body_h)


## the player's own model goes (a fresh one is made when Prog or Tommy is picked again) and what the moves list shows changes
func _leave_player() -> void:
	_clear_other()
	if an != null:
		an.actor.queue_free()
		an = null
	_set_props("")
	_act_period = 0.0
	if _bones_mi != null:
		_bones_mi.visible = false


func _clear_other() -> void:
	if foe != null:
		foe.dispose()
		foe = null
	if npc != null:
		npc.dispose()
		npc = null
	if P != null:
		P.god = false


func _arrive(h: float) -> void:
	body_h = h
	_cam_scale = maxf(1.0, h / 1.7)
	_look_y = h * cam_h
	paused = false
	_fill_actions()
	_sync_ui()


func set_suit(id: String) -> void:
	suit_id = id
	if an != null:
		PhantomSuit.wear_suit_by_id(an, id)


func set_weapon(i: int) -> void:
	weapon = clampi(i, -1, Weapons.WEAPONS.size() - 1)
	combat.rl = null
	_rl_wait = 0.0
	_sync_ui()


func weapon_by_id(id: String) -> int:
	for i in Weapons.WEAPONS.size():
		if Weapons.WEAPONS[i].id == id:
			return i
	return -1


## What the moves list holds for who is on the stage: [id, label, ...]; an empty id is a heading
func _actions() -> Array:
	match subject:
		&"enemy":
			return AnimCast.FOE_ACTIONS
		&"npc":
			return npc.actions() if npc != null else []
	return ACTIONS


func _cur_action() -> String:
	match subject:
		&"enemy":
			return foe.action if foe != null else ""
		&"npc":
			return npc.action if npc != null else ""
	return action


func _fill_actions() -> void:
	if _lst_actions == null:
		return
	_lst_actions.clear()
	for a: Array in _actions():
		var i := _lst_actions.add_item(("— " + a[1] + " —") if a[0] == "" else "   " + a[1])
		_lst_actions.set_item_metadata(i, a[0])
		if a[0] == "":
			_lst_actions.set_item_selectable(i, false)
			_lst_actions.set_item_disabled(i, true)


func set_action(id: String) -> void:
	if subject == &"enemy" and foe != null:
		foe.set_action(id)
		_sync_ui()
		return
	if subject == &"npc" and npc != null:
		npc.set_action(id)
		_sync_ui()
		return
	for a: Array in ACTIONS:
		if a[0] == id:
			action = id
			_act_period = float(a[2])
			act_t = 0.0
			_sync_ui()
			return


func cam_preset(id: String, snap: bool = false) -> void:
	for c: Array in CAMS:
		if c[0] == id:
			_goal = [float(c[2]), float(c[3]), float(c[4]), float(c[5])]
			turntable = false
			if _chk.has("turntable"):
				_chk["turntable"].set_pressed_no_signal(false)
			if snap:
				cam_yaw = _goal[0]
				cam_pitch = _goal[1]
				cam_dist = _goal[2]
				cam_h = _goal[3]
				_goal = []
			return


func fire() -> void:
	if weapon < 0 or an == null or an.wv == null:
		return
	var w := Weapons.WEAPONS[weapon]
	an.wv.fire(w.id, 10.0)
	an.wv.flash(1.0, w.id)
	P.recoil = minf(1.6, P.recoil + w.kick)      # (as Combat._shoot)


func reload() -> void:
	if subject != &"player" or weapon < 0 or combat.rl != null:
		return
	var w := Weapons.WEAPONS[weapon]
	if w.reload_kind != "shell" and w.reload_time <= 0.0:
		return      # (a gun that never reloads)
	combat.cur = weapon
	combat.ammo[weapon] = 0.0
	combat.reserve[weapon] = 999.0
	var ads := P.ads
	P.ads = false
	combat.start_reload(P)
	P.ads = ads


# ================= the frame =================
func _process(delta: float) -> void:
	if an == null and foe == null and npc == null:
		return
	var real := minf(0.05, maxf(0.0001, delta))
	var go := not paused or _step
	var dt := (1.0 / 60.0 if paused else real) * rate
	_step = false
	if subject == &"player":
		if go:
			_advance(dt)
	else:
		if go:
			_clock += dt
			if foe != null:
				foe.tick(dt, _clock)
			elif npc != null:
				npc.tick(dt)
		Game.enemy_views.flush()      # (the enemies' and the alien NPCs' batches: one upload, once all are posed)
	_camera(real)
	_draw_bones()
	_show_info()
	_tl_panel.offset_left = (_panel.offset_left + _panel.size.x + 12.0) if _panel.visible else 12.0


func _advance(dt: float) -> void:
	act_t += dt
	if _act_period > 0.0:
		act_t = fmod(act_t, _act_period)
	_fire_cd -= dt
	if auto_fire and _fire_cd <= 0.0 and weapon >= 0:
		fire()
		_fire_cd = 1.0 / maxf(0.2, Weapons.WEAPONS[weapon].rate)
	_drive(dt)
	_reload_tick(dt)
	an.update(dt, P)
	an.death_pose(P)
	if show_bones:
		an.actor.visible = true


## Combat's reload clock, and what Combat.update hands the animator from it
func _reload_tick(dt: float) -> void:
	if combat.rl != null:
		combat._reload_step(dt, P)
	var rl := combat.rl
	P.rl_on = rl != null
	if rl != null:
		P.rl_kind = rl.kind
		P.rl_dur = rl.dur / maxf(0.1, Config.reload_speed)
		P.rl_u = rl.u
		P.rl_ph = rl.ph
		P.rl_pu = rl.pu
		P.rl_n = rl.k
		P.rl_empty = rl.empty
		_rl_wait = 0.0
	elif loop_reload and weapon >= 0:
		_rl_wait += dt
		if _rl_wait > 0.6:
			_rl_wait = 0.0
			reload()
	combat.events.clear()


func _move(left: float, fwd: float, sp: float) -> void:
	var s := speed_ovr if speed_ovr > 0.0 else sp
	var n := maxf(0.001, Vector2(left, fwd).length())
	P.vx = left / n * s       # yaw 0: forward is +Z, his left is +X
	P.vz = fwd / n * s


## The stand-in player state for the move: what the game's Player and Combat would hold at time act_t of it. The body stays on the spot (the floor does not scroll), so speeds only drive the gaits.
func _drive(dt: float) -> void:
	var C := Config
	var t := act_t
	P.x = 0.0
	P.y = 0.0
	P.z = 0.0
	P.yaw = 0.0
	P.vx = 0.0
	P.vy = 0.0
	P.vz = 0.0
	P.grounded = true
	P.crouching = false
	P.strafing = false
	P.sprinting = false
	P.mode = &"normal"
	P.mode_t = 0.0
	P.ledge = null
	P.pole = null
	P.wall_run = null
	P.ladder = null
	P.swim_s = null
	P.flip = -1.0
	P.flip_type = &"front"
	P.land_t = 0.0
	P.land_impact = 0.0
	P.land_dur = C.land_dur
	P.slamming = false
	P.slam_drop = false
	P.slam_u = 0.0
	P.punching = false
	P.punch_stage = 0
	P.punch_u = 0.0
	P.dead = false
	P.dead_t = 0.0
	P.max_hp = 100.0
	P.hp = hp_ovr
	P.power_aim = false
	P.scoped = false
	P.crouch_hide = false
	P.factory_interaction = null
	P.armed = weapon >= 0
	P.weapon_idx = weapon
	P.aiming = aim and P.armed
	P.ads = P.aiming
	P.aim_pitch = aim_pitch
	P.aim_yaw = aim_yaw
	P.recoil = maxf(0.0, P.recoil - dt * 7.0)
	FlailSim.FLAIL.on = false
	var kind := ""
	match action:
		"tired_idle":
			P.hp = 20.0
		"walk":
			_move(0.0, 1.0, 1.5)
		"run":
			_move(0.0, 1.0, C.run_speed)
		"sprint":
			P.sprinting = true
			_move(0.0, 1.0, C.run_speed * C.sprint_speed_mult)
		"strafe_l":
			P.strafing = true
			_move(1.0, 0.0, 3.0)
		"strafe_r":
			P.strafing = true
			_move(-1.0, 0.0, 3.0)
		"backpedal":
			P.strafing = true
			_move(0.0, -1.0, 2.0)
		"tired_walk":
			P.hp = 20.0
			_move(0.0, 1.0, 1.5)
		"crouch":
			P.crouching = true
		"crouch_walk":
			P.crouching = true
			_move(0.0, 1.0, C.run_speed * C.crouch_speed_mult)
		"jump_cycle":
			_jump(t)
		"jump_rise":
			P.grounded = false
			P.vy = 5.0
			P.y = 0.9
		"fall":
			P.grounded = false
			P.vy = -9.0
			P.y = 0.9
		"hard_land":
			if t < 0.15:
				P.grounded = false
				P.vy = -17.0
				P.y = 17.0 * (0.15 - t)
			elif t - 0.15 < C.land_dur:
				P.land_t = C.land_dur - (t - 0.15)
				P.land_impact = 17.0
		"flip_front", "flip_back", "flip_side_l", "flip_side_r":
			_flip(t)
		"punch":
			var durs := Combat.PUNCH_DUR
			var a := 0.0
			for s in durs.size():
				if t < a + durs[s]:
					P.punching = true
					P.punch_stage = s + 1      # (Combat's stages count from 1)
					P.punch_u = (t - a) / durs[s]
					break
				a += durs[s]
		"slam":
			_slam(t)
		"flail":
			FlailSim.FLAIL.on = t < FlailSim.FLAIL.duration
			FlailSim.FLAIL.elapsed = t
		"hang":
			kind = "ledge"
			_hang(t)
		"climb":
			kind = "ledge"
			_climb(t)
		"pole":
			kind = "pole"
			_pole(t)
		"ladder":
			kind = "ladder"
			P.mode = &"ladder"
			P.y = fmod(t * 0.9, 2.4)
			P.lad_ph = P.y / (2.0 * RUNG)      # (one cycle = two rungs, as Player._ladder_step)
			P.ladder = {"x": 0.0, "z": 0.45, "fx": 0.0, "fz": 1.0, "top": 5.0}
		"wall_r", "wall_l":
			kind = action
			var wr := Player.WallRun.new()
			wr.side = 1.0 if action == "wall_r" else -1.0      # (+1: the side his moves were authored with)
			wr.nx = -wr.side
			wr.tz = 1.0
			wr.sp = C.wall_run_speed
			wr.t = t
			P.wall_run = wr
			P.grounded = false
			P.y = 0.4
			_move(0.0, 1.0, C.wall_run_speed)
		"swim_tread", "swim":
			kind = "water"
			P.mode = &"swim"
			P.swim_s = C.swim_float
			var spd := 0.0
			if action == "swim":
				_move(0.0, 1.0, C.swim_speed)
				spd = Vector2(P.vx, P.vz).length()
			P.swim_ph = fmod(t * ((0.3 + spd * 0.13) if spd > 0.4 else 0.4), 1.0)      # (Player._swim_step's stroke clock)
		"death_back", "death_front":
			P.dead = t > 0.05
			P.dead_t = maxf(0.0, t - 0.05)
			P.fall_dir = -1.0 if action == "death_back" else 1.0
	_set_props(kind)


## A real jump: Config's take-off speed, rise and fall gravity, then the landing
func _jump(t: float) -> void:
	var C := Config
	var v0 := C.jump_vel
	var t_up := v0 / C.gravity_up
	var top := v0 * v0 / (2.0 * C.gravity_up)
	var t_dn := sqrt(2.0 * top / C.gravity_down)
	if t < t_up:
		P.grounded = false
		P.vy = v0 - C.gravity_up * t
		P.y = v0 * t - 0.5 * C.gravity_up * t * t
	elif t < t_up + t_dn:
		var td := t - t_up
		P.grounded = false
		P.vy = -C.gravity_down * td
		P.y = top - 0.5 * C.gravity_down * td * td
	elif t - t_up - t_dn < C.land_dur:
		P.land_t = C.land_dur - (t - t_up - t_dn)
		P.land_impact = C.gravity_down * t_dn


func _flip(t: float) -> void:
	var C := Config
	P.grounded = false
	P.y = 1.2
	var front := action == "flip_front"
	P.flip_type = {"flip_front": &"front", "flip_back": &"back", "flip_side_l": &"side_l", "flip_side_r": &"side_r"}[action]
	P.flip_len = C.flip_dur if front else C.aerial_flip_dur
	var a := 0.15
	if t < a:
		P.vy = 4.0
	elif t < a + P.flip_len:
		P.flip = (t - a) / P.flip_len
		P.vy = 2.0
	else:
		P.vy = -4.0
	if action == "flip_side_l":
		_move(1.0, 0.0, 4.0)
	elif action == "flip_side_r":
		_move(-1.0, 0.0, 4.0)
	elif action == "flip_back":
		_move(0.0, -1.0, 3.0)


## Hammer fist: up and wound back, the drop, the impact
func _slam(t: float) -> void:
	var C := Config
	if t < 0.35:
		P.grounded = false
		P.slamming = true
		P.slam_u = t / 0.35
		P.y = 1.6
	elif t < 0.55:
		P.grounded = false
		P.slamming = true
		P.slam_drop = true
		P.slam_u = 1.0
		P.vy = -20.0
		P.y = 1.6 * (1.0 - (t - 0.35) / 0.2)
	elif t - 0.55 < C.land_dur:
		P.land_t = C.land_dur - (t - 0.55)
		P.land_impact = 20.0


func _ledge() -> Player.Ledge:
	var e := Player.Ledge.new()
	e.t = LEDGE_T
	e.fx = 0.0
	e.fz = 1.0
	e.y0 = LEDGE_T - Config.hang_drop
	return e


func _hang(t: float) -> void:
	P.mode = &"hang"
	P.mode_t = t
	P.ledge = _ledge()
	P.y = P.ledge.y0


## Player._ledge_step's pull-up, on the clock
func _climb(t: float) -> void:
	var C := Config
	var L := _ledge()
	var hang := 0.5
	if t < hang:
		_hang(t)
		return
	var pt := t - hang
	if pt < C.pull_time:
		P.mode = &"pull"
		P.mode_t = pt
		P.ledge = L
		var u := clampf(pt / C.pull_time, 0.0, 1.0)
		var up := U.ease_in_out(clampf(u / 0.65, 0.0, 1.0))
		var fw := U.ease_in_out(clampf((u - 0.45) / 0.55, 0.0, 1.0))
		P.y = lerpf(L.y0, L.t, up)
		P.z = L.fz * (C.radius + 0.15) * fw
		return
	P.y = L.t
	P.z = C.radius + 0.15
	P.land_t = maxf(0.0, 0.1 - (pt - C.pull_time))


## Player._pole_place on a swing
func _pole(t: float) -> void:
	var pl := Player.Pole.new()
	pl.p = {"x": 0.0, "y": POLE_Y, "z": 0.0, "axis": "x"}
	pl.lc = Config.pole_com
	pl.th = 0.8 * sin(t * 2.4)
	pl.w = 0.8 * 2.4 * cos(t * 2.4)
	pl.sgn = 1.0
	P.mode = &"pole"
	P.mode_t = t
	P.pole = pl
	P.z = pl.lc * sin(pl.th)
	P.y = POLE_Y - pl.lc * cos(pl.th) - 0.9


# ================= camera =================
func _camera(dt: float) -> void:
	if not _goal.is_empty():
		var k := 1.0 - exp(-10.0 * dt)
		cam_yaw = lerp_angle(cam_yaw, _goal[0], k)
		cam_pitch = lerpf(cam_pitch, _goal[1], k)
		cam_dist = lerpf(cam_dist, _goal[2], k)
		cam_h = lerpf(cam_h, _goal[3], k)
		if absf(angle_difference(cam_yaw, _goal[0])) < 0.002 and absf(cam_dist - _goal[2]) < 0.005:
			_goal = []
	if turntable:
		cam_yaw += dt * 0.45
	var base := 0.0
	var at := Vector3.ZERO      # what the camera follows, on the floor
	if follow:
		match subject:
			&"player":
				if an != null:
					base = an.actor.position.y - build_of(char_id).pivot * build_of(char_id).scale
					if P.dead:
						base = 0.0
				at = Vector3(P.x, 0.0, P.z)
			&"enemy":
				if foe != null:
					at = foe.focus()
					base = at.y
			&"npc":
				if npc != null:
					at = npc.focus()
					base = at.y
	_look_y = lerpf(_look_y, base + body_h * cam_h, 1.0 - exp(-8.0 * dt))
	var look := Vector3(at.x, _look_y, at.z)
	_focus = at
	var cp := cos(cam_pitch)
	cam.position = look + Vector3(sin(cam_yaw) * cp, sin(cam_pitch), cos(cam_yaw) * cp) * (cam_dist * _cam_scale)
	cam.look_at(look)
	_floor_mi.position = Vector3(roundf(at.x), 0.0, roundf(at.z))      # (the plate goes where the camera is: an enemy that chases walks on)
	(_floor_mi.material_override as ShaderMaterial).set_shader_parameter(&"centre", Vector2(at.x, at.z))


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			cam_dist = maxf(0.4, cam_dist * 0.9)
			_goal = []
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			cam_dist = minf(30.0, cam_dist / 0.9)
			_goal = []
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			_drag = 1 if mb.pressed else 0
		elif mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			_drag = 2 if mb.pressed else 0
	elif ev is InputEventMouseMotion and _drag != 0:
		var mm := ev as InputEventMouseMotion
		_goal = []
		if _drag == 1:
			cam_yaw -= mm.relative.x * 0.008
			cam_pitch = clampf(cam_pitch + mm.relative.y * 0.006, -1.3, 1.5)
		else:
			cam_h = clampf(cam_h + mm.relative.y * 0.003 * cam_dist / maxf(body_h, 0.3), -0.3, 1.6)
	elif ev is InputEventKey and ev.pressed:
		var k := ev as InputEventKey
		var handled := true
		match k.keycode:
			KEY_UP:
				_list_step(-1)
			KEY_DOWN:
				_list_step(1)
			KEY_LEFT:
				set_weapon(weapon - 1)
			KEY_RIGHT:
				set_weapon(weapon + 1 if weapon + 1 < Weapons.WEAPONS.size() else -1)
			_:
				handled = false
		if not handled and not k.echo:
			handled = true
			match k.keycode:
				KEY_TAB:
					_cycle_subject(-1 if k.shift_pressed else 1)
				KEY_SPACE:
					paused = not paused
					_sync_ui()
				KEY_PERIOD:
					paused = true
					_step = true
					_sync_ui()
				KEY_BACKSPACE, KEY_HOME:
					_restart()
				KEY_F:
					fire()
				KEY_G:
					auto_fire = not auto_fire
					_sync_ui()
				KEY_R:
					reload()
				KEY_A:
					aim = not aim
					_sync_ui()
				KEY_T:
					turntable = not turntable
					_goal = []
					_sync_ui()
				KEY_B:
					show_bones = not show_bones
					_sync_ui()
				KEY_H:
					_panel.visible = not _panel.visible
				KEY_MINUS:
					_set_rate(rate * 0.5)
				KEY_EQUAL:
					_set_rate(rate * 2.0)
				_:
					var n := k.keycode - KEY_1 if k.keycode >= KEY_1 and k.keycode <= KEY_9 else (9 if k.keycode == KEY_0 else -1)
					if n >= 0 and n < CAMS.size():
						cam_preset(CAMS[n][0])
					else:
						handled = false
		if handled:
			get_viewport().set_input_as_handled()


func _set_rate(r: float) -> void:
	rate = clampf(r, 0.0625, 2.0)
	_sync_ui()


func _list_step(d: int) -> void:
	var lst := _lst_actions
	if lst.item_count == 0:
		return
	var sel := lst.get_selected_items()
	var i: int = sel[0] if not sel.is_empty() else -1
	for _n in lst.item_count:
		i = posmod(i + d, lst.item_count)
		if lst.is_item_selectable(i):
			break
	lst.select(i)
	lst.ensure_current_is_visible()
	_on_list_pick(i)


func _restart() -> void:
	act_t = 0.0
	if foe != null:
		foe.restart()


## Tab / Shift+Tab: the next one in the character menu, enemies and NPCs after the playable ones
func _cycle_subject(d: int) -> void:
	var items: Array = []
	var at := 0
	for i in _opt_char.item_count:
		var m: Variant = _opt_char.get_item_metadata(i)
		if m is Array:
			if m[0] == subject and m[1] == _cur_id():
				at = items.size()
			items.append(m)
	if items.is_empty():
		return
	var n: Array = items[posmod(at + d, items.size())]
	set_subject(n[0], n[1])


func _cur_id() -> String:
	match subject:
		&"enemy":
			return foe_id
		&"npc":
			return npc_id
	return char_id


# ================= bones and the readout =================
func _draw_bones() -> void:
	_bones_mi.visible = show_bones and an != null
	if not show_bones or an == null:
		return
	_bones_mesh.clear_surfaces()
	var sk := an.skel
	var xf := sk.global_transform
	_bones_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for b in sk.get_bone_count():
		var p := sk.get_bone_parent(b)
		if p < 0:
			continue
		var nm := sk.get_bone_name(b)
		var c := Color(1.0, 0.85, 0.2)
		if nm.ends_with("L") or nm.ends_with(".L") or nm.ends_with("_l"):
			c = Color(0.3, 0.8, 1.0)
		elif nm.ends_with("R") or nm.ends_with(".R") or nm.ends_with("_r"):
			c = Color(1.0, 0.4, 0.35)
		_bones_mesh.surface_set_color(c)
		_bones_mesh.surface_add_vertex(xf * sk.get_bone_global_pose(p).origin)
		_bones_mesh.surface_set_color(c)
		_bones_mesh.surface_add_vertex(xf * sk.get_bone_global_pose(b).origin)
	_bones_mesh.surface_end()


func _show_info() -> void:
	var lines: PackedStringArray = []
	if subject != &"player":
		if foe == null and npc == null:
			return
		lines.append("%s  |  %s" % [_char_label(), _cur_label()])
		lines.append(foe.readout() if foe != null else npc.readout())
		if paused:
			lines.append("PAUSED")
		if rate != 1.0:
			lines.append("x%s speed" % str(snappedf(rate, 0.001)))
		_lbl_info.text = "\n".join(lines)
		_timeline.set_value_no_signal(0.0)
		_timeline.editable = false
		_lbl_time.text = "%.1f s   (no timeline: it runs on its own AI)" % (foe.t if foe != null else _clock)
		return
	var wname := "unarmed" if weapon < 0 else "%s (%s)" % [Weapons.WEAPONS[weapon].name, Weapons.WEAPONS[weapon].id]
	lines.append("%s  |  %s  |  %s%s" % [_char_label(), action, wname, "  |  AIM" if P.aiming else ""])
	var st := ""
	if paused:
		st = "PAUSED"
	if rate != 1.0:
		st += ("  " if st != "" else "") + "x%s speed" % str(snappedf(rate, 0.001))
	if P.rl_on:
		st += ("  " if st != "" else "") + "reload %s %.2f" % [P.rl_ph, P.rl_u]
	if st != "":
		lines.append(st)
	var parts: PackedStringArray = []
	for n: String in ["w_air", "w_cr", "w_strafe", "w_sp", "w_aim", "w_arm", "w_rl", "w_flip", "w_hang", "w_wr", "w_swim", "w_lad", "w_slam", "w_pu", "w_fat"]:
		var v: Variant = an.get(StringName(n))
		if v != null and float(v) > 0.01:
			parts.append("%s %.2f" % [n.substr(2), float(v)])
	lines.append("layers: " + (" | ".join(parts) if not parts.is_empty() else "ground"))
	_lbl_info.text = "\n".join(lines)
	var L := _act_period
	if not _tl_drag:
		_timeline.set_value_no_signal(act_t / L if L > 0.0 else 0.0)
	_timeline.editable = L > 0.0
	_lbl_time.text = ("%.2f / %.2f s" % [act_t, L]) if L > 0.0 else "%.1f s (held move)" % act_t


func _cur_label() -> String:
	var id := _cur_action()
	for a: Array in _actions():
		if a[0] == id:
			return a[1]
	return id


func _char_label() -> String:
	if subject == &"enemy":
		return AnimCast.foe_label(foe_id)
	if subject == &"npc":
		return AnimCast.npc_label(npc_id)
	for c: Array in CHARS:
		if c[0] == char_id:
			return c[1]
	return char_id


# ================= the interface =================
static func _theme() -> Theme:
	var t: Theme = CrtTheme.tools_theme().duplicate()
	var line := Color("2f6b3c")
	var bg := Color(0.03, 0.07, 0.045, 0.92)
	t.set_stylebox(&"panel", &"PanelContainer", CrtTheme.panel(bg, 6, line, 12, 10))
	var it := CrtTheme.panel(Color(0, 0, 0, 0.35), 4, line, 4, 4)
	t.set_stylebox(&"panel", &"ItemList", it)
	t.set_stylebox(&"focus", &"ItemList", StyleBoxEmpty.new())
	t.set_stylebox(&"selected", &"ItemList", CrtTheme.panel(Color(60.0 / 255.0, 160.0 / 255.0, 90.0 / 255.0, 0.55), 3))
	t.set_stylebox(&"selected_focus", &"ItemList", CrtTheme.panel(Color(60.0 / 255.0, 160.0 / 255.0, 90.0 / 255.0, 0.55), 3))
	t.set_stylebox(&"hovered", &"ItemList", CrtTheme.panel(Color(40.0 / 255.0, 120.0 / 255.0, 66.0 / 255.0, 0.35), 3))
	t.set_color(&"font_color", &"ItemList", Color("9df5b0"))
	t.set_color(&"font_selected_color", &"ItemList", Color("f0fff5"))
	t.set_color(&"font_hovered_color", &"ItemList", Color("c8ffd4"))
	t.set_color(&"font_disabled_color", &"ItemList", CrtTheme.AMBER)
	for st: Array in [[&"normal", Color(30.0 / 255.0, 80.0 / 255.0, 45.0 / 255.0, 0.35)], [&"hover", Color(40.0 / 255.0, 120.0 / 255.0, 66.0 / 255.0, 0.55)], [&"pressed", Color(60.0 / 255.0, 160.0 / 255.0, 90.0 / 255.0, 0.6)], [&"focus", Color(0, 0, 0, 0)], [&"disabled", Color(0, 0, 0, 0.3)]]:
		t.set_stylebox(st[0], &"OptionButton", CrtTheme.panel(st[1], 4, line, 10, 5))
	t.set_color(&"font_color", &"OptionButton", Color("c8ffd4"))
	t.set_color(&"font_hover_color", &"OptionButton", Color("e8ffe9"))
	t.set_stylebox(&"disabled", &"Button", CrtTheme.panel(Color(0, 0, 0, 0.3), 4, Color("1d3a24"), 10, 5))
	t.set_stylebox(&"panel", &"PopupMenu", CrtTheme.panel(bg, 4, line, 6, 6))
	t.set_stylebox(&"hover", &"PopupMenu", CrtTheme.panel(Color(60.0 / 255.0, 160.0 / 255.0, 90.0 / 255.0, 0.55), 3))
	t.set_color(&"font_color", &"PopupMenu", Color("9df5b0"))
	t.set_color(&"font_hover_color", &"PopupMenu", Color("f0fff5"))
	return t


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.theme = _theme()
	layer.add_child(_ui)
	# the panel down the left
	_panel = PanelContainer.new()
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 12.0
	_panel.offset_top = 12.0
	_panel.offset_right = 352.0
	_panel.offset_bottom = -12.0
	_ui.add_child(_panel)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override(&"separation", 6)
	sc.add_child(v)
	var title := CrtTheme.label("ANIM VIEWER", &"mono", 18, CrtTheme.PH_HI, 2)
	v.add_child(title)
	_opt_char = _option(v, "Character, enemy or NPC   [Tab]", [], func(i: int) -> void:
		var m: Array = _opt_char.get_item_metadata(i)
		set_subject(m[0], m[1]))
	_opt_char.add_separator("PLAYABLE")
	for c: Array in CHARS:
		_add_subject(&"player", c[0], c[1])
	_opt_char.add_separator("ENEMIES")
	for e: Array in AnimCast.ENEMIES:
		if e[0] == "":
			_opt_char.add_separator(e[1])
		else:
			_add_subject(&"enemy", e[0], e[1])
	_opt_char.add_separator("NPCS")
	for e: Array in AnimCast.NPC_IDS:
		if e[0] == "":
			_opt_char.add_separator(e[1])
		else:
			_add_subject(&"npc", e[0], AnimCast.npc_label(e[0]))
	var po0 := v.get_child_count()
	_opt_suit = _option(v, "Suit", SUITS.map(func(c: Array) -> String: return c[1]), func(i: int) -> void: set_suit(SUITS[i][0]))
	var wl: Array = ["Unarmed (fists)"]
	for w: Weapons.Def in Weapons.WEAPONS:
		wl.append("%s  (%s)" % [w.name, w.id])
	_opt_weapon = _option(v, "Weapon   [ < > ]", wl, func(i: int) -> void: set_weapon(i - 1))
	_player_only.append_array(_children_since(v, po0))
	# the moves (the game's own, for Prog and Tommy; the AI's, for an enemy or an NPC)
	_lst_actions = ItemList.new()
	_lst_actions.custom_minimum_size = Vector2(0, 330)
	_lst_actions.focus_mode = Control.FOCUS_NONE
	_lst_actions.item_selected.connect(_on_list_pick)
	v.add_child(_lst_actions)
	_fill_actions()
	# an enemy's target: the stand-in player it hunts
	_foe_box = VBoxContainer.new()
	v.add_child(_foe_box)
	_foe_box.add_child(CrtTheme.label("ENEMY'S TARGET", &"mono", 12, CrtTheme.PH_DIM, 1))
	_slider(_foe_box, "dist", "Target distance (m)", 1.0, 30.0, 0.5, 6.0, func(x: float) -> void:
		if foe != null:
			foe.set_dist(x))
	# modifiers
	var po1 := v.get_child_count()
	v.add_child(CrtTheme.label("OVER THE MOVE", &"mono", 12, CrtTheme.PH_DIM, 1))
	var g := GridContainer.new()
	g.columns = 2
	v.add_child(g)
	_check(g, "aim", "Aim  [A]", func(on: bool) -> void: aim = on)
	_check(g, "auto_fire", "Keep firing  [G]", func(on: bool) -> void: auto_fire = on)
	_check(g, "loop_reload", "Keep reloading", func(on: bool) -> void:
		loop_reload = on
		if on:
			reload())
	_check(g, "props", "Props", func(on: bool) -> void:
		show_props = on
		_prop_kind = "?")
	var hb2 := HBoxContainer.new()
	v.add_child(hb2)
	for b: Button in [_button(hb2, "Fire  [F]", fire), _button(hb2, "Reload  [R]", reload)]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider(v, "speed", "Move speed (0 = the move's own)", 0.0, 12.0, 0.1, 0.0, func(x: float) -> void: speed_ovr = x)
	_slider(v, "pitch", "Aim up / down", -1.2, 1.2, 0.01, 0.0, func(x: float) -> void: aim_pitch = x)
	_slider(v, "yaw", "Aim left / right", -0.8, 0.8, 0.01, 0.0, func(x: float) -> void: aim_yaw = x)
	_slider(v, "hp", "Health", 0.0, 100.0, 1.0, 100.0, func(x: float) -> void: hp_ovr = x)
	_player_only.append_array(_children_since(v, po1))
	# playback
	v.add_child(CrtTheme.label("PLAYBACK", &"mono", 12, CrtTheme.PH_DIM, 1))
	var hb3 := HBoxContainer.new()
	v.add_child(hb3)
	_button(hb3, "Pause [Space]", func() -> void:
		paused = not paused
		_sync_ui())
	_button(hb3, "Step [.]", func() -> void:
		paused = true
		_step = true
		_sync_ui())
	_button(hb3, "Restart [Bksp]", _restart)
	_slider(v, "rate", "Speed  [ - = ]", 0.05, 2.0, 0.05, 1.0, func(x: float) -> void: rate = x)
	# camera
	var cl := CrtTheme.label("CAMERA  (drag: orbit, right-drag: up / down, wheel: zoom)", &"mono", 12, CrtTheme.PH_DIM, 1)
	cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cl.custom_minimum_size = Vector2(300, 0)
	v.add_child(cl)
	var cg := GridContainer.new()
	cg.columns = 3
	v.add_child(cg)
	for i in CAMS.size():
		var c: Array = CAMS[i]
		var b := _button(cg, "%s [%d]" % [c[1], (i + 1) % 10] if i < 10 else c[1], func() -> void: cam_preset(c[0]))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var g2 := GridContainer.new()
	g2.columns = 2
	v.add_child(g2)
	_check(g2, "turntable", "Turntable  [T]", func(on: bool) -> void:
		turntable = on
		_goal = [])
	_check(g2, "follow", "Follow body", func(on: bool) -> void: follow = on)
	_check(g2, "bones", "Bones  [B]", func(on: bool) -> void: show_bones = on)
	_lbl_help = CrtTheme.label("Up / Down: move   Left / Right: weapon   Tab: character   H: hide this panel", &"mono", 11, CrtTheme.PH_LOW)
	_lbl_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_help.custom_minimum_size = Vector2(300, 0)
	v.add_child(_lbl_help)
	# the readout, top right
	_lbl_info = CrtTheme.label("", &"mono", 13, CrtTheme.PH, 0)
	_lbl_info.anchor_left = 1.0
	_lbl_info.anchor_right = 1.0
	_lbl_info.offset_left = -760.0
	_lbl_info.offset_right = -16.0
	_lbl_info.offset_top = 12.0
	_lbl_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_info.label_settings.outline_color = Color(0, 0, 0, 0.85)
	_lbl_info.label_settings.outline_size = 5
	_ui.add_child(_lbl_info)
	# the timeline along the bottom
	var tl := PanelContainer.new()
	_tl_panel = tl
	tl.anchor_left = 0.0
	tl.anchor_right = 1.0
	tl.anchor_top = 1.0
	tl.anchor_bottom = 1.0
	tl.offset_left = 366.0
	tl.offset_right = -12.0
	tl.offset_top = -52.0
	tl.offset_bottom = -12.0
	_ui.add_child(tl)
	var th := HBoxContainer.new()
	th.add_theme_constant_override(&"separation", 12)
	tl.add_child(th)
	_timeline = HSlider.new()
	_timeline.min_value = 0.0
	_timeline.max_value = 1.0
	_timeline.step = 0.0
	_timeline.focus_mode = Control.FOCUS_NONE
	_timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timeline.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_timeline.drag_started.connect(func() -> void:
		_tl_drag = true
		paused = true
		_sync_ui())
	_timeline.drag_ended.connect(func(_c: bool) -> void: _tl_drag = false)
	_timeline.value_changed.connect(_scrub)
	th.add_child(_timeline)
	_lbl_time = CrtTheme.label("", &"mono", 12, CrtTheme.PH, 0)
	_lbl_time.custom_minimum_size = Vector2(230, 0)
	th.add_child(_lbl_time)
	_chk["follow"].set_pressed_no_signal(true)
	_chk["props"].set_pressed_no_signal(true)


## Dragging the timeline: the move is replayed for a few frames at that moment so its blends settle (gait phases keep their own clock)
func _scrub(u: float) -> void:
	if an == null:
		return
	paused = true
	if _act_period > 0.0:
		var t := u * _act_period
		for _n in 12:
			act_t = t
			_advance(0.0001)
			act_t = t - 1.0 / 60.0
			_advance(1.0 / 60.0)
		act_t = t
	_sync_ui()


func _on_list_pick(i: int) -> void:
	if i < 0 or i >= _lst_actions.item_count:
		return
	var id: String = _lst_actions.get_item_metadata(i)
	if id != "":
		set_action(id)


func _add_subject(kind: StringName, id: String, label: String) -> void:
	_opt_char.add_item(label)
	_opt_char.set_item_metadata(_opt_char.item_count - 1, [kind, id])


## the controls added to `parent` since it had `from` children
static func _children_since(parent: Control, from: int) -> Array[Control]:
	var out: Array[Control] = []
	for i in range(from, parent.get_child_count()):
		out.append(parent.get_child(i) as Control)
	return out


func _option(parent: Control, label: String, items: Array, cb: Callable) -> OptionButton:
	parent.add_child(CrtTheme.label(label.to_upper(), &"mono", 12, CrtTheme.PH_DIM, 1))
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	for s: String in items:
		o.add_item(s)
	o.item_selected.connect(cb)
	parent.add_child(o)
	return o


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _check(parent: Control, key: String, text: String, cb: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(cb)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(c)
	_chk[key] = c
	return c


func _slider(parent: Control, key: String, text: String, lo: float, hi: float, st: float, val: float, cb: Callable) -> HSlider:
	var l := CrtTheme.label(text, &"mono", 12, CrtTheme.PH, 0)
	parent.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = st
	s.value = val
	s.focus_mode = Control.FOCUS_NONE
	s.custom_minimum_size = Vector2(0, 18)
	s.value_changed.connect(func(x: float) -> void:
		l.text = "%s:  %s" % [text, str(snappedf(x, st))]
		cb.call(x))
	l.text = "%s:  %s" % [text, str(snappedf(val, st))]
	parent.add_child(s)
	_sliders[key] = s
	return s


## The panel shows the state: what is picked, what is on
func _sync_ui() -> void:
	if _opt_char == null:
		return
	for j in _opt_char.item_count:
		var m: Variant = _opt_char.get_item_metadata(j)
		if m is Array and m[0] == subject and m[1] == _cur_id():
			_opt_char.select(j)
	for c in _player_only:
		c.visible = subject == &"player"
	_foe_box.visible = subject == &"enemy"
	if foe != null and _sliders.has("dist") and not is_equal_approx(_sliders["dist"].value, foe.dist):
		_sliders["dist"].value = foe.dist
	for j in SUITS.size():
		if SUITS[j][0] == suit_id:
			_opt_suit.select(j)
	_opt_weapon.select(weapon + 1)
	var want := _cur_action()
	for i in _lst_actions.item_count:
		if _lst_actions.get_item_metadata(i) == want:
			if not _lst_actions.is_selected(i):
				_lst_actions.select(i)
				_lst_actions.ensure_current_is_visible()
	for k: String in _chk:
		var on := false
		match k:
			"aim":
				on = aim
			"auto_fire":
				on = auto_fire
			"loop_reload":
				on = loop_reload
			"props":
				on = show_props
			"turntable":
				on = turntable
			"follow":
				on = follow
			"bones":
				on = show_bones
		(_chk[k] as CheckBox).set_pressed_no_signal(on)
	if _sliders.has("rate") and not is_equal_approx(_sliders["rate"].value, rate):
		_sliders["rate"].value = rate
