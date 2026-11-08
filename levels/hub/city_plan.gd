class_name CityPlan
extends RefCounted
## FOINT CITY street plan (JS levels/hub/city-plan.js): what the traffic and the crowd ask of the street grid. The plan itself is built by the JS and exported (life.json): roads, junctions, the directed lane graph.
## Here: paths sampled by distance, the signals, the turns, where a car can go next. Axis convention: an 'x' street runs along x (constant z = c), a 'z' avenue runs along z (constant x = c). +z is south, +x is east.

const LANE := 1.75
const PARK := 4.55
const CURB := 0.15
const SIG_GREEN := 13.0
const SIG_YELLOW := 3.0
const SIG_RED := 1.6
const CYCLE := 2.0 * (SIG_GREEN + SIG_YELLOW + SIG_RED)
const G := 0      # signal aspects (JS: 'G', 'Y', 'R')
const Y := 1
const R := 2
const DIRS := {&"E": Vector2(1, 0), &"W": Vector2(-1, 0), &"S": Vector2(0, 1), &"N": Vector2(0, -1)}
const REV := {&"E": &"W", &"W": &"E", &"N": &"S", &"S": &"N"}
const RIGHT := {&"E": &"S", &"S": &"W", &"W": &"N", &"N": &"E"}
const LEFT := {&"E": &"N", &"N": &"W", &"W": &"S", &"S": &"E"}


## JS makePath / pathAt: a drivable or walkable path: sampled points with cumulative lengths, sampled by distance
class Path:
	var pts: PackedVector2Array
	var cum: PackedFloat32Array
	var length := 0.0
	var kind := &""

	func _init(p: PackedVector2Array) -> void:
		pts = p
		cum.resize(p.size())
		var c := 0.0
		for i in range(1, p.size()):
			c += p[i].distance_to(p[i - 1])
			cum[i] = c
		length = c

	## position and heading at distance s: x, z, dx, dz
	func at(s: float) -> Vector4:
		s = clampf(s, 0.0, length)
		var lo := 0
		var hi := cum.size() - 1
		while hi - lo > 1:
			var m := (lo + hi) >> 1
			if cum[m] <= s:
				lo = m
			else:
				hi = m
		var a := pts[lo]
		var b := pts[hi]
		var l := cum[hi] - cum[lo]
		if l == 0.0:
			l = 1.0
		var u := (s - cum[lo]) / l
		return Vector4(a.x + (b.x - a.x) * u, a.y + (b.y - a.y) * u, (b.x - a.x) / l, (b.y - a.y) / l)


class Road:
	var id := 0
	var axis := &"x"
	var c := 0.0
	var x0 := 0.0
	var x1 := 0.0
	var z0 := 0.0
	var z1 := 0.0


class Junction:
	var id := 0
	var x := 0.0
	var z := 0.0
	var dead := false
	var signal_on := false      # (JS n.signal)
	var offset := 0.0
	var in_edges: Dictionary = {}    # direction -> Edge
	var out_edges: Dictionary = {}


class Edge:
	var id := 0
	var road: Road
	var from: Junction
	var to: Junction
	var d := &"E"
	var axis := &"x"
	var a0 := 0.0
	var a1 := 0.0
	var sg := 1
	var path: Path


var roads: Array[Road] = []
var nodes: Array[Junction] = []
var edges: Array[Edge] = []
var _turns: Dictionary = {}
var _rects := PackedFloat32Array()


func _init(j: Dictionary) -> void:
	for d: Dictionary in j["roads"]:
		var r := Road.new()
		r.id = int(d["id"])
		r.axis = StringName(d["axis"])
		r.c = d["c"]
		var q: Array = d["rect"]
		r.x0 = q[0]
		r.x1 = q[1]
		r.z0 = q[2]
		r.z1 = q[3]
		roads.append(r)
		_rects.append_array([r.x0, r.x1, r.z0, r.z1])
	for d: Dictionary in j["nodes"]:
		var n := Junction.new()
		n.id = int(d["id"])
		n.x = d["x"]
		n.z = d["z"]
		n.dead = d["dead"]
		n.signal_on = d["signal"]
		n.offset = d["offset"]
		nodes.append(n)
	for d: Dictionary in j["edges"]:
		var e := Edge.new()
		e.id = int(d["id"])
		e.road = roads[int(d["road"])]
		e.from = nodes[int(d["from"])]
		e.to = nodes[int(d["to"])]
		e.d = StringName(d["d"])
		e.axis = StringName(d["axis"])
		e.a0 = d["a0"]
		e.a1 = d["a1"]
		e.sg = int(d["sg"])
		var p: Array = d["pts"]
		e.path = Path.new(PackedVector2Array([Vector2(p[0][0], p[0][1]), Vector2(p[1][0], p[1][1])]))
		edges.append(e)
	var k := 0
	for d: Dictionary in j["nodes"]:      # (JSON keeps the JS's own order, which is what the car's choice goes by)
		for dir: String in d["in"]:
			nodes[k].in_edges[StringName(dir)] = edges[int(d["in"][dir])]
		for dir: String in d["out"]:
			nodes[k].out_edges[StringName(dir)] = edges[int(d["out"][dir])]
		k += 1


