extends Node
## Autoload Game: the one long-running game. Owns the frame (same order as the three.js main loop), the shared things that live for the
## whole session (player, camera rig, combat, FX, HUD) and the current level. Everything a level builds hangs under its Level node, so
## leaving a level is freeing that node plus its World: that is all the unload there is.
##
## SHARED FILE: several pieces plug in here. Re-read it right before editing and change only the part your piece needs.

const LEVELS := {
	"arena": "res://levels/arena/arena.gd",
	"club": "res://levels/club/club_level.gd",
	"apartment": "res://levels/apartment/apartment_level.gd",
	"warehouse": "res://levels/warehouse/warehouse_level.gd",
	"kame-lab": "res://levels/kame_lab/kame_lab_level.gd",
	"omnisphere": "res://levels/omnisphere/omnisphere_level.gd",
	"visiting-hours": "res://levels/visiting_hours/visiting_hours_level.gd",
	"spire": "res://levels/spire/spire_level.gd",
	"mothership": "res://levels/mothership/mothership_level.gd",
	"foint-dome": "res://levels/foint_dome/foint_dome_level.gd",
	"sky-sphere": "res://levels/sky_sphere/sky_sphere_level.gd",
	"hub": "res://levels/hub/hub_level.gd",
	"dev": "res://levels/dev/dev_level.gd",
	"blockout-demo": "res://levels/blockout_demo/level.gd",
	"worldbackalley": "res://levels/worldbackalley/level.gd",
	"jungle-test": "res://levels/jungle_test/jungle_test_level.gd",
	"underfoint": "res://levels/underfoint/underfoint_level.gd",
	"palace": "res://levels/palace/palace_level.gd",
}
const DEFAULT_LEVEL := "hub"      # JS START_LEVEL: a new game, CONTINUE with nowhere saved and the menu's world behind it all start on the hub street (the arena is the movement test ground: --level=arena)

var level: Level = null
var world: World = null
var player: Player = null
var rig: CameraRig = null
var camera: Camera3D = null
var root3d: Node3D = null
var ui_root: CanvasLayer = null     # all 2D UI hangs here
var time := 0.0
var paused := false
var overlay: Node = null      # a full-screen minigame that holds the world still (JS: the overlay plus setTimeScale)
var time_scale := 1.0
var _entering := false              # a level is being swapped in (enter_level)
var started := true                # false while the main menu / intro owns the frame

