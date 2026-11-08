class_name Combat
extends RefCounted
## Pure combat simulation (JS class Combat): punch combo, hitscan + rocket projectiles, arena gadgets, practice targets, ammo pickups, weapon wheel, player damage.
## Targets are analytic (cast_ray tests shapes against the list); the world is asked through World.ray_clear / point_solid, as in the JS.
##
## Everything the view needs comes out as `events`: an Array of Dictionaries with key "t" plus the JS keys, named by the port law (camelCase -> snake_case, in the "t" values
## too): equip, locked, shot, empty, reload, punch, punch_hit, hit, dmg, kill, slam, explode, pickup, respawn, player_hit, player_die, clone_hit, clone_die, shield_up,
## saw_bounce, saw_lost, saw_return, saw_catch, saw_clang, saw_slice, arc_start, arc_stop, arc_burnout, arc_zap, bellows_blast, yoke_start, yoke_fizzle, yoke_launch, yoke_impact,
## well_start, well_end, flail_swing, flail_impact (plus the robots' own: Enemies pushes into the same list).

const PUNCH_DUR: Array[float] = [0.26, 0.26, 0.38]
const PUNCH_HIT := 0.38
const PUNCH_CHAIN := 0.62
const PUNCH_DMG: Array[float] = [16.0, 16.0, 28.0]
const PUNCH_LUNGE: Array[float] = [3.2, 3.6, 5.2]

# the range: where the original arena's robots patrol, when a world has not said otherwise: [x, z, ax, az, w]
const DEFAULT_TARGET_SPOTS: Array = [[4.0, 22.0, 3.0, 0.0, 0.9], [-11.0, 22.0, 0.0, 3.0, 0.7], [10.0, 33.0, 4.0, 0.0, 1.2], [-12.0, -6.0, 0.0, 3.5, 0.8], [6.0, -14.0, 4.0, 0.0, 1.0],
	[22.0, 2.0, 0.0, 3.0, 1.1], [-6.0, -26.0, 5.0, 0.0, 0.9], [26.0, -8.0, 0.0, 4.0, 0.8], [16.0, 24.0, 1.8, 0.0, 0.9], [-26.0, 8.0, 0.0, 3.0, 1.0]]
const DEFAULT_CLERK_SPOT := [18.9, 10.5]
const DEFAULT_PICKUP_SPOTS: Array = [[4.0, 3.0], [-4.0, 5.0], [0.0, -7.0]]

# Levels whose own sandbox kit must never reach the save (the dev level's give-all), and are never CONTINUEd into
const SANDBOX_LEVELS: Array[String] = ["dev"]

# The kit of the movement test ground: it has no gunshop, and the wheel holds five.
const ARENA_KIT := {"ids": ["deagle", "shotgun", "rifle", "smg", "rocket"], "equip": "deagle"}


## A reload in progress (JS this.rl).
class Reload:
	var i := 0
	var t := 0.0
	var dur := 0.0
	var kind := "mag"
	var n := 0
	var k := -1
	var done := 0
	var ph := ""
	var u := 0.0
	var pu := 0.0
	var chambered := false
	var empty := false


## The punch combo state (JS this.punch).
class Punch:
	var stage := 0
	var t := 0.0
	var dur := 0.0
	var queued := false
	var hit := false
	var chain_t := 0.0
	var face := 0.0
	var side := "L"
	var last := 0


## A rocket in flight.
class Proj:
	var x := 0.0
	var y := 0.0
	var z := 0.0
	var dx := 0.0
	var dy := 0.0
	var dz := 0.0
	var speed := 0.0
	var life := 0.0
	var w: Weapons.Def


## A Saw-Loop disc in flight.
class Saw:
	var x := 0.0
	var y := 0.0
	var z := 0.0
	var vx := 0.0
	var vy := 0.0
	var vz := 0.0
	var speed := 0.0
	var ox := 0.0
	var oz := 0.0
	var bounces := 0
	var state := "out"     # out | return
	var t := 0.0
	var hit := {}          # target id -> the clock value until which it cannot be hit again
	var idx := 0
	var refunded := false
	var id := 0
	var gone := false


## A Moon Yoke stone in flight.
class Rock:
	var x := 0.0
	var y := 0.0
	var z := 0.0
	var vx := 0.0
	var vy := 0.0
	var vz := 0.0
	var ch := 0.0
	var t := 0.0
	var id := 0
	var gone := false


## A gravity well left by a Moon Yoke stone.
class Well:
	var x := 0.0
	var y := 0.0
	var z := 0.0
	var t := 0.0
	var dur := 0.0
	var r := 0.0
	var ch := 0.0
	var id := 0
	var gone := false


class Yoke:
	var holding := false
	var charge := 0.0


class Arc:
	var on := false
	var spent := false
	var idle := 0.0
	var t := 0.0
	var pts := PackedVector3Array()   # path of the beam
	var hits: Array[Target] = []      # who gets zapped
	var wall := false


## An ammo pod. hx / hz: its home, set by the first gadget step (the wells pull pods around).
class Pickup:
	var x := 0.0
	var y := 0.0
	var z := 0.0
	var cd := 0.0
	var hx := 0.0
	var hz := 0.0
	var has_home := false
	var pulled := false


## A weapon lying in the world (a spinning pickup, see FX.drop_vis).
class Drop:
	var id := 0
	var i := 0
	var x := 0.0
	var y := 0.0
	var z := 0.0
	var vx := 0.0
	var vy := 0.0
	var vz := 0.0
	var yaw := 0.0
	var rest := false
	var pin := 0.0
	var cd := 0.0
	var ammo := 0.0
	var reserve := 0.0


## The aiming guide of the Saw-Loop.
class SawGuide:
	var pts := PackedVector3Array()
	var n: Variant = null   # Vector3 normal of the first surface, or null
	var target := false


## cast_ray's answer. The same object is reused: valid until the next cast_ray.
class RayHit:
	var d := 0.0
	var target: Target = null
	var hit_world := false


## _world_hit's answer.
class WorldHit:
	var d := 0.0
	var nx := 0.0
	var ny := 0.0
	var nz := 0.0


var world: World
var cur := -1                       # -1 fists
var fire_punch_off := false         # (KAME LAB: fire never throws the unarmed punch)
var punch_off := false              # (KAME LAB: no punching mid-move)
var ammo := PackedFloat64Array()    # rounds in the current mag (the Electranator's charge is fractional)
var reserve := PackedFloat64Array() # spare rounds
var slots: Array = []               # the weapon wheel: weapon index per slot (null = empty), filled by give(); fists are always available on top of these
var owned := {}                     # = the non-null slots (kept for the shop / cycling)
var drops: Array[Drop] = []         # weapons lying in the world (spinning pickups, see FX.drop_vis)
var drop_focus: Drop = null
var _drop_id := 0
var rl: Reload = null
var auto_rl := 0.0
var cool := 0.0
var buffer := 0.0
var bloom := 0.0
var aim_t := 0.0
var aim_over: Variant = null      # {pos, look}: set by a playable level cutscene while its own view aims the guns
var events: Array = []              # Dictionaries, consumed by FX / audio / HUD
var projs: Array[Proj] = []
var saws: Array[Saw] = []           # Saw-Loop discs
var rocks: Array[Rock] = []         # Moon Yoke stones
var wells: Array[Well] = []         # gravity wells
var yoke := Yoke.new()
var arc := Arc.new()
var saw_guide: SawGuide = null
var _gid := 0
var punch := Punch.new()
var aim_pitch := 0.0
var aim_yaw := 0.0
var aim_point := Vector3.ZERO
var aim_dist := 0.0
var aim_on_target := false
var pull_aim := false
var muzzle := Vector3.ZERO
var aim_dir := Vector3(0, 0, 1)
var ads_on := false
var power_aim := false
var scope_w := 0.0                  # set by the frame: how far through the scope the view is (JS combat.scopeW)
var targets: Array[Target] = []
var pickups: Array[Pickup] = []
var clerk: Target = null
var enemies: Enemies                # JS Enemies (enemies/enemies.gd)
var flail: FlailSim                 # SCORPION FLAIL swing
var build: Builds.Build = null      # the character when it is not the one being played (JS this.build || CHAR): an AI ally

# hooks a level / vehicle system sets (JS this.onShatter and friends); empty = not there
var actor_damage: Callable          # (T, amount, from): a target that is really an AI clone's Player state
var on_shatter: Callable            # (T): FROST, a melee hit breaks a frozen enemy (powers/frost.js)
var on_world_shot: Callable         # (hp, left): a vehicle's body (vehicles/vehicles.js)
var on_blast: Callable              # (x, y, z, R, dmg): vehicles in reach
var vehicle_armor: Callable         # (P, amount, sx, sz, kind) -> amount: driving, the car's body takes most of it

var gear_live := false              # the wheel in play is the save's inventory (false in a level with its own kit, and while levels swap)

var _cam: CameraRig = null
var input_view: Inp.InputView = null      # an AI clone's virtual controls (JS: the input passed to update)
var _ray_hit := RayHit.new()
var _pull_best_set := false
var _pull_best_off := 9.0
var _pull_best_cy := 0.0
var _pull_best_hd := 0.0
var _pull_best_o := 0.0


func _init(p_world: World) -> void:
	world = p_world
	var n := Weapons.WEAPONS.size()
	ammo.resize(n)
	reserve.resize(n)
	ammo.fill(0.0)
	reserve.fill(0.0)
	slots.resize(Weapons.WHEEL_WEAPONS)
	slots.fill(null)
	load_slots([])                                       # (the save's inventory goes on the wheel when a level is entered: load_gear)
	enemies = Enemies.new(self)
	flail = FlailSim.new(self)
	_build_range()


## height below which a rocket / stone / bolt counts as having hit the ground at (x, z): a world whose ground is not at y 0 (the hub's FOINT CITY, at -10) gives `projectile_floor_at(x, z)`
static func floor_at(W: World, x: float, z: float) -> float:
	return float(W.projectile_floor_at.call(x, z)) if W.projectile_floor_at.is_valid() else W.projectile_floor_y


## the floor as the gadgets see it: projectile_floor_at if the world has one, else y 0 (not projectile_floor_y: as in the JS)
static func _floor0(W: World, x: float, z: float) -> float:
	return float(W.projectile_floor_at.call(x, z)) if W.projectile_floor_at.is_valid() else 0.0


## the stretch of the ray inside the infinite upright cylinder, cut by the slab between its floor and top (so a shot down through the top cap counts). INF = miss.
static func ray_cyl(ox: float, oy: float, oz: float, dx: float, dy: float, dz: float, T: Target) -> float:
	var a := dx * dx + dz * dz
	var px := ox - T.x
	var pz := oz - T.z
	var c := px * px + pz * pz - T.r * T.r
	var t0 := -INF
	var t1 := INF
	if a < 1e-9:
		if c > 0.0:
			return INF
	else:
		var b := 2.0 * (px * dx + pz * dz)
		var disc := b * b - 4.0 * a * c
		if disc < 0.0:
			return INF
		var s := sqrt(disc)
		t0 = (-b - s) / (2.0 * a)
		t1 = (-b + s) / (2.0 * a)
	if absf(dy) < 1e-9:
		if oy < T.y or oy > T.y + T.h:
			return INF
	else:
		var y0 := (T.y - oy) / dy
		var y1 := (T.y + T.h - oy) / dy
		if y0 > y1:
			var k := y0
			y0 = y1
			y1 = k
		t0 = maxf(t0, y0)
		t1 = minf(t1, y1)
	if t0 > t1 or t1 < 0.0:
		return INF
	return maxf(0.0, t0)


