class_name SinewCrawler
extends Robot
## SINEWCRAWLER (JS enemies/sinew-crawler.js): a wall ambusher with chattering mandibles.
##   Clings  it lives on a wall (a cylinder: the spire's body) or a ceiling and crawls along it after you, staying above you.
##   Drop    when you stand below it, it hisses and pulls back (a red ring marks where it will land, it stops tracking 0.2 s before), then pounces: damage + shove where it lands.
##   Spit    from the wall it spits bile globs at range.
##   Ground  after a drop it hunts you on foot (fast bites) for a few seconds, then leaps back up to its wall.
## cling (set by the level) = { cx, cz, R, y, inside } a cylinder wall, or { ceiling: true, x, z, y, R }; left alone = a ceiling 4.5 m above where it spawned (dev level); null = ground only (hatchlings).
## The JS swaps its numbers into the shared AI table around each update; this keeps its own table.

const HP := 70.0
const SPEED := 6.4
const WALL_SPEED := 2.6
const DROP_RANGE := 7.5
const DROP_WIND := 0.7
const DROP_TIME := 0.55
const DROP_DMG := 16.0
const DROP_R := 1.9
const DROP_PUSH := 9.0
const BITE_DMG := 9.0
const BITE_WIND := 0.35
const SPIT_CD := 3.4
const SPIT_WIND := 0.6
const SPIT_DMG := 6.0
const SPIT_SPEED := 15.0
const SPIT_RANGE := 18.0
const GROUND_TIME := 6.5
const LEAP_WIND := 0.5
const C_R := 0.55
const C_H := 0.8

## JS this.flight
class Flight:
	var from: Vector3
	var to: Vector3
	var dur: float
	var peak: float


var cling: Variant = &"unset"
var mode := &"ground"
var mode_t := 0.0
var spit_cd := 0.0
var flight: Flight = null
var has_drop := false
var drop_target := Vector3.ZERO
var fvy := 0.0
var normal := Vector3.UP
var wa := 0.0
var wy := 0.0
var ox := 0.0
var oz := 0.0
var _is_set := false


static func _rnd(a: float, b: float) -> float:
	return a + randf() * (b - a)


func _init(w: World, p_id: int, p_x: float, p_z: float, p_y: float, o: Dictionary = {}) -> void:
	ai = AiTable.new()
	ai.r = C_R
	ai.h = C_H
	ai.walk = SPEED * 0.5
	ai.run = SPEED
	ai.accel = 22.0
	ai.alert_delay = 0.15
	ai.reach = 1.3
	ai.m_wind = BITE_WIND
	ai.m_act = 0.25
	ai.m_hit = 0.08
	ai.m_rec = 0.55
	ai.m_dmg = BITE_DMG
	ai.s_act = 9.0
	ai.flinch = 0.15
	ai.stagger = 0.5
	ai.stagger_immune = 1.5
	ai.poise_max = 60.0
	super._init(w, p_id, p_x, p_z, p_y, o)
	meat = true
	crawler = true
	name = "SINEWCRAWLER"
	bark_set = {}
	speech = false
	mute = true
	voice = 1.5 + randf() * 0.2
	r = C_R
	h = C_H
	max = HP
	hp = HP


func reset(first: bool) -> void:
	super.reset(first)
	mode = &"ground"
	mode_t = 0.0
	spit_cd = _rnd(1.0, 2.5)
	flight = null
	has_drop = false
	fvy = 0.0
	normal = Vector3.UP


## called by the level after its props are set (and lazily on the first update otherwise)
func setup() -> void:
	_is_set = true
	if cling is StringName:
		cling = {"ceiling": true, "x": x, "z": z, "y": hy + 4.5, "R": 5.0}
	if cling != null:
		var c: Dictionary = cling
		mode = &"wall"
		wa = 0.0 if c.get("ceiling", false) else atan2(x - float(c.get("cx", 0.0)), z - float(c.get("cz", 0.0)))
		wy = c["y"]
		ox = 0.0
		oz = 0.0
		_place()