# Shared systems, filled in as they are ported. Untyped until every class exists; null-checked in the frame.
var animator: Animator = null   # player/animator.gd  the playable character's procedural animation (JS Animator)
var drunk := Drunk.new()        # player/drunk.gd     what CLUB 9's bar has done to him (lasts across levels until it wears off)
var char_pick := "prog" # the character being played: 'prog' or 'tommy' (--char=; the JS start screen's pick)
var combat: Combat = null  # combat/combat.gd       weapons, damage, targets (JS Combat)
var input_dead := false # a cutscene or a machine has the player: combat reads no buttons (JS: (CINE && !PLAYCINE) || player.factoryInteraction.active)
var money := 10000      # JS money (SAVEGAME.data.money, START_MONEY)
var save_data := {"money": 10000, "gear": {"slots": [], "ammo": {}, "reserve": {}, "equip": null}, "granted": {}, "armor": {"owned": ["standard"], "equipped": "standard"}}   # JS SAVEGAME.data, the live record of the slot in use (save.data once the save has booted)
var enemies: Enemies = null   # enemies/enemies.gd  AI population (JS Enemies)
var enemy_views := EnemyViews.new()   # enemies/enemy_views.gd  the robots on screen (JS fx.bots)
var _next_enemy_id := 1000
var _shared: Dictionary = {}   # JS SHARED: snapshots of the shared objects, taken before the first level runs (take_shared_snapshots / restore_shared)
var fx = null           # fx/fx.gd                  tracers, sparks, explosions, decals, shake (JS FX)
var sfx = null          # audio/sfx.gd              all sound (JS Sfx)
var hud = null          # ui/hud.gd                 health, ammo, crosshair, toasts (JS Hud)
var wheel = null        # ui/wheel.gd               weapon wheel (JS Wheel)
var view: View = null   # core/view.gd              camera FOV / shake, sun, fog, sky, render look (JS View + post-fx)
var vehicles = null     # vehicles/vehicles.gd      drivable vehicles (JS vehicles.js)
var menus: Array = []   # open-able terminals / shops (JS MENUS)
var shops: Shops = null  # ui/shop/shops.gd
# Who may own the camera at the end of the frame (View.apply_camera has the order and what each one must offer). Null until those systems are ported.
var dialogue: Dialogue = Dialogue.new()   # the shared dialogue (JS DLG + dlgCamera)
var doors: Doors = Doors.new()            # level doors, world actions, what X acts on (JS PORTALS, WORLD_ACTIONS, nearInteract, travel)
var cur_spawn_at := ""                    # the door the current level was entered by (JS curSpawnAt)
var cutscenes: Dictionary = {}   # name -> running cutscene object; the names and their priority are View.CUTSCENE_ORDER
var freecam = null      # dev console fly camera
var forge: Forge = null  # forge/forge.gd: the in-game level editor (FORGE, F8; new on purpose, not a port). One of `menus` while it edits, so the world holds still
var city_ambience: CityAmbience = null
var night_vision = null # gear/night-vision: light amplification around the draw
var player_clones := PlayerClones.new()      # player/player_clones.gd: AI allies on the player rig (the dev console's clone)
var power_store: PowerStore = null      # powers/power_store.gd   which implants are owned and equipped
var power: Power = null                 # powers/power.gd         power mode, mana, the implants
var implant_cs: ImplantInject = null    # cutscenes/implant_inject.gd
var arena_tv = null     # the arena's broadcast camera
var arena_blocked := false      # JS arenaBlocked: FOINT DOME between runs: no shooting, no wheel, the world held
var frame_dt := 0.0     # this frame's dt and real dt, for a level whose tick also runs parts the game does not freeze
var frame_real_dt := 0.0
var menu_cam := Callable()   # the camera while the main menu owns the frame
var ui: GameUi = null   # ui/game_ui.gd             all the 2D interface and the flow between its screens (start, pause, back to the menu)
var save: SaveGame = null    # core/save_game.gd    the three slots; save_data is its live record
var music = null        # a level's own music (JS music: volume, play(), duck(), stop()); the pause menu's slider shows while there is one


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	ArmorStore.on_change = sync_armor
	shops = Shops.new()
	menus.append_array(shops.all())


## Quitting. ENGINE DIFFERENCE: the JS has a garbage collector, RefCounted does not free cycles (combat <-> enemies <-> robots, combat <-> flail), and a World's bodies go only with dispose().
func _exit_tree() -> void:
	player_clones.clear()
	if shops != null:
		shops.dispose()
		shops = null
		menus.clear()
	if enemies != null:
		enemies.shutdown()
	if combat != null:
		combat.enemies = null
		combat.flail = null
	if world != null:
		world.dispose()


## Called by main.tscn once the scene tree exists.
func boot(scene_root: Node3D) -> void:
	root3d = scene_root
	camera = Camera3D.new()
	camera.name = "GameCamera"
	camera.near = 0.1
	camera.far = 2000.0
	camera.fov = Config.fov
	root3d.add_child(camera)
	view = View.new()
	view.name = "View"
	root3d.add_child(view)
	view.setup(camera)
	ui_root = CanvasLayer.new()
	ui_root.name = "UI"
	root3d.add_child(ui_root)
	sfx = Sfx.new()
	add_child(sfx)
	night_vision = NightVision.new()
	add_child(night_vision)
	power_store = PowerStore.new()
	power_store.load_save()
	vehicles = Vehicles.new()
	vehicles.name = "Vehicles"
	add_child(vehicles)
	fx = FX.new()
	root3d.add_child(fx)
	var id := DEFAULT_LEVEL
	var direct := false     # --level=: straight into the level, no opening and no menu, so tests stay fast (JS ?level=x&nointro&autostart); its saves stay in memory
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--level="):
			id = a.substr(8)
			direct = true
		elif a.begins_with("--char=") and Builds.BUILDS.has(a.substr(7)):
			char_pick = a.substr(7)
	save = SaveGame.new(not direct)
	use_save_record()
	started = false
	ui = GameUi.new()
	ui_root.add_child(ui)
	hud = ui.hud
	wheel = ui.wheel
	if direct:
		await enter_level(id)
		set_process(true)
		ui.start(true)
	else:
		ui.boot_show()
		ui.boot_step("Loading level", 0.3)
		await get_tree().process_frame
		await get_tree().process_frame
		await enter_level(id)
		await ui.warm_up()
		ui.boot_step("Ready", 1.0)
		set_process(true)
		ui.boot_hide()
		ui.play_intro()


