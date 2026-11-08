class_name AptRoaches
extends RefCounted
## Roaches (JS levels/apartment/props.js createRoaches): they live on surfaces (floor, counter, table, walls, the mattress) and run from you. The model and its MultiMesh come with the export (node "roaches").

const HOMES := [0, 0, 0, 1, 1, 1, 2, 2, 2, 3, 3, 4, 4, 5, 5, 5, 6, 6, 6, 7, 7, 8]
const COUNTER_TOP := 0.92
const TABLE := {"x0": -1.55, "z0": -2.55, "top": 0.42}
const BED := {"x0": 1.62, "z0": -2.85, "top": 0.55}


class Surf:
	var o: Vector3
	var U_: Vector3
	var V_: Vector3
	var N: Vector3
	var lu: float
	var lv: float
	func _init(po: Vector3, pu: Vector3, pv: Vector3, pn: Vector3, plu: float, plv: float) -> void:
		o = po
		U_ = pu
		V_ = pv
		N = pn
		lu = plu
		lv = plv


class Bug:
	var s: Surf
	var u := 0.0
	var v := 0.0
	var h := 0.0
	var wait := 0.0
	var flee := 0.0
	var scale := 1.0


var surfaces: Array[Surf] = []
var bugs: Array[Bug] = []
var mm: MultiMesh = null
var _rr := RandomNumberGenerator.new()


func _init(level: ExportedLevel) -> void:
	var R := Vector3.RIGHT
	var Z := Vector3.BACK
	var Y := Vector3.UP
	surfaces = [
		Surf.new(Vector3(-6, 0.002, 0.65), R, Z, Y, 3.55, 3.15),      # kitchen floor
		Surf.new(Vector3(-2.6, 0.002, 2.9), R, Z, Y, 2.0, 1.5),      # by the trash bags
		Surf.new(Vector3(-6, COUNTER_TOP + 0.002, 3.86), R, Z, Y, 3.3, 0.6),      # the counter
		Surf.new(Vector3(-5.99, 1.0, 1.0), Z, Y, R, 0.75, 1.3),      # the wall over the stove
		Surf.new(Vector3(TABLE.x0, float(TABLE.top) + 0.002, TABLE.z0), R, Z, Y, 1.0, 1.0),      # the coffee table
		Surf.new(Vector3(-2.4, 0.002, -3.4), R, Z, Y, 2.6, 2.6),      # living-room floor
		Surf.new(Vector3(3.5, 0.002, 1.05), R, Z, Y, 2.4, 3.4),      # bathroom floor
		Surf.new(Vector3(5.99, 0.3, 1.9), Z, Y, -R, 2.4, 1.6),      # bathroom wall
		Surf.new(Vector3(float(BED.x0) + 0.1, float(BED.top) + 0.003, float(BED.z0) + 0.1), R, Z, Y, 1.7, 1.2),      # the mattress
	]
	_rr.seed = 99
	for si: int in HOMES:
		var b := Bug.new()
		b.s = surfaces[si]
		b.u = _rr.randf()
		b.v = _rr.randf()
		b.h = _rr.randf() * TAU
		b.wait = _rr.randf() * 3.0
		b.scale = 0.8 + _rr.randf() * 0.5
		bugs.append(b)
	var nodes: Array = level.find_children("*", "MultiMeshInstance3D", true, false)
	for n: MultiMeshInstance3D in nodes:
		if String(n.name).contains("roaches") or n.get_meta(&"js_name", "") == "roaches":
			mm = n.multimesh
			(n as GeometryInstance3D).custom_aabb = AABB(Vector3(-20, -2, -20), Vector3(40, 8, 40))
			break


## returns the place of a new scatter, or null
func update(dt: float, P: Player) -> Variant:
	var scatter: Variant = null
	for i in bugs.size():
		var b := bugs[i]
		var s := b.s
		if P != null and dt > 0.0:
			var pos0 := s.o + s.U_ * (b.u * s.lu) + s.V_ * (b.v * s.lv)
			var rel := Vector3(P.x - s.o.x, P.y + 0.1 - s.o.y, P.z - s.o.z)
			var pu := rel.dot(s.U_) / s.lu
			var pv := rel.dot(s.V_) / s.lv
			var du := (b.u - pu) * s.lu
			var dv := (b.v - pv) * s.lv
			var d := sqrt(du * du + dv * dv)
			if d < 1.15 and absf(rel.dot(s.N)) < 2.2:
				if b.flee <= 0.0 and scatter == null:
					scatter = pos0
				b.flee = 1.2
				b.h = atan2(dv, du) + (_rr.randf() - 0.5) * 0.8
				b.wait = 0.0
		b.flee -= dt
		if b.wait > 0.0:
			b.wait -= dt
			if _rr.randf() < dt * 0.6:
				b.h += (_rr.randf() - 0.5) * 0.6
		else:
			var sp := 0.55 if b.flee > 0.0 else 0.13
			b.h += (_rr.randf() - 0.5) * dt * (2.0 if b.flee > 0.0 else 5.0)
			b.u += cos(b.h) * sp * dt / s.lu
			b.v += sin(b.h) * sp * dt / s.lv
			if b.u < 0.0 or b.u > 1.0:
				b.u = clampf(b.u, 0.0, 1.0)
				b.h = PI - b.h
			if b.v < 0.0 or b.v > 1.0:
				b.v = clampf(b.v, 0.0, 1.0)
				b.h = -b.h
			if b.flee <= 0.0 and _rr.randf() < dt * 0.35:
				b.wait = 0.4 + _rr.randf() * 3.5
		if mm != null:
			var f := (s.U_ * cos(b.h) + s.V_ * sin(b.h)).normalized()
			var x := s.N.cross(f).normalized()
			mm.set_instance_transform(i, Transform3D(Basis(x * b.scale, s.N * b.scale, f * b.scale), s.o + s.U_ * (b.u * s.lu) + s.V_ * (b.v * s.lv)))
	return scatter
