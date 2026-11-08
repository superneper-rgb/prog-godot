class_name OmProp
extends Target
## OMNISPHERE: a thing you are meant to shoot that is not an enemy (JS a plain target object with prop: true): a fuel cell, a gate valve, a cuff seal, a bridge emitter. It stands still, it does not count as a body, Combat just takes its hp.


static func make(p_id: int, p_x: float, p_z: float, p_y: float, p_r: float, p_h: float, p_hp: float) -> OmProp:
	var t := OmProp.new(p_id, p_x, p_z, p_y, {"r": p_r, "h": p_h, "max": p_hp, "hp": p_hp, "w": 0.0})
	t.respawn_t = 1e9
	t.dead = true
	t.data["prop"] = true
	return t


## in the combat list if it is not there yet
static func arm(t: Target) -> void:
	if Game.combat != null and not Game.combat.targets.has(t):
		Game.combat.targets.append(t)
