class_name PalaceRide
extends RefCounted
## A platform on the Pervert Palace site that carries whoever stands on it (levels/palace/palace_level.gd: crane B's beam bundle, the hoist cage, crane A's man-basket). Its node is drawn by
## palace_site.gd; here are its floor and walls as World solids that move with it, and the carry: whoever is on it when it moves (Prog, Sambo) moves with it, the way the other levels' lifts
## carry the player (levels/visiting_hours/vh_lift.gd). Walls named `gate` open and shut. The node can sway a little (its tilt is only drawn: the solids stay level).

var node: Node3D
var world: World
var pos := Vector3.ZERO           # the floor's top, at its middle
var hx := 1.0
var hz := 1.0
var floor_s: World.Solid
var walls: Array[Dictionary] = []      # {s, dx, dz, hx, hz, h, gate}
var tilt := Vector2.ZERO          # drawn sway (radians about x, z)


func _init(n: Node3D, w: World, p: Vector3, half: Vector2) -> void:
	node = n
	world = w
	pos = p
	hx = half.x
	hz = half.y
	floor_s = world.add({"kind": "box", "cx": p.x, "cz": p.z, "hx": hx, "hz": hz, "bottom": p.y - 0.18, "top": p.y, "tag": "ride", "no_cam": true})


## A wall standing on the floor: its middle (dx, dz) from the floor's middle, half sizes, height; a gate can be opened
func wall(dx: float, dz: float, whx: float, whz: float, h: float, gate: bool = false) -> void:
	var s := world.add({"kind": "box", "cx": pos.x + dx, "cz": pos.z + dz, "hx": whx, "hz": whz, "bottom": pos.y, "top": pos.y + h, "tag": "ride", "no_cam": true})
	walls.append({"s": s, "dx": dx, "dz": dz, "hx": whx, "hz": whz, "h": h, "gate": gate})


func set_gate(open: bool) -> void:
	for w: Dictionary in walls:
		if w.gate:
			(w.s as World.Solid).set_off(open)


## Is this point standing on it (feet height p.y)?
func on(x: float, y: float, z: float) -> bool:
	return absf(x - pos.x) < hx + 0.15 and absf(z - pos.z) < hz + 0.15 and y > pos.y - 0.45 and y < pos.y + 0.9


func player_on() -> bool:
	var P := Game.player
	return P != null and not P.dead and on(P.x, P.y, P.z)


## Move the floor's top to p: the solids follow, and Prog and Sambo come too if they are on it
func move_to(p: Vector3, sambo: PalaceSambo = null) -> void:
	var d := p - pos
	if d.length_squared() < 1e-12:
		_draw()
		return
	var P := Game.player
	if P != null and not P.dead and on(P.x, P.y, P.z):
		P.x += d.x
		P.y += d.y
		P.z += d.z
		if P.vy < 0.0 and d.y > 0.0:
			P.vy = 0.0
	if sambo != null and on(sambo.pos.x, sambo.pos.y, sambo.pos.z):
		sambo.pos += d
	pos = p
	floor_s.set_span(p.y - 0.18, p.y)
	floor_s.place(p.x, p.z)
	for w: Dictionary in walls:
		var s: World.Solid = w.s
		s.set_span(p.y, p.y + float(w.h))
		s.place(p.x + float(w.dx), p.z + float(w.dz))
	_draw()


func _draw() -> void:
	node.global_position = pos
	node.rotation = Vector3(tilt.x, node.rotation.y, tilt.y)