## The slot in use changed (or the game just booted): what is built from its record reads it again.
func use_save_record() -> void:
	save_data = save.data
	money = int(save.data.money)
	ArmorStore.load_save()
	if power_store != null:
		power_store.load_save()


## Swap the current level for another. spawn_at names a spot the level knows ("" = its default).
func enter_level(id: String, spawn_at: String = "") -> void:
	if power != null:
		power.on_level_change()
	_entering = true        # the frame holds until the new world can answer queries: nothing runs against a World that was just disposed
	leave_level()
	if not LEVELS.has(id):
		push_error("no level '%s'" % id)
		id = DEFAULT_LEVEL
	var scr: GDScript = load(LEVELS[id])
	level = scr.new()
	level.name = "Level_" + id
	level.id = id
	root3d.add_child(level)
	world = World.new(root3d.get_world_3d().space)
	level.world = world
	view.reset_render_state()       # the look of a fresh View: every level starts from it (JS BASE_LOOK.restore)
	level.build()
	view.level_built(level)         # its grade, glow and mist (core/looks.gd; a level's own `look` wins)
	ForgeLayer.attach(level)        # what the editor placed here (assets/levels/<id>/edits.json): part of the level, built with it
	# colliders join the physics broadphase on the next physics step
	await get_tree().physics_frame
	await get_tree().physics_frame
	if spawn_at != "":
		level.apply_spawn(spawn_at)
	if player == null:
		player = Player.new(world)
		rig = CameraRig.new(world)
		combat = Combat.new(world)
		vehicles.bind_combat(combat)
		enemies = combat.enemies
		enemies.on_reinforce = _on_reinforce
		enemies.spawn_hook = spawn_enemy          # the meatball prophet summons followers through these
		enemies.on_reap = despawn_enemy
		ArmorStore.load_save()
		power_store.load_save()
		power = Power.new()
		add_child(power)
		implant_cs = ImplantInject.new()
		add_child(implant_cs)
		cutscenes[&"implant_cs"] = implant_cs
		cutscenes[&"firefight"] = Firefight.new()      # (a test cutscene of the hub: console "cutscene play firefight")
		add_child(cutscenes[&"firefight"])
		cutscenes[&"frug_showdown"] = FrugShowdown.new()      # (a test cutscene of OMNISPHERE: console "cutscene play frug-showdown")
		add_child(cutscenes[&"frug_showdown"])
		cutscenes[&"tommy_ascension"] = TommyAscension.new()      # (a test cutscene, any level: console "cutscene play tommy-ascension")
		add_child(cutscenes[&"tommy_ascension"])
		take_shared_snapshots()
	else:
		player.world = world
		rig.world = world
		combat.reset_for_level(world)
	enemy_views.setup(enemies)
	combat.apply_loadout(id, level)
	if fx != null:
		enemy_views.link(fx)
		fx.setup(combat)
	player.reset()
	if animator == null:
		spawn_character(char_pick)
	else:
		Config.cam_height = animator.B.cam_height     # (restore_defaults put the shipped value back: the character's own orbit height stays)
		sync_armor()
	rig.snap_to(player)
	cur_spawn_at = spawn_at
	doors.enter_level(level)
	level.on_enter()
	_entering = false
	if started:
		level.start_music()
		save_game(true)      # autosave on arrival (through a door): this level is where CONTINUE goes


## Make `id` the playable character (JS spawnCharacter). Always from a fresh instance of the model: a new Animator takes the skeleton's pose as its rest.
func spawn_character(id: String) -> void:
	var B := Builds.character_build(id)
	if animator != null:
		animator.actor.queue_free()
	char_pick = id
	Config.cam_height = B.cam_height
	animator = Animator.create(B)
	root3d.add_child(animator.actor)
	animator.update(0.016, player)
	rig.snap_to(player)
	sync_armor()
	if not animator.missing.is_empty():
		push_warning("bones not found: %s" % [animator.missing])


## JS syncArmor: dress the character in the suit the armor store says he wears.
func sync_armor(_id: String = "") -> void:
	if animator != null:
		PhantomSuit.wear_suit_by_id(animator, ArmorStore.equipped_id())


