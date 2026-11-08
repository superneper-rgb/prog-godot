class_name Target
extends RefCounted
## One thing that can be shot: an upright cylinder in the combat target list (JS class Target). Targets are analytic, never physics
## bodies: Combat.cast_ray tests shapes against the list. Robots and drones extend this; the clerk and practice dummies are plain ones.

var id := 0
var x := 0.0
var z := 0.0
var y := 0.0
var r := 0.5
var h := 1.8
var max := 100.0          # max hp (JS T.max)
var hp := 100.0
var flash := 0.0
var dead := false
var respawn_t := 0.0
var kx := 0.0             # knockback offset of a plain target, decays
var kz := 0.0
var bx := 0.0             # the base point of its patrol sine
var bz := 0.0
var ax := 0.0             # patrol amplitude
var az := 0.0
var w := 1.0              # patrol rate
var ph := 0.0
var t := 0.0
var wob := 0.0
var face := 0.0

# optional in the JS (read with !!T.x there); plain fields here, all off by default
var robot := false        # AI enemy: ticked by Enemies, gets hurt()
var npc := false          # the clerk and friends: not an enemy, saws and blasts skip it
var crowd := false        # a crowd member (events carry this)
var boss := false
var heavy := false        # armoured: the saw bounces off, the flail shoves less
var frozen_t := 0.0       # FROST: a melee hit shatters a frozen enemy (powers/frost.gd)
var chill := 0.0          # FROST: chilled (0..1), everything it does runs slower
var chill_hold := 0.0     # no thawing while the spray is on it
var cold_dmg := 0.0       # cold damage banked and dealt in chunks
var shattered := false    # FROST: shattered, the body is gone
var actor_state: Object = null   # an AI clone's Player state: damage goes through Combat.actor_damage (JS T.actorState)
var kvx := 0.0            # knockback velocity (robots: Robot.reset owns it; on a plain target nothing reads it)
var kvz := 0.0
var data: Dictionary = {} # anything else a level attached (setpiece, foreman_part, dev, ...)


## JS new Target(id, x, z, y, o): o overrides any default by name, same as Object.assign (unknown names land in `data`).
func _init(p_id: int = 0, p_x: float = 0.0, p_z: float = 0.0, p_y: float = 0.0, o: Dictionary = {}) -> void:
	id = p_id
	x = p_x
	z = p_z
	y = p_y
	bx = p_x
	bz = p_z
	ph = randf() * 6.28
	if not o.is_empty():
		assign(o)


## JS Object.assign(this, o).
func assign(o: Dictionary) -> void:
	for k: String in o:
		if k in self:
			set(k, o[k])
		else:
			data[k] = o[k]


## AI reaction to a landed hit (robots override this: alert, flinch / stagger, broadcast to nearby robots, death). Combat.damage calls it only when `robot`.
## `from` is anything with x and z (the Player, a saw disc, a Vector3, a { x, y, z } Dictionary); pt is the hit point Dictionary or null.
func hurt(_amount: float, _from: Variant, _kb: float, _pt: Variant, _kill: bool) -> void:
	pass