static func _hyp3(x: float, y: float, z: float) -> float:
	return sqrt(x * x + y * y + z * z)


## empty the wheel and fill it from a list of weapon indexes, each with full ammo (at start, and whenever a level is entered)
func load_slots(list: Array) -> void:
	cur = -1
	slots.fill(null)
	owned.clear()
	ammo.fill(0.0)
	reserve.fill(0.0)
	var fill_at := 0                                     # older saves had up to 10 weapons: keep the first WHEEL_WEAPONS of them, packed into the free slots
	for k: int in list:
		if k >= 0 and k < Weapons.WEAPONS.size() and fill_at < slots.size() and not owned.has(k):
			var w := Weapons.WEAPONS[k]
			slots[fill_at] = k
			fill_at += 1
			owned[k] = true
			ammo[k] = w.mag_size
			reserve[k] = w.max - w.mag_size


## put a saved inventory on the wheel ({ slots: [weapon_id | null], ammo, reserve: { weapon_id: n } }), each weapon in its saved slot with its saved rounds
func load_gear(g: Dictionary) -> void:
	load_slots([])
	var saved: Array = g.get("slots", [])
	var saved_ammo: Dictionary = g.get("ammo", {})
	var saved_reserve: Dictionary = g.get("reserve", {})
	for s in saved.size():
		var id: Variant = saved[s]
		if not (id is String):
			continue
		var k := Weapons.index_of(id)
		if k < 0 or s >= slots.size() or owned.has(k):
			continue
		var w := Weapons.WEAPONS[k]
		var a: Variant = saved_ammo.get(id)
		var r: Variant = saved_reserve.get(id)
		slots[s] = k
		owned[k] = true
		ammo[k] = clampf(a, 0.0, w.mag_size) if (a is float or a is int) else float(w.mag_size)
		reserve[k] = clampf(r, 0.0, w.max - ammo[k]) if (r is float or r is int) else float(w.max - w.mag_size)


## the wheel as a saved inventory (the inverse of load_gear)
func gear_snapshot() -> Dictionary:
	var out_slots: Array = []
	for k: Variant in slots:
		out_slots.append(null if k == null else Weapons.WEAPONS[k].id)
	var by_ammo := {}
	var by_reserve := {}
	for k: int in owned:
		by_ammo[Weapons.WEAPONS[k].id] = ammo[k]
		by_reserve[Weapons.WEAPONS[k].id] = reserve[k]
	return {"slots": out_slots, "ammo": by_ammo, "reserve": by_reserve, "equip": Weapons.WEAPONS[cur].id if cur >= 0 and owned.has(cur) else null}


## JS levelKit(): the weapons a level hands out: { ids, equip } (ids = weapon ids, equip = the one in hand). A level says so with `loadout` / `equip` on its node.
static func level_kit(lv: Level) -> Dictionary:
	var ids: Variant = lv.get("loadout") if lv != null else null
	if ids != null:
		var e: Variant = lv.get("equip")
		return {"ids": ids, "equip": e if e != null else ""}
	if lv != null and lv.id == "arena":
		return ARENA_KIT
	return {"ids": [], "equip": ""}


## JS applyLoadout(id): fill the wheel on level entry. Normally that is the save's inventory (ammo and slots as saved) plus each kit weapon the level has not handed over yet in
## this save (`granted`): a level's kit is found once and kept, never given again. Kit weapons that do not fit on a full wheel stay owed for the next visit.
## A level with its own fixed kit (a sandbox level, or a level whose `loadout` is empty: it is played unarmed) starts from an empty wheel (plus its kit) and never writes the wheel back.
func apply_loadout(id: String, lv: Level) -> void:
	var k := level_kit(lv)
	var kit_ids: Array = k.ids
	var kit_equip: String = k.equip
	var own_kit := SANDBOX_LEVELS.has(id) or (lv != null and lv.get("loadout") is Array and (lv.get("loadout") as Array).is_empty())
	if own_kit:
		gear_live = false
		load_slots([])
		for w: String in kit_ids:
			give(Weapons.index_of(w))
		if kit_equip != "":
			equip(Weapons.index_of(kit_equip))
		return
	var g: Dictionary = Game.save_data.gear
	load_gear(g)
	var arena: bool = lv != null and lv.id == "maktar"
	if arena and owned.is_empty():      # the arena has no gunshop: an empty wheel gets one gun
		kit_ids = [Weapons.WEAPONS[0].id]
	var granted: Dictionary = Game.save_data.granted
	if not granted.has(id):
		granted[id] = []
	var got: Array = granted[id]
	for w: String in kit_ids:
		var i := Weapons.index_of(w)
		if not got.has(w) and (owned.has(i) or give(i) >= 0):
			got.append(w)
	var hold := -1
	for e: Variant in [kit_equip, g.get("equip")]:
		var i := Weapons.index_of(e) if e is String else -1
		if i >= 0 and owned.has(i):
			hold = i
			break
	if hold >= 0:
		equip(hold)
	elif arena and not owned.is_empty():
		for sl: Variant in slots:
			if sl != null and int(sl) >= 0:
				equip(int(sl))
				break
	gear_live = true


func _build_range() -> void:
	var W := world
	var spots: Array = W.target_spots if W.target_spots != null else DEFAULT_TARGET_SPOTS
	for i in spots.size():
		var s: Array = spots[i]
		var x: float = s[0]
		var z: float = s[1]
		var y := maxf(0.0, W.ground_height(x, z, 0.3, 20.0))
		var rb := Robot.new(W, i, x, z, y, {"ax": s[2], "az": s[3]})
		enemies.add(rb)                                       # the old sine-wave dummies are now hostile robots
		targets.append(rb)
	var cs: Array = W.clerk_spot if W.clerk_spot != null else DEFAULT_CLERK_SPOT
	clerk = Target.new(99, cs[0], cs[1], 0.0, {"r": 0.4, "h": 1.85, "max": 160.0, "hp": 160.0, "npc": true, "w": 0.0})
	targets.append(clerk)
	var ps: Array = W.pickup_spots if W.pickup_spots != null else DEFAULT_PICKUP_SPOTS
	for s: Array in ps:                                   # [x, z, y]: the Meat Spire has pods high up
		var p := Pickup.new()
		p.x = s[0]
		p.z = s[1]
		p.y = float(s[2]) if s.size() > 2 else maxf(0.0, W.ground_height(p.x, p.z, 0.3, 3.0))
		pickups.append(p)


## JS resetCombatForLevel(): empty combat of the old level, then build the targets / pickups of the current world.
func reset_for_level(W: World) -> void:
	world = W
	targets.clear()
	pickups.clear()
	drops.clear()
	drop_focus = null
	projs.clear()
	saws.clear()
	rocks.clear()
	wells.clear()
	events.clear()
	enemies.robots.clear()
	enemies.bolts.clear()
	enemies.reap.clear()
	rl = null
	cool = 0.0
	buffer = 0.0
	yoke.holding = false
	yoke.charge = 0.0
	flail.reset()
	_build_range()


func equip(i: int) -> void:
	if i >= 0 and not owned.has(i):
		events.append({"t": "locked"})
		return
	if i == cur:
		return
	cancel_reload()
	auto_rl = 0.0
	yoke.holding = false
	yoke.charge = 0.0
	_arc_off()
	flail.reset()
	cur = i
	cool = 0.22
	buffer = 0.0
	bloom = 0.0
	punch.stage = 0
	punch.queued = false
	events.append({"t": "equip", "i": i})


var weapon: Weapons.Def:
	get:
		return Weapons.WEAPONS[cur] if cur >= 0 else null


var armed: bool:
	get:
		return cur >= 0


# ---- inventory (weapon wheel) ----
## put weapon i in the first empty wheel slot with these rounds (default: full). Returns the slot, or -1 (already carried / wheel full).
func give(i: int, p_ammo: Variant = null, p_reserve: Variant = null) -> int:
	if i < 0 or i >= Weapons.WEAPONS.size() or owned.has(i):
		return -1
	var w := Weapons.WEAPONS[i]
	var s := slots.find(null)
	if s < 0:
		return -1
	var a: float
	var r: float
	if p_ammo == null:
		a = w.mag_size
		r = w.max - w.mag_size
	else:
		a = p_ammo
		r = float(p_reserve) if p_reserve != null else 0.0
	slots[s] = i
	owned[i] = true
	ammo[i] = clampf(roundf(a), 0.0, w.mag_size)
	reserve[i] = clampf(roundf(r), 0.0, w.max - ammo[i])
	Game.save_game()
	return s


## take weapon i off the wheel (holstering it first if it is in hand). Returns the rounds it had ({ ammo, reserve }), or null if it was not carried.
func remove(i: int) -> Variant:
	var s := slots.find(i)
	if s < 0:
		return null
	if rl != null and rl.i == i:
		cancel_reload()
	if cur == i:
		equip(-1)
	slots[s] = null
	owned.erase(i)
	var r := {"ammo": ammo[i], "reserve": reserve[i]}
	ammo[i] = 0.0
	reserve[i] = 0.0
	Game.save_game()
	return r


## a weapon lying in the world. o: { ammo, reserve, vx, vy, vz, cd (seconds before it can be picked up) }
func spawn_drop(i: int, x: float, y: float, z: float, o: Dictionary = {}) -> Drop:
	if i < 0 or i >= Weapons.WEAPONS.size():
		return null
	var w := Weapons.WEAPONS[i]
	var d := Drop.new()
	_drop_id += 1
	d.id = _drop_id
	d.i = i
	d.x = x
	d.y = y
	d.z = z
	d.vx = o.get("vx", 0.0)
	d.vy = o.get("vy", 0.0)
	d.vz = o.get("vz", 0.0)
	d.yaw = randf() * PI * 2.0
	d.cd = o.get("cd", 0.0)
	d.ammo = o.get("ammo", float(w.mag_size))
	d.reserve = o.get("reserve", float(w.max - w.mag_size))
	drops.append(d)
	return d


func remove_drop(d: Drop) -> void:
	var k := drops.find(d)
	if k >= 0:
		drops.remove_at(k)
	if drop_focus == d:
		drop_focus = null


## discard weapon i from the wheel: it is tossed a little in front of the player and lies there with the rounds it had left
func discard(i: int, P: Player) -> Drop:
	var r: Variant = remove(i)
	if r == null:
		return null
	var fx := sin(P.yaw)
	var fz := cos(P.yaw)
	return spawn_drop(i, P.x + fx * 0.45, P.y + 1.0, P.z + fz * 0.45, {"ammo": r.ammo, "reserve": r.reserve, "vx": fx * 1.6, "vz": fz * 1.6, "vy": 2.2, "cd": 0.5})