func leave_level() -> void:
	if forge != null:
		forge.level_left()      # (out of EDIT, and unsaved edits written, while the level still exists)
	save_game()
	if vehicles != null and vehicles.driving:      # JS enterLevel: nobody drives across a level change
		vehicles.exit(true)
	player_clones.clear()
	# JS resetCombatForLevel: `for (const r of robots) despawnEnemy(r)` comes first. The views go with their robots, or the old level's enemies stay on screen in the new one as frozen ghosts that nothing can hit.
	if dialogue.on:
		dialogue.end_dialogue()
	dialogue.clear_level()
	doors.clear_level()
	enemy_views.clear_level()
	if enemies != null:
		enemies.robots.clear()
	if fx != null:
		fx.clear_level()
	if sfx != null:
		sfx.clear_level()
	if level != null:
		level.on_exit()
		level.queue_free()
		level = null
	if world != null:
		world.dispose()
		world = null
	Config.restore_defaults()
	if rig != null:      # a level's set-piece pull-out (the Mawmother's, the Warden's, the Foreman's) ends with the level: only that level's own update ever lets go of it
		rig.pull_t = 0.0
		rig.pull_w = 0.0
		rig.pull_eff = 0.0
		rig.pull_dist = 0.0
		rig.pull_fov = 0.0
		rig.pull_lock = false
		rig.fov_add = 0.0
	restore_shared()


## JS takeSharedSnapshots: the shared objects as they are before any level has run. A level's patches on them (its hooks on Combat and Enemies, what it set on the
## player) are undone by restore_shared when it is left, so a level left half way (a door, the level list, a death in a set piece) leaves nothing behind.
func take_shared_snapshots() -> void:
	if not _shared.is_empty():
		return
	_shared = {"enemies": _hooks_of(enemies), "combat": _hooks_of(combat), "player": _plain_of(player), "orbit": Inp.orbit_btn, "capture_blocked": Inp.capture_blocked}


const SHARED_SKIP: Array[String] = ["armed", "weapon", "world"]     # read-only properties (a getter over other state), never written back

## JS isFn: the fields of a shared object a level may patch: its Callable hooks, and what starts out off (null, false).
static func _hooks_of(o: Object) -> Dictionary:
	var d := {}
	for p: Dictionary in o.get_property_list():
		if not (int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) or SHARED_SKIP.has(String(p.name)):
			continue
		var v: Variant = o.get(p.name)
		if v is Callable or v == null or v is bool:
			d[p.name] = v
	return d


## JS isPlain: primitives and functions, never the arrays / vectors a running game keeps in place.
static func _plain_of(o: Object) -> Dictionary:
	var d := {}
	for p: Dictionary in o.get_property_list():
		if not (int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) or SHARED_SKIP.has(String(p.name)):
			continue
		var v: Variant = o.get(p.name)
		if v == null or v is bool or v is int or v is float or v is String or v is StringName or v is Callable:
			d[p.name] = v
	return d


## JS restoreShared: the shared objects as they were before any level ran (a level's patches undone, the player as on a fresh page). The console's god mode is the
## player's own toggle, not a level patch, so it stays. Beyond the JS list: the animator's pose hook, the HUD's reticle switch, the frame's own level flags, because
## here those are fields a level writes where the JS had scoped patches that died with the level.
func restore_shared() -> void:
	if _shared.is_empty():
		return
	for k: String in _shared.enemies:
		enemies.set(k, _shared.enemies[k])
	for k: String in _shared.combat:
		combat.set(k, _shared.combat[k])
	var god: bool = player.god
	for k: String in _shared.player:
		player.set(k, _shared.player[k])
	player.god = god
	if animator != null:
		Config.cam_height = animator.B.cam_height     # the character being played, not the one at boot
		player.h = Config.height
		animator.pose_hook = Callable()
	Inp.orbit_btn = _shared.orbit
	Inp.capture_blocked = _shared.capture_blocked
	if hud != null:
		hud.hide_xhair = false
	input_dead = false
	time_scale = 1.0
	arena_blocked = false
	overlay = null


## the level's own sound beds, which a cutscene that brings its own score mutes (JS: sfx.master swapped)
func level_beds() -> Array[StringName]:
	return [&"OmOut", &"OmMusic", &"OmPA"]


## the story cutscene running now (View.CUTSCENE_ORDER), or null
func cutscene_on() -> Variant:
	for k: StringName in cutscenes:
		var cs: Variant = cutscenes[k]
		if cs != null and cs.on:
			return cs
	return null