func dispose() -> void:
	for n in nodes:
		n.in_edges.clear()
		n.out_edges.clear()


## JS plan.onRoad, with no margin
func on_road(x: float, z: float) -> bool:
	var q := _rects
	var i := 0
	var n := q.size()
	while i < n:
		if x > q[i] and x < q[i + 1] and z > q[i + 2] and z < q[i + 3]:
			return true
		i += 4
	return false


## signal aspect for one axis of a junction at time t (the 'x' axis is green first)
static func signal_at(n: Junction, axis: StringName, t: float) -> int:
	var u := fposmod(t + n.offset, CYCLE)
	var mine := u if axis == &"x" else fmod(u + CYCLE * 0.5, CYCLE)
	return G if mine < SIG_GREEN else (Y if mine < SIG_GREEN + SIG_YELLOW else R)


## seconds of green left for an axis (0 when not green)
static func green_left(n: Junction, axis: StringName, t: float) -> float:
	var u := fposmod(t + n.offset, CYCLE)
	var mine := u if axis == &"x" else fmod(u + CYCLE * 0.5, CYCLE)
	return SIG_GREEN - mine if mine < SIG_GREEN else 0.0


static func right_of(d: StringName) -> Vector2:
	var a: Vector2 = DIRS[d]
	return Vector2(-a.y, a.x)


static func turn_kind(a: StringName, b: StringName) -> StringName:
	return &"straight" if a == b else (&"right" if RIGHT[a] == b else (&"left" if LEFT[a] == b else &"uturn"))


static func _bez(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, n: int) -> PackedVector2Array:
	var o := PackedVector2Array()
	o.resize(n + 1)
	for i in n + 1:
		var t := float(i) / n
		var u := 1.0 - t
		o[i] = u * u * u * p0 + 3.0 * u * u * t * p1 + 3.0 * u * t * t * p2 + t * t * t * p3
	return o


## the path a car takes through a junction from in-edge ei onto out-edge eo (a U-turn at a dead end when eo is ei's reverse)
func turn_path(ei: Edge, eo: Edge) -> Path:
	var key := ei.id * 1000 + eo.id
	if _turns.has(key):
		return _turns[key]
	var p0 := ei.path.pts[1]
	var p3 := eo.path.pts[0]
	var di: Vector2 = DIRS[ei.d]
	var d_o: Vector2 = DIRS[eo.d]
	var kind := turn_kind(ei.d, eo.d)
	var pts: PackedVector2Array
	if kind == &"straight":
		pts = PackedVector2Array([p0, p3])
	elif kind == &"uturn":
		var fw := 6.5
		pts = _bez(p0, p0 + di * fw, p3 - d_o * fw, p3, 16)
	else:
		var l := p3.distance_to(p0)
		var kk := l * (0.5 if kind == &"right" else 0.55)
		pts = _bez(p0, p0 + di * kk, p3 - d_o * kk * 0.8, p3, 14)
	var p := Path.new(pts)
	p.kind = kind
	_turns[key] = p
	return p


## where a car can go next from in-edge e (no U-turns except at dead ends; trucks may enter dead ends)
func next_edges(e: Edge, dead: bool) -> Array[Edge]:
	var n := e.to
	var opts: Array[Edge] = []
	for d: StringName in n.out_edges:
		var eo: Edge = n.out_edges[d]
		if d == REV[e.d] and not n.dead:
			continue
		if eo.to.dead and not dead:
			continue
		opts.append(eo)
	if opts.is_empty() and n.out_edges.has(REV[e.d]):
		opts.append(n.out_edges[REV[e.d]])
	return opts


## JS RNG: a seeded generator, the same sequence as the JS's
class Rng:
	var s := 0

	func _init(seed_: int) -> void:
		s = seed_

	func next() -> float:
		s = (s * 1664525 + 1013904223) & 0xFFFFFFFF
		return float(s) / 4294967296.0
