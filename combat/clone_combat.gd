class_name CloneCombat
extends RefCounted
## A real Combat instance per AI clone (JS clone-combat.js): only population and inventory ownership differ. Its brain picks a robot, moves, aims, shoots, reloads, dodges; the opponents and orders of a Blood Gulch team match do not exist here (that level was dropped), so the opponents are always the game's targets.


## JS class CloneCombat extends Combat
class CloneRules:
	extends Combat
	var owner_state: Player = null
	var is_clone := true

	func _build_range() -> void:      # No duplicate enemies, NPCs or pickups.
		pass

	func damage(T: Target, amount: float, from: Variant, kb: float = 0.0, pt: Variant = null, melee: bool = false) -> Variant:
		var main: Combat = Game.combat
		if T.actor_state != null and main.actor_damage.is_valid():
			return main.actor_damage.call(T, amount, from, owner_state)
		var enemy_manager: Enemies = main.enemies
		var previous: Player = enemy_manager.P
		var first_event := main.events.size()
		enemy_manager.P = owner_state
		var result: Variant = main.damage(T, amount, from, kb, pt, melee)
		for i in range(first_event, main.events.size()):
			main.events[i]["clone_id"] = owner_state.clone_id
		enemy_manager.P = previous
		return result


## JS c.enemies = { update() {}, bolts: getCombat().enemies.bolts }
class NoEnemies:
	extends Enemies

	func update(_dt: float, _player: Player) -> void:
		pass


class Brain:
	var time := 0.0
	var enemy: Target = null
	var memory := 0.0
	var fire_at := 0.0
	var dodge_at := 0.0
	var scan := 0.0


## what think() wants this frame
class Intent:
	var target: Variant = null
	var stop_distance := 2.0
	var heading := 0.0
	var mx := 0.0
	var my := 0.0
	var mag := 0.0
	var buttons: Array[StringName] = []


static var _saved: Weapons.Live = null


## JS scoped(clone, fn): the weapon models share one live state: it reads as this clone's while fn runs, then goes back
static func _scope_in(clone: PlayerClones.Clone) -> void:
	if _saved == null:
		_saved = Weapons.Live.new()
	var N := Weapons.NEWW
	var s := _saved
	s.charge = N.charge
	s.ammo = N.ammo
	s.t = N.t
	s.arc = N.arc
	s.mag = N.mag
	s.reserve = N.reserve
	s.o = N.o
	s.o2 = N.o2
	s.o3 = N.o3
	var c := clone.combat
	N.charge = c.yoke.charge if c.yoke.holding else 0.0
	N.arc = 1.0 if c.arc.on else 0.0
	N.ammo = c.ammo[c.cur] if c.cur >= 0 else 0.0


static func _scope_out() -> void:
	var N := Weapons.NEWW
	var s := _saved
	N.charge = s.charge
	N.ammo = s.ammo
	N.t = s.t
	N.arc = s.arc
	N.mag = s.mag
	N.reserve = s.reserve
	N.o = s.o
	N.o2 = s.o2
	N.o3 = s.o3


## a weapon's index from its id or number, -1 if there is none
static func weapon_index(name: Variant) -> int:
	if name is int or name is float:
		var i := int(name)
		return i if i >= 0 and i < Weapons.WEAPONS.size() else -1
	for i in Weapons.WEAPONS.size():
		if Weapons.WEAPONS[i].id == str(name):
			return i
	return -1


## Returns what is wrong, or "" (the JS throws)
static func attach_clone(clone: PlayerClones.Clone, options: Dictionary) -> String:
	var wanted: Array = options.get("weapons", [options.get("weapon", "rifle")])
	var loadout: Array[int] = []
	for w: Variant in wanted:
		if str(w) == "fists":
			continue
		var i := weapon_index(w)
		if i < 0:
			return "Unknown clone weapon: " + str(w)
		loadout.append(i)
	var c := CloneRules.new(Game.world)
	clone.combat = c
	c.build = Builds.character_build(clone.character)
	c.owner_state = clone.state
	c._gid = clone.id * 1000000
	c.cur = -1
	c.slots.fill(null)
	c.owned.clear()
	c.ammo.fill(0.0)
	c.reserve.fill(0.0)
	if loadout.size() > c.slots.size():
		return "Clone loadout exceeds weapon-wheel capacity"
	var slot := 0
	for i: int in loadout:
		if c.owned.has(i):
			continue
		c.slots[slot] = i
		slot += 1
		c.owned[i] = true
		c.ammo[i] = Weapons.WEAPONS[i].mag_size
		c.reserve[i] = maxf(0.0, Weapons.WEAPONS[i].max - Weapons.WEAPONS[i].mag_size)
	if not loadout.is_empty():
		c.equip(loadout[0])
	var ne := NoEnemies.new(c)
	ne.bolts = Game.combat.enemies.bolts
	c.enemies = ne
	c.targets.clear()
	c.pickups.clear()
	c.events.clear()
	clone.brain = Brain.new()
	clone.brain.dodge_at = 1.0 + clone.id % 3
	clone.engage = options.get("engage", true) != false
	clone.state.team = options.get("team")
	clone.aim_rig = CameraRig.new(Game.world)
	_create_effects(clone)
	return ""


