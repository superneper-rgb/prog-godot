class_name Enemies
extends RefCounted
## The enemy population (JS class Enemies, index.html enemy.js): ticks every robot, hands out attack slots, broadcasts alerts, flies the bolts, keeps robots from stacking.
## Pure simulation. Combat owns the damage and the event list; views read the robots.
## Every event the robots push goes through push() into combat.events, as Dictionaries with `t` set to the snake_case name of the JS event.

## A bolt in flight (JS plain object in this.bolts). Pooled: a shot allocates nothing once the pool has grown.
class Bolt:
	var x := 0.0
	var y := 0.0
	var z := 0.0
	var dx := 0.0
	var dy := 0.0
	var dz := 0.0
	var speed := 0.0
	var life := 0.0
	var owner := 0
	var kind := "bolt"
	var dmg := 0.0
	var rad := 0.15
	var push := 0.0
	var slow_t := 0.0
	var slow_mul := 1.0

const AI_POISE_MAX := AI.poise_max           # Combat's gravity well reads this

var c: Combat
var robots: Array[Robot] = []
var bolts: Array[Bolt] = []
var t := 0.0
var P: Player = null
var barks: Barks
var gray_volley: Dictionary = {}          # grays take turns: whose burst it is, {id, until}
var creature_last_attack: Dictionary = {}  # creatures do not all start an attack on the same frame (enemies/creature_gameplay.gd)
var last: Dictionary = {}
var slot_free_hook: Callable                 # a level's own rule: (kind, who) -> bool, or null for the stock one (JS E.slotFree patched)
var fire_hook: Callable                      # (robot, x, y, z, dx, dy, dz, o) -> true when the level fired instead (JS E.fire patched)
var goon_fire: Dictionary = {}               # FOINT goons: who holds a shooting token, until when (JS goonFire)
var goon_aim_at := NAN                       # when the last goon started to aim
var goon_acid: FointGoon.AcidState = null    # acid in flight and on the floor
var goon_alarms: Callable                    # () -> [[x, z], ...]: a level's alarm panels
var on_goon_alarm: Callable                  # (goon): a level takes over what the alarm does
var reap: Array[Robot] = []                  # reap / on_reap / spawn_hook: the meatball prophet summons followers and cleans them up
var on_reap: Callable
var spawn_hook: Callable
var on_reinforce: Callable                   # Gun Drone reinforcements: (src) -> spawns ground robots, returns their positions flat [x, y, z, ...]
var pick_player_target: Callable             # (robot, player) -> who this robot hunts (a level with AI allies)
var get_combatants: Callable                 # (player) -> everyone a bolt can hit
var _just_p: Array = [null]
var _bolt_pool: Array[Bolt] = []

## JS this.world = combat.world, which there forwards to the current level's World.
var world: World:
	get:
		return Game.world


func _init(combat: Combat) -> void:
	c = combat
	barks = Barks.new(self)


func push(e: Dictionary) -> void:
	if P != null and P.is_ai_clone and not e.has("clone_id"):
		e["clone_id"] = P.clone_id
	c.events.append(e)


## JS add() also ran enhanceCreature(r, CONFIG), which is a no-op for the stock Robot and Drone: the creature kinds carry its wrappers in their own classes.
func add(r: Robot) -> Robot:
	r.E = self
	robots.append(r)
	return r


## JS resetCombatForLevel: every robot of the old level goes, with its bolts. (The views go with EnemyViews.setup.)
func clear_level(_W: World) -> void:
	robots.clear()
	reap.clear()
	_bolt_pool.append_array(bolts)
	bolts.clear()
	Game.enemy_views.clear_level()


## Quitting: lets go of everything that points back here (see Game._exit_tree).
func shutdown() -> void:
	robots.clear()
	reap.clear()
	barks = null
	c = null
	on_reap = Callable()
	spawn_hook = Callable()
	on_reinforce = Callable()


## Gun Drone reinforcements: on_reinforce(src) is set by the game (spawns ground robots, returns their positions flat [x, y, z, ...])
func reinforce_room() -> bool:
	if not on_reinforce.is_valid():
		return false
	var n := 0
	for r in robots:
		if not r.dead and r.reinf:
			n += 1
	return n < Drone.DRONE.alive_cap


func reinforce(src: Robot) -> Array:
	return on_reinforce.call(src) if on_reinforce.is_valid() else []


## how many robots hold an attack slot of this kind right now (melee / shot)
func slot_free(kind: StringName, who: Robot) -> bool:
	if slot_free_hook.is_valid():
		var v: Variant = slot_free_hook.call(kind, who)
		if v != null:
			return v
	var n := 0
	for r in robots:
		if r != who and not r.dead and r.slot == kind:
			n += 1
	return n < (Config.ai_melee_slots if kind == &"melee" else Config.ai_shot_slots)