## the drop the player could pick up right now (closest within reach), or null
func near_drop(P: Player) -> Drop:
	var best: Drop = null
	var bd := 1.6
	for d: Drop in drops:
		if d.cd > 0.0 or absf(P.y - d.y) > 1.6:
			continue
		var k := U.hyp(P.x - d.x, P.z - d.z)
		if k < bd:
			bd = k
			best = d
	return best


## pick a drop up: a new weapon goes into the wheel (and into his hands if they are empty); one already carried only gives its rounds.
## Returns "new" | "ammo" | "maxed" | "full"
func pick_up(d: Drop) -> String:
	var w := Weapons.WEAPONS[d.i]
	if owned.has(d.i):
		var room: float = w.max - ammo[d.i] - reserve[d.i]
		var have := d.ammo + d.reserve
		var take := minf(room, have)
		if take <= 0.0:
			return "maxed"
		reserve[d.i] += take
		var left := have - take
		if left > 0.0:
			d.ammo = minf(left, w.mag_size)
			d.reserve = left - d.ammo
		else:
			remove_drop(d)
		return "ammo"
	if give(d.i, d.ammo, d.reserve) < 0:
		return "full"
	remove_drop(d)
	if cur < 0:
		equip(d.i)
	return "new"


func _drop_step(dt: float) -> void:
	var W := world
	for k in range(drops.size() - 1, -1, -1):
		var d := drops[k]
		d.cd = maxf(0.0, d.cd - dt)
		if d.pin > 0.0:                                  # held by the dev tools' drag
			d.pin -= dt
			d.rest = false
			continue
		if d.rest:                                       # its support went away -> fall again
			if W.ground_height(d.x, d.z, 0.25, d.y + 0.05) < d.y - 0.02:
				d.rest = false
			else:
				continue
		d.vy -= 22.0 * dt
		var nx := d.x + d.vx * dt
		var nz := d.z + d.vz * dt
		if W.blocked(nx, nz, d.y, 0.3, 0.22, 0.2):
			d.vx = 0.0
			d.vz = 0.0
		else:
			d.x = nx
			d.z = nz
		var ny := d.y + d.vy * dt
		var g := W.ground_height(d.x, d.z, 0.25, d.y + 0.05)
		if ny <= g:
			d.y = g
			d.vy = 0.0
			d.vx = 0.0
			d.vz = 0.0
			d.rest = true
		else:
			d.y = ny
		if d.y < -40.0:
			drops.remove_at(k)


func start_reload(P: Player) -> bool:
	var w := weapon
	if w == null or rl != null or P.ads:
		return false
	var i := cur
	var need: float = w.mag_size - ammo[i]
	if need <= 0.0 or reserve[i] <= 0.0:
		return false
	var n := int(minf(need, reserve[i]))
	var dur := Weapons.SHELL_OPEN + n * Weapons.SHELL_PER + Weapons.SHELL_PUMP if w.reload_kind == "shell" else w.reload_time
	rl = Reload.new()
	rl.i = i
	rl.dur = dur
	rl.kind = w.reload_kind
	rl.n = n
	rl.empty = ammo[i] <= 0.0
	P.sprinting = false
	return true


func cancel_reload() -> void:
	if rl == null:
		return
	events.append({"t": "reload", "ph": "cancel", "id": Weapons.WEAPONS[rl.i].id})
	rl = null


func _rl_emit(r: Reload, w: Weapons.Def, ph: String) -> void:
	events.append({"t": "reload", "ph": ph, "id": w.id, "kind": r.kind, "dur": r.dur / maxf(0.1, Config.reload_speed), "emp": r.empty})


func _reload_step(dt: float, _P: Player) -> void:
	var r := rl
	var i := r.i
	var w := Weapons.WEAPONS[i]
	r.t += dt * maxf(0.1, Config.reload_speed)
	var ph: String
	var pu: float
	if r.kind == "shell":
		var t := r.t
		if t < Weapons.SHELL_OPEN:
			ph = "open"
			pu = t / Weapons.SHELL_OPEN
		elif t < Weapons.SHELL_OPEN + r.n * Weapons.SHELL_PER:
			var x := (t - Weapons.SHELL_OPEN) / Weapons.SHELL_PER
			r.k = floori(x)
			ph = "load"
			pu = x - r.k
			var want := r.k + (1 if pu >= 0.92 else 0)
			while r.done < want:
				r.done += 1
				ammo[i] += 1.0
				reserve[i] -= 1.0
				_rl_emit(r, w, "shell")
		else:
			ph = "pump"
			pu = minf(1.0, (t - Weapons.SHELL_OPEN - r.n * Weapons.SHELL_PER) / Weapons.SHELL_PUMP)
			while r.done < r.n:
				r.done += 1
				ammo[i] += 1.0
				reserve[i] -= 1.0
				_rl_emit(r, w, "shell")
			if pu > 0.62 and not r.chambered:
				r.chambered = true
				_rl_emit(r, w, "chamber")
	else:
		var u := minf(1.0, r.t / r.dur)
		var RL_PH := Weapons.RL_PH
		var k := 0
		while k < RL_PH.size() - 1 and u >= float(RL_PH[k][1]):
			k += 1
		var a: float = float(RL_PH[k - 1][1]) if k > 0 else 0.0
		var b: float = minf(1.0, float(RL_PH[k][1]))
		ph = RL_PH[k][0]
		pu = clampf((u - a) / (b - a), 0.0, 1.0)
		if ph == "rack" and r.done == 0:
			r.done = 1
			var take := minf(w.mag_size - ammo[i], reserve[i])
			ammo[i] += take
			reserve[i] -= take
		if ph == "rack" and pu > 0.7 and not r.chambered:
			r.chambered = true
			_rl_emit(r, w, "chamber")
	if ph != r.ph:
		r.ph = ph
		_rl_emit(r, w, ph)
	r.pu = pu
	r.u = minf(1.0, r.t / r.dur)
	if r.t >= r.dur:
		rl = null
		_rl_emit(r, w, "done")


## nearest world / target hit along a ray: { d, target | null, hit_world }. The answer is reused: read it before the next cast.
func cast_ray(ox: float, oy: float, oz: float, dx: float, dy: float, dz: float, max_d: float) -> RayHit:
	var d := world.ray_clear(ox, oy, oz, dx, dy, dz, max_d, 0.01)
	var hit_world := d < max_d - 0.01
	var tgt: Target = null
	var td := d + 0.12 if hit_world else max_d
	for T: Target in targets:
		if T.dead:
			continue
		var t := ray_cyl(ox, oy, oz, dx, dy, dz, T)
		if t < td:
			td = t
			tgt = T
	var h := _ray_hit
	h.d = td if tgt != null else d
	h.target = tgt
	h.hit_world = tgt == null and hit_world
	return h


## `from` is anything with x and z (the Player, a saw disc, a Vector3, a { x, z } Dictionary).
func damage(T: Target, amount: float, from: Variant, kb: float = 0.0, pt: Variant = null, melee: bool = false) -> Variant:
	if T.actor_state != null:
		return actor_damage.call(T, amount, from) if actor_damage.is_valid() else null
	if T.dead:
		return null
	if melee and T.frozen_t > 0.0 and on_shatter.is_valid():    # FROST: a punch / hammer fist breaks a frozen enemy (powers/frost.js)
		amount = maxf(amount, T.hp + 1.0)
		on_shatter.call(T)
	T.hp -= amount
	T.flash = 1.0
	T.wob = 1.0
	var dx: float = T.x - from.x
	var dz: float = T.z - from.z
	var l := U.hyp(dx, dz)
	if l == 0.0:
		l = 1.0
	if not T.npc and not T.robot:
		T.kx += dx / l * kb
		T.kz += dz / l * kb
	var kill := T.hp <= 0.0
	events.append({"t": "dmg", "x": T.x, "y": T.y + 1.5, "z": T.z, "amount": roundi(amount), "kill": kill, "crowd": T.crowd})
	events.append({"t": "kill" if kill else "hit", "x": T.x, "y": T.y + (T.h * 0.5 if T.boss else 1.2), "z": T.z, "npc": T.npc, "crowd": T.crowd, "robot": T.robot, "ux": dx / l, "uz": dz / l, "gy": T.y, "tid": T.id})
	if kill:
		T.dead = true
		T.respawn_t = 90.0 if T.npc else 4.0
	if T.robot:
		T.hurt(amount, from, kb, pt, kill)                       # AI reaction: alert, flinch / stagger, broadcast to nearby robots, death
	return null


## damage to the player (melee / bolt). Returns true if it landed. Handles invulnerability, knockback, death.
func hurt_player(P: Player, amount: float, sx: float, sz: float, kind: String) -> bool:
	if P.god:
		return false
	amount *= Config.ai_damage
	if vehicle_armor.is_valid():                                 # driving: the car's body takes most of it (vehicles/vehicles.js)
		amount = vehicle_armor.call(P, amount, sx, sz, kind)
		if not (amount > 0.0):
			return false
	if not P.is_ai_clone:                                        # the equipped suit's rated damage reduction (ARMOR_CATALOG); allies wear none
		amount *= 1.0 - ArmorStore.dr()
	if P.dead or P.invuln > 0.0 or amount <= 0.0:
		return false
	# the suit's energy shield soaks the (already armor-reduced) hit first; any overflow when it breaks carries through to health. Every hit restarts the shield's recharge delay.
	var hp_amt := amount
	var shield_hit := false
	var shield_break := false
	if not P.is_ai_clone and P.shield_max > 0.0:
		if P.shield > 0.0:
			var take := minf(P.shield, amount)
			P.shield -= take
			hp_amt = amount - take
			shield_hit = true
			shield_break = P.shield <= 1e-6
			if shield_break:
				P.shield = 0.0
		P.shield_t = P.shield_delay
		P.shield_rech = false
	P.hp = maxf(0.0, P.hp - hp_amt)
	P.regen_t = Config.player_regen_delay
	var dx := sx - P.x
	var dz := sz - P.z
	var l := U.hyp(dx, dz)
	if l == 0.0:
		l = 1.0
	var ux := dx / l
	var uz := dz / l
	P.ix -= ux * (7.0 if kind == "melee" else 1.6)
	P.iz -= uz * (7.0 if kind == "melee" else 1.6)
	events.append({"t": "clone_hit" if P.is_ai_clone else "player_hit", "actor_state": P if P.is_ai_clone else null, "amount": roundi(amount), "hp_amount": hp_amt, "dx": ux, "dz": uz, "kind": kind, "hp": P.hp, "kill": P.hp <= 0.0,
		"shield": shield_hit, "shield_break": shield_break, "shield_col": P.shield_col, "shield_hex": P.shield_hex})
	if P.hp <= 0.0:
		P.dead = true
		P.dead_t = 0.0
		P.fall_dir = -1.0 if ux * sin(P.yaw) + uz * cos(P.yaw) > 0.0 else 1.0     # hit from the front -> falls onto his back
		if not P.is_ai_clone:
			cancel_reload()
		events.append({"t": "clone_die" if P.is_ai_clone else "player_die", "actor_state": P if P.is_ai_clone else null})
	return true


