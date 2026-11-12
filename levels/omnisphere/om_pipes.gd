class_name OmPipes
extends RefCounted
## OMNISPHERE's siphon conduit (JS levels/omnisphere/escape.js): the pipe you run along is a round tube of radius 3, but the JS gives it a flat 5 m ramp solid on top of it, so the player stood in the air up to 1.3 m above the drawn pipe near its edges.
## ENGINE DIFFERENCE (user asked for the edges to stop floating): each conduit piece's ramp keeps its length, its width, and its height along the middle (the crown, where the glowing line runs), but its top now falls away across the width like the tube does (World kind "pipe"). Pieces blowing out and the catch span moving use the same solids as before.

const CONDUIT_R := 3.0      # escape.js tube(s0, s1, 3, ...)


## Turn each conduit piece's ramp (vhId pc-N) into the crown of its pipe. Returns how many.
static func fit(world: World) -> int:
	var n := 0
	for s in world.solids:
		var ex: Variant = s.data.get("extra")
		if s.kind == "ramp" and ex is Dictionary and String((ex as Dictionary).get("vhId", "")).begins_with("pc-"):
			s.reshape("pipe", CONDUIT_R)
			n += 1
	return n
