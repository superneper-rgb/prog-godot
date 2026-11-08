class_name PlayerClones
extends RefCounted
## AI allies built from the player rig (JS player-clones.js). AI supplies virtual controls; Player and Animator remain the authority for movement/poses. Their fighting is combat/clone_combat.gd.

const BUTTONS: Array[StringName] = [&"jump", &"crouch", &"strafe", &"l3", &"ads", &"attack", &"fire", &"reload"]


## JS createCloneInput: the virtual stick and buttons; `sub` is the view the later physics sub-steps get (same held state, no edges).
class CloneInput:
	extends Inp.InputView
	var sub: CloneInput = null
	var off := Inp.Btn.new()      # a button clones do not have (the keyboard's sprint)

	func _init() -> void:
		move = Inp.Stick.new()
		for n: StringName in PlayerClones.BUTTONS:
			btns[n] = Inp.Btn.new()

	func btn(n: StringName) -> Inp.Btn:
		return btns.get(n, off)


## The clone's Player. Player's existing out-of-world recovery returns this clone to its own home.
class ClonePlayer:
	extends Player
	var has_home := false
	var home_x := 0.0
	var home_y := 0.0
	var home_z := 0.0
	var home_yaw := 0.0
	var team: Variant = null      # (only a team match sets it: Blood Gulch's)

	func reset() -> void:
		super.reset()
		if has_home:
			x = home_x
			y = home_y
			z = home_z
			yaw = home_yaw


class Clone:
	var id := 0
	var character := ""
	var state: ClonePlayer
	var animator: Animator
	var input: CloneInput
	var mode := "follow"
	var target: Variant = null      # a Player, a Target, or a Vector2 (x, z)
	var patrol: Array[Vector2] = []
	var waypoint := 0
	var stop_distance := 2.0
	var jump_cooldown := 0.0
	var stuck := 0.0
	var detour := 0.0
	var action_state: Variant = null
	var heading := 0.0
	# (combat/clone_combat.gd attach_clone)
	var combat: CloneCombat.CloneRules = null
	var brain: CloneCombat.Brain = null
	var engage := true
	var aim_rig: CameraRig = null
	var effects: Gadgets = null
	var effects_root: Node3D = null
	var holds := {}
	var previous := {}
	var owner: PlayerClones = null

	func press(name: StringName, seconds: float = 0.14) -> Clone:
		if name not in PlayerClones.BUTTONS and name != &"slam":
			owner.error = "Unsupported clone action: " + name
			return self
		holds[name] = maxf(0.04, seconds)
		return self

	func equip(name: Variant) -> Clone:
		return CloneCombat.equip(self, name)

	func remove() -> bool:
		return owner.remove(id)


var clones := {}      # id -> Clone, in spawn order
var error := ""       # why the last spawn failed (the JS throws)
var _next_id := 1


static func _xz(o: Variant) -> Vector2:
	return o if o is Vector2 else Vector2(o.x, o.z)


func _fail(msg: String) -> Clone:
	error = msg
	return null