## the equipped suit's energy shield: follows the equipped suit (full when a shielded suit is put on), and after `delay` seconds without taking damage recharges gradually at `rate` per second
func shield_step(dt: float, P: Player) -> void:
	if P.is_ai_clone:                                            # allies wear no suit
		return
	var def: ArmorStore.ShieldDef = ArmorStore.shield()
	var mx := def.max if def != null else 0.0
	if P.shield_max != mx:
		P.shield_max = mx
		P.shield = mx
		P.shield_t = 0.0
		P.shield_rech = false
		if def != null:
			P.shield_delay = def.delay
			P.shield_rate = def.rate
			P.shield_col = def.col
			P.shield_hex = def.hex
		else:
			P.shield_col = ""
	if mx <= 0.0:
		return
	P.shield_t -= dt
	if P.shield_t <= 0.0 and P.shield < mx:
		if not P.shield_rech:
			P.shield_rech = true
			events.append({"t": "shield_up", "col": P.shield_col, "x": P.x, "y": P.y + 1.0, "z": P.z})
		P.shield = minf(mx, P.shield + P.shield_rate * dt)


func _pull_consider(cx: float, cy: float, cz: float, rad: float, pref: float, sx: float, sz: float, cam_yaw: float) -> void:
	var ex := cx - sx
	var ez := cz - sz
	var hd := U.hyp(ex, ez)
	if hd < 1.5 or hd > 45.0:
		return
	var off := maxf(0.0, absf(U.wrap_angle(atan2(ex, ez) - cam_yaw)) - atan2(rad, hd))   # angular size counts: a big target close by is easy to hold
	var score := off - pref
	if score < _pull_best_off:
		_pull_best_off = score
		_pull_best_set = true
		_pull_best_cy = cy
		_pull_best_hd = hd
		_pull_best_o = off


## One frame of combat, before the player moves. dead_input: the JS DEAD_INPUT (no buttons read while driving, stunned or in a cutscene).
func update(dt: float, P: Player, cam: CameraRig, dead_input: bool = false) -> void:
	var W := world
	var inp: Inp.InputView = input_view if input_view != null else (Inp.dead if dead_input else Inp.full)
	var b_fire: Inp.Btn = inp.btn(&"fire")
	var b_attack: Inp.Btn = inp.btn(&"attack")
	var b_reload: Inp.Btn = inp.btn(&"reload")
	var w := weapon
	_cam = cam
	# ---- targets ----
	for T: Target in targets:
		if T.robot:                                  # robots are ticked by the enemy AI (Enemies.update), the clerk below stays a still target
			continue
		T.t += dt
		T.flash = maxf(0.0, T.flash - dt * 5.0)
		T.wob = maxf(0.0, T.wob - dt * 2.5)
		if T.dead:
			T.respawn_t -= dt
			if T.respawn_t <= 0.0:
				T.dead = false
				T.hp = T.max
				T.flash = 1.0
				events.append({"t": "respawn", "x": T.x, "y": T.y, "z": T.z, "tid": T.id})
			continue
		var s := sin(T.t * T.w + T.ph)
		var c := cos(T.t * T.w + T.ph)
		var tnx := T.bx + T.ax * s
		var tnz := T.bz + T.az * s
		T.face = atan2(T.ax * c, T.az * c + 1e-6)
		T.x = tnx + T.kx
		T.z = tnz + T.kz
		T.kx *= exp(-6.0 * dt)
		T.kz *= exp(-6.0 * dt)
	for p: Pickup in pickups:
		p.cd = maxf(0.0, p.cd - dt)
		if p.cd <= 0.0 and U.hyp(P.x - p.x, P.z - p.z) < 1.2 and absf(P.y - p.y) < 1.5:
			var need := false                         # only what is on the wheel
			for i: int in owned:
				var wp := Weapons.WEAPONS[i]
				if not wp.energy and (ammo[i] < wp.mag_size or reserve[i] < wp.max - wp.mag_size):
					need = true
					break
			if need:
				for i: int in owned:
					var wp := Weapons.WEAPONS[i]
					ammo[i] = wp.mag_size
					reserve[i] = wp.max - wp.mag_size
				p.cd = 10.0
				events.append({"t": "pickup", "x": p.x, "y": p.y + 0.6, "z": p.z})
	_drop_step(dt)

	enemies.update(dt, P)
	_gadget_physics(dt, P)
	var actor_build: Builds.Build = build if build != null else Builds.character_build(Game.char_pick)
	flail.step(dt, P, weapon, actor_build)
	P.invuln = maxf(0.0, P.invuln - dt)
	if P.dead:                                        # down: no aiming / firing / reloading until the respawn
		P.dead_t += dt
		P.aiming = false
		P.ads = false
		P.scoped = false
		P.punching = false
		P.punch_face = null
		P.slamming = false
		P.sprinting = false
		P.rl_on = false
		rl = null
		aim_on_target = false
		yoke.holding = false
		yoke.charge = 0.0
		saw_guide = null
		return
	P.regen_t -= dt
	if P.regen_t <= 0.0 and P.hp < P.max_hp:
		P.hp = minf(P.max_hp, P.hp + Config.player_regen * dt)
	shield_step(dt, P)

	# ---- aim point from the camera ray (screen centre) ----
	var ap_look: Vector3 = aim_over.look if aim_over != null else cam.look      # a playable level cutscene aims through its own ray (JS cine.aim: OMNISPHERE's freefall)
	var ap_pos: Vector3 = aim_over.pos if aim_over != null else cam.pos
	var ap_dist: float = aim_over.dist if aim_over != null else cam.dist
	var cdx := ap_look.x - ap_pos.x
	var cdy := ap_look.y - ap_pos.y
	var cdz := ap_look.z - ap_pos.z
	var cl := _hyp3(cdx, cdy, cdz)
	if cl == 0.0:
		cl = 1.0
	var dx := cdx / cl
	var dy := cdy / cl
	var dz := cdz / cl
	var sx := ap_pos.x + dx * ap_dist
	var sy := ap_pos.y + dy * ap_dist
	var sz := ap_pos.z + dz * ap_dist
	pull_aim = false
	if cam.pull_eff > 0.3 and cam.pull_lock and not (w != null and w.scope and P.ads):
		# set-piece camera (high angle): the crosshair ray would hit the floor in front of you, so aim along the camera's heading instead, tilted up at whatever is roughly ahead (the boss, or a nearer
		# enemy you have turned towards). A soft lock: it fades out as you turn away, so you can aim freely at anything.
		var hx := sin(cam.yaw)
		var hz := cos(cam.yaw)
		sx = ap_look.x
		sy = ap_look.y
		sz = ap_look.z
		_pull_best_set = false
		_pull_best_off = 9.0
		_pull_consider(cam.pull_cx, cam.pull_aim_y if cam.pull_aim_y != 0.0 else sy, cam.pull_cz, 4.3, 0.12, sx, sz, cam.yaw)   # she is big: easier to hold
		for r: Robot in enemies.robots:
			if not r.dead:
				_pull_consider(r.x, r.y + (r.h * 0.5 if r.h != 0.0 else 0.9), r.z, 0.7, 0.0, sx, sz, cam.yaw)
		var lock := clampf(1.0 - (_pull_best_o - 0.12) / 0.5, 0.0, 1.0) if _pull_best_set else 0.0
		var th := atan2(_pull_best_cy - sy, _pull_best_hd) * lock if _pull_best_set else 0.0
		var ct := cos(th)
		dx = hx * ct
		dy = sin(th)
		dz = hz * ct
		pull_aim = true
	P.scoped = w != null and w.scope and P.ads
	P.scope_fov = w.scope_fov if (w != null and w.scope) else 0.0      # read by the camera rig / view / HUD
	var rr := cast_ray(sx, sy, sz, dx, dy, dz, 200.0 if P.scoped else 120.0)   # 200 m is plenty for the per-frame aim probe (the shot itself uses w.range)
	var rr_any := rr.target != null or rr.hit_world
	var dd := rr.d if rr_any else (200.0 if P.scoped else 70.0)
	aim_dist = rr.d if rr_any else 0.0                                   # metres to whatever is under the crosshair (scope readout)
	aim_point = Vector3(sx + dx * dd, sy + dy * dd, sz + dz * dd)
	aim_on_target = rr.target != null

	var fy := sin(P.yaw)
	var fz := cos(P.yaw)
	var mh := P.y + (actor_build.muz_crouch if P.crouching else actor_build.muz_y)
	# muzzle sits slightly to the right of the body (right vector = (-cos, sin))
	var muz := Vector3(P.x + fy * actor_build.muz_f - cos(P.yaw) * actor_build.muz_s, mh, P.z + fz * actor_build.muz_f + sin(P.yaw) * actor_build.muz_s)
	var ax := aim_point.x - muz.x
	var ay := aim_point.y - muz.y
	var az := aim_point.z - muz.z
	var al := _hyp3(ax, ay, az)
	if al < 2.5:
		ax = dx
		ay = dy
		az = dz
		al = 1.0
	ax /= al
	ay /= al
	az /= al
	aim_pitch = asin(clampf(ay, -1.0, 1.0))
	aim_yaw = clampf(U.wrap_angle(atan2(ax, az) - P.yaw), -0.14, 0.14)   # the gun stays square to his body; HE turns to the aim (see Player facing)
	muzzle = muz
	aim_dir = Vector3(ax, ay, az)
	P.aim_pitch = aim_pitch
	P.aim_yaw = aim_yaw
	P.armed = w != null
	ads_on = P.ads
	P.weapon_idx = cur

	# ---- state used by the controller / animator ----
	cool = maxf(0.0, cool - dt)
	buffer = maxf(0.0, buffer - dt)
	aim_t = maxf(0.0, aim_t - dt)
	bloom = maxf(0.0, bloom - dt * 0.06)
	P.recoil = maxf(0.0, P.recoil - dt * 7.0)

	# hammer fist: melee (X, or RT when unarmed) while in the air after a double jump
	var air_slam := not P.grounded and P.last_jump == &"double" and P.mode == &"normal"
	if (air_slam or P.slamming) and (b_attack.pressed or (w == null and b_fire.pressed)) and not P.slamming:
		P.slam_req = true
	if P.slam_hit != null:
		var h: Vector3 = P.slam_hit
		P.slam_hit = null
		var R := Config.slam_radius
		events.append({"t": "slam", "x": h.x, "y": h.y, "z": h.z, "r": R})
		for T: Target in targets:
			if T.dead or absf(T.y - h.y) > 2.6:
				continue
			var d := U.hyp(T.x - h.x, T.z - h.z)
			if d < R + T.r:
				damage(T, Config.slam_dmg * (1.0 - 0.55 * clampf(d / (R + T.r), 0.0, 1.0)), h, 6.0 * (1.0 - d / (R + 1.0)), null, true)
	var sl := P.slamming or P.slam_req
	power_aim = P.power_aim
	if P.power_aim:                                   # power mode (Z): the left hand casts (power_tick, frame loop); the gun stays lowered and silent, no reload; melee (V / pad X) still punches -- that is how FROST's frozen enemies get shattered
		P.aiming = P.mode == &"normal" and not sl
		buffer = 0.0
		_punch(dt, P, b_attack.pressed and not air_slam and not sl and not punch_off)
		if rl != null:
			cancel_reload()
		yoke.holding = false
		yoke.charge = 0.0
		_arc_off()
	elif w != null:
		P.aiming = (b_fire.held or aim_t > 0.0 or P.ads) and P.mode == &"normal" and not sl
		P.punching = false
		P.punch_face = null
		punch.stage = 0
		if b_fire.pressed:
			buffer = 0.12
		# ---- reload: X (pad) / R (keyboard). Sprint, ADS, ledge grab and weapon swaps cancel it. ----
		var empty_rl := Config.auto_reload != 0 and rl != null and rl.empty    # an auto reload of an empty gun is not cancelled by ADS / sprint (they are forced off until it is done)
		if empty_rl and P.mode == &"normal" and not sl:
			P.ads = false
			P.scoped = false
			P.sprinting = false
		if rl != null and (P.mode != &"normal" or P.sprinting or P.ads or sl):
			cancel_reload()
		var rl_btn := b_reload.pressed or (b_attack.pressed and not air_slam and not P.slamming)
		if rl_btn and P.mode == &"normal" and not sl:
			start_reload(P)
		var want := b_fire.held if w.mode == "auto" else (b_fire.pressed or buffer > 0.0)
		if w.special == "yoke":
			_yoke_hold(dt, P, w, muz, ax, ay, az, b_fire, sl)
		if w.special == "arc":
			_arc_step(dt, P, w, muz, ax, ay, az, b_fire, sl)
		if w.special == "saw":
			_saw_guide(muz, ax, ay, az)
		if want and rl != null and rl.kind == "shell" and ammo[cur] > 0.0 and rl.t > Weapons.SHELL_OPEN:   # shotgun: fire interrupts shell loading
			cancel_reload()
		if want and w.special != "yoke" and w.special != "arc" and cool <= 0.0 and P.mode == &"normal" and not sl and rl == null:
			if ammo[cur] <= 0.0:
				if Config.auto_reload != 0 and reserve[cur] > 0.0 and start_reload(P):
					pass                                 # dry-fire starts the reload
				elif b_fire.pressed:
					events.append({"t": "empty", "id": w.id})
					cool = 0.25
				buffer = 0.0
			else:
				_shoot(w, P, muz, ax, ay, az)
		if auto_rl > 0.0:
			auto_rl -= dt
		# an empty mag with ammo in reserve always reloads (retried every frame, not a one-shot timer): sprint / ADS / scope would otherwise leave the gun stuck empty
		if auto_rl <= 0.0 and Config.auto_reload != 0 and rl == null and ammo[cur] <= 0.0 and reserve[cur] > 0.0 and P.mode == &"normal" and not sl:
			P.ads = false
			P.scoped = false
			P.sprinting = false
			start_reload(P)
		if rl != null:
			_reload_step(dt, P)
		if P.ads and P.sprinting:
			P.sprinting = false
	else:
		P.aiming = false
		rl = null
		_punch(dt, P, false if (air_slam or sl or fire_punch_off or punch_off) else b_fire.pressed)
	P.rl_on = rl != null
	if w == null or w.special != "saw" or P.power_aim:
		saw_guide = null
	if w == null or w.special != "arc":
		_arc_off()
	_arc_regen(dt)
	var N := Weapons.NEWW
	N.charge = yoke.charge if yoke.holding else 0.0
	N.arc = 1.0 if arc.on else 0.0
	N.ammo = ammo[cur] if cur >= 0 else 0.0
	N.mag = Weapons.WEAPONS[cur].mag_size if cur >= 0 else 0
	N.reserve = reserve[cur] if cur >= 0 else 0.0
	if rl != null:
		P.rl_kind = rl.kind
		P.rl_dur = rl.dur / maxf(0.1, Config.reload_speed)
		P.rl_u = rl.u
		P.rl_ph = rl.ph
		P.rl_pu = rl.pu
		P.rl_n = rl.k
		P.rl_empty = rl.empty
	# ---- projectiles ----
	for i in range(projs.size() - 1, -1, -1):
		var q := projs[i]
		var left := q.speed * dt
		var dead := false
		while left > 0.0 and not dead:
			var st := minf(0.3, left)
			left -= st
			var nx := q.x + q.dx * st
			var ny := q.y + q.dy * st
			var nz := q.z + q.dz * st
			var hit := W.point_solid(nx, ny, nz) or ny < floor_at(W, nx, nz)
			if not hit:
				for T: Target in targets:
					if not T.dead and U.hyp(nx - T.x, nz - T.z) < T.r + 0.12 and ny > T.y and ny < T.y + T.h:
						hit = true
						break
			q.x = nx
			q.y = ny
			q.z = nz
			q.life += st / q.speed
			if hit or q.life > 4.0:
				dead = true
				_explode(q)
		if dead:
			projs.remove_at(i)


