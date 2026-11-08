class_name WhActors
extends RefCounted
## The warehouse's security (JS levels/warehouse/security.js + the wrappers navigation.js and entrances.js put on a robot): the JS swaps methods on each instance, so here each is a small subclass: robots, enforcers and mechs, spiders, drones. An arriving actor walks out of its alcove first; AI, firing and drone height corrections resume only after that, and it stays a normal damageable target.


## The arrival's walk: what entrances.js does to a robot's update.
static func arrival_tick(r: Robot, dt: float, speed: float, nx: float, nz: float) -> void:
	r.t += dt
	r.state_t += dt
	r.state = &"pursue"
	r.flash = maxf(0.0, r.flash - dt * 5.0)
	r.wob = maxf(0.0, r.wob - dt * 2.5)
	r.flinch_t = maxf(0.0, r.flinch_t - dt)
	r.flinch_cd = maxf(0.0, r.flinch_cd - dt)
	r.vx = nx * speed
	r.vz = nz * speed
	r.lvz = speed
	r.lvx = 0.0


class Bot:
	extends Robot
	var warehouse := true
	var warehouse_kind := "robot"
	var agent: WhNav.Agent = null
	var factory_arrival := false
	var factory_arrival_speed := 0.0
	var arrival_nx := 0.0
	var arrival_nz := 0.0

	func setup(kind: String, nav: WhNav) -> void:
		warehouse_kind = kind
		if kind == "guard" or kind == "mech":
			var big := kind == "mech"
			var scale := 1.6 if big else 1.3
			heavy = true
			visual_scale = scale
			max = 320.0 if big else 150.0
			hp = max
			r = 0.9 if big else 0.72
			h = 2.05 * scale
			name = "SECURITY MECH / PROTOTYPE" if big else "RESERVE ENFORCER"
		agent = WhNav.Agent.new(nav, self, kind)

	func update(dt: float, en: Enemies, P: Player) -> void:
		E = en
		if factory_arrival and not dead:
			WhActors.arrival_tick(self, dt, factory_arrival_speed, arrival_nx, arrival_nz)
			return
		if agent != null:
			agent.tick(dt)
		super.update(dt, en, P)

	func _free(px: float, pz: float) -> bool:
		if warehouse_kind == "guard" or warehouse_kind == "mech":
			return not world.blocked(px, pz, y, h, r, 0.42) and is_finite(world.ground_height(px, pz, r, y + 0.42))
		return super._free(px, pz)

	func _go(dt: float, ang: float, speed: float, still: bool) -> void:
		if warehouse_kind == "guard":
			speed *= 0.83
		if agent != null:
			super._go(dt, ang, agent.speed(speed), agent.still(still))
		else:
			super._go(dt, ang, speed, still)

	func _base_steer(tx: float, tz: float) -> float:
		return super._steer(tx, tz)

	func _steer(tx: float, tz: float) -> float:
		return agent.steer(tx, tz, _base_steer) if agent != null else super._steer(tx, tz)


class Spider:
	extends MaintenanceSpider
	var warehouse := true
	var warehouse_kind := "spider"
	var agent: WhNav.Agent = null
	var factory_arrival := false
	var factory_arrival_speed := 0.0
	var arrival_nx := 0.0
	var arrival_nz := 0.0

	func setup(_kind: String, nav: WhNav) -> void:
		agent = WhNav.Agent.new(nav, self, "spider")

	func update(dt: float, en: Enemies, P: Player) -> void:
		E = en
		if factory_arrival and not dead:
			WhActors.arrival_tick(self, dt, factory_arrival_speed, arrival_nx, arrival_nz)
			return
		if agent != null:
			agent.tick(dt)
		super.update(dt, en, P)

	func _go(dt: float, ang: float, speed: float, still: bool) -> void:
		if agent != null:
			super._go(dt, ang, agent.speed(speed), agent.still(still))
		else:
			super._go(dt, ang, speed, still)

	func _base_steer(tx: float, tz: float) -> float:
		return super._steer(tx, tz)

	func _steer(tx: float, tz: float) -> float:
		return agent.steer(tx, tz, _base_steer) if agent != null else super._steer(tx, tz)


class Flyer:
	extends Drone
	var warehouse := true
	var warehouse_kind := "drone"
	var warehouse_hover_floor := -INF
	var factory_arrival := false
	var factory_arrival_speed := 0.0
	var arrival_nx := 0.0
	var arrival_nz := 0.0

	func setup(_kind: String, _nav: WhNav) -> void:
		shot_damage = 4.0
		shot_windup = 0.95
		shot_cooldown = 6.0
		shot_gap = 0.22
		shot_recovery = 0.8
		lock_burst_aim = true
		recovery_strafe = 0.3

	func update(dt: float, en: Enemies, P: Player) -> void:
		E = en
		if factory_arrival and not dead:
			WhActors.arrival_tick(self, dt, factory_arrival_speed, arrival_nx, arrival_nz)
			return
		super.update(dt, en, P)

	## Native drones clamp floor height to zero. Basements need a floor-relative hover. A patrol over machinery must not dive to the recovery net whenever it crosses a gap. Other warehouse rooms retain floor-relative hovering.
	func _alt(dt: float) -> void:
		var fl := maxf(warehouse_hover_floor, world.ground_height(x, z, r, y + 0.2))
		if not is_finite(fl):
			return
		var want := fl + hover + sin(t * 1.7 + bob_ph) * 0.18
		vy += (clampf((want - y) * 2.2, -4.0, 4.0) - vy) * minf(1.0, 6.0 * dt)
		var ny := y + vy * dt
		if world.blocked(x, z, ny, h, r, 0.05):
			vy = 0.0
		else:
			y = maxf(fl + 0.6, ny)