func _place() -> void:
	var c: Dictionary = cling
	if c.get("ceiling", false):
		x = float(c["x"]) + ox
		z = float(c["z"]) + oz
		y = wy
		normal = Vector3(0.0, -1.0, 0.0)
		return
	var s := sin(wa)
	var co := cos(wa)
	var sg := -1.0 if c.get("inside", false) else 1.0
	x = float(c.get("cx", 0.0)) + s * float(c["R"])
	z = float(c.get("cz", 0.0)) + co * float(c["R"])
	y = wy
	normal = Vector3(s * sg, 0.0, co * sg)


func _go(dt: float, ang: float, speed: float, still: bool) -> void:
	if mode != &"ground":
		vx = 0.0
		vz = 0.0
		kvx = 0.0
		kvz = 0.0
		lvx = 0.0
		lvz = 0.0
		return
	super._go(dt, ang, speed, still)


func update(dt: float, en: Enemies, P: Player) -> void:
	E = en
	if not _is_set:
		setup()
	no_leash = mode != &"ground"
	mode_t += dt
	spit_cd -= dt
	if state == &"dead":                  # shot off its wall: it falls
		if mode != &"ground":
			fvy -= 22.0 * dt
			y += fvy * dt
			var g := world.ground_height(x, z, 0.3, y + 1.5)
			if g > -INF and y <= g:
				y = g
				mode = &"ground"
			elif y < hy - 40.0:
				mode = &"ground"
	elif P != null:
		if not P.dead and (state == &"idle" or state == &"return" or state == &"search"):      # JS aggro
			known = Known.at(P.x, P.z)
			seen_t = 0.0
			alert_why = "spawn"
			set_(&"pursue")
		if state == &"windup" and atk == &"drop" and state_t < DROP_WIND - 0.2:
			drop_target = Vector3(P.x, P.y if P.grounded else (drop_target.y if has_drop else P.y), P.z)
			has_drop = true
	ai.s_wind = DROP_WIND if atk == &"drop" else (LEAP_WIND if atk == &"leap" else SPIT_WIND)
	ai.s_rec = 0.85 if atk == &"drop" else 0.4
	super.update(dt, en, P)


func _pursue(dt: float, P: Player, dx: float, dz: float, dist: float, sees: bool) -> void:
	known = Known.at(P.x, P.z)
	seen_t = 0.0
	shot_cd = 1e9
	if mode == &"wall":
		var c: Dictionary = cling
		var hd := U.hyp(P.x - x, P.z - z)
		# crawl along the wall: towards your bearing, staying 3.5 - 5 m above you
		var want_y := clampf(P.y + 4.2, float(c["y"]) - 2.5, float(c["y"]) + 2.5)
		wy += clampf(want_y - wy, -WALL_SPEED * dt, WALL_SPEED * dt)
		if c.get("ceiling", false):
			var cr: float = c["R"]
			var tx := clampf(P.x - float(c["x"]), -cr, cr)
			var tz := clampf(P.z - float(c["z"]), -cr, cr)
			var sp := WALL_SPEED * dt
			ox += clampf(tx - ox, -sp, sp)
			oz += clampf(tz - oz, -sp, sp)
		else:
			var pa := atan2(P.x - float(c.get("cx", 0.0)), P.z - float(c.get("cz", 0.0)))
			var da := U.wrap_angle(pa - wa)
			wa += clampf(da, -WALL_SPEED / float(c["R"]) * dt, WALL_SPEED / float(c["R"]) * dt)
			lvz = WALL_SPEED if absf(da) > 0.05 else 0.0
		_place()
		_face(dt, atan2(dx, dz), 6.0)
		if not P.dead and P.grounded and hd < DROP_RANGE and P.y < y - 1.2 and mode_t > 0.8:
			_begin(&"drop", dist)
			return
		if not P.dead and sees and spit_cd <= 0.0 and dist < SPIT_RANGE:
			spit_cd = SPIT_CD * _rnd(0.85, 1.25)
			_begin(&"spit", dist)
			return
		return
	if cling != null and not (cling is StringName) and mode_t > GROUND_TIME:
		_begin(&"leap", dist)
		return
	super._pursue(dt, P, dx, dz, dist, sees)