func _shoot(w: Weapons.Def, P: Player, m: Vector3, ax: float, ay: float, az: float) -> void:
	if w.special == "saw":
		_saw_launch(w, P, m, ax, ay, az)
		return
	if w.special == "bellows":
		_bellows_fire(w, P, m, ax, ay, az)
		return
	if w.special == "flail":
		flail.start(w, P)
		return
	cool = 1.0 / w.rate
	buffer = 0.0
	ammo[cur] -= 1.0
	if ammo[cur] <= 0.0:
		auto_rl = 0.3
	aim_t = maxf(Config.aim_hold, minf(1.0 / w.rate + Config.aim_hold_semi, Config.aim_hold_max))   # stays aimed past the next shot's cooldown, so consecutive single shots never drop the pose
	P.recoil = minf(1.6, P.recoil + w.kick)
	if P.scoped and _cam != null:                     # looking through the scope: the view jumps up with the shot
		_cam.kick_p = minf(0.07, _cam.kick_p + 0.05)
	var spread := (w.spread + bloom) * ((w.scope_spread / w.spread if w.scope else Config.ads_spread) if P.ads else 1.0)
	if w.bloom_add != 0.0:
		bloom = minf(w.bloom_max, bloom + w.bloom_add)
	var pel: Array = []
	for _p in w.pellets:
		# random point in a cone
		var r := sqrt(randf()) * spread
		var a := randf() * 6.2832
		var rx := az                                  # horizontal vector perpendicular to the aim
		var rz := -ax
		var rlen := U.hyp(rx, rz)
		if rlen == 0.0:
			rlen = 1.0
		rx /= rlen
		rz /= rlen
		var dx := ax + rx * cos(a) * r
		var dy := ay + sin(a) * r
		var dz := az + rz * cos(a) * r
		var l := _hyp3(dx, dy, dz)
		dx /= l
		dy /= l
		dz /= l
		if w.proj:
			var q := Proj.new()
			q.x = m.x + dx * 0.4
			q.y = m.y + dy * 0.4
			q.z = m.z + dz * 0.4
			q.dx = dx
			q.dy = dy
			q.dz = dz
			q.speed = w.speed
			q.w = w
			projs.append(q)
			pel.append(null)
			continue
		# pierce (snipers): a round that kills keeps flying, spending w.pierce x the victim's hp on the way through; anything that survives the hit stops it. The dead are skipped by the next cast.
		var hp: Dictionary
		var left := w.dmg
		var bodies := 0
		while true:
			var r2 := cast_ray(m.x, m.y, m.z, dx, dy, dz, w.range)
			var r2d := r2.d
			hp = {"x": m.x + dx * r2d, "y": m.y + dy * r2d, "z": m.z + dz * r2d, "kind": "target" if r2.target != null else ("world" if r2.hit_world else "none"), "nx": -dx, "ny": -dy, "nz": -dz}
			if r2.target == null:
				break
			var T := r2.target
			var fall := clampf(1.0 - (r2d - 10.0) / 30.0, 0.3, 1.0) if w.pellets > 1 else 1.0
			var before := T.hp
			var amt := left * fall
			damage(T, amt, P, 0.25 if w.pellets > 1 else 0.5, hp)
			if w.pierce == 0.0 or not T.dead:
				break
			bodies += 1
			if bodies >= Weapons.PIERCE_MAX:
				break
			left -= before / fall * w.pierce
			if left < Weapons.PIERCE_MIN:
				break
		if hp.kind == "world" and on_world_shot.is_valid():          # (a vehicle's body: vehicles/vehicles.js)
			on_world_shot.call(hp, left)
		pel.append(hp)
	events.append({"t": "shot", "i": cur, "id": w.id, "left": int(ammo[cur]), "pellets": pel, "mx": m.x, "my": m.y, "mz": m.z, "dirx": ax, "diry": ay, "dirz": az})


# ======================= arena prototype weapons: Saw-Loop (ricochet disc) and Moon Yoke (gravity sling) =======================
## outward surface normal near a point that is just inside geometry: sums the free directions around it
func _normal_at(x: float, y: float, z: float, dx: float, dy: float, dz: float) -> Vector3:
	var W := world
	var e := 0.16
	var nx := 0.0
	var ny := 0.0
	var nz := 0.0
	for ix in range(-1, 2):
		for iy in range(-1, 2):
			for iz in range(-1, 2):
				if ix == 0 and iy == 0 and iz == 0:
					continue
				var l := _hyp3(ix, iy, iz)
				var px := x + ix * e
				var py := y + iy * e
				var pz := z + iz * e
				if py > _floor0(W, px, pz) + 0.03 and not W.point_solid(px, py, pz):
					nx += ix / l
					ny += iy / l
					nz += iz / l
	var ln := _hyp3(nx, ny, nz)
	if ln < 0.2:
		return Vector3(-dx, -dy, -dz)
	return Vector3(nx / ln, ny / ln, nz / ln)


## first world surface along a ray (floor plane included): { d, nx, ny, nz } or null
func _world_hit(ox: float, oy: float, oz: float, dx: float, dy: float, dz: float, max_d: float) -> WorldHit:
	var W := world
	var d := W.ray_clear(ox, oy, oz, dx, dy, dz, max_d, 0.01)
	var hit := d < max_d - 0.011
	var n: Variant = null
	if dy < -1e-4:
		var tf := (oy - _floor0(W, ox, oz) - 0.06) / -dy
		if tf >= 0.0 and tf < (d if hit else max_d):
			d = tf
			hit = true
			n = Vector3.UP
	if not hit:
		return null
	if n == null:
		n = _normal_at(ox + dx * (d + 0.07), oy + dy * (d + 0.07), oz + dz * (d + 0.07), dx, dy, dz)
	var out := WorldHit.new()
	var nv: Vector3 = n
	out.d = d
	out.nx = nv.x
	out.ny = nv.y
	out.nz = nv.z
	return out


