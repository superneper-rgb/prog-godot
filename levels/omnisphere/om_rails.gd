class_name OmRails
extends RefCounted
## OMNISPHERE's railings that the JS draws but never made solid: the route's decks (layout.js deck() `rails` with its `gaps`), the pad ring, the hall's two catwalks and the freight docks' edge (act2.js). Solid ones (summit.js rail(), escape.js landing and gallery) stay as they are.
## ENGINE DIFFERENCE (user asked for it): each rail run gets the same 1.1 m wall boxes the summit rails use (half-width .12, length + .1, from the deck up), with `no_cam`, so they stop feet, AI, shots and projectiles like the summit rails and can be vaulted (a jump clears 1.1 m), while the camera boom passes through. Gaps are the JS's: the stair mouths, the crevasse jump, the tram's section at Gamma, the docks bridge. Stair side rails (sloped), the chamber, bracket and gantry rails are left as drawn.

const H := 1.1
const HX := 0.12

## layout.js deck(x0, x1, z0, z1, top, { rails: 'nsew' (n = -z edge), gaps: [[side, a, b]] }): [x0, x1, z0, z1, top, sides, gaps]
const DECKS: Array = [
	[-8.0, 16.0, -41.0, -22.0, 8.0, "sw", [["s", -2.4, 2.4]]],
	[4.0, 30.0, -66.0, -44.0, 8.5, "es", [["s", 4.0, 16.0]]],
	[-16.0, 26.0, -84.0, -75.0, 13.0, "ne", []],
	[-36.6, -16.0, -78.0, -74.0, 13.0, "ns", []],
	[-64.0, -53.0, -82.0, -64.0, 12.96, "nw", []],
	[-162.0, -124.0, -62.0, -20.0, 18.0, "ns", [["n", -146.0, -138.0]]],
]


## One run of rail from a to b (x, z) at height y: a wall box like summit.js rail().
static func _seg(world: World, ax: float, az: float, bx: float, bz: float, y: float) -> World.Solid:
	var L := hypot(bx - ax, bz - az)
	if L < 0.01:
		return null
	return world.add({"kind": "box", "cx": (ax + bx) / 2.0, "cz": (az + bz) / 2.0, "hx": HX, "hz": L / 2.0 + 0.05, "top": y + H, "bottom": y, "tag": "rail", "yaw": atan2(bx - ax, bz - az), "no_cam": true})


static func hypot(a: float, b: float) -> float:
	return sqrt(a * a + b * b)


## a polyline of points (x, z) at one height
static func _line(world: World, pts: Array, y: float) -> void:
	for i in pts.size() - 1:
		_seg(world, float(pts[i][0]), float(pts[i][1]), float(pts[i + 1][0]), float(pts[i + 1][1]), y)


## JS layout.js railSides()
static func _deck(world: World, x0: float, x1: float, z0: float, z1: float, top: float, sides: String, gaps: Array) -> void:
	var e := 0.18
	var edge := {
		"n": [[x0 + e, z0 + e], [x1 - e, z0 + e]], "s": [[x0 + e, z1 - e], [x1 - e, z1 - e]],
		"w": [[x0 + e, z0 + e], [x0 + e, z1 - e]], "e": [[x1 - e, z0 + e], [x1 - e, z1 - e]]}
	for sd in sides:
		var pa: Array = (edge[sd] as Array)[0]
		var pb: Array = (edge[sd] as Array)[1]
		var along := sd == "n" or sd == "s"
		var lo: float = pa[0] if along else pa[1]
		var hi: float = pb[0] if along else pb[1]
		var cuts: Array = []
		for g: Array in gaps:
			if g[0] == sd:
				cuts.append([float(g[1]), float(g[2])])
		cuts.sort_custom(func(p: Array, q: Array) -> bool: return p[0] < q[0])
		var from := lo
		cuts.append([hi, hi])
		for c: Array in cuts:
			var to := minf(float(c[0]), hi)
			if to - from > 0.5:
				if along:
					_seg(world, from, float(pa[1]), to, float(pa[1]), top)
				else:
					_seg(world, float(pa[0]), from, float(pa[0]), to, top)
			from = maxf(from, float(c[1]))


static func build(world: World) -> int:
	var n := world.solids.size()
	for d: Array in DECKS:
		_deck(world, d[0], d[1], d[2], d[3], d[4], d[5], d[6])
	# the pad ring (layout.js: 31 points round r 9.75, open at the gangway)
	var ring: Array = []
	for i in 31:
		var a := -PI / 2.0 + 0.3 + float(i) / 30.0 * (TAU - 0.6)
		ring.append([cos(a) * 9.75, sin(a) * 9.75])
	_line(world, ring, 6.0)
	# the hall's catwalks (act2.js)
	_line(world, [[-234.0, -57.6], [-193.0, -57.6]], 26.0)
	_line(world, [[-234.0, -24.4], [-193.0, -24.4]], 26.0)
	# the freight docks' edge, open at the bridge (act2.js)
	_line(world, [[-239.8, -62.5], [-239.8, -121.8], [-204.5, -121.8]], 18.0)
	_line(world, [[-195.5, -121.8], [-170.2, -121.8], [-170.2, -62.5]], 18.0)
	return world.solids.size() - n


## The docks bridge's two side rails for one 12 m piece (centre z), a solid each so the collapse can drop them with the piece (om_escape.gd). New (user, 2026-11-10): the bridge had drawn rails with no collider, so you walked and shot through them.
static func bridge_rails(world: World, cz: float) -> Array[World.Solid]:
	var out: Array[World.Solid] = []
	for x: float in [-203.82, -196.18]:
		out.append(_seg(world, x, cz - 6.0, x, cz + 6.0, 18.0))
	return out