## the alert event: living robots within Config.ai_alert_radius of the damaged one are alerted (once each, no chaining)
func broadcast(src: Robot, lethal: bool) -> void:
	var R := Config.ai_alert_radius
	var hit: Array[int] = []
	for o in robots:
		if o == src or o.dead or o.ally_cd > 0.0:
			continue
		if U.hyp(o.x - src.x, o.z - src.z) > R or absf(o.y - src.y) > 8.0:
			continue
		o.on_ally(src, P)
		hit.append(o.id)
	last = {"t": t, "src": src.id, "lethal": lethal, "r": R, "alerted": hit}
	push({"t": "ai_alert", "id": src.id, "x": src.x, "y": src.y, "z": src.z, "r": R, "lethal": lethal, "alerted": hit})


## o (optional): { kind: "plasma" | "mind", speed, dmg, r (hit radius), push (m/s shove on hit), slow_t, slow_mul } -- the stock robot bolt passes nothing
## A shot with no robot behind it (the Foreman's rivets: JS fire({id: 97000}, ...))
func fire_from(id: int, x: float, y: float, z: float, dx: float, dy: float, dz: float, o: Dictionary = {}) -> void:
	var q: Bolt = _bolt_pool.pop_back() if not _bolt_pool.is_empty() else Bolt.new()
	q.x = x
	q.y = y
	q.z = z
	q.dx = dx
	q.dy = dy
	q.dz = dz
	q.speed = o.get("speed", AI.s_speed)
	q.life = 0.0
	q.owner = id
	q.kind = o.get("kind", "bolt")
	q.dmg = o.get("dmg", AI.s_dmg)
	q.rad = o.get("r", 0.15)
	q.push = 0.0
	q.slow_t = 0.0
	q.slow_mul = 1.0
	bolts.append(q)
	push({"t": "bolt", "id": id, "x": x, "y": y, "z": z, "dx": dx, "dy": dy, "dz": dz, "kind": q.kind})


func fire(r: Robot, x: float, y: float, z: float, dx: float, dy: float, dz: float, o: Dictionary = {}) -> void:
	if fire_hook.is_valid() and fire_hook.call(r, x, y, z, dx, dy, dz, o):
		return
	var q: Bolt = _bolt_pool.pop_back() if not _bolt_pool.is_empty() else Bolt.new()
	q.x = x
	q.y = y
	q.z = z
	q.dx = dx
	q.dy = dy
	q.dz = dz
	q.speed = o.get("speed", AI.s_speed)
	q.life = 0.0
	q.owner = r.id
	q.kind = o.get("kind", "bolt")
	q.dmg = o.get("dmg", AI.s_dmg)
	q.rad = o.get("r", 0.15)
	q.push = o.get("push", 0.0)
	q.slow_t = o.get("slow_t", 0.0)
	q.slow_mul = o.get("slow_mul", 1.0)
	bolts.append(q)
	push({"t": "bolt", "id": r.id, "x": x, "y": y, "z": z, "dx": dx, "dy": dy, "dz": dz, "kind": q.kind})