## JS clone.equip
static func equip(clone: PlayerClones.Clone, name: Variant) -> PlayerClones.Clone:
	var i := -1 if str(name) == "fists" else weapon_index(name)
	if i >= 0 and not clone.combat.owned.has(i):
		clone.owner.error = "Weapon is not in this clone loadout"
		return clone
	clone.combat.equip(i)
	return clone


static func _create_effects(clone: PlayerClones.Clone) -> void:
	if Game.fx == null:
		return
	var group := Node3D.new()
	group.name = "Clone combat effects %d" % clone.id
	Game.root3d.add_child(group)
	clone.effects_root = group
	clone.effects = Gadgets.new(Game.fx)
	group.add_child(clone.effects)


static func think(clone: PlayerClones.Clone, dt: float) -> Intent:
	var p := clone.state
	var c := clone.combat
	var brain := clone.brain
	brain.time += dt
	if not clone.engage:
		brain.enemy = null
		return null
	var enemy: Target = null
	var best := 85.0 if p.team else 32.0
	brain.scan -= dt
	brain.memory -= dt
	if not p.team or brain.scan <= 0.0:
		brain.scan = 0.22 + (clone.id % 4) * 0.025
		for e: Target in Game.combat.targets:
			if not e.robot or e.npc or e.dead or absf(e.y - p.y) > 9.0:
				continue
			var d := Vector2(e.x - p.x, e.z - p.z).length()
			if d < best and visible(p, e, c.build):
				enemy = e
				best = d
		if enemy != null:
			brain.enemy = enemy
			brain.memory = 1.5
	if brain.memory <= 0.0 or (brain.enemy != null and brain.enemy.dead):
		brain.enemy = null
	enemy = brain.enemy
	if enemy == null:
		return null
	var gap := Vector2(enemy.x - p.x, enemy.z - p.z).length()
	var heading := atan2(enemy.x - p.x, enemy.z - p.z)
	if p.team and c.rl == null:
		var preferred := "sniper" if gap > 27.0 else ("smg" if gap < 19.0 else "deagle")
		for i: int in c.owned:
			if Weapons.WEAPONS[i].id == preferred and c.ammo[i] + c.reserve[i] > 0.0:
				if i != c.cur:
					c.equip(i)
				break
	var w: Weapons.Def = c.weapon
	var melee := w == null
	var desired := 1.25 if melee else (6.0 if w.id == "shotgun" else (45.0 if w.id == "sniper" else (14.0 if w.proj else 12.0)))
	var forward := 0.85 if gap > desired + 1.5 else (-0.5 if gap < desired - 2.0 else 0.0)
	var side := 0.0 if melee else (0.42 if sin(brain.time * 0.9 + clone.id) > 0.0 else -0.42)
	var y := forward
	# Check the chosen strafe/retreat direction for a ledge before committing.
	var nx := p.x + sin(heading) * y - cos(heading) * side
	var nz := p.z + cos(heading) * y + sin(heading) * side
	var ground: float = p.world.ground_height(nx, nz, 0.3, p.y + 0.45)
	if not is_finite(ground) or ground < p.y - 1.3:
		side = 0.0
		y = 0.0
	var buttons: Array[StringName] = []
	if gap < 22.0:
		buttons.append(&"strafe")
	if w != null and c.ammo[c.cur] > 0.0 and c.rl == null and gap > 16.0 and not p.sprinting and p.grounded:
		buttons.append(&"ads")
	var aligned := absf(atan2(sin(heading - p.yaw), cos(heading - p.yaw))) < 0.25
	var reach := 2.0
	if not melee:
		var wr: float = w.range if w.range != 0.0 else 28.0
		reach = minf(wr, (85.0 if w.id == "sniper" else (40.0 if w.id == "deagle" else 26.0)) if p.team else 28.0)
	var can_shoot := visible(p, enemy, c.build) and aligned and gap < reach
	if can_shoot and c.rl == null:
		if w != null and w.special == "yoke":
			if fmod(brain.time, 1.4) < 1.05:
				buttons.append(&"fire")
		elif melee or w.mode != "auto":
			if brain.time >= brain.fire_at:
				buttons.append(&"fire")
				brain.fire_at = brain.time + (0.3 if melee else 1.0 / w.rate + 0.02)
		else:
			buttons.append(&"fire")
	if w != null and c.ammo[c.cur] == 0.0:
		if c.reserve[c.cur] > 0.0:
			buttons.append(&"reload")
		else:
			var next := -1
			for i: int in c.owned:
				if c.ammo[i] + c.reserve[i] > 0.0:
					next = i
					break
			c.equip(next)
	var es: Variant = enemy.get(&"state")
	var threatened: bool = (enemy.actor_state != null and enemy.actor_state.aiming) or es == &"attack" or es == &"windup"
	if not threatened:
		for q: Variant in Game.combat.enemies.bolts:
			if Vector2(q.x - p.x, q.z - p.z).length() < 3.0:
				threatened = true
				break
	if p.grounded and brain.time >= brain.dodge_at and threatened:
		buttons.append(&"jump")
		clone.press(&"jump", 0.16)
		brain.dodge_at = brain.time + 2.5
	elif not p.grounded and p.air_jump and p.vy < 1.0 and threatened and not clone.input.btns[&"jump"].held:
		buttons.append(&"jump")
	if melee and p.last_jump == &"double" and not p.grounded and gap < 2.5:
		buttons.append(&"attack")
	var it := Intent.new()
	it.target = enemy
	it.heading = heading
	it.mx = side
	it.my = y
	it.mag = minf(1.0, Vector2(side, y).length())
	it.buttons = buttons
	return it