func _begin(kind: StringName, dist: float) -> void:
	if kind == &"melee" or kind == &"shot":
		super._begin(kind, dist)
		return
	atk = kind
	hit_done = false
	shot_done = false
	slot = &""
	a_u = 0.0
	flight = null
	set_(&"windup")
	wob = 0.0
	E.push({"t": "robot_atk", "id": id, "kind": "sauce" if kind == &"spit" else ("whip" if kind == &"drop" else "wind"), "ph": "windup", "x": x, "y": y, "z": z})
	E.barks.say(self, "shoot" if kind == &"spit" else "alert")


func _attack(dt: float, P: Player, dx: float, dz: float, dist: float) -> void:
	if atk == &"spit":
		if not shot_done:
			shot_done = true
			var o := Vector3(x, y + 0.3, z) + normal * 0.4
			var d := Vector3(P.x - o.x, P.y + 1.0 - o.y, P.z - o.z)
			var L := d.length()
			if L == 0.0:
				L = 1.0
			E.fire(self, o.x, o.y, o.z, d.x / L, d.y / L, d.z / L, {"kind": "bile", "speed": SPIT_SPEED, "dmg": SPIT_DMG, "r": 0.25})
		if state_t > 0.2:
			set_(&"recover")
		return
	if atk == &"drop" or atk == &"leap":
		if flight == null:
			var to: Vector3
			if atk == &"drop":
				to = drop_target if has_drop else Vector3(P.x, P.y, P.z)
			else:
				var c: Dictionary = cling
				if c.get("ceiling", false):
					ox = 0.0
					oz = 0.0
				else:
					wa = atan2(x - float(c.get("cx", 0.0)), z - float(c.get("cz", 0.0)))
				wy = c["y"]
				var keep := Vector3(x, y, z)
				_place()
				to = Vector3(x, y, z)
				x = keep.x
				y = keep.y
				z = keep.z
			flight = Flight.new()
			flight.from = Vector3(x, y, z)
			flight.to = to
			flight.dur = DROP_TIME if atk == &"drop" else 0.7
			flight.peak = 0.7 if atk == &"drop" else 1.6
			mode = &"air"
		var f := flight
		var u := minf(1.0, state_t / f.dur)
		x = f.from.x + (f.to.x - f.from.x) * u
		z = f.from.z + (f.to.z - f.from.z) * u
		y = f.from.y + (f.to.y - f.from.y) * u + f.peak * 4.0 * u * (1.0 - u)
		if u >= 1.0:
			if atk == &"drop":
				mode = &"ground"
				mode_t = 0.0
				var g := world.ground_height(x, z, 0.4, y + 1.0)
				if g > -INF:
					y = g
				E.push({"t": "worm_slam", "x": x, "y": y, "z": z, "r": DROP_R})
				var hd := U.hyp(P.x - x, P.z - z)
				if not P.dead and hd < DROP_R and absf(P.y - y) < 1.6 and E.c.hurt_player(P, DROP_DMG, x, z, "melee"):
					var l := hd if hd != 0.0 else 1.0
					P.ix += (P.x - x) / l * DROP_PUSH
					P.iz += (P.z - z) / l * DROP_PUSH
			else:
				mode = &"wall"
				mode_t = 0.0
				_place()
			flight = null
			set_(&"recover")
		return
	super._attack(dt, P, dx, dz, dist)


func _die() -> void:
	super._die()
	respawn_t = 1e9
	fvy = 0.0
	if mode == &"air":
		mode = &"wall"