## options: character, mode (follow | patrol | idle), points (Array of Vector2), target, stop_distance, x, y, z, yaw, weapon, weapons, engage, team. Returns null with `error` set where the JS throws.
func spawn(options: Dictionary = {}) -> Clone:
	var world: World = Game.world
	var player: Player = Game.player
	var an: Animator = Game.animator
	var character: String = options.get("character", an.B.id if an != null else Game.char_pick)
	if not Builds.BUILDS.has(character):
		return _fail("Character is not loaded: " + character)
	var B := Builds.play_build(character)
	var mode: String = options.get("mode", "follow")
	if mode not in ["follow", "patrol", "idle"]:
		return _fail("Clone mode must be follow, patrol, or idle")
	var patrol: Array[Vector2] = []
	for p: Vector2 in options.get("points", []):
		patrol.append(p)
	if mode == "patrol" and patrol.is_empty():
		return _fail("Patrol needs at least one waypoint")
	var stop_dist := 2.0 if not options.has("stop_distance") else maxf(0.5, float(options.stop_distance))
	var found := false
	var loc := Vector3.ZERO
	var explicit := options.has("x") or options.has("z")
	if explicit and not (options.has("x") and options.has("z")):
		return _fail("Supply both x and z")
	for i in (1 if explicit else 16):
		var angle := player.yaw + PI + i * PI / 4.0
		var radius := 2.8 + floorf(i / 8.0) * 1.8
		var x: float = float(options.x) if explicit else player.x + sin(angle) * radius
		var z: float = float(options.z) if explicit else player.z + cos(angle) * radius
		var y: float = world.ground_height(x, z, Config.radius, player.y + 0.5) if not options.has("y") else float(options.y)
		if not is_finite(y) or world.blocked(x, z, y, Config.height, Config.radius, 0.02):
			continue
		var too_close := Vector2(x - player.x, z - player.z).length() < Config.radius * 2.0 + 0.2
		for c: Clone in clones.values():
			if Vector2(c.state.x - x, c.state.z - z).length() < Config.radius * 2.0 + 0.2:
				too_close = true
		if too_close:
			continue
		loc = Vector3(x, y, z)
		found = true
		break
	if not found:
		return _fail("No clear clone spawn location; choose another position")
	var state := ClonePlayer.new(world)
	var animation := Prog3Animator.create(B)
	state.x = loc.x
	state.y = loc.y
	state.z = loc.z
	state.yaw = player.yaw if not options.has("yaw") else float(options.yaw)
	state.grounded = false
	state.home_x = loc.x
	state.home_y = loc.y
	state.home_z = loc.z
	state.home_yaw = state.yaw
	state.has_home = true
	var input := CloneInput.new()
	input.sub = CloneInput.new()
	input.sub.move = input.move
	input.sub.sub = input.sub
	var clone := Clone.new()
	clone.id = _next_id
	_next_id += 1
	clone.character = character
	clone.state = state
	clone.animator = animation
	clone.input = input
	clone.mode = mode
	clone.target = options.get("target", player)
	clone.patrol = patrol
	clone.stop_distance = stop_dist
	clone.owner = self
	state.is_ai_clone = true
	state.clone_id = clone.id
	var why := CloneCombat.attach_clone(clone, options)
	if why != "":
		return _fail(why)
	animation.actor.name = "AI player clone %d" % clone.id
	Game.root3d.add_child(animation.actor)      # (before the first update: the animator reads world transforms)
	animation.update(0.0, state)
	clones[clone.id] = clone
	_hook_enemies()
	return clone


## JS combat.enemies.pickPlayerTarget / getCombatants, set for the whole session there. Here only while there are clones, so a level without them pays for no call per robot.
func _hook_enemies() -> void:
	var en: Enemies = Game.combat.enemies
	if clones.is_empty():
		en.pick_player_target = Callable()
		en.get_combatants = Callable()
		return
	en.pick_player_target = func(enemy: Variant, main_player: Player) -> Player: return CloneCombat.nearest_combatant(enemy, main_player, clones.values(), Game.world)
	en.get_combatants = func(main_player: Player) -> Array:
		var out: Array = [main_player]
		for c: Clone in clones.values():
			out.append(c.state)
		return out