static func visible(p: Player, enemy: Target, build: Builds.Build) -> bool:
	var y := p.y + build.muz_y
	var dx := enemy.x - p.x
	var dy := enemy.y + enemy.h * 0.6 - y
	var dz := enemy.z - p.z
	var d := Vector3(dx, dy, dz).length()
	return d < 0.01 or p.world.ray_clear(p.x, y, p.z, dx / d, dy / d, dz / d, d, 0.05) >= d - 0.2


static func step_actions(clone: PlayerClones.Clone, dt: float) -> void:
	var p := clone.state
	var c := clone.combat
	var camera := clone.aim_rig
	var target := clone.brain.enemy
	if p.dead:
		c._arc_off()
		c.yoke.holding = false
		c.saw_guide = null
		c.projs.clear()
		c.saws.clear()
		c.rocks.clear()
		c.wells.clear()
	c.targets.clear()
	for e: Target in Game.combat.targets:
		if e.robot and not e.npc:
			c.targets.append(e)
	camera.pos = Vector3(p.x, p.y + c.build.muz_y, p.z)
	camera.yaw = clone.heading
	camera.look = Vector3(target.x if target != null else p.x + sin(clone.heading) * 20.0, target.y + target.h * 0.6 if target != null else camera.pos.y, target.z if target != null else p.z + cos(clone.heading) * 20.0)
	_scope_in(clone)
	c.input_view = clone.input
	c.update(dt, p, camera)
	_scope_out()


static func animate_clone(clone: PlayerClones.Clone, dt: float) -> void:
	_scope_in(clone)
	clone.animator.update(dt, clone.state)
	_scope_out()
	clone.animator.actor.rotation.z = -minf(1.0, clone.state.dead_t / 0.7) * PI / 2.0 if clone.state.dead else 0.0


## JS renderEvents: this clone's shots, reloads and footfalls through the one FX, with the sound coming from him (JS clone.spatialSfx), no HUD and no camera shake
static func after_step(clone: PlayerClones.Clone, dt: float) -> void:
	var fx: FX = Game.fx
	if fx == null:
		clone.combat.events.clear()
		return
	_scope_in(clone)
	var shake := fx.shake
	var gadget: Gadgets = fx.gad
	fx.gad = clone.effects
	fx.scope_wv = clone.animator.wv
	Game.sfx.play_from = clone.state
	fx.handle(clone.combat.events, clone.state.events, clone)
	clone.effects.update_gadgets(dt, clone.combat, Game.camera, clone.state)
	Game.sfx.play_from = null
	fx.scope_wv = null
	fx.shake = shake
	fx.gad = gadget
	_scope_out()


static func on_remove(clone: PlayerClones.Clone) -> void:
	if clone.effects != null:
		clone.effects.clear()
	if clone.effects_root != null:
		clone.effects_root.queue_free()
	# (ENGINE DIFFERENCE: no garbage collector here: the rings of references a clone is built from are cut by hand, or they outlive it)
	var c := clone.combat
	var ne := c.enemies
	ne.barks = null
	ne.c = null
	c.enemies = null
	c.flail = null
	clone.input.sub.sub = null
	clone.input.sub = null
	clone.combat = null
	clone.owner = null


## Enemy targeting remains unchanged when no living clones are present.
static func nearest_combatant(enemy: Variant, player: Player, clones: Array, world: World) -> Player:
	var target := player
	var score: float = INF if player.dead else Vector2(enemy.x - player.x, enemy.z - player.z).length()
	for clone: PlayerClones.Clone in clones:
		var p := clone.state
		if p.dead:
			continue
		var d := Vector2(enemy.x - p.x, enemy.z - p.z).length()
		if d >= score or absf(p.y - enemy.y) > 8.0:
			continue
		var dy: float = p.y + p.h * 0.55 - (enemy.y + 1.2)
		var length: float = Vector3(p.x - enemy.x, dy, p.z - enemy.z).length()
		if length > 0.01 and world.ray_clear(enemy.x, enemy.y + 1.2, enemy.z, (p.x - enemy.x) / length, dy / length, (p.z - enemy.z) / length, length, 0.05) < length - 0.2:
			continue
		target = p
		score = d
	return target
