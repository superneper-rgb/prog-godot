class_name MaintenanceSpider
extends Robot
## The warehouse's low maintenance-spider enemy (JS enemies/maintenance-spider.js): the native robot target, reusing its damage / target registration, melee slots, collision and knockback, with its own small brain: always hunts you, a short lunge bite.

var spider := true


func _init(w: World, p_id: int, p_x: float, p_z: float, p_y: float, o: Dictionary = {}) -> void:
	super._init(w, p_id, p_x, p_z, p_y, o)
	max = 30.0
	hp = 30.0
	r = 0.55
	h = 0.48
	name = "MAINTENANCE SPIDER"
	voice = 1.6
	mute = true


func _free(px: float, pz: float) -> bool:
	var gy := world.ground_height(px, pz, 0.45, y + 0.42)
	return is_finite(gy) and gy >= y - 0.65 and not world.blocked(px, pz, y, h, r, 0.42)


func update(dt: float, en: Enemies, P: Player) -> void:
	E = en
	t += dt
	state_t += dt
	flash = maxf(0.0, flash - dt * 6.0)
	flinch_t = maxf(0.0, flinch_t - dt)
	flinch_cd = maxf(0.0, flinch_cd - dt)
	immune_t = maxf(0.0, immune_t - dt)
	bcast_cd = maxf(0.0, bcast_cd - dt)
	if dead:
		dead_t += dt
		slot = &""
		return
	var dx := P.x - x
	var dz := P.z - z
	var d := U.hyp(dx, dz)
	var same_floor := absf(P.y - y) < 1.1
	known = Known.at(P.x, P.z)
	yaw = atan2(dx, dz)
	if P.dead:
		_go(dt, 0.0, 0.0, true)
		return
	if state == &"stagger":
		_go(dt, 0.0, 0.0, true)
		if state_t > 0.45:
			set_(&"pursue")
		return
	if state == &"windup":
		_go(dt, 0.0, 0.0, true)
		a_u = clampf(state_t / 0.35, 0.0, 1.0)
		if state_t >= 0.35:
			hit_done = false
			set_(&"attack")
		return
	if state == &"attack":
		_go(dt, yaw, 8.0 if state_t < 0.18 else 0.0, state_t >= 0.18)
		if not hit_done and state_t >= 0.1:
			hit_done = true
			var reach := U.hyp(P.x - x, P.z - z)
			var dd := d if d != 0.0 else 1.0
			if same_floor and reach < 1.5 and world.ray_clear(x, y + 0.3, z, dx / dd, 0.0, dz / dd, d, 0.04) >= d - 0.2:
				E.c.hurt_player(P, 10.0, x, z, "melee")
		if state_t > 0.3:
			slot = &""
			set_(&"recover")
		return
	if state == &"recover":
		_go(dt, 0.0, 0.0, true)
		if state_t > 1.1:
			set_(&"pursue")
		return
	if d < 1.8 and same_floor and E.slot_free(&"melee", self):
		atk = &"melee"
		slot = &"melee"
		set_(&"windup")
		return
	state = &"pursue"
	_go(dt, _steer(P.x, P.z), 5.6, d < 1.1)