## JS menuOpen(), the part that holds the world still: a shop, a terminal, a level's modal.
func menu_open() -> bool:
	if overlay != null:
		return true
	for m: Variant in menus:
		if m.is_open:
			return true
	if cutscene_on() != null:
		return true
	if dialogue.on or doors.travelling:
		return true
	return level != null and level.has_method(&"modal") and level.call(&"modal")


## Spawn one hostile robot at a spawn point: pt { x, y, z, yaw }, o { drone, ax, az, no_respawn } (JS spawnEnemy). The other enemy kinds join here as they are ported: `kind` picks their class and view.
func spawn_enemy(pt: Dictionary, o: Dictionary = {}) -> Robot:
	var is_drone: bool = o.get("drone", false)
	var patrol_o := {"ax": o.get("ax", 0.0), "az": o.get("az", 0.0), "owner": o.get("owner"), "spawn": o}
	var kind: String = o.get("kind", "")
	var rb: Robot
	if is_drone:
		rb = Drone.new(world, _next_enemy_id, pt.x, pt.z, pt.y, patrol_o)
	elif _kind_script(kind) != null:
		rb = _kind_script(kind).new(world, _next_enemy_id, pt.x, pt.z, pt.y, patrol_o)
	else:
		if kind != "":
			push_warning("enemy kind '%s' is not ported yet: a robot stands in" % kind)
		rb = Robot.new(world, _next_enemy_id, pt.x, pt.z, pt.y, patrol_o)
	_next_enemy_id += 1
	rb.yaw = pt.get("yaw", 0.0)
	if o.get("no_respawn", false):                # { no_respawn: true } = once killed it stays dead (dev console / DEV level spawns)
		rb.no_respawn = true
	enemies.add(rb)
	combat.targets.append(rb)
	enemy_views.add_for(rb)
	return rb


## The console asks before it spawns a kind.
func can_spawn_kind(kind: String) -> bool:
	return _kind_script(kind) != null


## JS spawnEnemy's kinds that are ported: anything else is a robot stand-in, with a warning.
func _kind_script(kind: String) -> GDScript:
	match kind:
		"alien":
			return GrayAlien
		"tommygun":
			return TommyGunGray
		"buttonman":
			return ButtonMan
		"butler":
			return ProbeButler
		"consigliere":
			return Consigliere
		"brute":
			return GristleBrute
		"crawler":
			return SinewCrawler
		"spore":
			return BlisterBloat
		"tongue":
			return WallWretch
		"mimic":
			return MawLedge
		"warden":
			return MarrowWarden
		"dervish":
			return BriarDervish
		"taken":
			return Taken
		"tethered":
			return Tethered
		"goon":
			return FointGoon
		"wh_robot":
			return WhActors.Bot
		"wh_spider":
			return WhActors.Spider
		"wh_drone":
			return WhActors.Flyer
		"spider":
			return MaintenanceSpider
		"prophet":
			return Prophet
		"follower":
			return Follower
		"scream":
			return MawNest
		"muscle":
			return Muscle
		"assassin":
			return NightAssassin
		"worm":
			return Phoniworm
	return null


## JS despawnEnemy
func despawn_enemy(rb: Robot) -> void:
	enemies.robots.erase(rb)
	combat.targets.erase(rb)
	enemy_views.remove_for(rb)


## Gun Drone reinforcements: 2 ground robots appear 13 - 22 m from the player on level ground (never inside walls, never over the moat) and go straight for him
func _on_reinforce(_src: Robot) -> Array:
	# JS: `if (WH || GN) return []`: finite warehouse waves own every reinforcement, including drones; the same holds for the blockout-kit levels. Those levels set this hook to null when they are ported.
	var P := player
	var out: Array = []
	var made := 0
	for i in 40:
		if made >= Drone.DRONE.call_count:
			break
		var a := randf() * 6.2832
		var d := 13.0 + randf() * 9.0
		var x := P.x + sin(a) * d
		var z := P.z + cos(a) * d
		if level.id == "foint-dome" and U.hyp(x, z) > 38.0:
			continue
		var g := world.ground_height(x, z, AI.r, P.y + 1.5)
		if not (g > -INF) or absf(g - P.y) > 2.5:
			continue
		if world.blocked(x, z, g, AI.h, AI.r, AI.step):
			continue
		var crowded := false
		for r in enemies.robots:
			if not r.dead and not r.drone and U.hyp(r.x - x, r.z - z) < 1.5:
				crowded = true
				break
		if crowded:
			continue
		var rb := spawn_enemy({"x": x, "y": g, "z": z, "yaw": atan2(P.x - x, P.z - z)})
		rb.reinf = true
		rb._know(P.x, P.z)
		rb.seen_t = 0.0
		rb.alert_why = "called"
		rb.set_(&"alert")
		out.append_array([x, g, z])
		made += 1
	return out