func _tick(clone: Clone, dt: float) -> void:
	var state := clone.state
	var input := clone.input
	var world: World = state.world
	input.move.x = 0.0
	input.move.y = 0.0
	input.move.mag = 0.0
	var held := {}
	for name: StringName in clone.holds.keys():
		held[name] = true
		var remaining: float = clone.holds[name]
		if remaining <= dt:
			clone.holds.erase(name)
		else:
			clone.holds[name] = remaining - dt
	var heading := state.yaw
	var intent: CloneCombat.Intent = CloneCombat.think(clone, dt) if not state.dead else null
	var target: Variant = null
	if intent != null and intent.target != null:
		target = intent.target
	elif clone.mode == "patrol":
		target = clone.patrol[clone.waypoint]
	elif clone.mode == "follow":
		target = clone.target
	clone.jump_cooldown = maxf(0.0, clone.jump_cooldown - dt)
	clone.detour = maxf(0.0, clone.detour - dt)
	if not state.dead and target != null:
		var txz := _xz(target)
		var gap := Vector2(state.x - txz.x, state.z - txz.y).length()
		var stop := intent.stop_distance if intent != null else (0.65 if clone.mode == "patrol" else clone.stop_distance)
		if gap <= stop and clone.mode == "patrol":
			clone.waypoint = (clone.waypoint + 1) % clone.patrol.size()
		if gap > stop:
			heading = atan2(txz.x - state.x, txz.y - state.z)
			if clone.detour > 0.0:
				heading += 0.85 if clone.id % 2 else -0.85
			var ahead := 0.75
			var x := state.x + sin(heading) * ahead
			var z := state.z + cos(heading) * ahead
			var floor_y := world.ground_height(x, z, Config.radius, state.y + Config.step_up)
			var blocked := world.blocked(x, z, state.y, Config.height, Config.radius, Config.step_up)
			if is_finite(floor_y) and floor_y >= state.y - 1.3:
				input.move.mag = minf(1.0, (gap - stop) / 1.5)
				input.move.y = input.move.mag
				if gap > 9.0 and not state.sprinting:
					held[&"l3"] = true
				var crouch_clear := blocked and not world.blocked(x, z, state.y, Config.crouch_height, Config.radius, Config.step_up)
				if crouch_clear:
					held[&"crouch"] = true
				elif (blocked or clone.stuck > 0.65) and state.grounded and clone.jump_cooldown == 0.0:
					held[&"jump"] = true
					clone.holds[&"jump"] = 0.18
					clone.jump_cooldown = 1.2
					clone.detour = 0.8
					clone.stuck = 0.0
			else:
				var lx := state.x + sin(heading) * 2.8
				var lz := state.z + cos(heading) * 2.8
				var landing := world.ground_height(lx, lz, Config.radius, state.y + Config.step_up)
				if state.grounded and clone.jump_cooldown == 0.0 and is_finite(landing) and landing >= state.y - 0.6 and not world.blocked(lx, lz, landing, Config.height, Config.radius, Config.step_up):
					held[&"crouch"] = true
					held[&"jump"] = true
					clone.holds[&"jump"] = 0.18
					clone.jump_cooldown = 1.4
					input.move.mag = 1.0
					input.move.y = 1.0
				else:
					clone.detour = 0.8
	if intent != null:
		heading = intent.heading
		input.move.x = intent.mx
		input.move.y = intent.my
		input.move.mag = intent.mag
		for name: StringName in intent.buttons:
			held[name] = true
	var c := clone.combat
	if c != null and (c.rl != null or held.has(&"reload") or (c.weapon != null and c.ammo[c.cur] == 0.0)):
		held.erase(&"l3")
		state.sprinting = false
	if state.dead:
		held.clear()
		input.move.x = 0.0
		input.move.y = 0.0
		input.move.mag = 0.0
	for name: StringName in BUTTONS:
		var b: Inp.Btn = input.btns[name]
		var on := held.has(name)
		b.held = on
		b.pressed = on and not clone.previous.has(name)
		b.released = not on and clone.previous.has(name)
		b.value = 1.0 if on else 0.0
		var sb: Inp.Btn = input.sub.btns[name]
		sb.held = on
		sb.pressed = false
		sb.released = false
		sb.value = b.value
	clone.previous = held
	if held.has(&"slam"):
		state.slam_req = true
	clone.heading = heading
	CloneCombat.step_actions(clone, dt)
	var px := state.x
	var pz := state.z
	state.update_with(dt, input, input.sub, heading)
	clone.stuck = clone.stuck + dt if input.move.mag > 0.3 and Vector2(state.x - px, state.z - pz).length() < dt * 0.3 else 0.0
	CloneCombat.animate_clone(clone, dt)
	CloneCombat.after_step(clone, dt)
	state.events.clear()


func remove(id: int) -> bool:
	var clone: Clone = clones.get(id)
	if clone == null:
		return false
	CloneCombat.on_remove(clone)
	clone.animator.actor.queue_free()      # (the rig goes with its actor; meshes and materials are shared per model here, so nothing else to free)
	clones.erase(id)
	_hook_enemies()
	return true


func clear() -> void:
	for id: int in clones.keys():
		remove(id)


func list() -> Array:
	return clones.values()


func update(dt: float) -> void:
	if dt > 0.0:
		for c: Clone in clones.values():
			_tick(c, minf(dt, 0.05))


## JS cloneRenderCombat: what FX draws rockets from: the player's and every clone's
func render_projs(main: Array) -> Array:
	var out: Array = main.duplicate()
	for c: Clone in clones.values():
		out.append_array(c.combat.projs)
	return out