## aiming guide for the Saw-Loop: the path to the first surface and the first bounce off it
func _saw_guide(m: Vector3, ax: float, ay: float, az: float) -> void:
	var r1 := cast_ray(m.x, m.y, m.z, ax, ay, az, 60.0)
	var r1d := r1.d
	var r1_target := r1.target != null
	var wh := _world_hit(m.x, m.y, m.z, ax, ay, az, 60.0)
	var g := SawGuide.new()
	g.pts.append(m)
	if r1_target and (wh == null or r1d <= wh.d + 0.05):
		g.pts.append(Vector3(m.x + ax * r1d, m.y + ay * r1d, m.z + az * r1d))
		g.target = true
		saw_guide = g
		return
	if wh == null:
		g.pts.append(Vector3(m.x + ax * 40.0, m.y + ay * 40.0, m.z + az * 40.0))
		saw_guide = g
		return
	var hx := m.x + ax * wh.d
	var hy := m.y + ay * wh.d
	var hz := m.z + az * wh.d
	var dot := ax * wh.nx + ay * wh.ny + az * wh.nz
	g.pts.append(Vector3(hx, hy, hz))
	g.n = Vector3(wh.nx, wh.ny, wh.nz)
	var rx := ax - 2.0 * dot * wh.nx
	var ry := ay - 2.0 * dot * wh.ny
	var rz := az - 2.0 * dot * wh.nz
	var sx := hx + wh.nx * 0.12
	var sy := hy + wh.ny * 0.12
	var sz := hz + wh.nz * 0.12
	var w2 := _world_hit(sx, sy, sz, rx, ry, rz, 14.0)
	var l2 := w2.d if w2 != null else 14.0
	g.pts.append(Vector3(sx + rx * l2, sy + ry * l2, sz + rz * l2))
	saw_guide = g


func _saw_launch(w: Weapons.Def, P: Player, m: Vector3, ax: float, ay: float, az: float) -> void:
	var i := cur
	cool = 1.0 / w.rate
	buffer = 0.0
	ammo[i] -= 1.0
	if ammo[i] <= 0.0:
		auto_rl = 0.3
	aim_t = maxf(Config.aim_hold, minf(1.0 / w.rate + Config.aim_hold_semi, Config.aim_hold_max))
	P.recoil = minf(1.6, P.recoil + w.kick)
	var q := Saw.new()
	q.x = m.x + ax * 0.5
	q.y = m.y + ay * 0.5
	q.z = m.z + az * 0.5
	q.vx = ax
	q.vy = ay
	q.vz = az
	q.speed = Weapons.SAW_SPEED0
	q.ox = m.x
	q.oz = m.z
	q.idx = i
	_gid += 1
	q.id = _gid
	saws.append(q)
	events.append({"t": "shot", "i": i, "id": w.id, "left": int(ammo[i]), "pellets": [], "mx": m.x, "my": m.y, "mz": m.z, "dirx": ax, "diry": ay, "dirz": az})


## after a hit the disc skips on to the nearest other enemy it can see (cooldown-gated so it never re-hits the same one at once)
func _saw_seek(q: Saw, from: Target) -> bool:
	var best: Target = null
	var bd := 1e9
	for O: Target in targets:
		if O == from or O.dead or O.npc or not O.robot or float(q.hit.get(O.id, -1.0)) > q.t:
			continue
		var dx := O.x - q.x
		var dz := O.z - q.z
		var d := U.hyp(dx, dz)
		if d > Weapons.SAW_SEEK_R or d < 0.8:
			continue
		var dy := O.y + 1.1 - q.y
		var L := _hyp3(dx, dy, dz)
		if _world_hit(q.x, q.y, q.z, dx / L, dy / L, dz / L, L - 0.6) != null:     # a wall is in the way
			continue
		if d < bd:
			bd = d
			best = O
	if best == null:
		return false
	var dx := best.x - q.x
	var dy := best.y + 1.1 - q.y
	var dz := best.z - q.z
	var L := _hyp3(dx, dy, dz)
	if L == 0.0:
		L = 1.0
	q.vx = dx / L
	q.vy = dy / L
	q.vz = dz / L
	q.bounces += 1
	q.speed = minf(Weapons.SAW_SPEED_MAX, q.speed * Weapons.SAW_GAIN)
	events.append({"t": "saw_bounce", "id": q.id, "x": q.x, "y": q.y, "z": q.z, "nx": 0.0, "ny": 1.0, "nz": 0.0, "n": q.bounces, "speed": q.speed})
	return true


func _saw_step(q: Saw, dt: float, P: Player) -> void:
	q.t += dt
	if q.t > Weapons.SAW_LIFE:
		q.gone = true
		events.append({"t": "saw_lost", "id": q.id, "x": q.x, "y": q.y, "z": q.z})
		return
	if q.state == "out" and (q.bounces >= Weapons.SAW_MAX_BOUNCE or q.t > 5.0 or U.hyp(q.x - q.ox, q.z - q.oz) > 36.0):
		q.state = "return"
		events.append({"t": "saw_return", "id": q.id, "x": q.x, "y": q.y, "z": q.z})
	if q.state == "return" and not P.dead:            # curves back toward the player's chest
		var tx := P.x - q.x
		var ty := P.y + 1.2 - q.y
		var tz := P.z - q.z
		var tl := _hyp3(tx, ty, tz)
		if tl == 0.0:
			tl = 1.0
		var k := minf(1.0, Weapons.SAW_TURN * dt)
		var nx := q.vx + (tx / tl - q.vx) * k
		var ny := q.vy + (ty / tl - q.vy) * k
		var nz := q.vz + (tz / tl - q.vz) * k
		var nl := _hyp3(nx, ny, nz)
		if nl == 0.0:
			nl = 1.0
		q.vx = nx / nl
		q.vy = ny / nl
		q.vz = nz / nl
		q.speed += (Weapons.SAW_RET_SPEED - q.speed) * minf(1.0, 3.0 * dt)
		if tl < Weapons.SAW_CATCH_R:                   # caught: that shot's ammo comes back
			q.gone = true
			var w := Weapons.WEAPONS[q.idx]
			if not q.refunded:
				q.refunded = true
				if ammo[q.idx] < w.mag_size:
					ammo[q.idx] += 1.0
				elif ammo[q.idx] + reserve[q.idx] < w.max:
					reserve[q.idx] += 1.0
			events.append({"t": "saw_catch", "id": q.id, "x": q.x, "y": q.y, "z": q.z})
			return
	var left := q.speed * dt
	while left > 1e-4 and not q.gone:
		var st := minf(0.35, left)
		left -= st
		var wh := _world_hit(q.x, q.y, q.z, q.vx, q.vy, q.vz, st + Weapons.SAW_R * 0.5)
		if wh != null and wh.d < st + Weapons.SAW_R * 0.5 - 0.011:
			var go := maxf(0.0, wh.d - Weapons.SAW_R * 0.45)
			q.x += q.vx * go
			q.y += q.vy * go
			q.z += q.vz * go
			var dot := q.vx * wh.nx + q.vy * wh.ny + q.vz * wh.nz
			if dot < 0.0:
				q.vx -= 2.0 * dot * wh.nx
				q.vy -= 2.0 * dot * wh.ny
				q.vz -= 2.0 * dot * wh.nz
				var vl := _hyp3(q.vx, q.vy, q.vz)
				if vl == 0.0:
					vl = 1.0
				q.vx /= vl
				q.vy /= vl
				q.vz /= vl
				q.bounces += 1
				q.speed = minf(Weapons.SAW_SPEED_MAX, q.speed * Weapons.SAW_GAIN)
				q.x += wh.nx * 0.09
				q.y += wh.ny * 0.09
				q.z += wh.nz * 0.09
				events.append({"t": "saw_bounce", "id": q.id, "x": q.x, "y": q.y, "z": q.z, "nx": wh.nx, "ny": wh.ny, "nz": wh.nz, "n": q.bounces, "speed": q.speed})
			else:
				q.x += q.vx * st
				q.y += q.vy * st
				q.z += q.vz * st
		else:
			q.x += q.vx * st
			q.y += q.vy * st
			q.z += q.vz * st
		# enemies: light ones are sliced through, heavy armour makes the disc bounce off
		for T: Target in targets:
			if T.dead or T.npc:
				continue
			var dx := q.x - T.x
			var dz := q.z - T.z
			var d := U.hyp(dx, dz)
			if d > T.r + Weapons.SAW_R or q.y < T.y - 0.25 or q.y > T.y + T.h + 0.25:
				continue
			if float(q.hit.get(T.id, -1.0)) > q.t:
				continue
			q.hit[T.id] = q.t + Weapons.SAW_HIT_CD
			var dmg := minf(Weapons.SAW_DMG_MAX, Weapons.SAW_DMG0 * (1.0 + Weapons.SAW_DMG_GAIN * q.bounces))
			var pt := {"x": q.x, "y": q.y, "z": q.z, "kind": "target", "nx": -q.vx, "ny": -q.vy, "nz": -q.vz}
			if T.heavy:
				var l := d if d != 0.0 else 1.0
				var nx := dx / l
				var nz := dz / l
				var dot := q.vx * nx + q.vz * nz
				if dot < 0.0:
					q.vx -= 2.0 * dot * nx
					q.vz -= 2.0 * dot * nz
					var vl := _hyp3(q.vx, q.vy, q.vz)
					if vl == 0.0:
						vl = 1.0
					q.vx /= vl
					q.vy /= vl
					q.vz /= vl
					q.bounces += 1
					q.speed = minf(Weapons.SAW_SPEED_MAX, q.speed * Weapons.SAW_GAIN)
				damage(T, dmg * Weapons.SAW_HEAVY_DMG, q, 0.4, pt)
				events.append({"t": "saw_clang", "id": q.id, "x": q.x, "y": q.y, "z": q.z, "nx": nx, "ny": 0.0, "nz": nz})
			else:
				damage(T, dmg, q, 1.2, pt)
				q.speed *= Weapons.SAW_SLICE
				events.append({"t": "saw_slice", "id": q.id, "x": q.x, "y": q.y, "z": q.z, "kill": T.dead})
			if q.state == "out":                       # ricochet on to the next enemy
				_saw_seek(q, T)


# ---- Electranator: hold to fire a short chain-lightning beam (drains the charge); the charge refills by itself once you let go ----
func _arc_off() -> void:
	var A := arc
	if A.on:
		events.append({"t": "arc_stop"})
	A.on = false
	A.pts.clear()
	A.hits.clear()
	A.t = 0.0


## an Electranator that is on the wheel but not in hand keeps recharging
func _arc_regen(dt: float) -> void:
	for k: int in owned:
		var x := Weapons.WEAPONS[k]
		if x.special == "arc" and k != cur:
			ammo[k] = minf(x.mag_size, ammo[k] + Weapons.ARC_REGEN * dt)