## JS STORY: a flag in the save record, for what has happened in the story so far.
func story_get(k: String) -> bool:
	return (save_data.get("story", {}) as Dictionary).get(k, false)


func story_set(k: String) -> void:
	if not save_data.has("story"):
		save_data["story"] = {}
	save_data["story"][k] = true
	if save != null:
		save.write()


## JS addMoney: spend or earn (the HUD shows Game.money).
func add_money(n: float) -> void:
	money = maxi(0, int(money + n))
	if hud != null:
		hud.money_gain(n)
	save_game()


## JS saveGame: money, the wheel (when it is the player's own), where to CONTINUE from (while playing), then write the slot. milestone: flash the save icon (checkpoints, doors, purchases).
func save_game(milestone: bool = false) -> void:
	save_data.money = money
	if combat != null and combat.gear_live:
		save_data.gear = combat.gear_snapshot()
	if save == null:
		return
	if started and level != null and not GameUi.SANDBOX_LEVELS.has(level.id):
		save_data.where = {"level": level.id, "spawn_at": cur_spawn_at, "cp": null}
	if save.write() and milestone and hud != null:
		hud.save_icon()


## Kills pay (JS frame: the hub's cherub, tid CHERUB_ID, goes with the hub). In the dev level and the arena they are their own reward.
func _kill_money() -> void:
	for e: Dictionary in combat.events:
		if e.t != "kill" or e.get("crowd", false) or int(e.get("tid", -1)) == HubLevel.CHERUB_ID:
			continue
		var npc: bool = e.get("npc", false)
		if level.id == "dev" or level.id == "foint-dome":
			if npc and hud != null:
				hud.toast("NPC DOWN")
			continue
		var gain := 350 if npc else 25
		add_money(gain)
		if npc and hud != null:
			hud.toast("SHOPKEEPER DOWN  +$%d" % gain)


## JS playerLife: he lies where he fell, the screen fades, then he reboots at the spawn with brief invulnerability (the arena runs its own).
func _player_life() -> void:
	if level.id != "foint-dome" and player.dead and player.dead_t > 5.6:
		player.respawn()
		rig.snap_to(player)
		if combat.enemies != null:
			combat.enemies.player_respawned()
		if hud != null:
			hud.dead(false)
			hud.toast("REBOOTED", 1.2)


## JS cityAmbience.update in frame(). The hub's own roofs and doors are in the JS's numbers.
func _city_sound(real_dt: float) -> void:
	if city_ambience == null:
		city_ambience = CityAmbience.new()
		city_ambience.name = "CityAmbience"
		city_ambience.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(city_ambience)
	var on_street: bool = level.city_ambience
	var in_hub: bool = level.id == "hub"
	var p := player
	var in_shop := in_hub and p.x > 8.0 and p.x < 21.0 and p.z > 4.0 and p.z < 18.0 and p.y < 4.1
	var in_apt := in_hub and p.x < -7.6 and p.x > -18.2 and p.z > 6.0 and p.z < 23.9 and p.y > 3.4 and p.y < 6.6
	city_ambience.storm = level.storm
	city_ambience.update(real_dt, on_street and started and not paused, menu_open() or wheel.is_open, in_shop or in_apt, in_shop, U.hyp(p.x + 7.0, p.z + 36.6) if in_hub else INF)
	# the gunshop CRT keeps running (and glitching) on the real clock; its video holds while the game is frozen
	var tv: Variant = level.get(&"shop_tv")
	var tv_playing := false
	if tv != null:
		var listen := Vector3(sfx.listener_x, sfx.listener_y, sfx.listener_z)
		var tp: Vector3 = tv.global_position
		if tv.playing or U.hyp(p.x - tp.x, p.z - tp.z) < 30.0:      # the card / glitches only animate when you are near enough to see them
			tv.update(real_dt, listen)
		tv.set_paused(not started or paused or menu_open() or wheel.is_open)
		tv_playing = tv.playing
	city_ambience.tv_duck = tv_playing      # the shop music drops right down under the TV
	shops.vending_audio(frame_dt, started and not paused and not menu_open())      # only nearby machines run audio