func update(dt: float, player: Player) -> void:
	t += dt
	P = player
	for r in robots:
		if r.frozen_t > 0.0 and not r.dead:                                     # FROST: frozen solid -- no AI, no movement, no attacks
			continue
		var target: Player = pick_player_target.call(r, player) if pick_player_target.is_valid() else player
		P = target
		if r.entry != null and r.entry.step(dt, target):      # still on its way in: not fighting yet
			continue
		r.update(dt * (1.0 - 0.7 * minf(1.0, r.chill)) if r.chill != 0.0 else dt, self, target)      # chilled: everything it does runs slower
	P = player
	_separate(player)
	if not reap.is_empty() and on_reap.is_valid():
		var gone := reap.duplicate()
		reap.clear()
		for r in gone:
			on_reap.call(r)
	var combatants: Array = _just_p
	if get_combatants.is_valid():
		combatants = get_combatants.call(player)
	else:
		_just_p[0] = player
	# bolts: world / player collision, damage once, then the bolt is gone
	var W := world
	var radius := Config.radius
	for i in range(bolts.size() - 1, -1, -1):
		var q := bolts[i]
		var left := q.speed * dt
		var gone := false
		while left > 0.0 and not gone:
			var st := minf(0.35, left)
			left -= st
			q.x += q.dx * st
			q.y += q.dy * st
			q.z += q.dz * st
			q.life += st / q.speed
			var victim: Player = null
			for actor: Player in combatants:
				if not actor.dead and U.hyp(q.x - actor.x, q.z - actor.z) < radius + q.rad and q.y > actor.y - (0.3 if q.rad > 0.3 else 0.0) and q.y < actor.y + actor.h + 0.1:
					victim = actor
					break
			if victim != null:
				c.hurt_player(victim, q.dmg, q.x - q.dx * 2.0, q.z - q.dz * 2.0, "bolt")
				push({"t": "bolt_hit", "x": q.x, "y": q.y, "z": q.z, "kind": "player", "bk": q.kind, "nx": -q.dx, "ny": -q.dy, "nz": -q.dz})
				gone = true
				if q.kind == "ring" and not victim.god and not (victim.invuln > 0.0):       # the phoniworm's ringer blast: a hard shove, no slow
					victim.ix += q.dx * q.push
					victim.iz += q.dz * q.push
					var ev := {"t": "ring_hit", "x": victim.x, "y": victim.y + 1.1, "z": victim.z, "dx": q.dx, "dz": q.dz}
					if victim.is_ai_clone:
						ev["clone_id"] = victim.clone_id
					push(ev)
				if q.kind == "mind" and not victim.god and not (victim.invuln > 0.0):       # the alien's mind blast: shoved back along the blast, then slowed for a few seconds
					victim.ix += q.dx * q.push
					victim.iz += q.dz * q.push
					victim.slow_t = maxf(victim.slow_t, q.slow_t)
					victim.slow_mul = q.slow_mul
					var ev := {"t": "mind_hit", "x": victim.x, "y": victim.y + 1.1, "z": victim.z, "dur": q.slow_t, "dx": q.dx, "dz": q.dz}
					if victim.is_ai_clone:
						ev["clone_id"] = victim.clone_id
					push(ev)
			elif W.point_solid(q.x, q.y, q.z) or q.y < Combat.floor_at(W, q.x, q.z):
				push({"t": "bolt_hit", "x": q.x, "y": q.y, "z": q.z, "kind": "world", "bk": q.kind, "nx": -q.dx, "ny": -q.dy, "nz": -q.dz})
				gone = true
			elif q.life > 3.0:
				gone = true
		if gone:
			bolts.remove_at(i)
			_bolt_pool.append(q)
	barks.update(dt)


func _shove(a: Robot, nx: float, nz: float) -> void:
	if a._free(a.x + nx, a.z):
		a.x += nx
	if a._free(a.x, a.z + nz):
		a.z += nz


## anti-stacking: living robots push each other apart (and away from the player) without ever pushing into walls
func _separate(player: Player) -> void:
	var R := robots
	var n := R.size()
	var pr := Config.radius
	for i in n:
		var a := R[i]
		if a.dead:
			continue
		for j in range(i + 1, n):
			var b := R[j]
			if b.dead or absf(a.y - b.y) > 1.5:
				continue
			var dx := b.x - a.x
			var dz := b.z - a.z
			var d := sqrt(dx * dx + dz * dz)
			var mn := a.r + b.r + 0.25
			if d < mn:
				var o := (mn - d) * 0.5
				var nx := dx / d if d > 1e-4 else 1.0
				var nz := dz / d if d > 1e-4 else 0.0
				_shove(a, -nx * o, -nz * o)
				_shove(b, nx * o, nz * o)
		if not player.dead:
			var dx := a.x - player.x
			var dz := a.z - player.z
			var d := sqrt(dx * dx + dz * dz)
			var mn := a.r + pr + 0.55
			if d < mn and absf(a.y - player.y) < 1.5 and a.state != &"attack":
				var dd := d if d != 0.0 else 1.0
				_shove(a, dx / dd * (mn - d) * 0.4, dz / dd * (mn - d) * 0.4)


## player died and came back: everybody forgets him
func player_respawned() -> void:
	for r in robots:
		if not r.dead and r.state != &"idle":                                   # a fresh start: hostile robots stand down and walk home (green)
			r.slot = &""
			r.known = null
			r.sees = false
			r.set_(&"return")
	_bolt_pool.append_array(bolts)
	bolts.clear()


## one row per robot for the debug panel / console: Game.enemies.table()
func table() -> Array[Dictionary]:
	var px := P.x if P != null else 0.0
	var pz := P.z if P != null else 0.0
	var out: Array[Dictionary] = []
	for r in robots:
		out.append({"id": r.id, "state": r.state, "t": snappedf(r.state_t, 0.01), "light": r.light, "hp": roundf(r.hp), "poise": roundf(r.poise), "immune": snappedf(r.immune_t, 0.1), "slot": r.slot, "atk": r.atk, "why": r.alert_why, "stuck": r.stuck_n,
			"sees": r.sees, "dist": snappedf(U.hyp(r.x - px, r.z - pz), 0.1), "x": snappedf(r.x, 0.1), "z": snappedf(r.z, 0.1), "alert_radius": Config.ai_alert_radius})
	return out
