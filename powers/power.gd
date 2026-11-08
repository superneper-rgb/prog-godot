class_name Power
extends Node
## IMPLANT POWERS (JS index.html POWER block): Z (pad: d-pad up) toggles power mode: the camera moves to the left shoulder, the left arm comes up and the gun is lowered; fire then casts the equipped implant from the left hand for its mana cost. Z again goes back to guns. The SWARM's wasps crawl over the left arm whenever it is equipped.
## Charged implants (catalogue mana_max, e.g. INCINERATE): holding fire charges (ch.k 0..1 over Fireball.CHARGE_TIME, capped by the mana you have), release casts; the cost runs from mana (a tap) to mana_max (a full charge) and is paid on release. Channelled implants (catalogue drain, e.g. FROST): on while fire is held (needs mana to start), draining drain mana per second (spray).

const MANA_MAX := 100.0
const MANA_REGEN := 5.0
const MANA_DELAY := 1.6


class Charge:
	var on := false
	var k := 0.0
	var cost := 0.0


var cd := 0.0
var spray := false
var hand := Vector3.ZERO
var dir := Vector3.ZERO
var ch := Charge.new()
var swarm_fx: WaspSwarm
var fire_fx: Fireball
var frost_fx: Frost
var _arm_r_for: Animator = null
var _arm_r := Vector2.ZERO


func _ready() -> void:
	name = "Power"
	swarm_fx = WaspSwarm.new()
	add_child(swarm_fx)
	fire_fx = Fireball.new()
	add_child(fire_fx)
	frost_fx = Frost.new()
	add_child(frost_fx)
	Game.combat.on_shatter = frost_fx.shatter


static func power_cost(pw: Dictionary, k: float) -> float:
	return lerpf(pw["mana"], pw["mana_max"], k) if pw.has("mana_max") else float(pw.get("mana", 0.0))


## the left hand's world position (falls back to beside the body without a rig) and the aim direction from it
func power_hand() -> Vector3:
	var P := Game.player
	var an := Game.animator
	var B: Variant = an.by_key.get(&"handL") if an != null else null
	if B != null:
		hand = an.bone_world_pos(B.bone)
	else:
		hand = Vector3(P.x + cos(P.yaw) * 0.3, P.y + 1.35, P.z - sin(P.yaw) * 0.3)
	dir = (Game.combat.aim_point - hand).normalized()
	return hand


func toggle() -> void:
	var P := Game.player
	if P.power_aim:
		P.power_aim = false
		Game.sfx.play("equip", {"heavy": 0.1})
		return
	var pw: Variant = Game.power_store.equipped()
	if pw == null:
		Game.sfx.play("deny")
		Game.hud.toast("NO IMPLANT EQUIPPED - VISIT DORBATELEPHINIUM IMPLANTS")
		return
	if P.dead or (Game.vehicles != null and Game.vehicles.driving):
		return
	P.power_aim = true
	Game.sfx.play("equip", {"heavy": 0.1})


## fire pressed in power mode: a tap power casts at once; a charged power starts charging (_cast_charged fires it on release)
func _cast_power() -> void:
	var pw: Variant = Game.power_store.equipped()
	if pw == null or cd > 0.0:
		return
	var P := Game.player
	if P.mana < float(pw.get("mana", 0.0)):
		Game.sfx.play("deny")
		Game.hud.mana_deny()
		cd = 0.3
		return
	if pw.has("mana_max"):
		ch.on = true
		ch.k = 0.0
		ch.cost = pw["mana"]
		return
	power_hand()
	if pw["id"] == "swarm":
		swarm_fx.cast(hand, Game.combat.aim_point)
	else:
		return
	P.mana -= float(pw.get("mana", 0.0))
	P.mana_t = MANA_DELAY
	cd = 0.45
	if Game.animator != null:
		Game.animator.cast_k = 1.0


## fire released after charging: pay for the charge reached and let it fly
func _cast_charged(pw: Dictionary) -> void:
	var k := ch.k
	ch.on = false
	power_hand()
	if pw["id"] == "incinerate":
		fire_fx.launch(hand, Game.combat.aim_point, k)
	else:
		return
	var P := Game.player
	P.mana = maxf(0.0, P.mana - power_cost(pw, k))
	P.mana_t = MANA_DELAY
	cd = 0.3
	if Game.animator != null:
		Game.animator.cast_k = 1.0 + k * 0.5