## The frame. Same order as frame() in the three.js index.html.
func _process(delta: float) -> void:
	var real_dt := minf(0.05, maxf(0.0001, delta))
	var dt := real_dt * time_scale
	frame_dt = dt
	frame_real_dt = real_dt
	time += dt
	Inp.step(dt)
	Inp._guard_apply()
	if world == null or level == null or player == null or not started or _entering:
		ui.frame_begin(dt)
		if not started and player != null:
			view.apply_camera(real_dt)
		ui.frame_end(dt)
		return
	# F4 copies "[x, y, z]" in every level. It was only in the kit's (blockout) update, so the hub, exported levels and anything with no stages did nothing.
	if Inp.key_hit(KEY_F4) and not Inp.text_capture:
		var ps := "[%.1f, %.1f, %.1f]" % [player.x, player.y, player.z]
		DisplayServer.clipboard_set(ps)
		if hud != null:
			hud.toast("POSITION " + ps, 2.2)
	var sdt := dt       # 0 while a menu or the wheel freezes the simulation
	if sfx != null and not paused:
		sfx.enemy_audio.update(dt, player, not menu_open() and not wheel.is_open and not arena_blocked)
	level.tick(0.0 if (paused or wheel.is_open or menu_open()) else dt)
	_city_sound(real_dt)
	ui.frame_begin(dt)
	if paused:
		if sfx != null:
			sfx.enemy_audio.stop()
		night_vision.update(0.0, false)
		ui.frame_end(dt)
		view.apply_camera(real_dt)
		return
	# ---- weapon wheel: hold Y / Q; the game is frozen while it is open ----
	for m: Variant in menus:
		if m.is_open:
			m.update(dt)
	var lv_cine: Variant = level.get(&"cine")
	var cine: bool = lv_cine != null and lv_cine.on                  # a level cutscene that runs in the live world: the level moves the player, the rig gets no input
	var play_cine: bool = cine and lv_cine.get(&"play") == true      # a playable one (OMNISPHERE's freefall): the level still moves the body and the camera, but the weapons answer the player
	if not arena_blocked and not wheel.is_open and not menu_open() and (not cine or play_cine) and Inp.btn(&"quick").pressed and not player.punching:
		wheel.open(combat)
	if wheel.is_open:
		sdt = 0.0
		wheel.update(dt, combat)
		if (ui.wheel_discard or (Inp.using_pad and Inp.btn(&"attack").pressed)) and wheel.mode == "wheel":
			ui.discard_selected()                 # X: drop the highlighted weapon
		if wheel.pip and Inp.btn(&"b").pressed:
			wheel.toggle_inv(combat)              # E / B: press the terminal's button -> inventory page <-> weapon wheel
		var cancel: bool = not wheel.pip and Inp.btn(&"b").pressed      # (without the terminal art E still cancels the wheel)
		var release: bool = not Inp.btn(&"quick").held
		if release or cancel:
			var c: Variant = wheel.choice(combat)
			var inv: bool = wheel.mode != "wheel"
			wheel.close()
			if not cancel and not inv and c != null:      # letting go on the inventory page closes it without changing weapon
				combat.equip(c)
	else:
		if not arena_blocked and not menu_open() and (not cine or play_cine):
			if Inp.btn(&"d_left").pressed:
				ui.cycle_weapon(-1)
			elif Inp.btn(&"d_right").pressed:
				ui.cycle_weapon(1)
		if not menu_open() and (not cine or play_cine) and not player.dead and Inp.btn(&"nvg").pressed:      # (user, 2026-11-07: a level cutscene that holds the player, the closet's menu above all, keeps the d-pad to itself. The JS toggled here too.)
			night_vision.toggle()      # N / d-pad down: night vision goggles on / off
		if not arena_blocked and not menu_open() and not cine and Inp.btn(&"power").pressed and power != null:
			power.toggle()      # Z / d-pad up: power mode on / off
		# weapons on the ground: the closest one in reach gets the prompt, X picks it up (the press is eaten so the pad's X does not also reload)
		combat.drop_focus = combat.near_drop(player) if (not menu_open() and not player.dead) else null
		if combat.drop_focus != null and (ui.drop_req or (Inp.using_pad and Inp.btn(&"attack").pressed)):
			Inp.btn(&"attack").pressed = false
			ui.pick_up_drop(combat.drop_focus)
		# X: skip a line, or use what is in reach
		var x_hit: bool = ui.dlg_req or (Inp.using_pad and Inp.btn(&"attack").pressed)
		if dialogue.on:
			if x_hit:
				dialogue.req = true
				Inp.btn(&"attack").pressed = false
		elif cutscene_on() != null:
			if x_hit:      # X: skip the cutscene
				Inp.btn(&"attack").pressed = false
				cutscene_on().skip()
		elif x_hit and not menu_open() and shops.near_vendor() != null:
			# a shop wins over a weapon on the ground and anything else in reach
			Inp.btn(&"attack").pressed = false
			ui.dlg_req = false
			shops.near_vendor().open()
		elif x_hit and not menu_open() and combat.drop_focus == null:
			var it := doors.near_interact()
			if not it.is_empty():
				Inp.btn(&"attack").pressed = false
				doors.use(it)
	ui.wheel_discard = false
	ui.drop_req = false
	ui.dlg_req = false
	if dialogue.on:
		dialogue.tick(dt)
	for k: StringName in cutscenes:
		var cs: Variant = cutscenes[k]
		if cs != null and cs.on:
			cs.update(dt)
	if menu_open() or arena_blocked or (freecam != null and freecam.on):
		sdt = 0.0
	if sdt > 0.0:
		var driving: bool = vehicles != null and vehicles.driving   # in a vehicle the car is the body: no walking, no weapon input
		drunk.tick(sdt)      # (before the player: a stumble goes into the stick; going down holds the controls)
		var stunned := player.stun_t > 0.0 and not player.dead      # the night assassin's knife: no moving, jumping, shooting or powers (the camera still looks around)
		var cine_held := cine and not play_cine      # JS (CINE && !PLAYCINE): a level cutscene has the player: no buttons reach him
		combat.update(sdt, player, rig, driving or input_dead or stunned or cine_held or level.no_fight)
		if not cine:      # JS (!CINE): a level cutscene moves the body itself
			player.update(sdt, rig.yaw, player.dead or player.stun_t > 0.0)
			if level.has_method(&"after_player"):      # (KAME LAB: JS P.update's wrapper)
				level.call(&"after_player", sdt)
		# stun_t re-read: a stun landed during combat.update counts from this frame
		player_clones.update(sdt)
		if vehicles != null:
			vehicles.update(sdt)
		if sfx != null and not driving:
			sfx.update_player_footsteps(sdt, player)
		rig.update(sdt, player)
		if vehicles != null:
			vehicles.camera_adjust(sdt)
		if player.crawl_active:
			rig.crawl_view(player)
		combat.scope_w = rig.scope_w
		_kill_money()
		level.combat_events(combat.events)      # JS: for (e of combat.events) crowd.onEvent(e, player)
		if animator != null:
			animator.actor.visible = rig.scope_w < 0.75 and (vehicles == null or not vehicles.driving or vehicles.seated) and not rig.too_close     # through the scope the camera is at his eye: hide the body / gun
			animator.update(sdt, player)
			if level.has_method(&"after_animator"):      # (KAME LAB: JS an.update's wrapper)
				level.call(&"after_animator", animator, sdt)
			if lv_cine != null and lv_cine.on and lv_cine.has_method(&"pose_player"):
				lv_cine.pose_player(animator)      # a level cutscene that poses the body itself (the Mawmother's entrance)
			animator.death_pose(player)
			drunk.pose(animator, player)
		if power != null:
			power.tick(sdt, not (driving or cine_held or cine or player.stun_t > 0.0), driving)
		_player_life()
		var pev: Array[StringName] = player.events.duplicate()
		player.events.clear()
		if fx != null:
			enemy_views.link(fx)
			fx.handle(combat.events, pev)
			fx.update(sdt)
		else:
			enemy_views.tick(sdt, camera.global_position)
			combat.events.clear()
		enemy_views.flush()      # the robots were posed in fx.update: upload their batches
	FlashLights.push(get_tree(), camera.global_position)      # this frame's flashes, for the painted world (every frame: a paused flash stays lit)
	night_vision.update(dt if (not wheel.is_open and not menu_open()) else 0.0, not menu_open())      # after the body is posed, before the frame renders
	if power != null and (not started or paused or wheel.is_open or menu_open()):
		power.quiet()      # frozen powers go quiet
	ui.frame_end(dt)
	view.apply_camera(real_dt)