func _arc_step(dt: float, P: Player, w: Weapons.Def, m: Vector3, ax: float, ay: float, az: float, fire: Inp.Btn, sl: bool) -> void:
	var A := arc
	var i := cur
	var can := P.mode == &"normal" and not sl and rl == null and not P.dead
	if A.spent and ammo[i] >= w.mag_size * Weapons.ARC_RESTART:   # burnt out: wait for a bit of charge before it fires again
		A.spent = false
	var want := can and fire.held and not A.spent and ammo[i] > 0.0
	if not want:
		if can and fire.pressed and A.spent:
			events.append({"t": "empty"})
		_arc_off()
		A.idle += dt
		if A.idle > Weapons.ARC_REGEN_DELAY:
			ammo[i] = minf(w.mag_size, ammo[i] + Weapons.ARC_REGEN * dt)
		return
	if not A.on:
		A.on = true
		A.t = Weapons.ARC_TICK * 0.5
		events.append({"t": "arc_start"})
	A.idle = 0.0
	aim_t = maxf(aim_t, 0.3)
	bloom = 0.0
	ammo[i] = maxf(0.0, ammo[i] - Weapons.ARC_DRAIN * dt)
	_arc_beam(m, ax, ay, az)
	A.t += dt
	while A.t >= Weapons.ARC_TICK:
		A.t -= Weapons.ARC_TICK
		_arc_zap(P)
	if ammo[i] <= 0.0:
		ammo[i] = 0.0
		A.spent = true
		_arc_off()
		events.append({"t": "arc_burnout"})


func _arc_pt(T: Target) -> Vector3:
	return Vector3(T.x, T.y + T.h * 0.55, T.z)


## picks the target nearest the aim line (short range), then jumps to the 2 nearest others in sight: pts = path of the beam, hits = who gets zapped
func _arc_beam(m: Vector3, ax: float, ay: float, az: float) -> void:
	var A := arc
	var W := world
	var R := Weapons.ARC_RANGE
	var pts := A.pts
	var hits := A.hits
	var wall := W.ray_clear(m.x, m.y, m.z, ax, ay, az, R, 0.01)
	var T0: Target = null
	var best := 1e9
	for T: Target in targets:
		if T.dead:
			continue
		var cx := T.x - m.x
		var cy := T.y + T.h * 0.55 - m.y
		var cz := T.z - m.z
		var al := cx * ax + cy * ay + cz * az
		if al < 0.2 or al - T.r > minf(wall, R):      # behind us, out of range or behind a wall
			continue
		var pd := _hyp3(cx - ax * al, cy - ay * al, cz - az * al)
		if pd > T.r + 0.35 + al * Weapons.ARC_CONE:
			continue
		var sc := pd + al * 0.04
		if sc < best:
			best = sc
			T0 = T
	pts.clear()
	hits.clear()
	pts.append(m)
	A.wall = false
	if T0 == null:
		var d := minf(wall, R)
		pts.append(Vector3(m.x + ax * d, m.y + ay * d, m.z + az * d))
		A.wall = wall < R - 0.05
		return
	hits.append(T0)
	pts.append(_arc_pt(T0))
	for _c in Weapons.ARC_CHAINS:
		var f := pts[pts.size() - 1]
		var nx: Target = null
		var nd := Weapons.ARC_CHAIN_R
		for T: Target in targets:
			if T.dead or hits.has(T):
				continue
			var tp := _arc_pt(T)
			var d := f.distance_to(tp)
			if d >= nd or d < 1e-3:
				continue
			if W.ray_clear(f.x, f.y, f.z, (tp.x - f.x) / d, (tp.y - f.y) / d, (tp.z - f.z) / d, d, 0.01) < d - 0.4:   # a wall in between stops the jump
				continue
			nd = d
			nx = T
		if nx == null:
			break
		hits.append(nx)
		pts.append(_arc_pt(nx))


func _arc_zap(P: Player) -> void:
	var A := arc
	var base := Weapons.ARC_DPS * Weapons.ARC_TICK
	var k := 0
	for T: Target in A.hits.duplicate():
		if not T.dead:
			damage(T, base * (1.0 if k == 0 else Weapons.ARC_CHAIN_DMG), P, 0.0)
			events.append({"t": "arc_zap", "x": T.x, "y": T.y + T.h * 0.55, "z": T.z, "k": k})
		k += 1
	if A.hits.is_empty() and A.wall and A.pts.size() > 1:
		var e := A.pts[1]
		events.append({"t": "arc_zap", "x": e.x, "y": e.y, "z": e.z, "k": -1})


# ---- Bellows Beast: one sonic blast down the aim line. It pierces every enemy in a lane that widens with distance, stops at the first wall (or the floor),
#      and throws each enemy it hits out sideways, so a gap opens through the crowd. Damage fades with distance; heavy enemies are staggered but barely move. ----
func _bellows_fire(w: Weapons.Def, P: Player, m: Vector3, ax: float, ay: float, az: float) -> void:
	var i := cur
	var W := world
	cool = 1.0 / w.rate
	buffer = 0.0
	ammo[i] -= 1.0
	if ammo[i] <= 0.0:
		auto_rl = 0.3
	aim_t = maxf(Config.aim_hold, 0.6)
	P.recoil = minf(1.6, P.recoil + w.kick)
	var L := minf(Weapons.BELL_RANGE, W.ray_clear(m.x, m.y, m.z, ax, ay, az, Weapons.BELL_RANGE, 0.01))
	var stopped := L < Weapons.BELL_RANGE - 0.05
	if ay < -1e-4:                                    # aimed at the ground: the wave dies there
		var tf := (m.y - _floor0(W, m.x, m.z) - 0.06) / -ay
		if tf < L:
			L = maxf(0.5, tf)
			stopped = true
	var fl := U.hyp(ax, az)                           # flat forward and the sideways axis
	var fx := ax / fl if fl > 1e-3 else 0.0
	var fz := az / fl if fl > 1e-3 else 1.0
	var px := -fz
	var pz := fx
	var found: Array = []
	for T: Target in targets:
		if T.dead:
			continue
		var cx := T.x - m.x
		var cy := T.y + T.h * 0.5 - m.y
		var cz := T.z - m.z
		var al := cx * ax + cy * ay + cz * az
		if al < 0.3 or al - T.r > L:
			continue
		var rx := cx - ax * al
		var ry := cy - ay * al
		var rz := cz - az * al
		var ryc := U.signf0(ry) * maxf(0.0, absf(ry) - T.h * 0.5)     # a tall enemy is hit anywhere along its height
		if _hyp3(rx, ryc, rz) > Weapons.BELL_W0 + (Weapons.BELL_W1 - Weapons.BELL_W0) * (al / Weapons.BELL_RANGE) + T.r:
			continue
		found.append([T, al, rx, rz])
	found.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) < float(b[1]))
	var side := 1.0 if randf() < 0.5 else -1.0
	var hits: Array = []
	for f: Array in found:
		var T: Target = f[0]
		var al: float = f[1]
		var frx: float = f[2]
		var frz: float = f[3]
		var ll := U.hyp(frx, frz)
		var lx: float
		var lz: float
		if ll > 0.25:
			lx = frx / ll
			lz = frz / ll
		else:                                          # dead centre: alternate left / right so the crowd parts both ways
			side = -side
			lx = px * side
			lz = pz * side
		var ux := lx * 0.85 + fx * Weapons.BELL_FWD
		var uz := lz * 0.85 + fz * Weapons.BELL_FWD
		var ul := U.hyp(ux, uz)
		if ul == 0.0:
			ul = 1.0
		ux /= ul
		uz /= ul
		var heavy := T.heavy
		var dmg := w.dmg * (1.0 - Weapons.BELL_FALLOFF * al / Weapons.BELL_RANGE)
		damage(T, dmg, Vector3(T.x - ux, T.y, T.z - uz), (Weapons.BELL_KB * (Weapons.BELL_KB_HEAVY if heavy else 1.0)) if T.robot else Weapons.BELL_KB_PLAIN,
			{"x": T.x, "y": T.y + T.h * 0.5, "z": T.z, "kind": "target", "nx": -ax, "ny": 0.0, "nz": -az})
		if T.robot and not T.dead:
			var e := Weapons.BELL_PUSH * (Weapons.BELL_KB_HEAVY if heavy else 1.0)
			T.kvx += ux * e
			T.kvz += uz * e
		hits.append(T.x)
		hits.append(T.y + T.h * 0.5)
		hits.append(T.z)
	events.append({"t": "shot", "i": i, "id": w.id, "left": int(ammo[i]), "pellets": [], "mx": m.x, "my": m.y, "mz": m.z, "dirx": ax, "diry": ay, "dirz": az})
	events.append({"t": "bellows_blast", "x": m.x, "y": m.y, "z": m.z, "dx": ax, "dy": ay, "dz": az, "len": L, "wall": stopped, "ex": m.x + ax * L, "ey": m.y + ay * L, "ez": m.z + az * L, "hits": hits})


# ---- Moon Yoke: hold to gather rubble (the mass grows), release to sling it ----
func _yoke_hold(dt: float, P: Player, w: Weapons.Def, m: Vector3, ax: float, ay: float, az: float, fire: Inp.Btn, sl: bool) -> void:
	var Y := yoke
	var i := cur
	var can := P.mode == &"normal" and not sl and rl == null
	if not can:
		if Y.holding:
			events.append({"t": "yoke_fizzle"})
		Y.holding = false
		Y.charge = 0.0
		return
	if Y.holding:
		if fire.held and ammo[i] > 0.0:
			Y.charge = minf(1.0, Y.charge + dt / Weapons.YOKE_CHARGE_TIME)
		else:
			if Y.charge >= Weapons.YOKE_MIN_CHARGE:
				_yoke_launch(w, P, m, ax, ay, az, Y.charge)
			else:
				events.append({"t": "yoke_fizzle"})
			Y.holding = false
			Y.charge = 0.0
		aim_t = maxf(aim_t, 0.3)
	elif cool <= 0.0 and (fire.pressed or buffer > 0.0):
		if ammo[i] <= 0.0:
			if Config.auto_reload != 0 and reserve[i] > 0.0 and start_reload(P):
				pass                                   # dry press starts the reload
			elif fire.pressed:
				events.append({"t": "empty"})
				cool = 0.25
			buffer = 0.0
		else:
			Y.holding = true
			Y.charge = 0.0
			buffer = 0.0
			events.append({"t": "yoke_start"})


func _yoke_launch(w: Weapons.Def, P: Player, m: Vector3, ax: float, ay: float, az: float, ch: float) -> void:
	var i := cur
	ammo[i] -= 1.0
	if ammo[i] <= 0.0:
		auto_rl = 0.3
	cool = 1.0 / w.rate
	aim_t = maxf(Config.aim_hold, 0.5)
	P.recoil = minf(1.6, P.recoil + w.kick * (0.6 + ch))
	var sp := Weapons.YOKE_SPEED0 + (Weapons.YOKE_SPEED1 - Weapons.YOKE_SPEED0) * ch
	var ap := aim_point
	var dx := ap.x - m.x
	var dz := ap.z - m.z
	var dy := ap.y - m.y
	var dist := _hyp3(dx, dy, dz)
	if dist == 0.0:
		dist = 1.0
	var tt := dist / sp
	var rise := minf(dist * 0.6, 0.5 * Weapons.YOKE_GRAV * tt * tt)   # lob: aim above the crosshair so the stone lands on it
	var vx := dx
	var vy := dy + rise
	var vz := dz
	var vl := _hyp3(vx, vy, vz)
	if vl == 0.0:
		vl = 1.0
	vx = vx / vl * sp
	vy = vy / vl * sp
	vz = vz / vl * sp
	var q := Rock.new()
	q.x = m.x + ax * 0.6
	q.y = m.y + ay * 0.6
	q.z = m.z + az * 0.6
	q.vx = vx
	q.vy = vy
	q.vz = vz
	q.ch = ch
	_gid += 1
	q.id = _gid
	rocks.append(q)
	events.append({"t": "shot", "i": i, "id": w.id, "left": int(ammo[i]), "pellets": [], "mx": m.x, "my": m.y, "mz": m.z, "dirx": ax, "diry": ay, "dirz": az})
	events.append({"t": "yoke_launch", "ch": ch})