## how thick the left upper arm / forearm are (m, outer surface), measured once per character from the skinned meshes' bind pose (85th percentile of the distance from each bone's vertices to the bone line, widest mesh wins: a sleeve over the skin), so the wasps walk ON the arm.
func _arm_radii(an: Animator) -> Vector2:
	if _arm_r_for == an:
		return _arm_r
	_arm_r_for = an
	var r := [0.0, 0.0]
	var segs := [[&"upper_armL", &"forearmL"], [&"forearmL", &"handL"]]
	var sk := an.skel
	var ws := sk.global_basis.get_scale().x
	var walk: Array[Node] = [an.actor]
	while not walk.is_empty():
		var n: Node = walk.pop_back()
		walk.append_array(n.get_children())
		if not n is MeshInstance3D:
			continue
		var mi := n as MeshInstance3D
		if mi.mesh == null or mi.skin == null:
			continue
		var bind_of: Dictionary = {}
		for b in mi.skin.get_bind_count():
			var bi := mi.skin.get_bind_bone(b)
			bind_of[b] = bi if bi >= 0 else sk.find_bone(mi.skin.get_bind_name(b))
		for s in mi.mesh.get_surface_count():
			var arr: Array = mi.mesh.surface_get_arrays(s)
			var V: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var BI: Variant = arr[Mesh.ARRAY_BONES]
			var BW: Variant = arr[Mesh.ARRAY_WEIGHTS]
			if BI == null or (BI as PackedInt32Array).is_empty():
				continue
			var per: int = (BI as PackedInt32Array).size() / V.size()
			for k in 2:
				var ra: Variant = an.by_key.get(segs[k][0])
				var rb: Variant = an.by_key.get(segs[k][1])
				if ra == null or rb == null:
					continue
				var a: Vector3 = sk.get_bone_global_rest(ra.bone).origin
				var b: Vector3 = sk.get_bone_global_rest(rb.bone).origin
				var ds := PackedFloat32Array()
				for i in V.size():
					var best := -1
					var bw := 0.0
					for j in per:
						var w: float = BW[i * per + j]
						if w > bw:
							bw = w
							best = BI[i * per + j]
					if bind_of.get(best, -1) != ra.bone:
						continue
					ds.append(V[i].distance_to(Geometry3D.get_closest_point_to_segment(V[i], a, b)))
				if ds.size() > 8:
					ds.sort()
					r[k] = maxf(r[k], ds[floori(ds.size() * 0.85)] * ws)
	_arm_r = Vector2(r[0], r[1])
	return _arm_r


## every simulated frame (after the animator has posed the body): cooldown, mana refill, the wasps on the arm and the swarms. inp_on false: JS DEAD_INPUT.
func tick(dt: float, inp_on: bool, driving: bool) -> void:
	var P := Game.player
	cd = maxf(0.0, cd - dt)
	if P.dead or driving:
		P.power_aim = false
	var pw: Variant = Game.power_store.equipped()
	var can := P.power_aim and P.mode == &"normal"
	var b_fire := Inp.btn(&"fire")
	var pressed: bool = inp_on and b_fire.pressed
	var held: bool = inp_on and b_fire.held
	if ch.on and (not can or pw == null or not pw.has("mana_max")):      # power mode off / swapped implant: the charge is dropped, nothing paid
		ch.on = false
	if can and pressed and not ch.on and not (pw != null and pw.has("drain")):
		_cast_power()
	var spraying := false      # channelled implants (drain, e.g. FROST): on while fire is held and mana lasts
	if pw != null and pw.has("drain") and can:
		if pressed and P.mana < float(pw["mana"]):
			Game.sfx.play("deny")
			Game.hud.mana_deny()
		spraying = held and P.mana > 0.0 and (spray or P.mana >= float(pw["mana"]))
		if spraying:
			P.mana = maxf(0.0, P.mana - float(pw["drain"]) * dt)
			P.mana_t = MANA_DELAY
	spray = spraying
	if ch.on:      # charging: grows slowly, never past what the mana can pay for
		var k_max := clampf((P.mana - float(pw["mana"])) / maxf(1.0, float(pw["mana_max"]) - float(pw["mana"])), 0.0, 1.0)
		ch.k = minf(k_max, ch.k + dt / Fireball.CHARGE_TIME)
		ch.cost = power_cost(pw, ch.k)
		P.mana_t = MANA_DELAY
		if not held:
			_cast_charged(pw)
	P.mana_t -= dt
	if P.mana_t <= 0.0:
		P.mana = minf(P.max_mana, P.mana + MANA_REGEN * dt)
	var an := Game.animator
	var vis := an != null and an.actor.visible and P.power_aim
	var fire_on := vis and Game.power_store.is_equipped("incinerate")      # hand embers / cold air only while the arm is up (power mode)
	var frost_on := vis and Game.power_store.is_equipped("frost")
	if fire_on or frost_on:
		power_hand()
	fire_fx.update(dt, {"hand": hand, "dir": dir, "idle": true, "charging": ch.on, "k": ch.k} if fire_on else null)
	frost_fx.update(dt, {"hand": hand, "dir": dir, "idle": true, "spraying": spray} if frost_on else null)      # always ticked: chilled / frozen enemies thaw even after a swap
	var arm: Variant = null
	if an != null and Game.power_store.is_equipped("swarm") and an.actor.visible:
		var U_: Variant = an.by_key.get(&"upper_armL")
		var F_: Variant = an.by_key.get(&"forearmL")
		var H_: Variant = an.by_key.get(&"handL")
		if U_ != null and F_ != null and H_ != null:
			var R := _arm_radii(an)
			arm = {"agitated": P.power_aim, "S": an.bone_world_pos(U_.bone), "E": an.bone_world_pos(F_.bone), "H": an.bone_world_pos(H_.bone), "r1": R.x, "r2": R.y}
	swarm_fx.update(dt, arm)


## frozen powers go quiet (pause, menu, wheel)
func quiet() -> void:
	swarm_fx.quiet()
	fire_fx.quiet()
	frost_fx.quiet()


## a swarm riding an enemy of the old level would keep stinging / drawing there
func on_level_change() -> void:
	swarm_fx.clear()