func _rock_step(q: Rock, dt: float) -> void:
	var W := world
	q.t += dt
	var left := _hyp3(q.vx, q.vy, q.vz) * dt
	var n := maxi(1, ceili(left / 0.3))
	var h := dt / n
	for _s in n:
		if q.gone:
			break
		q.vy -= Weapons.YOKE_GRAV * h
		var nx := q.x + q.vx * h
		var ny := q.y + q.vy * h
		var nz := q.z + q.vz * h
		var hit_t: Target = null
		var hit := W.point_solid(nx, ny, nz) or ny < (float(W.projectile_floor_at.call(nx, nz)) + 0.03 if W.projectile_floor_at.is_valid() else 0.05)
		var rad := 0.28 + 0.3 * q.ch
		for T: Target in targets:
			if not T.dead and not T.npc and U.hyp(nx - T.x, nz - T.z) < T.r + rad and ny > T.y - 0.1 and ny < T.y + T.h + 0.1:
				hit_t = T
				hit = true
				break
		q.x = nx
		q.y = ny
		q.z = nz
		if hit or q.t > 6.0:
			q.gone = true
			_yoke_impact(q, hit_t)


func _yoke_impact(q: Rock, T: Target) -> void:
	var ch := q.ch
	var dmg := Weapons.YOKE_DMG0 + (Weapons.YOKE_DMG1 - Weapons.YOKE_DMG0) * ch
	var gy := maxf(-INF if world.projectile_floor_at.is_valid() else 0.0, q.y)    # (a world with its own ground height: the stone lands where it hit, not at y 0)
	if T != null:
		damage(T, dmg, q, 7.0 + 8.0 * ch, {"x": q.x, "y": q.y, "z": q.z, "kind": "target", "nx": -q.vx, "ny": 0.3, "nz": -q.vz})
	else:
		for O: Target in targets:                      # near miss: the splash of the landing
			if O.dead or O.npc:
				continue
			var d := U.hyp(O.x - q.x, O.z - q.z)
			if d < Weapons.YOKE_SPLASH + ch * 1.2 and absf(O.y - gy) < 2.5:
				damage(O, dmg * 0.4 * (1.0 - d / (Weapons.YOKE_SPLASH + ch * 1.2)), q, 3.0, null)
	events.append({"t": "yoke_impact", "x": q.x, "y": gy, "z": q.z, "ch": ch, "direct": T != null})
	var wl := Well.new()
	wl.x = q.x
	wl.y = gy + 0.9
	wl.z = q.z
	wl.dur = Weapons.YOKE_WELL_T0 + (Weapons.YOKE_WELL_T1 - Weapons.YOKE_WELL_T0) * ch
	wl.r = Weapons.YOKE_WELL_R0 + (Weapons.YOKE_WELL_R1 - Weapons.YOKE_WELL_R0) * ch
	wl.ch = ch
	_gid += 1
	wl.id = _gid
	wells.append(wl)
	events.append({"t": "well_start", "x": q.x, "y": gy + 0.9, "z": q.z, "ch": ch})


## loose projectiles curve toward the centre: returns the new (unit) heading for something at (ox, oy, oz)
static func _bend(wl: Well, env: float, dt: float, ox: float, oy: float, oz: float, v: Vector3) -> Vector3:
	var dx := wl.x - ox
	var dy := wl.y - oy
	var dz := wl.z - oz
	var d := _hyp3(dx, dy, dz)
	if d > wl.r or d < 0.3:
		return v
	var k := (1.0 - d / wl.r) * env * Weapons.YOKE_BEND * dt
	var o := Vector3(v.x + dx / d * k, v.y + dy / d * k, v.z + dz / d * k)
	var l := o.length()
	return o / l if l != 0.0 else o


## everything the two weapons keep alive: discs, thrown stones, gravity wells (and their pull on enemies, loose projectiles and pickups)
func _gadget_physics(dt: float, P: Player) -> void:
	if not saws.is_empty():
		for q: Saw in saws:
			_saw_step(q, dt, P)
		saws = saws.filter(func(q: Saw) -> bool: return not q.gone)
	if not rocks.is_empty():
		for q: Rock in rocks:
			_rock_step(q, dt)
		rocks = rocks.filter(func(q: Rock) -> bool: return not q.gone)
	for p: Pickup in pickups:
		if not p.has_home:
			p.has_home = true
			p.hx = p.x
			p.hz = p.z
		p.pulled = false
	if not wells.is_empty():
		var bolts := enemies.bolts
		for wl: Well in wells:
			wl.t += dt
			var env := minf(1.0, wl.t / 0.3) * minf(1.0, (wl.dur - wl.t) / 0.7)
			if wl.t >= wl.dur:
				wl.gone = true
				events.append({"t": "well_end", "x": wl.x, "y": wl.y, "z": wl.z, "id": wl.id})
				continue
			for T: Target in targets:
				if T.dead or T.npc or not T.robot:
					continue
				var dx := wl.x - T.x
				var dz := wl.z - T.z
				var d := U.hyp(dx, dz)
				if d > wl.r or absf(T.y + 0.9 - wl.y) > 4.5:
					continue
				var k := pow(maxf(0.0, 1.0 - d / wl.r), 0.6) * env
				var res := Weapons.YOKE_HEAVY_PULL if T.heavy else 1.0
				var dl := d if d != 0.0 else 1.0
				var ux := dx / dl
				var uz := dz / dl
				if d > 0.6:
					T.kvx += ux * Weapons.YOKE_PULL * k * res * dt
					T.kvz += uz * Weapons.YOKE_PULL * k * res * dt
				var rb := T as Robot
				if T.heavy and rb.state != &"dead":          # heavy enemies resist the pull but lose their footing
					rb.poise += Weapons.YOKE_POISE * k * dt
					if rb.poise >= AI.poise_max and rb.state != &"stagger" and rb.immune_t <= 0.0 and rb.state != &"attack":
						rb.hit_heavy = true
						rb.poise = 0.0
						rb.slot = &""
						rb.hit_x = -ux
						rb.hit_z = -uz
						rb.set_(&"stagger")
			for q: Proj in projs:
				var v := _bend(wl, env, dt, q.x, q.y, q.z, Vector3(q.dx, q.dy, q.dz))
				q.dx = v.x
				q.dy = v.y
				q.dz = v.z
			for q: Enemies.Bolt in bolts:
				var v := _bend(wl, env, dt, q.x, q.y, q.z, Vector3(q.dx, q.dy, q.dz))
				q.dx = v.x
				q.dy = v.y
				q.dz = v.z
			for q: Saw in saws:
				var v := _bend(wl, env, dt, q.x, q.y, q.z, Vector3(q.vx, q.vy, q.vz))
				q.vx = v.x
				q.vy = v.y
				q.vz = v.z
			for p: Pickup in pickups:
				var dx := wl.x - p.hx
				var dz := wl.z - p.hz
				var d := U.hyp(dx, dz)
				if d > wl.r:
					continue
				var k := (1.0 - d / wl.r) * env
				p.x = p.hx + dx * k * 0.85
				p.z = p.hz + dz * k * 0.85
				p.pulled = true
		wells = wells.filter(func(wl: Well) -> bool: return not wl.gone)
	for p: Pickup in pickups:
		if not p.pulled and p.has_home:
			p.x += (p.hx - p.x) * minf(1.0, 6.0 * dt)
			p.z += (p.hz - p.z) * minf(1.0, 6.0 * dt)


func _explode(q: Proj) -> void:
	var R := q.w.radius
	events.append({"t": "explode", "x": q.x, "y": q.y, "z": q.z, "r": R})
	if on_blast.is_valid():                           # (vehicles in reach: vehicles/vehicles.js)
		on_blast.call(q.x, q.y, q.z, R, q.w.dmg)
	for T: Target in targets:
		if T.dead:
			continue
		var d := _hyp3(T.x - q.x, T.y + 0.9 - q.y, T.z - q.z)
		if d < R + T.r:
			damage(T, q.w.dmg * (1.0 - clampf(d / (R + T.r), 0.0, 1.0) * 0.5), q, 4.5 * (1.0 - d / (R + 1.0)))


func _punch_start(P: Player, s: int) -> void:
	var pn := punch
	pn.stage = s
	pn.t = 0.0
	pn.dur = PUNCH_DUR[s - 1]
	pn.queued = false
	pn.hit = false
	pn.side = "R" if s == 2 else "L"
	pn.face = P.yaw                                   # no aim assist: punches go the way he is facing
	events.append({"t": "punch", "stage": s})
	P.sprinting = false


## fire_pressed: JS fire.pressed (the caller already masks it, as the JS passes a { pressed: false } stand-in).
func _punch(dt: float, P: Player, fire_pressed: bool) -> void:
	var pn := punch
	pn.chain_t = maxf(0.0, pn.chain_t - dt)
	if fire_pressed and P.mode == &"normal":
		if pn.stage == 0:
			_punch_start(P, pn.last + 1 if (pn.chain_t > 0.0 and pn.last > 0 and pn.last < 3) else 1)
		elif pn.t / pn.dur > 0.2:
			pn.queued = true
	if pn.stage > 0:
		pn.t += dt
		var u := pn.t / pn.dur
		if not pn.hit and u >= PUNCH_HIT:
			pn.hit = true
			var s := pn.stage
			var fx := sin(pn.face)
			var fz := cos(pn.face)
			P.ix = P.ix + fx * PUNCH_LUNGE[s - 1]
			P.iz = P.iz + fz * PUNCH_LUNGE[s - 1]
			var hit_any := false
			for T: Target in targets:
				if T.dead:
					continue
				var dx := T.x - P.x
				var dz := T.z - P.z
				var d := U.hyp(dx, dz)
				if d < 2.0 + T.r and absf(U.wrap_angle(atan2(dx, dz) - pn.face)) < 1.0 and T.y < P.y + 1.8 and T.y + T.h > P.y:
					damage(T, PUNCH_DMG[s - 1], P, 7.0 if s == 3 else 3.0, null, true)
					hit_any = true
			events.append({"t": "punch_hit", "stage": s, "hit": hit_any})
		if pn.queued and u >= PUNCH_CHAIN and pn.stage < 3:
			_punch_start(P, pn.stage + 1)
		elif pn.t >= pn.dur:
			pn.last = pn.stage
			pn.chain_t = 0.32 if pn.stage < 3 else 0.0
			pn.stage = 0
			pn.queued = false
			if pn.last == 3:
				pn.last = 0
	P.punching = pn.stage > 0
	P.punch_face = pn.face if pn.stage > 0 else null
	P.punch_stage = pn.stage
	P.punch_u = clampf(pn.t / pn.dur, 0.0, 1.0) if pn.stage > 0 else 0.0
